defmodule IndrajaalWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  @spec start_link(any()) :: any()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: any()
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm / telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec metrics() :: any()
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("intelitor.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("intelitor.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the __data received from the
          __database"
      ),
      summary("intelitor.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("intelitor.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a __database connection"
      ),
      summary("intelitor.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "The time the connection spent waiting before being checked out
            for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Ash Framework Metrics
      counter("ash.__request.stop",
        tags: [:domain, :resource, :action],
        description: "Number of Ash __requests completed"
      ),
      summary("ash.__request.stop.duration",
        tags: [:domain, :resource, :action],
        unit: {:native, :millisecond},
        description: "Duration of Ash __requests"
      ),

      # Security Metrics
      counter("intelitor.auth.login.total",
        tags: [:method, :result],
        description: "Authentication attempts"
      ),
      counter("intelitor.access.denied.total",
        tags: [:resource, :action],
        description: "Access denied __events"
      ),

      # Multi - tenancy Metrics
      counter("intelitor.tenant.switch.total",
        tags: [:tenant_id],
        description: "Tenant __context switches"
      )
    ]
  end

  @spec periodic_measurements() :: any()
  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute / 3 and a metric must be added
      # {IndrajaalWeb, :count_users, []}
    ]
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
