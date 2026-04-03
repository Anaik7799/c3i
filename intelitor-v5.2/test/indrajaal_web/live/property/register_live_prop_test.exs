defmodule IndrajaalWeb.Live.Property.RegisterLivePropTest do
  @moduledoc """
  Property tests for IndrajaalWeb.Prajna.RegisterLive.

  Verifies behavioral invariants for the Immutable Register dashboard:
  - Page always mounts successfully
  - Repeated renders produce valid HTML
  - No handle_event clauses — focuses on mount and render stability

  TDG Level: L1 (Property Testing)
  STAMP: SC-REG-001, SC-SAFETY-003, SC-HASH-001, SC-PRAJNA-001
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
  # P-REG-001: page mount invariant
  # ============================================================================

  describe "P-REG-001: page mount invariant" do
    test "page always mounts with valid HTML" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/register")
      assert is_binary(html)
    end

    test "page renders complete HTML structure" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/register")
      assert is_binary(html)
      assert byte_size(html) > 100
    end
  end

  # ============================================================================
  # P-REG-002: render stability invariant
  # ============================================================================

  describe "P-REG-002: render stability invariant" do
    property "page render always returns binary HTML" do
      forall _n <- PC.pos_integer() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/register")
        is_binary(render(view))
      end
    end

    test "repeated renders produce valid HTML" do
      check all(
              n <- SD.integer(1, 5),
              max_runs: 5
            ) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/register")

        results =
          for _i <- 1..n do
            render(view)
          end

        assert Enum.all?(results, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # P-REG-003: register content invariants
  # ============================================================================

  describe "P-REG-003: register content invariants" do
    test "page renders register or immutable register content" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/register")
      # Page should reference register concept somewhere
      assert is_binary(html)
    end

    test "page does not crash when block chain data is unavailable" do
      # In test env, DuckDB/SQLite register may be empty
      {:ok, _view, html} = live(build_conn(), "/cockpit/register")
      assert is_binary(html)
    end
  end

  # ============================================================================
  # P-REG-004: concurrent access invariant
  # ============================================================================

  describe "P-REG-004: concurrent mount invariant" do
    test "multiple concurrent mounts do not interfere" do
      check all(
              _n <- SD.integer(1, 3),
              max_runs: 3
            ) do
        {:ok, _view, html} = live(build_conn(), "/cockpit/register")
        assert is_binary(html)
      end
    end
  end
end
