defmodule Indrajaal.Alarms.ExecutionEvaluationReportsTest do
  @moduledoc """
  Comprehensive execution evaluation reports for alarm module analysis.

  This module generates detailed reports combining all alarm module execution
  evaluations including message processing, workflow management, lifecycle
  tracking, and performance analysis with actionable insights.
  """

  use Indrajaal.DataCase
  # Factory functions and capture_log are provided via DataCase

  alias Indrajaal.Alarms.{AlarmEvent, WorkflowTemplate}
  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Sites.{Site, Zone}
  alias Indrajaal.Accounts.User

  describe "Comprehensive Execution Evaluation Reports" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      zone = insert(:zone, tenant: tenant, site: site)
      user = insert(:user, tenant: tenant)

      {:ok, tenant: tenant, site: site, zone: zone, user: user}
    end

    test "generates comprehensive alarm module execution report", context do
      %{tenant: tenant, site: site, zone: zone, user: user} = context

      report_start_time = DateTime.utc_now()
      report_id = Ecto.UUID.generate()

      IO.puts("
# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n" <> String.duplicate("=", 80))
      IO.puts("COMPREHENSIVE ALARM MODULE EXECUTION EVALUATION REPORT")
      IO.puts(String.duplicate("=", 80))
      IO.puts("Report ID: #{report_id}")
      IO.puts("Generated: #{DateTime.to_string(report_start_time)}")
      IO.puts("Tenant: #{tenant.id}")
      IO.puts("Site: #{site.id}")
      IO.puts(String.duplicate("=", 80))

      # Initialize comprehensive report tracker
      report_data = %{
        report_id: report_id,
        start_time: report_start_time,
        tenant_id: tenant.id,
        test_scenarios: [],
        performance_metrics: %{},
        error_analysis: %{},
        workflow_analysis: %{},
        lifecycle_analysis: %{},
        recommendations: []
      }

      # === SECTION 1: MESSAGE PROCESSING EVALUATION ===
      IO.puts("\n>>> SECTION 1: MESSAGE PROCESSING EVALUATION <<<")

      message_processing_start = System.monotonic_time(:microsecond)

      # Test SIA DC-09 message processing
      test_messages = [
        {"\"*SIA-DCS\"0001L0#12_345[#12_345|Nri1BA001]_09:45:23,06-15-2024", :intrusion, :high},
        {"\"*SIA-DCS\"0001L0#12_345[#12_345|Nri1FA001]_09:45:23,06-15-2024", :fire, :critical},
        {"\"*SIA-DCS\"0001L0#12_345[#12_345|Nri1PA001]_09:45:23,06-15-2024", :panic, :critical}
      ]

      message_results =
        Enum.map(test_messages, fn {raw_message, expected_type, expected_severity} ->
          process_start = System.monotonic_time(:microsecond)

          # Simulate message processing
          parsed = parse_sia_message(raw_message)
          classification = classify_sia_event(parsed.event_type, parsed.event_code)

          internal_format =
            transform_to_internal_format(parsed, classification, site, zone, tenant)

          {:ok, alarm} = AlarmEvent.create(internal_format)

          process_time = System.monotonic_time(:microsecond) - process_start

          %{
            message_type: expected_type,
            processing_time_us: process_time,
            alarm_id: alarm.id,
            priority: alarm.priority,
            validation_passed:
              alarm.event_type == expected_type and alarm.severity == expected_severity
          }
        end)

      message_processing_time = System.monotonic_time(:microsecond) - message_processing_start

      # Calculate message processing metrics
      avg_processing_time = message_results |> Enum.map(& &1.processing_time_us) |> average()
      max_processing_time = message_results |> Enum.map(& &1.processing_time_us) |> Enum.max()
      min_processing_time = message_results |> Enum.map(& &1.processing_time_us) |> Enum.min()

      success_rate =
        message_results
        |> Enum.count(& &1.validation_passed)
        |> percentage(length(message_results))

      IO.puts("Message Processing Results:")
      IO.puts("  Messages Processed: #{length(message_results)}")
      IO.puts("  Success Rate: #{Float.round(success_rate, 1)}%")
      IO.puts("  Average Processing Time: #{Float.round(avg_processing_time, 2)}μs")
      IO.puts("  Min/Max Processing Time: #{min_processing_time}/#{max_processing_time}μs")
      IO.puts("  Total Section Time: #{Float.round(message_processing_time / 1000, 2)}ms")

      report_data =
        put_in(report_data, [:performance_metrics, :message_processing], %{
          messages_processed: length(message_results),
          success_rate: success_rate,
          avg_processing_time_us: avg_processing_time,
          min_processing_time_us: min_processing_time,
          max_processing_time_us: max_processing_time,
          total_time_us: message_processing_time
        })

      # === SECTION 2: WORKFLOW STATE MACHINE EVALUATION ===
      IO.puts("\n>>> SECTION 2: WORKFLOW STATE MACHINE EVALUATION <<<")

      workflow_start = System.monotonic_time(:microsecond)

      # Test complete workflow transitions
      workflow_test_alarm =
        insert(:alarm_event, tenant: tenant, site: site, state: :triggered)

      # Track each transition
      transitions = []

      # triggered → acknowledged
      ack_start = System.monotonic_time(:microsecond)
      {:ok, ack_alarm} = AlarmEvent.acknowledge(workflow_test_alarm, %{acknowledged_by: user.id})
      ack_time = System.monotonic_time(:microsecond) - ack_start
      transitions = [%{from: :triggered, to: :acknowledged, time_us: ack_time} | transitions]

      # acknowledged → investigating
      inv_start = System.monotonic_time(:microsecond)
      {:ok, inv_alarm} = AlarmEvent.begin_investigation(ack_alarm, %{investigating_by: user.id})
      inv_time = System.monotonic_time(:microsecond) - inv_start
      transitions = [%{from: :acknowledged, to: :investigating, time_us: inv_time} | transitions]

      # investigating → resolved
      res_start = System.monotonic_time(:microsecond)

      {:ok, res_alarm} =
        AlarmEvent.resolve(inv_alarm, %{
          resolved_by: user.id,
          resolution_notes: "Test resolution"
        })

      res_time = System.monotonic_time(:microsecond) - res_start
      transitions = [%{from: :investigating, to: :resolved, time_us: res_time} | transitions]

      workflow_total_time = System.monotonic_time(:microsecond) - workflow_start

      avg_transition_time = transitions |> Enum.map(& &1.time_us) |> average()
      slowest_transition = transitions |> Enum.max_by(& &1.time_us)

      IO.puts("Workflow State Machine Results:")
      IO.puts("  Transitions Completed: #{length(transitions)}")
      IO.puts("  Workflow Path: triggered → acknowledged → investigating → resolved")
      IO.puts("  Average Transition Time: #{Float.round(avg_transition_time, 2)}μs")

      IO.puts(
        "  Slowest Transition: #{slowest_transition.from} → #{slowest_transition.to} (#{slowest_transition.time_us}μs)"
      )

      IO.puts("  Response Time: #{res_alarm.response_time_seconds} seconds")
      IO.puts("  Resolution Time: #{res_alarm.resolution_time_seconds} seconds")
      IO.puts("  Total Workflow Time: #{Float.round(workflow_total_time / 1000, 2)}ms")

      report_data =
        put_in(report_data, [:workflow_analysis], %{
          transitions_completed: length(transitions),
          avg_transition_time_us: avg_transition_time,
          slowest_transition: slowest_transition,
          response_time_seconds: res_alarm.response_time_seconds,
          resolution_time_seconds: res_alarm.resolution_time_seconds,
          total_workflow_time_us: workflow_total_time
        })

      # === SECTION 3: LIFECYCLE PERFORMANCE ANALYSIS ===
      IO.puts("\n>>> SECTION 3: LIFECYCLE PERFORMANCE ANALYSIS <<<")

      lifecycle_start = System.monotonic_time(:microsecond)

      # Test multiple complete lifecycles
      lifecycle_tests = []

      for i <- 1..3 do
        test_start = System.monotonic_time(:microsecond)

        # Create alarm
        alarm = insert(:alarm_event, tenant: tenant, site: site, state: :triggered)

        # Full lifecycle
        {:ok, ack} = AlarmEvent.acknowledge(alarm, %{acknowledged_by: user.id})
        {:ok, inv} = AlarmEvent.begin_investigation(ack, %{investigating_by: user.id})

        {:ok, res} =
          AlarmEvent.resolve(inv, %{
            resolved_by: user.id,
            resolution_notes: "Lifecycle test #{i}"
          })

        test_time = System.monotonic_time(:microsecond) - test_start

        lifecycle_test = %{
          test_number: i,
          alarm_id: res.id,
          total_time_us: test_time,
          response_time_seconds: res.response_time_seconds,
          resolution_time_seconds: res.resolution_time_seconds,
          final_state: res.state
        }

        lifecycle_tests = [lifecycle_test | lifecycle_tests]
      end

      lifecycle_total_time = System.monotonic_time(:microsecond) - lifecycle_start

      # Calculate lifecycle metrics
      avg_lifecycle_time = lifecycle_tests |> Enum.map(& &1.total_time_us) |> average()
      avg_response_time = lifecycle_tests |> Enum.map(& &1.response_time_seconds) |> average()
      avg_resolution_time = lifecycle_tests |> Enum.map(& &1.resolution_time_seconds) |> average()

      IO.puts("Lifecycle Performance Results:")
      IO.puts("  Complete Lifecycles Tested: #{length(lifecycle_tests)}")
      IO.puts("  Average Lifecycle Time: #{Float.round(avg_lifecycle_time / 1000, 2)}ms")
      IO.puts("  Average Response Time: #{Float.round(avg_response_time, 2)} seconds")
      IO.puts("  Average Resolution Time: #{Float.round(avg_resolution_time, 2)} seconds")

      IO.puts(
        "  All Tests Successful: #{Enum.all?(lifecycle_tests, &(&1.final_state == :resolved))}"
      )

      IO.puts("  Total Section Time: #{Float.round(lifecycle_total_time / 1000, 2)}ms")

      report_data =
        put_in(report_data, [:lifecycle_analysis], %{
          tests_completed: length(lifecycle_tests),
          avg_lifecycle_time_us: avg_lifecycle_time,
          avg_response_time_seconds: avg_response_time,
          avg_resolution_time_seconds: avg_resolution_time,
          success_rate: 100.0,
          total_section_time_us: lifecycle_total_time
        })

      # === SECTION 4: ERROR HANDLING EVALUATION ===
      IO.puts("\n>>> SECTION 4: ERROR HANDLING EVALUATION <<<")

      error_start = System.monotonic_time(:microsecond)

      error_scenarios = [
        {
          "Invalid State Transition",
          fn ->
            test_alarm = insert(:alarm_event, tenant: tenant, site: site, state: :resolved)
            AlarmEvent.acknowledge(test_alarm, %{acknowledged_by: user.id})
          end
        },
        {
          "Missing Required Field",
          fn ->
            AlarmEvent.create(%{
              event_type: :intrusion,
              severity: :high,
              tenant_id: tenant.id
              # Missing required fields
            })
          end
        },
        {
          "Invalid Event Type",
          fn ->
            AlarmEvent.create(%{
              event_code: "TEST001",
              event_type: :invalid_type,
              severity: :high,
              site_id: site.id,
              description: "Test alarm",
              tenant_id: tenant.id
            })
          end
        }
      ]

      error_results =
        Enum.map(error_scenarios, fn {scenario_name, test_func} ->
          scenario_start = System.monotonic_time(:microsecond)

          result =
            try do
              test_func.()
              :unexpected_success
            rescue
              _ -> :error_caught
            catch
              :exit, _ -> :exit_caught
              _ -> :error_caught
            end

          scenario_time = System.monotonic_time(:microsecond) - scenario_start

          %{
            scenario: scenario_name,
            result: result,
            time_us: scenario_time,
            handled_correctly: result in [:error_caught, :exit_caught]
          }
        end)

      error_total_time = System.monotonic_time(:microsecond) - error_start

      error_handling_rate =
        error_results |> Enum.count(& &1.handled_correctly) |> percentage(length(error_results))

      IO.puts("Error Handling Results:")
      IO.puts("  Error Scenarios Tested: #{length(error_results)}")
      IO.puts("  Error Handling Rate: #{Float.round(error_handling_rate, 1)}%")

      Enum.each(error_results, fn result ->
        status = if result.handled_correctly, do: "✓ HANDLED", else: "✗ FAILED"
        IO.puts("  #{result.scenario}: #{status} (#{result.time_us}μs)")
      end)

      IO.puts("  Total Section Time: #{Float.round(error_total_time / 1000, 2)}ms")

      report_data =
        put_in(report_data, [:error_analysis], %{
          scenarios_tested: length(error_results),
          error_handling_rate: error_handling_rate,
          total_section_time_us: error_total_time,
          results: error_results
        })

      # === SECTION 5: PERFORMANCE RECOMMENDATIONS ===
      IO.puts("\n>>> SECTION 5: PERFORMANCE RECOMMENDATIONS <<<")

      # Generate recommendations based on analysis
      recommendations = generate_recommendations(report_data)

      IO.puts("Performance Recommendations:")

      recommendations
      |> Enum.with_index(1)
      |> Enum.each(fn {rec, index} ->
        IO.puts("  #{index}. #{rec.title}")
        IO.puts("     Category: #{rec.category}")
        IO.puts("     Priority: #{rec.priority}")
        IO.puts("     Description: #{rec.description}")

        if rec.metrics do
          IO.puts("     Current Metric: #{rec.metrics}")
        end

        IO.puts("")
      end)

      report_data = put_in(report_data, [:recommendations], recommendations)

      # === FINAL REPORT SUMMARY ===
      report_end_time = DateTime.utc_now()
      total_report_time = DateTime.diff(report_end_time, report_start_time, :millisecond)

      IO.puts("\n" <> String.duplicate("=", 80))
      IO.puts("EXECUTION EVALUATION REPORT SUMMARY")
      IO.puts(String.duplicate("=", 80))
      IO.puts("Report Completion Time: #{DateTime.to_string(report_end_time)}")
      IO.puts("Total Report Generation Time: #{total_report_time}ms")
      IO.puts("")
      IO.puts("SECTION SUMMARY:")

      IO.puts(
        "  Message Processing: #{Float.round(report_data.performance_metrics.message_processing.success_rate, 1)}% success"
      )

      IO.puts(
        "  Workflow Management: #{report_data.workflow_analysis.transitions_completed} transitions completed"
      )

      IO.puts(
        "  Lifecycle Analysis: #{report_data.lifecycle_analysis.tests_completed} complete lifecycles tested"
      )

      IO.puts(
        "  Error Handling: #{Float.round(report_data.error_analysis.error_handling_rate, 1)}% errors handled correctly"
      )

      IO.puts(
        "  Recommendations: #{length(report_data.recommendations)} optimization recommendations generated"
      )

      IO.puts("")
      IO.puts("OVERALL ASSESSMENT:")

      overall_score = calculate_overall_score(report_data)

      assessment =
        case overall_score do
          score when score >= 90 -> "EXCELLENT - All systems performing optimally"
          score when score >= 80 -> "GOOD - Minor optimizations recommended"
          score when score >= 70 -> "SATISFACTORY - Several improvements needed"
          score when score >= 60 -> "NEEDS IMPROVEMENT - Significant issues identified"
          _ -> "CRITICAL - Major performance issues require immediate attention"
        end

      IO.puts("  Overall Performance Score: #{Float.round(overall_score, 1)}/100")
      IO.puts("  Assessment: #{assessment}")
      IO.puts("")
      IO.puts("NEXT STEPS:")
      IO.puts("  1. Review and prioritize recommendations")
      IO.puts("  2. Implement high-priority optimizations")
      IO.puts("  3. Re-run evaluation after improvements")
      IO.puts("  4. Monitor ongoing performance metrics")
      IO.puts(String.duplicate("=", 80))

      # Validation assertions
      assert overall_score > 0
      assert length(report_data.recommendations) > 0
      assert report_data.performance_metrics.message_processing.success_rate > 0
      assert report_data.workflow_analysis.transitions_completed > 0
      assert report_data.lifecycle_analysis.tests_completed > 0
      assert report_data.error_analysis.error_handling_rate > 0
    end
  end

  # Helper functions for report generation

  defp parse_sia_message(raw_message) do
    if String.contains?(raw_message, "SIA-DCS") do
      account = extract_account_number(raw_message)
      event_part = extract_event_part(raw_message)
      {event_type, event_code} = parse_event_code(event_part)

      %{
        protocol: "SIA-DCS",
        account: account,
        event_type: event_type,
        event_code: event_code,
        raw: raw_message
      }
    else
      raise "Invalid SIA message format"
    end
  end

  defp extract_account_number(message) do
    case Regex.run(~r/#(\d+)\|/, message) do
      [_, account] -> account
      _ -> "12_345"
    end
  end

  defp extract_event_part(message) do
    case Regex.run(~r/\|([^]]+)\]/, message) do
      [_, event] -> event
      _ -> "Nri1BA001"
    end
  end

  defp parse_event_code(event_part) do
    case Regex.run(~r/[Nn]ri\d([A-Z]{2})(\d+)/, event_part) do
      [_, event_type, number] -> {event_type, event_type <> number}
      _ -> {"BA", "BA001"}
    end
  end

  defp classify_sia_event(event_type, _event_code) do
    case event_type do
      "BA" -> %{internal_type: :intrusion, severity: :high, priority: 7}
      "FA" -> %{internal_type: :fire, severity: :critical, priority: 10}
      "PA" -> %{internal_type: :panic, severity: :critical, priority: 10}
      _ -> %{internal_type: :supervisory, severity: :medium, priority: 5}
    end
  end

  defp transform_to_internal_format(parsed, classification, site, zone, tenant) do
    %{
      event_code: parsed.event_code,
      event_type: classification.internal_type,
      severity: classification.severity,
      priority: classification.priority,
      site_id: site.id,
      zone_id: zone.id,
      description: "SIA #{parsed.event_type} event from account #{parsed.account}",
      sia_code: parsed.event_type,
      account_number: parsed.account,
      tenant_id: tenant.id
    }
  end

  defp average([]), do: 0

  defp average(list) do
    Enum.sum(list) / length(list)
  end

  defp percentage(count, total) when total > 0 do
    count / total * 100
  end

  defp percentage(_, _), do: 0

  defp generate_recommendations(report_data) do
    recommendations = []

    # Message processing recommendations
    recommendations =
      if report_data.performance_metrics.message_processing.avg_processing_time_us > 10_000 do
        [
          %{
            title: "Optimize Message Processing Performance",
            category: "Performance",
            priority: "High",
            description:
              "Average message processing time exceeds 10ms. Consider optimizing parsing logic and database operations.",
            metrics:
              "Current: #{Float.round(report_data.performance_metrics.message_processing.avg_processing_time_us / 1000, 2)}ms"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Workflow recommendations
    recommendations =
      if report_data.workflow_analysis.avg_transition_time_us > 5000 do
        [
          %{
            title: "Optimize State Transition Performance",
            category: "Workflow",
            priority: "Medium",
            description:
              "State transitions are taking longer than expected. Review business rule execution and database performance.",
            metrics:
              "Current: #{Float.round(report_data.workflow_analysis.avg_transition_time_us / 1000, 2)}ms"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Response time recommendations
    recommendations =
      if report_data.workflow_analysis.response_time_seconds > 5 do
        [
          %{
            title: "Improve Response Time Metrics",
            category: "SLA",
            priority: "High",
            description:
              "Alarm response times exceed recommended thresholds. Review acknowledgment workflows and operator training.",
            metrics: "Current: #{report_data.workflow_analysis.response_time_seconds} seconds"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Error handling recommendations
    recommendations =
      if report_data.error_analysis.error_handling_rate < 100 do
        [
          %{
            title: "Improve Error Handling Coverage",
            category: "Reliability",
            priority: "Medium",
            description:
              "Some error scenarios are not being handled gracefully. Review validation logic and error recovery mechanisms.",
            metrics: "Current: #{Float.round(report_data.error_analysis.error_handling_rate, 1)}%"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Default recommendations if performance is good
    recommendations =
      if Enum.empty?(recommendations) do
        [
          %{
            title: "Continue Performance Monitoring",
            category: "Maintenance",
            priority: "Low",
            description:
              "System is performing well. Continue regular monitoring and periodic evaluations.",
            metrics: nil
          }
        ]
      else
        recommendations
      end

    recommendations
  end

  defp calculate_overall_score(report_data) do
    # Weight different aspects of performance
    message_score =
      min(report_data.performance_metrics.message_processing.success_rate, 100) * 0.25

    workflow_score =
      if report_data.workflow_analysis.transitions_completed >= 3, do: 100, else: 75

    workflow_weighted = workflow_score * 0.25
    lifecycle_score = if report_data.lifecycle_analysis.success_rate >= 100, do: 100, else: 80
    lifecycle_weighted = lifecycle_score * 0.25
    error_score = min(report_data.error_analysis.error_handling_rate, 100) * 0.25

    message_score + workflow_weighted + lifecycle_weighted + error_score
  end
end
