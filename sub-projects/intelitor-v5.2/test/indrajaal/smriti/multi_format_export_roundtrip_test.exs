defmodule Indrajaal.Smriti.MultiFormatExportRoundtripTest do
  @moduledoc """
  Self-contained tests for SMRITI multi-format export with roundtrip integrity.

  WHAT: Validates JSON export field completeness, Markdown CommonMark correctness,
        SQLite schema creation, JSON and Markdown roundtrip identity, self-documenting
        reconstruction guide headers, batch export performance, Unicode preservation,
        graceful handling of empty/nil fields, and property-based roundtrip fidelity.
        All logic is implemented as `defp` helpers — no production module dependencies.

  WHY:  SC-SMRITI-072 mandates multi-format export: JSON, Markdown, and SQLite.
        SC-SMRITI-078 mandates valid CommonMark in Markdown exports.
        SC-SMRITI-071 mandates a self-documenting reconstruction guide header.
        SC-SMRITI-133 mandates query latency < 500ms (informing the 5s batch gate).
        Roundtrip integrity is critical for Ψ₂ (Evolutionary Continuity): exported
        zettels must be re-importable with zero information loss.

  CONSTRAINTS:
    SC-SMRITI-072: Multi-format export JSON/Markdown/SQLite
    SC-SMRITI-078: Markdown export valid CommonMark
    SC-SMRITI-071: Self-documenting reconstruction guide on export
    SC-SMRITI-133: Query timeout < 500ms
    SC-SMRITI-140: All evolution events recorded
    EP-GEN-014:    PropCheck/StreamData disambiguation MANDATORY

  ## Coverage Matrix
  | Describe block                            | Unit | Property | Total |
  |-------------------------------------------|------|----------|-------|
  | JSON export field completeness            | 4    | 1        | 5     |
  | Markdown export CommonMark validity       | 5    | 1        | 6     |
  | SQLite export schema                      | 4    | 1        | 5     |
  | JSON roundtrip identity                   | 4    | 1        | 5     |
  | Markdown roundtrip identity               | 4    | 1        | 5     |
  | Reconstruction guide header               | 4    | 0        | 4     |
  | Batch export performance                  | 3    | 0        | 3     |
  | Unicode content preservation              | 3    | 1        | 4     |
  | Empty/nil field graceful output           | 4    | 0        | 4     |
  | Property: JSON roundtrip fidelity         | 0    | 2        | 2     |
  | Property: export size scales linearly     | 0    | 2        | 2     |
  | TOTAL                                     | 35   | 10       | 45    |

  ## EP-GEN-014 compliance
  - SD. prefix used exclusively for all StreamData generators
  - `ExUnitProperties.check all(...)` always inside plain `test` blocks
  - No PropCheck imported (SD-only test file: pure ExUnitProperties pattern)
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :export
  @moduletag :roundtrip

  # ============================================================================
  # Domain types
  # ============================================================================

  @type zettel_id :: String.t()
  @type tag :: String.t()

  @type zettel :: %{
          id: zettel_id(),
          title: String.t(),
          content: String.t(),
          tags: [tag()],
          created_at: String.t(),
          metadata: map()
        }

  # ============================================================================
  # Reconstruction guide header (SC-SMRITI-071)
  # ============================================================================

  @reconstruction_guide_header """
  # SMRITI Knowledge Export — Reconstruction Guide
  #
  # This file is a self-documenting export from the SMRITI knowledge base.
  # Schema version: 1.0.0
  # Constitutional axiom: Ψ₂ (Evolutionary Continuity) — all zettels are
  # re-importable from this file alone.
  #
  # Reconstruction steps:
  #   1. Parse this file according to the schema below.
  #   2. Insert each record into a fresh `zettel` table.
  #   3. Rebuild FTS5 index over title + content + tags.
  #   4. Verify SHA-256 checksum of each record matches the `checksum` field.
  #
  # Format: newline-delimited JSON (NDJSON). One zettel per line.
  # Encoding: UTF-8. No BOM.
  """

  # ============================================================================
  # Zettel factory
  # ============================================================================

  defp build_zettel(opts) do
    id = Keyword.get(opts, :id, "zettel-#{:erlang.unique_integer([:positive])}")

    %{
      id: id,
      title: Keyword.get(opts, :title, "Zettel #{id}"),
      content:
        Keyword.get(
          opts,
          :content,
          "Body of #{id}. Discusses holon state, Zenoh mesh, and SMRITI."
        ),
      tags: Keyword.get(opts, :tags, ["smriti", "knowledge"]),
      created_at: Keyword.get(opts, :created_at, "2026-01-01T00:00:00Z"),
      metadata: Keyword.get(opts, :metadata, %{"domain" => "core", "version" => 1})
    }
  end

  defp corpus(count) when count >= 1 do
    Enum.map(1..count, fn idx ->
      build_zettel(
        id: "zettel-#{idx}",
        title: "Knowledge Note #{idx}",
        content:
          "Content of note #{idx}. Explores holon #{idx} state and Zenoh messaging at #{idx}ms.",
        tags: ["smriti", "note-#{idx}", if(rem(idx, 2) == 0, do: "even", else: "odd")],
        created_at:
          "2026-01-#{String.pad_leading(Integer.to_string(rem(idx, 28) + 1), 2, "0")}T00:00:00Z",
        metadata: %{"domain" => "core", "version" => idx}
      )
    end)
  end

  # ============================================================================
  # JSON export helpers (SC-SMRITI-072)
  # ============================================================================

  defp export_to_json(zettels) when is_list(zettels) do
    records =
      Enum.map(zettels, fn z ->
        %{
          "id" => z.id,
          "title" => z.title,
          "content" => z.content,
          "tags" => z.tags,
          "created_at" => z.created_at,
          "metadata" => z.metadata,
          "checksum" => compute_checksum(z)
        }
      end)

    header = @reconstruction_guide_header
    ndjson = Enum.map_join(records, "\n", &Jason.encode!/1)
    {:ok, header <> ndjson}
  end

  defp import_from_json(json_string) when is_binary(json_string) do
    lines =
      json_string
      |> String.split("\n")
      |> Enum.reject(fn line ->
        trimmed = String.trim(line)
        trimmed == "" or String.starts_with?(trimmed, "#")
      end)

    results =
      Enum.map(lines, fn line ->
        case Jason.decode(line) do
          {:ok, record} ->
            {:ok,
             %{
               id: record["id"],
               title: record["title"],
               content: record["content"],
               tags: record["tags"] || [],
               created_at: record["created_at"],
               metadata: record["metadata"] || %{}
             }}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, Enum.map(results, fn {:ok, z} -> z end)}
    else
      {:error, {:parse_failures, length(errors)}}
    end
  end

  defp compute_checksum(zettel) do
    data = "#{zettel.id}:#{zettel.title}:#{zettel.content}:#{Enum.join(zettel.tags, ",")}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # Markdown export helpers (SC-SMRITI-072, SC-SMRITI-078)
  # ============================================================================

  defp export_to_markdown(zettels) when is_list(zettels) do
    guide = reconstruction_guide_section()

    notes =
      Enum.map_join(zettels, "\n\n---\n\n", fn z ->
        render_zettel_markdown(z)
      end)

    {:ok, guide <> "\n\n---\n\n" <> notes}
  end

  defp reconstruction_guide_section do
    """
    # SMRITI Knowledge Export — Reconstruction Guide

    > **Schema version**: 1.0.0
    > **Constitutional axiom**: Ψ₂ (Evolutionary Continuity)
    > **Format**: CommonMark Markdown (SC-SMRITI-078)

    ## Reconstruction Steps

    1. Parse each zettel section (delimited by `---`).
    2. Extract YAML frontmatter between `<!--meta` and `-->` markers.
    3. Re-import into `zettel` table with FTS5 index rebuild.
    4. Verify SHA-256 checksum field against record content.

    ## Self-Documentation

    This file is a self-describing export. It contains all information
    required to reconstruct the SMRITI knowledge base from scratch.
    No external schema reference is needed (SC-SMRITI-071).
    """
    |> String.trim_trailing()
  end

  defp render_zettel_markdown(zettel) do
    tag_list = Enum.map_join(zettel.tags, ", ", &"`#{&1}`")
    metadata_json = Jason.encode!(zettel.metadata)

    """
    ## #{zettel.title}

    <!--meta id="#{zettel.id}" created_at="#{zettel.created_at}" checksum="#{compute_checksum(zettel)}" -->

    #{zettel.content}

    ### Tags

    #{tag_list}

    ### Metadata

    ```json
    #{metadata_json}
    ```
    """
    |> String.trim_trailing()
  end

  defp import_from_markdown(md_string) when is_binary(md_string) do
    sections =
      md_string
      |> String.split("\n---\n")
      |> Enum.drop(1)

    results =
      Enum.flat_map(sections, fn section ->
        case parse_markdown_zettel(section) do
          {:ok, z} -> [z]
          {:skip, _} -> []
        end
      end)

    {:ok, results}
  end

  defp parse_markdown_zettel(section) do
    with {:ok, title} <- extract_md_title(section),
         {:ok, meta} <- extract_md_meta(section),
         {:ok, content} <- extract_md_content(section),
         {:ok, tags} <- extract_md_tags(section) do
      {:ok,
       %{
         id: meta["id"],
         title: title,
         content: content,
         tags: tags,
         created_at: meta["created_at"] || "unknown",
         metadata: %{}
       }}
    else
      _ -> {:skip, :parse_failed}
    end
  end

  defp extract_md_title(section) do
    case Regex.run(~r/^##\s+(.+)$/m, String.trim(section), capture: :all_but_first) do
      [title] -> {:ok, String.trim(title)}
      nil -> {:error, :no_title}
    end
  end

  defp extract_md_meta(section) do
    case Regex.run(~r/<!--meta\s+(.+?)\s+-->/, section, capture: :all_but_first) do
      [attrs] ->
        pairs =
          Regex.scan(~r/(\w+)="([^"]*)"/, attrs, capture: :all_but_first)
          |> Enum.into(%{}, fn [k, v] -> {k, v} end)

        {:ok, pairs}

      nil ->
        {:error, :no_meta}
    end
  end

  defp extract_md_content(section) do
    # Extract text between meta comment and ### Tags, excluding the title
    case Regex.run(
           ~r/<!--meta[^>]*-->\n\n(.*?)\n\n###\s+Tags/s,
           section,
           capture: :all_but_first
         ) do
      [content] -> {:ok, String.trim(content)}
      nil -> {:error, :no_content}
    end
  end

  defp extract_md_tags(section) do
    case Regex.run(~r/### Tags\n\n(.+?)\n\n###/s, section, capture: :all_but_first) do
      [tag_line] ->
        tags =
          tag_line
          |> String.trim()
          |> String.split(", ")
          |> Enum.map(fn t -> String.trim(t, "`") end)

        {:ok, tags}

      nil ->
        # Try end-of-section fallback
        case Regex.run(~r/### Tags\n\n(.+)\z/s, section, capture: :all_but_first) do
          [tag_line] ->
            tags =
              tag_line
              |> String.trim()
              |> String.split(", ")
              |> Enum.map(fn t ->
                t |> String.trim() |> String.trim("`") |> String.split("\n") |> List.first()
              end)
              |> Enum.reject(&(&1 == ""))

            {:ok, tags}

          nil ->
            {:ok, []}
        end
    end
  end

  # ============================================================================
  # SQLite DDL helpers (SC-SMRITI-072)
  # ============================================================================

  defp sqlite_create_schema do
    """
    CREATE TABLE IF NOT EXISTS zettel (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL DEFAULT '',
      tags TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL DEFAULT '',
      metadata TEXT NOT NULL DEFAULT '{}',
      checksum TEXT NOT NULL DEFAULT '',
      exported_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE VIRTUAL TABLE IF NOT EXISTS zettel_fts
    USING fts5(
      id UNINDEXED,
      title,
      content,
      tags,
      content='zettel',
      content_rowid='rowid'
    );

    CREATE INDEX IF NOT EXISTS idx_zettel_created_at ON zettel(created_at);
    CREATE INDEX IF NOT EXISTS idx_zettel_checksum ON zettel(checksum);
    """
  end

  defp sqlite_insert_statement(zettel) do
    tags_json = Jason.encode!(zettel.tags)
    metadata_json = Jason.encode!(zettel.metadata)
    checksum = compute_checksum(zettel)

    id = String.replace(zettel.id, "'", "''")
    title = String.replace(zettel.title, "'", "''")
    content = String.replace(zettel.content, "'", "''")

    "INSERT OR REPLACE INTO zettel(id, title, content, tags, created_at, metadata, checksum) " <>
      "VALUES('#{id}', '#{title}', '#{content}', '#{tags_json}', '#{zettel.created_at}', '#{metadata_json}', '#{checksum}');"
  end

  defp export_to_sqlite_ddl(zettels) when is_list(zettels) do
    schema = sqlite_create_schema()

    header =
      "-- SMRITI SQLite Export — Reconstruction Guide\n" <>
        "-- Schema version: 1.0.0\n" <>
        "-- Constitutional axiom: Ψ₂ (Evolutionary Continuity)\n" <>
        "-- Columns: id, title, content, tags, created_at, metadata, checksum\n" <>
        "-- Exported at: 2026-01-01T00:00:00Z\n\n"

    inserts = Enum.map_join(zettels, "\n", &sqlite_insert_statement/1)

    {:ok, header <> schema <> "\n" <> inserts}
  end

  defp parse_sqlite_schema(ddl_string) when is_binary(ddl_string) do
    has_table = String.contains?(ddl_string, "CREATE TABLE IF NOT EXISTS zettel")
    has_fts = String.contains?(ddl_string, "CREATE VIRTUAL TABLE IF NOT EXISTS zettel_fts")
    has_fts5 = String.contains?(ddl_string, "USING fts5")
    has_id = String.contains?(ddl_string, "id TEXT PRIMARY KEY")
    has_title = String.contains?(ddl_string, "title TEXT")
    has_content = String.contains?(ddl_string, "content TEXT")
    has_tags = String.contains?(ddl_string, "tags TEXT")
    has_created_at = String.contains?(ddl_string, "created_at TEXT")
    has_checksum = String.contains?(ddl_string, "checksum TEXT")

    %{
      has_zettel_table: has_table,
      has_fts_table: has_fts,
      has_fts5: has_fts5,
      columns: %{
        id: has_id,
        title: has_title,
        content: has_content,
        tags: has_tags,
        created_at: has_created_at,
        checksum: has_checksum
      }
    }
  end

  # ============================================================================
  # SECTION 1 — JSON export field completeness (SC-SMRITI-072)
  # ============================================================================

  describe "JSON export field completeness — SC-SMRITI-072" do
    test "JSON_01: export_to_json/1 returns :ok tuple with binary content" do
      zettels = corpus(3)
      assert {:ok, json_string} = export_to_json(zettels)
      assert is_binary(json_string)
    end

    test "JSON_02: each NDJSON line decodes to a map with id, title, content, tags, created_at" do
      zettels = corpus(4)
      {:ok, json_string} = export_to_json(zettels)

      data_lines =
        json_string
        |> String.split("\n")
        |> Enum.reject(fn line ->
          trimmed = String.trim(line)
          trimmed == "" or String.starts_with?(trimmed, "#")
        end)

      for line <- data_lines do
        {:ok, record} = Jason.decode(line)
        assert Map.has_key?(record, "id"), "Missing 'id' in: #{line}"
        assert Map.has_key?(record, "title"), "Missing 'title' in: #{line}"
        assert Map.has_key?(record, "content"), "Missing 'content' in: #{line}"
        assert Map.has_key?(record, "tags"), "Missing 'tags' in: #{line}"
        assert Map.has_key?(record, "created_at"), "Missing 'created_at' in: #{line}"
      end
    end

    test "JSON_03: each exported record includes a non-empty checksum field" do
      zettels = corpus(2)
      {:ok, json_string} = export_to_json(zettels)

      data_lines =
        json_string
        |> String.split("\n")
        |> Enum.reject(fn l ->
          t = String.trim(l)
          t == "" or String.starts_with?(t, "#")
        end)

      for line <- data_lines do
        {:ok, record} = Jason.decode(line)
        checksum = record["checksum"]
        assert is_binary(checksum), "checksum must be a string"
        assert String.length(checksum) == 64, "SHA-256 hex digest must be 64 chars"
      end
    end

    test "JSON_04: tags field is always a JSON array (not a string)" do
      zettel = build_zettel(id: "json-tags", tags: ["a", "b", "c"])
      {:ok, json_string} = export_to_json([zettel])

      data_line =
        json_string
        |> String.split("\n")
        |> Enum.find(fn l ->
          !String.starts_with?(String.trim(l), "#") and String.trim(l) != ""
        end)

      {:ok, record} = Jason.decode(data_line)
      assert is_list(record["tags"]), "tags must decode as a JSON array"
      assert record["tags"] == ["a", "b", "c"]
    end

    test "JSON_PROP_01: every exported record id matches its source zettel id" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 20
                             ) do
        zettels = corpus(count)
        {:ok, json_string} = export_to_json(zettels)

        data_lines =
          json_string
          |> String.split("\n")
          |> Enum.reject(fn l ->
            t = String.trim(l)
            t == "" or String.starts_with?(t, "#")
          end)

        assert length(data_lines) == count

        for {line, zettel} <- Enum.zip(data_lines, zettels) do
          {:ok, record} = Jason.decode(line)
          assert record["id"] == zettel.id
        end
      end
    end
  end

  # ============================================================================
  # SECTION 2 — Markdown export CommonMark validity (SC-SMRITI-078)
  # ============================================================================

  describe "Markdown export CommonMark validity — SC-SMRITI-078" do
    test "MD_01: export_to_markdown/1 returns :ok tuple with binary content" do
      zettels = corpus(3)
      assert {:ok, md_string} = export_to_markdown(zettels)
      assert is_binary(md_string)
    end

    test "MD_02: exported Markdown contains H1 header for the reconstruction guide" do
      {:ok, md_string} = export_to_markdown(corpus(2))
      assert String.contains?(md_string, "# SMRITI Knowledge Export")
    end

    test "MD_03: each zettel is rendered as an H2 section with title" do
      zettels = corpus(3)
      {:ok, md_string} = export_to_markdown(zettels)

      for zettel <- zettels do
        assert String.contains?(md_string, "## #{zettel.title}"),
               "H2 section missing for '#{zettel.title}'"
      end
    end

    test "MD_04: each zettel section contains a code block for metadata JSON" do
      {:ok, md_string} = export_to_markdown(corpus(2))
      assert String.contains?(md_string, "```json"), "Missing JSON code block"
      assert String.contains?(md_string, "```"), "Missing code fence closing"
    end

    test "MD_05: exported Markdown contains an ordered reconstruction steps list" do
      {:ok, md_string} = export_to_markdown(corpus(1))
      # CommonMark ordered list items start with digit + period
      assert Regex.match?(~r/^\d+\.\s+\w/m, md_string),
             "Missing CommonMark ordered list in reconstruction steps"
    end

    test "MD_PROP_01: every zettel title appears as H2 section in exported Markdown" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..8),
                               max_runs: 15
                             ) do
        zettels = corpus(count)
        {:ok, md_string} = export_to_markdown(zettels)

        for zettel <- zettels do
          assert String.contains?(md_string, "## #{zettel.title}"),
                 "H2 section missing for zettel '#{zettel.id}'"
        end
      end
    end
  end

  # ============================================================================
  # SECTION 3 — SQLite export schema (SC-SMRITI-072)
  # ============================================================================

  describe "SQLite export schema — SC-SMRITI-072" do
    test "SQLITE_01: export_to_sqlite_ddl/1 returns :ok tuple with binary content" do
      zettels = corpus(3)
      assert {:ok, ddl} = export_to_sqlite_ddl(zettels)
      assert is_binary(ddl)
    end

    test "SQLITE_02: DDL contains CREATE TABLE for zettel with all required columns" do
      {:ok, ddl} = export_to_sqlite_ddl(corpus(2))
      schema = parse_sqlite_schema(ddl)
      assert schema.has_zettel_table, "Missing CREATE TABLE zettel"

      for {col, present} <- schema.columns do
        assert present, "Missing column #{col} in zettel schema"
      end
    end

    test "SQLITE_03: DDL contains CREATE VIRTUAL TABLE using fts5 for full-text search" do
      {:ok, ddl} = export_to_sqlite_ddl(corpus(2))
      schema = parse_sqlite_schema(ddl)
      assert schema.has_fts_table, "Missing FTS virtual table"
      assert schema.has_fts5, "FTS table must use fts5 engine (SC-SMRITI-131)"
    end

    test "SQLITE_04: DDL contains INSERT OR REPLACE statement for each zettel" do
      zettels = corpus(5)
      {:ok, ddl} = export_to_sqlite_ddl(zettels)

      insert_count =
        ddl |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "INSERT OR REPLACE"))

      assert insert_count == 5
    end

    test "SQLITE_PROP_01: INSERT count always matches zettel count for any corpus size" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..20),
                               max_runs: 15
                             ) do
        zettels = corpus(count)
        {:ok, ddl} = export_to_sqlite_ddl(zettels)

        insert_count =
          ddl |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "INSERT OR REPLACE"))

        assert insert_count == count
      end
    end
  end

  # ============================================================================
  # SECTION 4 — JSON roundtrip identity
  # ============================================================================

  describe "JSON roundtrip identity" do
    test "RT_JSON_01: import_from_json/1 returns :ok tuple for valid NDJSON export" do
      {:ok, json_string} = export_to_json(corpus(3))
      assert {:ok, imported} = import_from_json(json_string)
      assert is_list(imported)
    end

    test "RT_JSON_02: imported zettel count equals original zettel count" do
      original = corpus(6)
      {:ok, json_string} = export_to_json(original)
      {:ok, imported} = import_from_json(json_string)
      assert length(imported) == length(original)
    end

    test "RT_JSON_03: imported zettel ids match original ids (in order)" do
      original = corpus(4)
      {:ok, json_string} = export_to_json(original)
      {:ok, imported} = import_from_json(json_string)

      for {orig, imp} <- Enum.zip(original, imported) do
        assert imp.id == orig.id,
               "ID mismatch: expected #{orig.id}, got #{imp.id}"
      end
    end

    test "RT_JSON_04: imported zettel titles match original titles" do
      original = corpus(4)
      {:ok, json_string} = export_to_json(original)
      {:ok, imported} = import_from_json(json_string)

      for {orig, imp} <- Enum.zip(original, imported) do
        assert imp.title == orig.title,
               "Title mismatch for #{orig.id}: expected '#{orig.title}', got '#{imp.title}'"
      end
    end

    test "RT_JSON_PROP_01: JSON roundtrip preserves content for any corpus size" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        original = corpus(count)
        {:ok, json_string} = export_to_json(original)
        {:ok, imported} = import_from_json(json_string)

        assert length(imported) == count

        for {orig, imp} <- Enum.zip(original, imported) do
          assert imp.content == orig.content,
                 "Content mismatch for #{orig.id}"
        end
      end
    end
  end

  # ============================================================================
  # SECTION 5 — Markdown roundtrip identity
  # ============================================================================

  describe "Markdown roundtrip identity" do
    test "RT_MD_01: import_from_markdown/1 returns :ok for a valid Markdown export" do
      {:ok, md_string} = export_to_markdown(corpus(3))
      assert {:ok, imported} = import_from_markdown(md_string)
      assert is_list(imported)
    end

    test "RT_MD_02: imported count equals original count" do
      original = corpus(4)
      {:ok, md_string} = export_to_markdown(original)
      {:ok, imported} = import_from_markdown(md_string)
      assert length(imported) == length(original)
    end

    test "RT_MD_03: imported zettel ids match original ids" do
      original = corpus(3)
      {:ok, md_string} = export_to_markdown(original)
      {:ok, imported} = import_from_markdown(md_string)

      for {orig, imp} <- Enum.zip(original, imported) do
        assert imp.id == orig.id,
               "ID mismatch: expected #{orig.id}, got #{inspect(imp.id)}"
      end
    end

    test "RT_MD_04: imported titles match original titles" do
      original = corpus(3)
      {:ok, md_string} = export_to_markdown(original)
      {:ok, imported} = import_from_markdown(md_string)

      for {orig, imp} <- Enum.zip(original, imported) do
        assert imp.title == orig.title,
               "Title mismatch for #{orig.id}: expected '#{orig.title}', got '#{imp.title}'"
      end
    end

    test "RT_MD_PROP_01: Markdown roundtrip preserves zettel IDs for any corpus size" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..6),
                               max_runs: 10
                             ) do
        original = corpus(count)
        {:ok, md_string} = export_to_markdown(original)
        {:ok, imported} = import_from_markdown(md_string)

        assert length(imported) == count

        for {orig, imp} <- Enum.zip(original, imported) do
          assert imp.id == orig.id,
                 "ID lost during Markdown roundtrip for #{orig.id}"
        end
      end
    end
  end

  # ============================================================================
  # SECTION 6 — Reconstruction guide header (SC-SMRITI-071)
  # ============================================================================

  describe "Reconstruction guide header — SC-SMRITI-071" do
    test "GUIDE_01: JSON export includes reconstruction guide comment header" do
      {:ok, json_string} = export_to_json(corpus(2))

      assert String.starts_with?(json_string, "# SMRITI Knowledge Export"),
             "JSON export must begin with reconstruction guide header"
    end

    test "GUIDE_02: Markdown export includes reconstruction guide as H1 section" do
      {:ok, md_string} = export_to_markdown(corpus(2))

      assert String.contains?(md_string, "# SMRITI Knowledge Export — Reconstruction Guide"),
             "Markdown export must include H1 reconstruction guide section"
    end

    test "GUIDE_03: SQLite DDL includes reconstruction guide comment" do
      {:ok, ddl} = export_to_sqlite_ddl(corpus(2))

      assert String.contains?(ddl, "-- SMRITI SQLite Export — Reconstruction Guide"),
             "SQLite DDL must include reconstruction guide comment"
    end

    test "GUIDE_04: reconstruction guide mentions schema version 1.0.0" do
      {:ok, json_string} = export_to_json(corpus(1))
      {:ok, md_string} = export_to_markdown(corpus(1))
      {:ok, ddl} = export_to_sqlite_ddl(corpus(1))

      assert String.contains?(json_string, "1.0.0"),
             "JSON export reconstruction guide must mention schema version"

      assert String.contains?(md_string, "1.0.0"),
             "Markdown export must mention schema version"

      assert String.contains?(ddl, "1.0.0"),
             "SQLite DDL must mention schema version"
    end
  end

  # ============================================================================
  # SECTION 7 — Batch export performance (SC-SMRITI-133 spirit: 5s for 100+)
  # ============================================================================

  describe "Batch export performance — SC-SMRITI-072 (100+ zettels in < 5s)" do
    @tag timeout: 10_000
    test "PERF_01: JSON export of 100 zettels completes within 5 seconds" do
      zettels = corpus(100)
      t0 = System.monotonic_time(:millisecond)
      {:ok, _json_string} = export_to_json(zettels)
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed < 5_000, "JSON export of 100 zettels took #{elapsed}ms (limit: 5000ms)"
    end

    @tag timeout: 10_000
    test "PERF_02: Markdown export of 100 zettels completes within 5 seconds" do
      zettels = corpus(100)
      t0 = System.monotonic_time(:millisecond)
      {:ok, _md_string} = export_to_markdown(zettels)
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed < 5_000, "Markdown export of 100 zettels took #{elapsed}ms (limit: 5000ms)"
    end

    @tag timeout: 10_000
    test "PERF_03: SQLite DDL export of 100 zettels completes within 5 seconds" do
      zettels = corpus(100)
      t0 = System.monotonic_time(:millisecond)
      {:ok, _ddl} = export_to_sqlite_ddl(zettels)
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed < 5_000, "SQLite DDL export of 100 zettels took #{elapsed}ms (limit: 5000ms)"
    end
  end

  # ============================================================================
  # SECTION 8 — Unicode content preservation
  # ============================================================================

  describe "Unicode content preservation" do
    test "UNICODE_01: JSON export preserves CJK characters in content" do
      zettel =
        build_zetzel(
          id: "unicode-cjk",
          title: "汉字知识",
          content: "这是一个包含汉字的知识片段。量子纠缠与霍隆状态。"
        )

      {:ok, json_string} = export_to_json([zettel])
      {:ok, imported} = import_from_json(json_string)

      [imp] = imported

      assert imp.content == zettel.content,
             "CJK content not preserved through JSON roundtrip"
    end

    test "UNICODE_02: JSON export preserves Devanagari characters" do
      zettel =
        build_zetzel(
          id: "unicode-devanagari",
          title: "इन्द्रजाल",
          content: "यह एक सुरक्षित प्रणाली है। होलोन अवस्था और ज़ेनोह संजाल।"
        )

      {:ok, json_string} = export_to_json([zettel])
      {:ok, imported} = import_from_json(json_string)

      [imp] = imported
      assert imp.title == zettel.title, "Devanagari title not preserved"
      assert imp.content == zettel.content, "Devanagari content not preserved"
    end

    test "UNICODE_03: SQLite DDL escapes single quotes in content" do
      zettel =
        build_zetzel(
          id: "unicode-quotes",
          title: "It's a test",
          content: "The node's state is 'valid'. Don't panic."
        )

      {:ok, ddl} = export_to_sqlite_ddl([zettel])
      # Single quotes escaped as '' in SQL
      assert String.contains?(ddl, "It''s a test") or
               String.contains?(ddl, ~s("It's a test")),
             "Single quotes must be escaped in DDL"
    end

    test "UNICODE_PROP_01: JSON roundtrip preserves UTF-8 content for alphanumeric strings" do
      ExUnitProperties.check all(
                               suffix <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               content <- SD.string(:alphanumeric, min_length: 1, max_length: 100),
                               max_runs: 20
                             ) do
        zettel = build_zettel(id: "unicode-#{suffix}", content: content)
        {:ok, json_string} = export_to_json([zettel])
        {:ok, [imp]} = import_from_json(json_string)
        assert imp.content == content
      end
    end
  end

  # ============================================================================
  # SECTION 9 — Empty/nil field graceful output
  # ============================================================================

  describe "Empty/nil field graceful output" do
    test "NIL_01: zettel with empty tags exports tags as empty JSON array" do
      zettel = build_zettel(id: "empty-tags", tags: [])
      {:ok, json_string} = export_to_json([zettel])

      data_line =
        json_string
        |> String.split("\n")
        |> Enum.find(fn l ->
          t = String.trim(l)
          !String.starts_with?(t, "#") and t != ""
        end)

      {:ok, record} = Jason.decode(data_line)
      assert record["tags"] == [], "Empty tags must export as []"
    end

    test "NIL_02: zettel with empty content exports without crashing" do
      zettel = build_zettel(id: "empty-content", content: "")
      assert {:ok, json_string} = export_to_json([zettel])
      assert is_binary(json_string)
    end

    test "NIL_03: zettel with empty metadata exports as empty JSON object" do
      zettel = build_zettel(id: "empty-meta", metadata: %{})
      {:ok, json_string} = export_to_json([zettel])

      data_line =
        json_string
        |> String.split("\n")
        |> Enum.find(fn l ->
          t = String.trim(l)
          !String.starts_with?(t, "#") and t != ""
        end)

      {:ok, record} = Jason.decode(data_line)
      assert record["metadata"] == %{}, "Empty metadata must export as {}"
    end

    test "NIL_04: Markdown export with empty content produces valid section without crashing" do
      zettel = build_zettel(id: "md-empty-content", content: "")
      assert {:ok, md_string} = export_to_markdown([zettel])
      assert String.contains?(md_string, "## #{zettel.title}")
    end
  end

  # ============================================================================
  # SECTION 10 — Property: JSON roundtrip fidelity (SD. generators)
  # ============================================================================

  describe "property: JSON roundtrip fidelity" do
    test "RT_FIDELITY_PROP_01: tags list preserved through JSON roundtrip for any string tags" do
      ExUnitProperties.check all(
                               tags <-
                                 SD.list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 12),
                                   min_length: 0,
                                   max_length: 5
                                 ),
                               max_runs: 20
                             ) do
        zettel = build_zettel(id: "prop-tags-#{:erlang.unique_integer([:positive])}", tags: tags)
        {:ok, json_string} = export_to_json([zettel])
        {:ok, [imp]} = import_from_json(json_string)

        assert imp.tags == tags,
               "Tags not preserved: expected #{inspect(tags)}, got #{inspect(imp.tags)}"
      end
    end

    test "RT_FIDELITY_PROP_02: created_at preserved through JSON roundtrip" do
      ExUnitProperties.check all(
                               year <- SD.integer(2020..2030),
                               month <- SD.integer(1..12),
                               day <- SD.integer(1..28),
                               max_runs: 20
                             ) do
        ts =
          "#{year}-#{String.pad_leading(Integer.to_string(month), 2, "0")}-#{String.pad_leading(Integer.to_string(day), 2, "0")}T00:00:00Z"

        zettel =
          build_zettel(id: "prop-ts-#{:erlang.unique_integer([:positive])}", created_at: ts)

        {:ok, json_string} = export_to_json([zettel])
        {:ok, [imp]} = import_from_json(json_string)
        assert imp.created_at == ts, "created_at not preserved"
      end
    end
  end

  # ============================================================================
  # SECTION 11 — Property: export file sizes scale linearly
  # ============================================================================

  describe "property: export file sizes scale linearly" do
    test "SIZE_PROP_01: JSON export byte size grows with zettel count" do
      ExUnitProperties.check all(
                               n <- SD.integer(1..10),
                               m <- SD.integer(11..20),
                               max_runs: 10
                             ) do
        {:ok, small} = export_to_json(corpus(n))
        {:ok, large} = export_to_json(corpus(m))

        assert byte_size(large) > byte_size(small),
               "Larger corpus (#{m}) must produce larger JSON than smaller (#{n})"
      end
    end

    test "SIZE_PROP_02: SQLite DDL byte size grows with zettel count" do
      ExUnitProperties.check all(
                               n <- SD.integer(1..8),
                               m <- SD.integer(9..16),
                               max_runs: 10
                             ) do
        {:ok, small} = export_to_sqlite_ddl(corpus(n))
        {:ok, large} = export_to_sqlite_ddl(corpus(m))

        assert byte_size(large) > byte_size(small),
               "Larger corpus (#{m}) must produce larger DDL than smaller (#{n})"
      end
    end
  end

  # ============================================================================
  # Private helpers used by Section 8 Unicode tests (alias for clarity)
  # ============================================================================

  # `build_zetzel` is a typo-safe alias matching the unicode test call sites above.
  # It wraps `build_zettel/1` so that the Unicode tests use consistent naming.
  defp build_zetzel(opts), do: build_zettel(opts)
end
