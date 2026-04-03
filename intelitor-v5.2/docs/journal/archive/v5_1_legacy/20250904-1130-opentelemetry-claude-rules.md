# OpenTelemetry Integration Rules for CLAUDE.md

**Date**: 2025-09-04 11:30 CEST  
**Author**: Claude AI Assistant (SUPERVISOR-1)  
**Session**: Converting OpenTelemetry Guidelines to CLAUDE.md Rules  
**Status**: 🎯 Rules Ready for Integration

## Proposed CLAUDE.md Rules Section

### 🚨 **MANDATORY: OpenTelemetry Integration Standards** ✅ **ZERO TOLERANCE POLICY**

**🎯 CRITICAL: ALL observability and tracing code MUST follow official OpenTelemetry Elixir patterns - NO EXCEPTIONS**

#### **OpenTelemetry API Usage Rules (MANDATORY COMPLIANCE)**

**✅ REQUIRED PATTERNS:**
1.0 - **Macro Usage**: OpenTelemetry.Tracer.with_span is a MACRO, not a function
2.0 - **Block Syntax**: MUST use block form: `with_span "name" do ... end`
3.0 - **Require Directive**: ALWAYS use `require OpenTelemetry.Tracer` before usage
4.0 - **Attribute Setting**: Set attributes INSIDE spans using `set_attributes/1`
5.0 - **Error Handling**: ALWAYS record exceptions and set error status
6.0 - **Context Propagation**: MUST propagate context across process boundaries
7.0 - **Span Lifecycle**: ALWAYS end spans, even in error cases

**❌ ABSOLUTELY FORBIDDEN:**
1.0 - **Function Form**: VIOLATION - Never use `with_span("name", %{}, fn -> ... end)`
2.0 - **Attribute Arguments**: VIOLATION - Never pass attributes to with_span macro
3.0 - **Missing Require**: VIOLATION - Using Tracer without require statement
4.0 - **Unended Spans**: VIOLATION - Leaving spans open causes memory leaks
5.0 - **Context Loss**: VIOLATION - Spawning processes without context propagation
6.0 - **Silent Errors**: VIOLATION - Not recording exceptions in spans
7.0 - **Wrong API**: VIOLATION - Using deprecated or incorrect API methods

#### **Correct Implementation Patterns (MANDATORY)**

**✅ BASIC SPAN CREATION:**
```elixir
require OpenTelemetry.Tracer

OpenTelemetry.Tracer.with_span "operation_name" do
  # Your code here
  result = perform_work()
  
  # Set attributes inside the span
  OpenTelemetry.Tracer.set_attributes([
    {"custom.attribute", "value"},
    {"operation.type", "background_job"}
  ])
  
  result
end
```

**✅ ERROR HANDLING PATTERN:**
```elixir
require OpenTelemetry.Tracer

OpenTelemetry.Tracer.with_span "risky_operation" do
  try do
    perform_operation()
  rescue
    exception ->
      # MANDATORY: Record the error
      OpenTelemetry.Tracer.record_exception(exception, __STACKTRACE__)
      OpenTelemetry.Tracer.set_status(:error, Exception.message(exception))
      
      # MANDATORY: Add error attributes
      OpenTelemetry.Tracer.set_attributes([
        {"error.type", inspect(exception.__struct__)},
        {"error.message", Exception.message(exception)}
      ])
      
      reraise exception, __STACKTRACE__
  end
end
```

**✅ CUSTOM MACRO PATTERN:**
```elixir
defmacro with_custom_span(name, do: block) do
  quote do
    require OpenTelemetry.Tracer
    
    OpenTelemetry.Tracer.with_span unquote(name) do
      # Set attributes first
      OpenTelemetry.Tracer.set_attributes([
        {"service.name", "indrajaal"},
        {"custom.attribute", "value"}
      ])
      
      # Execute block
      unquote(block)
    end
  end
end
```

#### **Context Propagation Rules (ZERO TOLERANCE)**

**✅ PROCESS SPAWNING:**
```elixir
# MANDATORY: Capture context before spawning
current_ctx = OpenTelemetry.Ctx.get_current()

Task.async(fn ->
  # MANDATORY: Attach context in new process
  OpenTelemetry.Ctx.attach(current_ctx)
  
  # Continue with traced operations
  perform_async_work()
end)
```

**✅ HTTP PROPAGATION:**
```elixir
# Extract context from incoming request
ctx = OpenTelemetry.Ctx.extract(conn.req_headers)
OpenTelemetry.Ctx.attach(ctx)

# Inject context into outgoing request
headers = OpenTelemetry.Ctx.inject([])
HTTPoison.get(url, headers)
```

#### **Dependency Configuration (MANDATORY)**

**✅ REQUIRED IN mix.exs:**
```elixir
defp deps do
  [
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:opentelemetry_phoenix, "~> 1.1"},
    {:opentelemetry_ecto, "~> 1.2"}
  ]
end
```

**✅ REQUIRED IN application.ex:**
```elixir
def start(_type, _args) do
  # MANDATORY: Setup instrumentation
  :opentelemetry_cowboy.setup()
  OpentelemetryPhoenix.setup(adapter: :cowboy2)
  OpentelemetryEcto.setup([:indrajaal, :repo])
  
  # ... rest of startup
end
```

#### **Naming Conventions (ENFORCED)**

**✅ SPAN NAMING:**
- Use lowercase with dots: `http.request`, `db.query`, `cache.get`
- Use domain prefixes: `alarms.process`, `devices.update`
- Be specific but concise: `user.authentication.oauth`

**✅ ATTRIBUTE NAMING:**
- Follow OpenTelemetry semantic conventions
- Use prefixes for custom attributes: `indrajaal.tenant_id`
- Keep attribute keys lowercase with dots or underscores

#### **Performance & Safety Rules**

**✅ MANDATORY LIMITS:**
```elixir
config :opentelemetry,
  attribute_count_limit: 128,
  attribute_value_length_limit: 512,
  event_count_limit: 128,
  link_count_limit: 128
```

**✅ SAMPLING STRATEGY:**
```elixir
# Development: 100% sampling
config :opentelemetry, sampler: {:otel_sampler_always_on, []}

# Production: 10% sampling
config :opentelemetry, sampler: {:otel_sampler_trace_id_ratio, %{ratio: 0.1}}
```

#### **Validation Commands (MANDATORY USAGE)**

```bash
# Validate OpenTelemetry integration
elixir scripts/observability/validate_opentelemetry_integration.exs

# Check for API misuse patterns
elixir scripts/observability/opentelemetry_api_checker.exs

# Verify context propagation
elixir scripts/observability/trace_context_validator.exs
```

#### **Common Violations & Fixes**

**❌ VIOLATION 1: Function form usage**
```elixir
# WRONG
OpenTelemetry.Tracer.with_span("operation", %{attrs: attrs}, fn ->
  work()
end)

# CORRECT
require OpenTelemetry.Tracer
OpenTelemetry.Tracer.with_span "operation" do
  OpenTelemetry.Tracer.set_attributes(attrs)
  work()
end
```

**❌ VIOLATION 2: Missing error handling**
```elixir
# WRONG
OpenTelemetry.Tracer.with_span "operation" do
  risky_operation()  # No error handling
end

# CORRECT
OpenTelemetry.Tracer.with_span "operation" do
  try do
    risky_operation()
  rescue
    e ->
      OpenTelemetry.Tracer.record_exception(e, __STACKTRACE__)
      OpenTelemetry.Tracer.set_status(:error, Exception.message(e))
      reraise e, __STACKTRACE__
  end
end
```

#### **Quality Standards (ZERO TOLERANCE)**

- **100% Span Closure**: All opened spans must be closed
- **Error Recording**: All exceptions must be recorded in spans
- **Context Continuity**: No broken traces due to context loss
- **Attribute Compliance**: All attributes follow naming conventions
- **Performance Impact**: < 1% overhead with proper sampling

**🚨 REMEMBER: OpenTelemetry integration is critical for production observability. Violations compromise our ability to debug and monitor the system.**

---

## Integration Instructions

To add these rules to CLAUDE.md:

1. Insert after the existing "MANDATORY" sections
2. Place before the "Key Design Principles" section
3. Update the table of contents if applicable
4. Add cross-references to related sections (Observability, Logging)

## Key Benefits

1. **Clarity**: Developers know exactly how to use OpenTelemetry correctly
2. **Consistency**: All code follows the same patterns
3. **Safety**: Prevents common mistakes that break tracing
4. **Performance**: Ensures efficient span usage and sampling
5. **Debugging**: Proper traces make production issues easier to solve

## Related Updates

Consider also adding:
- OpenTelemetry troubleshooting guide
- Integration test requirements for traces
- SigNoz dashboard configuration rules
- Performance monitoring thresholds