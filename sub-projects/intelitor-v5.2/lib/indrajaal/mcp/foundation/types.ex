defmodule Indrajaal.MCP.Foundation.Types do
  @moduledoc """
  MCP Core Type Definitions

  WHAT: Type specifications for MCP tools, resources, and operations
  WHY: Ensures type safety and schema validation across all MCP components
  CONSTRAINTS: SC-MCP-010 (type safety), SC-MCP-011 (schema validation)

  ## Tool Categories
  - **indrajaal.***: Domain-specific tools (180 tools)
  - **prajna.***: C3I cockpit tools (85 tools)
  - **cepaf.***: F# integration tools (65 tools)
  - **kms.***: Knowledge management tools (14 tools)

  ## STAMP Constraints
  - SC-MCP-010: All tools MUST have typed schemas
  - SC-MCP-011: Arguments MUST be validated before execution
  - SC-MCP-012: Results MUST conform to declared types
  """

  # Tool struct definition
  defmodule Tool do
    @moduledoc """
    MCP Tool definition struct.

    Used by domain handlers to define available tools.
    """
    defstruct [
      :name,
      :description,
      :input_schema,
      :namespace,
      requires_guardian: false,
      requires_proof_token: false,
      rate_limit: nil
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            description: String.t(),
            input_schema: map(),
            namespace: atom(),
            requires_guardian: boolean(),
            requires_proof_token: boolean(),
            rate_limit: map() | nil
          }
  end

  # Tool schema definition
  @type tool_schema :: %{
          name: String.t(),
          description: String.t(),
          inputSchema: json_schema(),
          namespace: atom(),
          requires_guardian: boolean(),
          requires_proof_token: boolean(),
          rate_limit: rate_limit_config()
        }

  @type json_schema :: %{
          type: String.t(),
          properties: map(),
          required: list(String.t())
        }

  @type rate_limit_config :: %{
          window_ms: non_neg_integer(),
          max_requests: non_neg_integer()
        }

  # Resource types
  @type resource :: %{
          uri: String.t(),
          name: String.t(),
          description: String.t(),
          mimeType: String.t()
        }

  # Prompt types
  @type prompt :: %{
          name: String.t(),
          description: String.t(),
          arguments: list(prompt_argument())
        }

  @type prompt_argument :: %{
          name: String.t(),
          description: String.t(),
          required: boolean()
        }

  # Execution context
  @type execution_context :: %{
          client_id: String.t(),
          request_id: String.t() | integer(),
          timestamp: DateTime.t(),
          guardian_approval: guardian_approval() | nil,
          proof_token: String.t() | nil,
          actor: map() | nil
        }

  @type guardian_approval :: %{
          approved: boolean(),
          approver: String.t(),
          timestamp: DateTime.t(),
          reason: String.t() | nil
        }

  # Namespace definitions
  @namespaces [:indrajaal, :prajna, :cepaf, :kms]

  # Domain mappings for indrajaal namespace
  @indrajaal_domains [
    :accounts,
    :alarms,
    :access_control,
    :authentication,
    :authorization,
    :communication,
    :compliance,
    :devices,
    :dispatch,
    :maintenance,
    :observability,
    :policies,
    :safety,
    :sites,
    :video
  ]

  # Prajna capability mappings
  @prajna_capabilities [
    :guardian,
    :sentinel,
    :prometheus,
    :ai_copilot,
    :smart_metrics,
    :immutable_register,
    :founder_directive,
    :immune_system,
    :pattern_hunter,
    :symbiotic_defense,
    :mara,
    :antibody
  ]

  # CEPAF module mappings
  @cepaf_modules [
    :arrows,
    :comonads,
    :optics,
    :category_theory,
    :ooda_controller,
    :aor_engine,
    :zenoh_session,
    :health_propagation,
    :quadplex_logger,
    :material3,
    :prajna_cockpit
  ]

  @doc """
  Returns all supported namespaces.
  """
  @spec namespaces() :: list(atom())
  def namespaces, do: @namespaces

  @doc """
  Returns all Indrajaal domains.
  """
  @spec indrajaal_domains() :: list(atom())
  def indrajaal_domains, do: @indrajaal_domains

  @doc """
  Returns all Prajna capabilities.
  """
  @spec prajna_capabilities() :: list(atom())
  def prajna_capabilities, do: @prajna_capabilities

  @doc """
  Returns all CEPAF modules.
  """
  @spec cepaf_modules() :: list(atom())
  def cepaf_modules, do: @cepaf_modules

  @doc """
  Creates a new tool schema.

  ## Examples

      iex> Types.new_tool_schema("indrajaal.accounts.list", "List all accounts", %{})
      %{name: "indrajaal.accounts.list", ...}

  """
  @spec new_tool_schema(String.t(), String.t(), map(), keyword()) :: tool_schema()
  def new_tool_schema(name, description, input_schema, opts \\ []) do
    namespace = extract_namespace(name)

    %{
      name: name,
      description: description,
      inputSchema: normalize_input_schema(input_schema),
      namespace: namespace,
      requires_guardian: Keyword.get(opts, :requires_guardian, false),
      requires_proof_token: Keyword.get(opts, :requires_proof_token, false),
      rate_limit: Keyword.get(opts, :rate_limit, default_rate_limit())
    }
  end

  @doc """
  Creates an execution context for a request.
  """
  @spec new_execution_context(String.t(), String.t() | integer(), keyword()) ::
          execution_context()
  def new_execution_context(client_id, request_id, opts \\ []) do
    %{
      client_id: client_id,
      request_id: request_id,
      timestamp: DateTime.utc_now(),
      guardian_approval: Keyword.get(opts, :guardian_approval),
      proof_token: Keyword.get(opts, :proof_token),
      actor: Keyword.get(opts, :actor)
    }
  end

  @doc """
  Validates tool arguments against the schema.
  """
  @spec validate_args(tool_schema(), map()) :: {:ok, map()} | {:error, String.t()}
  def validate_args(tool_schema, args) do
    schema = tool_schema.inputSchema

    with :ok <- validate_required_fields(schema, args),
         :ok <- validate_field_types(schema, args) do
      {:ok, args}
    end
  end

  @doc """
  Checks if a tool requires Guardian approval.
  """
  @spec requires_guardian?(tool_schema()) :: boolean()
  def requires_guardian?(tool_schema), do: tool_schema.requires_guardian

  @doc """
  Checks if a tool requires a PROMETHEUS proof token.
  """
  @spec requires_proof_token?(tool_schema()) :: boolean()
  def requires_proof_token?(tool_schema), do: tool_schema.requires_proof_token

  @doc """
  Extracts namespace from a fully-qualified tool name.

  ## Examples

      iex> Types.extract_namespace("indrajaal.accounts.list")
      :indrajaal

      iex> Types.extract_namespace("prajna.guardian.propose")
      :prajna

  """
  @spec extract_namespace(String.t()) :: atom()
  def extract_namespace(tool_name) do
    tool_name
    |> String.split(".")
    |> List.first()
    |> String.to_atom()
  end

  @doc """
  Extracts domain/capability from a fully-qualified tool name.

  ## Examples

      iex> Types.extract_domain("indrajaal.accounts.list")
      :accounts

  """
  @spec extract_domain(String.t()) :: atom()
  def extract_domain(tool_name) do
    tool_name
    |> String.split(".")
    |> Enum.at(1, "unknown")
    |> String.to_atom()
  end

  @doc """
  Extracts action from a fully-qualified tool name.

  ## Examples

      iex> Types.extract_action("indrajaal.accounts.list")
      :list

  """
  @spec extract_action(String.t()) :: atom()
  def extract_action(tool_name) do
    tool_name
    |> String.split(".")
    |> Enum.at(2, "unknown")
    |> String.to_atom()
  end

  # Private functions

  defp normalize_input_schema(schema) when is_map(schema) do
    %{
      type: Map.get(schema, :type, Map.get(schema, "type", "object")),
      properties: Map.get(schema, :properties, Map.get(schema, "properties", %{})),
      required: Map.get(schema, :required, Map.get(schema, "required", []))
    }
  end

  defp default_rate_limit do
    %{
      window_ms: 60_000,
      max_requests: 100
    }
  end

  defp validate_required_fields(schema, args) do
    required = schema.required || []

    missing =
      Enum.filter(required, fn field ->
        not Map.has_key?(args, field) and not Map.has_key?(args, String.to_atom(field))
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_field_types(schema, args) do
    properties = schema.properties || %{}

    errors =
      Enum.reduce(properties, [], fn {field, spec}, acc ->
        value = Map.get(args, field) || Map.get(args, String.to_atom(field))

        if value != nil do
          case validate_type(value, spec) do
            :ok -> acc
            {:error, msg} -> [{field, msg} | acc]
          end
        else
          acc
        end
      end)

    if Enum.empty?(errors) do
      :ok
    else
      error_msg =
        errors
        |> Enum.map(fn {field, msg} -> "#{field}: #{msg}" end)
        |> Enum.join("; ")

      {:error, "Type validation failed: #{error_msg}"}
    end
  end

  defp validate_type(value, %{"type" => "string"}) when is_binary(value), do: :ok
  defp validate_type(value, %{"type" => "integer"}) when is_integer(value), do: :ok
  defp validate_type(value, %{"type" => "number"}) when is_number(value), do: :ok
  defp validate_type(value, %{"type" => "boolean"}) when is_boolean(value), do: :ok
  defp validate_type(value, %{"type" => "array"}) when is_list(value), do: :ok
  defp validate_type(value, %{"type" => "object"}) when is_map(value), do: :ok
  defp validate_type(value, %{type: type}), do: validate_type(value, %{"type" => to_string(type)})
  defp validate_type(_value, %{"type" => type}), do: {:error, "expected #{type}"}
  defp validate_type(_value, _spec), do: :ok
end
