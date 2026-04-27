# BEAM Hot Code Reload Protocol (SC-HA-RELOAD)
# बीम उष्ण-कूट पुनःलोड प्रोतोकॉल

## Supreme Mandate (सर्वोच्च आदेश)
**The system MUST support zero-downtime bytecode upgrade via BEAM code server.**
**Full server restarts are PROHIBITED for code-only changes.**
अविनाशि तु तद्विद्धि येन सर्वमिदं ततम् — That which pervades all is indestructible (Gita 2.17)

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-HA-RELOAD-001 | Code changes MUST use hot reload, NOT server restart | HIGH |
| SC-HA-RELOAD-002 | ALWAYS use soft_purge (never hard purge) | CRITICAL |
| SC-HA-RELOAD-003 | MD5 checksum MUST be verified before and after reload | HIGH |
| SC-HA-RELOAD-004 | NIF (.so) changes REQUIRE server restart (exception) | CRITICAL |
| SC-HA-RELOAD-005 | WebSocket connections MUST survive hot reload | HIGH |
| SC-HA-RELOAD-006 | OODA cycles MUST NOT be interrupted during reload | HIGH |
| SC-HA-RELOAD-007 | Reload MUST be atomic — all changed modules or none | HIGH |
| SC-HA-RELOAD-008 | module_info() sanity check MUST pass after reload | CRITICAL |

## BEAM Code Server Theory (बीम कूट सेवक सिद्धान्त)

### Two-Version Invariant
```
∀ Module ∈ BEAM:
  versions(Module) ∈ {0, 1, 2}
  
  0 versions: module not loaded
  1 version:  only "current" exists
  2 versions: "current" (new) + "old" (previous)
  
Invariant: |versions(M)| ≤ 2 at all times
```

### Process Migration Model
```
Process P running Module M version V:
  - If P calls M:function() (fully-qualified), P migrates to current version
  - If P calls function() (local), P stays on version V
  - soft_purge(M) succeeds iff ∀P: version(P, M) ≠ old
  - hard_purge(M) kills all P where version(P, M) = old [DANGEROUS]
```

### Hot Reload Correctness Proof
```
Given:
  S₀ = system state before reload
  S₁ = system state after reload
  M_old = set of old module bytecodes
  M_new = set of new module bytecodes (after gleam build)
  
Preconditions:
  P1: gleam build succeeds (0 errors)
  P2: ∀m ∈ M_new: md5(m_disk) ≠ md5(m_loaded) → m is "changed"
  P3: ∀m ∈ changed: soft_purge(m) = true (no processes in old code)
  
Postconditions:
  Q1: ∀m ∈ changed: is_loaded(m) ∧ md5(m) = md5(m_disk)
  Q2: ∀m ∉ changed: version(m) = version_before(m) (unchanged modules untouched)
  Q3: ∀connection ∈ WebSocket: connection.alive = true
  Q4: ∀cycle ∈ OODA: cycle.interrupted = false
  
Safety: S₁ satisfies SC-FUNC-001 (system compiles and runs)
Liveness: reload completes in finite time (bounded by |changed| × load_time)
```

## Protocol Steps (प्रोतोकॉल चरण)

### Step 1: Build (निर्माण)
```bash
gleam build  # Incremental — only recompiles changed files
# MUST succeed with 0 errors before proceeding
```

### Step 2: Discover (खोज)
```
For each loaded module M where is_gleam_module(M):
  disk_md5 = beam_lib:md5(code:which(M))
  loaded_md5 = M:module_info(md5)
  if disk_md5 ≠ loaded_md5 → add to changed_set
```

### Step 3: Soft Purge (मृदु शुद्धि)
```
For each M in changed_set:
  result = code:soft_purge(M)
  if result = false → ABORT (processes still using old code)
  # NEVER use code:purge/1 (hard purge) — it kills processes
```

### Step 4: Load (लोड)
```
For each M in changed_set:
  {module, M} = code:load_file(M)
  # New bytecode now "current", old is gone (was soft_purged)
```

### Step 5: Verify (सत्यापन)
```
For each M in changed_set:
  assert is_loaded(M) = true
  assert md5(M) = disk_md5(M)  # Bytecode matches disk
  assert M:module_info(exports) is accessible  # Sanity check
```

## Agent Usage (एजेंट उपयोग)

### After editing Gleam files:
```bash
# Option A: Via HTTP endpoint (while server is running)
curl -s https://localhost:4100/api/v1/reload

# Option B: Via shell script
./scripts/hot-reload.sh

# Option C: Via Gleam code
hot_reload.build_and_reload()
```

### NEVER do this for code-only changes:
```bash
# ❌ PROHIBITED — kills all connections, loses state
pkill -f beam.smp
gleam run -- --serve
```

## Exception: NIF Changes (अपवाद: NIF परिवर्तन)
NIF (.so) shared libraries CANNOT be hot-reloaded. If any of these change:
- `priv/c3i_nif.so` — 14 NIFs
- `priv/planning_nif.so` — Planning NIF
- `priv/rule_engine_nif.so` — Rule engine NIF

Then a full server restart IS required:
```bash
pkill -f beam.smp
rm -rf build/dev/erlang/cepaf_gleam
gleam build
nohup gleam run -- --serve &
```

## Mathematical Robustness Checks (गणितीय मजबूती जाँच)

### 1. Determinism Check
```
∀ sequence of reloads R₁, R₂, ..., Rn:
  apply(R₁) ∘ apply(R₂) ∘ ... ∘ apply(Rn) = apply(Rn)
  
  Hot reload is idempotent — applying the same reload twice
  produces the same result as applying it once.
```

### 2. Commutativity Check
```
For independent modules A, B:
  reload(A) ∘ reload(B) = reload(B) ∘ reload(A)
  
  Order doesn't matter for independent modules.
  Dependent modules must be loaded in dependency order.
```

### 3. Monotonicity Check
```
∀ reload R:
  test_count(after R) ≥ test_count(before R)
  
  Hot reload MUST NOT reduce the test count.
  (Verified by running gleam test after reload)
```

### 4. State Preservation Check
```
∀ actor A with state S:
  if A makes only local calls during reload:
    state(A, after) = state(A, before)
  if A makes qualified call M:f() after reload:
    A migrates to new code with same state S
    (Gleam actors use process dictionaries — state survives code swap)
```

## Files (फ़ाइलें)
| File | Lines | Purpose |
|------|-------|---------|
| `src/hot_reload_ffi.erl` | ~250 | Erlang FFI — code server API bindings |
| `src/cepaf_gleam/ha/hot_reload.gleam` | ~120 | Gleam wrapper — typed hot reload API |
| `scripts/hot-reload.sh` | ~40 | CLI script for hot reload |
| `.gemini/rules/hot-reload-protocol.md` | This file | Protocol and correctness proofs |

## Integration with Dashboard (डैशबोर्ड एकीकरण)
The dashboard JS can trigger hot reload via:
```javascript
fetch("/api/v1/reload").then(r => r.json()).then(data => {
  logChange("reload", data.result);
});
```
WebSocket connections survive the reload — no reconnect needed.
