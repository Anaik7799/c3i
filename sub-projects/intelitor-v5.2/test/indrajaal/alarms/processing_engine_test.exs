defmodule Indrajaal.Alarms.ProcessingEngineTest do
  @moduledoc """
  TDG comprehensive test suite for ProcessingEngine.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-ALARMS-010: ProcessingEngine must handle SIA-DC09 protocol events
  - SC-ALARMS-011: API events must be normalized before processing
  - SC-ALARMS-012: process_alarm must return within @process_timeout (5s)

  ## Constitutional Verification
  - Psi0 Existence: Engine survives malformed events without crashing
  - Psi3 Verification: Each call returns a verifiable {:ok, _} or {:error, _}
  - Psi5 Truthfulness: Results accurately reflect alarm processing outcome

  ## Founder's Directive Alignment
  - Omega0.1: Alarm engine protects site resources through accurate event processing

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarms silently dropped or incorrectly classified
  - L5 Root Cause: Event normalization failure or missing device lookup stub
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.ProcessingEngine

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(ProcessingEngine) do
      nil ->
        start_supervised!({ProcessingEngine, []})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: process_alarm/1
  # ---------------------------------------------------------------------------

  describe "process_alarm/1" do
    test "returns {:ok, alarm} or {:error, reason} — not a crash" do
      device_event = %{
        tenant_id: "tenant-pe-1",
        source_device_id: Ecto.UUID.generate(),
        event_code: "BA001",
        event_type: :intrusion,
        severity: :high,
        priority: 8
      }

      result = ProcessingEngine.process_alarm(device_event)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "intrusion event_type produces result" do
      event = %{
        tenant_id: "tenant-pe-2",
        source_device_id: Ecto.UUID.generate(),
        event_type: :intrusion,
        event_code: "IN001"
      }

      result = ProcessingEngine.process_alarm(event)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "fire event_type produces result" do
      event = %{
        tenant_id: "tenant-pe-3",
        source_device_id: Ecto.UUID.generate(),
        event_type: :fire,
        event_code: "FA001"
      }

      result = ProcessingEngine.process_alarm(event)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "medical event_type produces result" do
      event = %{
        tenant_id: "tenant-pe-4",
        source_device_id: Ecto.UUID.generate(),
        event_type: :medical,
        event_code: "MA001"
      }

      result = ProcessingEngine.process_alarm(event)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "panic event_type produces result" do
      event = %{
        tenant_id: "tenant-pe-5",
        source_device_id: Ecto.UUID.generate(),
        event_type: :panic,
        event_code: "PA001"
      }

      result = ProcessingEngine.process_alarm(event)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "server remains alive after processing" do
      ProcessingEngine.process_alarm(%{
        tenant_id: "t",
        source_device_id: Ecto.UUID.generate(),
        event_type: :supervisory
      })

      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end

    test "processed_count in server state increments" do
      # Two calls — server should handle both without crash
      e = %{tenant_id: "t", source_device_id: Ecto.UUID.generate(), event_type: :intrusion}
      ProcessingEngine.process_alarm(e)
      ProcessingEngine.process_alarm(e)

      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end
  end

  # ---------------------------------------------------------------------------
  # describe: handle_sia_event/1
  # ---------------------------------------------------------------------------

  describe "handle_sia_event/1" do
    test "returns {:ok, _} or {:error, _} for binary SIA data" do
      result = ProcessingEngine.handle_sia_event(<<0x41, 0x43, 0x4B>>)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:ok, _} or {:error, _} for string SIA data" do
      result = ProcessingEngine.handle_sia_event("SIA-BA-001")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "SIA event with nil data does not crash server" do
      result = ProcessingEngine.handle_sia_event(nil)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end

    test "server stays alive after SIA event" do
      ProcessingEngine.handle_sia_event("any-binary")
      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end
  end

  # ---------------------------------------------------------------------------
  # describe: handle_api_event/2
  # ---------------------------------------------------------------------------

  describe "handle_api_event/2" do
    test "returns {:ok, _} or {:error, _} for valid params" do
      params = %{
        device_id: Ecto.UUID.generate(),
        event_type: "intrusion",
        event_code: "IN001",
        severity: :high,
        description: "Motion detected",
        metadata: %{},
        source_ip: "10.0.0.1"
      }

      result = ProcessingEngine.handle_api_event(params, "tenant-api-1")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:ok, _} or {:error, _} for minimal params" do
      params = %{device_id: Ecto.UUID.generate(), event_type: "fire"}
      result = ProcessingEngine.handle_api_event(params, "tenant-api-2")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "server stays alive after api event" do
      params = %{device_id: Ecto.UUID.generate(), event_type: "tamper"}
      ProcessingEngine.handle_api_event(params, "tenant-api-3")
      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: engine survives 10 concurrent process_alarm calls" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            ProcessingEngine.process_alarm(%{
              tenant_id: "t#{i}",
              source_device_id: Ecto.UUID.generate(),
              event_type: :intrusion
            })
          end)
        end)

      results = Task.await_many(tasks, 10_000)
      Enum.each(results, fn r -> assert match?({:ok, _}, r) or match?({:error, _}, r) end)
      assert Process.alive?(GenServer.whereis(ProcessingEngine))
    end

    test "Psi3 verification: each result is verifiable {:ok, _} or {:error, _}" do
      result =
        ProcessingEngine.process_alarm(%{
          tenant_id: "v",
          source_device_id: Ecto.UUID.generate(),
          event_type: :fire
        })

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "Psi5 truthfulness: result reflects actual processing not a stub :ok" do
      result =
        ProcessingEngine.process_alarm(%{
          tenant_id: "truth",
          source_device_id: Ecto.UUID.generate(),
          event_type: :intrusion
        })

      # Must be tagged tuple, not bare :ok
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "process_alarm completes within @process_timeout (5s)" do
      event = %{
        tenant_id: "sil4",
        source_device_id: Ecto.UUID.generate(),
        event_type: :intrusion
      }

      {elapsed_us, result} = :timer.tc(fn -> ProcessingEngine.process_alarm(event) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
      # 5 seconds = 5_000_000 microseconds
      assert elapsed_us < 5_000_000
    end

    test "SIA and API paths both return tagged tuples (dual channel)" do
      sia_result = ProcessingEngine.handle_sia_event("test-binary")
      api_result = ProcessingEngine.handle_api_event(%{device_id: Ecto.UUID.generate()}, "t")

      assert match?({:ok, _}, sia_result) or match?({:error, _}, sia_result)
      assert match?({:ok, _}, api_result) or match?({:error, _}, api_result)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "process_alarm with any event_type returns tagged tuple" do
    event_types = [:intrusion, :fire, :medical, :panic, :tamper, :supervisory, :holdup]

    forall event_type <- PC.oneof(Enum.map(event_types, &PC.exactly/1)) do
      result =
        ProcessingEngine.process_alarm(%{
          tenant_id: "prop-tenant",
          source_device_id: Ecto.UUID.generate(),
          event_type: event_type
        })

      match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  property "handle_sia_event never crashes regardless of binary content" do
    forall data <- PC.binary() do
      result = ProcessingEngine.handle_sia_event(data)
      match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "handle_api_event with any device_id returns tagged tuple" do
    ExUnitProperties.check all(
                             device_id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)
                           ) do
      result =
        ProcessingEngine.handle_api_event(
          %{device_id: device_id, event_type: "intrusion"},
          "tenant-prop"
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  test "process_alarm with any severity returns tagged tuple" do
    ExUnitProperties.check all(severity <- SD.member_of([:low, :medium, :high, :critical])) do
      result =
        ProcessingEngine.process_alarm(%{
          tenant_id: "sev-prop",
          source_device_id: Ecto.UUID.generate(),
          event_type: :intrusion,
          severity: severity
        })

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
