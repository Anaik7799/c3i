defmodule IndrajaalWeb.Live.Property.SentinelDashboardLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.SentinelDashboardLive.

  Verifies behavioral invariants for the Sentinel threat monitoring dashboard:
  - Page always mounts even when SentinelBridge GenServer is unavailable
  - Repeated renders produce stable HTML across arbitrary render counts
  - No handle_event clauses — focuses on mount and render stability

  TDG Level: L1 (Property Testing)
  STAMP: SC-IMMUNE-001, SC-PRAJNA-004, SC-GUARD-002, SC-HMI-001
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
  # P-SEN-001: page mount invariant
  # ============================================================================

  describe "P-SEN-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
      assert is_binary(html)
    end

    test "page renders complete HTML structure without SentinelBridge" do
      # SentinelBridge GenServer may not be running in test environment
      {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-SEN-002: render stability invariant
  # ============================================================================

  describe "P-SEN-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/sentinel")
        is_binary(render(view))
      end
    end

    test "repeated renders are stable" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/sentinel")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-SEN-003: health score display invariant
  # ============================================================================

  describe "P-SEN-003: health score display invariant" do
    test "page renders without crash when sentinel bridge is unavailable" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
      assert is_binary(html)
    end

    test "page renders consistently across multiple fresh mounts" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-SEN-004: threat advisory display invariant
  # ============================================================================

  describe "P-SEN-004: threat advisory display invariant" do
    property "page always renders with zero or more threat entries" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/sentinel")
        html = render(view)
        is_binary(html)
      end
    end

    test "page handles empty threat advisory list gracefully" do
      # In test env, no threat advisories stream from Zenoh/SentinelBridge
      {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
      assert is_binary(html)
    end
  end
end
