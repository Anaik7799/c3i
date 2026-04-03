defmodule Indrajaal.Morphogenic.L5ConfigurationManagementTest do
  @moduledoc """
  L5 Morphogenic Evolution Test: Configuration Management Safety

  Tests node-level configuration management: environment variable validation,
  config schema enforcement, hot-reload safety, and configuration drift
  detection. Validates that runtime configuration changes are safe.

  ## Fractal Layer
  L5 — Node (Runtime environment, configuration)

  ## STAMP Constraints
  - SC-CONSOL-005: Config validation at boot (fail fast)
  - SC-CONSOL-006: ConfigBridge syncs F#/Elixir configs
  - SC-ENV-001: Environment variable validation
  - AOR-CONSOL-004: VALIDATE config at startup, fail fast

  ## Morphogenic Task
  Auto-generated for 80% saturation — L5 substrate
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l5
  @moduletag :l5_config_management

  # ── ETS Table Setup ──────────────────────────────────────────────────

  @config_store :l5_config_store_table
  @config_history :l5_config_history_table
  @config_schema :l5_config_schema_table

  setup do
    for table <- [@config_store, @config_history, @config_schema] do
      if :ets.whereis(table) != :undefined, do: :ets.delete(table)
    end

    :ets.new(@config_store, [:named_table, :set, :public])
    :ets.new(@config_history, [:named_table, :ordered_set, :public])
    :ets.new(@config_schema, [:named_table, :set, :public])

    # Register default schema
    register_schema(:port, %{type: :integer, min: 1, max: 65535, required: true})
    register_schema(:host, %{type: :string, pattern: ~r/^[a-zA-Z0-9.\-]+$/, required: true})

    register_schema(:timeout_ms, %{
      type: :integer,
      min: 0,
      max: 600_000,
      required: false,
      default: 5000
    })

    register_schema(:log_level, %{
      type: :atom,
      values: [:debug, :info, :warning, :error],
      required: false,
      default: :info
    })

    register_schema(:tls_enabled, %{type: :boolean, required: false, default: false})

    on_exit(fn ->
      for table <- [@config_store, @config_history, @config_schema] do
        try do
          :ets.delete(table)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  # ── Schema Validation ────────────────────────────────────────────────

  describe "config schema validation" do
    test "valid integer within range passes" do
      assert :ok = set_config(:port, 4000)
      assert {:ok, 4000} = get_config(:port)
    end

    test "integer out of range rejected" do
      assert {:error, {:validation, _}} = set_config(:port, 70_000)
      assert {:error, {:validation, _}} = set_config(:port, 0)
    end

    test "valid string matching pattern passes" do
      assert :ok = set_config(:host, "localhost")
      assert :ok = set_config(:host, "192.168.1.1")
    end

    test "string not matching pattern rejected" do
      assert {:error, {:validation, _}} = set_config(:host, "host; rm -rf /")
    end

    test "valid atom from allowed values passes" do
      assert :ok = set_config(:log_level, :debug)
      assert :ok = set_config(:log_level, :error)
    end

    test "atom not in allowed values rejected" do
      assert {:error, {:validation, _}} = set_config(:log_level, :trace)
    end

    test "boolean validation" do
      assert :ok = set_config(:tls_enabled, true)
      assert :ok = set_config(:tls_enabled, false)
      assert {:error, {:validation, _}} = set_config(:tls_enabled, "yes")
    end

    test "unregistered key rejected" do
      assert {:error, :unknown_key} = set_config(:nonexistent_key, "value")
    end

    test "required key validated on boot check" do
      set_config(:port, 4000)
      set_config(:host, "localhost")
      assert :ok = validate_required_config()
    end

    test "missing required key fails boot check" do
      set_config(:port, 4000)
      # host is required but not set
      assert {:error, {:missing_required, [:host]}} = validate_required_config()
    end
  end

  # ── Config History ───────────────────────────────────────────────────

  describe "configuration change history" do
    test "changes are tracked with timestamps" do
      set_config(:port, 4000)
      set_config(:port, 4001)
      set_config(:port, 4002)

      history = get_config_history(:port)
      assert length(history) == 3
      values = Enum.map(history, fn {_ts, _key, val, _prev} -> val end)
      assert values == [4000, 4001, 4002]
    end

    test "previous value recorded on change" do
      set_config(:port, 4000)
      set_config(:port, 4001)

      history = get_config_history(:port)
      {_ts, :port, 4001, prev} = List.last(history)
      assert prev == 4000
    end

    test "history is append-only" do
      set_config(:log_level, :info)
      count_before = length(get_config_history(:log_level))
      set_config(:log_level, :debug)
      count_after = length(get_config_history(:log_level))
      assert count_after == count_before + 1
    end
  end

  # ── Hot Reload Safety ────────────────────────────────────────────────

  describe "hot reload safety" do
    test "config reload validates all keys" do
      set_config(:port, 4000)
      set_config(:host, "localhost")

      new_config = %{port: 5000, host: "new-host", log_level: :debug}
      assert :ok = hot_reload(new_config)
      assert {:ok, 5000} = get_config(:port)
      assert {:ok, "new-host"} = get_config(:host)
    end

    test "invalid reload rolls back all changes" do
      set_config(:port, 4000)
      set_config(:host, "localhost")

      bad_config = %{port: 99_999, host: "new-host"}
      assert {:error, _} = hot_reload(bad_config)

      # Original values preserved
      assert {:ok, 4000} = get_config(:port)
      assert {:ok, "localhost"} = get_config(:host)
    end

    test "partial reload only touches specified keys" do
      set_config(:port, 4000)
      set_config(:host, "localhost")
      set_config(:log_level, :info)

      assert :ok = hot_reload(%{log_level: :debug})
      assert {:ok, 4000} = get_config(:port)
      assert {:ok, "localhost"} = get_config(:host)
      assert {:ok, :debug} = get_config(:log_level)
    end
  end

  # ── Configuration Drift Detection ────────────────────────────────────

  describe "drift detection" do
    test "no drift when config matches expected" do
      expected = %{port: 4000, host: "localhost"}
      set_config(:port, 4000)
      set_config(:host, "localhost")

      assert {:ok, :no_drift} = check_drift(expected)
    end

    test "drift detected when config differs" do
      expected = %{port: 4000, host: "localhost"}
      set_config(:port, 5000)
      set_config(:host, "localhost")

      assert {:error, {:drift, drifts}} = check_drift(expected)
      assert :port in Keyword.keys(drifts)
    end

    test "drift report includes expected and actual" do
      expected = %{port: 4000}
      set_config(:port, 5000)

      {:error, {:drift, drifts}} = check_drift(expected)
      {expected_val, actual_val} = Keyword.get(drifts, :port)
      assert expected_val == 4000
      assert actual_val == 5000
    end
  end

  # ── Default Values ───────────────────────────────────────────────────

  describe "default value handling" do
    test "default used when key not explicitly set" do
      assert {:ok, 5000} = get_config_with_default(:timeout_ms)
      assert {:ok, :info} = get_config_with_default(:log_level)
    end

    test "explicit value overrides default" do
      set_config(:timeout_ms, 10_000)
      assert {:ok, 10_000} = get_config_with_default(:timeout_ms)
    end

    test "required key with no default returns error" do
      assert {:error, :not_set} = get_config_with_default(:port)
    end
  end

  # ── PropCheck Properties ─────────────────────────────────────────────

  describe "property: valid config always retrievable" do
    @tag timeout: 30_000
    property "set then get returns same value for valid integers" do
      forall port <- PC.range(1, 65535) do
        set_config(:port, port)
        {:ok, got} = get_config(:port)
        got == port
      end
    end
  end

  describe "property: invalid config never stored" do
    @tag timeout: 30_000
    property "out-of-range port rejected and previous preserved" do
      forall {valid_port, invalid_port} <- {PC.range(1, 65535), PC.range(70_000, 100_000)} do
        set_config(:port, valid_port)
        set_config(:port, invalid_port)
        {:ok, got} = get_config(:port)
        got == valid_port
      end
    end
  end

  # ── StreamData Properties ────────────────────────────────────────────

  describe "streamdata: hot reload atomicity" do
    @tag timeout: 30_000
    test "reload is atomic — all-or-nothing" do
      SD.tuple({SD.integer(1..65535), SD.string(:alphanumeric, min_length: 1, max_length: 20)})
      |> Enum.take(20)
      |> Enum.each(fn {port, host} ->
        set_config(:port, port)
        set_config(:host, host)

        # Invalid reload should not change anything
        bad = %{port: 0, host: host}
        hot_reload(bad)

        {:ok, current_port} = get_config(:port)
        assert current_port == port
      end)
    end
  end

  describe "streamdata: history growth is monotonic" do
    @tag timeout: 30_000
    test "each set_config adds exactly one history entry" do
      SD.list_of(SD.integer(1..65535), min_length: 1, max_length: 20)
      |> Enum.take(20)
      |> Enum.each(fn values ->
        # Clear any previous history by using fresh key via schema
        key = :port
        initial_len = length(get_config_history(key))

        for val <- values do
          set_config(key, val)
        end

        final_len = length(get_config_history(key))
        assert final_len == initial_len + length(values)
      end)
    end
  end

  # ── Helper Functions ─────────────────────────────────────────────────

  defp register_schema(key, schema) do
    :ets.insert(@config_schema, {key, schema})
  end

  defp set_config(key, value) do
    case :ets.lookup(@config_schema, key) do
      [{^key, schema}] ->
        case validate_value(value, schema) do
          :ok ->
            prev =
              case :ets.lookup(@config_store, key) do
                [{^key, old_val}] -> old_val
                [] -> nil
              end

            :ets.insert(@config_store, {key, value})
            :ets.insert(@config_history, {System.monotonic_time(:nanosecond), key, value, prev})
            :ok

          {:error, reason} ->
            {:error, {:validation, reason}}
        end

      [] ->
        {:error, :unknown_key}
    end
  end

  defp get_config(key) do
    case :ets.lookup(@config_store, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_set}
    end
  end

  defp get_config_with_default(key) do
    case get_config(key) do
      {:ok, _} = result ->
        result

      {:error, :not_set} ->
        case :ets.lookup(@config_schema, key) do
          [{^key, %{default: default}}] -> {:ok, default}
          _ -> {:error, :not_set}
        end
    end
  end

  defp get_config_history(key) do
    :ets.foldl(
      fn
        {ts, ^key, val, prev}, acc -> [{ts, key, val, prev} | acc]
        _, acc -> acc
      end,
      [],
      @config_history
    )
    |> Enum.sort_by(fn {ts, _, _, _} -> ts end)
  end

  defp validate_value(value, %{type: :integer} = schema) do
    cond do
      not is_integer(value) -> {:error, "expected integer, got #{inspect(value)}"}
      Map.has_key?(schema, :min) and value < schema.min -> {:error, "below minimum #{schema.min}"}
      Map.has_key?(schema, :max) and value > schema.max -> {:error, "above maximum #{schema.max}"}
      true -> :ok
    end
  end

  defp validate_value(value, %{type: :string} = schema) do
    cond do
      not is_binary(value) ->
        {:error, "expected string"}

      Map.has_key?(schema, :pattern) and not Regex.match?(schema.pattern, value) ->
        {:error, "does not match pattern"}

      true ->
        :ok
    end
  end

  defp validate_value(value, %{type: :atom} = schema) do
    cond do
      not is_atom(value) ->
        {:error, "expected atom"}

      Map.has_key?(schema, :values) and value not in schema.values ->
        {:error, "not in allowed values #{inspect(schema.values)}"}

      true ->
        :ok
    end
  end

  defp validate_value(value, %{type: :boolean}) do
    if is_boolean(value), do: :ok, else: {:error, "expected boolean"}
  end

  defp validate_required_config do
    missing =
      :ets.foldl(
        fn {key, schema}, acc ->
          if schema[:required] do
            case :ets.lookup(@config_store, key) do
              [] -> [key | acc]
              _ -> acc
            end
          else
            acc
          end
        end,
        [],
        @config_schema
      )

    if missing == [], do: :ok, else: {:error, {:missing_required, missing}}
  end

  defp hot_reload(new_config) do
    # Snapshot current state
    snapshot = :ets.tab2list(@config_store)

    results =
      Enum.map(new_config, fn {key, value} ->
        {key, set_config(key, value)}
      end)

    errors = Enum.filter(results, fn {_key, result} -> result != :ok end)

    if errors == [] do
      :ok
    else
      # Rollback
      :ets.delete_all_objects(@config_store)
      for {key, val} <- snapshot, do: :ets.insert(@config_store, {key, val})
      {:error, {:reload_failed, errors}}
    end
  end

  defp check_drift(expected) do
    drifts =
      Enum.reduce(expected, [], fn {key, expected_val}, acc ->
        case get_config(key) do
          {:ok, ^expected_val} -> acc
          {:ok, actual} -> [{key, {expected_val, actual}} | acc]
          {:error, :not_set} -> [{key, {expected_val, :not_set}} | acc]
        end
      end)

    if drifts == [], do: {:ok, :no_drift}, else: {:error, {:drift, drifts}}
  end
end
