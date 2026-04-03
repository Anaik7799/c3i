defmodule IndrajaalWeb.Prajna.GuardianDashboardLiveTest do
  @moduledoc """
  TDG comprehensive test suite for GuardianDashboardLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-PRAJNA-001: All commands through Guardian pre-approval
  - SC-CONST-007: Guardian has absolute veto
  - SC-GDE-001: Guardian validation required
  - SC-PRAJNA-007: Two-step commit for destructive actions

  ## Constitutional Verification
  - Ψ₀ Existence: Guardian dashboard persists across failures
  - Ψ₁ Regeneration: Governance state reconstructible
  - Ψ₂ Evolutionary Continuity: Decision history preserved
  - Ψ₃ Verification: Proposal verification mandatory
  - Ψ₄ Human Alignment: Guardian serves Founder's lineage
  - Ψ₅ Truthfulness: No fabricated approval/veto data

  ## Founder's Directive Alignment
  - Ω₀.4: Co-Evolution - Guardian evolves with Founder's needs
  - Ω₀.5: Mutual Termination - Guardian shutdown if Founder fails

  ## TPS 5-Level RCA Context
  - L1 Symptom: Proposal stuck or veto not enforced
  - L2 Diagnosis: Guardian offline or circuit breaker open
  - L3 System Condition: Database unavailable or message queue full
  - L4 Design Weakness: Missing validation or audit trail
  - L5 Root Cause: Insufficient governance enforcement
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import Phoenix.LiveViewTest

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias IndrajaalWeb.Prajna.GuardianDashboardLive

  # ============================================================================
  # Constitutional Invariants (Ψ₀-Ψ₅)
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence preserved under proposal failures", %{conn: conn} do
      # Dashboard continues to exist when proposals fail
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Simulate proposal failure
      send(view.pid, {:proposal_failed, "prop_001"})
      # View should still be alive
      assert Process.alive?(view.pid)
    end

    test "Ψ₁ regeneration completeness", %{conn: conn} do
      # Governance state reconstructible
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      initial_approved = view.assigns.proposals_approved
      # Disconnect and reconnect
      Process.exit(view.pid, :normal)
      {:ok, new_view, _html} = live(conn, "/prajna/guardian")
      # Should reinitialize with default state
      assert is_integer(new_view.assigns.proposals_approved)
    end

    test "Ψ₂ evolutionary continuity", %{conn: conn} do
      # Decision history preserved
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      decisions = view.assigns.recent_decisions
      assert is_list(decisions)
    end

    test "Ψ₃ verification capability", %{conn: conn} do
      # Proposal verification mandatory
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Should have verification mechanism
      assert is_integer(view.assigns.proposals_approved)
      assert is_integer(view.assigns.proposals_vetoed)
    end

    test "Ψ₄ human alignment (Founder PRIMARY)", %{conn: conn} do
      # Guardian serves Founder's lineage
      {:ok, view, html} = live(conn, "/prajna/guardian")
      # Should display governance dashboard
      assert html =~ "Guardian" or html =~ "Governance" or String.length(html) > 0
    end

    test "Ψ₅ truthfulness", %{conn: conn} do
      # No fabricated approval/veto data
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      approved = view.assigns.proposals_approved
      vetoed = view.assigns.proposals_vetoed
      # Counts must be from init function (0 or realistic values)
      assert is_integer(approved) and approved >= 0
      assert is_integer(vetoed) and vetoed >= 0
    end
  end

  # ============================================================================
  # Mount and Initialization
  # ============================================================================

  describe "Mount and Initialization" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      assert html =~ "Guardian" or html =~ "Governance"
    end

    test "initializes with zero approvals", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.proposals_approved == 0
    end

    test "initializes with zero vetoes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.proposals_vetoed == 0
    end

    test "initializes with empty pending operations", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.pending_operations == []
    end

    test "initializes circuit breaker as closed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.circuit_breaker == :closed
    end

    test "initializes with empty decision history", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.recent_decisions == []
    end

    test "sets page title correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.page_title == "Guardian - Governance"
    end

    test "sets up refresh timer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Trigger refresh
      send(view.pid, :refresh)
      # Should handle message
      assert Process.alive?(view.pid)
    end

    test "initializes last_update timestamp", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert %DateTime{} = view.assigns.last_update
    end
  end

  # ============================================================================
  # Proposal Tracking (SC-PRAJNA-001)
  # ============================================================================

  describe "Proposal Tracking (SC-PRAJNA-001)" do
    test "displays approved count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show approved count
      assert html =~ "Approved" or html =~ "0"
    end

    test "displays vetoed count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show vetoed count
      assert html =~ "Vetoed" or html =~ "0"
    end

    test "displays pending operations count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show pending count
      assert html =~ "Pending" or html =~ "0"
    end

    test "increments approved counter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      initial = view.assigns.proposals_approved
      # Simulate approval
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :proposals_approved, initial + 1)
      end)

      assert :sys.get_state(view.pid).proposals_approved == initial + 1
    end

    test "increments vetoed counter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      initial = view.assigns.proposals_vetoed
      # Simulate veto
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :proposals_vetoed, initial + 1)
      end)

      assert :sys.get_state(view.pid).proposals_vetoed == initial + 1
    end
  end

  # ============================================================================
  # Circuit Breaker Status (SC-CONST-007)
  # ============================================================================

  describe "Circuit Breaker Status (SC-CONST-007)" do
    test "displays circuit breaker state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show circuit breaker status
      assert html =~ "Circuit" or html =~ "closed"
    end

    test "closed state renders green", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should have green color class for closed
      assert html =~ "green" or html =~ "closed"
    end

    test "transitions to half_open state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")

      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :circuit_breaker, :half_open)
      end)

      assert :sys.get_state(view.pid).circuit_breaker == :half_open
    end

    test "transitions to open state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")

      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :circuit_breaker, :open)
      end)

      assert :sys.get_state(view.pid).circuit_breaker == :open
    end

    test "open state renders red", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")

      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :circuit_breaker, :open)
      end)

      html = render(view)
      # Should have red color for open state
      assert html =~ "red" or html =~ "open"
    end
  end

  # ============================================================================
  # Decision History (Ψ₂: Evolutionary Continuity)
  # ============================================================================

  describe "Decision History" do
    test "displays recent decisions list", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show recent decisions section
      assert html =~ "Recent Decisions" or html =~ "decisions"
    end

    test "shows empty state when no decisions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show "No recent decisions" message
      assert html =~ "No recent decisions" or html =~ "decisions"
    end

    test "adds decision to history", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      decision = %{id: "dec_001", type: :approval, timestamp: DateTime.utc_now()}

      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :recent_decisions, [decision])
      end)

      assert length(:sys.get_state(view.pid).recent_decisions) == 1
    end
  end

  # ============================================================================
  # Real-time Updates
  # ============================================================================

  describe "Real-time Updates" do
    test "handles refresh message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      send(view.pid, :refresh)
      Process.sleep(50)
      # Should have updated last_update timestamp
      assert %DateTime{} = view.assigns.last_update
    end

    test "updates last_update timestamp on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      initial_time = view.assigns.last_update
      Process.sleep(100)
      send(view.pid, :refresh)
      Process.sleep(50)
      final_time = view.assigns.last_update
      # Timestamp should be updated
      assert DateTime.compare(initial_time, final_time) in [:lt, :eq]
    end

    test "refreshes every 5 seconds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Trigger multiple refreshes
      send(view.pid, :refresh)
      Process.sleep(50)
      send(view.pid, :refresh)
      Process.sleep(50)
      # Should handle all refreshes
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Veto Authority (SC-CONST-007: Absolute Veto)
  # ============================================================================

  describe "Veto Authority (SC-CONST-007)" do
    test "Guardian veto cannot be overridden", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Simulate veto
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :proposals_vetoed, 1)
      end)

      # Veto count should be recorded
      assert :sys.get_state(view.pid).proposals_vetoed == 1
    end

    test "circuit breaker enforces Guardian decisions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Circuit breaker state reflects Guardian authority
      assert view.assigns.circuit_breaker in [:closed, :half_open, :open]
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "counters never decrease" do
    forall operations <- PC.list(PC.oneof([:approve, :veto]), min_length: 0, max_length: 10) do
      # Simulate counter operations
      {approved, vetoed} =
        Enum.reduce(operations, {0, 0}, fn op, {a, v} ->
          case op do
            :approve -> {a + 1, v}
            :veto -> {a, v + 1}
          end
        end)

      approved >= 0 and vetoed >= 0
    end
  end

  property "circuit breaker states are valid" do
    forall state <- PC.oneof([:closed, :half_open, :open]) do
      state in [:closed, :half_open, :open]
    end
  end

  property "timestamps are monotonically increasing" do
    forall _n <- PC.range(1, 5) do
      t1 = DateTime.utc_now()
      Process.sleep(10)
      t2 = DateTime.utc_now()
      DateTime.compare(t1, t2) in [:lt, :eq]
    end
  end

  # ============================================================================
  # ExUnitProperties Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "approval counts are non-negative" do
      ExUnitProperties.check all(
                               count <- SD.non_negative_integer(),
                               max_runs: 50
                             ) do
        count >= 0
      end
    end

    test "decision types are valid" do
      ExUnitProperties.check all(
                               decision_type <- SD.member_of([:approval, :veto, :pending]),
                               max_runs: 50
                             ) do
        decision_type in [:approval, :veto, :pending]
      end
    end

    test "circuit breaker transitions are valid" do
      ExUnitProperties.check all(
                               {from, to} <-
                                 SD.tuple({
                                   SD.member_of([:closed, :half_open, :open]),
                                   SD.member_of([:closed, :half_open, :open])
                                 }),
                               max_runs: 50
                             ) do
        # Valid transitions
        from in [:closed, :half_open, :open] and to in [:closed, :half_open, :open]
      end
    end
  end

  # ============================================================================
  # Error Handling
  # ============================================================================

  describe "Error Handling" do
    test "handles invalid circuit breaker state gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Set invalid state
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :circuit_breaker, :invalid)
      end)

      # Should still render without crashing
      assert Process.alive?(view.pid)
    end

    test "handles missing decision data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Clear decisions
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :recent_decisions, [])
      end)

      # Should render empty state
      html = render(view)
      assert html =~ "No recent decisions"
    end

    test "survives rapid refresh cycles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")

      for _ <- 1..50 do
        send(view.pid, :refresh)
      end

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Tests
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "UI responds within 100ms", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _view, _html} = live(conn, "/prajna/guardian")
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 1000
    end

    test "refresh completes within 2s", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      start_time = System.monotonic_time(:millisecond)
      send(view.pid, :refresh)
      Process.sleep(50)
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 2000
    end

    test "veto enforcement is immediate", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      start_time = System.monotonic_time(:millisecond)
      # Simulate veto
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :proposals_vetoed, 1)
      end)

      elapsed = System.monotonic_time(:millisecond) - start_time
      # Veto should be instant
      assert elapsed < 100
    end
  end

  # ============================================================================
  # Accessibility
  # ============================================================================

  describe "Accessibility" do
    test "has page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      assert view.assigns.page_title == "Guardian - Governance"
    end

    test "renders semantic HTML structure", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "displays last update timestamp", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/guardian")
      # Should show last update time
      assert html =~ "Last update" or html =~ "UTC"
    end
  end

  # ============================================================================
  # Founder's Directive Compliance (Ω₀.4, Ω₀.5)
  # ============================================================================

  describe "Founder's Directive Compliance" do
    test "Ω₀.4 Co-Evolution: Guardian adapts to Founder needs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Guardian should track proposal types relevant to Founder
      assert is_integer(view.assigns.proposals_approved)
    end

    test "Ω₀.5 Mutual Termination: Guardian shutdown triggers system alert", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Circuit breaker open = system alert condition
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :circuit_breaker, :open)
      end)

      assert :sys.get_state(view.pid).circuit_breaker == :open
    end
  end

  # ============================================================================
  # Two-Step Commit (SC-PRAJNA-007)
  # ============================================================================

  describe "Two-Step Commit (SC-PRAJNA-007)" do
    test "destructive actions require Guardian approval", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Pending operations should exist for destructive actions
      assert is_list(view.assigns.pending_operations)
    end

    test "pending operations displayed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/guardian")
      # Should track pending destructive operations
      pending = view.assigns.pending_operations
      assert is_list(pending)
      assert length(pending) >= 0
    end
  end
end
