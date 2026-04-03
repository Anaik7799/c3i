defmodule Indrajaal.Safety.STAMPRegistryTest do
  @moduledoc """
  TDG-Compliant tests for STAMPRegistry module.

  Tests STAMP safety constraint registry and validation.

  STAMP Constraints:
  - All 277+ constraints loadable at runtime
  - Guardian uses STAMP registry for validation
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Safety.STAMPRegistry

  describe "STAMPRegistry.start_link/1" do
    test "starts registry" do
      assert {:ok, pid} = STAMPRegistry.start_link(name: :test_stamp_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "STAMPRegistry.register/3" do
    test "registers a STAMP constraint" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_2)

      :ok =
        STAMPRegistry.register(reg, "SC-TEST-001", %{
          description: "Test constraint",
          category: :test,
          severity: :high
        })

      constraint = STAMPRegistry.get(reg, "SC-TEST-001")
      assert constraint.description == "Test constraint"
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.get/2" do
    test "returns constraint by ID" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_3)

      STAMPRegistry.register(reg, "SC-HOL-001", %{
        description: "All holons MUST implement all 5 systems",
        category: :holon,
        severity: :critical
      })

      constraint = STAMPRegistry.get(reg, "SC-HOL-001")

      assert constraint.id == "SC-HOL-001"
      assert constraint.category == :holon
      GenServer.stop(reg)
    end

    test "returns nil for unknown constraint" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_4)

      assert STAMPRegistry.get(reg, "SC-UNKNOWN-999") == nil
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.list_by_category/2" do
    test "returns constraints by category" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_5)

      STAMPRegistry.register(reg, "SC-HOL-001", %{category: :holon, severity: :high})
      STAMPRegistry.register(reg, "SC-HOL-002", %{category: :holon, severity: :high})
      STAMPRegistry.register(reg, "SC-BUS-001", %{category: :bus, severity: :high})

      holon_constraints = STAMPRegistry.list_by_category(reg, :holon)

      assert length(holon_constraints) == 2
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.validate/3" do
    test "validates action against constraint" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_6)

      STAMPRegistry.register(reg, "SC-TEST-001", %{
        category: :test,
        severity: :high,
        validator: fn action -> action.value < 100 end
      })

      assert {:ok, _} = STAMPRegistry.validate(reg, "SC-TEST-001", %{value: 50})

      assert {:error, :constraint_violated} =
               STAMPRegistry.validate(reg, "SC-TEST-001", %{value: 150})

      GenServer.stop(reg)
    end

    test "returns ok if no validator defined" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_7)

      STAMPRegistry.register(reg, "SC-TEST-002", %{
        category: :test,
        severity: :low
      })

      assert {:ok, _} = STAMPRegistry.validate(reg, "SC-TEST-002", %{any: :data})
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.validate_all/2" do
    test "validates action against all constraints in category" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_8)

      STAMPRegistry.register(reg, "SC-TEST-001", %{
        category: :test,
        severity: :high,
        validator: fn action -> action.value > 0 end
      })

      STAMPRegistry.register(reg, "SC-TEST-002", %{
        category: :test,
        severity: :high,
        validator: fn action -> action.value < 100 end
      })

      assert {:ok, _} = STAMPRegistry.validate_all(reg, :test, %{value: 50})
      assert {:error, violations} = STAMPRegistry.validate_all(reg, :test, %{value: -5})
      assert "SC-TEST-001" in violations
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.count/1" do
    test "returns total constraint count" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_9)

      STAMPRegistry.register(reg, "SC-A-001", %{category: :a, severity: :high})
      STAMPRegistry.register(reg, "SC-B-001", %{category: :b, severity: :high})
      STAMPRegistry.register(reg, "SC-C-001", %{category: :c, severity: :high})

      assert STAMPRegistry.count(reg) == 3
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.load_from_spec/2" do
    test "loads constraints from specification map" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_10)

      spec = %{
        "SC-HOL-001" => %{description: "Holon 1", category: :holon, severity: :critical},
        "SC-HOL-002" => %{description: "Holon 2", category: :holon, severity: :high},
        "SC-BUS-001" => %{description: "Bus 1", category: :bus, severity: :high}
      }

      :ok = STAMPRegistry.load_from_spec(reg, spec)

      assert STAMPRegistry.count(reg) == 3
      assert STAMPRegistry.get(reg, "SC-HOL-001").description == "Holon 1"
      GenServer.stop(reg)
    end
  end

  describe "STAMPRegistry.metrics/1" do
    test "returns registry metrics" do
      {:ok, reg} = STAMPRegistry.start_link(name: :test_stamp_11)

      STAMPRegistry.register(reg, "SC-A-001", %{category: :a, severity: :critical})
      STAMPRegistry.register(reg, "SC-B-001", %{category: :b, severity: :high})

      metrics = STAMPRegistry.metrics(reg)

      assert Map.has_key?(metrics, :total_constraints)
      assert Map.has_key?(metrics, :categories)
      assert Map.has_key?(metrics, :by_severity)
      assert metrics.total_constraints == 2
      GenServer.stop(reg)
    end
  end
end
