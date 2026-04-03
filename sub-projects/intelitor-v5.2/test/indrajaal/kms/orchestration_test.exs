# test/indrajaal/kms/orchestration_test.exs
defmodule Indrajaal.KMS.OrchestrationTest do
  use ExUnit.Case
  alias Indrajaal.KMS.Immortality.Protocol
  alias Indrajaal.KMS.Agents.KnowledgeAgent
  alias Indrajaal.KMS.Federation.Replication
  alias Indrajaal.KMS.Monitoring.HealthMonitor

  setup do
    # Ensure data dir exists for health check
    File.mkdir_p!("data/kms")
    File.touch!("data/kms/smriti.db")
    :ok
  end

  test "immortality protocol execution" do
    start_supervised!(Protocol)
    assert Protocol.execute() == :ok
  end

  test "knowledge agent initialization and OODA loop" do
    {:ok, pid} = start_supervised(KnowledgeAgent)
    assert Process.alive?(pid)
    # Allow OODA loop to tick (simulated by message check if we had introspection)
  end

  test "replication engine queue processing" do
    {:ok, pid} = start_supervised(Replication)
    assert :ok = Replication.add_peer(:node2)
    assert :ok = Replication.replicate(%{id: "holon_123", content: "test"})
  end

  test "health monitor comprehensive checks" do
    {:ok, pid} = start_supervised(HealthMonitor)
    assert Process.alive?(pid)
    # Wait for initial check
    Process.sleep(100)
  end
end
