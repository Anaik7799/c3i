defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceInstance do
  @moduledoc """
  Service instance resource for tracking individual instances of services.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "microservices_orchestrator_service_instances"
    repo Indrajaal.Repo

    references do
      reference :tenant, on_delete: :delete
    end
  end

  json_api do
    type "service_instance"

    routes do
      base("/api/integration/service_instances")

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
    attribute :instance_name, :string, allow_nil?: false, public?: true

    attribute :status, :atom,
      constraints: [one_of: [:starting, :healthy, :unhealthy, :stopping, :stopped]],
      default: :starting,
      public?: true

    attribute :host, :string, allow_nil?: false, public?: true
    attribute :port, :integer, allow_nil?: false, public?: true
    attribute :endpoint, :string, public?: true
    attribute :zone, :string, public?: true
    attribute :version, :string, public?: true
    attribute :weight, :integer, default: 100, public?: true
    attribute :last_health_check, :utc_datetime, public?: true
    attribute :metadata, :map, default: %{}, public?: true

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_service do
      argument :service_id, :uuid, allow_nil?: false
      filter expr(service_id == ^arg(:service_id))
    end

    read :healthy_instances do
      filter expr(status == :healthy)
    end
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
