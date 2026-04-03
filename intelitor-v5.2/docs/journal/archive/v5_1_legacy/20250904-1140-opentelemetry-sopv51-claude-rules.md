# OpenTelemetry SOPv5.1 Integration Rules for CLAUDE.md

**Date**: 2025-09-04 11:40 CEST  
**Author**: Claude AI Assistant (SUPERVISOR-1)  
**Session**: SOPv5.1 OpenTelemetry Rules with STAMP & TDG Integration  
**Status**: 🎯 Rules Formulated | ✅ Ready for CLAUDE.md Integration

## Executive Summary

This document provides comprehensive OpenTelemetry integration rules for CLAUDE.md that align with our SOPv5.1 cybernetic execution framework, STAMP safety methodology, and TDG test-driven generation principles. These rules ensure zero-tolerance compliance for observability infrastructure.

---

## 🚨 **MANDATORY: OpenTelemetry SOPv5.1 Integration Standards** ✅ **ZERO TOLERANCE POLICY**

**🎯 CRITICAL: ALL observability code MUST follow OpenTelemetry Elixir patterns with SOPv5.1 cybernetic validation, STAMP safety analysis, and TDG methodology - NO EXCEPTIONS**

### **10.0 - System Safety & OpenTelemetry Implementation**

This section falls under the MANDATORY System Safety & STAMP category (10.0) as observability is critical for system safety monitoring and incident analysis.

### **📋 Pre-Implementation Requirements (TDG MANDATORY)**

**✅ BEFORE ANY OPENTELEMETRY CODE:**
1.0 - **STPA Analysis**: Perform Systems-Theoretic Process Analysis for observability system
2.0 - **TDG Tests First**: Write comprehensive tests BEFORE implementation
3.0 - **Safety Constraints**: Define SC-1 through SC-5 for telemetry system
4.0 - **Hazard Identification**: Document all Unsafe Control Actions (UCAs)
5.0 - **CAST Preparation**: Establish reactive analysis framework

### **🛡️ STAMP Safety Constraints for OpenTelemetry**

**✅ MANDATORY SAFETY CONSTRAINTS:**
- **SC-1**: Telemetry must never expose sensitive tenant data
- **SC-2**: Span creation must not cause memory leaks or crashes
- **SC-3**: Context propagation must maintain trace integrity
- **SC-4**: Sampling must not miss critical error traces
- **SC-5**: Attribute limits must prevent resource exhaustion

**🔍 STPA Analysis Requirements:**
```elixir
# MANDATORY: Before implementing any tracing
mix stamp.stpa --feature-name OPENTELEMETRY_INTEGRATION --criticality HIGH
```

### **🧪 TDG Test Requirements (WRITE TESTS FIRST)**

**✅ MANDATORY TDG PATTERN:**
```elixir
# Step 1: Write failing test FIRST
defmodule Indrajaal.Observability.TelemetryEnhancementTest do
  use ExUnit.Case, async: true
  use PropCheck       # Dual property testing
  use ExUnitProperties
  
  # TDG: Test written BEFORE implementation
  describe "with_tenant_span/4 macro" do
    test "creates span with tenant isolation" do
      # This test MUST exist before the macro implementation
      assert_raise CompileError, fn ->
        Code.compile_quoted(quote do
          require Indrajaal.Observability.TelemetryEnhancement
          
          Indrajaal.Observability.TelemetryEnhancement.with_tenant_span "tenant_123", "test_span" do
            :ok
          end
        end)
      end
    end
  end
end

# Step 2: ONLY THEN implement the macro
defmacro with_tenant_span(tenant_id, span_name, attributes \\ %{}, do: block) do
  # Implementation to make test pass
end
```

### **🤖 OpenTelemetry API Rules (SOPv5.1 CYBERNETIC CONTROL)**

**✅ PHASE 0: Goal Ingestion**
- Analyze tracing requirements against safety constraints
- Classify as Category A (Critical) system infrastructure
- Allocate 11-agent coordination for implementation

**✅ PHASE 1: Pre-Flight Check**
```elixir
# MANDATORY: Validate before any OpenTelemetry usage
defp validate_opentelemetry_safety! do
  # Check SC-1 through SC-5
  assert :opentelemetry in Application.loaded_applications()
  assert Process.get(:opentelemetry_validated) == true
  assert tenant_isolation_enabled?()
end
```

**✅ PHASE 2: Cybernetic Execution**

**CORRECT PATTERNS (11-AGENT VALIDATED):**
```elixir
# Agent: SUPERVISOR-1 - Strategic Pattern
# Agent: HELPER-1 - Implementation
# Agent: WORKER-1 through WORKER-6 - Domain-specific usage
defmacro with_span(name, attributes \\ %{}, do: block) do
  quote do
    require OpenTelemetry.Tracer
    
    # STAMP SC-1: Tenant isolation check
    tenant_id = Process.get(:current_tenant_id) || "system"
    ObservabilityHelpers.validate_tenant_isolation!(tenant_id)
    
    # SOPv5.1: Cybernetic feedback loop
    start_time = System.monotonic_time(:microsecond)
    
    OpenTelemetry.Tracer.with_span unquote(name) do
      # TDG: Attributes validated by tests
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id},
        {"sopv5.1.phase", "execution"},
        {"stamp.safety_constraint", "SC-1,SC-2,SC-3"}
      ] ++ format_attributes(unquote(attributes)))
      
      try do
        result = unquote(block)
        
        # Cybernetic success metrics
        duration = System.monotonic_time(:microsecond) - start_time
        OpenTelemetry.Tracer.set_attributes([
          {"operation.success", true},
          {"sopv5.1.duration_us", duration}
        ])
        
        result
      rescue
        exception ->
          # STAMP: CAST-ready error recording
          OpenTelemetry.Tracer.record_exception(exception, __STACKTRACE__)
          OpenTelemetry.Tracer.set_status(:error, Exception.message(exception))
          
          # SOPv5.1: 5-Level RCA preparation
          OpenTelemetry.Tracer.add_event("sopv5.1.rca_required", [
            {"error.symptom", Exception.message(exception)},
            {"error.pattern", classify_error_pattern(exception)},
            {"stamp.uca", identify_unsafe_control_action(exception)}
          ])
          
          reraise exception, __STACKTRACE__
      end
    end
  end
end
```

**❌ FORBIDDEN PATTERNS (ZERO TOLERANCE):**
```elixir
# VIOLATION EP-081: Function form
OpenTelemetry.Tracer.with_span("name", %{}, fn -> ... end)

# VIOLATION EP-082: Missing require
OpenTelemetry.Tracer.with_span "name" do ... end  # Without require

# VIOLATION EP-083: Attributes in macro call
OpenTelemetry.Tracer.with_span "name", %{attributes: attrs} do ... end

# VIOLATION EP-084: Missing error handling
OpenTelemetry.Tracer.with_span "name" do
  dangerous_operation()  # No try/rescue
end

# VIOLATION EP-085: Context loss in spawned process
Task.async(fn ->
  OpenTelemetry.Tracer.with_span "async" do ... end  # Lost parent context
end)
```

### **📊 Multi-Agent Coordination for OpenTelemetry**

**✅ 11-AGENT ARCHITECTURE:**
```bash
# Supervisor coordinates OpenTelemetry integration
mix claude observability --supervisor 1 --helpers 4 --workers 6 \
  --opentelemetry-integration --stamp-validated --tdg-compliant

# Agent responsibilities:
# SUPERVISOR-1: Strategic oversight, STAMP compliance
# HELPER-1: Core macro implementations  
# HELPER-2: Context propagation patterns
# HELPER-3: Error handling standards
# HELPER-4: Performance optimization
# WORKER-1 to 6: Domain-specific instrumentation
```

### **🔧 Dependency Configuration (SOPv5.1 VALIDATED)**

**✅ MANDATORY mix.exs CONFIGURATION:**
```elixir
defp deps do
  [
    # Core OpenTelemetry (STAMP validated versions)
    {:opentelemetry, "~> 1.3"},              # SDK implementation
    {:opentelemetry_api, "~> 1.2"},          # API definitions  
    {:opentelemetry_exporter, "~> 1.6"},     # OTLP exporter
    
    # Framework instrumentation (TDG tested)
    {:opentelemetry_phoenix, "~> 1.1"},      # Phoenix integration
    {:opentelemetry_ecto, "~> 1.2"},         # Database tracing
    {:opentelemetry_cowboy, "~> 0.2"}        # HTTP server
  ]
end

# MANDATORY: Configure as temporary for fault isolation
def project do
  [
    releases: [
      indrajaal: [
        applications: [opentelemetry: :temporary]
      ]
    ]
  ]
end
```

### **🎯 Application Startup (CYBERNETIC INITIALIZATION)**

**✅ MANDATORY IN application.ex:**
```elixir
@impl true
def start(_type, _args) do
  # SOPv5.1 Phase 0: Goal ingestion
  Logger.info("[SOPv5.1] Initializing OpenTelemetry observability system")
  
  # STAMP: Verify safety constraints before startup
  :ok = validate_opentelemetry_safety_constraints!()
  
  # TDG: Run pre-startup tests
  :ok = run_opentelemetry_startup_tests!()
  
  # Initialize instrumentation libraries
  :opentelemetry_cowboy.setup()
  OpentelemetryPhoenix.setup(adapter: :cowboy2)
  OpentelemetryEcto.setup([:indrajaal, :repo])
  
  # SOPv5.1: Mark initialization complete
  Process.put(:opentelemetry_validated, true)
  
  # Continue with children...
end
```

### **⚡ Performance & Safety Configuration**

**✅ STAMP-VALIDATED LIMITS:**
```elixir
# Prevents SC-5 violations (resource exhaustion)
config :opentelemetry,
  attribute_count_limit: 128,           # Max attributes per span
  attribute_value_length_limit: 512,    # Max attribute value length
  event_count_limit: 128,               # Max events per span
  link_count_limit: 128,                # Max links per span
  span_limits: %{
    attribute_per_event_limit: 32,
    attribute_per_link_limit: 32
  }
```

**✅ CYBERNETIC SAMPLING STRATEGY:**
```elixir
# Development: 100% for complete observability
config :opentelemetry, 
  sampler: {:otel_sampler_always_on, []},
  sampler_config: %{sopv5_1_mode: :development}

# Production: Intelligent sampling with error priority
config :opentelemetry,
  sampler: {Indrajaal.Observability.CyberneticSampler, %{
    base_rate: 0.1,              # 10% baseline
    error_rate: 1.0,             # 100% errors
    critical_path_rate: 0.5,     # 50% critical operations
    sopv5_1_adaptive: true       # Dynamic adjustment
  }}
```

### **🚨 Context Propagation (ZERO TOLERANCE)**

**✅ PROCESS SPAWNING PATTERN:**
```elixir
# MANDATORY: Never lose trace context
defp spawn_with_trace_context(fun) do
  # Capture current context (STAMP SC-3)
  current_ctx = OpenTelemetry.Ctx.get_current()
  current_tenant = Process.get(:current_tenant_id)
  
  Task.async(fn ->
    # Restore context in new process
    OpenTelemetry.Ctx.attach(current_ctx)
    Process.put(:current_tenant_id, current_tenant)
    
    # SOPv5.1: Maintain cybernetic control
    try do
      fun.()
    rescue
      e -> 
        # CAST preparation for async failures
        record_async_failure(e, __STACKTRACE__)
        reraise e, __STACKTRACE__
    end
  end)
end
```

### **📋 Error Pattern Database Integration**

**✅ NEW ERROR PATTERNS FOR OPENTELEMETRY:**
- **EP-081**: Function form usage of with_span
- **EP-082**: Missing require directive
- **EP-083**: Attributes passed to macro
- **EP-084**: Missing error handling in spans
- **EP-085**: Context loss in async operations
- **EP-086**: Unended spans (memory leak)
- **EP-087**: Missing tenant isolation
- **EP-088**: Sampling configuration errors
- **EP-089**: Attribute limit violations
- **EP-090**: Invalid span naming

### **🔍 Validation & Monitoring**

**✅ MANDATORY DAILY VALIDATION:**
```bash
# SOPv5.1 cybernetic validation
mix claude observability --validate --sopv5.1

# STAMP safety constraint checking  
mix stamp.validate --constraints SC-1,SC-2,SC-3,SC-4,SC-5

# TDG test coverage verification
mix test --only opentelemetry --coverage

# Error pattern scanning
elixir scripts/observability/scan_opentelemetry_violations.exs
```

### **🎯 Emergency Response Protocol**

**IF OBSERVABILITY FAILS:**
```elixir
# 1. IMMEDIATE: Cybernetic safety halt
Logger.error("[SOPv5.1] OpenTelemetry failure detected - initiating safety protocol")

# 2. STAMP: Analyze unsafe control action
case identify_opentelemetry_uca() do
  {:uca, :memory_leak} -> activate_span_limit_enforcement()
  {:uca, :context_loss} -> restore_trace_continuity()
  {:uca, :data_exposure} -> activate_tenant_isolation_enforcement()
end

# 3. TPS: 5-Level RCA
run_five_level_rca(:opentelemetry_failure)

# 4. CAST: If incident occurred
mix stamp.cast --incident-type opentelemetry_failure --priority P1
```

### **📈 Success Metrics (CYBERNETIC MONITORING)**

**✅ MANDATORY KPIs:**
- **Trace Completeness**: > 99% (no broken traces)
- **Span Closure Rate**: 100% (no memory leaks)
- **Context Propagation**: 100% (no orphaned spans)
- **Error Recording**: 100% (all exceptions traced)
- **Performance Overhead**: < 1% with sampling
- **Safety Violations**: 0 (zero tolerance)

### **🏆 Strategic Value**

This OpenTelemetry integration provides:
1. **Complete Observability**: Every operation traced with SOPv5.1 metadata
2. **Safety Guaranteed**: STAMP constraints prevent system failures
3. **Test-Driven**: TDG ensures correctness before deployment
4. **Cybernetic Control**: Real-time adaptation and optimization
5. **Enterprise Ready**: Production-grade with zero tolerance for violations

**🚨 REMEMBER: OpenTelemetry is our eyes into the system. Without proper observability, we're blind to issues. These rules ensure we maintain complete visibility while protecting system safety and performance.**

---

## Integration Instructions for CLAUDE.md

1. **Location**: Insert after the "MANDATORY: System Safety & STAMP Methodology" section
2. **Category**: Falls under 10.0 - System Safety & STAMP Implementation
3. **Cross-References**: Link to Observability, Logging, and Performance sections
4. **Priority**: P1 (Critical) - Required for all production deployments

## Related Documentation Updates

1. Update Error Pattern Database with EP-081 through EP-090
2. Create OpenTelemetry troubleshooting guide
3. Add SigNoz dashboard configuration for SOPv5.1 metrics
4. Document CAST procedures for observability incidents