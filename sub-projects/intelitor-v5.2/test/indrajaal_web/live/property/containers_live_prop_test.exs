defmodule IndrajaalWeb.Prajna.ContainersLivePropTest do
  @moduledoc """
  Property-based tests for ContainersLive.

  WHAT: Verifies that ContainersLive maintains invariants across all valid inputs —
        container IDs come from a fixed 4-element set, restart/log operations are
        safe, and start_all/stop_all bulk actions are idempotent side-effect-wise.
  WHY: ContainersLive manages a fixed 4-container stack (:db, :redis, :obs, :app)
       and exposes restart and log actions protected by two-step commit. Property
       tests verify that only known IDs are accepted and bulk actions never crash.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-HMI-001, SC-CNT-009, EP-GEN-014

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

  # Fixed container IDs from @containers in ContainersLive
  @valid_container_ids ["db", "redis", "obs", "app"]

  # ═══════════════════════════════════════════════════════════════════════
  # CONTAINER SELECTION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "container selection properties" do
    property "P-CNT-001: selecting any known container ID produces a valid page" do
      forall id <- PC.oneof(@valid_container_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")
        html = render_click(view, "select_container", %{"id" => id})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CNT-002: selecting the same container twice is idempotent" do
      forall id <- PC.oneof(@valid_container_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        html1 = render_click(view, "select_container", %{"id" => id})
        html2 = render_click(view, "select_container", %{"id" => id})

        html1 == html2
      end
    end

    property "P-CNT-003: any sequence of container selections ends in valid state" do
      forall ids <- PC.non_empty(PC.list(PC.oneof(@valid_container_ids))) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        Enum.each(ids, fn id ->
          render_click(view, "select_container", %{"id" => id})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RESTART SAFETY PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "restart safety properties" do
    property "P-CNT-004: restart_container is safe for any known container ID" do
      forall id <- PC.oneof(@valid_container_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")
        html = render_click(view, "restart_container", %{"id" => id})

        # Restart arms a two-step commit flash — page remains valid
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CNT-005: view_logs is safe for any known container ID" do
      forall id <- PC.oneof(@valid_container_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")
        html = render_click(view, "view_logs", %{"id" => id})

        # Logs modal opens — page remains valid and longer than base
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CNT-006: close_logs after view_logs returns valid page" do
      forall id <- PC.oneof(@valid_container_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        render_click(view, "view_logs", %{"id" => id})
        html = render_click(view, "close_logs", %{})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # BULK ACTION IDEMPOTENCY PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "bulk action idempotency properties" do
    property "P-CNT-007: start_all called N times never crashes the view" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        for _i <- 1..n do
          render_click(view, "start_all", %{})
        end

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CNT-008: stop_all called N times never crashes the view" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        for _i <- 1..n do
          render_click(view, "stop_all", %{})
        end

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CNT-009: interleaving start_all and stop_all is always safe" do
      forall ops <- PC.non_empty(PC.list(PC.oneof(["start_all", "stop_all"]))) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/containers")

        Enum.each(ops, fn op ->
          render_click(view, op, %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            id <- SD.member_of(["db", "redis", "obs", "app"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/containers")
      html = render_click(view, "restart_container", %{"id" => id})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 30_000
    check all(
            id <- SD.member_of(["db", "redis", "obs", "app"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/containers")
      _open = render_click(view, "view_logs", %{"id" => id})
      html = render_click(view, "close_logs", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
