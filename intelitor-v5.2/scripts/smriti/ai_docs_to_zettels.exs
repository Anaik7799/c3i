#!/usr/bin/env elixir
# AI-Powered Docs to Zettels Converter
# Uses Claude via OpenRouter to intelligently convert documentation to Zettelkasten entries
#
# Usage:
#   OPENROUTER_API_KEY=sk-xxx elixir scripts/smriti/ai_docs_to_zettels.exs
#
# Test mode (2 files only):
#   OPENROUTER_API_KEY=sk-xxx elixir scripts/smriti/ai_docs_to_zettels.exs --test

Mix.install([
  {:exqlite, "~> 0.27"},
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

defmodule AiDocsToZettels do
  @docs_root "/home/an/dev/ver/intelitor-v5.2/docs"
  @db_path "/home/an/dev/ver/intelitor-v5.2/data/kms/smriti.db"
  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"

  # Claude model via OpenRouter
  @model "anthropic/claude-3.5-sonnet"

  # Cluster mapping based on folder
  @cluster_map %{
    "architecture" => "Architecture",
    "domain-docs" => "Domains",
    "guides" => "Guides",
    "kms" => "KMS",
    "formal_specs" => "Formal",
    "safety" => "Safety",
    "compliance" => "Compliance",
    "cockpit" => "Cockpit",
    "prajna" => "Prajna",
    "testing" => "Testing",
    "verification" => "Verification"
  }

  def run(args) do
    IO.puts("=== AI-Powered Docs to Zettels Converter ===\n")

    # Check for API key
    api_key = System.get_env("OPENROUTER_API_KEY")
    if is_nil(api_key) or api_key == "" do
      IO.puts("ERROR: OPENROUTER_API_KEY environment variable not set")
      IO.puts("Usage: OPENROUTER_API_KEY=sk-xxx elixir #{__ENV__.file}")
      System.halt(1)
    end

    # Test mode: only process 2 files
    test_mode = "--test" in args
    limit = if test_mode, do: 2, else: 50

    IO.puts("Mode: #{if test_mode, do: "TEST (2 files)", else: "FULL (up to 50 files)"}")
    IO.puts("API Key: #{String.slice(api_key, 0, 10)}...#{String.slice(api_key, -4, 4)}\n")

    # Connect to database
    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)
    IO.puts("Connected to database: #{@db_path}\n")

    # Collect docs
    docs = collect_docs(limit)
    IO.puts("Found #{length(docs)} documents to convert\n")

    # Process each doc with AI
    results = Enum.map(docs, fn doc_path ->
      IO.puts("\n--- Processing: #{Path.basename(doc_path)} ---")
      process_doc(conn, doc_path, api_key)
    end)

    # Summary
    successful = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &(&1 == :error))

    IO.puts("\n=== Conversion Complete ===")
    IO.puts("Successful: #{successful}")
    IO.puts("Failed: #{failed}")

    # Close database
    Exqlite.Sqlite3.close(conn)
  end

  defp collect_docs(limit) do
    # Priority folders to convert
    priority_folders = [
      "architecture",
      "domain-docs/01-core",
      "guides",
      "kms",
      "safety"
    ]

    priority_folders
    |> Enum.flat_map(fn folder ->
      path = Path.join(@docs_root, folder)
      if File.dir?(path) do
        Path.wildcard(Path.join(path, "**/*.md"))
        |> Enum.take(10)  # Max 10 per folder
      else
        []
      end
    end)
    |> Enum.take(limit)
  end

  defp process_doc(conn, doc_path, api_key) do
    # Read full file content
    case File.read(doc_path) do
      {:ok, content} ->
        relative_path = String.replace(doc_path, @docs_root <> "/", "")
        IO.puts("  File size: #{byte_size(content)} bytes")

        # Truncate very large files
        content = if byte_size(content) > 15000 do
          IO.puts("  Truncating large file to 15KB...")
          String.slice(content, 0, 15000)
        else
          content
        end

        # Call Claude via OpenRouter
        case call_claude(content, relative_path, api_key) do
          {:ok, zettel_data} ->
            IO.puts("  AI extraction successful")
            insert_zettel(conn, zettel_data, doc_path, relative_path)
            :ok

          {:error, reason} ->
            IO.puts("  ERROR: #{reason}")
            :error
        end

      {:error, reason} ->
        IO.puts("  ERROR reading file: #{inspect(reason)}")
        :error
    end
  end

  defp call_claude(content, relative_path, api_key) do
    folder = relative_path |> Path.dirname() |> String.split("/") |> List.first()
    cluster = Map.get(@cluster_map, folder, "General")

    prompt = """
    You are converting a documentation file into a Zettelkasten entry. Analyze the following markdown document and extract structured information.

    FILE PATH: #{relative_path}
    CLUSTER: #{cluster}

    DOCUMENT CONTENT:
    ---
    #{content}
    ---

    Please respond with ONLY a valid JSON object (no markdown code blocks, no explanation) with this exact structure:
    {
      "title": "A clear, concise title (max 100 chars)",
      "summary": "A 2-3 sentence summary of the key concepts",
      "tags": ["tag1", "tag2", "tag3"],
      "key_concepts": ["concept1", "concept2"],
      "related_topics": ["topic1", "topic2"],
      "level": "atomic|molecular|organism|ecosystem",
      "importance": "high|medium|low"
    }

    Rules:
    - title: Extract or create a meaningful title
    - summary: Capture the essence of the document
    - tags: 3-8 relevant tags (lowercase, no spaces)
    - key_concepts: Main ideas or entities discussed
    - related_topics: What this connects to conceptually
    - level: atomic (<1KB), molecular (1-5KB), organism (5-20KB), ecosystem (>20KB)
    - importance: Based on how foundational/critical this document is

    Respond with ONLY the JSON object, nothing else.
    """

    body = Jason.encode!(%{
      model: @model,
      messages: [
        %{role: "user", content: prompt}
      ],
      max_tokens: 1000,
      temperature: 0.3
    })

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://indrajaal.dev"},
      {"X-Title", "Indrajaal Z-KMS"}
    ]

    IO.puts("  Calling Claude via OpenRouter...")

    case Req.post(@openrouter_url, body: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: response_body}} ->
        parse_claude_response(response_body)

      {:ok, %{status: status, body: body}} ->
        {:error, "API returned status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp parse_claude_response(response_body) do
    case response_body do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        # Parse the JSON response from Claude
        content = String.trim(content)

        # Remove any markdown code blocks if present
        content = content
          |> String.replace(~r/^```json\s*/i, "")
          |> String.replace(~r/\s*```$/i, "")
          |> String.trim()

        case Jason.decode(content) do
          {:ok, data} ->
            {:ok, data}

          {:error, _} ->
            {:error, "Failed to parse Claude response as JSON: #{String.slice(content, 0, 200)}"}
        end

      _ ->
        {:error, "Unexpected response format: #{inspect(response_body)}"}
    end
  end

  defp insert_zettel(conn, zettel_data, doc_path, relative_path) do
    # Generate deterministic UUID from path
    uuid = generate_uuid(relative_path)

    # Get file stats
    {:ok, stat} = File.stat(doc_path)
    created_at = stat.ctime |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()
    updated_at = stat.mtime |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()

    # Calculate entropy based on file age
    entropy = calculate_entropy(doc_path)

    # Prepare values
    title = zettel_data["title"] || Path.basename(doc_path, ".md")
    content = zettel_data["summary"] || ""
    tags = (zettel_data["tags"] || []) |> Enum.join(",")
    level = zettel_data["level"] || "molecular"
    decay_rate = decay_rate_from_entropy(entropy)

    folder = relative_path |> Path.dirname() |> String.split("/") |> List.first()
    cluster = Map.get(@cluster_map, folder, "General")

    content_hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> String.slice(0, 16)

    sql = """
    INSERT OR REPLACE INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, cluster, content_hash, inserted_at, updated_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(stmt, [
      uuid,
      title,
      content,
      tags,
      entropy,
      level,
      decay_rate,
      cluster,
      content_hash,
      created_at,
      updated_at
    ])

    case Exqlite.Sqlite3.step(conn, stmt) do
      :done ->
        IO.puts("  Inserted: #{title}")
        Exqlite.Sqlite3.release(conn, stmt)
        :ok

      {:error, reason} ->
        IO.puts("  ERROR inserting: #{inspect(reason)}")
        Exqlite.Sqlite3.release(conn, stmt)
        :error
    end
  end

  defp generate_uuid(relative_path) do
    hash = :crypto.hash(:md5, relative_path)
    <<a::32, b::16, c::16, d::16, e::48>> = hash
    "#{hex(a, 8)}-#{hex(b, 4)}-#{hex(c, 4)}-#{hex(d, 4)}-#{hex(e, 12)}"
  end

  defp hex(int, len) do
    int
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(len, "0")
  end

  defp calculate_entropy(file_path) do
    {:ok, stat} = File.stat(file_path)
    mtime = stat.mtime |> NaiveDateTime.from_erl!()
    now = NaiveDateTime.utc_now()

    days_old = NaiveDateTime.diff(now, mtime, :day)

    cond do
      days_old < 7 -> 0.1 + (days_old / 7) * 0.1
      days_old < 30 -> 0.2 + ((days_old - 7) / 23) * 0.3
      days_old < 90 -> 0.5 + ((days_old - 30) / 60) * 0.3
      true -> min(0.8 + ((days_old - 90) / 365) * 0.2, 1.0)
    end
    |> Float.round(2)
  end

  defp decay_rate_from_entropy(entropy) do
    cond do
      entropy < 0.3 -> "slow"
      entropy < 0.6 -> "medium"
      true -> "fast"
    end
  end
end

# Run with command line args
AiDocsToZettels.run(System.argv())
