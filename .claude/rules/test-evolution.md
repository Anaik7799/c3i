---
paths: lib/indrajaal/cockpit/prajna/biomorphic_test_evolution.ex, lib/cepaf/src/Cepaf/Cockpit/FractalTestRunner.fs, lib/indrajaal/ai/**/*.ex
---
# Biomorphic Test Evolution Rules
# Overview
OpenRouter-integrated AI-powered test evolution system with biomorphic lifecycle.
Tests evolve autonomously using free AI models with OODA cycles and fractal structure.
# STAMP Constraints (Test Evolution)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-TEST-EVO-001 | OODA cycle for test evolution < 30s | HIGH |
| SC-TEST-EVO-002 | Fitness tracking MANDATORY (coverage, pass rate, mutation score) | CRITICAL |
| SC-TEST-EVO-003 | All 5 fractal levels MUST be generated | CRITICAL |
| SC-TEST-EVO-004 | Free AI models preferred for cost efficiency | HIGH |
| SC-TEST-EVO-005 | Genome evolution respects diversity floor (0.3) | MEDIUM |
| SC-TEST-EVO-006 | TrainingGym integration for learning feedback | HIGH |
| SC-TEST-EVO-007 | Zenoh publishing for test metrics telemetry | MEDIUM |
# STAMP Constraints (OpenRouter Integration)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-OPENROUTER-001 | Free models MUST be prioritized | HIGH |
| SC-OPENROUTER-002 | Rate limiting with exponential backoff | CRITICAL |
| SC-OPENROUTER-003 | Fallback to mock on API unavailable | HIGH |
| SC-OPENROUTER-004 | Max 10 concurrent AI requests | CRITICAL |
| SC-OPENROUTER-005 | Context window < 4K tokens per request | HIGH |
# Free AI Models by Purpose
```elixir
@free_models %{
property_gen:   "meta-llama/llama-3.1-8b-instruct:free",
code_analysis:  "google/gemma-2-9b-it:free",
bdd_gen:        "mistralai/mistral-7b-instruct:free",
fmea_analysis:  "qwen/qwen-2-7b-instruct:free",
formal_verify:  "meta-llama/llama-3.1-8b-instruct:free"
}
```
# Biomorphic Lifecycle
# 1. Genome (Configuration)
```elixir
%Genome{
mutation_rate: 0.1,        # Probability of test mutation
selection_pressure: 0.7,   # Keep top 70% of tests
crossover_rate: 0.3,       # Gene combination rate
ai_model_weights: %{...},  # Model selection weights
target_coverage: 0.95      # Target code coverage
}
```
# 2. Phenotype (Tests)
- Generated tests across 5 levels
- Compiled test modules
- Executable test suites
# 3. Fitness Function
```elixir
fitness =
(coverage_weight * coverage_score) +
(pass_weight * pass_rate) +
(mutation_weight * mutation_score) +
(diversity_weight * diversity_score)
# Default weights: 0.3, 0.3, 0.2, 0.2
```
# 4. Selection
- Keep tests with fitness > median
- Elite preservation for top 10%
- Roulette wheel for remaining slots
# 5. Mutation
- Parameter tweaks (thresholds, values)
- Operator swaps (assertions)
- Boundary exploration
# 6. Reproduction
- Crossover between high-fitness tests
- Combine best features from parents
- Inject novel test patterns
# OODA Cycle for Test Evolution
```
┌─────────────────────────────────────────────────────┐
│                  30-SECOND OODA CYCLE               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  OBSERVE          ORIENT           DECIDE    ACT    │
│  ┌─────┐         ┌─────┐          ┌─────┐  ┌─────┐ │
│  │Watch│──5s────▶│Anal.│───10s───▶│Plan │──▶│Exec │ │
│  │Files│         │Gaps │          │Gen  │  │Test │ │
│  └─────┘         └─────┘          └─────┘  └─────┘ │
│     │                                        │      │
│     └────────────── FEEDBACK ───────────────┘      │
│                                                     │
└─────────────────────────────────────────────────────┘
```
# AOR Rules (Test Evolution)
| ID | Rule |
|----|------|
| AOR-TEST-EVO-001 | Test generation MUST use free AI models first |
| AOR-TEST-EVO-002 | Failed generations recorded in TrainingGym |
| AOR-TEST-EVO-003 | Fitness < 0.5 triggers regeneration |
| AOR-TEST-EVO-004 | OODA cycle runs every 30s when active |
| AOR-TEST-EVO-005 | All 5 levels generated per module |
| AOR-TEST-EVO-006 | Mutation respects STAMP constraints |
| AOR-TEST-EVO-007 | Selection preserves diversity floor |
| AOR-TEST-EVO-008 | Publish metrics to Zenoh indrajaal/test/evolution |
# AOR Rules (OpenRouter)
| ID | Rule |
|----|------|
| AOR-OPENROUTER-001 | Use :free suffix models exclusively |
| AOR-OPENROUTER-002 | Implement exponential backoff on 429 |
| AOR-OPENROUTER-003 | Cache successful generations |
| AOR-OPENROUTER-004 | Log all API calls for audit |
| AOR-OPENROUTER-005 | Fallback to mock for offline development |
# 5-Level Fractal Test Generation
# Level 1: TDG (Property Tests)
- Model: `meta-llama/llama-3.1-8b-instruct:free`
- Output: PropCheck + ExUnitProperties tests
- Focus: Edge cases, invariants, generators
# Level 2: FMEA (Failure Analysis)
- Model: `qwen/qwen-2-7b-instruct:free`
- Output: RPN calculations, failure mode tests
- Focus: Critical paths, safety constraints
# Level 3: Formal (Verification)
- Model: `meta-llama/llama-3.1-8b-instruct:free`
- Output: Dialyzer specs, Quint models
- Focus: Type safety, temporal properties
# Level 4: Graph (Path Analysis)
- Model: `google/gemma-2-9b-it:free`
- Output: Control flow tests, FSM coverage
- Focus: State transitions, code paths
# Level 5: BDD (Integration)
- Model: `mistralai/mistral-7b-instruct:free`
- Output: Gherkin features, step definitions
- Focus: User journeys, acceptance criteria
# Telemetry Events
```elixir
# Test generation started
:telemetry.execute(
[:test_evolution, :generate, :start],
%{module: module_path, level: level},
%{}
)
# Test generation completed
:telemetry.execute(
[:test_evolution, :generate, :complete],
%{duration_ms: elapsed, tokens_used: tokens},
%{module: module_path, level: level, success: true}
)
# OODA cycle completed
:telemetry.execute(
[:test_evolution, :ooda, :complete],
%{cycle_ms: elapsed, mutations: count, fitness: score},
%{}
)
# Evolution epoch completed
:telemetry.execute(
[:test_evolution, :evolve, :epoch],
%{generation: gen, avg_fitness: avg, best_fitness: best},
%{}
)
```
# Zenoh Topics
| Topic | Purpose | Format |
|-------|---------|--------|
| `indrajaal/test/evolution/status` | System status | JSON |
| `indrajaal/test/evolution/fitness` | Fitness metrics | JSON |
| `indrajaal/test/evolution/generations` | Generation count | Integer |
| `indrajaal/test/evolution/coverage` | Coverage percent | Float |
# Integration with TrainingGym
Every test generation records an episode:
```elixir
TrainingGym.record_episode(%{
type: :test_generation,
model: model_name,
level: level,
success: success?,
fitness_delta: before_fitness - after_fitness,
tokens_used: token_count,
latency_ms: generation_time
})
```
# File Locations
```
lib/indrajaal/cockpit/prajna/
├── biomorphic_test_evolution.ex    # Main GenServer
├── smart_test_runner.ex            # Command testing
└── test_evolution_config.ex        # Configuration
lib/cepaf/src/Cepaf/Cockpit/
├── FractalTestRunner.fs            # F# OODA runner
└── TestCockpit.fs                  # F# test cockpit
test/
├── generated/                      # AI-generated tests
│   ├── tdg/                        # Level 1 tests
│   ├── fmea/                       # Level 2 tests
│   ├── formal/                     # Level 3 tests
│   ├── graph/                      # Level 4 tests
│   └── bdd/                        # Level 5 tests
└── evolution/
└── genome_snapshots/           # Genome history
```
# Running Test Evolution
```bash
# Start evolution server
mix test.evolution start
# Generate tests for module
mix test.evolution generate lib/indrajaal/accounts/user.ex
# Run single OODA cycle
mix test.evolution ooda
# Check fitness status
mix test.evolution status
# Evolve current genome
mix test.evolution evolve
```
# FMEA for Evolution Failures
| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| API rate limit | 6 | 4 | 8 | 192 | Exponential backoff |
| Low fitness | 5 | 5 | 3 | 75 | Regeneration trigger |
| Model unavailable | 7 | 2 | 9 | 126 | Fallback to mock |
| Token overflow | 4 | 3 | 7 | 84 | Chunk requests |
| Diversity collapse | 6 | 3 | 5 | 90 | Diversity floor enforcement |
# Constitutional Alignment
Test evolution MUST respect:
- **Ψ₀ (Existence)**: Tests ensure system survival
- **Ψ₁ (Regeneration)**: Tests verify reproducibility
- **Ψ₂ (History)**: Test history preserved in DuckDB
- **Ψ₃ (Verification)**: Tests ARE the verification layer
- **Ψ₄ (Human Alignment)**: Tests protect Founder's interests
- **Ψ₅ (Truthfulness)**: Tests reveal true system state