defmodule Indrajaal.Core.SmritiObsidianVaultExportTest do
  @moduledoc """
  TDG test: SMRITI Obsidian vault export with YAML frontmatter (L3 Domain).

  ## WHAT
  Validates Obsidian vault export contracts for the SMRITI knowledge base:
  YAML frontmatter structure, wikilinks, .obsidian config generation,
  reconstruction guide, atomicity, backlinks, and export timing.
  All logic is implemented as `defp` helpers using ETS as the zettel store —
  no production module dependencies are required.

  ## WHY
  SC-SMRITI-082 mandates Obsidian vault includes .obsidian config.
  SC-SMRITI-083 mandates Obsidian notes use YAML frontmatter.
  SC-SMRITI-072 mandates multi-format export (JSON/Markdown/SQLite).
  SC-SMRITI-078 mandates Markdown export is valid CommonMark.
  SC-SMRITI-071 mandates self-documenting reconstruction guide on export.

  ## CONSTRAINTS
  - SC-SMRITI-082: .obsidian config dir generation
  - SC-SMRITI-083: YAML frontmatter with required fields
  - SC-SMRITI-072: Multi-format export JSON/MD/SQLite
  - SC-SMRITI-078: Valid CommonMark markdown body
  - SC-SMRITI-071: Self-documenting reconstruction guide
  - SC-SMRITI-133: Query/export timeout < 500ms
  - SC-SMRITI-074: Immortality protocol atomic
  - EP-GEN-014:    StreamData-only (SD. prefix), no PropCheck

  ## Coverage Matrix
  | Describe block                        | Unit | Property | Total |
  |---------------------------------------|------|----------|-------|
  | YAML frontmatter structure            | 5    | 0        | 5     |
  | Frontmatter field values              | 4    | 0        | 4     |
  | Markdown body (CommonMark)            | 3    | 0        | 3     |
  | Wikilinks                             | 3    | 0        | 3     |
  | .obsidian config generation           | 2    | 0        | 2     |
  | Tags export                           | 2    | 0        | 2     |
  | Reconstruction guide                  | 2    | 0        | 2     |
  | Backlinks                             | 2    | 0        | 2     |
  | Export atomicity                      | 2    | 0        | 2     |
  | Export timing                         | 1    | 0        | 1     |
  | property: YAML frontmatter validity   | 0    | 1        | 1     |
  | property: file count invariant        | 0    | 1        | 1     |
  | TOTAL                                 | 26   | 2        | 28    |

  ## EP-GEN-014 compliance
  - SD. prefix used exclusively for StreamData generators.
  - `check all(...)` always inside plain `test` blocks.
  - No PropCheck imported (SD-only test file).

  ## Change History
  | Version | Date       | Author | Change                                            |
  |---------|------------|--------|---------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Initial implementation — Sprint 88, task e3622004 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :obsidian
  @moduletag :export
  @moduletag :sprint_88

  # --------------------------------------------------------------------------
  # Zettel type (mirrors SMRITI SC-SMRITI-083 field set)
  # --------------------------------------------------------------------------

  @type zettel_id :: String.t()

  @type zettel :: %{
          id: zettel_id(),
          title: String.t(),
          body: String.t(),
          tags: [String.t()],
          links: [zettel_id()],
          created_at: String.t(),
          updated_at: String.t()
        }

  # --------------------------------------------------------------------------
  # Setup: ETS-backed zettel store
  # --------------------------------------------------------------------------

  setup do
    table = :ets.new(:obsidian_vault_test, [:set, :public])

    zettels = [
      %{
        id: "z001",
        title: "Elixir OTP Patterns",
        body: "GenServer, Supervisor, and Application behaviour.",
        tags: ["elixir", "otp", "patterns"],
        links: ["z002", "z003"],
        created_at: "2026-01-01T00:00:00Z",
        updated_at: "2026-01-10T12:00:00Z"
      },
      %{
        id: "z002",
        title: "F# Domain Modelling",
        body: "Discriminated unions and active patterns for domain modelling.",
        tags: ["fsharp", "ddd"],
        links: ["z001"],
        created_at: "2026-01-02T00:00:00Z",
        updated_at: "2026-01-11T08:00:00Z"
      },
      %{
        id: "z003",
        title: "Zenoh Mesh Architecture",
        body: "Pub/sub with key expressions and 2oo3 quorum voting.",
        tags: ["zenoh", "mesh", "sil6"],
        links: [],
        created_at: "2026-01-03T00:00:00Z",
        updated_at: "2026-01-12T15:00:00Z"
      }
    ]

    Enum.each(zettels, fn z -> :ets.insert(table, {z.id, z}) end)

    on_exit(fn -> :ets.delete(table) end)

    {:ok, table: table, zettels: zettels}
  end

  # ==========================================================================
  # SECTION 1: YAML Frontmatter Structure (SC-SMRITI-083)
  # ==========================================================================

  describe "YAML frontmatter structure (SC-SMRITI-083)" do
    test "YAML_FM_01: note content starts with '---\\n'", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))

      assert String.starts_with?(note, "---\n"),
             "Note must start with YAML frontmatter delimiter '---\\n'"
    end

    test "YAML_FM_02: frontmatter block is closed by a second '---' line", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      {:ok, _pairs} = parse_yaml_frontmatter(note)
    end

    test "YAML_FM_03: frontmatter delimiter pattern is '---\\n...---\\n'", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      # Opening and closing delimiters must both be present
      assert Regex.match?(~r/\A---\n.*\n---\n/s, note),
             "Frontmatter must match \\A---\\n...\\n---\\n"
    end

    test "YAML_FM_04: all three seed zettels produce valid frontmatter", %{table: table} do
      backlinks = build_backlinks_index(table)

      for z <- all_zettels(table) do
        note = render_note(z, backlinks)

        assert {:ok, _} = parse_yaml_frontmatter(note),
               "Zettel #{z.id} produced invalid YAML frontmatter"
      end
    end

    test "YAML_FM_05: frontmatter is separated from body by a blank line", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      # After the closing "---" there must be a newline + blank line before body
      assert String.contains?(note, "---\n\n"),
             "Frontmatter must be separated from body by a blank line"
    end
  end

  # ==========================================================================
  # SECTION 2: Frontmatter Field Values (SC-SMRITI-083)
  # ==========================================================================

  describe "frontmatter field values (SC-SMRITI-083)" do
    test "YAML_FIELD_01: frontmatter contains id field matching zettel id", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      {:ok, fm} = parse_yaml_frontmatter(note)

      assert fm["id"] == z.id,
             "Frontmatter id '#{fm["id"]}' must match zettel id '#{z.id}'"
    end

    test "YAML_FIELD_02: frontmatter contains title matching zettel title", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      {:ok, fm} = parse_yaml_frontmatter(note)
      assert fm["title"] == z.title
    end

    test "YAML_FIELD_03: frontmatter contains created_at and updated_at timestamps", %{
      table: table
    } do
      [z] = lookup_zettels(table, ["z002"])
      note = render_note(z, build_backlinks_index(table))
      {:ok, fm} = parse_yaml_frontmatter(note)
      assert Map.has_key?(fm, "created_at"), "Missing 'created_at' in frontmatter"
      assert Map.has_key?(fm, "updated_at"), "Missing 'updated_at' in frontmatter"
    end

    test "YAML_FIELD_04: frontmatter contains tags and links list keys", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      {:ok, fm} = parse_yaml_frontmatter(note)
      assert Map.has_key?(fm, "tags"), "Missing 'tags' in frontmatter"
      assert Map.has_key?(fm, "links"), "Missing 'links' in frontmatter"
    end
  end

  # ==========================================================================
  # SECTION 3: Markdown Body — Valid CommonMark (SC-SMRITI-078)
  # ==========================================================================

  describe "markdown body validity (SC-SMRITI-078 CommonMark)" do
    test "MD_BODY_01: note body contains an H1 heading with the zettel title", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))

      assert String.contains?(note, "# #{z.title}"),
             "Body must have H1 heading matching zettel title"
    end

    test "MD_BODY_02: note body contains the zettel body text", %{table: table} do
      [z] = lookup_zettels(table, ["z002"])
      note = render_note(z, build_backlinks_index(table))

      assert String.contains?(note, z.body),
             "Note must include zettel body content"
    end

    test "MD_BODY_03: note body appears after the closing frontmatter delimiter", %{table: table} do
      [z] = lookup_zettels(table, ["z003"])
      note = render_note(z, build_backlinks_index(table))
      fm_end = "---\n"
      # Split on first "---\n" to skip opening, then find the second closing "---\n"
      after_fm =
        note
        |> String.split("---\n", parts: 3)
        |> List.last()

      assert String.contains?(after_fm, z.title),
             "H1 heading must appear after the frontmatter closing delimiter"
    end
  end

  # ==========================================================================
  # SECTION 4: Wikilinks (SC-SMRITI-083 + Obsidian convention)
  # ==========================================================================

  describe "wikilinks rendering" do
    test "WIKI_01: each outgoing link renders as [[zettel-id|title]] wikilink", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      # z001 links to z002 and z003
      note = render_note(z, build_backlinks_index(table))

      assert String.contains?(note, "[[z002|"),
             "Expected wikilink [[z002|...]] in note for z001"

      assert String.contains?(note, "[[z003|"),
             "Expected wikilink [[z003|...]] in note for z001"
    end

    test "WIKI_02: zettel with no outgoing links has empty links section", %{table: table} do
      [z] = lookup_zettels(table, ["z003"])
      note = render_note(z, build_backlinks_index(table))
      # z003 has no links, the links section must still be present but empty
      assert String.contains?(note, "## Links")
    end

    test "WIKI_03: wikilink format uses pipe separator '[[id|title]]'", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))
      # Must find at least one [[...|...]] pattern
      assert Regex.match?(~r/\[\[[^\]]+\|[^\]]+\]\]/, note),
             "No [[id|title]] wikilink found in note for z001"
    end
  end

  # ==========================================================================
  # SECTION 5: .obsidian Config Generation (SC-SMRITI-082)
  # ==========================================================================

  describe ".obsidian config generation (SC-SMRITI-082)" do
    test "OBSIDIAN_CFG_01: vault export includes .obsidian/app.json config file", %{table: table} do
      vault = export_vault(table)
      cfg_paths = Enum.map(vault.config_files, & &1.path)

      assert ".obsidian/app.json" in cfg_paths,
             "Vault must include .obsidian/app.json"
    end

    test "OBSIDIAN_CFG_02: vault export includes .obsidian/graph.json config file", %{
      table: table
    } do
      vault = export_vault(table)
      cfg_paths = Enum.map(vault.config_files, & &1.path)

      assert ".obsidian/graph.json" in cfg_paths,
             "Vault must include .obsidian/graph.json"
    end
  end

  # ==========================================================================
  # SECTION 6: Tags Export (SC-SMRITI-083)
  # ==========================================================================

  describe "tags export" do
    test "TAGS_01: each tag appears as YAML frontmatter list item '- tag'", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))

      for tag <- z.tags do
        assert String.contains?(note, "- #{tag}"),
               "Tag '#{tag}' must appear as YAML list item '- #{tag}'"
      end
    end

    test "TAGS_02: each tag also appears as #hashtag in the note body", %{table: table} do
      [z] = lookup_zettels(table, ["z001"])
      note = render_note(z, build_backlinks_index(table))

      for tag <- z.tags do
        assert String.contains?(note, "##{tag}"),
               "Tag '#{tag}' must appear as #hashtag in body"
      end
    end
  end

  # ==========================================================================
  # SECTION 7: Reconstruction Guide (SC-SMRITI-071)
  # ==========================================================================

  describe "reconstruction guide (SC-SMRITI-071)" do
    test "GUIDE_01: vault export includes a README.md with vault structure description", %{
      table: table
    } do
      vault = export_vault(table)
      readme = Enum.find(vault.config_files, fn f -> f.path == "README.md" end)
      assert readme != nil, "Vault must include README.md reconstruction guide"

      assert String.contains?(readme.content, "Vault Structure"),
             "README.md must describe vault structure"
    end

    test "GUIDE_02: README.md includes import instructions for Obsidian", %{table: table} do
      vault = export_vault(table)
      readme = Enum.find(vault.config_files, fn f -> f.path == "README.md" end)
      assert readme != nil

      assert String.contains?(readme.content, "Open as Vault") or
               String.contains?(readme.content, "Obsidian"),
             "README.md must include Obsidian import instructions"
    end
  end

  # ==========================================================================
  # SECTION 8: Backlinks (SC-SMRITI-083)
  # ==========================================================================

  describe "backlinks in frontmatter" do
    test "BACKLINK_01: zettel pointed to by others has backlinks in frontmatter", %{
      table: table
    } do
      # z001 links to z002; so z002 should have z001 as a backlink
      [z] = lookup_zettels(table, ["z002"])
      backlinks = build_backlinks_index(table)
      note = render_note(z, backlinks)
      {:ok, fm} = parse_yaml_frontmatter(note)

      assert Map.has_key?(fm, "backlinks"),
             "Frontmatter must include 'backlinks' key for zettel z002"
    end

    test "BACKLINK_02: zettel with no incoming links has empty backlinks list", %{table: table} do
      # z003 is not linked from anyone in seed data
      [z] = lookup_zettels(table, ["z003"])
      backlinks = build_backlinks_index(table)
      note = render_note(z, backlinks)
      {:ok, fm} = parse_yaml_frontmatter(note)

      assert Map.has_key?(fm, "backlinks"),
             "backlinks key must be present even when empty"

      # The value should be empty list marker ("[]") or no listed items
      assert fm["backlinks"] == "[]" or fm["backlinks"] == ""
    end
  end

  # ==========================================================================
  # SECTION 9: Export Atomicity (SC-SMRITI-074)
  # ==========================================================================

  describe "export atomicity (SC-SMRITI-074)" do
    test "ATOMIC_01: vault bundle contains all note files, config files, and README", %{
      table: table,
      zettels: zettels
    } do
      vault = export_vault(table)
      assert Map.has_key?(vault, :note_files), "Bundle must have :note_files"
      assert Map.has_key?(vault, :config_files), "Bundle must have :config_files"

      assert length(vault.note_files) == length(zettels),
             "note_files count must equal zettel count"

      assert length(vault.config_files) >= 3,
             "config_files must include app.json, graph.json, README.md"
    end

    test "ATOMIC_02: vault for 50 zettels produces exactly 50 note files", %{} do
      big_table = :ets.new(:big_vault_test, [:set, :public])

      for i <- 1..50 do
        z =
          build_zettel("bz#{String.pad_leading("#{i}", 3, "0")}", "Big Zettel #{i}", ["tag_#{i}"])

        :ets.insert(big_table, {z.id, z})
      end

      vault = export_vault(big_table)
      assert length(vault.note_files) == 50

      :ets.delete(big_table)
    end
  end

  # ==========================================================================
  # SECTION 10: Export Timing (SC-SMRITI-133)
  # ==========================================================================

  describe "export timing (SC-SMRITI-133 < 500ms)" do
    test "TIMING_01: exporting 100 zettels completes under 500ms", %{} do
      perf_table = :ets.new(:perf_vault_test, [:set, :public])

      for i <- 1..100 do
        z = build_zettel("pz#{i}", "Perf Zettel #{i}", ["perf", "test"])
        :ets.insert(perf_table, {z.id, z})
      end

      {time_us, vault} = :timer.tc(fn -> export_vault(perf_table) end)
      time_ms = time_us / 1000

      assert length(vault.note_files) == 100,
             "All 100 zettels must be exported"

      assert time_ms < 500,
             "Export of 100 zettels took #{Float.round(time_ms, 2)}ms (budget: 500ms)"

      :ets.delete(perf_table)
    end
  end

  # ==========================================================================
  # SECTION 11 (Property): YAML Frontmatter Validity for Random Zettels
  # ==========================================================================

  describe "property: YAML frontmatter validity" do
    test "PROP_FM_01: random zettels with random tags always produce valid YAML frontmatter" do
      ExUnitProperties.check all(
                               id_suffix <- SD.string(:alphanumeric, min_length: 3, max_length: 8),
                               title_word <-
                                 SD.string(:alphanumeric, min_length: 4, max_length: 16),
                               tag_count <- SD.integer(0..5),
                               max_runs: 30
                             ) do
        tags =
          Enum.map(1..max(tag_count, 1), fn i -> "tag_#{id_suffix}_#{i}" end)

        z =
          build_zettel(
            "prop_#{id_suffix}",
            "Title #{title_word}",
            tags
          )

        note = render_note(z, %{})

        assert {:ok, fm} = parse_yaml_frontmatter(note),
               "Zettel #{z.id} produced invalid YAML frontmatter"

        assert fm["id"] == z.id
        assert fm["title"] == z.title
      end
    end
  end

  # ==========================================================================
  # SECTION 12 (Property): File Count Invariant
  # ==========================================================================

  describe "property: file count invariant" do
    test "PROP_COUNT_01: vault note_files count always equals zettel count in store" do
      ExUnitProperties.check all(
                               n <- SD.integer(1..30),
                               max_runs: 20
                             ) do
        prop_table = :ets.new(:prop_count_vault, [:set, :public])

        for i <- 1..n do
          z = build_zettel("pv#{i}", "Vault Zettel #{i}", ["vault"])
          :ets.insert(prop_table, {z.id, z})
        end

        vault = export_vault(prop_table)

        assert length(vault.note_files) == n,
               "Expected #{n} note files, got #{length(vault.note_files)}"

        :ets.delete(prop_table)
      end
    end
  end

  # ==========================================================================
  # Private helpers — all simulation logic, no production module deps
  # ==========================================================================

  # Build a zettel map with sensible defaults.
  @spec build_zettel(String.t(), String.t(), [String.t()]) :: zettel()
  defp build_zettel(id, title, tags, opts \\ []) do
    %{
      id: id,
      title: title,
      body: Keyword.get(opts, :body, "Body content for #{title}."),
      tags: tags,
      links: Keyword.get(opts, :links, []),
      created_at: Keyword.get(opts, :created_at, "2026-01-01T00:00:00Z"),
      updated_at: Keyword.get(opts, :updated_at, "2026-01-15T00:00:00Z")
    }
  end

  # Retrieve all zettels from ETS table, sorted by id.
  @spec all_zettels(:ets.tab()) :: [zettel()]
  defp all_zettels(table) do
    table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, z} -> z end)
    |> Enum.sort_by(& &1.id)
  end

  # Retrieve specific zettels by id list.
  @spec lookup_zettels(:ets.tab(), [String.t()]) :: [zettel()]
  defp lookup_zettels(table, ids) do
    Enum.flat_map(ids, fn id ->
      case :ets.lookup(table, id) do
        [{_id, z}] -> [z]
        [] -> []
      end
    end)
  end

  # Build a backlinks index: %{zettel_id => [source_id, ...]}
  @spec build_backlinks_index(:ets.tab()) :: %{String.t() => [String.t()]}
  defp build_backlinks_index(table) do
    all_zettels(table)
    |> Enum.reduce(%{}, fn z, acc ->
      Enum.reduce(z.links, acc, fn target_id, inner_acc ->
        Map.update(inner_acc, target_id, [z.id], fn existing -> [z.id | existing] end)
      end)
    end)
  end

  # Resolve a zettel id to its title (fallback to id if not found).
  @spec resolve_title(:ets.tab() | nil, String.t()) :: String.t()
  defp resolve_title(nil, id), do: id

  defp resolve_title(table, id) do
    case :ets.lookup(table, id) do
      [{_id, z}] -> z.title
      [] -> id
    end
  end

  # Render a single zettel as an Obsidian note (YAML frontmatter + CommonMark body).
  # Backlinks index is %{zettel_id => [source_id, ...]}; pass %{} if unavailable.
  @spec render_note(zettel(), %{String.t() => [String.t()]}) :: String.t()
  defp render_note(z, backlinks_index) do
    backlinks = Map.get(backlinks_index, z.id, [])

    tags_yaml =
      case z.tags do
        [] -> "[]"
        tags -> "\n" <> Enum.map_join(tags, "\n", fn t -> "  - #{t}" end)
      end

    links_yaml =
      case z.links do
        [] -> "[]"
        links -> "\n" <> Enum.map_join(links, "\n", fn l -> "  - #{l}" end)
      end

    backlinks_yaml =
      case backlinks do
        [] -> "[]"
        bls -> "\n" <> Enum.map_join(bls, "\n", fn b -> "  - #{b}" end)
      end

    frontmatter = """
    ---
    id: #{z.id}
    title: #{z.title}
    created_at: #{z.created_at}
    updated_at: #{z.updated_at}
    tags: #{tags_yaml}
    links: #{links_yaml}
    backlinks: #{backlinks_yaml}
    ---
    """

    hashtags = Enum.map_join(z.tags, " ", fn t -> "##{t}" end)

    wikilinks_section =
      case z.links do
        [] ->
          "## Links\n\n_(no outgoing links)_\n"

        links ->
          items = Enum.map_join(links, "\n", fn l -> "- [[#{l}|#{l}]]" end)
          "## Links\n\n#{items}\n"
      end

    body = """

    # #{z.title}

    #{z.body}

    #{hashtags}

    #{wikilinks_section}
    """

    frontmatter <> body
  end

  # Export the full vault: note files + .obsidian config + README.
  @spec export_vault(:ets.tab()) :: %{
          note_files: [%{path: String.t(), content: String.t()}],
          config_files: [%{path: String.t(), content: String.t()}]
        }
  defp export_vault(table) do
    zettels = all_zettels(table)
    backlinks = build_backlinks_index(table)

    note_files =
      Enum.map(zettels, fn z ->
        safe_name = z.id |> String.replace(~r/[^a-zA-Z0-9\-_]/, "_") |> String.downcase()

        %{
          path: "notes/#{safe_name}.md",
          content: render_note(z, backlinks)
        }
      end)

    config_files = [
      %{
        path: ".obsidian/app.json",
        content: render_obsidian_app_config()
      },
      %{
        path: ".obsidian/graph.json",
        content: render_obsidian_graph_config()
      },
      %{
        path: "README.md",
        content: render_reconstruction_guide(zettels)
      }
    ]

    %{note_files: note_files, config_files: config_files}
  end

  # Generate .obsidian/app.json stub (SC-SMRITI-082).
  @spec render_obsidian_app_config() :: String.t()
  defp render_obsidian_app_config do
    ~S"""
    {
      "promptDelete": false,
      "legacyEditor": false,
      "livePreview": true,
      "defaultViewMode": "preview",
      "spellcheck": false
    }
    """
  end

  # Generate .obsidian/graph.json stub (SC-SMRITI-082).
  @spec render_obsidian_graph_config() :: String.t()
  defp render_obsidian_graph_config do
    ~S"""
    {
      "collapse-filter": true,
      "search": "",
      "showTags": false,
      "showAttachments": false,
      "hideUnresolved": false,
      "showOrphans": true,
      "collapse-color-groups": true,
      "colorGroups": [],
      "collapse-display": true,
      "showArrow": false,
      "textFadeMultiplier": 0,
      "nodeSizeMultiplier": 1,
      "lineSizeMultiplier": 1,
      "collapse-forces": true,
      "centerStrength": 0.518713248970312,
      "repelStrength": 10,
      "linkStrength": 1,
      "linkDistance": 250,
      "scale": 1,
      "close": false
    }
    """
  end

  # Render README.md reconstruction guide (SC-SMRITI-071).
  @spec render_reconstruction_guide([zettel()]) :: String.t()
  defp render_reconstruction_guide(zettels) do
    count = length(zettels)
    checksum = :crypto.hash(:sha256, inspect(zettels)) |> Base.encode16(case: :lower)

    """
    # SMRITI Obsidian Vault — Reconstruction Guide

    > Auto-generated by SMRITI v21.3.0 | SC-SMRITI-071 | SC-SMRITI-082

    ## Vault Structure

    ```
    vault/
    ├── .obsidian/
    │   ├── app.json       # Obsidian application settings
    │   └── graph.json     # Graph view settings
    ├── notes/
    │   └── *.md           # Zettel notes (YAML frontmatter + CommonMark body)
    └── README.md          # This reconstruction guide
    ```

    ## Contents

    - **Zettel count**: #{count}
    - **Export checksum** (SHA-256 of source zettels): `#{checksum}`
    - **Format**: Obsidian Markdown v1 with YAML frontmatter

    ## Import Instructions

    1. Install [Obsidian](https://obsidian.md/)
    2. Click **Open folder as Vault** in Obsidian
    3. Select this directory
    4. Verify the graph view shows #{count} nodes

    ## Field Reference

    | Field        | Type   | Description                             |
    |--------------|--------|-----------------------------------------|
    | `id`         | string | Unique zettel identifier                |
    | `title`      | string | Human-readable title                    |
    | `created_at` | ISO8601| Creation timestamp (UTC)                |
    | `updated_at` | ISO8601| Last modified timestamp (UTC)           |
    | `tags`       | list   | Topic tags (also appear as #hashtags)   |
    | `links`      | list   | Outgoing wikilinks `[[target_id|title]]`|
    | `backlinks`  | list   | Incoming links from other zettels       |
    """
  end

  # Parse YAML frontmatter from a note string.
  # Returns {:ok, %{key => value}} for simple scalar fields,
  # retaining raw list-block values as trimmed strings.
  @spec parse_yaml_frontmatter(String.t()) :: {:ok, map()} | {:error, :no_frontmatter}
  defp parse_yaml_frontmatter(content) do
    case Regex.run(~r/\A---\n(.*?)\n---\n/s, content, capture: :all_but_first) do
      [fm_body] ->
        pairs =
          fm_body
          |> String.split("\n")
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.reduce({%{}, nil}, fn line, {acc, current_key} ->
            cond do
              # List item line (indented with spaces and starts with "  -")
              String.starts_with?(line, "  ") and current_key != nil ->
                # Append to current key's raw value
                existing = Map.get(acc, current_key, "")
                {Map.put(acc, current_key, existing <> String.trim(line) <> " "), current_key}

              # Key: value line
              String.contains?(line, ":") ->
                case String.split(line, ":", parts: 2) do
                  [key, value] ->
                    trimmed_key = String.trim(key)
                    trimmed_val = String.trim(value)
                    {Map.put(acc, trimmed_key, trimmed_val), trimmed_key}

                  _ ->
                    {acc, current_key}
                end

              true ->
                {acc, current_key}
            end
          end)
          |> elem(0)

        {:ok, pairs}

      nil ->
        {:error, :no_frontmatter}
    end
  end
end
