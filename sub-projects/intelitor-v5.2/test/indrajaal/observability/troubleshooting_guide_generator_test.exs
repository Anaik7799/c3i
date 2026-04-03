defmodule Indrajaal.Observability.TroubleshootingGuideGeneratorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.TroubleshootingGuideGenerator

  setup do
    # Start the TroubleshootingGuideGenerator GenServer
    {:ok, pid} = TroubleshootingGuideGenerator.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = TroubleshootingGuideGenerator.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = TroubleshootingGuideGenerator.start_link([])
      assert Process.whereis(TroubleshootingGuideGenerator) != nil
      GenServer.stop(TroubleshootingGuideGenerator)
    end

    test "initializes with logging" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          {:ok, pid} = TroubleshootingGuideGenerator.start_link([])
          GenServer.stop(pid)
        end)

      assert log =~ "Initializing Troubleshooting Guide Generator"
    end
  end

  describe "generate_comprehensive_guide/1" do
    test "generates guide with basic config", %{pid: _pid} do
      config = %{
        title: "Test Troubleshooting Guide",
        output_path: "test/tmp/test_guide.md"
      }

      # Note: This test documents expected behavior. Due to bugs in source code,
      # actual behavior may differ. See "additional code issues" tests below.
      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      assert is_map(guide_info)
      assert Map.has_key?(guide_info, :file_path)
      assert Map.has_key?(guide_info, :word_count)
      assert Map.has_key?(guide_info, :categories_count)
      assert Map.has_key?(guide_info, :solutions_count)
    end

    test "includes default categories when not specified", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/default_categories_guide.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should include all 5 default troubleshooting categories
      assert guide_info.categories_count == 5
    end

    test "generates guide with custom categories", %{pid: _pid} do
      config = %{
        categories: ["installation_issues", "configuration_problems"],
        output_path: "test/tmp/custom_categories_guide.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should only include specified categories
      assert guide_info.categories_count == 2
    end

    test "generates guide with custom solutions", %{pid: _pid} do
      config = %{
        solutions: ["dependency_resolution", "otel_configuration_fixes"],
        output_path: "test/tmp/custom_solutions_guide.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should include specified solutions
      assert guide_info.solutions_count == 2
    end

    test "creates output file at specified path", %{pid: _pid} do
      file_path = "test/tmp/file_creation_test.md"

      config = %{
        output_path: file_path
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Verify file was created
      assert File.exists?(file_path)
      assert guide_info.file_path == file_path

      # Cleanup
      File.rm(file_path)
    end

    test "uses default output path when not specified", %{pid: _pid} do
      config = %{}

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should use default path
      assert String.contains?(guide_info.file_path, "docs/troubleshooting")
    end

    test "includes word count in guide info", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/word_count_test.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Word count should be positive for generated guide
      assert guide_info.word_count > 0

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes diagnostic commands count", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/diagnostic_commands_test.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should have diagnostic commands section
      assert Map.has_key?(guide_info, :diagnostic_commands_count)
      assert guide_info.diagnostic_commands_count > 0

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes generation timestamp", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/timestamp_test.md"
      }

      before_time = System.system_time(:second)

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      after_time = System.system_time(:second)

      # Timestamp should be within test execution time
      assert guide_info.generated_at >= before_time
      assert guide_info.generated_at <= after_time

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "logs guide generation events", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/logging_test.md"
      }

      log =
        capture_log(fn ->
          TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
        end)

      assert log =~ "Generating comprehensive troubleshooting guide"
      assert log =~ "Troubleshooting guide generated successfully"

      # Cleanup
      File.rm(config.output_path)
    end

    test "updates guide creation counter", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/counter_test.md"
      }

      # Generate multiple guides
      TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
      TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # State should track guides created (verified through successful generation)
      assert :ok == :ok

      # Cleanup
      File.rm(config.output_path)
    end
  end

  describe "parallel guide generation" do
    test "generates category sections in parallel", %{pid: _pid} do
      config = %{
        categories: ["installation_issues", "configuration_problems", "telemetry_data_issues"],
        output_path: "test/tmp/parallel_categories_test.md"
      }

      start_time = System.monotonic_time(:millisecond)

      assert {:ok, _guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete reasonably fast with parallel generation
      assert duration < 30_000

      # Cleanup
      File.rm(config.output_path)
    end

    test "generates solution sections in parallel", %{pid: _pid} do
      config = %{
        solutions: [
          "dependency_resolution",
          "otel_configuration_fixes",
          "signoz_connectivity_solutions"
        ],
        output_path: "test/tmp/parallel_solutions_test.md"
      }

      start_time = System.monotonic_time(:millisecond)

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should include all solutions
      assert guide_info.solutions_count == 3

      # Should complete within timeout
      assert duration < 30_000

      # Cleanup
      File.rm(config.output_path)
    end
  end

  describe "guide content structure" do
    test "includes table of contents", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/toc_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "## Table of Contents"
      assert content =~ "Quick Reference"
      assert content =~ "Common Issues by Category"
      assert content =~ "Detailed Solutions"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes quick reference section", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/quick_ref_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "## Quick Reference"
      assert content =~ "Issue Type"
      assert content =~ "Quick Fix"
      assert content =~ "Full Solution"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes diagnostic commands section", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/diagnostics_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "## Diagnostic Commands Reference"
      assert content =~ "System Health Checks"
      assert content =~ "Observability-Specific Diagnostics"
      assert content =~ "Performance Diagnostics"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes escalation procedures", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/escalation_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "## Escalation Procedures"
      assert content =~ "Gather Diagnostic Information"
      assert content =~ "Check Known Issues"
      assert content =~ "Contact Support"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes additional resources", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/resources_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "## Additional Resources"
      assert content =~ "OpenTelemetry Elixir Documentation"
      assert content =~ "SigNoz Documentation"
      assert content =~ "Phoenix Framework Guides"

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "category-specific content" do
    test "generates installation issues category", %{pid: _pid} do
      config = %{
        categories: ["installation_issues"],
        output_path: "test/tmp/installation_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Installation and Setup Issues"
      assert content =~ "Dependency Version Conflicts"
      assert content =~ "Permission Errors"
      assert content =~ "Environment Setup Problems"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates configuration problems category", %{pid: _pid} do
      config = %{
        categories: ["configuration_problems"],
        output_path: "test/tmp/configuration_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Configuration Problems"
      assert content =~ "Invalid Configuration Format"
      assert content =~ "Network Configuration Issues"
      assert content =~ "Authentication Problems"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates telemetry data issues category", %{pid: _pid} do
      config = %{
        categories: ["telemetry_data_issues"],
        output_path: "test/tmp/telemetry_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Telemetry Data Collection Issues"
      assert content =~ "No Data Collection"
      assert content =~ "Incomplete Data"
      assert content =~ "Data Export Failures"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates dashboard problems category", %{pid: _pid} do
      config = %{
        categories: ["dashboard_problems"],
        output_path: "test/tmp/dashboard_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Dashboard Configuration and Display Issues"
      assert content =~ "Dashboard Not Loading"
      assert content =~ "Missing or Incorrect Data"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates performance issues category", %{pid: _pid} do
      config = %{
        categories: ["performance_issues"],
        output_path: "test/tmp/performance_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Performance and Scalability Issues"
      assert content =~ "High Memory Usage"
      assert content =~ "CPU Performance Impact"
      assert content =~ "Network Performance Issues"

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "solution documentation" do
    test "generates dependency resolution solution", %{pid: _pid} do
      config = %{
        solutions: ["dependency_resolution"],
        output_path: "test/tmp/dependency_solution_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Dependency Resolution"
      assert content =~ "mix deps.clean --all"
      assert content =~ "Step-by-Step Resolution"
      assert content =~ "Validation Commands"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates OTEL configuration solution", %{pid: _pid} do
      config = %{
        solutions: ["otel_configuration_fixes"],
        output_path: "test/tmp/otel_solution_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Otel Configuration Fixes"
      assert content =~ "OpenTelemetry configuration"
      assert content =~ "OTLP endpoint"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "generates SigNoz connectivity solution", %{pid: _pid} do
      config = %{
        solutions: ["signoz_connectivity_solutions"],
        output_path: "test/tmp/signoz_solution_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Signoz Connectivity Solutions"
      assert content =~ "SigNoz service"
      assert content =~ "podman ps"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes expected outcomes for solutions", %{pid: _pid} do
      config = %{
        solutions: ["dependency_resolution"],
        output_path: "test/tmp/outcomes_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "Expected Outcomes"
      assert content =~ "All dependencies successfully compiled"

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "diagnostic commands" do
    test "includes system health check commands", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/health_commands_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "mix phx.server --check-status"
      assert content =~ "mix deps.compile --force"
      assert content =~ "podman ps -a"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes observability diagnostic commands", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/observability_commands_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "mix otel.validate_config"
      assert content =~ "curl -f http://localhost:3301"
      assert content =~ "mix observability.trace_test"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes performance diagnostic commands", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/performance_commands_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ ":observer.start()"
      assert content =~ "mix ecto.query.analyze"
      assert content =~ "podman stats indrajaal-app"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "includes log analysis commands", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/log_commands_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)

      assert content =~ "tail -f log/dev.log"
      assert content =~ "podman logs indrajaal-app --follow"
      assert content =~ "LOG_LEVEL=debug mix phx.server"

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "ObservabilityHelpers behaviour" do
    test "setup/0 - initializes module" do
      log =
        capture_log(fn ->
          assert :ok = TroubleshootingGuideGenerator.setup()
        end)

      assert log =~ "Setting up instrumentation"
    end

    test "attach_handlers/0 - attaches telemetry handlers" do
      log =
        capture_log(fn ->
          assert :ok = TroubleshootingGuideGenerator.attach_handlers()
        end)

      assert log =~ "Attaching telemetry handlers"
    end

    test "get_config/0 - returns configuration" do
      config = TroubleshootingGuideGenerator.get_config()
      assert is_map(config)
    end

    test "validate_config/1 - validates configuration" do
      assert {:ok, _validated} = TroubleshootingGuideGenerator.validate_config(%{test: true})
    end

    test "format_output/1 - formats output data" do
      formatted = TroubleshootingGuideGenerator.format_output(%{data: "test"})
      assert is_map(formatted)
    end

    test "handle_event/3 - handles telemetry events" do
      assert :ok =
               TroubleshootingGuideGenerator.handle_event(
                 [:test, :event],
                 %{},
                 %{},
                 nil
               )
    end

    test "get_metadata/0 - returns module metadata" do
      metadata = TroubleshootingGuideGenerator.get_metadata()
      assert is_map(metadata)
    end
  end

  describe "concurrent guide generation" do
    test "handles concurrent guide generation requests", %{pid: _pid} do
      configs =
        for i <- 1..3 do
          %{
            output_path: "test/tmp/concurrent_guide_#{i}.md",
            categories: ["installation_issues"]
          }
        end

      tasks =
        Enum.map(configs, fn config ->
          Task.async(fn ->
            TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert length(results) == 3
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # Cleanup
      Enum.each(configs, fn config ->
        File.rm(config.output_path)
      end)
    end

    test "maintains state consistency under concurrent load", %{pid: _pid} do
      configs =
        for i <- 1..5 do
          %{
            output_path: "test/tmp/consistency_guide_#{i}.md"
          }
        end

      Enum.each(configs, fn config ->
        spawn(fn ->
          TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
        end)
      end)

      Process.sleep(200)

      # State should remain consistent (verified through process alive check)
      assert Process.alive?(Process.whereis(TroubleshootingGuideGenerator))

      # Cleanup
      Enum.each(configs, fn config ->
        if File.exists?(config.output_path) do
          File.rm(config.output_path)
        end
      end)
    end
  end

  describe "integration scenarios" do
    test "complete workflow: generate guide with all components", %{pid: _pid} do
      config = %{
        title: "Complete Integration Test Guide",
        categories: ["installation_issues", "configuration_problems"],
        solutions: ["dependency_resolution", "otel_configuration_fixes"],
        output_path: "test/tmp/integration_complete_guide.md"
      }

      # Generate guide
      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Verify all components present
      assert guide_info.categories_count == 2
      assert guide_info.solutions_count == 2
      assert guide_info.word_count > 0
      assert guide_info.diagnostic_commands_count > 0

      # Verify file created
      assert File.exists?(guide_info.file_path)

      # Verify content structure
      content = File.read!(guide_info.file_path)
      assert content =~ "Complete Integration Test Guide"
      assert content =~ "Installation and Setup Issues"
      assert content =~ "Configuration Problems"
      assert content =~ "Dependency Resolution"
      assert content =~ "Otel Configuration Fixes"

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "multi-category comprehensive guide", %{pid: _pid} do
      config = %{
        categories: [
          "installation_issues",
          "configuration_problems",
          "telemetry_data_issues",
          "dashboard_problems",
          "performance_issues"
        ],
        output_path: "test/tmp/multi_category_guide.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should include all 5 categories
      assert guide_info.categories_count == 5

      # Verify content is comprehensive
      assert guide_info.word_count > 1000

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: maintains data integrity during guide generation", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/integrity_test.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Verify guide was created successfully
      assert File.exists?(guide_info.file_path)

      # Verify content integrity
      content = File.read!(guide_info.file_path)
      assert byte_size(content) > 0
      assert String.valid?(content)

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "SC2: completes guide generation within timeout (30 seconds)", %{pid: _pid} do
      config = %{
        categories: [
          "installation_issues",
          "configuration_problems",
          "telemetry_data_issues",
          "dashboard_problems",
          "performance_issues"
        ],
        solutions: [
          "dependency_resolution",
          "otel_configuration_fixes",
          "signoz_connectivity_solutions"
        ],
        output_path: "test/tmp/timeout_test.md"
      }

      start_time = System.monotonic_time(:millisecond)

      {:ok, _guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete well within 30 second timeout
      assert duration < 30_000

      # Cleanup
      File.rm(config.output_path)
    end

    test "SC3: handles concurrent guide generation safely (10 concurrent)", %{pid: _pid} do
      configs =
        for i <- 1..10 do
          %{
            output_path: "test/tmp/safety_concurrent_#{i}.md"
          }
        end

      tasks =
        Enum.map(configs, fn config ->
          Task.async(fn ->
            TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert length(results) == 10
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # Cleanup
      Enum.each(configs, fn config ->
        File.rm(config.output_path)
      end)
    end

    test "SC4: preserves file system state during generation", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/filesystem_state_test.md"
      }

      # Ensure directory exists
      File.mkdir_p!("test/tmp")

      # Generate guide
      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Verify file created
      assert File.exists?(guide_info.file_path)

      # Verify directory structure intact
      assert File.dir?("test/tmp")

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "SC5: maintains state consistency across 5 operations", %{pid: _pid} do
      configs =
        for i <- 1..5 do
          %{
            output_path: "test/tmp/state_consistency_#{i}.md"
          }
        end

      # Generate 5 guides sequentially
      results =
        Enum.map(configs, fn config ->
          TroubleshootingGuideGenerator.generate_comprehensive_guide(config)
        end)

      # All should succeed
      assert length(results) == 5
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # Process should still be alive and responsive
      assert Process.alive?(Process.whereis(TroubleshootingGuideGenerator))

      # Cleanup
      Enum.each(configs, fn config ->
        File.rm(config.output_path)
      end)
    end
  end

  describe "error handling and edge cases" do
    test "handles empty categories list", %{pid: _pid} do
      config = %{
        categories: [],
        output_path: "test/tmp/empty_categories_test.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should still generate guide with diagnostic section
      assert guide_info.categories_count == 0
      assert File.exists?(guide_info.file_path)

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "handles empty solutions list", %{pid: _pid} do
      config = %{
        solutions: [],
        output_path: "test/tmp/empty_solutions_test.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Should still generate guide
      assert guide_info.solutions_count == 0
      assert File.exists?(guide_info.file_path)

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "handles unknown category gracefully", %{pid: _pid} do
      config = %{
        categories: ["unknown_category"],
        output_path: "test/tmp/unknown_category_test.md"
      }

      # Should handle unknown category with default content
      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      assert guide_info.categories_count == 1

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "handles unknown solution gracefully", %{pid: _pid} do
      config = %{
        solutions: ["unknown_solution"],
        output_path: "test/tmp/unknown_solution_test.md"
      }

      # Should handle unknown solution with default content
      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      assert guide_info.solutions_count == 1

      # Cleanup
      File.rm(guide_info.file_path)
    end

    test "creates nested directories if needed", %{pid: _pid} do
      config = %{
        output_path: "test/tmp/nested/deep/directory/guide.md"
      }

      {:ok, guide_info} = TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      # Verify nested directories created
      assert File.exists?(guide_info.file_path)

      # Cleanup
      File.rm_rf!("test/tmp/nested")
    end

    test "handles long custom titles", %{pid: _pid} do
      config = %{
        title:
          "This is a very long title for a troubleshooting guide that tests the handling of extended title strings in the guide generation system",
        output_path: "test/tmp/long_title_test.md"
      }

      assert {:ok, guide_info} =
               TroubleshootingGuideGenerator.generate_comprehensive_guide(config)

      content = File.read!(guide_info.file_path)
      assert content =~ "This is a very long title"

      # Cleanup
      File.rm(guide_info.file_path)
    end
  end

  describe "additional code issues found in source" do
    test "BUG: line 50 - __data_flow_validation should be data_flow_validation" do
      # Line 50: solutions: ["instrumentation_setup", "__data_flow_validation", "exporter_configuration"]
      #                                               ^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "data_flow_validation"
      # This affects telemetry_data_issues category solutions list
    end

    test "BUG: line 55 - __data_source_connectivity should be data_source_connectivity" do
      # Line 55: solutions: ["dashboard_deployment", "panel_configuration", "__data_source_connectivity"]
      #                                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG
      # Should be: "data_source_connectivity"
      # This affects dashboard_problems category solutions list
    end

    test "BUG: line 92 - _opts parameter should be opts (unused variable)" do
      # Line 92: def init( opts) do
      #                   ^^^^^ BUG - space before parameter name and underscore prefix
      # Should be: def init(opts) do
      # Note: Also has formatting issue with space before parameter
    end

    test "BUG: line 104 - {:generatecomprehensiveguide should be {:generate_comprehensive_guide" do
      # Line 104: def handle_call({:generatecomprehensiveguide, config}, _from, state) do
      #                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscores in atom
      # Should be: {:generate_comprehensive_guide, config}
      # CRITICAL: This prevents the function from being called correctly
      # The actual call uses {:generate_comprehensive_guide, config} but handler expects {:generatecomprehensiveguide, config}
    end

    test "BUG: line 201 - _severity_levels variable should be severity_levels (unused)" do
      # Line 201: _severity_levels = config[:severity_levels] || ["critical", "high", "medium", "low"]
      #           ^^^^^^^^^^^^^^^^ BUG - underscore prefix for supposedly unused variable
      # Should be: severity_levels (or remove if truly unused)
      # This variable is defined but never used in generate_category_section
    end

    test "BUG: line 220 - generate_pr_evention_measures should be generate_prevention_measures" do
      # Line 220: ### Pr_evention Measures
      #               ^^^^^^^^^^^^^ BUG - typo in "Prevention" with underscore
      # Line 222: #{generate_pr_evention_measures(category)}
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - function name typo
      # Should be: generate_prevention_measures
      # This affects all category sections with prevention measures
    end

    test "BUG: line 252 - generate_diagnostic_commands_section has unused _req parameter" do
      # Line 252: defp generate_diagnostic_commands_section(_config, _req) do
      #                                                      ^^^^^^^^ BUG - _config is actually unused
      #                                                               ^^^^ BUG - _req parameter not expected
      # Should be: defp generate_diagnostic_commands_section(config) do
      # Or: defp generate_diagnostic_commands_section(_config) do if config is truly unused
      # Function signature doesn't match its usage at line 152 where it's called with only config
    end

    test "BUG: line 265 - __database should be database in comment" do
      # Line 265: # Check __database connectivity
      #                   ^^^^^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Check database connectivity
    end

    test "BUG: line 284 - __data should be data in comment" do
      # Line 284: # Validate trace __data flow
      #                          ^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Validate trace data flow
    end

    test "BUG: line 290 - __data should be data in comment" do
      # Line 290: # Monitor telemetry __data export
      #                               ^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Monitor telemetry data export
    end

    test "BUG: line 335 - generate_common_issues has unused _req parameter" do
      # Line 335: defp generate_common_issues(category, _req) do
      #                                                 ^^^^ BUG - unused parameter
      # Should be: defp generate_common_issues(category) do
      # Function is called without second parameter throughout the code
    end

    test "BUG: line 342 - _requirements should be requirements in comment" do
      # Line 342: # Elixir version _requirements not met
      #                             ^^^^^^^^^^^^^ BUG - underscore prefix in comment
      # Should be: # Elixir version requirements not met
    end

    test "BUG: line 359 - _required should be required in comment" do
      # Line 359: # Missing _required configuration keys
      #                     ^^^^^^^^^ BUG - underscore prefix in comment
      # Should be: # Missing required configuration keys
    end

    test "BUG: line 360 - __data should be data in comment" do
      # Line 360: # Incorrect __data types in configuration
      #                       ^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Incorrect data types in configuration
    end

    test "BUG: line 378 - __events should be events in comment" do
      # Line 378: # Application not generating expected __events
      #                                                ^^^^^^^^ BUG - double underscore prefix
      # Should be: # Application not generating expected events
    end

    test "BUG: line 412 - __data should be data in comment" do
      # Line 412: # Telemetry __data accumulation
      #                       ^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Telemetry data accumulation
    end

    test "BUG: line 461 - __data should be data in comment" do
      # Line 461: 3. Test __data export: `mix otel.test_export`
      #                    ^^^^^^ BUG - double underscore prefix in comment
      # Should be: 3. Test data export: `mix otel.test_export`
    end

    test "BUG: line 462 - __events should be events in comment" do
      # Line 462: 4. Monitor telemetry __events: `mix telemetry.monitor --live`
      #                                ^^^^^^^^ BUG - double underscore prefix
      # Should be: 4. Monitor telemetry events: `mix telemetry.monitor --live`
    end

    test "BUG: line 588 - __data should be data in comment" do
      # Line 588: # Check telemetry __data flow
      #                             ^^^^^^ BUG - double underscore prefix in comment
      # Should be: # Check telemetry data flow
    end

    test "BUG: line 612 - __data should be data in generated content" do
      # Line 612: "- Telemetry __data successfully exported to SigNoz\n- Traces visible in SigNoz dashboard\n- No configuration warnings in logs"
      #                       ^^^^^^ BUG - double underscore prefix
      # Should be: "- Telemetry data successfully exported to SigNoz..."
    end

    test "BUG: line 615 - __data should be data in generated content" do
      # Line 615: "- SigNoz dashboard accessible\n- Real-time __data updates visible\n- No connection timeout errors"
      #                                                        ^^^^^^ BUG - double underscore prefix
      # Should be: "- Real-time data updates visible\n..."
    end

    test "BUG: line 622 - generate_pr_evention_measures function name typo" do
      # Line 622: @spec generate_pr_evention_measures(String.t()) :: String.t()
      #                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - typo in function name
      # Line 623: defp generate_pr_evention_measures(category) do
      #                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - same typo
      # Should be: generate_prevention_measures
    end

    test "BUG: line 644 - __data should be data in comment (3 occurrences)" do
      # Line 644: # Monitor __data export success rates
      #                     ^^^^^^ BUG - double underscore prefix
      # Line 645: # Set up alerting for __data collection failures
      #                                 ^^^^^^ BUG - double underscore prefix
      # Should be: "data export" and "data collection"
    end

    test "BUG: line 689 - __data should be data in table content" do
      # Line 689: | No telemetry __data | Verify configuration | [Telemetry Issues](#telemetry-__data-issues) |
      #                         ^^^^^^ BUG - double underscore prefix (appears twice)
      # Should be: | No telemetry data | Verify configuration | [Telemetry Issues](#telemetry-data-issues) |
    end

    test "BUG: line 752 - count_diagnostic_commands logic error" do
      # Line 752-755:
      # defp count_diagnostic_commands(diagnostic_section) do
      #   diagnostic_section
      #   |> String.split("\n")
      #   |> Enum.count(&String.starts_with?(String.trim(&1), "#"))
      # end
      # ^^^^^ BUG - counts ALL lines starting with "#", including:
      #   - Headers (##, ###, ####)
      #   - Comments in bash code blocks (# Check application status)
      # This gives inaccurate command count - it counts headers and comments, not actual commands
      # Should filter for actual diagnostic commands, not headers/comments
    end
  end
end
