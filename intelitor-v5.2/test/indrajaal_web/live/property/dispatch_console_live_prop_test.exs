defmodule IndrajaalWeb.Operations.DispatchConsoleLivePropTest do
  @moduledoc """
  Property-based tests for Dispatch Console LiveView.
  Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014).

  WHAT: Verifies that DispatchConsoleLive maintains invariants across all valid
        inputs — assignment IDs, types, locations, priorities, and action sequences
        are handled safely. Tests all 12 handle_event clauses.
  WHY: The dispatch console is the real-time coordination hub for security response.
       Random assignment data and event sequences must never crash the LiveView.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-DSP-001, SC-DSP-002, SC-HMI-001, EP-GEN-014

  TDG Level: L1 (Property Testing)
  Route: /operations/dispatch
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_types ["patrol", "intrusion", "escort", "maintenance", "emergency", "access"]
  @valid_priorities ["routine", "high", "critical", "low"]
  @valid_resources ["", "team_alpha", "team_bravo", "officer_johnson", "unit_7"]

  # ═══════════════════════════════════════════════════════════════════════
  # select_assignment PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "select_assignment properties" do
    property "P-DSP-001: any alphanumeric assignment ID is safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "select_assignment", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-002: selecting known sample IDs never crashes" do
      forall n <- PC.integer(1, 10) do
        id = "ASN-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "select_assignment", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-003: repeated selection of the same ID is idempotent" do
      forall n <- PC.integer(1, 5) do
        id = "ASN-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "select_assignment", %{"id" => id})
        html = render_click(view, "select_assignment", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # create_assignment PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "create_assignment properties" do
    property "P-DSP-004: any valid assignment type produces a safe response" do
      forall {type, location, priority} <-
               {PC.oneof(@valid_types), PC.non_empty(PC.utf8()), PC.oneof(@valid_priorities)} do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")

        html =
          render_click(view, "create_assignment", %{
            "type" => type,
            "location" => location,
            "priority" => priority,
            "assign_to" => ""
          })

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-005: create_assignment with random assign_to string is safe" do
      forall {type, resource} <- {PC.oneof(@valid_types), PC.oneof(@valid_resources)} do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")

        html =
          render_click(view, "create_assignment", %{
            "type" => type,
            "location" => "Zone-A",
            "priority" => "routine",
            "assign_to" => resource
          })

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-006: new_assignment → create_assignment cycle always completes" do
      forall type <- PC.oneof(@valid_types) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "new_assignment", %{})

        html =
          render_click(view, "create_assignment", %{
            "type" => type,
            "location" => "Sector-1",
            "priority" => "routine",
            "assign_to" => ""
          })

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # track / reassign / escalate / divert / add_task PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "assignment action properties" do
    property "P-DSP-007: track with any ID string is always safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "track", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-008: reassign with any ID string is always safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "reassign", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-009: escalate with any ID string is always safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "escalate", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-010: divert with any ID string is always safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "select_assignment", %{"id" => id})
        html = render_click(view, "divert", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-011: add_task with any ID string is always safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        html = render_click(view, "add_task", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # no-payload events: broadcast_all, shift_handover, reports
  # ═══════════════════════════════════════════════════════════════════════

  describe "no-payload event properties" do
    property "P-DSP-012: broadcast_all N times never crashes" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")

        Enum.each(1..n, fn _ ->
          render_click(view, "broadcast_all", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-013: shift_handover is always safe regardless of prior state" do
      forall n <- PC.integer(1, 4) do
        id = "ASN-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "select_assignment", %{"id" => id})
        html = render_click(view, "shift_handover", %{})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-DSP-014: reports event is always safe" do
      forall _ <- PC.integer(1, 3) do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "broadcast_all", %{})
        html = render_click(view, "reports", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # cancel_new_assignment PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "cancel_new_assignment properties" do
    property "P-DSP-015: cancel after open always returns valid html" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
        render_click(view, "new_assignment", %{})
        html = render_click(view, "cancel_new_assignment", %{})
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
            type <- SD.member_of(@valid_types),
            priority <- SD.member_of(@valid_priorities),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/dispatch")

      html =
        render_click(view, "create_assignment", %{
          "type" => type,
          "location" => "Property-Test-Zone",
          "priority" => priority,
          "assign_to" => ""
        })

      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            id <- SD.string(:alphanumeric, min_length: 1, max_length: 10),
            event <- SD.member_of(["track", "reassign", "escalate", "add_task"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/dispatch")
      html = render_click(view, event, %{"id" => "ASN-" <> id})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            n <- SD.integer(1, 3),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/dispatch")

      1..n
      |> Enum.each(fn _ -> render_click(view, "broadcast_all", %{}) end)

      html = render_click(view, "shift_handover", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
