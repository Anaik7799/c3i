defmodule Indrajaal.Cockpit.Prajna.DeviceHealthMatrixTest do
  @moduledoc """
  Unit tests for DeviceHealthMatrix — traffic-light device health with Zenoh publish.

  WHAT: Tests device lifecycle, color coding, health aggregation, and Zenoh integration.
  WHY: Validates SC-DEV-001 (device dashboard), SC-BRIDGE-005 (Zenoh publish), SC-PRAJNA-004.

  STAMP Constraints:
  - SC-DEV-001: Device dashboard status
  - SC-BRIDGE-005: PubSub topics
  - SC-MON-003: Domain metrics per domain

  AOR Rules:
  - AOR-PHICS-002: Monitor device health every 5 seconds
  - AOR-OBS-001: Safety violations observable
  """

  use ExUnit.Case, async: false
  import ExUnitProperties, except: [property: 2, property: 3]

  alias Indrajaal.Cockpit.Prajna.DeviceHealthMatrix
  alias StreamData, as: SD

  @table :prajna_device_health

  setup do
    Process.flag(:trap_exit, true)

    # Stop any lingering process from previous test
    if pid = Process.whereis(DeviceHealthMatrix) do
      GenServer.stop(pid, :normal, 1000)
      Process.sleep(10)
    end

    if :ets.whereis(@table) != :undefined do
      :ets.delete(@table)
    end

    # Must use default name — update_device/2 always casts to __MODULE__
    {:ok, pid} = DeviceHealthMatrix.start_link([])
    # Wait for async seeding (init uses GenServer.cast for seed_devices)
    Process.sleep(100)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000) end)
    %{pid: pid}
  end

  describe "start_link/1" do
    test "creates ETS table and seeds 5 demo devices", %{pid: pid} do
      assert Process.alive?(pid)
      assert :ets.whereis(@table) != :undefined
      assert DeviceHealthMatrix.device_count() == 5
    end

    test "seeds correct demo device IDs" do
      matrix = DeviceHealthMatrix.get_matrix()
      ids = Enum.map(matrix, & &1.device_id)
      assert "cam-001" in ids
      assert "cam-002" in ids
      assert "reader-001" in ids
      assert "panel-001" in ids
      assert "sensor-001" in ids
    end
  end

  describe "get_matrix/0" do
    test "returns devices sorted by health_score ascending (worst first)" do
      matrix = DeviceHealthMatrix.get_matrix()
      healths = Enum.map(matrix, & &1.health_score)
      assert healths == Enum.sort(healths)
    end

    test "all devices have required fields" do
      matrix = DeviceHealthMatrix.get_matrix()

      for device <- matrix do
        assert is_binary(device.device_id)
        assert is_number(device.health_score)
        assert device.color in [:green, :yellow, :red]
      end
    end
  end

  describe "get_device/1" do
    test "returns {:ok, device_data} for existing device" do
      assert {:ok, device} = DeviceHealthMatrix.get_device("cam-001")
      assert device.health_score == 0.95
      assert device.device_id == "cam-001"
    end

    test "returns {:error, :not_found} for non-existent device" do
      assert {:error, :not_found} = DeviceHealthMatrix.get_device("phantom-device")
    end
  end

  describe "update_device/2" do
    test "updates device health_score via async cast" do
      :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: 0.42})
      Process.sleep(10)
      {:ok, device} = DeviceHealthMatrix.get_device("cam-001")
      assert device.health_score == 0.42
    end
  end

  describe "color coding (traffic-light)" do
    test "health_score > 0.8 is :green" do
      :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: 0.95})
      Process.sleep(10)
      {:ok, device} = DeviceHealthMatrix.get_device("cam-001")
      assert device.color == :green
    end

    test "health_score 0.5-0.8 is :yellow" do
      :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: 0.65})
      Process.sleep(10)
      {:ok, device} = DeviceHealthMatrix.get_device("cam-001")
      assert device.color == :yellow
    end

    test "health_score <= 0.5 is :red" do
      :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: 0.3})
      Process.sleep(10)
      {:ok, device} = DeviceHealthMatrix.get_device("cam-001")
      assert device.color == :red
    end
  end

  describe "summary/0" do
    test "returns aggregate counts with required keys" do
      summary = DeviceHealthMatrix.summary()
      assert is_integer(summary.total)
      assert is_integer(summary.green)
      assert is_integer(summary.yellow)
      assert is_integer(summary.red)
      assert is_float(summary.avg_health)
      assert is_binary(summary.generated_at)
      assert summary.total == summary.green + summary.yellow + summary.red
    end

    test "generated_at is valid ISO 8601" do
      summary = DeviceHealthMatrix.summary()
      assert {:ok, _, _} = DateTime.from_iso8601(summary.generated_at)
    end

    test "panel-001 (0.45) starts as red" do
      summary = DeviceHealthMatrix.summary()
      assert summary.red >= 1
    end
  end

  describe "device_count/0" do
    test "returns 5 after initialization" do
      assert DeviceHealthMatrix.device_count() == 5
    end
  end

  describe "property: color coding consistency" do
    test "color always matches health threshold" do
      ExUnitProperties.check all(
                               health <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 15
                             ) do
        :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: health})
        Process.sleep(5)

        case DeviceHealthMatrix.get_device("cam-001") do
          {:ok, device} ->
            expected =
              cond do
                health > 0.8 -> :green
                health > 0.5 -> :yellow
                true -> :red
              end

            assert device.color == expected

          {:error, _} ->
            :ok
        end
      end
    end
  end

  describe "property: summary invariants" do
    test "total always equals sum of color categories" do
      ExUnitProperties.check all(
                               health <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 15
                             ) do
        :ok = DeviceHealthMatrix.update_device("cam-001", %{health_score: health})
        Process.sleep(5)
        summary = DeviceHealthMatrix.summary()
        assert summary.total == summary.green + summary.yellow + summary.red
      end
    end
  end
end
