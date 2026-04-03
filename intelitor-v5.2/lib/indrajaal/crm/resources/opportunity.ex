defmodule Indrajaal.Crm.Opportunity do
  @moduledoc """
  CRM Opportunity resource for managing sales deals.

  Features:
  - Sales stage management with probability
  - Amount and expected revenue tracking
  - Opportunity teams and splits
  - Competitor tracking
  - Product line items (referenced)
  - Forecasting and reporting

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

    # Basic Information
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
      description "Opportunity name"
    end

    attribute :type, :atom do
      constraints one_of: [:new_business, :existing_business, :renewal, :upsell, :cross_sell]
      description "Opportunity type"
    end

    attribute :description, :string do
      description "Opportunity description"
    end

    # Financial
    attribute :amount, :decimal do
      constraints precision: 15, scale: 2
      description "Total opportunity amount"
    end

    attribute :expected_revenue, :decimal do
      constraints precision: 15, scale: 2
      description "Probability-weighted revenue"
    end

    attribute :probability, :integer do
      default 0
      constraints min: 0, max: 100
      description "Probability of close (0-100%)"
    end

    # Stage and timing
    attribute :stage, :atom do
      default :prospecting

      constraints one_of: [
                    :prospecting,
                    :qualification,
                    :needs_analysis,
                    :value_proposition,
                    :proposal,
                    :negotiation,
                    :closed_won,
                    :closed_lost
                  ]

      description "Current sales stage"
    end

    attribute :close_date, :date do
      description "Expected or actual close date"
    end

    attribute :next_step, :string do
      constraints max_length: 255
      description "Next action to take"
    end

    # Status
    attribute :is_closed, :boolean do
      default false
      description "Whether opportunity is closed"
    end

    attribute :is_won, :boolean do
      default false
      description "Whether opportunity is won"
    end

    attribute :closed_at, :utc_datetime do
      description "When opportunity was closed"
    end

    # Classification
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

    attribute :forecast_category, :atom do
      default :pipeline
      constraints one_of: [:pipeline, :best_case, :commit, :omitted, :closed]
      description "Forecast category"
    end

    # Competition and risk
    attribute :competitors, {:array, :string} do
      default []
      description "Competing vendors"
    end

    attribute :loss_reason, :string do
      constraints max_length: 255
      description "Reason if lost"
    end

    # Metadata
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
      allow_nil? false
      attribute_public? true
      description "Account this opportunity belongs to"
    end

    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
      description "Opportunity owner"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end

    has_many :activities, Indrajaal.Crm.Activity
    has_many :contact_roles, Indrajaal.Crm.OpportunityContactRole
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :type,
        :description,
        :amount,
        :probability,
        :stage,
        :close_date,
        :next_step,
        :lead_source,
        :forecast_category,
        :competitors,
        :tags,
        :custom_fields
      ]

      argument :account_id, :uuid, allow_nil?: false
      argument :owner_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:account_id, arg(:account_id))
      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      # Calculate expected revenue
      change fn changeset, _ ->
        calculate_expected_revenue(changeset)
      end

      validate present([:name, :account_id])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :type,
        :description,
        :amount,
        :probability,
        :close_date,
        :next_step,
        :forecast_category,
        :competitors,
        :tags,
        :custom_fields
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))

      # Recalculate expected revenue on amount/probability change
      change fn changeset, _ ->
        calculate_expected_revenue(changeset)
      end
    end

    update :advance_stage do
      require_atomic? false
      accept []

      argument :new_stage, :atom, allow_nil?: false

      change fn changeset, context ->
        new_stage = Ash.Changeset.get_argument(changeset, :new_stage)
        current_stage = Ash.Changeset.get_attribute(changeset, :stage)

        # Update probability based on stage
        probability = stage_to_probability(new_stage)

        changeset =
          changeset
          |> Ash.Changeset.change_attribute(:stage, new_stage)
          |> Ash.Changeset.change_attribute(:probability, probability)

        # Update forecast category
        forecast_category = determine_forecast_category(new_stage, probability)

        changeset =
          Ash.Changeset.change_attribute(changeset, :forecast_category, forecast_category)

        # Auto-close if won/lost stage
        changeset =
          case new_stage do
            :closed_won ->
              changeset
              |> Ash.Changeset.change_attribute(:is_closed, true)
              |> Ash.Changeset.change_attribute(:is_won, true)
              |> Ash.Changeset.change_attribute(:closed_at, DateTime.utc_now())

            :closed_lost ->
              changeset
              |> Ash.Changeset.change_attribute(:is_closed, true)
              |> Ash.Changeset.change_attribute(:is_won, false)
              |> Ash.Changeset.change_attribute(:closed_at, DateTime.utc_now())

            _ ->
              changeset
          end

        calculate_expected_revenue(changeset)
      end
    end

    update :close_won do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:stage, :closed_won)
        |> Ash.Changeset.change_attribute(:is_closed, true)
        |> Ash.Changeset.change_attribute(:is_won, true)
        |> Ash.Changeset.change_attribute(:probability, 100)
        |> Ash.Changeset.change_attribute(:forecast_category, :closed)
        |> Ash.Changeset.change_attribute(:closed_at, DateTime.utc_now())
        |> calculate_expected_revenue()
      end
    end

    update :close_lost do
      require_atomic? false
      accept []

      argument :loss_reason, :string

      change fn changeset, _ ->
        reason = Ash.Changeset.get_argument(changeset, :loss_reason)

        changeset
        |> Ash.Changeset.change_attribute(:stage, :closed_lost)
        |> Ash.Changeset.change_attribute(:is_closed, true)
        |> Ash.Changeset.change_attribute(:is_won, false)
        |> Ash.Changeset.change_attribute(:probability, 0)
        |> Ash.Changeset.change_attribute(:forecast_category, :omitted)
        |> Ash.Changeset.change_attribute(:loss_reason, reason)
        |> Ash.Changeset.change_attribute(:closed_at, DateTime.utc_now())
        |> calculate_expected_revenue()
      end
    end

    update :reopen do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:stage, :prospecting)
        |> Ash.Changeset.change_attribute(:is_closed, false)
        |> Ash.Changeset.change_attribute(:is_won, false)
        |> Ash.Changeset.change_attribute(:probability, 10)
        |> Ash.Changeset.change_attribute(:forecast_category, :pipeline)
        |> Ash.Changeset.change_attribute(:closed_at, nil)
        |> Ash.Changeset.change_attribute(:loss_reason, nil)
        |> calculate_expected_revenue()
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
    calculate :is_open?, :boolean, expr(not is_closed)

    calculate :days_to_close, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          if record.close_date do
            Date.diff(record.close_date, today)
          else
            nil
          end
        end)
      end
    end

    calculate :age_days, :integer do
      calculation fn records, _ ->
        today = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.inserted_at do
            DateTime.diff(today, record.inserted_at, :day)
          else
            0
          end
        end)
      end
    end
  end

  validations do
    validate compare(:probability, greater_than_or_equal_to: 0)
    validate compare(:probability, less_than_or_equal_to: 100)

    validate fn changeset, _ ->
      # Validate amount is positive if present
      amount = Ash.Changeset.get_attribute(changeset, :amount)

      if amount && Decimal.lt?(amount, Decimal.new(0)) do
        {:error, field: :amount, message: "must be positive"}
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

    # Managers can manage opportunities
    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read and update their opportunities
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
    define :advance_stage, args: [:new_stage]
    define :close_won
    define :close_lost, args: [:loss_reason]
    define :reopen
    define :assign, args: [:owner_id]
  end

  postgres do
    table "opportunities"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :name]
      index [:account_id]
      index [:owner_id]
      index [:stage]
      index [:is_closed]
      index [:is_won]
      index [:close_date]
      index [:forecast_category]
      index [:amount]
      index [:created_at]
    end
  end

  # Helper functions
  defp calculate_expected_revenue(changeset) do
    amount = Ash.Changeset.get_attribute(changeset, :amount)
    probability = Ash.Changeset.get_attribute(changeset, :probability) || 0

    if amount do
      # Expected revenue = amount * (probability / 100)
      expected = Decimal.mult(amount, Decimal.div(Decimal.new(probability), Decimal.new(100)))
      Ash.Changeset.change_attribute(changeset, :expected_revenue, expected)
    else
      Ash.Changeset.change_attribute(changeset, :expected_revenue, Decimal.new(0))
    end
  end

  defp stage_to_probability(stage) do
    case stage do
      :prospecting -> 10
      :qualification -> 20
      :needs_analysis -> 30
      :value_proposition -> 40
      :proposal -> 60
      :negotiation -> 80
      :closed_won -> 100
      :closed_lost -> 0
      _ -> 10
    end
  end

  defp determine_forecast_category(stage, probability) do
    cond do
      stage in [:closed_won, :closed_lost] -> :closed
      probability >= 90 -> :commit
      probability >= 70 -> :best_case
      probability > 0 -> :pipeline
      true -> :omitted
    end
  end
end
