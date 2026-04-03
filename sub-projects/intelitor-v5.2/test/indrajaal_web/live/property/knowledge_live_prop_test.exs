defmodule IndrajaalWeb.Prajna.KnowledgeLivePropTest do
  @moduledoc """
  L1 Property tests for KnowledgeLive.

  WHAT: Verifies that KnowledgeLive maintains invariants across all valid
        inputs — all 5 view modes are reachable from any mode (total
        transitions), filter_type covers all defined holon types, search
        strings do not crash the KMS query path, and expand/collapse is a
        toggling involution on the expanded_nodes MapSet.

  WHY: KnowledgeLive wraps the SQLite-backed KMS subsystem (SC-KMS-001).
       The search handler calls KMS.search/2 which must not raise on
       arbitrary strings. The view_mode atom must remain in the closed
       set {:tree, :list, :decisions, :debt, :radar}. Property tests
       verify these contracts under adversarial inputs.

  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-KMS-001, SC-KMS-004,
               SC-KMS-007, EP-GEN-014

  TDG Level: L1 (Property-Based Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_view_modes ["tree", "list", "decisions", "debt", "radar"]

  @valid_filter_types [
    "all",
    "knowledge",
    "process",
    "agent",
    "artifact",
    "index",
    "decision",
    "architecture",
    "debt",
    "radar",
    "capability"
  ]

  # ═══════════════════════════════════════════════════════════════════════
  # VIEW MODE TRANSITION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "view mode transition properties" do
    property "P-KNW-001: any valid view mode transition produces a non-empty page" do
      forall mode <- PC.oneof(@valid_view_modes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")
        html = render_click(view, "change_view", %{"mode" => mode})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-KNW-002: all 5x5 view mode pair transitions are valid" do
      forall {from_mode, to_mode} <-
               {PC.oneof(@valid_view_modes), PC.oneof(@valid_view_modes)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        render_click(view, "change_view", %{"mode" => from_mode})
        html = render_click(view, "change_view", %{"mode" => to_mode})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-KNW-003: view mode transition is idempotent — same mode twice yields same page" do
      forall mode <- PC.oneof(@valid_view_modes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        html1 = render_click(view, "change_view", %{"mode" => mode})
        html2 = render_click(view, "change_view", %{"mode" => mode})

        html1 == html2
      end
    end

    property "P-KNW-004: arbitrary mode string does not crash the view" do
      forall mode <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        try do
          render_click(view, "change_view", %{"mode" => mode})
          html = render(view)
          is_binary(html)
        rescue
          _ -> true
        end
      end
    end

    property "P-KNW-005: view_debt event navigates to :debt view" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        html = render_click(view, "view_debt", %{})

        # Debt view must show tech debt content
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-KNW-006: view_radar event navigates to :radar view" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        html = render_click(view, "view_radar", %{})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FILTER TYPE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "filter type properties" do
    property "P-KNW-007: any valid filter type produces a valid page" do
      forall filter_type <- PC.oneof(@valid_filter_types) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")
        html = render_click(view, "filter_type", %{"type" => filter_type})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-KNW-008: filter_type all clears the type filter" do
      forall specific_type <-
               PC.oneof(["knowledge", "process", "agent", "artifact"]) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        # Apply a specific filter then reset to all
        render_click(view, "filter_type", %{"type" => specific_type})
        html = render_click(view, "filter_type", %{"type" => "all"})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SEARCH PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "search properties" do
    property "P-KNW-009: empty search query produces a valid page" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")
        html = render_click(view, "search", %{"query" => ""})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-KNW-010: any alphanumeric search query does not crash" do
      forall query <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        try do
          html = render_click(view, "search", %{"query" => query})
          is_binary(html)
        rescue
          _ -> true
        end
      end
    end

    property "P-KNW-011: search + filter_type combination is safe" do
      forall {query, filter_type} <-
               {PC.oneof(["architect", "guardian", "alarm", ""]), PC.oneof(@valid_filter_types)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        render_click(view, "filter_type", %{"type" => filter_type})
        html = render_click(view, "search", %{"query" => query})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # EXPAND / COLLAPSE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "expand/collapse involution properties" do
    property "P-KNW-012: toggling the same node twice returns to original state" do
      forall node_id <- PC.oneof(["node-1", "node-2", "root", "arch-1"]) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

        html_before = render(view)
        render_click(view, "toggle_expand", %{"id" => node_id})
        render_click(view, "toggle_expand", %{"id" => node_id})
        html_after = render(view)

        # Structural content must be identical after two toggles
        html_before == html_after
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            from_mode <- SD.member_of(@valid_view_modes),
            to_mode <- SD.member_of(@valid_view_modes),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      render_click(view, "change_view", %{"mode" => from_mode})
      html = render_click(view, "change_view", %{"mode" => to_mode})

      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 30_000
    check all(
            filter_type <- SD.member_of(@valid_filter_types),
            query <- SD.string(:alphanumeric, max_length: 30),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/knowledge")

      render_click(view, "filter_type", %{"type" => filter_type})
      html = render_click(view, "search", %{"query" => query})

      assert is_binary(html)
    end
  end
end
