# STAMP/TDG/GDE Troubleshooting Guide

## Quick Reference

| Issue Category | Quick Fix | Detailed Section |
|----------------|-----------|------------------|
| Compilation Errors | `mix compile --warnings-as-errors` | [Compilation Issues](#compilation-issues) |
| Test Failures | `mix test --verbose` | [Test Issues](#test-issues) |
| Performance Problems | `mix benchmark.compare` | [Performance Issues](#performance-issues) |
| Feature Flag Issues | `mix feature.status` | [Feature Flag Issues](#feature-flag-issues) |
| Monitoring Problems | `mix telemetry.dashboard` | [Monitoring Issues](#monitoring-issues) |

## Common Issues and Solutions

### Compilation Issues

#### Issue: "warnings treated as errors"

**Symptoms:**
```
** (CompileError) warnings treated as errors
```

**Solution:**
```bash
# Check specific warnings
mix compile --warnings-as-errors --verbose

# Fix common patterns
# - Remove unused variables: prefix with _
# - Remove unused functions: add @doc false or remove
# - Fix pattern matching: ensure all cases covered
```

**Prevention:**
- Run `mix compile --warnings-as-errors` before committing
- Use `mix format` to fix formatting issues
- Enable editor warnings

#### Issue: "STAMP/TDG/GDE modules not found"

**Symptoms:**
```
** (UndefinedFunctionError) function Indrajaal.FeatureFlags.enabled?/1 is undefined
```

**Solution:**
```bash
# Check if GenServer is started
mix feature.status

# Start feature flags manually
iex -S mix
iex> {:ok, _} = Indrajaal.FeatureFlags.start_link([])
```

**Prevention:**
- Ensure proper supervision tree setup
- Check `application.ex` includes all modules
- Verify dependencies in `mix.exs`

### Test Issues

#### Issue: Property-based tests failing randomly

**Symptoms:**
```
Property failed after 42 tests
Failed test case: [complex data structure]
```

**Solution:**
```elixir
# Add more specific generators
def my_generator do
  oneof([
    valid_data_generator(),
    edge_case_generator(),
    invalid_data_generator()
  ])
end

# Increase test count for stability
ExUnitProperties.check all data <- my_generator(),
                           max_runs: 1000 do
  # test body
end
```

**Prevention:**
- Test generators thoroughly
- Use `resize/2` for complex data
- Add `max_shrinking_steps` for faster debugging

#### Issue: "TDG validation failed"

**Symptoms:**
```
TDG violation: No tests found for generated code
```

**Solution:**
```bash
# Check which modules lack tests
mix tdg.validate --comprehensive

# Generate test templates
mix tdg.generate --from-spec specs/my_feature.md

# Add missing tests manually
```

**Prevention:**
- Use TDG pre-commit hooks: `mix tdg.enforce --git-hooks install`
- Write tests before implementation
- Monitor coverage: `mix tdg.coverage --watch`

### Performance Issues

#### Issue: STAMP analysis taking too long

**Symptoms:**
- STPA analysis times out
- System becomes unresponsive during analysis

**Solution:**
```bash
# Run analysis with timeout
timeout 300 mix stamp.stpa --domain large_domain

# Use incremental analysis
mix stamp.stpa --domain large_domain --incremental

# Cache results
mix stamp.stpa --domain large_domain --cache
```

**Optimization:**
```elixir
# Limit analysis scope
def analyze_critical_paths_only do
  constraints = get_critical_constraints()
  perform_stpa_analysis(constraints, scope: :critical)
end
```

#### Issue: Dashboard loading slowly

**Symptoms:**
- LiveView dashboard takes >5 seconds to load
- Browser becomes unresponsive

**Solution:**
```elixir
# Implement pagination
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:page, 1)
    |> assign(:per_page, 50)
    |> load_data_paginated()

  {:ok, socket}
end

# Use background updates
def handle_info(:refresh_data, socket) do
  Process.send_after(self(), :refresh_data, 30_000)
  {:noreply, update_metrics_async(socket)}
end
```

### Feature Flag Issues

#### Issue: Feature flags not persisting

**Symptoms:**
- Flags reset after server restart
- Changes not visible across nodes

**Solution:**
```bash
# Check persistence configuration
mix feature.status --verbose

# Export current config
mix feature.export > feature_backup.json

# Import on restart
mix feature.import feature_backup.json
```

**Configuration:**
```elixir
# In config/runtime.exs
config :indrajaal, :feature_flags,
  persistence: :database,  # or :file, :ets
  sync_interval: 30_000
```

#### Issue: Rollout percentage not working

**Symptoms:**
- All users see feature despite low percentage
- Inconsistent feature visibility

**Solution:**
```elixir
# Check hash function
def debug_rollout(user_id, percentage) do
  hash = :erlang.phash2(user_id, 100)
  enabled = hash < percentage
  IO.puts("User #{user_id}: hash=#{hash}, percentage=#{percentage}, enabled=#{enabled}")
  enabled
end

# Use stable user identifier
FeatureFlags.enabled_for?(:feature, %{user_id: user.stable_id})
```

### Monitoring Issues

#### Issue: Telemetry events not appearing

**Symptoms:**
- Dashboard shows no data
- Metrics not updating

**Solution:**
```bash
# Check telemetry handlers
mix telemetry.status

# Test event emission
iex -S mix
iex> :telemetry.execute([:test, :event], %{value: 1}, %{})
```

**Debug telemetry:**
```elixir
# Add debug handler
:telemetry.attach(
  "debug-handler",
  [:stamp, :stpa, :completed],
  fn event, measurements, metadata, _config ->
    IO.inspect({event, measurements, metadata}, label: "Telemetry")
  end,
  nil
)
```

#### Issue: Dashboard not updating

**Symptoms:**
- LiveView shows stale data
- Real-time updates stopped

**Solution:**
```elixir
# Check PubSub subscription
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "metrics")
  end

  {:ok, socket}
end

# Debug PubSub messages
def handle_info(msg, socket) do
  IO.inspect(msg, label: "PubSub received")
  {:noreply, socket}
end
```

### Goal Management Issues

#### Issue: Goals not updating correctly

**Symptoms:**
- Progress tracking fails
- Interventions not triggering

**Solution:**
```bash
# Validate goal configuration
mix gde.goals --verify-definitions

# Check intervention rules
mix gde.interventions --validate --dry-run

# Debug progress calculation
mix gde.progress --goal "my_goal" --debug
```

**Fix calculation:**
```elixir
def calculate_progress(goal, current_value) do
  case goal.target_value do
    0 -> 100.0  # Avoid division by zero
    target ->
      progress = (current_value / target) * 100
      max(0.0, min(100.0, progress))  # Clamp to 0-100%
  end
end
```

## Error Codes Reference

### STAMP Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| STAMP-001 | Invalid safety constraint | Review constraint syntax |
| STAMP-002 | UCA analysis failed | Check domain model |
| STAMP-003 | CAST investigation incomplete | Provide more incident data |

### TDG Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| TDG-001 | No tests found | Write tests before implementation |
| TDG-002 | Coverage below threshold | Add more test cases |
| TDG-003 | Property test failed | Fix generator or implementation |

### GDE Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| GDE-001 | Invalid goal definition | Check SMART criteria |
| GDE-002 | Intervention failed | Review intervention logic |
| GDE-003 | Progress calculation error | Validate input data |

## Performance Tuning

### STAMP Optimization

```elixir
# Cache analysis results
defmodule StampCache do
  use GenServer

  def get_analysis(domain) do
    case :ets.lookup(:stamp_cache, domain) do
      [{^domain, result, timestamp}] ->
        if fresh?(timestamp), do: result, else: nil
      [] -> nil
    end
  end
end

# Parallel analysis
def analyze_domains(domains) do
  domains
  |> Task.async_stream(&perform_stpa_analysis/1, max_concurrency: 4)
  |> Enum.map(fn {:ok, result} -> result end)
end
```

### TDG Optimization

```elixir
# Incremental coverage
def calculate_incremental_coverage(changed_files) do
  changed_files
  |> Enum.map(&get_module_coverage/1)
  |> Enum.reduce(0, &+/2)
end

# Lazy test generation
def generate_tests_lazy(module) do
  Stream.resource(
    fn -> get_functions(module) end,
    fn functions ->
      case functions do
        [] -> {:halt, []}
        [func | rest] -> {[generate_test(func)], rest}
      end
    end,
    fn _ -> :ok end
  )
end
```

### Monitoring Optimization

```elixir
# Batch telemetry events
defmodule TelemetryBatcher do
  use GenServer

  def init(_) do
    :timer.send_interval(1000, :flush)
    {:ok, []}
  end

  def handle_info(:flush, events) do
    emit_batch(events)
    {:noreply, []}
  end
end

# Efficient dashboard updates
def handle_info(:update_dashboard, socket) do
  if socket.assigns.active_tab == :metrics do
    {:noreply, refresh_metrics(socket)}
  else
    {:noreply, socket}
  end
end
```

## Debugging Tools

### Debug Compilation

```bash
# Verbose compilation
mix compile --verbose --warnings-as-errors

# Check specific warnings
mix compile 2>&1 | grep "warning"

# Debug macros
mix compile --force --verbose
```

### Debug Tests

```bash
# Run specific test with debugging
mix test test/specific_test.exs --trace

# Debug property tests
mix test --only property --max-cases 10

# Coverage with debug info
mix test --cover --verbose
```

### Debug Performance

```bash
# Profile memory usage
mix profile.memory

# Profile execution time
mix profile.time

# Benchmark specific functions
mix benchmark --focus "function_name"
```

### Debug Telemetry

```elixir
# List all handlers
:telemetry.list_handlers([])

# Test specific events
:telemetry.test_event([:my, :event], %{value: 1}, %{})

# Debug handler execution
def debug_handler(event, measurements, metadata, _config) do
  IO.puts("Event: #{inspect(event)}")
  IO.puts("Measurements: #{inspect(measurements)}")
  IO.puts("Metadata: #{inspect(metadata)}")
end
```

## Monitoring and Alerting

### Health Checks

```bash
# System health
mix health.check --comprehensive

# Component health
mix health.check --stamp --tdg --gde

# Performance health
mix health.check --performance --threshold 100ms
```

### Log Analysis

```bash
# Filter STAMP logs
grep "STAMP" logs/dev.log

# Filter errors
grep "ERROR" logs/dev.log | grep -E "(STAMP|TDG|GDE)"

# Analyze patterns
awk '/STAMP.*error/ {print $0}' logs/dev.log | sort | uniq -c
```

## Getting Help

### Internal Resources

1. **Documentation**: Check `/docs/stamp_tdg_gde/` directory
2. **Code Examples**: See `test/` directory for usage patterns
3. **Configuration**: Review `config/` files

### Commands for Help

```bash
# General help
mix help

# Specific task help
mix help stamp.stpa
mix help tdg.validate
mix help gde.progress

# Feature status
mix feature.status --verbose
mix health.check --detailed
```

### External Resources

1. **STAMP Methodology**: MIT STAMP website
2. **Property-Based Testing**: PropEr/PropCheck documentation
3. **Phoenix LiveView**: Official Phoenix guides

### Support Checklist

Before requesting help, gather:

1. ✅ Error messages (full stack trace)
2. ✅ System information (`mix --version`, OS, etc.)
3. ✅ Configuration files
4. ✅ Steps to reproduce
5. ✅ Expected vs actual behavior

### Emergency Procedures

#### System Down

1. **Disable all features**: `mix feature.disable --all`
2. **Check logs**: `tail -f logs/prod.log`
3. **Rollback**: Use previous deployment
4. **Monitor**: Watch system metrics

#### Performance Crisis

1. **Identify bottleneck**: `mix profile.memory`
2. **Disable heavy features**: Feature flags
3. **Scale resources**: Add instances
4. **Contact team**: Alert on-call engineer

#### Data Corruption

1. **Stop writes**: Read-only mode
2. **Backup current state**: Database dump
3. **Restore from backup**: Last known good
4. **Investigate**: Root cause analysis

Remember: When in doubt, disable features and investigate safely!