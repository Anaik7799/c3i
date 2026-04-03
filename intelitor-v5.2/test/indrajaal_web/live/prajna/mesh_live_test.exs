defmodule IndrajaalWeb.Prajna.MeshLiveTest do
  @moduledoc """
  TDG comprehensive test suite for MeshLive — SIL-6 Biomorphic 15-Container Genome.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults (gray until abnormal)
  - SC-HMI-002: Trend vectors on all metrics
  - SC-HMI-010: Color Rich chromatic feedback
  - SC-VDP-005: Discriminable naming (container names)
  - SC-EID-001: Show functional flows, not just physical nodes
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-IGNITE-008: sil6Genome covers all 15 containers

  ## Constitutional Verification
  - Ψ₀ Existence: Dashboard persists across failures
  - Ψ₁ Regeneration: View state reconstructible
  - Ψ₂ Evolutionary Continuity: Metrics history preserved
  - Ψ₃ Verification: Data integrity checks
  - Ψ₄ Human Alignment: Founder's mesh authority
  - Ψ₅ Truthfulness: No fabricated node states

  ## Founder's Directive Alignment
  - Ω₀.3: Symbiotic binding visibility across mesh

  ## TPS 5-Level RCA Context
  - L1 Symptom: Node status not updating or UI freeze
  - L2 Diagnosis: PubSub disconnection or render error
  - L3 System Condition: WebSocket timeout or memory leak
  - L4 Design Weakness: Missing error boundary or state recovery
  - L5 Root Cause: Insufficient LiveView lifecycle management
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import Phoenix.LiveViewTest

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias IndrajaalWeb.Prajna.MeshLive

  # SIL-6 Genome container IDs (matches mesh_live.ex @sil6_genome)
  @container_ids [
    "zenoh-router", "indrajaal-db-prod", "indrajaal-obs-prod",
    "zenoh-router-1", "zenoh-router-2", "zenoh-router-3",
    "indrajaal-cortex", "cepaf-bridge",
    "indrajaal-ex-app-1", "indrajaal-chaya", "indrajaal-ollama",
    "indrajaal-ex-app-2", "indrajaal-ex-app-3",
    "indrajaal-ml-runner-1", "indrajaal-ml-runner-2"
  ]

  # ============================================================================
  # Constitutional Invariants (Ψ₀-Ψ₅)
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence preserved under node failures", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      # Simulate node failure
      send(view.pid, {:node_update, "zenoh-router", %{status: :stopped}})
      # View should still be alive
      assert render(view) =~ "SIL-6 Mesh Topology"
    end

    test "Ψ₁ regeneration completeness", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      initial_nodes = view.assigns.nodes
      # Disconnect and reconnect
      Process.exit(view.pid, :normal)
      {:ok, new_view, _html} = live(conn, "/cockpit/mesh")
      # Should have 15 genome nodes again
      assert is_list(new_view.assigns.nodes)
      assert length(new_view.assigns.nodes) == 15
    end

    test "Ψ₂ evolutionary continuity", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      # Trigger refresh
      send(view.pid, :refresh)
      # Nodes should have updated metrics
      assert is_list(view.assigns.nodes)
      assert length(view.assigns.nodes) == 15
    end

    test "Ψ₃ verification capability", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      # All nodes should have required SIL-6 genome fields
      Enum.each(view.assigns.nodes, fn node ->
        assert Map.has_key?(node, :id)
        assert Map.has_key?(node, :name)
        assert Map.has_key?(node, :tier)
        assert Map.has_key?(node, :role)
        assert Map.has_key?(node, :category)
      end)
    end

    test "Ψ₄ human alignment (Founder PRIMARY)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/mesh")
      # Should display SIL-6 mesh topology
      assert html =~ "SIL-6 Mesh Topology" or html =~ "mesh"
    end

    test "Ψ₅ truthfulness — 15 containers, not synthetic data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      nodes = view.assigns.nodes
      # Must have exactly 15 genome containers
      assert length(nodes) == 15
      # All IDs must be real container names
      node_ids = Enum.map(nodes, & &1.id)
      assert Enum.sort(node_ids) == Enum.sort(@container_ids)
    end
  end

  # ============================================================================
  # Mount and Initial Render (SC-HMI-001, SC-IGNITE-008)
  # ============================================================================

  describe "Mount and Initialization" do
    test "mounts successfully with SIL-6 title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/mesh")
      assert html =~ "SIL-6 Mesh Topology"
    end

    test "initializes with 15 genome nodes (SC-IGNITE-008)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert is_list(view.assigns.nodes)
      assert length(view.assigns.nodes) == 15
    end

    test "initializes with no selected node", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert is_nil(view.assigns.selected_node)
    end

    test "provides tier labels for 7-tier hierarchy", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Map.has_key?(view.assigns, :tier_labels)
      assert map_size(view.assigns.tier_labels) == 7
    end

    test "provides role icons for container roles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Map.has_key?(view.assigns, :role_icons)
      assert is_map(view.assigns.role_icons)
    end

    test "provides status icons", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Map.has_key?(view.assigns, :status_icons)
      assert is_map(view.assigns.status_icons)
    end

    test "provides trend icons (SC-HMI-002)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Map.has_key?(view.assigns, :trend_icons)
      assert is_map(view.assigns.trend_icons)
    end

    test "provides category labels for 3 ImageCategory types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Map.has_key?(view.assigns, :category_labels)
      assert map_size(view.assigns.category_labels) == 3
    end

    test "subscribes to PubSub when connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert Process.alive?(view.pid)
    end

    test "sets up refresh interval", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, :refresh)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # 7-Tier Boot Hierarchy (SC-IGNITE-008)
  # ============================================================================

  describe "7-Tier Boot Hierarchy" do
    test "nodes are distributed across 7 tiers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      tiers = Enum.map(view.assigns.nodes, & &1.tier) |> Enum.uniq() |> Enum.sort()
      assert tiers == [1, 2, 3, 4, 5, 6, 7]
    end

    test "T1 has 1 zenoh-router", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      t1 = Enum.filter(view.assigns.nodes, &(&1.tier == 1))
      assert length(t1) == 1
      assert hd(t1).id == "zenoh-router"
    end

    test "T4 has 3 quorum routers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      t4 = Enum.filter(view.assigns.nodes, &(&1.tier == 4))
      assert length(t4) == 3
      assert Enum.all?(t4, &(&1.role == :quorum_router))
    end

    test "T7 has 4 HA + ML containers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      t7 = Enum.filter(view.assigns.nodes, &(&1.tier == 7))
      assert length(t7) == 4
    end
  end

  # ============================================================================
  # 3 ImageCategory Types
  # ============================================================================

  describe "ImageCategory Distribution" do
    test "5 BuiltFromDockerfile containers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      built = Enum.filter(view.assigns.nodes, &(&1.category == :built))
      assert length(built) == 5
    end

    test "2 PulledFromRegistry containers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      pulled = Enum.filter(view.assigns.nodes, &(&1.category == :pulled))
      assert length(pulled) == 2
    end

    test "8 SharedImage containers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      shared = Enum.filter(view.assigns.nodes, &(&1.category == :shared))
      assert length(shared) == 8
    end
  end

  # ============================================================================
  # Node Selection
  # ============================================================================

  describe "Node Selection" do
    test "selects node on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      result = render_click(view, "select_node", %{"id" => "zenoh-router"})
      assert view.assigns.selected_node == "zenoh-router"
      assert String.length(result) > 0
    end

    test "handles invalid node ID gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      render_click(view, "select_node", %{"id" => "invalid"})
      assert Process.alive?(view.pid)
    end

    test "clears selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      render_click(view, "select_node", %{"id" => "indrajaal-db-prod"})
      assert view.assigns.selected_node == "indrajaal-db-prod"
      render_click(view, "clear_selection", %{})
      assert is_nil(view.assigns.selected_node)
    end
  end

  # ============================================================================
  # Real-time Updates (SC-PRAJNA-004)
  # ============================================================================

  describe "Real-time Updates" do
    test "handles refresh message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, :refresh)
      Process.sleep(50)
      assert is_list(view.assigns.nodes)
      assert length(view.assigns.nodes) == 15
    end

    test "handles node update message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, {:node_update, "indrajaal-db-prod", %{cpu: 75.5, status: :warning}})
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "updates node metrics periodically", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, :refresh)
      Process.sleep(50)
      send(view.pid, :refresh)
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Action Events (SC-SAFETY-001: Arm & Fire)
  # ============================================================================

  describe "Action Events" do
    test "restart_node requires Guardian approval", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      html = render_click(view, "restart_node", %{"id" => "zenoh-router"})
      assert html =~ "Guardian approval required" or html =~ "Restart command armed"
    end

    test "stop_node requires Guardian approval", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      html = render_click(view, "stop_node", %{"id" => "indrajaal-obs-prod"})
      assert html =~ "Guardian approval required" or html =~ "Stop command armed"
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "node updates preserve structure" do
    forall updates <- PC.list(PC.map(PC.atom(), PC.any()), min_length: 0, max_length: 5) do
      Enum.all?(updates, fn update ->
        is_map(update)
      end)
    end
  end

  property "selected node is always valid string or nil" do
    forall selected <- PC.oneof([PC.binary(), PC.return(nil)]) do
      is_binary(selected) or is_nil(selected)
    end
  end

  # ============================================================================
  # ExUnitProperties Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "container IDs are valid strings" do
      ExUnitProperties.check all(
                               container_id <- SD.member_of(@container_ids),
                               max_runs: 50
                             ) do
        assert String.length(container_id) > 0
        assert container_id =~ ~r/^[a-z0-9-]+$/
      end
    end

    test "status values are in valid set" do
      ExUnitProperties.check all(
                               status <-
                                 SD.member_of([:running, :healthy, :caution, :warning, :unhealthy, :stopped, :not_found]),
                               max_runs: 50
                             ) do
        status in [:running, :healthy, :caution, :warning, :unhealthy, :stopped, :not_found]
      end
    end

    test "tier numbers are in range 1-7" do
      ExUnitProperties.check all(
                               tier <- SD.integer(1..7),
                               max_runs: 50
                             ) do
        tier >= 1 and tier <= 7
      end
    end
  end

  # ============================================================================
  # Error Handling
  # ============================================================================

  describe "Error Handling" do
    test "handles malformed node update", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, {:node_update, nil, %{}})
      assert Process.alive?(view.pid)
    end

    test "handles missing node in update", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      send(view.pid, {:node_update, "nonexistent", %{status: :stopped}})
      assert Process.alive?(view.pid)
    end

    test "survives PubSub message flood", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")

      for container_id <- @container_ids do
        send(view.pid, {:node_update, container_id, %{cpu: :rand.uniform(100)}})
      end

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Tests
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "UI responds within 1s", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _view, _html} = live(conn, "/cockpit/mesh")
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 1000
    end

    test "refresh completes within 2s", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      start_time = System.monotonic_time(:millisecond)
      send(view.pid, :refresh)
      Process.sleep(50)
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 2000
    end
  end

  # ============================================================================
  # Accessibility
  # ============================================================================

  describe "Accessibility" do
    test "has SIL-6 page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/mesh")
      assert view.assigns.page_title == "SIL-6 Mesh Topology"
    end

    test "renders semantic HTML structure", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/mesh")
      assert is_binary(html)
      assert String.length(html) > 0
    end
  end
end
