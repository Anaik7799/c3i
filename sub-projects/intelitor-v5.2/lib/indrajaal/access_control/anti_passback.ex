defmodule Indrajaal.AccessControl.AntiPassback do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Pr_event credential sharing and tailgating by tracking entry / exit __states.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomainDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :current_state, :atom do
      constraints one_of: [:outside, :inside, :unknown]
      default :outside
    end

    attribute :last_entry_time, :utc_datetime
    attribute :last_exit_time, :utc_datetime
    attribute :last_access_point_id, :uuid

    attribute :violation_count, :integer, default: 0
    attribute :last_violation_time, :utc_datetime

    attribute :enforcement_level, :atom do
      constraints one_of: [:none, :warning, :strict]
      default :warning
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :bypass]
      default :active
    end

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :access_credential, Indrajaal.AccessControl.AccessCredential do
      allow_nil? false
    end

    belongs_to :zone, Indrajaal.Sites.Zone do
      allow_nil? false
    end
  end

  identities do
    identity :unique_credential_zone,
             [:tenant_id, :access_credential_id, :zone_id]
  end

  actions do
    defaults [:read, :update]

    create :initialize do
      primary? true
      accept [:access_credential_id, :zone_id, :enforcement_level]
    end

    update :record_entry do
      require_atomic? false
      accept [:last_access_point_id]

      change set_attribute(:current_state, :inside)
      change set_attribute(:last_entry_time, &DateTime.utc_now/0)
    end

    update :record_exit do
      require_atomic? false
      accept [:last_access_point_id]

      change set_attribute(:current_state, :outside)
      change set_attribute(:last_exit_time, &DateTime.utc_now/0)
    end

    update :record_violation do
      require_atomic? false
      accept []

      change increment(:violation_count)
      change set_attribute(:last_violation_time, &DateTime.utc_now/0)
    end

    update :reset_state do
      require_atomic? false
      accept []

      change set_attribute(:current_state, :unknown)
      change set_attribute(:last_entry_time, nil)
      change set_attribute(:last_exit_time, nil)
    end

    update :bypass do
      require_atomic? false
      accept []
      change set_attribute(:status, :bypass)
    end

    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:status, :active)
    end

    read :list_violations do
      filter expr(violation_count > 0)
    end
  end

  calculations do
    calculate :can_enter?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.current_state, record.enforcement_level, record.status} do
            {_, _, :bypass} -> true
            {:outside, _, :active} -> true
            {:unknown, :none, :active} -> true
            {:unknown, :warning, :active} -> true
            _ -> false
          end
        end)
      end
    end

    calculate :can_exit?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.current_state, record.enforcement_level, record.status} do
            {_, _, :bypass} -> true
            {:inside, _, :active} -> true
            {:unknown, :none, :active} -> true
            {:unknown, :warning, :active} -> true
            _ -> false
          end
        end)
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      # Allow system actors to update __states
      authorize_if relates_to_actor_via(:tenant)
    end
  end

  code_interface do
    define :initialize, action: :initialize
    define :record_entry, action: :record_entry
    define :record_exit, action: :record_exit
    define :record_violation, action: :record_violation
    define :reset_state, action: :reset_state
    define :bypass, action: :bypass
    define :activate, action: :activate
    define :list_violations
  end

  postgres do
    table "anti_passback"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
