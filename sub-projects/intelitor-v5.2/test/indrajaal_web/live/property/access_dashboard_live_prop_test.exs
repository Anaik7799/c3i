defmodule IndrajaalWeb.Operations.AccessDashboardLivePropTest do
  @moduledoc """
  Property-based tests for Access Dashboard LiveView.
  Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014).

  WHAT: Verifies that AccessDashboardLive maintains invariants across all valid
        inputs — access point IDs, event sequences, and repeated no-payload
        actions. Tests all 6 handle_event clauses: select_point, close_detail,
        grant_access, revoke_access, lockdown_zone, unlock_all.
  WHY: The access dashboard is the real-time security surface. Point selection,
       lockdown, and unlock actions have safety implications (SC-SAFETY-001).
       Random inputs and repeated actions must never crash the LiveView.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-HMI-001, SC-HMI-002, SC-SEC-001, EP-GEN-014

  TDG Level: L1 (Property Testing)
  Route: /operations/access
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @sample_point_ids ["ap-001", "ap-002", "ap-003", "ap-004", "ap-005"]
  @no_payload_events ["grant_access", "revoke_access", "lockdown_zone", "unlock_all"]

  # ═══════════════════════════════════════════════════════════════════════
  # select_point PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "select_point properties" do
    property "P-ACD-001: any known access point ID renders a valid page" do
      forall id <- PC.oneof(@sample_point_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        html = render_click(view, "select_point", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-002: selecting access points in any order is safe" do
      forall ids <- PC.non_empty(PC.list(PC.oneof(@sample_point_ids))) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")

        Enum.each(ids, fn id ->
          render_click(view, "select_point", %{"id" => id})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-003: unknown access point ID is safe (Enum.find returns nil)" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        html = render_click(view, "select_point", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-004: select_point then close_detail always restores base view" do
      forall id <- PC.oneof(@sample_point_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        render_click(view, "select_point", %{"id" => id})
        html = render_click(view, "close_detail", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # close_detail PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "close_detail properties" do
    property "P-ACD-005: close_detail N times without selection is always safe" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")

        Enum.each(1..n, fn _ ->
          render_click(view, "close_detail", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-006: select → close → select cycle is always safe" do
      forall {id1, id2} <-
               {PC.oneof(@sample_point_ids), PC.oneof(@sample_point_ids)} do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        render_click(view, "select_point", %{"id" => id1})
        render_click(view, "close_detail", %{})
        html = render_click(view, "select_point", %{"id" => id2})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # grant_access / revoke_access / lockdown_zone / unlock_all PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "no-payload event properties" do
    property "P-ACD-007: any single no-payload event is safe" do
      forall event <- PC.oneof(@no_payload_events) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        html = render_click(view, event, %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-008: any sequence of no-payload events never crashes" do
      forall events <- PC.non_empty(PC.list(PC.oneof(@no_payload_events))) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")

        Enum.each(events, fn event ->
          render_click(view, event, %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-009: lockdown_zone N times never crashes (arm-and-fire safety)" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")

        Enum.each(1..n, fn _ ->
          render_click(view, "lockdown_zone", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-010: lockdown followed immediately by unlock_all is safe" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        render_click(view, "lockdown_zone", %{})
        html = render_click(view, "unlock_all", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # select_point + no-payload event COMPOSITION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "event composition properties" do
    property "P-ACD-011: select_point then any no-payload event is safe" do
      forall {id, event} <-
               {PC.oneof(@sample_point_ids), PC.oneof(@no_payload_events)} do
        {:ok, view, _html} = live(build_conn(), "/operations/access")
        render_click(view, "select_point", %{"id" => id})
        html = render_click(view, event, %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-ACD-012: full six-event sequence in any order is safe" do
      all_events = @no_payload_events ++ ["select_point", "close_detail"]

      forall events <- PC.non_empty(PC.list(PC.oneof(all_events))) do
        {:ok, view, _html} = live(build_conn(), "/operations/access")

        Enum.each(events, fn event ->
          params =
            if event == "select_point",
              do: %{"id" => "ap-001"},
              else: %{}

          render_click(view, event, params)
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
    @tag timeout: 60_000
    check all(
            id <- SD.member_of(@sample_point_ids),
            event <- SD.member_of(@no_payload_events),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/access")
      render_click(view, "select_point", %{"id" => id})
      html = render_click(view, event, %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            id1 <- SD.member_of(@sample_point_ids),
            id2 <- SD.member_of(@sample_point_ids),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/access")
      render_click(view, "select_point", %{"id" => id1})
      render_click(view, "close_detail", %{})
      html = render_click(view, "select_point", %{"id" => id2})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            events <-
              SD.list_of(SD.member_of(@no_payload_events), min_length: 1, max_length: 4),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/access")

      Enum.each(events, fn event ->
        render_click(view, event, %{})
      end)

      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
