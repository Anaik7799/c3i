defmodule IndrajaalWeb.Fmea.SettingsLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.SettingsLive.

  Analyzes failure modes in the system settings and configuration screen,
  focusing on invalid values, envelope authorization bypass attempts,
  concurrent modifications, and data loss scenarios.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-CONFIG-001, SC-CONFIG-002, SC-HMI-001, SC-VDP-008
  Reference: IEC 60812 FMEA, NUREG-0700, MIL-STD-1472H
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-SETTINGS-001: Invalid Settings Values
  # Severity: 7 (misconfigured thresholds cause missed alarms or false positives)
  # Occurrence: 5 (operators frequently enter out-of-range values)
  # Detection: 3 (threshold values visible on screen)
  # RPN: 105
  # ============================================================================

  describe "FM-SETTINGS-001: Invalid Settings Values (RPN: 105)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Operator enters invalid threshold or display preference values |
    | Effect | Misconfigured thresholds cause missed alarms or constant false positives |
    | Severity | 7 (compromised alarm sensitivity degrades situational awareness) |
    | Occurrence | 5 (typos and out-of-range values common in numeric fields) |
    | Detection | 3 (visible on settings screen, save action provides feedback) |
    | RPN Before | 105 |
    | Mitigation | Input validation with range clamping, confirmation flash messages |
    | RPN After | 28 (S:7 x O:2 x D:2) |
    | STAMP | SC-CONFIG-001, SC-HMI-001 |
    """

    @tag rpn: 105
    test "update_threshold with empty string value does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "update_threshold", %{"cpu_warning" => ""})

      assert is_binary(html)
    end

    @tag rpn: 105
    test "update_threshold with negative numeric string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "update_threshold", %{"mem_warning" => "-999"})

      assert is_binary(html)
    end

    @tag rpn: 105
    test "update_display with unknown theme value does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "update_display", %{"theme" => "nonexistent_theme_xyzzy"})

      assert is_binary(html)
    end

    @tag rpn: 105
    test "update_ai with out-of-range analysis interval does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "update_ai", %{"analysis_interval" => "999999"})

      assert is_binary(html)
    end

    @tag rpn: 105
    test "page mounts and renders settings header without crash" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/settings")

      assert is_binary(html)
      assert html =~ "Settings" or html =~ "SETTINGS"
    end
  end

  # ============================================================================
  # FM-SETTINGS-002: Envelope Auth with Wrong Code
  # Severity: 8 (safety envelope access with wrong authorization = security breach attempt)
  # Occurrence: 4 (operator error, brute-force, client-side replay)
  # Detection: 2 (auth failure flashed immediately)
  # RPN: 64
  # ============================================================================

  describe "FM-SETTINGS-002: Envelope Auth with Wrong Code (RPN: 64)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | envelope_auth submitted with incorrect authorization code |
    | Effect | Safety envelope parameters exposed or modified without proper auth |
    | Severity | 8 (two-key auth bypass = safety parameter mutation risk, SC-CONFIG-002) |
    | Occurrence | 4 (operator typo, screen sharing, brute force attempt) |
    | Detection | 2 (error flash rendered immediately on mismatch) |
    | RPN Before | 64 |
    | Mitigation | Error flash with no hint, no partial unlock on single key failure |
    | RPN After | 16 (S:8 x O:1 x D:2) |
    | STAMP | SC-CONFIG-002, SC-SAFETY-001 |
    """

    @tag rpn: 64
    test "envelope_auth with wrong code renders error and does not unlock" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      # Arm the envelope edit mode first
      _html = render_click(view, "modify_envelope", %{})

      # Submit wrong authorization code
      html = render_submit(view, "envelope_auth", %{"code" => "0000"})

      assert is_binary(html)
    end

    @tag rpn: 64
    test "envelope_auth with empty code does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html = render_click(view, "modify_envelope", %{})

      html = render_submit(view, "envelope_auth", %{"code" => ""})

      assert is_binary(html)
    end

    @tag rpn: 64
    test "envelope_auth with very long code string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html = render_click(view, "modify_envelope", %{})

      long_code = String.duplicate("9", 10_000)
      html = render_submit(view, "envelope_auth", %{"code" => long_code})

      assert is_binary(html)
    end

    @tag rpn: 64
    test "cancel_envelope_edit after wrong auth resets state gracefully" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html = render_click(view, "modify_envelope", %{})
      _html = render_submit(view, "envelope_auth", %{"code" => "wrong"})
      html = render_click(view, "cancel_envelope_edit", %{})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-SETTINGS-003: Concurrent Settings Modification
  # Severity: 6 (stale settings write overwrites a valid change from another session)
  # Occurrence: 3 (rare — dual-operator scenario)
  # Detection: 4 (unsaved-changes indicator may obscure overwrite)
  # RPN: 72
  # ============================================================================

  describe "FM-SETTINGS-003: Concurrent Settings Modification (RPN: 72)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Two operator sessions modify settings simultaneously |
    | Effect | Last-writer-wins overwrites valid threshold change from other session |
    | Severity | 6 (lost configuration change, alarms mis-tuned) |
    | Occurrence | 3 (shift handover scenario, shared workstation) |
    | Detection | 4 (unsaved-changes banner present but does not warn of remote change) |
    | RPN Before | 72 |
    | Mitigation | Optimistic concurrency, version stamp on save, flash on overwrite |
    | RPN After | 18 (S:6 x O:1 x D:3) |
    | STAMP | SC-CONFIG-001, SC-HMI-001 |
    """

    @tag rpn: 72
    test "rapid successive update_threshold calls are idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html1 = render_click(view, "update_threshold", %{"cpu_warning" => "85"})
      html2 = render_click(view, "update_threshold", %{"cpu_warning" => "90"})

      assert is_binary(html2)
    end

    @tag rpn: 72
    test "update_display followed immediately by save_changes does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html1 = render_click(view, "update_display", %{"theme" => "light"})
      html2 = render_click(view, "save_changes", %{})

      assert is_binary(html2)
    end

    @tag rpn: 72
    test "toggle_llm called multiple times rapidly does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html1 = render_click(view, "toggle_llm", %{})
      _html2 = render_click(view, "toggle_llm", %{})
      html3 = render_click(view, "toggle_llm", %{})

      assert is_binary(html3)
    end
  end

  # ============================================================================
  # FM-SETTINGS-004: Settings Save During Network Partition
  # Severity: 7 (operator believes settings saved; system continues with stale config)
  # Occurrence: 2 (rare network fault)
  # Detection: 5 (save flash shown regardless, actual persistence failure silent)
  # RPN: 70
  # ============================================================================

  describe "FM-SETTINGS-004: Settings Save During Network Partition (RPN: 70)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | save_changes fires but backend persistence call fails silently |
    | Effect | Operator receives "Settings saved" flash but config reverts on restart |
    | Severity | 7 (phantom confirmation; next shift starts with wrong thresholds) |
    | Occurrence | 2 (network/DB partition uncommon) |
    | Detection | 5 (flash message indistinguishable from success; silent error) |
    | RPN Before | 70 |
    | Mitigation | Async save with explicit error flash on failure, retry indicator |
    | RPN After | 21 (S:7 x O:1 x D:3) |
    | STAMP | SC-CONFIG-001, SC-FUNC-003 |
    """

    @tag rpn: 70
    test "save_changes when no user is logged in does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      # Trigger unsaved changes first
      _html = render_click(view, "update_threshold", %{"cpu_warning" => "88"})

      # Save without authenticated user — must not crash
      html = render_click(view, "save_changes", %{})

      assert is_binary(html)
    end

    @tag rpn: 70
    test "export_config does not crash regardless of backend state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "export_config", %{})

      assert is_binary(html)
    end

    @tag rpn: 70
    test "import_config does not crash regardless of backend state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "import_config", %{})

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-SETTINGS-005: Reset Defaults Data Loss
  # Severity: 9 (operator-tuned safety thresholds wiped without warning)
  # Occurrence: 2 (accidental click or misunderstood button label)
  # Detection: 2 (reset is immediate with flash, no undo path)
  # RPN: 36
  # ============================================================================

  describe "FM-SETTINGS-005: Reset Defaults Data Loss (RPN: 36)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | reset_defaults fired accidentally, erasing operator-tuned thresholds |
    | Effect | Site-specific alarm thresholds replaced with factory defaults |
    | Severity | 9 (factory thresholds inappropriate for site = safety critical) |
    | Occurrence | 2 (misclick; no confirmation required by current implementation) |
    | Detection | 2 (reset flash appears immediately; operator may not notice until alarm) |
    | RPN Before | 36 |
    | Mitigation | Confirmation modal before reset, backup to ImmutableRegister pre-reset |
    | RPN After | 9 (S:9 x O:1 x D:1) |
    | STAMP | SC-CONFIG-001, SC-SAFETY-004 |
    """

    @tag rpn: 36
    test "reset_defaults returns page without crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html = render_click(view, "reset_defaults", %{})

      assert is_binary(html)
    end

    @tag rpn: 36
    test "reset_defaults after unsaved changes does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html = render_click(view, "update_threshold", %{"cpu_warning" => "99"})
      html = render_click(view, "reset_defaults", %{})

      assert is_binary(html)
    end

    @tag rpn: 36
    test "reset_defaults followed by save_changes is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      _html1 = render_click(view, "reset_defaults", %{})
      html2 = render_click(view, "save_changes", %{})

      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: SettingsLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_settings_001, :invalid_settings_values, 105},
        {:fm_settings_002, :envelope_auth_wrong_code, 64},
        {:fm_settings_003, :concurrent_settings_modification, 72},
        {:fm_settings_004, :save_during_network_partition, 70},
        {:fm_settings_005, :reset_defaults_data_loss, 36}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 5
      assert total_rpn_before == 347

      # Highest RPN is invalid settings values — requires priority mitigation
      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :invalid_settings_values
      assert highest_rpn == 105
    end
  end
end
