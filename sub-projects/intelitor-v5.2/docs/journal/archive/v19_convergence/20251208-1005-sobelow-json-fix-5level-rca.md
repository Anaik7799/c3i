# Journal Entry: Sobelow JSON Format Crash Fix

**Date**: 2025-12-08 10:05 CEST
**Author**: Claude Code (Opus 4.5)
**Type**: Bug Fix / 5-Level RCA
**Methodology**: TPS, Jidoka, 5-Level RCA

---

## Summary

Fixed critical Sobelow JSON format crash using 5-Level RCA methodology with Jidoka (fix at source) principle. Both JSON and text formats now work correctly.

---

## 5-Level Root Cause Analysis

### Level 1: Surface Problem
- **Symptom**: `MatchError` crash when running `mix sobelow --format json`
- **Error Location**: `deps/sobelow/lib/sobelow/config/secrets.ex:66`
- **Error Message**:
  ```
  ** (MatchError) no match of right hand side value: 26
  ```

### Level 2: Proximate Cause
- Pattern match `{vuln_line_no, vuln_line_col} = get_vuln_line(...)` failed
- Function returned integer `26` instead of expected tuple `{line, col}`
- The value `26` was a line number being used as default value

### Level 3: Contributing Factors
- Multi-line heredoc strings (`"""..."""`) in config files (e.g., `secret_key_base`)
- Sobelow's `String.replace("\"#{secret}\"", "@sobelow_secret")` doesn't match heredocs
- AST traversal fails to find `@sobelow_secret` marker in heredoc cases
- No secrets found in AST means empty `secrets` list

### Level 4: Systemic Issue
- Type inconsistency in `get_vuln_line/3` function
- Function can return either:
  - `{line_no, col_no}` tuple (when secret found)
  - Integer `config_line_no` (when secret not found - the bug)
- Original code: `Enum.find(secrets, config_line_no, &(&1 > config_line_no))`
- The third argument to `Enum.find/3` is the default value (integer), not a tuple

### Level 5: Root Cause
- **Bug in Sobelow 0.14.1**: The `get_vuln_line/3` function in `config/secrets.ex`
- **Design Flaw**: Return type inconsistency - should always return tuple
- **Original Line 122**:
  ```elixir
  Enum.find(secrets, config_line_no, &(&1 > config_line_no))
  ```
  This returns `config_line_no` (integer) when no match found.

---

## Jidoka Fix Applied

Per Jidoka principle (stop and fix at source), patched `deps/sobelow/lib/sobelow/config/secrets.ex`:

### Before (Lines 115-123):
```elixir
defp get_vuln_line(file, config_line_no, secret) do
  {_, secrets} =
    File.read!(file)
    |> String.replace("\"#{secret}\"", "@sobelow_secret")
    |> Code.string_to_quoted()
    |> Macro.prewalk([], &get_vuln_line/2)

  Enum.find(secrets, config_line_no, &(&1 > config_line_no))
end
```

### After (Lines 115-128):
```elixir
defp get_vuln_line(file, config_line_no, secret) do
  {_, secrets} =
    File.read!(file)
    |> String.replace("\"#{secret}\"", "@sobelow_secret")
    |> Code.string_to_quoted()
    |> Macro.prewalk([], &get_vuln_line/2)

  # Fix: Always return a tuple {line_no, col_no} for pattern match consistency
  # When secret is not found (e.g., heredoc strings), default to {config_line_no, 0}
  case Enum.find(secrets, &(&1 > config_line_no)) do
    {line_no, col_no} -> {line_no, col_no}
    nil -> {config_line_no, 0}
  end
end
```

---

## Verification Results

### JSON Format Test
```bash
mix sobelow --format json --out sobelow-report.json
# Result: Success - 57,986 byte valid JSON file generated
```

### Text Format Test
```bash
mix sobelow --format txt
# Result: Success - runs without errors
```

### JSON Validation
```bash
python3 -c "import json; json.load(open('sobelow-report.json'))"
# Result: JSON is valid
```

---

## Configuration Fix (Prior Issue)

Also fixed `.sobelow-conf` configuration errors:

### Removed Invalid Options:
- `details: true` - expects module name string like "XSS", not boolean
- `files: [...]` - not a valid Sobelow option
- `confidence: "high"` - not a valid Sobelow option

### Fixed Option:
- `skip: []` changed to `skip: false` - boolean, not list

---

## Files Modified

1. `deps/sobelow/lib/sobelow/config/secrets.ex` - Jidoka fix for tuple return type
2. `.sobelow-conf` - Removed invalid configuration options

---

## STAMP Safety Constraints Validated

- SC-VAL-003: 5-method validation consensus maintained
- SC-SEC-044: Security scanning (Sobelow) now operational

---

## Recommendations

1. **Report Bug**: Submit issue to Sobelow GitHub repository
2. **Monitor Updates**: Check if Sobelow 0.14.2+ fixes this issue
3. **Backup Patch**: Keep local patch documented for reapplication after `mix deps.get`

---

## Tags

`#sobelow` `#5-level-rca` `#jidoka` `#tps` `#bug-fix` `#security-scanning`
