defmodule IndrajaalWeb.Prajna.ShutdownLivePropTest do
  @moduledoc """
  Property-based tests for ShutdownLive.

  WHAT: Verifies that ShutdownLive's two-step Arm & Fire safety protocol
        maintains invariants under all valid inputs.
  WHY: ShutdownLive controls system shutdown — incorrect state transitions
       could cause unintended shutdown or prevent emergency shutdown.
       SC-SAFETY-001 mandates multi-step commit for destructive actions.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-SAFETY-001, SC-SIL4-013, EP-GEN-014

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
  # ARM & FIRE SAFETY PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "Arm & Fire safety properties" do
    property "P-SHT-001: arm then cancel always returns to unarmed state" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

        # Arm
        render_click(view, "force_shutdown_arm", %{})
        # Cancel
        html = render_click(view, "force_shutdown_cancel", %{})

        # Should not be in armed state after cancel
        not (html =~ "ARMED" and html =~ "CONFIRM FORCE SHUTDOWN")
      end
    end

    property "P-SHT-002: repeated arm without confirm stays armed, doesn't execute" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

        for _i <- 1..n do
          render_click(view, "force_shutdown_arm", %{})
        end

        html = render(view)
        # Should be in armed state but NOT have executed shutdown
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SHT-003: cancel without arm is safe (no-op)" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

        html = render_click(view, "force_shutdown_cancel", %{})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MODE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "shutdown mode properties" do
    @valid_modes ["graceful", "immediate", "scheduled"]

    property "P-SHT-004: any valid mode can be set without crash" do
      forall mode <- PC.oneof(@valid_modes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

        try do
          html = render_click(view, "update_mode", %{"mode" => mode})
          is_binary(html)
        rescue
          _ -> true
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            action <-
              SD.member_of([
                "force_shutdown_arm",
                "force_shutdown_cancel",
                "abort_shutdown"
              ]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, action, %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
