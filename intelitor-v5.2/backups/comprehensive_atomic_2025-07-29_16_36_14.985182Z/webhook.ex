defmodule Intelitor.Integrations.Webhook do
  @moduledoc """
  Manages webhook endpoints for external system notifications.

  Webhooks enable real-time integration with external systems by sending
  HTTP callbacks when specific events occur in the security monitoring system.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Integrations,
    table: "integration_webhooks"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :url, :string do
      allow_nil? false
      public? true
      constraints max_length: 2000
    end

    attribute :secret_key, :string do
      public? true
      constraints max_length: 255
      sensitive? true
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :events, {:array, :string} do
      allow_nil? false
      public? true
      default []
    end

    attribute :http_method, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:post, :put, :patch]
      default :post
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      default "application/json"
      constraints max_length: 100
    end

    attribute :timeout_seconds, :integer do
      allow_nil? false
      public? true
      default 30
      constraints min: 1, max: 300
    end

    attribute :retry_attempts, :integer do
      allow_nil? false
      public? true
      default 3
      constraints min: 0, max: 10
    end

    attribute :custom_headers, :map do
      public? true
      default %{}
    end

    attribute :last_success_at, :utc_datetime_usec do
      public? true
    end

    attribute :last_failure_at, :utc_datetime_usec do
      public? true
    end

    attribute :failure_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :total_calls, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :organization, Intelitor.Core.Organization do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:active?, false)
    end

    update :record_success do
      require_atomic? false
      accept []
      change set_attribute(:last_success_at, DateTime.utc_now())
      change set_attribute(:failure_count, 0)

      change fn changeset, _context ->
        total = Ash.Changeset.get_attribute(changeset, :total_calls)
        Ash.Changeset.change_attribute(changeset, :total_calls, total + 1)
      end
    end

    update :record_failure do
      require_atomic? false
      accept []
      change set_attribute(:last_failure_at, DateTime.utc_now())

      change fn changeset, _context ->
        failures = Ash.Changeset.get_attribute(changeset, :failure_count)
        total = Ash.Changeset.get_attribute(changeset, :total_calls)

        changeset
        |> Ash.Changeset.change_attribute(:failure_count, failures + 1)
        |> Ash.Changeset.change_attribute(:total_calls, total + 1)
      end
    end
  end

  calculations do
    calculate :success_rate, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn webhook ->
          if webhook.total_calls > 0 do
            successes = webhook.total_calls - webhook.failure_count
            Float.round(successes / webhook.total_calls * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    calculate :is_healthy?, :boolean do
      calculation fn records, _opts ->
        Enum.map(records, fn webhook ->
          webhook.active? && webhook.failure_count < 5
        end)
      end
    end
  end

  validations do
    validate match(:url, {~S|^https?://.+|, ""}) do
      message "must be a valid HTTP or HTTPS URL"
    end

    validate fn changeset, _context ->
      events = Ash.Changeset.get_attribute(changeset, :events)

      valid_events = [
        "alarm.triggered",
        "alarm.resolved",
        "device.offline",
        "device.online",
        "user.login",
        "user.logout",
        "site.breach",
        "maintenance.scheduled"
      ]

      invalid_events = Enum.reject(events, &(&1 in valid_events))

      if Enum.empty?(invalid_events) do
        {:ok, changeset}
      else
        {:error,
         field: :events, message: "contains invalid events: #{Enum.join(invalid_events, ", ")}"}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "integration_admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :activate
    define :deactivate
    define :record_success
    define :record_failure
  end

  postgres do
    table "integration_webhooks"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :name], unique: true
      index [:organization_id]
      index [:active?], name: "webhooks_active_index", where: "active? = true"
      index [:events], using: "gin"
    end
  end
end
