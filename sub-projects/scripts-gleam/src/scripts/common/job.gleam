/// JobSpec record — Slurm-flavoured resource declaration for sa-plan jobs.
/// Per scheduling-symbiosis.md §3.1 schema.

pub type Qos {
  Low
  Normal
  High
  Critical
}

pub type JobSpec {
  JobSpec(
    cpu_request: Int,
    mem_request_mb: Int,
    walltime_secs: Int,
    qos: Qos,
    account: String,
  )
}

pub fn default() -> JobSpec {
  JobSpec(
    cpu_request: 1,
    mem_request_mb: 256,
    walltime_secs: 3600,
    qos: Normal,
    account: "default",
  )
}

pub fn qos_weight(q: Qos) -> Int {
  case q {
    Low -> 0
    Normal -> 1
    High -> 5
    Critical -> 50
  }
}
