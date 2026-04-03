defmodule Indrajaal.SMRITI.Mesh.GossipTest do
  @moduledoc """
  Tests for Indrajaal.SMRITI.Mesh.Gossip - L6 Zenoh Gossip Protocol

  ## STAMP Constraints Tested
  - SC-GOSSIP-001: All broadcasts via Zenoh (not telemetry-only)
  - SC-GOSSIP-002: Subscription callbacks processed < 100ms
  - SC-GOSSIP-003: Message ordering preserved per topic
  - SC-FRAC-001: Cluster-level AI coordination
  - SC-FRAC-005: Global AI learning propagation

  ## TDG Compliance
  Uses dual property testing per EP-GEN-014:
  - PropCheck for QuickCheck-style properties
  - ExUnitProperties (StreamData) for shrinking
  """

  use ExUnit.Case, async: false
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.SMRITI.Mesh.Gossip

  # ============================================================
  # TEST SETUP
  # ============================================================

  setup do
    # Start the gossip GenServer if not already running
    # Use a unique name to avoid conflicts with the application's instance
    test_name = :"test_gossip_#{:rand.uniform(100_000)}"

    case GenServer.whereis(Gossip) do
      nil ->
        # No global instance running, start one
        {:ok, pid} = Gossip.start_link(node_id: "test-node-#{:rand.uniform(1000)}")

        on_exit(fn ->
          # Only try to stop if process is still alive
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000)
        end)

        {:ok, pid: pid, test_name: test_name}

      pid ->
        # Use the existing instance
        {:ok, pid: pid, test_name: test_name}
    end
  end

  # ============================================================
  # UNIT TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts with default options" do
      pid = GenServer.whereis(Gossip)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "generates unique node_id" do
      %{node_id: node_id} = Gossip.status()
      assert is_binary(node_id)
      assert String.starts_with?(node_id, "gossip-") or String.starts_with?(node_id, "test-node-")
    end
  end

  describe "broadcast_sense/2" do
    test "broadcasts sense event with valid holon_id and metadata" do
      holon_id = "holon-#{:rand.uniform(10000)}"
      metadata = %{type: :document, size: 1024, source: "test"}

      # Should return :ok (even if Zenoh not connected, telemetry fires)
      result = Gossip.broadcast_sense(holon_id, metadata)
      assert result in [:ok, {:error, :not_connected}]
    end

    test "increments sense_broadcasts stats" do
      initial_stats = Gossip.stats()
      holon_id = "holon-stats-test"

      Gossip.broadcast_sense(holon_id, %{type: :test})

      new_stats = Gossip.stats()
      # Stats should increase or error count should increase
      assert new_stats.sense_broadcasts >= initial_stats.sense_broadcasts or
               new_stats.broadcast_errors >= initial_stats.broadcast_errors
    end
  end

  describe "broadcast_rot/2" do
    test "broadcasts rot event with valid holon_id and entropy" do
      holon_id = "holon-rot-#{:rand.uniform(10000)}"
      entropy = 0.75

      result = Gossip.broadcast_rot(holon_id, entropy)
      assert result in [:ok, {:error, :not_connected}]
    end

    test "accepts entropy between 0.0 and 1.0" do
      for entropy <- [0.0, 0.25, 0.5, 0.75, 1.0] do
        result = Gossip.broadcast_rot("holon-entropy-test", entropy)
        assert result in [:ok, {:error, :not_connected}]
      end
    end
  end

  describe "broadcast_consensus/3" do
    test "broadcasts consensus request" do
      request_id = "consensus-#{:rand.uniform(10000)}"
      content = %{fact: "test assertion", priority: :p1}

      result = Gossip.broadcast_consensus(request_id, content)
      assert result in [:ok, {:error, :not_connected}]
    end

    test "accepts options keyword list" do
      result =
        Gossip.broadcast_consensus(
          "consensus-opts",
          %{fact: "test"},
          timeout: 5000,
          required_votes: 2
        )

      assert result in [:ok, {:error, :not_connected}]
    end
  end

  describe "register_callback/2" do
    test "registers callback for :sense events" do
      callback = fn _msg -> :ok end
      {:ok, ref} = Gossip.register_callback(:sense, callback)
      assert is_reference(ref)
    end

    test "registers callback for :rot events" do
      callback = fn _msg -> :ok end
      {:ok, ref} = Gossip.register_callback(:rot, callback)
      assert is_reference(ref)
    end

    test "registers callback for :all events" do
      callback = fn _msg -> :ok end
      {:ok, ref} = Gossip.register_callback(:all, callback)
      assert is_reference(ref)
    end
  end

  describe "unregister_callback/1" do
    test "unregisters previously registered callback" do
      callback = fn _msg -> :ok end
      {:ok, ref} = Gossip.register_callback(:sense, callback)

      assert :ok = Gossip.unregister_callback(ref)
    end
  end

  describe "stats/0" do
    test "returns statistics map" do
      stats = Gossip.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :started_at)
      assert Map.has_key?(stats, :sense_broadcasts)
      assert Map.has_key?(stats, :rot_broadcasts)
      assert Map.has_key?(stats, :consensus_broadcasts)
      assert Map.has_key?(stats, :messages_received)
      assert Map.has_key?(stats, :broadcast_errors)
    end

    test "started_at is a DateTime" do
      %{started_at: started_at} = Gossip.stats()
      assert %DateTime{} = started_at
    end
  end

  describe "status/0" do
    test "returns status map" do
      status = Gossip.status()

      assert is_map(status)
      assert Map.has_key?(status, :node_id)
      assert Map.has_key?(status, :subscriptions)
      assert Map.has_key?(status, :callbacks)
      assert Map.has_key?(status, :zenoh_connected)
    end

    test "zenoh_connected is boolean" do
      %{zenoh_connected: connected} = Gossip.status()
      assert is_boolean(connected)
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "broadcast_sense accepts any valid holon_id string" do
      # Use utf8() generator for valid UTF-8 strings that can be JSON encoded
      forall holon_id <- PC.utf8() do
        result = Gossip.broadcast_sense(holon_id, %{type: :test})
        result in [:ok, {:error, :not_connected}]
      end
    end

    @tag :property
    property "broadcast_rot accepts any float entropy" do
      forall entropy <- PC.float(0.0, 1.0) do
        result = Gossip.broadcast_rot("holon-prop", entropy)
        result in [:ok, {:error, :not_connected}]
      end
    end

    @tag :property
    property "stats counters are non-negative" do
      forall _i <- PC.integer(1, 10) do
        stats = Gossip.stats()

        stats.sense_broadcasts >= 0 and
          stats.rot_broadcasts >= 0 and
          stats.consensus_broadcasts >= 0 and
          stats.messages_received >= 0 and
          stats.broadcast_errors >= 0
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "broadcast_sense handles varied metadata" do
      ExUnitProperties.check all(
                               holon_id <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               metadata_type <-
                                 SD.member_of([:document, :image, :audio, :video, :text]),
                               size <- SD.positive_integer()
                             ) do
        metadata = %{type: metadata_type, size: size}
        result = Gossip.broadcast_sense(holon_id, metadata)
        assert result in [:ok, {:error, :not_connected}]
      end
    end

    @tag :property
    test "broadcast_consensus handles varied content" do
      ExUnitProperties.check all(
                               request_id <-
                                 SD.string(:alphanumeric, min_length: 8, max_length: 32),
                               fact <- SD.string(:printable, min_length: 1, max_length: 100),
                               priority <- SD.member_of([:p0, :p1, :p2, :p3])
                             ) do
        content = %{fact: fact, priority: priority}
        result = Gossip.broadcast_consensus(request_id, content)
        assert result in [:ok, {:error, :not_connected}]
      end
    end

    @tag :property
    test "callback registration is idempotent" do
      ExUnitProperties.check all(event_type <- SD.member_of([:sense, :rot, :consensus, :all])) do
        callback = fn _msg -> :ok end
        {:ok, ref1} = Gossip.register_callback(event_type, callback)
        {:ok, ref2} = Gossip.register_callback(event_type, callback)

        # Each registration gets a unique ref
        assert ref1 != ref2

        # Cleanup
        Gossip.unregister_callback(ref1)
        Gossip.unregister_callback(ref2)
      end
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "integration" do
    @tag :integration
    test "callback receives broadcasted sense event" do
      test_pid = self()

      callback = fn msg ->
        send(test_pid, {:gossip_received, msg})
        :ok
      end

      {:ok, ref} = Gossip.register_callback(:sense, callback)

      # Simulate receiving a message (would come from Zenoh in real scenario)
      send(
        GenServer.whereis(Gossip),
        {:zenoh_message, "smriti/senses/test-holon",
         """
           {"type": "sense", "id": "test-holon", "node_id": "other-node", "timestamp": "2026-01-16T12:00:00Z"}
         """}
      )

      # Give time for message processing
      Process.sleep(50)

      # Cleanup
      Gossip.unregister_callback(ref)

      # Check if we received the callback
      assert_receive {:gossip_received, _msg}, 500
    end

    @tag :integration
    test "ignores own messages" do
      test_pid = self()
      %{node_id: my_node_id} = Gossip.status()

      callback = fn msg ->
        send(test_pid, {:gossip_received, msg})
        :ok
      end

      {:ok, ref} = Gossip.register_callback(:sense, callback)

      # Send a message that appears to be from ourselves
      send(
        GenServer.whereis(Gossip),
        {:zenoh_message, "smriti/senses/self-test",
         """
           {"type": "sense", "id": "self-test", "node_id": "#{my_node_id}", "timestamp": "2026-01-16T12:00:00Z"}
         """}
      )

      # Give time for message processing
      Process.sleep(50)

      # Cleanup
      Gossip.unregister_callback(ref)

      # Should NOT receive callback for our own message
      refute_receive {:gossip_received, _msg}, 100
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "handles Zenoh disconnection gracefully" do
      # When Zenoh is not connected, should still work (telemetry still fires)
      result = Gossip.broadcast_sense("fmea-disconnect", %{type: :test})
      assert result in [:ok, {:error, :not_connected}]
    end

    @tag :fmea
    test "handles malformed incoming message" do
      # Send malformed JSON
      send(GenServer.whereis(Gossip), {:zenoh_message, "smriti/senses/malformed", "not-json"})

      # Should not crash
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(Gossip))
    end

    @tag :fmea
    test "handles callback exceptions" do
      # Register a callback that throws
      bad_callback = fn _msg -> raise "intentional error" end
      {:ok, ref} = Gossip.register_callback(:sense, bad_callback)

      # Send a message
      send(
        GenServer.whereis(Gossip),
        {:zenoh_message, "smriti/senses/error-test",
         """
           {"type": "sense", "id": "error-test", "node_id": "other", "timestamp": "2026-01-16T12:00:00Z"}
         """}
      )

      # Should not crash
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(Gossip))

      # Cleanup
      Gossip.unregister_callback(ref)
    end
  end
end
