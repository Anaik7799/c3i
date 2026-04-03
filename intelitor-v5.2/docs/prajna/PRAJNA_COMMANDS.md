# Prajna Quick Command Reference

**Version**: 3.1.0-DEVENV | **Tag**: `prajna-cockpit-20251231`
**Status**: FULLY OPERATIONAL

## Quick Start (Recommended)

```bash
# Enter devenv shell
devenv shell

# Start standalone stack
sa-up

# Check status
sa-status

# Start Phoenix (if not in container)
app

# View help
help
```

## Live Endpoints

| Endpoint | URL |
|----------|-----|
| **Main Cockpit** | http://localhost:4000/prajna |
| **AI Copilot** | http://localhost:4000/prajna/copilot |
| **Health** | http://localhost:4000/health |
| **Grafana** | http://localhost:3000 (admin/indrajaal) |
| **Prometheus** | http://localhost:9090 |

## Devenv Commands Reference

### App & Server
| Command | Description |
|---------|-------------|
| `app` | Start Phoenix server |
| `app-start` | Start containers + Phoenix |
| `app-iex` | Phoenix with IEx console |

### Compilation & Quality
| Command | Description |
|---------|-------------|
| `compile` | Compile with Patient Mode |
| `compile-strict` | Warnings as errors |
| `quality` | Format + Credo |
| `quality-full` | + Dialyzer + Sobelow |

### Testing
| Command | Description |
|---------|-------------|
| `test` | Run tests |
| `test-cover` | With coverage |
| `sa-test` | Runtime tests (swarm) |
| `sa-ux` | UX/UI evaluation |

### Standalone Environment
| Command | Description |
|---------|-------------|
| `sa-up` | Start prod stack (4 containers) |
| `sa-down` | Stop stack |
| `sa-clean` | Stop + remove volumes |
| `sa-status` | Container status |
| `sa-logs [svc]` | Stream logs |
| `sa-db` | DB only |
| `sa-obs` | Observability only |
| `sa-app` | App only |
| `sa-orchestrate` | Test orchestrator |

### CEPAF / F#
| Command | Description |
|---------|-------------|
| `cockpitf [cmd]` | F# Cockpit ops |
| `cepaf-build` | Build F# projects |

### Database
| Command | Description |
|---------|-------------|
| `db-setup` | Setup database |
| `db-reset` | Reset database |
| `db-migrate` | Run migrations |
| `db-console` | psql console |

## Direct Commands (Without Devenv)

### Compilation
```bash
# Standard compile
mix compile

# Patient mode compile
NO_TIMEOUT=true PATIENT_MODE=enabled mix compile --warnings-as-errors
```

### Prajna Tests
```bash
# All Prajna tests
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/

# Specific components
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/orchestrator_test.exs
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/dark_cockpit_test.exs
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ai_copilot_test.exs
```

### CEPAF (F#)
```bash
# Build
cd lib/cepaf && dotnet build

# Run tests
cd lib/cepaf && dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

# Filter tests
cd lib/cepaf && dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --filter "STAMP"
```

### Containers (Manual)
```bash
# Start standalone stack
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d

# Check status
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml ps

# View logs
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml logs -f indrajaal-ex-app-1

# Stop
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml down
```

### Server
```bash
# Start Phoenix
PHX_SERVER=true PORT=4000 mix phx.server

# With IEx
PHX_SERVER=true PORT=4000 iex -S mix phx.server
```

### Quality
```bash
mix format --check-formatted && mix credo --strict && mix dialyzer
```

## IEx Commands

```elixir
# Check Prajna status
Indrajaal.Cockpit.Prajna.DarkCockpit.get_state()

# Get metrics
Indrajaal.Cockpit.Prajna.SmartMetrics.get_metrics()

# Circuit breaker status
Indrajaal.Cockpit.Prajna.CircuitBreaker.status()

# AI Copilot query
Indrajaal.Cockpit.Prajna.AICopilot.query("system health")
```

## One-Liner Commands

```bash
# Quick start (in devenv)
sa-up && sleep 5 && app

# Full test suite
sa-test && cepaf-build

# Quality gate
quality-full

# Health check
curl -s http://localhost:4000/health | jq '.status'
```

---

**Last Updated**: 2025-12-31
