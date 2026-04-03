defmodule Indrajaal.Smriti.GraphTooltip do
  @moduledoc """
  Graph tooltip with Zettelkasten note info for the SMRITI knowledge graph.

  Generates richly formatted tooltip payloads for knowledge graph nodes.
  Each tooltip includes the zettel's title, type, connection count, tags,
  and a short excerpt — all computed from the zettel record.

  This is a pure module: no side effects, no process state.

  ## STAMP Constraints
  - SC-SMRITI-131: Full-text search / graph queries — ENFORCED (tooltip uses existing data)
  - SC-HMI-010: Vibrant chromatic feedback based on node type — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type zettel :: %{
          required(:id) => String.t(),
          required(:title) => String.t(),
          required(:type) => atom(),
          optional(:tags) => [String.t()],
          optional(:content) => String.t(),
          optional(:connection_count) => non_neg_integer(),
          optional(:created_at) => DateTime.t() | nil,
          optional(:updated_at) => DateTime.t() | nil
        }

  @type tooltip :: %{
          id: String.t(),
          title: String.t(),
          type_label: String.t(),
          color: String.t(),
          tags: [String.t()],
          excerpt: String.t(),
          connection_count: non_neg_integer(),
          age_label: String.t(),
          html: String.t()
        }

  # Color palette per zettel type (SC-HMI-010 chromatic feedback)
  @type_colors %{
    concept: "#60a5fa",
    reference: "#34d399",
    journal: "#fbbf24",
    task: "#f87171",
    decision: "#a78bfa",
    architecture: "#fb923c",
    constraint: "#e879f9",
    unknown: "#94a3b8"
  }

  @doc """
  Build a tooltip payload for the given zettel record.
  """
  @spec build(zettel()) :: tooltip()
  def build(%{id: id, title: title, type: type} = zettel) do
    color = Map.get(@type_colors, type, @type_colors.unknown)
    tags = Map.get(zettel, :tags, [])
    content = Map.get(zettel, :content, "")
    connection_count = Map.get(zettel, :connection_count, 0)
    updated_at = Map.get(zettel, :updated_at)

    excerpt = excerpt(content)
    type_label = type_label(type)
    age_label = age_label(updated_at)
    html = render_html(title, type_label, color, tags, excerpt, connection_count, age_label)

    %{
      id: id,
      title: title,
      type_label: type_label,
      color: color,
      tags: tags,
      excerpt: excerpt,
      connection_count: connection_count,
      age_label: age_label,
      html: html
    }
  end

  @doc """
  Return the hex color for a given zettel type atom.
  """
  @spec color_for_type(atom()) :: String.t()
  def color_for_type(type) when is_atom(type) do
    Map.get(@type_colors, type, @type_colors.unknown)
  end

  @doc """
  Return all known type → color mappings.
  """
  @spec type_color_map() :: %{atom() => String.t()}
  def type_color_map, do: @type_colors

  @doc """
  Produce a plain-text excerpt from content (first 120 chars, word-safe).
  """
  @spec excerpt(String.t()) :: String.t()
  def excerpt(""), do: ""

  def excerpt(content) when is_binary(content) do
    stripped = String.replace(content, ~r/[#*`>\[\]_~]/, "")
    trimmed = String.trim(stripped)

    if String.length(trimmed) <= 120 do
      trimmed
    else
      # Cut at last space before 120 chars
      prefix = String.slice(trimmed, 0, 120)

      case String.split(prefix, " ") |> Enum.drop(-1) |> Enum.join(" ") do
        "" -> prefix
        safe -> safe <> "…"
      end
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  @spec type_label(atom()) :: String.t()
  defp type_label(:concept), do: "Concept"
  defp type_label(:reference), do: "Reference"
  defp type_label(:journal), do: "Journal"
  defp type_label(:task), do: "Task"
  defp type_label(:decision), do: "Decision"
  defp type_label(:architecture), do: "Architecture"
  defp type_label(:constraint), do: "Constraint"
  defp type_label(other) when is_atom(other), do: other |> Atom.to_string() |> String.capitalize()

  @spec age_label(DateTime.t() | nil) :: String.t()
  defp age_label(nil), do: "unknown age"

  defp age_label(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> "#{div(diff, 604_800)}w ago"
    end
  end

  @spec render_html(
          String.t(),
          String.t(),
          String.t(),
          [String.t()],
          String.t(),
          non_neg_integer(),
          String.t()
        ) ::
          String.t()
  defp render_html(title, type_label, color, tags, excerpt, connection_count, age_label) do
    tag_html =
      tags
      |> Enum.take(5)
      |> Enum.map(&"<span class=\"zettel-tag\">#{escape_html(&1)}</span>")
      |> Enum.join(" ")

    """
    <div class="zettel-tooltip" style="border-left: 3px solid #{color};">
      <div class="zettel-tooltip__header">
        <span class="zettel-tooltip__type" style="color: #{color};">#{escape_html(type_label)}</span>
        <span class="zettel-tooltip__age">#{escape_html(age_label)}</span>
      </div>
      <div class="zettel-tooltip__title">#{escape_html(title)}</div>
      <div class="zettel-tooltip__excerpt">#{escape_html(excerpt)}</div>
      <div class="zettel-tooltip__footer">
        <span class="zettel-tooltip__connections">#{connection_count} connections</span>
        <span class="zettel-tooltip__tags">#{tag_html}</span>
      </div>
    </div>
    """
    |> String.trim()
  end

  @spec escape_html(String.t()) :: String.t()
  defp escape_html(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
