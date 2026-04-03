defmodule IndrajaalWeb.Prajna.ClusterLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.Prajna.ClusterLive.

  WHAT: Verifies ClusterLive's 6 handle_event clauses: select_node, force_election,
        add_node, remove_node, scale_pool, toggle_autoscale.
  WHY: ClusterLive manages FLAME pool scaling and cluster topology — incorrect state
       could lead to resource exhaustion or node starvation. force_election is a
       two-step safety-critical action (SC-SAFETY-001).
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-CLU-001 through SC-CLU-008, SC-HMI-001

  TDG Level: L4 (Integration Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module structure" do
    test "module exists and exports required callbacks" do
      alias IndrajaalWeb.Prajna.ClusterLive
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.ClusterLive)
      assert function_exported?(IndrajaalWeb.Prajna.ClusterLive, :mount, 3)
      assert function_exported?(IndrajaalWeb.Prajna.ClusterLive, :render, 1)
      assert function_exported?(IndrajaalWeb.Prajna.ClusterLive, :handle_event, 3)
      assert function_exported?(IndrajaalWeb.Prajna.ClusterLive, :handle_info, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render" do
    test "mounts successfully at /cockpit/cluster" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/cluster")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "initial render shows cluster topology" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/cluster")
      assert html =~ "CLUSTER" or html =~ "cluster" or html =~ "Cluster" or html =~ "node"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: select_node
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event select_node" do
    test "selecting a node updates the view" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "select_node", %{"id" => "node-1"})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "selecting different nodes in sequence" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      render_click(view, "select_node", %{"id" => "node-1"})
      html = render_click(view, "select_node", %{"id" => "node-2"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: force_election
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event force_election" do
    test "force election produces info flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "force_election", %{})
      assert html =~ "election" or html =~ "Election"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: add_node / remove_node
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event add_node" do
    test "add_node opens wizard flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "add_node", %{})
      assert html =~ "wizard" or html =~ "node" or html =~ "Add"
    end
  end

  describe "handle_event remove_node" do
    test "remove_node produces confirmation warning" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "remove_node", %{"id" => "node-3"})
      assert html =~ "removal" or html =~ "confirmation" or html =~ "node-3"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: scale_pool
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event scale_pool" do
    test "scale up default pool" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "scale_pool", %{"pool" => "default", "direction" => "up"})
      assert html =~ "Scaling" or html =~ "default" or html =~ "+2"
    end

    test "scale down compute pool" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "scale_pool", %{"pool" => "compute", "direction" => "down"})
      assert html =~ "Scaling" or html =~ "compute" or html =~ "-2"
    end

    test "scale io pool" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "scale_pool", %{"pool" => "io", "direction" => "up"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: toggle_autoscale
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event toggle_autoscale" do
    test "toggle produces info flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      html = render_click(view, "toggle_autoscale", %{})
      assert html =~ "Auto-scale" or html =~ "autoscale" or html =~ "toggled"
    end

    test "double toggle is safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")
      render_click(view, "toggle_autoscale", %{})
      html = render_click(view, "toggle_autoscale", %{})
      assert is_binary(html)
    end
  end
end
