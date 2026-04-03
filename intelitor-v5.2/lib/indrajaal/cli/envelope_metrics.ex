defmodule Indrajaal.CLI.EnvelopeMetrics do
  @moduledoc """
  CLI envelope command — formats real system metrics from Zenoh for terminal display.

  Pure formatter module: reads data from `Indrajaal.Cli.ZenohMetricsCollector`
  (GenServer that subscribes to live Zenoh topics) and formats it into a
  compact ANSI-coloured envelope string suitable for the Prajna TUI.

  No side effects. All functions are pure transformations of the data they receive.

  ## Data Sources
  - `Indrajaal.Cli.ZenohMetricsCollector.get_envelope/0`
  - `indrajaal/metrics/**` Zenoh topics
  - `indrajaal/cpu/governor/status` Zenoh topic
  - `indrajaal/math/health` Zenoh topic

  ## STAMP Compliance
  - SC-CLI-001: CLI commands available and responsive
  - SC-HMI-010: Color-rich terminal feedback
  - SC-MON-001: Metrics refresh interval displayed
  - SC-FUNC-001: Module must compile without errors/warnings

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — task 5f6b39f5 |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type envelope :: %{
          nodes: map(),
          health: map(),
          cpu_governor: map(),
          math_health: map(),
          last_update: DateTime.t() | nil
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

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetch the current metrics envelope from `ZenohMetricsCollector` and format it
  as a multi-line terminal string.

  Falls back to an empty envelope if the collector is unavailable.
  """
  @spec run() :: String.t()
  def run do
    envelope = fetch_envelope()
    format(envelope)
  end

  @doc """
  Format a metrics `envelope` map into a human-readable, colour-annotated string
  suitable for terminal display.

  Pure function — does not call any external process.
  """
  @spec format(envelope()) :: String.t()
  def format(envelope) when is_map(envelope) do
    lines = [
      header_line(),
      cpu_line(envelope),
      math_line(envelope),
      nodes_line(envelope),
      health_summary_line(envelope),
      footer_line(envelope)
    ]

    Enum.join(lines, "\n")
  end

  @doc """
  Format the CPU governor section of the envelope.

  ## Examples

      iex> format_cpu(%{cpu_pct: 45, mode: "full", schedulers: 16})
      "CPU  45%  [full] S=16"
  """
  @spec format_cpu(map()) :: formatted_line()
  def format_cpu(%{"cpu_pct" => pct, "mode" => mode, "schedulers" => s}) do
    color = cpu_color(pct)
    "#{color}CPU  #{pct}%#{@reset}  [#{mode}] S=#{s}"
  end

  def format_cpu(%{cpu_pct: pct, mode: mode, schedulers: s}) do
    color = cpu_color(pct)
    "#{color}CPU  #{pct}%#{@reset}  [#{mode}] S=#{s}"
  end

  def format_cpu(_), do: "#{@gray}CPU  --  (no data)#{@reset}"

  @doc """
  Format the mathematical health section.
  """
  @spec format_math(map()) :: formatted_line()
  def format_math(%{"score" => score, "disciplines" => disc, "critical_rpns" => rpns}) do
    color = health_color(score)
    "#{color}Math  #{score}%#{@reset}  #{disc} disciplines  #{remark_rpns(rpns)}"
  end

  def format_math(%{score: score, disciplines: disc, critical_rpns: rpns}) do
    color = health_color(score)
    "#{color}Math  #{score}%#{@reset}  #{disc} disciplines  #{remark_rpns(rpns)}"
  end

  def format_math(_), do: "#{@gray}Math  --  (no data)#{@reset}"

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_envelope do
    collector = Indrajaal.Cli.ZenohMetricsCollector

    if Code.ensure_loaded?(collector) and
         function_exported?(collector, :get_envelope, 0) and
         GenServer.whereis(collector) != nil do
      collector.get_envelope()
    else
      %{nodes: %{}, health: %{}, cpu_governor: %{}, math_health: %{}, last_update: nil}
    end
  end

  defp header_line do
    "#{@bold}#{@cyan}── Indrajaal Metrics Envelope ─────────────────#{@reset}"
  end

  defp cpu_line(%{cpu_governor: cg}), do: format_cpu(cg)
  defp cpu_line(_), do: format_cpu(%{})

  defp math_line(%{math_health: mh}), do: format_math(mh)
  defp math_line(_), do: format_math(%{})

  defp nodes_line(%{nodes: nodes}) when map_size(nodes) > 0 do
    node_count = map_size(nodes)
    "#{@cyan}Nodes#{@reset}  #{node_count} reporting"
  end

  defp nodes_line(_), do: "#{@gray}Nodes  0 reporting#{@reset}"

  defp health_summary_line(%{health: health}) when map_size(health) > 0 do
    domain_count = map_size(health)

    critical_count =
      Enum.count(health, fn {_k, v} ->
        Map.get(v, "status") == "critical" or Map.get(v, :status) == :critical
      end)

    if critical_count > 0 do
      "#{@red}Health  #{domain_count} domains  #{critical_count} CRITICAL#{@reset}"
    else
      "#{@green}Health  #{domain_count} domains  all OK#{@reset}"
    end
  end

  defp health_summary_line(_), do: "#{@gray}Health  -- (no domain data)#{@reset}"

  defp footer_line(%{last_update: nil}),
    do: "#{@gray}Updated  never (ZenohMetricsCollector not running)#{@reset}"

  defp footer_line(%{last_update: dt}) do
    ts = Calendar.strftime(dt, "%H:%M:%S")
    "#{@gray}Updated  #{ts} UTC#{@reset}"
  end

  defp footer_line(_), do: "#{@gray}Updated  --#{@reset}"

  defp cpu_color(pct) when is_integer(pct) and pct >= 85, do: @red
  defp cpu_color(pct) when is_integer(pct) and pct >= 70, do: @yellow
  defp cpu_color(_), do: @green

  defp health_color(score) when is_integer(score) and score >= 80, do: @green
  defp health_color(score) when is_integer(score) and score >= 50, do: @yellow
  defp health_color(_), do: @red

  defp remark_rpns(0), do: "#{@green}0 critical RPNs#{@reset}"
  defp remark_rpns(n) when is_integer(n) and n > 0, do: "#{@red}#{n} critical RPNs#{@reset}"
  defp remark_rpns(_), do: ""
end
