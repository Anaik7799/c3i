defmodule Indrajaal.FormatHelpers do
  @moduledoc """
  Shared formatting functions for consistent output.
  Eliminates duplication across Mix tasks.
  """

  @spec format_ports(binary() | list()) :: binary()
  def format_ports(ports) when is_binary(ports) do
    ports
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map_join(&format_port_mapping/1, ", ")
  end

  @spec format_ports(term()) :: term()
  def format_ports(ports) when is_list(ports) do
    ports
    |> Enum.map_join(&format_port_mapping/1, ", ")
  end

  @spec format_ports(term()) :: term()
  # def format_ports(_), do: "none"
  # Claude Agent: EP-076 - Unreachable function clause commented
  defp format_port_mapping(port) when is_binary(port) do
    case String.split(port, "->") do
      [host_port, container_port] ->
        "#{String.trim(host_port)}→#{String.trim(container_port)}"

      _ ->
        port
    end
  end

  defp format_port_mapping(port), do: to_string(port)
end
