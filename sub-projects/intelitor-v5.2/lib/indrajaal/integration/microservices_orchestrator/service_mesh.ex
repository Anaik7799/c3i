defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceMesh do
  @moduledoc """
  Service mesh resource for managing service mesh configurations.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "microservices_orchestrator_service_mesh"
    repo Indrajaal.Repo

    references do
      reference :tenant, on_delete: :delete
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
    attribute :mesh_enabled, :boolean, default: false, public?: true
    attribute :security_enabled, :boolean, default: true, public?: true
    attribute :observability_enabled, :boolean, default: true, public?: true
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
