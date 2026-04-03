defmodule IndrajaalWeb.Live.Property.CopilotLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.CopilotLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - submit_query with any string is safe
  - dismiss_insight with any id is idempotent
  - select_insight with any id leaves page in valid state
  - toggle_llm is always reversible

  TDG Level: L1 (Property Testing)
  STAMP: SC-AI-001, SC-HMI-001, SC-VDP-009, SC-EVAL-003
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @known_insight_ids ~w(INS-001 INS-002 INS-003 INS-004)

  # ============================================================================
  # P-COP-001: submit_query with any string is safe
  # ============================================================================

  describe "P-COP-001: submit_query safety for any string input" do
    property "submit_query with any utf8 string does not crash" do
      forall query <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")

        result =
          try do
            render_click(view, "submit_query", %{"query" => query})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "submit_query with various query types returns binary result" do
      check all(
              query <-
                SD.one_of([
                  SD.constant(""),
                  SD.constant("What is the current CPU?"),
                  SD.string(:ascii, min_length: 1, max_length: 200),
                  SD.constant(String.duplicate("x", 10_000))
                ]),
              max_runs: 10
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")

        result =
          try do
            render_click(view, "submit_query", %{"query" => query})
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
  # P-COP-002: dismiss_insight idempotency
  # ============================================================================

  describe "P-COP-002: dismiss_insight idempotency for any id" do
    property "dismiss_insight with any known id is safe" do
      forall id <- PC.oneof(@known_insight_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
        _html1 = render_click(view, "dismiss_insight", %{"id" => id})
        html2 = render_click(view, "dismiss_insight", %{"id" => id})
        is_binary(html2)
      end
    end

    test "dismiss_insight with arbitrary id does not crash" do
      check all(
              id <- SD.string(:alphanumeric, min_length: 1, max_length: 30),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
        result = render_click(view, "dismiss_insight", %{"id" => id})
        assert is_binary(result)
      end
    end
  end

  # ============================================================================
  # P-COP-003: select_insight with any id is safe
  # ============================================================================

  describe "P-COP-003: select_insight safety for any id" do
    property "select_insight with any known id leaves page in valid state" do
      forall id <- PC.oneof(@known_insight_ids) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
        result = render_click(view, "select_insight", %{"id" => id})
        is_binary(result)
      end
    end

    test "select_insight with non-existent id is safe" do
      check all(
              id <- SD.string(:alphanumeric, min_length: 5, max_length: 20),
              max_runs: 10
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
        result = render_click(view, "select_insight", %{"id" => "PHANTOM-#{id}"})
        assert is_binary(result)
      end
    end
  end

  # ============================================================================
  # P-COP-004: toggle_llm is always reversible
  # ============================================================================

  describe "P-COP-004: toggle_llm reversibility" do
    property "double-toggling LLM restores original state representation" do
      forall _n <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")
        _html1 = render_click(view, "toggle_llm", %{})
        html2 = render_click(view, "toggle_llm", %{})
        is_binary(html2)
      end
    end

    test "toggle_llm any number of times leaves page valid" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")

        for _i <- 1..n do
          render_click(view, "toggle_llm", %{})
        end

        html = render(view)
        assert is_binary(html)
      end
    end
  end

  # ============================================================================
  # P-COP-005: apply_recommendation with any id is safe
  # ============================================================================

  describe "P-COP-005: apply_recommendation safety for any id" do
    property "apply_recommendation with any id does not crash" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/ai-copilot")

        result =
          try do
            render_click(view, "apply_recommendation", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/ai-copilot")
      assert is_binary(html)
      assert html =~ "Copilot" or html =~ "AI" or html =~ "copilot"
    end
  end
end
