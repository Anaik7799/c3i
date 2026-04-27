import gleeunit
import gleeunit/should
import scripts/common/breaker

pub fn main() -> Nil { gleeunit.main() }

pub fn breaker_starts_closed_test() {
  let b = breaker.new("test", 3, 1000)
  b.state |> should.equal(breaker.Closed)
}

pub fn breaker_opens_after_threshold_test() {
  let b = breaker.new("t", 3, 1000)
  let b = breaker.record_failure(b, 1000)
  let b = breaker.record_failure(b, 2000)
  b.state |> should.equal(breaker.Closed)
  let b = breaker.record_failure(b, 3000)
  b.state |> should.equal(breaker.Open)
}

pub fn breaker_blocks_when_open_test() {
  let b = breaker.new("t", 1, 1000)
  let b = breaker.record_failure(b, 1_000_000_000)
  let #(_, allowed) = breaker.allow(b, 1_000_000_000)
  allowed |> should.equal(False)
}

pub fn breaker_halfopen_after_cooloff_test() {
  let b = breaker.new("t", 1, 100)
  let b = breaker.record_failure(b, 0)
  let #(b2, allowed) = breaker.allow(b, 200_000_000)
  allowed |> should.equal(True)
  b2.state |> should.equal(breaker.HalfOpen)
}

pub fn breaker_closes_after_halfopen_success_test() {
  let b = breaker.new("t", 1, 100)
  let b = breaker.record_failure(b, 0)
  let #(b2, _) = breaker.allow(b, 200_000_000)
  let b3 = breaker.record_success(b2)
  b3.state |> should.equal(breaker.Closed)
}
