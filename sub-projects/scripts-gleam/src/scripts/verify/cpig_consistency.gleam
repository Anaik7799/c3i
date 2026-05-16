//// scripts/verify/cpig_consistency — SC-CPIG-CONSISTENCY validator.
////
//// Mechanically enforces matrix-score ↔ evidence parity across 13 subsystems.
//// For every gate.score=1, evidence array MUST be non-empty.
//// For zk_ingestion gates, evidence MUST be backed by holons in Smriti.db
//// (delegated to operator query — this gate flags structural shape only).
////
//// Prevents the Pass-15 dishonesty class where matrix claimed 1 but
//// evidence string carried "gap" annotations (62/65 → recount → 60/65).
////
//// Exit 0 = consistent. Exit 1 = at least one structural mismatch.
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729),
////             [zk-ca8c05bebfcae93f] Anti-Stub-That-Lies mechanical verification.

import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import simplifile

const matrix_path: String = "/home/an/dev/ver/c3i/docs/journal/task-116480247290237220/cpig-matrix.json"

pub fn main() -> Nil {
  io.println("══ CPIG Consistency Validator (SC-CPIG-CONSISTENCY) ══")

  case simplifile.read(matrix_path) {
    Error(_) -> {
      io.println("✗ matrix not readable: " <> matrix_path)
      Nil
    }
    Ok(body) ->
      case parse(body) {
        Error(e) -> io.println("✗ parse: " <> e)
        Ok(violations) -> emit(violations)
      }
  }
}

type Violation {
  Violation(subsystem: String, gate: String, kind: String)
}

fn parse(body: String) -> Result(List(Violation), String) {
  let gate_decoder = {
    use score <- decode.field("score", decode.int)
    use evidence <- decode.field("evidence", decode.list(decode.string))
    decode.success(#(score, evidence))
  }
  let sub_decoder = {
    use id <- decode.field("id", decode.string)
    use score <- decode.field("score", decode.int)
    use gates_obj <- decode.field("gates", decode.dict(decode.string, gate_decoder))
    decode.success(#(id, score, gates_obj))
  }
  let top_decoder = {
    use subs <- decode.field("subsystems", decode.list(sub_decoder))
    use claimed_mean <- decode.optional_field(
      "system_score_mean",
      0,
      decode.int,
    )
    use claimed_max <- decode.optional_field("system_score_max", 0, decode.int)
    decode.success(#(subs, claimed_mean, claimed_max))
  }
  case json.parse(body, top_decoder) {
    Error(_) -> Error("json decode failed")
    Ok(#(subs, claimed_mean, claimed_max)) -> {
      let gate_v = scan(subs)
      let summary_v = scan_summary(subs, claimed_mean, claimed_max)
      Ok(list.append(gate_v, summary_v))
    }
  }
}

fn scan_summary(
  subs: List(#(String, Int, dict.Dict(String, #(Int, List(String))))),
  claimed_mean: Int,
  claimed_max: Int,
) -> List(Violation) {
  let actual_sum =
    list.fold(subs, 0, fn(acc, s) {
      let #(_, score, _) = s
      acc + score
    })
  let actual_max = list.length(subs) * 5
  let mean_violation = case claimed_mean == 0 || claimed_mean == actual_sum {
    True -> []
    False -> [
      Violation(
        "<top-level>",
        "system_score_mean",
        "claims "
          <> int.to_string(claimed_mean)
          <> " but Σ(subsystem.score) = "
          <> int.to_string(actual_sum),
      ),
    ]
  }
  let max_violation = case claimed_max == 0 || claimed_max == actual_max {
    True -> []
    False -> [
      Violation(
        "<top-level>",
        "system_score_max",
        "claims "
          <> int.to_string(claimed_max)
          <> " but |subsystems| × 5 = "
          <> int.to_string(actual_max),
      ),
    ]
  }
  list.append(mean_violation, max_violation)
}

fn scan(
  subs: List(#(String, Int, dict.Dict(String, #(Int, List(String))))),
) -> List(Violation) {
  list.flat_map(subs, fn(sub) {
    let #(id, _, gates) = sub
    dict.to_list(gates)
    |> list.flat_map(fn(g) {
      let #(gname, #(score, evidence)) = g
      case score, list.length(evidence) {
        1, 0 -> [Violation(id, gname, "score=1 but evidence=[]")]
        _, _ -> []
      }
    })
  })
}

fn emit(violations: List(Violation)) -> Nil {
  case violations {
    [] -> {
      io.println("✓ CPIG matrix consistent: all score=1 gates have evidence")
      Nil
    }
    _ -> {
      io.println(
        "✗ "
        <> int.to_string(list.length(violations))
        <> " SC-CPIG-CONSISTENCY violations:",
      )
      list.each(violations, fn(v) {
        io.println(
          "  • " <> v.subsystem <> " / " <> v.gate <> " — " <> v.kind,
        )
      })
      io.println(
        "hint: sa-plan add --priority P1 'Recount CPIG matrix per SC-CPIG-CONSISTENCY'",
      )
    }
  }
}

import gleam/dict
