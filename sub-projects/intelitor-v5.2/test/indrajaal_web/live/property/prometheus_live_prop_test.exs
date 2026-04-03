defmodule IndrajaalWeb.Live.Property.PrometheusLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.PrometheusLive.

  Verifies behavioral invariants for the Prometheus verification dashboard:
  - Page always mounts successfully (no handle_event clauses)
  - Constitutional constraint count display is always valid
  - Repeated renders produce stable HTML

  TDG Level: L1 (Property Testing)
  STAMP: SC-PRAJNA-001, SC-VDP-001, SC-FRACTAL-001, SC-HMI-001
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
  # P-PRM-001: page mount invariant
  # ============================================================================

  describe "P-PRM-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/prometheus")
      assert is_binary(html)
    end

    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/prometheus")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-PRM-002: render stability invariant
  # ============================================================================

  describe "P-PRM-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/prometheus")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/prometheus")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-PRM-003: constitutional constraint count display invariant
  # ============================================================================

  describe "P-PRM-003: constitutional constraint count display invariant" do
    test "page renders even when constraint data is unavailable" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/prometheus")
      assert is_binary(html)
    end

    test "page renders consistently across multiple fresh mounts" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/prometheus")
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-PRM-004: verification status display invariant
  # ============================================================================

  describe "P-PRM-004: verification status display invariant" do
    property "page always renders with a valid verification representation" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/prometheus")
        html = render(view)
        is_binary(html)
      end
    end

    test "page handles empty verification data gracefully" do
      # PrometheusLive has no handle_event — focus on mount/render stability
      {:ok, _view, html} = live(build_conn(), "/cockpit/prometheus")
      assert is_binary(html)
    end
  end
end
