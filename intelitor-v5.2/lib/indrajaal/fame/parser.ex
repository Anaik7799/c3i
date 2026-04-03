defmodule Indrajaal.FAME.Parser do
  @moduledoc """
  FAME Metadata Parser - Extracts FAME blocks from Elixir source files.

  WHAT: Parses Elixir modules to extract @fame_* module attributes.
  WHY: Enables validation, reporting, and graph generation from existing code.
  CONSTRAINTS: Must handle malformed FAME gracefully; SC-FAME-003.

  ## Parsing Strategy

  1. **AST-Based**: Uses Code.string_to_quoted for reliable parsing
  2. **Attribute Extraction**: Finds all @fame_* module attributes
  3. **Reconstruction**: Builds complete FAME block from individual attributes
  4. **Fallback**: Returns partial data when some blocks are missing

  ## STAMP Compliance
  - SC-FAME-003: Parser must handle malformed FAME gracefully
  - SC-FAME-004: Parser must report missing required blocks

  ## AOR Compliance
  - AOR-FAME-002: Never crash on parse failure; return error tuple
  """

  alias Indrajaal.FAME.Schema

  @fame_attributes [
    :fame_meta,
    :fame_impact,
    :fame_boundaries,
    :fame_knowledge,
    :fame_evolution,
    :fame_formal,
    :fame_agent_context,
    :fame_metabolism,
    :fame_invariants,
    :fame_stigmergy,
    :fame_contracts,
    :fame_observability
  ]

  @required_attributes [:fame_meta, :fame_impact, :fame_boundaries, :fame_evolution]

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Parses FAME metadata from a file path.

  ## Parameters
  - file_path: Path to the Elixir source file

  ## Returns
  - `{:ok, fame_block}` - Successfully parsed FAME metadata
  - `{:partial, fame_block, missing}` - Partial FAME with list of missing blocks
  - `{:error, reason}` - Parse failure

  ## Example

      iex> Parser.parse_file("lib/indrajaal/accounts/user.ex")
      {:ok, %{meta: %{...}, impact: %{...}, ...}}
  """
  @spec parse_file(String.t()) ::
          {:ok, Schema.fame_block()}
          | {:partial, map(), [atom()]}
          | {:error, term()}
  def parse_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_string(content, file_path)

      {:error, reason} ->
        {:error, {:file_read_error, file_path, reason}}
    end
  end

  @doc """
  Parses FAME metadata from source code string.

  ## Parameters
  - source: Elixir source code as string
  - file_path: Optional file path for error reporting

  ## Returns
  Same as parse_file/1
  """
  @spec parse_string(String.t(), String.t()) ::
          {:ok, Schema.fame_block()}
          | {:partial, map(), [atom()]}
          | {:error, term()}
  def parse_string(source, file_path \\ "<string>") do
    case Code.string_to_quoted(source, file: file_path) do
      {:ok, ast} ->
        extract_fame_from_ast(ast, file_path)

      {:error, {location, message, token}} ->
        {:error, {:parse_error, file_path, location, message, token}}
    end
  end

  @doc """
  Checks if a file contains any FAME metadata.

  ## Parameters
  - file_path: Path to check

  ## Returns
  - `true` if file contains at least @fame_meta
  - `false` otherwise
  """
  @spec has_fame?(String.t()) :: boolean()
  def has_fame?(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        String.contains?(content, "@fame_meta")

      _ ->
        false
    end
  end

  @doc """
  Extracts just the artifact_id from a file's FAME metadata.

  ## Parameters
  - file_path: Path to the file

  ## Returns
  - `{:ok, artifact_id}` or `{:error, reason}`
  """
  @spec get_artifact_id(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_artifact_id(file_path) do
    case parse_file(file_path) do
      {:ok, %{meta: %{artifact_id: id}}} -> {:ok, id}
      {:partial, %{meta: %{artifact_id: id}}, _} -> {:ok, id}
      {:partial, _, _} -> {:error, :no_artifact_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all FAME attributes found in a file.

  ## Parameters
  - file_path: Path to the file

  ## Returns
  - `{:ok, [atom()]}` - List of found FAME attribute names
  - `{:error, reason}`
  """
  @spec list_fame_attributes(String.t()) :: {:ok, [atom()]} | {:error, term()}
  def list_fame_attributes(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        found =
          @fame_attributes
          |> Enum.filter(fn attr ->
            String.contains?(content, "@#{attr}")
          end)

        {:ok, found}

      {:error, reason} ->
        {:error, {:file_read_error, file_path, reason}}
    end
  end

  @doc """
  Calculates FAME completeness score for a file.

  ## Parameters
  - file_path: Path to the file

  ## Returns
  - `{:ok, score}` where score is 0.0 to 1.0
  - `{:error, reason}`
  """
  @spec completeness_score(String.t()) :: {:ok, float()} | {:error, term()}
  def completeness_score(file_path) do
    case list_fame_attributes(file_path) do
      {:ok, found} ->
        total = length(@fame_attributes)
        present = length(found)
        {:ok, present / total}

      error ->
        error
    end
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp extract_fame_from_ast(ast, file_path) do
    attributes = extract_module_attributes(ast)

    fame_attrs =
      attributes
      |> Enum.filter(fn {name, _} -> name in @fame_attributes end)
      |> Map.new()

    if map_size(fame_attrs) == 0 do
      {:error, {:no_fame_metadata, file_path}}
    else
      build_fame_block(fame_attrs)
    end
  end

  defp extract_module_attributes(ast) do
    {_, attrs} =
      Macro.prewalk(ast, [], fn
        {:@, _, [{name, _, [value]}]} = node, acc when is_atom(name) ->
          {node, [{name, safe_eval(value)} | acc]}

        node, acc ->
          {node, acc}
      end)

    attrs
  end

  defp safe_eval(ast) do
    try do
      {value, _} = Code.eval_quoted(ast)
      value
    rescue
      _ -> {:unevaluated, ast}
    end
  end

  defp build_fame_block(attrs) do
    fame_block = %{
      meta: Map.get(attrs, :fame_meta),
      impact: Map.get(attrs, :fame_impact),
      boundaries: Map.get(attrs, :fame_boundaries),
      evolution: Map.get(attrs, :fame_evolution)
    }

    optional_blocks = %{
      knowledge: Map.get(attrs, :fame_knowledge),
      formal: Map.get(attrs, :fame_formal),
      agent_context: Map.get(attrs, :fame_agent_context),
      metabolism: Map.get(attrs, :fame_metabolism),
      invariants: Map.get(attrs, :fame_invariants),
      stigmergy: Map.get(attrs, :fame_stigmergy),
      contracts: Map.get(attrs, :fame_contracts),
      observability: Map.get(attrs, :fame_observability)
    }

    # Add optional blocks that are present
    fame_block =
      optional_blocks
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(fame_block)

    # Check for missing required blocks
    missing =
      @required_attributes
      |> Enum.filter(fn attr ->
        key = attr |> Atom.to_string() |> String.replace("fame_", "") |> String.to_atom()
        is_nil(Map.get(fame_block, key))
      end)
      |> Enum.map(fn attr ->
        attr |> Atom.to_string() |> String.replace("fame_", "") |> String.to_atom()
      end)

    if Enum.empty?(missing) do
      {:ok, fame_block}
    else
      {:partial, fame_block, missing}
    end
  end

  # ============================================================================
  # BATCH OPERATIONS
  # ============================================================================

  @doc """
  Parses FAME from multiple files.

  ## Parameters
  - file_paths: List of file paths to parse

  ## Returns
  - Map of file_path => parse_result
  """
  @spec parse_batch([String.t()]) :: %{
          String.t() => {:ok, map()} | {:partial, map(), [atom()]} | {:error, term()}
        }
  def parse_batch(file_paths) do
    file_paths
    |> Task.async_stream(&{&1, parse_file(&1)}, max_concurrency: System.schedulers_online())
    |> Enum.reduce(%{}, fn
      {:ok, {path, result}}, acc -> Map.put(acc, path, result)
      {:exit, reason}, acc -> Map.put(acc, :error, reason)
    end)
  end

  @doc """
  Scans a directory for files with FAME metadata.

  ## Parameters
  - dir: Directory path to scan
  - pattern: Glob pattern (default "**/*.ex")

  ## Returns
  - `{:ok, %{with_fame: [paths], without_fame: [paths]}}`
  """
  @spec scan_directory(String.t(), String.t()) ::
          {:ok, %{with_fame: [String.t()], without_fame: [String.t()]}}
  def scan_directory(dir, pattern \\ "**/*.ex") do
    path = Path.join(dir, pattern)
    files = Path.wildcard(path)

    {with_fame, without} =
      files
      |> Enum.split_with(&has_fame?/1)

    {:ok, %{with_fame: with_fame, without_fame: without}}
  end

  @doc """
  Generates a FAME coverage report for a directory.

  ## Parameters
  - dir: Directory to analyze

  ## Returns
  - Map with statistics and file lists
  """
  @spec coverage_report(String.t()) :: map()
  def coverage_report(dir) do
    {:ok, %{with_fame: with_fame, without_fame: without}} = scan_directory(dir)

    total = length(with_fame) + length(without)
    coverage_pct = if total > 0, do: length(with_fame) / total * 100, else: 0.0

    completeness_scores =
      with_fame
      |> Enum.map(fn path ->
        case completeness_score(path) do
          {:ok, score} -> {path, score}
          _ -> {path, 0.0}
        end
      end)
      |> Map.new()

    avg_completeness =
      if map_size(completeness_scores) > 0 do
        completeness_scores
        |> Map.values()
        |> Enum.sum()
        |> Kernel./(map_size(completeness_scores))
      else
        0.0
      end

    %{
      total_files: total,
      with_fame: length(with_fame),
      without_fame: length(without),
      coverage_percent: Float.round(coverage_pct, 2),
      average_completeness: Float.round(avg_completeness, 2),
      files_with_fame: with_fame,
      files_without_fame: without,
      completeness_by_file: completeness_scores
    }
  end
end
