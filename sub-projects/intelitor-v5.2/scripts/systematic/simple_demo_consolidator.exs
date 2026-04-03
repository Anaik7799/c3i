#!/usr/bin/env elixir

defmodule SimpleDemoConsolidator do
  @moduledoc """
  Simple consolidation of demo test files to eliminate duplicate code.

  Applies DemoTestHelpers systematically to achieve >90% duplicate code reduction.
  """

  @spec main(term()) :: any()
  def main(_args \\ []) do
    IO.puts("🔧 Starting demo test consolidation...")

    # Get all demo test files
    demo_files = Path.wildcard("test/demo/*_test.exs" |> Enum.sort())

    IO.puts("📁 Found #{length(demo_files)} demo test files")

    # Process each file
    Enum.each(demo_files, fn file ->
      IO.puts("🔄 Processing: #{Path.basename(file)}")
      add_demo_helpers_import(file)
    end)

    IO.puts("✅ Demo test consolidation completed!")
    IO.puts("🔍 Run validation: elixir scripts/validation/simple_credo_counter.exs")
  end

  defp add_demo_helpers_import(file_path) do
    content = File.read!(file_path)

    # Check if DemoTestHelpers is already imported
    if String.contains?(content, "Indrajaal.DemoTestHelpers") do
      IO.puts("  ⏭️  Already has DemoTestHelpers")
    else
      # Add import after the module definition
      updated_content =
        String.replace(
          content,
          ~r/(defmodule\s+\w+.*?do)/,
          "\\1\n  import Indrajaal.DemoTestHelpers"
        )

      # Add usage of shared test helper for common patterns
      updated_content =
        updated_content
        |> replace_common_test_patterns()

      if content != updated_content do
        File.write!(file_path, updated_content)
        IO.puts("  ✅ Updated with DemoTestHelpers")
      else
        IO.puts("  ⏭️  No changes needed")
      end
    end
  end

  defp replace_common_test_patterns(content) do
    content
    |> replace_multi_tenant_pattern()
    |> add_demo_setup_helper()
  end

  defp replace_multi_tenant_pattern(content) do
    # Replace common multi-tenant test patterns
    pattern =
      ~r/tenant1.*?=.*?tenant_fixture.*?tenant2.*?=.*?tenant_fixture.*?__user1.*?=.*?__user_fixture.*?__user2.*?=.*?__user_fixture/s

    if Regex.match?(pattern, content) do
      String.replace(content, pattern, "scenario = test_multi_tenant_scenario()")
    else
      content
    end
  end

  defp add_demo_setup_helper(content) do
    # Add helper usage in common setup blocks
    pattern = ~r/setup do.*?tenant.*?=.*?tenant_fixture.*?__user.*?=.*?__user_fixture.*?\{:ok.*?\}/s

    if Regex.match?(pattern, content) do
      String.replace(content, pattern, "setup do\n    demo_test_setup()\n  end")
    else
      content
    end
  end
end

# Execute the script
SimpleDemoConsolidator.main(System.argv())
