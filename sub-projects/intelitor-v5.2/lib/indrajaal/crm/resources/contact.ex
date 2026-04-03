defmodule Indrajaal.Crm.Contact do
  @moduledoc """
  CRM Contact resource representing individuals at companies.

  Features:
  - Contact information management
  - Account association
  - Contact roles on opportunities
  - Activity and communication tracking
  - Preferences and consent management

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

    # Personal Information
    attribute :salutation, :string do
      constraints max_length: 20
      description "Mr./Ms./Dr./Prof."
    end

    attribute :first_name, :string do
      constraints max_length: 100
      description "First name"
    end

    attribute :last_name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
      description "Last name"
    end

    attribute :middle_name, :string do
      constraints max_length: 100
      description "Middle name"
    end

    attribute :suffix, :string do
      constraints max_length: 20
      description "Jr./Sr./III"
    end

    attribute :title, :string do
      constraints max_length: 100
      description "Job title"
    end

    attribute :department, :string do
      constraints max_length: 100
      description "Department"
    end

    # Contact Information
    attribute :email, :ci_string do
      constraints max_length: 255
      description "Primary email"
    end

    attribute :secondary_email, :ci_string do
      constraints max_length: 255
      description "Secondary email"
    end

    attribute :phone, :string do
      constraints max_length: 50
      description "Business phone"
    end

    attribute :mobile, :string do
      constraints max_length: 50
      description "Mobile phone"
    end

    attribute :home_phone, :string do
      constraints max_length: 50
      description "Home phone"
    end

    attribute :assistant_name, :string do
      constraints max_length: 100
      description "Assistant's name"
    end

    attribute :assistant_phone, :string do
      constraints max_length: 50
      description "Assistant's phone"
    end

    # Address
    attribute :mailing_street, :string do
      constraints max_length: 255
    end

    attribute :mailing_city, :string do
      constraints max_length: 100
    end

    attribute :mailing_state, :string do
      constraints max_length: 100
    end

    attribute :mailing_postal_code, :string do
      constraints max_length: 20
    end

    attribute :mailing_country, :string do
      constraints max_length: 100
    end

    attribute :other_street, :string do
      constraints max_length: 255
    end

    attribute :other_city, :string do
      constraints max_length: 100
    end

    attribute :other_state, :string do
      constraints max_length: 100
    end

    attribute :other_postal_code, :string do
      constraints max_length: 20
    end

    attribute :other_country, :string do
      constraints max_length: 100
    end

    # Status and preferences
    attribute :status, :atom do
      default :active
      constraints one_of: [:active, :inactive, :deceased]
      description "Contact status"
    end

    attribute :lead_source, :atom do
      constraints one_of: [
                    :web,
                    :phone,
                    :referral,
                    :partner,
                    :trade_show,
                    :email,
                    :social,
                    :other
                  ]

      description "Original lead source"
    end

    attribute :description, :string do
      description "Notes about contact"
    end

    # Communication preferences
    attribute :email_opt_out, :boolean do
      default false
      description "Opted out of email"
    end

    attribute :do_not_call, :boolean do
      default false
      description "Do not call flag"
    end

    attribute :has_opted_out_of_fax, :boolean do
      default false
      description "Fax opt-out"
    end

    # Social media
    attribute :linkedin_url, :string do
      constraints max_length: 255
    end

    attribute :twitter_handle, :string do
      constraints max_length: 100
    end

    # Metadata
    attribute :birthdate, :date do
      description "Birthday (year optional)"
    end

    attribute :reports_to_id, :uuid do
      description "Manager/reports-to contact"
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :custom_fields, :map do
      default %{}
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :account, Indrajaal.Crm.Account do
      attribute_public? true
      description "Associated account"
    end

    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
      description "Contact owner"
    end

    belongs_to :reports_to, __MODULE__ do
      source_attribute :reports_to_id
      attribute_public? true
      description "Manager/supervisor contact"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end

    has_many :direct_reports, __MODULE__ do
      destination_attribute :reports_to_id
      description "Contacts reporting to this contact"
    end

    has_many :activities, Indrajaal.Crm.Activity
    has_many :opportunity_roles, Indrajaal.Crm.OpportunityContactRole
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :salutation,
        :first_name,
        :last_name,
        :middle_name,
        :suffix,
        :title,
        :department,
        :email,
        :secondary_email,
        :phone,
        :mobile,
        :home_phone,
        :assistant_name,
        :assistant_phone,
        :mailing_street,
        :mailing_city,
        :mailing_state,
        :mailing_postal_code,
        :mailing_country,
        :other_street,
        :other_city,
        :other_state,
        :other_postal_code,
        :other_country,
        :lead_source,
        :description,
        :email_opt_out,
        :do_not_call,
        :has_opted_out_of_fax,
        :linkedin_url,
        :twitter_handle,
        :birthdate,
        :tags,
        :custom_fields
      ]

      argument :account_id, :uuid
      argument :owner_id, :uuid
      argument :reports_to_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:reports_to_id, arg(:reports_to_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:last_name])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :salutation,
        :first_name,
        :last_name,
        :middle_name,
        :suffix,
        :title,
        :department,
        :email,
        :secondary_email,
        :phone,
        :mobile,
        :home_phone,
        :assistant_name,
        :assistant_phone,
        :mailing_street,
        :mailing_city,
        :mailing_state,
        :mailing_postal_code,
        :mailing_country,
        :other_street,
        :other_city,
        :other_state,
        :other_postal_code,
        :other_country,
        :status,
        :description,
        :email_opt_out,
        :do_not_call,
        :has_opted_out_of_fax,
        :linkedin_url,
        :twitter_handle,
        :birthdate,
        :tags,
        :custom_fields
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :assign do
      require_atomic? false
      accept []

      argument :owner_id, :uuid, allow_nil?: false

      change fn changeset, _ ->
        owner_id = Ash.Changeset.get_argument(changeset, :owner_id)
        Ash.Changeset.change_attribute(changeset, :owner_id, owner_id)
      end
    end

    update :change_account do
      require_atomic? false
      accept []

      argument :account_id, :uuid

      change fn changeset, _ ->
        account_id = Ash.Changeset.get_argument(changeset, :account_id)
        Ash.Changeset.change_attribute(changeset, :account_id, account_id)
      end
    end

    update :opt_out_email do
      require_atomic? false
      accept []

      change set_attribute(:email_opt_out, true)
    end

    update :opt_in_email do
      require_atomic? false
      accept []

      change set_attribute(:email_opt_out, false)
    end

    update :mark_deceased do
      require_atomic? false
      accept []

      change set_attribute(:status, :deceased)
    end
  end

  calculations do
    calculate :full_name, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          parts = [
            record.salutation,
            record.first_name,
            record.middle_name,
            record.last_name,
            record.suffix
          ]

          parts
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")
        end)
      end
    end

    calculate :is_active?, :boolean, expr(status == :active)
    calculate :has_account?, :boolean, expr(not is_nil(account_id))
    calculate :can_email?, :boolean, expr(not email_opt_out and not is_nil(email))
    calculate :can_call?, :boolean, expr(not do_not_call and not is_nil(phone))
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+$/) do
      where present(:email)
    end

    validate match(:secondary_email, ~r/^[^\s]+@[^\s]+$/) do
      where present(:secondary_email)
    end
  end

  policies do
    # Admins can do anything
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can manage contacts
    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read and update their contacts
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
    end

    policy action_type(:update) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :update
    define :assign, args: [:owner_id]
    define :change_account, args: [:account_id]
    define :opt_out_email
    define :opt_in_email
    define :mark_deceased
  end

  postgres do
    table "contacts"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :email], where: "email IS NOT NULL"
      index [:tenant_id, :last_name]
      index [:account_id], where: "account_id IS NOT NULL"
      index [:owner_id]
      index [:status]
      index [:reports_to_id], where: "reports_to_id IS NOT NULL"
      index [:lead_source]
      index [:created_at]
    end
  end
end
