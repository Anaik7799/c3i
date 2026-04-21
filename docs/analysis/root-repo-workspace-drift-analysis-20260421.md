# Root Repo Workspace Drift Analysis — 2026-04-21

## Snapshot
- Repo: `/home/an/dev/ver/c3i` (branch `main`)
- Total drift entries (`git status --porcelain`): **434**
  - Untracked: **258**
  - Deleted: **89**
  - Modified: **87**

## Drift by top-level area
- `.gemini`: 162
- `docs`: 93
- `lib`: 92
- `.claude`: 55
- `.playwright-mcp`: 8
- `sub-projects`: 5
- `scripts`: 4
- `data`: 2
- root files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `PROJECT_TODOLIST.md`, etc.): remainder

## Critical classes (FMEA-style)

| Category | Count | S | O | D | RPN | Criticality |
|---|---:|---:|---:|---:|---:|---|
| G_AGENT_GOVERNANCE_DRIFT | 130 | 8 | 8 | 4 | 256 | P0 |
| F_CORE_CODE_DRIFT (`lib/cepaf_gleam`) | 92 | 9 | 7 | 4 | 252 | P0 |
| E_DOC_DRIFT | 90 | 5 | 8 | 5 | 200 | P1 |
| C_RUNTIME_STATE (`data/logs`, `data/smriti`) | 2 | 8 | 7 | 3 | 168 | P1 |
| A_DUPLICATE_NESTING (path hygiene) | 87 | 6 | 9 | 3 | 162 | P1 |
| B_LOCAL_ENV_ARTIFACTS | 15 | 4 | 8 | 4 | 128 | P2 |
| D_BINARY_ARTIFACTS | 2 | 5 | 6 | 4 | 120 | P2 |

## Key findings

### 1) Massive governance drift in `.gemini`
- There is widespread modified content + removals under nested legacy paths:
  - `.gemini/agents/agents/*` (29 deletions)
  - `.gemini/commands/commands/*` (2 deletions)
  - `.gemini/rules/rules/*` (56 deletions)
- These deletions appear to be **path-normalization cleanup**, not data loss:
  - all deleted nested files have matching top-level counterparts present/tracked.

### 2) `.claude`/`.gemini` parity is partially staged, partially drifting
- Root repo now has newly added `.claude/*` and `.gemini/*` governance artifacts.
- But many `.gemini` files still show unrelated modifications from prior sessions.
- This creates parity ambiguity and raises merge/cherry-pick risk.

### 3) Core code drift (`lib/cepaf_gleam`) is substantial and mixed
- 92 entries under `lib/cepaf_gleam` include modified and untracked files.
- Includes deletion of `claude_compute.gleam` and many new bridge/HA/auth/ui modules.
- This is not a small change set; it should be split into controlled commits by domain.

### 4) Docs drift is mostly binary-heavy artifacts
- 93 untracked docs paths; estimated ~31 MB total, ~30 MB binary-like assets (PNGs/WEBM/MP4/SVG bundles).
- These likely came from visual verification/evolution runs.
- Should be explicitly policy-decided (keep in git vs move to artifact store/releases).

### 5) Runtime/environment contamination in working tree
- `data/smriti/Smriti.db` modified
- `data/logs/ignition_capture.log` modified
- `.playwright-mcp/*`, `.zshrc`, generated index files at root
- Current `.gitignore` is too narrow for ongoing workflow outputs.

### 6) Submodule signal
- Root shows `sub-projects/c3i` modified pointer (expected when submodule advances).
- `git submodule status` currently errors due to legacy path (`lib/cepaf_gleam/native/bevy-engine`) lacking `.gitmodules` mapping.
- Indicates prior nested submodule residue/historical config mismatch.

## Recommended remediation plan (criticality-first)

### P0 (immediate)
1. **Freeze and snapshot**: save current status to file before further edits.
2. **Split commits by blast radius**:
   - governance/artifact parity (`.claude/.gemini`) only,
   - core code (`lib/cepaf_gleam`) only,
   - docs/assets only,
   - runtime/log state never committed.
3. **Quarantine runtime state**:
   - reset `data/smriti/Smriti.db`, `data/logs/*` from git tracking path or move to ignored paths.

### P1
4. **Path normalization cleanup commit** for duplicate nesting (`agents/agents`, `rules/rules`, `commands/commands`) with explicit migration note.
5. **Submodule integrity audit**:
   - inspect accidental embedded repos under `lib/cepaf_gleam/native/*`.
   - either formalize with `.gitmodules` or de-initialize embedded git dirs.

### P2
6. **Gitignore hardening** for local artifacts:
   - `.playwright-mcp/`
   - `data/logs/*.log`
   - `data/smriti/*.db`
   - generated root index files (`claude_*.txt`, `gemini_*.txt`)
   - optional: `docs/screenshots/`, `docs/videos/` (if externalized).
7. **Artifact policy**: define whether large media belongs in repo or release storage.

## Fast triage commands
```bash
# 1) Save current drift ledger
cd /home/an/dev/ver/c3i
git status --porcelain=v1 > docs/analysis/root-drift-ledger-20260421.txt

# 2) Inspect high-risk classes quickly
git status --porcelain | rg '^( M| D|\?\?) (\.gemini|lib/cepaf_gleam|data/|docs/)'

# 3) Verify duplicate-nesting cleanup candidates
find .gemini -type d \( -path '*/agents/agents' -o -path '*/commands/commands' -o -path '*/rules/rules' \)

# 4) Size check for untracked docs/media
python3 - <<'PY'
import subprocess, pathlib
out=subprocess.check_output(['git','status','--porcelain=v1'],text=True).splitlines()
paths=[l[3:] for l in out if l.startswith('?? docs/')]
sz=0
for p in paths:
    pp=pathlib.Path(p)
    if pp.is_dir():
        for f in pp.rglob('*'):
            if f.is_file(): sz += f.stat().st_size
    elif pp.is_file():
        sz += pp.stat().st_size
print(round(sz/1024/1024,2),'MB')
PY
```
