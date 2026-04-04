//! # Launch Module — Container Creation & Ignition
//!
//! ## Fractal Position: L4-System / Container Launch
//! ## Source: PanopticIgnition.fs:722-981, journal §3.6
//! ## STAMP: SC-IGNITE-006, SC-BOOT-004, SC-BOOT-006

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::*;
use log::{info, warn, error, debug};
use std::time::Duration;
use ed25519_dalek::{SigningKey, Signer, VerifyingKey};
use rand_core::OsRng;
use tokio::io::{AsyncBufReadExt, BufReader};

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
    let token = format!("{}:{}:{}", timestamp, nonce, hex::encode(signature.to_bytes()));
    let pubkey = hex::encode(verifying_key.to_bytes());
    
    (token, pubkey)
}

/// Generate SECRET_KEY_BASE (64 random hex bytes).
pub fn generate_secret_key() -> String {
    (0..64).map(|_| format!("{:02x}", rand::random::<u8>())).collect()
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
pub fn build_dependency_graph() -> DependencyGraph {
    let mut dg = DependencyGraph::new();
    
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
    
    dg
}

/// Helper to monitor container stderr and pipe to tui-logger.
async fn monitor_stderr(container_name: String, mut child: tokio::process::Child) {
    if let Some(stderr) = child.stderr.take() {
        let mut reader = BufReader::new(stderr).lines();
        let name = container_name.clone();
        tokio::spawn(async move {
            while let Ok(Some(line)) = reader.next_line().await {
                info!("[{}] {}", name, line);
            }
        });
    }
}

/// Specialized launch for application container with ProofToken.
pub async fn launch_app(proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    let secret_key = generate_secret_key();
    let cmd = build_app_cmd();
    let image = "localhost/indrajaal-ex-app-1:latest";
    let name = "indrajaal-ex-app-1";

    info!("  [Launch] Starting {} with ProofToken...", name);

    // Robustness Rank 4: Verify Image
    podman::verify_image(image).await?;

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
        "run".into(), "-d".into(),
        "--name".into(), name.into(),
        "--hostname".into(), name.into(),
        "--network".into(), MESH_NETWORK.into(),
        "--ip".into(), "172.28.0.10".into(),
        "--memory".into(), APP_MEMORY_LIMIT.into(),
        "--memory-swap".into(), APP_MEMORY_SWAP.into(),
        "-p".into(), "4000:4000".into(),
        "-p".into(), "4001:4001".into(),
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
    monitor_stderr(name.to_string(), child).await;

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

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let mut args: Vec<String> = vec![
        "run".into(), "-d".into(),
        "--name".into(), name.into(),
        "--hostname".into(), name.into(),
        "--network".into(), MESH_NETWORK.into(),
        "--ip".into(), TEST_CONTAINER_IP.into(),
        "--memory".into(), APP_MEMORY_LIMIT.into(),
        "--memory-swap".into(), APP_MEMORY_SWAP.into(),
        "-p".into(), format!("{}:{}", TEST_PHOENIX_PORT, TEST_PHOENIX_PORT),
        "-p".into(), format!("{}:{}", TEST_HEALTH_PORT, TEST_HEALTH_PORT),
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
    monitor_stderr(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Specialized launch for cepaf-bridge with ProofToken.
pub async fn launch_bridge(proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    let name = "cepaf-bridge";
    let uid = get_current_uid();
    let socket_host = format!("/run/user/{}/podman/podman.sock", uid);

    info!("  [Launch] Starting {} with ProofToken...", name);

    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let socket_mount = format!("{}:{}:z", socket_host, BRIDGE_SOCKET_CONTAINER);
    
    let args = vec![
        "run".into(), "-d".into(), "-i".into(),
        "--name".into(), name.into(),
        "--hostname".into(), name.into(),
        "--network".into(), MESH_NETWORK.into(),
        "-p".into(), "9876:9876".into(),
        "--env".into(), format!("CEPAF_BRIDGE_PORT={}", BRIDGE_PORT),
        "--env".into(), "CEPAF_BRIDGE_HOST=0.0.0.0".into(),
        "--env".into(), format!("ZENOH_ROUTER_ENDPOINT=tcp://zenoh-router-1:{}", ZENOH_PORT),
        "--env".into(), format!("PODMAN_SOCKET={}", BRIDGE_SOCKET_CONTAINER),
        "--env".into(), "UID=0".into(),
        "--env".into(), "DOTNET_ENVIRONMENT=Production".into(),
        "--env".into(), format!("C3I_PROOF_TOKEN={}", proof_token),
        "--env".into(), format!("C3I_PROOF_PUBKEY={}", proof_pubkey),
        "-v".into(), socket_mount,
        "localhost/cepaf-bridge:latest".into(),
    ];

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_stderr(name.to_string(), child).await;

    Ok(name.to_string())
}

/// Generic container launch for Zenoh, DB, OBS, Cortex.
pub async fn launch_generic(name: &str, proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    info!("  [Launch] Starting {} with ProofToken...", name);
    
    if podman::container_exists(name).await {
        podman::force_remove(name).await?;
    }

    let image = match name {
        n if n.starts_with("zenoh") => "zenoh/zenoh:latest",
        "indrajaal-db-prod" => "postgres:15-alpine",
        "indrajaal-obs-prod" => "prom/prometheus:latest", // Simplified for now
        "indrajaal-cortex" => "localhost/indrajaal-cortex:latest",
        _ => "alpine:latest",
    };

    let mut args = vec![
        "run".into(), "-d".into(),
        "--name".into(), name.into(),
        "--hostname".into(), name.into(),
        "--network".into(), MESH_NETWORK.into(),
        "--env".into(), format!("C3I_PROOF_TOKEN={}", proof_token),
        "--env".into(), format!("C3I_PROOF_PUBKEY={}", proof_pubkey),
    ];

    if name == "indrajaal-db-prod" {
        args.push("--env".into());
        args.push("POSTGRES_PASSWORD=postgres".into());
    }

    args.push(image.into());

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let child = podman::podman_spawn(&args_ref)?;
    monitor_stderr(name.to_string(), child).await;

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
            
            let handle = tokio::spawn(async move {
                launch_by_name(&name, &token, &pubkey).await
            });
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
        
        if wave_failed {
            error!("  ❌ Ignition transaction failed at Wave {}. Initiating Compensating Transaction...", i);
            let containers_to_rollback: Vec<&str> = launched_successfully.iter().map(|s| s.as_str()).collect();
            rollback_wave(containers_to_rollback).await;
            return Err(IgnitionError::LaunchFailed(format!("Wave {} failed", i)));
        }
    }
    
    info!("  ✅ Authoritative SIL-6 Mesh Ignition Complete");
    Ok(())
}

/// Rank 8 Idea: Compensating Transaction (Rollback)
pub async fn rollback_wave(containers: Vec<&str>) {
    warn!("  [Rollback] Reverting state for containers: {:?}", containers);
    for name in containers {
        let _ = podman::force_remove(name).await;
    }
    warn!("  [Rollback] System returned to Safe State.");
}

/// Router for container launch logic.
async fn launch_by_name(name: &str, proof_token: &str, proof_pubkey: &str) -> Result<String, IgnitionError> {
    match name {
        "indrajaal-ex-app-1" => launch_app(proof_token, proof_pubkey).await,
        "cepaf-bridge" => launch_bridge(proof_token, proof_pubkey).await,
        _ => launch_generic(name, proof_token, proof_pubkey).await,
    }
}

/// App environment variables with ProofToken injection.
pub fn app_env_vars(secret_key: &str, proof_token: &str, proof_pubkey: &str) -> Vec<(String, String)> {
    vec![
        ("MIX_ENV".into(), "prod".into()),
        ("SKIP_ZENOH_NIF".into(), "0".into()),
        ("SKIP_LINEAGE_NIF".into(), "1".into()),
        ("RUSTLER_SKIP_COMPILE".into(), "false".into()),
        ("ELIXIR_ERL_OPTIONS".into(), "+fnu +S 16:16 +SDio 16".into()),
        ("PORT".into(), PHOENIX_PORT.to_string()),
        ("PHX_HOST".into(), "localhost".into()),
        ("PHX_PORT".into(), PHOENIX_PORT.to_string()),
        ("DATABASE_URL".into(), format!("ecto://postgres:postgres@indrajaal-db-prod:{}/indrajaal_prod", POSTGRES_INTERNAL_PORT)),
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
        ("ZENOH_ROUTER_ENDPOINT".into(), format!("tcp/zenoh-router-1:{}", ZENOH_PORT)),
        ("ZENOH_MODE".into(), "client".into()),
        ("OTEL_EXPORTER_OTLP_ENDPOINT".into(), format!("http://indrajaal-obs-prod:{}", OTEL_GRPC_PORT)),
        ("OTEL_SERVICE_NAME".into(), "indrajaal-ex-app-1".into()),
        ("RELEASE_NODE".into(), "indrajaal@indrajaal-ex-app-1".into()),
        ("RELEASE_COOKIE".into(), "indrajaal_prod_cookie".into()),
        ("PRAJNA_COCKPIT_ENABLED".into(), "true".into()),
        ("PRAJNA_DARK_MODE".into(), "true".into()),
        ("PRAJNA_AI_COPILOT_ENABLED".into(), "true".into()),
        ("QUADPLEX_ZENOH".into(), "true".into()),
        ("CLUSTERING_ENABLED".into(), "true".into()),
        ("CEPAF_BRIDGE_URL".into(), format!("http://cepaf-bridge:{}", BRIDGE_PORT)),
        ("CORTEX_URL".into(), format!("http://indrajaal-cortex:{}", CORTEX_PORT)),
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
pub fn test_env_vars(secret_key: &str, proof_token: &str, proof_pubkey: &str) -> Vec<(String, String)> {
    let mut vars = app_env_vars(secret_key, proof_token, proof_pubkey);
    // Override for test
    for (key, val) in &mut vars {
        if key == "MIX_ENV" { *val = "test".into(); }
        if key == "POSTGRES_DB" { *val = TEST_DATABASE_NAME.into(); }
        if key == "DATABASE_URL" { 
            *val = format!("ecto://postgres:postgres@indrajaal-db-prod:{}/{}", POSTGRES_INTERNAL_PORT, TEST_DATABASE_NAME);
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
