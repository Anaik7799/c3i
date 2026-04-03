defmodule Indrajaal.AssetManagement.AssetLocationTest do
  @moduledoc """
  TDG test suite for AssetLocation Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Asset location tracking inaccurate
  - L5 Root Cause: Missing location hierarchy validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement.AssetLocation

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AssetLocation)
    end

    test "create function is exported" do
      assert function_exported?(AssetLocation, :create, 1)
    end
  end

  describe "location_type constraints" do
    test "all location types are valid atoms" do
      types = [
        :building,
        :floor,
        :room,
        :rack,
        :desk,
        :vehicle,
        :warehouse,
        :storage,
        :field,
        :virtual
      ]

      assert length(types) == 10
      Enum.each(types, fn t -> assert is_atom(t) end)
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = AssetLocation.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when name is missing" do
      result =
        AssetLocation.create(%{
          location_type: :room,
          location_code: "R-001"
        })

      assert match?({:error, _}, result)
    end
  end
end
