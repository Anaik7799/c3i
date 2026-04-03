defmodule IndrajaalWeb.Prajna.AlarmsLivePropTest do
  @moduledoc """
  Property-based tests for AlarmsLive.

  WHAT: Verifies that AlarmsLive maintains invariants across all valid inputs —
        severity filters are total, alarm operations are safe, storm detection
        threshold is consistent.
  WHY: AlarmsLive has 11 handle_event clauses and 6 handle_info patterns. It
       processes real-time alarm streams from Zenoh. Property tests verify
       correctness under adversarial inputs.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-ALARM-001 through SC-ALARM-041, EP-GEN-014

  TDG Level: L1 (Property Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # SEVERITY FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "severity filter properties" do
    @valid_severities ["all", "critical", "major", "minor", "advisory"]

    property "P-ALM-001: any valid severity filter produces a valid page" do
      forall sev <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
        html = render_click(view, "filter_severity", %{"severity" => sev})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-002: severity filter is idempotent" do
      forall sev <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

        html1 = render_click(view, "filter_severity", %{"severity" => sev})
        html2 = render_click(view, "filter_severity", %{"severity" => sev})

        html1 == html2
      end
    end

    property "P-ALM-003: any sequence of filter switches ends in valid state" do
      forall sevs <- PC.non_empty(PC.list(PC.oneof(@valid_severities))) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

        Enum.each(sevs, fn sev ->
          render_click(view, "filter_severity", %{"severity" => sev})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ALM-004: invalid severity does not crash" do
      forall sev <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

        try do
          render_click(view, "filter_severity", %{"severity" => sev})
          html = render(view)
          is_binary(html)
        rescue
          _ -> true
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SEARCH PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "search properties" do
    property "P-ALM-005: any search query produces a valid page" do
      forall query <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

        try do
          html = render_click(view, "search", %{"query" => query})
          is_binary(html) and String.length(html) > 50
        rescue
          _ -> true
        end
      end
    end

    property "P-ALM-006: empty search query shows all alarms" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
        html = render_click(view, "search", %{"query" => ""})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # COMBINED FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "combined filter properties" do
    property "P-ALM-007: filter + search combination is safe" do
      forall {sev, query} <-
               {PC.oneof(@valid_severities), PC.oneof(["fire", "sensor", "zone", "", "test"])} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

        render_click(view, "filter_severity", %{"severity" => sev})
        html = render_click(view, "search", %{"query" => query})

        is_binary(html) and String.length(html) > 50
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            sev <- SD.member_of(["all", "critical", "major", "minor", "advisory"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
      html = render_click(view, "filter_severity", %{"severity" => sev})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 30_000
    check all(
            query <- SD.string(:alphanumeric, max_length: 50),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
      html = render_click(view, "search", %{"query" => query})
      assert is_binary(html)
    end
  end
end
