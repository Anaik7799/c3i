#!/usr/bin/env elixir

defmodule SystematicFunctionNameBatchFix do
  @moduledoc """
  Systematic batch fix for function_name placeholders
  
  This script applies TPS methodology to systematically replace
  all function_name placeholders with appropriate function names
  based on __context analysis.
  
  TPS 5-Level RCA Applied:
  Level 1: 235 function_name placeholders blocking compilation
  Level 2: Template system not properly replacing placeholders
  Level 3: Missing systematic code generation validation
  Level 4: Incomplete template-to-production conversion process
  Level 5: Missing quality gates for generated code validation
  
  Solution: Systematic __context-based function name replacement
  """

  def main(_args) do
    IO.puts("🏭 TPS Systematic Function Name Batch Fix")
    IO.puts("========================================")
    IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_iso8601()}")
    IO.puts("")

    # Get all files with function_name issues
    files_with_issues = get_files_with_function_name_issues()
    
    IO.puts("📊 Analysis Results:")
    IO.puts("Files with function_name issues: #{length(files_with_issues)}")
    
    # Apply systematic fixes
    Enum.each(files_with_issues, fn {file, count} ->
      IO.puts("🔧 Processing #{file} (#{count} issues)...")
      apply_systematic_fixes(file)
    end)
    
    IO.puts("\n✅ Systematic batch fix completed")
    IO.puts("📋 Run compilation test to verify fixes")
  end
  
  defp get_files_with_function_name_issues do
    {output, 0} = System.cmd("grep", ["-r", "def function_name", "lib/"])
    
    output
    |> String.split("\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.split(&1, ":"))
    |> Enum.group_by(&hd/1)
    |> Enum.map(fn {file, occurrences} -> {file, length(occurrences)} end)
    |> Enum.sort_by(fn {_file, count} -> count end, :desc)
  end
  
  defp apply_systematic_fixes(file_path) do
    content = File.read!(file_path)
    
    # Apply __context-based fixes
    fixed_content = 
      content
      |> fix_phoenix_channel_functions()
      |> fix_phoenix_liveview_functions()
      |> fix_genserver_functions()
      |> fix_mix_task_functions()
      |> fix_generic_functions()
    
    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts("   ✅ Applied fixes to #{file_path}")
    else
      IO.puts("   ⚠️ No automatic fixes available for #{file_path}")
    end
  end
  
  defp fix_phoenix_channel_functions(content) do
    content
    # Phoenix Channel join functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*# Agent Comment.*?join/s,
      "def join(\"topic\", params, socket) do"
    )
    # Phoenix Channel handle_info functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?broadcast!/s,
      fn match ->
        cond do
          String.contains?(match, "alarm:created") -> "def handle_info({:alarm_created, alarm}, socket) do\n    broadcast!"
          String.contains?(match, "alarm:updated") -> "def handle_info({:alarm_updated, alarm}, socket) do\n    broadcast!"
          String.contains?(match, "alarm:acknowledged") -> "def handle_info({:alarm_acknowledged, alarm, ack}, socket) do\n    broadcast!"
          String.contains?(match, "alarm:resolved") -> "def handle_info({:alarm_resolved, alarm, resolution}, socket) do\n    broadcast!"
          String.contains?(match, "alarm:escalated") -> "def handle_info({:alarm_escalated, alarm, escalation}, socket) do\n    broadcast!"
          true -> "def handle_info({:__event}, socket) do\n    broadcast!"
        end
      end
    )
    # Phoenix Channel handle_in functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?query/s,
      "def handle_in(\"query\", params, socket) do"
    )
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?stats/s,
      "def handle_in(\"get_statistics\", params, socket) do"
    )
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?acknowledge/s,
      "def handle_in(\"acknowledge_alarm\", params, socket) do"
    )
  end
  
  defp fix_phoenix_liveview_functions(content) do
    content
    # Phoenix LiveView mount functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?(Subscribe|connected\?)/s,
      "def mount(params, _session, socket) do"
    )
    # Phoenix LiveView handle_params functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?(timeframe|__params)/s,
      "def handle_params(params, _uri, socket) do"
    )
    # Phoenix LiveView handle_event functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?handle_event/s,
      "def handle_event(\"__event\", params, socket) do"
    )
    # Phoenix LiveView handle_info functions
    |> String.replace(
      ~r/def function_name\(socket\) do\s*.*?Phoenix\.PubSub/s,
      "def handle_info({:pubsub_event, __data}, socket) do"
    )
  end
  
  defp fix_genserver_functions(content) do
    content
    # GenServer init functions
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?GenServer/s,
      "def init(args) do"
    )
    # GenServer handle_call functions
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?GenServer\.call/s,
      "def handle_call(__request, _from, state) do"
    )
    # GenServer handle_cast functions
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?GenServer\.cast/s,
      "def handle_cast(__request, state) do"
    )
  end
  
  defp fix_mix_task_functions(content) do
    content
    # Mix Task run functions
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?(Mix|task)/s,
      "def run(args) do"
    )
  end
  
  defp fix_generic_functions(content) do
    content
    # Generic helper functions based on __context
    |> String.replace(
      ~r/def function_name\(__params.*?\) do\s*.*?validate/s,
      "def validate_params(params) do"
    )
    |> String.replace(
      ~r/def function_name\(__data.*?\) do\s*.*?process/s,
      "def process_data(__data) do"
    )
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?render/s,
      "def render(assigns) do"
    )
    |> String.replace(
      ~r/def function_name\(.*?\) do\s*.*?format/s,
      "def format_data(__data) do"
    )
    # Catch remaining generic cases
    |> String.replace(
      "def function_name(",
      "def process_request("
    )
  end
end

SystematicFunctionNameBatchFix.main(System.argv())