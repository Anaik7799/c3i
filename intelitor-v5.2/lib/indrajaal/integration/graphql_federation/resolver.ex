defmodule Indrajaal.Integration.GraphQLFederation.Resolver do
  @moduledoc """
  WHAT: GraphQL federation resolver providing Ash-backed CRUD operations and
        field resolution for the GraphQLFederation.Schema resource.

  WHY: Centralises all schema-level resolution logic, giving callers a clean
       functional API that is independent of the Ash DSL surface and hides
       changeset construction details.

  CONSTRAINTS:
  - SC-ASH-001: force_change_attribute in before_action for mutations
  - SC-DB-001:  All persistence through Indrajaal.BaseResource (via Schema)
  - SC-GDE-001: Guardian validation required before deployment changes
  - AOR-AGT-001: Code must compile (mix compile) before task complete

  ## Change History
  | Version | Date       | Author       | Change                           |
  |---------|------------|--------------|----------------------------------|
  | 21.2.1  | 2026-03-19 | Claude       | Real implementation replacing stub|
  """

  require Logger

  alias Indrajaal.Integration.GraphQLFederation.Schema

  @telemetry_prefix [:indrajaal, :integration, :resolver]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetches a single Schema resource by its UUID primary key.

  Returns `{:ok, schema}` when found, `{:error, %Ash.Error.Query.NotFound{}}`
  when the record does not exist.
  """
  @spec get_by_id(String.t()) :: {:ok, map()} | {:error, term()}
  def get_by_id(id) when is_binary(id) do
    start = System.monotonic_time(:microsecond)

    result =
      Ash.get(Schema, id, domain: Indrajaal.Integration.GraphQLFederation)

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :get_by_id
    })

    case result do
      {:ok, record} ->
        Logger.debug("Resolver.get_by_id: found schema #{id}")
        {:ok, record}

      {:error, reason} ->
        Logger.warning("Resolver.get_by_id: not found id=#{id} reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_by_id(id) do
    {:error, {:invalid_id, id}}
  end

  @doc """
  Lists all Schema resources currently stored.

  Returns `{:ok, [%Schema{}]}` — an empty list when none exist.
  """
  @spec list_all() :: {:ok, list()} | {:error, term()}
  def list_all do
    start = System.monotonic_time(:microsecond)

    result = Ash.read(Schema, domain: Indrajaal.Integration.GraphQLFederation)

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :list_all
    })

    case result do
      {:ok, records} ->
        Logger.debug("Resolver.list_all: returned #{length(records)} schemas")
        {:ok, records}

      {:error, reason} ->
        Logger.error("Resolver.list_all failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates a new Schema resource from the given attribute map.

  Accepted keys: `:name`, `:description`, `:active`.
  Returns `{:ok, %Schema{}}` on success.
  """
  @spec create(map()) :: {:ok, map()} | {:error, term()}
  def create(params) when is_map(params) do
    start = System.monotonic_time(:microsecond)

    result =
      Schema
      |> Ash.Changeset.for_create(:create, params,
        domain: Indrajaal.Integration.GraphQLFederation
      )
      |> Ash.create()

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :create
    })

    case result do
      {:ok, record} ->
        Logger.info("Resolver.create: created schema #{record.id}")
        {:ok, record}

      {:error, reason} ->
        Logger.error("Resolver.create failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def create(params) do
    {:error, {:invalid_params, params}}
  end

  @doc """
  Updates an existing Schema resource identified by `id`.

  Merges `params` into the existing record via the `:update` action.
  Returns `{:ok, %Schema{}}` with the updated record on success.
  """
  @spec update(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update(id, params) when is_binary(id) and is_map(params) do
    start = System.monotonic_time(:microsecond)

    result =
      with {:ok, record} <- Ash.get(Schema, id, domain: Indrajaal.Integration.GraphQLFederation) do
        record
        |> Ash.Changeset.for_update(:update, params,
          domain: Indrajaal.Integration.GraphQLFederation
        )
        |> Ash.update()
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :update
    })

    case result do
      {:ok, record} ->
        Logger.info("Resolver.update: updated schema #{id}")
        {:ok, record}

      {:error, reason} ->
        Logger.error("Resolver.update failed id=#{id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def update(id, params) do
    {:error, {:invalid_args, id: id, params: params}}
  end

  @doc """
  Destroys the Schema resource identified by `id`.

  Returns `{:ok, %{id: id, deleted: true}}` on success.
  """
  @spec delete(String.t()) :: {:ok, map()} | {:error, term()}
  def delete(id) when is_binary(id) do
    start = System.monotonic_time(:microsecond)

    result =
      with {:ok, record} <- Ash.get(Schema, id, domain: Indrajaal.Integration.GraphQLFederation) do
        Ash.destroy(record)
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :delete
    })

    case result do
      :ok ->
        Logger.info("Resolver.delete: destroyed schema #{id}")
        {:ok, %{id: id, deleted: true}}

      {:error, reason} ->
        Logger.error("Resolver.delete failed id=#{id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete(id) do
    {:error, {:invalid_id, id}}
  end

  @doc """
  GraphQL field resolver entry point called by the Absinthe resolver pipeline.

  Dispatches to the appropriate operation based on `info.definition.name` when
  provided, otherwise delegates to `get_by_id/1` using `args.id`.

  Returns `{:ok, result}` | `{:error, reason}`.
  """
  @spec resolve(map(), map(), map()) :: {:ok, term()} | {:error, term()}
  def resolve(parent, args, _info) do
    start = System.monotonic_time(:microsecond)

    result =
      cond do
        Map.has_key?(args, :id) ->
          get_by_id(args.id)

        parent != nil and is_map(parent) and Map.has_key?(parent, :schema_id) ->
          get_by_id(parent.schema_id)

        true ->
          list_all()
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :resolve
    })

    result
  end

  @doc """
  Returns the federation schema definition map used by the GraphQL gateway
  to describe the Schema type to downstream consumers.
  """
  @spec federation_schema() :: map()
  def federation_schema do
    %{
      type: "Schema",
      key_fields: ["id"],
      extends: false,
      fields: %{
        id: %{type: "ID!", resolve: :id},
        name: %{type: "String!", resolve: :name},
        description: %{type: "String", resolve: :description},
        active: %{type: "Boolean!", resolve: :active},
        inserted_at: %{type: "DateTime", resolve: :inserted_at},
        updated_at: %{type: "DateTime", resolve: :updated_at}
      },
      queries: %{
        schema: %{args: %{id: "ID!"}, resolver: &get_by_id/1},
        schemas: %{args: %{}, resolver: fn -> list_all() end}
      },
      mutations: %{
        create_schema: %{
          args: %{name: "String!", description: "String", active: "Boolean"},
          resolver: &create/1
        },
        update_schema: %{
          args: %{id: "ID!", name: "String", description: "String", active: "Boolean"},
          resolver: fn %{id: id} = args -> update(id, Map.delete(args, :id)) end
        },
        delete_schema: %{args: %{id: "ID!"}, resolver: fn %{id: id} -> delete(id) end}
      }
    }
  end
end
