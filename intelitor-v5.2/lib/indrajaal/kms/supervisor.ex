defmodule Indrajaal.KMS.Supervisor do
  @moduledoc """
  Knowledge Management System Supervisor

  Manages KMS services: core storage (SQLite/DuckDB), AI classification,
  and web knowledge retrieval.

  STAMP: SC-KMS-001 (SQLite/DuckDB init), SC-KMS-013 (AI classification)
  Strategy: :one_for_one — each KMS service is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.KMS.Service, []},
      {Indrajaal.KMS.AI, [llm_enabled: true, auto_garden: false]},
      {Indrajaal.KMS.WebKnowledge, []},
      {Indrajaal.KMS.Vectors, []},
      {Indrajaal.KMS.Vectors.FractalIngestor, [batch_size: 20, interval_ms: :timer.minutes(5)]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
