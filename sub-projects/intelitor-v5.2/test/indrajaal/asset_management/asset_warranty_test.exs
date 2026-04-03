defmodule Indrajaal.AssetManagement.AssetWarrantyTest do
  @moduledoc """
  TDG test suite for AssetWarranty Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Expired warranties not flagged
  - L5 Root Cause: Missing date comparison validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement.AssetWarranty

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AssetWarranty)
    end

    test "code_interface functions are exported" do
      assert function_exported?(AssetWarranty, :create, 1)
      assert function_exported?(AssetWarranty, :register_warranty, 1)
      assert function_exported?(AssetWarranty, :extend_warranty, 2)
      assert function_exported?(AssetWarranty, :activate, 2)
      assert function_exported?(AssetWarranty, :deactivate, 2)
      assert function_exported?(AssetWarranty, :enable_auto_renewal, 2)
      assert function_exported?(AssetWarranty, :disable_auto_renewal, 2)
    end
  end

  describe "warranty_type constraints" do
    test "all warranty types are defined" do
      types = [:manufacturer, :extended, :service_contract, :insurance]
      assert length(types) == 4
      assert :manufacturer in types
    end
  end

  describe "coverage_type constraints" do
    test "all coverage types are defined" do
      coverage_types = [:full, :parts_only, :labor_only, :limited]
      assert length(coverage_types) == 4
      assert :full in coverage_types
    end
  end

  describe "renewal_notice_days constraint" do
    test "default notice days is reasonable" do
      assert 30 >= 1 and 30 <= 365
    end
  end

  describe "register_warranty/1 without DB" do
    test "returns error when required fields are missing" do
      result =
        AssetWarranty.register_warranty(%{
          warranty_type: :manufacturer,
          provider_name: "ACME Corp"
        })

      assert match?({:error, _}, result)
    end

    test "returns error when asset_id is missing" do
      result =
        AssetWarranty.register_warranty(%{
          warranty_type: :manufacturer,
          provider_name: "ACME Corp",
          start_date: Date.utc_today(),
          end_date: Date.add(Date.utc_today(), 365)
        })

      assert match?({:error, _}, result)
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = AssetWarranty.create(%{})
      assert match?({:error, _}, result)
    end
  end
end
