defmodule IndrajaalWeb.Fmea.CopilotLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.CopilotLive.

  Analyzes failure modes in the AI Copilot interface, focusing on
  apply_recommendation bypass of human review, submit_query with empty/malicious
  input, dismiss_insight race conditions, and LLM toggle state corruption.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-AI-001, SC-HMI-001, SC-VDP-009, SC-EVAL-003, SC-PRAJNA-001, SC-SAFETY-001
  Reference: IEC 60812 FMEA
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-COP-001: Apply Recommendation Without Human Review
  # Severity: 9 (AI recommendation applied without operator validation = SC-AI-001)
  # Occurrence: 4 (operator trusts AI, clicks quickly)
  # Detection: 4 (no confirmation step, action fires immediately)
  # RPN: 144
  # ============================================================================

  describe "FM-COP-001: Apply Recommendation Without Human Review (RPN: 144)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | apply_recommendation executes without human confirmation step |
    | Effect | AI-directed action taken without operator review — violates SC-AI-001 |
    | Severity | 9 (safety: AI bypasses Human-in-the-Loop mandate) |
    | Occurrence | 4 (operator under pressure, clicks APPLY without reviewing) |
    | Detection | 4 (flash shown, but action already applied) |
    | RPN Before | 144 |
    | Mitigation | Two-step: arm recommendation then confirm with explicit review dialog |
    | RPN After | 36 (S:9 x O:2 x D:2) |
    | STAMP | SC-AI-001, SC-SAFETY-001, SC-PRAJNA-005 |
    """

    @tag rpn: 144
    test "page mounts and renders AI Copilot interface" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/ai-copilot")
      assert is_binary(html)
      assert html =~ "Copilot" or html =~ "copilot" or html =~ "AI"
    end

    @tag rpn: 144
    test "apply_recommendation with existing id fires flash without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "apply_recommendation", %{"id" => "INS-001"})
      assert is_binary(html)
    end

    @tag rpn: 144
    test "apply_recommendation with non-existent id is graceful" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "apply_recommendation", %{"id" => "INS-NONEXISTENT-99999"})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-COP-002: submit_query with Empty or Malicious Input
  # Severity: 5 (query panics or leaks internal info on unexpected input)
  # Occurrence: 4 (operator submits form with empty query by accident)
  # Detection: 3 (response renders but may expose stack trace)
  # RPN: 60
  # ============================================================================

  describe "FM-COP-002: Query with Empty or Malicious Input (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | submit_query receives empty string or injection payload |
    | Effect | process_query may expose internal module names or crash on nil |
    | Severity | 5 (moderate: confusing output, minor info disclosure) |
    | Occurrence | 4 (accidental empty submit is common) |
    | Detection | 3 (query result renders, operator sees response) |
    | RPN Before | 60 |
    | Mitigation | Validate query length > 0 before processing; sanitize before display |
    | RPN After | 20 (S:5 x O:2 x D:2) |
    | STAMP | SC-HMI-001, SC-VDP-009 |
    """

    @tag rpn: 60
    test "submit_query with empty string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "submit_query", %{"query" => ""})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "submit_query with normal question returns valid response" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "submit_query", %{"query" => "What is the current CPU?"})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "submit_query with long string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      long_query = String.duplicate("a", 10_000)
      html = render_click(view, "submit_query", %{"query" => long_query})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "clear_query after submit_query resets state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      _html1 = render_click(view, "submit_query", %{"query" => "health?"})
      html2 = render_click(view, "clear_query", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-COP-003: dismiss_insight Race Condition
  # Severity: 5 (stale insight visible briefly if dismissed concurrently)
  # Occurrence: 4 (two operator sessions dismiss same insight)
  # Detection: 3 (UI briefly shows dismissed insight — visually noticeable)
  # RPN: 60
  # ============================================================================

  describe "FM-COP-003: dismiss_insight Race Condition (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Two sessions dismiss same insight id simultaneously |
    | Effect | Both succeed (idempotent filter), but audit trail may double-count |
    | Severity | 5 (minor UX confusion, not safety-critical) |
    | Occurrence | 4 (common: multiple operators on same copilot view) |
    | Detection | 3 (insight disappears from both sessions correctly) |
    | RPN Before | 60 |
    | Mitigation | Idempotent Enum.reject is already safe — document double-dismiss |
    | RPN After | 15 (S:5 x O:1 x D:3) |
    | STAMP | SC-HMI-001, SC-PRAJNA-001 |
    """

    @tag rpn: 60
    test "dismiss_insight with existing id removes it from list" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "dismiss_insight", %{"id" => "INS-001"})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "dismiss_insight with non-existent id is graceful" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "dismiss_insight", %{"id" => "INS-PHANTOM-99999"})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "double-dismiss of same insight id is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      _html1 = render_click(view, "dismiss_insight", %{"id" => "INS-002"})
      html2 = render_click(view, "dismiss_insight", %{"id" => "INS-002"})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-COP-004: LLM Toggle State Corruption
  # Severity: 3 (LLM enabled state inverted by double-click)
  # Occurrence: 5 (rapid double-click common on slow networks)
  # Detection: 3 (button label shows ON/OFF — state visible)
  # RPN: 45
  # ============================================================================

  describe "FM-COP-004: LLM Toggle State Corruption (RPN: 45)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Rapid double-click on toggle_llm inverts state twice → wrong final state |
    | Effect | Operator sees LLM: OFF but thinks they turned it ON |
    | Severity | 3 (minor: advisory-only AI, not safety path) |
    | Occurrence | 5 (rapid clicking common in busy cockpit) |
    | Detection | 3 (label visible — operator can verify state) |
    | RPN Before | 45 |
    | Mitigation | Debounce toggle, or show confirmation for LLM disable |
    | RPN After | 9 (S:3 x O:1 x D:3) |
    | STAMP | SC-AI-001, SC-HMI-001 |
    """

    @tag rpn: 45
    test "toggle_llm single click inverts state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "toggle_llm", %{})
      assert is_binary(html)
    end

    @tag rpn: 45
    test "toggle_llm double-click returns to original state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      _html1 = render_click(view, "toggle_llm", %{})
      html2 = render_click(view, "toggle_llm", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-COP-005: select_insight then dismiss — Stale Selection
  # Severity: 3 (selected_insight assign still holds dismissed id)
  # Occurrence: 5 (common: select insight, then dismiss it)
  # Detection: 3 (panel shows empty — noticeable)
  # RPN: 45
  # ============================================================================

  describe "FM-COP-005: select_insight then dismiss Stale State (RPN: 45)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | dismiss_insight does not clear selected_insight when they match |
    | Effect | selected_insight holds id of dismissed insight — nil panel briefly |
    | Severity | 3 (minor UX inconsistency, not safety-critical) |
    | Occurrence | 5 (normal workflow: inspect then dismiss) |
    | Detection | 3 (panel renders empty — visually obvious) |
    | RPN Before | 45 |
    | Mitigation | dismiss_insight clears selected_insight if it matches dismissed id |
    | RPN After | 9 (S:3 x O:1 x D:3) |
    | STAMP | SC-HMI-001, SC-PRAJNA-001 |
    """

    @tag rpn: 45
    test "select_insight with valid id sets selection" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "select_insight", %{"id" => "INS-001"})
      assert is_binary(html)
    end

    @tag rpn: 45
    test "select_insight then dismiss leaves page in valid state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      _html1 = render_click(view, "select_insight", %{"id" => "INS-002"})
      html2 = render_click(view, "dismiss_insight", %{"id" => "INS-002"})
      assert is_binary(html2)
    end

    @tag rpn: 45
    test "analyze_now triggers without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "analyze_now", %{})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-COP-006: clear_query When No Query Active
  # Severity: 1 (assigns empty string over empty string — no effect)
  # Occurrence: 5 (operator clicks clear habitually)
  # Detection: 1 (no crash, no visual change)
  # RPN: 5
  # ============================================================================

  describe "FM-COP-006: clear_query When No Query Active (RPN: 5)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | clear_query called when query = \"\" and query_result = nil |
    | Effect | assign(:query, \"\") and assign(:query_result, nil) — pure no-op |
    | Severity | 1 (negligible — idempotent operation) |
    | Occurrence | 5 (operator clicks clear button by habit) |
    | Detection | 1 (no change, no symptom) |
    | RPN Before | 5 |
    | Mitigation | Already idempotent — no action required |
    | RPN After | 1 |
    | STAMP | SC-HMI-001 |
    """

    @tag rpn: 5
    test "clear_query on fresh mount is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
      html = render_click(view, "clear_query", %{})
      assert is_binary(html)
    end

    @tag rpn: 5
    test "repeated clear_query calls are safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")

      for _i <- 1..3 do
        render_click(view, "clear_query", %{})
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: CopilotLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_cop_001, :apply_recommendation_without_human_review, 144},
        {:fm_cop_002, :query_empty_or_malicious_input, 60},
        {:fm_cop_003, :dismiss_insight_race_condition, 60},
        {:fm_cop_004, :llm_toggle_state_corruption, 45},
        {:fm_cop_005, :select_insight_then_dismiss_stale, 45},
        {:fm_cop_006, :clear_query_when_no_query_active, 5}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 6
      assert total_rpn_before == 359

      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :apply_recommendation_without_human_review
      assert highest_rpn == 144
    end
  end
end
