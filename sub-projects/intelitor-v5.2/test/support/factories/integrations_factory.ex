defmodule Indrajaal.IntegrationsFactory do
  @moduledoc """
  Factory definitions for Integrations domain.
  """

  defmacro __using__(_) do
    quote do
      alias Indrajaal.Integrations.{Webhook, ApiConnection, DataMapping, SyncJob}

      @spec webhook_factory(any()) :: any()
      def webhook_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        organization =
          attrs_map[:organization] || insert(:organization, tenant: tenant)

        %Webhook{
          name: sequence(:webhook_name, &"Webhook #{&1}"),
          url: sequence(:webhook_url, &"https://api.example.com/webhook/#{&1}"),
          secret_key: "secret_#{System.unique_integer()}",
          active?: true,
          __events: ["alarm.triggered", "device.offline"],
          http_method: :post,
          content_type: "application/json",
          timeout_seconds: 30,
          retry_attempts: 3,
          custom_headers: %{"Authorization" => "Bearer token123"},
          failure_count: 0,
          total_calls: 0,
          metadata: %{},
          tenant: tenant,
          organization: organization
        }
        |> merge_attributes(attrs_map)
      end

      @spec api_connection_factory(any()) :: any()
      def api_connection_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        organization =
          attrs_map[:organization] || insert(:organization, tenant: tenant)

        %ApiConnection{
          name: sequence(:api_connection_name, &"API Connection #{&1}"),
          connection_type: :rest_api,
          base_url: sequence(:api_base_url, &"https://api.example#{&1}.com"),
          api_key: "api_key_#{System.unique_integer()}",
          __username: "api_user",
          password: "api_password",
          connection_config: %{},
          status: :disconnected,
          connection_attempts: 0,
          timeout_seconds: 30,
          enabled?: true,
          auto_retry?: true,
          metadata: %{},
          tenant: tenant,
          organization: organization
        }
        |> merge_attributes(attrs_map)
      end

      @spec data_mapping_factory(any()) :: any()
      def data_mapping_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        api_connection =
          attrs_map[:api_connection] || insert(:api_connection, tenant: tenant)

        creator = attrs_map[:creator] || insert(:user, tenant: tenant)

        %DataMapping{
          name: sequence(:data_mapping_name, &"Data Mapping #{&1}"),
          source_system: "external_system",
          target_system: "indrajaal",
          entity_type: :device,
          direction: :inbound,
          field_mappings: %{
            "id" => "external_id",
            "name" => "device_name",
            "type" => "device_type"
          },
          transformation_rules: %{},
          filter_conditions: %{},
          active?: true,
          priority: 100,
          usage_count: 0,
          metadata: %{},
          tenant: tenant,
          api_connection: api_connection,
          creator: creator,
          created_by: creator.id
        }
        |> merge_attributes(attrs_map)
      end

      @spec sync_job_factory(any()) :: any()
      def sync_job_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        api_connection =
          attrs_map[:api_connection] || insert(:api_connection, tenant: tenant)

        data_mapping =
          attrs_map[:data_mapping] ||
            insert(:data_mapping, tenant: tenant, api_connection: api_connection)

        creator = attrs_map[:creator] || insert(:user, tenant: tenant)

        %SyncJob{
          name: sequence(:sync_job_name, &"Sync Job #{&1}"),
          job_type: :scheduled,
          status: :pending,
          direction: :pull,
          # Every 6 hours
          schedule_cron: "0 */6 * * *",
          batch_size: 100,
          records_processed: 0,
          records_succeeded: 0,
          records_failed: 0,
          configuration: %{},
          result_summary: %{},
          enabled?: true,
          retry_count: 0,
          max_retries: 3,
          metadata: %{},
          tenant: tenant,
          api_connection: api_connection,
          data_mapping: data_mapping,
          creator: creator,
          created_by: creator.id
        }
        |> merge_attributes(attrs_map)
      end
    end
  end
end
