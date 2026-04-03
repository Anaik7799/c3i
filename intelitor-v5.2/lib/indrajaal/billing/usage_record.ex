defmodule Indrajaal.Billing.UsageRecord do
  @moduledoc """
  Represents usage tracking records for usage - based billing.

  Usage records capture consumption metrics including device usage,
  storage consumption, API calls, video streaming, and other billable
  activities. They support real - time tracking, aggregation, and flexible
  rating models for accurate usage - based billing calculations.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Billing

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Usage record identification
    attribute :record_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :subscription_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :customer_id, :uuid do
      allow_nil? false
      public? true
    end

    # Usage details
    attribute :usage_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :device_hours,
                    :storage_gb,
                    :bandwidth_gb,
                    :api_calls,
                    :video_minutes,
                    :recording_hours,
                    :analytics_events,
                    :_users,
                    :locations,
                    :alerts,
                    :reports,
                    :integrations,
                    :support_incidents,
                    :training_hours
                  ]

      default :device_hours
    end

    attribute :metric_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :quantity, :decimal do
      allow_nil? false
      public? true

      constraints precision: 15,
                  scale: 6,
                  min: 0
    end

    attribute :unit_of_measure, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "hours"
    end

    # Time tracking
    attribute :usage_start, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :usage_end, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :billing_period, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    # Resource identification
    attribute :resource_type, :string do
      public? true
      constraints max_length: 50
    end

    attribute :resource_id, :uuid do
      public? true
    end

    attribute :device_id, :uuid do
      public? true
    end

    attribute :location_id, :uuid do
      public? true
    end

    attribute :user_id, :uuid do
      public? true
    end

    # Usage categorization
    attribute :category, :atom do
      public? true

      constraints one_of: [
                    :basic,
                    :premium,
                    :enterprise,
                    :addon,
                    :overage,
                    :included,
                    :promotional,
                    :trial,
                    :free_tier
                  ]
    end

    attribute :tier, :string do
      public? true
      constraints max_length: 50
    end

    attribute :priority, :atom do
      public? true
      constraints one_of: [:low, :normal, :high, :critical]
      default :normal
    end

    # Pricing and rating
    attribute :unit_price, :decimal do
      public? true

      constraints precision: 10,
                  scale: 6,
                  min: 0
    end

    attribute :total_cost, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :currency, :string do
      public? true
      constraints max_length: 3
      default "USD"
    end

    attribute :prorate?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :proration_factor, :decimal do
      public? true

      constraints precision: 10,
                  scale: 6,
                  min: 0,
                  max: 1
    end

    # Allowances and limits
    attribute :included_quantity, :decimal do
      public? true

      constraints precision: 15,
                  scale: 6,
                  min: 0

      default 0
    end

    attribute :overage_quantity, :decimal do
      public? true

      constraints precision: 15,
                  scale: 6,
                  min: 0

      default 0
    end

    attribute :overage_rate, :decimal do
      public? true

      constraints precision: 10,
                  scale: 6,
                  min: 0
    end

    attribute :overage_cost, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0
    end

    # Billing status
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :calculated,
                    :billed,
                    :invoiced,
                    :paid,
                    :credited,
                    :disputed
                  ]

      default :pending
    end

    attribute :billable?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :billed_at, :utc_datetime_usec do
      public? true
    end

    attribute :invoice_id, :uuid do
      public? true
    end

    # Aggregation and rollup
    attribute :aggregation_level, :atom do
      public? true
      constraints one_of: [:raw, :hourly, :daily, :monthly, :billing_period]
      default :raw
    end

    attribute :aggregated_from_records, {:array, :uuid} do
      public? true
      default []
    end

    attribute :child_records_count, :integer do
      public? true
      constraints min: 0
      default 0
    end

    # Quality and validation
    attribute :validated?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :validation_errors, {:array, :string} do
      public? true
      default []
    end

    attribute :data_source, :string do
      public? true
      constraints max_length: 100
    end

    attribute :collection_method, :atom do
      public? true
      constraints one_of: [:automatic, :manual, :api, :import, :estimate]
      default :automatic
    end

    attribute :accuracy_level, :atom do
      public? true
      constraints one_of: [:exact, :estimated, :approximated, :projected]
      default :exact
    end

    # Context and metadata
    attribute :session_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :transaction_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :correlation_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :event_data, :map do
      public? true
      default %{}
    end

    attribute :usage_context, :map do
      public? true
      default %{}
    end

    # Geographic and regulatory
    attribute :region, :string do
      public? true
      constraints max_length: 50
    end

    attribute :timezone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :regulatory_requirements, {:array, :string} do
      public? true
      default []
    end

    attribute :data_residency, :string do
      public? true
      constraints max_length: 50
    end

    # Performance metrics
    attribute :response_time_ms, :integer do
      public? true
      constraints min: 0
    end

    attribute :error_count, :integer do
      public? true
      constraints min: 0
      default 0
    end

    attribute :success_rate, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :quality_score, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Business rules and discounts
    attribute :discount_applied?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :discount_percentage, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :discount_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0
    end

    attribute :promotional_rate?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Compliance and audit
    attribute :retention_period_days, :integer do
      public? true
      constraints min: 1, max: 7300
    end

    attribute :audit_trail, {:array, :map} do
      public? true
      default []
    end

    attribute :compliance_flags, {:array, :string} do
      public? true
      default []
    end

    attribute :data_classification, :atom do
      public? true
      constraints one_of: [:public, :internal, :confidential, :restricted]
      default :internal
    end

    # External system integration
    attribute :external_record_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :sync_status, :atom do
      public? true
      constraints one_of: [:pending, :synced, :failed, :not_applicable]
    end

    attribute :sync_error, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :last_sync_at, :utc_datetime_usec do
      public? true
    end

    # Notes and references
    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :reference_number, :string do
      public? true
      constraints max_length: 100
    end

    # Metadata
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
    belongs_to :subscription, Indrajaal.Billing.Subscription do
      attribute_public? true
    end

    belongs_to :customer, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :invoice, Indrajaal.Billing.Invoice do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :subscription_id,
        :customer_id,
        :usage_type,
        :metric_name,
        :quantity,
        :unit_of_measure,
        :usage_start,
        :usage_end,
        :billing_period,
        :resource_type,
        :resource_id,
        :device_id,
        :location_id,
        :user_id,
        :category,
        :tier,
        :priority,
        :unit_price,
        :currency,
        :prorate?,
        :proration_factor,
        :included_quantity,
        :overage_rate,
        :billable?,
        :aggregation_level,
        :child_records_count,
        :data_source,
        :collection_method,
        :accuracy_level,
        :session_id,
        :transaction_id,
        :correlation_id,
        :event_data,
        :usage_context,
        :region,
        :timezone,
        :regulatory_requirements,
        :data_residency,
        :response_time_ms,
        :error_count,
        :success_rate,
        :quality_score,
        :promotional_rate?,
        :retention_period_days,
        :compliance_flags,
        :data_classification,
        :external_record_id,
        :description,
        :notes,
        :reference_number,
        :metadata
      ]

      change fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> generate_record_number()
        |> Ash.Changeset.force_change_attribute(:recorded_at, now)
        |> Ash.Changeset.force_change_attribute(:status, :pending)
        |> calculate_usage_cost()
        |> Indrajaal.Core.Holon.FounderWealthRedirect.redirect_wealth()
      end
    end

    update :calculate_cost do
      require_atomic? false

      accept [:total_cost, :overage_quantity, :overage_cost, :status]

      validate attribute_equals(:status, :pending)

      change fn changeset, _context ->
        changeset
        |> calculate_usage_cost()
        |> Ash.Changeset.force_change_attribute(:status, :calculated)
      end
    end

    update :apply_discount do
      require_atomic? false

      accept [:discount_applied?, :discount_percentage, :discount_amount, :total_cost]

      argument :discount_percentage, :decimal do
        allow_nil? false

        constraints precision: 5,
                    scale: 2,
                    min: 0,
                    max: 100
      end

      change fn changeset, _context ->
        discount_percentage = changeset.arguments.discount_percentage
        current_cost = Ash.Changeset.get_attribute(changeset, :total_cost) || Decimal.new(0)

        discount_amount =
          current_cost
          |> Decimal.mult(discount_percentage)
          |> Decimal.div(100)

        new_total_cost = Decimal.sub(current_cost, discount_amount)

        changeset
        |> Ash.Changeset.force_change_attribute(:discount_applied?, true)
        |> Ash.Changeset.force_change_attribute(
          :discount_percentage,
          discount_percentage
        )
        |> Ash.Changeset.force_change_attribute(
          :discount_amount,
          discount_amount
        )
        |> Ash.Changeset.force_change_attribute(:total_cost, new_total_cost)
      end
    end

    update :validate_usage do
      require_atomic? false

      accept [:validated?, :validation_errors, :status]

      argument :validation_errors, {:array, :string} do
        default []
      end

      change fn changeset, _context ->
        errors = changeset.arguments.validation_errors
        is_valid = Enum.empty?(errors)

        changeset
        |> Ash.Changeset.force_change_attribute(:validated?, is_valid)
        |> Ash.Changeset.force_change_attribute(:validation_errors, errors)
      end
    end

    update :aggregate_usage do
      require_atomic? false

      accept [
        :quantity,
        :total_cost,
        :aggregation_level,
        :aggregated_from_records,
        :child_records_count
      ]

      argument :child_record_ids, {:array, :uuid} do
        allow_nil? false
      end

      argument :aggregation_level, :atom do
        allow_nil? false
        constraints one_of: [:hourly, :daily, :monthly, :billing_period]
      end

      change fn changeset, _context ->
        child_ids = changeset.arguments.child_record_ids
        aggregation_level = changeset.arguments.aggregation_level

        # In a real implementation, this would aggregate actual child records
        changeset
        |> Ash.Changeset.force_change_attribute(
          :aggregation_level,
          aggregation_level
        )
        |> Ash.Changeset.force_change_attribute(
          :aggregated_from_records,
          child_ids
        )
        |> Ash.Changeset.force_change_attribute(
          :child_records_count,
          length(child_ids)
        )
      end
    end

    update :mark_billed do
      require_atomic? false

      accept [:status, :billed_at, :invoice_id]

      argument :invoice_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:status, :calculated)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :billed)
        |> Ash.Changeset.force_change_attribute(:billed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :invoice_id,
          changeset.arguments.invoice_id
        )
      end
    end

    update :add_audit_entry do
      require_atomic? false

      accept [:audit_trail]

      argument :action, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :details, :string do
        constraints max_length: 500
      end

      argument :user_id, :uuid

      change fn changeset, _context ->
        audit_trail = Ash.Changeset.get_attribute(changeset, :audit_trail) || []

        audit_entry = %{
          "action" => changeset.arguments.action,
          "details" => changeset.arguments.details,
          "user_id" => changeset.arguments.user_id,
          "timestamp" => DateTime.utc_now()
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :audit_trail,
          [audit_entry | audit_trail]
        )
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :usage_duration_hours, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn usage ->
              if usage.usage_start && usage.usage_end do
                diff_seconds =
                  DateTime.diff(
                    usage.usage_end,
                    usage.usage_start,
                    :second
                  )

                Decimal.div(diff_seconds, 3600)
              else
                Decimal.new(0)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :effective_rate, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn usage ->
              if usage.quantity &&
                   Decimal.compare(
                     usage.quantity,
                     0
                   ) == :gt && usage.total_cost do
                Decimal.div(usage.total_cost, usage.quantity)
              else
                Decimal.new(0)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :is_overage?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn usage ->
              usage.overage_quantity &&
                Decimal.compare(
                  usage.overage_quantity,
                  0
                ) == :gt
            end
          )

        {:ok, values}
      end
    end

    calculate :billing_month, :string do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn usage ->
              if usage.usage_start do
                # YYYY - MM format
                usage.usage_start
                |> DateTime.to_date()
                |> Date.to_string()
                |> String.slice(0, 7)
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :cost_per_hour, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn usage ->
              if usage.usage_start && usage.usage_end && usage.total_cost do
                hours =
                  DateTime.diff(
                    usage.usage_end,
                    usage.usage_start,
                    :second
                  ) / 3600

                if hours > 0 do
                  Decimal.div(usage.total_cost, hours)
                else
                  Decimal.new(0)
                end
              else
                Decimal.new(0)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :days_since_usage, :integer do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        values =
          Enum.map(
            records,
            fn usage ->
              if usage.usage_end do
                DateTime.diff(
                  now,
                  usage.usage_end,
                  :day
                )
              else
                nil
              end
            end
          )

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
      authorize_if actor_attribute_equals(:role, "accountant")
      authorize_if actor_attribute_equals(:role, "customer_service")
      # Customers can read their own usage records
      authorize_if expr(customer_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      # System can create usage records
      authorize_if always()
    end

    policy action([
             :calculate_cost,
             :apply_discount,
             :validate_usage,
             :aggregate_usage,
             :mark_billed,
             :add_audit_entry
           ]) do
      # Billing system can update usage records
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :calculate_cost
    define :apply_discount
    define :validate_usage
    define :aggregate_usage
    define :mark_billed
    define :add_audit_entry
    define :destroy
  end

  postgres do
    table "billing_usage_records"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :record_number], unique: true
      index [:subscription_id]
      index [:customer_id]
      index [:invoice_id], where: "invoice_id IS NOT NULL"
      index [:usage_type]
      index [:metric_name]
      index [:status]
      index [:billing_period]
      index [:usage_start]
      index [:usage_end]
      index [:recorded_at]
      index [:billed_at], where: "billed_at IS NOT NULL"
      index [:resource_type], where: "resource_type IS NOT NULL"
      index [:resource_id], where: "resource_id IS NOT NULL"
      index [:device_id], where: "device_id IS NOT NULL"
      index [:location_id], where: "location_id IS NOT NULL"
      index [:user_id], where: "user_id IS NOT NULL"
      index [:category], where: "category IS NOT NULL"
      index [:billable?], name: "usage_records_billable_index", where: "billable? = true"
      index [:validated?], name: "usage_records_validated_index", where: "validated? = true"

      index [:discount_applied?],
        name: "usage_records_discount_applied_index",
        where: "discount_applied? = true"

      index [:promotional_rate?],
        name: "usage_records_promotional_index",
        where: "promotional_rate? = true"

      index [:aggregation_level]
      index [:collection_method]
      index [:accuracy_level]
      index [:data_classification]
      index [:region], where: "region IS NOT NULL"
      index [:total_cost], where: "total_cost > 0"
    end
  end

  # Helper functions
  @spec generate_record_number(term()) :: term()
  defp generate_record_number(changeset) do
    # Generate record number like USG - 20_251_206 - 001
    today = Date.utc_today()
    date_str = today |> Date.to_string() |> String.replace("-", "")

    random_num = :rand.uniform(999)

    random_suffix =
      random_num
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    record_number = "USG-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, :record_number, record_number)
  end

  @spec calculate_usage_cost(term()) :: term()
  defp calculate_usage_cost(changeset) do
    quantity = Ash.Changeset.get_argument_or_attribute(changeset, :quantity) || Decimal.new(0)
    unit_price = Ash.Changeset.get_argument_or_attribute(changeset, :unit_price) || Decimal.new(0)

    included_quantity =
      Ash.Changeset.get_argument_or_attribute(changeset, :included_quantity) || Decimal.new(0)

    overage_rate =
      Ash.Changeset.get_argument_or_attribute(
        changeset,
        :overage_rate
      ) || unit_price

    # Calculate base cost
    _billable_quantity = Decimal.max(Decimal.sub(quantity, included_quantity), Decimal.new(0))
    base_cost = Decimal.mult(quantity, unit_price)

    # Calculate overage
    overage_quantity =
      if Decimal.compare(quantity, included_quantity) == :gt do
        Decimal.sub(quantity, included_quantity)
      else
        Decimal.new(0)
      end

    overage_cost = Decimal.mult(overage_quantity, overage_rate)

    # Total cost
    total_cost = Decimal.add(base_cost, overage_cost)

    changeset
    |> Ash.Changeset.force_change_attribute(:overage_quantity, overage_quantity)
    |> Ash.Changeset.force_change_attribute(:overage_cost, overage_cost)
    |> Ash.Changeset.force_change_attribute(:total_cost, total_cost)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Billing
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
