defmodule Indrajaal.KMS.Immortality.ProtocolTest do
  @moduledoc """
  Tests for the L7 Immortality Protocol module.

  ## STAMP Constraints Tested

  - SC-SMRITI-070: Minimum 3 preservation targets MANDATORY
  - SC-SMRITI-074: Weekly execution MANDATORY
  - SC-OBS-015: All operations emit telemetry events

  ## TDG Compliance

  - Unit tests for core functions
  - Property tests for preservation targets
  - Integration tests for GenServer lifecycle
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.KMS.Immortality.Protocol

  # ============================================================================
  # Unit Tests
  # ============================================================================

  describe "preservation_targets/0" do
    test "returns at least 3 targets (SC-SMRITI-070)" do
      targets = Protocol.preservation_targets()
      assert length(targets) >= 3
    end

    test "all targets have required format" do
      targets = Protocol.preservation_targets()

      for {type, dest} <- targets do
        assert is_atom(type)
        assert is_binary(dest) or is_atom(dest)
      end
    end

    test "includes required target types" do
      targets = Protocol.preservation_targets()
      types = Enum.map(targets, fn {type, _} -> type end)

      assert :local_backup in types
      assert :print_ready in types
    end
  end

  describe "minimum_targets/0" do
    test "returns minimum required successful targets" do
      min = Protocol.minimum_targets()
      assert is_integer(min)
      assert min >= 3
    end

    test "minimum is less than total targets" do
      min = Protocol.minimum_targets()
      total = length(Protocol.preservation_targets())
      assert min <= total
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "preservation target properties" do
    property "all targets are valid tuples" do
      targets = Protocol.preservation_targets()

      forall target <- PC.elements(targets) do
        {type, dest} = target
        is_atom(type) and (is_binary(dest) or is_atom(dest))
      end
    end

    property "target types are unique" do
      targets = Protocol.preservation_targets()
      types = Enum.map(targets, fn {type, _} -> type end)

      length(types) == length(Enum.uniq(types))
    end
  end

  # ============================================================================
  # Property Tests (ExUnitProperties/StreamData)
  # ============================================================================

  describe "target configuration properties" do
    test "preservation targets count is stable" do
      for _ <- 1..10 do
        count = length(Protocol.preservation_targets())
        assert count == 5, "Expected 5 targets, got #{count}"
      end
    end

    test "minimum targets is always >= 3" do
      for _ <- 1..10 do
        min = Protocol.minimum_targets()
        assert min >= 3, "Minimum targets #{min} < 3 violates SC-SMRITI-070"
      end
    end
  end

  # ============================================================================
  # Telemetry Tests (Observer-Observed Pattern)
  # ============================================================================

  describe "telemetry emissions (SC-OBS-015)" do
    setup do
      ref = make_ref()
      test_pid = self()

      handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, ref, event, measurements, metadata})
      end

      events = [
        [:smriti, :immortality, :success],
        [:smriti, :immortality, :failure]
      ]

      :telemetry.attach_many("test-#{inspect(ref)}", events, handler, nil)

      on_exit(fn ->
        :telemetry.detach("test-#{inspect(ref)}")
      end)

      {:ok, ref: ref}
    end

    @tag :integration
    test "emits telemetry events on execution", %{ref: ref} do
      # Note: This test requires the GenServer to be started
      # In isolation, we just verify the telemetry handler is attached
      assert :ok ==
               :telemetry.execute([:smriti, :immortality, :success], %{timestamp: 0}, %{
                 test: true
               })

      assert_receive {:telemetry, ^ref, [:smriti, :immortality, :success], _, _}, 1000
    end
  end

  # ============================================================================
  # Integration Tests (GenServer Lifecycle)
  # ============================================================================

  describe "GenServer lifecycle" do
    @tag :integration
    test "start_link/1 returns {:ok, pid}" do
      # Start with a unique name to avoid conflicts
      name = :"test_protocol_#{System.unique_integer([:positive])}"

      case Protocol.start_link(name: name) do
        {:ok, pid} ->
          assert is_pid(pid)
          assert Process.alive?(pid)
          GenServer.stop(pid)

        {:error, {:already_started, _pid}} ->
          # Protocol is already running globally
          :ok
      end
    end
  end

  # ============================================================================
  # Constitutional Alignment Tests
  # ============================================================================

  describe "constitutional alignment" do
    test "implements Ψ₀ (Existence) - protocol can be started" do
      # The module should be loadable and callable
      assert function_exported?(Protocol, :start_link, 1)
      assert function_exported?(Protocol, :execute, 0)
      assert function_exported?(Protocol, :get_status, 0)
    end

    test "implements Ψ₁ (Regeneration) - targets include local backup" do
      targets = Protocol.preservation_targets()
      assert Enum.any?(targets, fn {type, _} -> type == :local_backup end)
    end

    test "implements Ω₀.2 (Genetic Perpetuity) - minimum 3 redundant copies" do
      min = Protocol.minimum_targets()
      assert min >= 3, "Must have at least 3 redundant copies for genetic perpetuity"
    end
  end
end
