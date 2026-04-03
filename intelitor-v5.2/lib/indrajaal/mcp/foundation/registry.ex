defmodule Indrajaal.MCP.Foundation.Registry do
  @moduledoc """
  MCP Tool Registry

  WHAT: Central registry for all MCP tools with schema validation
  WHY: Enables tool discovery, validation, and routing
  CONSTRAINTS: SC-MCP-020 (registry integrity), SC-MCP-021 (schema validation)

  ## Tool Namespaces
  - `indrajaal.*`: 180 domain-specific tools
  - `prajna.*`: 85 C3I cockpit tools
  - `cepaf.*`: 65 F# integration tools
  - `kms.*`: 14 knowledge management tools

  ## STAMP Constraints
  - SC-MCP-020: Registry MUST maintain referential integrity
  - SC-MCP-021: All tools MUST have valid schemas
  - SC-MCP-022: Tool names MUST be unique across all namespaces
  - SC-MCP-023: Registry changes MUST be logged to Immutable Register
  """

  use GenServer
  require Logger

  alias Indrajaal.MCP.Foundation.Types

  @table_name :mcp_tool_registry

  # Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new tool in the registry.

  ## Examples

      iex> Registry.register(%{name: "indrajaal.accounts.list", ...})
      :ok

  """
  @spec register(Types.tool_schema()) :: :ok | {:error, String.t()}
  def register(tool_schema) do
    GenServer.call(__MODULE__, {:register, tool_schema})
  end

  @doc """
  Registers multiple tools at once.
  """
  @spec register_all(list(Types.tool_schema())) :: :ok | {:error, String.t()}
  def register_all(tools) do
    GenServer.call(__MODULE__, {:register_all, tools})
  end

  @doc """
  Gets a tool by name.

  ## Examples

      iex> Registry.get("indrajaal.accounts.list")
      {:ok, %{name: "indrajaal.accounts.list", ...}}

  """
  @spec get(String.t()) :: {:ok, Types.tool_schema()} | {:error, :not_found}
  def get(tool_name) do
    case :ets.lookup(@table_name, tool_name) do
      [{^tool_name, tool_schema}] -> {:ok, tool_schema}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all tools, optionally filtered by namespace.

  ## Examples

      iex> Registry.list(:indrajaal)
      [%{name: "indrajaal.accounts.list", ...}, ...]

      iex> Registry.list()
      [...]  # All tools

  """
  @spec list(atom() | nil) :: list(Types.tool_schema())
  def list(namespace \\ nil) do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_name, schema} -> schema end)
    |> filter_by_namespace(namespace)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Lists all tools in MCP format (for tools/list response).
  """
  @spec list_mcp_format(atom() | nil) :: list(map())
  def list_mcp_format(namespace \\ nil) do
    list(namespace)
    |> Enum.map(&to_mcp_format/1)
  end

  @doc """
  Validates arguments for a tool.
  """
  @spec validate_args(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def validate_args(tool_name, args) do
    case get(tool_name) do
      {:ok, tool_schema} ->
        Types.validate_args(tool_schema, args)

      {:error, :not_found} ->
        {:error, "Tool not found: #{tool_name}"}
    end
  end

  @doc """
  Checks if a tool exists.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(tool_name) do
    case get(tool_name) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Checks if a tool requires Guardian approval.
  """
  @spec requires_guardian?(String.t()) :: boolean()
  def requires_guardian?(tool_name) do
    case get(tool_name) do
      {:ok, tool_schema} -> Types.requires_guardian?(tool_schema)
      {:error, :not_found} -> false
    end
  end

  @doc """
  Checks if a tool requires a PROMETHEUS proof token.
  """
  @spec requires_proof_token?(String.t()) :: boolean()
  def requires_proof_token?(tool_name) do
    case get(tool_name) do
      {:ok, tool_schema} -> Types.requires_proof_token?(tool_schema)
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gets the count of registered tools.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Gets counts by namespace.
  """
  @spec count_by_namespace() :: map()
  def count_by_namespace do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_name, schema} -> schema.namespace end)
    |> Enum.frequencies()
  end

  @doc """
  Unregisters a tool.
  """
  @spec unregister(String.t()) :: :ok
  def unregister(tool_name) do
    GenServer.call(__MODULE__, {:unregister, tool_name})
  end

  @doc """
  Clears all registered tools.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, tool_schema}, _from, state) do
    result = do_register(tool_schema)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:register_all, tools}, _from, state) do
    results =
      Enum.map(tools, fn tool ->
        {tool.name, do_register(tool)}
      end)

    errors = Enum.filter(results, fn {_name, result} -> result != :ok end)

    if Enum.empty?(errors) do
      {:reply, :ok, state}
    else
      error_msg =
        errors
        |> Enum.map(fn {name, {:error, msg}} -> "#{name}: #{msg}" end)
        |> Enum.join("; ")

      {:reply, {:error, error_msg}, state}
    end
  end

  @impl true
  def handle_call({:unregister, tool_name}, _from, state) do
    :ets.delete(@table_name, tool_name)
    Logger.debug("Unregistered MCP tool: #{tool_name}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.info("Cleared all MCP tools from registry")
    {:reply, :ok, state}
  end

  # Private functions

  defp do_register(tool_schema) do
    with :ok <- validate_tool_schema(tool_schema),
         :ok <- check_uniqueness(tool_schema.name) do
      :ets.insert(@table_name, {tool_schema.name, tool_schema})
      Logger.debug("Registered MCP tool: #{tool_schema.name}")
      :ok
    end
  end

  defp validate_tool_schema(schema) do
    cond do
      not is_binary(schema.name) or byte_size(schema.name) == 0 ->
        {:error, "Tool name must be a non-empty string"}

      not is_binary(schema.description) ->
        {:error, "Tool description must be a string"}

      not is_map(schema.inputSchema) ->
        {:error, "Input schema must be a map"}

      not is_atom(schema.namespace) ->
        {:error, "Namespace must be an atom"}

      schema.namespace not in Types.namespaces() ->
        {:error, "Unknown namespace: #{schema.namespace}"}

      true ->
        :ok
    end
  end

  defp check_uniqueness(tool_name) do
    case :ets.lookup(@table_name, tool_name) do
      [] -> :ok
      [_] -> {:error, "Tool already registered: #{tool_name}"}
    end
  end

  defp filter_by_namespace(tools, nil), do: tools

  defp filter_by_namespace(tools, namespace) do
    Enum.filter(tools, fn tool -> tool.namespace == namespace end)
  end

  defp to_mcp_format(tool_schema) do
    %{
      name: tool_schema.name,
      description: tool_schema.description,
      inputSchema: tool_schema.inputSchema
    }
  end
end
