defmodule Indrajaal.Intelligence.FLAMEIntegrationTest do
  use ExUnit.Case
  require Logger

  # Tag as distributed test
  @moduletag :distributed
  @moduletag :flame

  alias Indrajaal.Intelligence.Entry
  alias Indrajaal.FLAME.IntelligencePool

  setup do
    # Ensure FLAME pool is started
    # In :test env, we use FLAME.Backend.Local, so it just spawns a process locally
    # but mimics remote execution.
    :ok
  end

  test "verify intelligence pool configuration" do
    # Check if pool is registered
    pid = Process.whereis(IntelligencePool)
    assert pid != nil, "IntelligencePool is not running!"
    assert Process.alive?(pid)
  end

  test "execute raw threat analysis via FLAME" do
    event = %{
      type: :security_alert,
      source: "test_probe",
      timestamp: DateTime.utc_now(),
      payload: "SUSPICIOUS_PACKET_SIGNATURE_XYZ"
    }

    # This calls FLAME.call inside
    result = Entry.analyze_threat_raw(event)

    assert is_map(result)
    assert result.threat_level == :high
    assert result.confidence > 0.9
    assert result.model_version == "legacy"

    # In Local backend mode, source_node is likely same as self, but process ID differs.
    # We mainly verify it returned successfully.
    Logger.info("FLAME Result: #{inspect(result)}")
  end

  test "health check includes flame status" do
    health = Entry.health_check()
    assert health.flame_pool == :up
  end
end
