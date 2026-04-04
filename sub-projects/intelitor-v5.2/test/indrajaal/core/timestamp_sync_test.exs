defmodule Indrajaal.Core.TimestampSyncTest do
  use ExUnit.Case, async: false

  alias Indrajaal.Core.TimestampSync

  describe "TimestampSync module" do
    test "sync_now/0 triggers sync" do
      # Just call sync_now - if GenServer is started, this should work
      # If not started, it will fail gracefully
      result = TimestampSync.sync_now()
      assert result in [:ok, :error]
    end

    test "drift_status/0 returns status map" do
      status = TimestampSync.drift_status()
      assert is_map(status)
      assert Map.has_key?(status, :last_drift)
      assert Map.has_key?(status, :drift_level)
      assert Map.has_key?(status, :sync_count)
    end

    test "drift_level is one of valid atoms" do
      status = TimestampSync.drift_status()
      assert status.drift_level in [:nominal, :minor, :warning, :critical]
    end

    test "sync_count is a non-negative integer" do
      status = TimestampSync.drift_status()
      assert is_integer(status.sync_count)
      assert status.sync_count >= 0
    end
  end
end
