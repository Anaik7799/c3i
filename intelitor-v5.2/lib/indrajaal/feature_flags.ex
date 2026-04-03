defmodule Indrajaal.FeatureFlags do
  @moduledoc """
  Feature flags system for STAMP / TDG / GDE rollout control
  """

  use GenServer
  require Logger

  @default_flags %{
    # STAMP flags
    stamp_enabled: false,
    stamp_stpa_analysis: false,
    stamp_cast_investigation: false,
    stamp_violation_tracking: false,
    # :warning, :error, :block
    stamp_enforcement_level: :warning,

    # TDG flags
    tdg_enabled: false,
    tdg_pre_generation_check: false,
    tdg_coverage_enforcement: false,
    tdg_property_testing: false,
    tdg_git_hooks: false,
    tdg_minimum_coverage: 95,

    # GDE flags
    gde_enabled: false,
    gde_goal_tracking: false,
    gde_automated_interventions: false,
    gde_predictive_analytics: false,
    gde_real_time_monitoring: false,

    # Integration flags
    unified_dashboard: false,
    telemetry_export: false,
    ci_cd_integration: false,

    # Rollout percentage (for canary deployment)
    rollout_percentage: 0,
    rollout_teams: []
  }

  # Client API

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a feature is enabled
  """
  @spec enabled?(any()) :: any()
  def enabled?(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:enabled?, flag})
  end

  @doc """
  Check if feature is enabled for a specific user / team
  """
  @spec enabled_for?(any(), any()) :: any()
  def enabled_for?(flag, %{team: team}) do
    GenServer.call(__MODULE__, {:enabled_for?, flag, team})
  end

  @spec enabled_for?(any(), any()) :: any()
  def enabled_for?(flag, %{user_id: user_id}) do
    GenServer.call(__MODULE__, {:enabled_for_user?, flag, user_id})
  end

  @doc """
  Enable a feature flag
  """
  @spec enable(any()) :: any()
  def enable(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:enable, flag})
  end

  @doc """
  Disable a feature flag
  """
  @spec disable(any()) :: any()
  def disable(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:disable, flag})
  end

  @doc """
  Set rollout percentage for canary deployment
  """
  @spec set_rollout_percentage(any()) :: any()
  def set_rollout_percentage(percentage)
      when percentage >= 0 and
             percentage <=
               100 do
    GenServer.call(__MODULE__, {:set_rollout_percentage, percentage})
  end

  @doc """
  Add team to rollout
  """
  @spec add_team_to_rollout(any()) :: any()
  def add_team_to_rollout(team) do
    GenServer.call(__MODULE__, {:add_team_to_rollout, team})
  end

  @doc """
  Get all feature flags
  """
  def all_flags do
    GenServer.call(__MODULE__, :all_flags)
  end

  @doc """
  Bulk update flags (useful for deployment scripts)
  """
  @spec bulk_update(any()) :: any()
  def bulk_update(flags) when is_map(flags) do
    GenServer.call(__MODULE__, {:bulk_update, flags})
  end

  @doc """
  Export flags configuration
  """
  def export_config do
    GenServer.call(__MODULE__, :export_config)
  end

  @doc """
  Import flags configuration
  """
  @spec import_config(any()) :: any()
  def import_config(config) when is_map(config) do
    GenServer.call(__MODULE__, {:import_config, config})
  end

  # Server callbacks

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    # Load from environment or config
    initial_flags = load_initial_flags()

    # Subscribe to configuration changes
    :ok = Phoenix.PubSub.subscribe(Indrajaal.PubSub, "feature_flags")

    # Log initial state
    Logger.info("Feature flags initialized: #{inspect(initial_flags)}")

    # Emit telemetry
    :telemetry.execute(
      [:feature_flags, :initialized],
      %{count: map_size(initial_flags)},
      %{flags: initial_flags}
    )

    {:ok, initial_flags}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:enabled?, flag}, _from, state) do
    enabled = Map.get(state, flag, false)

    # Emit telemetry
    :telemetry.execute(
      [:feature_flags, :checked],
      %{enabled: enabled},
      %{flag: flag}
    )

    {:reply, enabled, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:enabledfor?, flag, team}, _from, state) do
    base_enabled = Map.get(state, flag, false)
    team_enabled = team in Map.get(state, :rollout_teams, [])
    percentage = Map.get(state, :rollout_percentage, 0)

    # Check if enabled for this team
    enabled =
      base_enabled and
        (team_enabled or
           check_percentage_rollout(
             team,
             percentage
           ))

    {:reply, enabled, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:enabled_for_user?, flag, user_id}, _from, state) do
    base_enabled = Map.get(state, flag, false)
    percentage = Map.get(state, :rollout_percentage, 0)

    # Use consistent hashing for percentage rollout
    enabled = base_enabled and check_percentage_rollout(user_id, percentage)

    {:reply, enabled, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:enable, flag}, _from, state) do
    new_state = Map.put(state, flag, true)

    # Broadcast change
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "feature_flags",
      {:flag_changed, flag, true}
    )

    # Log change
    Logger.info("Feature flag enabled: #{flag}")

    # Emit telemetry
    :telemetry.execute(
      [:feature_flags, :changed],
      %{enabled: true},
      %{flag: flag}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:disable, flag}, _from, state) do
    new_state = Map.put(state, flag, false)

    # Broadcast change
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "feature_flags",
      {:flag_changed, flag, false}
    )

    # Log change
    Logger.info("Feature flag disabled: #{flag}")

    # Emit telemetry
    :telemetry.execute(
      [:feature_flags, :changed],
      %{enabled: false},
      %{flag: flag}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:setrolloutpercentage, percentage}, _from, state) do
    new_state = Map.put(state, :rollout_percentage, percentage)

    Logger.info("Rollout percentage set to: #{percentage}%")

    {:reply, :ok, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:add_team_to_rollout, team}, _from, state) do
    teams = Map.get(state, :rollout_teams, [])
    new_teams = Enum.uniq([team | teams])
    new_state = Map.put(state, :rollout_teams, new_teams)

    Logger.info("Team added to rollout: #{team}")

    {:reply, :ok, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:all_flags, _from, state) do
    {:reply, state, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:bulk_update, flags}, _from, state) do
    new_state = Map.merge(state, flags)

    # Broadcast changes
    Enum.each(flags, fn {flag, value} ->
      if Map.get(state, flag) != value do
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          "feature_flags",
          {:flag_changed, flag, value}
        )
      end
    end)

    Logger.info("Bulk update applied: #{map_size(flags)} flags updated")

    {:reply, :ok, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:export_config, _from, state) do
    config = %{
      flags: state,
      exported_at: DateTime.utc_now(),
      version: "1.0.0"
    }

    {:reply, config, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:import_config, config}, _from, _state) do
    new_state = config.flags

    Logger.info("Configuration imported: #{map_size(new_state)} flags")

    {:reply, :ok, new_state}
  end

  # Private functions

  defp load_initial_flags do
    # Load from application config
    configured_flags = Application.get_env(:indrajaal, :feature_flags, %{})

    # Merge with defaults
    Map.merge(@default_flags, configured_flags)
  end

  @spec check_percentage_rollout(term(), term()) :: term()
  defp check_percentage_rollout(identifier, percentage) do
    # Use consistent hashing to determine if enabled
    hash = :erlang.phash2(identifier, 100)
    hash < percentage
  end
end

defmodule Indrajaal.FeatureFlags.Plug do
  @moduledoc """
  Plug for feature flag checking in Phoenix controllers
  """

  import Plug.Conn
  import Phoenix.Controller

  @spec init(any()) :: any()
  def init(opts), do: opts
  # Claude Agent: EP-076 - Unreachable function clause uncommented to match @spec
  @spec call(any(), any()) :: any()
  def call(conn, flag: flag) do
    if Indrajaal.FeatureFlags.enabled?(flag) do
      conn
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Feature not available"})
      |> halt()
    end
  end
end

defmodule Indrajaal.FeatureFlags.LiveView do
  @moduledoc """
  Helpers for feature flags in LiveView
  """

  defmacro _using__(_opts) do
    quote do
      @spec mount(term(), term(), term()) :: term()
      def mount(_params, _session, _socket) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Indrajaal.PubSub, "feature_flags")
        end

        {:ok, assign(socket, :feature_flags, Indrajaal.FeatureFlags.all_flags())}
      end

      def handleinfo({:flagchanged, flag, value}, _socket) do
        _flags = Map.put(socket.assigns.feature_flags, flag, value)
        {:noreply, assign(socket, :feature_flags, flags)}
      end

      @spec feature_enabled?(any(), any()) :: any()
      def feature_enabled?(socket, flag) do
        Map.get(socket.assigns.feature_flags, flag, false)
      end
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
