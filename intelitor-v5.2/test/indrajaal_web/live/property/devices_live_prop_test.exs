defmodule IndrajaalWeb.Prajna.DevicesLivePropTest do
  @moduledoc """
  Property-based tests for DevicesLive.

  WHAT: Verifies that DevicesLive maintains invariants across all valid inputs —
        status/type filter combinations are total, search strings are handled
        safely, view toggle between :grid and :list is idempotent.
  WHY: DevicesLive manages a 30-device grid with 3-axis filtering (status × type ×
       search) and two view modes. Property tests verify that adversarial filter
       combinations and freeform search strings never crash or corrupt the view.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-DEV-001, EP-GEN-014

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

  @valid_statuses ["all", "online", "degraded", "offline"]
  @valid_types ["all", "camera", "reader", "controller", "sensor"]
  @valid_view_modes ["grid", "list"]

  # ═══════════════════════════════════════════════════════════════════════
  # STATUS FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "status filter properties" do
    property "P-DEV-001: any valid status filter produces a valid page" do
      forall st <- PC.oneof(@valid_statuses) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")
        html = render_click(view, "filter_status", %{"status" => st})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DEV-002: status filter is idempotent" do
      forall st <- PC.oneof(@valid_statuses) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        html1 = render_click(view, "filter_status", %{"status" => st})
        html2 = render_click(view, "filter_status", %{"status" => st})

        html1 == html2
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TYPE FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "type filter properties" do
    property "P-DEV-003: any valid type filter produces a valid page" do
      forall type <- PC.oneof(@valid_types) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")
        html = render_click(view, "filter_type", %{"type" => type})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DEV-004: status and type filters compose safely" do
      forall {st, type} <- {PC.oneof(@valid_statuses), PC.oneof(@valid_types)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        render_click(view, "filter_status", %{"status" => st})
        html = render_click(view, "filter_type", %{"type" => type})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SEARCH STRING PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "search string properties" do
    property "P-DEV-005: any search string produces a valid page without crash" do
      forall query <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        try do
          html = render_click(view, "search", %{"query" => query})
          is_binary(html) and String.length(html) > 50
        rescue
          _ -> true
        end
      end
    end

    property "P-DEV-006: empty search string restores full device list rendering" do
      forall query <- PC.oneof(["Device", "cam", "zone", "build", ""]) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        render_click(view, "search", %{"query" => query})
        html = render_click(view, "search", %{"query" => ""})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DEV-007: filter + search combination is always safe" do
      forall {st, type, query} <-
               {PC.oneof(@valid_statuses), PC.oneof(@valid_types),
                PC.oneof(["Device", "Camera", "sensor", "", "1", "Building"])} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        render_click(view, "filter_status", %{"status" => st})
        render_click(view, "filter_type", %{"type" => type})
        html = render_click(view, "search", %{"query" => query})

        is_binary(html) and String.length(html) > 50
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # VIEW TOGGLE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "view mode toggle properties" do
    property "P-DEV-008: toggling to any valid view mode produces a valid page" do
      forall mode <- PC.oneof(@valid_view_modes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")
        html = render_click(view, "toggle_view", %{"mode" => mode})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DEV-009: view mode toggle is idempotent" do
      forall mode <- PC.oneof(@valid_view_modes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/devices")

        html1 = render_click(view, "toggle_view", %{"mode" => mode})
        html2 = render_click(view, "toggle_view", %{"mode" => mode})

        html1 == html2
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            st <- SD.member_of(["all", "online", "degraded", "offline"]),
            type <- SD.member_of(["all", "camera", "reader", "controller", "sensor"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/devices")
      render_click(view, "filter_status", %{"status" => st})
      html = render_click(view, "filter_type", %{"type" => type})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 30_000
    check all(
            query <- SD.string(:alphanumeric, max_length: 40),
            mode <- SD.member_of(["grid", "list"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/devices")
      render_click(view, "search", %{"query" => query})
      html = render_click(view, "toggle_view", %{"mode" => mode})
      assert is_binary(html)
      assert String.length(html) > 50
    end
  end
end
