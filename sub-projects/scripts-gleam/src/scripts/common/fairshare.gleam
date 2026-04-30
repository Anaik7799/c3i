/// Fair-share priority computation (Slurm multifactor).
/// Mirror of Rust kernel logic; advisory only.
/// Per scheduling-ontology.md §6 formula.

import gleam/float
import gleam/int

const w_age = 10.0

const w_fair = 20.0

const w_qos = 30.0

const w_part = 5.0

const w_nice = 5.0

const w_size = 2.0

fn clamp(v: Float, lo: Float, hi: Float) -> Float {
  case v <. lo {
    True -> lo
    False ->
      case v >. hi {
        True -> hi
        False -> v
      }
  }
}

pub fn priority(
  age_secs: Int,
  account_used_secs: Int,
  account_quota_secs: Int,
  qos: Int,
  partition_mult: Float,
  nice: Int,
  cpu_req: Int,
) -> Float {
  let age =
    clamp(int.to_float(age_secs) /. 3600.0, 0.0, 24.0)
  let fair = case account_quota_secs == 0 {
    True -> 0.0
    False ->
      clamp(
        1.0
          -. int.to_float(account_used_secs)
          /. int.to_float(account_quota_secs),
        0.0,
        1.0,
      )
  }
  w_age
  *. age
  +. w_fair
  *. fair
  +. w_qos
  *. int.to_float(qos)
  +. w_part
  *. partition_mult
  +. w_nice
  *. int.to_float(nice)
  -. w_size
  *. int.to_float(cpu_req)
}

pub fn decay(used_secs: Int) -> Int {
  used_secs * 9 / 10
}

pub fn clamp_export(v: Float, lo: Float, hi: Float) -> Float {
  clamp(v, lo, hi)
}

pub fn weights() -> #(Float, Float, Float, Float, Float, Float) {
  #(w_age, w_fair, w_qos, w_part, w_nice, w_size)
}
