defmodule Intelitor.Core.AuditLog do
  @moduledoc """
  Comprehensive audit logging for compliance and security.

  Records all significant actions in the system with full context.
  Uses TimescaleDB hypertables for efficient time-series storage.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Core,
    table: "audit_logs",
    # Skip standard audit logging to avoid recursion
    extensions: []

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :actor_id, :uuid do
      description "ID of the user/system that performed the action"
    end

    attribute :actor_type, :string do
      constraints max_length: 50
      description "Type of actor (user, system, api_key, etc.)"
    end

    attribute :action, :string do
      allow_nil? false
      constraints max_length: 100
      description "Action performed (create, update, delete, read, etc.)"
    end

    attribute :resource_type, :string do
      allow_nil? false
      constraints max_length: 100
      description "Type of resource affected"
    end

    attribute :resource_id, :uuid do
      description "ID of the affected resource"
    end

    attribute :changes, :map do
      default %{}
      description "What changed (for updates)"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional context (IP, user agent, etc.)"
    end

    attribute :ip_address, :string do
      # IPv6 max length
      constraints max_length: 45
      description "IP address of the request"
    end

    attribute :user_agent, :string do
      constraints max_length: 500
      description "User agent string"
    end

    attribute :request_id, :uuid do
      description "Correlation ID for the request"
    end

    attribute :session_id, :uuid do
      description "Session that performed the action"
    end

    attribute :severity, :atom do
      constraints one_of: [:debug, :info, :warning, :error, :critical]
      default :info
      description "Log severity level"
    end

    attribute :success?, :boolean do
      default true
      description "Whether the action succeeded"
    end

    attribute :error_message, :string do
      constraints max_length: 1000
      description "Error message if action failed"
    end

    create_timestamp :occurred_at
  end

  actions do
    defaults [:read]

    create :log do
      accept [
        :actor_id,
        :actor_type,
        :action,
        :resource_type,
        :resource_id,
        :changes,
        :metadata,
        :ip_address,
        :user_agent,
        :request_id,
        :session_id,
        :severity,
        :success?,
        :error_message
      ]

      # Skip standard audit logging for audit logs
      change fn changeset, _ ->
        changeset
      end
    end

    read :by_actor do
      argument :actor_id, :uuid do
        allow_nil? false
      end

      filter expr(actor_id == ^arg(:actor_id))
    end

    read :by_resource do
      argument :resource_type, :string do
        allow_nil? false
      end

      argument :resource_id, :uuid do
        allow_nil? false
      end

      filter expr(
               resource_type == ^arg(:resource_type) and
                 resource_id == ^arg(:resource_id)
             )
    end

    read :by_date_range do
      argument :start_date, :datetime do
        allow_nil? false
      end

      argument :end_date, :datetime do
        allow_nil? false
      end

      filter expr(
               occurred_at >= ^arg(:start_date) and
                 occurred_at <= ^arg(:end_date)
             )
    end

    read :failures do
      filter expr(success? == false)
      description "Only failed actions"
    end

    read :by_severity do
      argument :min_severity, :atom do
        allow_nil? false
        constraints one_of: [:debug, :info, :warning, :error, :critical]
      end

      filter expr(severity >= ^arg(:min_severity))
    end
  end

  calculations do
    calculate :actor_display_name, :string do
      calculation fn records, _ ->
        # This would look up actual user/system names
        Enum.map(records, fn record ->
          "#{record.actor_type}:#{record.actor_id}"
        end)
      end

      description "Human-readable actor name"
    end

    calculate :resource_display_name, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          "#{record.resource_type}:#{record.resource_id}"
        end)
      end

      description "Human-readable resource identifier"
    end

    calculate :duration_ms, :integer do
      calculation fn records, _ ->
        # Would calculate from metadata if request timing is stored
        Enum.map(records, fn record ->
          get_in(record.metadata, ["duration_ms"]) || 0
        end)
      end

      description "Request duration in milliseconds"
    end
  end

  policies do
    # Audit logs can be read by admins and auditors
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :auditor)
      authorize_if actor_attribute_equals(:role, :security_admin)

      # Users can see their own audit trail
      authorize_if expr(actor_id == ^actor(:id) and actor_type == "user")
    end

    # Only system can create audit logs
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:is_system, true)
    end

    # Audit logs cannot be updated or deleted
    policy action_type([:update, :destroy]) do
      forbid_if always()
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :log, action: :log
  end

  postgres do
    table "audit_logs"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :occurred_at],
        name: "audit_logs_tenant_time_index"

      index [:actor_id, :occurred_at],
        name: "audit_logs_actor_time_index"

      index [:resource_type, :resource_id, :occurred_at],
        name: "audit_logs_resource_time_index"

      index [:severity],
        name: "audit_logs_severity_index",
        where: "severity >= 'warning'"

      index [:success?],
        name: "audit_logs_failures_index",
        where: "success? = false"

      index [:request_id],
        name: "audit_logs_request_id_index"
    end

    custom_statements do
      # Create TimescaleDB hypertable for efficient time-series storage
      statement :create_hypertable do
        up """
        SELECT create_hypertable('audit_logs', 'occurred_at',
          chunk_time_interval => interval '1 day',
          if_not_exists => true
        );
        """

        down """
        -- Hypertables cannot be easily reverted
        """
      end

      # Add compression policy for older data
      statement :add_compression_policy do
        up """
        ALTER TABLE audit_logs SET (
          timescaledb.compress,
          timescaledb.compress_segmentby = 'tenant_id',
          timescaledb.compress_orderby = 'occurred_at DESC'
        );

        SELECT add_compression_policy('audit_logs', INTERVAL '30 days');
        """

        down """
        SELECT remove_compression_policy('audit_logs');
        """
      end

      # Add retention policy to automatically drop old data
      statement :add_retention_policy do
        up """
        SELECT add_retention_policy('audit_logs', INTERVAL '1 year');
        """

        down """
        SELECT remove_retention_policy('audit_logs');
        """
      end
    end
  end

  # Helper module for easy audit logging
  defmodule Logger do
    @moduledoc false

    def log(action, resource_type, resource_id, actor, opts \\ []) do
      params = %{
        actor_id: actor[:id],
        actor_type: actor[:type] || "user",
        action: to_string(action),
        resource_type: to_string(resource_type),
        resource_id: resource_id,
        changes: Keyword.get(opts, :changes, %{}),
        metadata: Keyword.get(opts, :metadata, %{}),
        ip_address: Keyword.get(opts, :ip_address),
        user_agent: Keyword.get(opts, :user_agent),
        request_id: Keyword.get(opts, :request_id),
        session_id: Keyword.get(opts, :session_id),
        severity: Keyword.get(opts, :severity, :info),
        success?: Keyword.get(opts, :success?, true),
        error_message: Keyword.get(opts, :error_message),
        tenant_id: actor[:tenant_id]
      }

      Intelitor.Core.AuditLog.log(params, actor: %{is_system: true})
    end
  end
end
