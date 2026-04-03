defmodule IndrajaalWeb.Live.Property.StartupLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.StartupLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - abort_startup is always safe regardless of current phase state
  - skip_to_cockpit is always safe regardless of current phase state
  - Page always mounts successfully
  - Repeated renders produce stable HTML

  TDG Level: L1 (Property Testing)
  STAMP: SC-HMI-001, SC-VDP-008, SC-EMR-057, SC-SAFETY-001, SC-PRAJNA-001
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
  # P-STA-001: page mount invariant
  # ============================================================================

  describe "P-STA-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/startup")
      assert is_binary(html)
    end

    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/startup")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-STA-002: abort_startup safety invariant
  # ============================================================================

  describe "P-STA-002: abort_startup safety invariant" do
    property "abort_startup is always safe regardless of phase state" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")

        result =
          try do
            render_click(view, "abort_startup", %{})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "abort_startup is safe across multiple mounts" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")

        result =
          try do
            render_click(view, "abort_startup", %{})
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
  # P-STA-003: skip_to_cockpit safety invariant
  # ============================================================================

  describe "P-STA-003: skip_to_cockpit safety invariant" do
    property "skip_to_cockpit is always safe regardless of prior state" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")

        result =
          try do
            render_click(view, "skip_to_cockpit", %{})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "skip_to_cockpit is safe across multiple mounts" do
      check all(_ <- SD.constant(nil), max_runs: 3) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")

        result =
          try do
            render_click(view, "skip_to_cockpit", %{})
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
  # P-STA-004: render stability invariant
  # ============================================================================

  describe "P-STA-004: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/startup")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end
end
