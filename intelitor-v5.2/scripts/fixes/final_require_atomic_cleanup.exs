#!/usr/bin/env elixir

defmodule FinalRequireAtomicCleanup do
  @moduledoc """
  Final cleanup of all __require_atomic? issues
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🏁 FINAL __require_atomic? CLEANUP
    ================================
    """

    # List of files with known issues
    problematic_files = [
      "lib/indrajaal/communication/broadcast_campaign.ex",
      "lib/indrajaal/guard_tour/tour_report.ex",
      "lib/indrajaal/core/tenant.ex",
      "lib/indrajaal/visitor_management/contractor_management.ex",
      "lib/indrajaal/visitor_management/visit_request.ex"
    ]

    # Process all files
    all_files = Path.wildcard("lib/**/*.ex")

    results = all_files
    |> Enum.map(&process_file/1)
    |> Enum.filter(& &1.changed)

    IO.puts "\n📊 RESULTS:"
    IO.puts "- Files processed: #{length(all_files)}"
    IO.puts "- Files fixed: #{length(results)}"
    IO.puts "- Total fixes: #{Enum.sum(Enum.map(results, & &1.fixes))}"
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)

    # Apply all fixes
    {_fixed_content, _total_fixes} = content
    |> remove_consecutive_duplicates()
    |> remove_multiple_in_same_action()
    |> ensure_proper_action_structure()

    changed = content != fixed_content

    if changed do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path} (#{total_fixes} fixes)"
    end

    %{
      file: file_path,
      changed: changed,
      fixes: total_fixes
    }
  end

  @spec remove_consecutive_duplicates(term(), term()) :: term()
  defp remove_consecutive_duplicates({content, fixes}) do
    fixed = Regex.replace(
      ~r/(__require_atomic\? false\s*\n)(\s*__require_atomic\? false\s*\n)+/,
      content,
      "\\1"
    )

    new_fixes = count_replacements(content, fixed)
    {fixed, fixes + new_fixes}
  end

  @spec remove_consecutive_duplicates(term()) :: term()
  defp remove_consecutive_duplicates(content) when is_binary(content) do
    remove_consecutive_duplicates({content, 0})
  end

  @spec remove_multiple_in_same_action(term(), term()) :: term()
  defp remove_multiple_in_same_action({content, fixes}) do
    # Split into lines and process action by action
    lines = String.split(content, "\n")
    {_processed_lines, _new_fixes} = process_action_blocks(lines, [], 0, false, false)

    {Enum.join(processed_lines, "\n"), fixes + new_fixes}
  end

  @spec ensure_proper_action_structure(term(), term()) :: term()
  defp ensure_proper_action_structure({content, fixes}) do
    # Remove __require_atomic? that appears after other content in action
    fixed = Regex.replace(
      ~r/(change\s+[^\n]+\n)(\s*__require_atomic\? false\s*\n)(\s*end)/m,
      content,
      "\\1\\3"
    )

    new_fixes = count_replacements(content, fixed)
    {fixed, fixes + new_fixes}
  end

  defp process_action_blocks([], acc, fixes, _, _), do: {Enum.reverse(acc), fixes}

  defp process_action_blocks([line | rest], acc, fixes, in_action, has_require_atomic) do
    trimmed = String.trim(line)

    cond do
      # Start of action
      Regex.match?(~r/^(update|destroy|create)\s+:\w+\s+do$/, trimmed) ->
        process_action_blocks(rest, [line | acc], fixes, true, false)

      # End of action
      in_action and trimmed == "end" ->
        process_action_blocks(rest, [line | acc], fixes, false, false)

      # First __require_atomic? in action
      in_action and not has_require_atomic and trimmed == "__require_atomic? false" ->
        process_action_blocks(rest, [line | acc], fixes, in_action, true)

      # Duplicate __require_atomic? in same action
      in_action and has_require_atomic and trimmed == "__require_atomic? false" ->
        process_action_blocks(rest, acc, fixes + 1, in_action, true)

      # Other lines
      true ->
        process_action_blocks(rest, [line | acc], fixes, in_action, has_require_atomic)
    end
  end

  @spec count_replacements(term(), term()) :: term()
  defp count_replacements(original, fixed) do
    original_count = length(String.split(original, "__require_atomic? false")) - 1
    fixed_count = length(String.split(fixed, "__require_atomic? false")) - 1
    original_count - fixed_count
  end
end

FinalRequireAtomicCleanup.execute()