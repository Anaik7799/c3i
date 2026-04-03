defmodule Indrajaal.Cortex.GDE.StringScanner do
  @moduledoc """
  String Scanner: DSL for extracting structured data from logs and error messages.

  WHAT: Pattern-based log parsing for error analysis.
  WHY: Converts unstructured log text into structured signals for GDE.
  CONSTRAINTS: Must be composable, safe, and handle malformed input.

  ## Pattern DSL

  The scanner uses a simple DSL for defining extraction patterns:

  ```elixir
  alias Indrajaal.Cortex.GDE.StringScanner

  # Define a pattern
  pattern = StringScanner.pattern([
    literal: "** (CompileError)",
    capture: :file,
    literal: ":",
    capture: :line,
    literal: ":",
    capture: :message
  ])

  # Apply to log text
  {:ok, result} = StringScanner.scan(log_text, pattern)
  # => %{file: "lib/foo.ex", line: "10", message: "undefined function bar/0"}
  ```

  ## Built-in Patterns

  - `:compile_error` - Elixir compilation errors
  - `:test_failure` - ExUnit test failures
  - `:warning` - Compiler warnings
  - `:runtime_error` - Runtime exceptions

  ## STAMP Constraints

  - SC-GDE-030: Patterns must be deterministic
  - SC-GDE-031: Must handle malformed input gracefully
  - SC-GDE-032: Capture groups must be named

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-030 to SC-GDE-032 |
  """

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type pattern_element ::
          {:literal, String.t()}
          | {:capture, atom()}
          | {:capture, atom(), Regex.t()}
          | {:optional, [pattern_element()]}
          | {:skip_until, String.t()}
          | {:skip_whitespace}

  @type pattern :: [pattern_element()]

  @type scan_result :: %{atom() => String.t()}

  # ============================================================
  # PATTERN CONSTRUCTION
  # ============================================================

  @doc """
  Creates a pattern from a list of pattern elements.

  ## Pattern Elements

  - `{:literal, "text"}` - Match literal text
  - `{:capture, :name}` - Capture until next literal
  - `{:capture, :name, regex}` - Capture matching regex
  - `{:optional, elements}` - Optional section
  - `{:skip_until, "text"}` - Skip until literal found
  - `{:skip_whitespace}` - Skip whitespace

  ## Example

      pattern([
        literal: "Error:",
        skip_whitespace: true,
        capture: :message
      ])
  """
  @spec pattern(keyword() | [pattern_element()]) :: pattern()
  def pattern(elements) when is_list(elements) do
    Enum.map(elements, &normalize_element/1)
  end

  @doc """
  Creates a pattern from a format string (simplified syntax).

  ## Format

  - `{name}` - Capture group
  - `{}` - Skip (don't capture)
  - Everything else - literal

  ## Example

      pattern_from_string("** (CompileError) {file}:{line}: {message}")
  """
  @spec pattern_from_string(String.t()) :: pattern()
  def pattern_from_string(format_string) do
    # Parse format string into pattern elements
    split_parts = Regex.split(~r/(\{[^}]*\})/, format_string, include_captures: true)
    filtered = Enum.reject(split_parts, &(&1 == ""))

    Enum.map(filtered, fn part ->
      case Regex.run(~r/\{(\w*)\}/, part) do
        [_, ""] -> {:skip_until, next_literal(format_string, part)}
        [_, name] -> {:capture, String.to_atom(name)}
        nil -> {:literal, part}
      end
    end)
  end

  # ============================================================
  # SCANNING
  # ============================================================

  @doc """
  Scans text using a pattern and extracts captures.

  ## Parameters
  - text: Text to scan
  - pattern: Pattern to match

  ## Returns
  - {:ok, captures} on match
  - {:error, :no_match} if pattern doesn't match
  """
  @spec scan(String.t(), pattern()) :: {:ok, scan_result()} | {:error, :no_match}
  def scan(text, pattern) do
    case do_scan(text, pattern, %{}) do
      {:ok, _remaining, captures} -> {:ok, captures}
      :no_match -> {:error, :no_match}
    end
  end

  @doc """
  Scans text and returns all matches (for patterns that can match multiple times).

  ## Parameters
  - text: Text to scan
  - pattern: Pattern to match
  - opts: Options
    - :limit - Maximum matches (default: 100)

  ## Returns
  - List of capture maps
  """
  @spec scan_all(String.t(), pattern(), keyword()) :: [scan_result()]
  def scan_all(text, pattern, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    do_scan_all(text, pattern, [], limit)
  end

  @doc """
  Checks if text matches a pattern (without capturing).
  """
  @spec matches?(String.t(), pattern()) :: boolean()
  def matches?(text, pattern) do
    match?({:ok, _}, scan(text, pattern))
  end

  # ============================================================
  # BUILT-IN PATTERNS
  # ============================================================

  @doc """
  Returns a built-in pattern by name.

  ## Available Patterns

  - `:compile_error` - `** (CompileError) file:line: message`
  - `:test_failure` - ExUnit test failure
  - `:warning` - Compiler warning
  - `:runtime_error` - Runtime exception
  - `:undefined_function` - Undefined function error
  - `:undefined_module` - Undefined module error
  """
  @spec builtin(atom()) :: pattern()
  def builtin(:compile_error) do
    pattern([
      {:literal, "** (CompileError) "},
      {:capture, :file},
      {:literal, ":"},
      {:capture, :line, ~r/\d+/},
      {:literal, ": "},
      {:capture, :message}
    ])
  end

  def builtin(:test_failure) do
    pattern([
      {:capture, :index, ~r/\d+/},
      {:literal, ") test "},
      {:capture, :test_name},
      {:literal, " ("},
      {:capture, :module},
      {:literal, ")"}
    ])
  end

  def builtin(:warning) do
    pattern([
      {:literal, "warning: "},
      {:capture, :message}
    ])
  end

  def builtin(:runtime_error) do
    pattern([
      {:literal, "** ("},
      {:capture, :error_type},
      {:literal, ") "},
      {:capture, :message}
    ])
  end

  def builtin(:undefined_function) do
    pattern([
      {:literal, "undefined function "},
      {:capture, :function},
      {:literal, "/"},
      {:capture, :arity, ~r/\d+/}
    ])
  end

  def builtin(:undefined_module) do
    pattern([
      {:literal, "undefined module "},
      {:capture, :module}
    ])
  end

  def builtin(:ash_error) do
    pattern([
      {:literal, "** (Ash.Error."},
      {:capture, :error_type},
      {:literal, ") "},
      {:capture, :message}
    ])
  end

  def builtin(_), do: []

  # ============================================================
  # EXTRACTION HELPERS
  # ============================================================

  @doc """
  Extracts all compile errors from log text.
  """
  @spec extract_compile_errors(String.t()) :: [scan_result()]
  def extract_compile_errors(text) do
    scan_all(text, builtin(:compile_error))
  end

  @doc """
  Extracts all test failures from log text.
  """
  @spec extract_test_failures(String.t()) :: [scan_result()]
  def extract_test_failures(text) do
    scan_all(text, builtin(:test_failure))
  end

  @doc """
  Extracts all warnings from log text.
  """
  @spec extract_warnings(String.t()) :: [scan_result()]
  def extract_warnings(text) do
    scan_all(text, builtin(:warning))
  end

  @doc """
  Extracts structured error info from any error text.

  Returns the first matching pattern's result.
  """
  @spec extract_error(String.t()) :: {:ok, map()} | {:error, :unknown}
  def extract_error(text) do
    patterns = [
      {:compile_error, builtin(:compile_error)},
      {:runtime_error, builtin(:runtime_error)},
      {:undefined_function, builtin(:undefined_function)},
      {:undefined_module, builtin(:undefined_module)},
      {:ash_error, builtin(:ash_error)}
    ]

    Enum.find_value(patterns, {:error, :unknown}, fn {type, pattern} ->
      case scan(text, pattern) do
        {:ok, captures} -> {:ok, Map.put(captures, :type, type)}
        {:error, _} -> nil
      end
    end)
  end

  # ============================================================
  # PRIVATE - PATTERN NORMALIZATION
  # ============================================================

  defp normalize_element({:literal, text}), do: {:literal, text}
  defp normalize_element({:capture, name}), do: {:capture, name}
  defp normalize_element({:capture, name, regex}), do: {:capture, name, regex}

  defp normalize_element({:optional, elements}),
    do: {:optional, Enum.map(elements, &normalize_element/1)}

  defp normalize_element({:skip_until, text}), do: {:skip_until, text}
  defp normalize_element({:skip_whitespace}), do: {:skip_whitespace}
  defp normalize_element({:skip_whitespace, true}), do: {:skip_whitespace}
  defp normalize_element({key, value}) when is_atom(key), do: {key, value}

  defp next_literal(format_string, after_part) do
    case String.split(format_string, after_part, parts: 2) do
      [_, rest] ->
        case Regex.run(~r/^\{[^}]*\}(.+?)(?:\{|$)/, rest) do
          [_, lit] -> lit
          nil -> "\n"
        end

      _ ->
        "\n"
    end
  end

  # ============================================================
  # PRIVATE - SCANNING IMPLEMENTATION
  # ============================================================

  defp do_scan(text, [], captures), do: {:ok, text, captures}

  defp do_scan(text, [{:literal, lit} | rest], captures) do
    case String.split(text, lit, parts: 2) do
      [_, remaining] -> do_scan(remaining, rest, captures)
      [_] -> :no_match
    end
  end

  defp do_scan(text, [{:capture, name} | rest], captures) do
    # Capture until next literal or end
    case rest do
      [] ->
        # Capture rest of line
        line = text |> String.split("\n", parts: 2) |> List.first() |> String.trim()
        {:ok, "", Map.put(captures, name, line)}

      [{:literal, next_lit} | _] ->
        case String.split(text, next_lit, parts: 2) do
          [captured, remaining] ->
            do_scan(next_lit <> remaining, rest, Map.put(captures, name, String.trim(captured)))

          [_] ->
            :no_match
        end

      _ ->
        :no_match
    end
  end

  defp do_scan(text, [{:capture, name, regex} | rest], captures) do
    case Regex.run(regex, text, return: :index) do
      [{start, len}] ->
        captured = String.slice(text, start, len)
        remaining = String.slice(text, start + len, String.length(text))
        do_scan(remaining, rest, Map.put(captures, name, captured))

      nil ->
        :no_match
    end
  end

  defp do_scan(text, [{:skip_whitespace} | rest], captures) do
    do_scan(String.trim_leading(text), rest, captures)
  end

  defp do_scan(text, [{:skip_until, lit} | rest], captures) do
    case String.split(text, lit, parts: 2) do
      [_, remaining] -> do_scan(remaining, rest, captures)
      [_] -> :no_match
    end
  end

  defp do_scan(text, [{:optional, elements} | rest], captures) do
    case do_scan(text, elements ++ rest, captures) do
      {:ok, remaining, new_captures} -> {:ok, remaining, new_captures}
      :no_match -> do_scan(text, rest, captures)
    end
  end

  defp do_scan_all(_text, _pattern, results, 0), do: Enum.reverse(results)

  defp do_scan_all("", _pattern, results, _limit), do: Enum.reverse(results)

  defp do_scan_all(text, pattern, results, limit) do
    case do_scan(text, pattern, %{}) do
      {:ok, remaining, captures} ->
        # Move to next line to find more matches
        next_text =
          case String.split(remaining, "\n", parts: 2) do
            [_, rest] -> rest
            [_] -> ""
          end

        do_scan_all(next_text, pattern, [captures | results], limit - 1)

      :no_match ->
        # Try next line
        case String.split(text, "\n", parts: 2) do
          [_, rest] -> do_scan_all(rest, pattern, results, limit)
          [_] -> Enum.reverse(results)
        end
    end
  end
end
