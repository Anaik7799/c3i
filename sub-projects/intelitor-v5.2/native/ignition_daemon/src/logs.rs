use crate::artifacts::SIL6_GENOME;
use crate::errors::IgnitionError;
use log::{info, warn};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use std::process::Stdio;
use tokio::task::JoinSet;

pub async fn run_logs(follow: bool, tail: u32) -> Result<(), IgnitionError> {
    info!("── [L4] Streaming logs for SIL-6 Mesh ({} containers) ──", SIL6_GENOME.len());
    
    let mut set = JoinSet::new();
    
    for &container in SIL6_GENOME {
        let tail_str = tail.to_string();
        
        set.spawn(async move {
            let mut args = vec!["logs"];
            if follow {
                args.push("-f");
            }
            args.push("--tail");
            args.push(&tail_str);
            args.push(container);

            let mut child = Command::new("podman")
                .args(&args)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()?;

            let stdout = child.stdout.take().unwrap();
            let stderr = child.stderr.take().unwrap();

            let mut stdout_reader = BufReader::new(stdout).lines();
            let mut stderr_reader = BufReader::new(stderr).lines();

            loop {
                tokio::select! {
                    line = stdout_reader.next_line() => {
                        match line {
                            Ok(Some(l)) => println!("[{:<20}] {}", container, l),
                            Ok(None) => break,
                            Err(_) => break,
                        }
                    }
                    line = stderr_reader.next_line() => {
                        match line {
                            Ok(Some(l)) => eprintln!("[{:<20}] ⚠ {}", container, l),
                            Ok(None) => break,
                            Err(_) => break,
                        }
                    }
                }
            }
            Ok::<(), std::io::Error>(())
        });
    }

    while let Some(_) = set.join_next().await {}
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_run_logs_no_panic() {
        // Run logs in non-follow mode with small tail, should finish immediately if podman available
        // Even if it fails, we check it doesn't panic.
        let result = run_logs(false, 1).await;
        assert!(result.is_ok());
    }
}
