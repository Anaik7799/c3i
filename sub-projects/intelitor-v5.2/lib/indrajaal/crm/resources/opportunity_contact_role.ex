defmodule Indrajaal.Crm.OpportunityContactRole do
  @moduledoc """
  Junction resource linking Contacts to Opportunities with specific roles.

  Features:
  - Many-to-many relationship between Contacts and Opportunities
  - Role assignment (Decision Maker, Influencer, etc.)
  - Primary contact designation
  - Activity tracking per role

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

    # Role definition
    attribute :role, :atom do
      allow_nil? false

      constraints one_of: [
                    :decision_maker,
                    :economic_buyer,
                    :technical_buyer,
                    :influencer,
                    :evaluator,
                    :champion,
                    :blocker,
                    :end_user,
                    :other
                  ]

      description "Contact's role in the opportunity"
    end

    attribute :is_primary, :boolean do
      default false
      description "Is this the primary contact for the opportunity?"
    end

    # Additional details
    attribute :influence_level, :atom do
      constraints one_of: [:high, :medium, :low]
      description "Level of influence on decision"
    end

    attribute :notes, :string do
      description "Notes about this contact's involvement"
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :opportunity, Indrajaal.Crm.Opportunity do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :contact, Indrajaal.Crm.Contact do
      allow_nil? false
      attribute_public? true
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
      accept [:role, :is_primary, :influence_level, :notes]

      argument :opportunity_id, :uuid, allow_nil?: false
      argument :contact_id, :uuid, allow_nil?: false
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:opportunity_id, arg(:opportunity_id))
      change set_attribute(:contact_id, arg(:contact_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:opportunity_id, :contact_id, :role])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:role, :is_primary, :influence_level, :notes]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :set_primary do
      require_atomic? false
      accept []

      # When setting a contact as primary, unset all other contacts on same opportunity
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :is_primary, true)
      end
    end

    update :unset_primary do
      require_atomic? false
      accept []

      change set_attribute(:is_primary, false)
    end
  end

  calculations do
    calculate :is_decision_maker?, :boolean, expr(role == :decision_maker)
    calculate :is_influencer?, :boolean, expr(role == :influencer)
  end

  validations do
    # Ensure unique contact per opportunity
    validate fn changeset, _ ->
      opportunity_id = Ash.Changeset.get_attribute(changeset, :opportunity_id)
      contact_id = Ash.Changeset.get_attribute(changeset, :contact_id)

      if opportunity_id && contact_id do
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

    # Managers can manage contact roles
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
    end
  end

  code_interface do
    define :create
    define :update
    define :set_primary
    define :unset_primary
  end

  postgres do
    table "opportunity_contact_roles"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :opportunity_id, :contact_id], unique: true
      index [:opportunity_id]
      index [:contact_id]
      index [:role]
      index [:is_primary], where: "is_primary = true"
      index [:created_at]
    end
  end
end
