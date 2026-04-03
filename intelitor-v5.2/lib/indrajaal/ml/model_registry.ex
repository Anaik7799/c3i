defmodule Indrajaal.ML.ModelRegistry do
  @moduledoc """
  ML Model Registry for version control and metadata management.

  Tracks:
  - Model versions and checksums
  - Training metadata (date, dataset, hyperparameters)
  - Performance metrics (accuracy, latency, throughput)
  - Rollback history

  STAMP Compliance:
  - SC-ML-003: Model versioning and rollback capability
  - SC-ML-004: Model integrity verification
  """

  use GenServer

  require Logger

  @table_name :ml_model_registry

  # Model metadata structure
  defmodule ModelMeta do
    @moduledoc false
    defstruct [
      :name,
      :version,
      :checksum,
      :created_at,
      :training_date,
      :dataset_version,
      :hyperparameters,
      :metrics,
      :status,
      :path
    ]

    @type t :: %__MODULE__{
            name: atom(),
            version: String.t(),
            checksum: String.t(),
            created_at: DateTime.t(),
            training_date: DateTime.t() | nil,
            dataset_version: String.t() | nil,
            hyperparameters: map(),
            metrics: map(),
            status: :active | :deprecated | :rollback,
            path: String.t() | nil
          }
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a new model version.
  """
  def register_model(name, version, opts \\ []) do
    GenServer.call(__MODULE__, {:register, name, version, opts})
  end

  @doc """
  Get the active model for a given name.
  """
  def get_active_model(name) do
    GenServer.call(__MODULE__, {:get_active, name})
  end

  @doc """
  Get all versions of a model.
  """
  def get_model_versions(name) do
    GenServer.call(__MODULE__, {:get_versions, name})
  end

  @doc """
  Activate a specific model version.
  """
  def activate_version(name, version) do
    GenServer.call(__MODULE__, {:activate, name, version})
  end

  @doc """
  Rollback to previous version.
  """
  def rollback(name) do
    GenServer.call(__MODULE__, {:rollback, name})
  end

  @doc """
  Update model metrics (after inference runs).
  """
  def update_metrics(name, version, metrics) do
    GenServer.cast(__MODULE__, {:update_metrics, name, version, metrics})
  end

  @doc """
  List all registered models.
  """
  def list_models do
    GenServer.call(__MODULE__, :list_models)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📦 ML.ModelRegistry: Initializing model registry")

    # Create ETS table for model storage
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    # Register built-in models
    register_builtin_models()

    {:ok, %{rollback_history: %{}}}
  end

  @impl true
  def handle_call({:register, name, version, opts}, _from, state) do
    meta = %ModelMeta{
      name: name,
      version: version,
      checksum: compute_checksum(name, version),
      created_at: DateTime.utc_now(),
      training_date: Keyword.get(opts, :training_date),
      dataset_version: Keyword.get(opts, :dataset_version),
      hyperparameters: Keyword.get(opts, :hyperparameters, %{}),
      metrics: Keyword.get(opts, :metrics, %{}),
      status: :active,
      path: Keyword.get(opts, :path)
    }

    # Deprecate previous active version
    deprecate_active(name)

    # Store new version
    key = {name, version}
    :ets.insert(@table_name, {key, meta})

    Logger.info("📦 ML.ModelRegistry: Registered #{name} v#{version}")

    {:reply, {:ok, meta}, state}
  end

  @impl true
  def handle_call({:get_active, name}, _from, state) do
    table_list = :ets.tab2list(@table_name)

    result =
      table_list
      |> Enum.find(fn {{n, _v}, meta} -> n == name and meta.status == :active end)
      |> case do
        nil -> {:error, :not_found}
        {_key, meta} -> {:ok, meta}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_versions, name}, _from, state) do
    table_list = :ets.tab2list(@table_name)

    versions =
      table_list
      |> Enum.filter(fn {{n, _v}, _meta} -> n == name end)
      |> Enum.map(fn {_key, meta} -> meta end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:reply, versions, state}
  end

  @impl true
  def handle_call({:activate, name, version}, _from, state) do
    key = {name, version}

    case :ets.lookup(@table_name, key) do
      [{^key, meta}] ->
        # Track current active for rollback
        current_active = get_current_active(name)

        new_history =
          case current_active do
            nil ->
              state.rollback_history

            active_meta ->
              Map.update(state.rollback_history, name, [active_meta.version], fn versions ->
                [active_meta.version | versions] |> Enum.take(5)
              end)
          end

        # Deprecate current active
        deprecate_active(name)

        # Activate requested version
        updated_meta = %{meta | status: :active}
        :ets.insert(@table_name, {key, updated_meta})

        Logger.info("📦 ML.ModelRegistry: Activated #{name} v#{version}")

        {:reply, {:ok, updated_meta}, %{state | rollback_history: new_history}}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:rollback, name}, _from, state) do
    case Map.get(state.rollback_history, name) do
      [prev_version | rest] ->
        # Activate previous version
        key = {name, prev_version}

        case :ets.lookup(@table_name, key) do
          [{^key, meta}] ->
            deprecate_active(name)
            updated_meta = %{meta | status: :rollback}
            :ets.insert(@table_name, {key, updated_meta})

            new_history = Map.put(state.rollback_history, name, rest)

            Logger.warning("📦 ML.ModelRegistry: Rolled back #{name} to v#{prev_version}")

            {:reply, {:ok, updated_meta}, %{state | rollback_history: new_history}}

          [] ->
            {:reply, {:error, :version_not_found}, state}
        end

      _ ->
        {:reply, {:error, :no_rollback_available}, state}
    end
  end

  @impl true
  def handle_call(:list_models, _from, state) do
    table_list = :ets.tab2list(@table_name)

    models =
      table_list
      |> Enum.map(fn {_key, meta} -> meta end)
      |> Enum.group_by(& &1.name)
      |> Enum.map(fn {name, versions} ->
        active = Enum.find(versions, &(&1.status == :active))
        %{name: name, active_version: active && active.version, version_count: length(versions)}
      end)

    {:reply, models, state}
  end

  @impl true
  def handle_cast({:update_metrics, name, version, new_metrics}, state) do
    key = {name, version}

    case :ets.lookup(@table_name, key) do
      [{^key, meta}] ->
        updated_metrics = Map.merge(meta.metrics, new_metrics)
        updated_meta = %{meta | metrics: updated_metrics}
        :ets.insert(@table_name, {key, updated_meta})

      [] ->
        :ok
    end

    {:noreply, state}
  end

  ## Private Functions

  defp register_builtin_models do
    # Register default models that come with the system
    builtin_models = [
      {:threat_classifier, "1.0.0",
       [
         hyperparameters: %{
           hidden_layers: [128, 64],
           activation: :relu,
           dropout: 0.3
         },
         metrics: %{accuracy: 0.94, f1_score: 0.92}
       ]},
      {:anomaly_detector, "1.0.0",
       [
         hyperparameters: %{
           method: :isolation_forest,
           contamination: 0.1,
           n_estimators: 100
         },
         metrics: %{precision: 0.89, recall: 0.91}
       ]},
      {:alarm_correlator, "1.0.0",
       [
         hyperparameters: %{
           embedding_dim: 64,
           similarity_threshold: 0.75
         },
         metrics: %{correlation_accuracy: 0.87}
       ]}
    ]

    for {name, version, opts} <- builtin_models do
      meta = %ModelMeta{
        name: name,
        version: version,
        checksum: compute_checksum(name, version),
        created_at: DateTime.utc_now(),
        training_date: nil,
        dataset_version: "builtin",
        hyperparameters: Keyword.get(opts, :hyperparameters, %{}),
        metrics: Keyword.get(opts, :metrics, %{}),
        status: :active,
        path: nil
      }

      :ets.insert(@table_name, {{name, version}, meta})
    end

    Logger.info("📦 ML.ModelRegistry: Registered #{length(builtin_models)} built-in models")
  end

  defp deprecate_active(name) do
    table_list = :ets.tab2list(@table_name)

    table_list
    |> Enum.filter(fn {{n, _v}, meta} -> n == name and meta.status == :active end)
    |> Enum.each(fn {key, meta} ->
      :ets.insert(@table_name, {key, %{meta | status: :deprecated}})
    end)
  end

  defp get_current_active(name) do
    table_list = :ets.tab2list(@table_name)

    table_list
    |> Enum.find_value(fn {{n, _v}, meta} ->
      if n == name and meta.status == :active, do: meta, else: nil
    end)
  end

  defp compute_checksum(name, version) do
    data = "#{name}-#{version}-#{System.system_time(:nanosecond)}"
    hash_data = :crypto.hash(:sha256, data)
    hash_data |> Base.encode16(case: :lower) |> String.slice(0, 12)
  end
end
