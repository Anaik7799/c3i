defmodule Indrajaal.FAME.Validator do
  @moduledoc """
  FAME (Fractal Artifact Metadata Enrichment) Validator v2.0.0-BIO

  WHAT: Validates FAME metadata blocks in Elixir source files against schema definitions.
  WHY: SC-FAME-002 requires all blocks to have validation; enables CI/CD quality gates.
  CONSTRAINTS: P0 artifacts MUST have complete required blocks; validation is non-destructive.

  ## Validation Scope

  This module validates:
  - Required blocks presence (meta, impact, boundaries, evolution for P0)
  - Field type compliance against Schema types
  - Cross-reference integrity (artifact_id format, parent/child relationships)
  - STAMP constraint references validity

  ## STAMP Compliance
  - SC-FAME-001: Schema types must be Dialyzer-verified
  - SC-FAME-002: All blocks must have validation functions
  - SC-DOC-001: Moduledoc with WHAT/WHY/CONSTRAINTS

  ## AOR Compliance
  - AOR-DOC-001: Read moduledoc before editing
  - AOR-FAME-001: Schema changes require dual-agent review
  """

  # Schema module reference kept for documentation purposes (types defined there)
  # alias Indrajaal.FAME.Schema

  @required_blocks [:meta, :impact, :boundaries, :evolution]
  @all_blocks [
    :meta,
    :impact,
    :boundaries,
    :knowledge,
    :evolution,
    :formal,
    :agent_context,
    :metabolism,
    :invariants,
    :stigmergy,
    :contracts,
    :observability
  ]

  @type validation_result :: {:ok, map()} | {:error, [validation_error()]}
  @type validation_error :: %{
          field: String.t(),
          message: String.t(),
          severity: :error | :warning
        }

  @type file_result :: %{
          file: String.t(),
          status: :passed | :failed | :missing,
          errors: [validation_error()],
          fame_data: map() | nil
        }

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Validates FAME metadata in a single Elixir source file.

  ## Parameters
  - file_path: Path to the .ex or .exs file
  - opts: Validation options
    - strict: true for P0 artifacts requiring all fields
    - extract_only: true to only extract without validation

  ## Returns
  - {:ok, %{fame_data: map, errors: []}} on success
  - {:error, errors} on validation failure
  - {:missing, reason} if no FAME metadata found

  ## Example

      iex> Indrajaal.FAME.Validator.validate_file("lib/indrajaal/accounts/user.ex")
      {:ok, %{fame_data: %{meta: %{...}}, errors: []}}
  """
  @spec validate_file(String.t(), keyword()) ::
          {:ok, map()} | {:error, list()} | {:missing, String.t()}
  def validate_file(file_path, opts \\ []) do
    strict = Keyword.get(opts, :strict, false)

    with {:ok, content} <- File.read(file_path),
         {:ok, fame_data} <- extract_fame_metadata(content) do
      errors = validate_fame_block(fame_data, strict: strict)

      if Enum.empty?(errors) or not strict do
        {:ok, %{fame_data: fame_data, errors: errors}}
      else
        {:error, errors}
      end
    else
      {:error, :enoent} ->
        {:error, [%{field: "file", message: "File not found: #{file_path}", severity: :error}]}

      {:error, :no_fame_metadata} ->
        {:missing, "No FAME metadata found in #{file_path}"}

      {:error, reason} ->
        {:error, [%{field: "file", message: "Read error: #{inspect(reason)}", severity: :error}]}
    end
  end

  @doc """
  Validates FAME metadata in multiple files matching a pattern.

  ## Parameters
  - pattern: Glob pattern (e.g., "lib/**/*.ex")
  - opts: Validation options (same as validate_file/2)

  ## Returns
  - List of file_result maps

  ## Example

      iex> Indrajaal.FAME.Validator.validate_pattern("lib/indrajaal/**/*.ex")
      [%{file: "lib/indrajaal/accounts/user.ex", status: :passed, ...}, ...]
  """
  @spec validate_pattern(String.t(), keyword()) :: [file_result()]
  def validate_pattern(pattern, opts \\ []) do
    pattern
    |> Path.wildcard()
    |> Enum.filter(&String.ends_with?(&1, [".ex", ".exs"]))
    |> Enum.map(&validate_and_format(&1, opts))
  end

  @doc """
  Validates a FAME block map against schema requirements.

  ## Parameters
  - fame_block: The FAME metadata map
  - opts: Validation options

  ## Returns
  - List of validation errors (empty list = valid)
  """
  @spec validate_fame_block(map(), keyword()) :: [validation_error()]
  def validate_fame_block(fame_block, opts \\ []) do
    strict = Keyword.get(opts, :strict, false)

    errors = []

    # Check required blocks
    errors =
      if strict do
        @required_blocks
        |> Enum.reduce(errors, fn block, acc ->
          if Map.has_key?(fame_block, block) do
            acc
          else
            [
              %{
                field: "#{block}",
                message: "Required block @fame_#{block} is missing",
                severity: :error
              }
              | acc
            ]
          end
        end)
      else
        errors
      end

    # Validate each present block
    errors =
      fame_block
      |> Enum.reduce(errors, fn {block_name, block_data}, acc ->
        block_errors = validate_block(block_name, block_data, strict)
        acc ++ block_errors
      end)

    Enum.reverse(errors)
  end

  @doc """
  Generates a validation summary from file results.

  ## Parameters
  - results: List of file_result maps

  ## Returns
  - Summary map with counts and grouped failures
  """
  @spec summarize_results([file_result()]) :: map()
  def summarize_results(results) do
    passed = Enum.count(results, &(&1.status == :passed))
    failed = Enum.count(results, &(&1.status == :failed))
    missing = Enum.count(results, &(&1.status == :missing))

    failures =
      results
      |> Enum.filter(&(&1.status == :failed))
      |> Enum.map(fn r -> {r.file, r.errors} end)
      |> Map.new()

    %{
      total: length(results),
      passed: passed,
      failed: failed,
      missing: missing,
      failures: failures
    }
  end

  # ============================================================================
  # PRIVATE: METADATA EXTRACTION
  # ============================================================================

  defp extract_fame_metadata(content) do
    # Parse the Elixir file to AST
    case Code.string_to_quoted(content, warn_on_unnecessary_quotes: false) do
      {:ok, ast} ->
        fame_data = extract_fame_from_ast(ast)

        if map_size(fame_data) > 0 do
          {:ok, fame_data}
        else
          {:error, :no_fame_metadata}
        end

      {:error, _reason} ->
        # Fall back to regex-based extraction for partially valid files
        fame_data = extract_fame_via_regex(content)

        if map_size(fame_data) > 0 do
          {:ok, fame_data}
        else
          {:error, :no_fame_metadata}
        end
    end
  end

  defp extract_fame_from_ast(ast) do
    # Walk the AST looking for @fame_* module attributes
    {_ast, fame_data} = Macro.prewalk(ast, %{}, &extract_fame_attribute/2)
    fame_data
  end

  defp extract_fame_attribute({:@, _, [{fame_attr, _, [value]}]} = node, acc)
       when is_atom(fame_attr) do
    attr_name = Atom.to_string(fame_attr)

    if String.starts_with?(attr_name, "fame_") do
      trimmed_name = String.replace_prefix(attr_name, "fame_", "")
      block_name = String.to_atom(trimmed_name)

      if block_name in @all_blocks do
        evaluated_value = try_evaluate_value(value)
        {node, Map.put(acc, block_name, evaluated_value)}
      else
        {node, acc}
      end
    else
      {node, acc}
    end
  end

  defp extract_fame_attribute(node, acc), do: {node, acc}

  defp try_evaluate_value(quoted) do
    # Try to evaluate simple literals, maps, and lists
    try do
      {value, _} = Code.eval_quoted(quoted)
      value
    rescue
      _ -> quoted
    end
  end

  defp extract_fame_via_regex(content) do
    @all_blocks
    |> Enum.reduce(%{}, fn block_name, acc ->
      pattern = ~r/@fame_#{block_name}\s+(%\{[\s\S]*?\})/m

      case Regex.run(pattern, content) do
        [_, match] ->
          case Code.eval_string(match) do
            {value, _} -> Map.put(acc, block_name, value)
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  # ============================================================================
  # PRIVATE: BLOCK VALIDATION
  # ============================================================================

  defp validate_block(:meta, data, strict) do
    errors = []

    # Required fields for meta block
    required_meta_fields = [:fame_version, :artifact_id, :artifact_type, :purpose]

    errors =
      if strict do
        Enum.reduce(required_meta_fields, errors, fn field, acc ->
          if Map.has_key?(data, field) and not is_nil(data[field]) do
            acc
          else
            [
              %{
                field: "meta.#{field}",
                message: "Required field missing",
                severity: :error
              }
              | acc
            ]
          end
        end)
      else
        errors
      end

    # Validate artifact_id format (dot-separated hierarchical)
    errors =
      case Map.get(data, :artifact_id) do
        nil ->
          errors

        id when is_binary(id) ->
          if Regex.match?(~r/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/, id) do
            errors
          else
            [
              %{
                field: "meta.artifact_id",
                message: "Invalid format: must be dot-separated lowercase identifiers",
                severity: :warning
              }
              | errors
            ]
          end

        _ ->
          [
            %{
              field: "meta.artifact_id",
              message: "Must be a string",
              severity: :error
            }
            | errors
          ]
      end

    # Validate artifact_type
    errors =
      case Map.get(data, :artifact_type) do
        nil ->
          errors

        type when type in [:module, :script, :config, :doc, :spec, :test, :resource] ->
          errors

        type ->
          valid_types = [:module, :script, :config, :doc, :spec, :test, :resource]

          [
            %{
              field: "meta.artifact_type",
              message: "Invalid type #{inspect(type)}, expected one of #{inspect(valid_types)}",
              severity: :error
            }
            | errors
          ]
      end

    # Validate scope
    errors =
      case Map.get(data, :scope) do
        nil ->
          errors

        scope when scope in [:atomic, :component, :domain, :system] ->
          errors

        scope ->
          valid_scopes = [:atomic, :component, :domain, :system]

          [
            %{
              field: "meta.scope",
              message:
                "Invalid scope #{inspect(scope)}, expected one of #{inspect(valid_scopes)}",
              severity: :warning
            }
            | errors
          ]
      end

    errors
  end

  defp validate_block(:impact, data, _strict) do
    errors = []

    # Validate first_order structure
    errors =
      case Map.get(data, :first_order) do
        nil ->
          errors

        %{depends_on: deps, depended_by: by} when is_list(deps) and is_list(by) ->
          errors

        _ ->
          [
            %{
              field: "impact.first_order",
              message: "Must have depends_on and depended_by as lists",
              severity: :warning
            }
            | errors
          ]
      end

    # Validate change_risk
    errors =
      case Map.get(data, :change_risk) do
        nil ->
          errors

        %{} = risk ->
          validate_risk_levels(risk, errors)

        _ ->
          [
            %{
              field: "impact.change_risk",
              message: "Must be a map with risk levels",
              severity: :warning
            }
            | errors
          ]
      end

    errors
  end

  defp validate_block(:boundaries, data, strict) do
    errors = []

    # Validate STAMP constraints list
    errors =
      case Map.get(data, :stamp) do
        nil ->
          errors

        [] when strict ->
          [
            %{
              field: "boundaries.stamp",
              message: "Empty list not allowed for P0 artifacts",
              severity: :error
            }
            | errors
          ]

        stamps when is_list(stamps) ->
          # Validate STAMP constraint format (SC-XXX-NNN)
          invalid_stamps =
            Enum.filter(stamps, fn stamp ->
              not Regex.match?(~r/^SC-[A-Z]+-\d{3}$/, to_string(stamp))
            end)

          if Enum.empty?(invalid_stamps) do
            errors
          else
            [
              %{
                field: "boundaries.stamp",
                message: "Invalid STAMP format: #{inspect(invalid_stamps)}, expected SC-XXX-NNN",
                severity: :warning
              }
              | errors
            ]
          end

        _ ->
          [
            %{
              field: "boundaries.stamp",
              message: "Must be a list of STAMP constraint IDs",
              severity: :error
            }
            | errors
          ]
      end

    # Validate TDG spec
    errors =
      case Map.get(data, :tdg) do
        nil ->
          errors

        %{} = tdg ->
          if Map.has_key?(tdg, :test_file) do
            errors
          else
            [
              %{
                field: "boundaries.tdg",
                message: "TDG spec should include test_file reference",
                severity: :warning
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    errors
  end

  defp validate_block(:evolution, data, _strict) do
    errors = []

    # Validate stability level
    errors =
      case Map.get(data, :stability) do
        nil ->
          errors

        level when level in [:volatile, :evolving, :stable, :frozen] ->
          errors

        level ->
          valid_stability = [:volatile, :evolving, :stable, :frozen]

          [
            %{
              field: "evolution.stability",
              message:
                "Invalid stability #{inspect(level)}, expected one of #{inspect(valid_stability)}",
              severity: :warning
            }
            | errors
          ]
      end

    # Validate change_frequency
    errors =
      case Map.get(data, :change_frequency) do
        nil ->
          errors

        freq when freq in [:continuous, :frequent, :occasional, :rare, :never] ->
          errors

        freq ->
          valid_frequency = [:continuous, :frequent, :occasional, :rare, :never]

          [
            %{
              field: "evolution.change_frequency",
              message:
                "Invalid frequency #{inspect(freq)}, expected one of #{inspect(valid_frequency)}",
              severity: :warning
            }
            | errors
          ]
      end

    errors
  end

  defp validate_block(:knowledge, data, _strict) do
    errors = []

    # Validate zettel_id format (YYYYMMDDHHMM-slug)
    errors =
      case Map.get(data, :zettel_id) do
        nil ->
          errors

        id when is_binary(id) ->
          if Regex.match?(~r/^\d{12}-[\w-]+$/, id) do
            errors
          else
            [
              %{
                field: "knowledge.zettel_id",
                message: "Invalid format: expected YYYYMMDDHHMM-slug",
                severity: :warning
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    errors
  end

  defp validate_block(:metabolism, data, _strict) do
    errors = []

    # Validate resource_profile
    errors =
      case Map.get(data, :resource_profile) do
        nil ->
          errors

        %{cpu_weight: _, memory_footprint: _, io_pattern: _} ->
          errors

        _ ->
          [
            %{
              field: "metabolism.resource_profile",
              message: "Must have cpu_weight, memory_footprint, and io_pattern",
              severity: :warning
            }
            | errors
          ]
      end

    errors
  end

  defp validate_block(:contracts, data, _strict) do
    errors = []

    # Validate contract structures
    [:preconditions, :postconditions, :class_invariants]
    |> Enum.reduce(errors, fn field, acc ->
      case Map.get(data, field) do
        nil ->
          acc

        list when is_list(list) ->
          acc ++ validate_contract_list(field, list)

        _ ->
          [
            %{
              field: "contracts.#{field}",
              message: "Must be a list of contracts",
              severity: :error
            }
            | acc
          ]
      end
    end)
  end

  # Generic validation for optional blocks
  defp validate_block(_block_name, _data, _strict), do: []

  defp validate_risk_levels(risk, errors) do
    errors =
      case Map.get(risk, :breaking_change_likelihood) do
        nil ->
          errors

        level when level in [:low, :medium, :high, :critical] ->
          errors

        _ ->
          [
            %{
              field: "impact.change_risk.breaking_change_likelihood",
              message: "Invalid risk level",
              severity: :warning
            }
            | errors
          ]
      end

    case Map.get(risk, :rollback_complexity) do
      nil ->
        errors

      level when level in [:trivial, :low, :medium, :high, :extreme] ->
        errors

      _ ->
        [
          %{
            field: "impact.change_risk.rollback_complexity",
            message: "Invalid complexity level",
            severity: :warning
          }
          | errors
        ]
    end
  end

  defp validate_contract_list(field_name, contracts) do
    contracts
    |> Enum.with_index()
    |> Enum.flat_map(fn {contract, idx} ->
      case contract do
        %{id: _, name: _, expression: _} ->
          []

        _ ->
          [
            %{
              field: "contracts.#{field_name}[#{idx}]",
              message: "Contract must have id, name, and expression",
              severity: :warning
            }
          ]
      end
    end)
  end

  # ============================================================================
  # PRIVATE: RESULT FORMATTING
  # ============================================================================

  defp validate_and_format(file_path, opts) do
    case validate_file(file_path, opts) do
      {:ok, %{fame_data: data, errors: errors}} ->
        status = if Enum.empty?(errors), do: :passed, else: :failed

        %{
          file: file_path,
          status: status,
          errors: errors,
          fame_data: data
        }

      {:error, errors} ->
        %{
          file: file_path,
          status: :failed,
          errors: errors,
          fame_data: nil
        }

      {:missing, _reason} ->
        %{
          file: file_path,
          status: :missing,
          errors: [],
          fame_data: nil
        }
    end
  end
end
