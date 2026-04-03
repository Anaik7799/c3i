defmodule Indrajaal.Integration.MicroservicesOrchestrator.ConfigurationManager do
  @moduledoc """
  Configuration manager resource for managing service configurations.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPostgres]

  postgres do
    table "microservices_orchestrator_configuration_managers"
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
    attribute :version, :string, allow_nil?: false, public?: true
    attribute :configuration, :map, default: %{}, public?: true
    attribute :active, :boolean, default: false, public?: true

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
