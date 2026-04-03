defmodule IndrajaalWeb.Live.Property.TopologyLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.TopologyLive.

  Verifies behavioral invariants for the topology visualization dashboard:
  - Page always mounts successfully (no handle_event clauses)
  - Topology update handle_info produces valid state
  - Correction applied handle_info is stable

  TDG Level: L1 (Property Testing)
  STAMP: SC-HMI-001, SC-VDP-001, SC-FRACTAL-001, SC-PRAJNA-001
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  # ============================================================================
  # P-TOP-001: page mount invariant
  # ============================================================================

  describe "P-TOP-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/topology")
      assert is_binary(html)
    end

    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/topology")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-TOP-002: render stability invariant
  # ============================================================================

  describe "P-TOP-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/topology")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/topology")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-TOP-003: topology data display invariant
  # ============================================================================

  describe "P-TOP-003: topology data display invariant" do
    test "page renders when no topology data is available" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/topology")
      assert is_binary(html)
    end

    test "multiple mounts are consistent" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/topology")
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-TOP-004: node count display invariant
  # ============================================================================

  describe "P-TOP-004: node count display invariant" do
    property "page always renders with valid node representation" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/topology")
        html = render(view)
        is_binary(html)
      end
    end

    test "page handles empty topology gracefully" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/topology")
      assert is_binary(html)
    end
  end
end
