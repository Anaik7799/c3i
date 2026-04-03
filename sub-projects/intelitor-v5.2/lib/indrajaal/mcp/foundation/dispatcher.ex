defmodule Indrajaal.MCP.Foundation.Dispatcher do
  @moduledoc """
  MCP Request Dispatcher

  WHAT: Routes MCP requests to appropriate tool handlers
  WHY: Central dispatch point with safety checks and telemetry
  CONSTRAINTS: SC-MCP-040 (dispatch safety), SC-MCP-041 (audit logging)

  ## Dispatch Flow
  1. Parse and validate request
  2. Authenticate client
  3. Check rate limits
  4. Validate Guardian approval (if required)
  5. Validate proof token (if required)
  6. Execute tool handler
  7. Log to Immutable Register
  8. Return response

  ## STAMP Constraints
  - SC-MCP-040: All dispatches MUST pass safety checks
  - SC-MCP-041: All dispatches MUST be logged to audit trail
  - SC-MCP-042: Write operations MUST have Guardian approval
  - SC-MCP-043: State mutations MUST have PROMETHEUS proof token
  """

  require Logger

  alias Indrajaal.MCP.Foundation.{Protocol, Registry, Auth, Types}

  @doc """
  Dispatches an MCP request.

  ## Examples

      iex> Dispatcher.dispatch(%{method: "tools/list", ...}, %{auth: ...})
      {:ok, %{tools: [...]}}

  """
  @spec dispatch(Protocol.request(), map()) ::
          {:ok, term()} | {:error, Protocol.error_response()}
  def dispatch(request, context \\ %{}) do
    with {:ok, auth_info} <- authenticate(context),
         :ok <- check_rate_limit(auth_info.client_id),
         {:ok, result} <- route_request(request, auth_info) do
      log_dispatch(request, auth_info, :success)
      {:ok, result}
    else
      {:error, %{error: _} = error_response} ->
        log_dispatch(request, Map.get(context, :client_id, "unknown"), :error)
        {:error, error_response}

      {:error, reason} when is_binary(reason) ->
        log_dispatch(request, Map.get(context, :client_id, "unknown"), :error)
        {:error, Protocol.error_response(request.id, :internal_error, reason)}

      {:error, reason} ->
        log_dispatch(request, Map.get(context, :client_id, "unknown"), :error)
        {:error, Protocol.error_response(request.id, :internal_error, inspect(reason))}
    end
  end

  @doc """
  Dispatches a raw JSON request string.
  """
  @spec dispatch_raw(String.t(), map()) :: String.t()
  def dispatch_raw(raw_json, context \\ %{}) do
    case Protocol.parse_request(raw_json) do
      {:ok, request} ->
        case dispatch(request, context) do
          {:ok, result} ->
            request.id
            |> Protocol.success_response(result)
            |> Protocol.encode_response()

          {:error, error_response} ->
            Protocol.encode_response(error_response)
        end

      {:error, error_response} ->
        Protocol.encode_response(error_response)
    end
  end

  # Private functions

  defp authenticate(context) do
    case Map.get(context, :headers) do
      nil ->
        # No headers, use anonymous client
        {:ok, %{client_id: "anonymous", permissions: [:read], tier: :basic}}

      headers ->
        Auth.authenticate(headers)
    end
  end

  defp check_rate_limit(client_id) do
    case Auth.check_rate_limit(client_id) do
      :ok ->
        :ok

      {:error, :rate_limit_exceeded} ->
        {:error,
         Protocol.error_response(
           nil,
           :rate_limit_exceeded,
           "Rate limit exceeded. Try again later."
         )}
    end
  end

  defp route_request(request, auth_info) do
    case request.method do
      # MCP lifecycle methods
      "initialize" ->
        handle_initialize(request, auth_info)

      "initialized" ->
        {:ok, %{}}

      "ping" ->
        {:ok, %{}}

      # Tool methods
      "tools/list" ->
        handle_tools_list(request, auth_info)

      "tools/call" ->
        handle_tools_call(request, auth_info)

      # Resource methods
      "resources/list" ->
        handle_resources_list(request, auth_info)

      "resources/read" ->
        handle_resources_read(request, auth_info)

      "resources/subscribe" ->
        handle_resources_subscribe(request, auth_info)

      # Prompt methods
      "prompts/list" ->
        handle_prompts_list(request, auth_info)

      "prompts/get" ->
        handle_prompts_get(request, auth_info)

      # Completion methods
      "completion/complete" ->
        handle_completion(request, auth_info)

      # Unknown method
      _ ->
        {:error,
         Protocol.error_response(
           request.id,
           :method_not_found,
           "Unknown method: #{request.method}"
         )}
    end
  end

  # Handler implementations

  defp handle_initialize(request, _auth_info) do
    server_info = %{
      name: "indrajaal-mcp",
      version: "1.0.0",
      description: "Indrajaal Cybernetic Fractal Security System MCP Server"
    }

    {:ok, Protocol.initialize_response(request.id, server_info).result}
  end

  defp handle_tools_list(request, _auth_info) do
    namespace =
      case request.params do
        %{"namespace" => ns} -> String.to_atom(ns)
        %{namespace: ns} -> ns
        _ -> nil
      end

    tools = Registry.list_mcp_format(namespace)
    {:ok, %{tools: tools}}
  end

  defp handle_tools_call(request, auth_info) do
    params = request.params || %{}
    tool_name = Map.get(params, "name") || Map.get(params, :name)
    tool_args = Map.get(params, "arguments") || Map.get(params, :arguments) || %{}

    with {:ok, tool_schema} <- get_tool(tool_name),
         :ok <- check_permissions(tool_schema, auth_info),
         :ok <- check_guardian_if_required(tool_schema, params),
         :ok <- check_proof_token_if_required(tool_schema, params),
         {:ok, validated_args} <- Registry.validate_args(tool_name, tool_args),
         {:ok, result} <- execute_tool(tool_name, validated_args, auth_info) do
      {:ok, format_tool_result(result)}
    else
      {:error, :not_found} ->
        {:error,
         Protocol.error_response(request.id, :method_not_found, "Tool not found: #{tool_name}")}

      {:error, %{error: _} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error, Protocol.error_response(request.id, :internal_error, to_string(reason))}
    end
  end

  defp handle_resources_list(_request, _auth_info) do
    # Return available resources (holon state, metrics, etc.)
    resources = [
      %{
        uri: "indrajaal://holons",
        name: "Holon State",
        description: "Current holon state from SQLite",
        mimeType: "application/json"
      },
      %{
        uri: "indrajaal://metrics",
        name: "System Metrics",
        description: "Real-time system metrics",
        mimeType: "application/json"
      },
      %{
        uri: "indrajaal://sentinel",
        name: "Sentinel Health",
        description: "Sentinel health status",
        mimeType: "application/json"
      }
    ]

    {:ok, %{resources: resources}}
  end

  defp handle_resources_read(request, _auth_info) do
    params = request.params || %{}
    uri = Map.get(params, "uri") || Map.get(params, :uri)

    case uri do
      "indrajaal://holons" ->
        {:ok, %{contents: [%{uri: uri, mimeType: "application/json", text: "{}"}]}}

      "indrajaal://metrics" ->
        {:ok, %{contents: [%{uri: uri, mimeType: "application/json", text: "{}"}]}}

      "indrajaal://sentinel" ->
        {:ok, %{contents: [%{uri: uri, mimeType: "application/json", text: "{}"}]}}

      _ ->
        {:error, Protocol.error_response(request.id, :invalid_params, "Unknown resource: #{uri}")}
    end
  end

  defp handle_resources_subscribe(request, _auth_info) do
    params = request.params || %{}
    uri = Map.get(params, "uri") || Map.get(params, :uri)

    # Register subscription (would integrate with PubSub)
    Logger.info("Subscribed to resource: #{uri}")
    {:ok, %{}}
  end

  defp handle_prompts_list(_request, _auth_info) do
    prompts = [
      %{
        name: "analyze_alarm",
        description: "Analyze an alarm event for root cause",
        arguments: [
          %{name: "alarm_id", description: "The alarm ID to analyze", required: true}
        ]
      },
      %{
        name: "generate_report",
        description: "Generate a compliance report",
        arguments: [
          %{name: "report_type", description: "Type of report", required: true},
          %{name: "date_range", description: "Date range for report", required: false}
        ]
      }
    ]

    {:ok, %{prompts: prompts}}
  end

  defp handle_prompts_get(request, _auth_info) do
    params = request.params || %{}
    prompt_name = Map.get(params, "name") || Map.get(params, :name)
    arguments = Map.get(params, "arguments") || Map.get(params, :arguments) || %{}

    case prompt_name do
      "analyze_alarm" ->
        alarm_id = Map.get(arguments, "alarm_id") || Map.get(arguments, :alarm_id)

        {:ok,
         %{
           description: "Analyze alarm #{alarm_id}",
           messages: [
             %{
               role: "user",
               content: %{
                 type: "text",
                 text: "Analyze alarm #{alarm_id} and identify root cause."
               }
             }
           ]
         }}

      "generate_report" ->
        report_type = Map.get(arguments, "report_type") || Map.get(arguments, :report_type)

        {:ok,
         %{
           description: "Generate #{report_type} report",
           messages: [
             %{
               role: "user",
               content: %{
                 type: "text",
                 text: "Generate a #{report_type} compliance report."
               }
             }
           ]
         }}

      _ ->
        {:error,
         Protocol.error_response(request.id, :invalid_params, "Unknown prompt: #{prompt_name}")}
    end
  end

  defp handle_completion(request, _auth_info) do
    params = request.params || %{}
    _ref = Map.get(params, "ref") || Map.get(params, :ref)
    _argument = Map.get(params, "argument") || Map.get(params, :argument)

    # Return completion suggestions
    {:ok, %{completion: %{values: [], total: 0, hasMore: false}}}
  end

  defp get_tool(nil), do: {:error, :not_found}

  defp get_tool(tool_name) do
    Registry.get(tool_name)
  end

  defp check_permissions(tool_schema, auth_info) do
    required_permission =
      if Types.requires_guardian?(tool_schema) do
        :write
      else
        :read
      end

    if required_permission in auth_info.permissions do
      :ok
    else
      {:error, Protocol.error_response(nil, :guardian_veto, "Insufficient permissions")}
    end
  end

  defp check_guardian_if_required(tool_schema, params) do
    if Types.requires_guardian?(tool_schema) do
      approval_token =
        Map.get(params, "guardian_approval") ||
          Map.get(params, :guardian_approval)

      case Auth.validate_guardian_approval(approval_token) do
        {:ok, _approval} -> :ok
        {:error, reason} -> {:error, Protocol.error_response(nil, :guardian_veto, reason)}
      end
    else
      :ok
    end
  end

  defp check_proof_token_if_required(tool_schema, params) do
    if Types.requires_proof_token?(tool_schema) do
      proof_token =
        Map.get(params, "proof_token") ||
          Map.get(params, :proof_token)

      case Auth.validate_proof_token(proof_token) do
        {:ok, _proof} -> :ok
        {:error, reason} -> {:error, Protocol.error_response(nil, :proof_token_required, reason)}
      end
    else
      :ok
    end
  end

  defp execute_tool(tool_name, args, auth_info) do
    # Route to appropriate handler module based on namespace
    namespace = Types.extract_namespace(tool_name)
    domain = Types.extract_domain(tool_name)
    action = Types.extract_action(tool_name)

    context = Types.new_execution_context(auth_info.client_id, make_ref(), actor: auth_info)

    handler_module = get_handler_module(namespace, domain)

    if handler_module && function_exported?(handler_module, :handle, 3) do
      handler_module.handle(action, args, context)
    else
      # Fallback for unimplemented handlers
      {:ok,
       %{
         status: "not_implemented",
         tool: tool_name,
         message: "Handler not yet implemented for #{tool_name}"
       }}
    end
  end

  defp get_handler_module(namespace, domain) do
    case namespace do
      :indrajaal ->
        Module.concat([Indrajaal.MCP.Domains, Macro.camelize(to_string(domain)), Handler])

      :prajna ->
        Module.concat([Indrajaal.MCP.Prajna, Macro.camelize(to_string(domain)), Handler])

      :cepaf ->
        Module.concat([Indrajaal.MCP.Cepaf, Macro.camelize(to_string(domain)), Handler])

      :kms ->
        Module.concat([Indrajaal.MCP.Kms, Macro.camelize(to_string(domain)), Handler])

      _ ->
        nil
    end
  end

  defp format_tool_result(result) do
    content =
      cond do
        is_binary(result) ->
          [%{type: "text", text: result}]

        is_map(result) ->
          [%{type: "text", text: Jason.encode!(result, pretty: true)}]

        true ->
          [%{type: "text", text: inspect(result, pretty: true)}]
      end

    %{content: content, isError: false}
  end

  defp log_dispatch(request, auth_info, status) when is_map(auth_info) do
    log_dispatch(request, auth_info.client_id, status)
  end

  defp log_dispatch(request, client_id, status) do
    Logger.debug("MCP dispatch: method=#{request.method} client=#{client_id} status=#{status}")

    # Would also log to Immutable Register for audit
    :telemetry.execute(
      [:mcp, :dispatch],
      %{count: 1},
      %{
        method: request.method,
        client_id: client_id,
        status: status,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
end
