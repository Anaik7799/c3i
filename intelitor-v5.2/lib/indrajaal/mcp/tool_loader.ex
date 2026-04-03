defmodule Indrajaal.MCP.ToolLoader do
  @moduledoc """
  MCP Tool Loader - Registers all domain tools at startup

  WHAT: Loads and registers all MCP tools from domain handlers
  WHY: Centralized tool registration for discovery and dispatch
  CONSTRAINTS: SC-MCP-080 (registration at startup)

  ## Tool Namespaces
  - indrajaal.*: Domain-specific tools (180+ planned)
  - prajna.*: C3I cockpit tools (85+ planned)
  - cepaf.*: F# integration tools (65+ planned)
  - kms.*: Knowledge management tools (14+ planned)

  ## STAMP Constraints
  - SC-MCP-080: All tools MUST be registered at startup
  - SC-MCP-081: Registration failures MUST be logged
  - SC-MCP-082: Tool counts MUST be reported
  """

  require Logger

  alias Indrajaal.MCP.Foundation.Registry

  @domain_handlers [
    # Indrajaal Domains (16 handlers, 154 tools)
    Indrajaal.MCP.Domains.Accounts.Handler,
    Indrajaal.MCP.Domains.AccessControl.Handler,
    Indrajaal.MCP.Domains.Alarms.Handler,
    Indrajaal.MCP.Domains.Analytics.Handler,
    Indrajaal.MCP.Domains.Billing.Handler,
    Indrajaal.MCP.Domains.Communication.Handler,
    Indrajaal.MCP.Domains.Compliance.Handler,
    Indrajaal.MCP.Domains.Devices.Handler,
    Indrajaal.MCP.Domains.Dispatch.Handler,
    Indrajaal.MCP.Domains.Health.Handler,
    Indrajaal.MCP.Domains.Identity.Handler,
    Indrajaal.MCP.Domains.Maintenance.Handler,
    Indrajaal.MCP.Domains.Policy.Handler,
    Indrajaal.MCP.Domains.Security.Handler,
    Indrajaal.MCP.Domains.Sites.Handler,
    Indrajaal.MCP.Domains.Video.Handler
  ]

  @prajna_handlers [
    # Prajna C3I
    Indrajaal.MCP.Prajna.Guardian.Handler,
    Indrajaal.MCP.Prajna.Sentinel.Handler,
    Indrajaal.MCP.Prajna.AiCopilot.Handler,
    Indrajaal.MCP.Prajna.Prometheus.Handler,
    Indrajaal.MCP.Prajna.SmartMetrics.Handler,
    Indrajaal.MCP.Prajna.ImmutableRegister.Handler,
    Indrajaal.MCP.Prajna.Health.Handler
  ]

  @cepaf_handlers [
    # CEPAF F# integration - to be added
  ]

  @kms_handlers [
    # KMS - to be added
  ]

  @doc """
  Loads all domain tools into the registry.
  """
  @spec load_all() :: {:ok, map()} | {:error, term()}
  def load_all do
    Logger.info("Loading MCP tools...")

    all_handlers = @domain_handlers ++ @prajna_handlers ++ @cepaf_handlers ++ @kms_handlers

    results =
      all_handlers
      |> Enum.map(&load_handler/1)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    success_count = Map.get(results, :ok, []) |> List.flatten() |> length()
    error_count = Map.get(results, :error, []) |> length()

    counts = Registry.count_by_namespace()

    Logger.info("MCP tool loading complete: #{success_count} tools loaded, #{error_count} errors")
    Logger.info("Tools by namespace: #{inspect(counts)}")

    if error_count > 0 do
      errors = Map.get(results, :error, [])
      Logger.warning("Failed to load some tools: #{inspect(errors)}")
    end

    {:ok,
     %{
       total_loaded: success_count,
       errors: error_count,
       by_namespace: counts
     }}
  end

  @doc """
  Loads tools from a specific handler module.
  """
  @spec load_handler(module()) :: {:ok, list()} | {:error, term()}
  def load_handler(handler_module) do
    if Code.ensure_loaded?(handler_module) and function_exported?(handler_module, :list_tools, 0) do
      tools = handler_module.list_tools()

      case Registry.register_all(tools) do
        :ok ->
          Logger.debug("Loaded #{length(tools)} tools from #{handler_module}")
          {:ok, tools}

        {:error, reason} ->
          Logger.warning("Failed to load tools from #{handler_module}: #{reason}")
          {:error, {handler_module, reason}}
      end
    else
      Logger.debug("Handler #{handler_module} not available or missing list_tools/0")
      {:ok, []}
    end
  end

  @doc """
  Returns all handler modules.
  """
  @spec handlers() :: list(module())
  def handlers do
    @domain_handlers ++ @prajna_handlers ++ @cepaf_handlers ++ @kms_handlers
  end

  @doc """
  Returns handler counts by category.
  """
  @spec handler_counts() :: map()
  def handler_counts do
    %{
      indrajaal: length(@domain_handlers),
      prajna: length(@prajna_handlers),
      cepaf: length(@cepaf_handlers),
      kms: length(@kms_handlers),
      total: length(handlers())
    }
  end
end
