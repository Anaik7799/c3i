#!/usr/bin/env elixir

# Create SigNoz dashboards
# Usage: elixir scripts/observability/create_signoz_dashboards.exs [--validate]

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

defmodule CreateSigNozDashboards do
  @moduledoc """
  Script to create or validate SigNoz dashboards for the Indrajaal system.

  This script can:
  - Create all predefined dashboards in SigNoz
  - Validate that dashboards exist
  - Show dashboard URLs
  """

  @spec main(list()) :: :ok
  def main(args \\ []) do
    case parse_args(args) do
      %{validate: true} ->
        validate_dashboards()

      %{help: true} ->
        show_help()

      _ ->
        create_all_dashboards()
    end
  end

  defp parse_args(args) do
    {__opts, _, _} =
      OptionParser.parse(args,
        switches: [validate: :boolean, help: :boolean],
        aliases: [v: :validate, h: :help]
      )

    Map.new(__opts)
  end

  defp create_all_dashboards do
    IO.puts("Creating SigNoz dashboards...")

    # Load the dashboard module
    Code.eval_file("lib/indrajaal/observability/dashboards.ex")

    api_url = System.get_env("SIGNOZ_API_URL", "http://localhost:8080")
    api_key = System.get_env("SIGNOZ_API_KEY", "")

    if api_key == "" do
      IO.puts("""

      WARNING: SIGNOZ_API_KEY environment variable not set!

      To create dashboards, you need to:
      1. Get your SigNoz API key from the SigNoz UI
      2. Set it as an environment variable:
         export SIGNOZ_API_KEY="your-api-key-here"
      3. Run this script again
      """)

      System.halt(1)
    end

    IO.puts("Using SigNoz API at: #{api_url}")

    case Indrajaal.Observability.Dashboards.create_dashboards() do
      {:ok, dashboards} ->
        IO.puts("\n✅ Successfully created dashboards:")

        urls = Indrajaal.Observability.Dashboards.get_dashboard_urls(dashboards, api_url)

        Enum.each(urls, fn {name, url} ->
          IO.puts("  - #{format_name(name)}: #{url}")
        end)

        IO.puts("\n🎉 All dashboards created successfully!")

      {:error, errors} ->
        IO.puts("\n❌ Failed to create some dashboards:")

        Enum.each(errors, fn {type, reason} ->
          IO.puts("  - #{format_name(type)}: #{inspect(reason)}")
        end)

        System.halt(1)
    end
  end

  defp validate_dashboards do
    IO.puts("Validating SigNoz dashboards...")

    # Load the dashboard module
    Code.eval_file("lib/indrajaal/observability/dashboards.ex")

    dashboard_types = [:system_overview, :alarms, :security, :performance, :business_kpis]

    IO.puts("\nChecking dashboard configurations...")

    _results =
      Enum.map(dashboard_types, fn type ->
        config = Indrajaal.Observability.Dashboards.load_dashboard_config(type)

        case Indrajaal.Observability.Dashboards.validate_dashboard_config(config) do
          :ok ->
            IO.puts("  ✅ #{format_name(type)} - Valid configuration")
            {:ok, type}

          {:error, errors} ->
            IO.puts("  ❌ #{format_name(type)} - Invalid configuration: #{inspect(errors)}")
            {:error, type}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      IO.puts("\n✅ All dashboard configurations are valid!")
    else
      IO.puts("\n❌ Some dashboard configurations have errors.")
      System.halt(1)
    end
  end

  defp show_help do
    IO.puts("""
    SigNoz Dashboard Creator

    Usage:
      elixir #{__ENV__.file} [options]

    Options:
      --validate, -v    Validate dashboard configurations without creating them
      --help, -h        Show this help message

    Environment Variables:
      SIGNOZ_API_URL    SigNoz API URL (default: http://localhost:8080)
      SIGNOZ_API_KEY    SigNoz API key (__required for creating dashboards)

    Examples:
      # Create all dashboards
      export SIGNOZ_API_KEY="your-api-key"
      elixir #{__ENV__.file}
      
      # Validate configurations only
      elixir #{__ENV__.file} --validate
    """)
  end

  defp format_name(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end

# Run the script
CreateSigNozDashboards.main(System.argv())
