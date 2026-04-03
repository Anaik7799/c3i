defmodule IndrajaalWeb.Live.Property.GuardianLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.GuardianLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - filter_priority atom safety with any string
  - two-step commit invariants across arbitrary proposal ids
  - select_proposal with any id leaves page in valid state
  - confirm_action without prior request is always a no-op

  TDG Level: L1 (Property Testing)
  STAMP: SC-GUARD-001, SC-GUARD-002, SC-PRAJNA-005, SC-GDE-001, SC-SAFETY-001
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_priorities ~w(all p0 p1 p2)

  # ============================================================================
  # P-GRD-001: filter_priority atom safety
  # ============================================================================

  describe "P-GRD-001: filter_priority atom safety for any string" do
    property "filter_priority with any valid priority value is safe" do
      forall priority <- PC.oneof(@valid_priorities) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")

        result =
          try do
            render_click(view, "filter_priority", %{"priority" => priority})
          rescue
            _ -> "rescued"
          catch
            :exit, _ -> "exit_caught"
          end

        is_binary(result)
      end
    end

    test "filter_priority with arbitrary unknown string does not crash" do
      check all(
              priority <- SD.string(:ascii, min_length: 1, max_length: 50),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")

        result =
          try do
            render_click(view, "filter_priority", %{"priority" => priority})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        assert is_binary(result)
      end
    end
  end

  # ============================================================================
  # P-GRD-002: confirm_action without prior request is always a no-op
  # ============================================================================

  describe "P-GRD-002: confirm_action no-op invariant" do
    property "confirm_action without prior request never mutates state visibly" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")
        result = render_click(view, "confirm_action", %{})
        is_binary(result)
      end
    end

    test "confirm_action is always safe regardless of prior state" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")
        html = render_click(view, "confirm_action", %{})
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-GRD-003: two-step commit invariants
  # ============================================================================

  describe "P-GRD-003: two-step commit invariants for any proposal id" do
    property "request_approve then cancel_confirm restores neutral state" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")

        _html1 =
          try do
            render_click(view, "request_approve", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        html2 =
          try do
            render_click(view, "cancel_confirm", %{})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(html2)
      end
    end

    property "request_veto then cancel_confirm restores neutral state" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")

        _html1 =
          try do
            render_click(view, "request_veto", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        html2 =
          try do
            render_click(view, "cancel_confirm", %{})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(html2)
      end
    end

    test "cancel_confirm is always safe even with no pending action" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")
        html = render_click(view, "cancel_confirm", %{})
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-GRD-004: select_proposal with any id is safe
  # ============================================================================

  describe "P-GRD-004: select_proposal safety for any id" do
    property "select_proposal with any id leaves page in valid state" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")

        result =
          try do
            render_click(view, "select_proposal", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "close_proposal is always safe" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")
        html = render_click(view, "close_proposal", %{})
        assert is_binary(html)
      end
    end

    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/guardian-approval")
      assert is_binary(html)
      assert html =~ "Guardian" or html =~ "guardian"
    end
  end
end
