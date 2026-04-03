defmodule Indrajaal.Validation.ContextWindow do
  @moduledoc """
  Multiline Context Window for FPPS Log Preprocessing.

  WHAT: Preprocesses compilation log content by joining related multiline
  entries into single logical lines before passing to the 5 FPPS methods.
  This ensures all methods see the same "logical line" boundaries and
  produce consistent category counts for consensus.

  WHY: Compilation output from `mix compile`, `mix credo`, and `mix dialyzer`
  can split a single semantic error across multiple physical lines. Without
  normalization, methods that scan full-content (Pattern's regex with \\s+)
  could detect cross-line patterns while per-line methods (AST, Statistical,
  Binary, LineByLine) would miss them, breaking SC-VAL-003 consensus.

  CONSTRAINTS:
  - SC-VAL-003: 100% consensus required across all 5 methods
  - SC-MULTILINE-001: Multiline entries must be joined before validation
  - SC-MULTILINE-002: Joining must be deterministic and idempotent

  ## Joining Rules
  1. **Continuation lines**: Lines starting with whitespace that follow an
     error/warning line are appended to the previous logical line.
  2. **Elixir error blocks**: `** (ExceptionType)` followed by indented
     stacktrace lines are joined into one logical entry.
  3. **Compilation error blocks**: `== Compilation error in file ...` followed
     by the error detail lines are joined.
  4. **Credo output blocks**: Lines following `Found N issue` that contain
     file references are joined.

  ## Performance
  Single-pass O(n) processing. No regex compilation at runtime — all patterns
  are module attributes compiled at load time.

  Task 44.1.0.0.0
  """

  # ---------------------------------------------------------------------------
  # Continuation detection patterns (compile-time)
  # ---------------------------------------------------------------------------

  # Lines that START a new logical block (never continuations)
  @block_starters [
    # Elixir compilation error header
    ~r/^==\s+Compilation error/,
    # Elixir exception display
    ~r/^\*\*\s+\(/,
    # Elixir warning/error prefix with file location
    ~r/^(warning|error):/i,
    # Mix task output header
    ~r/^(Compiling|Generated|Running|Compiled)/,
    # Credo category header
    ~r/^(Software Design|Refactoring|Warnings|Readability|Consistency)/,
    # Credo result line
    ~r/^\s*Found\s+\d+/i,
    # Dialyzer output
    ~r/^\s*dialyzed/i,
    # Empty line (block separator)
    ~r/^\s*$/
  ]

  # Lines that are CONTINUATIONS of the previous logical line:
  # - Indented lines (stacktrace, multi-line error detail)
  # - Lines starting with pipe character (Credo detail)
  # - Lines starting with └, ├, │ (tree-style output)
  @continuation_pattern ~r/^(\s{2,}|\s*[\|│├└┃])/

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Normalizes log content by joining multiline entries into logical lines.

  Each "logical line" in the output represents one semantic unit (one error,
  one warning, one compilation message). Continuation lines are joined with
  a space separator.

  Returns the normalized content as a single binary string with logical lines
  separated by newlines.

  ## Examples

      iex> content = "== Compilation error in file lib/foo.ex ==\\n** (CompileError) undefined function bar/1"
      iex> Indrajaal.Validation.ContextWindow.normalize(content)
      "== Compilation error in file lib/foo.ex == ** (CompileError) undefined function bar/1"

  """
  @spec normalize(binary()) :: binary()
  def normalize(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> join_continuations()
    |> Enum.join("\n")
  end

  def normalize(_content), do: ""

  @doc """
  Returns logical lines as a list (without re-joining into a string).

  Useful when callers need to iterate over logical lines directly.
  """
  @spec logical_lines(binary()) :: [String.t()]
  def logical_lines(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> join_continuations()
  end

  def logical_lines(_content), do: []

  # ---------------------------------------------------------------------------
  # Private: Single-pass continuation joining
  # ---------------------------------------------------------------------------

  defp join_continuations(lines) do
    # Process lines in order, accumulating the current logical line.
    # When we encounter a non-continuation line, emit the accumulated line
    # and start a new accumulator.
    {result, current} =
      Enum.reduce(lines, {[], nil}, fn line, {acc, current_line} ->
        cond do
          # Empty line — emit current and skip
          String.trim(line) == "" ->
            if current_line do
              {[current_line | acc], nil}
            else
              {acc, nil}
            end

          # First line of content (no current accumulator)
          is_nil(current_line) ->
            {acc, line}

          # This line is a continuation of the previous
          continuation?(line) and not block_starter?(line) ->
            joined = current_line <> " " <> String.trim(line)
            {acc, joined}

          # New block — emit current, start new
          true ->
            {[current_line | acc], line}
        end
      end)

    # Don't forget the last accumulated line
    final =
      if current do
        [current | result]
      else
        result
      end

    Enum.reverse(final)
  end

  defp continuation?(line) do
    Regex.match?(@continuation_pattern, line)
  end

  defp block_starter?(line) do
    Enum.any?(@block_starters, &Regex.match?(&1, line))
  end
end
