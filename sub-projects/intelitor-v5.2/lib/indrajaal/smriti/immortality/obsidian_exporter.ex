defmodule Indrajaal.Smriti.Immortality.ObsidianExporter do
  @moduledoc """
  SMRITI Obsidian Vault Exporter — knowledge graph as linked markdown notes.

  WHAT: Exports SMRITI knowledge entries as an Obsidian-compatible vault with YAML
        frontmatter, wiki-style [[links]], and an .obsidian/ config directory.
  WHY:  SC-SMRITI-082/083 mandate Obsidian vault export for human-readable
        knowledge portability and offline navigation.
  CONSTRAINTS: SC-SMRITI-072, SC-SMRITI-078, SC-SMRITI-082, SC-SMRITI-083

  ## Constitutional Alignment
  - Ψ₁ Regeneration: Full export enables reconstruction from vault alone
  - Ψ₂ History: Evolution timestamps preserved in YAML frontmatter
  - Ψ₅ Truthfulness: Metadata accurately reflects extraction_status

  ## STAMP Compliance
  - SC-SMRITI-072: Multi-format export (Obsidian vault is the Markdown/JSON variant)
  - SC-SMRITI-078: Markdown output MUST be valid CommonMark
  - SC-SMRITI-082: .obsidian/ config directory included in export
  - SC-SMRITI-083: All notes MUST use YAML frontmatter

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-23 | Claude | Initial implementation (Sprint 88) |
  """

  require Logger

  @obsidian_config_dir ".obsidian"
  @attachments_dir "attachments"
  @templates_dir "templates"
  @daily_notes_dir "daily"

  @type export_opts :: %{
          optional(:vault_name) => String.t(),
          optional(:include_tags) => boolean(),
          optional(:include_graph_links) => boolean(),
          optional(:max_entries) => pos_integer()
        }

  @type entry :: %{
          id: String.t(),
          title: String.t(),
          content: String.t(),
          tags: [String.t()],
          created_at: DateTime.t() | String.t(),
          updated_at: DateTime.t() | String.t(),
          source: String.t() | nil,
          links: [String.t()],
          metadata: map()
        }

  @doc """
  Exports all SMRITI entries to an Obsidian-compatible vault at `output_dir`.

  Creates:
  - `{output_dir}/.obsidian/` — Obsidian config (app.json, community-plugins.json,
    graph.json, workspace.json)
  - `{output_dir}/vault-index.md` — Root index note with statistics
  - `{output_dir}/{title}.md` — One note per SMRITI entry with YAML frontmatter
  - `{output_dir}/attachments/` — Reserved for binary attachments
  - `{output_dir}/templates/` — Obsidian note templates
  - `{output_dir}/daily/` — Placeholder for daily notes

  Returns `{:ok, stats}` or `{:error, reason}`.
  """
  @spec export_vault(String.t(), [entry()], export_opts()) :: {:ok, map()} | {:error, term()}
  def export_vault(output_dir, entries, opts \\ %{}) do
    start_time = System.monotonic_time(:millisecond)
    vault_name = Map.get(opts, :vault_name, "SMRITI Knowledge Vault")
    include_links = Map.get(opts, :include_graph_links, true)

    Logger.info("[ObsidianExporter] Exporting #{length(entries)} entries to #{output_dir}")

    with :ok <- ensure_vault_structure(output_dir),
         :ok <- write_obsidian_config(output_dir, vault_name),
         {:ok, written} <- write_entries(output_dir, entries, include_links),
         :ok <- write_vault_index(output_dir, entries, vault_name),
         :ok <- write_templates(output_dir) do
      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      stats = %{
        vault_dir: output_dir,
        vault_name: vault_name,
        entries_written: written,
        total_entries: length(entries),
        duration_ms: elapsed_ms,
        exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      emit_telemetry(:export_complete, stats)
      Logger.info("[ObsidianExporter] Export complete: #{written} notes in #{elapsed_ms}ms")
      {:ok, stats}
    else
      {:error, reason} = err ->
        Logger.error("[ObsidianExporter] Export failed: #{inspect(reason)}")
        emit_telemetry(:export_failed, %{reason: reason})
        err
    end
  end

  @doc """
  Converts a single SMRITI entry into an Obsidian-compatible markdown note with YAML
  frontmatter. Returns the full note content as a string.
  """
  @spec entry_to_note(entry()) :: String.t()
  def entry_to_note(entry) do
    frontmatter = build_frontmatter(entry)
    body = build_note_body(entry)
    frontmatter <> "\n\n" <> body
  end

  @doc """
  Returns the sanitized filename (without extension) for an Obsidian note derived from
  the entry title.
  """
  @spec note_filename(String.t()) :: String.t()
  def note_filename(title) when is_binary(title) do
    title
    |> String.replace(~r/[\/\\:*?"<>|#^[\]{}]/, "-")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 200)
  end

  def note_filename(_), do: "untitled-#{:erlang.unique_integer([:positive])}"

  # ---------------------------------------------------------------------------
  # Private: Vault Structure
  # ---------------------------------------------------------------------------

  @spec ensure_vault_structure(String.t()) :: :ok | {:error, term()}
  defp ensure_vault_structure(output_dir) do
    dirs = [
      output_dir,
      Path.join(output_dir, @obsidian_config_dir),
      Path.join(output_dir, @attachments_dir),
      Path.join(output_dir, @templates_dir),
      Path.join(output_dir, @daily_notes_dir)
    ]

    Enum.reduce_while(dirs, :ok, fn dir, _acc ->
      case File.mkdir_p(dir) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:mkdir_failed, dir, reason}}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: Obsidian Config Files
  # ---------------------------------------------------------------------------

  @spec write_obsidian_config(String.t(), String.t()) :: :ok | {:error, term()}
  defp write_obsidian_config(output_dir, vault_name) do
    config_dir = Path.join(output_dir, @obsidian_config_dir)

    configs = [
      {"app.json", Jason.encode!(obsidian_app_config(), pretty: true)},
      {"community-plugins.json", Jason.encode!([], pretty: true)},
      {"graph.json", Jason.encode!(obsidian_graph_config(), pretty: true)},
      {"workspace.json", Jason.encode!(obsidian_workspace_config(vault_name), pretty: true)},
      {"hotkeys.json", Jason.encode!(%{}, pretty: true)},
      {".smriti-vault-meta.json",
       Jason.encode!(
         %{
           generator: "Indrajaal SMRITI v21.3.0-SIL6",
           vault_name: vault_name,
           format_version: "1.0",
           created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
           constitution: "Ψ₁ Regeneration, Ψ₂ History, Ψ₅ Truthfulness"
         },
         pretty: true
       )}
    ]

    Enum.reduce_while(configs, :ok, fn {filename, content}, _acc ->
      path = Path.join(config_dir, filename)

      case File.write(path, content) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:write_config_failed, filename, reason}}}
      end
    end)
  end

  @spec obsidian_app_config() :: map()
  defp obsidian_app_config do
    %{
      "foldIndent" => false,
      "showUnsupportedFiles" => false,
      "theme" => "obsidian",
      "cssTheme" => "",
      "fontSize" => 16,
      "baseFontSize" => 16,
      "enabledPlugins" => ["graph", "search", "tag-pane", "backlink", "note-composer"],
      "vimMode" => false,
      "alwaysUpdateLinks" => true,
      "newLinkFormat" => "shortest",
      "useMarkdownLinks" => false,
      "attachmentFolderPath" => @attachments_dir,
      "dailyNotesFolder" => @daily_notes_dir,
      "template" => %{"folder" => @templates_dir},
      "userIgnoreFilters" => [".smriti-vault-meta.json"]
    }
  end

  @spec obsidian_graph_config() :: map()
  defp obsidian_graph_config do
    %{
      "collapse-filter" => false,
      "search" => "",
      "showTags" => true,
      "showAttachments" => false,
      "hideUnresolved" => false,
      "showOrphans" => true,
      "collapse-color-groups" => false,
      "colorGroups" => [],
      "collapse-display" => false,
      "showArrow" => true,
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
  end

  @spec obsidian_workspace_config(String.t()) :: map()
  defp obsidian_workspace_config(vault_name) do
    %{
      "main" => %{
        "id" => "smriti-main",
        "type" => "split",
        "children" => [
          %{
            "id" => "smriti-file-explorer",
            "type" => "leaf",
            "state" => %{
              "type" => "file-explorer",
              "state" => %{}
            }
          },
          %{
            "id" => "smriti-editor",
            "type" => "leaf",
            "state" => %{
              "type" => "markdown",
              "state" => %{"file" => "vault-index.md", "mode" => "preview"}
            }
          }
        ]
      },
      "left" => %{
        "id" => "smriti-left",
        "type" => "split",
        "children" => []
      },
      "right" => %{
        "id" => "smriti-right",
        "type" => "split",
        "children" => []
      },
      "active" => "smriti-editor",
      "lastOpenFiles" => ["vault-index.md"],
      "vaultName" => vault_name
    }
  end

  # ---------------------------------------------------------------------------
  # Private: Entry Writing
  # ---------------------------------------------------------------------------

  @spec write_entries(String.t(), [entry()], boolean()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defp write_entries(output_dir, entries, include_links) do
    results =
      Enum.map(entries, fn entry ->
        filename = note_filename(entry.title) <> ".md"
        path = Path.join(output_dir, filename)
        content = build_note_content(entry, include_links)
        File.write(path, content)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, length(entries)}
    else
      {:error, {:partial_write_failure, length(errors), errors}}
    end
  end

  @spec build_note_content(entry(), boolean()) :: String.t()
  defp build_note_content(entry, include_links) do
    frontmatter = build_frontmatter(entry)
    body = build_note_body(entry)

    links_section =
      if include_links and length(entry.links) > 0 do
        link_lines = Enum.map(entry.links, fn link -> "- [[#{link}]]" end)
        "\n\n## Linked Notes\n\n" <> Enum.join(link_lines, "\n")
      else
        ""
      end

    frontmatter <> "\n\n" <> body <> links_section
  end

  @spec build_frontmatter(entry()) :: String.t()
  defp build_frontmatter(entry) do
    created_str = format_datetime(entry.created_at)
    updated_str = format_datetime(Map.get(entry, :updated_at, entry.created_at))

    tags_yaml =
      case Map.get(entry, :tags, []) do
        [] -> "tags: []"
        tags -> "tags:\n" <> Enum.map_join(tags, "\n", fn t -> "  - #{sanitize_tag(t)}" end)
      end

    source_line =
      case Map.get(entry, :source) do
        nil -> ""
        "" -> ""
        src -> "\nsource: \"#{escape_yaml_string(src)}\""
      end

    extraction_status =
      entry
      |> Map.get(:metadata, %{})
      |> Map.get(:extraction_status, :complete)
      |> to_string()

    """
    ---
    id: "#{entry.id}"
    title: "#{escape_yaml_string(entry.title)}"
    #{tags_yaml}
    created: "#{created_str}"
    modified: "#{updated_str}"#{source_line}
    extraction_status: "#{extraction_status}"
    generator: "Indrajaal SMRITI v21.3.0-SIL6"
    ---\
    """
  end

  @spec build_note_body(entry()) :: String.t()
  defp build_note_body(entry) do
    title_section = "# #{entry.title}\n"

    content_section =
      case Map.get(entry, :content, "") do
        "" -> "_No content available._\n"
        content -> content <> "\n"
      end

    metadata_section = build_metadata_section(entry)

    title_section <> "\n" <> content_section <> metadata_section
  end

  @spec build_metadata_section(entry()) :: String.t()
  defp build_metadata_section(entry) do
    extra_meta = Map.get(entry, :metadata, %{})

    if map_size(extra_meta) == 0 do
      ""
    else
      rows =
        extra_meta
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.map(fn {k, v} -> "| #{k} | #{inspect(v)} |" end)
        |> Enum.join("\n")

      if rows == "" do
        ""
      else
        "\n\n## Metadata\n\n| Key | Value |\n|-----|-------|\n#{rows}\n"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Vault Index
  # ---------------------------------------------------------------------------

  @spec write_vault_index(String.t(), [entry()], String.t()) :: :ok | {:error, term()}
  defp write_vault_index(output_dir, entries, vault_name) do
    now_str = DateTime.utc_now() |> DateTime.to_iso8601()
    total = length(entries)

    tag_cloud = build_tag_cloud(entries)

    recent_links =
      entries
      |> Enum.sort_by(&format_datetime(Map.get(&1, :updated_at, &1.created_at)), :desc)
      |> Enum.take(10)
      |> Enum.map(fn e -> "- [[#{note_filename(e.title)}|#{e.title}]]" end)
      |> Enum.join("\n")

    content = """
    ---
    title: "#{escape_yaml_string(vault_name)} — Index"
    tags:
      - smriti
      - vault-index
    created: "#{now_str}"
    modified: "#{now_str}"
    generator: "Indrajaal SMRITI v21.3.0-SIL6"
    ---

    # #{vault_name}

    > *Generated by Indrajaal SMRITI v21.3.0-SIL6 — #{now_str}*
    >
    > Constitutional compliance: Ψ₁ Regeneration | Ψ₂ History | Ψ₅ Truthfulness

    ## Statistics

    | Metric | Value |
    |--------|-------|
    | Total Notes | #{total} |
    | Export Date | #{now_str} |
    | Generator | Indrajaal SMRITI v21.3.0-SIL6 |

    ## Tag Cloud

    #{tag_cloud}

    ## Recently Modified

    #{if recent_links == "", do: "_No entries._", else: recent_links}

    ## All Notes

    #{build_all_notes_list(entries)}

    ---
    *This vault was generated by the SMRITI knowledge system. To regenerate, use:*
    ```elixir
    Indrajaal.Smriti.Immortality.ObsidianExporter.export_vault(output_dir, entries)
    ```
    """

    path = Path.join(output_dir, "vault-index.md")
    File.write(path, content)
  end

  @spec build_tag_cloud([entry()]) :: String.t()
  defp build_tag_cloud(entries) do
    tag_counts =
      entries
      |> Enum.flat_map(&Map.get(&1, :tags, []))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_tag, count} -> count end, :desc)
      |> Enum.take(30)

    if Enum.empty?(tag_counts) do
      "_No tags._"
    else
      tag_counts
      |> Enum.map(fn {tag, count} -> "##{sanitize_tag(tag)} (#{count})" end)
      |> Enum.join(" · ")
    end
  end

  @spec build_all_notes_list([entry()]) :: String.t()
  defp build_all_notes_list(entries) do
    if Enum.empty?(entries) do
      "_No entries._"
    else
      entries
      |> Enum.sort_by(& &1.title)
      |> Enum.map(fn e ->
        tags_inline =
          case Map.get(e, :tags, []) do
            [] -> ""
            tags -> " " <> Enum.map_join(tags, " ", fn t -> "##{sanitize_tag(t)}" end)
          end

        "- [[#{note_filename(e.title)}|#{e.title}]]#{tags_inline}"
      end)
      |> Enum.join("\n")
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Templates
  # ---------------------------------------------------------------------------

  @spec write_templates(String.t()) :: :ok | {:error, term()}
  defp write_templates(output_dir) do
    templates_dir = Path.join(output_dir, @templates_dir)
    now_str = DateTime.utc_now() |> DateTime.to_iso8601()

    note_template = """
    ---
    title: "{{title}}"
    tags: []
    created: "{{date}}"
    modified: "{{date}}"
    source: ""
    extraction_status: "complete"
    generator: "Indrajaal SMRITI v21.3.0-SIL6"
    ---

    # {{title}}

    ## Summary

    <!-- Add summary here -->

    ## Content

    <!-- Add content here -->

    ## Links

    <!-- Add [[wiki-links]] here -->
    """

    daily_template = """
    ---
    title: "Daily Note — {{date}}"
    tags:
      - daily-note
    created: "#{now_str}"
    modified: "#{now_str}"
    generator: "Indrajaal SMRITI v21.3.0-SIL6"
    ---

    # Daily Note — {{date}}

    ## Observations

    ## Decisions

    ## Actions

    ## Links
    """

    with :ok <- File.write(Path.join(templates_dir, "Note Template.md"), note_template),
         :ok <- File.write(Path.join(templates_dir, "Daily Note Template.md"), daily_template) do
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Helpers
  # ---------------------------------------------------------------------------

  @spec format_datetime(DateTime.t() | String.t() | nil) :: String.t()
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(dt_str) when is_binary(dt_str), do: dt_str
  defp format_datetime(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp format_datetime(_), do: DateTime.utc_now() |> DateTime.to_iso8601()

  @spec escape_yaml_string(String.t()) :: String.t()
  defp escape_yaml_string(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", " ")
    |> String.replace("\r", "")
  end

  defp escape_yaml_string(other), do: inspect(other)

  @spec sanitize_tag(String.t() | atom()) :: String.t()
  defp sanitize_tag(tag) when is_atom(tag), do: sanitize_tag(to_string(tag))

  defp sanitize_tag(tag) when is_binary(tag) do
    tag
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-_\/]/, "-")
    |> String.replace(~r/\-+/, "-")
    |> String.trim("-")
  end

  defp sanitize_tag(other), do: sanitize_tag(to_string(other))

  @spec emit_telemetry(atom(), map()) :: :ok
  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :immortality, :obsidian, event],
      %{timestamp: System.monotonic_time(:millisecond)},
      metadata
    )

    :ok
  end
end
