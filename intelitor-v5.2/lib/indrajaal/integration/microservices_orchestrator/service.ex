defmodule Indrajaal.Integration.MicroservicesOrchestrator.Service do
  @moduledoc """
  Service resource for microservices orchestration platform.

  Represents a service in the orchestration platform with comprehensive
  metadata, configuration, and lifecycle management capabilities.
  """

  use Ash.Resource,
    domain: Indrajaal.Integration.MicroservicesOrchestrator,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "microservices_orchestrator_services"
    repo Indrajaal.Repo

    references do
      reference :tenant, on_delete: :delete
    end
  end

  json_api do
    type "service"

    routes do
      base("/api/integration/services")

      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  graphql do
    type :service

    queries do
      read_one :get_service, :read
      list(:list_services, :read)
    end

    mutations do
      create :create_service, :create
      update :update_service, :update
      destroy :delete_service, :destroy
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :version, :string, allow_nil?: false, public?: true

    attribute :status, :atom,
      constraints: [one_of: [:active, :inactive, :deploying, :failed]],
      default: :inactive,
      public?: true

    attribute :port, :integer, public?: true
    attribute :health_check_path, :string, default: "/health", public?: true
    attribute :dependencies, {:array, :string}, default: [], public?: true
    attribute :metadata, :map, default: %{}, public?: true
    attribute :configuration, :map, default: %{}, public?: true

    # Scaling configuration
    attribute :min_instances, :integer, default: 1, public?: true
    attribute :max_instances, :integer, default: 10, public?: true
    attribute :current_instances, :integer, default: 0, public?: true

    # Resource constraints
    attribute :cpu_limit, :string, public?: true
    attribute :memory_limit, :string, public?: true
    attribute :disk_limit, :string, public?: true

    # Service mesh configuration
    attribute :mesh_enabled, :boolean, default: false, public?: true
    attribute :security_enabled, :boolean, default: true, public?: true
    attribute :observability_enabled, :boolean, default: true, public?: true

    timestamps()
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create

    read :by_name do
      argument :name, :string, allow_nil?: false
      get? true
      filter expr(name == ^arg(:name))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :active_services do
      filter expr(status == :active)
    end

    update :activate do
      change set_attribute(:status, :active)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :deactivate do
      change set_attribute(:status, :inactive)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :set_deploying do
      change set_attribute(:status, :deploying)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :mark_failed do
      change set_attribute(:status, :failed)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    action :register_service, :struct do
      argument :service_config, :map, allow_nil?: false

      run fn input, __context ->
        # Extract service configuration
        config = input.arguments.service_config

        service_attrs = %{
          name: Map.get(config, "name") || Map.get(config, :name),
          description: Map.get(config, "description") || Map.get(config, :description),
          version: Map.get(config, "version") || Map.get(config, :version),
          port: Map.get(config, "port") || Map.get(config, :port),
          health_check_path:
            Map.get(config, "health_check_path") || Map.get(config, :health_check_path, "/health"),
          dependencies: Map.get(config, "dependencies") || Map.get(config, :dependencies, []),
          metadata: Map.get(config, "metadata") || Map.get(config, :metadata, %{}),
          tenant_id: Map.get(config, "tenant_id") || Map.get(config, :tenant_id)
        }

        # Extract scaling configuration
        scaling = Map.get(config, "scaling") || Map.get(config, :scaling, %{})

        service_attrs =
          Map.merge(service_attrs, %{
            min_instances:
              Map.get(scaling, "min_instances") || Map.get(scaling, :min_instances, 1),
            max_instances:
              Map.get(scaling, "max_instances") || Map.get(scaling, :max_instances, 10)
          })

        {:ok, service_attrs}
      end
    end
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      source_attribute :tenant_id
      allow_nil? false
    end
  end

  validations do
    validate match(:name, ~r/^[a-z][a-z0-9\-_]*$/),
      message:
        "Service name must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores"

    validate match(:version, ~r/^\d+\.\d+\.\d+/),
      message: "Version must follow semantic versioning format (x.y.z)"

    validate numericality(:port, greater_than: 1000, less_than: 65_535),
      message: "Port must be between 1001 and 65_534"

    validate numericality(:min_instances, greater_than: 0),
      message: "Minimum instances must be greater than 0"

    validate numericality(:max_instances, greater_than: 0),
      message: "Maximum instances must be greater than 0"

    validate compare(:max_instances, greater_than_or_equal_to: :min_instances),
      message: "Maximum instances must be greater than or equal to minimum instances"
  end

  @doc """
  Gets a service by name with tenant context.
  """
  def get_service_by_name(name, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)

    __MODULE__
    |> Ash.Query.set_tenant(tenant_id)
    |> Ash.Query.for_read(:by_name, %{name: name})
    |> Ash.read_one(Indrajaal.Integration.MicroservicesOrchestrator)
  rescue
    _ -> {:error, :not_found}
  end

  @doc """
  Lists all services with optional filtering.
  """
  def list_services(opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)

    __MODULE__
    |> Ash.Query.set_tenant(tenant_id)
    |> Ash.Query.limit(1000)
    |> Ash.read(Indrajaal.Integration.MicroservicesOrchestrator)
  rescue
    _ -> {:error, :query_failed}
  end
end
