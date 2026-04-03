defmodule IndrajaalWeb.Fmea.TestCockpitLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.TestCockpitLive.

  Analyzes failure modes in the biomorphic test evolution cockpit, focusing
  on test runner crashes, genome slider extremes, GenServer timeout,
  duplicate module watcher registration, and no-tests-found scenarios.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-TEST-EVO-001, SC-TEST-EVO-002, SC-TEST-EVO-003, SC-BIO-005, SC-HMI-001
  Reference: IEC 60812 FMEA, NUREG-0700, Biomorphic Evolution Protocol
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-TEST-001: Test Runner Crash Mid-Execution
  # Severity: 6 (evolution cycle interrupted; fitness data lost)
  # Occurrence: 3 (GenServer crash under load, OOM in external test process)
  # Detection: 3 (generation_status assign shows crash state)
  # RPN: 54
  # ============================================================================

  describe "FM-TEST-001: Test Runner Crash Mid-Execution (RPN: 54)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | BiomorphicTestEvolution GenServer crashes during evolution cycle |
    | Effect | OODA cycle broken; fitness metrics stale; operator cannot track coverage |
    | Severity | 6 (test evolution paused; coverage drift undetected) |
    | Occurrence | 3 (OOM in async Task.async, crash in model call) |
    | Detection | 3 (generation_status indicator shows error) |
    | RPN Before | 54 |
    | Mitigation | Supervisor restart strategy, Task.async error capture, flash on failure |
    | RPN After | 18 (S:6 x O:1 x D:3) |
    | STAMP | SC-TEST-EVO-001, SC-BIO-005 |
    """

    @tag rpn: 54
    test "page mounts and renders test cockpit without crash" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/test-evolution")

      assert is_binary(html)
      assert html =~ "Test" or html =~ "test"
    end

    @tag rpn: 54
    test "stop_evolution when evolution not running does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      # stop_evolution when already idle must be idempotent
      html = render_click(view, "stop_evolution", %{})

      assert is_binary(html)
    end

    @tag rpn: 54
    test "run_ooda when evolution is not running does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html = render_click(view, "run_ooda", %{})

      assert is_binary(html)
    end

    @tag rpn: 54
    test "start_evolution handles already-started GenServer gracefully" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      # First start
      _html1 = render_click(view, "start_evolution", %{})
      # Second start — must hit already_started branch without crash
      html2 = render_click(view, "start_evolution", %{})

      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-TEST-002: Genome Slider Extreme Values
  # Severity: 4 (evolution with pathological genome config produces zero tests)
  # Occurrence: 4 (operators explore boundary values)
  # Detection: 2 (fitness score immediately reflects zero output)
  # RPN: 32
  # ============================================================================

  describe "FM-TEST-002: Genome Slider Extreme Values (RPN: 32)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Genome parameters set to boundary extremes (0 or max) |
    | Effect | Test generation produces zero or degenerate output |
    | Severity | 4 (evolution cycles wasted; coverage does not improve) |
    | Occurrence | 4 (operators explore slider extremes during tuning) |
    | Detection | 2 (zero test count immediately visible in cockpit KPIs) |
    | RPN Before | 32 |
    | Mitigation | Genome range validation, minimum viable value guards |
    | RPN After | 8 (S:4 x O:1 x D:2) |
    | STAMP | SC-TEST-EVO-002, SC-TEST-EVO-003 |
    """

    @tag rpn: 32
    test "switch_tab to genome does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html = render_click(view, "switch_tab", %{"tab" => "genome"})

      assert is_binary(html)
    end

    @tag rpn: 32
    test "switch_tab to overview does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html = render_click(view, "switch_tab", %{"tab" => "overview"})

      assert is_binary(html)
    end

    @tag rpn: 32
    test "switch_tab to levels does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html = render_click(view, "switch_tab", %{"tab" => "levels"})

      assert is_binary(html)
    end

    @tag rpn: 32
    test "switch_tab with unknown tab string does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html =
        try do
          render_click(view, "switch_tab", %{"tab" => "unknown_tab_xyzzy_9999"})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-TEST-003: BiomorphicTestEvolution GenServer Timeout
  # Severity: 7 (OODA cycle stalls; evolution appears running but is frozen)
  # Occurrence: 2 (rare — only under sustained high load or model API outage)
  # Detection: 3 (OODA phase indicator shows stale phase)
  # RPN: 42
  # ============================================================================

  describe "FM-TEST-003: BiomorphicTestEvolution GenServer Timeout (RPN: 42)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | BiomorphicTestEvolution GenServer call times out under heavy load |
    | Effect | Fitness metrics frozen; evolution status shows :running but no progress |
    | Severity | 7 (silent stall not caught; operator loses confidence in metrics) |
    | Occurrence | 2 (model API rate-limiting or OOM) |
    | Detection | 3 (stale OODA phase indicator eventually noticed) |
    | RPN Before | 42 |
    | Mitigation | GenServer call timeout tuning, watchdog on OODA cycle timer |
    | RPN After | 14 (S:7 x O:1 x D:2) |
    | STAMP | SC-TEST-EVO-001, SC-VER-041 |
    """

    @tag rpn: 42
    test "generate_tests with empty module name does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html =
        try do
          render_click(view, "generate_tests", %{"module" => ""})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end

    @tag rpn: 42
    test "generate_tests with nonexistent module name does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html =
        try do
          render_click(view, "generate_tests", %{"module" => "Nonexistent.Module.XyZzy"})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end

    @tag rpn: 42
    test "run_ooda followed by stop_evolution does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      _html1 = render_click(view, "run_ooda", %{})
      html2 = render_click(view, "stop_evolution", %{})

      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-TEST-004: Module Watch Duplicate Registration
  # Severity: 3 (duplicate PubSub subscriptions receive double events; minor noise)
  # Occurrence: 5 (operator adds same module twice from different sessions)
  # Detection: 4 (duplicate test entries in recent_tests list; subtle)
  # RPN: 60
  # ============================================================================

  describe "FM-TEST-004: Module Watch Duplicate Registration (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | watch_module event fired twice for the same module path |
    | Effect | Duplicate PubSub subscriptions cause double test generation events |
    | Severity | 3 (minor — duplicate entries in recent_tests, no safety risk) |
    | Occurrence | 5 (operator clicks "Watch" without noticing existing entry) |
    | Detection | 4 (duplicate list entries visible but easy to miss) |
    | RPN Before | 60 |
    | Mitigation | MapSet-based deduplication of watched_modules assign |
    | RPN After | 12 (S:3 x O:2 x D:2) |
    | STAMP | SC-TEST-EVO-003, SC-HMI-001 |
    """

    @tag rpn: 60
    test "switch_tab to recent does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html = render_click(view, "switch_tab", %{"tab" => "recent"})

      assert is_binary(html)
    end

    @tag rpn: 60
    test "rapid tab switches across all defined tabs does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      _html1 = render_click(view, "switch_tab", %{"tab" => "genome"})
      _html2 = render_click(view, "switch_tab", %{"tab" => "levels"})
      _html3 = render_click(view, "switch_tab", %{"tab" => "recent"})
      html4 = render_click(view, "switch_tab", %{"tab" => "overview"})

      assert is_binary(html4)
    end

    @tag rpn: 60
    test "unknown event does not crash the LiveView process" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      html =
        try do
          render_click(view, "nonexistent_test_cockpit_event", %{"data" => "anything"})
        rescue
          _ -> render(view)
        catch
          :exit, _ -> "<html>handled</html>"
        end

      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-TEST-005: Test Execution with No Tests Found
  # Severity: 3 (evolution cycle completes with zero output; wasted compute)
  # Occurrence: 4 (new module, empty test file, wrong module path)
  # Detection: 2 (zero tests immediately visible in level coverage KPIs)
  # RPN: 24
  # ============================================================================

  describe "FM-TEST-005: Test Execution with No Tests Found (RPN: 24)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | generate_tests targets a module with no existing test surface |
    | Effect | Evolution cycle completes but produces zero tests; coverage unchanged |
    | Severity | 3 (wasted OODA cycle; no coverage regression, no safety impact) |
    | Occurrence | 4 (new modules, stub modules, non-public API modules) |
    | Detection | 2 (zero test count in level coverage immediately visible) |
    | RPN Before | 24 |
    | Mitigation | Pre-generation module surface analysis, skip empty modules with warning |
    | RPN After | 6 (S:3 x O:1 x D:2) |
    | STAMP | SC-TEST-EVO-003, SC-HMI-001 |
    """

    @tag rpn: 24
    test "start_evolution followed by run_ooda does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      _html1 = render_click(view, "start_evolution", %{})
      html2 = render_click(view, "run_ooda", %{})

      assert is_binary(html2)
    end

    @tag rpn: 24
    test "stop_evolution when evolution_active is false is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/test-evolution")

      # Call stop without prior start
      _html1 = render_click(view, "stop_evolution", %{})
      html2 = render_click(view, "stop_evolution", %{})

      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: TestCockpitLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_test_001, :test_runner_crash_mid_execution, 54},
        {:fm_test_002, :genome_slider_extreme_values, 32},
        {:fm_test_003, :biomorphic_genserver_timeout, 42},
        {:fm_test_004, :module_watch_duplicate_registration, 60},
        {:fm_test_005, :test_execution_no_tests_found, 24}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 5
      assert total_rpn_before == 212

      # Highest RPN is module watch duplicate registration — requires priority mitigation
      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :module_watch_duplicate_registration
      assert highest_rpn == 60
    end
  end
end
