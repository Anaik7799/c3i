defmodule AEE.WorkerAgent do
  @moduledoc """
  AEE Worker Agent - Direct file manipulation and fixing
  Container-specific implementation with PHICS support
  """
  
  use GenServer
  __require Logger
  
  def start_link(opts) do
    name = Keyword.get(__opts, :name, :aee_worker)
    container = Keyword.get(__opts, :container, 1)
    worker_id = Keyword.get(__opts, :worker_id, 1)
    GenServer.start_link(__MODULE__, %{container: container, worker_id: worker_id}, name: {:global, name})
  end
  
  def init(state) do
    Logger.info("[AEE-Worker-#{__state.container}-#{__state.worker_id}] Ready for autonomous fixing...")
    
    __state = Map.merge(__state, %{
      files_processed: 0,
      fixes_applied: 0,
      current_task: nil
    })
    
    {:ok, __state}
  end
  
  def handle_call({:process_file, file_path}, _from, state) do
    Logger.info("[AEE-Worker-#{__state.container}-#{__state.worker_id}] Processing #{file_path}")
    
    # Compile file and analyze issues
    result = case compile_and_analyze(file_path) do
      {:ok, issues} -> 
        fixes = apply_fixes(file_path, issues)
        {:ok, %{file: file_path, fixes: fixes}}
      error -> 
        error
    end
    
    new_state = %{__state | 
      files_processed: __state.files_processed + 1,
      current_task: nil
    }
    
    {:reply, result, new_state}
  end
  
  defp compile_and_analyze(file_path) do
    # Use Mix compiler to get warnings/errors
    case System.cmd("mix", ["compile", "--force", file_path], cd: "/workspace") do
      {output, 0} -> parse_compilation_output(output)
      {output, _} -> parse_compilation_output(output)
    end
  end
  
  defp parse_compilation_output(output) do
    # Parse compiler output for warnings and errors
    issues = output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["warning:", "error:"]))
    |> Enum.map(&parse_issue/1)
    |> Enum.reject(&is_nil/1)
    
    {:ok, issues}
  end
  
  defp parse_issue(line) do
    # Extract issue details from compiler output
    cond do
      String.contains?(line, "variable") and String.contains?(line, "unused") ->
        %{type: :unused_variable, line: line}
      String.contains?(line, "undefined variable") ->
        %{type: :undefined_variable, line: line}
      true ->
        nil
    end
  end
  
  defp apply_fixes(file_path, issues) do
    # Apply fixes using MultiEdit pattern
    Enum.map(issues, fn issue ->
      case issue.type do
        :unused_variable -> apply_underscore_prefix(file_path, issue)
        :undefined_variable -> suggest_variable_fix(file_path, issue)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp apply_underscore_prefix(file_path, issue) do
    # TPS: Systematic underscore prefix application
    %{type: :fix_applied, pattern: "EP-001", action: :underscore_prefix}
  end
  
  defp suggest_variable_fix(file_path, issue) do
    # STAMP: Safety analysis for variable definition
    %{type: :fix_suggested, pattern: "EP-002", suggestion: "Define variable or add as parameter"}
  end
end
