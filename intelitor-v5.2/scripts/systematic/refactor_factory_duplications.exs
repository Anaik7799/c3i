#!/usr/bin/env elixir

defmodule FactoryDuplicationRefactor do
  @moduledoc """
  SOPv5.1 TPS Factory Refactoring for Duplication Elimination

  Systematically refactor factory files to use shared utilities.
  Target: ~400 violations reduced through factory pattern consolidation.

  Agent: Helper-3 (Factory Specialist)
  Pattern: EP503 - Factory duplication elimination
  """

  @spec main() :: any()
  def main do
    IO.puts("🔧 SOPv5.1 TPS Jidoka: Refactoring factory duplications")
    IO.puts("🎯 Target: ~400 violations through factory pattern consolidation")

    # Step 1: Update factory files to import shared utilities
    add_shared_imports()

    # Step 2: Refactor common patterns
    refactor_common_patterns()

    # Step 3: Update main factory to import shared utilities
    update_main_factory()

    IO.puts("✅ Factory duplication refactoring completed")
    IO.puts("📊 Run validation to measure improvement")
  end

  defp add_shared_imports do
    IO.puts("📝 Adding shared imports to factory files")

    factory_files = [
      "test/support/factories/accounts_factory.ex",
      "test/support/factories/policy_factory.ex",
      "test/support/factories/integrations_factory.ex",
      "test/support/factories/analytics_factory.ex",
      "test/support/factories/compliance_factory.ex",
      "test/support/factories/devices_factory.ex",
      "test/support/factories/communication_factory.ex"
    ]

    Enum.each(factory_files, fn file_path ->
      if File.exists?(file_path) do
        content = File.read!(file_path)

        # Add import for shared utilities if not already present
        if not String.contains?(content, "Indrajaal.Shared.FactoryUtilities") do
          updated_content =
            content
            |> String.replace(
              "import Indrajaal.Shared.TestSupport",
              "import Indrajaal.Shared.TestSupport\nimport Indrajaal.Shared.FactoryUtilities"
            )

          File.write!(file_path, updated_content)
          IO.puts("✅ Added shared imports to #{file_path}")
        end
      end
    end)
  end

  defp refactor_common_patterns do
    IO.puts("🔄 Refactoring common factory patterns")

    # Pattern 1: Normalize attribute handling
    refactor_attribute_normalization()

    # Pattern 2: Common sequence generators
    refactor_sequence_patterns()

    # Pattern 3: Tenant handling
    refactor_tenant_patterns()
  end

  defp refactor_attribute_normalization do
    IO.puts("   📝 Refactoring attribute normalization patterns")

    pattern = "attrs_map = if is_list(attrs), do: Enum.into(attrs, %{}), else: attrs"
    replacement = "attrs_map = normalize_attrs(attrs)"

    apply_pattern_replacement(pattern, replacement)
  end

  defp refactor_sequence_patterns do
    IO.puts("   📝 Refactoring sequence patterns")

    # Email sequences - use double quotes and escape interpolation
    pattern = "sequence(:email, &\"__user\#{&1}@test.example.com\")"
    replacement = "sequence(:email, email_sequence())"
    apply_pattern_replacement(pattern, replacement)

    # Skip regex patterns for now to avoid complexity
    IO.puts("   📝 Skipping complex regex patterns for now")
  end

  defp refactor_tenant_patterns do
    IO.puts("   📝 Refactoring tenant patterns")

    pattern = "tenant = attrs_map[:tenant] || insert(:tenant)"
    replacement = "{_tenant, _attrs_map} = handle_tenant_association(attrs_map, __MODULE__)"
    apply_pattern_replacement(pattern, replacement)
  end

  defp apply_pattern_replacement(pattern, replacement, type \\ :string) do
    factory_files = Path.wildcard("test/support/factories/*.ex")

    Enum.each(factory_files, fn file_path ->
      if File.exists?(file_path) do
        content = File.read!(file_path)

        updated_content =
          case type do
            :string -> String.replace(content, pattern, replacement)
            :regex -> Regex.replace(pattern, content, replacement)
          end

        if updated_content != content do
          File.write!(file_path, updated_content)
          IO.puts("     ✅ Updated pattern in #{file_path}")
        end
      end
    end)
  end

  defp update_main_factory do
    IO.puts("📝 Updating main factory file")

    main_factory = "test/support/factory.ex"

    if File.exists?(main_factory) do
      content = File.read!(main_factory)

      if not String.contains?(content, "Indrajaal.Shared.FactoryUtilities") do
        # Add import after existing alias
        updated_content =
          String.replace(
            content,
            "alias Indrajaal.Shared.DatetimeUtilities",
            "alias Indrajaal.Shared.DatetimeUtilities\n  import Indrajaal.Shared.FactoryUtilities"
          )

        File.write!(main_factory, updated_content)
        IO.puts("✅ Updated main factory file")
      end
    end
  end
end

# Run the refactoring
FactoryDuplicationRefactor.main()
