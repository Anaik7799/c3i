defmodule Indrajaal.AI.Supervisor do
  @moduledoc """
  AI Services Supervisor

  Manages AI inference services: local model (Ollama), OpenRouter pricing
  cache, and pricing metrics/correctness validation.

  STAMP: SC-CACHE-001 (pricing cache), SC-PROM-001 (metrics)
  Strategy: :one_for_one — each AI service is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.AI.LocalModel, []},
      {Indrajaal.AI.PricingCache, []},
      {Indrajaal.AI.PricingMetrics, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
