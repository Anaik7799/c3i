#!/usr/bin/env elixir
# SMRITI GUI Tester
# Performs detailed GUI validation by analyzing HTML/CSS/JS responses
#
# Usage: elixir scripts/smriti/smriti_gui_tester.exs

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

defmodule SmritiGuiTester do
  @client_url "http://localhost:3001"
  @api_url "http://localhost:5001"

  def run do
    IO.puts("""
    ╔════════════════════════════════════════════════════════════════╗
    ║              SMRITI GUI Component Tester                        ║
    ╚════════════════════════════════════════════════════════════════╝
    """)

    # Test GUI components
    test_html_structure()
    test_spa_elements()
    test_api_data_for_gui()
    test_interactive_elements()

    IO.puts("\n=== GUI Testing Complete ===")
  end

  defp test_html_structure do
    IO.puts("\n─── HTML Structure Analysis ───")

    case Req.get("#{@client_url}/") do
      {:ok, %{status: 200, body: html}} ->
        checks = [
          {"DOCTYPE declaration", String.contains?(html, "<!DOCTYPE html>")},
          {"HTML lang attribute", String.contains?(html, "lang=\"en\"")},
          {"UTF-8 charset", String.contains?(html, "charset=\"UTF-8\"")},
          {"Viewport meta", String.contains?(html, "viewport")},
          {"Title tag", String.contains?(html, "<title>")},
          {"Root div", String.contains?(html, "id=\"root\"")},
          {"Module script", String.contains?(html, "type=\"module\"")},
          {"CSS styles", String.contains?(html, "<style>")}
        ]

        Enum.each(checks, fn {name, passed} ->
          status = if passed, do: "✓", else: "✗"
          IO.puts("  #{status} #{name}")
        end)

        passed = Enum.count(checks, fn {_, p} -> p end)
        IO.puts("  └─ #{passed}/#{length(checks)} checks passed")

      {:error, reason} ->
        IO.puts("  ✗ Failed to fetch HTML: #{inspect(reason)}")
    end
  end

  defp test_spa_elements do
    IO.puts("\n─── SPA Element Analysis ───")

    case Req.get("#{@client_url}/") do
      {:ok, %{status: 200, body: html}} ->
        # Extract and analyze JS bundle
        case Regex.run(~r/src="([^"]+\.js)"/, html) do
          [_, js_path] ->
            IO.puts("  ✓ JS Bundle: #{js_path}")

            case Req.get("#{@client_url}#{js_path}") do
              {:ok, %{status: 200, body: js}} ->
                size_kb = div(byte_size(js), 1024)
                IO.puts("    └─ Size: #{size_kb}KB")

                # Check for Elmish/Fable patterns
                checks = [
                  {"Elmish patterns", String.contains?(js, "dispatch") or String.contains?(js, "Dispatch")},
                  {"React elements", String.contains?(js, "createElement")},
                  {"Cytoscape.js", String.contains?(js, "cytoscape") or String.contains?(js, "Cytoscape")},
                  {"API fetch", String.contains?(js, "fetch") or String.contains?(js, "Fetch")},
                  {"JSON handling", String.contains?(js, "JSON")},
                  {"Event handlers", String.contains?(js, "addEventListener") or String.contains?(js, "onclick")}
                ]

                Enum.each(checks, fn {name, found} ->
                  status = if found, do: "✓", else: "○"
                  IO.puts("    #{status} #{name}")
                end)

              {:error, _} ->
                IO.puts("    ✗ Could not fetch JS bundle")
            end

          nil ->
            IO.puts("  ✗ No JS bundle found")
        end

      {:error, reason} ->
        IO.puts("  ✗ Failed: #{inspect(reason)}")
    end
  end

  defp test_api_data_for_gui do
    IO.puts("\n─── API Data for GUI Rendering ───")

    # Test Zettels data structure for GUI
    IO.puts("  Zettels Data:")
    case Req.get("#{@api_url}/api/zettels") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        items = body["items"] || []
        if length(items) > 0 do
          first = List.first(items)
          fields = ["id", "title", "content", "tags", "entropy", "level", "decayRate"]

          Enum.each(fields, fn field ->
            value = first[field]
            status = if value != nil, do: "✓", else: "✗"
            preview = case value do
              v when is_binary(v) -> "\"#{String.slice(v, 0, 30)}...\""
              v when is_list(v) -> "[#{length(v)} items]"
              v when is_number(v) -> "#{v}"
              nil -> "nil"
              _ -> inspect(value)
            end
            IO.puts("    #{status} #{field}: #{preview}")
          end)
        end

      _ ->
        IO.puts("    ✗ Could not fetch zettels")
    end

    # Test Graph data structure for Cytoscape
    IO.puts("  Graph Data (for Cytoscape):")
    case Req.get("#{@api_url}/api/graph") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        nodes = body["nodes"] || []
        edges = body["edges"] || []

        IO.puts("    ✓ Nodes: #{length(nodes)}")
        IO.puts("    ✓ Edges: #{length(edges)}")

        if length(nodes) > 0 do
          first_node = List.first(nodes)
          node_fields = ["id", "label", "entropy", "cluster", "level"]
          IO.puts("    Node structure:")
          Enum.each(node_fields, fn field ->
            value = first_node[field]
            status = if value != nil, do: "✓", else: "○"
            IO.puts("      #{status} #{field}")
          end)
        end

      _ ->
        IO.puts("    ✗ Could not fetch graph data")
    end

    # Test Search response for UI
    IO.puts("  Search Results (for UI):")
    case Req.get("#{@api_url}/api/search?q=safety") do
      {:ok, %{status: 200, body: body}} when is_list(body) and length(body) > 0 ->
        first = List.first(body)
        IO.puts("    ✓ Results: #{length(body)}")
        IO.puts("    ✓ Has zettel: #{first["zettel"] != nil}")
        IO.puts("    ✓ Has score: #{first["score"] != nil}")
        IO.puts("    ✓ Has highlights: #{first["highlights"] != nil}")
        IO.puts("    ✓ Has matchType: #{first["matchType"] != nil}")

      _ ->
        IO.puts("    ✗ Could not fetch search results")
    end
  end

  defp test_interactive_elements do
    IO.puts("\n─── Interactive Elements Analysis ───")

    # Test different routes/views
    routes = [
      {"/", "Home/Graph View"},
      {"/api/zettels", "Zettels List"},
      {"/api/graph", "Graph Data"},
      {"/api/search?q=test", "Search"}
    ]

    IO.puts("  Route accessibility:")
    Enum.each(routes, fn {route, name} ->
      url = if String.starts_with?(route, "/api"), do: "#{@api_url}#{route}", else: "#{@client_url}#{route}"

      case Req.get(url, receive_timeout: 5000) do
        {:ok, %{status: 200}} ->
          IO.puts("    ✓ #{name} (#{route})")

        {:ok, %{status: status}} ->
          IO.puts("    ○ #{name} (#{route}) - HTTP #{status}")

        {:error, _} ->
          IO.puts("    ✗ #{name} (#{route}) - Failed")
      end
    end)

    # Simulate user interactions via API
    IO.puts("\n  Simulated User Interactions:")

    # 1. Load initial data
    IO.puts("    1. Initial page load:")
    {time1, _} = :timer.tc(fn ->
      Req.get("#{@client_url}/")
    end)
    IO.puts("       └─ #{div(time1, 1000)}ms")

    # 2. Load graph data
    IO.puts("    2. Graph visualization load:")
    {time2, _} = :timer.tc(fn ->
      Req.get("#{@api_url}/api/graph")
    end)
    IO.puts("       └─ #{div(time2, 1000)}ms")

    # 3. Search interaction
    IO.puts("    3. Search 'architecture':")
    {time3, result} = :timer.tc(fn ->
      Req.get("#{@api_url}/api/search?q=architecture")
    end)
    result_count = case result do
      {:ok, %{body: body}} when is_list(body) -> length(body)
      _ -> 0
    end
    IO.puts("       └─ #{div(time3, 1000)}ms, #{result_count} results")

    # 4. Click on zettel (load details)
    IO.puts("    4. Load zettel details:")
    case Req.get("#{@api_url}/api/zettels") do
      {:ok, %{body: %{"items" => [first | _]}}} ->
        {time4, _} = :timer.tc(fn ->
          Req.get("#{@api_url}/api/zettels/#{first["id"]}")
        end)
        IO.puts("       └─ #{div(time4, 1000)}ms")

      _ ->
        IO.puts("       └─ Could not test")
    end

    # 5. Entropy metrics load
    IO.puts("    5. Load entropy metrics:")
    {time5, _} = :timer.tc(fn ->
      Req.get("#{@api_url}/api/metrics/entropy")
    end)
    IO.puts("       └─ #{div(time5, 1000)}ms")
  end
end

SmritiGuiTester.run()
