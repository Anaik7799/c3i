defmodule Indrajaal.KMS.Panspermia.Format.Obsidian do
  @moduledoc """
  Obsidian vault format renderer for Panspermia exports.

  Renders SMRITI knowledge entries to Obsidian-compatible vault format
  with full support for wikilinks, YAML frontmatter, and graph visualization.

  ## STAMP Constraints

  - SC-SMRITI-082: Vault MUST include .obsidian config
  - SC-SMRITI-083: Notes MUST use YAML frontmatter
  - SC-SMRITI-084: Wikilinks MUST be valid
  - SC-OBS-023: Render operations emit telemetry

  ## Constitutional Alignment

  - Ψ₁ (Regeneration): Vault portable to any Obsidian instance
  - Ψ₂ (History): Version history in frontmatter

  ## Obsidian Features

  - YAML frontmatter for metadata
  - Wikilinks [[...]] for internal references
  - Tags via #tag syntax
  - Graph view compatible
  - Backlinks supported
  - Canvas compatible
  """

  @type entry :: %{
          id: String.t(),
          content: String.t(),
          metadata: map(),
          created_at: String.t(),
          updated_at: String.t(),
          checksum: String.t()
        }

  @doc """
  Renders the vault index file (MOC - Map of Content).
  """
  @spec render_index(list(entry())) :: String.t()
  def render_index(entries) do
    emit_telemetry(:render_index_start, %{entries_count: length(entries)})

    # Group entries by category if available
    grouped = group_by_category(entries)

    category_sections =
      grouped
      |> Enum.map(fn {category, cat_entries} ->
        links =
          cat_entries
          |> Enum.take(50)
          |> Enum.map(fn entry ->
            title = extract_title(entry.content)
            "- [[#{sanitize_link(entry.id)}|#{title}]]"
          end)
          |> Enum.join("\n")

        """
        ## #{category}

        #{links}
        """
      end)
      |> Enum.join("\n")

    content = """
    ---
    title: SMRITI Knowledge Index
    type: index
    created: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    smriti_version: #{smriti_version()}
    constitutional: true
    axioms: [Ψ₀, Ψ₁, Ψ₂, Ψ₃, Ψ₄, Ψ₅]
    tags:
      - smriti
      - index
      - moc
    ---

    # SMRITI Knowledge Index

    > **Constitutional Mandate**: This vault implements Ψ₁ (Regeneration) - the system
    > can be fully rebuilt from these notes alone.

    ## Quick Stats

    - **Total Entries**: #{length(entries)}
    - **Categories**: #{map_size(grouped)}
    - **Exported**: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M")}

    ## Categories

    #{category_sections}

    ## Navigation

    - 🔍 Use **Search** (Ctrl+Shift+F) to find entries
    - 🕸️ Use **Graph View** (Ctrl+G) to visualize connections
    - 📌 Use **Backlinks** to find related entries

    ## Constitution

    | Axiom | Name | Status |
    |-------|------|--------|
    | Ψ₀ | Existence | ✅ Active |
    | Ψ₁ | Regeneration | ✅ Active |
    | Ψ₂ | History | ✅ Active |
    | Ψ₃ | Verification | ✅ Active |
    | Ψ₄ | Human Alignment | ✅ Active |
    | Ψ₅ | Truthfulness | ✅ Active |

    ---
    *Founder's Directive (Ω₀): This vault exists for knowledge immortality.*
    """

    emit_telemetry(:render_index_complete, %{size_bytes: byte_size(content)})
    content
  end

  @doc """
  Renders an individual note file.
  """
  @spec render_note(entry(), boolean()) :: String.t()
  def render_note(entry, include_metadata \\ true) do
    emit_telemetry(:render_note_start, %{entry_id: entry.id})

    title = extract_title(entry.content)
    tags = extract_tags(entry)
    aliases = extract_aliases(entry)

    frontmatter =
      if include_metadata do
        metadata_yaml = render_metadata_yaml(entry.metadata)

        """
        ---
        id: #{entry.id}
        title: "#{escape_yaml(title)}"
        created: #{entry.created_at}
        updated: #{entry.updated_at}
        checksum: #{entry.checksum}
        tags: #{inspect(tags)}
        aliases: #{inspect(aliases)}
        #{metadata_yaml}---
        """
      else
        """
        ---
        id: #{entry.id}
        title: "#{escape_yaml(title)}"
        ---
        """
      end

    content = convert_content_to_obsidian(entry.content)

    # Extract and create wikilink suggestions
    related = suggest_related_notes(entry)

    related_section =
      if length(related) > 0 do
        """

        ---

        ## Related Notes

        #{Enum.map(related, fn id -> "- [[#{sanitize_link(id)}]]" end) |> Enum.join("\n")}
        """
      else
        ""
      end

    note_content = """
    #{frontmatter}

    # #{title}

    #{content}
    #{related_section}
    """

    emit_telemetry(:render_note_complete, %{
      entry_id: entry.id,
      size_bytes: byte_size(note_content)
    })

    note_content
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp group_by_category(entries) do
    entries
    |> Enum.group_by(fn entry ->
      get_in(entry, [:metadata, "category"]) ||
        get_in(entry, [:metadata, :category]) ||
        "Uncategorized"
    end)
    |> Enum.sort_by(fn {cat, _} -> cat end)
  end

  defp extract_tags(entry) do
    base_tags = ["smriti", "knowledge"]

    custom_tags =
      case get_in(entry, [:metadata, "tags"]) || get_in(entry, [:metadata, :tags]) do
        tags when is_list(tags) -> tags
        tag when is_binary(tag) -> String.split(tag, ",") |> Enum.map(&String.trim/1)
        _ -> []
      end

    Enum.uniq(base_tags ++ custom_tags)
  end

  defp extract_aliases(entry) do
    case get_in(entry, [:metadata, "aliases"]) || get_in(entry, [:metadata, :aliases]) do
      aliases when is_list(aliases) -> aliases
      alias when is_binary(alias) -> [alias]
      _ -> []
    end
  end

  defp render_metadata_yaml(metadata) when is_map(metadata) do
    metadata
    |> Map.drop(["tags", "aliases", :tags, :aliases])
    |> Enum.map(fn {k, v} ->
      key = to_string(k)

      value =
        cond do
          is_binary(v) -> "\"#{escape_yaml(v)}\""
          is_list(v) -> inspect(v)
          is_map(v) -> inspect(v)
          true -> to_string(v)
        end

      "#{key}: #{value}\n"
    end)
    |> Enum.join()
  end

  defp render_metadata_yaml(_), do: ""

  defp convert_content_to_obsidian(content) do
    content
    # Convert potential internal references to wikilinks
    |> String.replace(~r/\[([^\]]+)\]\(#([^)]+)\)/m, "[[\\2|\\1]]")

    # Preserve code blocks
    # (no conversion needed, Obsidian uses same syntax)
  end

  defp suggest_related_notes(entry) do
    # Extract potential references from content
    # This is a simple implementation - could be enhanced with NLP
    content = entry.content || ""

    # Look for patterns that might be entry IDs
    Regex.scan(~r/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i, content)
    |> List.flatten()
    |> Enum.reject(&(&1 == entry.id))
    |> Enum.take(5)
  end

  defp extract_title(content) do
    content
    |> String.split("\n")
    |> List.first("")
    |> String.slice(0, 60)
    |> String.replace(~r/^#+\s*/, "")
    |> String.trim()
    |> case do
      "" -> "Untitled"
      title -> title
    end
  end

  defp sanitize_link(text) do
    text
    |> String.replace(~r/[#^|\[\]\\\/:]/, "_")
    |> String.slice(0, 100)
  end

  defp escape_yaml(text) do
    text
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", " ")
  end

  defp smriti_version do
    Application.spec(:indrajaal, :vsn) |> to_string() |> String.trim()
  rescue
    _ -> "21.2.0-SIL6"
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :panspermia, :format, :obsidian, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
