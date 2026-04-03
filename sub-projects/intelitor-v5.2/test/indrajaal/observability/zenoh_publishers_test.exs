defmodule Indrajaal.Observability.ZenohPublishersTest do
  @moduledoc """
  Tests for Sprint 32 Zenoh publishers.

  WHAT: Unit tests for ZenohContainerPublisher, ZenohAgentMeshPublisher,
        ZenohBiomorphicPublisher, and ZenohDomainPublisher.
  WHY: SC-SYNC-011/012/013 require verified publisher functionality.
  CONSTRAINTS: TDG compliance, SC-TEST-001.

  ## Test Coverage
  - Publisher lifecycle (start/stop)
  - Subscription management
  - Message delivery
  - Stats collection

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 21.1.0 |
  | Sprint | 32 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Observability.ZenohContainerPublisher
  alias Indrajaal.Observability.ZenohAgentMeshPublisher
  alias Indrajaal.Observability.ZenohBiomorphicPublisher
  alias Indrajaal.Observability.ZenohDomainPublisher

  describe "ZenohContainerPublisher" do
    test "starts successfully" do
      {:ok, pid} = ZenohContainerPublisher.start_link(name: :test_container_pub)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "returns stats" do
      {:ok, pid} = ZenohContainerPublisher.start_link(name: :test_container_stats)

      stats = ZenohContainerPublisher.get_stats(pid)

      assert is_map(stats)
      assert Map.has_key?(stats, :started_at)
      assert Map.has_key?(stats, :publish_count)
      assert Map.has_key?(stats, :monitored_containers)

      GenServer.stop(pid)
    end

    test "subscribe and receive status updates" do
      {:ok, pid} = ZenohContainerPublisher.start_link(name: :test_container_sub)

      {:ok, ref} = ZenohContainerPublisher.subscribe(pid)
      assert is_reference(ref)

      # Trigger immediate publish
      ZenohContainerPublisher.publish_now(pid)

      # Should receive status message
      assert_receive {:zenoh_container, :status, message}, 5000
      assert Map.has_key?(message, :containers)
      assert Map.has_key?(message, :overall_health)

      :ok = ZenohContainerPublisher.unsubscribe(pid, ref)
      GenServer.stop(pid)
    end

    test "publishes container event" do
      {:ok, pid} = ZenohContainerPublisher.start_link(name: :test_container_event)

      {:ok, _ref} = ZenohContainerPublisher.subscribe(pid)

      ZenohContainerPublisher.publish_event(pid, :restart, "indrajaal-ex-app-1", %{reason: "test"})

      assert_receive {:zenoh_container, :event, message}, 5000
      assert message.event_type == :restart
      assert message.container == "indrajaal-ex-app-1"

      GenServer.stop(pid)
    end
  end

  describe "ZenohAgentMeshPublisher" do
    test "starts successfully" do
      {:ok, pid} = ZenohAgentMeshPublisher.start_link(name: :test_mesh_pub)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "returns stats with agent info" do
      {:ok, pid} = ZenohAgentMeshPublisher.start_link(name: :test_mesh_stats)

      stats = ZenohAgentMeshPublisher.get_stats(pid)

      assert is_map(stats)
      assert Map.has_key?(stats, :known_agents)
      assert Map.has_key?(stats, :active_agents)

      GenServer.stop(pid)
    end

    test "subscribe and receive topology updates" do
      {:ok, pid} = ZenohAgentMeshPublisher.start_link(name: :test_mesh_sub)

      {:ok, ref} = ZenohAgentMeshPublisher.subscribe(pid)
      assert is_reference(ref)

      ZenohAgentMeshPublisher.publish_topology(pid)

      assert_receive {:zenoh_mesh, :topology, message}, 5000
      assert Map.has_key?(message, :agents)
      assert Map.has_key?(message, :mesh_health)

      :ok = ZenohAgentMeshPublisher.unsubscribe(pid, ref)
      GenServer.stop(pid)
    end

    test "publishes command event" do
      {:ok, pid} = ZenohAgentMeshPublisher.start_link(name: :test_mesh_cmd)

      {:ok, _ref} = ZenohAgentMeshPublisher.subscribe(pid)

      ZenohAgentMeshPublisher.publish_command(pid, "ooda-agent", "status", %{})

      assert_receive {:zenoh_mesh, :command, message}, 5000
      assert message.agent_id == "ooda-agent"
      assert message.command == "status"

      GenServer.stop(pid)
    end

    test "handles agent heartbeat" do
      {:ok, pid} = ZenohAgentMeshPublisher.start_link(name: :test_mesh_hb)

      {:ok, _ref} = ZenohAgentMeshPublisher.subscribe(pid)

      ZenohAgentMeshPublisher.agent_heartbeat(pid, "test-agent", %{memory: 1000})

      assert_receive {:zenoh_mesh, :heartbeat, message}, 5000
      assert message.agent_id == "test-agent"

      # Verify state updated
      states = ZenohAgentMeshPublisher.get_agent_states(pid)
      assert Map.has_key?(states, "test-agent")

      GenServer.stop(pid)
    end
  end

  describe "ZenohBiomorphicPublisher" do
    test "starts successfully" do
      {:ok, pid} = ZenohBiomorphicPublisher.start_link(name: :test_bio_pub)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "returns stats with holon info" do
      {:ok, pid} = ZenohBiomorphicPublisher.start_link(name: :test_bio_stats)

      stats = ZenohBiomorphicPublisher.get_stats(pid)

      assert is_map(stats)
      assert Map.has_key?(stats, :known_holons)
      assert Map.has_key?(stats, :evolution_count)

      GenServer.stop(pid)
    end

    test "subscribe and receive holon updates" do
      {:ok, pid} = ZenohBiomorphicPublisher.start_link(name: :test_bio_sub)

      {:ok, ref} = ZenohBiomorphicPublisher.subscribe(pid)
      assert is_reference(ref)

      ZenohBiomorphicPublisher.publish_vitals(pid)

      assert_receive {:zenoh_bio, :holons, message}, 5000
      assert Map.has_key?(message, :holons)
      assert Map.has_key?(message, :organism_health)

      :ok = ZenohBiomorphicPublisher.unsubscribe(pid, ref)
      GenServer.stop(pid)
    end

    test "publishes evolution event" do
      {:ok, pid} = ZenohBiomorphicPublisher.start_link(name: :test_bio_evo)

      {:ok, _ref} = ZenohBiomorphicPublisher.subscribe(pid)

      ZenohBiomorphicPublisher.publish_evolution(pid, "prajna-holon", :mutation, %{gene: "config"})

      assert_receive {:zenoh_bio, :evolution, message}, 5000
      assert message.holon_id == "prajna-holon"
      assert message.event_type == :mutation

      GenServer.stop(pid)
    end
  end

  describe "ZenohDomainPublisher" do
    test "starts successfully" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_pub)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "returns stats" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_stats)

      stats = ZenohDomainPublisher.get_stats(pid)

      assert is_map(stats)
      assert Map.has_key?(stats, :publish_count)
      assert Map.has_key?(stats, :event_buffer_size)

      GenServer.stop(pid)
    end

    test "subscribe to specific domain" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_sub)

      {:ok, ref} = ZenohDomainPublisher.subscribe(pid, :alarms)
      assert is_reference(ref)

      :ok = ZenohDomainPublisher.unsubscribe(pid, ref)
      GenServer.stop(pid)
    end

    test "publishes alarm event" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_alarm)

      {:ok, _ref} = ZenohDomainPublisher.subscribe(pid, :alarms)

      ZenohDomainPublisher.publish_alarm_event(pid, :new, %{alarm_id: "test-001"})

      assert_receive {:zenoh_domain, :alarms, :event, message}, 5000
      assert message.event_type == :new

      GenServer.stop(pid)
    end

    test "publishes device event" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_device)

      {:ok, _ref} = ZenohDomainPublisher.subscribe(pid, :devices)

      ZenohDomainPublisher.publish_device_event(pid, "dev-001", :status_change, %{
        status: "online"
      })

      assert_receive {:zenoh_domain, :devices, :event, message}, 5000
      assert message.device_id == "dev-001"

      GenServer.stop(pid)
    end

    test "publishes access audit event" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_access)

      {:ok, _ref} = ZenohDomainPublisher.subscribe(pid, :access)

      ZenohDomainPublisher.publish_access_event(pid, %{user: "test", action: "grant"})

      assert_receive {:zenoh_domain, :access, :audit, message}, 5000
      assert message.event.user == "test"

      GenServer.stop(pid)
    end

    test "publish_all triggers all domain publishes" do
      {:ok, pid} = ZenohDomainPublisher.start_link(name: :test_domain_all)

      # Subscribe to all domains
      {:ok, _ref} = ZenohDomainPublisher.subscribe(pid)

      # Trigger all publishes
      ZenohDomainPublisher.publish_all(pid)

      # Should receive messages from multiple domains
      assert_receive {:zenoh_domain, :alarms, :correlation, _}, 5000
      assert_receive {:zenoh_domain, :devices, :state, _}, 5000
      assert_receive {:zenoh_domain, :access, :summary, _}, 5000

      GenServer.stop(pid)
    end
  end

  describe "Subscriber cleanup on process death" do
    test "removes subscriber when process dies" do
      {:ok, pid} = ZenohContainerPublisher.start_link(name: :test_cleanup)

      # Start a subscriber process
      subscriber =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      # Subscribe from the spawned process
      {:ok, _ref} =
        GenServer.call(pid, {:subscribe, nil, subscriber})

      # Verify subscriber exists
      stats_before = ZenohContainerPublisher.get_stats(pid)
      assert stats_before.subscriber_count == 1

      # Kill the subscriber
      Process.exit(subscriber, :kill)

      # Give time for DOWN message to be processed
      Process.sleep(100)

      # Verify subscriber removed
      stats_after = ZenohContainerPublisher.get_stats(pid)
      assert stats_after.subscriber_count == 0

      GenServer.stop(pid)
    end
  end
end
