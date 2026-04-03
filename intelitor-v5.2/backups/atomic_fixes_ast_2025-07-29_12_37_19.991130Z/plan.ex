defmodule Intelitor.Billing.Plan do
  @moduledoc """
  Represents billing plans and pricing models.

  Plans define the pricing structure, features, and limits for different
  service tiers. They support various billing models including subscription,
  usage-based, and hybrid pricing with flexible discount and promotion
  capabilities.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Billing,
    table: "billing_plans"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Plan identification
    attribute :plan_code, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :plan_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :version, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1.0"
    end

    # Plan classification
    attribute :plan_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :basic,
                    :standard,
                    :premium,
                    :enterprise,
                    :custom,
                    :trial,
                    :freemium,
                    :addon,
                    :promotional
                  ]

      default :standard
    end

    attribute :service_tier, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:bronze, :silver, :gold, :platinum, :diamond]
      default :silver
    end

    attribute :market_segment, :atom do
      public? true
      constraints one_of: [:residential, :small_business, :enterprise, :government]
    end

    # Pricing model
    attribute :billing_model, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :subscription,
                    :usage_based,
                    :tiered,
                    :per_device,
                    :per_location,
                    :hybrid,
                    :one_time,
                    :freemium,
                    :custom
                  ]

      default :subscription
    end

    attribute :billing_frequency, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:monthly, :quarterly, :semi_annual, :annual, :biennial]
      default :monthly
    end

    attribute :base_price, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      constraints max_length: 3
      default "USD"
    end

    # Usage-based pricing
    attribute :usage_pricing_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :usage_pricing_tiers, {:array, :map} do
      public? true
      default []
    end

    attribute :overage_rate, :decimal do
      public? true

      constraints precision: 10,
                  scale: 4,
                  min: 0
    end

    # Device and location limits
    attribute :max_devices, :integer do
      public? true
      constraints min: 0
    end

    attribute :max_locations, :integer do
      public? true
      constraints min: 0
    end

    attribute :max_users, :integer do
      public? true
      constraints min: 1
    end

    attribute :max_cameras, :integer do
      public? true
      constraints min: 0
    end

    attribute :max_zones, :integer do
      public? true
      constraints min: 0
    end

    # Storage and retention limits
    attribute :storage_gb_included, :integer do
      public? true
      constraints min: 0
    end

    attribute :retention_days, :integer do
      public? true
      # 20 years
      constraints min: 1, max: 7300
    end

    attribute :storage_overage_rate, :decimal do
      public? true

      constraints precision: 10,
                  scale: 4,
                  min: 0
    end

    # Feature inclusions
    attribute :included_features, {:array, :string} do
      public? true
      default []
    end

    attribute :excluded_features, {:array, :string} do
      public? true
      default []
    end

    attribute :addon_features, {:array, :map} do
      public? true
      default []
    end

    # Service levels
    attribute :monitoring_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:basic, :standard, :premium, :enterprise]
      default :basic
    end

    attribute :response_time_guarantee, :integer do
      public? true
      # 24 hours in seconds
      constraints min: 1, max: 86400
    end

    attribute :uptime_sla_percentage, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 90.00,
                  max: 100.00
    end

    attribute :support_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:basic, :standard, :priority, :premium, :white_glove]
      default :basic
    end

    # Trial and promotional
    attribute :trial_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :trial_duration_days, :integer do
      public? true
      constraints min: 1, max: 365
    end

    attribute :free_tier?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :promotional?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :promotional_ends_at, :utc_datetime_usec do
      public? true
    end

    # Setup and onboarding
    attribute :setup_fee, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :installation_included?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :onboarding_included?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :training_included?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Contract terms
    attribute :minimum_commitment_months, :integer do
      public? true
      constraints min: 1, max: 60
    end

    attribute :early_termination_fee, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :auto_renewal?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :cancellation_notice_days, :integer do
      public? true
      constraints min: 0, max: 365
      default 30
    end

    # Discounts and pricing modifiers
    attribute :volume_discounts, {:array, :map} do
      public? true
      default []
    end

    attribute :annual_discount_percentage, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :loyalty_discount_percentage, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    # Plan status and lifecycle
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :active,
                    :inactive,
                    :deprecated,
                    :archived,
                    :grandfathered
                  ]

      default :draft
    end

    attribute :effective_date, :date do
      public? true
    end

    attribute :end_date, :date do
      public? true
    end

    attribute :grandfathered?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Sales and marketing
    attribute :publicly_available?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :sales_contact_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :target_customer_profile, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :value_proposition, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :competitive_advantages, {:array, :string} do
      public? true
      default []
    end

    # Financial tracking
    attribute :cost_basis, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :margin_percentage, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :revenue_recognition_model, :atom do
      public? true
      constraints one_of: [:immediate, :monthly, :milestone_based, :usage_based]
    end

    # Analytics and performance
    attribute :subscriber_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :conversion_rate, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :churn_rate, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :average_lifetime_value, :decimal do
      public? true

      constraints precision: 12,
                  scale: 2,
                  min: 0
    end

    # Metadata and configuration
    attribute :configuration, :map do
      public? true
      default %{}
    end

    attribute :terms_and_conditions, :string do
      public? true
      constraints max_length: 10000
    end

    attribute :keywords, {:array, :string} do
      public? true
      default []
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
    has_many :subscriptions, Intelitor.Billing.Subscription
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :plan_code,
        :plan_name,
        :description,
        :version,
        :plan_type,
        :service_tier,
        :market_segment,
        :billing_model,
        :billing_frequency,
        :base_price,
        :currency,
        :usage_pricing_enabled?,
        :usage_pricing_tiers,
        :overage_rate,
        :max_devices,
        :max_locations,
        :max_users,
        :max_cameras,
        :max_zones,
        :storage_gb_included,
        :retention_days,
        :storage_overage_rate,
        :included_features,
        :excluded_features,
        :addon_features,
        :monitoring_level,
        :response_time_guarantee,
        :uptime_sla_percentage,
        :support_level,
        :trial_enabled?,
        :trial_duration_days,
        :free_tier?,
        :promotional?,
        :promotional_ends_at,
        :setup_fee,
        :installation_included?,
        :onboarding_included?,
        :training_included?,
        :minimum_commitment_months,
        :early_termination_fee,
        :auto_renewal?,
        :cancellation_notice_days,
        :volume_discounts,
        :annual_discount_percentage,
        :loyalty_discount_percentage,
        :effective_date,
        :end_date,
        :grandfathered?,
        :publicly_available?,
        :sales_contact_required?,
        :target_customer_profile,
        :value_proposition,
        :competitive_advantages,
        :cost_basis,
        :margin_percentage,
        :revenue_recognition_model,
        :configuration,
        :terms_and_conditions,
        :keywords,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :draft)
        |> Ash.Changeset.force_change_attribute(:subscriber_count, 0)
      end
    end


    update :activate do
      require_atomic? false
      accept [:status, :effective_date]

      validate attribute_equals(:status, :draft)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :active)
        |> Ash.Changeset.force_change_attribute(:effective_date, Date.utc_today())
      end
    end

    update :deactivate do
      require_atomic? false
      
      
      accept [:status]

      validate attribute_equals(:status, :active)

      change set_attribute(:status, :inactive)
    end

    update :deprecate do
      require_atomic? false
      accept [:status, :end_date]

      validate attribute_in(:status, [:active, :inactive])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :deprecated)
        |> Ash.Changeset.force_change_attribute(:end_date, Date.utc_today())
      end
    end

    update :grandfather do
      require_atomic? false
      
      
      accept [:grandfathered?, :status]

      validate attribute_equals(:status, :deprecated)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:grandfathered?, true)
        |> Ash.Changeset.force_change_attribute(:status, :grandfathered)
      end
    end

    update :update_subscriber_count do
      require_atomic? false
      
      
      accept [:subscriber_count]

      argument :count, :integer do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :subscriber_count,
          changeset.arguments.count
        )
      end
    end

    update :update_analytics do
      require_atomic? false
      accept [:conversion_rate, :churn_rate, :average_lifetime_value]

      argument :conversion_rate, :decimal do
        constraints precision: 5,
                    scale: 2,
                    min: 0,
                    max: 100
      end

      argument :churn_rate, :decimal do
        constraints precision: 5,
                    scale: 2,
                    min: 0,
                    max: 100
      end

      argument :lifetime_value, :decimal do
        constraints precision: 12,
                    scale: 2,
                    min: 0
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    # Migrated to shared utility: Eliminates duplicate code (mass: 60)
    calculate :monthly_price, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn plan ->
              Intelitor.Shared.BillingCalculations.calculate_monthly_price(
                plan.base_price,
                plan.billing_frequency
              )
            end
          )

        {:ok, values}
      end
    end

    calculate :annual_price, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn plan ->
              case plan.billing_frequency do
                :monthly ->
                  Decimal.mult(
                    plan.base_price,
                    12
                  )

                :quarterly ->
                  Decimal.mult(plan.base_price, 4)

                :semi_annual ->
                  Decimal.mult(plan.base_price, 2)

                :annual ->
                  plan.base_price

                :biennial ->
                  Decimal.div(plan.base_price, 2)

                _ ->
                  plan.base_price
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :has_trial?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn plan ->
              plan.trial_enabled? && plan.trial_duration_days && plan.trial_duration_days > 0
            end
          )

        {:ok, values}
      end
    end

    calculate :is_available?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn plan ->
              plan.status == :active &&
                plan.publicly_available? &&
                (is_nil(plan.effective_date) || Date.compare(today, plan.effective_date) != :lt) &&
                (is_nil(plan.end_date) || Date.compare(today, plan.end_date) == :lt)
            end
          )

        {:ok, values}
      end
    end

    calculate :margin_amount, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn plan ->
              if plan.margin_percentage && plan.base_price do
                Decimal.mult(
                  plan.base_price,
                  Decimal.div(
                    plan.margin_percentage,
                    100
                  )
                )
              else
                Decimal.new(0)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :price_per_device, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn plan ->
              if plan.max_devices && plan.max_devices > 0 do
                Decimal.div(
                  plan.base_price,
                  plan.max_devices
                )
              else
                plan.base_price
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
      authorize_if actor_attribute_equals(:role, "sales")
      authorize_if actor_attribute_equals(:role, "customer_service")
      # Public plans can be read by anyone
      authorize_if expr(publicly_available? == true and status == :active)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
    end

    policy action([:activate, :deactivate, :deprecate, :grandfather]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
    end

    policy action([:update_subscriber_count, :update_analytics]) do
      # System can update analytics
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :deactivate
    define :deprecate
    define :grandfather
    define :update_subscriber_count
    define :update_analytics
    define :destroy
  end

  postgres do
    table "billing_plans"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :plan_code], unique: true
      index [:plan_type]
      index [:service_tier]
      index [:billing_model]
      index [:billing_frequency]
      index [:status]

      index [:publicly_available?],
        name: "plans_publicly_available_index",
        where: "publicly_available? = true"

      index [:trial_enabled?], name: "plans_trial_enabled_index", where: "trial_enabled? = true"
      index [:free_tier?], name: "plans_free_tier_index", where: "free_tier? = true"
      index [:promotional?], name: "plans_promotional_index", where: "promotional? = true"
      index [:grandfathered?], name: "plans_grandfathered_index", where: "grandfathered? = true"
      index [:effective_date], where: "effective_date IS NOT NULL"
      index [:end_date], where: "end_date IS NOT NULL"
      index [:promotional_ends_at], where: "promotional_ends_at IS NOT NULL"
      index [:base_price]
      index [:currency]
    end
  end
end
