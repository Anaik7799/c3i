#!/usr/bin/env elixir
# Docs to Zettels Converter
# Converts markdown documentation to Zettelkasten entries

Mix.install([
  {:exqlite, "~> 0.27"}
])

defmodule DocsToZettels do
  @docs_root "/home/an/dev/ver/intelitor-v5.2/docs"
  @db_path "/home/an/dev/ver/intelitor-v5.2/data/kms/smriti.db"

  # Priority folders to convert (in order)
  @priority_folders [
    "architecture",
    "domain-docs/01-core",
    "domain-docs/02-accounts",
    "domain-docs/03-policy",
    "domain-docs/04-sites",
    "domain-docs/05-devices",
    "domain-docs/06-alarms",
    "domain-docs/07-video",
    "domain-docs/08-access-control",
    "domain-docs/09-dispatch",
    "domain-docs/10-maintenance",
    "guides",
    "kms",
    "formal_specs",
    "safety",
    "compliance",
    "cockpit",
    "prajna"
  ]

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
    "prajna" => "Prajna"
  }

  def run do
    IO.puts("=== Docs to Zettels Converter ===\n")

    # Connect to database
    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)

    # Clear existing sample data (keep schema)
    IO.puts("Clearing existing data...")
    Exqlite.Sqlite3.execute(conn, "DELETE FROM holon_edges")
    Exqlite.Sqlite3.execute(conn, "DELETE FROM holons")
    Exqlite.Sqlite3.execute(conn, "DELETE FROM holons_fts")

    # Collect all docs from priority folders
    docs = collect_docs()
    IO.puts("Found #{length(docs)} documents to convert\n")

    # Convert and insert
    zettels = Enum.map(docs, &convert_to_zettel/1)
    IO.puts("Inserting #{length(zettels)} zettels...")

    Enum.each(zettels, fn zettel ->
      insert_zettel(conn, zettel)
    end)

    # Create links based on wiki-style references
    IO.puts("\nCreating links...")
    links = create_links(zettels)
    IO.puts("Found #{length(links)} links")

    Enum.each(links, fn link ->
      insert_link(conn, link)
    end)

    # Close connection
    Exqlite.Sqlite3.close(conn)

    IO.puts("\n=== Conversion Complete ===")
    IO.puts("Zettels: #{length(zettels)}")
    IO.puts("Links: #{length(links)}")
  end

  defp collect_docs do
    @priority_folders
    |> Enum.flat_map(fn folder ->
      path = Path.join(@docs_root, folder)
      if File.dir?(path) do
        Path.wildcard(Path.join(path, "**/*.md"))
        |> Enum.take(50)  # Limit per folder
      else
        []
      end
    end)
    |> Enum.take(200)  # Total limit
  end

  defp convert_to_zettel(file_path) do
    content = File.read!(file_path)
    relative_path = String.replace(file_path, @docs_root <> "/", "")
    folder = relative_path |> Path.dirname() |> String.split("/") |> List.first()

    # Extract title from first heading or filename
    title = extract_title(content, file_path)

    # Extract tags from content and path
    tags = extract_tags(content, relative_path)

    # Calculate entropy based on file age
    entropy = calculate_entropy(file_path)

    # Determine level based on content size
    level = determine_level(content)

    # Determine cluster
    cluster = Map.get(@cluster_map, folder, "General")

    # Generate UUID from file path (deterministic)
    uuid = generate_uuid(relative_path)

    # Get file stats
    {:ok, stat} = File.stat(file_path)
    created_at = stat.ctime |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()
    updated_at = stat.mtime |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()

    # Content hash
    content_hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> String.slice(0, 16)

    %{
      uuid: uuid,
      title: title,
      content: content,
      tags: tags,
      entropy: entropy,
      level: level,
      decay_rate: decay_rate_from_entropy(entropy),
      cluster: cluster,
      content_hash: content_hash,
      created_at: created_at,
      updated_at: updated_at,
      relative_path: relative_path
    }
  end

  defp extract_title(content, file_path) do
    # Try to get title from first H1 heading
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      nil ->
        # Fall back to filename
        file_path
        |> Path.basename(".md")
        |> String.replace(~r/[-_]/, " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp extract_tags(content, relative_path) do
    # Extract from path
    path_tags = relative_path
      |> Path.dirname()
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.downcase/1)
      |> Enum.map(&String.replace(&1, ~r/^\d+-/, ""))  # Remove number prefixes

    # Extract from content (keywords)
    content_tags = extract_keywords(content)

    (path_tags ++ content_tags)
    |> Enum.uniq()
    |> Enum.take(8)
  end

  defp extract_keywords(content) do
    keywords = [
      "holon", "fractal", "vsm", "ooda", "guardian", "sentinel", "zenoh",
      "prajna", "cockpit", "telemetry", "mesh", "cluster", "container",
      "safety", "compliance", "alarm", "device", "video", "access",
      "authentication", "authorization", "dispatch", "maintenance",
      "elixir", "phoenix", "ash", "ecto", "fsharp", "nif", "rustler"
    ]

    content_lower = String.downcase(content)

    keywords
    |> Enum.filter(fn kw -> String.contains?(content_lower, kw) end)
    |> Enum.take(5)
  end

  defp calculate_entropy(file_path) do
    {:ok, stat} = File.stat(file_path)
    mtime = stat.mtime |> NaiveDateTime.from_erl!()
    now = NaiveDateTime.utc_now()

    # Days since last modification
    days_old = NaiveDateTime.diff(now, mtime, :day)

    # Entropy increases with age (0.0 to 1.0)
    # Fresh: < 7 days (0.0-0.2)
    # Aging: 7-30 days (0.2-0.5)
    # Rotting: > 30 days (0.5-1.0)
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

  defp determine_level(content) do
    size = byte_size(content)
    cond do
      size < 1000 -> "atomic"
      size < 5000 -> "molecular"
      size < 20000 -> "organism"
      true -> "ecosystem"
    end
  end

  defp generate_uuid(relative_path) do
    # Create deterministic UUID from path
    hash = :crypto.hash(:md5, relative_path)
    <<a::32, b::16, c::16, d::16, e::48>> = hash

    # Format as UUID v5-style
    "#{hex(a, 8)}-#{hex(b, 4)}-#{hex(c, 4)}-#{hex(d, 4)}-#{hex(e, 12)}"
  end

  defp hex(int, len) do
    int
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(len, "0")
  end

  defp insert_zettel(conn, zettel) do
    tags_str = Enum.join(zettel.tags, ",")

    sql = """
    INSERT OR REPLACE INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, cluster, content_hash, inserted_at, updated_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(stmt, [
      zettel.uuid,
      zettel.title,
      zettel.content,
      tags_str,
      zettel.entropy,
      zettel.level,
      zettel.decay_rate,
      zettel.cluster,
      zettel.content_hash,
      zettel.created_at,
      zettel.updated_at
    ])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
  end

  defp create_links(zettels) do
    # Build title -> uuid index
    title_index = zettels
      |> Enum.map(fn z -> {String.downcase(z.title), z.uuid} end)
      |> Map.new()

    # Find [[wiki-style]] links in content
    zettels
    |> Enum.flat_map(fn zettel ->
      # Find all [[...]] references
      Regex.scan(~r/\[\[([^\]]+)\]\]/, zettel.content)
      |> Enum.map(fn [_, ref] -> String.downcase(ref) end)
      |> Enum.filter(fn ref -> Map.has_key?(title_index, ref) end)
      |> Enum.map(fn ref ->
        %{
          source: zettel.uuid,
          target: title_index[ref],
          link_type: "wiki",
          weight: 1.0
        }
      end)
    end)
    |> Enum.uniq_by(fn l -> {l.source, l.target} end)
  end

  defp insert_link(conn, link) do
    sql = """
    INSERT OR IGNORE INTO holon_edges (source_id, target_id, link_type, weight)
    VALUES (?1, ?2, ?3, ?4)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    Exqlite.Sqlite3.bind(conn, stmt, [link.source, link.target, link.link_type, link.weight])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
  end
end

DocsToZettels.run()
