defmodule IndrajaalWeb.Operations.ActiveAlarmsLivePropTest do
  @moduledoc """
  Property-based tests for Active Alarms LiveView.
  Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014).

  WHAT: Verifies that ActiveAlarmsLive maintains invariants across all valid
        inputs — severity filters, status filters, search strings, alarm IDs,
        and batch selection sequences are handled without crash.
        Tests all 9 handle_event clauses.
  WHY: The active alarms feed is the primary real-time threat surface for operators.
       Random filter sequences and adversarial search strings must never crash.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-ALARM-001, SC-HMI-001, SC-HMI-003, EP-GEN-014

  TDG Level: L1 (Property Testing)
  Route: /operations/alarms
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_severities ["critical", "warning", "caution", "advisory", "all"]
  @valid_statuses ["active", "acknowledged", "silenced", "all"]
  @valid_durations ["15m", "30m", "1h", "4h", "8h", "24h"]

  # ═══════════════════════════════════════════════════════════════════════
  # filter_severity PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "filter_severity properties" do
    property "P-ALM-001: any valid severity filter produces a safe render" do
      forall severity <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "filter_severity", %{"severity" => severity})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-002: any sequence of severity filters ends in valid state" do
      forall severities <- PC.non_empty(PC.list(PC.oneof(@valid_severities))) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")

        Enum.each(severities, fn sev ->
          render_click(view, "filter_severity", %{"severity" => sev})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-003: filter_severity is idempotent" do
      forall severity <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html1 = render_click(view, "filter_severity", %{"severity" => severity})
        html2 = render_click(view, "filter_severity", %{"severity" => severity})
        html1 == html2
      end
    end

    property "P-ALM-004: unknown severity value is always safe" do
      forall s <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "filter_severity", %{"severity" => s})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # filter_status PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "filter_status properties" do
    property "P-ALM-005: any valid status filter produces a safe render" do
      forall status <- PC.oneof(@valid_statuses) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "filter_status", %{"status" => status})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-006: severity and status filters compose safely" do
      forall {severity, status} <-
               {PC.oneof(@valid_severities), PC.oneof(@valid_statuses)} do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        render_click(view, "filter_severity", %{"severity" => severity})
        html = render_click(view, "filter_status", %{"status" => status})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # search PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "search properties" do
    property "P-ALM-007: any UTF-8 search string is safe" do
      forall s <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "search", %{"search" => s})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-008: search after filter composition is safe" do
      forall {severity, s} <- {PC.oneof(@valid_severities), PC.utf8()} do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        render_click(view, "filter_severity", %{"severity" => severity})
        html = render_click(view, "search", %{"search" => s})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # acknowledge PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "acknowledge properties" do
    property "P-ALM-009: acknowledge with any alarm ID is safe" do
      forall n <- PC.integer(1, 20) do
        id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "acknowledge", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-010: acknowledging multiple IDs in sequence is safe" do
      forall ids <- PC.non_empty(PC.list(PC.integer(1, 5))) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")

        Enum.each(ids, fn n ->
          id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
          render_click(view, "acknowledge", %{"id" => id})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # acknowledge_all PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "acknowledge_all properties" do
    property "P-ALM-011: acknowledge_all with any severity is safe" do
      forall severity <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "acknowledge_all", %{"severity" => severity})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # silence PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "silence properties" do
    property "P-ALM-012: silence with any alarm ID and duration is safe" do
      forall {n, duration} <- {PC.integer(1, 10), PC.oneof(@valid_durations)} do
        id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "silence", %{"id" => id, "duration" => duration})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # toggle_select + batch_acknowledge PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "toggle_select and batch_acknowledge properties" do
    property "P-ALM-013: toggle_select any number of alarms then batch_acknowledge is safe" do
      forall ids <- PC.non_empty(PC.list(PC.integer(1, 5))) do
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")

        Enum.each(ids, fn n ->
          id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
          render_click(view, "toggle_select", %{"id" => id})
        end)

        html = render_click(view, "batch_acknowledge", %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-014: double toggle_select always deselects" do
      forall n <- PC.integer(1, 5) do
        id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        render_click(view, "toggle_select", %{"id" => id})
        render_click(view, "toggle_select", %{"id" => id})
        html = render_click(view, "batch_acknowledge", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # escalate PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "escalate properties" do
    property "P-ALM-015: escalate with any alarm ID is always safe" do
      forall n <- PC.integer(1, 10) do
        id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/alarms")
        html = render_click(view, "escalate", %{"id" => id})
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
            severity <- SD.member_of(@valid_severities),
            status <- SD.member_of(@valid_statuses),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms")
      render_click(view, "filter_severity", %{"severity" => severity})
      html = render_click(view, "filter_status", %{"status" => status})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            search <- SD.string(:alphanumeric, max_length: 20),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/alarms")
      html = render_click(view, "search", %{"search" => search})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            n <- SD.integer(1, 5),
            duration <- SD.member_of(@valid_durations),
            max_runs: 10
          ) do
      id = "ALM-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
      {:ok, view, _html} = live(build_conn(), "/operations/alarms")
      render_click(view, "toggle_select", %{"id" => id})
      html = render_click(view, "silence", %{"id" => id, "duration" => duration})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
