#!/usr/bin/env elixir

# Fix FeatureFlag tests to use correct Ash patterns
# Part of Phase 1: Fix Test Infrastructure

defmodule FixFeatureFlagTests do
  @moduledoc """
  Fixes FeatureFlag tests to use Ash resource code interface instead of domain functions.

  Changes:-Core.create_feature_flag → FeatureFlag.create
  - Core.get_feature_flag → FeatureFlag.get
  - Core.update_feature_flag → FeatureFlag.update
  - Core.list_feature_flags → FeatureFlag.list
  - Core.delete_feature_flag → FeatureFlag.destroy
  """

  @spec run() :: any()
  def run do
    IO.puts("🔧 Fixing FeatureFlag test patterns...")

    test_files = [
      "test/intelitor/core/feature_flag_test.exs",
      "test/intelitor/core/feature_flag_comprehensive_test.exs",
      "test/intelitor/core/feature_flag_targeting_test.exs",
      "test/intelitor/core/feature_flag_rollout_test.exs"
    ]

    Enum.each(test_files, &fix_test_file/1)

    IO.puts("✅ FeatureFlag test fixes complete!")
  end

  @spec fix_test_file(term()) :: term()
  defp fix_test_file(file_path) do
    full_path = Path.join(File.cwd!(), file_path)

    if File.exists?(full_path) do
      IO.puts("  Fixing #{file_path}...")

      content = File.read!(full_path)

      # Fix function calls
      fixed_content = content
      |> String.replace("Core.create_feature_flag(", "FeatureFlag.create(")
      |> String.replace("Core.get_feature_flag(", "FeatureFlag.get(")
      |> String.replace("Core.update_feature_flag(", "FeatureFlag.update(")
      |> String.replace("Core.list_feature_flags(", "FeatureFlag.list(")
      |> String.replace("Core.delete_feature_flag(", "FeatureFlag.destroy(")
      |> String.replace("Core.toggle_feature_flag(", "FeatureFlag.toggle(")
      |> String.replace("Core.set_rollout_feature_flag(", "FeatureFlag.set_rollout(")

      # Fix alias if needed
      fixed_content = if String.contains?(fixed_content, "alias Intelitor.Core") and
                        not String.contains?(fixed_content, "alias Intelitor.Core.FeatureFlag") do
        fixed_content

    |> String.replace("alias Intelitor.Core\n",
      "alias Intelitor.Core\n  alias Intelitor.Core.FeatureFlag\n")
      else
        fixed_content
      end

      # Add alias if completely missing
      if not String.contains?(fixed_content, "alias Intelitor.Core.FeatureFlag") do
        fixed_content = String.replace(fixed_content,
      "use Intelitor.DataCase", "use Intelitor.DataCase\n\n  alias Intelitor.Core.FeatureFlag")
      end

      File.write!(full_path, fixed_content)
      IO.puts("    ✓ Fixed #{count_replacements(content, fixed_content)} occurren
    else
      IO.puts("  ⚠️  File not found: #{file_path}")
    end
  end

  @spec count_replacements(term(), term()) :: term()
  defp count_replacements(original, fixed) do
    patterns = [
      "Core.create_feature_flag",
      "Core.get_feature_flag",
      "Core.update_feature_flag",
      "Core.list_feature_flags",
      "Core.delete_feature_flag",
      "Core.toggle_feature_flag",
      "Core.set_rollout_feature_flag"
    ]

    Enum.sum(Enum.map(patterns, fn pattern ->
      length(String.split(original, pattern)) - 1
    end))
  end
end

FixFeatureFlagTests.run()
end
