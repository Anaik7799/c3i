defmodule Indrajaal.Shared.MobileViewHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.MobileViewHelpers module.

  Tests mobile API view rendering utilities for:
  - render_mobile_index function
  - render_mobile_show function
  - render_mobile_item function
  - render_mobile_error function
  - render_meta_data function
  - render_changeset_errors function
  - add_domain_specific_fields function

  Created: 2025-11-27 16:30:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Mobile View Helpers)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.MobileViewHelpers
  alias Ecto.Changeset

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "MobileViewHelpers module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.MobileViewHelpers)
    end

    test "module exports render_mobile_index function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_mobile_index, 7} in functions
    end

    test "module exports render_mobile_show function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_mobile_show, 4} in functions
    end

    test "module exports render_mobile_item function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_mobile_item, 1} in functions
    end

    test "module exports render_mobile_error function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_mobile_error, 1} in functions
    end

    test "module exports render_meta_data function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_meta_data, 0} in functions
    end

    test "module exports render_changeset_errors function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:render_changeset_errors, 1} in functions
    end

    test "module exports add_domain_specific_fields function" do
      functions = Indrajaal.Shared.MobileViewHelpers.__info__(:functions)
      assert {:add_domain_specific_fields, 2} in functions
    end

    test "module has use_mobile_view_helpers macro" do
      macros = Indrajaal.Shared.MobileViewHelpers.__info__(:macros)
      assert {:use_mobile_view_helpers, 1} in macros
    end
  end

  # ============================================================================
  # RENDER_META_DATA TESTS
  # ============================================================================

  describe "render_meta_data/0" do
    test "returns map with api_version" do
      result = MobileViewHelpers.render_meta_data()

      assert Map.has_key?(result, :api_version)
      assert result.api_version == "v1"
    end

    test "returns map with timestamp" do
      result = MobileViewHelpers.render_meta_data()

      assert Map.has_key?(result, :timestamp)
      assert is_binary(result.timestamp)
    end

    test "timestamp is ISO8601 format" do
      result = MobileViewHelpers.render_meta_data()

      # Should be valid ISO8601
      assert {:ok, _, _} = DateTime.from_iso8601(result.timestamp)
    end
  end

  # ============================================================================
  # RENDER_CHANGESET_ERRORS TESTS
  # ============================================================================

  describe "render_changeset_errors/1" do
    test "formats changeset errors to map" do
      changeset = %Changeset{
        errors: [name: {"can't be blank", [validation: :required]}],
        valid?: false
      }

      result = MobileViewHelpers.render_changeset_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :name)
    end

    test "handles multiple errors" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", []},
          email: {"is invalid", []}
        ],
        valid?: false
      }

      result = MobileViewHelpers.render_changeset_errors(changeset)

      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
    end

    test "handles empty errors" do
      changeset = %Changeset{errors: [], valid?: true}

      result = MobileViewHelpers.render_changeset_errors(changeset)

      assert result == %{}
    end
  end

  # ============================================================================
  # RENDER_MOBILE_ITEM TESTS
  # ============================================================================

  describe "render_mobile_item/1" do
    test "renders item with standard fields" do
      item = %{
        id: 1,
        name: "Test Item",
        description: "Test description",
        active: true,
        meta_data: %{key: "value"},
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      result = MobileViewHelpers.render_mobile_item(item)

      assert result.id == 1
      assert result.name == "Test Item"
      assert result.description == "Test description"
      assert result.active == true
      assert result.meta_data == %{key: "value"}
    end

    test "formats timestamps to ISO8601" do
      now = DateTime.utc_now()

      item = %{
        id: 1,
        name: "Test",
        description: "Desc",
        active: true,
        meta_data: nil,
        inserted_at: now,
        updated_at: now
      }

      result = MobileViewHelpers.render_mobile_item(item)

      assert is_binary(result.created_at)
      assert is_binary(result.updated_at)
    end

    test "handles nil meta_data" do
      item = %{
        id: 1,
        name: "Test",
        description: "Desc",
        active: true,
        meta_data: nil,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      result = MobileViewHelpers.render_mobile_item(item)

      assert result.meta_data == %{}
    end
  end

  # ============================================================================
  # RENDER_MOBILE_ERROR TESTS
  # ============================================================================

  describe "render_mobile_error/1" do
    test "returns error response with status" do
      changeset = %Changeset{
        errors: [name: {"is required", []}],
        valid?: false
      }

      result = MobileViewHelpers.render_mobile_error(changeset)

      assert result.status == "error"
    end

    test "includes errors" do
      changeset = %Changeset{
        errors: [email: {"is invalid", []}],
        valid?: false
      }

      result = MobileViewHelpers.render_mobile_error(changeset)

      assert Map.has_key?(result, :errors)
    end

    test "includes meta_data" do
      changeset = %Changeset{errors: [], valid?: false}

      result = MobileViewHelpers.render_mobile_error(changeset)

      assert Map.has_key?(result, :meta_data)
      assert Map.has_key?(result.meta_data, :api_version)
    end
  end

  # ============================================================================
  # ADD_DOMAIN_SPECIFIC_FIELDS TESTS
  # ============================================================================

  describe "add_domain_specific_fields/2" do
    test "adds type field when present in item" do
      base = %{id: 1, name: "Test"}
      item = %{type: "device"}

      result = MobileViewHelpers.add_domain_specific_fields(base, item)

      assert result.type == "device"
    end

    test "adds status field when present in item" do
      base = %{id: 1, name: "Test"}
      item = %{status: "active"}

      result = MobileViewHelpers.add_domain_specific_fields(base, item)

      assert result.status == "active"
    end

    test "adds location field when present in item" do
      base = %{id: 1, name: "Test"}
      item = %{location: "Building A"}

      result = MobileViewHelpers.add_domain_specific_fields(base, item)

      assert result.location == "Building A"
    end

    test "returns base unchanged when no domain fields" do
      base = %{id: 1, name: "Test"}
      item = %{other_field: "value"}

      result = MobileViewHelpers.add_domain_specific_fields(base, item)

      assert result == base
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "render_meta_data always returns map with api_version" do
      forall _ <- PC.integer() do
        result = MobileViewHelpers.render_meta_data()
        is_map(result) and Map.has_key?(result, :api_version)
      end
    end

    property "render_meta_data always has valid timestamp" do
      forall _ <- PC.integer() do
        result = MobileViewHelpers.render_meta_data()

        case DateTime.from_iso8601(result.timestamp) do
          {:ok, _, _} -> true
          _ -> false
        end
      end
    end

    property "render_changeset_errors always returns map" do
      forall errors <- PC.list({PC.atom(), {PC.binary(), PC.list()}}) do
        changeset = %Changeset{errors: errors, valid?: false}
        result = MobileViewHelpers.render_changeset_errors(changeset)
        is_map(result)
      end
    end

    property "add_domain_specific_fields preserves base fields" do
      forall {id, name} <- {PC.pos_integer(), PC.binary()} do
        base = %{id: id, name: name}
        item = %{other: "value"}
        result = MobileViewHelpers.add_domain_specific_fields(base, item)
        result.id == id and result.name == name
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = MobileViewHelpers.__info__(:module)
      assert info == Indrajaal.Shared.MobileViewHelpers
    end

    test "module has both functions and macros" do
      functions = MobileViewHelpers.__info__(:functions)
      macros = MobileViewHelpers.__info__(:macros)

      assert is_list(functions)
      assert is_list(macros)
      assert length(functions) > 0
      assert length(macros) > 0
    end

    test "render_changeset_errors handles empty changeset" do
      changeset = %Changeset{}

      result = MobileViewHelpers.render_changeset_errors(changeset)

      assert is_map(result)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/mobile_view_helpers.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.MobileViewHelpers")
    end

    test "render_mobile_item has @spec" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      assert String.contains?(source, "@spec render_mobile_item")
    end

    test "render_mobile_error has @spec" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      assert String.contains?(source, "@spec render_mobile_error")
    end

    test "add_domain_specific_fields has @spec" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      assert String.contains?(source, "@spec add_domain_specific_fields")
    end

    test "defines defmacro use_mobile_view_helpers" do
      source = File.read!("lib/indrajaal/shared/mobile_view_helpers.ex")
      assert String.contains?(source, "defmacro use_mobile_view_helpers")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "mobile error response workflow" do
      changeset = %Changeset{
        errors: [
          name: {"is required", [validation: :required]},
          email: {"is invalid", [validation: :format]}
        ],
        valid?: false
      }

      result = MobileViewHelpers.render_mobile_error(changeset)

      assert result.status == "error"
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :meta_data)
      assert result.meta_data.api_version == "v1"
    end

    test "mobile item with domain fields workflow" do
      item = %{
        id: 123,
        name: "Security Camera",
        description: "HD Camera",
        active: true,
        meta_data: %{resolution: "1080p"},
        type: "camera",
        status: "online",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      result = MobileViewHelpers.render_mobile_item(item)

      assert result.id == 123
      assert result.name == "Security Camera"
      # Type should be added by add_domain_specific_fields
      assert result.type == "camera"
    end

    test "all public functions are accessible" do
      functions = MobileViewHelpers.__info__(:functions)

      public_functions = [
        {:render_mobile_index, 7},
        {:render_mobile_show, 4},
        {:render_mobile_item, 1},
        {:render_mobile_error, 1},
        {:render_meta_data, 0},
        {:render_changeset_errors, 1},
        {:add_domain_specific_fields, 2}
      ]

      Enum.each(public_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
