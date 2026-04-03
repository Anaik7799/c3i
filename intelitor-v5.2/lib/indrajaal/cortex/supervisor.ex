defmodule Indrajaal.Cortex.Supervisor do
  @moduledoc """
  Supervisor for the Autonomic Cortex (Layer C4).

  ## WHAT
  Manages higher-order cognitive functions including self-healing, prediction,
  and the FastOODA loop for Cybernetically Augmented Evolution (CAE).

  ## WHY
  The Cortex requires supervised cognitive components for autonomous operation.
  FastOODA enables 50ms cycle times for rapid system adaptation (SC-OODA-001).

  ## CONSTRAINTS
  - SC-CTX-001: All cognitive components must be supervised
  - SC-CTX-002: FastOODA starts for CAE operation when enabled (config-driven)
  - SC-CTX-003: Self-healing takes priority over prediction
  - SC-CTX-004: FastOODA disabled in test mode for isolated test instances

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Updated | 2025-12-29 |
  | Author | Cybernetic Architect |
  | STAMP | SC-CTX-001 to SC-CTX-003, SC-OODA-001 |
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    fast_ooda_config = Application.get_env(:indrajaal, Indrajaal.Cortex.FastOODA, [])

    fast_ooda_enabled =
      fast_ooda_config
      |> Keyword.get(:enabled, true)

    base_children = [
      # Core cognitive components
      {Indrajaal.Cortex.SelfHealing, []},
      {Indrajaal.Cortex.Predictor, []},
      {Indrajaal.Cortex.Synapse, []},
      {Indrajaal.Cortex.GDE.Controller, [auto_evolve: true]},
      {Indrajaal.Cortex.GDE.EvolutionEngine, [entropy_threshold: 0.2]},
      # Autonomic drift control — KL divergence every 30s (SC-DRIFT-001)
      {Indrajaal.Cortex.DriftMonitor, []},
      # Semantic intent routing for cognitive operations
      {Indrajaal.Cortex.SemanticRouter, []},
      # Tier 1 Cognitive Reasoning (T22.1.1)
      {Indrajaal.Cortex.Reasoning.ChainOfThought, []},
      # Active Inference - Surprise Minimization (T22.1.4)
      {Indrajaal.Cybernetic.Inference.SurpriseMinimization, []}
    ]

    children =
      if fast_ooda_enabled do
        # FastOODA for CAE - 50ms cycle OODA loop (SC-OODA-001)
        base_children ++ [{Indrajaal.Cortex.FastOODA, []}]
      else
        base_children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
