defmodule Indrajaal.TUI.ContainerHealthBars do
  @moduledoc """
  TUI ANSI Dashboard — Container Health Bars.

  WHAT: Pure-function module that renders ANSI-colored health bars for a list
        of container statuses. Designed for the Prajna Emergency Terminal (TUI).

  WHY: Operators running Prajna in headless / degraded-display mode need a
       compact, colour-coded summary of container health that fits into an 80-
       column terminal. No GenServer state required — the caller provides
       current status snapshots and receives a ready-to-print ANSI string.

  CONSTRAINTS:
    - SC-HMI-010: Color Rich — vibrant chromatic feedback
    - SC-PRAJNA-001: Prajna TUI must render in <50ms
    - SC-SIL4-001: Safety functions must fail to safe state (outputs plain text
      on render error rather than crashing)
    - SC-CPU-GOV-001: Pure functions; zero GenServer overhead

  ## Container Status Schema
  Each element in the input list must be a map with at least:
    - `:name`   (string) — container name, e.g. "indrajaal-ex-app-1"
    - `:status` (atom)   — :healthy | :degraded | :unhealthy
    - `:pct`    (number) — utilisation percentage 0–100 (e.g. CPU or uptime %)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-28 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | STAMP | SC-HMI-010, SC-PRAJNA-001, SC-SIL4-001 |
  """

  # ANSI escape sequences
  @reset "\e[0m"
  @green "\e[32m"
  @yellow "\e[33m"
  @red "\e[31m"
  @bold "\e[1m"
  @dim "\e[2m"

  @bar_width 20
  @name_width 30

  # ═══════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════

  @doc """
  Renders a full ANSI-colored health bar dashboard for `container_statuses`.

  Each entry must have `:name`, `:status`, and `:pct` keys.
  Returns a UTF-8 string suitable for `IO.puts/1`.
  """
  @spec render([map()]) :: String.t()
  def render(container_statuses) when is_list(container_statuses) do
    bar_lines =
      container_statuses
      |> Enum.map(&render_row/1)
      |> Enum.join("\n")

    summary_line = summary(container_statuses)
    separator = "#{@dim}#{String.duplicate("─", 55)}#{@reset}"

    [bar_lines, separator, summary_line]
    |> Enum.join("\n")
  end

  @doc """
  Renders a single container bar with `name` and `pct` (0–100).

  Uses :healthy/:degraded/:unhealthy status to pick colour.
  """
  @spec bar(String.t(), number(), atom()) :: String.t()
  def bar(name, pct, status \\ :healthy)
      when is_binary(name) and is_number(pct) do
    {color, symbol} = status_color_symbol(status)
    filled = round(pct / 100 * @bar_width)
    empty = @bar_width - filled

    bar_str =
      color <>
        String.duplicate("█", filled) <>
        @dim <>
        String.duplicate("░", empty) <>
        @reset

    padded_name =
      name
      |> String.slice(0, @name_width)
      |> String.pad_trailing(@name_width)

    pct_str = pct |> round() |> Integer.to_string() |> String.pad_leading(3)

    "#{@bold}#{color}#{symbol}#{@reset} #{@dim}#{padded_name}#{@reset} [#{bar_str}] #{color}#{@bold}#{pct_str}%#{@reset}"
  end

  @doc """
  Returns a summary line: "Healthy: N  Degraded: N  Unhealthy: N".
  """
  @spec summary([map()]) :: String.t()
  def summary(container_statuses) when is_list(container_statuses) do
    counts =
      Enum.reduce(container_statuses, %{healthy: 0, degraded: 0, unhealthy: 0}, fn item, acc ->
        status = Map.get(item, :status, :unhealthy)
        Map.update(acc, status, 1, &(&1 + 1))
      end)

    healthy_count = Map.get(counts, :healthy, 0)
    degraded_count = Map.get(counts, :degraded, 0)
    unhealthy_count = Map.get(counts, :unhealthy, 0)

    "#{@green}#{@bold}Healthy:#{@reset} #{healthy_count}  " <>
      "#{@yellow}#{@bold}Degraded:#{@reset} #{degraded_count}  " <>
      "#{@red}#{@bold}Unhealthy:#{@reset} #{unhealthy_count}"
  end

  # ═══════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════

  @spec render_row(map()) :: String.t()
  defp render_row(%{name: name, status: status, pct: pct}) do
    bar(name, pct, status)
  end

  defp render_row(item) do
    # Graceful fallback per SC-SIL4-001 (fail to safe state)
    name = Map.get(item, :name, "unknown")
    status = Map.get(item, :status, :unhealthy)
    pct = Map.get(item, :pct, 0)
    bar(to_string(name), pct * 1.0, status)
  end

  @spec status_color_symbol(atom()) :: {String.t(), String.t()}
  defp status_color_symbol(:healthy), do: {@green, "●"}
  defp status_color_symbol(:degraded), do: {@yellow, "◑"}
  defp status_color_symbol(:unhealthy), do: {@red, "○"}
  defp status_color_symbol(_), do: {@red, "?"}
end
