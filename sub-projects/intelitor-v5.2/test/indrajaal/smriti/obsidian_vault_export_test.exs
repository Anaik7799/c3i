defmodule Indrajaal.SMRITI.ObsidianVaultExportTest do
  @moduledoc """
  Self-contained tests for SMRITI Obsidian vault export with YAML frontmatter.

  WHAT: Validates Obsidian vault creation, per-note YAML frontmatter generation,
        wikilink [[]] rendering, tag taxonomy, backlink computation, graph
        metadata construction, and .obsidian config generation.
        All logic is implemented as `defp` helpers — no production module
        dependencies are required.

  WHY:  SC-SMRITI-082 mandates Obsidian vault includes .obsidian config.
        SC-SMRITI-083 mandates notes use YAML frontmatter.
        SC-SMRITI-078 mandates valid CommonMark markdown output.
        The Obsidian vault is the canonical human-readable view of the
        SMRITI knowledge graph and MUST be regenerable from raw entries alone.

  CONSTRAINTS: SC-SMRITI-082, SC-SMRITI-083, SC-SMRITI-078, SC-SMRITI-072,
               SC-SMRITI-140, SC-SMRITI-141, EP-GEN-014

  ## Coverage Matrix
  | Describe block                          | Unit | Property | Total |
  |-----------------------------------------|------|----------|-------|
  | vault creation                          | 4    | 1        | 5     |
  | note export with YAML frontmatter       | 5    | 2        | 7     |
  | wikilink [[]] generation                | 4    | 2        | 6     |
  | tag taxonomy                            | 4    | 1        | 5     |
  | backlink computation                    | 4    | 1        | 5     |
  | graph metadata                          | 4    | 1        | 5     |
  | .obsidian config generation             | 4    | 1        | 5     |
  | property: all notes valid frontmatter   | 0    | 3        | 3     |
  | property: links resolve to notes        | 0    | 2        | 2     |
  | property: tag hierarchy consistent      | 0    | 2        | 2     |
  | TOTAL                                   | 29   | 16       | 45    |

  ## EP-GEN-014 compliance
  - SD. prefix used exclusively for StreamData generators
  - `ExUnitProperties.check all(...)` always inside plain `test` blocks
  - No PropCheck imported (SD-only test file)
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :obsidian
  @moduletag :export

  # ============================================================================
  # Domain types
  # ============================================================================

  @type note_id :: String.t()
  @type tag :: String.t()

  @type smriti_entry :: %{
          id: note_id(),
          title: String.t(),
          content: String.t(),
          tags: [tag()],
          links_to: [note_id()],
          created_at: String.t(),
          updated_at: String.t(),
          version: pos_integer(),
          domain: String.t()
        }

  @type vault_note :: %{
          path: String.t(),
          content: String.t(),
          frontmatter: map()
        }

  @type vault :: %{
          notes: [vault_note()],
          config: map(),
          tag_index: map(),
          backlinks: map(),
          graph_metadata: map()
        }

  # ============================================================================
  # Entry factory
  # ============================================================================

  defp build_entry(opts \\ []) do
    id = Keyword.get(opts, :id, "note-#{:erlang.unique_integer([:positive])}")

    %{
      id: id,
      title: Keyword.get(opts, :title, "Note #{id}"),
      content: Keyword.get(opts, :content, "Body of #{id}. References Zenoh, SQLite, holons."),
      tags: Keyword.get(opts, :tags, ["smriti", "knowledge"]),
      links_to: Keyword.get(opts, :links_to, []),
      created_at: Keyword.get(opts, :created_at, "2026-01-01T00:00:00Z"),
      updated_at: Keyword.get(opts, :updated_at, "2026-01-02T00:00:00Z"),
      version: Keyword.get(opts, :version, 1),
      domain: Keyword.get(opts, :domain, "core")
    }
  end

  defp corpus(count) do
    ids = Enum.map(1..count, &"note-#{&1}")

    Enum.map(Enum.with_index(ids, 1), fn {id, idx} ->
      # Each note links to the next note (circular excluded for last)
      links =
        if idx < count do
          ["note-#{idx + 1}"]
        else
          []
        end

      build_entry(
        id: id,
        title: "Knowledge Note #{idx}",
        content: "This is note #{idx}. It connects ideas about holon state and Zenoh.",
        tags: ["smriti", "note#{idx}", if(rem(idx, 2) == 0, do: "even", else: "odd")],
        links_to: links,
        version: idx,
        domain: if(rem(idx, 3) == 0, do: "federation", else: "core")
      )
    end)
  end

  # ============================================================================
  # Helper: YAML frontmatter generator
  # ============================================================================

  defp generate_frontmatter(entry) do
    tags_yaml =
      entry.tags
      |> Enum.map(&"  - #{&1}")
      |> Enum.join("\n")

    links_yaml =
      entry.links_to
      |> Enum.map(&"  - \"[[#{&1}]]\"")
      |> Enum.join("\n")

    links_block =
      if entry.links_to == [] do
        "links: []"
      else
        "links:\n#{links_yaml}"
      end

    raw = """
    ---
    id: #{entry.id}
    title: "#{entry.title}"
    domain: #{entry.domain}
    version: #{entry.version}
    created: #{entry.created_at}
    modified: #{entry.updated_at}
    tags:
    #{tags_yaml}
    #{links_block}
    ---
    """

    {raw, parse_frontmatter_pairs(raw)}
  end

  defp parse_frontmatter_pairs(content) do
    case Regex.run(~r/\A---\n(.*?)\n---/s, content, capture: :all_but_first) do
      [body] ->
        body
        |> String.split("\n")
        |> Enum.reject(&(String.trim(&1) == ""))
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, ":", parts: 2) do
            [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
            _ -> acc
          end
        end)

      nil ->
        %{}
    end
  end

  # ============================================================================
  # Helper: wikilink renderer
  # ============================================================================

  defp render_wikilinks(ids) when is_list(ids) do
    Enum.map(ids, fn id -> "[[#{id}]]" end)
  end

  defp render_tag_wikilinks(tags) when is_list(tags) do
    Enum.map(tags, fn tag -> "[[tags/#{tag}]]" end)
  end

  # ============================================================================
  # Helper: note renderer (YAML frontmatter + CommonMark body)
  # ============================================================================

  defp render_note(entry) do
    {frontmatter_block, fm_pairs} = generate_frontmatter(entry)
    tag_links = render_tag_wikilinks(entry.tags) |> Enum.join(" ")
    ref_links = render_wikilinks(entry.links_to) |> Enum.join(" ")

    refs_section =
      if entry.links_to == [] do
        "_No outgoing links._"
      else
        ref_links
      end

    content = """
    #{frontmatter_block}
    # #{entry.title}

    #{entry.content}

    ## Tags

    #{tag_links}

    ## References

    #{refs_section}

    ## Metadata

    | Field     | Value            |
    |-----------|------------------|
    | Domain    | #{entry.domain}  |
    | Version   | #{entry.version} |
    | Created   | #{entry.created_at} |
    | Modified  | #{entry.updated_at} |
    """

    safe_path =
      entry.title
      |> String.replace(~r/[^a-zA-Z0-9\s\-_]/, "")
      |> String.replace(" ", "_")
      |> String.downcase()

    %{
      path: "notes/#{safe_path}.md",
      content: content,
      frontmatter: fm_pairs
    }
  end

  # ============================================================================
  # Helper: tag taxonomy builder
  # ============================================================================

  defp build_tag_index(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      Enum.reduce(entry.tags, acc, fn tag, inner ->
        existing = Map.get(inner, tag, [])
        Map.put(inner, tag, [entry.id | existing])
      end)
    end)
  end

  defp build_tag_hierarchy(entries) do
    all_tags = entries |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

    grouped =
      Enum.group_by(all_tags, fn tag ->
        cond do
          String.starts_with?(tag, "note") -> "note_tags"
          tag in ["even", "odd"] -> "parity_tags"
          true -> "system_tags"
        end
      end)

    %{
      all_tags: all_tags,
      total: length(all_tags),
      groups: grouped
    }
  end

  # ============================================================================
  # Helper: backlink computation
  # ============================================================================

  defp compute_backlinks(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      Enum.reduce(entry.links_to, acc, fn target_id, inner ->
        existing = Map.get(inner, target_id, [])
        Map.put(inner, target_id, [entry.id | existing])
      end)
    end)
  end

  # ============================================================================
  # Helper: graph metadata
  # ============================================================================

  defp build_graph_metadata(entries) do
    backlinks = compute_backlinks(entries)
    tag_index = build_tag_index(entries)

    nodes =
      Enum.map(entries, fn e ->
        %{
          id: e.id,
          label: e.title,
          domain: e.domain,
          out_degree: length(e.links_to),
          in_degree: length(Map.get(backlinks, e.id, [])),
          tag_count: length(e.tags)
        }
      end)

    edges =
      Enum.flat_map(entries, fn e ->
        Enum.map(e.links_to, fn target -> %{source: e.id, target: target} end)
      end)

    %{
      node_count: length(nodes),
      edge_count: length(edges),
      tag_count: map_size(tag_index),
      nodes: nodes,
      edges: edges,
      schema_version: "1.0.0"
    }
  end

  # ============================================================================
  # Helper: .obsidian config generator (SC-SMRITI-082)
  # ============================================================================

  defp generate_obsidian_config(entries) do
    tag_hierarchy = build_tag_hierarchy(entries)

    app_config = %{
      "legacyEditor" => false,
      "defaultViewMode" => "source",
      "alwaysUpdateLinks" => true,
      "newLinkFormat" => "relative",
      "useMarkdownLinks" => false,
      "theme" => "obsidian",
      "cssTheme" => "Minimal",
      "baseFontSize" => 14,
      "enabledPlugins" => ["backlink", "tag-pane", "graph", "search"]
    }

    graph_config = %{
      "collapse-filter" => false,
      "search" => "",
      "showTags" => true,
      "showAttachments" => false,
      "hideUnresolved" => false,
      "showOrphans" => true,
      "collapse-color-groups" => false,
      "colorGroups" => [],
      "collapse-display" => false,
      "textFadeMultiplier" => 0,
      "nodeSizeMultiplier" => 1,
      "lineSizeMultiplier" => 1,
      "collapse-forces" => false,
      "centerStrength" => 0.518713248970312,
      "repelStrength" => 10,
      "linkStrength" => 1,
      "linkDistance" => 250,
      "scale" => 1,
      "close" => false
    }

    workspace_config = %{
      "main" => %{
        "id" => "main",
        "type" => "split",
        "children" => [],
        "direction" => "vertical"
      }
    }

    %{
      "app.json" => Jason.encode!(app_config, pretty: true),
      "graph.json" => Jason.encode!(graph_config, pretty: true),
      "workspace.json" => Jason.encode!(workspace_config, pretty: true),
      "community-plugins.json" => "[]",
      "core-plugins.json" => Jason.encode!(["backlink", "tag-pane", "graph"], pretty: true),
      "tag-pane-info" => %{tags: tag_hierarchy.all_tags, total: tag_hierarchy.total}
    }
  end

  # ============================================================================
  # Helper: full vault assembler
  # ============================================================================

  defp build_vault(entries) when is_list(entries) do
    notes = Enum.map(entries, &render_note/1)
    tag_index = build_tag_index(entries)
    backlinks = compute_backlinks(entries)
    graph_metadata = build_graph_metadata(entries)
    config = generate_obsidian_config(entries)

    %{
      notes: notes,
      config: config,
      tag_index: tag_index,
      backlinks: backlinks,
      graph_metadata: graph_metadata
    }
  end

  defp has_yaml_frontmatter?(content) do
    Regex.match?(~r/\A---\n.*?\n---/s, content)
  end

  defp extract_wikilinks(content) do
    Regex.scan(~r/\[\[([^\]]+)\]\]/, content, capture: :all_but_first)
    |> List.flatten()
  end

  # ============================================================================
  # SECTION 1 — Vault creation
  # ============================================================================

  describe "vault creation" do
    test "VAULT_01: build_vault/1 returns a map with required keys for empty list" do
      vault = build_vault([])
      assert Map.has_key?(vault, :notes)
      assert Map.has_key?(vault, :config)
      assert Map.has_key?(vault, :tag_index)
      assert Map.has_key?(vault, :backlinks)
      assert Map.has_key?(vault, :graph_metadata)
    end

    test "VAULT_02: note count equals entry count" do
      entries = corpus(8)
      vault = build_vault(entries)
      assert length(vault.notes) == 8
    end

    test "VAULT_03: all note paths are unique within the vault" do
      entries = corpus(10)
      vault = build_vault(entries)
      paths = Enum.map(vault.notes, & &1.path)
      assert length(paths) == length(Enum.uniq(paths))
    end

    test "VAULT_04: all note paths are under the notes/ directory" do
      entries = corpus(5)
      vault = build_vault(entries)

      for note <- vault.notes do
        assert String.starts_with?(note.path, "notes/"),
               "Path #{note.path} must start with notes/"

        assert String.ends_with?(note.path, ".md"),
               "Path #{note.path} must end with .md"
      end
    end

    test "VAULT_PROP_01: vault note count always equals entry count" do
      ExUnitProperties.check all(
                               count <- SD.integer(0..20),
                               max_runs: 20
                             ) do
        entries = if count == 0, do: [], else: corpus(count)
        vault = build_vault(entries)
        assert length(vault.notes) == count
      end
    end
  end

  # ============================================================================
  # SECTION 2 — Note export with YAML frontmatter (SC-SMRITI-083)
  # ============================================================================

  describe "note export with YAML frontmatter (SC-SMRITI-083)" do
    test "FM_01: each rendered note content starts with YAML frontmatter block" do
      entries = corpus(4)
      vault = build_vault(entries)

      for note <- vault.notes do
        assert has_yaml_frontmatter?(note.content),
               "Note #{note.path} missing YAML frontmatter"
      end
    end

    test "FM_02: frontmatter block begins and ends with triple-dash delimiters" do
      entry = build_entry(id: "fm-test")
      note = render_note(entry)
      lines = String.split(note.content, "\n")
      [first | rest] = lines
      assert first == "---"
      close_idx = Enum.find_index(rest, &(&1 == "---"))
      assert close_idx != nil, "No closing --- found in frontmatter"
    end

    test "FM_03: frontmatter contains id, title, domain, version, created, modified fields" do
      entry = build_entry(id: "fm-fields", title: "Field Test", version: 7, domain: "federation")
      note = render_note(entry)

      for field <- ~w[id title domain version created modified] do
        assert String.contains?(note.content, "#{field}:"),
               "Frontmatter missing field: #{field}"
      end
    end

    test "FM_04: frontmatter id value matches original entry id" do
      entry = build_entry(id: "unique-note-42")
      note = render_note(entry)
      assert note.frontmatter["id"] == "unique-note-42"
    end

    test "FM_05: frontmatter version matches entry version" do
      entry = build_entry(id: "v-test", version: 99)
      note = render_note(entry)
      assert note.frontmatter["version"] == "99"
    end

    test "FM_PROP_01: all notes in any vault have valid YAML frontmatter" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..15),
                               max_runs: 20
                             ) do
        entries = corpus(count)
        vault = build_vault(entries)

        for note <- vault.notes do
          assert has_yaml_frontmatter?(note.content),
                 "Note #{note.path} failed frontmatter check"
        end
      end
    end

    test "FM_PROP_02: frontmatter id always matches the source entry id" do
      ExUnitProperties.check all(
                               suffix <- SD.string(:alphanumeric, min_length: 3, max_length: 10),
                               max_runs: 20
                             ) do
        entry = build_entry(id: "note-#{suffix}")
        note = render_note(entry)
        assert note.frontmatter["id"] == "note-#{suffix}"
      end
    end
  end

  # ============================================================================
  # SECTION 3 — Wikilink [[]] generation
  # ============================================================================

  describe "wikilink [[]] generation" do
    test "WIKI_01: render_wikilinks/1 wraps each id in [[]] brackets" do
      links = render_wikilinks(["note-1", "note-2"])
      assert links == ["[[note-1]]", "[[note-2]]"]
    end

    test "WIKI_02: render_tag_wikilinks/1 produces tags/ prefixed wikilinks" do
      links = render_tag_wikilinks(["smriti", "core"])
      assert links == ["[[tags/smriti]]", "[[tags/core]]"]
    end

    test "WIKI_03: note body contains wikilink for every tag" do
      entry = build_entry(id: "wl-tags", tags: ["alpha", "beta", "gamma"])
      note = render_note(entry)

      for tag <- entry.tags do
        assert String.contains?(note.content, "[[tags/#{tag}]]"),
               "Missing tag wikilink [[tags/#{tag}]]"
      end
    end

    test "WIKI_04: note body contains wikilink for each outgoing link" do
      entry = build_entry(id: "wl-refs", links_to: ["note-10", "note-20"])
      note = render_note(entry)

      for target <- entry.links_to do
        assert String.contains?(note.content, "[[#{target}]]"),
               "Missing reference wikilink [[#{target}]]"
      end
    end

    test "WIKI_PROP_01: wikilinks in content are extractable via regex" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..8),
                               max_runs: 15
                             ) do
        tags = Enum.map(1..count, &"tag#{&1}")
        entry = build_entry(id: "wl-prop", tags: tags)
        note = render_note(entry)
        found = extract_wikilinks(note.content)

        for tag <- tags do
          assert "tags/#{tag}" in found,
                 "Tag wikilink tags/#{tag} not found in extracted links"
        end
      end
    end

    test "WIKI_PROP_02: empty links_to produces no reference wikilinks in References section" do
      ExUnitProperties.check all(
                               i <- SD.integer(1..20),
                               max_runs: 15
                             ) do
        entry = build_entry(id: "wl-empty-#{i}", links_to: [])
        note = render_note(entry)

        assert String.contains?(note.content, "_No outgoing links._"),
               "Expected no-outgoing-links placeholder"
      end
    end
  end

  # ============================================================================
  # SECTION 4 — Tag taxonomy
  # ============================================================================

  describe "tag taxonomy" do
    test "TAG_01: build_tag_index/1 returns a map keyed by tag name" do
      entries = corpus(6)
      index = build_tag_index(entries)
      assert is_map(index)
      assert Map.has_key?(index, "smriti")
    end

    test "TAG_02: each tag maps to the list of entry ids that carry it" do
      e1 = build_entry(id: "e1", tags: ["alpha", "shared"])
      e2 = build_entry(id: "e2", tags: ["beta", "shared"])
      index = build_tag_index([e1, e2])
      assert "e1" in index["alpha"]
      assert "e2" in index["beta"]
      assert "e1" in index["shared"]
      assert "e2" in index["shared"]
    end

    test "TAG_03: build_tag_hierarchy/1 returns all_tags, total, and groups" do
      entries = corpus(6)
      hierarchy = build_tag_hierarchy(entries)
      assert Map.has_key?(hierarchy, :all_tags)
      assert Map.has_key?(hierarchy, :total)
      assert Map.has_key?(hierarchy, :groups)
      assert hierarchy.total == length(hierarchy.all_tags)
    end

    test "TAG_04: tag_index in vault maps all unique tags across entries" do
      entries = corpus(5)
      all_tags = entries |> Enum.flat_map(& &1.tags) |> Enum.uniq()
      vault = build_vault(entries)

      for tag <- all_tags do
        assert Map.has_key?(vault.tag_index, tag), "Tag #{tag} missing from vault tag_index"
      end
    end

    test "TAG_PROP_01: tag_index entry count is non-negative for any input" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..15),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        index = build_tag_index(entries)
        assert map_size(index) >= 0
        assert Enum.all?(Map.values(index), &is_list/1)
      end
    end
  end

  # ============================================================================
  # SECTION 5 — Backlink computation
  # ============================================================================

  describe "backlink computation" do
    test "BL_01: compute_backlinks/1 returns empty map for entries with no links" do
      entries = [
        build_entry(id: "bl-a", links_to: []),
        build_entry(id: "bl-b", links_to: [])
      ]

      assert compute_backlinks(entries) == %{}
    end

    test "BL_02: a linked-to entry appears as backlink target" do
      e1 = build_entry(id: "src", links_to: ["tgt"])
      e2 = build_entry(id: "tgt", links_to: [])
      backlinks = compute_backlinks([e1, e2])
      assert Map.has_key?(backlinks, "tgt")
      assert "src" in backlinks["tgt"]
    end

    test "BL_03: multiple sources linking to same target all appear in backlinks" do
      src1 = build_entry(id: "s1", links_to: ["hub"])
      src2 = build_entry(id: "s2", links_to: ["hub"])
      src3 = build_entry(id: "s3", links_to: ["hub"])
      hub = build_entry(id: "hub", links_to: [])
      backlinks = compute_backlinks([src1, src2, src3, hub])
      assert length(backlinks["hub"]) == 3
    end

    test "BL_04: vault backlinks key contains computed backlink map" do
      entries = corpus(5)
      vault = build_vault(entries)
      # corpus produces chain: note-1 -> note-2 -> ... -> note-4 -> (no link)
      # so note-2 has backlink from note-1
      assert Map.has_key?(vault.backlinks, "note-2")
      assert "note-1" in vault.backlinks["note-2"]
    end

    test "BL_PROP_01: backlink map values are always non-empty lists" do
      ExUnitProperties.check all(
                               count <- SD.integer(2..12),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        backlinks = compute_backlinks(entries)

        for {_target, sources} <- backlinks do
          assert is_list(sources)
          assert sources != [], "Backlink entry must have at least one source"
        end
      end
    end
  end

  # ============================================================================
  # SECTION 6 — Graph metadata
  # ============================================================================

  describe "graph metadata" do
    test "GRAPH_01: build_graph_metadata/1 returns node_count, edge_count, tag_count" do
      entries = corpus(5)
      meta = build_graph_metadata(entries)
      assert Map.has_key?(meta, :node_count)
      assert Map.has_key?(meta, :edge_count)
      assert Map.has_key?(meta, :tag_count)
      assert Map.has_key?(meta, :schema_version)
    end

    test "GRAPH_02: node_count equals number of entries" do
      entries = corpus(7)
      meta = build_graph_metadata(entries)
      assert meta.node_count == 7
    end

    test "GRAPH_03: edge_count equals total links_to references across all entries" do
      e1 = build_entry(id: "g1", links_to: ["g2", "g3"])
      e2 = build_entry(id: "g2", links_to: ["g3"])
      e3 = build_entry(id: "g3", links_to: [])
      meta = build_graph_metadata([e1, e2, e3])
      assert meta.edge_count == 3
    end

    test "GRAPH_04: each node carries out_degree and in_degree fields" do
      entries = corpus(5)
      meta = build_graph_metadata(entries)

      for node <- meta.nodes do
        assert Map.has_key?(node, :out_degree)
        assert Map.has_key?(node, :in_degree)
        assert node.out_degree >= 0
        assert node.in_degree >= 0
      end
    end

    test "GRAPH_PROP_01: sum of out_degrees equals edge_count for any corpus" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..12),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        meta = build_graph_metadata(entries)
        total_out = Enum.sum(Enum.map(meta.nodes, & &1.out_degree))
        assert total_out == meta.edge_count
      end
    end
  end

  # ============================================================================
  # SECTION 7 — .obsidian config generation (SC-SMRITI-082)
  # ============================================================================

  describe ".obsidian config generation (SC-SMRITI-082)" do
    test "CONFIG_01: generate_obsidian_config/1 returns a map with app.json key" do
      config = generate_obsidian_config(corpus(3))
      assert Map.has_key?(config, "app.json")
      assert is_binary(config["app.json"])
    end

    test "CONFIG_02: app.json is valid JSON with enabledPlugins field" do
      config = generate_obsidian_config(corpus(3))
      {:ok, app} = Jason.decode(config["app.json"])
      assert Map.has_key?(app, "enabledPlugins")
      assert is_list(app["enabledPlugins"])
    end

    test "CONFIG_03: graph.json is valid JSON with showTags field" do
      config = generate_obsidian_config(corpus(2))
      {:ok, graph} = Jason.decode(config["graph.json"])
      assert Map.has_key?(graph, "showTags")
    end

    test "CONFIG_04: config includes community-plugins.json and core-plugins.json" do
      config = generate_obsidian_config(corpus(3))
      assert Map.has_key?(config, "community-plugins.json")
      assert Map.has_key?(config, "core-plugins.json")
      assert {:ok, _} = Jason.decode(config["community-plugins.json"])
      assert {:ok, _} = Jason.decode(config["core-plugins.json"])
    end

    test "CONFIG_PROP_01: config map always has at least 5 keys for any corpus" do
      ExUnitProperties.check all(
                               count <- SD.integer(0..10),
                               max_runs: 15
                             ) do
        entries = if count == 0, do: [], else: corpus(count)
        config = generate_obsidian_config(entries)
        assert map_size(config) >= 5
      end
    end
  end

  # ============================================================================
  # SECTION 8 — Property: all notes have valid frontmatter
  # ============================================================================

  describe "property: all notes have valid frontmatter" do
    test "ALL_FM_PROP_01: every note in vault has opening --- delimiter" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..12),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        vault = build_vault(entries)

        for note <- vault.notes do
          assert String.starts_with?(note.content, "---\n"),
                 "Note #{note.path} does not start with ---"
        end
      end
    end

    test "ALL_FM_PROP_02: frontmatter map on each vault note is non-empty" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        vault = build_vault(entries)

        for note <- vault.notes do
          assert map_size(note.frontmatter) > 0,
                 "Note #{note.path} has empty frontmatter map"
        end
      end
    end

    test "ALL_FM_PROP_03: version field in frontmatter is always a numeric string" do
      ExUnitProperties.check all(
                               version <- SD.integer(1..999),
                               max_runs: 20
                             ) do
        entry = build_entry(id: "v-prop-#{version}", version: version)
        note = render_note(entry)
        assert note.frontmatter["version"] == Integer.to_string(version)
      end
    end
  end

  # ============================================================================
  # SECTION 9 — Property: links resolve to existing notes
  # ============================================================================

  describe "property: links resolve to existing notes" do
    test "LINK_RESOLVE_PROP_01: all link targets in corpus exist as entry ids" do
      ExUnitProperties.check all(
                               count <- SD.integer(2..15),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        all_ids = MapSet.new(Enum.map(entries, & &1.id))
        all_links = Enum.flat_map(entries, & &1.links_to)

        for link <- all_links do
          assert MapSet.member?(all_ids, link),
                 "Link target #{link} does not exist in corpus"
        end
      end
    end

    test "LINK_RESOLVE_PROP_02: wikilinks extracted from note body match links_to list" do
      ExUnitProperties.check all(
                               count <- SD.integer(0..5),
                               max_runs: 15
                             ) do
        link_ids = Enum.map(1..max(count, 1), &"target-#{&1}")

        entry =
          build_entry(
            id: "src-prop",
            links_to: if(count == 0, do: [], else: link_ids)
          )

        note = render_note(entry)
        found_links = extract_wikilinks(note.content)

        for id <- entry.links_to do
          assert id in found_links,
                 "Expected wikilink #{id} in extracted links"
        end
      end
    end
  end

  # ============================================================================
  # SECTION 10 — Property: tag hierarchy is consistent
  # ============================================================================

  describe "property: tag hierarchy is consistent" do
    test "TAG_HIER_PROP_01: total in hierarchy equals length of all_tags list" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..12),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        hierarchy = build_tag_hierarchy(entries)
        assert hierarchy.total == length(hierarchy.all_tags)
      end
    end

    test "TAG_HIER_PROP_02: all_tags list has no duplicates" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..12),
                               max_runs: 15
                             ) do
        entries = corpus(count)
        hierarchy = build_tag_hierarchy(entries)

        assert hierarchy.all_tags == Enum.uniq(hierarchy.all_tags),
               "all_tags contains duplicates"
      end
    end
  end
end
