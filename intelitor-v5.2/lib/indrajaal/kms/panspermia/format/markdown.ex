defmodule Indrajaal.KMS.Panspermia.Format.Markdown do
  @moduledoc """
  Markdown format renderer for Panspermia exports.

  Renders SMRITI knowledge entries to human-readable Markdown format
  suitable for documentation, sharing, and long-term preservation.

  ## STAMP Constraints

  - SC-SMRITI-078: Markdown MUST be valid CommonMark
  - SC-SMRITI-079: Headers MUST form valid hierarchy
  - SC-OBS-021: Render operations emit telemetry

  ## Constitutional Alignment

  - Ψ₁ (Regeneration): Markdown parseable by any system
  - Ψ₅ (Truthfulness): Content preserved without modification
  """

  @type entry :: %{
          id: String.t(),
          content: String.t(),
          metadata: map(),
          created_at: String.t(),
          updated_at: String.t(),
          checksum: String.t()
        }

  @type lineage_event :: %{
          entry_id: String.t(),
          action: String.t(),
          timestamp: String.t(),
          actor: String.t() | nil
        }

  @doc """
  Renders entries and lineage to Markdown format.
  """
  @spec render(list(entry()), list(lineage_event()), boolean()) :: String.t()
  def render(entries, lineage, include_metadata \\ true) do
    emit_telemetry(:render_start, %{entries_count: length(entries)})

    content = """
    # SMRITI Knowledge Export

    **Exported**: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    **Entries**: #{length(entries)}
    **Format**: Markdown (CommonMark)

    ---

    ## Table of Contents

    #{render_toc(entries)}

    ---

    ## Knowledge Entries

    #{render_entries(entries, include_metadata)}

    ---

    ## Evolution Lineage

    #{render_lineage(lineage)}

    ---

    ## Metadata

    - **SMRITI Version**: #{smriti_version()}
    - **Constitutional**: Ψ₀-Ψ₅ Compliant
    - **Directive**: Ω₀ (Founder's Directive)

    > This export implements Ψ₁ (Regeneration) - content can be imported
    > into any Markdown-compatible system.
    """

    emit_telemetry(:render_complete, %{size_bytes: byte_size(content)})
    content
  end

  # ============================================================================
  # Private Renderers
  # ============================================================================

  defp render_toc(entries) do
    entries
    |> Enum.take(50)
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, idx} ->
      title = extract_title(entry.content)
      "#{idx}. [#{title}](#entry-#{entry.id})"
    end)
    |> Enum.join("\n")
  end

  defp render_entries(entries, include_metadata) do
    entries
    |> Enum.map(fn entry -> render_entry(entry, include_metadata) end)
    |> Enum.join("\n\n---\n\n")
  end

  defp render_entry(entry, include_metadata) do
    title = extract_title(entry.content)

    metadata_section =
      if include_metadata and map_size(entry.metadata) > 0 do
        """

        **Metadata**:
        ```json
        #{Jason.encode!(entry.metadata, pretty: true)}
        ```
        """
      else
        ""
      end

    """
    ### #{title} {#entry-#{entry.id}}

    **ID**: `#{entry.id}`
    **Created**: #{entry.created_at}
    **Updated**: #{entry.updated_at}
    **Checksum**: `#{entry.checksum}`
    #{metadata_section}

    #{entry.content}
    """
  end

  defp render_lineage([]), do: "_No evolution events recorded._"

  defp render_lineage(lineage) do
    header =
      "| Entry ID | Action | Timestamp | Actor |\n|----------|--------|-----------|-------|\n"

    rows =
      lineage
      |> Enum.take(100)
      |> Enum.map(fn event ->
        "| `#{truncate(event.entry_id, 12)}` | #{event.action} | #{event.timestamp} | #{event.actor || "-"} |"
      end)
      |> Enum.join("\n")

    header <> rows
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp extract_title(content) do
    content
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 60)
    |> String.replace(~r/^#+\s*/, "")
    |> String.trim()
    |> case do
      "" -> "Untitled"
      title -> title
    end
  end

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max - 3) <> "..."
  end

  defp truncate(str, _max), do: str

  defp smriti_version do
    Application.spec(:indrajaal, :vsn) |> to_string() |> String.trim()
  rescue
    _ -> "21.2.0-SIL6"
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :panspermia, :format, :markdown, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
