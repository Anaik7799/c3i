defmodule Indrajaal.FAME.Schema do
  @moduledoc """
  FAME (Fractal Artifact Metadata Enrichment) Schema Definitions v2.0.0-BIO

  WHAT: Type definitions for all 12 FAME metadata blocks enabling AI/ML-driven evolution.
  WHY: SC-DOC-001 requires structured metadata; enables intelligent codebase navigation.
  CONSTRAINTS: All P0 artifacts MUST have complete FAME metadata blocks.

  ## FAME Block Hierarchy

  ### Core Identity (Blocks 1-7)
  1. @meta - Artifact identity and hierarchy
  2. @impact - 1st/2nd order effect analysis
  3. @boundaries - TDG/STAMP/FMEA/AOR constraints
  4. @knowledge - Zettelkasten-style linking
  5. @evolution - AI agent guidance
  6. @formal - Mathematical structures (optional)
  7. @agent_context - Code generation hints

  ### Bio-Fractal Extensions (Blocks 8-10)
  8. @metabolism - Resource profiles and adaptation
  9. @invariants - Core immutable constraints
  10. @stigmergy - Environment-mediated coordination

  ### System Engineering (Blocks 11-12)
  11. @contracts - Design by Contract (DbC)
  12. @observability - Fractal logging/telemetry

  ## STAMP Compliance
  - SC-DOC-001: Moduledoc with WHAT/WHY/CONSTRAINTS
  - SC-FAME-001: Schema types must be Dialyzer-verified
  - SC-FAME-002: All blocks must have validation functions

  ## AOR Compliance
  - AOR-DOC-001: Read moduledoc before editing
  - AOR-FAME-001: Schema changes require dual-agent review
  """

  # ============================================================================
  # BLOCK 1: CORE IDENTITY (@meta)
  # ============================================================================

  @typedoc """
  Core identity metadata for artifact identification and hierarchy.

  ## Fields
  - fame_version: FAME schema version (e.g., "2.0.0-BIO")
  - artifact_id: Zenoh-style hierarchical ID (e.g., "indrajaal.accounts.user")
  - artifact_type: :module | :script | :config | :doc | :spec | :test
  - created: Creation date
  - last_evolved: Last modification date
  - purpose: One-line description of what this artifact does
  - context: Where this fits in the system
  - scope: :atomic | :component | :domain | :system
  - parent: Parent artifact ID (nil for root)
  - children: List of child artifact IDs
  - siblings: List of sibling artifact IDs
  """
  @type meta :: %{
          fame_version: String.t(),
          artifact_id: String.t(),
          artifact_type: artifact_type(),
          created: Date.t(),
          last_evolved: Date.t(),
          purpose: String.t(),
          context: String.t(),
          scope: scope(),
          parent: String.t() | nil,
          children: [String.t()],
          siblings: [String.t()]
        }

  @type artifact_type :: :module | :script | :config | :doc | :spec | :test | :resource
  @type scope :: :atomic | :component | :domain | :system

  # ============================================================================
  # BLOCK 2: IMPACT ANALYSIS (@impact)
  # ============================================================================

  @typedoc """
  1st and 2nd order effect analysis for change impact assessment.

  ## Fields
  - first_order: Direct dependencies and dependents
  - second_order: Transitive effects and blast radius
  - change_risk: Breaking change likelihood and rollback complexity
  """
  @type impact :: %{
          first_order: first_order_impact(),
          second_order: second_order_impact(),
          change_risk: change_risk()
        }

  @type first_order_impact :: %{
          depends_on: [String.t()],
          depended_by: [String.t()]
        }

  @type second_order_impact :: %{
          upstream_cascade: [String.t()],
          downstream_cascade: [String.t()],
          failure_blast_radius: blast_radius()
        }

  @type blast_radius :: :minimal | :local | :medium | :system | :catastrophic

  @type change_risk :: %{
          breaking_change_likelihood: risk_level(),
          rollback_complexity: complexity_level(),
          testing_coverage_required: float()
        }

  @type risk_level :: :low | :medium | :high | :critical
  @type complexity_level :: :trivial | :low | :medium | :high | :extreme

  # ============================================================================
  # BLOCK 3: BOUNDARY CONTROLS (@boundaries)
  # ============================================================================

  @typedoc """
  TDG/STAMP/FMEA/AOR constraint specifications.

  ## Fields
  - tdg: Test-Driven Generation requirements
  - stamp: STAMP safety constraints
  - fmea: Failure Mode and Effects Analysis
  - aor: Agent Operating Rules
  """
  @type boundaries :: %{
          tdg: tdg_spec(),
          stamp: [String.t()],
          fmea: fmea_spec(),
          aor: [String.t()]
        }

  @type tdg_spec :: %{
          test_file: String.t(),
          property_test: String.t() | nil,
          coverage_min: float(),
          must_fail_before_code: boolean()
        }

  @type fmea_spec :: %{
          failure_modes: [failure_mode()],
          mitigations: [String.t()]
        }

  @type failure_mode :: %{
          mode: String.t(),
          severity: severity_level(),
          detection: detection_method(),
          rpn: non_neg_integer()
        }

  @type severity_level :: :negligible | :minor | :moderate | :major | :critical | :catastrophic
  @type detection_method :: :automated | :manual | :audit_log | :external | :none

  # ============================================================================
  # BLOCK 4: KNOWLEDGE MAP (@knowledge)
  # ============================================================================

  @typedoc """
  Zettelkasten-style knowledge linking and graph integration.

  ## Fields
  - zettel_id: Unique Zettelkasten identifier (YYYYMMDDHHMM-slug)
  - tags: Semantic tags for categorization
  - links: Bidirectional links to related artifacts
  - graph_node: Node identifier in knowledge graph
  - graph_edges: Typed edges connecting to other nodes
  """
  @type knowledge :: %{
          zettel_id: String.t(),
          tags: [atom()],
          links: knowledge_links(),
          graph_node: String.t(),
          graph_edges: [graph_edge()]
        }

  @type knowledge_links :: %{
          concepts: [String.t()],
          related_code: [String.t()],
          formal_specs: [String.t()],
          journal: [String.t()]
        }

  @type graph_edge :: {edge_type(), String.t()}
  @type edge_type :: :depends | :validates | :audits_to | :implements | :extends | :uses

  # ============================================================================
  # BLOCK 5: EVOLUTION CRITERIA (@evolution)
  # ============================================================================

  @typedoc """
  AI/ML agent guidance for intelligent artifact modification.

  ## Fields
  - agent_instructions: Natural language guidance for AI agents
  - stability: How stable this artifact should be
  - change_frequency: Expected change frequency
  - approval_required: Types of changes requiring review
  - evolution_log: History of significant changes
  """
  @type evolution :: %{
          agent_instructions: String.t(),
          stability: stability_level(),
          change_frequency: frequency(),
          approval_required: [approval_type()],
          evolution_log: [evolution_entry()]
        }

  @type stability_level :: :volatile | :evolving | :stable | :frozen
  @type frequency :: :continuous | :frequent | :occasional | :rare | :never
  @type approval_type :: :api_change | :schema_change | :security_change | :any_change

  @type evolution_entry :: %{
          date: Date.t(),
          change: String.t(),
          agent: String.t()
        }

  # ============================================================================
  # BLOCK 6: FORMAL STRUCTURES (@formal) - Optional
  # ============================================================================

  @typedoc """
  Mathematical structures and formal verification links.

  ## Fields
  - mathematica_spec: Path to Mathematica specification
  - invariants: Mathematical invariants (Unicode math notation)
  - quint_model: Path to Quint TLA+ model
  - quint_properties: Named Quint properties to verify
  - agda_proof: Path to Agda proof file
  - proven_properties: List of proven property names
  - graph_type: Type of graph structure
  - graph_metrics: Graph topology metrics
  """
  @type formal :: %{
          optional(:mathematica_spec) => String.t(),
          optional(:invariants) => [String.t()],
          optional(:quint_model) => String.t(),
          optional(:quint_properties) => [String.t()],
          optional(:agda_proof) => String.t(),
          optional(:proven_properties) => [String.t()],
          optional(:graph_type) => graph_type(),
          optional(:graph_metrics) => graph_metrics()
        }

  @type graph_type :: :dag | :tree | :cyclic | :bipartite | :complete
  @type graph_metrics :: %{
          in_degree: non_neg_integer(),
          out_degree: non_neg_integer(),
          betweenness_centrality: float()
        }

  # ============================================================================
  # BLOCK 7: AGENT CONTEXT (@agent_context)
  # ============================================================================

  @typedoc """
  Code generation and debugging hints for AI agents.

  ## Fields
  - code_style: Preferred coding style
  - preferred_patterns: Elixir patterns to use
  - avoid_patterns: Anti-patterns to avoid
  - debug_hints: Common debugging approaches
  - common_errors: Known error patterns (EP-* codes)
  - test_strategy: Testing approach
  - edge_cases: Important edge cases to test
  - update_checklist: Steps to follow when updating
  """
  @type agent_context :: %{
          code_style: code_style(),
          preferred_patterns: [atom()],
          avoid_patterns: [atom()],
          debug_hints: [String.t()],
          common_errors: [String.t()],
          test_strategy: test_strategy(),
          edge_cases: [String.t()],
          update_checklist: [String.t()]
        }

  @type code_style :: :functional | :oop | :hybrid | :declarative
  @type test_strategy :: :unit | :integration | :property_based | :e2e | :mixed

  # ============================================================================
  # BLOCK 8: METABOLISM (@metabolism) - Bio-Fractal
  # ============================================================================

  @typedoc """
  Resource profiles and adaptation characteristics (Bio-Fractal).

  ## Fields
  - resource_profile: CPU, memory, I/O characteristics
  - adaptation: Scaling triggers and degradation behavior
  - lifecycle: Apoptosis and autophagy configuration
  - budget: Resource consumption limits
  """
  @type metabolism :: %{
          resource_profile: resource_profile(),
          adaptation: adaptation_config(),
          lifecycle: lifecycle_config(),
          budget: resource_budget()
        }

  @type resource_profile :: %{
          cpu_weight: weight(),
          memory_footprint: weight(),
          io_pattern: io_pattern()
        }

  @type weight :: :minimal | :low | :medium | :high | :extreme
  @type io_pattern :: :read_heavy | :write_heavy | :balanced | :burst | :minimal

  @type adaptation_config :: %{
          scale_trigger: scale_trigger(),
          degrade_gracefully: boolean(),
          adaptation_rate: float()
        }

  @type scale_trigger :: %{
          cpu: float(),
          memory: float(),
          latency_ms: non_neg_integer()
        }

  @type lifecycle_config :: %{
          apoptosis_triggers: [apoptosis_trigger()],
          autophagy_enabled: boolean(),
          max_age_hours: non_neg_integer() | nil
        }

  @type apoptosis_trigger ::
          :orphaned | :corrupted | :unresponsive | :resource_exceeded | :obsolete

  @type resource_budget :: %{
          max_concurrent_ops: non_neg_integer(),
          max_memory_mb: non_neg_integer(),
          max_cpu_percent: non_neg_integer()
        }

  # ============================================================================
  # BLOCK 9: INVARIANTS (@invariants) - Bio-Fractal
  # ============================================================================

  @typedoc """
  Core immutable constraints that define system correctness.

  ## Fields
  - structural: Architecture invariants (INV-STRUCT-*)
  - behavioral: Semantic invariants (INV-BEHAV-*)
  - communication: Protocol invariants (INV-COMM-*)
  - operational: Runtime invariants (INV-OPER-*)
  - fitness: Fitness function for invariant evaluation
  """
  @type invariants :: %{
          structural: [invariant()],
          behavioral: [invariant()],
          communication: [invariant()],
          operational: [invariant()],
          fitness: fitness_spec()
        }

  @type invariant :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          enforcement: enforcement_level(),
          verification: String.t() | nil
        }

  @type enforcement_level :: :compile_time | :test | :runtime | :manual | :continuous

  @type fitness_spec :: %{
          function: String.t(),
          threshold: float(),
          evaluation_interval_ms: non_neg_integer()
        }

  # ============================================================================
  # BLOCK 10: STIGMERGY (@stigmergy) - Bio-Fractal
  # ============================================================================

  @typedoc """
  Environment-mediated coordination and emergent behavior.

  ## Fields
  - signals: Pheromone-like signals emitted and responded to
  - coordination: Coordination pattern and gradient following
  - emergence: Allowed and forbidden emergent patterns
  """
  @type stigmergy :: %{
          signals: signal_config(),
          coordination: coordination_config(),
          emergence: emergence_config()
        }

  @type signal_config :: %{
          emits: [signal_type()],
          responds_to: [signal_type()],
          decay_rate: float()
        }

  @type signal_type :: %{
          key: String.t(),
          payload_type: atom(),
          ttl_ms: non_neg_integer()
        }

  @type coordination_config :: %{
          pattern: coordination_pattern(),
          gradient: gradient_spec() | nil
        }

  @type coordination_pattern ::
          :gradient_following
          | :quorum_sensing
          | :stigmergic_consensus
          | :leader_election
          | :none

  @type gradient_spec :: %{
          source: String.t(),
          direction: :ascending | :descending
        }

  @type emergence_config :: %{
          allowed_patterns: [emergence_pattern()],
          forbidden_patterns: [emergence_pattern()]
        }

  @type emergence_pattern ::
          :load_balancing
          | :failover
          | :cascade_failure
          | :resource_hoarding
          | :oscillation
          | :deadlock

  # ============================================================================
  # BLOCK 11: CONTRACTS (@contracts) - System Engineering
  # ============================================================================

  @typedoc """
  Design by Contract (DbC) specifications.

  ## Fields
  - preconditions: Input validation contracts (PRE-*)
  - postconditions: Output validation contracts (POST-*)
  - class_invariants: State invariants (INV-CLASS-*)
  - interface: API contract specifications
  """
  @type contracts :: %{
          preconditions: [contract()],
          postconditions: [contract()],
          class_invariants: [contract()],
          interface: interface_contract()
        }

  @type contract :: %{
          id: String.t(),
          name: String.t(),
          expression: String.t(),
          failure_action: failure_action()
        }

  @type failure_action :: :reject | :alert | :log | :raise | :compensate

  @type interface_contract :: %{
          input_schema: String.t() | nil,
          output_schema: String.t() | nil,
          validation: validation_mode(),
          versioning: version_strategy()
        }

  @type validation_mode :: :strict | :lenient | :coerce | :none
  @type version_strategy :: :semver | :date | :hash | :none

  # ============================================================================
  # BLOCK 12: OBSERVABILITY (@observability) - System Engineering
  # ============================================================================

  @typedoc """
  Fractal logging, telemetry, and messaging configuration.

  ## Fields
  - logging: 5-level fractal logging configuration (L1-L5)
  - telemetry: OpenTelemetry span and metric configuration
  - messaging: Zenoh-style channel configuration
  """
  @type observability :: %{
          logging: logging_config(),
          telemetry: telemetry_config(),
          messaging: messaging_config()
        }

  @type logging_config :: %{
          levels: %{
            l5_cognitive: level_config(),
            l4_systemic: level_config(),
            l3_transaction: level_config(),
            l2_component: level_config(),
            l1_atomic: level_config()
          }
        }

  @type level_config :: %{
          key: String.t(),
          retention: String.t(),
          sample_rate: float()
        }

  @type telemetry_config :: %{
          spans: %{
            l5: String.t(),
            l4: String.t(),
            l3: String.t(),
            l2: String.t(),
            l1: String.t()
          },
          metrics: metrics_config()
        }

  @type metrics_config :: %{
          counters: [String.t()],
          gauges: [String.t()],
          histograms: [String.t()]
        }

  @type messaging_config :: %{
          channels: %{
            l5_commands: String.t(),
            l4_events: String.t(),
            l3_requests: String.t(),
            l2_signals: String.t(),
            l1_data: String.t()
          }
        }

  # ============================================================================
  # COMPLETE FAME BLOCK TYPE
  # ============================================================================

  @typedoc """
  Complete FAME metadata structure combining all 12 blocks.

  ## Required Blocks (P0 artifacts)
  - meta: Core identity (ALWAYS required)
  - impact: Effect analysis (ALWAYS required)
  - boundaries: Constraints (ALWAYS required)
  - evolution: AI guidance (ALWAYS required)

  ## Optional Blocks
  - knowledge: Zettelkasten linking
  - formal: Mathematical structures
  - agent_context: Code generation hints
  - metabolism: Resource profiles
  - invariants: Core constraints
  - stigmergy: Coordination
  - contracts: DbC specifications
  - observability: Logging/telemetry
  """
  @type fame_block :: %{
          required(:meta) => meta(),
          required(:impact) => impact(),
          required(:boundaries) => boundaries(),
          required(:evolution) => evolution(),
          optional(:knowledge) => knowledge(),
          optional(:formal) => formal(),
          optional(:agent_context) => agent_context(),
          optional(:metabolism) => metabolism(),
          optional(:invariants) => invariants(),
          optional(:stigmergy) => stigmergy(),
          optional(:contracts) => contracts(),
          optional(:observability) => observability()
        }

  # ============================================================================
  # FACTORY FUNCTIONS
  # ============================================================================

  @doc """
  Creates a minimal valid FAME block with required fields only.

  ## Example

      iex> Indrajaal.FAME.Schema.new_minimal("indrajaal.accounts.user", :module)
      %{
        meta: %{...},
        impact: %{...},
        boundaries: %{...},
        evolution: %{...}
      }
  """
  @spec new_minimal(String.t(), artifact_type()) :: fame_block()
  def new_minimal(artifact_id, artifact_type) do
    %{
      meta: %{
        fame_version: "2.0.0-BIO",
        artifact_id: artifact_id,
        artifact_type: artifact_type,
        created: Date.utc_today(),
        last_evolved: Date.utc_today(),
        purpose: "TODO: Add purpose",
        context: "TODO: Add context",
        scope: infer_scope(artifact_id),
        parent: infer_parent(artifact_id),
        children: [],
        siblings: []
      },
      impact: %{
        first_order: %{depends_on: [], depended_by: []},
        second_order: %{
          upstream_cascade: [],
          downstream_cascade: [],
          failure_blast_radius: :local
        },
        change_risk: %{
          breaking_change_likelihood: :low,
          rollback_complexity: :low,
          testing_coverage_required: 0.80
        }
      },
      boundaries: %{
        tdg: %{
          test_file: infer_test_path(artifact_id),
          property_test: nil,
          coverage_min: 0.80,
          must_fail_before_code: true
        },
        stamp: [],
        fmea: %{failure_modes: [], mitigations: []},
        aor: ["AOR-CODE-001"]
      },
      evolution: %{
        agent_instructions: "TODO: Add agent instructions",
        stability: :evolving,
        change_frequency: :occasional,
        approval_required: [],
        evolution_log: []
      }
    }
  end

  @doc """
  Creates a complete FAME block with all 12 blocks populated.
  """
  @spec new_complete(String.t(), artifact_type(), keyword()) :: fame_block()
  def new_complete(artifact_id, artifact_type, opts \\ []) do
    minimal = new_minimal(artifact_id, artifact_type)

    Map.merge(minimal, %{
      knowledge: Keyword.get(opts, :knowledge, default_knowledge(artifact_id)),
      formal: Keyword.get(opts, :formal, %{}),
      agent_context: Keyword.get(opts, :agent_context, default_agent_context()),
      metabolism: Keyword.get(opts, :metabolism, default_metabolism()),
      invariants: Keyword.get(opts, :invariants, default_invariants()),
      stigmergy: Keyword.get(opts, :stigmergy, default_stigmergy()),
      contracts: Keyword.get(opts, :contracts, default_contracts()),
      observability: Keyword.get(opts, :observability, default_observability(artifact_id))
    })
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

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

  defp infer_test_path(artifact_id) do
    path =
      artifact_id
      |> String.replace(".", "/")
      |> then(&"test/#{&1}_test.exs")

    path
  end

  defp default_knowledge(artifact_id) do
    today = Date.utc_today()
    iso_date = Date.to_iso8601(today)
    date_str = String.replace(iso_date, "-", "")
    slug = String.split(artifact_id, ".")
    slug_name = List.last(slug)
    zettel_id = "#{date_str}-#{slug_name}"

    %{
      zettel_id: zettel_id,
      tags: [],
      links: %{concepts: [], related_code: [], formal_specs: [], journal: []},
      graph_node: "node:#{String.replace(artifact_id, ".", ":")}",
      graph_edges: []
    }
  end

  defp default_agent_context do
    %{
      code_style: :functional,
      preferred_patterns: [:with_chain, :pipe, :pattern_match],
      avoid_patterns: [:nested_case, :deep_nesting],
      debug_hints: [],
      common_errors: [],
      test_strategy: :mixed,
      edge_cases: [],
      update_checklist: [
        "Run mix compile",
        "Run related tests",
        "Check for STAMP violations",
        "Update journal if significant"
      ]
    }
  end

  defp default_metabolism do
    %{
      resource_profile: %{cpu_weight: :low, memory_footprint: :low, io_pattern: :minimal},
      adaptation: %{
        scale_trigger: %{cpu: 0.80, memory: 0.85, latency_ms: 100},
        degrade_gracefully: true,
        adaptation_rate: 0.1
      },
      lifecycle: %{apoptosis_triggers: [:orphaned], autophagy_enabled: false, max_age_hours: nil},
      budget: %{max_concurrent_ops: 100, max_memory_mb: 256, max_cpu_percent: 50}
    }
  end

  defp default_invariants do
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

  defp default_stigmergy do
    %{
      signals: %{emits: [], responds_to: [], decay_rate: 0.1},
      coordination: %{pattern: :none, gradient: nil},
      emergence: %{allowed_patterns: [], forbidden_patterns: [:cascade_failure, :deadlock]}
    }
  end

  defp default_contracts do
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

  defp default_observability(artifact_id) do
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
        metrics: %{counters: [], gauges: [], histograms: []}
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
end
