defmodule Indrajaal.Communication.ContactGroup do
  @moduledoc """
  Groups of __users for targeted messaging and notifications.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.CommunicationDomain

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :group_type, :atom do
      constraints one_of: [:department, :role_based, :location_based, :custom, :emergency]
      allow_nil? false
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :auto_membership_rules, :map do
      default %{}
    end

    attribute :member_user_ids, {:array, :uuid} do
      default []
    end

    attribute :external_contacts, {:array, :map} do
      default []
    end

    attribute :default_channel_preferences, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :created_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :contact_preferences, Indrajaal.Communication.ContactPreference do
      destination_attribute :group_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_group do
      argument :name, :string do
        allow_nil? false
      end

      argument :group_type, :atom do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:group_type, arg(:group_type))
      change set_attribute(:created_by_id, arg(:created_by_id))
    end

    update :add_members do
      require_atomic? false

      argument :user_ids, {:array, :uuid} do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_members = changeset.data.member_user_ids || []
        new_user_ids = Ash.Changeset.get_argument(changeset, :user_ids)
        updated_members = Enum.uniq(current_members ++ new_user_ids)
        Ash.Changeset.change_attribute(changeset, :member_user_ids, updated_members)
      end
    end

    update :remove_members do
      require_atomic? false

      argument :user_ids, {:array, :uuid} do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_members = changeset.data.member_user_ids || []
        remove_user_ids = Ash.Changeset.get_argument(changeset, :user_ids)
        updated_members = current_members -- remove_user_ids
        Ash.Changeset.change_attribute(changeset, :member_user_ids, updated_members)
      end
    end

    update :add_external_contact do
      require_atomic? false

      argument :contact_info, :map do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_contacts = changeset.data.external_contacts || []
        new_contact = Ash.Changeset.get_argument(changeset, :contact_info)
        updated_contacts = current_contacts ++ [new_contact]
        Ash.Changeset.change_attribute(changeset, :external_contacts, updated_contacts)
      end
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  code_interface do
    define :create
    define :create_group
    define :add_members
    define :remove_members
    define :add_external_contact
    define :activate
    define :deactivate
  end

  postgres do
    table "contact_groups"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :group_type]
      index [:tenant_id, :is_active]
      index [:tenant_id, :created_by_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
