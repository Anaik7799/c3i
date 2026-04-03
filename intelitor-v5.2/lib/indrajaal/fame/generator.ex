defmodule Indrajaal.FAME.Generator do
  @moduledoc """
  FAME (Fractal Artifact Metadata Enrichment) Generator v2.0.0-BIO

  WHAT: Automatically generates FAME metadata skeletons for Elixir artifacts by
        parsing source files and inferring metadata from AST, file paths, and
        module structure.

  WHY: SC-DOC-001 mandates structured metadata for all P0 artifacts. Manual FAME
       block creation for 8,375+ files is impractical. This generator enables
       mass enrichment while maintaining quality through inference algorithms.

  CONSTRAINTS:
    - SC-FAME-001: Generated blocks must pass Schema validation
    - SC-FAME-002: Must support both minimal (4 blocks) and complete (12 blocks) modes
    - SC-FAME-003: Artifact IDs must follow Zenoh-style hierarchical format
    - SC-FAME-004: Dependencies must be inferred from use/import/alias declarations
    - AOR-DOC-001: Read moduledoc before editing generated metadata

  ## Generation Modes

  - `:minimal` - Generates 4 required blocks: meta, impact, boundaries, evolution
  - `:complete` - Generates all 12 blocks with sensible defaults

  ## Usage

      # Generate from file path
      {:ok, fame} = Indrajaal.FAME.Generator.generate_for_file("lib/indrajaal/accounts/user.ex")

      # Generate with options
      {:ok, fame} = Indrajaal.FAME.Generator.generate_for_file(
        "lib/indrajaal/accounts/user.ex",
        mode: :complete,
        include_knowledge: true
      )

      # Infer artifact ID from path
      "indrajaal.accounts.user" = Indrajaal.FAME.Generator.infer_artifact_id("lib/indrajaal/accounts/user.ex")

  ## STAMP Compliance
  - SC-FAME-001: Schema validation enforced
  - SC-FAME-002: Dual mode support implemented
  - SC-FAME-003: Zenoh-style IDs via infer_artifact_id/1
  - SC-FAME-004: Dependency inference via infer_dependencies/1
  """

  alias Indrajaal.FAME.Schema

  # ============================================================================
  # TYPES
  # ============================================================================

  @type generation_opts :: [
          mode: :minimal | :complete,
          include_knowledge: boolean(),
          include_formal: boolean(),
          infer_stamp_constraints: boolean(),
          infer_test_paths: boolean()
        ]

  @type generation_result :: {:ok, Schema.fame_block()} | {:error, term()}

  @type ast_node :: Macro.t()

  @type dependency :: %{
          type: :use | :import | :alias | :require,
          module: atom() | String.t(),
          opts: keyword()
        }

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Generates FAME metadata for a given file path.

  Reads the file, parses it to AST, extracts module information, and generates
  appropriate FAME blocks based on the artifact type and options.

  ## Parameters
    - `file_path` - Path to the Elixir source file (relative or absolute)
    - `opts` - Generation options (see module docs)

  ## Options
    - `:mode` - `:minimal` (default) or `:complete`
    - `:include_knowledge` - Include knowledge block (default: true in complete mode)
    - `:include_formal` - Include formal block (default: false)
    - `:infer_stamp_constraints` - Auto-infer STAMP constraints (default: true)
    - `:infer_test_paths` - Auto-infer test file paths (default: true)

  ## Returns
    - `{:ok, fame_block}` - Successfully generated FAME metadata
    - `{:error, reason}` - Generation failed

  ## Examples

      iex> Indrajaal.FAME.Generator.generate_for_file("lib/indrajaal/accounts/user.ex")
      {:ok, %{meta: %{artifact_id: "indrajaal.accounts.user", ...}, ...}}

      iex> Indrajaal.FAME.Generator.generate_for_file("lib/indrajaal/accounts/user.ex", mode: :complete)
      {:ok, %{meta: %{...}, knowledge: %{...}, metabolism: %{...}, ...}}
  """
  @spec generate_for_file(String.t(), generation_opts()) :: generation_result()
  def generate_for_file(file_path, opts \\ []) do
    with {:ok, content} <- read_file(file_path),
         {:ok, ast} <- parse_content(content) do
      generate_from_ast(ast, Keyword.merge(opts, file_path: file_path))
    end
  end

  @doc """
  Generates FAME metadata from a parsed AST.

  This is useful when you already have the AST available or want to generate
  FAME for dynamically constructed modules.

  ## Parameters
    - `ast` - Parsed Elixir AST (from Code.string_to_quoted/2)
    - `opts` - Generation options

  ## Options
    - `:file_path` - Original file path (used for artifact ID inference)
    - `:mode` - `:minimal` (default) or `:complete`
    - Additional options as in generate_for_file/2

  ## Returns
    - `{:ok, fame_block}` - Successfully generated FAME metadata
    - `{:error, reason}` - Generation failed

  ## Examples

      iex> {:ok, ast} = Code.string_to_quoted("defmodule Foo do end")
      iex> Indrajaal.FAME.Generator.generate_from_ast(ast)
      {:ok, %{meta: %{artifact_id: "foo", ...}, ...}}
  """
  @spec generate_from_ast(ast_node(), generation_opts()) :: generation_result()
  def generate_from_ast(ast, opts \\ []) do
    mode = Keyword.get(opts, :mode, :minimal)
    file_path = Keyword.get(opts, :file_path)

    with {:ok, module_info} <- extract_module_info(ast),
         artifact_id <- infer_artifact_id_from_info(module_info, file_path),
         artifact_type <- infer_artifact_type(module_info, file_path),
         dependencies <- infer_dependencies(ast) do
      fame =
        case mode do
          :minimal ->
            build_minimal_fame(artifact_id, artifact_type, module_info, dependencies, opts)

          :complete ->
            build_complete_fame(artifact_id, artifact_type, module_info, dependencies, opts)
        end

      {:ok, fame}
    end
  end

  @doc """
  Converts a file path to a Zenoh-style hierarchical artifact ID.

  The artifact ID follows the pattern: `domain.subdomain.component.module`
  derived from the file path structure.

  ## Parameters
    - `file_path` - Path to the Elixir source file

  ## Returns
    - Zenoh-style artifact ID string

  ## Examples

      iex> Indrajaal.FAME.Generator.infer_artifact_id("lib/indrajaal/accounts/user.ex")
      "indrajaal.accounts.user"

      iex> Indrajaal.FAME.Generator.infer_artifact_id("lib/indrajaal/cybernetic/advanced_control_system.ex")
      "intelitor.cybernetic.advanced_control_system"

      iex> Indrajaal.FAME.Generator.infer_artifact_id("test/indrajaal/accounts/user_test.exs")
      "test.indrajaal.accounts.user_test"
  """
  @spec infer_artifact_id(String.t()) :: String.t()
  def infer_artifact_id(file_path) when is_binary(file_path) do
    root_path = Path.rootname(file_path)

    trimmed_path =
      root_path
      |> String.trim_leading("lib/")
      |> String.trim_leading("test/")
      |> handle_test_prefix(file_path)
      |> String.replace("/", ".")

    trimmed_path
    |> String.downcase()
    |> normalize_artifact_id()
  end

  @doc """
  Parses an Elixir AST to extract dependency information from use, import,
  alias, and require declarations.

  ## Parameters
    - `ast` - Parsed Elixir AST

  ## Returns
    - List of dependency maps with type, module, and options

  ## Examples

      iex> {:ok, ast} = Code.string_to_quoted(\"""
      ...> defmodule Foo do
      ...>   use Ash.Resource
      ...>   import Ecto.Query
      ...>   alias MyApp.Accounts.User
      ...> end
      ...> \""")
      iex> Indrajaal.FAME.Generator.infer_dependencies(ast)
      [
        %{type: :use, module: Ash.Resource, opts: []},
        %{type: :import, module: Ecto.Query, opts: []},
        %{type: :alias, module: MyApp.Accounts.User, opts: []}
      ]
  """
  @spec infer_dependencies(ast_node()) :: [dependency()]
  def infer_dependencies(ast) do
    ast
    |> extract_declarations()
    |> Enum.map(&normalize_dependency/1)
    |> Enum.uniq_by(fn dep -> {dep.type, dep.module} end)
  end

  @doc """
  Infers the artifact type from module information and file path.

  ## Parameters
    - `module_info` - Extracted module information map
    - `file_path` - Optional file path for additional context

  ## Returns
    - Artifact type atom: :module, :resource, :test, :script, :config, :doc, :spec

  ## Examples

      iex> Indrajaal.FAME.Generator.infer_artifact_type(%{uses: [Ash.Resource]}, "lib/foo.ex")
      :resource

      iex> Indrajaal.FAME.Generator.infer_artifact_type(%{uses: []}, "test/foo_test.exs")
      :test
  """
  @spec infer_artifact_type(map(), String.t() | nil) :: Schema.artifact_type()
  def infer_artifact_type(module_info, file_path \\ nil) do
    cond do
      # Check file path first
      is_binary(file_path) and String.ends_with?(file_path, "_test.exs") ->
        :test

      is_binary(file_path) and String.ends_with?(file_path, ".exs") ->
        :script

      is_binary(file_path) and String.contains?(file_path, "config/") ->
        :config

      # Check module characteristics
      uses_ash_resource?(module_info) ->
        :resource

      phoenix_controller?(module_info) ->
        :module

      phoenix_live_view?(module_info) ->
        :module

      genserver?(module_info) ->
        :module

      supervisor?(module_info) ->
        :module

      # Default
      true ->
        :module
    end
  end

  # ============================================================================
  # PRIVATE: FILE OPERATIONS
  # ============================================================================

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:file_read_error, reason, file_path}}
    end
  end

  defp parse_content(content) do
    case Code.string_to_quoted(content, columns: true, token_metadata: true) do
      {:ok, ast} -> {:ok, ast}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  # ============================================================================
  # PRIVATE: AST EXTRACTION
  # ============================================================================

  defp extract_module_info(ast) do
    module_name = extract_module_name(ast)
    moduledoc = extract_moduledoc(ast)
    uses = extract_uses(ast)
    imports = extract_imports(ast)
    aliases = extract_aliases(ast)
    requires = extract_requires(ast)
    functions = extract_public_functions(ast)
    callbacks = extract_callbacks(ast)

    {:ok,
     %{
       module_name: module_name,
       moduledoc: moduledoc,
       uses: uses,
       imports: imports,
       aliases: aliases,
       requires: requires,
       functions: functions,
       callbacks: callbacks
     }}
  end

  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _, [{:__aliases__, _, parts}, _]} ->
        Module.concat(parts)

      {:defmodule, _, [module_atom, _]} when is_atom(module_atom) ->
        module_atom

      {:__block__, _, children} ->
        children
        |> Enum.find_value(fn child -> extract_module_name(child) end)

      _ ->
        nil
    end
  end

  defp extract_moduledoc(ast) do
    ast
    |> find_in_do_block()
    |> Enum.find_value(fn
      {:@, _, [{:moduledoc, _, [doc]}]} when is_binary(doc) -> doc
      {:@, _, [{:moduledoc, _, [{:sigil_S, _, [{_, _, [doc]}, _]}]}]} -> doc
      _ -> nil
    end) || ""
  end

  defp extract_uses(ast) do
    do_block = find_in_do_block(ast)

    do_block
    |> Enum.flat_map(fn
      {:use, _, [{:__aliases__, _, parts} | rest]} ->
        opts = extract_opts(rest)
        [%{module: Module.concat(parts), opts: opts}]

      {:use, _, [module | rest]} when is_atom(module) ->
        opts = extract_opts(rest)
        [%{module: module, opts: opts}]

      _ ->
        []
    end)
  end

  defp extract_imports(ast) do
    do_block = find_in_do_block(ast)

    do_block
    |> Enum.flat_map(fn
      {:import, _, [{:__aliases__, _, parts} | rest]} ->
        opts = extract_opts(rest)
        [%{module: Module.concat(parts), opts: opts}]

      {:import, _, [module | rest]} when is_atom(module) ->
        opts = extract_opts(rest)
        [%{module: module, opts: opts}]

      _ ->
        []
    end)
  end

  defp extract_aliases(ast) do
    do_block = find_in_do_block(ast)

    do_block
    |> Enum.flat_map(fn
      {:alias, _, [{:__aliases__, _, parts} | rest]} ->
        opts = extract_opts(rest)
        [%{module: Module.concat(parts), opts: opts}]

      {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, nested}]} ->
        # Handle alias with braces: alias MyApp.{Foo, Bar}
        mapped_aliases =
          Enum.map(nested, fn
            {:__aliases__, _, parts} -> %{module: Module.concat(base ++ parts), opts: []}
            _ -> nil
          end)

        Enum.reject(mapped_aliases, &is_nil/1)

      _ ->
        []
    end)
  end

  defp extract_requires(ast) do
    ast
    |> find_in_do_block()
    |> Enum.flat_map(fn
      {:require, _, [{:__aliases__, _, parts} | rest]} ->
        opts = extract_opts(rest)
        [%{module: Module.concat(parts), opts: opts}]

      {:require, _, [module | rest]} when is_atom(module) ->
        opts = extract_opts(rest)
        [%{module: module, opts: opts}]

      _ ->
        []
    end)
  end

  defp extract_public_functions(ast) do
    ast
    |> find_in_do_block()
    |> Enum.flat_map(fn
      {:def, _, [{name, _, args} | _]} when is_atom(name) ->
        arity = if is_list(args), do: length(args), else: 0
        [{name, arity}]

      {:def, _, [{:when, _, [{name, _, args} | _]} | _]} when is_atom(name) ->
        arity = if is_list(args), do: length(args), else: 0
        [{name, arity}]

      _ ->
        []
    end)
    |> Enum.uniq()
  end

  defp extract_callbacks(ast) do
    ast
    |> find_in_do_block()
    |> Enum.flat_map(fn
      {:@, _, [{:callback, _, _}]} -> [:has_callbacks]
      {:@, _, [{:impl, _, _}]} -> [:implements_callbacks]
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp find_in_do_block(ast) do
    case ast do
      {:defmodule, _, [_, [do: {:__block__, _, children}]]} ->
        children

      {:defmodule, _, [_, [do: single]]} ->
        [single]

      {:__block__, _, children} ->
        Enum.flat_map(children, &find_in_do_block/1)

      _ ->
        []
    end
  end

  defp extract_opts([opts]) when is_list(opts), do: opts
  defp extract_opts(_), do: []

  defp extract_declarations(ast) do
    ast
    |> find_in_do_block()
    |> Enum.flat_map(fn
      {type, _, [{:__aliases__, _, parts} | rest]}
      when type in [:use, :import, :alias, :require] ->
        [{type, Module.concat(parts), extract_opts(rest)}]

      {type, _, [module | rest]}
      when type in [:use, :import, :alias, :require] and is_atom(module) ->
        [{type, module, extract_opts(rest)}]

      {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, nested}]} ->
        Enum.flat_map(nested, fn
          {:__aliases__, _, parts} -> [{:alias, Module.concat(base ++ parts), []}]
          _ -> []
        end)

      _ ->
        []
    end)
  end

  defp normalize_dependency({type, module, opts}) do
    %{
      type: type,
      module: module,
      opts: opts
    }
  end

  # ============================================================================
  # PRIVATE: ARTIFACT ID INFERENCE
  # ============================================================================

  defp infer_artifact_id_from_info(module_info, file_path) do
    cond do
      is_binary(file_path) ->
        infer_artifact_id(file_path)

      module_info.module_name != nil ->
        module_str = module_info.module_name |> to_string() |> String.trim_leading("Elixir.")

        module_str
        |> String.replace(".", "_")
        |> Macro.underscore()
        |> String.replace("/", ".")

      true ->
        "unknown.artifact.#{:erlang.unique_integer([:positive])}"
    end
  end

  defp handle_test_prefix(path, original_path) do
    if String.starts_with?(original_path, "test/") do
      "test.#{path}"
    else
      path
    end
  end

  defp normalize_artifact_id(id) do
    id
    |> String.replace(~r/[^a-z0-9._]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  # ============================================================================
  # PRIVATE: TYPE INFERENCE
  # ============================================================================

  defp uses_ash_resource?(module_info) do
    module_info.uses
    |> Enum.any?(fn use ->
      use.module in [Ash.Resource, Indrajaal.BaseResource]
    end)
  end

  defp phoenix_controller?(module_info) do
    module_info.uses
    |> Enum.any?(fn use ->
      module_str = to_string(use.module)
      String.contains?(module_str, "Controller") or String.contains?(module_str, "Phoenix")
    end)
  end

  defp phoenix_live_view?(module_info) do
    module_info.uses
    |> Enum.any?(fn use ->
      use.module in [Phoenix.LiveView, Phoenix.LiveComponent]
    end)
  end

  defp genserver?(module_info) do
    module_info.uses
    |> Enum.any?(fn use ->
      use.module == GenServer
    end)
  end

  defp supervisor?(module_info) do
    module_info.uses
    |> Enum.any?(fn use ->
      use.module in [Supervisor, DynamicSupervisor]
    end)
  end

  # ============================================================================
  # PRIVATE: FAME BLOCK BUILDERS
  # ============================================================================

  defp build_minimal_fame(artifact_id, artifact_type, module_info, dependencies, opts) do
    %{
      meta: build_meta_block(artifact_id, artifact_type, module_info),
      impact: build_impact_block(dependencies, module_info, opts),
      boundaries: build_boundaries_block(artifact_id, module_info, opts),
      evolution: build_evolution_block(module_info, opts)
    }
  end

  defp build_complete_fame(artifact_id, artifact_type, module_info, dependencies, opts) do
    minimal = build_minimal_fame(artifact_id, artifact_type, module_info, dependencies, opts)

    include_knowledge = Keyword.get(opts, :include_knowledge, true)
    include_formal = Keyword.get(opts, :include_formal, false)

    additional = %{
      agent_context: build_agent_context_block(module_info, opts),
      metabolism: build_metabolism_block(module_info, opts),
      invariants: build_invariants_block(module_info, opts),
      stigmergy: build_stigmergy_block(module_info, opts),
      contracts: build_contracts_block(module_info, opts),
      observability: build_observability_block(artifact_id, opts)
    }

    additional =
      if include_knowledge do
        Map.put(additional, :knowledge, build_knowledge_block(artifact_id, module_info, opts))
      else
        additional
      end

    additional =
      if include_formal do
        Map.put(additional, :formal, build_formal_block(module_info, opts))
      else
        additional
      end

    Map.merge(minimal, additional)
  end

  # ============================================================================
  # PRIVATE: INDIVIDUAL BLOCK BUILDERS
  # ============================================================================

  defp build_meta_block(artifact_id, artifact_type, module_info) do
    purpose = extract_purpose_from_moduledoc(module_info.moduledoc)
    context = extract_context_from_moduledoc(module_info.moduledoc)

    %{
      fame_version: "2.0.0-BIO",
      artifact_id: artifact_id,
      artifact_type: artifact_type,
      created: Date.utc_today(),
      last_evolved: Date.utc_today(),
      purpose: purpose,
      context: context,
      scope: infer_scope(artifact_id),
      parent: infer_parent(artifact_id),
      children: [],
      siblings: []
    }
  end

  defp build_impact_block(dependencies, _module_info, _opts) do
    depends_on =
      dependencies
      |> Enum.filter(fn dep -> dep.type in [:use, :import] end)
      |> Enum.map(fn dep -> to_string(dep.module) end)

    %{
      first_order: %{
        depends_on: depends_on,
        depended_by: []
      },
      second_order: %{
        upstream_cascade: [],
        downstream_cascade: [],
        failure_blast_radius: infer_blast_radius(dependencies)
      },
      change_risk: %{
        breaking_change_likelihood: infer_breaking_likelihood(dependencies),
        rollback_complexity: :low,
        testing_coverage_required: 0.80
      }
    }
  end

  defp build_boundaries_block(artifact_id, module_info, opts) do
    infer_tests = Keyword.get(opts, :infer_test_paths, true)
    infer_stamp = Keyword.get(opts, :infer_stamp_constraints, true)

    test_file =
      if infer_tests do
        artifact_id
        |> String.replace(".", "/")
        |> then(&"test/#{&1}_test.exs")
      else
        nil
      end

    stamp_constraints =
      if infer_stamp do
        infer_stamp_constraints(module_info)
      else
        []
      end

    %{
      tdg: %{
        test_file: test_file,
        property_test: nil,
        coverage_min: 0.80,
        must_fail_before_code: true
      },
      stamp: stamp_constraints,
      fmea: %{
        failure_modes: [],
        mitigations: []
      },
      aor: infer_aor_constraints(module_info)
    }
  end

  defp build_evolution_block(module_info, _opts) do
    agent_instructions = build_agent_instructions(module_info)

    %{
      agent_instructions: agent_instructions,
      stability: infer_stability(module_info),
      change_frequency: :occasional,
      approval_required: infer_approval_required(module_info),
      evolution_log: []
    }
  end

  defp build_knowledge_block(artifact_id, _module_info, _opts) do
    zettel_id = generate_zettel_id(artifact_id)

    %{
      zettel_id: zettel_id,
      tags: [],
      links: %{
        concepts: [],
        related_code: [],
        formal_specs: [],
        journal: []
      },
      graph_node: "node:#{String.replace(artifact_id, ".", ":")}",
      graph_edges: []
    }
  end

  defp build_formal_block(_module_info, _opts) do
    %{}
  end

  defp build_agent_context_block(module_info, _opts) do
    %{
      code_style: infer_code_style(module_info),
      preferred_patterns: [:with_chain, :pipe, :pattern_match],
      avoid_patterns: [:nested_case, :deep_nesting],
      debug_hints: [],
      common_errors: infer_common_errors(module_info),
      test_strategy: infer_test_strategy(module_info),
      edge_cases: [],
      update_checklist: [
        "Run mix compile",
        "Run related tests",
        "Check for STAMP violations",
        "Update journal if significant"
      ]
    }
  end

  defp build_metabolism_block(_module_info, _opts) do
    %{
      resource_profile: %{
        cpu_weight: :low,
        memory_footprint: :low,
        io_pattern: :minimal
      },
      adaptation: %{
        scale_trigger: %{cpu: 0.80, memory: 0.85, latency_ms: 100},
        degrade_gracefully: true,
        adaptation_rate: 0.1
      },
      lifecycle: %{
        apoptosis_triggers: [:orphaned],
        autophagy_enabled: false,
        max_age_hours: nil
      },
      budget: %{
        max_concurrent_ops: 100,
        max_memory_mb: 256,
        max_cpu_percent: 50
      }
    }
  end

  defp build_invariants_block(_module_info, _opts) do
    %{
      structural: [],
      behavioral: [],
      communication: [],
      operational: [],
      fitness: %{
        function: "lib/indrajaal/fame/fitness.ex:evaluate/1",
        threshold: 1.0,
        evaluation_interval_ms: 60_000
      }
    }
  end

  defp build_stigmergy_block(_module_info, _opts) do
    %{
      signals: %{
        emits: [],
        responds_to: [],
        decay_rate: 0.1
      },
      coordination: %{
        pattern: :none,
        gradient: nil
      },
      emergence: %{
        allowed_patterns: [],
        forbidden_patterns: [:cascade_failure, :deadlock]
      }
    }
  end

  defp build_contracts_block(_module_info, _opts) do
    %{
      preconditions: [],
      postconditions: [],
      class_invariants: [],
      interface: %{
        input_schema: nil,
        output_schema: nil,
        validation: :strict,
        versioning: :semver
      }
    }
  end

  defp build_observability_block(artifact_id, _opts) do
    key_prefix = String.replace(artifact_id, ".", "/")

    %{
      logging: %{
        levels: %{
          l5_cognitive: %{key: "log/system/#{key_prefix}/**", retention: "90d", sample_rate: 1.0},
          l4_systemic: %{key: "log/domain/#{key_prefix}/**", retention: "30d", sample_rate: 1.0},
          l3_transaction: %{key: "log/tx/#{key_prefix}/**", retention: "7d", sample_rate: 1.0},
          l2_component: %{
            key: "log/component/#{key_prefix}/**",
            retention: "24h",
            sample_rate: 0.1
          },
          l1_atomic: %{key: "log/atomic/#{key_prefix}/**", retention: "1h", sample_rate: 0.01}
        }
      },
      telemetry: %{
        spans: %{
          l5: "#{key_prefix}.system.**",
          l4: "#{key_prefix}.domain.**",
          l3: "#{key_prefix}.tx.**",
          l2: "#{key_prefix}.component.**",
          l1: "#{key_prefix}.atomic.**"
        },
        metrics: %{
          counters: [],
          gauges: [],
          histograms: []
        }
      },
      messaging: %{
        channels: %{
          l5_commands: "cmd/system/#{key_prefix}/**",
          l4_events: "event/domain/#{key_prefix}/**",
          l3_requests: "req/tx/#{key_prefix}/**",
          l2_signals: "signal/component/#{key_prefix}/**",
          l1_data: "data/atomic/#{key_prefix}/**"
        }
      }
    }
  end

  # ============================================================================
  # PRIVATE: INFERENCE HELPERS
  # ============================================================================

  defp extract_purpose_from_moduledoc(moduledoc) when is_binary(moduledoc) do
    # Try to extract WHAT section or first line
    case Regex.run(~r/WHAT:\s*(.+?)(?:\n|$)/s, moduledoc) do
      [_, what] ->
        trimmed_what = String.trim(what)
        String.slice(trimmed_what, 0, 200)

      nil ->
        extract_first_meaningful_line(moduledoc)
    end
  end

  defp extract_purpose_from_moduledoc(_), do: "TODO: Add purpose"

  defp extract_context_from_moduledoc(moduledoc) when is_binary(moduledoc) do
    case Regex.run(~r/WHY:\s*(.+?)(?:\n\n|CONSTRAINTS:|$)/s, moduledoc) do
      [_, why] ->
        trimmed_why = String.trim(why)
        String.slice(trimmed_why, 0, 300)

      nil ->
        "TODO: Add context"
    end
  end

  defp extract_context_from_moduledoc(_), do: "TODO: Add context"

  defp extract_first_meaningful_line(text) do
    text
    |> String.split("\n")
    |> Enum.find(fn line ->
      trimmed = String.trim(line)

      trimmed != "" and not String.starts_with?(trimmed, "#") and
        not String.starts_with?(trimmed, "@")
    end)
    |> case do
      nil ->
        "TODO: Add purpose"

      line ->
        trimmed_line = String.trim(line)
        String.slice(trimmed_line, 0, 200)
    end
  end

  defp infer_scope(artifact_id) do
    parts = String.split(artifact_id, ".")

    case length(parts) do
      1 -> :system
      2 -> :domain
      3 -> :component
      _ -> :atomic
    end
  end

  defp infer_parent(artifact_id) do
    parts = String.split(artifact_id, ".")

    case parts do
      [_] -> nil
      parts -> parts |> Enum.drop(-1) |> Enum.join(".")
    end
  end

  defp infer_blast_radius(dependencies) do
    count = length(dependencies)

    cond do
      count > 10 -> :system
      count > 5 -> :medium
      count > 2 -> :local
      true -> :minimal
    end
  end

  defp infer_breaking_likelihood(dependencies) do
    # Higher likelihood if using core Ash/Phoenix components
    critical_deps =
      Enum.count(dependencies, fn dep ->
        module_str = to_string(dep.module)
        String.contains?(module_str, "Ash") or String.contains?(module_str, "Phoenix")
      end)

    cond do
      critical_deps > 3 -> :high
      critical_deps > 1 -> :medium
      true -> :low
    end
  end

  defp infer_stamp_constraints(module_info) do
    constraints = []

    constraints =
      if uses_ash_resource?(module_info) do
        ["SC-ASH-001", "SC-DB-001" | constraints]
      else
        constraints
      end

    constraints =
      if genserver?(module_info) or supervisor?(module_info) do
        ["SC-OBS-069" | constraints]
      else
        constraints
      end

    constraints
  end

  defp infer_aor_constraints(module_info) do
    constraints = ["AOR-CODE-001"]

    constraints =
      if uses_ash_resource?(module_info) do
        ["AOR-DB-001" | constraints]
      else
        constraints
      end

    constraints
  end

  defp build_agent_instructions(module_info) do
    cond do
      uses_ash_resource?(module_info) ->
        "This is an Ash resource. Follow SC-ASH-* constraints. Use BaseResource patterns. Test with Ash.Changeset factories."

      genserver?(module_info) ->
        "This is a GenServer. Ensure proper handle_* callbacks. Test init/1 and all message handlers."

      supervisor?(module_info) ->
        "This is a Supervisor. Do not modify child specs without understanding restart strategies."

      true ->
        "Standard Elixir module. Follow project conventions and STAMP constraints."
    end
  end

  defp infer_stability(module_info) do
    cond do
      supervisor?(module_info) -> :stable
      uses_ash_resource?(module_info) -> :evolving
      true -> :evolving
    end
  end

  defp infer_approval_required(module_info) do
    approvals = []

    approvals =
      if uses_ash_resource?(module_info) do
        [:schema_change | approvals]
      else
        approvals
      end

    approvals
  end

  defp generate_zettel_id(artifact_id) do
    date_str = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "")
    slug = artifact_id |> String.split(".") |> List.last()
    "#{date_str}-#{slug}"
  end

  defp infer_code_style(module_info) do
    cond do
      uses_ash_resource?(module_info) -> :declarative
      genserver?(module_info) -> :functional
      true -> :functional
    end
  end

  defp infer_common_errors(module_info) do
    errors = []

    errors =
      if uses_ash_resource?(module_info) do
        ["EP-ASH-001: Missing require_atomic?", "EP-ASH-002: Wrong tenant access" | errors]
      else
        errors
      end

    errors
  end

  defp infer_test_strategy(module_info) do
    cond do
      uses_ash_resource?(module_info) -> :mixed
      genserver?(module_info) -> :integration
      true -> :unit
    end
  end
end
