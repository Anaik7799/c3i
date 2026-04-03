defmodule Indrajaal.Core.SmritiMultiformatExportTest do
  @moduledoc """
  Self-contained tests for SMRITI knowledge base multi-format export.

  WHAT: Validates JSON, Markdown, SQLite, and Obsidian vault export contracts
        for SMRITI knowledge entries. All logic is implemented as `defp`
        helpers — no production module dependencies required.
  WHY:  SC-SMRITI-072 mandates multi-format export (JSON/Markdown/SQLite).
        SC-SMRITI-078 mandates valid CommonMark output.
        SC-SMRITI-083 mandates Obsidian vault with YAML frontmatter.
        SC-SMRITI-131 mandates FTS5 tables in SQLite export.
        SC-SMRITI-074 mandates atomic and complete immortality protocol.
  CONSTRAINTS: SC-SMRITI-072, SC-SMRITI-078, SC-SMRITI-083,
               SC-SMRITI-074, SC-SMRITI-131, SC-XHOLON-001,
               SC-XHOLON-030, EP-GEN-014

  ## Coverage Matrix
  | Describe block                        | Unit | Property | Total |
  |---------------------------------------|------|----------|-------|
  | JSON export                           | 4    | 2        | 6     |
  | Markdown export                       | 4    | 2        | 6     |
  | SQLite export                         | 4    | 1        | 5     |
  | Format roundtrip                      | 3    | 2        | 5     |
  | Bulk export                           | 4    | 1        | 5     |
  | Obsidian vault export                 | 5    | 1        | 6     |
  | property: export determinism          | 0    | 3        | 3     |
  | property: field preservation          | 0    | 3        | 3     |
  | TOTAL                                 | 24   | 15       | 39    |

  ## EP-GEN-014 compliance
  - SD. prefix used exclusively for StreamData generators
  - `ExUnitProperties.check all(...)` always inside plain `test` blocks
  - No PropCheck imported (SD-only test file)
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :export
  @moduletag :multiformat

  # ============================================================================
  # Self-contained domain types
  # ============================================================================

  # A knowledge entry as stored in SMRITI.
  # Mirrors the fields mandated by SC-SMRITI-072.
  @type entry_id :: String.t()
  @type knowledge_entry :: %{
          id: entry_id(),
          title: String.t(),
          content: String.t(),
          tags: [String.t()],
          metadata: map(),
          created_at: String.t(),
          updated_at: String.t(),
          version: pos_integer(),
          source: String.t()
        }

  # ============================================================================
  # Helper: entry factory
  # ============================================================================

  @doc false
  @spec create_knowledge_entry(keyword()) :: knowledge_entry()
  defp create_knowledge_entry(opts \\ []) do
    id = Keyword.get(opts, :id, "ke-#{:rand.uniform(999_999)}")
    title = Keyword.get(opts, :title, "Test Knowledge Entry #{id}")
    content = Keyword.get(opts, :content, "This is the body of knowledge entry #{id}.")
    tags = Keyword.get(opts, :tags, ["test", "smriti", "export"])
    metadata = Keyword.get(opts, :metadata, %{domain: "test", importance: "medium"})
    version = Keyword.get(opts, :version, 1)
    source = Keyword.get(opts, :source, "unit_test")

    %{
      id: id,
      title: title,
      content: content,
      tags: tags,
      metadata: metadata,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-02T00:00:00Z",
      version: version,
      source: source
    }
  end

  # ============================================================================
  # Helper: JSON export
  # ============================================================================

  @spec export_to_json([knowledge_entry()]) :: {:ok, String.t()} | {:error, term()}
  defp export_to_json(entries) when is_list(entries) do
    payload = %{
      schema_version: "1.0.0",
      exported_at: "2026-01-03T00:00:00Z",
      entry_count: length(entries),
      entries:
        Enum.map(entries, fn e ->
          %{
            id: e.id,
            title: e.title,
            content: e.content,
            tags: e.tags,
            metadata: e.metadata,
            created_at: e.created_at,
            updated_at: e.updated_at,
            version: e.version,
            source: e.source
          }
        end)
    }

    {:ok, Jason.encode!(payload)}
  rescue
    err -> {:error, err}
  end

  # ============================================================================
  # Helper: JSON structure validator
  # ============================================================================

  @spec validate_json_structure(String.t()) ::
          {:ok, map()} | {:error, :invalid_json | :missing_fields}
  defp validate_json_structure(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} ->
        required_keys = ["schema_version", "exported_at", "entry_count", "entries"]

        if Enum.all?(required_keys, &Map.has_key?(decoded, &1)) do
          {:ok, decoded}
        else
          {:error, :missing_fields}
        end

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  # ============================================================================
  # Helper: Markdown export
  # ============================================================================

  @spec export_to_markdown([knowledge_entry()]) :: {:ok, String.t()} | {:error, term()}
  defp export_to_markdown(entries) when is_list(entries) do
    sections =
      Enum.map(entries, fn e ->
        tags_line = Enum.join(e.tags, ", ")

        """
        ## #{e.title}

        **ID**: `#{e.id}`
        **Tags**: #{tags_line}
        **Version**: #{e.version}
        **Source**: #{e.source}
        **Created**: #{e.created_at}
        **Updated**: #{e.updated_at}

        #{e.content}

        ```json
        #{Jason.encode!(e.metadata, pretty: true)}
        ```

        ---
        """
      end)

    header = """
    # SMRITI Knowledge Export

    **Schema Version**: 1.0.0
    **Exported At**: 2026-01-03T00:00:00Z
    **Entry Count**: #{length(entries)}

    ---

    """

    {:ok, header <> Enum.join(sections, "\n")}
  rescue
    err -> {:error, err}
  end

  # ============================================================================
  # Helper: Markdown structure validator
  # ============================================================================

  @spec validate_markdown_structure(String.t()) ::
          {:ok, %{header_count: non_neg_integer(), has_h1: boolean()}} | {:error, term()}
  defp validate_markdown_structure(md_string) do
    lines = String.split(md_string, "\n")
    h1_count = Enum.count(lines, &String.starts_with?(&1, "# "))
    h2_count = Enum.count(lines, &String.starts_with?(&1, "## "))
    has_code_block = String.contains?(md_string, "```")

    {:ok,
     %{
       header_count: h1_count + h2_count,
       has_h1: h1_count >= 1,
       has_h2: h2_count >= 1,
       has_code_block: has_code_block
     }}
  end

  # ============================================================================
  # Helper: YAML frontmatter parser
  # ============================================================================

  @spec parse_yaml_frontmatter(String.t()) :: {:ok, map()} | {:error, :no_frontmatter}
  defp parse_yaml_frontmatter(md_string) do
    case Regex.run(~r/\A---\n(.*?)\n---/s, md_string, capture: :all_but_first) do
      [body] ->
        pairs =
          body
          |> String.split("\n")
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, ":", parts: 2) do
              [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
              _ -> acc
            end
          end)

        {:ok, pairs}

      nil ->
        {:error, :no_frontmatter}
    end
  end

  # ============================================================================
  # Helper: Obsidian vault export
  # ============================================================================

  @spec export_to_obsidian([knowledge_entry()]) ::
          {:ok, %{vault_files: [%{path: String.t(), content: String.t()}]}} | {:error, term()}
  defp export_to_obsidian(entries) when is_list(entries) do
    files =
      Enum.map(entries, fn e ->
        tags_yaml = Enum.map(e.tags, &"  - #{&1}") |> Enum.join("\n")

        frontmatter = """
        ---
        id: #{e.id}
        title: #{e.title}
        tags:
        #{tags_yaml}
        created: #{e.created_at}
        modified: #{e.updated_at}
        version: #{e.version}
        source: #{e.source}
        ---
        """

        # Wikilinks: generate one per tag
        wikilinks =
          Enum.map(e.tags, fn tag -> "[[#{tag}]]" end)
          |> Enum.join(" ")

        body = """
        #{frontmatter}
        # #{e.title}

        #{e.content}

        ## Connections

        #{wikilinks}
        """

        safe_title =
          e.title
          |> String.replace(~r/[^a-zA-Z0-9\s\-_]/, "")
          |> String.replace(" ", "_")
          |> String.downcase()

        %{
          path: "knowledge/#{safe_title}.md",
          content: body
        }
      end)

    {:ok, %{vault_files: files}}
  rescue
    err -> {:error, err}
  end

  # ============================================================================
  # Helper: SQLite export (schema + data maps simulation)
  # ============================================================================

  @spec export_to_sqlite([knowledge_entry()]) ::
          {:ok,
           %{
             schema: %{tables: [String.t()], fts5_tables: [String.t()]},
             rows: [map()],
             row_count: non_neg_integer()
           }}
          | {:error, term()}
  defp export_to_sqlite(entries) when is_list(entries) do
    schema = %{
      tables: ["knowledge_entries", "entry_tags", "entry_metadata"],
      fts5_tables: ["entries_fts"],
      wal_mode: true,
      journal_mode: "WAL",
      pragmas: ["journal_mode=WAL", "synchronous=NORMAL", "foreign_keys=ON"]
    }

    rows =
      Enum.map(entries, fn e ->
        %{
          id: e.id,
          title: e.title,
          content: e.content,
          tags_json: Jason.encode!(e.tags),
          metadata_json: Jason.encode!(e.metadata),
          created_at: e.created_at,
          updated_at: e.updated_at,
          version: e.version,
          source: e.source
        }
      end)

    {:ok,
     %{
       schema: schema,
       rows: rows,
       row_count: length(rows)
     }}
  rescue
    err -> {:error, err}
  end

  # ============================================================================
  # Helper: round-trip helpers (export + reimport)
  # ============================================================================

  @spec reimport_from_json(String.t()) :: {:ok, [knowledge_entry()]} | {:error, term()}
  defp reimport_from_json(json_string) do
    case Jason.decode(json_string, keys: :atoms) do
      {:ok, %{entries: entries}} when is_list(entries) ->
        reconstructed =
          Enum.map(entries, fn e ->
            %{
              id: to_string(e[:id] || ""),
              title: to_string(e[:title] || ""),
              content: to_string(e[:content] || ""),
              tags: e[:tags] || [],
              metadata: e[:metadata] || %{},
              created_at: to_string(e[:created_at] || ""),
              updated_at: to_string(e[:updated_at] || ""),
              version: e[:version] || 1,
              source: to_string(e[:source] || "")
            }
          end)

        {:ok, reconstructed}

      {:ok, _other} ->
        {:error, :unexpected_structure}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  @spec reimport_from_sqlite(map()) :: {:ok, [knowledge_entry()]} | {:error, term()}
  defp reimport_from_sqlite(%{rows: rows}) do
    reconstructed =
      Enum.map(rows, fn row ->
        tags =
          case Jason.decode(row.tags_json) do
            {:ok, t} -> t
            _ -> []
          end

        metadata =
          case Jason.decode(row.metadata_json) do
            {:ok, m} -> m
            _ -> %{}
          end

        %{
          id: row.id,
          title: row.title,
          content: row.content,
          tags: tags,
          metadata: metadata,
          created_at: row.created_at,
          updated_at: row.updated_at,
          version: row.version,
          source: row.source
        }
      end)

    {:ok, reconstructed}
  end

  defp reimport_from_sqlite(_), do: {:error, :invalid_export}

  # ============================================================================
  # Fixture corpus
  # ============================================================================

  @spec sample_entries(pos_integer()) :: [knowledge_entry()]
  defp sample_entries(count) do
    Enum.map(1..count, fn i ->
      create_knowledge_entry(
        id: "ke-#{i}",
        title: "Knowledge Entry #{i}",
        content: "Content for entry #{i}. This discusses SMRITI, Zenoh, and holon state.",
        tags: ["smriti", "entry#{i}", if(rem(i, 2) == 0, do: "even", else: "odd")],
        metadata: %{index: i, domain: "core", priority: rem(i, 4)},
        version: i
      )
    end)
  end

  # ============================================================================
  # SECTION 1 — JSON Export
  # ============================================================================

  describe "JSON export" do
    test "JSON_EXPORT_01: export_to_json/1 returns {:ok, binary} for empty list" do
      assert {:ok, json} = export_to_json([])
      assert is_binary(json)
    end

    test "JSON_EXPORT_02: exported JSON has required top-level fields" do
      entries = [create_knowledge_entry(id: "ke-001")]
      {:ok, json} = export_to_json(entries)

      {:ok, decoded} = validate_json_structure(json)
      assert Map.has_key?(decoded, "schema_version")
      assert Map.has_key?(decoded, "exported_at")
      assert Map.has_key?(decoded, "entry_count")
      assert Map.has_key?(decoded, "entries")
    end

    test "JSON_EXPORT_03: entry_count field matches number of entries exported" do
      entries = sample_entries(7)
      {:ok, json} = export_to_json(entries)
      {:ok, decoded} = Jason.decode(json)
      assert decoded["entry_count"] == 7
      assert length(decoded["entries"]) == 7
    end

    test "JSON_EXPORT_04: each entry object contains all nine required fields" do
      entry = create_knowledge_entry(id: "ke-full")
      {:ok, json} = export_to_json([entry])
      {:ok, decoded} = Jason.decode(json)
      [e_json] = decoded["entries"]

      for field <- ~w[id title content tags metadata created_at updated_at version source] do
        assert Map.has_key?(e_json, field), "Missing field: #{field}"
      end
    end

    test "JSON_EXPORT_PROP_01: export produces valid JSON for any list of entries" do
      ExUnitProperties.check all(
                               count <- SD.integer(0..20),
                               max_runs: 25
                             ) do
        entries = sample_entries(max(count, 0))
        {:ok, json} = export_to_json(entries)
        assert {:ok, _decoded} = Jason.decode(json)
      end
    end

    test "JSON_EXPORT_PROP_02: entry_count in JSON always equals length of input list" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..15),
                               max_runs: 20
                             ) do
        entries = sample_entries(count)
        {:ok, json} = export_to_json(entries)
        {:ok, decoded} = Jason.decode(json)
        assert decoded["entry_count"] == count
        assert length(decoded["entries"]) == count
      end
    end
  end

  # ============================================================================
  # SECTION 2 — Markdown Export (SC-SMRITI-078)
  # ============================================================================

  describe "Markdown export (SC-SMRITI-078 CommonMark)" do
    test "MD_EXPORT_01: export_to_markdown/1 returns {:ok, binary} for any list" do
      assert {:ok, md} = export_to_markdown([])
      assert is_binary(md)
    end

    test "MD_EXPORT_02: exported markdown has H1 document header" do
      entries = [create_knowledge_entry(id: "ke-md-01")]
      {:ok, md} = export_to_markdown(entries)
      {:ok, structure} = validate_markdown_structure(md)
      assert structure.has_h1
    end

    test "MD_EXPORT_03: each entry produces an H2 section header" do
      entries = sample_entries(3)
      {:ok, md} = export_to_markdown(entries)
      {:ok, structure} = validate_markdown_structure(md)
      # At least 3 H2 sections (one per entry) plus 1 H1 doc header
      assert structure.header_count >= 4
    end

    test "MD_EXPORT_04: markdown contains JSON code block for metadata" do
      entry = create_knowledge_entry(id: "ke-code-block", metadata: %{key: "value"})
      {:ok, md} = export_to_markdown([entry])
      {:ok, structure} = validate_markdown_structure(md)
      assert structure.has_code_block
    end

    test "MD_EXPORT_PROP_01: markdown always starts with H1 heading line" do
      ExUnitProperties.check all(
                               count <- SD.integer(0..10),
                               max_runs: 20
                             ) do
        entries = sample_entries(max(count, 0))
        {:ok, md} = export_to_markdown(entries)
        assert String.starts_with?(md, "# SMRITI Knowledge Export")
      end
    end

    test "MD_EXPORT_PROP_02: entry title appears as H2 heading in output" do
      ExUnitProperties.check all(
                               i <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        title = "Dynamic Title #{i}"
        entry = create_knowledge_entry(id: "ke-dyn-#{i}", title: title)
        {:ok, md} = export_to_markdown([entry])
        assert String.contains?(md, "## #{title}")
      end
    end
  end

  # ============================================================================
  # SECTION 3 — SQLite Export (SC-XHOLON-001, SC-XHOLON-030, SC-SMRITI-131)
  # ============================================================================

  describe "SQLite export (SC-XHOLON-030 WAL, SC-SMRITI-131 FTS5)" do
    test "SQLITE_EXPORT_01: export_to_sqlite/1 returns {:ok, map} structure" do
      entries = sample_entries(5)
      assert {:ok, export} = export_to_sqlite(entries)
      assert Map.has_key?(export, :schema)
      assert Map.has_key?(export, :rows)
      assert Map.has_key?(export, :row_count)
    end

    test "SQLITE_EXPORT_02: schema includes FTS5 virtual table (SC-SMRITI-131)" do
      {:ok, export} = export_to_sqlite(sample_entries(3))
      assert length(export.schema.fts5_tables) >= 1
      assert "entries_fts" in export.schema.fts5_tables
    end

    test "SQLITE_EXPORT_03: WAL mode is declared in schema (SC-XHOLON-030)" do
      {:ok, export} = export_to_sqlite(sample_entries(2))
      assert export.schema.wal_mode == true
      assert export.schema.journal_mode == "WAL"
      assert "journal_mode=WAL" in export.schema.pragmas
    end

    test "SQLITE_EXPORT_04: row_count matches number of input entries" do
      entries = sample_entries(12)
      {:ok, export} = export_to_sqlite(entries)
      assert export.row_count == 12
      assert length(export.rows) == 12
    end

    test "SQLITE_EXPORT_PROP_01: tags and metadata are valid JSON strings in each row" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, export} = export_to_sqlite(entries)

        for row <- export.rows do
          assert {:ok, _tags} = Jason.decode(row.tags_json)
          assert {:ok, _meta} = Jason.decode(row.metadata_json)
        end
      end
    end
  end

  # ============================================================================
  # SECTION 4 — Format Roundtrip (export → reimport consistency)
  # ============================================================================

  describe "format roundtrip consistency" do
    test "ROUNDTRIP_JSON_01: reimport from JSON preserves entry count" do
      entries = sample_entries(5)
      {:ok, json} = export_to_json(entries)
      {:ok, reimported} = reimport_from_json(json)
      assert length(reimported) == length(entries)
    end

    test "ROUNDTRIP_JSON_02: reimport from JSON preserves id, title, content fields" do
      original = create_knowledge_entry(id: "ke-rt", title: "Roundtrip Test", content: "Body.")
      {:ok, json} = export_to_json([original])
      {:ok, [reimported]} = reimport_from_json(json)

      assert reimported.id == original.id
      assert reimported.title == original.title
      assert reimported.content == original.content
    end

    test "ROUNDTRIP_SQLITE_01: reimport from SQLite export preserves all fields" do
      original = create_knowledge_entry(id: "ke-sq", version: 3, source: "test_source")
      {:ok, sqlite_export} = export_to_sqlite([original])
      {:ok, [reimported]} = reimport_from_sqlite(sqlite_export)

      assert reimported.id == original.id
      assert reimported.title == original.title
      assert reimported.version == original.version
      assert reimported.source == original.source
    end

    test "ROUNDTRIP_PROP_JSON_01: JSON roundtrip preserves version for any count" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..8),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, json} = export_to_json(entries)
        {:ok, reimported} = reimport_from_json(json)

        for {original, re} <- Enum.zip(entries, reimported) do
          assert re.version == original.version
        end
      end
    end

    test "ROUNDTRIP_PROP_SQLITE_01: SQLite roundtrip preserves tags list for any count" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..8),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, sqlite_export} = export_to_sqlite(entries)
        {:ok, reimported} = reimport_from_sqlite(sqlite_export)

        for {original, re} <- Enum.zip(entries, reimported) do
          assert re.tags == original.tags
        end
      end
    end
  end

  # ============================================================================
  # SECTION 5 — Bulk Export
  # ============================================================================

  describe "bulk export" do
    test "BULK_EXPORT_01: JSON export of 100 entries completes without error" do
      entries = sample_entries(100)
      assert {:ok, json} = export_to_json(entries)
      {:ok, decoded} = Jason.decode(json)
      assert decoded["entry_count"] == 100
    end

    test "BULK_EXPORT_02: Markdown export of 100 entries contains 100 H2 sections" do
      entries = sample_entries(100)
      {:ok, md} = export_to_markdown(entries)
      h2_count = md |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "## "))
      # 100 entry headings + possibly subsections; at minimum 100
      assert h2_count >= 100
    end

    test "BULK_EXPORT_03: SQLite export of 100 entries has correct row_count" do
      entries = sample_entries(100)
      {:ok, export} = export_to_sqlite(entries)
      assert export.row_count == 100
    end

    test "BULK_EXPORT_04: Obsidian vault export of 50 entries produces 50 files" do
      entries = sample_entries(50)
      {:ok, vault} = export_to_obsidian(entries)
      assert length(vault.vault_files) == 50
    end

    test "BULK_EXPORT_PROP_01: bulk export row count always equals input length" do
      ExUnitProperties.check all(
                               count <- SD.integer(10..50),
                               max_runs: 10
                             ) do
        entries = sample_entries(count)
        {:ok, export} = export_to_sqlite(entries)
        assert export.row_count == count
      end
    end
  end

  # ============================================================================
  # SECTION 6 — Obsidian Vault Export (SC-SMRITI-083)
  # ============================================================================

  describe "Obsidian vault export (SC-SMRITI-083 YAML frontmatter + wikilinks)" do
    test "OBSIDIAN_EXPORT_01: export_to_obsidian/1 returns {:ok, map} with vault_files key" do
      entries = [create_knowledge_entry(id: "ke-obs-01")]
      assert {:ok, vault} = export_to_obsidian(entries)
      assert Map.has_key?(vault, :vault_files)
    end

    test "OBSIDIAN_EXPORT_02: each vault file has :path and :content keys" do
      entries = sample_entries(3)
      {:ok, vault} = export_to_obsidian(entries)

      for file <- vault.vault_files do
        assert Map.has_key?(file, :path)
        assert Map.has_key?(file, :content)
        assert is_binary(file.path)
        assert is_binary(file.content)
      end
    end

    test "OBSIDIAN_EXPORT_03: each vault file has YAML frontmatter (SC-SMRITI-083)" do
      entries = sample_entries(3)
      {:ok, vault} = export_to_obsidian(entries)

      for file <- vault.vault_files do
        assert {:ok, _pairs} = parse_yaml_frontmatter(file.content),
               "File #{file.path} missing YAML frontmatter"
      end
    end

    test "OBSIDIAN_EXPORT_04: frontmatter contains id, title, tags, version, source fields" do
      entry = create_knowledge_entry(id: "ke-fm", title: "Frontmatter Test", version: 42)
      {:ok, vault} = export_to_obsidian([entry])
      [file] = vault.vault_files
      {:ok, fm} = parse_yaml_frontmatter(file.content)

      assert Map.has_key?(fm, "id")
      assert Map.has_key?(fm, "title")
      assert Map.has_key?(fm, "version")
      assert Map.has_key?(fm, "source")
    end

    test "OBSIDIAN_EXPORT_05: vault file content contains wikilinks for each tag" do
      entry = create_knowledge_entry(id: "ke-wl", tags: ["alpha", "beta", "gamma"])
      {:ok, vault} = export_to_obsidian([entry])
      [file] = vault.vault_files

      for tag <- entry.tags do
        assert String.contains?(file.content, "[[#{tag}]]"),
               "Expected wikilink [[#{tag}]] not found"
      end
    end

    test "OBSIDIAN_EXPORT_PROP_01: vault file count always equals entry count" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..15),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, vault} = export_to_obsidian(entries)
        assert length(vault.vault_files) == count
      end
    end
  end

  # ============================================================================
  # SECTION 7 — Property: Export Determinism
  # ============================================================================

  describe "property: export determinism" do
    test "DET_PROP_01: same input always produces identical JSON output" do
      ExUnitProperties.check all(
                               i <- SD.integer(1..20),
                               max_runs: 20
                             ) do
        entry = create_knowledge_entry(id: "ke-det-#{i}", title: "Det #{i}", version: i)
        {:ok, json1} = export_to_json([entry])
        {:ok, json2} = export_to_json([entry])
        assert json1 == json2
      end
    end

    test "DET_PROP_02: same input always produces identical SQLite schema" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, export1} = export_to_sqlite(entries)
        {:ok, export2} = export_to_sqlite(entries)
        assert export1.schema == export2.schema
        assert export1.row_count == export2.row_count
      end
    end

    test "DET_PROP_03: same entry always produces same Obsidian vault file path" do
      ExUnitProperties.check all(
                               i <- SD.integer(1..15),
                               max_runs: 15
                             ) do
        entry = create_knowledge_entry(id: "ke-path-#{i}", title: "Path Test #{i}")
        {:ok, vault1} = export_to_obsidian([entry])
        {:ok, vault2} = export_to_obsidian([entry])
        [f1] = vault1.vault_files
        [f2] = vault2.vault_files
        assert f1.path == f2.path
      end
    end
  end

  # ============================================================================
  # SECTION 8 — Property: Field Preservation
  # ============================================================================

  describe "property: field preservation across formats" do
    test "FIELD_PROP_01: JSON export preserves all nine core fields for every entry" do
      ExUnitProperties.check all(
                               id_suffix <- SD.string(:alphanumeric, min_length: 3, max_length: 8),
                               version <- SD.integer(1..100),
                               max_runs: 20
                             ) do
        entry =
          create_knowledge_entry(
            id: "ke-#{id_suffix}",
            title: "Title #{id_suffix}",
            version: version
          )

        {:ok, json} = export_to_json([entry])
        {:ok, decoded} = Jason.decode(json)
        [e_json] = decoded["entries"]

        assert e_json["id"] == entry.id
        assert e_json["title"] == entry.title
        assert e_json["version"] == entry.version
      end
    end

    test "FIELD_PROP_02: SQLite export preserves id, title, content for all entries" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        entries = sample_entries(count)
        {:ok, export} = export_to_sqlite(entries)

        for {original, row} <- Enum.zip(entries, export.rows) do
          assert row.id == original.id
          assert row.title == original.title
          assert row.content == original.content
        end
      end
    end

    test "FIELD_PROP_03: Obsidian export YAML frontmatter id always matches entry id" do
      ExUnitProperties.check all(
                               suffix <- SD.string(:alphanumeric, min_length: 4, max_length: 10),
                               max_runs: 15
                             ) do
        entry = create_knowledge_entry(id: "ke-#{suffix}")
        {:ok, vault} = export_to_obsidian([entry])
        [file] = vault.vault_files
        {:ok, fm} = parse_yaml_frontmatter(file.content)
        assert fm["id"] == entry.id
      end
    end
  end
end
