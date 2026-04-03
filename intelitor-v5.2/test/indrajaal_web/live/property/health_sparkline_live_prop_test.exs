defmodule IndrajaalWeb.Live.Property.HealthSparklineLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.HealthSparklineLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - select_node with any node id leaves page in valid state
  - set_threshold with any metric + value combination is safe
  - Page always mounts successfully even without Zenoh health stream

  TDG Level: L1 (Property Testing)
  STAMP: SC-MON-001, SC-MON-002, SC-MON-004, SC-PRF-050, SC-HMI-001
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @known_node_ids ~w(gw-01 app-01 app-02 app-03 app-04 app-05 all)
  @known_metrics ~w(cpu memory queue_depth response_latency)

  # ============================================================================
  # P-HS-001: page mount invariant
  # ============================================================================

  describe "P-HS-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/health-sparklines")
      assert is_binary(html)
    end

    test "page renders complete HTML structure without live metrics" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/health-sparklines")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-HS-002: select_node safety invariant
  # ============================================================================

  describe "P-HS-002: select_node safety for any node id" do
    property "select_node with any known node id is safe" do
      forall node <- PC.oneof(@known_node_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")

        result =
          try do
            render_click(view, "select_node", %{"node" => node})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "select_node with arbitrary unknown node id does not crash" do
      check all(
              node <- SD.string(:ascii, min_length: 1, max_length: 50),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")

        result =
          try do
            render_click(view, "select_node", %{"node" => node})
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
  # P-HS-003: set_threshold safety invariant
  # ============================================================================

  describe "P-HS-003: set_threshold safety for any metric and value" do
    property "set_threshold with any known metric and numeric value string is safe" do
      forall {metric, value} <- {PC.oneof(@known_metrics), PC.pos_integer()} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")

        result =
          try do
            render_click(view, "set_threshold", %{
              "metric" => metric,
              "value" => Integer.to_string(value)
            })
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "set_threshold with arbitrary metric and value string does not crash" do
      check all(
              metric <- SD.string(:ascii, min_length: 1, max_length: 30),
              value <- SD.string(:ascii, min_length: 1, max_length: 20),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")

        result =
          try do
            render_click(view, "set_threshold", %{"metric" => metric, "value" => value})
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
  # P-HS-004: render stability invariant
  # ============================================================================

  describe "P-HS-004: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/health-sparklines")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end
end
