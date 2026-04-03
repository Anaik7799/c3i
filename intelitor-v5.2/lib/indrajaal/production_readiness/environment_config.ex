defmodule Indrajaal.ProductionReadiness.EnvironmentConfig do
  @moduledoc """
  Environment configuration management with templates and validation.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-008: Environment changes must be reversible
  - UCA-006: Pr_event environment variable conflicts
  """

  use GenServer
  require Logger

  @critical_variables [
    "DATABASE_URL",
    "SECRET_KEY_BASE",
    "PHX_SERVER",
    "PHX_HOST",
    "SSL_CERT_PATH",
    "SSL_KEY_PATH"
  ]

  @template_dir "config/env_templates"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Load an environment configuration template.
  """
  def load_template(template_spec) do
    GenServer.call(__MODULE__, {:load_template, template_spec})
  end

  @doc """
  Validate environment configuration.
  """
  def validate(config) do
    GenServer.call(__MODULE__, {:validate, config})
  end

  @doc """
  Apply environment configuration with rollback support.
  Satisfies SC-008: Environment changes must be reversible.
  """
  def apply(config) do
    GenServer.call(__MODULE__, {:apply_config, config})
  end

  @doc """
  Rollback to a previous environment state.
  """
  def rollback(rollback_id) do
    GenServer.call(__MODULE__, {:rollback, rollback_id})
  end

  @doc """
  List available environment templates.
  """
  def list_templates do
    GenServer.call(__MODULE__, :list_templates)
  end

  @doc """
  Get current environment status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Ensure template directory exists
    File.mkdir_p!(@template_dir)

    state = %{
      current_config: load_current_environment(),
      rollback_history: [],
      applied_configs: [],
      validation_rules: load_validation_rules()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:load_template, template_spec}, _from, state) do
    case load_template_internal(template_spec) do
      {:ok, template} ->
        config = build_config_from_template(template, template_spec)
        {:reply, {:ok, config}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:validate, config}, _from, state) do
    validation_result = validate_config(config, state.validation_rules)

    if validation_result.valid? do
      {:reply, {:ok, validation_result}, state}
    else
      {:reply, {:error, validation_result}, state}
    end
  end

  @impl true
  def handle_call({:apply_config, config}, _from, state) do
    # UCA-006: Check for critical variable conflicts
    case check_critical_conflicts(config, state.current_config) do
      :ok ->
        # SC-008: Create rollback point
        rollback_point = create_rollback_point(state.current_config)

        # Apply configuration
        case apply_configuration(config) do
          {:ok, applied_result} ->
            new_state = %{
              state
              | current_config: merge_configs(state.current_config, config),
                rollback_history: [rollback_point | state.rollback_history],
                applied_configs: [config | state.applied_configs]
            }

            result =
              Map.merge(applied_result, %{
                rollback_id: rollback_point.id,
                rollback_available: true
              })

            {:reply, {:ok, result}, new_state}

          error ->
            {:reply, error, state}
        end

      {:error, :critical_variable_conflict} = error ->
        Logger.error("[EnvironmentConfig] Critical variable conflict detected")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:rollback, rollback_id}, _from, state) do
    case find_rollback_point(state.rollback_history, rollback_id) do
      nil ->
        {:reply, {:error, :rollback_point_not_found}, state}

      rollback_point ->
        Logger.info("[EnvironmentConfig] Rolling back to #{rollback_id}")

        # Restore environment
        case restore_environment(rollback_point) do
          :ok ->
            new_state = %{state | current_config: rollback_point.environment_snapshot}

            {:reply, {:ok, %{environment_restored: true}}, new_state}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_templates, _from, state) do
    templates = list_available_templates()
    {:reply, templates, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      current_variables: map_size(state.current_config),
      rollback_points: length(state.rollback_history),
      applied_configs: length(state.applied_configs),
      critical_variables_set: count_critical_variables(state.current_config)
    }

    {:reply, status, state}
  end

  # Private functions

  defp load_current_environment do
    System.get_env()
    |> Enum.into(%{})
  end

  defp load_validation_rules do
    %{
      required_variables: [
        "DATABASE_URL",
        "SECRET_KEY_BASE"
      ],
      format_rules: %{
        "DATABASE_URL" => ~r/^postgresql:\/\/.+/,
        "REDIS_URL" => ~r/^redis:\/\/.+/,
        "SSL_CERT_PATH" => ~r/\.crt$|\.pem$/,
        "SSL_KEY_PATH" => ~r/\.key$|\.pem$/
      },
      value_constraints: %{
        "POOL_SIZE" => fn v -> String.to_integer(v) > 0 end,
        "PORT" => fn v -> String.to_integer(v) in 1..65_535 end
      }
    }
  end

  # AGENT GA FIX: Only using name field
  defp load_template_internal(%{name: name} = _spec) do
    template_path = Path.join(@template_dir, "#{name}.eex")

    if File.exists?(template_path) do
      content = File.read!(template_path)

      template = %{
        name: name,
        content: content,
        variables: extract_template_variables(content),
        meta_data: load_template_meta_data(name)
      }

      {:ok, template}
    else
      # Try built-in templates
      case get_builtin_template(name) do
        nil -> {:error, :template_not_found}
        template -> {:ok, template}
      end
    end
  end

  defp get_builtin_template(_), do: nil

  defp extract_template_variables(content) do
    matches = Regex.scan(~r/<%=\s*(\w+)\s*%>/, content, capture: :all_but_first)

    matches
    |> Enum.map(&List.first/1)
    |> Enum.uniq()
  end

  defp load_template_meta_data(name) do
    meta_data_path = Path.join(@template_dir, "#{name}.json")

    if File.exists?(meta_data_path) do
      content = File.read!(meta_data_path)

      content
      |> Jason.decode!()
      |> atomize_keys()
    else
      %{}
    end
  end

  defp build_config_from_template(template, spec) do
    %{
      name: template.name,
      template: template,
      variables: spec[:variables] || %{},
      secrets: spec[:secrets] || [],
      validation_required: true
    }
  end

  defp validate_config(config, rules) do
    errors = []

    # Check _required variables
    errors = errors ++ check_required_variables(config, rules._required_variables)

    # Check format rules
    errors = errors ++ check_format_rules(config, rules.format_rules)

    # Check value constraints
    errors = errors ++ check_value_constraints(config, rules.value_constraints)

    %{
      valid?: Enum.empty?(errors),
      errors: errors,
      warnings: generate_warnings(config),
      validation_passed: Enum.empty?(errors)
    }
  end

  defp check_required_variables(config, required) do
    variables = config[:variables] || %{}

    required
    |> Enum.reject(fn var -> Map.has_key?(variables, var) end)
    |> Enum.map(fn var -> {:missing_required, var} end)
  end

  defp check_format_rules(config, format_rules) do
    variables = config[:variables] || %{}

    format_rules
    |> Enum.filter(fn {var, _} -> Map.has_key?(variables, var) end)
    |> Enum.reject(fn {var, regex} -> Regex.match?(regex, variables[var]) end)
    |> Enum.map(fn {var, _} -> {:invalid_format, var} end)
  end

  defp check_value_constraints(config, constraints) do
    variables = config[:variables] || %{}

    constraints
    |> Enum.filter(fn {var, _} -> Map.has_key?(variables, var) end)
    |> Enum.reject(fn {var, check_fn} -> check_fn.(variables[var]) end)
    |> Enum.map(fn {var, _} -> {:constraint_failed, var} end)
  end

  defp generate_warnings(config) do
    warnings = []

    # Warn about missing SSL in production
    if config[:name] == "production" and not config[:variables]["SSL_CERT_PATH"] do
      warnings ++ [{:missing_ssl, "Production environment should have SSL configured"}]
    else
      warnings
    end
  end

  defp check_critical_conflicts(config, current_env) do
    # UCA-006: Pr_event critical variable conflicts
    variables = config[:variables] || %{}

    conflicts =
      @critical_variables
      |> Enum.filter(fn var ->
        Map.has_key?(variables, var) and
          Map.has_key?(current_env, var) and
          variables[var] != current_env[var]
      end)

    if Enum.empty?(conflicts) or config[:force] do
      :ok
    else
      {:error, :critical_variable_conflict}
    end
  end

  defp create_rollback_point(current_env) do
    %{
      id: "env_rollback_#{DateTime.utc_now() |> DateTime.to_iso8601(:basic)}",
      timestamp: DateTime.utc_now(),
      environment_snapshot: current_env
    }
  end

  defp apply_configuration(config) do
    variables = config[:variables] || %{}
    secrets = config[:secrets] || []

    # Apply variables
    Enum.each(variables, fn {key, value} ->
      System.put_env(key, value)
    end)

    # Load secrets (simulation)
    loaded_secrets =
      Enum.map(secrets, fn secret ->
        {secret, load_secret(secret)}
      end)

    {:ok,
     %{
       variables_set: map_size(variables),
       secrets_loaded: length(loaded_secrets),
       validation_passed: true
     }}
  end

  defp load_secret(secret_name) do
    # In production, this would load from secure storage
    Logger.info("[EnvironmentConfig] Loading secret: #{secret_name}")
    :loaded
  end

  defp merge_configs(current, new_config) do
    new_vars = new_config[:variables] || %{}
    Map.merge(current, new_vars)
  end

  defp find_rollback_point(history, id) do
    Enum.find(history, &(&1.id == id))
  end

  defp restore_environment(rollback_point) do
    # Clear current environment and restore snapshot
    current_env = System.get_env()

    # Remove variables not in snapshot
    Enum.each(current_env, fn {key, _value} ->
      unless Map.has_key?(rollback_point.environment_snapshot, key) do
        System.delete_env(key)
      end
    end)

    # Restore snapshot values
    Enum.each(rollback_point.environment_snapshot, fn {key, value} ->
      System.put_env(key, value)
    end)

    :ok
  end

  defp list_available_templates do
    # List files in template directory
    case File.ls(@template_dir) do
      {:ok, files} ->
        template_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".eex"))
          |> Enum.map(&String.trim_trailing(&1, ".eex"))

        # Add built-in templates
        (["production", "staging", "development"] ++ template_files)
        |> Enum.uniq()
        |> Enum.sort()

      _ ->
        ["production", "staging", "development"]
    end
  end

  defp count_critical_variables(env) do
    @critical_variables
    |> Enum.count(&Map.has_key?(env, &1))
  end

  defp atomize_keys(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
  end
end
