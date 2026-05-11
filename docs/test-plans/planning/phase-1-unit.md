# Phase 1 — Unit (L1, L2)

**Goal:** every public function in the `/planning` slice has an exhaustive unit test on pure inputs.

## In-scope modules

| Module | Functions covered |
|---|---|
| `c3i_nif` (NIF binding wrapper, Gleam side) | `plan_status`, `plan_list`, `plan_search`, `plan_add`, `plan_update`, `plan_get` |
| `ui/domain.gleam` | `Page` enum, `FractalLayer` enum, `HealthStatus`, `Task`, type encoders |
| `ui/wisp/router.gleam` (parse helpers) | `parse_status_filter`, `parse_search_query`, `decode_priority` |
| `priv/web-build/src/planning-grid.ts` → `priv/static/planning-grid.bundled.js` (TypeScript type check + bundle smoke) | `classifyFractalLayer`, `taskAge`, `truncate`, `fmtPercent`, `priColors` |

## Test cases (sample shape)

```gleam
gleeunit_test "plan_status returns 5 keys" {
  let r = plan_status() |> json_decode_status()
  expect.equal(map.size(r), 5)
  expect.true(map.has_key(r, "active"))
  expect.true(map.has_key(r, "blocked"))
}

gleeunit_test "classifyFractalLayer infers L0 for keyword 'guardian'" {
  expect.equal(classify_fractal_layer("guardian: emergency"), "L0")
  expect.equal(classify_fractal_layer("zenoh router restart"), "L6")
  expect.equal(classify_fractal_layer("planning task X"), "L3")  // default
}
```

## Math gate (Shannon entropy of failure modes)

`H = -Σ(p_i log2(p_i))` over the 8 categories C1–C8 with weights from CLAUDE.md §8.

Expected after phase: H ≥ 2.5, CCM ≥ 0.90.

## Failure modes addressed

| Mode | Mitigation |
|---|---|
| Wrong NIF ABI mismatch (panic) | round-trip JSON check |
| Fractal classifier mis-bucketing | golden fixture per layer |
| Priority enum drift (P0..P3 vs lower-case) | SC-VALUE-GUARD-002 enum |

## Exit criteria

- All cases green via `gleam test`.
- Coverage report ≥ 90 % for in-scope modules.
- Wiring guard test still passes.
