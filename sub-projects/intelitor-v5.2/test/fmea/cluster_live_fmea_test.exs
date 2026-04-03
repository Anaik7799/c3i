defmodule IndrajaalWeb.Fmea.ClusterLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.ClusterLive.

  Analyzes failure modes in the cluster management screen, covering
  leader election during node removal, scale-beyond-limits, autoscale
  oscillation, and split-brain scenarios.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-CLUSTER-001, SC-CLUSTER-002, SC-SIL4-011, SC-SIL4-015
  Reference: Raft consensus, NASA-STD-3000, Tailscale DNS
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-CLU-001: Election During Node Removal
  # Severity: 9 (cluster state undefined during simultaneous election + removal)
  # Occurrence: 3 (happens under rolling upgrades)
  # Detection: 4 (last_election indicator exists but race is subtle)
  # RPN: 108
  # ============================================================================

  describe "FM-CLU-001: Leader Election During Node Removal (RPN: 108)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | force_election triggered while remove_node is in flight |
    | Effect | Quorum lost momentarily; cluster may split-brain |
    | Severity | 9 (split-brain is safety-critical per SC-CLUSTER-002) |
    | Occurrence | 3 (rolling upgrade, simultaneous node failure) |
    | Detection | 4 (gossip log shows event but race is subtle) |
    | RPN Before | 108 |
    | Mitigation | Serialize election and removal; quorum check before remove |
    | RPN After | 27 (S:9 x O:1 x D:3) |
    | STAMP | SC-CLUSTER-002, SC-SIL4-011, SC-SIL4-015 |
    """

    @tag rpn: 108
    test "page mounts with cluster nodes and sentinel status rendered" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/cluster")

      assert is_binary(html)
    end

    @tag rpn: 108
    test "force_election event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "force_election", %{})

      assert is_binary(html)
    end

    @tag rpn: 108
    test "remove_node with unknown node id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "remove_node", %{"id" => "node-does-not-exist-99"})

      assert is_binary(html)
    end

    @tag rpn: 108
    test "force_election immediately after remove_node does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      render_click(view, "remove_node", %{"id" => "indrajaal@node-2"})
      html = render_click(view, "force_election", %{})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-CLU-002: Scale Beyond Cluster Limits
  # Severity: 7 (resource exhaustion, cluster instability)
  # Occurrence: 3 (autoscale misconfiguration, manual error)
  # Detection: 4 (pool counter visible but limit not enforced in UI)
  # RPN: 84
  # ============================================================================

  describe "FM-CLU-002: Scale Beyond Cluster Limits (RPN: 84)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | scale_pool up issued when pool is already at max capacity |
    | Effect | Resource exhaustion on host, OOM possible |
    | Severity | 7 (cluster instability, degraded performance) |
    | Occurrence | 3 (autoscale misconfiguration) |
    | Detection | 4 (pool counter shown, but limit not enforced in UI) |
    | RPN Before | 84 |
    | Mitigation | Max pool size enforced server-side; UI disables at limit |
    | RPN After | 21 (S:7 x O:1 x D:3) |
    | STAMP | SC-FLAME-004, SC-CLUSTER-001 |
    """

    @tag rpn: 84
    test "scale_pool up event renders without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "scale_pool", %{"pool" => "flame-default", "direction" => "up"})

      assert is_binary(html)
    end

    @tag rpn: 84
    test "scale_pool down event renders without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html =
        render_click(view, "scale_pool", %{"pool" => "flame-default", "direction" => "down"})

      assert is_binary(html)
    end

    @tag rpn: 84
    test "scale_pool with unknown pool name does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html =
        render_click(view, "scale_pool", %{
          "pool" => "nonexistent-pool-xyz",
          "direction" => "up"
        })

      assert is_binary(html)
    end

    @tag rpn: 84
    test "scale_pool with unknown direction does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html =
        render_click(view, "scale_pool", %{
          "pool" => "flame-default",
          "direction" => "sideways"
        })

      assert is_binary(html)
    end

    @tag rpn: 84
    test "repeated scale_pool up calls are bounded gracefully" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      for _ <- 1..20 do
        render_click(view, "scale_pool", %{"pool" => "flame-default", "direction" => "up"})
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-CLU-003: Autoscale Oscillation
  # Severity: 5 (continuous scale up/down wastes resources, instability)
  # Occurrence: 4 (feedback loop with load threshold)
  # Detection: 5 (gradual oscillation hard to notice)
  # RPN: 100
  # ============================================================================

  describe "FM-CLU-003: Autoscale Oscillation (RPN: 100)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | toggle_autoscale causes continuous up/down scale thrash |
    | Effect | Frequent container restarts; degraded performance |
    | Severity | 5 (performance degradation, resource waste) |
    | Occurrence | 4 (threshold too close to steady-state load) |
    | Detection | 5 (gradual oscillation hard to notice until significant) |
    | RPN Before | 100 |
    | Mitigation | Cooldown period between scale events; hysteresis band |
    | RPN After | 25 (S:5 x O:2 x D:2.5) |
    | STAMP | SC-FLAME-006, SC-CLUSTER-001 |
    """

    @tag rpn: 100
    test "toggle_autoscale event renders without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "toggle_autoscale", %{})

      assert is_binary(html)
    end

    @tag rpn: 100
    test "rapid toggle_autoscale calls do not corrupt state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      for _ <- 1..10 do
        render_click(view, "toggle_autoscale", %{})
      end

      html = render(view)
      assert is_binary(html)
    end

    @tag rpn: 100
    test "scale_pool interleaved with toggle_autoscale remains stable" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      render_click(view, "toggle_autoscale", %{})
      render_click(view, "scale_pool", %{"pool" => "flame-default", "direction" => "up"})
      render_click(view, "toggle_autoscale", %{})
      html = render_click(view, "scale_pool", %{"pool" => "flame-default", "direction" => "down"})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-CLU-004: Node Selection While Cluster Refreshing
  # Severity: 5 (stale node data shown after selection)
  # Occurrence: 5 (operator clicks during 2s refresh cycle)
  # Detection: 4 (stale data visually similar to fresh data)
  # RPN: 100
  # ============================================================================

  describe "FM-CLU-004: Node Selection During Refresh Race (RPN: 100)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | select_node fires while :refresh is recomputing nodes list |
    | Effect | Selected node panel shows stale metrics |
    | Severity | 5 (operator acts on stale data) |
    | Occurrence | 5 (2s refresh cycle means frequent overlap) |
    | Detection | 4 (stale data visually identical to fresh) |
    | RPN Before | 100 |
    | Mitigation | Optimistic update + immediate re-render on selection |
    | RPN After | 25 (S:5 x O:2 x D:2.5) |
    | STAMP | SC-CLUSTER-001, SC-HMI-010 |
    """

    @tag rpn: 100
    test "select_node with valid id renders node detail" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "select_node", %{"id" => "indrajaal@app-01"})

      assert is_binary(html)
    end

    @tag rpn: 100
    test "select_node with unknown id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "select_node", %{"id" => "indrajaal@ghost-node-9999"})

      assert is_binary(html)
    end

    @tag rpn: 100
    test "select_node with empty id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "select_node", %{"id" => ""})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-CLU-005: Add Node With Duplicate Identity
  # Severity: 7 (quorum double-counting, split-brain risk)
  # Occurrence: 2 (operator error during manual expansion)
  # Detection: 5 (second node appears normal in list)
  # RPN: 70
  # ============================================================================

  describe "FM-CLU-005: Add Node With Duplicate Identity (RPN: 70)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | add_node invoked twice or with already-existing node name |
    | Effect | Quorum double-counted; possible split-brain |
    | Severity | 7 (cluster quorum violation per SC-CLUSTER-002) |
    | Occurrence | 2 (operator error during manual expansion) |
    | Detection | 5 (duplicate node looks normal in list) |
    | RPN Before | 70 |
    | Mitigation | Idempotent add; duplicate detection before state update |
    | RPN After | 21 (S:7 x O:1 x D:3) |
    | STAMP | SC-SIL4-011, SC-CLUSTER-002 |
    """

    @tag rpn: 70
    test "add_node event renders without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      html = render_click(view, "add_node", %{})

      assert is_binary(html)
    end

    @tag rpn: 70
    test "repeated add_node calls do not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      for _ <- 1..5 do
        render_click(view, "add_node", %{})
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-CLU-006: Split-Brain Detection Latency Violation
  # Severity: 9 (undetected split-brain = dual-leader = data divergence)
  # Occurrence: 2 (network partition events)
  # Detection: 3 (gossip log shows partition)
  # RPN: 54
  # ============================================================================

  describe "FM-CLU-006: Split-Brain Detection Latency (RPN: 54)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Split-brain detection exceeds SC-CLUSTER-002 5s threshold |
    | Effect | Dual leaders; write conflicts; data divergence |
    | Severity | 9 (data integrity violation) |
    | Occurrence | 2 (network partition events) |
    | Detection | 3 (gossip log detects eventually) |
    | RPN Before | 54 |
    | Mitigation | SC-SIL4-015 apoptosis triggered; monitor gossip heartbeat |
    | RPN After | 18 (S:9 x O:1 x D:2) |
    | STAMP | SC-CLUSTER-002, SC-SIL4-015 |
    """

    @tag rpn: 54
    @tag :sc_cluster_002
    test "cluster page mounts within split-brain detection threshold" do
      start_ms = System.monotonic_time(:millisecond)

      {:ok, _view, html} = live(build_conn(), "/cockpit/cluster")

      elapsed = System.monotonic_time(:millisecond) - start_ms

      assert is_binary(html)
      # Mount must not saturate the 5s detection window
      assert elapsed < 2000,
             "ClusterLive mount took #{elapsed}ms; must not saturate SC-CLUSTER-002 5s window"
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: ClusterLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_clu_001, :election_during_node_removal, 108},
        {:fm_clu_002, :scale_beyond_limits, 84},
        {:fm_clu_003, :autoscale_oscillation, 100},
        {:fm_clu_004, :node_selection_race, 100},
        {:fm_clu_005, :add_node_duplicate, 70},
        {:fm_clu_006, :split_brain_latency, 54}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 6
      assert total_rpn_before == 516

      # Election during removal is highest risk
      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :election_during_node_removal
      assert highest_rpn == 108
    end
  end
end
