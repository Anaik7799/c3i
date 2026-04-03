defmodule IndrajaalWeb.Operations.AlarmInvestigationLivePropTest do
  @moduledoc """
  Property-based tests for Alarm Investigation LiveView.
  Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014).

  WHAT: Verifies that AlarmInvestigationLive maintains invariants across all valid
        inputs — arbitrary alarm IDs in the URL, random note content, and any
        ordering of the 7 handle_event clauses: verify, false_alarm, escalate,
        close, add_note, play_video, export_clip.
  WHY: The investigation view drives forensic workflows. Status transitions and
       evidence capture must be resilient to arbitrary operator input sequences.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-HMI-001, SC-HMI-004, SC-ALARM-001, EP-GEN-014

  TDG Level: L1 (Property Testing)
  Route: /operations/alarms/:id
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @status_events ["verify", "false_alarm", "escalate", "close"]
  @sample_alarm_ids ["ALM-001", "ALM-002", "ALM-003", "ALM-004", "ALM-005"]

  # ═══════════════════════════════════════════════════════════════════════
  # URL alarm ID PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "alarm ID URL properties" do
    property "P-INV-001: any alphanumeric alarm ID in URL mounts safely" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, _view, html} = live(build_conn(), "/operations/alarms/#{URI.encode(id)}")
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-002: sample alarm IDs all mount and render correctly" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, _view, html} = live(build_conn(), "/operations/alarms/#{id}")
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-003: numeric-style alarm IDs mount safely" do
      forall n <- PC.integer(1, 9999) do
        {:ok, _view, html} = live(build_conn(), "/operations/alarms/#{n}")
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # verify PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "verify properties" do
    property "P-INV-004: verify on any alarm ID is safe" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        html = render_click(view, "verify", %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-005: verify is idempotent (calling twice stays safe)" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        render_click(view, "verify", %{})
        html = render_click(view, "verify", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # false_alarm / escalate / close PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "status transition properties" do
    property "P-INV-006: any single status event on any alarm ID is safe" do
      forall {id, event} <-
               {PC.oneof(@sample_alarm_ids), PC.oneof(@status_events)} do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        html = render_click(view, event, %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-007: any two-step status transition is safe" do
      forall {id, e1, e2} <-
               {PC.oneof(@sample_alarm_ids), PC.oneof(@status_events), PC.oneof(@status_events)} do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        render_click(view, e1, %{})
        html = render_click(view, e2, %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # add_note PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "add_note properties" do
    property "P-INV-008: add_note with any UTF-8 content is safe" do
      forall note <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/ALM-001")
        html = render_click(view, "add_note", %{"note" => note})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-009: multiple sequential notes never crash" do
      forall notes <- PC.non_empty(PC.list(PC.utf8())) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/ALM-001")

        Enum.each(notes, fn note ->
          render_click(view, "add_note", %{"note" => note})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-010: add_note then status transition is always safe" do
      forall {note, event} <- {PC.utf8(), PC.oneof(@status_events)} do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/ALM-001")
        render_click(view, "add_note", %{"note" => note})
        html = render_click(view, event, %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # play_video / export_clip PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "video properties" do
    property "P-INV-011: play_video on any alarm is always safe" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        html = render_click(view, "play_video", %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-012: export_clip on any alarm is always safe" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        html = render_click(view, "export_clip", %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-INV-013: play_video then export_clip sequence is always safe" do
      forall id <- PC.oneof(@sample_alarm_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
        render_click(view, "play_video", %{})
        html = render_click(view, "export_clip", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 60_000
    check all(
            id <- SD.member_of(@sample_alarm_ids),
            event <- SD.member_of(@status_events),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
      html = render_click(view, event, %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            note <- SD.string(:alphanumeric, max_length: 100),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/ALM-001")
      render_click(view, "add_note", %{"note" => note})
      html = render_click(view, "play_video", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            id <- SD.member_of(@sample_alarm_ids),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms/#{id}")
      render_click(view, "play_video", %{})
      render_click(view, "export_clip", %{})
      html = render_click(view, "verify", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
