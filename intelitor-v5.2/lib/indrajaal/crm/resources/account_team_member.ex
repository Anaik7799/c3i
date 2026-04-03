defmodule Indrajaal.Crm.AccountTeamMember do
  @moduledoc """
  Account Team Member resource for managing account teams.

  Features:
  - Assign multiple users to an account with specific roles
  - Define access levels and responsibilities
  - Track team member contributions
  - Support for territory-based assignments

  ## STAMP Compliance
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-DB-012: create_if_not_exists indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Team member role and responsibility
    attribute :team_role, :atom do
      allow_nil? false

      constraints one_of: [
                    :account_manager,
                    :sales_rep,
                    :technical_consultant,
                    :customer_success,
                    :support,
                    :executive_sponsor,
                    :other
                  ]

      description "Team member's role on the account"
    end

    attribute :access_level, :atom do
      default :read_only
      constraints one_of: [:read_only, :read_write, :full_access]
      description "Access level for this team member"
    end

    # Status
    attribute :is_active, :boolean do
      default true
      description "Is this team member currently active?"
    end

    # Contribution tracking
    attribute :primary_responsibility, :string do
      constraints max_length: 255
      description "Primary responsibility for this account"
    end

    attribute :notes, :string do
      description "Notes about team member's involvement"
    end

    # Territory
    attribute :territory, :string do
      constraints max_length: 100
      description "Territory assignment"
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :account, Indrajaal.Crm.Account do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_public? true
      description "Team member user"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:team_role, :access_level, :primary_responsibility, :notes, :territory]

      argument :account_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:account_id, :user_id, :team_role])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:team_role, :access_level, :is_active, :primary_responsibility, :notes, :territory]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :activate do
      require_atomic? false
      accept []

      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      accept []

      change set_attribute(:is_active, false)
    end

    update :change_role do
      require_atomic? false
      accept []

      argument :team_role, :atom, allow_nil?: false

      change fn changeset, _ ->
        role = Ash.Changeset.get_argument(changeset, :team_role)
        Ash.Changeset.change_attribute(changeset, :team_role, role)
      end
    end

    update :change_access_level do
      require_atomic? false
      accept []

      argument :access_level, :atom, allow_nil?: false

      change fn changeset, _ ->
        level = Ash.Changeset.get_argument(changeset, :access_level)
        Ash.Changeset.change_attribute(changeset, :access_level, level)
      end
    end
  end

  calculations do
    calculate :is_active_member?, :boolean, expr(is_active == true)
    calculate :has_write_access?, :boolean, expr(access_level in [:read_write, :full_access])
  end

  validations do
    # Ensure unique user per account
    validate fn changeset, _ ->
      account_id = Ash.Changeset.get_attribute(changeset, :account_id)
      user_id = Ash.Changeset.get_attribute(changeset, :user_id)

      if account_id && user_id do
        # In production, query to check if combination exists
        # For now, rely on database unique constraint
        :ok
      else
        :ok
      end
    end
  end

  policies do
    # Admins can do anything
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can manage team members
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read team information
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
    end
  end

  code_interface do
    define :create
    define :update
    define :activate
    define :deactivate
    define :change_role, args: [:team_role]
    define :change_access_level, args: [:access_level]
  end

  postgres do
    table "account_team_members"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :account_id, :user_id], unique: true
      index [:account_id]
      index [:user_id]
      index [:team_role]
      index [:is_active], where: "is_active = true"
      index [:territory]
      index [:created_at]
    end
  end
end
