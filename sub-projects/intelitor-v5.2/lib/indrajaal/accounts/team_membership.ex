defmodule Indrajaal.Accounts.TeamMembership do
  @moduledoc """
  Team membership join table with role - based access.

  Manages the relationship between __users and teams, including
  roles, permissions, and membership metadata.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Accounts

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:member, :lead, :admin]
      default :member
      description "Role within the team"
    end

    attribute :joined_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      description "When user joined the team"
    end

    attribute :active, :boolean do
      default true
      description "Whether membership is active"
    end

    attribute :permissions, {:array, :atom} do
      default []
      description "Team - specific permissions"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional membership data"
    end

    timestamps()
  end

  relationships do
    belongs_to :team, Indrajaal.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :invited_by, Indrajaal.Accounts.User do
      description "User who invited this member"
    end
  end

  identities do
    identity :unique_membership, [:team_id, :user_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:team_id, :user_id, :role, :permissions, :invited_by_id, :tenant_id]

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:joined_at, DateTime.utc_now())
      end
    end

    update :update_role do
      require_atomic? false
      accept [:role, :permissions]
    end

    update :activate do
      accept []
      require_atomic? false
      change set_attribute(:active, true)
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:active, false)
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:active, false)
    end
  end

  calculations do
    calculate :duration_days, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.joined_at do
            DateTime.diff(now, record.joined_at, :day)
          else
            0
          end
        end)
      end
    end

    calculate :role_display, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.role do
            :admin -> "Administrator"
            :lead -> "Team Lead"
            :member -> "Member"
            _ -> "Unknown"
          end
        end)
      end
    end
  end

  validations do
    # Validations will be added when cross - resource validation is needed
  end

  policies do
    # Team admins can manage memberships
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     exists(
                       team.team_memberships,
                       user_id == ^actor(:id) and role == :admin
                     )
                   )

      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Members can read memberships
    policy action_type(:read) do
      authorize_if expr(team_id in ^actor(:team_ids))
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Users can deactivate their own membership
    policy action([:deactivate, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create
    define :update_role
    define :activate
    define :deactivate
  end

  postgres do
    table "team_memberships"
    repo Indrajaal.Repo

    custom_indexes do
      index [:team_id, :user_id], unique: true
      index [:user_id, :active]
      index [:team_id, :role], where: "active = true"
    end
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
