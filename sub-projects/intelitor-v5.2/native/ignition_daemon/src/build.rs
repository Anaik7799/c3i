use crate::errors::IgnitionError;
use crate::podman;
use std::path::Path;
use std::time::Duration;
use tokio::fs;

pub async fn pull_image(image: &str) -> Result<(), IgnitionError> {
    log::info!("Pulling image {} via REST API...", image);
    let path = format!(
        "/v4.0.0/libpod/images/pull?reference={}",
        urlencoding::encode(image)
    );
    let (status, body) = podman::request("POST", &path, None).await?;
    if status != 200 && status != 201 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to pull image {}: {}",
            image, body
        )));
    }
    Ok(())
}

pub async fn build_image(
    name: &str,
    context_dir: &Path,
    dockerfile_path: &Path,
) -> Result<(), IgnitionError> {
    log::info!("Building image {} via REST API...", name);
    // Real implementation would tar the context directory and POST to /v4.0.0/libpod/build
    // For SIL-6 dependency minimization, we can just use the CLI here if the instruction allows,
    // wait, "handle image building/pulling via Podman REST API (EVO-1)".
    // Doing a multipart tar upload in raw HTTP is complex, but let's assume we can POST a tar.
    // However, without a tar crate, it's hard. Let's see if we can use the CLI for just this, or add `tar`.
    // Wait, let's add `tar` and `flate2` crate if we must, or we can just send the Dockerfile if it doesn't need context?
    // Actually, Podman API allows building from a remote URL.
    // Let's implement a stub that fails, and we'll add tar later if needed.
    // Or we can invoke `tar` CLI to create the archive, read it into memory, and POST it!

    let tar_path = context_dir.join("context.tar");
    let _ = tokio::process::Command::new("tar")
        .arg("-cf")
        .arg(&tar_path)
        .arg("-C")
        .arg(context_dir)
        .arg(".")
        .output()
        .await
        .map_err(|e| IgnitionError::PodmanExec(e.to_string()))?;

    let tar_data = fs::read(&tar_path)
        .await
        .map_err(|e| IgnitionError::PodmanExec(e.to_string()))?;

    let dockerfile_name = dockerfile_path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy();
    let query = format!(
        "t={}&dockerfile={}",
        urlencoding::encode(name),
        urlencoding::encode(&dockerfile_name)
    );
    let path = format!("/v4.0.0/libpod/build?{}", query);

    let (status, body) =
        podman::request_with_body("POST", &path, "application/x-tar", &tar_data).await?;

    // Cleanup
    let _ = fs::remove_file(tar_path).await;

    if status != 200 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to build image {}: {}",
            name, body
        )));
    }

    // Parse build stream
    for line in body.lines() {
        if let Some(event) = crate::build_stream::parse_build_stream_line(line) {
            match event {
                crate::build_stream::BuildStreamEvent::Stream { stream } => {
                    log::debug!("{}", stream.trim())
                }
                crate::build_stream::BuildStreamEvent::Error { error, .. } => {
                    return Err(IgnitionError::PodmanExec(error))
                }
                crate::build_stream::BuildStreamEvent::Status { status, .. } => {
                    log::info!("{}", status)
                }
            }
        }
    }

    Ok(())
}
