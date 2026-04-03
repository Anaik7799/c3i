defmodule Indrajaal.KMS.Panspermia.Format do
  @moduledoc """
  Format rendering namespace for Panspermia exports.

  Provides a unified interface to all export format renderers.

  ## Available Formats

  - `Format.Markdown` - CommonMark compatible Markdown
  - `Format.OrgMode` - Emacs Org-Mode format
  - `Format.Obsidian` - Obsidian vault format

  ## STAMP Constraints

  - SC-SMRITI-085: All formats MUST be human-readable
  - SC-SMRITI-086: All formats MUST preserve content integrity
  - SC-OBS-024: Format rendering emits telemetry

  ## Usage

      alias Indrajaal.KMS.Panspermia.Format

      # Render to Markdown
      markdown = Format.Markdown.render(entries, lineage)

      # Render to Org-Mode
      org = Format.OrgMode.render(entries, lineage)

      # Render Obsidian vault
      index = Format.Obsidian.render_index(entries)
      note = Format.Obsidian.render_note(entry)
  """

  # Re-export format modules for convenient access
  defdelegate markdown(entries, lineage, opts \\ true), to: __MODULE__.Markdown, as: :render
  defdelegate org_mode(entries, lineage, opts \\ true), to: __MODULE__.OrgMode, as: :render
  defdelegate obsidian_index(entries), to: __MODULE__.Obsidian, as: :render_index
  defdelegate obsidian_note(entry, opts \\ true), to: __MODULE__.Obsidian, as: :render_note

  @doc """
  Returns all available format modules.
  """
  @spec available() :: list(module())
  def available do
    [
      __MODULE__.Markdown,
      __MODULE__.OrgMode,
      __MODULE__.Obsidian
    ]
  end

  @doc """
  Checks if a format module is valid.
  """
  @spec valid_format?(atom()) :: boolean()
  def valid_format?(format) when is_atom(format) do
    format in [:markdown, :org_mode, :obsidian, :json, :sqlite]
  end
end
