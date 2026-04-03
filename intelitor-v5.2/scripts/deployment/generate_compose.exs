#!/usr/bin/env elixir

defmodule GenerateCompose do
  @moduledoc """
  Generates podman-compose.yml from the single source of truth at
  Indrajaal.Deployment.Config.
  """

  def main() do
    IO.puts("⚙️ Generating podman-compose.yml from single source of truth...")

    # Load the deployment config module
    Code.require_file("lib/indrajaal/deployment/config.ex", __DIR__ |> Path.dirname() |> Path.dirname())
    containers = Indrajaal.Deployment.Config.containers()

    # Convert container config to YAML structure
    services = 
      containers
      |> Enum.sort_by(& &1[:dependency_order])
      |> Enum.reduce(%{}, fn container, acc ->
        service_def = %{
          "image" => "localhost/#{container[:image_name]}:#{container[:image_tag]}",
          "container_name" => container[:service_name],
          "ports" => container[:ports],
          "environment" => 
            container[:env]
            |> Enum.map(fn str ->
              case String.split(str, "=", parts: 2) do
                [key, val] -> {key, val}
                _ -> {str, ""}
              end
            end)
            |> Map.new(),
          "volumes" => container[:volumes],
          "networks" => ["indrajaal-network"],
        }
        |> add_if_present("working_dir", container[:workdir])
        |> add_if_present("command", container[:args])

        Map.put(acc, container[:service_name], service_def)
      end)

    networks = %{
      "indrajaal-network" => %{
        "driver" => "bridge"
      }
    }

    compose_data = %{
      "version" => "3.8",
      "services" => services,
      "networks" => networks
    }

    # Use a YAML library that can encode.
    Mix.install([{:ymlr, "~> 5.0"}])

    # Generate YAML string using the correct library and function
    yaml_string = Ymlr.document!(compose_data, sort_maps: true)
    
    # Write to file
    File.write!("podman-compose.yml", yaml_string)

    IO.puts("✅ Successfully generated podman-compose.yml")
  end

  defp add_if_present(map, key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)
end

GenerateCompose.main()
