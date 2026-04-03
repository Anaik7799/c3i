#!/usr/bin/env elixir

# Batch Verification Fixer Script
# Follows CLAUDE.md rules for batch verification with max 25 changes

defmodule LocalTime do
  def timestamp_string do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    timezone = System.get_env("TZ", "CEST")
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B ~s", 
      [year, month, day, hour, minute, second, timezone])
    |> to_string()
  end
  
  def for_git do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", 
      [year, month, day, hour, minute, second])
    |> to_string()
  end
end

defmodule BatchVerificationFixer do
  @max_batch_size 25
  @container_path "/workspace"
  
  def run(args \\ []) do
    IO.puts("🚀 Batch Verification Fixer Starting...")
    IO.puts("📅 Started at: #{LocalTime.timestamp_string()}")
    IO.puts("📦 Maximum batch size: #{@max_batch_size} changes")
    IO.puts("")
    
    case parse_args(args) do
      {:ok, options} ->
        execute_batch_fixes(options)
      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        print_usage()
    end
  end
  
  defp execute_batch_fixes(options) do
    target = Keyword.get(options, :target, "lib/indrajaal/logging.ex")
    
    IO.puts("🎯 Target: #{target}")
    IO.puts("📋 Creating initial git checkpoint...")
    
    create_checkpoint("Initial checkpoint before fixes")
    
    # Analyze the target file for issues
    case analyze_file(target) do
      {:ok, issues} ->
        IO.puts("📊 Found #{length(issues)} issues to fix")
        process_issues_in_batches(issues, target)
      {:error, reason} ->
        IO.puts("❌ Failed to analyze file: #{reason}")
    end
  end
  
  defp analyze_file(file_path) do
    full_path = Path.join(@container_path, file_path)
    
    case File.read(full_path) do
      {:ok, content} ->
        issues = []
        
        # Find _severity being used
        issues = issues ++ find_pattern(content, ~r/_severity(?=,)/, "underscore variable used", :replace_underscore)
        
        # Find _context being used
        issues = issues ++ find_pattern(content, ~r/_context(?=[\s,\)])/, "underscore variable used", :replace_underscore)
        
        # Find undefined variables
        issues = issues ++ analyze_undefined_variables(content)
        
        {:ok, issues}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp find_pattern(content, regex, description, fix_type) do
    Regex.scan(regex, content, return: :index)
    |> Enum.map(fn [{start_pos, length}] ->
      line_num = count_lines_before(content, start_pos)
      %{
        type: fix_type,
        line: line_num,
        position: start_pos,
        length: length,
        description: description,
        original: String.slice(content, start_pos, length)
      }
    end)
  end
  
  defp analyze_undefined_variables(content) do
    # This is a simplified analysis - in practice would use AST
    []
  end
  
  defp count_lines_before(content, position) do
    content
    |> String.slice(0, position)
    |> String.split("\n")
    |> length()
  end
  
  defp process_issues_in_batches(issues, target_file) do
    issues
    |> Enum.chunk_every(@max_batch_size)
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, 0}, fn {batch, batch_num}, {:ok, total_fixed} ->
      IO.puts("\n📦 Processing batch #{batch_num} (#{length(batch)} fixes)...")
      
      case apply_and_verify_batch(batch, target_file, batch_num) do
        {:ok, fixed_count} ->
          {:cont, {:ok, total_fixed + fixed_count}}
        {:error, reason} ->
          IO.puts("❌ Batch #{batch_num} failed: #{reason}")
          IO.puts("🔄 Rolling back to previous checkpoint...")
          rollback_batch()
          {:halt, {:error, reason, total_fixed}}
      end
    end)
    |> case do
      {:ok, total} ->
        IO.puts("\n✅ Successfully fixed #{total} issues")
        IO.puts("📅 Completed at: #{LocalTime.timestamp_string()}")
      {:error, _reason, partial} ->
        IO.puts("\n⚠️ Partially completed: #{partial} issues fixed before error")
    end
  end
  
  defp apply_and_verify_batch(batch, target_file, batch_num) do
    # Apply fixes
    full_path = Path.join(@container_path, target_file)
    
    case File.read(full_path) do
      {:ok, content} ->
        # Apply each fix in the batch
        _fixed_content = Enum.reduce(batch, _content, fn issue, acc ->
          apply_fix(acc, issue)
        end)
        
        # Write the fixed content
        File.write!(full_path, fixed_content)
        
        IO.puts("📝 Applied #{length(batch)} fixes")
        IO.puts("🔍 Verifying compilation...")
        
        # Verify compilation
        case compile_project() do
          :ok ->
            IO.puts("✅ Compilation successful")
            commit_batch(batch_num, length(batch))
            {:ok, length(batch)}
          {:error, output} ->
            IO.puts("❌ Compilation failed")
            IO.puts(output)
            {:error, "Compilation failed after applying batch #{batch_num}"}
        end
      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end
  
  defp apply_fix(content, %{type: :replace_underscore, original: original}) do
    # Remove underscore prefix
    replacement = String.replace(original, "_", "")
    String.replace(content, original, replacement)
  end
  
  defp apply_fix(content, _issue), do: content
  
  defp create_checkpoint(message) do
    System.cmd("git", ["add", "-A"], cd: @container_path)
    System.cmd("git", ["commit", "-m", "#{message} - #{LocalTime.for_git()}"], cd: @container_path)
  end
  
  defp rollback_batch do
    System.cmd("git", ["reset", "--hard", "HEAD"], cd: @container_path)
  end
  
  defp compile_project do
    case System.cmd("mix", ["compile", "--warnings-as-errors"], 
                    cd: @container_path, 
                    stderr_to_stdout: true,
                    env: [{"ELIXIR_ERL_OPTIONS", "+fnu"}]) do
      {_output, 0} -> :ok
      {output, _} -> {:error, output}
    end
  end
  
  defp commit_batch(batch_num, fix_count) do
    message = "Batch #{batch_num}: Applied #{fix_count} fixes - #{LocalTime.for_git()}"
    System.cmd("git", ["add", "-A"], cd: @container_path)
    System.cmd("git", ["commit", "-m", message], cd: @container_path)
    IO.puts("✅ Committed batch #{batch_num}")
  end
  
  defp parse_args(args) do
    case OptionParser.parse(args, switches: [target: :string, help: :boolean]) do
      {__opts, [], []} ->
        if Keyword.get(__opts, :help) do
          {:error, :help_requested}
        else
          {:ok, __opts}
        end
      _ ->
        {:error, :invalid_args}
    end
  end
  
  defp print_usage do
    IO.puts("""
    
    Usage: elixir batch_verification_fixer.exs [options]
    
    Options:
      --target FILE    Target file to fix (default: lib/indrajaal/logging.ex)
      --help           Show this help message
    
    Examples:
      elixir batch_verification_fixer.exs
      elixir batch_verification_fixer.exs --target lib/indrajaal/devices.ex
    """)
  end
end

# Run the script
BatchVerificationFixer.run(System.argv())