defmodule IndrajaalWeb.Prajna.GitIntelligenceLiveTest do
  @moduledoc """
  Tests for GitIntelligenceLive — Prajna cockpit panel for Git Health Score.

  STAMP: SC-BRIDGE-001, SC-BIO-EXT-001, SC-HMI-002
  """
  use ExUnit.Case, async: true

  alias IndrajaalWeb.Prajna.GitIntelligenceLive

  describe "module definition" do
    test "module exists" do
      assert Code.ensure_loaded?(GitIntelligenceLive)
    end

    test "implements mount/3" do
      assert function_exported?(GitIntelligenceLive, :mount, 3)
    end

    test "implements render/1" do
      assert function_exported?(GitIntelligenceLive, :render, 1)
    end

    test "implements handle_info/2" do
      assert function_exported?(GitIntelligenceLive, :handle_info, 2)
    end
  end

  describe "PubSub integration design" do
    test "subscribes to 3 PubSub channels" do
      # Verify the module references the correct PubSub topics
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "git_intelligence"
      assert source =~ "git_intelligence:health"
      assert source =~ "git_intelligence:threat"
    end

    test "handles git_intelligence messages" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ ":git_intelligence"
      assert source =~ ":git_intelligence_health"
      assert source =~ ":git_intelligence_threat"
    end
  end

  describe "ETS integration design" do
    test "reads from GitZenohSubscriber" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "GitZenohSubscriber.get_metrics()"
      assert source =~ "GitZenohSubscriber.get_stats()"
    end

    test "displays all 7 ETS-derived keys" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ ":ghs"
      assert source =~ ":ghs_at"
      assert source =~ ":icp_adoption"
      assert source =~ ":biomorphic_health"
      assert source =~ ":threat_level"
      assert source =~ ":vital_signs"
      assert source =~ ":founder_alignment"
    end
  end

  describe "Dark Cockpit rendering" do
    test "uses dark theme (SC-HMI-001)" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "bg-gray-900"
      assert source =~ "text-white"
    end

    test "displays GHS with color coding" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "ghs_color"
      assert source =~ "text-green-400"
      assert source =~ "text-red-400"
    end

    test "displays threat level with severity coloring" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "threat_color"
      assert source =~ "animate-pulse"
    end

    test "displays biomorphic health bars for 5 subsystems" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "Immune"
      assert source =~ "Neural"
      assert source =~ "Homeostatic"
      assert source =~ "Regenerative"
      assert source =~ "Symbiotic"
    end

    test "displays Founder's Directive alignment" do
      source = File.read!("lib/indrajaal_web/live/prajna/git_intelligence_live.ex")
      assert source =~ "Survival"
      assert source =~ "Sentience"
      assert source =~ "Power"
    end
  end
end
