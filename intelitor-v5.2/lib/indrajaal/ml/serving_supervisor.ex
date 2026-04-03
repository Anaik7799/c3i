defmodule Indrajaal.ML.ServingSupervisor do
  @moduledoc """
  Supervisor for all Nx.Serving ML inference processes.

  STAMP Compliance:
  - SC-ML-001: ML model serving isolation
  - SC-ML-002: Graceful degradation on model failure
  - SC-ML-003: Model versioning and rollback capability

  GDE/CAFE Integration:
  - C3 Intelligence tier coordination
  - FLAME integration for heavy inference
  - Telemetry for inference latency tracking
  """

  use Supervisor

  require Logger

  @doc """
  Start the ML Serving supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🧠 ML.ServingSupervisor: Initializing ML inference infrastructure")

    children = [
      # Model Registry - tracks model versions and metadata
      {Indrajaal.ML.ModelRegistry, []},

      # Threat Classification Serving
      serving_child_spec(
        :threat_classifier,
        Indrajaal.ML.Serving.ThreatClassifier,
        batch_size: 10,
        batch_timeout: 100
      ),

      # Anomaly Detection Serving
      serving_child_spec(
        :anomaly_detector,
        Indrajaal.ML.Serving.AnomalyDetector,
        batch_size: 50,
        batch_timeout: 50
      ),

      # Alarm Correlation Serving (NLP-based)
      serving_child_spec(
        :alarm_correlator,
        Indrajaal.ML.Serving.AlarmCorrelator,
        batch_size: 20,
        batch_timeout: 100
      ),

      # Telemetry handler for ML metrics
      {Indrajaal.ML.Telemetry, []}
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end

  # Build child spec for Nx.Serving process
  defp serving_child_spec(name, module, opts) do
    %{
      id: name,
      start: {module, :start_link, [[name: name] ++ opts]},
      restart: :permanent,
      shutdown: 30_000,
      type: :worker
    }
  end

  @doc """
  Get the status of all serving processes.
  """
  def status do
    children = Supervisor.which_children(__MODULE__)

    Enum.map(children, fn {id, pid, type, _modules} ->
      %{
        id: id,
        pid: pid,
        alive: is_pid(pid) and Process.alive?(pid),
        type: type
      }
    end)
  end

  @doc """
  Restart a specific serving process.
  """
  def restart_serving(name) do
    case Supervisor.terminate_child(__MODULE__, name) do
      :ok ->
        Supervisor.restart_child(__MODULE__, name)

      error ->
        error
    end
  end
end
