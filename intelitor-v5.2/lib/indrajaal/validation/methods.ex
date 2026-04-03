defmodule Indrajaal.Validation.Methods.PatternMethod do
  @moduledoc false
  def run(content) do
    error_matches = Regex.scan(~r/error:|exception|fail/i, content)
    errors = error_matches |> length()

    warning_matches = Regex.scan(~r/warning:/i, content)
    warnings = warning_matches |> length()

    %{errors: errors, warnings: warnings, method: :pattern}
  end
end

defmodule Indrajaal.Validation.Methods.ASTMethod do
  @moduledoc false
  def run(content) do
    # Simplified AST check
    case Code.string_to_quoted(content) do
      {:ok, _} -> %{errors: 0, warnings: 0, method: :ast}
      {:error, _} -> %{errors: 1, warnings: 0, method: :ast}
    end
  end
end

defmodule Indrajaal.Validation.Methods.StatisticalMethod do
  @moduledoc false

  # Statistical analysis: counts error and warning signals using frequency scoring.
  # Each error keyword contributes a weighted score; totals are normalised to counts.
  @error_keywords ~w(error exception fail failure crash abort killed segfault panic)
  @warning_keywords ~w(warning warn deprecated notice caution)

  def run(content) when is_binary(content) do
    lines = String.split(content, "\n", trim: true)
    total = max(length(lines), 1)

    {raw_errors, raw_warnings} =
      Enum.reduce(lines, {0, 0}, fn line, {errs, warns} ->
        lower = String.downcase(line)
        err_hits = Enum.count(@error_keywords, &String.contains?(lower, &1))
        warn_hits = Enum.count(@warning_keywords, &String.contains?(lower, &1))
        {errs + err_hits, warns + warn_hits}
      end)

    # Normalise: cap at line count (1 error per line at most statistically)
    errors = min(raw_errors, total)
    warnings = min(raw_warnings, total)

    %{errors: errors, warnings: warnings, method: :statistical}
  end

  def run(_), do: %{errors: 0, warnings: 0, method: :statistical}
end

defmodule Indrajaal.Validation.Methods.BinaryMethod do
  @moduledoc false

  # Binary scan: searches for error/warning byte sequences without regex.
  # Uses :binary.matches/2 for byte-level pattern matching.
  @error_patterns [
    "error:",
    "Error:",
    "ERROR:",
    "exception",
    "Exception",
    " fail",
    "FAIL",
    "crash",
    "Crash"
  ]
  @warning_patterns ["warning:", "Warning:", "WARNING:", "warn:"]

  def run(content) when is_binary(content) do
    errors =
      Enum.reduce(@error_patterns, 0, fn pattern, acc ->
        matches = :binary.matches(content, pattern)
        acc + length(matches)
      end)

    warnings =
      Enum.reduce(@warning_patterns, 0, fn pattern, acc ->
        matches = :binary.matches(content, pattern)
        acc + length(matches)
      end)

    %{errors: errors, warnings: warnings, method: :binary}
  end

  def run(_), do: %{errors: 0, warnings: 0, method: :binary}
end

defmodule Indrajaal.Validation.Methods.LineByLineMethod do
  @moduledoc false

  # Line-by-line heuristic: classify each line independently using prefix/infix rules.
  @error_prefixes ["error", "exception", "crash", "fatal", "abort", "fail"]
  @warning_prefixes ["warning", "warn", "deprecated", "notice"]

  def run(content) when is_binary(content) do
    lines = String.split(content, "\n", trim: true)

    {errors, warnings} =
      Enum.reduce(lines, {0, 0}, fn line, {errs, warns} ->
        stripped = line |> String.trim() |> String.downcase()

        is_error =
          Enum.any?(@error_prefixes, fn prefix ->
            String.starts_with?(stripped, prefix) or
              String.contains?(stripped, "#{prefix}:")
          end)

        is_warning =
          not is_error and
            Enum.any?(@warning_prefixes, fn prefix ->
              String.starts_with?(stripped, prefix) or
                String.contains?(stripped, "#{prefix}:")
            end)

        new_errs = if is_error, do: errs + 1, else: errs
        new_warns = if is_warning, do: warns + 1, else: warns
        {new_errs, new_warns}
      end)

    %{errors: errors, warnings: warnings, method: :line_by_line}
  end

  def run(_), do: %{errors: 0, warnings: 0, method: :line_by_line}
end
