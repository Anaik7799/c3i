defmodule Indrajaal.Shared.UnifiedHelperPatternsTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.UnifiedHelperPatterns module.

  Tests unified shared helper patterns for:
  - format_changeset_errors function
  - format_datetime function
  - validate_required_fields function
  - sanitize_params function

  Created: 2025-11-27 16:30:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Helper Patterns)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.UnifiedHelperPatterns
  alias Ecto.Changeset

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "UnifiedHelperPatterns module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.UnifiedHelperPatterns)
    end

    test "module exports format_changeset_errors function" do
      functions = Indrajaal.Shared.UnifiedHelperPatterns.__info__(:functions)
      assert {:format_changeset_errors, 1} in functions
    end

    test "module exports format_datetime function" do
      functions = Indrajaal.Shared.UnifiedHelperPatterns.__info__(:functions)
      assert {:format_datetime, 1} in functions
    end

    test "module exports validate_required_fields function" do
      functions = Indrajaal.Shared.UnifiedHelperPatterns.__info__(:functions)
      assert {:validate_required_fields, 2} in functions
    end

    test "module exports sanitize_params function" do
      functions = Indrajaal.Shared.UnifiedHelperPatterns.__info__(:functions)
      assert {:sanitize_params, 1} in functions
    end
  end

  # ============================================================================
  # FORMAT_CHANGESET_ERRORS TESTS
  # ============================================================================

  describe "format_changeset_errors/1" do
    test "formats changeset with single error" do
      changeset = %Changeset{
        errors: [name: {"can't be blank", [validation: :required]}],
        valid?: false
      }

      result = UnifiedHelperPatterns.format_changeset_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :name)
    end

    test "formats changeset with multiple errors" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", [validation: :required]},
          email: {"has invalid format", [validation: :format]}
        ],
        valid?: false
      }

      result = UnifiedHelperPatterns.format_changeset_errors(changeset)

      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
    end

    test "formats changeset with no errors" do
      changeset = %Changeset{
        errors: [],
        valid?: true
      }

      result = UnifiedHelperPatterns.format_changeset_errors(changeset)

      assert result == %{}
    end

    test "interpolates error message placeholders" do
      changeset = %Changeset{
        errors: [count: {"must be at least %{count}", [count: 5, validation: :length]}],
        valid?: false
      }

      result = UnifiedHelperPatterns.format_changeset_errors(changeset)

      assert Map.has_key?(result, :count)
      errors = Map.get(result, :count)
      assert is_list(errors)
    end
  end

  # ============================================================================
  # FORMAT_DATETIME TESTS
  # ============================================================================

  describe "format_datetime/1" do
    test "formats DateTime struct" do
      {:ok, datetime} = DateTime.new(~D[2025-11-27], ~T[16:30:00], "Etc/UTC")

      result = UnifiedHelperPatterns.format_datetime(datetime)

      assert is_binary(result)
      assert String.contains?(result, "2025")
      assert String.contains?(result, "11")
      assert String.contains?(result, "27")
    end

    test "formats NaiveDateTime" do
      naive_datetime = ~N[2025-11-27 16:30:00]

      result = UnifiedHelperPatterns.format_datetime(naive_datetime)

      assert is_binary(result)
      assert String.contains?(result, "2025")
    end

    test "returns formatted string with time components" do
      {:ok, datetime} = DateTime.new(~D[2025-01-15], ~T[10:30:45], "Etc/UTC")

      result = UnifiedHelperPatterns.format_datetime(datetime)

      assert String.contains?(result, "10")
      assert String.contains?(result, "30")
      assert String.contains?(result, "45")
    end
  end

  # ============================================================================
  # VALIDATE_REQUIRED_FIELDS TESTS
  # ============================================================================

  describe "validate_required_fields/2" do
    test "returns ok when all required fields present" do
      params = %{name: "Test", email: "test@example.com"}
      required = [:name, :email]

      result = UnifiedHelperPatterns.validate_required_fields(params, required)

      assert result == {:ok, params}
    end

    test "returns error with missing fields" do
      params = %{name: "Test"}
      required = [:name, :email, :phone]

      result = UnifiedHelperPatterns.validate_required_fields(params, required)

      assert {:error, {:missing_fields, missing}} = result
      assert :email in missing
      assert :phone in missing
    end

    test "returns ok for empty required fields list" do
      params = %{any: "value"}
      required = []

      result = UnifiedHelperPatterns.validate_required_fields(params, required)

      assert result == {:ok, params}
    end

    test "returns error for empty params with required fields" do
      params = %{}
      required = [:name]

      result = UnifiedHelperPatterns.validate_required_fields(params, required)

      assert {:error, {:missing_fields, [:name]}} = result
    end

    test "handles string keys in params map" do
      params = %{"name" => "Test"}
      required = [:name]

      result = UnifiedHelperPatterns.validate_required_fields(params, required)

      # String keys don't match atom required fields
      assert {:error, {:missing_fields, [:name]}} = result
    end
  end

  # ============================================================================
  # SANITIZE_PARAMS TESTS
  # ============================================================================

  describe "sanitize_params/1" do
    test "removes nil values" do
      params = %{name: "Test", email: nil, phone: "123"}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert result == %{name: "Test", phone: "123"}
    end

    test "removes empty string values" do
      params = %{name: "Test", email: "", phone: "123"}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert result == %{name: "Test", phone: "123"}
    end

    test "removes both nil and empty strings" do
      params = %{a: nil, b: "", c: "value", d: nil}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert result == %{c: "value"}
    end

    test "preserves non-empty values" do
      params = %{name: "Test", count: 0, active: false}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :count)
      assert Map.has_key?(result, :active)
    end

    test "handles empty map" do
      params = %{}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert result == %{}
    end

    test "handles map with only nil/empty values" do
      params = %{a: nil, b: ""}

      result = UnifiedHelperPatterns.sanitize_params(params)

      assert result == %{}
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "format_changeset_errors returns map" do
      forall errors <- PC.list({PC.atom(), {PC.binary(), PC.list()}}) do
        changeset = %Changeset{errors: errors, valid?: false}
        result = UnifiedHelperPatterns.format_changeset_errors(changeset)
        is_map(result)
      end
    end

    property "sanitize_params always returns map" do
      forall params <- PC.map(PC.atom(), PC.any()) do
        result = UnifiedHelperPatterns.sanitize_params(params)
        is_map(result)
      end
    end

    property "sanitize_params never returns nil or empty string values" do
      forall params <- PC.map(PC.atom(), PC.oneof([nil, PC.binary(), PC.integer(), PC.boolean()])) do
        result = UnifiedHelperPatterns.sanitize_params(params)
        Enum.all?(Map.values(result), fn v -> v != nil and v != "" end)
      end
    end

    property "validate_required_fields returns ok or error tuple" do
      forall {params, required} <- {PC.map(PC.atom(), PC.binary()), PC.list(PC.atom())} do
        result = UnifiedHelperPatterns.validate_required_fields(params, required)

        case result do
          {:ok, _} -> true
          {:error, {:missing_fields, _}} -> true
          _ -> false
        end
      end
    end

    property "validate_required_fields with empty required list always succeeds" do
      forall params <- PC.map(PC.atom(), PC.any()) do
        {:ok, ^params} = UnifiedHelperPatterns.validate_required_fields(params, [])
        true
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "format_changeset_errors handles empty changeset" do
      changeset = %Changeset{}

      result = UnifiedHelperPatterns.format_changeset_errors(changeset)

      assert is_map(result)
    end

    test "module info returns expected structure" do
      info = UnifiedHelperPatterns.__info__(:module)
      assert info == Indrajaal.Shared.UnifiedHelperPatterns
    end

    test "sanitize_params preserves zero values" do
      params = %{count: 0}
      result = UnifiedHelperPatterns.sanitize_params(params)
      assert result.count == 0
    end

    test "sanitize_params preserves false boolean" do
      params = %{active: false}
      result = UnifiedHelperPatterns.sanitize_params(params)
      assert result.active == false
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/unified_helper_patterns.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/unified_helper_patterns.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/unified_helper_patterns.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.UnifiedHelperPatterns")
    end

    test "format_changeset_errors has @spec" do
      source = File.read!("lib/indrajaal/shared/unified_helper_patterns.ex")
      assert String.contains?(source, "@spec format_changeset_errors")
    end

    test "validate_required_fields has @spec" do
      source = File.read!("lib/indrajaal/shared/unified_helper_patterns.ex")
      assert String.contains?(source, "@spec validate_required_fields")
    end

    test "sanitize_params has @spec" do
      source = File.read!("lib/indrajaal/shared/unified_helper_patterns.ex")
      assert String.contains?(source, "@spec sanitize_params")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "sanitize then validate workflow" do
      params = %{name: "Test", email: nil, phone: ""}
      required = [:name]

      sanitized = UnifiedHelperPatterns.sanitize_params(params)
      result = UnifiedHelperPatterns.validate_required_fields(sanitized, required)

      assert {:ok, %{name: "Test"}} = result
    end

    test "all helper functions are accessible" do
      functions = UnifiedHelperPatterns.__info__(:functions)

      helper_functions = [
        {:format_changeset_errors, 1},
        {:format_datetime, 1},
        {:validate_required_fields, 2},
        {:sanitize_params, 1}
      ]

      Enum.each(helper_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
