//! # Launch Module — Container Creation & Ignition
//!
//! ## Fractal Position: L4-System / Container Launch
//! ## Source: PanopticIgnition.fs:722-981, journal §3.6
//! ## STAMP: SC-IGNITE-006, SC-BOOT-004, SC-BOOT-006

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::*;
use ed25519_dalek::{Signer, SigningKey, Verifier, VerifyingKey};
use log::{debug, error, info, warn};
use rand_core::OsRng;
use std::time::Duration;
use tokio::fs::OpenOptions;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};

/// Task 8.5: ProofToken Environment Injection (Rank 9)
/// Generates a transient ed25519 keypair and a signed ProofToken.
pub fn generate_proof_token() -> (String, String) {
    let mut csprng = OsRng;
    let signing_key: SigningKey = SigningKey::generate(&mut csprng);
    let verifying_key: VerifyingKey = signing_key.verifying_key();

    let timestamp = chrono::Utc::now().to_rfc3339();
    let nonce = uuid::Uuid::new_v4().to_string();
    let message = format!("{}:{}", timestamp, nonce);

    let signature = signing_key.sign(message.as_bytes());
    let token = format!(
        "{}:{}:{}",
        timestamp,
        nonce,
        hex::encode(signature.to_bytes())
    );
    let pubkey = hex::encode(verifying_key.to_bytes());

    (token, pubkey)
}

/// Generate SECRET_KEY_BASE (64 random hex bytes).
pub fn generate_secret_key() -> String {
    (0..64)
        .map(|_| format!("{:02x}", rand::random::<u8>()))
        .collect()
}

/// Build the CMD chain for the app container.
pub fn build_app_cmd() -> String {
    r#"LC_ALL=C redis-server --daemonize yes --protected-mode no --save "" --appendonly no --dir /tmp --port 6379 2>/dev/null || echo "WARN: redis"; mkdir -p data/tmp data/state; mix ecto.migrate 2>/dev/null; exec mix phx.server"#.to_string()
}

/// Build the CMD chain for the test app container.
pub fn build_test_cmd(test_args: &str) -> String {
    format!(
        r#"LC_ALL=C redis-server --daemonize yes --protected-mode no --save "" --appendonly no --dir /tmp --port 6379 2>/dev/null || echo "WARN: redis"; mkdir -p data/tmp data/state; mix ecto.create 2>/dev/null; mix ecto.migrate 2>/dev/null; exec mix test {}"#,
        test_args
    )
}

/// Task 8.3: DAG-based Dependency Resolution (Rank 7)
pub fn build_dependency_graph() -> crate::dag::DependencyGraph {
    if let Ok(dg) = crate::dag::DependencyGraph::load_from_file("config/dag.toml") {
        return dg;
    }

    warn!("Failed to load config/dag.toml, using default graph");

    let mut dg = crate::dag::DependencyGraph::new();

    // Tier 0: Mesh Backplane
    dg.add_container("zenoh-router-1");
    dg.add_container("zenoh-router-2");
    dg.add_container("zenoh-router-3");

    // Tier 1: Foundation (Database & Observability)
    dg.add_dependency("indrajaal-db-prod", "zenoh-router-1");
    dg.add_dependency("indrajaal-db-prod", "zenoh-router-2");
    dg.add_dependency("indrajaal-db-prod", "zenoh-router-3");

    dg.add_dependency("indrajaal-obs-prod", "zenoh-router-1");

    // Tier 2: Cognitive (Cortex)
    dg.add_dependency("indrajaal-cortex", "indrajaal-db-prod");

    // Tier 3: Application Seed
    dg.add_dependency("indrajaal-ex-app-1", "indrajaal-db-prod");
    dg.add_dependency("indrajaal-ex-app-1", "indrajaal-obs-prod");
    dg.add_dependency("indrajaal-ex-app-1", "indrajaal-cortex");

    // Tier 4: Bridge
    dg.add_dependency("cepaf-bridge", "indrajaal-ex-app-1");

    // Tier 5: HA Replicas + Digital Twin (depend on app-1 + db)
    dg.add_dependency("indrajaal-ex-app-2", "indrajaal-ex-app-1");
    dg.add_dependency("indrajaal-ex-app-3", "indrajaal-ex-app-1");
    dg.add_dependency("indrajaal-chaya", "indrajaal-ex-app-1");

    // Tier 6: AI/ML Compute (depend on zenoh mesh)
    dg.add_dependency("indrajaal-ollama", "zenoh-router-1");
    dg.add_dependency("indrajaal-mojo", "zenoh-router-1");

    // Tier 7: ML Runners (depend on ollama)
    dg.add_dependency("indrajaal-ml-runner-1", "indrajaal-ollama");
    dg.add_dependency("indrajaal-ml-runner-2", "indrajaal-ollama");

    dg
}

/// Task 8.1: Robust I/O Capture (Rank 3)
/// Monitors both stdout and stderr, logging to file and tui-logger.
async fn monitor_streams(container_name: String, mut child: tokio::process::Child) {
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let name = container_name.clone();

    tokio::spawn(async move {
        let _ = tokio::fs::create_dir_all("data/logs").await;
        let mut log_file = match OpenOptions::new()
            .create(true)
            .append(true)
            .open("data/logs/ignition_capture.log")
            .await
        {
            Ok(f) => f,
            Err(e) => {
                error!("Failed to open ignition_capture.log: {}", e);
                return;
            }
        };

        let mut stdout_lines = stdout.map(|s| BufReader::new(s).lines());
        let mut stderr_lines = stderr.map(|s| BufReader::new(s).lines());

        loop {
            tokio::select! {
                Some(line) = async {
                    if let Some(ref mut reader) = stdout_lines {
                        reader.next_line().await.ok().flatten()
                    } else {
                        None
                    }
                } => {
                    let log_line = format!("[{}] (STDOUT) {}\n", name, line);
                    let _ = log_file.write_all(log_line.as_bytes()).await;
                    info!("[{}] {}", name, line);
                }
                Some(line) = async {
                    if let Some(ref mut reader) = stderr_lines {
                        reader.next_line().await.ok().flatten()
                    } else {
                        None
                    }
                } => {
                    let log_line = format!("[{}] (STDERR) {}\n", name, line);
                    let _ = log_file.write_all(log_line.as_bytes()).await;
                    info!("[{}] {}", name, line);
                }
                else => break,
            }
        }
    });
}

/// Specialized launch for application container with ProofToken.
pub async fn launch_app(proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    let secret_key = generate_secret_key();
    let cmd = build_app_cmd();
    let image = "localhost/indrajaal-ex-app-1:latest";
    let name = "indrajaal-ex-app-1";

    info!("  [Launch] Starting {} with ProofToken...", name);

    // Robustness Rank 4: Verify Image
    let digest = podman::verify_image(image).await?;
    info!("  [Verify] Image {} verified: {}", image, digest);

    // Pre-provision directories
    let _ = std::fs::create_dir_all("data/tmp");
    let _ = std::fs::create_dir_all("data/state");

    // Stale lockfile purge
    let _ = std::fs::remove_file("data/tmp/redis.pid");
    let _ = std::fs::remove_file("data/state/app.lock");

    // Remove stale container
    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let mut args: Vec<String> = vec![
        "run".into(),
        "-d".into(),
        "--name".into(),
        name.into(),
        "--hostname".into(),
        name.into(),
        "--network".into(),
        MESH_NETWORK.into(),
        "--ip".into(),
        "172.28.0.10".into(),
        "--memory".into(),
        APP_MEMORY_LIMIT.into(),
        "--memory-swap".into(),
        APP_MEMORY_SWAP.into(),
        "-p".into(),
        "4000:4000".into(),
        "-p".into(),
        "4001:4001".into(),
    ];

    for (key, val) in app_env_vars(&secret_key, proof_token, proof_pubkey) {
        args.push("--env".into());
        args.push(format!("{}={}", key, val));
    }

    args.push("-v".into());
    args.push("/home/an/dev/ver/intelitor-v5.2/priv/native:/workspace/priv/native:Z".into());
    args.push(image.into());
    args.push("sh".into());
    args.push("-c".into());
    args.push(cmd);

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_streams(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Launch Elixir HA replica using the SAME env, CMD, and image as ex-app-1.
/// Reuses app_env_vars() and build_app_cmd() for consistent configuration.
pub async fn launch_elixir_replica(
    name: &str,
    proof_token: &str,
    proof_pubkey: &str,
) -> Result<String, IgnitionError> {
    let secret_key = generate_secret_key();
    let cmd = build_app_cmd();
    let image = "localhost/indrajaal-ex-app-1:latest";

    info!("  [Launch] Starting Elixir replica {} (same config as ex-app-1)...", name);

    // Robustness Rank 4: Verify Image
    let digest = podman::verify_image(image).await?;
    info!("  [Verify] Image {} verified: {}", image, digest);

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let port = match name {
        "indrajaal-chaya" => "4002",
        "indrajaal-ex-app-2" => "4003",
        "indrajaal-ex-app-3" => "4004",
        _ => "4000",
    };

    let mut args: Vec<String> = vec![
        "run".into(),
        "-d".into(),
        "--name".into(),
        name.into(),
        "--hostname".into(),
        name.into(),
        "--network".into(),
        MESH_NETWORK.into(),
        "--memory".into(),
        APP_MEMORY_LIMIT.into(),
        "--memory-swap".into(),
        APP_MEMORY_SWAP.into(),
    ];

    // Same env vars as ex-app-1, with overridden PHX_HOST and PORT
    for (key, val) in app_env_vars(&secret_key, proof_token, proof_pubkey) {
        args.push("--env".into());
        if key == "PORT" {
            args.push(format!("PORT={}", port));
        } else if key == "PHX_HOST" {
            args.push(format!("PHX_HOST={}", name));
        } else {
            args.push(format!("{}={}", key, val));
        }
    }

    args.push("-v".into());
    args.push("/home/an/dev/ver/intelitor-v5.2/priv/native:/workspace/priv/native:Z".into());
    args.push(image.into());
    args.push("sh".into());
    args.push("-c".into());
    args.push(cmd);

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_streams(name.to_string(), child).await;

    info!("  ✅ {} launched (replica of ex-app-1, port {})", name, port);
    Ok(name.to_string())
}

/// Specialized launch for test application container.
pub async fn launch_test_app(test_args: &str) -> Result<String, IgnitionError> {
    let secret_key = generate_secret_key();
    let (proof_token, proof_pubkey) = generate_proof_token();
    let cmd = build_test_cmd(test_args);
    let image = "localhost/indrajaal-ex-app-1:latest";
    let name = TEST_CONTAINER_NAME;

    info!("  [Launch] Starting {} (TEST) with ProofToken...", name);

    // Robustness Rank 4: Verify Image
    let digest = podman::verify_image(image).await?;
    info!("  [Verify] Image {} verified: {}", image, digest);

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let mut args: Vec<String> = vec![
        "run".into(),
        "-d".into(),
        "--name".into(),
        name.into(),
        "--hostname".into(),
        name.into(),
        "--network".into(),
        MESH_NETWORK.into(),
        "--ip".into(),
        TEST_CONTAINER_IP.into(),
        "--memory".into(),
        APP_MEMORY_LIMIT.into(),
        "--memory-swap".into(),
        APP_MEMORY_SWAP.into(),
        "-p".into(),
        format!("{}:{}", TEST_PHOENIX_PORT, TEST_PHOENIX_PORT),
        "-p".into(),
        format!("{}:{}", TEST_HEALTH_PORT, TEST_HEALTH_PORT),
    ];

    for (key, val) in test_env_vars(&secret_key, &proof_token, &proof_pubkey) {
        args.push("--env".into());
        args.push(format!("{}={}", key, val));
    }

    args.push("-v".into());
    args.push("/home/an/dev/ver/intelitor-v5.2/priv/native:/workspace/priv/native:Z".into());
    args.push(image.into());
    args.push("sh".into());
    args.push("-c".into());
    args.push(cmd);

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_streams(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Specialized launch for cepaf-bridge with ProofToken.
pub async fn launch_bridge(proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    let name = "cepaf-bridge";
    let image = "localhost/cepaf-bridge:latest";
    let uid = get_current_uid();
    let socket_host = format!("/run/user/{}/podman/podman.sock", uid);

    info!("  [Launch] Starting {} with ProofToken...", name);

    // Robustness Rank 4: Verify Image
    let digest = podman::verify_image(image).await?;
    info!("  [Verify] Image {} verified: {}", image, digest);

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let socket_mount = format!("{}:{}:z", socket_host, BRIDGE_SOCKET_CONTAINER);

    let args = vec![
        "run".into(),
        "-d".into(),
        "-i".into(),
        "--name".into(),
        name.into(),
        "--hostname".into(),
        name.into(),
        "--network".into(),
        MESH_NETWORK.into(),
        "-p".into(),
        "9876:9876".into(),
        "--env".into(),
        format!("CEPAF_BRIDGE_PORT={}", BRIDGE_PORT),
        "--env".into(),
        "CEPAF_BRIDGE_HOST=0.0.0.0".into(),
        "--env".into(),
        format!("ZENOH_ROUTER_ENDPOINT=tcp://zenoh-router-1:{}", ZENOH_PORT),
        "--env".into(),
        format!("PODMAN_SOCKET={}", BRIDGE_SOCKET_CONTAINER),
        "--env".into(),
        "UID=0".into(),
        "--env".into(),
        "DOTNET_ENVIRONMENT=Production".into(),
        "--env".into(),
        format!("C3I_PROOF_TOKEN={}", proof_token),
        "--env".into(),
        format!("C3I_PROOF_PUBKEY={}", proof_pubkey),
        "-v".into(),
        socket_mount,
        image.into(),
    ];

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_streams(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Generic container launch for Zenoh, DB, OBS, Cortex.
pub async fn launch_generic(
    name: &str,
    proof_token: &str,
    proof_pubkey: &str,
) -> Result<String, IgnitionError> {
    // Elixir app containers use the full launch_app() path with proper env/CMD
    if name == "indrajaal-ex-app-1" {
        return launch_app(proof_token, proof_pubkey).await;
    }
    if matches!(name, "indrajaal-ex-app-2" | "indrajaal-ex-app-3" | "indrajaal-chaya") {
        return launch_elixir_replica(name, proof_token, proof_pubkey).await;
    }

    info!("  [Launch] Starting {} with ProofToken...", name);

    let image = match name {
        n if n.starts_with("zenoh") => "localhost/zenoh-router:latest",
        "indrajaal-db-prod" => "localhost/indrajaal-db-prod:latest",
        "indrajaal-obs-prod" => "localhost/indrajaal-obs-prod:latest",
        "indrajaal-cortex" => "localhost/indrajaal-cortex:latest",
        "cepaf-bridge" => "localhost/cepaf-bridge:latest",
        "indrajaal-ex-app-2" | "indrajaal-ex-app-3" | "indrajaal-chaya" => "localhost/indrajaal-ex-app-1:latest",
        "indrajaal-ollama" | "indrajaal-ml-runner-1" | "indrajaal-ml-runner-2" => "localhost/indrajaal-ollama:latest",
        "indrajaal-mojo" => "localhost/indrajaal-mojo:latest",
        _ => "docker.io/library/alpine:3.21",
    };

    // Robustness Rank 4: Verify Image
    let digest = podman::verify_image(image).await?;
    info!("  [Verify] Image {} verified: {}", image, digest);

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let mut args = vec![
        "run".into(),
        "-d".into(),
        "--name".into(),
        name.into(),
        "--hostname".into(),
        name.into(),
        "--network".into(),
        MESH_NETWORK.into(),
        "--env".into(),
        format!("C3I_PROOF_TOKEN={}", proof_token),
        "--env".into(),
        format!("C3I_PROOF_PUBKEY={}", proof_pubkey),
    ];

    if name == "indrajaal-db-prod" {
        args.push("--env".into());
        args.push("POSTGRES_PASSWORD=postgres".into());
    }

    // Elixir HA replicas need the same env as ex-app-1
    if matches!(name, "indrajaal-ex-app-2" | "indrajaal-ex-app-3" | "indrajaal-chaya") {
        let port = if name == "indrajaal-chaya" { "4002" } else { "4000" };
        for (k, v) in &[
            ("MIX_ENV", "prod"),
            ("DATABASE_URL", "ecto://postgres:postgres@indrajaal-db-prod:5432/indrajaal_prod"),
            ("SECRET_KEY_BASE", &generate_secret_key()),
            ("ZENOH_ENABLED", "true"),
            ("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router-1:7447"),
            ("SKIP_ZENOH_NIF", "0"),
            ("ELIXIR_ERL_OPTIONS", "+fnu +S 4:4 +SDio 4"),
            ("PHX_HOST", name),
            ("PORT", port),
        ] {
            args.push("--env".into());
            args.push(format!("{}={}", k, v));
        }
    }

    args.push(image.into());

    // Elixir replicas need the same CMD as ex-app-1
    if matches!(name, "indrajaal-ex-app-2" | "indrajaal-ex-app-3" | "indrajaal-chaya") {
        args.push("sh".into());
        args.push("-c".into());
        args.push("redis-server --daemonize yes --protected-mode no --save \"\" --appendonly no --dir /tmp --port 6379 2>/dev/null; mkdir -p data/tmp data/state; exec mix phx.server".into());
    }

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_streams(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Launch the core mesh infrastructure using DAG-based dependency resolution.
pub async fn launch_mesh() -> Result<(), IgnitionError> {
    info!("🚀 STARTING AUTHORITATIVE DAG-BASED MESH IGNITION");

    let dg = build_dependency_graph();
    let waves = dg.calculate_waves();
    let (proof_token, proof_pubkey) = generate_proof_token();

    let mut launched_successfully = Vec::new();

    for (i, wave) in waves.iter().enumerate() {
        info!("  [Wave {}] Grouping: {:?}", i, wave);

        let mut wave_handles = Vec::new();
        for container_name in wave {
            let name = container_name.clone();
            let token = proof_token.clone();
            let pubkey = proof_pubkey.clone();

            let handle = tokio::spawn(async move { launch_by_name(&name, &token, &pubkey).await });
            wave_handles.push((container_name.clone(), handle));
        }

        let mut wave_failed = false;
        for (name, handle) in wave_handles {
            match handle.await.unwrap() {
                Ok(_) => {
                    launched_successfully.push(name);
                }
                Err(e) => {
                    error!("  ❌ Wave failure: {} failed: {}", name, e);
                    wave_failed = true;
                }
            }
        }

        // Rule engine: graduated response to tier failures
        let tier_rule = crate::rule_engine::evaluate_launch_tier(wave_failed, wave_failed);
        info!("  Launch rule: {} — {}", tier_rule.decision, tier_rule.reason);

        if wave_failed && tier_rule.decision == "HaltPipeline" {
            error!("  ❌ Ignition transaction failed at Wave {}. Initiating Compensating Transaction...", i);
            let containers_to_rollback: Vec<&str> = launched_successfully
                .iter()
                .map(|s: &String| s.as_str())
                .collect();
            rollback_wave(containers_to_rollback).await;
            return Err(IgnitionError::LaunchFailed(format!("Wave {} failed", i)));
        } else if wave_failed {
            warn!("  ⚠️  Wave {} had non-critical failures — continuing per rule engine", i);
        }
    }

    info!("  ✅ Authoritative SIL-6 Mesh Ignition Complete");
    Ok(())
}

/// Rank 8 Idea: Compensating Transaction (Rollback)
pub async fn rollback_wave(containers: Vec<&str>) {
    warn!(
        "  [Rollback] Reverting state for containers: {:?}",
        containers
    );
    for name in containers {
        // Task 8.3: Stop before remove
        let _ = podman::stop_container(name, 5).await;
        let _ = podman::force_remove(name).await;
    }
    warn!("  [Rollback] System returned to Safe State.");
}

/// Router for container launch logic.
async fn launch_by_name(
    name: &str,
    proof_token: &str,
    proof_pubkey: &str,
) -> Result<String, IgnitionError> {
    match name {
        "indrajaal-ex-app-1" => launch_app(proof_token, proof_pubkey).await,
        "cepaf-bridge" => launch_bridge(proof_token, proof_pubkey).await,
        _ => launch_generic(name, proof_token, proof_pubkey).await,
    }
}

/// App environment variables with ProofToken injection.
pub fn app_env_vars(
    secret_key: &str,
    proof_token: &str,
    proof_pubkey: &str,
) -> Vec<(String, String)> {
    vec![
        ("MIX_ENV".into(), "prod".into()),
        ("SKIP_ZENOH_NIF".into(), "0".into()),
        ("SKIP_LINEAGE_NIF".into(), "1".into()),
        ("RUSTLER_SKIP_COMPILE".into(), "false".into()),
        ("ELIXIR_ERL_OPTIONS".into(), "+fnu +S 16:16 +SDio 16".into()),
        ("PORT".into(), PHOENIX_PORT.to_string()),
        ("PHX_HOST".into(), "localhost".into()),
        ("PHX_PORT".into(), PHOENIX_PORT.to_string()),
        (
            "DATABASE_URL".into(),
            format!(
                "ecto://postgres:postgres@indrajaal-db-prod:{}/indrajaal_prod",
                POSTGRES_INTERNAL_PORT
            ),
        ),
        ("DATABASE_SSL".into(), "false".into()),
        ("POSTGRES_HOST".into(), "indrajaal-db-prod".into()),
        ("POSTGRES_PORT".into(), POSTGRES_INTERNAL_PORT.to_string()),
        ("POSTGRES_DB".into(), "indrajaal_prod".into()),
        ("POSTGRES_USER".into(), "postgres".into()),
        ("POSTGRES_PASSWORD".into(), "postgres".into()),
        ("REDIS_URL".into(), "redis://localhost:6379".into()),
        ("REDIS_HOST".into(), "localhost".into()),
        ("REDIS_PORT".into(), "6379".into()),
        ("REDIS_EMBEDDED".into(), "true".into()),
        ("SECRET_KEY_BASE".into(), secret_key.to_string()),
        ("ZENOH_ENABLED".into(), "true".into()),
        (
            "ZENOH_ROUTER_ENDPOINT".into(),
            format!("tcp/zenoh-router-1:{}", ZENOH_PORT),
        ),
        ("ZENOH_MODE".into(), "client".into()),
        (
            "OTEL_EXPORTER_OTLP_ENDPOINT".into(),
            format!("http://indrajaal-obs-prod:{}", OTEL_GRPC_PORT),
        ),
        ("OTEL_SERVICE_NAME".into(), "indrajaal-ex-app-1".into()),
        ("RELEASE_NODE".into(), "indrajaal@indrajaal-ex-app-1".into()),
        ("RELEASE_COOKIE".into(), "indrajaal_prod_cookie".into()),
        ("PRAJNA_COCKPIT_ENABLED".into(), "true".into()),
        ("PRAJNA_DARK_MODE".into(), "true".into()),
        ("PRAJNA_AI_COPILOT_ENABLED".into(), "true".into()),
        ("QUADPLEX_ZENOH".into(), "true".into()),
        ("CLUSTERING_ENABLED".into(), "true".into()),
        (
            "CEPAF_BRIDGE_URL".into(),
            format!("http://cepaf-bridge:{}", BRIDGE_PORT),
        ),
        (
            "CORTEX_URL".into(),
            format!("http://indrajaal-cortex:{}", CORTEX_PORT),
        ),
        ("TAILSCALE_ENABLED".into(), "false".into()),
        ("PHICS_ENABLED".into(), "true".into()),
        ("NO_TIMEOUT".into(), "true".into()),
        ("PATIENT_MODE".into(), "enabled".into()),
        ("SOPV51_COMPLIANT".into(), "true".into()),
        ("UNIFIED_APP_MODE".into(), "true".into()),
        ("SIL_LEVEL".into(), "6".into()),
        ("FLAME_ENABLED".into(), "true".into()),
        ("FLAME_BACKEND".into(), "local".into()),
        ("LOG_LEVEL".into(), "info".into()),
        ("LANG".into(), "en_US.UTF-8".into()),
        ("LC_ALL".into(), "en_US.UTF-8".into()),
        ("FRACTAL_LOGGING_ENABLED".into(), "true".into()),
        ("C3I_PROOF_TOKEN".into(), proof_token.to_string()),
        ("C3I_PROOF_PUBKEY".into(), proof_pubkey.to_string()),
    ]
}

/// Test environment variables.
pub fn test_env_vars(
    secret_key: &str,
    proof_token: &str,
    proof_pubkey: &str,
) -> Vec<(String, String)> {
    let mut vars = app_env_vars(secret_key, proof_token, proof_pubkey);
    // Override for test
    for (key, val) in &mut vars {
        if key == "MIX_ENV" {
            *val = "test".into();
        }
        if key == "POSTGRES_DB" {
            *val = TEST_DATABASE_NAME.into();
        }
        if key == "DATABASE_URL" {
            *val = format!(
                "ecto://postgres:postgres@indrajaal-db-prod:{}/{}",
                POSTGRES_INTERNAL_PORT, TEST_DATABASE_NAME
            );
        }
    }
    vars.push(("WALLABY_ENABLED".into(), "true".into()));
    vars
}

/// Get current UID.
fn get_current_uid() -> u32 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find(|l| l.starts_with("Uid:"))
                .and_then(|l| l.split_whitespace().nth(1))
                .and_then(|v| v.parse().ok())
        })
        .unwrap_or(1000)
}

// =============================================================================
// Unit Tests — Pure Function Coverage
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // ─── generate_secret_key ───

    #[test]
    fn test_secret_key_is_128_hex_chars() {
        let key = generate_secret_key();
        assert_eq!(
            key.len(),
            128,
            "SECRET_KEY_BASE should be 64 bytes = 128 hex chars"
        );
    }

    #[test]
    fn test_secret_key_is_valid_hex() {
        let key = generate_secret_key();
        assert!(
            key.chars().all(|c| c.is_ascii_hexdigit()),
            "SECRET_KEY_BASE should be hex-only: {}",
            key
        );
    }

    #[test]
    fn test_secret_key_is_unique_per_call() {
        let key1 = generate_secret_key();
        let key2 = generate_secret_key();
        assert_ne!(key1, key2, "Two generated keys should differ (entropy)");
    }

    // ─── generate_proof_token ───

    #[test]
    fn test_proof_token_format() {
        let (token, pubkey) = generate_proof_token();
        // Token format: "{timestamp}:{nonce}:{hex_signature}"
        let parts: Vec<&str> = token.split(':').collect();
        assert!(
            parts.len() >= 3,
            "Token should have at least 3 colon-separated parts"
        );
        // Pubkey is hex-encoded ed25519 public key (32 bytes = 64 hex chars)
        assert_eq!(pubkey.len(), 64, "Ed25519 public key = 64 hex chars");
    }

    #[test]
    fn test_proof_token_pubkey_is_hex() {
        let (_token, pubkey) = generate_proof_token();
        assert!(
            pubkey.chars().all(|c| c.is_ascii_hexdigit()),
            "Public key should be hex: {}",
            pubkey
        );
    }

    #[test]
    fn test_proof_token_verification() {
        let (token, pubkey_hex) = generate_proof_token();
        let parts: Vec<&str> = token.split(':').collect();
        assert_eq!(parts.len(), 3);

        let timestamp = parts[0];
        let nonce = parts[1];
        let sig_hex = parts[2];

        let message = format!("{}:{}", timestamp, nonce);
        let sig_bytes = hex::decode(sig_hex).expect("Signature should be hex");
        let sig = ed25519_dalek::Signature::from_slice(&sig_bytes).expect("Invalid signature bytes");

        let pubkey_bytes = hex::decode(pubkey_hex).expect("Pubkey should be hex");
        let pubkey = VerifyingKey::from_bytes(&pubkey_bytes.try_into().expect("Invalid pubkey length"))
            .expect("Invalid pubkey bytes");

        assert!(
            pubkey.verify(message.as_bytes(), &sig).is_ok(),
            "Signature verification failed"
        );
    }

    // ─── build_app_cmd ───

    #[test]
    fn test_app_cmd_starts_redis() {
        let cmd = build_app_cmd();
        assert!(cmd.contains("redis-server"), "CMD should start Redis");
        assert!(cmd.contains("LC_ALL=C"), "Redis needs LC_ALL=C (F11 fix)");
    }

    #[test]
    fn test_app_cmd_runs_migrations() {
        let cmd = build_app_cmd();
        assert!(cmd.contains("ecto.migrate"), "CMD should run migrations");
    }

    #[test]
    fn test_app_cmd_starts_phoenix_server() {
        let cmd = build_app_cmd();
        assert!(cmd.contains("mix phx.server"), "CMD should start Phoenix");
    }

    #[test]
    fn test_app_cmd_creates_data_dirs() {
        let cmd = build_app_cmd();
        assert!(cmd.contains("mkdir -p data/tmp data/state"));
    }

    // ─── build_test_cmd ───

    #[test]
    fn test_test_cmd_runs_mix_test() {
        let cmd = build_test_cmd("--only wallaby");
        assert!(cmd.contains("mix test --only wallaby"));
    }

    #[test]
    fn test_test_cmd_creates_database() {
        let cmd = build_test_cmd("");
        assert!(
            cmd.contains("ecto.create"),
            "Test CMD should create DB first"
        );
        assert!(cmd.contains("ecto.migrate"), "Test CMD should migrate");
    }

    #[test]
    fn test_test_cmd_starts_redis() {
        let cmd = build_test_cmd("");
        assert!(cmd.contains("redis-server"));
        assert!(cmd.contains("LC_ALL=C"));
    }

    #[test]
    fn test_test_cmd_preserves_args() {
        let cmd = build_test_cmd("test/specific_test.exs --trace");
        assert!(cmd.contains("test/specific_test.exs --trace"));
    }

    // ─── app_env_vars ───

    #[test]
    fn test_app_env_vars_has_required_keys() {
        let vars = app_env_vars("secret", "token", "pubkey");
        let keys: Vec<&str> = vars.iter().map(|(k, _)| k.as_str()).collect();

        let required = [
            "MIX_ENV",
            "SKIP_ZENOH_NIF",
            "ELIXIR_ERL_OPTIONS",
            "PORT",
            "DATABASE_URL",
            "POSTGRES_HOST",
            "POSTGRES_PORT",
            "POSTGRES_DB",
            "SECRET_KEY_BASE",
            "ZENOH_ENABLED",
            "ZENOH_ROUTER_ENDPOINT",
            "OTEL_EXPORTER_OTLP_ENDPOINT",
            "RELEASE_NODE",
            "RELEASE_COOKIE",
            "C3I_PROOF_TOKEN",
            "C3I_PROOF_PUBKEY",
        ];
        for key in &required {
            assert!(keys.contains(key), "Missing required env var: {}", key);
        }
    }

    #[test]
    fn test_app_env_vars_is_prod_mode() {
        let vars = app_env_vars("secret", "token", "pubkey");
        let mix_env = vars.iter().find(|(k, _)| k == "MIX_ENV").unwrap();
        assert_eq!(mix_env.1, "prod");
    }

    #[test]
    fn test_app_env_vars_zenoh_enabled() {
        let vars = app_env_vars("secret", "token", "pubkey");
        let zenoh = vars.iter().find(|(k, _)| k == "ZENOH_ENABLED").unwrap();
        assert_eq!(zenoh.1, "true");
    }

    #[test]
    fn test_app_env_vars_nif_not_skipped() {
        let vars = app_env_vars("secret", "token", "pubkey");
        let nif = vars.iter().find(|(k, _)| k == "SKIP_ZENOH_NIF").unwrap();
        assert_eq!(nif.1, "0", "Zenoh NIF must NOT be skipped (SC-ZENOH-001)");
    }

    #[test]
    fn test_app_env_vars_uses_correct_ports() {
        let vars = app_env_vars("secret", "token", "pubkey");
        let port = vars.iter().find(|(k, _)| k == "PORT").unwrap();
        assert_eq!(port.1, "4000");
        let pg_port = vars.iter().find(|(k, _)| k == "POSTGRES_PORT").unwrap();
        assert_eq!(pg_port.1, "5432"); // internal port inside mesh
    }

    #[test]
    fn test_app_env_vars_injects_proof_token() {
        let vars = app_env_vars("secret", "my_token", "my_pubkey");
        let token = vars.iter().find(|(k, _)| k == "C3I_PROOF_TOKEN").unwrap();
        assert_eq!(token.1, "my_token");
        let pubkey = vars.iter().find(|(k, _)| k == "C3I_PROOF_PUBKEY").unwrap();
        assert_eq!(pubkey.1, "my_pubkey");
    }

    #[test]
    fn test_app_env_vars_injects_secret_key() {
        let vars = app_env_vars("my_secret_abc", "token", "pubkey");
        let sk = vars.iter().find(|(k, _)| k == "SECRET_KEY_BASE").unwrap();
        assert_eq!(sk.1, "my_secret_abc");
    }

    #[test]
    fn test_app_env_vars_has_elixir_erl_options() {
        let vars = app_env_vars("s", "t", "p");
        let opts = vars
            .iter()
            .find(|(k, _)| k == "ELIXIR_ERL_OPTIONS")
            .unwrap();
        assert!(opts.1.contains("+S 16:16"), "Must have +S 16:16 schedulers");
        assert!(opts.1.contains("+SDio 16"), "Must have +SDio 16 dirty IO");
    }

    // ─── test_env_vars ───

    #[test]
    fn test_test_env_vars_overrides_mix_env() {
        let vars = test_env_vars("secret", "token", "pubkey");
        let mix_env = vars.iter().find(|(k, _)| k == "MIX_ENV").unwrap();
        assert_eq!(mix_env.1, "test");
    }

    #[test]
    fn test_test_env_vars_uses_test_database() {
        let vars = test_env_vars("secret", "token", "pubkey");
        let db = vars.iter().find(|(k, _)| k == "POSTGRES_DB").unwrap();
        assert_eq!(db.1, TEST_DATABASE_NAME);
    }

    #[test]
    fn test_test_env_vars_has_wallaby() {
        let vars = test_env_vars("secret", "token", "pubkey");
        let wallaby = vars.iter().find(|(k, _)| k == "WALLABY_ENABLED").unwrap();
        assert_eq!(wallaby.1, "true");
    }

    #[test]
    fn test_test_env_vars_database_url_uses_test_db() {
        let vars = test_env_vars("secret", "token", "pubkey");
        let url = vars.iter().find(|(k, _)| k == "DATABASE_URL").unwrap();
        assert!(
            url.1.contains(TEST_DATABASE_NAME),
            "DATABASE_URL should use test DB"
        );
        assert!(
            !url.1.contains("indrajaal_prod"),
            "DATABASE_URL should NOT use prod DB"
        );
    }

    // ─── build_dependency_graph ───

    #[test]
    fn test_dependency_graph_has_zenoh_roots() {
        let dg = build_dependency_graph();
        let waves = dg.calculate_waves();
        // Wave 0 should contain the zenoh routers (no dependencies)
        assert!(!waves.is_empty());
        let wave0 = &waves[0];
        assert!(
            wave0.contains(&"zenoh-router-1".to_string())
                || wave0.contains(&"zenoh-router-2".to_string())
                || wave0.contains(&"zenoh-router-3".to_string()),
            "Wave 0 should contain zenoh routers: {:?}",
            wave0
        );
    }

    #[test]
    fn test_dependency_graph_app_depends_on_db() {
        let dg = build_dependency_graph();
        let waves = dg.calculate_waves();
        // Find wave containing app and wave containing db
        let app_wave = waves
            .iter()
            .position(|w| w.contains(&"indrajaal-ex-app-1".to_string()));
        let db_wave = waves
            .iter()
            .position(|w| w.contains(&"indrajaal-db-prod".to_string()));
        assert!(app_wave.is_some() && db_wave.is_some());
        assert!(
            app_wave.unwrap() > db_wave.unwrap(),
            "App must boot after DB: app in wave {:?}, db in wave {:?}",
            app_wave,
            db_wave
        );
    }

    #[test]
    fn test_dependency_graph_bridge_depends_on_app() {
        let dg = build_dependency_graph();
        let waves = dg.calculate_waves();
        let app_wave = waves
            .iter()
            .position(|w| w.contains(&"indrajaal-ex-app-1".to_string()));
        let bridge_wave = waves
            .iter()
            .position(|w| w.contains(&"cepaf-bridge".to_string()));
        assert!(
            bridge_wave.unwrap() > app_wave.unwrap(),
            "Bridge must boot after App"
        );
    }

    #[test]
    fn test_dependency_graph_waves_are_non_empty() {
        let dg = build_dependency_graph();
        let waves = dg.calculate_waves();
        for (i, wave) in waves.iter().enumerate() {
            assert!(!wave.is_empty(), "Wave {} should not be empty", i);
        }
    }

    // ─── get_current_uid ───

    #[test]
    fn test_get_current_uid_returns_nonzero() {
        let uid = get_current_uid();
        assert!(uid > 0, "UID should be > 0 (not root in rootless podman)");
    }
}
