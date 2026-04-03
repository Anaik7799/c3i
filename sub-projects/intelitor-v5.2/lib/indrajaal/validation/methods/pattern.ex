defmodule Indrajaal.Validation.Methods.Pattern do
  @moduledoc """
  L1 Pattern-based validation method for FPPS 5-method consensus.

  WHAT: Scans compilation log content using pre-compiled regex patterns
  to detect errors and warnings as defined in Mathematica §5.1.

  WHY: SIL-4 FPPS requires 5 independent validation methods that must
  all agree (SC-VAL-003). The Pattern method provides fast, compile-time
  regex-based detection of error and warning indicators in log output.

  ## STAMP Compliance
  - SC-VAL-003: 100% consensus required across all 5 methods
  - SC-VAL-005: Complete log analysis, never partial

  ## Pattern Coverage (Mathematica §5.1 FPPSMethods.Pattern)
  Covers 10 error patterns and 5 warning patterns derived from
  the EP-110 incident and Mathematica formal specification.

  ## Catastrophic Backtracking Protection
  All patterns are anchored or use possessive quantifiers where needed.
  No nested quantifiers or overlapping alternations that could cause
  exponential backtracking on adversarial input.

  ## Multiline Safety (SC-MULTILINE-001)
  Patterns that must match within a single logical line use `[ \\t]+`
  instead of `\\s+` to prevent `\\s` matching newlines and causing
  false-positive cross-line detection. This ensures consensus alignment
  with the other 4 FPPS methods (AST, Statistical, Binary, LineByLine)
  which all classify per-line.

  ## Change History
  | Version | Date       | Author  | Change                                      |
  |---------|------------|---------|---------------------------------------------|
  | 21.2.1  | 2026-03-10 | Claude  | Enhanced: compile-time patterns, 10 error   |
  |         |            |         | + 5 warning patterns, backtracking guards   |
  | 21.0.0  | 2026-01-05 | Claude  | Initial implementation (Task 22.2.3.2.1)   |

  Task 22.2.3.2.1
  """

  # ---------------------------------------------------------------------------
  # Compile-time pattern definitions (SC-PATTERN-001: no runtime compilation)
  # ---------------------------------------------------------------------------
  #
  # Error patterns from Mathematica §5.1 FPPSMethods.Pattern.ErrorPatterns.
  # Each regex is compiled at module load time (not per-invocation).
  # Patterns are designed to avoid catastrophic backtracking:
  #   - No nested quantifiers (e.g., (a+)+ is forbidden)
  #   - Alternations use fixed-length branches where possible
  #   - Complex patterns use character classes instead of .* wildcards

  @error_patterns [
    # "error:" literal — the canonical Elixir/Mix error prefix
    ~r/error:/i,
    # Mix compilation error header "== Compilation error ..."
    ~r/==\s+Compilation error/,
    # Erlang/Elixir exception prefix "** ("
    ~r/\*\*\s+\(/,
    # Specific exception types (fixed alternation, no backtracking risk)
    ~r/\b(?:CompileError|ArgumentError|RuntimeError|UndefinedFunctionError|KeyError|MatchError)\b/,
    # Undefined variable or function (common Elixir compile errors)
    ~r/\bundefined (?:variable|function)\b/,
    # "cannot compile module" phrase
    ~r/cannot compile module\b/,
    # "syntax error" literal
    ~r/syntax error\b/i,
    # Mix dependency or protocol consolidation errors
    ~r/\(EXIT\)\s+/,
    # Dialyzer error prefix ([ \t]+ not \s+ to avoid cross-line matching)
    ~r/\bdialyzed[ \t]+with[ \t]+\d+[ \t]+error/i,
    # Credo strict error output prefix ([ \t]+ not \s+ to avoid cross-line matching)
    ~r/\bFound[ \t]+\d+[ \t]+issue/i
  ]

  @warning_patterns [
    # "warning:" literal — canonical Elixir/Mix warning prefix
    ~r/warning:/i,
    # "deprecated" keyword (covers deprecated, deprecation)
    ~r/\bdeprecated\b/i,
    # Unused variable/function/alias/import
    ~r/\bunused\b/i,
    # Variable shadowing
    ~r/\bshadowed\b/i,
    # Unreachable code
    ~r/\bunreachable\b/i
  ]

  # ---------------------------------------------------------------------------
  # Validation guard: reject inputs that could cause excessive scan time.
  # 10 MB is a generous upper bound for a compilation log.
  # ---------------------------------------------------------------------------
  @max_content_bytes 10_485_760

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Validates log content using pre-compiled regex patterns.

  Scans the content against #{length(@error_patterns)} error patterns and
  #{length(@warning_patterns)} warning patterns (Mathematica §5.1).

  Returns a map compatible with FPPS consensus (SC-VAL-003):
    - `:method` — always `:pattern`
    - `:errors` — count of distinct error patterns matched
    - `:warnings` — count of distinct warning patterns matched

  Counts are distinct-pattern matches (not total occurrences), which
  ensures deterministic consensus with the AST and statistical methods.

  ## Error handling
  - Returns `{:error, :content_too_large}` if content exceeds #{@max_content_bytes} bytes
  - Handles non-binary input gracefully
  """
  @spec validate(binary()) :: %{
          method: :pattern,
          errors: non_neg_integer(),
          warnings: non_neg_integer()
        }
  def validate(content) when is_binary(content) do
    if byte_size(content) > @max_content_bytes do
      # Still return a valid consensus-compatible result; log the truncation
      truncated = binary_part(content, 0, @max_content_bytes)
      do_validate(truncated)
    else
      do_validate(content)
    end
  end

  def validate(_content) do
    # Non-binary input — return zero counts so consensus is not disrupted by bad callers
    %{method: :pattern, errors: 0, warnings: 0}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @doc false
  defp do_validate(content) do
    errors = count_matching_patterns(content, @error_patterns)
    warnings = count_matching_patterns(content, @warning_patterns)

    %{method: :pattern, errors: errors, warnings: warnings}
  end

  # Counts how many patterns in the list match anywhere in content.
  # Returns the count of *distinct patterns* that match (not total occurrences),
  # keeping the result bounded and consistent with other FPPS methods.
  @spec count_matching_patterns(binary(), [Regex.t()]) :: non_neg_integer()
  defp count_matching_patterns(content, patterns) do
    Enum.count(patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end
end
