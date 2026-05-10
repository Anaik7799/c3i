# Phase 3 — Property-based tests (5 properties × 1000 cases each)

Per **SC-PROP-001..025** + **SC-FSH-030** (PropCheck-style).

| Property | Cases | Counter-example budget |
|---|---:|---|
| `∀ sequences (put, get, rotate, sync). version_vector monotonic` | 1000 | 0 (must hold) |
| `∀ clock advances. soft → hard stale boundary deterministic` | 1000 | 0 |
| `∀ master_key inputs. wrong_key never decrypts (negative)` | 1000 | 0 |
| `∀ caller patterns. audit log gap ≤ 5s after every NIF call` | 1000 | 0 |
| `∀ network partition durations. reconnect convergence ≤ 5min` | 1000 | 0 |

Implementation via `propcheck` (Gleam port) — generators produce random sequences of
operations within the typed `vault` algebra, runner verifies invariants after each step.

```gleam
test "property: version vector monotonic" {
  use sequence <- propcheck.forall(generate_op_sequence(min: 10, max: 100))
  let h = unseal_for_test()
  let final_versions = list.fold(sequence, dict.new(), fn(acc, op) {
    case op {
      Put(name, value) -> {
        let new_v = vault.put(h, name, value, default_policy()) |> result.unwrap.version
        dict.update(acc, name, fn(prev) {
          case prev {
            None -> Some([new_v])
            Some(versions) -> {
              should.be_true(new_v > list.last(versions) |> result.unwrap)
              Some(list.append(versions, [new_v]))
            }
          }
        })
      }
      _ -> acc
    }
  })
  // versions monotonic per name
  Nil
}
```

Run: `gleam test -- --module vault_property_test`
