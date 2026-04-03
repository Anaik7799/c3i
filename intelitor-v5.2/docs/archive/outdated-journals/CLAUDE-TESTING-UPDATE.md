# CLAUDE-TESTING.md Updates for Mix Integration

## Key Changes Required

### 1. Replace Script Execution with Mix Commands

**OLD:**
```bash
./test_alarm_compliance.exs
./run_tests.exs
./scripts/run-test-cluster.sh
```

**NEW:**
```bash
mix test
mix test.coverage
mix test.coverage --html
mix test --only integration
```

### 2. Test File Locations

**OLD:**
```elixir
File.write!("test_alarm_compliance.exs", test_content)
```

**NEW:**
```elixir
File.write!("test/indrajaal/alarms/compliance_test.exs", test_content)
```

### 3. Test Organization

All tests should follow Mix/ExUnit conventions:
- Unit tests: `test/indrajaal/domain_name/`
- Integration tests: `test/integration/`
- Web tests: `test/indrajaal_web/`
- Support files: `test/support/`

### 4. Running Specific Test Types

**OLD:**
```bash
# Run specific test script
./test_performance.exs
```

**NEW:**
```bash
# Using tags
mix test --only performance
mix test --only security
mix test --only integration

# Run specific file
mix test test/indrajaal/alarms/alarm_event_test.exs

# Run specific test
mix test test/indrajaal/alarms/alarm_event_test.exs:45
```

### 5. Test Configuration

Add to `config/test.exs`:
```elixir
# Tag configuration
config :indrajaal, :test_tags,
  integration: :skip,
  performance: :skip,
  security: :include

# Test cluster configuration
config :indrajaal, :test_cluster,
  nodes: 3,
  vm_memory: "2048",
  network: "test-bridge"
```

### 6. Mix Aliases for Testing

Add to `mix.exs`:
```elixir
defp aliases do
  [
    "test.all": ["test", "test --only integration"],
    "test.security": ["test --only security"],
    "test.performance": ["test --only performance"],
    "test.cluster": ["cmd scripts/testing/run-cluster-tests.sh"]
  ]
end
```

### 7. Script Organization

Move test scripts to proper locations:
- Cluster setup scripts → `scripts/testing/`
- Test utilities → `test/support/`
- One-time test scripts → Archive or convert to Mix tasks

### 8. Coverage Integration

**OLD:**
```bash
# Manual coverage calculation
```

**NEW:**
```bash
# Integrated with ExCoveralls
mix test.coverage
mix coveralls.html
mix coveralls.github
```

### 9. Documentation Updates

Update all references from:
- `Create test script` → `Create test file`
- `./test_*.exs` → `mix test`
- Script paths → Test file paths in `test/`

### 10. VM Test Integration

Keep VM scripts but integrate with Mix:
```elixir
defmodule Mix.Tasks.Test.Cluster do
  use Mix.Task

  def run(_) do
    System.cmd("scripts/testing/start-test-cluster.sh", [])
    Mix.Task.run("test", ["--only", "cluster"])
    System.cmd("scripts/testing/stop-test-cluster.sh", [])
  end
end
```