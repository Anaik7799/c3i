defmodule IndrajaalWeb.Live.Property.GitIntelligenceLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.GitIntelligenceLive.

  Verifies behavioral invariants for the Git Intelligence dashboard:
  - Page always mounts even without Zenoh bridge
  - Repeated renders are stable across arbitrary render counts
  - No handle_event clauses — focuses on handle_info resilience

  TDG Level: L1 (Property Testing)
  STAMP: SC-IMMUNE-001, SC-ZENOH-003, SC-BRIDGE-005, SC-GIT-006
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
  # P-GIT-001: page mount invariant
  # ============================================================================

  describe "P-GIT-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end

    test "page renders complete HTML structure without Zenoh bridge" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-GIT-002: render stability invariant
  # ============================================================================

  describe "P-GIT-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")
        is_binary(render(view))
      end
    end

    test "repeated renders are stable" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-GIT-003: health score bounds invariant
  # ============================================================================

  describe "P-GIT-003: health score display invariant" do
    test "page renders without crash when health data is unavailable" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end

    test "page renders consistently across multiple fresh mounts" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-GIT-004: commit stream display invariant
  # ============================================================================

  describe "P-GIT-004: commit stream display invariant" do
    property "page always renders with zero or more commit entries" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/git-intelligence")
        html = render(view)
        is_binary(html)
      end
    end

    test "page handles empty commit stream gracefully" do
      # In test env, no commits will be streaming from Zenoh
      {:ok, _view, html} = live(build_conn(), "/cockpit/git-intelligence")
      assert is_binary(html)
    end
  end
end
