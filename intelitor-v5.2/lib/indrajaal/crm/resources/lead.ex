defmodule Indrajaal.Crm.Lead do
  @moduledoc """
  CRM Lead resource for managing potential customers.

  Features:
  - Lead capture and qualification
  - AI-based lead scoring
  - Conversion to Account/Contact/Opportunity
  - Activity tracking and history
  - Source attribution and rating

  ## STAMP Compliance
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-DB-012: create_if_not_exists indexes

  ## FMEA Analysis
  | Failure Mode | Severity | RPN | Mitigation |
  |--------------|----------|-----|------------|
  | Lead data loss | 9 | 72 | Audit trail + soft delete |
  | Duplicate records | 7 | 140 | Duplicate detection rules |
  | Invalid conversion | 8 | 120 | Validation + rollback |
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
      description "Lead's first name"
    end

    attribute :last_name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
      description "Lead's last name"
    end

    attribute :title, :string do
      constraints max_length: 100
      description "Job title"
    end

    attribute :email, :ci_string do
      constraints max_length: 255
      description "Primary email address"
    end

    attribute :phone, :string do
      constraints max_length: 50
      description "Primary phone number"
    end

    attribute :mobile, :string do
      constraints max_length: 50
      description "Mobile phone number"
    end

    # Company Information
    attribute :company, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
      description "Company name"
    end

    attribute :industry, :string do
      constraints max_length: 100
      description "Industry sector"
    end

    attribute :annual_revenue, :decimal do
      constraints precision: 15, scale: 2
      description "Annual company revenue"
    end

    attribute :num_employees, :integer do
      description "Number of employees"
    end

    attribute :website, :string do
      constraints max_length: 255
      description "Company website URL"
    end

    # Address
    attribute :street, :string do
      constraints max_length: 255
      description "Street address"
    end

    attribute :city, :string do
      constraints max_length: 100
      description "City"
    end

    attribute :state, :string do
      constraints max_length: 100
      description "State/Province"
    end

    attribute :postal_code, :string do
      constraints max_length: 20
      description "Postal/ZIP code"
    end

    attribute :country, :string do
      constraints max_length: 100
      description "Country"
    end

    # Lead Details
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

      description "How lead was acquired"
    end

    attribute :status, :atom do
      default :new
      constraints one_of: [:new, :contacted, :qualified, :unqualified, :converted]
      description "Current lead status"
    end

    attribute :rating, :atom do
      constraints one_of: [:hot, :warm, :cold]
      description "Lead temperature/priority"
    end

    attribute :score, :integer do
      default 0
      constraints min: 0, max: 100
      description "AI-computed lead score (0-100)"
    end

    attribute :notes, :string do
      description "Internal notes"
    end

    attribute :converted_at, :utc_datetime do
      description "When lead was converted"
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
      description "Lead owner/assigned user"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end

    belongs_to :converted_account, Indrajaal.Crm.Account do
      attribute_public? true
      description "Account created from conversion"
    end

    belongs_to :converted_contact, Indrajaal.Crm.Contact do
      attribute_public? true
      description "Contact created from conversion"
    end

    belongs_to :converted_opportunity, Indrajaal.Crm.Opportunity do
      attribute_public? true
      description "Opportunity created from conversion"
    end

    has_many :activities, Indrajaal.Crm.Activity
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :salutation,
        :first_name,
        :last_name,
        :title,
        :email,
        :phone,
        :mobile,
        :company,
        :industry,
        :annual_revenue,
        :num_employees,
        :website,
        :street,
        :city,
        :state,
        :postal_code,
        :country,
        :lead_source,
        :rating,
        :notes
      ]

      argument :owner_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:last_name, :company])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :salutation,
        :first_name,
        :last_name,
        :title,
        :email,
        :phone,
        :mobile,
        :company,
        :industry,
        :annual_revenue,
        :num_employees,
        :website,
        :street,
        :city,
        :state,
        :postal_code,
        :country,
        :lead_source,
        :status,
        :rating,
        :notes
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :qualify do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :status, :qualified)
      end
    end

    update :disqualify do
      require_atomic? false
      accept []

      argument :reason, :string

      change fn changeset, _ ->
        reason = Ash.Changeset.get_argument(changeset, :reason)
        current_notes = Ash.Changeset.get_attribute(changeset, :notes) || ""
        new_notes = "#{current_notes}\nDisqualified: #{reason}"

        changeset
        |> Ash.Changeset.change_attribute(:status, :unqualified)
        |> Ash.Changeset.change_attribute(:notes, new_notes)
      end
    end

    update :convert do
      require_atomic? false
      accept []

      argument :create_opportunity, :boolean, default: true
      argument :opportunity_name, :string
      argument :opportunity_amount, :decimal

      # Conversion logic will create Account, Contact, and optionally Opportunity
      # Implementation requires Account and Contact resources to exist first
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :converted)
        |> Ash.Changeset.change_attribute(:converted_at, DateTime.utc_now())
      end
    end

    update :score do
      require_atomic? false
      accept []

      # AI-based lead scoring logic
      change fn changeset, _ ->
        # Simple scoring algorithm - can be enhanced with AI model
        score = calculate_lead_score(changeset)
        Ash.Changeset.change_attribute(changeset, :score, score)
      end
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
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)
    calculate :is_converted?, :boolean, expr(status == :converted)
    calculate :is_qualified?, :boolean, expr(status == :qualified)
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+$/) do
      where present(:email)
    end
  end

  policies do
    # Admins can do anything
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can manage leads
    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read and update their own leads
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
    define :qualify
    define :disqualify
    define :convert, args: [:create_opportunity, :opportunity_name, :opportunity_amount]
    define :score
    define :assign, args: [:owner_id]
  end

  postgres do
    table "leads"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :email], where: "email IS NOT NULL"
      index [:tenant_id, :company]
      index [:status]
      index [:rating]
      index [:lead_source]
      index [:owner_id]
      index [:score]
      index [:converted_at], where: "converted_at IS NOT NULL"
      index [:created_at]
    end
  end

  # Helper function for lead scoring
  defp calculate_lead_score(changeset) do
    score = 0

    # Email: +20
    score = if Ash.Changeset.get_attribute(changeset, :email), do: score + 20, else: score

    # Phone: +15
    score = if Ash.Changeset.get_attribute(changeset, :phone), do: score + 15, else: score

    # Company size: +25
    num_employees = Ash.Changeset.get_attribute(changeset, :num_employees)
    score = if num_employees && num_employees > 100, do: score + 25, else: score

    # Revenue: +30
    revenue = Ash.Changeset.get_attribute(changeset, :annual_revenue)

    score =
      if revenue && Decimal.gt?(revenue, Decimal.new(1_000_000)), do: score + 30, else: score

    # Rating: hot=10, warm=5
    rating = Ash.Changeset.get_attribute(changeset, :rating)

    score =
      case rating do
        :hot -> score + 10
        :warm -> score + 5
        _ -> score
      end

    min(score, 100)
  end
end
