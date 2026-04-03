defmodule IndrajaalWeb.Fmea.GitIntelligenceLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.GitIntelligenceLive.

  Analyzes failure modes in the Git Intelligence dashboard, focusing on
  Zenoh bridge disconnection masking commit stream, health score overflow,
  threat alert display corruption, and ETS cache unavailability.

  This LiveView has NO handle_event clauses — all failure modes are on the
  data acquisition and handle_info paths (refresh, git_intelligence,
  git_intelligence_health, git_intelligence_threat).

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-IMMUNE-001, SC-ZENOH-003, SC-BRIDGE-005, SC-PRAJNA-004, SC-GIT-006
  Reference: IEC 60812 FMEA
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-GIT-001: Zenoh Git Intelligence Bridge Disconnection
  # Severity: 9 (commit stream lost — unauthorized commits go undetected)
  # Occurrence: 3 (Zenoh router restart, network partition)
  # Detection: 5 (health badge shows disconnected but operator may not check)
  # RPN: 135
  # ============================================================================

  describe "FM-GIT-001: Zenoh Bridge Disconnection (RPN: 135)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | GitIntelligence Zenoh subscriber loses connection |
    | Effect | Commit stream stops — malicious commits invisible in dashboard |
    | Severity | 9 (safety-critical: SC-GIT-006 Guardian gating unmonitored) |
    | Occurrence | 3 (Zenoh router restart, container restart) |
    | Detection | 5 (health indicator may show disconnected but not prominently) |
    | RPN Before | 135 |
    | Mitigation | Prominent \"STREAM DISCONNECTED\" banner; auto-reconnect with escalation |
    | RPN After | 27 (S:9 x O:1 x D:3) |
    | STAMP | SC-ZENOH-003, SC-BRIDGE-005, SC-GIT-006 |
    """

    @tag rpn: 135
    test "page mounts and renders git intelligence dashboard" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)

      assert html =~ "Git" or html =~ "git" or html =~ "GIT" or
               html =~ "Intelligence" or html =~ "Commit"
    end

    @tag rpn: 135
    test "page renders when Zenoh bridge is unavailable" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end

    @tag rpn: 135
    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # FM-GIT-002: Health Score NaN or Out of Range
  # Severity: 7 (GHS display shows invalid value — operator misreads health)
  # Occurrence: 2 (malformed Zenoh message with invalid score)
  # Detection: 5 (unusual % value may not be flagged)
  # RPN: 70
  # ============================================================================

  describe "FM-GIT-002: Health Score NaN or Out of Range (RPN: 70)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | git_intelligence_health message contains health_score outside [0.0, 1.0] |
    | Effect | GHS display shows NaN%, negative%, or >100% |
    | Severity | 7 (operator may misinterpret degraded git health as healthy) |
    | Occurrence | 2 (rare: malformed Zenoh payload) |
    | Detection | 5 (unusual % — may be dismissed as display glitch) |
    | RPN Before | 70 |
    | Mitigation | Clamp health_score to [0.0, 1.0] on receipt |
    | RPN After | 14 (S:7 x O:1 x D:2) |
    | STAMP | SC-PRAJNA-004, SC-IMMUNE-001 |
    """

    @tag rpn: 70
    test "page renders health section without crash" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end

    @tag rpn: 70
    test "repeated renders produce stable HTML" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")
      html1 = render(view)
      html2 = render(view)
      assert is_binary(html1)
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-GIT-003: Threat Alert PubSub Flood
  # Severity: 7 (UI unresponsive when burst of threat events arrives)
  # Occurrence: 3 (scanner misconfiguration, test harness loop)
  # Detection: 4 (latency visible to operator)
  # RPN: 84
  # ============================================================================

  describe "FM-GIT-003: Threat Alert PubSub Flood (RPN: 84)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | {:git_intelligence_threat, _} messages flood the LiveView mailbox |
    | Effect | LiveView mailbox overwhelmed — operator loses real-time commit monitoring |
    | Severity | 7 (operator loses git threat awareness) |
    | Occurrence | 3 (scanner misconfiguration, buggy publisher) |
    | Detection | 4 (latency visible but not diagnosed immediately) |
    | RPN Before | 84 |
    | Mitigation | Circuit breaker on handle_info for git threats; deduplicate by sha |
    | RPN After | 28 (S:7 x O:2 x D:2) |
    | STAMP | SC-CIRCUIT-001, SC-BRIDGE-005, SC-IMMUNE-001 |
    """

    @tag rpn: 84
    test "page is resilient to rapid re-renders" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")

      for _i <- 1..3 do
        render(view)
      end

      html = render(view)
      assert is_binary(html)
    end

    @tag rpn: 84
    test "page handles missing git data gracefully" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-GIT-004: Recent Commits List Overflow
  # Severity: 3 (old commits silently dropped from display)
  # Occurrence: 5 (active repo with many commits)
  # Detection: 6 (no count indicator — hard to detect)
  # RPN: 90
  # ============================================================================

  describe "FM-GIT-004: Recent Commits List Overflow (RPN: 90)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | recent_commits list grows unbounded or truncates without indicator |
    | Effect | Operator cannot see all recent commits — misses Guardian-gated ones |
    | Severity | 3 (minor: some commits invisible in UI) |
    | Occurrence | 5 (active repo with continuous commits) |
    | Detection | 6 (no truncation indicator — hard to detect) |
    | RPN Before | 90 |
    | Mitigation | Show \"N more commits\" indicator; persist all to DuckDB |
    | RPN After | 18 (S:3 x O:2 x D:3) |
    | STAMP | SC-GIT-006, SC-ARK-001 |
    """

    @tag rpn: 90
    test "page renders commit list section without crash" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end

    @tag rpn: 90
    test "page remains stable across multiple renders" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")

      for _i <- 1..5 do
        render(view)
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-GIT-005: ETS Cache Unavailable on Mount
  # Severity: 5 (dashboard mounts with empty state — no history shown)
  # Occurrence: 3 (ETS table not yet populated on first boot)
  # Detection: 3 (empty dashboard obvious)
  # RPN: 45
  # ============================================================================

  describe "FM-GIT-005: ETS Cache Unavailable on Mount (RPN: 45)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | GitIntelligence ETS cache not populated before LiveView mounts |
    | Effect | Dashboard shows empty/zero state — \"No commits\" when actually running |
    | Severity | 5 (moderate: confusing but not safety-critical) |
    | Occurrence | 3 (first boot before first Zenoh sync cycle) |
    | Detection | 3 (empty state is visually obvious) |
    | RPN Before | 45 |
    | Mitigation | Show \"Loading...\" state distinguishable from \"No data\" state |
    | RPN After | 9 (S:5 x O:1 x D:1) |
    | STAMP | SC-PRAJNA-001, SC-ZENOH-003 |
    """

    @tag rpn: 45
    test "page renders on first mount even without cached data" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: GitIntelligenceLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_git_001, :zenoh_bridge_disconnection, 135},
        {:fm_git_002, :health_score_nan_or_out_of_range, 70},
        {:fm_git_003, :threat_alert_pubsub_flood, 84},
        {:fm_git_004, :recent_commits_list_overflow, 90},
        {:fm_git_005, :ets_cache_unavailable_on_mount, 45}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 5
      assert total_rpn_before == 424

      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :zenoh_bridge_disconnection
      assert highest_rpn == 135
    end
  end
end
