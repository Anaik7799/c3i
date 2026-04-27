//// scripts/pass8/p8_test_coord — smoke test for KMS coordinator (OTP actor).

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord

pub fn main() -> Nil {
  io.println("=== KMS coordinator smoke test ===")

  let assert Ok(coord) = kms_coord.start()

  // Stage 1: 3 sequential reads
  [1,2,3]
  |> list.each(fn(i) {
    case kms_coord.query(
      coord,
      "SELECT COUNT(*) AS n FROM holons",
      [],
    ) {
      Ok(qr) -> io.println(
        "read #" <> int.to_string(i) <> " holons=" <> scalar_of(qr),
      )
      Error(e) ->
        io.println_error("read FAIL: " <> kms.error_to_string(e))
    }
  })

  // Stage 2: an invalid SQL to test breaker updates
  let _ = kms_coord.query(coord, "SELECT * FROM _nope", [])
  let _ = kms_coord.query(coord, "SELECT * FROM _nope", [])

  // Stage 3: introspection
  let s = kms_coord.introspect(coord)
  io.println(kms_coord.summary_line(s))

  // Stage 4: 20 concurrent-ish reads (sequential over the actor, which
  // serialises them internally but proves the actor sticks under load).
  io.println("burst 20 reads…")
  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
  |> list.each(fn(_) {
    let _ = kms_coord.query(
      coord,
      "SELECT provider, COUNT(*) AS n FROM model_pricing GROUP BY provider",
      [],
    )
    Nil
  })

  let s2 = kms_coord.introspect(coord)
  io.println("post-burst " <> kms_coord.summary_line(s2))

  process.sleep(100)
  io.println("=== DONE ===")
}

fn scalar_of(qr: kms.QueryResult) -> String {
  case qr.rows {
    [[#(_, v), ..], ..] -> v
    _ -> "(empty)"
  }
}

// stub to prevent unused warning
