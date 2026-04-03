defmodule Indrajaal.Safety.STAMPRegistry do
  @moduledoc """
  STAMP Constraint Registry - Runtime Safety Validation for v20.0.0

  Provides runtime registration and validation of STAMP safety constraints.
  All 277+ constraints can be loaded at startup and validated during operation.

  ## STAMP Categories

  - `:holon` - SC-HOL-* - Holon behavior constraints
  - `:bus` - SC-BUS-* - UnifiedBus constraints
  - `:ooda` - SC-OODA-* - FastOODA constraints
  - `:guard` - SC-GUARD-* - Guardian constraints
  - `:gde` - SC-GDE-* - Goal-Directed Evolution
  - `:val` - SC-VAL-* - Validation constraints
  - `:cnt` - SC-CNT-* - Container constraints
  - `:agt` - SC-AGT-* - Agent constraints
  - `:cmp` - SC-CMP-* - Compilation constraints
  - `:sec` - SC-SEC-* - Security constraints

  ## Usage

      {:ok, reg} = STAMPRegistry.start_link()

      # Register a constraint
      STAMPRegistry.register(reg, "SC-HOL-001", %{
        description: "All holons MUST implement all 5 systems",
        category: :holon,
        severity: :critical,
        validator: &holon_vsm_validator/1
      })

      # Validate an action
      {:ok, _} = STAMPRegistry.validate(reg, "SC-HOL-001", action)

      # Validate all constraints in category
      {:ok, _} = STAMPRegistry.validate_all(reg, :holon, action)

  """

  use GenServer
  require Logger

  @type constraint_id :: String.t()
  @type category :: atom()
  @type severity :: :critical | :high | :medium | :low

  @type constraint :: %{
          id: constraint_id(),
          description: String.t() | nil,
          category: category(),
          severity: severity(),
          validator: (map() -> boolean()) | nil,
          registered_at: DateTime.t()
        }

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Registers a STAMP constraint.
  """
  @spec register(GenServer.server(), constraint_id(), map()) :: :ok
  def register(server, constraint_id, attrs) do
    GenServer.call(server, {:register, constraint_id, attrs})
  end

  @doc """
  Gets a constraint by ID.
  """
  @spec get(GenServer.server(), constraint_id()) :: constraint() | nil
  def get(server, constraint_id) do
    GenServer.call(server, {:get, constraint_id})
  end

  @doc """
  Lists all constraints in a category.
  """
  @spec list_by_category(GenServer.server(), category()) :: [constraint()]
  def list_by_category(server, category) do
    GenServer.call(server, {:list_by_category, category})
  end

  @doc """
  Validates an action against a specific constraint.
  """
  @spec validate(GenServer.server(), constraint_id(), map()) ::
          {:ok, constraint()} | {:error, :constraint_violated | :not_found}
  def validate(server, constraint_id, action) do
    GenServer.call(server, {:validate, constraint_id, action})
  end

  @doc """
  Validates an action against all constraints in a category.
  Returns list of violated constraint IDs.
  """
  @spec validate_all(GenServer.server(), category(), map()) ::
          {:ok, [constraint()]} | {:error, [constraint_id()]}
  def validate_all(server, category, action) do
    GenServer.call(server, {:validate_all, category, action})
  end

  @doc """
  Returns total constraint count.
  """
  @spec count(GenServer.server()) :: non_neg_integer()
  def count(server) do
    GenServer.call(server, :count)
  end

  @doc """
  Loads constraints from a specification map.
  """
  @spec load_from_spec(GenServer.server(), map()) :: :ok
  def load_from_spec(server, spec) do
    GenServer.call(server, {:load_from_spec, spec})
  end

  @doc """
  Returns registry metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      constraints: %{},
      by_category: %{},
      by_severity: %{},
      metrics: %{
        validations: 0,
        violations: 0
      },
      started_at: DateTime.utc_now()
    }

    Logger.info("[STAMPRegistry] Started")

    {:ok, state}
  end

  @impl true
  def handle_call({:register, constraint_id, attrs}, _from, state) do
    constraint = %{
      id: constraint_id,
      description: Map.get(attrs, :description),
      category: Map.get(attrs, :category, :general),
      severity: Map.get(attrs, :severity, :medium),
      validator: Map.get(attrs, :validator),
      registered_at: DateTime.utc_now()
    }

    # Update main map
    new_constraints = Map.put(state.constraints, constraint_id, constraint)

    # Update category index
    category = constraint.category
    existing_in_category = Map.get(state.by_category, category, [])
    new_by_category = Map.put(state.by_category, category, [constraint_id | existing_in_category])

    # Update severity index
    severity = constraint.severity
    existing_in_severity = Map.get(state.by_severity, severity, [])
    new_by_severity = Map.put(state.by_severity, severity, [constraint_id | existing_in_severity])

    new_state = %{
      state
      | constraints: new_constraints,
        by_category: new_by_category,
        by_severity: new_by_severity
    }

    Logger.debug("[STAMPRegistry] Registered #{constraint_id} (#{category}/#{severity})")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get, constraint_id}, _from, state) do
    constraint = Map.get(state.constraints, constraint_id)
    {:reply, constraint, state}
  end

  @impl true
  def handle_call({:list_by_category, category}, _from, state) do
    constraint_ids = Map.get(state.by_category, category, [])

    constraints =
      constraint_ids
      |> Enum.map(&Map.get(state.constraints, &1))
      |> Enum.filter(& &1)

    {:reply, constraints, state}
  end

  @impl true
  def handle_call({:validate, constraint_id, action}, _from, state) do
    new_metrics = %{state.metrics | validations: state.metrics.validations + 1}

    case Map.get(state.constraints, constraint_id) do
      nil ->
        {:reply, {:error, :not_found}, %{state | metrics: new_metrics}}

      constraint ->
        case validate_constraint(constraint, action) do
          true ->
            {:reply, {:ok, constraint}, %{state | metrics: new_metrics}}

          false ->
            new_metrics = %{new_metrics | violations: new_metrics.violations + 1}
            {:reply, {:error, :constraint_violated}, %{state | metrics: new_metrics}}
        end
    end
  end

  @impl true
  def handle_call({:validate_all, category, action}, _from, state) do
    constraint_ids = Map.get(state.by_category, category, [])

    new_metrics = %{
      state.metrics
      | validations: state.metrics.validations + length(constraint_ids)
    }

    {passed, violations} =
      constraint_ids
      |> Enum.map(&Map.get(state.constraints, &1))
      |> Enum.filter(& &1)
      |> Enum.split_with(&validate_constraint(&1, action))

    new_state = %{state | metrics: new_metrics}

    if violations == [] do
      {:reply, {:ok, passed}, new_state}
    else
      violation_ids = Enum.map(violations, & &1.id)
      new_metrics = %{new_metrics | violations: new_metrics.violations + length(violations)}
      {:reply, {:error, violation_ids}, %{new_state | metrics: new_metrics}}
    end
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, map_size(state.constraints), state}
  end

  @impl true
  def handle_call({:load_from_spec, spec}, _from, state) do
    new_state =
      Enum.reduce(spec, state, fn {id, attrs}, acc ->
        constraint = %{
          id: id,
          description: Map.get(attrs, :description),
          category: Map.get(attrs, :category, :general),
          severity: Map.get(attrs, :severity, :medium),
          validator: Map.get(attrs, :validator),
          registered_at: DateTime.utc_now()
        }

        new_constraints = Map.put(acc.constraints, id, constraint)

        category = constraint.category
        existing_in_category = Map.get(acc.by_category, category, [])
        new_by_category = Map.put(acc.by_category, category, [id | existing_in_category])

        severity = constraint.severity
        existing_in_severity = Map.get(acc.by_severity, severity, [])
        new_by_severity = Map.put(acc.by_severity, severity, [id | existing_in_severity])

        %{
          acc
          | constraints: new_constraints,
            by_category: new_by_category,
            by_severity: new_by_severity
        }
      end)

    Logger.info("[STAMPRegistry] Loaded #{map_size(spec)} constraints from spec")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    categories =
      state.by_category
      |> Enum.map(fn {cat, ids} -> {cat, length(ids)} end)
      |> Map.new()

    by_severity =
      state.by_severity
      |> Enum.map(fn {sev, ids} -> {sev, length(ids)} end)
      |> Map.new()

    metrics = %{
      total_constraints: map_size(state.constraints),
      categories: categories,
      by_severity: by_severity,
      validations: state.metrics.validations,
      violations: state.metrics.violations,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp validate_constraint(%{validator: nil}, _action), do: true

  defp validate_constraint(%{validator: validator}, action) when is_function(validator, 1) do
    try do
      validator.(action)
    rescue
      _ -> false
    end
  end

  defp validate_constraint(_, _), do: true
end
