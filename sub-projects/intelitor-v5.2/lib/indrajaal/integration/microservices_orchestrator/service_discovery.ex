defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceDiscovery do
  @moduledoc """
  Service discovery resource for managing service discovery configurations.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "microservices_orchestrator_service_discovery"
    repo Indrajaal.Repo

    references do
      reference :tenant, on_delete: :delete
    end
  end

  json_api do
    type "service_discovery"

    routes do
      base("/api/integration/service_discovery")

      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid, allow_nil?: false, public?: true
    attribute :service_id, :uuid, allow_nil?: false, public?: true

    attribute :discovery_type, :atom,
      constraints: [one_of: [:dns, :api, :consul, :etcd]],
      default: :dns,
      public?: true

    attribute :health_check_enabled, :boolean, default: true, public?: true
    attribute :configuration, :map, default: %{}, public?: true

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      source_attribute :tenant_id
      allow_nil? false
    end

    belongs_to :service, Indrajaal.Integration.MicroservicesOrchestrator.Service do
      attribute_writable? true
    end
  end
end
