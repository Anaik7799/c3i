defmodule Indrajaal.Integrations.ApiConnection do
  @moduledoc """
  Manages API connections to external security systems.

  API connections enable bidirectional integration with third - party systems
  such as access control panels, video management systems, and alarm panels.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Integrations

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :connection_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :rest_api,
                    :soap,
                    :graphql,
                    :sia_dc09,
                    :onvif,
                    :mqtt,
                    :webhook,
                    :database,
                    :file_transfer
                  ]
    end

    attribute :base_url, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :api_key, :string do
      public? true
      constraints max_length: 500
      sensitive? true
    end

    attribute :__username, :string do
      public? true
      constraints max_length: 100
    end

    attribute :password, :string do
      public? true
      constraints max_length: 255
      sensitive? true
    end

    attribute :certificate_data, :string do
      public? true
      sensitive? true
    end

    attribute :connection_config, :map do
      public? true
      default %{}
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:connected, :disconnected, :error, :testing]
      default :disconnected
    end

    attribute :last_connected_at, :utc_datetime_usec do
      public? true
    end

    attribute :last_error_at, :utc_datetime_usec do
      public? true
    end

    attribute :last_error_message, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :connection_attempts, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :rate_limit_per_minute, :integer do
      public? true
      constraints min: 1, max: 10_000
    end

    attribute :timeout_seconds, :integer do
      allow_nil? false
      public? true
      default 30
      constraints min: 1, max: 300
    end

    attribute :enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :auto_retry?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    belongs_to :organization, Indrajaal.Core.Organization do
      allow_nil? false
      public? true
    end

    has_many :data_mappings, Indrajaal.Integrations.DataMapping do
      public? true
    end

    has_many :sync_jobs, Indrajaal.Integrations.SyncJob do
      public? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :connect do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        now = DateTime.utc_now()
        attempts = Ash.Changeset.get_attribute(changeset, :connection_attempts)

        changeset
        |> Ash.Changeset.change_attribute(:status, :connected)
        |> Ash.Changeset.change_attribute(:last_connected_at, now)
        |> Ash.Changeset.change_attribute(:connection_attempts, attempts + 1)
        |> Ash.Changeset.change_attribute(:last_error_message, nil)
      end
    end

    update :disconnect do
      require_atomic? false
      accept []
      change set_attribute(:status, :disconnected)
    end

    update :record_error do
      require_atomic? false

      argument :error_message, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, __context ->
        now = DateTime.utc_now()
        attempts = Ash.Changeset.get_attribute(changeset, :connection_attempts)
        error_message = Ash.Changeset.get_argument(changeset, :error_message)

        changeset
        |> Ash.Changeset.change_attribute(:status, :error)
        |> Ash.Changeset.change_attribute(:last_error_at, now)
        |> Ash.Changeset.change_attribute(:last_error_message, error_message)
        |> Ash.Changeset.change_attribute(:connection_attempts, attempts + 1)
      end
    end

    update :enable do
      require_atomic? false
      accept []
      change set_attribute(:enabled?, true)
    end

    update :disable do
      require_atomic? false
      accept []
      change set_attribute(:enabled?, false)
    end
  end

  calculations do
    calculate :is_healthy?, :boolean do
      calculation fn records, opts ->
        Enum.map(records, fn connection ->
          connection.enabled? && connection.status == :connected &&
            (!connection.last_error_at ||
               DateTime.diff(DateTime.utc_now(), connection.last_error_at, :hour) > 1)
        end)
      end
    end

    calculate :uptime_percentage, :float do
      calculation fn records, opts ->
        Enum.map(records, fn connection ->
          if connection.last_connected_at do
            # Simplified uptime calculation
            hours_since_last_connect =
              DateTime.diff(DateTime.utc_now(), connection.last_connected_at, :hour)

            error_hours =
              if connection.last_error_at &&
                   connection.last_error_at > connection.last_connected_at do
                DateTime.diff(DateTime.utc_now(), connection.last_error_at, :hour)
              else
                0
              end

            if hours_since_last_connect > 0 do
              uptime_hours = hours_since_last_connect - error_hours
              Float.round(uptime_hours / hours_since_last_connect * 100, 2)
            else
              100.0
            end
          else
            0.0
          end
        end)
      end
    end
  end

  validations do
    validate fn changeset, __context ->
      connection_type = Ash.Changeset.get_attribute(changeset, :connection_type)
      base_url = Ash.Changeset.get_attribute(changeset, :base_url)

      if connection_type in [:rest_api, :soap, :graphql, :onvif] && is_nil(base_url) do
        {:error, field: :base_url, message: "_required for #{connection_type} connection"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, __context ->
      base_url = Ash.Changeset.get_attribute(changeset, :base_url)

      if base_url && !String.match?(base_url, ~r/^https?:\/\/.+/i) do
        {:error, field: :base_url, message: "must be a valid HTTP or HTTPS URL"}
      else
        {:ok, changeset}
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
    define :connect
    define :disconnect
    define :record_error
    define :enable
    define :disable
  end

  postgres do
    table "integration_api_connections"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :name], unique: true
      index [:organization_id]
      index [:connection_type]
      index [:status]
      index [:enabled?], name: "api_connection_enabled_index"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic feedback
# Domain: Integrations
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
