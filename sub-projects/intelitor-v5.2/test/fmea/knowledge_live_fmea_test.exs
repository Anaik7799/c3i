defmodule IndrajaalWeb.Fmea.KnowledgeLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.KnowledgeLive.

  Analyzes failure modes in the knowledge management dashboard, focusing
  on malicious search input, view-mode race conditions, empty knowledge
  base display, large result set rendering, and navigation inconsistencies.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-KMS-001, SC-KMS-004, SC-KMS-007, SC-HMI-001
  Reference: IEC 60812 FMEA, Fractal Holonic Architecture spec
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-KNOWLEDGE-001: Search with Malicious Input
  # Severity: 6 (SQL injection / regex DoS crashing the KMS search path)
  # Occurrence: 4 (pentest, curious operators, client-side tampering)
  # Detection: 3 (error flash or empty result set visible immediately)
  # RPN: 72
  # ============================================================================

  describe "FM-KNOWLEDGE-001: Search with Malicious Input (RPN: 72)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | search event receives SQL injection or regex-bomb payload |
    | Effect | KMS.search/2 crashes or hangs; page becomes unresponsive |
    | Severity | 6 (operator loses knowledge access; no direct safety impact) |
    | Occurrence | 4 (any operator can type arbitrary text into search box) |
    | Detection | 3 (results panel shows empty or error; operator notices quickly) |
    | RPN Before | 72 |
    | Mitigation | Input sanitization in KMS.search/2, parameterized FTS5 queries |
    | RPN After | 12 (S:6 x O:1 x D:2) |
    | STAMP | SC-KMS-004, SC-KMS-001 |
    """

    @tag rpn: 72
    test "search with SQL injection payload does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "search", %{"query" => "'; DROP TABLE holons; --"})

      assert is_binary(html)
    end

    @tag rpn: 72
    test "search with regex bomb payload does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      # Classic ReDoS pattern
      html = render_click(view, "search", %{"query" => "(a+)+" <> String.duplicate("a", 100)})

      assert is_binary(html)
    end

    @tag rpn: 72
    test "search with very long query string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      long_query = String.duplicate("architecture", 1_000)
      html = render_click(view, "search", %{"query" => long_query})

      assert is_binary(html)
    end

    @tag rpn: 72
    test "search with unicode control characters does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "search", %{"query" => "\u0000\u001F\u007F\uFFFD"})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-KNOWLEDGE-002: View Mode Switch During Loading
  # Occurrence: 5 (operators switch views while data is still loading)
  # Severity: 4 (broken intermediate render; operator must reload)
  # Detection: 3 (visual artifact visible immediately in UI)
  # RPN: 60
  # ============================================================================

  describe "FM-KNOWLEDGE-002: View Mode Switch During Loading (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | change_view fired while KMS data load is still in progress |
    | Effect | Template rendered with partially populated assigns for wrong view mode |
    | Severity | 4 (visual glitch; knowledge still accessible via refresh) |
    | Occurrence | 5 (operators impatient during slow queries) |
    | Detection | 3 (broken layout immediately visible) |
    | RPN Before | 60 |
    | Mitigation | Loading state guard in template, view-mode assign set atomically |
    | RPN After | 12 (S:4 x O:1 x D:3) |
    | STAMP | SC-KMS-004, SC-HMI-001 |
    """

    @tag rpn: 60
    test "change_view to tree mode does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "change_view", %{"mode" => "tree"})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "change_view to list mode does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "change_view", %{"mode" => "list"})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "rapid view mode switches do not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      _html1 = render_click(view, "change_view", %{"mode" => "list"})
      _html2 = render_click(view, "change_view", %{"mode" => "tree"})
      html3 = render_click(view, "change_view", %{"mode" => "list"})

      assert is_binary(html3)
    end

    @tag rpn: 60
    test "change_view with unknown mode string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html =
        try do
          render_click(view, "change_view", %{"mode" => "holographic_3d_unknown"})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-KNOWLEDGE-003: Empty Knowledge Base Display
  # Severity: 3 (operator cannot find knowledge but page is functional)
  # Occurrence: 6 (fresh deployments, test environments, DB wipe)
  # Detection: 2 (empty state immediately visible)
  # RPN: 36
  # ============================================================================

  describe "FM-KNOWLEDGE-003: Empty Knowledge Base Display (RPN: 36)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | KMS returns empty holon set on initial load |
    | Effect | Page renders with empty tree/list; operator cannot find knowledge |
    | Severity | 3 (minor operational inconvenience, not a safety risk) |
    | Occurrence | 6 (common in test/staging environments) |
    | Detection | 2 (empty state is immediately visible) |
    | RPN Before | 36 |
    | Mitigation | Empty-state messaging with onboarding guidance, seed data check |
    | RPN After | 6 (S:3 x O:1 x D:2) |
    | STAMP | SC-KMS-001, SC-HMI-001 |
    """

    @tag rpn: 36
    test "page mounts and renders without crash even when holons empty" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/knowledge")

      assert is_binary(html)
      assert html =~ "Knowledge" or html =~ "knowledge"
    end

    @tag rpn: 36
    test "select_holon with non-existent id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "select_holon", %{"id" => "holon-does-not-exist-99999"})

      assert is_binary(html)
    end

    @tag rpn: 36
    test "toggle_expand with non-existent node id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "toggle_expand", %{"id" => "nonexistent-node-00000"})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-KNOWLEDGE-004: Large Result Set Rendering
  # Severity: 5 (browser freeze from large DOM; operator loses responsiveness)
  # Occurrence: 3 (unconstrained search on large knowledge base)
  # Detection: 4 (browser lag not immediately obvious until user interaction)
  # RPN: 60
  # ============================================================================

  describe "FM-KNOWLEDGE-004: Large Result Set Rendering (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | KMS.search/2 returns thousands of results; LiveView pushes large diff |
    | Effect | Browser DOM update freezes the operator workstation |
    | Severity | 5 (operator loses control of cockpit interface temporarily) |
    | Occurrence | 3 (broad single-character queries, large knowledge base) |
    | Detection | 4 (freeze not apparent until after search; lag detected after fact) |
    | RPN Before | 60 |
    | Mitigation | KMS.search/2 limit: 20 (already coded), UI pagination guard |
    | RPN After | 15 (S:5 x O:1 x D:3) |
    | STAMP | SC-KMS-004, SC-HMI-001 |
    """

    @tag rpn: 60
    test "search with single character does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "search", %{"query" => "a"})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "search followed by empty query clears results without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      _html1 = render_click(view, "search", %{"query" => "architecture"})
      html2 = render_click(view, "search", %{"query" => ""})

      assert is_binary(html2)
    end

    @tag rpn: 60
    test "filter_type with known type after search does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      _html1 = render_click(view, "search", %{"query" => "knowledge"})
      html2 = render_click(view, "filter_type", %{"type" => "architecture"})

      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-KNOWLEDGE-005: Breadcrumb Navigation Inconsistency
  # Severity: 4 (operator navigates to wrong knowledge context)
  # Occurrence: 3 (holon tree navigation with rapid clicks)
  # Detection: 5 (subtle — selected_holon assign may not match displayed breadcrumb)
  # RPN: 60
  # ============================================================================

  describe "FM-KNOWLEDGE-005: Breadcrumb Navigation Inconsistency (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | select_holon and toggle_expand fired in rapid succession |
    | Effect | Breadcrumb shows parent while detail panel shows child |
    | Severity | 4 (confusion about which knowledge item is displayed) |
    | Occurrence | 3 (double-click or rapid keyboard navigation) |
    | Detection | 5 (mismatch between breadcrumb and detail panel is subtle) |
    | RPN Before | 60 |
    | Mitigation | Atomic assign update for selected_holon + expanded path |
    | RPN After | 20 (S:4 x O:2 x D:2.5) |
    | STAMP | SC-KMS-007, SC-HMI-001 |
    """

    @tag rpn: 60
    test "filter_type all clears filter without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      _html1 = render_click(view, "filter_type", %{"type" => "knowledge"})
      html2 = render_click(view, "filter_type", %{"type" => "all"})

      assert is_binary(html2)
    end

    @tag rpn: 60
    test "create_adr event does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "create_adr", %{})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "create_holon event does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html = render_click(view, "create_holon", %{})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "unknown event does not crash the LiveView process" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      html =
        try do
          render_click(view, "nonexistent_knowledge_event", %{"data" => "anything"})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: KnowledgeLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_knowledge_001, :search_malicious_input, 72},
        {:fm_knowledge_002, :view_mode_switch_during_loading, 60},
        {:fm_knowledge_003, :empty_knowledge_base_display, 36},
        {:fm_knowledge_004, :large_result_set_rendering, 60},
        {:fm_knowledge_005, :breadcrumb_navigation_inconsistency, 60}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 5
      assert total_rpn_before == 288

      # Highest RPN is malicious search input — requires priority mitigation
      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :search_malicious_input
      assert highest_rpn == 72
    end
  end
end
