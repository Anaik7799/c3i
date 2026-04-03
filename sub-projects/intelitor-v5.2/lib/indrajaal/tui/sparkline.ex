defmodule Indrajaal.TUI.Sparkline do
  @moduledoc """
  TUI Sparkline Renderer — CPU / Memory Trend Visualisation.

  WHAT: Pure-function module that converts a list of numeric values into
        an ANSI-coloured Unicode block-character sparkline string. No state
        or GenServer required; the caller provides raw time-series samples.

  WHY: Operators viewing the Prajna Emergency Terminal need at-a-glance
       trend information for CPU and memory without a full GUI chart.
       Unicode block characters (▁▂▃▄▅▆▇█) give 8-level resolution in a
       single terminal character width.

  CONSTRAINTS:
    - SC-HMI-010: Color Rich — vibrant chromatic feedback
    - SC-PRAJNA-001: TUI render <50ms — pure functions only
    - SC-CPU-GOV-001: Zero overhead — no process spawning
    - SC-MON-002: Infrastructure metrics complete

  ## Supported Colors
    - `:green`  — healthy / normal range
    - `:yellow` — warning / elevated
    - `:red`    — critical / exceeded threshold

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-28 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | STAMP | SC-HMI-010, SC-PRAJNA-001, SC-MON-002 |
  """

  @blocks [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  @ansi_colors %{
    green: "\e[32m",
    yellow: "\e[33m",
    red: "\e[31m",
    cyan: "\e[36m",
    white: "\e[37m"
  }

  @reset "\e[0m"
  @bold "\e[1m"

  # ═══════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════

  @doc """
  Renders `values` as a Unicode block sparkline string (no label, default colour).

  ## Examples

      iex> Indrajaal.TUI.Sparkline.render([10, 50, 30, 90, 45])
      "▁▄▂█▃"
  """
  @spec render([number()]) :: String.t()
  def render(values) when is_list(values) do
    render(values, [])
  end

  @doc """
  Renders `values` as a sparkline with optional `opts`:
    - `:width`  — maximum number of columns to use (default: full list)
    - `:label`  — prefix label string (default: nil)
    - `:color`  — ANSI colour atom: :green | :yellow | :red (default: :white)

  ## Examples

      iex> Indrajaal.TUI.Sparkline.render([20, 60, 80, 40], label: "CPU", color: :green)
      "CPU ▂▅▇▃"
  """
  @spec render([number()], keyword()) :: String.t()
  def render(values, opts) when is_list(values) and is_list(opts) do
    width = Keyword.get(opts, :width, length(values))
    label = Keyword.get(opts, :label, nil)
    color = Keyword.get(opts, :color, :white)

    # Trim to requested width (take last N points for rolling window feel)
    trimmed =
      if length(values) > width do
        Enum.take(values, -width)
      else
        values
      end

    normalized = normalize(trimmed, 7)
    bars = Enum.map_join(normalized, "", &block_char/1)

    ansi = Map.get(@ansi_colors, color, @ansi_colors.white)
    colored_bars = "#{ansi}#{bars}#{@reset}"

    case label do
      nil -> colored_bars
      lbl -> "#{@bold}#{lbl}#{@reset} #{colored_bars}"
    end
  end

  @doc """
  Normalises `values` to the range `[0, max_level]` (integer).

  Values are scaled linearly; all identical values map to 0.
  Empty list returns empty list.

  ## Examples

      iex> Indrajaal.TUI.Sparkline.normalize([0, 50, 100], 7)
      [0, 3, 7]
  """
  @spec normalize([number()], non_neg_integer()) :: [non_neg_integer()]
  def normalize([], _max_level), do: []

  def normalize(values, max_level) when is_list(values) and is_integer(max_level) do
    min_v = Enum.min(values)
    max_v = Enum.max(values)
    range = max_v - min_v

    if range == 0 do
      List.duplicate(0, length(values))
    else
      Enum.map(values, fn v ->
        round((v - min_v) / range * max_level)
        |> max(0)
        |> min(max_level)
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════

  @spec block_char(non_neg_integer()) :: String.t()
  defp block_char(level) when is_integer(level) do
    Enum.at(@blocks, min(level, length(@blocks) - 1), "█")
  end
end
