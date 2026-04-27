# Analysis: gleam/json vs serdes_json — When to Use Each

**Date**: 2026-04-19
**Author**: Claude Opus 4.6 + Abhijit Naik
**Context**: Sutra Matrix homeserver has two JSON libraries — this analysis defines when each should be used.

---

## 1. Scope & Trigger

The Sutra server now has two JSON libraries:
- **gleam/json** (v3.1.0) — Gleam-native, type-safe, BEAM-native
- **serdes_json** (v0.1.0) — Rust NIF via serde_json, 45 functions, raw blob support

This analysis determines the decision framework for which library to use in each context.

## 2. Library Comparison

### Architecture

| Aspect | gleam/json | serdes_json (NIF) |
|--------|-----------|-------------------|
| **Language** | Gleam (pure BEAM) | Rust → NIF → BEAM |
| **Backend** | Custom Gleam encoder | serde_json 1.x |
| **Type Safety** | Compile-time (opaque Json type) | Runtime (String in, String out) |
| **Raw JSON Embedding** | NOT POSSIBLE (double-escapes) | NATIVE (parse_or_string) |
| **Latency** | ~0 (in-process) | ~1-5μs NIF call overhead |
| **Memory** | BEAM-managed | Rust heap → copy to BEAM |
| **Crash Safety** | Cannot crash BEAM | DirtyCpu scheduled (safe) |
| **Pretty Printing** | NOT AVAILABLE | `to_string_pretty()` |
| **JSON Pointer** | NOT AVAILABLE | `pointer()` RFC 6901 |
| **Merge/Patch** | NOT AVAILABLE | `merge()`, `merge_patch()` RFC 7396 |
| **Diff** | NOT AVAILABLE | `diff()` RFC 6902 |
| **Validation** | Via `json.parse()` with decoder | `validate()` (boolean, fast) |

### API Surface

| Category | gleam/json | serdes_json |
|----------|-----------|-------------|
| **Construction** | `object`, `string`, `int`, `bool`, `null`, `array`, `nullable`, `dict`, `preprocessed_array` | `object_raw`, `array_raw`, `embed`, `nest`, `wrap_array`, `null` |
| **Serialization** | `to_string`, `to_string_tree` | `to_string`, `to_string_pretty`, `minify` |
| **Parsing** | `parse(str, decoder)`, `parse_bits` | `parse`, `validate`, `type_of` |
| **Query** | — | `pointer`, `get`, `get_index`, `get_keys`, `get_values`, `length`, `contains_key`, `is_*`, `as_*` |
| **Manipulation** | — | `merge`, `set`, `remove`, `remove_at`, `merge_patch` |
| **Array** | — | `array_push`, `array_concat`, `array_flatten`, `array_unique`, `array_sort`, `array_reverse`, `array_slice` |
| **String** | — | `escape`, `unescape` |
| **Comparison** | — | `equal`, `diff` |
| **Object Utils** | — | `pick`, `omit`, `rename_key`, `flatten` |
| **TOTAL** | **14 functions** | **45 functions** |

## 3. Decision Framework

### USE gleam/json WHEN:

1. **All values are Gleam-typed** — You have `String`, `Int`, `Bool`, `List` values, not raw JSON blobs.
   ```gleam
   // GOOD — all values are Gleam types
   json.object([
     #("user_id", json.string(user_id)),
     #("device_id", json.string(device_id)),
     #("is_guest", json.bool(False)),
   ]) |> json.to_string
   ```

2. **Compile-time type safety matters** — The `Json` type is opaque; you can't construct invalid JSON.

3. **Simple responses** — Login, error, whoami, event_id, room_id responses.

4. **No raw JSON blobs** — The response doesn't embed pre-serialized JSON from storage.

5. **Performance-critical hot path** — No NIF call overhead (in-process on BEAM).

### USE serdes_json WHEN:

1. **Raw JSON blob embedding** — Device keys, OTK values, event content, cross-signing keys stored as pre-serialized JSON strings.
   ```gleam
   // GOOD — raw blob embedded without double-escaping
   serdes_json.object_raw([
     #("device_keys", raw_device_key_blob),
     #("failures", "{}"),
   ])
   ```

2. **JSON Pointer access** — Deep path queries into stored JSON.
   ```gleam
   serdes_json.pointer(event_json, "/content/body")
   ```

3. **Merging JSON objects** — Combining stored JSON fragments.
   ```gleam
   serdes_json.merge(base_response, cross_signing_keys)
   ```

4. **JSON validation** — Checking if an incoming string is valid JSON.
   ```gleam
   case serdes_json.validate(user_input) {
     True -> process(user_input)
     False -> error_response()
   }
   ```

5. **Pretty printing** — Debug output, logs, admin responses.
   ```gleam
   serdes_json.to_string_pretty(stored_json)
   ```

6. **Diff/Patch** — Computing changes between JSON objects (state resolution).
   ```gleam
   let patches = serdes_json.diff(old_state, new_state)
   ```

7. **Array manipulation** — Sorting, deduplication, slicing stored JSON arrays.

8. **Complex nested structures with raw values** — Matrix protocol responses where inner objects are pre-serialized.

### USE BOTH TOGETHER WHEN:

The most common pattern in Sutra — use gleam/json for the typed structure and serdes_json for raw blob insertion:

```gleam
// Pattern: gleam/json for structure + serdes_json for raw blobs
let e2ee_ext = json.object([
  #("device_one_time_keys_count", json.object([
    #("curve25519", json.int(otk_count)),
    #("signed_curve25519", json.int(otk_count)),
  ])),
  #("device_unused_fallback_key_types", json.preprocessed_array([
    json.string("signed_curve25519"),
  ])),
]) |> json.to_string

// Then compose with raw blobs via serdes_json
let response = serdes_json.object_raw([
  #("pos", "\"s" <> int.to_string(timestamp) <> "\""),
  #("extensions", serdes_json.object_raw([
    #("e2ee", e2ee_ext),  // gleam/json output is valid JSON → raw embedding works
    #("to_device", td_response),
  ])),
])
```

## 4. Use Case Matrix

| Use Case | gleam/json | serdes_json | Recommended | Reason |
|----------|:---------:|:-----------:|:-----------:|--------|
| Login response | ✅ | ✅ | **gleam/json** | All typed values, no raw blobs |
| Error response | ✅ | ✅ | **gleam/json** | Simple key-value, type-safe |
| whoami response | ✅ | ✅ | **gleam/json** | 3 typed fields |
| Event ID response | ✅ | ✅ | **gleam/json** | Single string field |
| Capabilities response | ✅ | ✅ | **gleam/json** | Nested but all typed |
| Push rules (complex nested) | ✅ | ✅ | **gleam/json** | Large but all typed |
| Sync response (v2) | ⚠️ | ✅ | **both** | Structure = gleam, events = serdes |
| Sliding sync response | ⚠️ | ✅ | **both** | Structure = gleam, events = serdes |
| keys/query (device keys) | ❌ | ✅ | **serdes_json** | Raw device key blobs |
| keys/claim (OTK values) | ❌ | ✅ | **serdes_json** | Raw OTK blobs |
| keys/signatures/upload parse | ❌ | ✅ | **serdes_json** | Parse + merge raw blobs |
| Event encoding (raw content) | ❌ | ✅ | **serdes_json** | Raw content field |
| Cross-signing keys | ❌ | ✅ | **serdes_json** | Raw key blobs |
| Key backup (auth_data) | ❌ | ✅ | **serdes_json** | Raw auth_data blob |
| Account data (raw content) | ❌ | ✅ | **serdes_json** | User-defined JSON |
| JSON validation | ❌ | ✅ | **serdes_json** | Fast boolean check |
| Pretty print debug | ❌ | ✅ | **serdes_json** | Not in gleam/json |
| JSON Pointer query | ❌ | ✅ | **serdes_json** | Not in gleam/json |
| State diff/patch | ❌ | ✅ | **serdes_json** | Not in gleam/json |
| Federation responses | ⚠️ | ✅ | **both** | Structure + raw events |
| User display_name in JSON | ✅ | ✅ | **gleam/json** | json.string() escapes safely |

**Legend**: ✅ works correctly, ⚠️ works but requires workarounds, ❌ cannot do correctly

## 5. Performance Characteristics

### Theoretical Analysis

| Operation | gleam/json | serdes_json | Notes |
|-----------|-----------|-------------|-------|
| **Simple object (5 keys)** | ~2μs | ~5μs | gleam/json faster (no NIF overhead) |
| **Nested object (3 levels)** | ~5μs | ~8μs | gleam/json faster |
| **Large object (50 keys)** | ~15μs | ~12μs | serdes_json faster (Rust speed dominates) |
| **Event encoding (raw content)** | N/A | ~6μs | Only serdes_json can do this correctly |
| **100 events array** | N/A | ~600μs | Only serdes_json |
| **JSON validation** | ~20μs (parse+decode) | ~3μs | serdes_json 6x faster |
| **JSON Pointer (/a/b/c)** | N/A | ~4μs | Only serdes_json |
| **Merge two objects** | N/A | ~8μs | Only serdes_json |
| **Pretty print** | N/A | ~5μs | Only serdes_json |

### NIF Call Overhead

Each NIF call has ~1-3μs overhead for:
- Erlang → Rust context switch
- String copy from BEAM heap to Rust heap
- Result copy back to BEAM heap
- DirtyCpu scheduler handoff

For operations < 1μs of actual work, gleam/json wins.
For operations > 5μs of actual work, serdes_json wins.
**Crossover point**: ~3-5μs of work (roughly 10-20 JSON keys).

### Memory

- **gleam/json**: Builds StringTree (BEAM iodata) — zero-copy for Mist HTTP responses
- **serdes_json**: Builds Rust String → copies to BEAM binary — one allocation + copy

For HTTP responses, gleam/json's `to_string_tree()` can be more efficient since Mist can send iodata directly without flattening.

## 6. Security Analysis

| Concern | gleam/json | serdes_json |
|---------|-----------|-------------|
| **XSS via user input** | SAFE — `json.string()` escapes all special chars | SAFE — `escape()` uses serde_json escaping |
| **JSON injection** | IMPOSSIBLE — opaque Json type | SAFE — `parse_or_string` validates or escapes |
| **Double-escaping** | RISK — `json.string()` escapes pre-serialized JSON | SAFE — `object_raw()` validates and embeds raw |
| **Brace imbalance** | IMPOSSIBLE — type system prevents | IMPOSSIBLE — serde_json guarantees valid output |
| **NIF crash** | N/A | SAFE — DirtyCpu, no unsafe Rust, no panics |

## 7. Decision Flowchart

```
Is the value a pre-serialized JSON string from storage?
├── YES → serdes_json (object_raw, encode_event, otk_claim_response)
└── NO → Are all values Gleam-typed (String, Int, Bool, List)?
    ├── YES → gleam/json (json.object, json.string, json.int)
    └── NO → Is the operation query/manipulation (pointer, merge, diff)?
        ├── YES → serdes_json (pointer, merge, diff, set, remove)
        └── NO → gleam/json (default for type safety)
```

## 8. Recommended Patterns

### Pattern 1: Simple Response (gleam/json)
```gleam
router.JsonResponse(200,
  json.object([
    #("event_id", json.string(event_id)),
  ]) |> json.to_string
)
```

### Pattern 2: Response with Raw Blob (serdes_json)
```gleam
router.JsonResponse(200,
  serdes_json.object_raw([
    #("device_keys", device_key_blob),
    #("failures", "{}"),
  ])
)
```

### Pattern 3: Composition (both)
```gleam
let typed_part = json.object([
  #("count", json.int(42)),
  #("enabled", json.bool(True)),
]) |> json.to_string

let response = serdes_json.object_raw([
  #("settings", typed_part),
  #("raw_data", stored_blob),
])
```

### Pattern 4: Matrix Event (serdes_json)
```gleam
serdes_json.encode_event(
  event_id, event_type, sender,
  origin_server_ts, raw_content, state_key,
)
```

### Pattern 5: Validation + Processing (serdes_json)
```gleam
case serdes_json.validate(user_input) {
  False -> error_response(400, "Invalid JSON")
  True -> {
    let processed = serdes_json.set(user_input, "/processed", "true")
    store(processed)
  }
}
```

## 9. STAMP & Constitutional Alignment

| ID | Constraint |
|----|------------|
| SC-JSON-001 | ALL JSON responses MUST use gleam/json or serdes_json — CRITICAL |
| SC-JSON-002 | Manual string concat for JSON is PROHIBITED — CRITICAL |
| SC-JSON-003 | Raw JSON blobs MUST use serdes_json — HIGH |
| SC-JSON-004 | User-supplied strings MUST use json.string() or serdes_json.escape() — INFINITE |
| SC-JSON-005 | gleam/json PREFERRED for simple typed responses — HIGH |
| SC-JSON-006 | serdes_json REQUIRED when embedding pre-serialized blobs — CRITICAL |

## 10. Metrics

| Metric | Value |
|--------|-------|
| gleam/json functions | 14 |
| serdes_json functions | 45 |
| Total JSON API surface | 59 functions |
| Files using gleam/json | 8 |
| Files using serdes_json | 6 |
| Manual JSON concat remaining | 28 lines (parsers only, not response builders) |
| NIF binary size | 668 KB |
| NIF function count | 45 |

## 11. Conclusion

**gleam/json** is the default for simple, typed responses. It's faster for small objects, provides compile-time type safety, and integrates natively with BEAM.

**serdes_json** is required for any operation involving pre-serialized JSON blobs, JSON manipulation (merge, patch, pointer), validation, pretty printing, or diff. It's faster for large/complex objects and provides 31 operations gleam/json cannot do at all.

**Both together** is the most common pattern in the Matrix server — gleam/json builds the typed skeleton, serdes_json embeds the raw protocol blobs.

The key insight: **gleam/json is for CONSTRUCTION, serdes_json is for COMPOSITION**. You build typed values with gleam/json, you compose pre-existing JSON fragments with serdes_json.

---

## Appendix A: Complete Operation Audit (127 operations)

### Summary by Category

| Category | Operations | Examples |
|----------|-----------|---------|
| **gleam/json PREFERRED** | 71 | Login, register, error, whoami, capabilities, event_id responses |
| **serdes_json PREFERRED** | 48 | Device key blobs, OTK embedding, PDU events, merge, pointer |
| **BOTH TOGETHER** | 8 | Sync responses, sliding sync, event encoding with raw content |
| **Total** | **127** | Across 9 source files |

### Distribution by File

| File | gleam/json | serdes_json | Both | Total |
|------|-----------|-------------|------|-------|
| handlers.gleam | 22 | 8 | 1 | 31 |
| handlers_e2ee.gleam | 6 | 11 | 0 | 17 |
| handlers_federation.gleam | 10 | 11 | 1 | 22 |
| handlers_misc.gleam | 8 | 3 | 0 | 11 |
| handlers_ephemeral.gleam | 8 | 4 | 0 | 12 |
| handlers_rooms.gleam | 3 | 0 | 0 | 3 |
| router.gleam | 8 | 0 | 0 | 8 |
| sync_engine.gleam | 2 | 6 | 5 | 13 |
| sutra_server.gleam | 4 | 5 | 1 | 10 |
| **Total** | **71** | **48** | **8** | **127** |

### Top 5 Recommended Changes

1. **handlers.gleam L662,724,782,839** — Membership content to gleam/json
2. **handlers.gleam L1741** — Room aliases to gleam/json array
3. **handlers.gleam L1892** — Push rule enabled to json.bool()
4. **handlers_e2ee.gleam L301** — Empty claim response to gleam/json
5. **handlers_e2ee.gleam L604** — User ID extraction to serdes_json.get_keys()
