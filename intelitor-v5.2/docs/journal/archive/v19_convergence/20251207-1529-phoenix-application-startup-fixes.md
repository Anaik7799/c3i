# Phoenix Application Startup Fixes

**Date**: 2025-12-07 15:29 CET
**Author**: Claude Code (Opus 4.5)
**Status**: COMPLETED

## Overview

Successfully started the Indrajaal Phoenix application locally with database services running in containers. Fixed several runtime errors that prevented proper application startup.

## Infrastructure Status

| Service | Type | Status | Port | Details |
|---------|------|--------|------|---------|
| TimescaleDB | Container | Running | 5433 | PostgreSQL 17.6, container `indrajaal-timescaledb-demo` |
| Redis | Container | Running | 6379 | Container `indrajaal-redis-demo` |
| Phoenix | Local | Running | 4000 | HTTP 200 OK verified |

## Issues Fixed

### 1. Missing ErrorHTML Module

**Error**:
```
no "500" html template defined for IndrajaalWeb.ErrorHTML (the module does not exist)
```

**Root Cause**: Phoenix endpoint configuration referenced `IndrajaalWeb.ErrorHTML` but the module was missing.

**Fix**: Created `lib/indrajaal_web/controllers/error_html.ex`:
```elixir
defmodule IndrajaalWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.
  """
  use IndrajaalWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
```

Also created `lib/indrajaal_web/controllers/error_json.ex` for JSON error responses:
```elixir
defmodule IndrajaalWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
```

### 2. ArithmeticError in OpenTelemetryContext Plug

**Error**:
```
(ArithmeticError) bad argument in arithmetic expression
    :erlang.-(-576460734259304022, nil)
```

**Location**: `lib/indrajaal_web/plugs/opentelemetry_context.ex:97`

**Root Cause**: The plug attempted to calculate request duration using `conn.private[:req_start_time]` without checking if it was set. When `req_start_time` was `nil`, the arithmetic operation failed.

**Fix**: Added nil check before telemetry execution (lines 94-108):
```elixir
# Record custom metrics (only if start time was recorded)
req_start_time = conn.private[:req_start_time]

if req_start_time do
  :telemetry.execute(
    [:indrajaal, :http, :request],
    %{duration: System.monotonic_time() - req_start_time},
    %{
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      tenant_id: get_tenant_id(conn)
    }
  )
end
```

## Files Modified

| File | Action | Description |
|------|--------|-------------|
| `lib/indrajaal_web/controllers/error_html.ex` | Created | HTML error handler module |
| `lib/indrajaal_web/controllers/error_json.ex` | Created | JSON error handler module |
| `lib/indrajaal_web/plugs/opentelemetry_context.ex` | Modified | Added nil check for req_start_time |

## Verification

```bash
# Server responds with HTTP 200
curl -sI http://localhost:4000/
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
```

## Related Components

- **OpenTelemetry Integration**: Full OTEL instrumentation initialized (Phoenix, Ecto, Oban, Finch)
- **Telemetry Handlers**: Multiple domain-specific handlers attached (alarms, access-control, etc.)
- **TLS Certificates**: 150 CA certificates loaded from OTP store

## Known Warnings (Non-blocking)

1. **Logger backends deprecation**: `:backends` key for `:logger` application is deprecated
2. **Local function handlers**: Telemetry handlers using local functions (performance note)
3. **JavaScript build**: Missing `chart.js/auto` and `chartjs-adapter-date-fns` (frontend assets)

## Next Steps

1. Consider fixing the JavaScript dependencies for chart functionality
2. Update logger configuration to use new pattern (remove `:backends` key)
3. Consider refactoring telemetry handlers to use module functions for better performance

---

**Document Status**: Verified working as of 2025-12-07 15:29 CET
