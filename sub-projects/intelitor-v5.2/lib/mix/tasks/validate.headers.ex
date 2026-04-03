defmodule Mix.Tasks.Validate.Headers do
  @moduledoc """
  Validates HTTP header name formatting in source files.

  Checks for header names containing spaces which cause silent failures
  when extracting headers from Plug.Conn.

  STAMP Constraint: SC-PROP-025
  Formal Specs: ComprehensiveErrorModel.agda (buggy-returns-buggy)

  ## Examples of Violations

      # BAD - spaces in header name
      get_req_header(conn, "x - forwarded - for")
      get_req_header(conn, "accept - language")

      # GOOD - no spaces
      get_req_header(conn, "x-forwarded-for")
      get_req_header(conn, "accept-language")

  ## Usage

      mix validate.headers           # Check all lib and test files
      mix validate.headers --strict  # Exit with error on violations
  """

  use Mix.Task

  @shortdoc "Validates HTTP header names for spacing bugs"

  # Common header patterns that might have spacing bugs
  @buggy_patterns [
    ~r/"accept - language"/,
    ~r/"accept - encoding"/,
    ~r/"x - forwarded - for"/,
    ~r/"x - real - ip"/,
    ~r/"content - type"/,
    ~r/"content - length"/,
    ~r/"cache - control"/,
    ~r/"user - agent"/
  ]

  @impl Mix.Task
  def run(args) do
    strict_mode = "--strict" in args

    Mix.shell().info("Header Spacing Bug Validator")
    Mix.shell().info("============================")

    violations = scan_for_violations()

    if length(violations) > 0 do
      Mix.shell().error("\nFound #{length(violations)} header spacing violation(s):")

      Enum.each(violations, fn {file, line_num, matched} ->
        Mix.shell().error("  #{file}:#{line_num}")
        Mix.shell().error("    Found: #{matched}")
      end)

      Mix.shell().info("\n")
      Mix.shell().info("Fix: Remove spaces from header names")
      Mix.shell().info("  'x - forwarded - for' -> 'x-forwarded-for'")

      if strict_mode do
        Mix.raise("Header spacing bugs found: #{length(violations)} occurrences")
      end
    else
      Mix.shell().info("Header Validation: All header names valid ✓")
    end
  end

  defp scan_for_violations do
    files =
      (Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")) --
        ["lib/mix/tasks/validate.headers.ex"]

    files
    |> Enum.flat_map(&check_file/1)
  end

  defp check_file(file_path) do
    file_path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.flat_map(fn {line, line_num} ->
      Enum.flat_map(@buggy_patterns, fn pattern ->
        case Regex.run(pattern, line) do
          [matched] -> [{file_path, line_num, matched}]
          nil -> []
        end
      end)
    end)
    |> Enum.to_list()
  end
end
