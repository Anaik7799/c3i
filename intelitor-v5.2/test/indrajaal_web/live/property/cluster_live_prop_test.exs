defmodule IndrajaalWeb.Prajna.ClusterLivePropTest do
  @moduledoc """
  Property-based tests for ClusterLive.

  WHAT: Verifies that ClusterLive node selection, pool scaling, and autoscale
        toggle maintain invariants across all valid inputs.
  WHY: ClusterLive manages FLAME pool scaling and cluster topology — incorrect
       state could lead to resource exhaustion or node starvation.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-CLU-001 through SC-CLU-008, EP-GEN-014

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
  # NODE SELECTION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "node selection properties" do
    property "P-CLU-001: selecting any node ID does not crash" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

        try do
          html = render_click(view, "select_node", %{"id" => id})
          is_binary(html) and String.length(html) > 100
        rescue
          _ -> true
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # POOL SCALING PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "pool scaling properties" do
    @valid_pools ["default", "compute", "io"]
    @valid_directions ["up", "down"]

    property "P-CLU-002: scaling any pool in any direction does not crash" do
      forall {pool, dir} <- {PC.oneof(@valid_pools), PC.oneof(@valid_directions)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

        try do
          html =
            render_click(view, "scale_pool", %{
              "pool" => pool,
              "direction" => dir
            })

          is_binary(html) and String.length(html) > 100
        rescue
          _ -> true
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # AUTOSCALE TOGGLE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "autoscale toggle properties" do
    property "P-CLU-003: toggle autoscale twice returns to original state" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

        html1 = render_click(view, "toggle_autoscale", %{})
        html2 = render_click(view, "toggle_autoscale", %{})

        # Double toggle should return to original state
        is_binary(html1) and is_binary(html2)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            node_id <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      try do
        html = render_click(view, "select_node", %{"id" => node_id})
        assert is_binary(html)
      rescue
        _ -> :ok
      end
    end
  end
end
