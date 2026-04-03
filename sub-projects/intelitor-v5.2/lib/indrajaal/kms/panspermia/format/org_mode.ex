defmodule Indrajaal.KMS.Panspermia.Format.OrgMode do
  @moduledoc """
  Org-Mode format renderer for Panspermia exports.

  Renders SMRITI knowledge entries to Emacs Org-Mode format for integration
  with the powerful Org ecosystem (agenda, babel, export, capture).

  ## STAMP Constraints

  - SC-SMRITI-080: Org syntax MUST be valid
  - SC-SMRITI-081: Properties MUST use drawer format
  - SC-OBS-022: Render operations emit telemetry

  ## Constitutional Alignment

  - Ψ₁ (Regeneration): Org files readable by any text editor
  - Ψ₂ (History): TODO states preserve lineage

  ## Org-Mode Integration

  - Uses property drawers for metadata
  - Supports TODO/DONE states for entries
  - Compatible with org-babel for code blocks
  - Supports org-roam backlinks
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
  Renders entries and lineage to Org-Mode format.
  """
  @spec render(list(entry()), list(lineage_event()), boolean()) :: String.t()
  def render(entries, lineage, include_metadata \\ true) do
    emit_telemetry(:render_start, %{entries_count: length(entries)})

    content = """
    #+TITLE: SMRITI Knowledge Export
    #+AUTHOR: Indrajaal KMS
    #+DATE: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    #+STARTUP: overview
    #+OPTIONS: toc:3 num:t
    #+PROPERTY: SMRITI_VERSION #{smriti_version()}
    #+PROPERTY: CONSTITUTIONAL Ψ₀-Ψ₅

    * Overview
    :PROPERTIES:
    :EXPORTED: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    :ENTRIES: #{length(entries)}
    :FORMAT: Org-Mode
    :END:

    This export implements Ψ₁ (Regeneration) - content can be imported
    into any Org-Mode compatible system (Emacs, Logseq, etc.).

    * Knowledge Entries
    #{render_entries(entries, include_metadata)}

    * Evolution Lineage
    #{render_lineage(lineage)}

    * Metadata
    :PROPERTIES:
    :VERSION: #{smriti_version()}
    :DIRECTIVE: Ω₀ (Founder's Directive)
    :AXIOMS: Ψ₀ Ψ₁ Ψ₂ Ψ₃ Ψ₄ Ψ₅
    :END:

    ** Constitutional Invariants

    | Axiom | Name | Description |
    |-------+------+-------------|
    | Ψ₀ | Existence | System MUST continue to exist |
    | Ψ₁ | Regeneration | System MUST be reconstructible |
    | Ψ₂ | History | Evolution history MUST be preserved |
    | Ψ₃ | Verification | All state MUST be verifiable |
    | Ψ₄ | Human Alignment | System serves Founder's lineage |
    | Ψ₅ | Truthfulness | System MUST NOT deceive |
    """

    emit_telemetry(:render_complete, %{size_bytes: byte_size(content)})
    content
  end

  # ============================================================================
  # Private Renderers
  # ============================================================================

  defp render_entries(entries, include_metadata) do
    entries
    |> Enum.map(fn entry -> render_entry(entry, include_metadata) end)
    |> Enum.join("\n")
  end

  defp render_entry(entry, include_metadata) do
    title = extract_title(entry.content)
    state = if entry.metadata["completed"], do: "DONE", else: "TODO"

    properties =
      if include_metadata do
        """
        :PROPERTIES:
        :ID: #{entry.id}
        :CREATED: #{entry.created_at}
        :UPDATED: #{entry.updated_at}
        :CHECKSUM: #{entry.checksum}
        #{render_custom_properties(entry.metadata)}:END:
        """
      else
        """
        :PROPERTIES:
        :ID: #{entry.id}
        :END:
        """
      end

    content = convert_content_to_org(entry.content)

    """
    ** #{state} #{title}
    #{properties}
    #{content}
    """
  end

  defp render_custom_properties(metadata) when is_map(metadata) do
    metadata
    |> Map.drop(["completed"])
    |> Enum.map(fn {k, v} ->
      key = String.upcase(to_string(k))
      value = if is_binary(v), do: v, else: inspect(v)
      ":#{key}: #{value}\n"
    end)
    |> Enum.join()
  end

  defp render_custom_properties(_), do: ""

  defp render_lineage([]), do: "No evolution events recorded."

  defp render_lineage(lineage) do
    header =
      "| Entry ID | Action | Timestamp | Actor |\n|----------+--------+-----------+-------|\n"

    rows =
      lineage
      |> Enum.take(100)
      |> Enum.map(fn event ->
        "| ~#{truncate(event.entry_id, 12)}~ | #{event.action} | #{event.timestamp} | #{event.actor || "-"} |"
      end)
      |> Enum.join("\n")

    header <> rows
  end

  defp convert_content_to_org(content) do
    content
    # Convert markdown headers to org headers (relative)
    |> String.replace(~r/^### /m, "**** ")
    |> String.replace(~r/^## /m, "*** ")
    |> String.replace(~r/^# /m, "** ")
    # Convert code blocks
    |> String.replace(~r/```(\w+)\n/m, "#+BEGIN_SRC \\1\n")
    |> String.replace(~r/```/m, "#+END_SRC")
    # Convert bold
    |> String.replace(~r/\*\*(.+?)\*\*/m, "*\\1*")
    # Convert inline code
    |> String.replace(~r/`([^`]+)`/m, "~\\1~")
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
      "" -> "Untitled Entry"
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
      [:smriti, :panspermia, :format, :org_mode, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
