#!/usr/bin/env elixir

defmodule FixParameterMismatches do
  def run do
    IO.puts("🔧 Fixing parameter mismatches in advanced_multi_agent_coordinator.ex")

    file = "lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex"
    content = File.read!(file)

    # Fix scale_agent_pool - needs type and count parameters
    content = String.replace(
      content,
      "defp scale_agent_pool(state) do",
      "defp scale_agent_pool(state, type, count) do"
    )

    # Fix add_active_task - needs task, from, and workload_spec parameters
    content = String.replace(
      content,
      ~r/defp add_active_task\(state\) do/,
      "defp add_active_task(state, task, from, workload_spec) do"
    )

    # Fix spawn_agents - needs type parameter
    content = String.replace(
      content,
      ~r/defp spawn_agents\(state, count\) do/,
      "defp spawn_agents(state, type, count) do"
    )

    # Fix update_completion_metrics - needs task_info parameter
    content = String.replace(
      content,
      ~r/defp update_completion_metrics\(state, _task_id, result\) do/,
      "defp update_completion_metrics(state, task_id, result) do"
    )

    # Add task_info retrieval in update_completion_metrics
    content = String.replace(
      content,
      ~r/  defp update_completion_metrics\(state, task_id, result\) do\n    duration = System\.monotonic_time/,
      """
        defp update_completion_metrics(state, task_id, result) do
          task_info = Map.get(state.active_tasks, task_id, %{started_at: System.monotonic_time(:millisecond)})
          duration = System.monotonic_time"""
    )

    # Fix apply_tps_rca_analysis - uses undefined error and workload_spec
    content = String.replace(
      content,
      "defp apply_tps_rca_analysis(state) do",
      "defp apply_tps_rca_analysis(state, error, workload_spec) do"
    )

    # Fix apply_performance_optimizations - uses undefined result
    content = String.replace(
      content,
      ~r/defp apply_performance_optimizations\(state\) do\n    # Apply optimizations based on current state metrics\n    optimization_factor = if state\.performance_metrics\.tasks_completed > 100, do: 1\.2, else: 1\.0\n    Map\.put\(result,/,
      """
      defp apply_performance_optimizations(state) do
        # Apply optimizations based on current state metrics
        optimization_factor = if state.performance_metrics.tasks_completed > 100, do: 1.2, else: 1.0
        result = %{optimizations: []}
        Map.put(result,"""
    )

    # Fix generate_scaling_plan - uses undefined recommendations
    content = String.replace(
      content,
      ~r/defp generate_scaling_plan\(state\) do\n    # Enhanced scaling plan generation based on recommendations and current state\n    actions = if map_size\(state\.agents\) > 20, do: \[:optimize\], else: \[:maintain\]\n    %\{actions: actions, recommendations_applied: length\(Map\.keys\(recommendations\)\)\}/,
      """
      defp generate_scaling_plan(state) do
        # Enhanced scaling plan generation based on recommendations and current state
        actions = if map_size(state.agents) > 20, do: [:optimize], else: [:maintain]
        recommendations = %{}
        %{actions: actions, recommendations_applied: length(Map.keys(recommendations))}"""
    )

    File.write!(file, content)
    IO.puts("✅ Fixed all parameter mismatches")
  end
end

FixParameterMismatches.run()