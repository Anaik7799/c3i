defmodule Indrajaal.KMS.Telemetry.DashboardTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Telemetry.Dashboard.
  Tests dashboard_config/0 — pure configuration map generation.
  STAMP: SC-OBS-069 (dual log), SC-MON-005 (dashboard data available)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Telemetry.Dashboard

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Dashboard)
    end

    test "exports dashboard_config/0" do
      assert function_exported?(Dashboard, :dashboard_config, 0)
    end
  end

  describe "dashboard_config/0" do
    test "returns a map" do
      config = Dashboard.dashboard_config()
      assert is_map(config)
    end

    test "config has a title" do
      config = Dashboard.dashboard_config()
      assert Map.has_key?(config, :title)
      assert is_binary(config.title)
    end

    test "config has panels list" do
      config = Dashboard.dashboard_config()
      assert Map.has_key?(config, :panels)
      assert is_list(config.panels)
    end

    test "panels list is non-empty" do
      config = Dashboard.dashboard_config()
      assert length(config.panels) > 0
    end

    test "each panel has a title and type" do
      config = Dashboard.dashboard_config()

      Enum.each(config.panels, fn panel ->
        assert Map.has_key?(panel, :title)
        assert Map.has_key?(panel, :type)
      end)
    end

    test "panels include health score gauge" do
      config = Dashboard.dashboard_config()
      titles = Enum.map(config.panels, & &1.title)
      assert "Health Score" in titles
    end
  end
end
