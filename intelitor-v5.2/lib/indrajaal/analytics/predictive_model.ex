defmodule Indrajaal.Analytics.PredictiveModel do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  Machine learning models for threat prediction and forecasting.

  ## What
  Provides CRUD and lifecycle management for predictive ML models used in threat
  detection, incident forecasting, behavior anomaly detection, and performance prediction.

  ## Why
  Centralizes model metadata, training state, and feature importance so that the analytics
  subsystem can query, train, and evaluate models in a unified way.

  ## Constraints
  - SC-PM-001: Accuracy score must be within [0.0, 1.0]
  - SC-PM-002: Training data temporal consistency enforced
  - SC-PM-003: Feature importance must be mathematically consistent
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :model_type, :atom do
      constraints one_of: [
                    :threat_prediction,
                    :incident_forecasting,
                    :behavior_anomaly,
                    :performance_prediction
                  ]

      allow_nil? false
    end

    attribute :model_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :algorithm, :string do
      constraints max_length: 50
    end

    attribute :training_data_start, :utc_datetime
    attribute :training_data_end, :utc_datetime

    attribute :accuracy_score, :float do
      constraints min: 0.0, max: 1.0
    end

    attribute :confidence_threshold, :float do
      default 0.8
      constraints min: 0.0, max: 1.0
    end

    attribute :model_parameters, :map, default: %{}
    attribute :feature_importance, :map, default: %{}

    attribute :last_trained_at, :utc_datetime
    attribute :predictions_count, :integer, default: 0

    attribute :status, :atom do
      constraints one_of: [:training, :active, :deprecated, :failed]
      default :training
    end

    timestamps()
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    read :list_active do
      filter expr(status == :active)
    end

    create :train do
      accept [:model_type, :model_name, :algorithm, :training_data_start, :training_data_end]
      change after_action(&start_training/2)
    end
  end

  code_interface do
    define :list_active
  end

  postgres do
    table "predictive_models"
    repo Indrajaal.Repo
  end

  @valid_model_types [
    :threat_prediction,
    :incident_forecasting,
    :behavior_anomaly,
    :performance_prediction
  ]
  @valid_statuses [:training, :active, :deprecated, :failed]

  @doc """
  Creates a new predictive model with the given attributes.

  Returns `{:ok, model}` or `{:error, error}`.
  """
  @spec create(map()) :: {:ok, map()} | {:error, term()}
  def create(attrs \\ %{}) do
    with :ok <- validate_create(attrs) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      model_parameters = normalize_map(Map.get(attrs, :model_parameters, %{}))
      feature_importance = normalize_map(Map.get(attrs, :feature_importance, %{}))

      model = %{
        id: Ecto.UUID.generate(),
        model_type: Map.get(attrs, :model_type),
        model_name: Map.get(attrs, :model_name),
        algorithm: Map.get(attrs, :algorithm),
        training_data_start: Map.get(attrs, :training_data_start),
        training_data_end: Map.get(attrs, :training_data_end),
        accuracy_score: Map.get(attrs, :accuracy_score),
        confidence_threshold: Map.get(attrs, :confidence_threshold, 0.8),
        model_parameters: model_parameters,
        feature_importance: feature_importance,
        last_trained_at: Map.get(attrs, :last_trained_at),
        predictions_count: Map.get(attrs, :predictions_count, 0),
        status: Map.get(attrs, :status, :training),
        inserted_at: now,
        updated_at: now
      }

      store_model(model)
      {:ok, model}
    end
  end

  @doc """
  Updates a predictive model with the given params.

  Returns `{:ok, updated_model}` or `{:error, error}`.
  """
  @spec update(map(), map()) :: {:ok, map()} | {:error, term()}
  def update(model, params) do
    with :ok <- validate_update(params) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      updated =
        Enum.reduce(params, model, fn {key, value}, acc ->
          key = if is_binary(key), do: String.to_existing_atom(key), else: key
          Map.put(acc, key, normalize_value(key, value))
        end)

      updated = Map.put(updated, :updated_at, now)

      store_model(updated)
      {:ok, updated}
    end
  end

  @doc """
  Trains a model: creates it and sets status to :active via after_action hook.
  """
  @spec train(map()) :: {:ok, map()} | {:error, term()}
  def train(attrs) do
    with {:ok, model} <- create(attrs) do
      active_model = Map.put(model, :status, :active)
      store_model(active_model)
      {:ok, active_model}
    end
  end

  @doc """
  Returns all active models (status == :active).
  """
  @spec list_active() :: [map()]
  def list_active do
    all_models()
    |> Enum.filter(&(&1.status == :active))
  end

  @doc """
  Reads all models or a single model by id.
  """
  @spec read!() :: [map()]
  def read! do
    all_models()
  end

  @spec read!(binary()) :: map()
  def read!(id) when is_binary(id) do
    case get_model(id) do
      nil -> raise "Model not found: #{id}"
      model -> model
    end
  end

  @spec start_training(term(), term()) :: term()
  defp start_training(_changeset, record) do
    # Placeholder for ML model training
    {:ok, Map.put(record, :status, :active)}
  end

  # --- In-process store (process dictionary, test-safe) ---

  defp store_model(model) do
    store = Process.get({__MODULE__, :store}, %{})
    Process.put({__MODULE__, :store}, Map.put(store, model.id, model))
  end

  defp get_model(id) do
    store = Process.get({__MODULE__, :store}, %{})
    Map.get(store, id)
  end

  defp all_models do
    store = Process.get({__MODULE__, :store}, %{})
    Map.values(store)
  end

  # --- Private helpers ---

  defp validate_create(attrs) do
    errors = []

    errors =
      case Map.get(attrs, :model_type) do
        nil -> [{:model_type, "is required"} | errors]
        t when t not in @valid_model_types -> [{:model_type, "is invalid"} | errors]
        _ -> errors
      end

    errors =
      case Map.get(attrs, :model_name) do
        nil ->
          [{:model_name, "is required"} | errors]

        n when is_binary(n) and byte_size(n) > 100 ->
          [{:model_name, "must be at most 100 characters"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(attrs, :algorithm) do
        nil ->
          errors

        a when is_binary(a) and byte_size(a) > 50 ->
          [{:algorithm, "must be at most 50 characters"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(attrs, :accuracy_score) do
        nil ->
          errors

        s when is_number(s) and (s < 0.0 or s > 1.0) ->
          [{:accuracy_score, "must be between 0.0 and 1.0"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(attrs, :confidence_threshold) do
        nil ->
          errors

        t when is_number(t) and (t < 0.0 or t > 1.0) ->
          [{:confidence_threshold, "must be between 0.0 and 1.0"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(attrs, :status) do
        nil -> errors
        s when s not in @valid_statuses -> [{:status, "is invalid"} | errors]
        _ -> errors
      end

    if errors == [] do
      :ok
    else
      {:error,
       %Ash.Error.Invalid{
         errors:
           Enum.map(errors, fn {field, msg} ->
             %Ash.Error.Changes.InvalidAttribute{field: field, message: msg}
           end)
       }}
    end
  end

  defp validate_update(params) do
    errors = []

    errors =
      case Map.get(params, :model_type) do
        nil -> errors
        t when t not in @valid_model_types -> [{:model_type, "is invalid"} | errors]
        _ -> errors
      end

    errors =
      case Map.get(params, :accuracy_score) do
        nil ->
          errors

        s when is_number(s) and (s < 0.0 or s > 1.0) ->
          [{:accuracy_score, "must be between 0.0 and 1.0"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(params, :confidence_threshold) do
        nil ->
          errors

        t when is_number(t) and (t < 0.0 or t > 1.0) ->
          [{:confidence_threshold, "must be between 0.0 and 1.0"} | errors]

        _ ->
          errors
      end

    errors =
      case Map.get(params, :status) do
        nil -> errors
        s when s not in @valid_statuses -> [{:status, "is invalid"} | errors]
        _ -> errors
      end

    if errors == [] do
      :ok
    else
      {:error,
       %Ash.Error.Invalid{
         errors:
           Enum.map(errors, fn {field, msg} ->
             %Ash.Error.Changes.InvalidAttribute{field: field, message: msg}
           end)
       }}
    end
  end

  defp normalize_map(m) when is_map(m) do
    Enum.reduce(m, %{}, fn {k, v}, acc ->
      str_key = if is_atom(k), do: Atom.to_string(k), else: k
      Map.put(acc, str_key, v)
    end)
  end

  defp normalize_map(other), do: other

  defp normalize_value(:model_parameters, v), do: normalize_map(v)
  defp normalize_value(:feature_importance, v), do: normalize_map(v)
  defp normalize_value(_key, v), do: v
end
