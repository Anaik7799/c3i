defmodule Indrajaal.Supervisors.InfrastructureSupervisor do
  @moduledoc """
  L2 INFRASTRUCTURE SUPERVISOR
  Manages application delivery, background processing, and observability singletons.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      IndrajaalWeb.Endpoint,
      {Oban,
       repo: Indrajaal.Repo,
       plugins: [Oban.Plugins.Pruner],
       queues: [default: 10],
       notifier: {Oban.Notifiers.Postgres, repo: Indrajaal.Repo}},
      {Indrajaal.Claude.Logger, []},
      {Indrajaal.Claude.MandatoryLoggingEnforcer, []},
      {Indrajaal.Observability.SingletonsSupervisor, []},
      {Indrajaal.Performance.Supervisor, []},
      Indrajaal.Compilation.Registry,
      Indrajaal.Validation.RateLimiterRegistry,
      # CRM audit log — ETS ring buffer with DuckDB flush (task 4a2ab7eb)
      {Indrajaal.Crm.AuditLog, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
