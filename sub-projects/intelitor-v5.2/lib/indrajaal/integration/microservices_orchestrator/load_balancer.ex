defmodule Indrajaal.Integration.MicroservicesOrchestrator.LoadBalancer do
  @moduledoc """
  Load balancer resource for managing load balancing configurations.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPostgres.DataLayer, AshJsonApi.Resource]

  postgres do
    table "microservices_orchestrator_load_balancers"
    repo Indrajaal.Repo

    references do
      reference :tenant, on_delete: :delete
    end
  end

  json_api do
    type "load_balancer"

    routes do
      base("/api/integration/load_balancers")

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

    attribute :algorithm, :atom,
      constraints: [one_of: [:round_robin, :weighted_round_robin, :least_connections, :hash]],
      default: :round_robin,
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

  @doc """
  Apply load balancing algorithm to instances.
  """
  def apply_algorithm(instances, algorithm) do
    case algorithm do
      :round_robin -> instances
      :weighted_round_robin -> Enum.sort_by(instances, & &1.weight, :desc)
      # Simplified for now
      :least_connections -> instances
      :hash -> Enum.shuffle(instances)
      _ -> instances
    end
  end
end
