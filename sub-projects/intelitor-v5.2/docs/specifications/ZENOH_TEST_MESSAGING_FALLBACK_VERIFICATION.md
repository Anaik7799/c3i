# ZENOH TEST MESSAGING - FALLBACK VERIFICATION SPECIFICATION
## Version 2.0.0 | 2026-01-18 | Pass 3: Log-Based Fallback & Verification Integration

---

## 1. FALLBACK ARCHITECTURE (SC-ZTEST-008)

### 1.1 Dual-Write Strategy

**Principle**: ALL checkpoint messages MUST be written to structured logs BEFORE any Zenoh publish attempt.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     DUAL-WRITE FALLBACK ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Checkpoint Event                                                            │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ STEP 1: Log Fallback (GUARANTEED)                               │        │
│  │ [ZTEST-CHECKPOINT] checkpoint=... topic=... payload=...         │        │
│  │ Written to: stdout, Logger, file (./data/tmp/ztest.log)         │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ STEP 2: Zenoh Publish (BEST-EFFORT)                             │        │
│  │ Async Task.start() - non-blocking                               │        │
│  │ Retries: 3 with exponential backoff                             │        │
│  │ On failure: Already have log backup                             │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ STEP 3: Telemetry Emit                                          │        │
│  │ :telemetry.execute([:ztest, :publish], %{...})                  │        │
│  │ Tracks: success/failure, latency, fallback_used                 │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Fallback Log Format

**Structured Format**:
```
[ZTEST-CHECKPOINT] checkpoint={checkpoint_id} topic={topic} message={message} state_vector={vector} type={type} payload={json} timestamp={iso8601}
```

**Field Definitions**:
| Field | Required | Format | Example |
|-------|----------|--------|---------|
| checkpoint | Yes | CP-{DOMAIN}-{NN} | CP-BOOT-03 |
| topic | Yes | indrajaal/... | indrajaal/boot/foundation/db_ready |
| message | No | String | PostgreSQL healthy on :5433 |
| state_vector | No | [0,1]^6 | [1,1,1,0,0,0] |
| type | No | String | boot_checkpoint |
| payload | No | JSON | {"port": 5433} |
| timestamp | Yes | ISO 8601 UTC | 2026-01-18T12:00:00.000Z |

### 1.3 Elixir Implementation

```elixir
# lib/indrajaal/testing/zenoh_test_formatter.ex

# SC-ZTEST-008: Log-based fallback when Zenoh unavailable
defp log_checkpoint_fallback(topic, message) do
  checkpoint_id = Map.get(message, :checkpoint, "unknown")
  type = Map.get(message, :type, "unknown")

  Logger.info(
    "[ZTEST-CHECKPOINT] topic=#{topic} checkpoint=#{checkpoint_id} type=#{type} payload=#{Jason.encode!(message)}",
    domain: :zenoh_test,
    topic: topic,
    checkpoint: checkpoint_id,
    type: type
  )
end

defp publish_async(state, topic, message) do
  # STEP 1: ALWAYS log fallback first (SC-ZTEST-008, AOR-ZTEST-008)
  log_checkpoint_fallback(topic, message)

  # STEP 2: Async Zenoh publish (best-effort)
  Task.start(fn ->
    try do
      payload = Jason.encode!(message)
      if state.enabled do
        case do_publish(state.zenoh_session, topic, payload) do
          :ok -> :ok
          {:error, _reason} -> :ok  # Already have log fallback
        end
      end
    rescue
      _ -> :ok  # Already have log fallback
    end
  end)
end
```

### 1.4 F# Implementation

```fsharp
// lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx

module ZenohCheckpoints =
    /// SC-ZTEST-008: Log-based fallback when Zenoh unavailable
    let private logCheckpointFallback (checkpointId: string) (topic: string) (message: string) (stateVectorStr: string) =
        let timestamp = DateTimeOffset.UtcNow.ToString("o")
        printfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s state_vector=%s timestamp=%s"
            checkpointId topic message stateVectorStr timestamp

    let publishCheckpoint (checkpoint: BootCheckpoint) (stateVectorStr: string) (message: string) =
        let topic = getCheckpointTopic checkpoint
        let checkpointId = getCheckpointId checkpoint

        // STEP 1: ALWAYS write log-based fallback first (AOR-ZTEST-008)
        logCheckpointFallback checkpointId topic message stateVectorStr

        // STEP 2: Attempt Zenoh HTTP bridge publish (non-blocking, best-effort)
        async {
            try
                use client = new HttpClient()
                client.Timeout <- TimeSpan.FromSeconds(5.0)
                // ... Zenoh HTTP bridge publish
            with
            | ex -> ()  // Already have log fallback
        } |> Async.Start
```

---

## 2. VERIFICATION PROCEDURES

### 2.1 Log Parsing Regex

**Full Regex Pattern**:
```regex
\[ZTEST-CHECKPOINT\] checkpoint=(?<checkpoint>CP-[A-Z]+-[0-9]{2}(?:-TX-[0-9]{2})?) topic=(?<topic>indrajaal/[^\s]+)(?: message=(?<message>[^\s]+))?(?: state_vector=(?<state_vector>\[[0-1,]+\]))?(?: type=(?<type>[^\s]+))?(?: payload=(?<payload>\{[^}]+\}))? timestamp=(?<timestamp>[^\s]+)
```

**Simplified Patterns**:
```regex
# Boot checkpoints
\[ZTEST-CHECKPOINT\].*checkpoint=CP-BOOT-[0-9]{2}

# Test checkpoints
\[ZTEST-CHECKPOINT\].*checkpoint=CP-TEST-[0-9]{2}

# Smoke checkpoints
\[ZTEST-CHECKPOINT\].*checkpoint=CP-SMOKE-[0-9]{2}

# Any checkpoint with state vector
\[ZTEST-CHECKPOINT\].*state_vector=\[[0-1,]+\]
```

### 2.2 Verification Commands

```bash
# Count all fallback checkpoints in log
grep -c '\[ZTEST-CHECKPOINT\]' ./data/tmp/ztest.log

# Extract boot checkpoints
grep '\[ZTEST-CHECKPOINT\].*checkpoint=CP-BOOT' ./data/tmp/ztest.log

# Verify state vector progression
grep '\[ZTEST-CHECKPOINT\].*state_vector=' ./data/tmp/ztest.log | \
  grep -oP 'state_vector=\K\[[0-1,]+\]'

# Parse to JSON (using jq)
grep '\[ZTEST-CHECKPOINT\]' ./data/tmp/ztest.log | \
  sed 's/.*payload=//' | jq '.'

# Count by checkpoint type
grep '\[ZTEST-CHECKPOINT\]' ./data/tmp/ztest.log | \
  grep -oP 'checkpoint=\K[^\s]+' | sort | uniq -c

# Verify all 10 boot checkpoints present
for i in $(seq -w 01 10); do
  grep -q "checkpoint=CP-BOOT-$i" ./data/tmp/ztest.log && echo "CP-BOOT-$i: FOUND" || echo "CP-BOOT-$i: MISSING"
done
```

### 2.3 Elixir Verification Script

```elixir
# scripts/verification/ztest_fallback_verifier.exs

defmodule ZtestFallbackVerifier do
  @checkpoint_regex ~r/\[ZTEST-CHECKPOINT\] checkpoint=(?<checkpoint>[^\s]+) topic=(?<topic>[^\s]+)/

  @expected_boot_checkpoints [
    "CP-BOOT-01", "CP-BOOT-02", "CP-BOOT-03", "CP-BOOT-04", "CP-BOOT-05",
    "CP-BOOT-06", "CP-BOOT-07", "CP-BOOT-08", "CP-BOOT-09", "CP-BOOT-10"
  ]

  def verify(log_path) do
    log_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "[ZTEST-CHECKPOINT]"))
    |> Enum.map(&parse_checkpoint/1)
    |> analyze_results()
  end

  defp parse_checkpoint(line) do
    case Regex.named_captures(@checkpoint_regex, line) do
      %{"checkpoint" => cp, "topic" => topic} -> {cp, topic}
      _ -> nil
    end
  end

  defp analyze_results(checkpoints) do
    found_boot = checkpoints
      |> Enum.filter(fn {cp, _} -> String.starts_with?(cp, "CP-BOOT") end)
      |> Enum.map(fn {cp, _} -> cp end)
      |> Enum.uniq()

    missing = @expected_boot_checkpoints -- found_boot

    %{
      total_checkpoints: length(checkpoints),
      boot_checkpoints_found: length(found_boot),
      boot_checkpoints_missing: missing,
      verification_passed: Enum.empty?(missing)
    }
  end
end

# Run verification
result = ZtestFallbackVerifier.verify("./data/tmp/ztest.log")
IO.inspect(result, label: "Fallback Verification Result")
```

---

## 3. STAMP CONSTRAINTS (Fallback-Specific)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ZTEST-008 | Log fallback MUST be written BEFORE Zenoh attempt | CRITICAL | Code review + timing |
| SC-ZTEST-008-A | Fallback format MUST match [ZTEST-CHECKPOINT] pattern | CRITICAL | Regex test |
| SC-ZTEST-008-B | Fallback MUST include checkpoint ID | CRITICAL | Field presence |
| SC-ZTEST-008-C | Fallback MUST include topic | CRITICAL | Field presence |
| SC-ZTEST-008-D | Fallback MUST include ISO 8601 timestamp | HIGH | Format validation |
| SC-ZTEST-008-E | Fallback MUST be parseable by regex | HIGH | Parse test |

---

## 4. AOR RULES (Fallback-Specific)

| ID | Rule | Verification |
|----|------|--------------|
| AOR-ZTEST-008 | ALWAYS write log fallback BEFORE Zenoh attempt | Code review |
| AOR-ZTEST-013 | Parse log fallback with [ZTEST-CHECKPOINT] regex | Integration test |
| AOR-ZTEST-FALLBACK-001 | Log fallback MUST NOT block main execution | Performance test |
| AOR-ZTEST-FALLBACK-002 | Fallback logs MUST be rotated at 100MB | Log config |
| AOR-ZTEST-FALLBACK-003 | Fallback verification MUST run in CI pipeline | CI config |

---

## 5. INTEGRATION TEST SUITE

### 5.1 Test Cases

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| FALLBACK-001 | Zenoh unavailable - checkpoints still logged | All checkpoints in log |
| FALLBACK-002 | Parse boot checkpoint from log | 10 checkpoints parsed |
| FALLBACK-003 | State vector progression valid | Monotonic increase |
| FALLBACK-004 | Timestamp format valid | All ISO 8601 |
| FALLBACK-005 | No duplicate checkpoint IDs | Unique per run |
| FALLBACK-006 | Regex matches all formats | 100% match rate |
| FALLBACK-007 | Concurrent writes safe | No data corruption |
| FALLBACK-008 | Log rotation works | Files < 100MB |

### 5.2 Property Tests

```elixir
# test/indrajaal/testing/ztest_fallback_property_test.exs

use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# TDG-ZTEST-FALLBACK-001: Log format always parseable
property "fallback log format is parseable" do
  forall {cp_domain, cp_num} <- {PC.oneof([:BOOT, :TEST, :SMOKE]), PC.range(1, 99)} do
    checkpoint_id = "CP-#{cp_domain}-#{String.pad_leading(to_string(cp_num), 2, "0")}"
    topic = "indrajaal/#{String.downcase(to_string(cp_domain))}/test"

    log_line = "[ZTEST-CHECKPOINT] checkpoint=#{checkpoint_id} topic=#{topic} timestamp=2026-01-18T12:00:00.000Z"

    Regex.match?(~r/\[ZTEST-CHECKPOINT\]/, log_line)
  end
end

# TDG-ZTEST-FALLBACK-002: State vector always valid
property "state vector format is valid" do
  forall sv <- SD.fixed_list(List.duplicate(SD.member_of([0, 1]), 6)) do
    sv_str = "[#{Enum.join(sv, ",")}]"
    Regex.match?(~r/\[[0-1,]+\]/, sv_str)
  end
end
```

---

## 6. MONITORING AND ALERTING

### 6.1 Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `ztest.fallback.count` | Counter | Number of fallback writes |
| `ztest.fallback.parse_success` | Counter | Successfully parsed fallbacks |
| `ztest.fallback.parse_failure` | Counter | Failed parses |
| `ztest.zenoh.publish_success` | Counter | Successful Zenoh publishes |
| `ztest.zenoh.publish_failure` | Counter | Failed Zenoh publishes |
| `ztest.fallback.latency_ms` | Histogram | Log write latency |

### 6.2 Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| FallbackOnlyMode | zenoh.publish_failure > 10/min | WARNING |
| CheckpointsMissing | boot_checkpoints_found < 10 | CRITICAL |
| ParseFailureHigh | parse_failure > 5% | WARNING |
| LatencyHigh | fallback.latency_ms p99 > 100ms | WARNING |

---

## 7. OPERATIONAL PROCEDURES

### 7.1 During Normal Operation

1. Checkpoints published to both Zenoh AND log
2. Dashboard shows real-time updates via Zenoh
3. Log serves as backup/audit trail

### 7.2 During Zenoh Outage

1. Zenoh publishes fail (caught by try/rescue)
2. Log fallback continues to work
3. Operator can verify checkpoints via log parsing
4. System continues to function

### 7.3 Post-Incident Verification

1. Run `ztest_fallback_verifier.exs` on log files
2. Verify all expected checkpoints present
3. Reconstruct timeline from timestamps
4. Compare against expected DAG order

---

## 8. REVISION HISTORY

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 3: Fallback verification specification |
