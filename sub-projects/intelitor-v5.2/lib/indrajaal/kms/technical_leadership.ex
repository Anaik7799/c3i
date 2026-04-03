defmodule Indrajaal.KMS.TechnicalLeadership do
  @moduledoc """
  Technical Leadership & Architecture domain view for KMS.

  WHAT: Specialized KMS interface for CTOs, Tech Leads, and Architects.
  WHY: Enable strategic technical decision-making with full knowledge context.
  CONSTRAINTS: SC-KMS-007 (decision traceability), SC-KMS-008 (architecture coherence)

  ## Domain Concepts

  ### Decision Records
  - **ADR** (Architecture Decision Record): Major architectural choices
  - **RFC** (Request for Comments): Proposed changes for team review
  - **Tech Spec**: Detailed technical specifications
  - **Spike**: Time-boxed research/exploration results

  ### Architecture Artifacts
  - **C4 Models**: Context, Container, Component, Code diagrams
  - **Sequence Diagrams**: Interaction flows
  - **Data Models**: Schema definitions and relationships
  - **API Contracts**: OpenAPI/AsyncAPI specifications

  ### Technical Debt
  - **Debt Items**: Tracked technical debt with impact scores
  - **Remediation Plans**: Scheduled debt payoff strategies
  - **Quality Gates**: Automated debt thresholds

  ### Knowledge Graph
  - **Decision → Implementation**: Links ADRs to code changes
  - **Dependency Map**: Service/module dependencies
  - **Capability Matrix**: Team skills vs technology requirements

  ## Holon Types (Technical Leadership Domain)
  - `:decision` - ADR, RFC, Tech Spec, Spike
  - `:architecture` - C4 models, diagrams, contracts
  - `:debt` - Technical debt items and plans
  - `:capability` - Team/technology capabilities
  - `:radar` - Technology radar entries

  ## STAMP Constraints
  - SC-KMS-007: All decisions must be traceable to implementation
  - SC-KMS-008: Architecture changes require impact analysis
  - SC-KMS-009: Technical debt must have remediation timeline
  """

  alias Indrajaal.KMS

  # ============================================================================
  # DECISION RECORDS (ADR/RFC/SPEC)
  # ============================================================================

  @doc """
  Create a new Architecture Decision Record (ADR).

  ## Parameters
  - `title`: Decision title (e.g., "Use PostgreSQL for primary storage")
  - `context`: Background and problem statement
  - `decision`: The decision made
  - `consequences`: Expected outcomes and trade-offs
  - `opts`: Additional options
    - `:status` - draft | proposed | accepted | deprecated | superseded
    - `:supersedes` - ID of superseded ADR
    - `:related_to` - List of related holon IDs
    - `:tags` - Categorization tags

  ## Example
  ```elixir
  {:ok, adr} = TechnicalLeadership.create_adr(
    "Use Event Sourcing for Audit Trail",
    "We need complete audit trail with replay capability...",
    "Implement event sourcing pattern using Commanded library",
    ["Full audit history", "Increased complexity", "Learning curve"],
    status: :proposed,
    tags: ["architecture", "data", "audit"]
  )
  ```
  """
  @spec create_adr(String.t(), String.t(), String.t(), list(String.t()), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_adr(title, context, decision, consequences, opts \\ []) do
    status = Keyword.get(opts, :status, :draft)
    supersedes = Keyword.get(opts, :supersedes)
    related_to = Keyword.get(opts, :related_to, [])
    tags = Keyword.get(opts, :tags, [])

    # Generate ADR number
    adr_number = generate_adr_number()

    payload = %{
      type: "adr",
      number: adr_number,
      title: title,
      context: context,
      decision: decision,
      consequences: consequences,
      status: status,
      supersedes: supersedes,
      related_decisions: related_to,
      tags: tags,
      created_by: current_user(),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :decision,
      name: "ADR-#{adr_number}: #{title}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "adr",
        version: "1.0",
        schema: "adr_v1"
      }
    }

    with {:ok, holon} <- KMS.create_holon(attrs) do
      # Create relationships to related decisions
      Enum.each(related_to, fn related_id ->
        KMS.create_edge(holon.id, related_id, :references)
      end)

      # Link to superseded ADR if applicable
      if supersedes do
        KMS.create_edge(holon.id, supersedes, :supersedes)
        update_adr_status(supersedes, :superseded)
      end

      {:ok, holon}
    end
  end

  @doc """
  Create a Request for Comments (RFC).

  ## Parameters
  - `title`: RFC title
  - `summary`: Brief description
  - `motivation`: Why this change is needed
  - `detailed_design`: Technical details
  - `opts`: Additional options
    - `:reviewers` - List of reviewer identifiers
    - `:deadline` - Review deadline (DateTime)
    - `:scope` - affected_systems list
  """
  @spec create_rfc(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_rfc(title, summary, motivation, detailed_design, opts \\ []) do
    reviewers = Keyword.get(opts, :reviewers, [])
    deadline = Keyword.get(opts, :deadline)
    scope = Keyword.get(opts, :scope, [])

    rfc_number = generate_rfc_number()

    payload = %{
      type: "rfc",
      number: rfc_number,
      title: title,
      summary: summary,
      motivation: motivation,
      detailed_design: detailed_design,
      status: :open,
      reviewers: reviewers,
      review_deadline: deadline && DateTime.to_iso8601(deadline),
      affected_systems: scope,
      comments: [],
      votes: %{approve: [], reject: [], abstain: []},
      created_by: current_user(),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :decision,
      name: "RFC-#{rfc_number}: #{title}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "rfc",
        version: "1.0",
        schema: "rfc_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  @doc """
  Create a Technical Specification document.
  """
  @spec create_tech_spec(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_tech_spec(title, overview, sections, opts \\ []) do
    related_adr = Keyword.get(opts, :related_adr)
    api_contracts = Keyword.get(opts, :api_contracts, [])

    payload = %{
      type: "tech_spec",
      title: title,
      overview: overview,
      sections: sections,
      related_adr: related_adr,
      api_contracts: api_contracts,
      status: :draft,
      version: "1.0.0",
      created_by: current_user(),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :decision,
      name: "SPEC: #{title}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "tech_spec",
        version: "1.0",
        schema: "tech_spec_v1"
      }
    }

    with {:ok, holon} <- KMS.create_holon(attrs) do
      if related_adr do
        KMS.create_edge(holon.id, related_adr, :implements)
      end

      {:ok, holon}
    end
  end

  @doc """
  Create a Spike (time-boxed research) record.
  """
  @spec create_spike(String.t(), String.t(), integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_spike(title, question, timebox_hours, opts \\ []) do
    findings = Keyword.get(opts, :findings, "")
    recommendation = Keyword.get(opts, :recommendation, "")
    artifacts = Keyword.get(opts, :artifacts, [])

    payload = %{
      type: "spike",
      title: title,
      question: question,
      timebox_hours: timebox_hours,
      status: :in_progress,
      findings: findings,
      recommendation: recommendation,
      artifacts: artifacts,
      started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      created_by: current_user()
    }

    attrs = %{
      type: :decision,
      name: "SPIKE: #{title}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "spike",
        version: "1.0",
        schema: "spike_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  # ============================================================================
  # ARCHITECTURE ARTIFACTS
  # ============================================================================

  @doc """
  Create a C4 Model diagram entry.

  ## Levels
  - `:context` - System context diagram
  - `:container` - Container diagram
  - `:component` - Component diagram
  - `:code` - Code-level diagram
  """
  @spec create_c4_model(atom(), String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_c4_model(level, title, description, elements, opts \\ [])
      when level in [:context, :container, :component, :code] do
    parent_diagram = Keyword.get(opts, :parent_diagram)
    mermaid_source = Keyword.get(opts, :mermaid)
    plantuml_source = Keyword.get(opts, :plantuml)

    payload = %{
      type: "c4_model",
      level: level,
      title: title,
      description: description,
      elements: elements,
      relationships: Keyword.get(opts, :relationships, []),
      mermaid_source: mermaid_source,
      plantuml_source: plantuml_source,
      version: "1.0",
      last_verified: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :architecture,
      name: "C4-#{level |> to_string() |> String.upcase()}: #{title}",
      parent_id: parent_diagram,
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "c4_model",
        level: level,
        version: "1.0",
        schema: "c4_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  @doc """
  Create an API Contract specification.
  """
  @spec create_api_contract(String.t(), String.t(), atom(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_api_contract(name, version, protocol, spec, opts \\ [])
      when protocol in [:rest, :graphql, :grpc, :async_api] do
    payload = %{
      type: "api_contract",
      name: name,
      version: version,
      protocol: protocol,
      spec: spec,
      base_url: Keyword.get(opts, :base_url),
      authentication: Keyword.get(opts, :authentication),
      rate_limits: Keyword.get(opts, :rate_limits),
      deprecation_policy: Keyword.get(opts, :deprecation_policy),
      status: Keyword.get(opts, :status, :active),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :architecture,
      name: "API: #{name} v#{version}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "api_contract",
        protocol: protocol,
        version: "1.0",
        schema: "api_contract_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  @doc """
  Create a Data Model specification.
  """
  @spec create_data_model(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_data_model(name, schema, opts \\ []) do
    payload = %{
      type: "data_model",
      name: name,
      schema: schema,
      database: Keyword.get(opts, :database),
      relationships: Keyword.get(opts, :relationships, []),
      indexes: Keyword.get(opts, :indexes, []),
      constraints: Keyword.get(opts, :constraints, []),
      migration_history: [],
      version: "1.0",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :architecture,
      name: "MODEL: #{name}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "data_model",
        version: "1.0",
        schema: "data_model_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  # ============================================================================
  # TECHNICAL DEBT MANAGEMENT
  # ============================================================================

  @doc """
  Create a Technical Debt item.

  ## Impact Scores (1-10)
  - `:velocity_impact` - Effect on development speed
  - `:reliability_impact` - Effect on system stability
  - `:security_impact` - Security risk level
  - `:maintainability_impact` - Code maintainability effect
  """
  @spec create_debt_item(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_debt_item(title, description, impact_scores, opts \\ []) do
    estimated_effort = Keyword.get(opts, :estimated_effort)
    affected_areas = Keyword.get(opts, :affected_areas, [])
    root_cause = Keyword.get(opts, :root_cause)
    introduced_by = Keyword.get(opts, :introduced_by)

    # Calculate composite score
    composite_score = calculate_debt_score(impact_scores)

    payload = %{
      type: "tech_debt",
      title: title,
      description: description,
      impact_scores: impact_scores,
      composite_score: composite_score,
      estimated_effort_hours: estimated_effort,
      affected_areas: affected_areas,
      root_cause: root_cause,
      introduced_by: introduced_by,
      introduced_at:
        Keyword.get(opts, :introduced_at, DateTime.utc_now() |> DateTime.to_iso8601()),
      status: :identified,
      remediation_plan: nil,
      created_by: current_user()
    }

    attrs = %{
      type: :debt,
      name: "DEBT: #{title}",
      payload: payload,
      vital_signs: %{
        health: max(0.0, 1.0 - composite_score / 10),
        stress: composite_score / 10,
        energy: 0.5,
        coherence: 0.5
      },
      genome: %{
        domain: "technical_leadership",
        subtype: "tech_debt",
        version: "1.0",
        schema: "tech_debt_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  @doc """
  Create a remediation plan for technical debt.
  """
  @spec create_remediation_plan(String.t(), list(String.t()), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_remediation_plan(title, debt_item_ids, timeline, opts \\ []) do
    payload = %{
      type: "remediation_plan",
      title: title,
      debt_items: debt_item_ids,
      timeline: timeline,
      milestones: Keyword.get(opts, :milestones, []),
      resources_required: Keyword.get(opts, :resources, []),
      risk_mitigation: Keyword.get(opts, :risk_mitigation),
      success_criteria: Keyword.get(opts, :success_criteria, []),
      status: :planned,
      progress: 0,
      created_by: current_user(),
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :debt,
      name: "PLAN: #{title}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "remediation_plan",
        version: "1.0",
        schema: "remediation_plan_v1"
      }
    }

    with {:ok, plan} <- KMS.create_holon(attrs) do
      # Link to debt items
      Enum.each(debt_item_ids, fn debt_id ->
        KMS.create_edge(plan.id, debt_id, :remediates)
      end)

      {:ok, plan}
    end
  end

  # ============================================================================
  # TECHNOLOGY RADAR
  # ============================================================================

  @doc """
  Create a Technology Radar entry.

  ## Quadrants
  - `:techniques` - Processes and practices
  - `:tools` - Software tools
  - `:platforms` - Infrastructure platforms
  - `:languages_frameworks` - Programming languages and frameworks

  ## Rings
  - `:adopt` - Ready for production use
  - `:trial` - Worth pursuing in projects
  - `:assess` - Worth exploring
  - `:hold` - Proceed with caution
  """
  @spec create_radar_entry(String.t(), atom(), atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_radar_entry(name, quadrant, ring, description, opts \\ [])
      when quadrant in [:techniques, :tools, :platforms, :languages_frameworks]
      when ring in [:adopt, :trial, :assess, :hold] do
    payload = %{
      type: "radar_entry",
      name: name,
      quadrant: quadrant,
      ring: ring,
      description: description,
      rationale: Keyword.get(opts, :rationale),
      examples: Keyword.get(opts, :examples, []),
      related_adrs: Keyword.get(opts, :related_adrs, []),
      last_reviewed: DateTime.utc_now() |> DateTime.to_iso8601(),
      review_history: [],
      created_by: current_user()
    }

    attrs = %{
      type: :radar,
      name: "RADAR: #{name}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "radar_entry",
        quadrant: quadrant,
        ring: ring,
        version: "1.0",
        schema: "radar_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  @doc """
  Move a radar entry to a different ring.
  """
  @spec move_radar_entry(String.t(), atom(), String.t()) :: {:ok, map()} | {:error, term()}
  def move_radar_entry(entry_id, new_ring, rationale)
      when new_ring in [:adopt, :trial, :assess, :hold] do
    with {:ok, entry} <- KMS.get_holon(entry_id) do
      old_ring = entry.payload["ring"] || entry.payload[:ring]

      history_entry = %{
        from: old_ring,
        to: new_ring,
        rationale: rationale,
        moved_by: current_user(),
        moved_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      updated_payload =
        entry.payload
        |> Map.put(:ring, new_ring)
        |> Map.put("ring", new_ring)
        |> Map.update(:review_history, [history_entry], &[history_entry | &1])
        |> Map.update("review_history", [history_entry], &[history_entry | &1])
        |> Map.put(:last_reviewed, DateTime.utc_now() |> DateTime.to_iso8601())

      KMS.update_holon(entry_id, %{
        payload: updated_payload,
        genome: Map.put(entry.genome || %{}, :ring, new_ring)
      })
    end
  end

  # ============================================================================
  # CAPABILITY MATRIX
  # ============================================================================

  @doc """
  Create a Team Capability entry.
  """
  @spec create_team_capability(String.t(), list(String.t()), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_team_capability(team_name, technologies, proficiency_levels, opts \\ []) do
    payload = %{
      type: "team_capability",
      team_name: team_name,
      technologies: technologies,
      proficiency_levels: proficiency_levels,
      certifications: Keyword.get(opts, :certifications, []),
      training_needs: Keyword.get(opts, :training_needs, []),
      growth_areas: Keyword.get(opts, :growth_areas, []),
      last_assessment: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    attrs = %{
      type: :capability,
      name: "CAPABILITY: #{team_name}",
      payload: payload,
      genome: %{
        domain: "technical_leadership",
        subtype: "team_capability",
        version: "1.0",
        schema: "capability_v1"
      }
    }

    KMS.create_holon(attrs)
  end

  # ============================================================================
  # QUERIES & ANALYTICS
  # ============================================================================

  @doc """
  List all ADRs with optional status filter.
  """
  @spec list_adrs(keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_adrs(opts \\ []) do
    status = Keyword.get(opts, :status)

    case KMS.list_holons(type: :decision) do
      {:ok, holons} ->
        adrs =
          holons
          |> Enum.filter(fn h ->
            genome = h[:genome] || h["genome"] || %{}
            subtype = genome[:subtype] || genome["subtype"]
            subtype == "adr"
          end)
          |> maybe_filter_status(status)
          |> Enum.sort_by(
            fn h ->
              payload = h[:payload] || h["payload"] || %{}
              payload[:number] || payload["number"] || 0
            end,
            :desc
          )

        {:ok, adrs}

      error ->
        error
    end
  end

  @doc """
  List all open RFCs.
  """
  @spec list_open_rfcs() :: {:ok, list(map())} | {:error, term()}
  def list_open_rfcs do
    case KMS.list_holons(type: :decision) do
      {:ok, holons} ->
        rfcs =
          holons
          |> Enum.filter(fn h ->
            genome = h[:genome] || h["genome"] || %{}
            payload = h[:payload] || h["payload"] || %{}
            subtype = genome[:subtype] || genome["subtype"]
            status = payload[:status] || payload["status"]
            subtype == "rfc" and status == :open
          end)

        {:ok, rfcs}

      error ->
        error
    end
  end

  @doc """
  Get technical debt summary with prioritization.
  """
  @spec debt_summary() :: {:ok, map()} | {:error, term()}
  def debt_summary do
    case KMS.list_holons(type: :debt) do
      {:ok, holons} ->
        debt_items =
          holons
          |> Enum.filter(fn h ->
            genome = h[:genome] || h["genome"] || %{}
            (genome[:subtype] || genome["subtype"]) == "tech_debt"
          end)

        summary = %{
          total_items: length(debt_items),
          by_status: group_by_payload_field(debt_items, :status),
          by_severity: categorize_by_score(debt_items),
          total_estimated_hours: sum_estimated_hours(debt_items),
          highest_priority: get_highest_priority_debt(debt_items, 5),
          average_score: calculate_average_score(debt_items)
        }

        {:ok, summary}

      error ->
        error
    end
  end

  @doc """
  Get Technology Radar current state.
  """
  @spec radar_snapshot() :: {:ok, map()} | {:error, term()}
  def radar_snapshot do
    case KMS.list_holons(type: :radar) do
      {:ok, holons} ->
        entries =
          Enum.filter(holons, fn h ->
            genome = h[:genome] || h["genome"] || %{}
            (genome[:subtype] || genome["subtype"]) == "radar_entry"
          end)

        snapshot = %{
          techniques: group_by_ring(entries, :techniques),
          tools: group_by_ring(entries, :tools),
          platforms: group_by_ring(entries, :platforms),
          languages_frameworks: group_by_ring(entries, :languages_frameworks),
          total_entries: length(entries),
          last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        {:ok, snapshot}

      error ->
        error
    end
  end

  @doc """
  Get decision impact analysis - trace from ADR to implementation.
  """
  @spec decision_impact(String.t()) :: {:ok, map()} | {:error, term()}
  def decision_impact(adr_id) do
    with {:ok, adr} <- KMS.get_holon(adr_id),
         {:ok, descendants} <- KMS.get_descendants(adr_id) do
      # Group descendants by type
      by_type =
        Enum.group_by(descendants, fn h ->
          genome = h[:genome] || h["genome"] || %{}
          genome[:subtype] || genome["subtype"] || "unknown"
        end)

      analysis = %{
        adr: adr,
        tech_specs: Map.get(by_type, "tech_spec", []),
        api_contracts: Map.get(by_type, "api_contract", []),
        data_models: Map.get(by_type, "data_model", []),
        related_debt: find_related_debt(adr_id),
        implementation_status: calculate_implementation_status(by_type),
        last_analyzed: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, analysis}
    end
  end

  @doc """
  Architecture coherence check - validate C4 model consistency.
  """
  @spec check_architecture_coherence() :: {:ok, map()} | {:error, term()}
  def check_architecture_coherence do
    case KMS.list_holons(type: :architecture) do
      {:ok, holons} ->
        c4_models =
          Enum.filter(holons, fn h ->
            genome = h[:genome] || h["genome"] || %{}
            (genome[:subtype] || genome["subtype"]) == "c4_model"
          end)

        issues = []

        # Check for orphaned components
        issues = issues ++ check_orphaned_components(c4_models)

        # Check for missing relationships
        issues = issues ++ check_missing_relationships(c4_models)

        # Check for stale diagrams
        issues = issues ++ check_stale_diagrams(c4_models)

        result = %{
          total_models: length(c4_models),
          by_level: group_by_genome_field(c4_models, :level),
          issues: issues,
          coherence_score: calculate_coherence_score(issues, c4_models),
          last_checked: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        {:ok, result}

      error ->
        error
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp generate_adr_number do
    case list_adrs() do
      {:ok, adrs} ->
        max_number =
          adrs
          |> Enum.map(fn a ->
            payload = a[:payload] || a["payload"] || %{}
            payload[:number] || payload["number"] || 0
          end)
          |> Enum.max(fn -> 0 end)

        max_number + 1

      _ ->
        1
    end
  end

  defp generate_rfc_number do
    timestamp = DateTime.utc_now()
    random_num = :rand.uniform(999)
    random_str = random_num |> Integer.to_string() |> String.pad_leading(3, "0")
    "#{timestamp.year}-#{String.pad_leading("#{timestamp.month}", 2, "0")}-#{random_str}"
  end

  defp current_user do
    Process.get(:current_user) || Process.get(:actor_email) || "system"
  end

  defp update_adr_status(adr_id, new_status) do
    with {:ok, adr} <- KMS.get_holon(adr_id) do
      updated_payload = Map.put(adr.payload, :status, new_status)
      KMS.update_holon(adr_id, %{payload: updated_payload})
    end
  end

  defp calculate_debt_score(impact_scores) do
    weights = %{
      velocity_impact: 0.3,
      reliability_impact: 0.25,
      security_impact: 0.25,
      maintainability_impact: 0.2
    }

    Enum.reduce(weights, 0.0, fn {key, weight}, acc ->
      score = Map.get(impact_scores, key, 0) || Map.get(impact_scores, to_string(key), 0)
      acc + score * weight
    end)
  end

  defp maybe_filter_status(holons, nil), do: holons

  defp maybe_filter_status(holons, status) do
    Enum.filter(holons, fn h ->
      payload = h[:payload] || h["payload"] || %{}
      (payload[:status] || payload["status"]) == status
    end)
  end

  defp group_by_payload_field(holons, field) do
    holons
    |> Enum.group_by(fn h ->
      payload = h[:payload] || h["payload"] || %{}
      payload[field] || payload[to_string(field)] || :unknown
    end)
    |> Enum.map(fn {k, v} -> {k, length(v)} end)
    |> Map.new()
  end

  defp group_by_genome_field(holons, field) do
    holons
    |> Enum.group_by(fn h ->
      genome = h[:genome] || h["genome"] || %{}
      genome[field] || genome[to_string(field)] || :unknown
    end)
    |> Enum.map(fn {k, v} -> {k, length(v)} end)
    |> Map.new()
  end

  defp categorize_by_score(debt_items) do
    debt_items
    |> Enum.group_by(fn h ->
      payload = h[:payload] || h["payload"] || %{}
      score = payload[:composite_score] || payload["composite_score"] || 0

      cond do
        score >= 8 -> :critical
        score >= 6 -> :high
        score >= 4 -> :medium
        true -> :low
      end
    end)
    |> Enum.map(fn {k, v} -> {k, length(v)} end)
    |> Map.new()
  end

  defp sum_estimated_hours(debt_items) do
    Enum.reduce(debt_items, 0, fn h, acc ->
      payload = h[:payload] || h["payload"] || %{}
      hours = payload[:estimated_effort_hours] || payload["estimated_effort_hours"] || 0
      acc + hours
    end)
  end

  defp get_highest_priority_debt(debt_items, limit) do
    debt_items
    |> Enum.sort_by(
      fn h ->
        payload = h[:payload] || h["payload"] || %{}
        payload[:composite_score] || payload["composite_score"] || 0
      end,
      :desc
    )
    |> Enum.take(limit)
  end

  defp calculate_average_score([]), do: 0.0

  defp calculate_average_score(items) do
    scores =
      Enum.map(items, fn h ->
        payload = h[:payload] || h["payload"] || %{}
        payload[:composite_score] || payload["composite_score"] || 0.0
      end)

    case length(scores) do
      0 -> 0.0
      n -> Enum.sum(scores) / n
    end
  end

  defp group_by_ring(entries, quadrant) do
    entries
    |> Enum.filter(fn h ->
      genome = h[:genome] || h["genome"] || %{}
      (genome[:quadrant] || genome["quadrant"]) == quadrant
    end)
    |> Enum.group_by(fn h ->
      genome = h[:genome] || h["genome"] || %{}
      genome[:ring] || genome["ring"] || :unknown
    end)
  end

  defp find_related_debt(adr_id) do
    case KMS.get_edges(adr_id) do
      {:ok, edges} ->
        debt_ids =
          edges
          |> Enum.filter(fn edge ->
            edge_type = edge[:type] || edge["type"]
            edge_type in ["relates_to", "impacts", "addresses", "mitigates"]
          end)
          |> Enum.map(fn edge ->
            source = edge[:source_id] || edge["source_id"]
            target = edge[:target_id] || edge["target_id"]
            if source == adr_id, do: target, else: source
          end)
          |> Enum.uniq()

        Enum.reduce(debt_ids, [], fn id, acc ->
          case KMS.get_holon(id) do
            {:ok, holon} ->
              genome = holon[:genome] || Map.get(holon, :genome, %{})
              subtype = genome[:subtype] || genome["subtype"]
              if subtype == "tech_debt", do: [holon | acc], else: acc

            _ ->
              acc
          end
        end)

      _ ->
        []
    end
  end

  defp calculate_implementation_status(by_type) do
    total = Enum.reduce(by_type, 0, fn {_, items}, acc -> acc + length(items) end)

    if total > 0 do
      %{
        total_artifacts: total,
        specs_count: length(Map.get(by_type, "tech_spec", [])),
        apis_count: length(Map.get(by_type, "api_contract", [])),
        models_count: length(Map.get(by_type, "data_model", []))
      }
    else
      %{total_artifacts: 0, status: :not_started}
    end
  end

  defp check_orphaned_components(c4_models) do
    # Check for components without parent containers
    c4_models
    |> Enum.filter(fn h ->
      genome = h[:genome] || h["genome"] || %{}
      level = genome[:level] || genome["level"]
      level == :component and is_nil(h[:parent_id] || h["parent_id"])
    end)
    |> Enum.map(fn h ->
      %{type: :orphaned_component, holon_id: h[:id] || h["id"], severity: :warning}
    end)
  end

  defp check_missing_relationships(c4_models) do
    # Check for containers with no relationships
    c4_models
    |> Enum.filter(fn h ->
      genome = h[:genome] || h["genome"] || %{}
      payload = h[:payload] || h["payload"] || %{}
      level = genome[:level] || genome["level"]
      relationships = payload[:relationships] || payload["relationships"] || []
      level == :container and Enum.empty?(relationships)
    end)
    |> Enum.map(fn h ->
      %{type: :isolated_container, holon_id: h[:id] || h["id"], severity: :info}
    end)
  end

  defp check_stale_diagrams(c4_models) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    c4_models
    |> Enum.filter(fn h ->
      payload = h[:payload] || h["payload"] || %{}
      last_verified = payload[:last_verified] || payload["last_verified"]

      case last_verified && DateTime.from_iso8601(last_verified) do
        {:ok, dt, _} -> DateTime.compare(dt, thirty_days_ago) == :lt
        _ -> true
      end
    end)
    |> Enum.map(fn h ->
      %{type: :stale_diagram, holon_id: h[:id] || h["id"], severity: :warning}
    end)
  end

  defp calculate_coherence_score([], _models), do: 100.0
  defp calculate_coherence_score(_issues, []), do: 0.0

  defp calculate_coherence_score(issues, c4_models) do
    # Coherence score: 100 - (issues_count / models_count * 100), min 0
    issue_ratio = length(issues) / max(length(c4_models), 1)
    max(0.0, 100.0 - issue_ratio * 100.0)
  end
end
