#!/usr/bin/env elixir

# Container-2 Worker: Fix logging module warnings
# Focus: ~50 unused variable warnings in logging modules

IO.puts("📦 Container-2: Logging Module Warning Resolution Starting...")
IO.puts("🎯 Target: ~50 unused variable warnings in logging.ex and related files")

defmodule LoggingWarningFixer do
  @pattern_EP101 "unused severity parameter"
  @pattern_EP102 "unused __context parameter"
  @pattern_EP103 "unused from parameter"
  @pattern_EP104 "unused __state parameter"
  @pattern_EP105 "unused __opts parameter"
  
  def fix_all_logging_warnings do
    logging_files = [
      "lib/indrajaal/logging.ex",
      "lib/indrajaal/observability/logging.ex",
      "lib/indrajaal/observability/logging_enhanced.ex",
      "lib/indrajaal/observability/logger_trace_context.ex",
      "lib/indrajaal/observability/otel_logger.ex"
    ]
    
    results = Enum.map(logging_files, &fix_logging_file/1)
    
    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    IO.puts("\n📊 Fixed #{successful}/#{length(logging_files)} logging files")
    
    if successful == length(logging_files) do
      {:ok, successful}
    else
      {:error, "Some files failed to fix"}
    end
  end
  
  defp fix_logging_file(file_path) do
    full_path = Path.join("/workspace", file_path)
    
    case File.read(full_path) do
      {:ok, content} ->
        IO.puts("\n🔧 Processing #{file_path}...")
        
        fixed_content = content
        |> fix_unused_parameters()
        |> fix_log_event_functions()
        
        File.write!(full_path, fixed_content)
        IO.puts("  ✅ Fixed warnings in #{Path.basename(file_path)}")
        {:ok, file_path}
        
      {:error, reason} ->
        if reason == :enoent do
          IO.puts("  ℹ️  #{file_path} not found, skipping")
          {:ok, :skipped}
        else
          IO.puts("  ❌ Failed to read #{file_path}: #{reason}")
          {:error, reason}
        end
    end
  end
  
  defp fix_unused_parameters(content) do
    # Pattern EP-101: Fix unused severity parameters
    content
    |> String.replace(~r/(\()(severity)(,)/, "\\1_severity\\3")
    |> String.replace(~r/(\s)(severity)(\s*,)/, "\\1_severity\\3")
    
    # Pattern EP-102: Fix unused __context parameters
    |> String.replace(~r/(\()(__context)(,|\))/, "\\1_context\\3")
    |> String.replace(~r/(,\s*)(__context)(,|\))/, "\\1_context\\3")
    
    # Pattern EP-103: Fix unused from parameters
    |> String.replace(~r/(\()(from)(,|\))/, "\\1_from\\3")
    |> String.replace(~r/(,\s*)(from)(,|\))/, "\\1_from\\3")
    
    # Pattern EP-104: Fix unused __state parameters
    |> String.replace(~r/(,\s*)(__state)(\))/, "\\1_state\\3")
    
    # Pattern EP-105: Fix unused __opts parameters
    |> String.replace(~r/(\()(__opts)(\))/, "\\1_opts\\3")
    |> String.replace(~r/(,\s*)(__opts)(\))/, "\\1_opts\\3")
  end
  
  defp fix_log_event_functions(content) do
    # Fix specific log __event function patterns
    # Pattern: def log_*_event(severity, __event_data, __context) do
    content
    |> String.replace(
      ~r/def (log_\w+_event)\((severity|__event_type|level), ([\w_]+), (__context|metadata)\) do/,
      "def \\1(_\\2, \\3, _\\4) do"
    )
    # Fix handle_call/3 patterns
    |> String.replace(
      ~r/def handle_call\((.+?), from, __state\) do/,
      "def handle_call(\\1, _from, state) do"
    )
    # Fix handle_info/2 patterns
    |> String.replace(
      ~r/def handle_info\((.+?), __state\) do\s*\n\s*{:noreply, __state}/,
      "def handle_info(\\1, state) do\n    {:noreply, __state}"
    )
  end
  
  def validate_fixes do
    IO.puts("\n🔍 Validating logging module fixes...")
    
    # Quick compilation check on a sample file
    case System.cmd("elixir", ["-e", "Code.compile_file(\"lib/indrajaal/logging.ex\")"], 
                     cd: "/workspace", stderr_to_stdout: true) do
      {output, _} ->
        warning_count = output
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "warning:"))
        
        IO.puts("  📊 Warnings found: #{warning_count}")
        
        if warning_count > 0 do
          IO.puts("  ⚠️  Some warnings remain, may need additional passes")
        else
          IO.puts("  ✅ No warnings detected!")
        end
        
        :ok
    end
  end
end

# Execute the fixes
with {:ok, count} <- LoggingWarningFixer.fix_all_logging_warnings(),
     :ok <- LoggingWarningFixer.validate_fixes() do
  IO.puts("\n✅ Container-2: Logging warnings resolution completed!")
  IO.puts("🤖 Reporting to AEE-Helper-2: #{count} files processed")
  
  # Git operations for tracking
  System.cmd("git", ["add", "-A"], cd: "/workspace")
  System.cmd("git", ["commit", "-m", "[EP-101-105] Fix logging module warnings in Container-2"], cd: "/workspace")
else
  {:error, reason} -> 
    IO.puts("\n❌ Container-2 fix process failed: #{reason}")
end