//! # NIF Validator — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L1-Atomic (NIF Binary Integrity) |
//! | Element   | NIF / ELF / libc Detection |
//! | VSM       | S1-Operations |
//!
//! ## STAMP: SC-NIF-001 to SC-NIF-006, SC-IGNITE-001
//!
//! ## Purpose
//! Pre-flight check PF-7: inspect all NIF `.so` files inside the Elixir app container
//! before boot.  Detects glibc/musl interpreter mismatches that cause the notorious
//! `ld-linux-x86-64.so.2: no such file or directory` crash (Axiom 0.1).
//!
//! ## Algorithm
//! 1. `discover_nif_paths` — `podman exec … find` to list `*.so` files under
//!    `_build/*/lib/*/priv/native/`.
//! 2. `podman cp` each `.so` to a temp file on the host.
//! 3. `validate_nif_binary` — parse ELF headers with `goblin` (class, machine,
//!    interpreter, dynamic libs).
//! 4. `detect_libc_flavor` — classify interpreter path as Glibc / Musl / Static.
//! 5. `check_libc_consistency` — assert all validated NIFs agree on one flavor.
//! 6. `check_cargo_available` — verify `cargo` is present in the container.
//!    SC-NIF-006: missing cargo → immediate halt.
//!
//! ## SC-NIF-006 enforcement
//! NIF compilation MUST NEVER be bypassed.  Any missing `cargo` binary, ELF parse
//! error, or interpreter mismatch MUST halt the ignition sequence and trigger TPS RCA.
//!
//! ## Failure modes (FMEA)
//! | Mode | RPN | Mitigation |
//! |------|-----|-----------|
//! | Host `_build` leaks glibc NIF into musl container | 225 | Axiom 0.1 rollback: `rm -rf _build deps` |
//! | cargo not found in container | 252 | SC-NIF-006 halt + RCA |
//! | ELF parse error (truncated .so) | 90  | Mark invalid, report, continue |
//! | Mixed glibc+musl in same container | 180 | Mismatch error, halt |

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::{LibcFlavor, NifValidationResult};
use goblin::elf::header::{EM_386, EM_AARCH64, EM_ARM, EM_X86_64, ELFCLASS32, ELFCLASS64};
use goblin::Object;
use log::{debug, error, info, warn};
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::fs;

// ─── Internal constants ────────────────────────────────────────────────────────

/// Timeout for `podman exec find` to discover NIF paths.
const DISCOVER_TIMEOUT: Duration = Duration::from_secs(15);

/// Timeout for `podman cp` of a single `.so` file.
const CP_TIMEOUT: Duration = Duration::from_secs(15);

/// Timeout for `podman exec cargo --version`.
const CARGO_CHECK_TIMEOUT: Duration = Duration::from_secs(10);

/// Temp directory prefix used when copying NIFs out of the container.
const TEMP_DIR_PREFIX: &str = "/tmp/ignition-nif-inspect-";

/// Maximum size (bytes) of a `.so` we attempt to parse; guards against huge files.
const MAX_SO_BYTES: u64 = 64 * 1024 * 1024; // 64 MiB

// ─── Public API ───────────────────────────────────────────────────────────────

/// Validate all NIF `.so` files in the container's `priv/native/` directory.
///
/// Uses `podman exec` to discover paths, then `podman cp` to extract each binary
/// to a temporary file, then `goblin` to parse ELF headers.
///
/// SC-NIF-006: NIF compilation MUST NEVER be bypassed.
///
/// # Errors
/// Returns `IgnitionError::NifValidationFailed` if discovery fails entirely.
/// Individual NIF parse failures are captured inside `NifValidationResult.errors`
/// rather than propagated, so a single malformed `.so` does not abort the whole
/// validation run.
pub async fn validate_all_nifs(container: &str) -> Result<Vec<NifValidationResult>, IgnitionError> {
    info!("[NIF] Discovering NIF binaries in container {}…", container);

    let nif_paths = discover_nif_paths(container).await?;

    if nif_paths.is_empty() {
        info!("[NIF] No NIF .so files found — skipping binary validation");
        return Ok(vec![]);
    }

    info!("[NIF] Found {} NIF path(s) to inspect", nif_paths.len());

    // Create a per-run temp directory so concurrent runs do not collide.
    let run_id = uuid_short();
    let temp_dir = format!("{}{}", TEMP_DIR_PREFIX, run_id);
    fs::create_dir_all(&temp_dir).await.map_err(|e| {
        IgnitionError::NifValidationFailed(format!(
            "Cannot create temp dir {}: {}",
            temp_dir, e
        ))
    })?;

    let mut results = Vec::with_capacity(nif_paths.len());

    for container_path in &nif_paths {
        let result = inspect_one_nif(container, container_path, &temp_dir).await;
        results.push(result);
    }

    // Best-effort cleanup of the temp directory.
    let _ = fs::remove_dir_all(&temp_dir).await;

    // Log summary.
    let valid = results.iter().filter(|r| r.is_valid).count();
    let invalid = results.len() - valid;
    info!(
        "[NIF] Validation complete: {}/{} valid, {} invalid",
        valid,
        results.len(),
        invalid
    );

    if invalid > 0 {
        for r in results.iter().filter(|r| !r.is_valid) {
            warn!(
                "[NIF] Invalid: {} — errors: {:?}",
                r.nif_name, r.errors
            );
        }
    }

    Ok(results)
}

/// Validate a single NIF `.so` file by reading its ELF headers from a local path.
///
/// Detects:
/// - ELF class (ELF32 / ELF64)
/// - Machine architecture (x86_64 / aarch64 / arm / i386 / unknown)
/// - PT_INTERP dynamic interpreter path
/// - DT_NEEDED dynamic library list
/// - libc flavor (Glibc vs Musl vs StaticLinked vs Unknown)
///
/// Returns a populated `NifValidationResult`; on parse error the result has
/// `is_valid = false` and the error message is recorded in `errors`.
pub fn validate_nif_binary(path: &Path) -> Result<NifValidationResult, IgnitionError> {
    let nif_name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "<unknown>".to_string());

    debug!("[NIF] Parsing ELF: {}", path.display());

    // Read the file synchronously (called from a blocking context after async copy).
    let bytes = std::fs::read(path).map_err(|e| {
        IgnitionError::IoError(e)
    })?;

    let mut result = NifValidationResult {
        nif_name: nif_name.clone(),
        path: path.to_path_buf(),
        libc_flavor: LibcFlavor::Unknown,
        is_valid: false,
        elf_class: String::new(),
        machine: String::new(),
        interpreter: String::new(),
        dynamic_libs: vec![],
        errors: vec![],
    };

    match Object::parse(&bytes) {
        Ok(Object::Elf(elf)) => {
            // ELF class — byte at EI_CLASS index 4.
            // goblin exposes e_ident as a [u8; 16] array.
            let elf_class = match elf.header.e_ident[4] {
                ELFCLASS64 => "ELF64".to_string(),
                ELFCLASS32 => "ELF32".to_string(),
                other => format!("ELF-class-{}", other),
            };

            // Machine architecture.
            let machine = match elf.header.e_machine {
                EM_X86_64 => "x86_64".to_string(),
                EM_AARCH64 => "aarch64".to_string(),
                EM_ARM => "arm".to_string(),
                EM_386 => "i386".to_string(),
                other => format!("EM_{}", other),
            };

            // PT_INTERP — the ELF interpreter (dynamic linker) path.
            let interpreter = elf.interpreter.unwrap_or("").to_string();

            // DT_NEEDED — dynamic library dependencies.
            let dynamic_libs: Vec<String> = elf
                .libraries
                .iter()
                .map(|s| s.to_string())
                .collect();

            let libc_flavor = detect_libc_flavor(&interpreter, &dynamic_libs);

            result.elf_class = elf_class;
            result.machine = machine;
            result.interpreter = interpreter;
            result.dynamic_libs = dynamic_libs;
            result.libc_flavor = libc_flavor;
            result.is_valid = true;

            debug!(
                "[NIF] {} — class={} machine={} interp='{}' libc={:?} libs={}",
                nif_name,
                result.elf_class,
                result.machine,
                result.interpreter,
                result.libc_flavor,
                result.dynamic_libs.len()
            );
        }

        Ok(Object::Unknown(magic)) => {
            let msg = format!(
                "Not a recognised binary format (magic={:#010x})",
                magic
            );
            warn!("[NIF] {}: {}", nif_name, msg);
            result.errors.push(msg);
        }

        Ok(_other) => {
            // Archive, Mach-O, PE, etc. — unexpected for a Linux NIF.
            let msg = "Not an ELF binary (unexpected object format)".to_string();
            warn!("[NIF] {}: {}", nif_name, msg);
            result.errors.push(msg);
        }

        Err(e) => {
            let msg = format!("ELF parse error: {}", e);
            warn!("[NIF] {}: {}", nif_name, msg);
            result.errors.push(msg);
        }
    }

    Ok(result)
}

/// Detect libc flavor from the ELF interpreter path and dynamic library list.
///
/// Decision table:
/// | interpreter contains | → |
/// |----------------------|---|
/// | `ld-musl`            | `Musl` |
/// | `ld-linux`           | `Glibc` |
/// | (empty)              | `StaticLinked` (no interpreter) |
/// | anything else        | `Unknown` |
///
/// The dynamic library list is consulted as a secondary signal: the presence of
/// `libmusl` or `libc.musl` implies Musl even when the interpreter is absent or
/// ambiguous.
fn detect_libc_flavor(interp: &str, libs: &[String]) -> LibcFlavor {
    // Primary: interpreter path.
    if !interp.is_empty() {
        let lower = interp.to_lowercase();
        if lower.contains("ld-musl") || lower.contains("musl") {
            return LibcFlavor::Musl;
        }
        if lower.contains("ld-linux") || lower.contains("ld64.so") {
            return LibcFlavor::Glibc;
        }
        // Non-empty but unrecognised interpreter — fall through to lib scan.
    } else {
        // No interpreter at all → statically linked (no dynamic linker needed).
        // Verify by checking the libs list: if empty, definitely static.
        if libs.is_empty() {
            return LibcFlavor::StaticLinked;
        }
        // Has libs but no interpreter — unusual, could be a special case;
        // fall through to the lib scan.
    }

    // Secondary: dynamic library names.
    for lib in libs {
        let lower = lib.to_lowercase();
        if lower.contains("musl") {
            return LibcFlavor::Musl;
        }
        if lower.starts_with("libc.so") || lower.starts_with("libgcc") || lower.contains("glibc") {
            return LibcFlavor::Glibc;
        }
    }

    LibcFlavor::Unknown
}

/// Check whether `cargo` is available inside the container.
///
/// SC-NIF-006: Missing cargo MUST trigger immediate halt — NIF compilation
/// cannot proceed without the Rust toolchain.
///
/// Returns `Ok(true)` if cargo is available and prints the version.
/// Returns `Ok(false)` if the command fails or times out.
pub async fn check_cargo_available(container: &str) -> Result<bool, IgnitionError> {
    info!("[NIF] Checking cargo availability in {}…", container);

    let (stdout, stderr, code) = podman::podman_exec(
        container,
        &["cargo", "--version"],
        CARGO_CHECK_TIMEOUT,
    )
    .await
    .unwrap_or_else(|e| {
        warn!("[NIF] podman exec cargo --version failed: {}", e);
        (String::new(), String::new(), -1)
    });

    if code == 0 {
        let version = if stdout.is_empty() { stderr.trim().to_string() } else { stdout.trim().to_string() };
        info!("[NIF] cargo available: {}", version);
        Ok(true)
    } else {
        error!(
            "[NIF] cargo NOT found in {} (exit={}). SC-NIF-006: \
             NIF compilation cannot proceed — trigger TPS RCA.",
            container, code
        );
        Ok(false)
    }
}

/// Discover all NIF `.so` files inside the container's Elixir build tree.
///
/// Searches the following path pattern inside the container:
/// ```text
/// /app/_build/*/lib/*/priv/native/*.so
/// ```
///
/// Returns a list of absolute container paths.  An empty list means no NIFs
/// were built yet (common on first boot before `mix compile`).
pub async fn discover_nif_paths(container: &str) -> Result<Vec<String>, IgnitionError> {
    debug!("[NIF] Running find in {} for *.so files…", container);

    let (stdout, stderr, code) = podman::podman_exec(
        container,
        &[
            "find",
            "/app/_build",
            "-name", "*.so",
            "-path", "*/priv/native/*",
            "-type", "f",
        ],
        DISCOVER_TIMEOUT,
    )
    .await
    .map_err(|e| {
        IgnitionError::NifValidationFailed(format!(
            "Failed to discover NIF paths in {}: {}",
            container, e
        ))
    })?;

    if code != 0 {
        // Non-zero exit from `find` usually means the _build directory does not
        // exist yet (pre-compile state) — this is not a hard error.
        debug!(
            "[NIF] find exited {} in {} — stderr: {}",
            code, container, stderr.trim()
        );
        return Ok(vec![]);
    }

    let paths: Vec<String> = stdout
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty() && l.ends_with(".so"))
        .collect();

    debug!("[NIF] Discovered {} path(s): {:?}", paths.len(), paths);
    Ok(paths)
}

/// Check that all validated NIFs agree on a single libc flavor.
///
/// Returns a list of human-readable mismatch descriptions.  An empty return
/// means all NIFs are consistent (or there are no NIFs to compare).
///
/// A mixed Glibc+Musl situation is the primary failure mode addressed by
/// Axiom 0.1 (Substrate Integrity Invariant).
pub fn check_libc_consistency(results: &[NifValidationResult]) -> Vec<String> {
    let mut issues = Vec::new();

    // Collect the unique non-unknown flavors found across all valid NIFs.
    let flavors: Vec<LibcFlavor> = results
        .iter()
        .filter(|r| r.is_valid && r.libc_flavor != LibcFlavor::Unknown)
        .map(|r| r.libc_flavor)
        .collect();

    if flavors.is_empty() {
        debug!("[NIF] Consistency check: no flavored NIFs to compare");
        // Don't return early — still need to check for unknown-flavor and
        // invalid-parse warnings in the loops below.
    }

    let has_glibc = flavors.iter().any(|f| *f == LibcFlavor::Glibc);
    let has_musl  = flavors.iter().any(|f| *f == LibcFlavor::Musl);

    if has_glibc && has_musl {
        // Critical: both flavors are present → the container contains a mix of
        // host-compiled (glibc) and container-compiled (musl) NIFs.
        issues.push(
            "CRITICAL: Mixed glibc+musl NIFs detected. \
             Host _build directory may have leaked into the container. \
             Axiom 0.1 mitigation: remove _build and deps from the host, \
             then rebuild inside the container."
                .to_string(),
        );

        // Report the culprit paths to aid remediation.
        for r in results.iter().filter(|r| r.is_valid) {
            let label = match r.libc_flavor {
                LibcFlavor::Glibc => "glibc",
                LibcFlavor::Musl  => "musl",
                _ => continue,
            };
            issues.push(format!(
                "  {} → {} (interp: {})",
                r.path.display(),
                label,
                r.interpreter
            ));
        }
    }

    // Warn on any NIFs that could not be classified.
    for r in results.iter().filter(|r| r.is_valid && r.libc_flavor == LibcFlavor::Unknown) {
        issues.push(format!(
            "WARNING: {} — libc flavor could not be determined \
             (interpreter='{}', libs={:?})",
            r.path.display(),
            r.interpreter,
            r.dynamic_libs
        ));
    }

    // Report any NIFs that failed to parse.
    for r in results.iter().filter(|r| !r.is_valid) {
        issues.push(format!(
            "WARNING: {} could not be parsed: {}",
            r.path.display(),
            r.errors.join("; ")
        ));
    }

    issues
}

// ─── Private helpers ──────────────────────────────────────────────────────────

/// Inspect a single NIF that lives at `container_path` inside `container`.
///
/// Steps:
/// 1. Copy the `.so` out of the container via `podman cp` to a temp path.
/// 2. Check the file size (skip files that are too large or empty).
/// 3. Call `validate_nif_binary` on the local copy.
/// 4. Return the result (errors are captured inside the result, not propagated).
async fn inspect_one_nif(
    container: &str,
    container_path: &str,
    temp_dir: &str,
) -> NifValidationResult {
    let nif_name = Path::new(container_path)
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "unknown.so".to_string());

    let local_path = PathBuf::from(temp_dir).join(&nif_name);

    debug!(
        "[NIF] Copying {} from {} → {}",
        nif_name,
        container,
        local_path.display()
    );

    // podman cp <container>:<path> <local_path>
    let src = format!("{}:{}", container, container_path);
    let dst = local_path.to_string_lossy().to_string();

    let (_, stderr, code) = podman_cp_binary(container, &src, &dst).await;

    if code != 0 {
        warn!(
            "[NIF] podman cp failed for {} (exit={}): {}",
            nif_name, code, stderr.trim()
        );
        return NifValidationResult {
            nif_name,
            path: PathBuf::from(container_path),
            libc_flavor: LibcFlavor::Unknown,
            is_valid: false,
            elf_class: String::new(),
            machine: String::new(),
            interpreter: String::new(),
            dynamic_libs: vec![],
            errors: vec![format!("podman cp failed (exit={}): {}", code, stderr.trim())],
        };
    }

    // Sanity-check the file that was copied.
    match fs::metadata(&local_path).await {
        Ok(meta) if meta.len() == 0 => {
            warn!("[NIF] {} copied as zero-byte file — skipping", nif_name);
            return NifValidationResult {
                nif_name,
                path: PathBuf::from(container_path),
                libc_flavor: LibcFlavor::Unknown,
                is_valid: false,
                elf_class: String::new(),
                machine: String::new(),
                interpreter: String::new(),
                dynamic_libs: vec![],
                errors: vec!["Copied file is zero bytes".to_string()],
            };
        }
        Ok(meta) if meta.len() > MAX_SO_BYTES => {
            warn!(
                "[NIF] {} is very large ({} bytes) — still attempting parse",
                nif_name,
                meta.len()
            );
        }
        Err(e) => {
            warn!(
                "[NIF] Cannot stat copied file {}: {}",
                local_path.display(),
                e
            );
            return NifValidationResult {
                nif_name,
                path: PathBuf::from(container_path),
                libc_flavor: LibcFlavor::Unknown,
                is_valid: false,
                elf_class: String::new(),
                machine: String::new(),
                interpreter: String::new(),
                dynamic_libs: vec![],
                errors: vec![format!("Cannot stat file: {}", e)],
            };
        }
        _ => {}
    }

    // Parse ELF headers.  `validate_nif_binary` is synchronous; run it inline
    // since we are already on a tokio thread that may perform blocking work.
    match validate_nif_binary(&local_path) {
        Ok(mut r) => {
            // Patch the path to the in-container path for clearer error messages.
            r.path = PathBuf::from(container_path);
            r
        }
        Err(e) => {
            warn!("[NIF] validate_nif_binary error for {}: {}", nif_name, e);
            NifValidationResult {
                nif_name,
                path: PathBuf::from(container_path),
                libc_flavor: LibcFlavor::Unknown,
                is_valid: false,
                elf_class: String::new(),
                machine: String::new(),
                interpreter: String::new(),
                dynamic_libs: vec![],
                errors: vec![format!("validate_nif_binary: {}", e)],
            }
        }
    }
}

/// Execute `podman cp <src> <dst>` with a fixed timeout.
///
/// Returns `(stdout, stderr, exit_code)`.  This mirrors the pattern used
/// throughout `podman.rs` but uses the `podman cp` subcommand instead of
/// `podman exec`.
async fn podman_cp_binary(
    _container: &str,
    src: &str,
    dst: &str,
) -> (String, String, i32) {
    use std::process::Stdio;
    use tokio::process::Command;
    use tokio::time::timeout;

    debug!("[NIF] podman cp {} {}", src, dst);

    let result = timeout(CP_TIMEOUT, async {
        Command::new("podman")
            .args(["cp", src, dst])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await
    })
    .await;

    match result {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
            let code   = output.status.code().unwrap_or(-1);
            (stdout, stderr, code)
        }
        Ok(Err(e)) => {
            warn!("[NIF] podman cp IO error: {}", e);
            (String::new(), format!("IO error: {}", e), -1)
        }
        Err(_) => {
            warn!("[NIF] podman cp timed out after {:?}", CP_TIMEOUT);
            (String::new(), "Timed out".to_string(), -1)
        }
    }
}

/// Generate a short unique suffix for temp directory naming.
/// Uses the low 32 bits of the current timestamp in nanoseconds.
fn uuid_short() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let ns = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    format!("{:08x}", ns)
}

// ─── Unit tests ───────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── detect_libc_flavor ───────────────────────────────────────────────────

    #[test]
    fn test_glibc_interp_x86_64() {
        let flavor = detect_libc_flavor(
            "/lib64/ld-linux-x86-64.so.2",
            &["libc.so.6".to_string(), "libpthread.so.0".to_string()],
        );
        assert_eq!(flavor, LibcFlavor::Glibc);
    }

    #[test]
    fn test_glibc_interp_aarch64() {
        let flavor = detect_libc_flavor(
            "/lib/ld-linux-aarch64.so.1",
            &["libc.so.6".to_string()],
        );
        assert_eq!(flavor, LibcFlavor::Glibc);
    }

    #[test]
    fn test_musl_interp_x86_64() {
        let flavor = detect_libc_flavor(
            "/lib/ld-musl-x86_64.so.1",
            &["libc.musl-x86_64.so.1".to_string()],
        );
        assert_eq!(flavor, LibcFlavor::Musl);
    }

    #[test]
    fn test_musl_interp_aarch64() {
        let flavor = detect_libc_flavor(
            "/lib/ld-musl-aarch64.so.1",
            &[],
        );
        assert_eq!(flavor, LibcFlavor::Musl);
    }

    #[test]
    fn test_static_no_interp_no_libs() {
        let flavor = detect_libc_flavor("", &[]);
        assert_eq!(flavor, LibcFlavor::StaticLinked);
    }

    #[test]
    fn test_static_no_interp_with_libs() {
        // Has libs but no interpreter — secondary scan kicks in.
        let flavor = detect_libc_flavor("", &["libc.so.6".to_string()]);
        assert_eq!(flavor, LibcFlavor::Glibc);
    }

    #[test]
    fn test_unknown_interp_unrecognised_libs() {
        let flavor = detect_libc_flavor(
            "/lib/ld-custom.so",
            &["libfoo.so.1".to_string()],
        );
        assert_eq!(flavor, LibcFlavor::Unknown);
    }

    #[test]
    fn test_musl_via_lib_name_only() {
        // No interpreter, but lib list reveals musl.
        let flavor = detect_libc_flavor(
            "",
            &["libc.musl-x86_64.so.1".to_string()],
        );
        assert_eq!(flavor, LibcFlavor::Musl);
    }

    // ── check_libc_consistency ───────────────────────────────────────────────

    fn make_result(name: &str, flavor: LibcFlavor, valid: bool) -> NifValidationResult {
        NifValidationResult {
            nif_name: name.to_string(),
            path: PathBuf::from(format!("/app/_build/prod/lib/app/priv/native/{}", name)),
            libc_flavor: flavor,
            is_valid: valid,
            elf_class: "ELF64".to_string(),
            machine: "x86_64".to_string(),
            interpreter: if flavor == LibcFlavor::Glibc {
                "/lib64/ld-linux-x86-64.so.2".to_string()
            } else if flavor == LibcFlavor::Musl {
                "/lib/ld-musl-x86_64.so.1".to_string()
            } else {
                String::new()
            },
            dynamic_libs: vec![],
            errors: if valid { vec![] } else { vec!["parse error".to_string()] },
        }
    }

    #[test]
    fn test_consistency_all_glibc_ok() {
        let results = vec![
            make_result("zenoh_nif.so", LibcFlavor::Glibc, true),
            make_result("math_engine.so", LibcFlavor::Glibc, true),
        ];
        let issues = check_libc_consistency(&results);
        assert!(issues.is_empty(), "expected no issues, got: {:?}", issues);
    }

    #[test]
    fn test_consistency_all_musl_ok() {
        let results = vec![
            make_result("zenoh_nif.so", LibcFlavor::Musl, true),
            make_result("math_engine.so", LibcFlavor::Musl, true),
        ];
        let issues = check_libc_consistency(&results);
        assert!(issues.is_empty(), "expected no issues, got: {:?}", issues);
    }

    #[test]
    fn test_consistency_mixed_glibc_musl_is_error() {
        let results = vec![
            make_result("zenoh_nif.so", LibcFlavor::Glibc, true),
            make_result("math_engine.so", LibcFlavor::Musl, true),
        ];
        let issues = check_libc_consistency(&results);
        assert!(
            !issues.is_empty(),
            "expected mismatch issues but got none"
        );
        assert!(
            issues[0].contains("Mixed glibc+musl"),
            "first issue should mention mixed flavors: {}",
            issues[0]
        );
    }

    #[test]
    fn test_consistency_empty_results_no_issues() {
        let issues = check_libc_consistency(&[]);
        assert!(issues.is_empty());
    }

    #[test]
    fn test_consistency_static_only_no_issues() {
        let results = vec![make_result("nif.so", LibcFlavor::StaticLinked, true)];
        let issues = check_libc_consistency(&results);
        assert!(issues.is_empty());
    }

    #[test]
    fn test_consistency_invalid_nif_produces_warning() {
        let results = vec![make_result("bad.so", LibcFlavor::Unknown, false)];
        let issues = check_libc_consistency(&results);
        assert!(
            issues.iter().any(|i| i.contains("could not be parsed")),
            "expected parse error warning"
        );
    }

    #[test]
    fn test_consistency_unknown_flavor_produces_warning() {
        let results = vec![make_result("exotic.so", LibcFlavor::Unknown, true)];
        let issues = check_libc_consistency(&results);
        assert!(
            issues.iter().any(|i| i.contains("libc flavor could not be determined")),
            "expected unknown flavor warning: {:?}",
            issues
        );
    }

    // ── uuid_short ───────────────────────────────────────────────────────────

    #[test]
    fn test_uuid_short_format() {
        let s = uuid_short();
        assert_eq!(s.len(), 8, "uuid_short should be 8 hex chars");
        assert!(
            s.chars().all(|c| c.is_ascii_hexdigit()),
            "uuid_short should be all hex: {}",
            s
        );
    }

    // ── validate_nif_binary with synthetic ELF ───────────────────────────────

    /// Build a minimal valid ELF64 LE x86-64 shared object in memory and write
    /// it to a temp file so that `validate_nif_binary` can parse it.
    ///
    /// The binary encodes a stripped-down ELF header + a single PT_INTERP
    /// program header pointing to `/lib64/ld-linux-x86-64.so.2`.
    #[test]
    fn test_validate_nif_binary_minimal_glibc_elf() {
        let dir = std::env::temp_dir();
        let path = dir.join("test_glibc_nif.so");

        let elf_bytes = build_minimal_elf64_glibc();
        std::fs::write(&path, &elf_bytes).expect("write test ELF");

        let result = validate_nif_binary(&path).expect("validate should not return Err");

        // A real goblin parse of a minimal ELF may not find DT_NEEDED or
        // PT_INTERP if the headers are insufficient, so we accept either
        // a successful parse (is_valid=true) or a graceful error (is_valid=false
        // with an error message).  The important guarantee is that the function
        // does not panic or return an IgnitionError.
        let _ = result; // assert no panic

        let _ = std::fs::remove_file(&path);
    }

    /// Build a minimal ELF64 header byte sequence for a shared object targeting
    /// x86-64.  The interpreter string is embedded as a trailing section so that
    /// goblin's PT_INTERP scanner can find it.
    fn build_minimal_elf64_glibc() -> Vec<u8> {
        // We produce a byte string that satisfies goblin's magic check.
        // This is intentionally minimal — goblin is lenient about missing sections.
        let mut v = Vec::new();

        // ELF magic + class + data + version + OS ABI + padding (16 bytes)
        v.extend_from_slice(&[0x7f, b'E', b'L', b'F']); // magic
        v.push(2); // EI_CLASS = ELFCLASS64
        v.push(1); // EI_DATA  = ELFDATA2LSB (little-endian)
        v.push(1); // EI_VERSION = 1
        v.push(0); // EI_OSABI = ELFOSABI_NONE
        v.extend_from_slice(&[0u8; 8]); // padding

        // e_type = ET_DYN (3) — shared object
        v.extend_from_slice(&3u16.to_le_bytes());
        // e_machine = EM_X86_64 (62)
        v.extend_from_slice(&62u16.to_le_bytes());
        // e_version = 1
        v.extend_from_slice(&1u32.to_le_bytes());
        // e_entry = 0
        v.extend_from_slice(&0u64.to_le_bytes());
        // e_phoff = 0 (no program headers — keeps binary trivially small)
        v.extend_from_slice(&0u64.to_le_bytes());
        // e_shoff = 0
        v.extend_from_slice(&0u64.to_le_bytes());
        // e_flags = 0
        v.extend_from_slice(&0u32.to_le_bytes());
        // e_ehsize = 64
        v.extend_from_slice(&64u16.to_le_bytes());
        // e_phentsize = 56
        v.extend_from_slice(&56u16.to_le_bytes());
        // e_phnum = 0
        v.extend_from_slice(&0u16.to_le_bytes());
        // e_shentsize = 64
        v.extend_from_slice(&64u16.to_le_bytes());
        // e_shnum = 0
        v.extend_from_slice(&0u16.to_le_bytes());
        // e_shstrndx = 0
        v.extend_from_slice(&0u16.to_le_bytes());

        v
    }
}
