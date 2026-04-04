//! # CPU Governor — Adaptive Parallelism
//!
//! ## Fractal Position: L4-System / Resource Management
//! ## Source: cpu-governor.sh (235 lines)
//! ## STAMP: SC-CPU-GOV-001 to SC-CPU-GOV-010
//!
//! CPU measurement via /proc/stat differential (NOT /proc/loadavg).
//! /proc/loadavg includes I/O wait which inflates readings.

use crate::types::*;
use log::{info, warn};
use std::time::Duration;

/// Parse /proc/stat first line and return (active_ticks, total_ticks).
/// Source: cpu-governor.sh:20-36
async fn read_proc_stat() -> Result<(u64, u64), std::io::Error> {
    let content = tokio::fs::read_to_string("/proc/stat").await?;
    let first_line = content.lines().next().unwrap_or("");
    let fields: Vec<u64> = first_line
        .split_whitespace()
        .skip(1) // skip "cpu" label
        .filter_map(|s| s.parse().ok())
        .collect();

    if fields.len() < 7 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Cannot parse /proc/stat",
        ));
    }

    // user(0) nice(1) system(2) idle(3) iowait(4) irq(5) softirq(6)
    let active = fields[0] + fields[1] + fields[2] + fields[5] + fields[6];
    let total = active + fields[3] + fields[4]; // + idle + iowait

    Ok((active, total))
}

/// Measure CPU usage over a sample window.
/// Source: cpu-governor.sh:20-36 (1s), :40-54 (100ms)
///
/// Math: CPU% = (active_delta / total_delta) × 100
/// SC-CPU-GOV-009: CPU check uses /proc/stat differential
pub async fn cpu_usage(sample_ms: u64) -> Result<u8, std::io::Error> {
    let (active1, total1) = read_proc_stat().await?;
    tokio::time::sleep(Duration::from_millis(sample_ms)).await;
    let (active2, total2) = read_proc_stat().await?;

    let active_delta = active2.saturating_sub(active1);
    let total_delta = total2.saturating_sub(total1);

    if total_delta == 0 {
        return Ok(0);
    }

    Ok(((active_delta * 100) / total_delta) as u8)
}

/// Fast CPU measurement (100ms sample).
pub async fn cpu_usage_fast() -> Result<u8, std::io::Error> {
    cpu_usage(100).await
}

/// Wait until CPU drops below resume threshold.
/// Source: cpu-governor.sh:57-82
/// SC-CPU-GOV-005: Wait-loop when CPU > 85% (pause until < 75%)
pub async fn wait_until_available() -> Result<bool, std::io::Error> {
    let mut elapsed_secs = 0u64;

    loop {
        let cpu = cpu_usage_fast().await?;

        if cpu <= CPU_RESUME_THRESHOLD {
            return Ok(true);
        }

        if cpu > CPU_HARD_LIMIT {
            warn!(
                "[Governor] CPU {}% > {}% hard limit — waiting ({}/{}s)",
                cpu, CPU_HARD_LIMIT, elapsed_secs, CPU_MAX_WAIT_SECS
            );
        }

        if elapsed_secs >= CPU_MAX_WAIT_SECS {
            warn!("[Governor] Max wait {}s exceeded — proceeding with min parallelism", CPU_MAX_WAIT_SECS);
            return Ok(false);
        }

        tokio::time::sleep(Duration::from_secs(CPU_CHECK_INTERVAL_SECS)).await;
        elapsed_secs += CPU_CHECK_INTERVAL_SECS;
    }
}

/// Compute adaptive parallelism config from current CPU%.
/// Source: cpu-governor.sh:85-116
///
/// | CPU % | Schedulers | Dirty IO | Mix Jobs | Nice |
/// |-------|-----------|----------|----------|------|
/// | < 60% | 16        | 16       | 16       | 10   |
/// | < 70% | 12        | 12       | 12       | 10   |
/// | < 80% | 10        | 10       | 10       | 15   |
/// | ≤ 85% | 6         | 6        | 6        | 19   |
///
/// SC-CPU-GOV-006, SC-CPU-GOV-007
pub fn adaptive_parallelism(cpu_pct: u8) -> ParallelismConfig {
    if cpu_pct < 60 {
        ParallelismConfig { schedulers: 16, dirty_io: 16, mix_jobs: 16, nice_level: 10 }
    } else if cpu_pct < 70 {
        ParallelismConfig { schedulers: 12, dirty_io: 12, mix_jobs: 12, nice_level: 10 }
    } else if cpu_pct < 80 {
        ParallelismConfig { schedulers: 10, dirty_io: 10, mix_jobs: 10, nice_level: 15 }
    } else {
        ParallelismConfig { schedulers: 6, dirty_io: 6, mix_jobs: 6, nice_level: 19 }
    }
}

/// Get current governor status.
pub async fn status() -> String {
    let cpu = cpu_usage_fast().await.unwrap_or(0);
    let config = adaptive_parallelism(cpu);
    format!(
        "CPU: {}% | Schedulers: {} | Jobs: {} | Nice: {}",
        cpu, config.schedulers, config.mix_jobs, config.nice_level
    )
}

// =============================================================================
// Unit Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // ─── adaptive_parallelism boundary tests (SC-CPU-GOV-006, SC-CPU-GOV-007) ───

    #[test]
    fn test_adaptive_parallelism_full_speed_at_0_pct() {
        let config = adaptive_parallelism(0);
        assert_eq!(config.schedulers, 16);
        assert_eq!(config.dirty_io, 16);
        assert_eq!(config.mix_jobs, 16);
        assert_eq!(config.nice_level, 10);
    }

    #[test]
    fn test_adaptive_parallelism_full_speed_at_59_pct() {
        let config = adaptive_parallelism(59);
        assert_eq!(config.schedulers, 16);
        assert_eq!(config.mix_jobs, 16);
    }

    #[test]
    fn test_adaptive_parallelism_slight_reduction_at_60_pct() {
        let config = adaptive_parallelism(60);
        assert_eq!(config.schedulers, 12);
        assert_eq!(config.dirty_io, 12);
        assert_eq!(config.mix_jobs, 12);
        assert_eq!(config.nice_level, 10);
    }

    #[test]
    fn test_adaptive_parallelism_slight_reduction_at_69_pct() {
        let config = adaptive_parallelism(69);
        assert_eq!(config.schedulers, 12);
    }

    #[test]
    fn test_adaptive_parallelism_moderate_throttle_at_70_pct() {
        let config = adaptive_parallelism(70);
        assert_eq!(config.schedulers, 10);
        assert_eq!(config.dirty_io, 10);
        assert_eq!(config.mix_jobs, 10);
        assert_eq!(config.nice_level, 15);
    }

    #[test]
    fn test_adaptive_parallelism_moderate_throttle_at_79_pct() {
        let config = adaptive_parallelism(79);
        assert_eq!(config.schedulers, 10);
        assert_eq!(config.nice_level, 15);
    }

    #[test]
    fn test_adaptive_parallelism_heavy_throttle_at_80_pct() {
        let config = adaptive_parallelism(80);
        assert_eq!(config.schedulers, 6);
        assert_eq!(config.dirty_io, 6);
        assert_eq!(config.mix_jobs, 6);
        assert_eq!(config.nice_level, 19);
    }

    #[test]
    fn test_adaptive_parallelism_heavy_throttle_at_85_pct() {
        let config = adaptive_parallelism(85);
        assert_eq!(config.schedulers, 6);
        assert_eq!(config.nice_level, 19);
    }

    #[test]
    fn test_adaptive_parallelism_heavy_throttle_at_100_pct() {
        let config = adaptive_parallelism(100);
        assert_eq!(config.schedulers, 6);
        assert_eq!(config.nice_level, 19);
    }

    #[test]
    fn test_adaptive_parallelism_all_boundary_values() {
        // Test every boundary: 0, 59, 60, 69, 70, 79, 80, 85, 100
        let cases: Vec<(u8, u8)> = vec![
            (0, 16), (30, 16), (59, 16),   // full speed
            (60, 12), (65, 12), (69, 12),   // slight
            (70, 10), (75, 10), (79, 10),   // moderate
            (80, 6), (85, 6), (100, 6),     // heavy
        ];
        for (cpu, expected_schedulers) in cases {
            let config = adaptive_parallelism(cpu);
            assert_eq!(
                config.schedulers, expected_schedulers,
                "CPU {}% should give {} schedulers, got {}",
                cpu, expected_schedulers, config.schedulers
            );
        }
    }

    #[test]
    fn test_adaptive_parallelism_nice_levels() {
        assert_eq!(adaptive_parallelism(50).nice_level, 10);
        assert_eq!(adaptive_parallelism(65).nice_level, 10);
        assert_eq!(adaptive_parallelism(75).nice_level, 15);
        assert_eq!(adaptive_parallelism(82).nice_level, 19);
    }

    #[test]
    fn test_adaptive_parallelism_dirty_io_equals_schedulers() {
        for cpu in (0..=100).step_by(5) {
            let config = adaptive_parallelism(cpu);
            assert_eq!(
                config.schedulers, config.dirty_io,
                "CPU {}%: schedulers ({}) != dirty_io ({})",
                cpu, config.schedulers, config.dirty_io
            );
        }
    }

    #[test]
    fn test_adaptive_parallelism_jobs_equals_schedulers() {
        for cpu in (0..=100).step_by(5) {
            let config = adaptive_parallelism(cpu);
            assert_eq!(
                config.schedulers, config.mix_jobs,
                "CPU {}%: schedulers ({}) != mix_jobs ({})",
                cpu, config.schedulers, config.mix_jobs
            );
        }
    }
}
