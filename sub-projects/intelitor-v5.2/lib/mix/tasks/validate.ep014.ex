defmodule Mix.Tasks.Validate.Ep014 do
  @moduledoc """
  Validates EP-GEN-014 compliance in test files.

  EP-GEN-014 Pattern:
  When using both PropCheck and ExUnitProperties (check all() macro),
  files MUST include:
  1. `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  2. `alias PropCheck.BasicTypes, as: PC`
  3. `alias StreamData, as: SD`

  STAMP Constraints: SC-PROP-023, SC-PROP-024
  Formal Specs: ComprehensiveErrorModel.agda (conflict-implies-failure)

  ## Usage

      mix validate.ep014           # Check all test files
      mix validate.ep014 --fix     # Attempt automatic fixes (future)
      mix validate.ep014 --strict  # Exit with error on violations
  """

  use Mix.Task

  @shortdoc "Validates EP-GEN-014 compliance in test files"

  @impl Mix.Task
  def run(args) do
    strict_mode = "--strict" in args

    Mix.shell().info("EP-GEN-014 Compliance Validator")
    Mix.shell().info("================================")

    violations = scan_for_violations()

    if length(violations) > 0 do
      Mix.shell().error("\nFound #{length(violations)} EP-GEN-014 violation(s):")

      Enum.each(violations, fn {file, issues} ->
        Mix.shell().error("\n  #{file}:")

        Enum.each(issues, fn issue ->
          Mix.shell().error("    - #{issue}")
        end)
      end)

      Mix.shell().info("\n")
      Mix.shell().info("Fix Pattern:")
      Mix.shell().info("  Add after 'use PropCheck':")

      Mix.shell().info(
        "    import ExUnitProperties, except: [property: 2, property: 3, check: 2]"
      )

      Mix.shell().info("    alias PropCheck.BasicTypes, as: PC")
      Mix.shell().info("    alias StreamData, as: SD")

      if strict_mode do
        Mix.raise("EP-GEN-014 violations found: #{length(violations)} files")
      end
    else
      Mix.shell().info("EP-GEN-014: All test files compliant ✓")
    end
  end

  defp scan_for_violations do
    test_files = Path.wildcard("test/**/*_test.exs")

    test_files
    |> Enum.map(&check_file/1)
    |> Enum.reject(&is_nil/1)
  end

  defp check_file(file_path) do
    content = File.read!(file_path)
    issues = []

    has_propcheck = String.contains?(content, "use PropCheck")
    has_check_all = String.contains?(content, "check all(")
    has_except = String.contains?(content, "except:")
    has_pc_alias = String.contains?(content, "alias PropCheck.BasicTypes, as: PC")
    has_sd_alias = String.contains?(content, "alias StreamData, as: SD")

    # Violation 1: Has check all() (ExUnitProperties) with PropCheck but no except clause
    issues =
      if has_propcheck and has_check_all and not has_except do
        [
          "Missing 'import ExUnitProperties, except: [property: 2, property: 3, check: 2]'"
          | issues
        ]
      else
        issues
      end

    # Violation 2: Both frameworks without PC alias
    issues =
      if has_propcheck and has_check_all and not has_pc_alias do
        ["Missing 'alias PropCheck.BasicTypes, as: PC'" | issues]
      else
        issues
      end

    # Violation 3: Both frameworks without SD alias
    issues =
      if has_propcheck and has_check_all and not has_sd_alias do
        ["Missing 'alias StreamData, as: SD'" | issues]
      else
        issues
      end

    if length(issues) > 0 do
      {file_path, Enum.reverse(issues)}
    else
      nil
    end
  end
end
