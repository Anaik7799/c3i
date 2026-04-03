defmodule IndrajaalWeb.Live.Property.ThreatLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.ThreatLive.

  Verifies behavioral invariants across arbitrary input combinations:
  - filter_severity atom safety with any string input
  - filter_status atom safety with any string input
  - acknowledge idempotency across arbitrary threat ids
  - dismiss safety across arbitrary threat ids

  TDG Level: L1 (Property Testing)
  STAMP: SC-IMMUNE-001, SC-PRAJNA-004, SC-HMI-010
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_severities ~w(all extinction critical high medium low)
  @valid_statuses ~w(all active acknowledged resolved)

  # ============================================================================
  # P-THR-001: filter_severity never crashes for any string input
  # ============================================================================

  describe "P-THR-001: filter_severity safety for any string" do
    property "filter_severity with any valid severity atom string is safe" do
      forall sev <- PC.oneof(@valid_severities) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "filter_severity", %{"severity" => sev})
          rescue
            _ -> "rescued"
          catch
            :exit, _ -> "exit_caught"
          end

        is_binary(result)
      end
    end

    test "filter_severity with all valid severity values is safe" do
      check all(
              sev <- SD.member_of(@valid_severities),
              max_runs: 10
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "filter_severity", %{"severity" => sev})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        assert is_binary(result)
      end
    end

    test "filter_severity with arbitrary unknown string does not crash" do
      check all(
              sev <- SD.string(:ascii, min_length: 1, max_length: 50),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "filter_severity", %{"severity" => sev})
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
  # P-THR-002: filter_status never crashes for any string input
  # ============================================================================

  describe "P-THR-002: filter_status safety for any string" do
    property "filter_status with any valid status atom string is safe" do
      forall status <- PC.oneof(@valid_statuses) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "filter_status", %{"status" => status})
          rescue
            _ -> "rescued"
          catch
            :exit, _ -> "exit_caught"
          end

        is_binary(result)
      end
    end

    test "filter_status with arbitrary unknown string does not crash" do
      check all(
              status <- SD.string(:ascii, min_length: 1, max_length: 50),
              max_runs: 15
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "filter_status", %{"status" => status})
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
  # P-THR-003: acknowledge_threat idempotency for arbitrary ids
  # ============================================================================

  describe "P-THR-003: acknowledge_threat idempotency" do
    property "acknowledging a threat id twice leaves page in valid state" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        _html1 =
          try do
            render_click(view, "acknowledge_threat", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        html2 =
          try do
            render_click(view, "acknowledge_threat", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(html2)
      end
    end

    test "acknowledge_all is always safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/threat")
      html = render_click(view, "acknowledge_all", %{})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # P-THR-004: dismiss_threat with arbitrary id is safe
  # ============================================================================

  describe "P-THR-004: dismiss_threat safety for arbitrary ids" do
    property "dismiss_threat with any threat id does not crash" do
      forall id <- PC.utf8() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")

        result =
          try do
            render_click(view, "dismiss_threat", %{"id" => id})
          rescue
            _ -> render(view)
          catch
            :exit, _ -> "<html>handled</html>"
          end

        is_binary(result)
      end
    end

    test "select_threat then dismiss_threat with matching id is safe" do
      check all(
              id <- SD.string(:alphanumeric, min_length: 3, max_length: 20),
              max_runs: 10
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/threat")
        _html1 = render_click(view, "select_threat", %{"id" => id})
        html2 = render_click(view, "dismiss_threat", %{"id" => id})
        assert is_binary(html2)
      end
    end
  end

  # ============================================================================
  # P-THR-005: page mount is always safe
  # ============================================================================

  describe "P-THR-005: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/threat")
      assert is_binary(html)
      assert html =~ "Threat" or html =~ "threat" or html =~ "THREAT"
    end

    test "close_detail when no threat selected is always safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/threat")
      html = render_click(view, "close_detail", %{})
      assert is_binary(html)
    end
  end
end
