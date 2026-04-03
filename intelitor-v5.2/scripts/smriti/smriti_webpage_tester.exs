#!/usr/bin/env elixir
# SMRITI Webpage and API Tester
# Tests all endpoints and validates responses
#
# Usage: elixir scripts/smriti/smriti_webpage_tester.exs

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

defmodule SmritiWebpageTester do
  @client_url "http://localhost:3001"
  @api_url "http://localhost:5001"

  def run do
    IO.puts("""
    ╔════════════════════════════════════════════════════════════════╗
    ║           SMRITI Webpage & API Tester                           ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  Client: #{@client_url}                                       ║
    ║  API:    #{@api_url}                                         ║
    ╚════════════════════════════════════════════════════════════════╝
    """)

    results = [
      test_section("CLIENT TESTS", [
        {"Client Homepage", fn -> test_client_homepage() end},
        {"Client Assets (JS)", fn -> test_client_assets() end},
        {"Client API Proxy", fn -> test_client_proxy() end}
      ]),
      test_section("API TESTS", [
        {"Zettels List", fn -> test_api_zettels() end},
        {"Graph Data", fn -> test_api_graph() end},
        {"Entropy Metrics", fn -> test_api_entropy() end},
        {"Search Function", fn -> test_api_search() end},
        {"Single Zettel", fn -> test_api_single_zettel() end},
        {"Pagination", fn -> test_api_pagination() end}
      ]),
      test_section("INTEGRATION TESTS", [
        {"Client-API Round Trip", fn -> test_roundtrip() end},
        {"Search Response Time", fn -> test_search_performance() end},
        {"Graph Load Time", fn -> test_graph_performance() end}
      ])
    ]

    passed = Enum.sum(for {_, p, _} <- List.flatten(results), do: p)
    failed = Enum.sum(for {_, _, f} <- List.flatten(results), do: f)

    IO.puts("""

    ╔════════════════════════════════════════════════════════════════╗
    ║                       TEST SUMMARY                             ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  Passed: #{String.pad_leading("#{passed}", 3)}                                                   ║
    ║  Failed: #{String.pad_leading("#{failed}", 3)}                                                   ║
    ║  Total:  #{String.pad_leading("#{passed + failed}", 3)}                                                   ║
    ╠════════════════════════════════════════════════════════════════╣
    ║  Status: #{if failed == 0, do: "✓ ALL TESTS PASSED", else: "✗ SOME TESTS FAILED"}                          ║
    ╚════════════════════════════════════════════════════════════════╝
    """)

    if failed > 0, do: System.halt(1)
  end

  defp test_section(name, tests) do
    IO.puts("\n═══ #{name} ═══")
    results = Enum.map(tests, fn {test_name, test_fn} ->
      result = try do
        test_fn.()
      rescue
        e -> {:error, Exception.message(e)}
      end

      case result do
        :ok ->
          IO.puts("  ✓ #{test_name}")
          {:pass, 1, 0}

        {:ok, details} ->
          IO.puts("  ✓ #{test_name} - #{details}")
          {:pass, 1, 0}

        {:error, reason} ->
          IO.puts("  ✗ #{test_name} - #{reason}")
          {:fail, 0, 1}
      end
    end)
    results
  end

  # === CLIENT TESTS ===

  defp test_client_homepage do
    case Req.get("#{@client_url}/") do
      {:ok, %{status: 200, body: body}} ->
        cond do
          String.contains?(body, "SMRITI") -> :ok
          String.contains?(body, "Zettelkasten") -> :ok
          String.contains?(body, "<div id=\"root\">") -> {:ok, "SPA container found"}
          true -> {:error, "Expected SMRITI content not found"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_client_assets do
    case Req.get("#{@client_url}/") do
      {:ok, %{status: 200, body: body}} ->
        # Extract JS asset URL from HTML
        case Regex.run(~r/src="([^"]+\.js)"/, body) do
          [_, js_path] ->
            case Req.get("#{@client_url}#{js_path}") do
              {:ok, %{status: 200, body: js_body}} when byte_size(js_body) > 1000 ->
                {:ok, "JS bundle #{div(byte_size(js_body), 1024)}KB"}

              {:ok, %{status: status}} ->
                {:error, "JS asset HTTP #{status}"}

              {:error, reason} ->
                {:error, inspect(reason)}
            end

          nil ->
            {:error, "No JS asset found in HTML"}
        end

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_client_proxy do
    # Test that client can proxy to API
    case Req.get("#{@client_url}/api/zettels", receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        if Map.has_key?(body, "items"), do: :ok, else: {:error, "Invalid response format"}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # === API TESTS ===

  defp test_api_zettels do
    case Req.get("#{@api_url}/api/zettels") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        total = body["total"] || 0
        items = body["items"] || []

        cond do
          total > 0 and length(items) > 0 ->
            {:ok, "#{total} zettels, #{length(items)} returned"}

          total == 0 ->
            {:error, "No zettels found"}

          true ->
            {:error, "Invalid response structure"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_api_graph do
    case Req.get("#{@api_url}/api/graph") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        nodes = body["nodes"] || []
        edges = body["edges"] || []
        {:ok, "#{length(nodes)} nodes, #{length(edges)} edges"}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_api_entropy do
    case Req.get("#{@api_url}/api/metrics/entropy") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        avg = body["averageEntropy"]
        fresh = body["freshCount"]
        aging = body["agingCount"]
        rotting = body["rottingCount"]

        if is_number(avg) and is_integer(fresh) do
          {:ok, "avg=#{Float.round(avg, 2)}, fresh=#{fresh}, aging=#{aging}, rotting=#{rotting}"}
        else
          {:error, "Invalid entropy data structure"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_api_search do
    case Req.get("#{@api_url}/api/search?q=architecture") do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        count = length(body)
        if count > 0 do
          first = List.first(body)
          title = get_in(first, ["zettel", "title"]) || "untitled"
          {:ok, "#{count} results, top: #{String.slice(title, 0, 40)}..."}
        else
          {:error, "No search results"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_api_single_zettel do
    # First get a zettel ID
    case Req.get("#{@api_url}/api/zettels") do
      {:ok, %{status: 200, body: %{"items" => [first | _]}}} ->
        zettel_id = first["id"]

        case Req.get("#{@api_url}/api/zettels/#{zettel_id}") do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            title = body["title"] || "untitled"
            {:ok, "#{String.slice(title, 0, 50)}..."}

          {:ok, %{status: 404}} ->
            {:error, "Zettel not found"}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end

      _ ->
        {:error, "Could not get zettel list"}
    end
  end

  defp test_api_pagination do
    case Req.get("#{@api_url}/api/zettels?page=1&pageSize=5") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        page = body["page"]
        page_size = body["pageSize"]
        items = body["items"] || []

        if page == 1 and length(items) <= 5 do
          {:ok, "page=#{page}, items=#{length(items)}"}
        else
          {:error, "Pagination not working correctly"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # === INTEGRATION TESTS ===

  defp test_roundtrip do
    # Test full client -> API -> response cycle
    start = System.monotonic_time(:millisecond)

    case Req.get("#{@client_url}/api/zettels") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        elapsed = System.monotonic_time(:millisecond) - start

        if body["total"] > 0 and elapsed < 5000 do
          {:ok, "#{elapsed}ms latency"}
        else
          {:error, "Round trip too slow: #{elapsed}ms"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_search_performance do
    start = System.monotonic_time(:millisecond)

    case Req.get("#{@api_url}/api/search?q=safety") do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        elapsed = System.monotonic_time(:millisecond) - start

        cond do
          elapsed < 100 -> {:ok, "#{elapsed}ms (excellent)"}
          elapsed < 500 -> {:ok, "#{elapsed}ms (good)"}
          elapsed < 1000 -> {:ok, "#{elapsed}ms (acceptable)"}
          true -> {:error, "Search too slow: #{elapsed}ms"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp test_graph_performance do
    start = System.monotonic_time(:millisecond)

    case Req.get("#{@api_url}/api/graph") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        elapsed = System.monotonic_time(:millisecond) - start
        nodes = length(body["nodes"] || [])

        cond do
          elapsed < 100 -> {:ok, "#{elapsed}ms for #{nodes} nodes (excellent)"}
          elapsed < 500 -> {:ok, "#{elapsed}ms for #{nodes} nodes (good)"}
          elapsed < 1000 -> {:ok, "#{elapsed}ms for #{nodes} nodes (acceptable)"}
          true -> {:error, "Graph load too slow: #{elapsed}ms"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end

SmritiWebpageTester.run()
