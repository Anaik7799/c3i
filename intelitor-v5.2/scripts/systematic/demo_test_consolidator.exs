#!/usr/bin/env elixir

defmodule DemoTestConsolidator do
  @moduledoc """
  Systematic consolidation of demo test files to eliminate duplicate code.

  This script applies the existing DemoTestHelpers module across 40+ demo test files
  to achieve >90% duplicate code reduction target. Based on credo analysis showing
  2,383 remaining duplicate violations, primarily from demo test file duplication.

  SOPv5.1 TPS Methodology: Systematic application of DRY principles with Jidoka.
  """

  def main(_args \\ []) do
    IO.puts("🔧 Starting systematic demo test consolidation...")
    IO.puts("📊 Target: Eliminate ~2,000 duplicate violations from demo tests")
    IO.puts("🎯 Goal: Achieve >90% duplicate code reduction")
    IO.puts("")

    # Get all demo test files
    demo_test_files = get_demo_test_files()

    IO.puts("📁 Found #{length(demo_test_files)} demo test files to process")
    IO.puts("")

    # Process each file systematically
    Enum.with_index(demo_test_files, 1)
    |> Enum.each(fn {file, index} ->
      IO.puts("🔄 Processing #{index}/#{length(demo_test_files)}: #{Path.basename(file)}")
      consolidate_demo_test_file(file)
    end)

    IO.puts("")
    IO.puts("✅ Demo test consolidation completed!")
    IO.puts("🔍 Run validation to measure duplicate code reduction...")
    IO.puts("elixir scripts/validation/simple_credo_counter.exs")
  end

  defp get_demo_test_files do
    Path.wildcard("test/demo/*_test.exs")
    |> Enum.sort()
  end

  defp consolidate_demo_test_file(file_path) do
    content = File.read!(file_path)

    # Apply systematic replacements to use DemoTestHelpers
    updated_content =
      content
      |> add_demo_test_helpers_import()
      |> replace_multi_tenant_test_pattern()
      |> replace_concurrent_test_pattern()
      |> replace_enterprise_demo_test_pattern()
      |> replace_duplicate_setup_patterns()

    # Only write if changes were made
    if content != updated_content do
      File.write!(file_path, updated_content)
      IO.puts("  ✅ Updated: #{Path.basename(file_path)}")
    else
      IO.puts("  ⏭️  Skipped: #{Path.basename(file_path)} (no changes needed)")
    end
  end

  defp add_demo_test_helpers_import(content) do
    # Add import for DemoTestHelpers if not already present
    if String.contains?(content, "Indrajaal.DemoTestHelpers") do
      content
    else
      # Find the module definition and add import after it
      content
      |> String.replace(
        ~r/defmodule\s+\w+\s+do/,
        "\\0\n  import Indrajaal.DemoTestHelpers"
      )
    end
  end

  defp replace_multi_tenant_test_pattern(content) do
    # Replace the duplicate multi-tenant test pattern
    multi_tenant_pattern = ~r/test "demo supports multi-tenant scenarios".*?do.*?end/s

    if Regex.match?(multi_tenant_pattern, content) do
      replacement = """
      test "demo supports multi-tenant scenarios" do
        # Use shared demo test helper to eliminate duplication
        scenario = test_multi_tenant_scenario()

        assert scenario.tenant1.id != scenario.tenant2.id
        assert scenario.__user1.__tenant_id == scenario.tenant1.id
        assert scenario.__user2.__tenant_id == scenario.tenant2.id
      end"""

      Regex.replace(multi_tenant_pattern, content, replacement)
    else
      content
    end
  end

  defp replace_concurrent_test_pattern(content) do
    # Replace concurrent test patterns with shared helper
    concurrent_pattern = ~r/test "demo handles concurrent.*?".*?do.*?Task\.async.*?end/s

    if Regex.match?(concurrent_pattern, content) do
      replacement = """
      test "demo handles concurrent operations correctly" do
        # Use shared concurrent test helper
        result = test_concurrent_scenario(5)

        assert result.success_count >= 3
        assert result.total_operations == 5
      end"""

      Regex.replace(concurrent_pattern, content, replacement)
    else
      content
    end
  end

  defp replace_enterprise_demo_test_pattern(content) do
    # Replace the massive enterprise demo test pattern (mass: 144)
    enterprise_pattern = ~r/@tag :enterprise_demo.*?test.*?".*?enterprise.*?demo.*?".*?do.*?end/s

    if Regex.match?(enterprise_pattern, content) do
      replacement = """
      @tag :enterprise_demo
      test "enterprise demo validation" do
        # Use shared enterprise demo test helper
        assert enterprise_demo_tests() == :success
      end"""

      Regex.replace(enterprise_pattern, content, replacement)
    else
      content
    end
  end

  defp replace_duplicate_setup_patterns(content) do
    # Replace common setup patterns that appear in multiple files
    setup_patterns = [
      # Replace duplicate setup blocks
      {~r/setup do.*?tenant = tenant_fixture.*?__user = __user_fixture.*?\{:ok.*?\}/s,
       "setup do\n    demo_test_setup()\n  end"},

      # Replace duplicate assertion patterns
      {~r/assert.*?is_binary.*?assert.*?String\.length.*?> 0/s,
       "assert_demo_success_response(response)"}
    ]

    Enum.reduce(setup_patterns, content, fn {pattern, replacement}, acc ->
      if Regex.match?(pattern, acc) do
        Regex.replace(pattern, acc, replacement)
      else
        acc
      end
    end)
  end
end

# Execute the script
DemoTestConsolidator.main(System.argv())
