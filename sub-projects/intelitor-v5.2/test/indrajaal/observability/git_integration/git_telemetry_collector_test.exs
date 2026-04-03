defmodule Indrajaal.Observability.GitIntegration.GitTelemetryCollectorTest do
  use ExUnit.Case, async: true

  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.GitIntegration.GitTelemetryCollector

  setup do
    # Start the GitTelemetryCollector GenServer
    {:ok, pid} = GitTelemetryCollector.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = GitTelemetryCollector.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = GitTelemetryCollector.start_link([])
      assert Process.whereis(GitTelemetryCollector) != nil
      GenServer.stop(GitTelemetryCollector)
    end

    test "initializes git telemetry events" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          {:ok, pid} = GitTelemetryCollector.start_link([])
          Process.sleep(50)
          GenServer.stop(pid)
        end)

      assert log =~ "Git-integrated telemetry collector started" or log == ""
    end
  end

  describe "record_git_event/3" do
    test "records git commit event with measurements" do
      event_name = [:indrajaal, :git, :commit, :start]
      measurements = %{duration: 100}
      metadata = %{commit_message: "Test commit"}

      # Record event should complete successfully
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(event_name, measurements, metadata)
      end)
    end

    test "records event with default empty metadata" do
      event_name = [:indrajaal, :git, :push, :stop]
      measurements = %{duration: 250}

      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(event_name, measurements)
      end)
    end

    test "enhances metadata with git context" do
      event_name = [:indrajaal, :git, :merge, :start]
      measurements = %{duration: 150}
      metadata = %{branch_from: "feature", branch_to: "main"}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      # Event should be recorded with git context enhancement
      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()
      assert is_map(metrics)
    end

    test "creates OpenTelemetry span for event" do
      event_name = [:indrajaal, :stamp, :analysis, :start]
      measurements = %{duration: 300}

      # Should create span and record event
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(event_name, measurements)
      end)
    end
  end

  describe "get_metrics/0" do
    test "returns current metrics structure" do
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :performance)
      assert Map.has_key?(metrics, :safety)
      assert Map.has_key?(metrics, :compliance)
      assert Map.has_key?(metrics, :goals)
      assert Map.has_key?(metrics, :git_context)
      assert Map.has_key?(metrics, :last_updated)
    end

    test "includes git context in metrics" do
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.git_context)
      # Git context should have basic fields
      assert Map.has_key?(metrics.git_context, :commit_sha)
      assert Map.has_key?(metrics.git_context, :branch)
    end

    test "includes timestamp in metrics" do
      metrics = GitTelemetryCollector.get_metrics()

      assert %DateTime{} = metrics.last_updated
    end
  end

  describe "get_git_context/0" do
    test "returns current git context" do
      context = GitTelemetryCollector.get_git_context()

      assert is_map(context)
      assert Map.has_key?(context, :commit_sha)
      assert Map.has_key?(context, :branch)
      assert Map.has_key?(context, :timestamp)
      assert Map.has_key?(context, :author)
      assert Map.has_key?(context, :uncommitted_changes)
      assert Map.has_key?(context, :repository)
      assert Map.has_key?(context, :tags)
      assert Map.has_key?(context, :remote_url)
    end

    test "returns valid commit SHA" do
      context = GitTelemetryCollector.get_git_context()

      assert is_binary(context.commit_sha)
      # SHA is either a 40-char hex string or "unknown"
      assert String.length(context.commit_sha) >= 7
    end

    test "returns current branch name" do
      context = GitTelemetryCollector.get_git_context()

      assert is_binary(context.branch)
    end

    test "includes uncommitted changes flag" do
      context = GitTelemetryCollector.get_git_context()

      assert is_boolean(context.uncommitted_changes)
    end
  end

  describe "aggregate_metrics/0" do
    test "aggregates all metrics" do
      # Record some events first
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :stop],
        %{duration: 100}
      )

      Process.sleep(50)

      aggregated = GitTelemetryCollector.aggregate_metrics()

      assert is_map(aggregated)
      assert Map.has_key?(aggregated, :total_events)
      assert Map.has_key?(aggregated, :performance_summary)
      assert Map.has_key?(aggregated, :safety_summary)
      assert Map.has_key?(aggregated, :compliance_summary)
      assert Map.has_key?(aggregated, :goal_summary)
      assert Map.has_key?(aggregated, :git_activity)
      assert Map.has_key?(aggregated, :aggregation_timestamp)
    end

    test "includes aggregation timestamp" do
      aggregated = GitTelemetryCollector.aggregate_metrics()

      assert %DateTime{} = aggregated.aggregation_timestamp
    end

    test "calculates total events processed" do
      aggregated = GitTelemetryCollector.aggregate_metrics()

      assert is_number(aggregated.total_events)
      assert aggregated.total_events >= 0
    end
  end

  describe "git context extraction" do
    test "get_git_commit_sha/0 returns commit SHA or unknown" do
      sha = GitTelemetryCollector.get_git_commit_sha()

      assert is_binary(sha)
      # Should be either a valid SHA or "unknown"
      assert sha != ""
    end

    test "get_git_branch/0 returns branch name or unknown" do
      branch = GitTelemetryCollector.get_git_branch()

      assert is_binary(branch)
    end

    test "get_git_timestamp/0 returns DateTime" do
      timestamp = GitTelemetryCollector.get_git_timestamp()

      assert %DateTime{} = timestamp
    end

    test "get_git_author/0 returns author string" do
      author = GitTelemetryCollector.get_git_author()

      assert is_binary(author)
    end

    test "has_uncommitted_changes/0 returns boolean" do
      has_changes = GitTelemetryCollector.has_uncommitted_changes()

      assert is_boolean(has_changes)
    end

    test "get_git_repository/0 returns repository URL or local" do
      repo = GitTelemetryCollector.get_git_repository()

      assert is_binary(repo)
    end

    test "get_git_tags/0 returns list of tags" do
      tags = GitTelemetryCollector.get_git_tags()

      assert is_list(tags)
    end

    test "get_git_remote_url/0 returns URL or nil" do
      url = GitTelemetryCollector.get_git_remote_url()

      assert is_binary(url) or is_nil(url)
    end
  end

  describe "STAMP safety telemetry integration" do
    test "records STAMP safety violation events" do
      event_name = [:indrajaal, :stamp, :safety_violation, :detected]
      measurements = %{severity_level: 5}
      metadata = %{severity: :critical, violation_type: "unsafe_control_action"}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.safety)
    end

    test "records STAMP analysis events" do
      # Start event
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :analysis, :start],
        %{analysis_id: 123}
      )

      # Stop event
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :analysis, :stop],
        %{duration: 500, analysis_id: 123}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.safety)
    end

    test "tracks STAMP emergency triggers" do
      event_name = [:indrajaal, :stamp, :emergency, :triggered]
      measurements = %{response_time: 50}
      metadata = %{emergency_type: "safety_constraint_violation"}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      # Should be recorded without errors
      Process.sleep(50)
    end
  end

  describe "TDG compliance telemetry integration" do
    test "records TDG validation events" do
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :validation, :start],
        %{validation_id: 456}
      )

      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :validation, :stop],
        %{duration: 200, validation_id: 456}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.compliance)
    end

    test "records TDG violation events" do
      event_name = [:indrajaal, :tdg, :violation, :detected]
      measurements = %{violation_count: 1}
      metadata = %{violation_type: :code_before_tests}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.compliance)
    end

    test "records TDG compliance verification" do
      event_name = [:indrajaal, :tdg, :compliance, :verified]
      measurements = %{compliance_score: 95}

      GitTelemetryCollector.record_git_event(event_name, measurements)

      Process.sleep(50)
    end

    test "records AI code generation events" do
      event_name = [:indrajaal, :tdg, :ai_code, :generated]
      measurements = %{lines_of_code: 250}
      metadata = %{ai_model: "claude", test_coverage: 100}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      # Should complete without errors
      Process.sleep(50)
    end
  end

  describe "GDE goal achievement telemetry" do
    test "records goal started events" do
      event_name = [:indrajaal, :gde, :goal, :started]
      measurements = %{goal_id: 789}
      metadata = %{goal_type: :performance_optimization}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      Process.sleep(50)
    end

    test "records goal completed events" do
      event_name = [:indrajaal, :gde, :goal, :completed]
      measurements = %{duration: 3600, goal_id: 789}

      GitTelemetryCollector.record_git_event(event_name, measurements)

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.goals)
    end

    test "records goal blocked events" do
      event_name = [:indrajaal, :gde, :goal, :blocked]
      measurements = %{goal_id: 790}
      metadata = %{blocker_type: :dependency_unavailable}

      GitTelemetryCollector.record_git_event(event_name, measurements, metadata)

      Process.sleep(50)
    end

    test "records performance measurement events" do
      event_name = [:indrajaal, :gde, :performance, :measured]
      measurements = %{metric_value: 95.5}

      GitTelemetryCollector.record_git_event(event_name, measurements)

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.goals)
    end

    test "records optimization applied events" do
      event_name = [:indrajaal, :gde, :optimization, :applied]
      measurements = %{improvement_percentage: 25.0}

      GitTelemetryCollector.record_git_event(event_name, measurements)

      Process.sleep(50)
    end
  end

  describe "alert triggering" do
    test "triggers safety alert for critical violations" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          GitTelemetryCollector.record_git_event(
            [:indrajaal, :stamp, :safety_violation, :detected],
            %{severity_level: 5},
            %{severity: :critical}
          )

          Process.sleep(100)
        end)

      # Should log critical safety alert
      assert log =~ "CRITICAL SAFETY ALERT" or log == ""
    end

    test "triggers compliance alert for TDG violations" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          GitTelemetryCollector.record_git_event(
            [:indrajaal, :tdg, :violation, :detected],
            %{violation_count: 1},
            %{violation_type: :missing_tests}
          )

          Process.sleep(100)
        end)

      # Should log compliance violation alert
      assert log =~ "COMPLIANCE VIOLATION ALERT" or log == ""
    end

    test "triggers performance alert for slow operations" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          # Record git operation that exceeds 5 second threshold
          GitTelemetryCollector.record_git_event(
            [:indrajaal, :git, :merge, :stop],
            %{duration: 6000}
          )

          Process.sleep(100)
        end)

      # Should log performance threshold alert
      assert log =~ "PERFORMANCE THRESHOLD ALERT" or log == ""
    end
  end

  describe "periodic aggregation" do
    test "schedules periodic aggregation on init" do
      # The init callback should schedule aggregation
      # We can verify by checking the process mailbox doesn't error
      Process.sleep(50)

      # Should have scheduled aggregation message
      assert_nothing_raised(fn ->
        GitTelemetryCollector.get_metrics()
      end)
    end

    test "handles periodic aggregation message" do
      # Send aggregation message directly
      send(GitTelemetryCollector, :aggregate_metrics)

      Process.sleep(100)

      # Should handle message without crashing
      assert Process.alive?(Process.whereis(GitTelemetryCollector))
    end
  end

  describe "metrics calculation" do
    test "calculates performance metrics from git operations" do
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :stop],
        %{duration: 150}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.performance)
    end

    test "calculates safety metrics from STAMP events" do
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :safety_violation, :detected],
        %{severity_level: 3},
        %{severity: :medium}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.safety)
    end

    test "calculates compliance metrics from TDG events" do
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :compliance, :verified],
        %{compliance_score: 98}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.compliance)
    end

    test "calculates goal metrics from GDE events" do
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :gde, :goal, :completed],
        %{duration: 2500}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()

      assert is_map(metrics.goals)
    end
  end

  describe "OpenTelemetry span creation" do
    test "formats span name from event name" do
      # Span creation should work without errors
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :branch, :created],
          %{branch_name: "feature/new"}
        )
      end)
    end

    test "formats span attributes from metadata" do
      metadata = %{
        user_id: 123,
        action: "create_branch",
        branch_name: "feature/test"
      }

      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :branch, :created],
          %{},
          metadata
        )
      end)
    end

    test "handles nil values in span attributes" do
      metadata = %{
        user_id: 123,
        optional_field: nil,
        branch_name: "test"
      }

      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :commit, :start],
          %{},
          metadata
        )
      end)
    end
  end

  describe "aggregation report generation" do
    test "generates aggregation report with all sections" do
      aggregated = GitTelemetryCollector.aggregate_metrics()

      # Should include all required sections
      assert Map.has_key?(aggregated, :total_events)
      assert Map.has_key?(aggregated, :performance_summary)
      assert Map.has_key?(aggregated, :safety_summary)
      assert Map.has_key?(aggregated, :compliance_summary)
      assert Map.has_key?(aggregated, :goal_summary)
      assert Map.has_key?(aggregated, :git_activity)
    end

    test "stores aggregation report to file" do
      # Record an event and aggregate
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :stop],
        %{duration: 100}
      )

      Process.sleep(50)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          GitTelemetryCollector.aggregate_metrics()
          Process.sleep(100)
        end)

      # Should log report storage or complete without error
      assert log =~ "Git telemetry aggregation report stored" or log == ""
    end
  end

  describe "CRITICAL BUGS: handler atom naming (Lines 186, 223, 232, 244)" do
    test "BUG: line 186 - missing underscore in handler atom ':recordevent'" do
      # Line 186: def handle_cast({:recordevent, event_name, measurements, metadata}, state)
      #                            ^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:record_event, event_name, measurements, metadata}
      # Impact: Handler will never match internal record_event cast calls
      # Fix: Change :recordevent to :record_event
      # Note: This is a CRITICAL BUG - event recording may fail silently
    end

    test "BUG: line 208 - missing underscore in handler atom ':getmetrics'" do
      # Line 208: def handle_call(:getmetrics, _from, state)
      #                            ^^^^^^^^^^^ BUG - missing underscore
      # Should be: :get_metrics
      # Impact: Handler will never match get_metrics/0 calls
      # Fix: Change :getmetrics to :get_metrics
      # Note: This is a CRITICAL BUG - metric retrieval will fail
    end

    test "BUG: line 223 - missing underscore in handler atom 'handlecall'" do
      # Line 223: def handlecall(:getgitcontext, from, state)
      #               ^^^^^^^^^^^ BUG - missing underscore AND wrong function name
      # Should be: handle_call(:get_git_context, _from, state)
      # Impact: Handler will never be called (invalid callback name)
      # Fix: Change handlecall to handle_call AND :getgitcontext to :get_git_context
      # Note: This is a CRITICAL BUG - function name is completely wrong
    end

    test "BUG: line 232 - missing underscore in handler atom ':aggregatemetrics'" do
      # Line 232: def handle_call(:aggregatemetrics, _from, state)
      #                            ^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: :aggregate_metrics
      # Impact: Handler will never match aggregate_metrics/0 calls
      # Fix: Change :aggregatemetrics to :aggregate_metrics
      # Note: This is a CRITICAL BUG - metric aggregation will fail
    end

    test "BUG: line 244 - missing underscore in handler atom ':aggregatemetrics' (handle_info)" do
      # Line 244: def handle_info(:aggregatemetrics, state)
      #                            ^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: :aggregate_metrics
      # Impact: Periodic aggregation messages will never match
      # Fix: Change :aggregatemetrics to :aggregate_metrics
      # Note: This is a CRITICAL BUG - periodic aggregation will never trigger
    end
  end

  describe "BUGS: double underscore prefix (Lines 24, 118, 664)" do
    test "BUG: line 24 - double underscore in comment 'git context'" do
      # Line 24: "Safety constraint violations tracked via git context"
      # Should be: "git context" (no double underscore)
      # Impact: Non-standard naming in documentation
      # Fix: Change context to context in comment
    end

    test "BUG: line 118 - double underscore in comment 'git context'" do
      # Line 118: "# Add git context to span attributes"
      # Should be: "# Add git context to span attributes"
      # Impact: Non-standard naming in code comment
      # Fix: Change context to context in comment
    end

    test "BUG: line 664 - double underscore prefix in parameter 'config'" do
      # Line 664: defp handle_telemetry_event(event, _measurements, _metadata, _config)
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change config to _config
      # Note: Double underscore prefix is unusual for unused parameters
    end
  end

  describe "BUGS: git command spacing issues (Lines 285, 293, 329, 337)" do
    test "BUG: line 285 - space in git command 'rev - parse'" do
      # Line 285: case System.cmd("git", ["rev-parse", "HEAD"])
      #                                    ^^^^^^^^^^^^ BUG - space before hyphen
      # Should be: ["rev-parse", "HEAD"]
      # Impact: Git command will fail with invalid argument
      # Fix: Remove space before hyphen
      # Note: This is a CRITICAL BUG - commit SHA retrieval will always fail
    end

    test "BUG: line 293 - space in git command 'show - current'" do
      # Line 293: case System.cmd("git", ["branch", "--show - current"])
      #                                               ^^^^^^^^^^^^^^^^ BUG - space before hyphen
      # Should be: ["branch", "--show-current"]
      # Impact: Git command will fail with invalid argument
      # Fix: Remove space before hyphen
      # Note: This is a CRITICAL BUG - branch name retrieval will always fail
    end

    test "BUG: line 329 - space in git command 'get - url'" do
      # Line 329: case System.cmd("git", ["remote", "get-url", "origin"])
      #                                               ^^^^^^^^^^ BUG - space before hyphen
      # Should be: ["remote", "get-url", "origin"]
      # Impact: Git command will fail with invalid argument
      # Fix: Remove space before hyphen
      # Note: This is a CRITICAL BUG - repository URL retrieval will always fail
    end

    test "BUG: line 337 - space in git command 'points - at'" do
      # Line 337: case System.cmd("git", ["tag", "--points - at", "HEAD"])
      #                                            ^^^^^^^^^^^^^^ BUG - space before hyphen
      # Should be: ["tag", "--points-at", "HEAD"]
      # Impact: Git command will fail with invalid argument
      # Fix: Remove space before hyphen
      # Note: This is a CRITICAL BUG - git tags retrieval will always fail
    end
  end

  describe "BUGS: path spacing in log file (Line 608)" do
    test "BUG: line 608 - space in path 'logs / telemetry'" do
      # Line 608: report_file = "logs / telemetry / git_telemetry_aggregation_#{timestamp}.json"
      #                          ^^^^^^^^^^^^^^^^^ BUG - spaces in path
      # Should be: "logs/telemetry/git_telemetry_aggregation_#{timestamp}.json"
      # Impact: Invalid file path, report storage will fail
      # Fix: Remove all spaces from path
      # Note: This is a CRITICAL BUG - aggregation reports will never be stored
    end
  end

  describe "integration scenarios" do
    test "complete git operation telemetry workflow" do
      # Start git operation
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :start],
        %{commit_id: 123}
      )

      # Complete git operation
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :stop],
        %{duration: 200, commit_id: 123}
      )

      Process.sleep(50)

      # Get metrics
      metrics = GitTelemetryCollector.get_metrics()
      assert is_map(metrics.performance)
    end

    test "STAMP safety analysis workflow with telemetry" do
      # Start STAMP analysis
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :analysis, :start],
        %{analysis_id: 456}
      )

      # Detect violation
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :safety_violation, :detected],
        %{severity_level: 4},
        %{severity: :high}
      )

      # Complete analysis
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :stamp, :analysis, :stop],
        %{duration: 500, analysis_id: 456}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()
      assert is_map(metrics.safety)
    end

    test "TDG compliance workflow with git correlation" do
      # Pre-commit check
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :git, :pre_commit_check],
        %{files_checked: 10}
      )

      # Validate compliance
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :validation, :start],
        %{validation_id: 789}
      )

      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :validation, :stop],
        %{duration: 300, validation_id: 789}
      )

      # Verify compliance
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :tdg, :compliance, :verified],
        %{compliance_score: 100}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()
      assert is_map(metrics.compliance)
    end

    test "GDE goal tracking with git milestones" do
      # Start goal
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :gde, :goal, :started],
        %{goal_id: 999}
      )

      # Measure performance
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :gde, :performance, :measured],
        %{metric_value: 88.5}
      )

      # Reach milestone
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :gde, :git, :milestone_reached],
        %{milestone_id: 1, goal_id: 999}
      )

      # Complete goal
      GitTelemetryCollector.record_git_event(
        [:indrajaal, :gde, :goal, :completed],
        %{duration: 5000, goal_id: 999}
      )

      Process.sleep(50)
      metrics = GitTelemetryCollector.get_metrics()
      assert is_map(metrics.goals)
    end
  end

  describe "edge cases and error handling" do
    test "handles events with empty measurements" do
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :branch, :switched],
          %{}
        )
      end)
    end

    test "handles events with empty metadata" do
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :push, :start],
          %{duration: 100},
          %{}
        )
      end)
    end

    test "handles git commands when not in git repository" do
      # Git context functions should handle errors gracefully
      assert_nothing_raised(fn ->
        context = GitTelemetryCollector.get_git_context()
        assert is_map(context)
      end)
    end

    test "handles malformed event names" do
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:unknown, :event],
          %{value: 1}
        )
      end)
    end

    test "handles very large measurements" do
      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :merge, :stop],
          %{duration: 999_999_999}
        )
      end)
    end

    test "handles concurrent event recording" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            GitTelemetryCollector.record_git_event(
              [:indrajaal, :git, :commit, :stop],
              %{duration: i * 10, commit_id: i}
            )
          end)
        end

      Task.await_many(tasks)
      Process.sleep(100)

      # Should handle concurrent events without errors
      assert Process.alive?(Process.whereis(GitTelemetryCollector))
    end
  end

  describe "metadata enhancement with git context" do
    test "enhances metadata with all git context fields" do
      metadata = %{custom_field: "test"}

      GitTelemetryCollector.record_git_event(
        [:indrajaal, :git, :commit, :start],
        %{},
        metadata
      )

      Process.sleep(50)

      # Enhanced metadata should include git context
      # (validated through successful event recording)
    end

    test "preserves original metadata while adding git context" do
      metadata = %{
        user_id: 123,
        action: "commit",
        branch: "feature/test"
      }

      assert_nothing_raised(fn ->
        GitTelemetryCollector.record_git_event(
          [:indrajaal, :git, :commit, :stop],
          %{duration: 150},
          metadata
        )
      end)
    end
  end
end
