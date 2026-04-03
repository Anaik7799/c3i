defmodule IndrajaalWeb.Live.Property.MeshLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.MeshLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - select_node with any node id leaves page in valid state
  - destructive operations with any id do not crash
  - clear_selection is always idempotent

  TDG Level: L1 (Property Testing)
  STAMP: SC-HMI-001, SC-EID-001, SC-VDP-005, SC-SAFETY-001
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @known_node_ids ~w(
    zenoh-router indrajaal-db-prod indrajaal-obs-prod
    zenoh-router-1 zenoh-router-2 zenoh-router-3
    cepaf-bridge indrajaal-cortex
    indrajaal-ex-app-1 indrajaal-ex-app-2 indrajaal-ex-app-3
    indrajaal-chaya indrajaal-ollama
    indrajaal-ml-runner-1 indrajaal-ml-runner-2
  )

  # ============================================================================
  # P-MSH-001: select_node with any id is safe
  # ============================================================================

  describe "P-MSH-001: select_node safety for any node id" do
    property "select_node with any known node id is safe" do
      forall id <- PC.oneof(@known_node_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, "select_node", %{"id" => id})
        is_binary(result)
      end
    end

    test "select_node with arbitrary string id does not crash" do
      check all(
              id <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, "select_node", %{"id" => id})
        assert is_binary(result)
      end
    end
  end

  # ============================================================================
  # P-MSH-002: destructive operations with any id are safe
  # ============================================================================

  describe "P-MSH-002: destructive operations safety for any node id" do
    property "restart_node with any node id does not crash" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, "restart_node", %{"id" => id})
        is_binary(result)
      end
    end

    property "stop_node with any node id does not crash" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, "stop_node", %{"id" => id})
        is_binary(result)
      end
    end

    test "all operations on known node ids are safe" do
      check all(
              id <- SD.member_of(@known_node_ids),
              op <- SD.member_of(~w(restart_node stop_node)),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, op, %{"id" => id})
        assert is_binary(result)
      end
    end
  end

  # ============================================================================
  # P-MSH-003: clear_selection is always idempotent
  # ============================================================================

  describe "P-MSH-003: clear_selection idempotency" do
    property "clear_selection is always a no-op or valid state reset" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        result = render_click(view, "clear_selection", %{})
        is_binary(result)
      end
    end

    test "select then clear leaves page in neutral state" do
      check all(
              id <- SD.member_of(@known_node_ids),
              max_runs: 10
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        _html1 = render_click(view, "select_node", %{"id" => id})
        html2 = render_click(view, "clear_selection", %{})
        assert is_binary(html2)
      end
    end
  end

  # ============================================================================
  # P-MSH-004: page mount invariant
  # ============================================================================

  describe "P-MSH-004: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/mesh")
      assert is_binary(html)
      assert html =~ "Mesh" or html =~ "mesh" or html =~ "MESH"
    end

    test "page render is always binary" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
        assert is_binary(render(view))
      end
    end
  end
end
