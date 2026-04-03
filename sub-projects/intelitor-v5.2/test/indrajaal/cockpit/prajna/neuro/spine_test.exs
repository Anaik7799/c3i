defmodule Indrajaal.Cockpit.Prajna.Neuro.SpineTest do
  use ExUnit.Case
  @moduletag :zenoh_nif
  use PropCheck
  alias Indrajaal.Cockpit.Prajna.Neuro.Spine
  alias PropCheck.BasicTypes, as: PC

  setup do
    # Start Spine with default module name so process_signal/1 can find it
    {:ok, pid} = Spine.start_link(id: "spine_test_#{System.unique_integer([:positive])}")

    on_exit(fn ->
      # Only stop if process is still alive
      try do
        if Process.alive?(pid) do
          GenServer.stop(pid, :normal, 100)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    %{spine: pid}
  end

  test "L1 Reflex: Immediately blocks SQL Injection", %{spine: _spine} do
    signal = %{payload: "UNION SELECT * FROM users"}

    # Should hit L1 reflex (regex match)
    assert {:ok, :l1_reflex, :block_ip} = Spine.process_signal(signal)
  end

  test "L2 Reflex: Handles simple signals locally", %{spine: _spine} do
    # Short signal = Low complexity = High local confidence
    signal = %{status: "warning", value: 45}

    assert {:ok, :l2_local_ml, _action} = Spine.process_signal(signal)
  end

  test "L3 Cognition: Escalates complex signals to Cortex", %{spine: _spine} do
    # Long/Complex signal = High complexity = Low local confidence -> OpenRouter
    complex_data = String.duplicate("complex_log_trace ", 100)
    signal = %{trace: complex_data}

    assert {:ok, :l3_cortex, {:proposed_plan, _}} = Spine.process_signal(signal)
  end

  describe "property tests" do
    property "route selection is deterministic for identical signals" do
      forall signal_type <- PC.oneof([:simple, :complex, :attack]) do
        signal =
          case signal_type do
            :simple -> %{status: "ok", value: 42}
            :complex -> %{trace: String.duplicate("data ", 50)}
            :attack -> %{payload: "UNION SELECT *"}
          end

        result1 = Spine.process_signal(signal)
        result2 = Spine.process_signal(signal)
        result1 == result2
      end
    end

    property "message routing returns valid result tuple structure" do
      forall signal <- PC.map(PC.atom(), PC.any()) do
        case Spine.process_signal(signal) do
          {:ok, layer, _action} ->
            is_atom(layer) and layer in [:l1_reflex, :l2_local_ml, :l3_cortex]

          {:error, _reason} ->
            true

          other ->
            is_tuple(other)
        end
      end
    end
  end
end
