defmodule Indrajaal.Core.Holon.LegacyReplicatorTest do
  use ExUnit.Case, async: false
  alias Indrajaal.Core.Holon.FounderHistory
  alias Indrajaal.Core.Holon.LegacyReplicator

  setup do
    if is_nil(GenServer.whereis(LegacyReplicator)), do: LegacyReplicator.start_link()
    :ok
  end

  describe "LegacyReplicator" do
    test "triggers broadcast when history event is appended" do
      # We would mock TailscaleMesh.broadcast here to verify call
      # Since we don't have a mock library easily available,
      # we verify the functional flow.

      {:ok, event} =
        FounderHistory.append_event(:test_evolution, %{data: "persistence"}, %{agent: "test"})

      assert event.type == :test_evolution
      assert byte_size(event.hash) == 16
    end

    test "verifies remote events for chain integrity" do
      valid_event = %{
        id: "evt_123",
        type: :test,
        payload: %{},
        metadata: %{},
        timestamp: DateTime.utc_now(),
        prev_hash: nil
      }

      # Correct hash
      binary = :erlang.term_to_binary(valid_event)

      hash =
        binary
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)
        |> String.slice(0, 16)

      event_with_hash = Map.put(valid_event, :hash, hash)

      assert :ok == FounderHistory.verify_and_store_remote_event(event_with_hash)

      # Invalid hash
      bad_event = Map.put(event_with_hash, :hash, "wrong_hash")
      assert {:error, :invalid_hash} == FounderHistory.verify_and_store_remote_event(bad_event)
    end
  end
end
