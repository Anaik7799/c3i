defmodule Indrajaal.Shared.ApiPatterns do
  @moduledoc """
  Shared API creation patterns to eliminate duplication across domain APIs.

  This module extracts common API patterns used by:
  - Indrajaal.Alarms.Api (mass: 29)
  - Indrajaal.DomainApi (mass: 29)
  - Other domain APIs with similar patterns

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  @doc """
  Creates a standardized resource creation function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform (default: :create)

  ## Returns
  Function that takes attrs and opts,
    returns {:ok, resource} or {:error, reason}

  ## Example
      def start_link(opts \\ []) do
        Indrajaal.Shared.ApiPatterns.create_resource_function(
          Indrajaal.Alarms.IncidentType
        ).(_attrs, opts)
      end
  """
  @spec create_resource_function(module(), atom()) :: (map(), keyword() ->
                                                         {:ok, any()} | {:error, any()})
  def create_resource_function(resource_module, action_name \\ :create) do
    fn attrs, opts ->
      try do
        resource_module
        |> Ash.Changeset.for_create(action_name, attrs, opts)
        |> Ash.create!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Creates a standardized resource update function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform (default: :update)

  ## Returns
  Function that takes resource,
    attrs and opts, returns {:ok, resource} or {:error, reason}
  """
  @spec update_resource_function(module(), atom()) :: (any(), map(), keyword() ->
                                                         {:ok, any()} | {:error, any()})
  def update_resource_function(_resource_module, action_name \\ :update) do
    fn resource, attrs, opts ->
      try do
        resource
        |> Ash.Changeset.for_update(action_name, attrs, opts)
        |> Ash.update!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Creates a standardized resource retrieval function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform (default: :read)

  ## Returns
  Function that takes id and opts, returns {:ok, resource} or {:error, reason}
  """
  @spec get_resource_function(module(), atom()) :: (any(), keyword() ->
                                                      {:ok, any()} | {:error, any()})
  def get_resource_function(resource_module, _action_name \\ :read) do
    fn id, opts ->
      try do
        resource_module
        |> Ash.get!(id, opts)
        |> case do
          nil -> {:error, :not_found}
          resource -> {:ok, resource}
        end
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Creates a standardized resource listing function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform (default: :read)

  ## Returns
  Function that takes opts, returns {:ok, [resources]} or {:error, reason}
  """
  @spec list_resources_function(module(), atom()) :: (keyword() ->
                                                        {:ok, list()} | {:error, any()})
  def list_resources_function(resource_module, _action_name \\ :read) do
    fn opts ->
      try do
        resource_module
        |> Ash.read!(opts)
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Creates a standardized resource deletion function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform (default: :destroy)

  ## Returns
  Function that takes resource and opts,
    returns {:ok, resource} or {:error, reason}
  """
  @spec delete_resource_function(module(), atom()) :: (any(), keyword() ->
                                                         {:ok, any()} | {:error, any()})
  def delete_resource_function(_resource_module, action_name \\ :destroy) do
    fn resource, opts ->
      try do
        resource
        |> Ash.Changeset.for_destroy(action_name, %{}, opts)
        |> Ash.destroy!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Creates a complete CRUD API module for a resource.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `resource_name` - Singular name for function generation (e.g.,
      "incident_type")

  ## Returns
  Map of function definitions that can be used with defdelegate

  ## Example
      # In your API module:
      alias Indrajaal.Shared.ApiPatterns

      @functions ApiPatterns.generate_crud_functions(Indrajaal.Alarms.IncidentType,

      "incident_type")

      defdelegate create_incident_type(attrs,
        opts \\ []), to: @functions, as: :create
      defdelegate get_incident_type(id, opts \\ []), to: @functions, as: :get
      defdelegate list_incident_types(opts \\ []), to: @functions, as: :list
      defdelegate update_incident_type(resource,
        attrs, opts \\ []), to: @functions, as: :update
      defdelegate delete_incident_type(resource,
        opts \\ []), to: @functions, as: :delete
  """
  @spec generate_crud_functions(module(), String.t()) :: map()
  def generate_crud_functions(resource_module, _resource_name) do
    %{
      create: create_resource_function(resource_module),
      get: get_resource_function(resource_module),
      list: list_resources_function(resource_module),
      update: update_resource_function(resource_module),
      delete: delete_resource_function(resource_module)
    }
  end

  @doc """
  Macro to generate standard CRUD functions for a resource.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `singular_name` - Singular name for functions (e.g., :incident_type)
    - `plural_name` - Plural name for list function (e.g., :incident_types)

  ## Example
      use Indrajaal.Shared.ApiPatterns

      generate_crud_api(Indrajaal.Alarms.IncidentType,
      :incident_type,
      :incident_types)
      # This generates:
      # - create_incident_type / 2
      # - get_incident_type / 2
      # - list_incident_types / 1
      # - update_incident_type / 3
      # - delete_incident_type / 2
  """
  defmacro generate_crud_api(resource_module, singular_name, plural_name) do
    function_names = build_function_names(singular_name, plural_name)

    quote do
      (unquote_splicing(
         generate_crud_functions(
           resource_module,
           singular_name,
           plural_name,
           function_names
         )
       ))
    end
  end

  @spec build_function_names(term(), term()) :: term()
  defp build_function_names(singular_name, plural_name) do
    %{
      create: :"create_#{singular_name}",
      get: :"get_#{singular_name}",
      list: :"list_#{plural_name}",
      update: :"update_#{singular_name}",
      delete: :"delete_#{singular_name}"
    }
  end

  defp generate_crud_functions(resource_module, singular_name, plural_name, function_names) do
    [
      generate_create_function(resource_module, singular_name, function_names.create),
      generate_get_function(resource_module, singular_name, function_names.get),
      generate_list_function(resource_module, plural_name, function_names.list),
      generate_update_function(resource_module, singular_name, function_names.update),
      generate_delete_function(resource_module, singular_name, function_names.delete)
    ]
  end

  defp generate_create_function(resource_module, singular_name, function_name) do
    quote do
      @doc """
      Create a #{unquote(singular_name)}
      """
      @spec unquote(function_name)(map(), keyword()) :: any()
      def unquote(function_name)(attrs, opts \\ []) do
        unquote(__MODULE__).create_resource_function(unquote(resource_module)).(
          attrs,
          opts
        )
      end
    end
  end

  defp generate_get_function(resource_module, singular_name, function_name) do
    quote do
      @doc """
      Get a #{unquote(singular_name)} by ID
      """
      @spec unquote(function_name)(map(), keyword()) :: any()
      def unquote(function_name)(id, opts \\ []) do
        unquote(__MODULE__).get_resource_function(unquote(resource_module)).(
          id,
          opts
        )
      end
    end
  end

  defp generate_list_function(resource_module, plural_name, function_name) do
    quote do
      @doc """
      List all #{unquote(plural_name)}
      """
      @spec unquote(function_name)(map(), keyword()) :: any()
      def unquote(function_name)(opts \\ []) do
        unquote(__MODULE__).list_resources_function(unquote(resource_module)).(opts)
      end
    end
  end

  defp generate_update_function(resource_module, singular_name, function_name) do
    quote do
      @doc """
      Update a #{unquote(singular_name)}
      """
      @spec unquote(function_name)(map(), keyword()) :: any()
      def unquote(function_name)(resource, attrs, opts \\ []) do
        unquote(__MODULE__).update_resource_function(unquote(resource_module)).(
          resource,
          attrs,
          opts
        )
      end
    end
  end

  defp generate_delete_function(resource_module, singular_name, function_name) do
    quote do
      @doc """
      Delete a #{unquote(singular_name)}
      """
      @spec unquote(function_name)(map(), keyword()) :: any()
      def unquote(function_name)(resource, opts \\ []) do
        unquote(__MODULE__).delete_resource_function(unquote(resource_module)).(
          resource,
          opts
        )
      end
    end
  end

  @doc """
  Creates a batch operation function with error handling.

  ## Parameters
    - `resource_module` - The Ash resource module
    - `action_name` - The action to perform
    - `batch_size` - Number of items to process in each batch (default: 100)

  ## Returns
  Function that takes list of attrs and opts,
    returns {:ok, results} or {:error, reason}
  """
  @spec batch_create_function(module(), atom(), integer()) :: (list(map()), keyword() ->
                                                                 {:ok, list()} | {:error, any()})
  def batch_create_function(resource_module, action_name \\ :create, batch_size \\ 100) do
    fn attrs_list, opts ->
      try do
        results =
          attrs_list
          |> Enum.chunk_every(batch_size)
          |> Enum.flat_map(fn batch ->
            Enum.map(
              batch,
              fn attrs ->
                resource_module
                |> Ash.Changeset.for_create(
                  action_name,
                  attrs,
                  opts
                )
                |> Ash.create!()
              end
            )
          end)

        {:ok, results}
      rescue
        e -> {:error, e}
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [generate_crud_api: 3]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
