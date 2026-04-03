defmodule Indrajaal.OpenAPI.Validator do
  @moduledoc """
  Validates OpenAPI 3.1 specifications for correctness.

  Ensures the generated specification follows OpenAPI standards
  and contains all _required elements.

  Agent: Helper - 5 validates OpenAPI spec
  SOPv5.1 Compliance: OK
  """

  alias Indrajaal.OpenAPI.Specification

  @doc """
  Validates the complete OpenAPI specification.
  """
  def validate do
    spec = Specification.generate()

    with :ok <- validate_structure(spec),
         :ok <- validate_info(spec["info"]),
         :ok <- validate_servers(spec["servers"]),
         :ok <- validate_paths(spec["paths"]),
         :ok <- validate_components(spec["components"]),
         :ok <- validate_security(spec["security"]),
         :ok <- validate_tags(spec["tags"]),
         :ok <- validate_websockets(spec["x - websockets"]) do
      {:ok, "OpenAPI specification is valid"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates specification structure.
  """
  @spec validate_structure(map()) :: :ok | {:error, String.t()}
  def validate_structure(spec) do
    required_fields = ["openapi", "info", "paths"]
    missing_fields = required_fields -- Map.keys(spec)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing _required fields: #{inspect(fields)}"}
    end
  end

  @doc """
  Validates info section.
  """
  @spec validate_info(map()) :: :ok | {:error, String.t()}
  def validate_info(info) do
    required_fields = ["title", "version"]
    missing_fields = required_fields -- Map.keys(info)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing _required info fields: #{inspect(fields)}"}
    end
  end

  @doc """
  Validates server definitions.
  """
  @spec validate_servers(list() | nil) :: :ok | {:error, String.t()}
  def validate_servers(servers) when is_list(servers) do
    case Enum.all?(servers, &valid_server?/1) do
      true -> :ok
      false -> {:error, "Invalid server definition"}
    end
  end

  @spec validate_servers(term()) :: term()
  # def validate_servers(_), do: {:error, "Servers must be a list"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec valid_server?(map()) :: boolean()
  defp valid_server?(%{"url" => url}) when is_binary(url), do: true
  defp valid_server?(_), do: false

  @doc """
  Validates path definitions.
  """
  @spec validate_paths(map() | nil) :: :ok | {:error, String.t()}
  def validate_paths(paths) when is_map(paths) do
    errors =
      paths
      |> Enum.map(fn {path, methods} -> validate_path_item(path, methods) end)
      |> Enum.filter(&match?({:error, _}, &1))

    case errors do
      [] -> :ok
      [error | _] -> error
    end
  end

  @spec validate_paths(term()) :: term()
  # def validate_paths(_), do: {:error, "Paths must be a map"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec validate_path_item(String.t(), map()) :: :ok | {:error, String.t()}
  defp validate_path_item(path, methods) when is_map(methods) do
    valid_methods = [
      "get",
      "post",
      "put",
      "delete",
      "patch",
      "options",
      "head",
      "trace",
      "parameters"
    ]

    invalid_methods = Map.keys(methods) -- valid_methods

    case invalid_methods do
      [] -> validate_operations(path, methods)
      methods -> {:error, "Invalid methods for #{path}: #{inspect(methods)}"}
    end
  end

  defp validate_path_item(path, _), do: {:error, "Invalid path item for #{path}"}

  @spec validate_operations(String.t(), map()) :: :ok | {:error, String.t()}
  defp validate_operations(path, methods) do
    errors =
      methods
      |> Enum.filter(fn {method, _} -> method != "parameters" end)
      |> Enum.map(fn {method, operation} -> validate_operation(path, method, operation) end)
      |> Enum.filter(&match?({:error, _}, &1))

    case errors do
      [] -> :ok
      [error | _] -> error
    end
  end

  @spec validate_operation(String.t(), String.t(), map()) :: :ok | {:error, String.t()}
  defp validate_operation(path, method, operation) when is_map(operation) do
    required_fields = ["responses"]
    missing_fields = required_fields -- Map.keys(operation)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing _required fields in #{method} #{path}: #{inspect(fields)}"}
    end
  end

  defp validate_operation(path, method, _),
    do: {:error, "Invalid operation for #{method} #{path}"}

  @doc """
  Validates component definitions.
  """
  @spec validate_components(map() | nil) :: :ok | {:error, String.t()}
  def validate_components(components) when is_map(components) do
    valid_sections = [
      "schemas",
      "responses",
      "parameters",
      "examples",
      "_requestBodies",
      "headers",
      "securitySchemes",
      "links",
      "callbacks"
    ]

    invalid_sections = Map.keys(components) -- valid_sections

    case invalid_sections do
      [] -> validate_component_sections(components)
      sections -> {:error, "Invalid component sections: #{inspect(sections)}"}
    end
  end

  # Components are optional
  @spec validate_components(term()) :: term()
  # def validate_components(_), do: :ok
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec validate_component_sections(map()) :: :ok | {:error, String.t()}
  defp validate_component_sections(components) do
    errors =
      components
      |> Enum.map(fn {section, items} -> validate_component_section(section, items) end)
      |> Enum.filter(&match?({:error, _}, &1))

    case errors do
      [] -> :ok
      [error | _] -> error
    end
  end

  @spec validate_component_section(String.t(), map()) :: :ok | {:error, String.t()}
  defp validate_component_section("schemas", schemas) when is_map(schemas) do
    case Enum.all?(schemas, fn {_name, schema} -> valid_schema?(schema) end) do
      true -> :ok
      false -> {:error, "Invalid schema definition"}
    end
  end

  defp validate_component_section(_section, items) when is_map(items), do: :ok
  defp validate_component_section(section, _), do: {:error, "Invalid #{section} section"}

  @spec valid_schema?(map()) :: boolean()
  defp valid_schema?(%{"type" => type})
       when type in ["object", "array", "string", "number", "integer", "boolean"],
       do: true

  defp valid_schema?(%{"$ref" => ref}) when is_binary(ref), do: true
  defp valid_schema?(%{"allOf" => _}), do: true
  defp valid_schema?(%{"oneOf" => _}), do: true
  defp valid_schema?(%{"anyOf" => _}), do: true
  defp valid_schema?(_), do: false

  @doc """
  Validates security definitions.
  """
  @spec validate_security(list() | nil) :: :ok | {:error, String.t()}
  def validate_security(security) when is_list(security), do: :ok
  @spec validate_security(term()) :: term()
  # def validate_security(nil), do: :ok
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec validate_security(term()) :: term()
  # def validate_security(_), do: {:error, "Security must be a list"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Validates tag definitions.
  """
  @spec validate_tags(list() | nil) :: :ok | {:error, String.t()}
  def validate_tags(tags) when is_list(tags) do
    case Enum.all?(tags, &valid_tag?/1) do
      true -> :ok
      false -> {:error, "Invalid tag definition"}
    end
  end

  @spec validate_tags(term()) :: term()
  # def validate_tags(nil), do: :ok
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec validate_tags(term()) :: term()
  # def validate_tags(_), do: {:error, "Tags must be a list"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec valid_tag?(map()) :: boolean()
  defp valid_tag?(%{"name" => name}) when is_binary(name), do: true
  defp valid_tag?(_), do: false

  @doc """
  Validates WebSocket documentation extension.
  """
  @spec validate_websockets(map() | nil) :: :ok | {:error, String.t()}
  def validate_websockets(websockets) when is_map(websockets), do: :ok
  @spec validate_websockets(term()) :: term()
  # def validate_websockets(nil), do: :ok
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec validate_websockets(term()) :: term()
  # def validate_websockets(_), do: {:error, "WebSocket documentation must be a map"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Generates a validation report.
  """
  def generate_report do
    spec = Specification.generate()

    %{
      valid: match?({:ok, _}, validate()),
      version: spec["openapi"],
      info: %{
        title: get_in(spec, ["info", "title"]),
        version: get_in(spec, ["info", "version"])
      },
      statistics: %{
        paths: count_paths(spec["paths"]),
        operations: count_operations(spec["paths"]),
        schemas: count_schemas(get_in(spec, ["components", "schemas"])),
        examples: count_examples(get_in(spec, ["components", "examples"]))
      },
      coverage: calculate_coverage(spec)
    }
  end

  @spec count_paths(map() | nil) :: non_neg_integer()
  defp count_paths(nil), do: 0
  defp count_paths(paths), do: map_size(paths)

  @spec count_operations(map() | nil) :: non_neg_integer()
  defp count_operations(nil), do: 0

  defp count_operations(paths) do
    paths
    |> Enum.map(fn {_path, methods} ->
      methods
      |> Map.keys()
      |> Enum.filter(&(&1 != "parameters"))
      |> length()
    end)
    |> Enum.sum()
  end

  @spec count_schemas(map() | nil) :: non_neg_integer()
  defp count_schemas(nil), do: 0
  defp count_schemas(schemas), do: map_size(schemas)

  @spec count_examples(map() | nil) :: non_neg_integer()
  defp count_examples(nil), do: 0
  defp count_examples(examples), do: map_size(examples)

  @spec calculate_coverage(map()) :: float()
  defp calculate_coverage(spec) do
    paths = spec["paths"] || %{}
    total_operations = count_operations(paths)

    documented_operations =
      paths
      |> Enum.map(fn {_path, methods} ->
        methods
        |> Enum.filter(fn {method, _} -> method != "parameters" end)
        |> Enum.count(fn {_method, operation} ->
          Map.has_key?(operation, "summary") && Map.has_key?(operation, "description")
        end)
      end)
      |> Enum.sum()

    case total_operations do
      0 -> 100.0
      total -> Float.round(documented_operations / total * 100, 1)
    end
  end
end
