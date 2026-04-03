defmodule Indrajaal.CLI.EnvelopeHealth do
  @moduledoc """
  CLI envelope command — formats Zenoh health score and Sentinel threat count for the terminal.

  Pure formatter module: reads the latest health snapshot from
  `Indrajaal.Cli.HealthScoreAggregator` and renders it as an ANSI-coloured
  multi-line string for the Prajna TUI dashboard.

  No side effects. All functions are pure transformations of input maps.

  ## Data Source
  - `Indrajaal.Cli.HealthScoreAggregator.get_snapshot/0`

  ## Output Example

      ── Indrajaal Health Envelope ─────────────────
      Score   87%   ▓▓▓▓▓▓▓▓▓░  NOMINAL
      Threats  0    [NOMINAL]
      Domains  30   (top 3: safety=92, mesh=88, alarms=85)
      Updated  12:34:56 UTC

  ## STAMP Compliance
  - SC-CLI-001: CLI commands available and responsive
  - SC-HEALTH-001: Health scores MUST be published continuously
  - SC-HEALTH-003: Threat count MUST be derived from Sentinel
  - SC-HMI-010: Color-rich terminal feedback
  - SC-FUNC-001: Module must compile without errors/warnings

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — task cb47f15f |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type snapshot :: %{
          composite_score: non_neg_integer(),
          domain_scores: %{atom() => non_neg_integer()},
          active_threat_count: non_neg_integer(),
          threat_level: String.t(),
          threat_details: list(),
          last_sentinel_check: DateTime.t() | nil
        }

  @type formatted_line :: String.t()

  # ANSI escape codes
  @reset "\e[0m"
  @bold "\e[1m"
  @green "\e[32m"
  @yellow "\e[33m"
  @red "\e[31m"
  @cyan "\e[36m"
  @gray "\e[90m"

  # Bar width for the progress bar
  @bar_width 10

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetch the health snapshot from `HealthScoreAggregator` and format it as a
  multi-line terminal string.

  Falls back gracefully if the aggregator GenServer is not running.
  """
  @spec run() :: String.t()
  def run do
    snapshot = fetch_snapshot()
    format(snapshot)
  end

  @doc """
  Format a health `snapshot` map into a human-readable, colour-annotated string.

  Pure function — does not call any external process.
  """
  @spec format(snapshot()) :: String.t()
  def format(snapshot) when is_map(snapshot) do
    lines = [
      header_line(),
      score_line(snapshot),
      threat_line(snapshot),
      domains_line(snapshot),
      footer_line(snapshot)
    ]

    Enum.join(lines, "\n")
  end

  @doc """
  Render a 10-character ASCII progress bar for a 0-100 score.

  ## Examples

      iex> progress_bar(80)
      "▓▓▓▓▓▓▓▓░░"

      iex> progress_bar(100)
      "▓▓▓▓▓▓▓▓▓▓"
  """
  @spec progress_bar(non_neg_integer()) :: String.t()
  def progress_bar(score) when is_integer(score) and score >= 0 and score <= 100 do
    filled = round(score * @bar_width / 100)
    empty = @bar_width - filled
    String.duplicate("▓", filled) <> String.duplicate("░", empty)
  end

  def progress_bar(_), do: String.duplicate("░", @bar_width)

  @doc """
  Return the threat level string with ANSI colour applied.
  """
  @spec colorize_threat_level(String.t()) :: String.t()
  def colorize_threat_level("CRITICAL"), do: "#{@red}CRITICAL#{@reset}"
  def colorize_threat_level("HIGH"), do: "#{@red}HIGH#{@reset}"
  def colorize_threat_level("ELEVATED"), do: "#{@yellow}ELEVATED#{@reset}"
  def colorize_threat_level("NOMINAL"), do: "#{@green}NOMINAL#{@reset}"
  def colorize_threat_level("LOW"), do: "#{@green}LOW#{@reset}"
  def colorize_threat_level(other) when is_binary(other), do: "#{@gray}#{other}#{@reset}"

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_snapshot do
    aggregator = Indrajaal.Cli.HealthScoreAggregator

    if Code.ensure_loaded?(aggregator) and
         function_exported?(aggregator, :get_snapshot, 0) and
         GenServer.whereis(aggregator) != nil do
      aggregator.get_snapshot()
    else
      %{
        composite_score: 0,
        domain_scores: %{},
        active_threat_count: 0,
        threat_level: "UNKNOWN",
        threat_details: [],
        last_sentinel_check: nil
      }
    end
  end

  defp header_line do
    "#{@bold}#{@cyan}── Indrajaal Health Envelope ─────────────────#{@reset}"
  end

  defp score_line(%{composite_score: score, threat_level: level}) do
    color = score_color(score)
    bar = progress_bar(score)
    "#{color}Score  #{pad(score, 3)}%#{@reset}  #{bar}  #{colorize_threat_level(level)}"
  end

  defp score_line(_), do: "#{@gray}Score  --#{@reset}"

  defp threat_line(%{active_threat_count: count, threat_level: level}) do
    color = if count > 0, do: @red, else: @green
    "#{color}Threats  #{count}#{@reset}    [#{colorize_threat_level(level)}]"
  end

  defp threat_line(_), do: "#{@gray}Threats  --#{@reset}"

  defp domains_line(%{domain_scores: scores}) when map_size(scores) > 0 do
    count = map_size(scores)

    top3 =
      scores
      |> Enum.sort_by(fn {_k, v} -> v end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join(", ")

    "#{@cyan}Domains  #{count}#{@reset}  (top 3: #{top3})"
  end

  defp domains_line(_), do: "#{@gray}Domains  0 (no data)#{@reset}"

  defp footer_line(%{last_sentinel_check: nil}),
    do: "#{@gray}Updated  --  (Sentinel not checked)#{@reset}"

  defp footer_line(%{last_sentinel_check: dt}) when not is_nil(dt) do
    ts = Calendar.strftime(dt, "%H:%M:%S")
    "#{@gray}Updated  #{ts} UTC#{@reset}"
  end

  defp footer_line(_), do: "#{@gray}Updated  --#{@reset}"

  defp score_color(score) when is_integer(score) and score >= 80, do: @green
  defp score_color(score) when is_integer(score) and score >= 50, do: @yellow
  defp score_color(_), do: @red

  defp pad(n, width) when is_integer(n) do
    str = Integer.to_string(n)
    String.pad_leading(str, width)
  end
end
