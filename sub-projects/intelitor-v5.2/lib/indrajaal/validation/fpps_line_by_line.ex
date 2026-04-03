defmodule Indrajaal.Validation.FPPSLineByLine do
  @moduledoc """
  FPPS Line-by-Line Validation Method

  WHAT: Provides source code line-by-line validation for FPPS 5-point consensus.

  WHY: SIL-4 requires multiple independent validation methods.
  Line-by-line validation inspects source code for patterns, syntax,
  STAMP constraint compliance, and coding standards.

  CONSTRAINTS:
  - SC-SIL4-023: FPPS 3/5 consensus required
  - SC-VAL-001: Patient Mode validation only
  - SC-DOC-001: moduledoc with WHAT/WHY/CONSTRAINTS

  TECHNIQUES:
  | Technique | Purpose |
  |-----------|---------|
  | Pattern Matching | Detect anti-patterns |
  | Syntax Verification | Ensure valid Elixir |
  | STAMP Compliance | Check constraint markers |
  | Style Checking | Coding standards |

  AOR:
  - AOR-VAL-004: Source must comply with STAMP constraints
  - AOR-DOC-001: Read moduledoc before editing
  """

  require Logger

  # =============================================================================
  # Types
  # =============================================================================

  @type validation_target :: :elixir | :fsharp | :config | :documentation
  @type validation_result :: :healthy | :unhealthy | :degraded | :unknown

  @type violation :: %{
          file: String.t(),
          line: non_neg_integer(),
          column: non_neg_integer() | nil,
          rule: String.t(),
          message: String.t(),
          severity: :error | :warning | :info
        }

  @type line_report :: %{
          target: String.t(),
          result: validation_result(),
          file_count: non_neg_integer(),
          line_count: non_neg_integer(),
          violations: [violation()],
          error_count: non_neg_integer(),
          warning_count: non_neg_integer(),
          stamp_compliance: float(),
          confidence: float()
        }

  # =============================================================================
  # Constants
  # =============================================================================

  @anti_patterns [
    # SC-VAR-001: No underscore prefix on used variables
    {~r/(_[a-z][a-zA-Z0-9_]*)\s*=[^=].*\n.*[^_]\1[^_a-zA-Z0-9]/,
     "SC-VAR-001: Underscore-prefixed variable is used"},

    # SC-CREDO-001: No apply/2
    {~r/apply\(\s*[A-Z][a-zA-Z0-9_.]*,\s*:[a-z_]+,\s*\[/,
     "SC-CREDO-001: Use direct Module.function() calls instead of apply/2"},

    # SC-PROP-023: Must use PC/SD aliases
    {~r/forall\s+\w+\s*<-\s*(?!PC\.)[a-z_]+\(\)/,
     "SC-PROP-023: Use PC. prefix for PropCheck generators"},

    # SC-ASH-001: force_change_attribute pattern
    {~r/change\.data\[[^\]]+\]\s*=[^=]/,
     "SC-ASH-001: Use force_change_attribute in before_action"},

    # SC-NIF-001: NIF blocking
    {~r/:erlang\.nif_error\s*\(/, "SC-NIF-001: Ensure NIF does not block BEAM scheduler"}
  ]

  @required_patterns [
    # SC-DOC-001: moduledoc required
    {~r/@moduledoc\s+"""/, "SC-DOC-001: @moduledoc required", :warning},

    # SC-DB-001: BaseResource usage
    {~r/use\s+Indrajaal\.BaseResource/, "SC-DB-001: Ash resources must use BaseResource", :info}
  ]

  @stamp_marker_pattern ~r/SC-[A-Z]+-\d{3}/

  # =============================================================================
  # FPPS Consensus API (SC-VAL-003)
  # =============================================================================
  # Counts the same 10 error + 5 warning categories as Pattern, but
  # classifies each line individually using heuristic rules rather than
  # full-content regex.  A category is "present" if at least one line
  # in the log is classified as belonging to that category.

  @doc """
  Validates compilation log content using per-line heuristic classification.

  Counts distinct error/warning categories (same 10+5 as Pattern module)
  by classifying each line. Returns a consensus-compatible map.

  This is the primary entry point for FPPS 5-method consensus.
  """
  @spec validate_log_content(binary()) :: %{
          method: :line_by_line,
          errors: non_neg_integer(),
          warnings: non_neg_integer()
        }
  def validate_log_content(content) when is_binary(content) do
    lines = String.split(content, "\n")

    # Classify each line and collect which categories are hit
    {error_cats, warning_cats} =
      Enum.reduce(lines, {MapSet.new(), MapSet.new()}, fn line, {err_acc, warn_acc} ->
        lower = String.downcase(line)
        errs = classify_error_categories(lower)
        warns = classify_warning_categories(lower)
        {MapSet.union(err_acc, errs), MapSet.union(warn_acc, warns)}
      end)

    %{
      method: :line_by_line,
      errors: MapSet.size(error_cats),
      warnings: MapSet.size(warning_cats)
    }
  end

  def validate_log_content(_content) do
    %{method: :line_by_line, errors: 0, warnings: 0}
  end

  # Returns a MapSet of error category indices (1-10) that this line matches.
  defp classify_error_categories(lower_line) do
    cats = MapSet.new()

    cats = if String.contains?(lower_line, "error:"), do: MapSet.put(cats, 1), else: cats

    cats =
      if String.contains?(lower_line, "compilation error"),
        do: MapSet.put(cats, 2),
        else: cats

    cats = if String.contains?(lower_line, "** ("), do: MapSet.put(cats, 3), else: cats

    cats =
      if Enum.any?(
           [
             "compileerror",
             "argumenterror",
             "runtimeerror",
             "undefinedfunctionerror",
             "keyerror",
             "matcherror"
           ],
           &String.contains?(lower_line, &1)
         ),
         do: MapSet.put(cats, 4),
         else: cats

    cats =
      if String.contains?(lower_line, "undefined variable") or
           String.contains?(lower_line, "undefined function"),
         do: MapSet.put(cats, 5),
         else: cats

    cats =
      if String.contains?(lower_line, "cannot compile module"),
        do: MapSet.put(cats, 6),
        else: cats

    cats =
      if String.contains?(lower_line, "syntax error"), do: MapSet.put(cats, 7), else: cats

    cats = if String.contains?(lower_line, "(exit)"), do: MapSet.put(cats, 8), else: cats

    cats =
      if String.contains?(lower_line, "dialyzed with"), do: MapSet.put(cats, 9), else: cats

    if String.contains?(lower_line, "found") and String.contains?(lower_line, "issue"),
      do: MapSet.put(cats, 10),
      else: cats
  end

  # Returns a MapSet of warning category indices (1-5) that this line matches.
  defp classify_warning_categories(lower_line) do
    cats = MapSet.new()
    cats = if String.contains?(lower_line, "warning:"), do: MapSet.put(cats, 1), else: cats
    cats = if String.contains?(lower_line, "deprecated"), do: MapSet.put(cats, 2), else: cats
    cats = if String.contains?(lower_line, "unused"), do: MapSet.put(cats, 3), else: cats
    cats = if String.contains?(lower_line, "shadowed"), do: MapSet.put(cats, 4), else: cats

    if String.contains?(lower_line, "unreachable"),
      do: MapSet.put(cats, 5),
      else: cats
  end

  # =============================================================================
  # Public API (Rich Reports — used by validate_artifacts, not consensus)
  # =============================================================================

  @doc """
  Validates source files using line-by-line analysis.
  """
  @spec validate(String.t(), validation_target(), keyword()) ::
          {:ok, line_report()} | {:error, term()}
  def validate(target, type, opts \\ []) do
    case type do
      :elixir -> validate_elixir_files(target, opts)
      :fsharp -> validate_fsharp_files(target, opts)
      :config -> validate_config_files(target, opts)
      :documentation -> validate_documentation(target, opts)
    end
  end

  @doc """
  Validates Elixir source files.
  """
  @spec validate_elixir_files(String.t(), keyword()) :: {:ok, line_report()} | {:error, term()}
  def validate_elixir_files(path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "**/*.ex")
    exclude = Keyword.get(opts, :exclude, ["_build/**", "deps/**"])

    files = find_files(path, pattern, exclude)

    if length(files) > 0 do
      results = Enum.map(files, &analyze_elixir_file/1)

      violations = Enum.flat_map(results, fn {_, _, violations} -> violations end)
      total_lines = Enum.sum(Enum.map(results, fn {_, lines, _} -> lines end))

      error_count = Enum.count(violations, &(&1.severity == :error))
      warning_count = Enum.count(violations, &(&1.severity == :warning))

      stamp_compliance = calculate_stamp_compliance(files)

      report = %{
        target: path,
        result: determine_result(error_count, warning_count),
        file_count: length(files),
        line_count: total_lines,
        violations: violations,
        error_count: error_count,
        warning_count: warning_count,
        stamp_compliance: stamp_compliance,
        confidence: calculate_confidence(length(files), error_count)
      }

      {:ok, report}
    else
      {:error, {:no_files_found, path}}
    end
  end

  @doc """
  Validates F# source files.
  """
  @spec validate_fsharp_files(String.t(), keyword()) :: {:ok, line_report()} | {:error, term()}
  def validate_fsharp_files(path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "**/*.fs")
    exclude = Keyword.get(opts, :exclude, ["bin/**", "obj/**"])

    files = find_files(path, pattern, exclude)

    if length(files) > 0 do
      results = Enum.map(files, &analyze_fsharp_file/1)

      violations = Enum.flat_map(results, fn {_, _, violations} -> violations end)
      total_lines = Enum.sum(Enum.map(results, fn {_, lines, _} -> lines end))

      error_count = Enum.count(violations, &(&1.severity == :error))
      warning_count = Enum.count(violations, &(&1.severity == :warning))

      report = %{
        target: path,
        result: determine_result(error_count, warning_count),
        file_count: length(files),
        line_count: total_lines,
        violations: violations,
        error_count: error_count,
        warning_count: warning_count,
        stamp_compliance: 1.0,
        confidence: calculate_confidence(length(files), error_count)
      }

      {:ok, report}
    else
      {:error, {:no_files_found, path}}
    end
  end

  @doc """
  Validates configuration files.
  """
  @spec validate_config_files(String.t(), keyword()) :: {:ok, line_report()} | {:error, term()}
  def validate_config_files(path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "**/*.exs")

    config_files = find_files(path, pattern, [])

    if length(config_files) > 0 do
      results = Enum.map(config_files, &analyze_config_file/1)

      violations = Enum.flat_map(results, fn {_, _, violations} -> violations end)
      total_lines = Enum.sum(Enum.map(results, fn {_, lines, _} -> lines end))

      error_count = Enum.count(violations, &(&1.severity == :error))
      warning_count = Enum.count(violations, &(&1.severity == :warning))

      report = %{
        target: path,
        result: determine_result(error_count, warning_count),
        file_count: length(config_files),
        line_count: total_lines,
        violations: violations,
        error_count: error_count,
        warning_count: warning_count,
        stamp_compliance: 1.0,
        confidence: calculate_confidence(length(config_files), error_count)
      }

      {:ok, report}
    else
      {:error, {:no_files_found, path}}
    end
  end

  @doc """
  Validates documentation files (markdown).
  """
  @spec validate_documentation(String.t(), keyword()) :: {:ok, line_report()} | {:error, term()}
  def validate_documentation(path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "**/*.md")

    doc_files = find_files(path, pattern, ["node_modules/**"])

    if length(doc_files) > 0 do
      results = Enum.map(doc_files, &analyze_doc_file/1)

      violations = Enum.flat_map(results, fn {_, _, violations} -> violations end)
      total_lines = Enum.sum(Enum.map(results, fn {_, lines, _} -> lines end))

      error_count = Enum.count(violations, &(&1.severity == :error))
      warning_count = Enum.count(violations, &(&1.severity == :warning))

      report = %{
        target: path,
        result: determine_result(error_count, warning_count),
        file_count: length(doc_files),
        line_count: total_lines,
        violations: violations,
        error_count: error_count,
        warning_count: warning_count,
        stamp_compliance: 1.0,
        confidence: calculate_confidence(length(doc_files), error_count)
      }

      {:ok, report}
    else
      {:error, {:no_files_found, path}}
    end
  end

  @doc """
  Gets the validation result only (for FPPS consensus).
  """
  @spec get_result(String.t(), validation_target()) :: validation_result()
  def get_result(target, type) do
    case validate(target, type) do
      {:ok, report} -> report.result
      {:error, _} -> :unknown
    end
  end

  @doc """
  Validates a single file and returns violations.
  """
  @spec validate_file(String.t()) :: {:ok, [violation()]} | {:error, term()}
  def validate_file(file_path) do
    cond do
      String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs") ->
        {_file, _lines, violations} = analyze_elixir_file(file_path)
        {:ok, violations}

      String.ends_with?(file_path, ".fs") ->
        {_file, _lines, violations} = analyze_fsharp_file(file_path)
        {:ok, violations}

      String.ends_with?(file_path, ".md") ->
        {_file, _lines, violations} = analyze_doc_file(file_path)
        {:ok, violations}

      true ->
        {:error, {:unsupported_file_type, file_path}}
    end
  end

  # =============================================================================
  # Private: File Discovery
  # =============================================================================

  defp find_files(path, pattern, exclude) do
    full_pattern = Path.join(path, pattern)

    full_pattern
    |> Path.wildcard()
    |> Enum.reject(fn file ->
      Enum.any?(exclude, fn exclude_pattern ->
        exclude_full = Path.join(path, exclude_pattern)
        String.starts_with?(file, String.replace(exclude_full, "**", ""))
      end)
    end)
    |> Enum.reject(&File.dir?/1)
  end

  # =============================================================================
  # Private: Elixir Analysis
  # =============================================================================

  defp analyze_elixir_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        line_count = length(lines)

        # Check anti-patterns
        anti_violations = check_anti_patterns(file_path, content)

        # Check required patterns (for specific file types)
        required_violations =
          if is_module_file?(file_path) do
            check_required_patterns(file_path, content)
          else
            []
          end

        # Check syntax
        syntax_violations = check_elixir_syntax(file_path, content)

        all_violations = anti_violations ++ required_violations ++ syntax_violations

        {file_path, line_count, all_violations}

      {:error, _} ->
        {file_path, 0, []}
    end
  end

  defp is_module_file?(path) do
    String.ends_with?(path, ".ex") && !String.contains?(path, "test/")
  end

  defp check_anti_patterns(file_path, content) do
    @anti_patterns
    |> Enum.flat_map(fn {pattern, message} ->
      case Regex.run(pattern, content, return: :index) do
        [{start, _}] ->
          line_number = count_lines_before(content, start)

          [
            %{
              file: file_path,
              line: line_number,
              column: nil,
              rule: extract_rule_id(message),
              message: message,
              severity: :warning
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp check_required_patterns(file_path, content) do
    @required_patterns
    |> Enum.flat_map(fn {pattern, message, severity} ->
      if Regex.match?(pattern, content) do
        []
      else
        [
          %{
            file: file_path,
            line: 1,
            column: nil,
            rule: extract_rule_id(message),
            message: message,
            severity: severity
          }
        ]
      end
    end)
  end

  defp check_elixir_syntax(file_path, content) do
    case Code.string_to_quoted(content) do
      {:ok, _ast} ->
        []

      {:error, {line, message, token}} ->
        [
          %{
            file: file_path,
            line: line,
            column: nil,
            rule: "SYNTAX-001",
            message: "Syntax error: #{message} (token: #{inspect(token)})",
            severity: :error
          }
        ]
    end
  rescue
    _ ->
      []
  end

  defp count_lines_before(content, byte_offset) do
    content
    |> binary_part(0, min(byte_offset, byte_size(content)))
    |> String.split("\n")
    |> length()
  end

  defp extract_rule_id(message) do
    case Regex.run(~r/^(SC-[A-Z]+-\d{3})/, message) do
      [_, rule_id] -> rule_id
      _ -> "UNKNOWN"
    end
  end

  # =============================================================================
  # Private: F# Analysis
  # =============================================================================

  defp analyze_fsharp_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        line_count = length(lines)

        violations = check_fsharp_patterns(file_path, content, lines)

        {file_path, line_count, violations}

      {:error, _} ->
        {file_path, 0, []}
    end
  end

  defp check_fsharp_patterns(file_path, content, lines) do
    violations = []

    # Check for mutable variables (let mutable)
    mutable_violations =
      lines
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _} -> String.contains?(line, "let mutable") end)
      |> Enum.map(fn {_, line_num} ->
        %{
          file: file_path,
          line: line_num,
          column: nil,
          rule: "FS-MUT-001",
          message: "Avoid mutable variables in F#",
          severity: :warning
        }
      end)

    # Check for unchecked exceptions
    exception_violations =
      if String.contains?(content, "failwith") do
        [
          %{
            file: file_path,
            line: find_line_with(lines, "failwith"),
            column: nil,
            rule: "FS-EXC-001",
            message: "Consider using Result instead of failwith",
            severity: :info
          }
        ]
      else
        []
      end

    violations ++ mutable_violations ++ exception_violations
  end

  defp find_line_with(lines, pattern) do
    case Enum.find_index(lines, &String.contains?(&1, pattern)) do
      nil -> 1
      idx -> idx + 1
    end
  end

  # =============================================================================
  # Private: Config Analysis
  # =============================================================================

  defp analyze_config_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        line_count = length(lines)

        violations = check_config_patterns(file_path, content)

        {file_path, line_count, violations}

      {:error, _} ->
        {file_path, 0, []}
    end
  end

  defp check_config_patterns(file_path, content) do
    violations = []

    # Check for hardcoded secrets
    secret_patterns = [
      ~r/password:\s*"[^"]+"/,
      ~r/secret_key_base:\s*"[^"]+"/,
      ~r/api_key:\s*"[^"]+"/
    ]

    secret_violations =
      secret_patterns
      |> Enum.flat_map(fn pattern ->
        if Regex.match?(pattern, content) do
          [
            %{
              file: file_path,
              line: 1,
              column: nil,
              rule: "CFG-SEC-001",
              message: "Potential hardcoded secret detected",
              severity: :warning
            }
          ]
        else
          []
        end
      end)

    violations ++ secret_violations
  end

  # =============================================================================
  # Private: Documentation Analysis
  # =============================================================================

  defp analyze_doc_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        line_count = length(lines)

        violations = check_doc_patterns(file_path, content, lines)

        {file_path, line_count, violations}

      {:error, _} ->
        {file_path, 0, []}
    end
  end

  defp check_doc_patterns(file_path, _content, lines) do
    violations = []

    # Check for broken links (basic check)
    broken_link_violations =
      lines
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, line_num} ->
        # Look for markdown links
        case Regex.run(~r/\[([^\]]+)\]\(([^)]+)\)/, line) do
          [_, _text, url] ->
            if String.starts_with?(url, "http") do
              []
            else
              # Local link - check if file exists
              target = Path.join(Path.dirname(file_path), url)

              if File.exists?(target) or String.starts_with?(url, "#") do
                []
              else
                [
                  %{
                    file: file_path,
                    line: line_num,
                    column: nil,
                    rule: "DOC-LINK-001",
                    message: "Potentially broken link: #{url}",
                    severity: :warning
                  }
                ]
              end
            end

          _ ->
            []
        end
      end)

    # Check for TODO/FIXME comments
    todo_violations =
      lines
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _} ->
        String.contains?(String.upcase(line), ["TODO", "FIXME", "XXX"])
      end)
      |> Enum.map(fn {_, line_num} ->
        %{
          file: file_path,
          line: line_num,
          column: nil,
          rule: "DOC-TODO-001",
          message: "TODO/FIXME comment found",
          severity: :info
        }
      end)

    violations ++ broken_link_violations ++ todo_violations
  end

  # =============================================================================
  # Private: STAMP Compliance
  # =============================================================================

  defp calculate_stamp_compliance(files) do
    # Count files with STAMP constraint markers
    files_with_stamp =
      files
      |> Enum.count(fn file ->
        case File.read(file) do
          {:ok, content} -> Regex.match?(@stamp_marker_pattern, content)
          _ -> false
        end
      end)

    if length(files) > 0 do
      files_with_stamp / length(files)
    else
      1.0
    end
  end

  # =============================================================================
  # Private: Result Determination
  # =============================================================================

  defp determine_result(error_count, warning_count) do
    cond do
      error_count > 0 -> :unhealthy
      warning_count > 5 -> :degraded
      warning_count > 0 -> :degraded
      true -> :healthy
    end
  end

  defp calculate_confidence(file_count, error_count) do
    if file_count == 0 do
      0.0
    else
      max(0.0, 1.0 - error_count / file_count)
    end
  end
end
