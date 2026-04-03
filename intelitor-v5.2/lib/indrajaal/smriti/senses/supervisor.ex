defmodule Indrajaal.Smriti.Senses.Supervisor do
  @moduledoc """
  SMRITI Senses Supervisor.
  Manages Gatekeeper and Curator.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Indrajaal.Smriti.Senses.Gatekeeper,
      Indrajaal.Smriti.Cognition.Curator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
