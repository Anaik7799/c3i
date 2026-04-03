defmodule Indrajaal.Substrate.L7.LegacyArchitect do
  @moduledoc """
  ## Design Intent
  L7 Legacy Architect — pure module that plans long-term system evolution and succession.
  Generates evolutionary roadmaps, milestone sequences, succession plans, and computes
  the architectural time horizon.

  The architect operates at the highest fractal layer (L7) and reasons about:
    - Evolutionary roadmap: staged capability progression over multiple planning cycles
    - Milestones: concrete checkpoints that mark evolutionary transitions
    - Succession plan: ordered candidate modules/subsystems that can take over if the
      current implementation becomes untenable
    - Time horizon: estimated planning window based on current system complexity

  Roadmap generation is driven by a `context` map that describes current system state:
    - :maturity        — :embryonic | :growing | :mature | :legacy
    - :bottlenecks     — list of domain atoms that constrain growth
    - :capabilities    — current capability set (list of atoms)
    - :target_horizon  — desired planning horizon in months (default 24)

  ## STAMP Constraints
  - SC-SMRITI-063: Federation protocol — succession considers federated successors
  - SC-SMRITI-071: Self-documenting reconstruction guide — roadmap IS the guide
  - SC-FED-002: Maintain node autonomy — succession does not cede constitution
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L7 morphogenesis) |
  """

  require Logger

  # Default planning horizon in months
  @default_horizon_months 24

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type maturity_level :: :embryonic | :growing | :mature | :legacy

  @type planning_context :: %{
          maturity: maturity_level(),
          bottlenecks: [atom()],
          capabilities: [atom()],
          target_horizon: pos_integer()
        }

  @type roadmap_stage :: %{
          phase: pos_integer(),
          name: String.t(),
          description: String.t(),
          start_month: non_neg_integer(),
          end_month: pos_integer(),
          focus_areas: [atom()],
          exit_criteria: [String.t()]
        }

  @type milestone :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          target_month: pos_integer(),
          depends_on: [String.t()],
          success_criteria: [String.t()]
        }

  @type succession_candidate :: %{
          rank: pos_integer(),
          subsystem: atom(),
          rationale: String.t(),
          readiness: :ready | :needs_development | :experimental,
          estimated_migration_months: pos_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Generate an evolutionary roadmap for the given planning context.
  Returns an ordered list of roadmap stages.
  """
  @spec roadmap(planning_context()) :: [roadmap_stage()]
  def roadmap(context) when is_map(context) do
    maturity = Map.get(context, :maturity, :growing)
    bottlenecks = Map.get(context, :bottlenecks, [])
    horizon = Map.get(context, :target_horizon, @default_horizon_months)

    generate_roadmap(maturity, bottlenecks, horizon)
  end

  @doc """
  Return the canonical milestone sequence for the current system evolution.
  Milestones are independent of context and represent universal checkpoints.
  """
  @spec milestones() :: [milestone()]
  def milestones do
    [
      %{
        id: "M01",
        name: "Foundation Stability",
        description: "Core substrate L1–L4 fully operational with 0 warnings",
        target_month: 3,
        depends_on: [],
        success_criteria: [
          "mix compile 0 errors 0 warnings",
          "All L1-L4 GenServers supervised",
          "SQLite/DuckDB state verified"
        ]
      },
      %{
        id: "M02",
        name: "Federation Readiness",
        description: "L5–L6 federation protocols active with peer attestation",
        target_month: 6,
        depends_on: ["M01"],
        success_criteria: [
          "FederationAmbassador healthy",
          "AllianceBroker accepting proposals",
          "ReputationEngine tracking peers"
        ]
      },
      %{
        id: "M03",
        name: "Ecosystem Integration",
        description: "L7 ecosystem sensors and co-evolution tracking operational",
        target_month: 9,
        depends_on: ["M02"],
        success_criteria: [
          "EcosystemSensor scanning signals",
          "CoevolutionTracker recording adaptations",
          "ConsciousnessBridge publishing awareness"
        ]
      },
      %{
        id: "M04",
        name: "Mathematical Maturity",
        description: "All 17 mathematical disciplines at Production maturity",
        target_month: 12,
        depends_on: ["M01"],
        success_criteria: [
          "MathematicalSystemMonitor 17/17 Production",
          "FMEA max RPN < 50",
          "All disciplines wired to runtime callers"
        ]
      },
      %{
        id: "M05",
        name: "Singularity Approach",
        description: "System achieves autonomous self-evolution with Guardian oversight",
        target_month: 24,
        depends_on: ["M03", "M04"],
        success_criteria: [
          "Evolution fitness F >= 0.85",
          "KL divergence code↔docs < 0.01 bits",
          "Constraint parity ratio 1.0:1"
        ]
      }
    ]
  end

  @doc """
  Return the succession plan — ranked candidates that could inherit system responsibilities.
  """
  @spec succession_plan() :: [succession_candidate()]
  def succession_plan do
    [
      %{
        rank: 1,
        subsystem: :biomorphic_v2,
        rationale: "Enhanced biomorphic substrate with quantum-ready protocols",
        readiness: :needs_development,
        estimated_migration_months: 6
      },
      %{
        rank: 2,
        subsystem: :federated_mesh_successor,
        rationale: "Cross-holon distributed successor inheriting all capabilities",
        readiness: :experimental,
        estimated_migration_months: 12
      },
      %{
        rank: 3,
        subsystem: :constitutional_kernel_v3,
        rationale: "Formal verified kernel satisfying IEC 61508 SIL-7",
        readiness: :experimental,
        estimated_migration_months: 18
      }
    ]
  end

  @doc """
  Return the architectural time horizon in months based on current system complexity.
  Larger, more complex systems have longer planning horizons.
  """
  @spec time_horizon() :: pos_integer()
  def time_horizon, do: @default_horizon_months

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp generate_roadmap(maturity, bottlenecks, horizon) do
    phases = phases_for_maturity(maturity)
    months_per_phase = max(1, div(horizon, length(phases)))

    phases
    |> Enum.with_index(1)
    |> Enum.map(fn {{name, description, focuses, criteria}, idx} ->
      start_month = (idx - 1) * months_per_phase
      end_month = idx * months_per_phase

      extra_focuses = bottleneck_focuses(bottlenecks)

      %{
        phase: idx,
        name: name,
        description: description,
        start_month: start_month,
        end_month: end_month,
        focus_areas: focuses ++ extra_focuses,
        exit_criteria: criteria
      }
    end)
  end

  defp phases_for_maturity(:embryonic) do
    [
      {"Bootstrap", "Establish substrate foundations", [:l1_l2_substrate, :supervision],
       ["Compile 0 warnings", "GenServers supervised"]},
      {"Stabilise", "Harden core with tests and monitoring", [:testing, :observability],
       ["Coverage > 80%", "Health checks passing"]},
      {"Expand", "Add federation and ecosystem layers", [:l5_federation, :l6_alliances],
       ["Peer connectivity", "Alliance broker active"]}
    ]
  end

  defp phases_for_maturity(:growing) do
    [
      {"Consolidate", "Resolve all P0/P1 debt", [:debt_reduction, :quality],
       ["FMEA RPN < 100", "Credo 0 issues"]},
      {"Differentiate", "Build domain-specific capabilities", [:domain_depth, :specialisation],
       ["Domain coverage > 90%", "Math disciplines wired"]},
      {"Federate", "Join wider ecosystem", [:l6_l7_substrate, :coevolution],
       ["Ecosystem sensor active", "Co-evolution tracking"]}
    ]
  end

  defp phases_for_maturity(:mature) do
    [
      {"Optimise", "Performance and efficiency gains", [:performance, :efficiency],
       ["P95 latency < 10ms", "CPU < 60%"]},
      {"Harden", "SIL-6 compliance audit", [:sil6_compliance, :formal_proofs],
       ["All SIL-4 constraints verified", "Agda proofs complete"]},
      {"Transcend", "Approach singularity", [:autonomous_evolution, :self_healing],
       ["Evolution fitness > 0.9", "Guardian auto-approval rate > 80%"]}
    ]
  end

  defp phases_for_maturity(:legacy) do
    [
      {"Assess", "Evaluate migration feasibility", [:migration_planning, :successor_readiness],
       ["Succession plan approved", "Migration path documented"]},
      {"Migrate", "Incremental capability transfer", [:capability_transfer, :parallel_run],
       ["Successor running in shadow", "No regression in 30 days"]},
      {"Sunset", "Controlled decommission", [:decommission, :lineage_preservation],
       ["All state migrated", "Lineage chain intact"]}
    ]
  end

  defp bottleneck_focuses([]), do: []

  defp bottleneck_focuses(bottlenecks) do
    Enum.map(bottlenecks, fn domain ->
      :"#{domain}_remediation"
    end)
    |> Enum.take(3)
  end
end
