# OpenRouter Integration & Token Optimization Strategy

**Status**: ACTIVE
**Objective**: Integrate Claude/Gemini via OpenRouter with < 10% budget waste.

## 1. Model Tiering Strategy

We categorize tasks to assign the lowest-cost model capable of solving it.

| Tier | Model ID | Cost (Input/Output per 1M) | Use Case |
| :--- | :--- | :--- | :--- |
| **Tier 0 (Reflex)** | `local/llama3` | $0.00 / $0.00 | Filtering, Summarization, Basic Logic |
| **Tier 1 (Fast)** | `google/gemini-flash-1.5-8b` | $0.03 / $0.15 | Log Analysis, Context Retrieval, First-pass Fixes |
| **Tier 2 (Logic)** | `anthropic/claude-3.5-sonnet` | $3.00 / $15.00 | Architecture, Complex Code Gen, Security Audit |
| **Tier 3 (Deep)** | `openai/o1-preview` (Optional) | $15.00 / $60.00 | 5-Level RCA (Rare usage) |

## 2. Token Caching Architecture

We utilize **Ephemeral Context Caching** to reduce input costs by ~90% for repetitive tasks.

### 2.1 The Prompt Structure
To maximize cache hits, prompts MUST follow this immutable order:

1.  **Static System Prompt** (SOPv5.11 Rules, STAMP Constraints) -> `[CACHE_CONTROL]`
2.  **Static Codebase Map** (File structure, Core module definitions) -> `[CACHE_CONTROL]`
3.  **Dynamic Context** (Specific file contents for this task)
4.  **User Instruction** (The specific request)

### 2.2 OpenRouter Headers for Caching
When sending requests to OpenRouter for Anthropic models:

```json
"messages": [
  {
    "role": "system",
    "content": [
      {
        "type": "text",
        "text": "You are Indrajaal...",
        "cache_control": {"type": "ephemeral"}
      }
    ]
  }
]
```

## 3. Cost Control Gates

### 3.1 The "Local Filter" Pattern
Before calling `open_router_client.chat()`, the `Synapse` MUST:
1.  Run `Indrajaal.Unicon.Scanner` on logs.
2.  If log > 100 lines, use `LocalModel` to summarize.
3.  Only send the summary + relevant lines.

### 3.2 Hard Budget Limits
The `OpenRouterClient` module maintains a local counter (ETS table).
*   **Daily Limit**: $2.00 (Configurable)
*   **Action**: If limit reached, switch all calls to `LocalModel` automatically.

## 4. Configuration

```elixir
# config/runtime.exs
config :indrajaal, :ai,
  openrouter_key: System.get_env("OPENROUTER_API_KEY"),
  site_url: "https://indrajaal.dev",
  app_name: "Indrajaal SCS"
```
