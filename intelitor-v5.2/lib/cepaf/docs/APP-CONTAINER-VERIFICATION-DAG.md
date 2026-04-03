# App Container Verification DAG
## Detailed Task Graph for Creation, Setup, and Testing
**Version**: 1.0.0 | **Date**: 2024-12-24 | **Status**: ACTIVE

---

## 1. Master Execution DAG

```
                              [START]
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  PHASE_0: PREREQUISITES │
                    └────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P0.1_IMG │          │ P0.2_NET │          │ P0.3_DB  │
    │ Verify   │          │ Create   │          │ Health   │
    │ Image    │          │ Network  │          │ Check    │
    └──────────┘          └──────────┘          └──────────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   PHASE_1: CREATION    │
                    └────────────────────────┘
                                 │
                                 ▼
                         ┌──────────────┐
                         │   P1.1_CNT   │
                         │   Create     │
                         │  Container   │
                         └──────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │    PHASE_2: SETUP      │
                    └────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P2.1_HEX │          │ P2.2_REB │          │ P2.3_DEP │
    │ Install  │          │ Install  │          │ Deps Get │
    │ Hex      │ ────────►│ Rebar    │ ────────►│ Fetch    │
    └──────────┘          └──────────┘          └──────────┘
                                                      │
                                                      ▼
                                               ┌──────────┐
                                               │ P2.4_CMP │
                                               │ Deps     │
                                               │ Compile  │
                                               └──────────┘
                                                      │
                                 ▼─────────────────────
                    ┌────────────────────────┐
                    │  PHASE_3: DATABASE     │
                    └────────────────────────┘
                                 │
                         ┌──────────────┐
                         │  P3.1_CONN   │
                         │  DB Connect  │
                         │  Verify      │
                         └──────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P3.2_CRE │          │ P3.3_MIG │          │ P3.4_SED │
    │ Ecto     │ ────────►│ Ecto     │ ────────►│ Seed     │
    │ Create   │          │ Migrate  │          │ (opt)    │
    └──────────┘          └──────────┘          └──────────┘
                                                      │
                                 ▼─────────────────────
                    ┌────────────────────────┐
                    │ PHASE_4: COMPILATION   │
                    └────────────────────────┘
                                 │
                         ┌──────────────┐
                         │  P4.1_MIX    │
                         │  Mix Compile │
                         │ (949 files)  │
                         └──────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P4.2_AST │          │ P4.3_DIG │          │ P4.4_WAR │
    │ Assets   │          │ Phoenix  │          │ Warning  │
    │ Build    │          │ Digest   │          │ Count    │
    └──────────┘          └──────────┘          └──────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   PHASE_5: STARTUP     │
                    └────────────────────────┘
                                 │
                         ┌──────────────┐
                         │  P5.1_PHX    │
                         │  Phoenix     │
                         │  Server      │
                         └──────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  PHASE_6: HEALTH       │
                    └────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P6.1_TCP │          │ P6.2_HTTP│          │ P6.3_LOG │
    │ Port     │          │ Health   │          │ Pattern  │
    │ 4000     │          │ Endpoint │          │ Match    │
    └──────────┘          └──────────┘          └──────────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  PHASE_7: VERIFICATION │
                    └────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
    ┌──────────┐          ┌──────────┐          ┌──────────┐
    │ P7.1_API │          │ P7.2_OBS │          │ P7.3_E2E │
    │ Endpoint │          │ Telemetry│          │ Full     │
    │ Test     │          │ Verify   │          │ Test     │
    └──────────┘          └──────────┘          └──────────┘
                                 │
                                 ▼
                              [READY]
                         (SIL-2 VERIFIED)
```

---

## 2. Task Definition Table

### Phase 0: Prerequisites
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P0.1_IMG | Image Verify | Verify app image exists | None | 2s | `podman images \| grep sopv51` |
| P0.2_NET | Network Create | Create/verify networks | None | 3s | `podman network ls` |
| P0.3_DB | DB Health | Verify database healthy | None | 5s | `podman wait --condition=healthy` |

### Phase 1: Creation
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P1.1_CNT | Container Create | Create app container | P0.* | 15s | `podman ps \| grep app-standalone` |

### Phase 2: Setup
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P2.1_HEX | Hex Install | Install Hex package manager | P1.1_CNT | 5s | `mix local.hex --force` |
| P2.2_REB | Rebar Install | Install Rebar3 | P2.1_HEX | 3s | `mix local.rebar --force` |
| P2.3_DEP | Deps Get | Fetch all dependencies | P2.2_REB | 30s | `mix deps.get` |
| P2.4_CMP | Deps Compile | Compile dependencies | P2.3_DEP | 120s | `mix deps.compile` |

### Phase 3: Database
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P3.1_CONN | DB Connect | Verify DB connectivity | P2.4_CMP | 5s | `pg_isready -h db -p 5433` |
| P3.2_CRE | Ecto Create | Create database | P3.1_CONN | 10s | `mix ecto.create` |
| P3.3_MIG | Ecto Migrate | Run migrations | P3.2_CRE | 30s | `mix ecto.migrate` |
| P3.4_SED | Seed Data | Optional seed data | P3.3_MIG | 10s | `mix run priv/repo/seeds.exs` |

### Phase 4: Compilation
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P4.1_MIX | Mix Compile | Compile 949 app files | P3.3_MIG | 300s | `mix compile` |
| P4.2_AST | Asset Build | Build JS/CSS assets | P4.1_MIX | 30s | `npm run build` |
| P4.3_DIG | Phoenix Digest | Generate asset digests | P4.2_AST | 10s | `mix phx.digest` |
| P4.4_WAR | Warning Count | Verify 0 warnings | P4.1_MIX | 5s | `grep -c warning compile.log` |

### Phase 5: Startup
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P5.1_PHX | Phoenix Start | Start Phoenix server | P4.3_DIG | 10s | `mix phx.server` |

### Phase 6: Health
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P6.1_TCP | TCP Probe | Port 4000 reachable | P5.1_PHX | 3s | `nc -z localhost 4000` |
| P6.2_HTTP | HTTP Health | Health endpoint 200 | P6.1_TCP | 5s | `curl localhost:4000/health` |
| P6.3_LOG | Log Pattern | Verify startup patterns | P5.1_PHX | 5s | `podman logs \| grep "Running"` |

### Phase 7: Verification
| Task ID | Name | Description | Dependencies | Est. Duration | Verification |
|---------|------|-------------|--------------|---------------|--------------|
| P7.1_API | API Test | Test API endpoints | P6.2_HTTP | 10s | `curl localhost:4000/api/v1/health` |
| P7.2_OBS | Telemetry | Verify OTEL export | P6.2_HTTP | 5s | `curl localhost:9568/metrics` |
| P7.3_E2E | E2E Test | Full integration test | P7.1_API | 30s | DB read/write cycle |

---

## 3. State Transition Graph

```
[ABSENT] ──(P1.1_CNT)──► [CREATED]
    │                        │
    │                   (P2.1-2.4)
    │                        │
    │                        ▼
    │                 [DEPS_COMPILED]
    │                        │
    │                   (P3.1-3.3)
    │                        │
    │                        ▼
    │                  [DB_READY]
    │                        │
    │                   (P4.1-4.4)
    │                        │
    │                        ▼
    │                [APP_COMPILED]
    │                        │
    │                   (P5.1_PHX)
    │                        │
    │                        ▼
    │                  [STARTING]
    │                        │
    │                   (P6.1-6.3)
    │                        │
    │                        ▼
    │                  [HEALTHY]
    │                        │
    │                   (P7.1-7.3)
    │                        │
    │                        ▼
    │                 [SIL_READY]
    │                        │
    │                        ▼
    └────────────────► [VERIFIED]
```

---

## 4. Execution Timeline (Patient Mode)

```
Time (s)  Phase              Task             Status
────────────────────────────────────────────────────────
   0      PREREQUISITES      P0.1_IMG         ✓ Complete
   2      PREREQUISITES      P0.2_NET         ✓ Complete
   5      PREREQUISITES      P0.3_DB          ✓ Complete
  20      CREATION          P1.1_CNT         ✓ Complete
  25      SETUP             P2.1_HEX         ✓ Complete
  28      SETUP             P2.2_REB         ✓ Complete
  58      SETUP             P2.3_DEP         ✓ Complete
 178      SETUP             P2.4_CMP         ✓ Complete
 183      DATABASE          P3.1_CONN        ✓ Complete
 193      DATABASE          P3.2_CRE         ○ In Progress
 223      DATABASE          P3.3_MIG         ○ Pending
 233      DATABASE          P3.4_SED         ○ Pending
 533      COMPILATION       P4.1_MIX         ○ Pending
 563      COMPILATION       P4.2_AST         ○ Pending
 573      COMPILATION       P4.3_DIG         ○ Pending
 578      COMPILATION       P4.4_WAR         ○ Pending
 588      STARTUP           P5.1_PHX         ○ Pending
 591      HEALTH            P6.1_TCP         ○ Pending
 596      HEALTH            P6.2_HTTP        ○ Pending
 601      HEALTH            P6.3_LOG         ○ Pending
 611      VERIFICATION      P7.1_API         ○ Pending
 616      VERIFICATION      P7.2_OBS         ○ Pending
 646      VERIFICATION      P7.3_E2E         ○ Pending
────────────────────────────────────────────────────────
TOTAL ESTIMATED: ~650 seconds (~11 minutes)
```

---

## 5. STAMP Compliance Checkpoints

| Checkpoint | Constraint | Phase | Verification |
|------------|-----------|-------|--------------|
| SC-CNT-009 | NixOS/Podman | P0 | Container runtime check |
| SC-CNT-010 | Localhost registry | P0 | Image source check |
| SC-VAL-001 | Patient Mode | P2-P4 | Environment vars |
| SC-CMP-025 | Zero warnings | P4.4 | Compile log analysis |
| SC-CMP-026 | All files compiled | P4.1 | File count verification |
| SC-DB-001 | Database connectivity | P3.1 | Connection test |
| SC-OBS-069 | Dual logging | P6.3 | Log output check |
| SC-PRF-050 | Response < 50ms | P6.2 | Health latency |

---

## 6. Current Execution Status

### Live Tracking
```bash
# Watch container status
watch -n5 'podman ps -a --filter name=indrajaal-app-standalone --format "table {{.Names}}\t{{.Status}}"'

# Stream logs
podman logs -f indrajaal-app-standalone

# Check compilation progress
podman exec indrajaal-app-standalone sh -c "wc -l /var/log/claude/compile.log 2>/dev/null || echo 'Compiling...'"
```

### Status Query Commands
```bash
# Phase 0: Prerequisites
podman images | grep sopv51 && echo "P0.1_IMG: ✓"
podman network ls | grep standalone && echo "P0.2_NET: ✓"
podman inspect indrajaal-db-standalone --format '{{.State.Health.Status}}' && echo "P0.3_DB: ✓"

# Phase 1-5: Container phases
podman logs indrajaal-app-standalone 2>&1 | grep -E "(Hex/Rebar|Dependencies|Compiling|Starting Phoenix)"

# Phase 6: Health
curl -sf http://localhost:4000/health && echo "P6.2_HTTP: ✓"
```

---

## 7. Failure Recovery Procedures

| Task | Error Type | Recovery Command |
|------|------------|------------------|
| P0.3_DB | DB Not Ready | `podman-compose -f db-standalone.yml up -d && sleep 30` |
| P2.3_DEP | Deps Fetch Fail | `podman exec app mix deps.clean --all && mix deps.get` |
| P4.1_MIX | Compile Error | Check `compile.log`, fix errors, restart container |
| P5.1_PHX | Port Conflict | `podman rm -f app && podman-compose up -d` |
| P6.2_HTTP | Health Timeout | Increase `start_period` in healthcheck |

---

## 8. Verification Script

```bash
#!/bin/bash
# Full DAG Verification Script

echo "=== App Container DAG Verification ==="
echo "Started at: $(date)"

# Phase 0
echo "[P0] Prerequisites..."
podman images | grep -q sopv51 && echo "  P0.1_IMG: ✓" || echo "  P0.1_IMG: ✗"
podman network ls | grep -q standalone && echo "  P0.2_NET: ✓" || echo "  P0.2_NET: ✗"
podman inspect indrajaal-db-standalone --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy && echo "  P0.3_DB: ✓" || echo "  P0.3_DB: ✗"

# Phase 6
echo "[P6] Health..."
curl -sf http://localhost:4000/health >/dev/null && echo "  P6.2_HTTP: ✓" || echo "  P6.2_HTTP: ✗ (container still starting)"

# Summary
echo ""
echo "Container Status:"
podman ps -a --filter name=indrajaal-app-standalone --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "Completed at: $(date)"
```

---

**Document Status**: ACTIVE
**Last Updated**: 2024-12-24
**Related**: TESTSUITE-APP_CONTAINER-Standalone.md
