---
name: impact
description: 1st-5th order cascade impact analysis with Zenoh topology and Sentinel health context
---
---

# Impact Analysis Command (SC-CHG-002)

Multi-order cascade analysis with live system telemetry from Zenoh mesh.

## Usage
```
/impact lib/indrajaal/cockpit/prajna/guardian_integration.ex
/impact Indrajaal.Safety.Sentinel
/impact "alarm storm handling"
```

## Analysis Levels
1. **1st Order**: Direct callers and immediate effects
2. **2nd Order**: Caller cascade within domain
3. **3rd Order**: Cross-domain effects (30 Ash domains)
4. **4th Order**: System-wide (50 agents, 15 containers)
5. **5th Order**: Ecosystem/Federation effects

## Fractal Scale (L0-L7)
L0: Function → L1: Module → L2: Domain → L3: Holon → L4: Container → L5: Node → L6: Cluster → L7: Federation

## Steps
1. Read target: $ARGUMENTS
2. Find direct callers with Grep
3. Map domain boundaries (30 domains)
4. Trace supervision tree impact
5. **Live system context via MCP**:
   - System health: `sentinel(action: "health")` — baseline health context
   - Active threats: `sentinel(action: "threats")` — any threats this change could trigger
   - Zenoh topology: `zenoh_query(action: "metrics")` — mesh state
   - Subscribe to related topics: `zenoh_sub(action: "subscribe", key: "indrajaal/{domain}/**")` — observe live data flow
6. Assess cluster/federation effects (L6-L7)
7. Generate impact report with STAMP constraint mapping

## 4-Layer Impact Matrix (SC-CHG-IMPACT)
| Layer | Scope | Assessment |
|-------|-------|------------|
| L1-CODE | Files, functions, types | Direct changes |
| L2-DOMAIN | Ash resources, business rules | Domain logic |
| L3-SYSTEM | Containers, ports, configs | Infrastructure |
| L4-ECOSYSTEM | CI/CD, docs, tests, federation | External |

## Impact Severity Score
```
Score = Σ(Layer_i × Severity_i)
  L1: ×1, L2: ×2, L3: ×3, L4: ×4
  0-10: LOW → Standard review
  11-20: MEDIUM → Senior review
  21-30: HIGH → Architecture review
  31+: CRITICAL → Guardian approval
```

## Zenoh Data Flow Impact
When changing modules that participate in Zenoh pub/sub:
- Identify affected topic key expressions
- Map publishers and subscribers
- Assess message format compatibility
- Verify FIFO ordering preservation (SC-ZTEST-012)

## Mathematical Foundation

**Impact Score** (4-layer weighted):

$$I_{total} = \sum_{l=1}^{4} w_l \cdot S_l, \quad w = (1, 2, 3, 4)$$

**Cascade Probability** (5-order chain):

$$P(\text{5th order}) = \prod_{i=1}^{5} P(\text{order}_i | \text{order}_{i-1})$$

**Blast Radius** (graph-theoretic):

$$R(v) = |\{u \in V : \text{dist}(v, u) \leq k\}|, \quad k = \text{cascade depth}$$

**Change Entropy**:

$$H(\Delta) = -\sum_{f \in \text{files}} p_f \log_2 p_f \text{ bits}$$

Higher entropy = more dispersed change = higher risk.

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-CHG-001 | Structured change notes |
| SC-CHG-002 | 4-layer impact analysis MANDATORY |
| SC-CHG-008 | Impact score > 20 requires architecture review |
| SC-FUNC-003 | Rollback path MUST exist for every change |
| SC-REG-001 | All state mutations via append-only register |
| SC-CONST-001 | Constitutional check BEFORE reconfiguration |
| SC-PROM-001 | Proof token required for mutations |

## Output
- Caller cascade tree (5 orders)
- Domain impact matrix (30 domains)
- Agent/container effects (50 agents, 15 containers)
- Live health context from Sentinel
- Zenoh topology impact
- STAMP constraint mapping
- Recommended mitigations with priority
