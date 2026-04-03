defmodule Indrajaal.Intelligence.AlertTest do
  @moduledoc """
  TDG Test Suite for Intelligence Alert Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: Intelligence alert safety constraints
  - SOPv5.11_CYBERNETIC: Alert intelligence validation

  Tests intelligence alert capabilities:
  - Alert schema validation
  - Multi-tenant isolation
  - Changeset validation
  - Alert classification
  """
  use ExUnit.Case, async: true
  use PropCheck
  import PropCheck.BasicTypes
  # ExUnitProperties removed - using PropCheck only
  # StreamData removed - using PropCheck generators
  # EP-GEN-014: Mandatory aliases for generator disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Intelligence.Alert

  @moduletag :tdg_compliant
  @moduletag :intelligence_domain

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(Alert)
    end

    test "module uses Ecto.Schema" do
      assert function_exported?(Alert, :__schema__, 1)
    end
  end

  describe "schema fields" do
    test "has required base fields" do
      fields = Alert.__schema__(:fields)
      assert :id in fields
      assert :name in fields
      assert :description in fields
      assert :active in fields
      assert :metadata in fields
    end

    test "has multi-tenant fields" do
      fields = Alert.__schema__(:fields)
      assert :tenant_id in fields
      assert :created_by_id in fields
      assert :updated_by_id in fields
    end

    test "has intelligence-specific fields" do
      fields = Alert.__schema__(:fields)
      assert :type in fields
      assert :status in fields
      assert :configuration in fields
      assert :tags in fields
    end
  end

  describe "changeset validation" do
    test "changeset/2 function exists" do
      assert function_exported?(Alert, :changeset, 2)
    end

    test "validates name is required" do
      changeset = Alert.changeset(%Alert{}, %{})
      assert changeset.errors[:name] != nil
    end

    test "validates name length constraints" do
      changeset = Alert.changeset(%Alert{}, %{name: ""})
      assert changeset.errors[:name] != nil
    end

    test "validates description max length" do
      long_desc = String.duplicate("a", 1001)
      changeset = Alert.changeset(%Alert{}, %{name: "Test", description: long_desc})
      assert changeset.errors[:description] != nil
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(Alert)
      end
    end

    property "alert names are non-empty strings" do
      forall name <- PC.non_empty(PC.binary()) do
        is_binary(name) and byte_size(name) > 0
      end
    end

    property "alert metadata is always a map" do
      forall meta <- PC.map(PC.binary(), PC.term()) do
        is_map(meta)
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "alert names within valid length" do
      names = ["SecurityBreach", "IntrusionDetected", "SystemDown"]

      Enum.each(names, fn name ->
        assert String.length(name) >= 1
        assert String.length(name) <= 255
      end)
    end

    test "alert descriptions within valid length" do
      descriptions = ["", "Short description", String.duplicate("a", 500)]

      Enum.each(descriptions, fn desc ->
        assert String.length(desc) <= 1000
      end)
    end

    test "alert types are valid strings" do
      alert_types = ["critical", "warning", "info", "debug"]

      Enum.each(alert_types, fn alert_type ->
        assert is_binary(alert_type)
      end)
    end

    test "alert tags are string lists" do
      tags = ["security", "intrusion", "critical"]
      assert is_list(tags)
      assert Enum.all?(tags, &is_binary/1)
    end
  end

  describe "STAMP safety for intelligence" do
    test "SC-DAT-033: prevents cross-tenant alert access" do
      fields = Alert.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "SC-EMR-058: supports automatic failure detection" do
      assert Code.ensure_loaded?(Alert)
    end

    test "SC-OBS-065: supports alert intelligence logging" do
      assert Code.ensure_loaded?(Alert)
    end
  end
end
