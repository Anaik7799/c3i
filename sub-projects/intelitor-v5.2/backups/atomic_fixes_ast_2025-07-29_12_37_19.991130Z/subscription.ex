defmodule Intelitor.Billing.Subscription do
  @moduledoc """
  Represents customer subscriptions to billing plans.

  Subscriptions track the relationship between customers and their selected
  billing plans, including billing cycles, renewals, modifications, and
  lifecycle management with comprehensive status tracking and automation.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Billing,
    table: "billing_subscriptions"

  use Intelitor.Multitenancy.TenantResource

  # Aliases for cleaner code
  alias Ash.Changeset

  attributes do
    uuid_primary_key :id

    # Subscription identification
    attribute :subscription_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :customer_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :plan_id, :uuid do
      allow_nil? false
      public? true
    end

    # Subscription details
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :active,
                    :suspended,
                    :past_due,
                    :cancelled,
                    :expired,
                    :trial,
                    :paused,
                    :churned,
                    :terminated
                  ]

      default :pending
    end

    attribute :billing_status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :current,
                    :past_due,
                    :failed,
                    :retry,
                    :cancelled,
                    :suspended
                  ]

      default :current
    end

    # Subscription timeline
    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :activated_at, :utc_datetime_usec do
      public? true
    end

    attribute :trial_start, :utc_datetime_usec do
      public? true
    end

    attribute :trial_end, :utc_datetime_usec do
      public? true
    end

    attribute :current_period_start, :utc_datetime_usec do
      public? true
    end

    attribute :current_period_end, :utc_datetime_usec do
      public? true
    end

    attribute :next_billing_date, :utc_datetime_usec do
      public? true
    end

    attribute :cancelled_at, :utc_datetime_usec do
      public? true
    end

    attribute :ended_at, :utc_datetime_usec do
      public? true
    end

    # Pricing and billing
    attribute :base_amount, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :discount_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :tax_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :total_amount, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      constraints max_length: 3
      default "USD"
    end

    # Usage tracking
    attribute :usage_based_billing?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :usage_charges, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :usage_allowances, :map do
      public? true
      default %{}
    end

    attribute :usage_overages, :map do
      public? true
      default %{}
    end

    # Billing frequency and terms
    attribute :billing_frequency, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :monthly,
                    :quarterly,
                    :semi_annual,
                    :annual,
                    :biennial
                  ]

      default :monthly
    end

    attribute :billing_day, :integer do
      public? true
      constraints min: 1, max: 31
    end

    attribute :auto_renewal?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :commitment_end_date, :utc_datetime_usec do
      public? true
    end

    attribute :grace_period_days, :integer do
      public? true
      constraints min: 0, max: 90
      default 0
    end

    # Payment information
    attribute :payment_method_id, :uuid do
      public? true
    end

    attribute :payment_provider, :string do
      public? true
      constraints max_length: 50
    end

    attribute :payment_provider_subscription_id, :string do
      public? true
      constraints max_length: 100
    end

    # Customizations and modifications
    attribute :custom_pricing?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :custom_terms, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :modifications, {:array, :map} do
      public? true
      default []
    end

    attribute :addons, {:array, :map} do
      public? true
      default []
    end

    # Customer and sales information
    attribute :sales_rep_id, :uuid do
      public? true
    end

    attribute :customer_success_manager_id, :uuid do
      public? true
    end

    attribute :acquisition_source, :string do
      public? true
      constraints max_length: 100
    end

    attribute :referral_code, :string do
      public? true
      constraints max_length: 50
    end

    attribute :promotional_codes, {:array, :string} do
      public? true
      default []
    end

    # Subscription health and metrics
    attribute :health_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :engagement_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :churn_risk_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :satisfaction_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Billing and payment history
    attribute :successful_payments, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :failed_payments, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :total_paid, :decimal do
      allow_nil? false
      public? true

      constraints precision: 12,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :outstanding_balance, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2

      default 0.00
    end

    # Contract and legal
    attribute :contract_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :contract_start_date, :date do
      public? true
    end

    attribute :contract_end_date, :date do
      public? true
    end

    attribute :terms_accepted?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :terms_accepted_at, :utc_datetime_usec do
      public? true
    end

    attribute :gdpr_consent?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Renewal and cancellation
    attribute :renewal_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :cancellation_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :cancellation_feedback, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :exit_survey_completed?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Financial tracking
    attribute :lifetime_value, :decimal do
      public? true

      constraints precision: 12,
                  scale: 2,
                  min: 0
    end

    attribute :annual_contract_value, :decimal do
      public? true

      constraints precision: 12,
                  scale: 2,
                  min: 0
    end

    attribute :monthly_recurring_revenue, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    # Dunning management
    attribute :dunning_campaign_id, :uuid do
      public? true
    end

    attribute :dunning_level, :integer do
      public? true
      constraints min: 0, max: 10
      default 0
    end

    attribute :last_dunning_attempt, :utc_datetime_usec do
      public? true
    end

    attribute :dunning_paused?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Communication preferences
    attribute :billing_notifications?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :usage_alerts?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :renewal_reminders?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Metadata
    attribute :notes, :string do
      public? true
      constraints max_length: 5000
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :plan, Intelitor.Billing.Plan do
      attribute_public? true
    end

    belongs_to :customer, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :sales_rep, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :customer_success_manager, Intelitor.Accounts.User do
      attribute_public? true
    end

    has_many :invoices, Intelitor.Billing.Invoice
    has_many :payments, Intelitor.Billing.Payment
    has_many :usage_records, Intelitor.Billing.UsageRecord
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :customer_id,
        :plan_id,
        :billing_frequency,
        :billing_day,
        :auto_renewal?,
        :commitment_end_date,
        :grace_period_days,
        :payment_method_id,
        :payment_provider,
        :custom_pricing?,
        :custom_terms,
        :addons,
        :sales_rep_id,
        :customer_success_manager_id,
        :acquisition_source,
        :referral_code,
        :promotional_codes,
        :contract_number,
        :contract_start_date,
        :contract_end_date,
        :billing_notifications?,
        :usage_alerts?,
        :renewal_reminders?,
        :notes,
        :metadata
      ]

      change fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> generate_subscription_number()
        |> Changeset.force_change_attribute(:started_at, now)
        |> Changeset.force_change_attribute(:status, :pending)
        |> Changeset.force_change_attribute(:billing_status, :current)
        |> calculate_pricing()
      end
    end


    update :activate do
      require_atomic? false
      accept [
        :status,
        :activated_at,
        :current_period_start,
        :current_period_end,
        :next_billing_date
      ]

      validate attribute_equals(:status, :pending)

      change fn changeset, _context ->
        now = DateTime.utc_now()
        plan = Changeset.get_attribute(changeset, :plan)

        frequency =
          Changeset.get_attribute(changeset, :billing_frequency)

        {period_end, next_billing} = calculate_billing_dates(now, frequency)

        changeset
        |> Changeset.force_change_attribute(:status, :active)
        |> Changeset.force_change_attribute(:activated_at, now)
        |> Changeset.force_change_attribute(:current_period_start, now)
        |> Changeset.force_change_attribute(:current_period_end, period_end)
        |> Changeset.force_change_attribute(:next_billing_date, next_billing)
      end
    end

    update :start_trial do
      require_atomic? false
      
      
      accept [:status, :trial_start, :trial_end, :next_billing_date]

      validate attribute_equals(:status, :pending)

      change fn changeset, _context ->
        now = DateTime.utc_now()
        plan = Changeset.get_attribute(changeset, :plan)
        trial_days = (plan && plan.trial_duration_days) || 14

        trial_end = DateTime.add(now, trial_days * 24 * 60 * 60, :second)

        changeset
        |> Changeset.force_change_attribute(:status, :trial)
        |> Changeset.force_change_attribute(:trial_start, now)
        |> Changeset.force_change_attribute(:trial_end, trial_end)
        |> Changeset.force_change_attribute(:next_billing_date, trial_end)
      end
    end

    update :suspend do
      require_atomic? false
      
      
      accept [:status]

      validate attribute_in(:status, [:active, :past_due])

      change set_attribute(:status, :suspended)
    end

    update :resume do
      require_atomic? false
      
      
      accept [:status]

      validate attribute_equals(:status, :suspended)

      change set_attribute(:status, :active)
    end

    update :cancel do
      require_atomic? false
      accept [
        :status,
        :cancelled_at,
        :cancellation_reason,
        :cancellation_feedback
      ]

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :feedback, :string do
        constraints max_length: 2000
      end

      argument :immediate?, :boolean do
        default false
      end

      validate attribute_in(:status, [:active, :trial, :past_due, :suspended])

      change fn changeset, _context ->
        now = DateTime.utc_now()
        immediate = changeset.arguments.immediate?

        end_date =
          if immediate do
            now
          else
            Changeset.get_attribute(changeset, :current_period_end) || now
          end

        changeset
        |> Changeset.force_change_attribute(:status, :cancelled)
        |> Changeset.force_change_attribute(:cancelled_at, now)
        |> Changeset.force_change_attribute(:ended_at, end_date)
        |> Changeset.force_change_attribute(
          :cancellation_reason,
          changeset.arguments.reason
        )
        |> then(fn cs ->
          if feedback = changeset.arguments.feedback do
            Changeset.force_change_attribute(
              cs,
              :cancellation_feedback,
              feedback
            )
          else
            cs
          end
        end)
      end
    end

    update :renew do
      require_atomic? false
      
      
      accept [
        :current_period_start,
        :current_period_end,
        :next_billing_date,
        :renewal_count
      ]

      validate attribute_equals(:status, :active)

      change fn changeset, _context ->
        now = DateTime.utc_now()

        frequency =
          Changeset.get_attribute(changeset, :billing_frequency)

        current_renewals =
          Changeset.get_attribute(changeset, :renewal_count)

        {period_end, next_billing} = calculate_billing_dates(now, frequency)

        changeset
        |> Changeset.force_change_attribute(:current_period_start, now)
        |> Changeset.force_change_attribute(:current_period_end, period_end)
        |> Changeset.force_change_attribute(:next_billing_date, next_billing)
        |> Changeset.force_change_attribute(
          :renewal_count,
          current_renewals + 1
        )
      end
    end

    update :update_billing_status do
      require_atomic? false
      
      
      accept [:billing_status]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :current,
                      :past_due,
                      :failed,
                      :retry,
                      :cancelled,
                      :suspended
                    ]
      end

      change fn changeset, _context ->
        Changeset.force_change_attribute(
          changeset,
          :billing_status,
          changeset.arguments.status
        )
      end
    end

    update :record_payment do
      require_atomic? false
      
      
      accept [
        :successful_payments,
        :failed_payments,
        :total_paid,
        :outstanding_balance
      ]

      argument :payment_successful?, :boolean do
        allow_nil? false
      end

      argument :amount, :decimal do
        allow_nil? false

        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      change fn changeset, _context ->
        successful = changeset.arguments.payment_successful?
        amount = changeset.arguments.amount

        current_successful =
          Changeset.get_attribute(changeset, :successful_payments)

        current_failed =
          Changeset.get_attribute(changeset, :failed_payments)

        current_total =
          Changeset.get_attribute(changeset, :total_paid)

        current_balance =
          Changeset.get_attribute(changeset, :outstanding_balance)

        changeset =
          if successful do
            changeset
            |> Changeset.force_change_attribute(
              :successful_payments,
              current_successful + 1
            )
            |> Changeset.force_change_attribute(
              :total_paid,
              Decimal.add(current_total, amount)
            )
            |> Changeset.force_change_attribute(
              :outstanding_balance,
              Decimal.sub(current_balance, amount)
            )
          else
            Changeset.force_change_attribute(
              changeset,
              :failed_payments,
              current_failed + 1
            )
          end

        changeset
      end
    end

    update :update_usage_charges do
      require_atomic? false
      accept [:usage_charges, :usage_overages]

      argument :charges, :decimal do
        allow_nil? false

        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      argument :overages, :map do
        default %{}
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_active?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn subscription ->
            subscription.status in [:active, :trial]
          end)

        {:ok, values}
      end
    end

    calculate :days_until_renewal, :integer do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        values =
          Enum.map(records, fn subscription ->
            if subscription.next_billing_date do
              DateTime.diff(subscription.next_billing_date, now, :day)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :subscription_age_days, :integer do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        values =
          Enum.map(records, fn subscription ->
            DateTime.diff(now, subscription.started_at, :day)
          end)

        {:ok, values}
      end
    end

    calculate :payment_success_rate, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn subscription ->
            total_payments =
              subscription.successful_payments + subscription.failed_payments

            if total_payments > 0 do
              subscription.successful_payments
              |> Decimal.div(total_payments)
              |> Decimal.mult(100)
            else
              Decimal.new(100)
            end
          end)

        {:ok, values}
      end
    end

    calculate :net_amount, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn subscription ->
            Decimal.sub(subscription.base_amount, subscription.discount_amount)
            |> Decimal.add(subscription.tax_amount)
            |> Decimal.add(subscription.usage_charges)
          end)

        {:ok, values}
      end
    end

    calculate :is_overdue?, :boolean do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        values =
          Enum.map(records, fn subscription ->
            subscription.billing_status == :past_due &&
              subscription.next_billing_date &&
              DateTime.compare(now, subscription.next_billing_date) == :gt
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      authorize_if actor_attribute_equals(:role, "customer_service")
      authorize_if actor_attribute_equals(:role, "sales")
      # Customers can read their own subscriptions
      authorize_if expr(customer_id == ^actor(:id))
      # Sales reps can read their customer subscriptions
      authorize_if expr(sales_rep_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      authorize_if actor_attribute_equals(:role, "sales")
    end

    policy action([
             :activate,
             :start_trial,
             :suspend,
             :resume,
             :cancel,
             :renew
           ]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      authorize_if actor_attribute_equals(:role, "customer_service")
      # Customer can cancel their own subscription
      authorize_if expr(action == :cancel and customer_id == ^actor(:id))
    end

    policy action([
             :update_billing_status,
             :record_payment,
             :update_usage_charges
           ]) do
      # System can update billing status and payments
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :start_trial
    define :suspend
    define :resume
    define :cancel
    define :renew
    define :update_billing_status
    define :record_payment
    define :update_usage_charges
    define :destroy
  end

  postgres do
    table "billing_subscriptions"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :subscription_number], unique: true
      index [:customer_id]
      index [:plan_id]
      index [:sales_rep_id], where: "sales_rep_id IS NOT NULL"

      index [:customer_success_manager_id],
        where: "customer_success_manager_id IS NOT NULL"

      index [:status]
      index [:billing_status]
      index [:started_at]
      index [:activated_at], where: "activated_at IS NOT NULL"
      index [:trial_start], where: "trial_start IS NOT NULL"
      index [:trial_end], where: "trial_end IS NOT NULL"
      index [:current_period_end], where: "current_period_end IS NOT NULL"
      index [:next_billing_date], where: "next_billing_date IS NOT NULL"
      index [:cancelled_at], where: "cancelled_at IS NOT NULL"

      index [:auto_renewal?],
        name: "subscriptions_auto_renewal_index",
        where: "auto_renewal? = true"

      index [:usage_based_billing?],
        name: "subscriptions_usage_based_index",
        where: "usage_based_billing? = true"

      index [:commitment_end_date], where: "commitment_end_date IS NOT NULL"
      index [:contract_number], where: "contract_number IS NOT NULL"
      index [:acquisition_source], where: "acquisition_source IS NOT NULL"
      index [:outstanding_balance], where: "outstanding_balance != 0"
    end
  end

  # Helper functions
  defp generate_subscription_number(changeset) do
    # Generate subscription number like SUB-20251206-001
    date_str =
      Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    subscription_number = "SUB-#{date_str}-#{random_suffix}"

    Changeset.force_change_attribute(
      changeset,
      :subscription_number,
      subscription_number
    )
  end

  defp calculate_pricing(changeset) do
    plan = Changeset.get_attribute(changeset, :plan)

    if plan do
      base_amount = plan.base_price
      # Future implementation: Calculate discounts and taxes based on plan
      discount_amount = Decimal.new(0)
      tax_amount = Decimal.new(0)

      total_amount =
        base_amount
        |> Decimal.sub(discount_amount)
        |> Decimal.add(tax_amount)

      changeset
      |> Changeset.force_change_attribute(:base_amount, base_amount)
      |> Changeset.force_change_attribute(:discount_amount, discount_amount)
      |> Changeset.force_change_attribute(:tax_amount, tax_amount)
      |> Changeset.force_change_attribute(:total_amount, total_amount)
      |> Changeset.force_change_attribute(:currency, plan.currency)
    else
      changeset
    end
  end

  defp calculate_billing_dates(start_date, frequency) do
    days = billing_frequency_to_days(frequency)
    seconds = days * 24 * 60 * 60
    period_end = DateTime.add(start_date, seconds, :second)
    {period_end, period_end}
  end

  defp billing_frequency_to_days(frequency) do
    case frequency do
      :monthly -> 30
      :quarterly -> 90
      :semi_annual -> 180
      :annual -> 365
      :biennial -> 730
      _ -> 30
    end
  end
end
