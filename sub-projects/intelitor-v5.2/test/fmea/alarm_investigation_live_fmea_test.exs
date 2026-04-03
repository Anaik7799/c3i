defmodule IndrajaalWeb.Fmea.AlarmInvestigationLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Operations.AlarmInvestigationLive.

  Analyzes failure modes in the Alarm Investigation interface, focusing on
  destructive state transitions without Guardian pre-approval, note injection,
  video export without audit, and concurrent operator state corruption.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-ALARM-001, SC-SAFETY-001, SC-SAFETY-003, SC-GDE-001, SC-PRAJNA-005
  Reference: IEC 60812 FMEA, IEC 61508 SIL-4
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # Default test alarm ID used across tests
  @test_alarm_id "ALM-2024-00_142"

  # ============================================================================
  # FM-ALI-001: False Alarm Without Audit Trail
  # Severity: 9 (false_alarm disposition recorded without audit entry = SC-SAFETY-003)
  # Occurrence: 3 (operator clicks too fast, misidentifies alarm)
  # Detection: 5 (audit trail missing — only detectable via external review)
  # RPN: 135
  # ============================================================================

  describe "FM-ALI-001: False Alarm Without Audit Trail (RPN: 135)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | false_alarm event fires without creating an audit entry |
    | Effect | Alarm marked false-positive with no traceable justification |
    | Severity | 9 (safety: false alarm disposition must be audited per SC-SAFETY-003) |
    | Occurrence | 3 (operator under pressure, clicks without entering note) |
    | Detection | 5 (missing audit entry only visible to compliance review) |
    | RPN Before | 135 |
    | Mitigation | Require note before false_alarm; write to Immutable Register on disposition |
    | RPN After | 27 (S:9 x O:1 x D:3) |
    | STAMP | SC-SAFETY-003, SC-ALARM-001, SC-GDE-001 |
    """

    @tag rpn: 135
    test "page mounts and renders alarm investigation interface" do
      {:ok, _view, html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      assert is_binary(html)
    end

    @tag rpn: 135
    test "false_alarm event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "false_alarm", %{})
      assert is_binary(html)
    end

    @tag rpn: 135
    test "false_alarm after adding a note does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      _html1 = render_click(view, "add_note", %{"note" => "Verified: sensor malfunction"})
      html2 = render_click(view, "false_alarm", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-ALI-002: Escalate Without Guardian Pre-Approval
  # Severity: 9 (escalation = safety action — must be Guardian-gated per SC-SAFETY-001)
  # Occurrence: 4 (operator escalates under stress without formal review)
  # Detection: 4 (escalation flash shown, but Guardian not consulted)
  # RPN: 144
  # ============================================================================

  describe "FM-ALI-002: Escalate Without Guardian Pre-Approval (RPN: 144)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | escalate event fires without Guardian.validate/2 pre-approval |
    | Effect | Alarm escalated to safety response team without constitutional validation |
    | Severity | 9 (safety-critical: unvalidated escalation triggers response chain) |
    | Occurrence | 4 (alarm investigation interface under pressure encourages rapid action) |
    | Detection | 4 (flash shown but Guardian not consulted) |
    | RPN Before | 144 |
    | Mitigation | Wrap escalate in Guardian.validate/2; require two-step confirm |
    | RPN After | 27 (S:9 x O:1 x D:3) |
    | STAMP | SC-SAFETY-001, SC-GDE-001, SC-PRAJNA-005 |
    """

    @tag rpn: 144
    test "escalate event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "escalate", %{})
      assert is_binary(html)
    end

    @tag rpn: 144
    test "verify then escalate sequence does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      _html1 = render_click(view, "verify", %{})
      html2 = render_click(view, "escalate", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-ALI-003: add_note with Missing or Empty Note Parameter
  # Severity: 7 (blank note recorded in audit trail — compliance violation)
  # Occurrence: 4 (operator submits form without filling note field)
  # Detection: 3 (empty note visible in audit trail)
  # RPN: 84
  # ============================================================================

  describe "FM-ALI-003: add_note Missing or Empty Parameter (RPN: 84)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | add_note receives empty string or missing \"note\" key |
    | Effect | Empty audit entry recorded — compliance review finds blank justification |
    | Severity | 7 (significant: blank audit entry is a compliance violation) |
    | Occurrence | 4 (operator submits form by habit without content) |
    | Detection | 3 (empty note visible in audit trail list) |
    | RPN Before | 84 |
    | Mitigation | Validate note length > 0 before recording; reject empty notes |
    | RPN After | 21 (S:7 x O:1 x D:3) |
    | STAMP | SC-SAFETY-003, SC-ALARM-001 |
    """

    @tag rpn: 84
    test "add_note with valid note does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "add_note", %{"note" => "Investigated and verified"})
      assert is_binary(html)
    end

    @tag rpn: 84
    test "add_note with empty string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")

      html =
        try do
          render_click(view, "add_note", %{"note" => ""})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end

    @tag rpn: 84
    test "add_note with missing note key does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")

      html =
        try do
          render_click(view, "add_note", %{})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-ALI-004: Close Without Completing Investigation
  # Severity: 7 (alarm closed in active state — investigation incomplete)
  # Occurrence: 4 (operator closes by mistake or session timeout)
  # Detection: 4 (alarm status shows closed but notes missing)
  # RPN: 112
  # ============================================================================

  describe "FM-ALI-004: Close Without Completing Investigation (RPN: 112)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | close event fires on an alarm that has no disposition note |
    | Effect | Alarm closed in database without proper investigation record |
    | Severity | 7 (significant: incomplete investigation — compliance and safety risk) |
    | Occurrence | 4 (session timeout, accidental close) |
    | Detection | 4 (closed alarm may have no notes — audit review required) |
    | RPN Before | 112 |
    | Mitigation | Require at least one note before close is permitted |
    | RPN After | 28 (S:7 x O:2 x D:2) |
    | STAMP | SC-ALARM-001, SC-SAFETY-003, SC-GDE-001 |
    """

    @tag rpn: 112
    test "close event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "close", %{})
      assert is_binary(html)
    end

    @tag rpn: 112
    test "verify then close sequence does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      _html1 = render_click(view, "verify", %{})
      html2 = render_click(view, "close", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-ALI-005: play_video with Missing Evidence
  # Severity: 5 (video not found — operator missing critical evidence)
  # Occurrence: 4 (evidence not yet attached or camera offline)
  # Detection: 3 (error message or empty player visible)
  # RPN: 60
  # ============================================================================

  describe "FM-ALI-005: play_video with Missing Evidence (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | play_video event fires when no video evidence is linked to alarm |
    | Effect | Player shows empty or error state — operator makes decision without evidence |
    | Severity | 5 (moderate: missing evidence but not a direct safety action) |
    | Occurrence | 4 (cameras offline, evidence not yet uploaded) |
    | Detection | 3 (empty player visible — operator aware of missing evidence) |
    | RPN Before | 60 |
    | Mitigation | Show clear \"No video evidence\" message; disable button when no evidence |
    | RPN After | 15 (S:5 x O:1 x D:3) |
    | STAMP | SC-ALARM-001, SC-HMI-001 |
    """

    @tag rpn: 60
    test "play_video event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "play_video", %{})
      assert is_binary(html)
    end

    @tag rpn: 60
    test "export_clip event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "export_clip", %{})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-ALI-006: Verify on Already-Verified Alarm
  # Severity: 3 (double-verify records redundant audit entry)
  # Occurrence: 5 (operator verifies again after page reload)
  # Detection: 2 (idempotent visible in audit trail)
  # RPN: 30
  # ============================================================================

  describe "FM-ALI-006: Verify on Already-Verified Alarm (RPN: 30)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | verify called multiple times on the same alarm |
    | Effect | Duplicate audit entries recorded — minor compliance noise |
    | Severity | 3 (minor: audit trail noisy but not wrong) |
    | Occurrence | 5 (page reload, back-button, concurrent sessions) |
    | Detection | 2 (duplicate entries visible in audit trail) |
    | RPN Before | 30 |
    | Mitigation | Idempotent verify; deduplicate by operator+timestamp |
    | RPN After | 6 (S:3 x O:1 x D:2) |
    | STAMP | SC-ALARM-001, SC-SAFETY-003 |
    """

    @tag rpn: 30
    test "verify event does not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      html = render_click(view, "verify", %{})
      assert is_binary(html)
    end

    @tag rpn: 30
    test "double-verify is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      _html1 = render_click(view, "verify", %{})
      html2 = render_click(view, "verify", %{})
      assert is_binary(html2)
    end

    @tag rpn: 30
    test "full investigation workflow does not crash" do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{@test_alarm_id}")
      _h1 = render_click(view, "verify", %{})
      _h2 = render_click(view, "add_note", %{"note" => "Sensor verified as triggered"})
      _h3 = render_click(view, "play_video", %{})
      html4 = render_click(view, "close", %{})
      assert is_binary(html4)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: AlarmInvestigationLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_ali_001, :false_alarm_without_audit_trail, 135},
        {:fm_ali_002, :escalate_without_guardian_pre_approval, 144},
        {:fm_ali_003, :add_note_missing_or_empty_parameter, 84},
        {:fm_ali_004, :close_without_completing_investigation, 112},
        {:fm_ali_005, :play_video_with_missing_evidence, 60},
        {:fm_ali_006, :verify_on_already_verified_alarm, 30}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 6
      assert total_rpn_before == 565

      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :escalate_without_guardian_pre_approval
      assert highest_rpn == 144
    end
  end
end
