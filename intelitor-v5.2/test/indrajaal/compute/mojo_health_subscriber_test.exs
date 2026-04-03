defmodule Indrajaal.Compute.MojoHealthSubscriberTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Compute.MojoHealthSubscriber

  setup do
    # PubSub is already started by the application — don't re-start it
    {:ok, pid} = MojoHealthSubscriber.start_link(name: :test_mojo_health_sub)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{pid: pid}
  end

  describe "current_health/0" do
    test "returns unknown status initially", %{pid: pid} do
      health = GenServer.call(pid, :current_health)
      assert health.status == :unknown
      assert health.last_health == nil
      assert health.last_received_at == nil
      assert health.stale == true
    end
  end

  describe "handle_info {:zenoh_message, ...}" do
    test "processes healthy status from Zenoh message", %{pid: pid} do
      payload = Jason.encode!(%{"status" => "healthy", "models_loaded" => ["llama-3-8b"]})
      send(pid, {:zenoh_message, "indrajaal/inference/health", payload})

      # Allow async processing
      :timer.sleep(10)

      health = GenServer.call(pid, :current_health)
      assert health.status == :healthy
      assert health.last_health["status"] == "healthy"
      refute is_nil(health.last_received_at)
    end

    test "processes degraded status", %{pid: pid} do
      payload = Jason.encode!(%{"status" => "degraded", "queue_depth" => 95})
      send(pid, {:zenoh_message, "indrajaal/inference/health", payload})
      :timer.sleep(10)

      health = GenServer.call(pid, :current_health)
      assert health.status == :degraded
    end

    test "maps unknown status values to :unknown", %{pid: pid} do
      payload = Jason.encode!(%{"status" => "rebooting"})
      send(pid, {:zenoh_message, "indrajaal/inference/health", payload})
      :timer.sleep(10)

      health = GenServer.call(pid, :current_health)
      assert health.status == :unknown
    end

    test "handles invalid JSON gracefully", %{pid: pid} do
      send(pid, {:zenoh_message, "indrajaal/inference/health", "not-json"})
      :timer.sleep(10)

      # Should still be alive and in initial state
      assert Process.alive?(pid)
      health = GenServer.call(pid, :current_health)
      assert health.status == :unknown
    end

    test "broadcasts health updates to PubSub", %{pid: pid} do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:mojo_health")

      payload = Jason.encode!(%{"status" => "healthy"})
      send(pid, {:zenoh_message, "indrajaal/inference/health", payload})

      assert_receive {:mojo_health_update, %{"status" => "healthy"}}, 500
    end
  end

  describe "stale detection" do
    test "detects stale status when no messages received", %{pid: pid} do
      health = GenServer.call(pid, :current_health)
      assert health.stale == true
    end

    test "reports non-stale after receiving a message", %{pid: pid} do
      payload = Jason.encode!(%{"status" => "healthy"})
      send(pid, {:zenoh_message, "indrajaal/inference/health", payload})
      :timer.sleep(10)

      health = GenServer.call(pid, :current_health)
      assert health.stale == false
    end
  end

  describe "handle_info catch-all" do
    test "ignores unknown messages", %{pid: pid} do
      send(pid, :some_random_message)
      assert Process.alive?(pid)
    end
  end
end
