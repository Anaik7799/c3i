# Metabolic Reporting Journal: AI Token Utilization
**Project**: Indrajaal SIL-6
**Mandate**: Periodic 15-minute reporting of AI token state and headroom.

## Metabolic State Matrix (Estimated)

| Entity | Primary Model | Current Utilization | Headroom | Status |
|---|---|---|---|---|
| **Claude** | `anthropic/claude-3.5-sonnet` | 8.5M tokens / 10M | 1.5M tokens | **AMBER** |
| **Gemini** | `google/gemini-2.0-pro-exp` | 2.1M tokens / 10M | 7.9M tokens | **GREEN** |
| **OpenRouter** | Multi-Provider (Global) | $4.25 / $10.00 | $5.75 | **GREEN** |

## Pulse History (2026-03-25)

| Timestamp | Load Avg | Total Cost | Report Key |
|---|---|---|---|
| 14:15 CEST | 1.00 | $4.25 | `indrajaal/metabolic/status` |
| 14:30 CEST | 1.05 | $4.30 | `indrajaal/metabolic/status` |

## Operating Rules (Metabolic Reporting)
1. **Pulse Frequency**: MUST report every 15 minutes.
2. **Backpressure Awareness**: If headroom for Claude reaches < 10%, Gemini SHALL take over all high-complexity synthesis tasks to preserve the budget.
3. **Data Source**: Current state is derived from `PricingMetrics` Prometheus telemetry and observer log inference.
