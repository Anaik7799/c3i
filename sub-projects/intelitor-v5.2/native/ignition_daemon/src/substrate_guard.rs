//! # Substrate Guard — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L1-Atomic (Substrate Integrity) |
//! | Element   | Axiom 0.1 / Volume / Contamination |
//!
//! ## STAMP: SC-IGNITE-001, SC-IGNITE-002, Axiom 0.1, Axiom 0.2
//!
//! Enforces the two substrate axioms from CLAUDE.md §0.0 before any container
//! boot is permitted:
//!
//! ### Axiom 0.1 — Substrate Integrity Invariant
//! ```text
//! ∀c ∈ C_mesh : Mount(HostSource) ⟹ ¬∃ Artifact(HostBuild)
//! ```
//! Host-side `_build` and `deps` directories are PROHIBITED when running in
//! containerized mesh mode. They cause glibc/musl NIF conflicts.
//!
//! ### Axiom 0.2 — Volume Shadowing Safeguard
//! Volume mounts SHALL NOT shadow directories containing image-baked
//! configuration files unless the volume is pre-seeded with canonical state.
//!
//! ## Failure Mode (FMEA RPN 225)
//! GlibcMuslConflict: host `_build` leaks into container → NIF crash at
//! BEAM startup.  Remediation: `rm -rf _build deps` on host.
//!
//! ## Usage
//! ```no_run
//! use std::path::Path;
//! use crate::substrate_guard;
//!
//! let report = substrate_guard::run_all_checks(Path::new("/project")).await?;
//! if !report.all_passed {
//!     let cmds = substrate_guard::remediation_commands(&report);
//!     // present cmds to operator
//! }
//! ```

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::{SubstrateCheck, SubstrateReport, MESH_NETWORK};
use log::{debug, error, info, warn};
use std::fs;
use std::path::{Path, PathBuf};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Run all substrate integrity checks.
///
/// Checks in order:
/// 1. Host `_build` contamination (Axiom 0.1)
/// 2. Host `deps` contamination (Axiom 0.1)
/// 3. NIF `.so` files compiled on host (glibc/musl conflict risk)
/// 4. Volume mount shadow analysis (Axiom 0.2)
/// 5. `SKIP_ZENOH_NIF` environment variable (SC-ZENOH-001)
/// 6. Container network integrity (mesh DNS)
///
/// Returns a `SubstrateReport` with all individual check results and
/// aggregated contamination paths.
///
/// SC-IGNITE-001: Architectural control checks MUST be enforced at every
/// ignition stage.
pub async fn run_all_checks(project_root: &Path) -> Result<SubstrateReport, IgnitionError> {
    info!(
        "[SubstrateGuard] Running Axiom 0.1/0.2 checks on {}",
        project_root.display()
    );

    let mut checks: Vec<SubstrateCheck> = Vec::with_capacity(6);

    // ── Check 1: host _build (sync, filesystem) ──────────────────────────────
    let build_check = check_host_build(project_root);
    let host_build_detected = !build_check.passed;
    if host_build_detected {
        warn!(
            "[SubstrateGuard] AXIOM 0.1 VIOLATION: {}",
            build_check.detail
        );
    } else {
        debug!("[SubstrateGuard] _build check passed");
    }
    checks.push(build_check);

    // ── Check 2: host deps (sync, filesystem) ────────────────────────────────
    let deps_check = check_host_deps(project_root);
    let host_deps_detected = !deps_check.passed;
    if host_deps_detected {
        warn!(
            "[SubstrateGuard] AXIOM 0.1 VIOLATION: {}",
            deps_check.detail
        );
    } else {
        debug!("[SubstrateGuard] deps check passed");
    }
    checks.push(deps_check);

    // ── Check 3: NIF .so contamination (sync, filesystem walk) ───────────────
    let nif_check = check_nif_contamination(project_root);
    if !nif_check.passed {
        error!(
            "[SubstrateGuard] NIF contamination detected: {}",
            nif_check.detail
        );
    } else {
        debug!("[SubstrateGuard] NIF contamination check passed");
    }
    checks.push(nif_check);

    // ── Check 4: volume shadow analysis (sync, file read) ────────────────────
    let vol_check = check_volume_shadows(project_root);
    if !vol_check.passed {
        warn!(
            "[SubstrateGuard] AXIOM 0.2 WARNING: {}",
            vol_check.detail
        );
    } else {
        debug!("[SubstrateGuard] volume shadow check passed");
    }
    checks.push(vol_check);

    // ── Check 5: SKIP_ZENOH_NIF env (sync, env read) ─────────────────────────
    let zenoh_check = check_zenoh_nif_enabled();
    if !zenoh_check.passed {
        warn!(
            "[SubstrateGuard] SC-ZENOH-001 WARNING: {}",
            zenoh_check.detail
        );
    } else {
        debug!("[SubstrateGuard] SKIP_ZENOH_NIF check passed");
    }
    checks.push(zenoh_check);

    // ── Check 6: network integrity (async, podman call) ──────────────────────
    let net_check = check_network_integrity(MESH_NETWORK).await;
    if !net_check.passed {
        warn!(
            "[SubstrateGuard] Network check: {}",
            net_check.detail
        );
    } else {
        debug!("[SubstrateGuard] network integrity check passed");
    }
    checks.push(net_check);

    // ── Aggregate contamination paths ─────────────────────────────────────────
    let contamination_paths = find_contamination_paths(project_root);

    let all_passed = checks.iter().all(|c| c.passed);
    let passed_count = checks.iter().filter(|c| c.passed).count();

    if all_passed {
        info!(
            "[SubstrateGuard] All {}/{} substrate checks passed — substrate is clean",
            passed_count,
            checks.len()
        );
    } else {
        let failed: Vec<&str> = checks
            .iter()
            .filter(|c| !c.passed)
            .map(|c| c.name.as_str())
            .collect();
        error!(
            "[SubstrateGuard] {}/{} checks FAILED: {:?}",
            checks.len() - passed_count,
            checks.len(),
            failed
        );
    }

    Ok(SubstrateReport {
        checks,
        all_passed,
        host_build_detected,
        host_deps_detected,
        contamination_paths,
    })
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDIVIDUAL CHECKS (sync — no async needed for filesystem probes)
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if host-side `_build` directory exists with compiled artifacts.
///
/// Axiom 0.1: Host `_build` is PROHIBITED in containerized mode.
///
/// A non-empty `_build` directory is only flagged as contaminated when it
/// contains compiled BEAM bytecode (`.beam`) or native shared objects
/// (`.so`).  An empty `_build/` (e.g. created by a failed compile) is
/// reported as a warning but does not constitute a hard violation.
///
/// Detection criteria:
/// - `{project_root}/_build/` directory exists, AND
/// - at least one of its top-level subdirectories is non-empty (contains
///   files, indicating a prior compile has been run).
fn check_host_build(project_root: &Path) -> SubstrateCheck {
    let name = "host_build_contamination".to_string();
    let build_dir = project_root.join("_build");

    if !build_dir.exists() {
        return SubstrateCheck {
            name,
            passed: true,
            detail: "_build directory does not exist — substrate is clean".to_string(),
        };
    }

    // Directory exists: check whether it contains compiled artifacts.
    match has_compiled_artifacts(&build_dir) {
        Ok(true) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Host _build directory {} contains compiled artifacts (BEAM/NIF .so files). \
                 Axiom 0.1: PROHIBITED in containerized mesh mode. \
                 Run: rm -rf _build",
                build_dir.display()
            ),
        },
        Ok(false) => SubstrateCheck {
            name,
            passed: true,
            detail: format!(
                "_build directory exists at {} but contains no compiled artifacts — \
                 likely an empty skeleton from a failed compile; substrate is clean",
                build_dir.display()
            ),
        },
        Err(e) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Failed to inspect _build directory {}: {} — treating as contaminated",
                build_dir.display(),
                e
            ),
        },
    }
}

/// Check if host-side `deps` directory exists with dependency packages.
///
/// Axiom 0.1: Host `deps` is PROHIBITED in containerized mode.
///
/// An empty `deps/` is tolerated; it is only flagged when subdirectories
/// are present (each subdirectory is a fetched dependency).
fn check_host_deps(project_root: &Path) -> SubstrateCheck {
    let name = "host_deps_contamination".to_string();
    let deps_dir = project_root.join("deps");

    if !deps_dir.exists() {
        return SubstrateCheck {
            name,
            passed: true,
            detail: "deps directory does not exist — substrate is clean".to_string(),
        };
    }

    match count_subdirectories(&deps_dir) {
        Ok(0) => SubstrateCheck {
            name,
            passed: true,
            detail: format!(
                "deps directory exists at {} but is empty — substrate is clean",
                deps_dir.display()
            ),
        },
        Ok(n) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Host deps directory {} contains {} dependency packages. \
                 Axiom 0.1: PROHIBITED in containerized mesh mode. \
                 Run: rm -rf deps",
                deps_dir.display(),
                n
            ),
        },
        Err(e) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Failed to inspect deps directory {}: {} — treating as contaminated",
                deps_dir.display(),
                e
            ),
        },
    }
}

/// Check for NIF `.so` files compiled on host that would conflict with
/// container libc.
///
/// Scans the path pattern:
/// `{project_root}/_build/*/lib/*/priv/native/*.so`
///
/// A host-compiled NIF `.so` links against the host glibc ABI.  If a
/// container volume-mounts the project root containing `_build`, the
/// container BEAM may attempt to load those NIFs against a musl libc,
/// producing the `ld-linux-x86-64.so.2` not found error (FMEA RPN 225:
/// GlibcMuslConflict).
fn check_nif_contamination(project_root: &Path) -> SubstrateCheck {
    let name = "nif_so_contamination".to_string();
    let build_dir = project_root.join("_build");

    if !build_dir.exists() {
        return SubstrateCheck {
            name,
            passed: true,
            detail: "No _build directory — no NIF contamination possible".to_string(),
        };
    }

    let found = find_nif_so_files(&build_dir);

    if found.is_empty() {
        SubstrateCheck {
            name,
            passed: true,
            detail: "No host-compiled NIF .so files found in _build".to_string(),
        }
    } else {
        let paths: Vec<String> = found
            .iter()
            .map(|p| p.display().to_string())
            .collect();
        SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "{} host-compiled NIF .so file(s) found under _build/*/lib/*/priv/native/. \
                 These will cause glibc/musl conflict inside the container (FMEA RPN 225). \
                 Run: rm -rf _build. Paths: {}",
                found.len(),
                paths.join(", ")
            ),
        }
    }
}

/// Check volume mount configuration for shadowing issues.
///
/// Axiom 0.2: Volume mounts SHALL NOT shadow directories containing
/// image-baked configuration files unless the volume is pre-seeded with
/// canonical state.
///
/// Reads `{project_root}/podman-compose.yml` and looks for bind-mount
/// entries (`type: bind`) or short-form host-path mounts (`./...:/etc/...`)
/// that target canonical directories (`/etc`, `/app/config`, `/app/_build`,
/// `/app/deps`).  If any such mount is present the check warns the
/// operator — it is a WARNING rather than a hard failure because the
/// compose file may have been intentionally seeded.
fn check_volume_shadows(project_root: &Path) -> SubstrateCheck {
    let name = "volume_shadow_risk".to_string();

    // Try podman-compose.yml first, then compose.yml, then docker-compose.yml.
    let compose_candidates = [
        project_root.join("podman-compose.yml"),
        project_root.join("compose.yml"),
        project_root.join("docker-compose.yml"),
    ];

    let compose_path = match compose_candidates.iter().find(|p| p.exists()) {
        Some(p) => p.clone(),
        None => {
            return SubstrateCheck {
                name,
                passed: true,
                detail: "No compose file found — no volume shadow risk to assess".to_string(),
            }
        }
    };

    let content = match fs::read_to_string(&compose_path) {
        Ok(c) => c,
        Err(e) => {
            return SubstrateCheck {
                name,
                passed: true, // Cannot read → cannot assess → do not block boot
                detail: format!(
                    "Could not read {} ({}); skipping volume shadow check",
                    compose_path.display(),
                    e
                ),
            }
        }
    };

    // Shadowing patterns that indicate a dangerous volume mount.
    // We look for lines mounting the project root's _build or deps into the
    // container, or mounting onto image-baked config dirs under /etc.
    let dangerous_patterns: &[&str] = &[
        ":/_build",
        ":/deps",
        ":/app/_build",
        ":/app/deps",
        ":/etc/",
        "- ./_build:",
        "- ./deps:",
        "source: ./_build",
        "source: ./deps",
    ];

    let mut flagged_lines: Vec<String> = Vec::new();
    for (line_no, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        for pattern in dangerous_patterns {
            if trimmed.contains(pattern) {
                flagged_lines.push(format!("  line {}: {}", line_no + 1, trimmed));
                break;
            }
        }
    }

    if flagged_lines.is_empty() {
        SubstrateCheck {
            name,
            passed: true,
            detail: format!(
                "No dangerous volume shadows detected in {}",
                compose_path.display()
            ),
        }
    } else {
        SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Potential Axiom 0.2 violation in {}: {} line(s) mount host \
                 _build/deps or image-baked /etc directories. \
                 Ensure volumes are pre-seeded with canonical state:\n{}",
                compose_path.display(),
                flagged_lines.len(),
                flagged_lines.join("\n")
            ),
        }
    }
}

/// Check that `SKIP_ZENOH_NIF` environment variable is set to `"0"` or
/// is absent entirely.
///
/// SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes.
///
/// If `SKIP_ZENOH_NIF=1` is set in the calling environment the Zenoh
/// native integration is disabled, violating SC-ZENOH-001.  The check
/// passes when the variable is absent (Zenoh is enabled by default) or
/// explicitly set to `"0"`.
fn check_zenoh_nif_enabled() -> SubstrateCheck {
    let name = "zenoh_nif_enabled".to_string();

    match std::env::var("SKIP_ZENOH_NIF") {
        Err(_) => {
            // Variable not set — Zenoh NIF will be loaded (correct).
            SubstrateCheck {
                name,
                passed: true,
                detail: "SKIP_ZENOH_NIF is unset — Zenoh NIF will be loaded (SC-ZENOH-001 satisfied)".to_string(),
            }
        }
        Ok(ref val) if val == "0" => SubstrateCheck {
            name,
            passed: true,
            detail: "SKIP_ZENOH_NIF=0 — Zenoh NIF is explicitly enabled (SC-ZENOH-001 satisfied)".to_string(),
        },
        Ok(val) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "SKIP_ZENOH_NIF={} — Zenoh NIF is DISABLED. \
                 SC-ZENOH-001: NIF MUST be loaded on ALL nodes. \
                 Set SKIP_ZENOH_NIF=0 or unset the variable.",
                val
            ),
        },
    }
}

/// Check that the container network exists and has DNS enabled.
///
/// Uses `crate::podman::network_exists` and
/// `crate::podman::network_dns_enabled`.  A missing network means the
/// mesh cannot boot; DNS disabled means container-name resolution fails
/// between services.
///
/// This check is async because it shells out to `podman network inspect`.
pub async fn check_network_integrity(network_name: &str) -> SubstrateCheck {
    let name = "mesh_network_integrity".to_string();

    if !podman::network_exists(network_name).await {
        return SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Mesh network '{}' does not exist. \
                 Create it with: podman network create --dns-enable=true {}",
                network_name, network_name
            ),
        };
    }

    match podman::network_dns_enabled(network_name).await {
        Ok(true) => SubstrateCheck {
            name,
            passed: true,
            detail: format!(
                "Mesh network '{}' exists and DNS is enabled — inter-container resolution OK",
                network_name
            ),
        },
        Ok(false) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Mesh network '{}' exists but DNS is DISABLED. \
                 Container-name resolution will fail. \
                 Recreate with: podman network rm {} && \
                 podman network create --dns-enable=true {}",
                network_name, network_name, network_name
            ),
        },
        Err(e) => SubstrateCheck {
            name,
            passed: false,
            detail: format!(
                "Failed to inspect DNS status of network '{}': {}",
                network_name, e
            ),
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTAMINATION PATH SCANNER
// ═══════════════════════════════════════════════════════════════════════════════

/// Detect all contamination paths — host-compiled artifacts that should be
/// removed before a clean containerised build.
///
/// Returns a `Vec<PathBuf>` of paths that should be deleted.  These are:
/// - `{project_root}/_build` (if it has compiled artifacts)
/// - `{project_root}/deps`   (if it is non-empty)
/// - Each `.so` file found under `_build/*/lib/*/priv/native/`
fn find_contamination_paths(project_root: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();

    let build_dir = project_root.join("_build");
    if build_dir.exists() {
        match has_compiled_artifacts(&build_dir) {
            Ok(true) => paths.push(build_dir.clone()),
            _ => {}
        }
        // Also collect individual NIF .so files for precise reporting.
        for so_path in find_nif_so_files(&build_dir) {
            paths.push(so_path);
        }
    }

    let deps_dir = project_root.join("deps");
    if deps_dir.exists() {
        match count_subdirectories(&deps_dir) {
            Ok(n) if n > 0 => paths.push(deps_dir),
            _ => {}
        }
    }

    paths
}

/// Generate remediation commands for contamination.
///
/// Returns shell commands the operator should run to clean the host
/// substrate before retrying the ignition sequence.
///
/// SC-IGNITE-003: Rollback capability — must be able to advise recovery.
pub fn remediation_commands(report: &SubstrateReport) -> Vec<String> {
    let mut cmds: Vec<String> = Vec::new();

    if report.host_build_detected || report.host_deps_detected {
        // Preferred: remove both at once (Axiom 0.1 rollback from CLAUDE.md).
        cmds.push("rm -rf _build deps".to_string());
    } else if report.host_build_detected {
        cmds.push("rm -rf _build".to_string());
    } else if report.host_deps_detected {
        cmds.push("rm -rf deps".to_string());
    }

    // If specific NIF .so files were found but _build was otherwise clean,
    // emit targeted removal commands.
    let nif_paths: Vec<&PathBuf> = report
        .contamination_paths
        .iter()
        .filter(|p| {
            p.extension().map(|ext| ext == "so").unwrap_or(false)
        })
        .collect();

    for nif_path in &nif_paths {
        // Only emit a targeted command if we did NOT already advise
        // removing the entire _build tree.
        if !report.host_build_detected {
            cmds.push(format!("rm -f {}", nif_path.display()));
        }
    }

    // If a volume shadow risk was detected, advise regenerating the compose
    // file or pre-seeding the volume.
    let volume_shadow_failed = report
        .checks
        .iter()
        .any(|c| c.name == "volume_shadow_risk" && !c.passed);

    if volume_shadow_failed {
        cmds.push(
            "# Review podman-compose.yml volume mounts — \
             ensure _build and deps are not bind-mounted into containers"
                .to_string(),
        );
        cmds.push(
            "# If intentional, pre-seed the volume with container-compiled artifacts \
             (not host-compiled). Axiom 0.2."
                .to_string(),
        );
    }

    // Zenoh NIF disabled.
    let zenoh_failed = report
        .checks
        .iter()
        .any(|c| c.name == "zenoh_nif_enabled" && !c.passed);

    if zenoh_failed {
        cmds.push("unset SKIP_ZENOH_NIF  # or: export SKIP_ZENOH_NIF=0".to_string());
    }

    // Network missing or DNS disabled.
    let net_failed = report
        .checks
        .iter()
        .any(|c| c.name == "mesh_network_integrity" && !c.passed);

    if net_failed {
        let net = MESH_NETWORK;
        cmds.push(format!(
            "podman network rm {net} 2>/dev/null; \
             podman network create --dns-enable=true {net}",
            net = net
        ));
    }

    if cmds.is_empty() {
        cmds.push("# No remediation required — substrate is clean".to_string());
    }

    cmds
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Return `true` if `dir` contains at least one `.beam` or `.so` file
/// within any of its immediate subdirectories (i.e. the env-profile dirs
/// like `_build/dev` or `_build/test`).
///
/// We walk only two levels deep to keep the check fast:
///   `_build/` → `dev/` / `test/` / `prod/` → scan for `.beam` / `.so`
fn has_compiled_artifacts(dir: &Path) -> Result<bool, std::io::Error> {
    // Elixir build layout: _build/{profile}/lib/{app}/ebin/*.beam
    // We need to scan up to 4 levels deep to catch .beam and .so files.
    // Level 1: profile directories (dev, test, prod, …)
    for profile_entry in fs::read_dir(dir)? {
        let profile_entry = profile_entry?;
        if !profile_entry.file_type()?.is_dir() {
            continue;
        }
        // Level 2: immediate children of the profile dir (_build/dev/*)
        let profile_path = profile_entry.path();
        if contains_beam_or_so(&profile_path).unwrap_or(false) {
            return Ok(true);
        }
        // Level 3: e.g. _build/dev/lib/*
        if let Ok(l3_entries) = fs::read_dir(&profile_path) {
            for l3_entry in l3_entries.flatten() {
                if !l3_entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                    continue;
                }
                let l3_path = l3_entry.path();
                if contains_beam_or_so(&l3_path).unwrap_or(false) {
                    return Ok(true);
                }
                // Level 4: e.g. _build/dev/lib/app/* (where .beam files live)
                if let Ok(l4_entries) = fs::read_dir(&l3_path) {
                    for l4_entry in l4_entries.flatten() {
                        if !l4_entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                            // Check files at this level too
                            if let Some(ext) = l4_entry.path().extension() {
                                if ext == "beam" || ext == "so" {
                                    return Ok(true);
                                }
                            }
                            continue;
                        }
                        if contains_beam_or_so(&l4_entry.path()).unwrap_or(false) {
                            return Ok(true);
                        }
                    }
                }
            }
        }
    }
    Ok(false)
}

/// Scan a single directory (non-recursive) for `.beam` or `.so` files.
fn contains_beam_or_so(dir: &Path) -> Result<bool, std::io::Error> {
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        if let Some(ext) = entry.path().extension() {
            if ext == "beam" || ext == "so" {
                return Ok(true);
            }
        }
    }
    Ok(false)
}

/// Count the number of direct subdirectories in `dir`.
fn count_subdirectories(dir: &Path) -> Result<usize, std::io::Error> {
    let count = fs::read_dir(dir)?
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_dir()).unwrap_or(false))
        .count();
    Ok(count)
}

/// Recursively find NIF `.so` files under `_build/*/lib/*/priv/native/`.
///
/// The traversal is strictly bounded:
///   _build/
///     {profile}/                     ← depth 1
///       lib/                         ← depth 2
///         {app_name}/                ← depth 3
///           priv/                    ← depth 4
///             native/                ← depth 5
///               *.so                 ← files we want
///
/// We do not use a general recursive walk to avoid scanning the entire
/// project tree on large monorepos.
fn find_nif_so_files(build_dir: &Path) -> Vec<PathBuf> {
    let mut results = Vec::new();

    // depth 1: profile
    let profile_entries = match fs::read_dir(build_dir) {
        Ok(e) => e,
        Err(_) => return results,
    };

    for profile in profile_entries.flatten() {
        if !profile.file_type().map(|t| t.is_dir()).unwrap_or(false) {
            continue;
        }
        // depth 2: lib/
        let lib_dir = profile.path().join("lib");
        if !lib_dir.is_dir() {
            continue;
        }
        // depth 3: {app_name}/
        let app_entries = match fs::read_dir(&lib_dir) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for app in app_entries.flatten() {
            if !app.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                continue;
            }
            // depth 4+5: priv/native/
            let native_dir = app.path().join("priv").join("native");
            if !native_dir.is_dir() {
                continue;
            }
            // collect .so files
            let native_entries = match fs::read_dir(&native_dir) {
                Ok(e) => e,
                Err(_) => continue,
            };
            for so_file in native_entries.flatten() {
                let path = so_file.path();
                if path.extension().map(|ext| ext == "so").unwrap_or(false) {
                    debug!("[SubstrateGuard] NIF .so found: {}", path.display());
                    results.push(path);
                }
            }
        }
    }

    results
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn make_temp_dir() -> TempDir {
        tempfile::tempdir().expect("tempdir")
    }

    // ── check_zenoh_nif_enabled ──────────────────────────────────────────────

    #[test]
    fn zenoh_nif_passes_when_unset() {
        // Remove the var for the duration of this test.
        std::env::remove_var("SKIP_ZENOH_NIF");
        let check = check_zenoh_nif_enabled();
        assert!(check.passed, "unset should pass: {}", check.detail);
    }

    #[test]
    fn zenoh_nif_passes_when_zero() {
        std::env::set_var("SKIP_ZENOH_NIF", "0");
        let check = check_zenoh_nif_enabled();
        std::env::remove_var("SKIP_ZENOH_NIF");
        assert!(check.passed, "=0 should pass: {}", check.detail);
    }

    #[test]
    fn zenoh_nif_fails_when_one() {
        std::env::set_var("SKIP_ZENOH_NIF", "1");
        let check = check_zenoh_nif_enabled();
        std::env::remove_var("SKIP_ZENOH_NIF");
        assert!(!check.passed, "=1 should fail: {}", check.detail);
        assert!(check.detail.contains("DISABLED"));
    }

    // ── check_host_build ────────────────────────────────────────────────────

    #[test]
    fn build_check_passes_when_no_dir() {
        let tmp = make_temp_dir();
        let check = check_host_build(tmp.path());
        assert!(check.passed, "no _build should pass: {}", check.detail);
    }

    #[test]
    fn build_check_passes_when_empty_dir() {
        let tmp = make_temp_dir();
        fs::create_dir(tmp.path().join("_build")).unwrap();
        let check = check_host_build(tmp.path());
        assert!(check.passed, "empty _build should pass: {}", check.detail);
    }

    #[test]
    fn build_check_fails_when_beam_present() {
        let tmp = make_temp_dir();
        let dev = tmp.path().join("_build").join("dev").join("lib").join("app");
        fs::create_dir_all(&dev).unwrap();
        fs::write(dev.join("module.beam"), b"FOR1").unwrap();
        let check = check_host_build(tmp.path());
        assert!(!check.passed, "should fail with .beam present: {}", check.detail);
        assert!(check.detail.contains("compiled artifacts"));
    }

    // ── check_host_deps ─────────────────────────────────────────────────────

    #[test]
    fn deps_check_passes_when_no_dir() {
        let tmp = make_temp_dir();
        let check = check_host_deps(tmp.path());
        assert!(check.passed, "no deps should pass: {}", check.detail);
    }

    #[test]
    fn deps_check_passes_when_empty_dir() {
        let tmp = make_temp_dir();
        fs::create_dir(tmp.path().join("deps")).unwrap();
        let check = check_host_deps(tmp.path());
        assert!(check.passed, "empty deps should pass: {}", check.detail);
    }

    #[test]
    fn deps_check_fails_when_subdirs_present() {
        let tmp = make_temp_dir();
        let phoenix = tmp.path().join("deps").join("phoenix");
        fs::create_dir_all(&phoenix).unwrap();
        let check = check_host_deps(tmp.path());
        assert!(!check.passed, "should fail with subdirs: {}", check.detail);
        assert!(check.detail.contains("dependency packages"));
    }

    // ── check_nif_contamination ─────────────────────────────────────────────

    #[test]
    fn nif_check_passes_when_no_build_dir() {
        let tmp = make_temp_dir();
        let check = check_nif_contamination(tmp.path());
        assert!(check.passed, "no _build should pass: {}", check.detail);
    }

    #[test]
    fn nif_check_passes_when_no_so_files() {
        let tmp = make_temp_dir();
        let native = tmp
            .path()
            .join("_build")
            .join("dev")
            .join("lib")
            .join("zenoh_nif")
            .join("priv")
            .join("native");
        fs::create_dir_all(&native).unwrap();
        // Write a .beam instead of .so — should not trigger the check.
        fs::write(native.join("dummy.beam"), b"").unwrap();
        let check = check_nif_contamination(tmp.path());
        assert!(check.passed, "no .so should pass: {}", check.detail);
    }

    #[test]
    fn nif_check_fails_when_so_present() {
        let tmp = make_temp_dir();
        let native = tmp
            .path()
            .join("_build")
            .join("dev")
            .join("lib")
            .join("zenoh_nif")
            .join("priv")
            .join("native");
        fs::create_dir_all(&native).unwrap();
        fs::write(native.join("libzenoh_nif.so"), b"\x7fELF").unwrap();
        let check = check_nif_contamination(tmp.path());
        assert!(!check.passed, "should fail with .so present: {}", check.detail);
        assert!(check.detail.contains("glibc/musl conflict"));
    }

    // ── check_volume_shadows ────────────────────────────────────────────────

    #[test]
    fn volume_check_passes_when_no_compose_file() {
        let tmp = make_temp_dir();
        let check = check_volume_shadows(tmp.path());
        assert!(check.passed, "no compose should pass: {}", check.detail);
    }

    #[test]
    fn volume_check_passes_with_safe_compose() {
        let tmp = make_temp_dir();
        let compose = tmp.path().join("podman-compose.yml");
        fs::write(
            &compose,
            b"services:\n  app:\n    image: myapp:latest\n    volumes:\n      - data:/data\n",
        )
        .unwrap();
        let check = check_volume_shadows(tmp.path());
        assert!(check.passed, "safe compose should pass: {}", check.detail);
    }

    #[test]
    fn volume_check_fails_with_build_mount() {
        let tmp = make_temp_dir();
        let compose = tmp.path().join("podman-compose.yml");
        fs::write(
            &compose,
            b"services:\n  app:\n    volumes:\n      - ./_build:/app/_build\n",
        )
        .unwrap();
        let check = check_volume_shadows(tmp.path());
        assert!(!check.passed, "build mount should fail: {}", check.detail);
        assert!(check.detail.contains("Axiom 0.2"));
    }

    // ── find_contamination_paths ─────────────────────────────────────────────

    #[test]
    fn contamination_paths_empty_when_clean() {
        let tmp = make_temp_dir();
        let paths = find_contamination_paths(tmp.path());
        assert!(paths.is_empty(), "clean tree should have no paths: {:?}", paths);
    }

    #[test]
    fn contamination_paths_includes_build_and_deps_when_dirty() {
        let tmp = make_temp_dir();

        // Create _build with a .beam file.
        let dev = tmp.path().join("_build").join("dev").join("lib").join("app");
        fs::create_dir_all(&dev).unwrap();
        fs::write(dev.join("module.beam"), b"FOR1").unwrap();

        // Create deps with a subdirectory.
        let phoenix = tmp.path().join("deps").join("phoenix");
        fs::create_dir_all(&phoenix).unwrap();

        let paths = find_contamination_paths(tmp.path());
        let path_strings: Vec<String> = paths
            .iter()
            .map(|p| p.to_string_lossy().to_string())
            .collect();

        assert!(
            path_strings.iter().any(|s| s.contains("_build")),
            "_build should be in contamination paths: {:?}",
            path_strings
        );
        assert!(
            path_strings.iter().any(|s| s.contains("deps")),
            "deps should be in contamination paths: {:?}",
            path_strings
        );
    }

    // ── remediation_commands ─────────────────────────────────────────────────

    #[test]
    fn remediation_no_commands_when_clean() {
        let report = SubstrateReport {
            checks: vec![],
            all_passed: true,
            host_build_detected: false,
            host_deps_detected: false,
            contamination_paths: vec![],
        };
        let cmds = remediation_commands(&report);
        assert_eq!(cmds.len(), 1);
        assert!(cmds[0].contains("No remediation required"), "{:?}", cmds);
    }

    #[test]
    fn remediation_suggests_rm_rf_build_deps_when_both_dirty() {
        let report = SubstrateReport {
            checks: vec![
                SubstrateCheck {
                    name: "host_build_contamination".into(),
                    passed: false,
                    detail: "dirty".into(),
                },
                SubstrateCheck {
                    name: "host_deps_contamination".into(),
                    passed: false,
                    detail: "dirty".into(),
                },
            ],
            all_passed: false,
            host_build_detected: true,
            host_deps_detected: true,
            contamination_paths: vec![],
        };
        let cmds = remediation_commands(&report);
        assert!(
            cmds.iter().any(|c| c == "rm -rf _build deps"),
            "expected rm -rf _build deps: {:?}",
            cmds
        );
    }

    #[test]
    fn remediation_suggests_unset_skip_zenoh_when_set() {
        let report = SubstrateReport {
            checks: vec![SubstrateCheck {
                name: "zenoh_nif_enabled".into(),
                passed: false,
                detail: "SKIP_ZENOH_NIF=1".into(),
            }],
            all_passed: false,
            host_build_detected: false,
            host_deps_detected: false,
            contamination_paths: vec![],
        };
        let cmds = remediation_commands(&report);
        assert!(
            cmds.iter().any(|c| c.contains("SKIP_ZENOH_NIF")),
            "expected unset SKIP_ZENOH_NIF: {:?}",
            cmds
        );
    }
}
