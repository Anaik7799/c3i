defmodule Intelitor.Accounts.Team do
  @moduledoc """
  Team resource for organizing users into functional groups.

  Teams provide a way to group users for permissions, notifications,
  dispatch assignments, and organizational structure.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Accounts,
    table: "teams"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 255
      description "Team name"
    end

    attribute :code, :string do
      constraints max_length: 50,
                  match: ~S/^[A-Z0-9_-]+$/

      description "Unique team code (uppercase)"
    end

    attribute :description, :string do
      constraints max_length: 5000
      description "Team purpose and responsibilities"
    end

    attribute :type, :atom do
      constraints one_of: [:operational, :administrative, :security, :maintenance, :management]
      default :operational
      description "Team type/function"
    end

    attribute :active, :boolean do
      default true
      description "Whether team is active"
    end

    attribute :settings, :map do
      default %{}
      description "Team-specific settings"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional team data"
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Intelitor.Core.Organization do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :parent_team, __MODULE__ do
      description "Parent team for hierarchical structure"
    end

    has_many :child_teams, __MODULE__ do
      destination_attribute :parent_team_id
    end

    many_to_many :members, Intelitor.Accounts.User do
      through Intelitor.Accounts.TeamMembership
      source_attribute :id
      source_attribute_on_join_resource :team_id
      destination_attribute :id
      destination_attribute_on_join_resource :user_id
    end

    has_many :team_memberships, Intelitor.Accounts.TeamMembership
  end

  identities do
    identity :unique_code_per_org, [:organization_id, :code]
  end

  actions do
    defaults [:read, :update]

    create :create do
      accept [:name, :code, :description, :type, :organization_id, :parent_team_id, :settings]

      change fn changeset, _ ->
        # Auto-generate code if not provided
        if is_nil(Ash.Changeset.get_attribute(changeset, :code)) do
          name = Ash.Changeset.get_attribute(changeset, :name)

          code =
            name
            |> String.upcase()
            |> String.replace(~r/[^A-Z0-9]+/, "_")
            |> String.slice(0, 50)

          Ash.Changeset.change_attribute(changeset, :code, code)
        else
          changeset
        end
      end
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

    update :add_member do
      require_atomic? false
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :role, :atom do
        constraints one_of: [:member, :lead, :admin]
        default :member
      end

      change fn changeset, context ->
        # This would typically create a TeamMembership
        changeset
      end
    end

    update :remove_member do
      require_atomic? false
      argument :user_id, :uuid do
        allow_nil? false
      end

      change fn changeset, context ->
        # This would typically remove a TeamMembership
        changeset
      end
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:active, false)
    end
  end

  calculations do
    calculate :member_count, :integer do
      calculation fn records, _ ->
        # This would count TeamMemberships
        Enum.map(records, fn record ->
          length(record.team_memberships || [])
        end)
      end

      load [:team_memberships]
    end

    calculate :full_path, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          build_path(record, [])
          |> Enum.reverse()
          |> Enum.join(" / ")
        end)
      end

      load [:parent_team]
    end

    calculate :is_leaf?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          Enum.empty?(record.child_teams || [])
        end)
      end

      load [:child_teams]
    end
  end

  validations do
    validate string_length(:name, min: 2, max: 255)

    validate string_length(:code, min: 2, max: 50) do
      where present(:code)
    end

    validate string_length(:description, max: 5000) do
      where present(:description)
    end
  end

  policies do
    # Team members can read their teams
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:members])
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Managers can create teams
    policy action_type(:create) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Managers can update teams
    policy action_type(:update) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Managers can activate/deactivate teams (update actions)
    policy action([:activate, :deactivate]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Team admins can manage members (update actions)
    policy action([:add_member, :remove_member]) do
      authorize_if expr(exists(team_memberships, user_id == ^actor(:id) and role == :admin))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Only admins can destroy teams
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create
    define :update
    define :activate
    define :deactivate
    define :add_member
    define :remove_member
  end

  postgres do
    table "teams"
    repo Intelitor.Repo

    custom_indexes do
      index [:organization_id, :code], unique: true
      index [:organization_id, :active]
      index [:parent_team_id]
      index [:type]
    end
  end

  # Helper function for path calculation
  defp build_path(nil, acc), do: acc

  defp build_path(team, acc) do
    build_path(team.parent_team, [team.name | acc])
  end
end
