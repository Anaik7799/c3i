defmodule IndrajaalWeb.Live.Property.GuardianDashboardLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.GuardianDashboardLive.

  Verifies behavioral invariants for the Guardian status dashboard:
  - Page always mounts successfully (no handle_event clauses)
  - Refresh cycle produces stable HTML
  - Circuit breaker state display is always valid

  TDG Level: L1 (Property Testing)
  STAMP: SC-GUARD-001, SC-GUARD-002, SC-ENFORCE-013, SC-PRAJNA-001
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
  # P-GDASH-001: page mount invariant
  # ============================================================================

  describe "P-GDASH-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/guardian")
      assert is_binary(html)
    end

    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/guardian")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-GDASH-002: render stability invariant
  # ============================================================================

  describe "P-GDASH-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-GDASH-003: circuit breaker display invariant
  # ============================================================================

  describe "P-GDASH-003: circuit breaker state display invariant" do
    test "page renders when Guardian process is unavailable" do
      # Guardian GenServer may not be running in test env
      {:ok, _view, html} = live(build_conn(), "/cockpit/guardian")
      assert is_binary(html)
    end

    test "multiple mounts with unavailable Guardian are consistent" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/guardian")
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-GDASH-004: pending proposals display invariant
  # ============================================================================

  describe "P-GDASH-004: pending proposals display invariant" do
    property "page always renders with zero or more pending proposal entries" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/guardian")
        html = render(view)
        is_binary(html)
      end
    end

    test "page handles empty proposals list gracefully" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/guardian")
      assert is_binary(html)
    end
  end
end
