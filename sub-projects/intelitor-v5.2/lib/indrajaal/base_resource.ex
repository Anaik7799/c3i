defmodule Indrajaal.BaseResource do
  @moduledoc """
  Base resource module providing common configuration for all Ash resources.

  Includes:
  - Common Ash.Resource setup with data layer and extensions
  - Standard code interface
  - Common calculations and preparations

  ## Usage

      defmodule MyApp.MyResource do
        use Indrajaal.BaseResource,
          domain: MyApp.MyDomain

        postgres do
          table "my_resources"
          repo Indrajaal.Repo

          # Add custom indexes, __statements, etc.
        end
      end

  ## FAME (Framework for Augmented Module Enrichment)

  This module is classified as **P0-CRITICAL** with **FROZEN** stability.
  All Ash resources in the system inherit from this module, making it
  the foundation of the entire data layer.

  ### Safety Constraints
  - SC-DB-001: All resources MUST use BaseResource
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for function-based changes

  ### Modification Protocol
  Any changes to this module require:
  1. Executive Agent approval (AOR-EXE-001)
  2. Full regression test suite execution
  3. STAMP hazard analysis review
  4. Rollback plan verification (SC-EMR-060)
  """

  # ============================================================================
  # FAME Metadata - Framework for Augmented Module Enrichment
  # Classification: P0-CRITICAL | Stability: FROZEN
  # ============================================================================

  @fame_meta %{
    module: __MODULE__,
    version: "1.0.0",
    created: ~D[2025-01-01],
    last_modified: ~D[2025-12-28],
    authors: ["Indrajaal Core Team"],
    classification: :p0_critical,
    domain: :data_layer,
    purpose:
      "Foundation module for all Ash resources - provides common configuration, data layer setup, code interfaces, and standard calculations",
    keywords: [:ash, :resource, :base, :macro, :data_layer, :postgres, :foundation]
  }

  @fame_impact %{
    blast_radius: :catastrophic,
    blast_radius_rationale:
      "151+ Ash resources inherit from this module - any defect propagates to entire data layer",
    dependent_count: 151,
    dependent_domains: [
      :accounts,
      :access_control,
      :alarms,
      :analytics,
      :asset_management,
      :authentication,
      :authorization,
      :billing,
      :communication,
      :compliance,
      :core,
      :devices,
      :dispatch,
      :guard_tour,
      :integration,
      :integrations,
      :maintenance,
      :policy,
      :risk_management,
      :sites,
      :video,
      :visitor_management
    ],
    failure_modes: [
      {:compilation_failure, :critical, "Syntax errors prevent all resources from compiling"},
      {:data_layer_misconfiguration, :critical,
       "Incorrect AshPostgres setup breaks database operations"},
      {:policy_authorizer_failure, :critical,
       "Missing authorizer breaks all authorization checks"},
      {:calculation_error, :high, "resource_metadata calculation affects all resources"}
    ],
    recovery_time_objective: "< 5 minutes",
    recovery_point_objective: "Last known good commit"
  }

  @fame_dependencies %{
    direct: [
      {Ash.Resource, :critical, "Core Ash resource functionality"},
      {AshPostgres.DataLayer, :critical, "PostgreSQL data layer"},
      {Ash.Policy.Authorizer, :critical, "Authorization policies"},
      {Ash.Resource.Info, :high, "Resource introspection"}
    ],
    indirect: [
      {Ecto, :critical, "Database adapter"},
      {Indrajaal.Repo, :critical, "PostgreSQL repository"}
    ],
    external: [
      {:postgresql, :critical, "Database backend"}
    ]
  }

  @fame_safety %{
    stamp_constraints: [
      {:SC_DB_001, :mandatory, "All resources MUST use BaseResource"},
      {:SC_ASH_001, :mandatory, "force_change_attribute in before_action hooks"},
      {:SC_ASH_004, :mandatory, "require_atomic? false for function-based changes"},
      {:SC_DB_005, :mandatory, "uuid_primary_key for all resources"},
      {:SC_DB_012, :mandatory, "create_if_not_exists for indexes"}
    ],
    aor_constraints: [
      {:AOR_DB_001, "Use BaseResource for all Ash resources"},
      {:AOR_EXE_001, "Executive approval required for modifications"},
      {:AOR_SAF_001, "Halt <1s on STAMP violation"}
    ],
    hazards: [
      {:HAZ_001, :catastrophic, "Compilation failure cascades to all resources"},
      {:HAZ_002, :critical, "Data layer misconfiguration causes silent data corruption"},
      {:HAZ_003, :critical, "Authorization bypass if authorizer not properly configured"}
    ],
    mitigations: [
      {:MIT_001, "Frozen stability prevents unauthorized changes"},
      {:MIT_002, "Comprehensive test coverage for all code paths"},
      {:MIT_003, "FPPS validation before any modification"}
    ]
  }

  @fame_stability %{
    level: :frozen,
    rationale:
      "Foundation module - changes have catastrophic blast radius affecting 151+ resources",
    change_frequency: :rare,
    last_breaking_change: nil,
    deprecation_policy: :never,
    modification_requirements: [
      :executive_approval,
      :full_regression_suite,
      :stamp_hazard_review,
      :rollback_plan,
      :fpps_consensus
    ]
  }

  @fame_verification %{
    test_coverage_required: 100,
    test_types: [:unit, :integration, :property, :regression],
    critical_test_paths: [
      "test/indrajaal/base_resource_test.exs",
      "test/support/factory_test.exs"
    ],
    property_tests: [
      "All resources using BaseResource compile successfully",
      "Code interface methods are accessible",
      "resource_metadata calculation returns valid map"
    ],
    verification_commands: [
      "mix compile --warnings-as-errors",
      "mix test --only base_resource",
      "mix dialyzer"
    ]
  }

  @fame_api %{
    public_macros: [
      {:__using__, 1, "Macro invoked when `use Indrajaal.BaseResource` is called"}
    ],
    options: [
      {:domain, :required, "The Ash domain module"},
      {:table, :deprecated, "No longer used - resources define their own postgres blocks"},
      {:extensions, :optional, "Additional Ash extensions to include"},
      {:primary_read_warning?, :optional, "Enable/disable primary read warnings (default: true)"}
    ],
    injected_features: [
      {:code_interface, "Defines :get and :list actions"},
      {:preparations, "Loads :resource_metadata by default"},
      {:calculations, "Provides :resource_metadata calculation"}
    ]
  }

  # Suppress unused attribute warnings - these are for documentation/tooling
  _ = @fame_meta
  _ = @fame_impact
  _ = @fame_dependencies
  _ = @fame_safety
  _ = @fame_stability
  _ = @fame_verification
  _ = @fame_api

  defmacro __using__(opts) do
    domain = Keyword.fetch!(opts, :domain)
    # The table parameter is no longer used in BaseResource
    # Resources define their own postgres blocks
    _table = Keyword.get(opts, :table)
    extensions = Keyword.get(opts, :extensions, [])
    primary_read_warning? = Keyword.get(opts, :primary_read_warning?, true)

    # Ensure unique extensions list
    all_extensions = Enum.uniq([Ash.Policy.Authorizer | extensions])

    quote do
      use Ash.Resource,
        domain: unquote(domain),
        data_layer: AshPostgres.DataLayer,
        extensions: unquote(all_extensions),
        authorizers: [Ash.Policy.Authorizer],
        primary_read_warning?: unquote(primary_read_warning?)

      # Default code interface - resources can override or extend
      unless Module.get_attribute(__MODULE__, :skip_default_code_interface) do
        code_interface do
          define :get, action: :read, get?: true
          define :list, action: :read
        end
      end

      preparations do
        prepare build(load: [:resource_metadata])
      end

      calculations do
        calculate :resource_metadata, :map do
          calculation fn records, _ ->
            Enum.map(records, fn record ->
              %{
                resource: __MODULE__,
                primary_key: Map.take(record, Ash.Resource.Info.primary_key(__MODULE__))
              }
            end)
          end
        end
      end

      # Audit logging will be added later when Oban is configured
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
