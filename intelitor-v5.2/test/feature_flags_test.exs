defmodule Indrajaal.FeatureFlagsLegacyTest do
  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  import Indrajaal.Factory
  alias Indrajaal.FeatureFlags

  setup do
    tenant = insert(:tenant)
    {:ok, tenant: tenant}
  end

  test "bulk update works correctly" do
    flags = %{
      stamp_enabled: true,
      tdg_enabled: true,
      gde_enabled: false
    }

    assert :ok = FeatureFlags.bulk_update(flags)

    assert FeatureFlags.enabled?(:stamp_enabled)
    assert FeatureFlags.enabled?(:tdg_enabled)
    refute FeatureFlags.enabled?(:gde_enabled)
  end

  describe "rollout functionality" do
    test "percentage rollout works" do
      FeatureFlags.enable(:stamp_enabled)
      FeatureFlags.set_rollout_percentage(50)

      # Test with multiple user IDs
      enabled_count =
        Enum.count(1..1000, fn i ->
          FeatureFlags.enabled_for?(:stamp_enabled, %{__user_id: "__user_#{i}"})
        end)

      # Should be roughly 50% (allowing for variance)
      assert enabled_count > 400
      assert enabled_count < 600
    end

    test "team-based rollout" do
      FeatureFlags.enable(:tdg_enabled)
      FeatureFlags.add_team_to_rollout("engineering")

      assert FeatureFlags.enabled_for?(:tdg_enabled, %{team: "engineering"})
      refute FeatureFlags.enabled_for?(:tdg_enabled, %{team: "marketing"})
    end
  end

  describe "configuration export / import" do
    test "can export and import configuration" do
      # Set up some flags
      FeatureFlags.bulk_update(%{
        stamp_enabled: true,
        tdg_enabled: false,
        rollout_percentage: 25
      })

      # Export
      config = FeatureFlags.export_config()

      assert config.flags.stamp_enabled == true
      assert config.flags.tdg_enabled == false
      assert config.flags.rollout_percentage == 25
      assert config.version == "1.0.0"

      # Change flags
      FeatureFlags.disable(:stamp_enabled)

      # Import back
      assert :ok = FeatureFlags.import_config(config)

      # Should be restored
      assert FeatureFlags.enabled?(:stamp_enabled)
    end
  end

  describe "telemetry integration" do
    test "emits telemetry __events on flag changes" do
      self_pid = self()
      handler_id = "test-handler-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:feature_flags, :changed],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      FeatureFlags.enable(:stamp_enabled)

      assert_receive {:telemetry, [:feature_flags, :changed], %{enabled: true},
                      %{flag: :stamp_enabled}}

      :telemetry.detach(handler_id)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
