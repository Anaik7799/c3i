defmodule Indrajaal.Morphogenic.L1TypeSafetyBoundariesTest do
  @moduledoc """
  WHAT: L1 Fractal Layer — Type Safety at Boundaries
  WHY: Verifies that all system boundary crossings enforce strict type contracts,
       preventing invalid data from propagating through the SIL-6 biomorphic mesh.
       This covers API input validation, Zenoh message type enforcement, database read
       coercion, struct field validation, guard clause coverage, nil/null safety, and
       atom exhaustion prevention.

  ## Architecture
  Self-contained simulation using ETS tables as stand-ins for:
  - Type registry (maps type names → validation specs)
  - Boundary validation result cache (memoized coercion results)
  - Violation log (audit trail of type failures)

  ## STAMP Compliance
  - SC-SIL4-002: Type boundary checks mandatory (fail-closed)
  - SC-TYPE-001: Type safety validation enforced at all boundaries
  - SC-VALID-001: STAMP references for every validated action

  ## Fractal Layer
  L1 (Function): Pure input/output contracts, boundary coercion, type guards

  ## Constitutional Alignment
  - Ψ₀ Existence: Invalid types fail-closed, never silently corrupt state
  - Ψ₃ Verification: All boundary crossings leave an audit trail
  """

  use ExUnit.Case, async: false

  # EP-GEN-014 compliant dual-property header
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l1
  @moduletag :type_safety

  # ---------------------------------------------------------------------------
  # ETS Table Names (self-contained simulation)
  # ---------------------------------------------------------------------------

  @type_registry :l1_type_registry
  @validation_cache :l1_validation_cache
  @violation_log :l1_violation_log
  @struct_registry :l1_struct_registry

  # ---------------------------------------------------------------------------
  # Boundary Type Specifications (simulated typespec registry)
  # ---------------------------------------------------------------------------

  # Supported primitive types at boundaries
  @primitive_types [:integer, :float, :string, :boolean, :atom, :binary, :list, :map]

  # Coercible type pairs: {from_type, to_type}
  @coercible_pairs [
    {:string, :integer},
    {:string, :float},
    {:string, :boolean},
    {:string, :atom},
    {:string, :datetime},
    {:integer, :float},
    {:integer, :string},
    {:float, :string},
    {:boolean, :string},
    {:atom, :string}
  ]

  # Atom allowlist (prevents exhaustion attacks)
  @safe_atoms [
    :ok,
    :error,
    :pending,
    :active,
    :inactive,
    :healthy,
    :degraded,
    :critical,
    :info,
    :warning,
    :debug,
    :alert,
    :emergency,
    :notice,
    :read,
    :write,
    :create,
    :update,
    :delete,
    :low,
    :medium,
    :high,
    :p0,
    :p1,
    :p2,
    :p3,
    :zenoh,
    :database,
    :api,
    :mcp,
    :internal
  ]

  # Maximum allowed dynamic atoms (SC-SIL4-002 atom exhaustion prevention)
  @max_dynamic_atoms 100

  # ---------------------------------------------------------------------------
  # Simulated Struct Specs
  # ---------------------------------------------------------------------------

  @struct_specs %{
    ZenohMessage: %{
      required: [:topic, :payload, :timestamp],
      optional: [:metadata, :ttl],
      types: %{
        topic: :string,
        payload: :binary,
        timestamp: :datetime,
        ttl: :integer,
        metadata: :map
      }
    },
    ApiRequest: %{
      required: [:method, :path, :tenant_id],
      optional: [:body, :headers, :timeout_ms],
      types: %{
        method: :atom,
        path: :string,
        tenant_id: :string,
        body: :map,
        headers: :map,
        timeout_ms: :integer
      }
    },
    DatabaseRow: %{
      required: [:id, :inserted_at],
      optional: [:updated_at, :deleted_at],
      types: %{
        id: :string,
        inserted_at: :datetime,
        updated_at: :datetime,
        deleted_at: :datetime
      }
    },
    SensorReading: %{
      required: [:sensor_id, :value, :unit, :recorded_at],
      optional: [:confidence, :source],
      types: %{
        sensor_id: :string,
        value: :float,
        unit: :atom,
        recorded_at: :datetime,
        confidence: :float,
        source: :atom
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup_all do
    # Create ETS tables for self-contained simulation
    :ets.new(@type_registry, [:set, :public, :named_table])
    :ets.new(@validation_cache, [:set, :public, :named_table])
    :ets.new(@violation_log, [:bag, :public, :named_table])
    :ets.new(@struct_registry, [:set, :public, :named_table])

    # Seed type registry
    Enum.each(@primitive_types, fn type ->
      :ets.insert(@type_registry, {type, %{valid: true, coercible_from: [], coercible_to: []}})
    end)

    # Seed coercible pairs
    Enum.each(@coercible_pairs, fn {from, to} ->
      :ets.insert(@type_registry, {{:coercible, from, to}, true})
    end)

    # Seed struct registry
    Enum.each(@struct_specs, fn {name, spec} ->
      :ets.insert(@struct_registry, {name, spec})
    end)

    on_exit(fn ->
      for tbl <- [@type_registry, @validation_cache, @violation_log, @struct_registry] do
        if :ets.whereis(tbl) != :undefined, do: :ets.delete(tbl)
      end
    end)

    :ok
  end

  setup do
    # Clear per-test caches and violation log
    :ets.delete_all_objects(@validation_cache)
    :ets.delete_all_objects(@violation_log)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Simulated Type Validation Engine (no production module deps)
  # ---------------------------------------------------------------------------

  # Infer the runtime type of a value
  defp infer_type(nil), do: :null
  defp infer_type(value) when is_integer(value), do: :integer
  defp infer_type(value) when is_float(value), do: :float
  defp infer_type(value) when is_binary(value), do: :string
  defp infer_type(value) when is_boolean(value), do: :boolean
  defp infer_type(value) when is_atom(value), do: :atom
  defp infer_type(value) when is_list(value), do: :list
  defp infer_type(value) when is_map(value), do: :map
  defp infer_type(_), do: :unknown

  # Check if a value is valid for a given expected type
  defp type_valid?(value, :integer) when is_integer(value), do: true
  defp type_valid?(value, :float) when is_float(value), do: true
  defp type_valid?(value, :float) when is_integer(value), do: true
  defp type_valid?(value, :string) when is_binary(value), do: true
  defp type_valid?(value, :boolean) when is_boolean(value), do: true
  defp type_valid?(value, :atom) when is_atom(value) and not is_nil(value), do: true
  defp type_valid?(value, :binary) when is_binary(value), do: true
  defp type_valid?(value, :list) when is_list(value), do: true
  defp type_valid?(value, :map) when is_map(value), do: true
  defp type_valid?(%DateTime{}, :datetime), do: true
  defp type_valid?(nil, _), do: false
  defp type_valid?(_, _), do: false

  # Coerce a value from its inferred type to a target type
  defp coerce(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, {:coercion_failed, value, :string, :integer}}
    end
  end

  defp coerce(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {f, ""} ->
        {:ok, f}

      _ ->
        case Integer.parse(value) do
          {i, ""} -> {:ok, i * 1.0}
          _ -> {:error, {:coercion_failed, value, :string, :float}}
        end
    end
  end

  defp coerce(value, :float) when is_integer(value), do: {:ok, value * 1.0}

  defp coerce(value, :boolean) when is_binary(value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes", "on"] -> {:ok, true}
      v when v in ["false", "0", "no", "off"] -> {:ok, false}
      _ -> {:error, {:coercion_failed, value, :string, :boolean}}
    end
  end

  defp coerce(value, :atom) when is_binary(value) do
    candidate = String.to_existing_atom(value)

    if candidate in @safe_atoms do
      {:ok, candidate}
    else
      {:error, {:unsafe_atom, value}}
    end
  rescue
    ArgumentError -> {:error, {:unknown_atom, value}}
  end

  defp coerce(value, :string) when is_integer(value), do: {:ok, Integer.to_string(value)}
  defp coerce(value, :string) when is_float(value), do: {:ok, Float.to_string(value)}
  defp coerce(value, :string) when is_boolean(value), do: {:ok, to_string(value)}
  defp coerce(value, :string) when is_atom(value), do: {:ok, Atom.to_string(value)}

  defp coerce(value, :datetime) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, reason} -> {:error, {:coercion_failed, value, :string, :datetime, reason}}
    end
  end

  defp coerce(value, type) do
    actual_type = infer_type(value)

    if actual_type == type do
      {:ok, value}
    else
      {:error, {:no_coercion, value, actual_type, type}}
    end
  end

  # Cached coercion — stores result in ETS to test idempotency
  defp cached_coerce(value, target_type) do
    cache_key = {value, target_type}

    case :ets.lookup(@validation_cache, cache_key) do
      [{^cache_key, result}] ->
        result

      [] ->
        result = coerce(value, target_type)
        :ets.insert(@validation_cache, {cache_key, result})
        result
    end
  end

  # Validate a struct-like map against a registered spec
  defp validate_struct(struct_name, data) when is_map(data) do
    case :ets.lookup(@struct_registry, struct_name) do
      [] ->
        log_violation(:unknown_struct, struct_name, data)
        {:error, {:unknown_struct, struct_name}}

      [{^struct_name, spec}] ->
        required = Map.get(spec, :required, [])
        types = Map.get(spec, :types, %{})

        missing = Enum.reject(required, &Map.has_key?(data, &1))

        type_errors =
          Enum.flat_map(types, fn {field, expected_type} ->
            case Map.get(data, field) do
              nil ->
                if field in required do
                  [{:missing_required, field}]
                else
                  []
                end

              value ->
                if type_valid?(value, expected_type) do
                  []
                else
                  [{:type_mismatch, field, expected_type, infer_type(value)}]
                end
            end
          end)

        if missing == [] and type_errors == [] do
          {:ok, data}
        else
          errors = Enum.map(missing, &{:missing_field, &1}) ++ type_errors
          log_violation(:struct_validation_failed, struct_name, errors)
          {:error, {:validation_failed, struct_name, errors}}
        end
    end
  end

  defp validate_struct(struct_name, data) do
    log_violation(:non_map_struct_data, struct_name, data)
    {:error, {:expected_map, struct_name, infer_type(data)}}
  end

  # Guard clause completeness check — verifies all atoms in a set are handled
  defp guard_covers_all_atoms?(handler_fn, atom_set) do
    Enum.all?(atom_set, fn atom ->
      try do
        case handler_fn.(atom) do
          {:error, :unhandled} -> false
          _ -> true
        end
      rescue
        FunctionClauseError -> false
      end
    end)
  end

  # Nil safety validator — fails closed on nil inputs at boundary
  defp nil_safe_validate(value, field_name, expected_type) do
    if is_nil(value) do
      log_violation(:nil_at_boundary, field_name, expected_type)
      {:error, {:nil_not_allowed, field_name}}
    else
      if type_valid?(value, expected_type) do
        {:ok, value}
      else
        log_violation(:type_mismatch_at_boundary, field_name, {infer_type(value), expected_type})
        {:error, {:type_mismatch, field_name, expected_type, infer_type(value)}}
      end
    end
  end

  # Atom exhaustion guard — only allows atoms from the safe allowlist
  defp safe_atom_from_string(str) when is_binary(str) do
    dynamic_atoms = :ets.select(@validation_cache, [{{:atom_created, :"$1"}, [], [:"$1"]}])

    if length(dynamic_atoms) >= @max_dynamic_atoms do
      {:error, :atom_exhaustion_threshold_reached}
    else
      try do
        atom = String.to_existing_atom(str)

        if atom in @safe_atoms do
          {:ok, atom}
        else
          {:error, {:atom_not_in_allowlist, str}}
        end
      rescue
        ArgumentError -> {:error, {:unknown_atom, str}}
      end
    end
  end

  defp safe_atom_from_string(value) do
    {:error, {:expected_string_for_atom_conversion, infer_type(value)}}
  end

  # Log a boundary violation to the ETS violation log
  defp log_violation(violation_type, context, detail) do
    entry = {
      violation_type,
      context,
      detail,
      System.monotonic_time(:microsecond)
    }

    :ets.insert(@violation_log, {violation_type, entry})
  end

  # Fetch all violation log entries of a given type
  defp violations_of_type(violation_type) do
    :ets.lookup(@violation_log, violation_type)
  end

  # ---------------------------------------------------------------------------
  # Unit Tests — Type Validation at Boundaries
  # ---------------------------------------------------------------------------

  describe "primitive type detection at boundary" do
    test "infers correct types for all primitives" do
      assert infer_type(42) == :integer
      assert infer_type(3.14) == :float
      assert infer_type("hello") == :string
      assert infer_type(true) == :boolean
      assert infer_type(false) == :boolean
      assert infer_type(:ok) == :atom
      assert infer_type([1, 2, 3]) == :list
      assert infer_type(%{a: 1}) == :map
      assert infer_type(nil) == :null
    end

    test "rejects nil as a valid type for any expected type (SC-SIL4-002)" do
      for expected_type <- @primitive_types do
        refute type_valid?(nil, expected_type),
               "nil should not be valid for type #{expected_type}"
      end
    end

    test "accepts valid values for each primitive type" do
      assert type_valid?(0, :integer)
      assert type_valid?(-100, :integer)
      assert type_valid?(0.0, :float)
      assert type_valid?(1, :float)
      assert type_valid?("", :string)
      assert type_valid?("hello world", :string)
      assert type_valid?(true, :boolean)
      assert type_valid?(false, :boolean)
      assert type_valid?(:ok, :atom)
      assert type_valid?([], :list)
      assert type_valid?([1, 2], :list)
      assert type_valid?(%{}, :map)
    end
  end

  describe "boundary coercion — string to integer" do
    test "coerces valid integer strings" do
      assert {:ok, 42} = coerce("42", :integer)
      assert {:ok, -7} = coerce("-7", :integer)
      assert {:ok, 0} = coerce("0", :integer)
    end

    test "rejects malformed integer strings at boundary" do
      assert {:error, _} = coerce("3.14", :integer)
      assert {:error, _} = coerce("abc", :integer)
      assert {:error, _} = coerce("", :integer)
      assert {:error, _} = coerce("1 2", :integer)
    end

    test "rejects nil input — fail-closed per SC-SIL4-002" do
      assert {:error, _} = coerce(nil, :integer)
    end
  end

  describe "boundary coercion — string to float" do
    test "coerces valid float and integer strings to float" do
      assert {:ok, 3.14} = coerce("3.14", :float)
      assert {:ok, 1.0} = coerce("1", :float)
      assert {:ok, -2.5} = coerce("-2.5", :float)
    end

    test "promotes integer to float without data loss" do
      assert {:ok, 5.0} = coerce(5, :float)
      assert {:ok, +0.0} = coerce(0, :float)
    end

    test "rejects non-numeric strings" do
      assert {:error, _} = coerce("not_a_number", :float)
      assert {:error, _} = coerce("1e", :float)
    end
  end

  describe "boundary coercion — string to boolean" do
    test "accepts truthy string representations" do
      for str <- ["true", "True", "TRUE", "1", "yes", "YES", "on", "ON"] do
        assert {:ok, true} = coerce(str, :boolean), "Expected true for #{inspect(str)}"
      end
    end

    test "accepts falsy string representations" do
      for str <- ["false", "False", "FALSE", "0", "no", "NO", "off", "OFF"] do
        assert {:ok, false} = coerce(str, :boolean), "Expected false for #{inspect(str)}"
      end
    end

    test "rejects ambiguous boolean strings" do
      for str <- ["maybe", "y", "n", "t", "f", "2", ""] do
        assert {:error, _} = coerce(str, :boolean), "Expected error for #{inspect(str)}"
      end
    end
  end

  describe "boundary coercion — ISO 8601 datetime" do
    test "parses valid ISO 8601 datetime strings" do
      assert {:ok, %DateTime{}} = coerce("2026-03-24T12:00:00Z", :datetime)
      assert {:ok, %DateTime{}} = coerce("2026-01-01T00:00:00+00:00", :datetime)
      assert {:ok, dt} = coerce("2026-03-24T15:30:00Z", :datetime)
      assert dt.year == 2026
      assert dt.month == 3
      assert dt.day == 24
    end

    test "rejects invalid datetime formats at API boundary" do
      assert {:error, _} = coerce("2026-03-24", :datetime)
      assert {:error, _} = coerce("not-a-date", :datetime)
      assert {:error, _} = coerce("24/03/2026 12:00", :datetime)
      assert {:error, _} = coerce("", :datetime)
    end
  end

  describe "atom exhaustion prevention (SC-SIL4-002)" do
    test "allows known safe atoms from allowlist" do
      for atom_str <- ["ok", "error", "pending", "active", "healthy"] do
        result = safe_atom_from_string(atom_str)
        assert {:ok, _atom} = result, "Expected #{atom_str} to be in safe atom allowlist"
      end
    end

    test "rejects strings that would create unknown atoms" do
      # These strings cannot become existing atoms
      for str <- ["definitely_not_an_atom_xyz_123", "another_unknown_9999"] do
        result = safe_atom_from_string(str)
        assert {:error, reason} = result
        assert reason in [{:unknown_atom, str}, {:atom_not_in_allowlist, str}]
      end
    end

    test "rejects non-string input for atom conversion" do
      assert {:error, _} = safe_atom_from_string(42)
      assert {:error, _} = safe_atom_from_string(nil)
      assert {:error, _} = safe_atom_from_string(3.14)
    end
  end

  describe "nil safety at boundaries" do
    test "nil_safe_validate rejects nil for any field (fail-closed)" do
      assert {:error, {:nil_not_allowed, :sensor_id}} =
               nil_safe_validate(nil, :sensor_id, :string)
    end

    test "nil_safe_validate accepts valid values" do
      assert {:ok, "s-001"} = nil_safe_validate("s-001", :sensor_id, :string)
      assert {:ok, 42} = nil_safe_validate(42, :count, :integer)
      assert {:ok, :ok} = nil_safe_validate(:ok, :status, :atom)
    end

    test "nil_safe_validate logs violations to ETS audit trail" do
      nil_safe_validate(nil, :critical_field, :string)
      violations = violations_of_type(:nil_at_boundary)
      assert length(violations) >= 1
    end

    test "type mismatch at boundary is also logged" do
      nil_safe_validate("not_an_integer", :port, :integer)
      violations = violations_of_type(:type_mismatch_at_boundary)
      assert length(violations) >= 1
    end
  end

  describe "struct validation at Zenoh message boundary" do
    test "validates a well-formed ZenohMessage" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T12:00:00Z")

      valid = %{
        topic: "indrajaal/health/node1",
        payload: <<1, 2, 3>>,
        timestamp: dt
      }

      assert {:ok, _} = validate_struct(:ZenohMessage, valid)
    end

    test "rejects ZenohMessage missing required fields" do
      incomplete = %{topic: "indrajaal/health/node1"}

      assert {:error, {:validation_failed, :ZenohMessage, errors}} =
               validate_struct(:ZenohMessage, incomplete)

      error_types = Enum.map(errors, &elem(&1, 0))
      assert :missing_field in error_types
    end

    test "rejects ZenohMessage with wrong field types" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T12:00:00Z")

      _bad_types = %{
        topic: 12345,
        payload: "not binary — actually string",
        timestamp: dt
      }

      # topic should be :string, payload should be :binary
      # Both are binary in Elixir, so topic is valid as a string/binary
      # payload is a string/binary — valid as :binary too
      # Let's test with a non-binary payload type: integer
      bad_payload = %{
        topic: "indrajaal/topic",
        payload: 99_999,
        timestamp: dt
      }

      assert {:error, _} = validate_struct(:ZenohMessage, bad_payload)
    end

    test "validates a well-formed ApiRequest" do
      valid = %{
        method: :get,
        path: "/api/v1/health",
        tenant_id: "tenant-abc-123"
      }

      assert {:ok, _} = validate_struct(:ApiRequest, valid)
    end

    test "rejects ApiRequest missing required tenant_id" do
      no_tenant = %{method: :post, path: "/api/v1/alarms"}
      assert {:error, _} = validate_struct(:ApiRequest, no_tenant)
    end

    test "rejects non-map data for struct validation" do
      assert {:error, {:expected_map, :ZenohMessage, _}} =
               validate_struct(:ZenohMessage, "not a map")

      assert {:error, {:expected_map, :ApiRequest, _}} = validate_struct(:ApiRequest, 42)
    end

    test "rejects unknown struct name" do
      assert {:error, {:unknown_struct, :Nonexistent}} = validate_struct(:Nonexistent, %{})
    end
  end

  describe "guard clause completeness verification" do
    test "guard covers all safe atoms (completeness check)" do
      # Simulate a handler that covers a known subset of safe atoms
      handled_atoms = [:ok, :error, :pending, :active, :inactive]

      handler = fn atom ->
        case atom do
          :ok -> {:handled, :ok}
          :error -> {:handled, :error}
          :pending -> {:handled, :pending}
          :active -> {:handled, :active}
          :inactive -> {:handled, :inactive}
          _ -> {:error, :unhandled}
        end
      end

      # This handler does NOT cover all @safe_atoms — should return false
      assert guard_covers_all_atoms?(handler, handled_atoms)
      refute guard_covers_all_atoms?(handler, @safe_atoms)
    end

    test "exhaustive handler covers its declared atom set" do
      atom_set = [:healthy, :degraded, :critical]

      exhaustive_handler = fn atom ->
        case atom do
          :healthy -> {:handled, :healthy}
          :degraded -> {:handled, :degraded}
          :critical -> {:handled, :critical}
        end
      end

      assert guard_covers_all_atoms?(exhaustive_handler, atom_set)
    end
  end

  describe "database read boundary coercion" do
    test "DatabaseRow struct accepts valid fields" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T10:00:00Z")

      row = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        inserted_at: dt
      }

      assert {:ok, _} = validate_struct(:DatabaseRow, row)
    end

    test "DatabaseRow rejects non-string ID (prevents SQL injection surface)" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T10:00:00Z")

      bad_row = %{
        id: 12345,
        inserted_at: dt
      }

      assert {:error, {:validation_failed, :DatabaseRow, errors}} =
               validate_struct(:DatabaseRow, bad_row)

      assert Enum.any?(errors, fn
               {:type_mismatch, :id, :string, :integer} -> true
               _ -> false
             end)
    end

    test "DatabaseRow optional fields are not required" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T10:00:00Z")

      minimal = %{id: "uuid-here", inserted_at: dt}
      assert {:ok, _} = validate_struct(:DatabaseRow, minimal)
    end
  end

  describe "SensorReading boundary validation" do
    test "validates a well-formed SensorReading" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T09:00:00Z")

      reading = %{
        sensor_id: "temp-sensor-007",
        value: 23.4,
        unit: :celsius,
        recorded_at: dt
      }

      # :celsius is not in @safe_atoms but is a valid atom — struct validates type, not allowlist
      assert {:ok, _} = validate_struct(:SensorReading, reading)
    end

    test "rejects SensorReading with string value instead of float" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T09:00:00Z")

      bad = %{
        sensor_id: "temp-001",
        value: "23.4",
        unit: :celsius,
        recorded_at: dt
      }

      assert {:error, _} = validate_struct(:SensorReading, bad)
    end
  end

  describe "ETS-backed validation cache" do
    test "caches coercion results and returns same value on second call" do
      result1 = cached_coerce("42", :integer)
      result2 = cached_coerce("42", :integer)
      assert result1 == result2
    end

    test "cache returns error consistently for invalid coercions" do
      result1 = cached_coerce("not_a_number", :integer)
      result2 = cached_coerce("not_a_number", :integer)
      assert {:error, _} = result1
      assert result1 == result2
    end

    test "different inputs produce independently cached results" do
      cached_coerce("10", :integer)
      cached_coerce("20", :integer)
      cached_coerce("bad", :integer)

      assert {:ok, 10} = cached_coerce("10", :integer)
      assert {:ok, 20} = cached_coerce("20", :integer)
      assert {:error, _} = cached_coerce("bad", :integer)
    end
  end

  # ---------------------------------------------------------------------------
  # Property Tests — EP-GEN-014 Compliant
  # ---------------------------------------------------------------------------

  # Property 1: Type coercion idempotency for string→integer
  # coerce(coerce(x, integer), string) then coerce(that, integer) == coerce(x, integer)
  property "string-to-integer coercion is stable under re-coercion", max_size: 50 do
    forall int <- PC.integer() do
      str = Integer.to_string(int)
      first_coerce = coerce(str, :integer)

      idempotent =
        case first_coerce do
          {:ok, val} ->
            str2 = Integer.to_string(val)
            coerce(str2, :integer)

          err ->
            err
        end

      first_coerce == idempotent
    end
  end

  # Property 2: Boundary rejection — invalid types for integer boundary always return error
  property "non-numeric strings are rejected at integer boundary", max_size: 20 do
    forall str <- PC.utf8() do
      case Integer.parse(str) do
        {_, ""} ->
          # Valid integer string — should succeed
          match?({:ok, _}, coerce(str, :integer))

        _ ->
          # Invalid — must be rejected at boundary (SC-SIL4-002 fail-closed)
          match?({:error, _}, coerce(str, :integer))
      end
    end
  end

  # Property 3: Float promotion from integer is lossless for small integers
  property "integer-to-float coercion preserves value", max_size: 30 do
    forall n <- PC.integer(1, 1_000_000) do
      case coerce(n, :float) do
        {:ok, f} -> f == n * 1.0
        _ -> false
      end
    end
  end

  # Property 4: Struct validation exhaustiveness — required fields presence is necessary and sufficient
  property "struct validation fails on any missing required field", max_size: 20 do
    forall required_field <- PC.oneof([:topic, :payload, :timestamp]) do
      {:ok, dt, _} = DateTime.from_iso8601("2026-03-24T12:00:00Z")

      complete = %{
        topic: "test/topic",
        payload: <<"data">>,
        timestamp: dt
      }

      incomplete = Map.delete(complete, required_field)

      complete_result = validate_struct(:ZenohMessage, complete)
      incomplete_result = validate_struct(:ZenohMessage, incomplete)

      match?({:ok, _}, complete_result) and match?({:error, _}, incomplete_result)
    end
  end

  # Property 5 (StreamData): Type validity is stable — valid values don't become invalid
  test "SD: type validity is deterministic and stable" do
    ExUnitProperties.check all(
                             int <- SD.integer(),
                             str <- SD.binary(),
                             bool <- SD.boolean()
                           ) do
      assert type_valid?(int, :integer)
      assert type_valid?(str, :string)
      assert type_valid?(bool, :boolean)
      refute type_valid?(int, :boolean)
      refute type_valid?(bool, :integer)
    end
  end

  # Property 6 (StreamData): Coercion of integer → string → integer is identity
  test "SD: integer round-trip through string coercion is identity" do
    ExUnitProperties.check all(n <- SD.integer()) do
      assert {:ok, str} = coerce(n, :string)
      assert is_binary(str)
      assert {:ok, ^n} = coerce(str, :integer)
    end
  end
end
