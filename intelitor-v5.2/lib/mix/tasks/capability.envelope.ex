defmodule Mix.Tasks.Capability.Envelope do
  @moduledoc """
  Generates capability envelope dashboard and reports.

  ## Usage

      mix capability.envelope              # Interactive dashboard
      mix capability.envelope --json       # JSON output
      mix capability.envelope --markdown   # Markdown report
      mix capability.envelope --journal    # Save to journal

  ## STAMP Compliance
  - SC-DOC-001: Comprehensive documentation
  - SC-OBS-069: Dual logging
  """

  use Mix.Task

  @shortdoc "Generate capability envelope dashboard"

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:jason)

    metrics = collect_metrics()

    cond do
      "--json" in args ->
        output_json(metrics)

      "--markdown" in args ->
        output_markdown(metrics)

      "--journal" in args ->
        save_to_journal(metrics)
        output_summary(metrics)

      true ->
        output_dashboard(metrics)
    end
  end

  defp collect_metrics do
    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Mix.Project.config()[:version] || "21.1.0",
      modules: count_modules(),
      tests: count_tests(),
      stamp: count_stamp_refs(),
      prajna: assess_prajna(),
      evolution: %{
        foundation: 95,
        safety: 72,
        prajna: 78,
        biomorphic: 58,
        distributed: 65,
        observability: 85
      },
      sil: %{sil1: 100, sil2: 95, sil3: 60, sil4: 25},
      sprint: %{
        number: 30,
        name: "Prajna Biomorphic Integration",
        overall: 80,
        tasks: [
          %{id: "30.1", name: "Version Alignment", status: :complete, progress: 100},
          %{id: "30.2", name: "Guardian Integration", status: :complete, progress: 100},
          %{id: "30.3", name: "Founder Directive", status: :in_progress, progress: 67},
          %{id: "30.4", name: "Immutable Register", status: :in_progress, progress: 75},
          %{id: "30.5", name: "Sentinel Bridge", status: :complete, progress: 100},
          %{id: "30.6", name: "PROMETHEUS", status: :in_progress, progress: 83},
          %{id: "30.7", name: "Mara Module", status: :blocked, progress: 50},
          %{id: "30.8", name: "Antibody Module", status: :in_progress, progress: 75},
          %{id: "30.9", name: "Constitutional", status: :complete, progress: 100},
          %{id: "30.10", name: "Domain Integrations", status: :in_progress, progress: 50}
        ]
      }
    }
    |> calculate_eri()
  end

  defp count_modules do
    path = Path.join([File.cwd!(), "lib", "indrajaal"])
    count = Path.wildcard(Path.join([path, "**", "*.ex"])) |> length()
    %{total: count, target: 1000, percentage: round(count / 1000 * 100)}
  end

  defp count_tests do
    path = Path.join([File.cwd!(), "test"])
    count = Path.wildcard(Path.join([path, "**", "*_test.exs"])) |> length()
    %{total: count, target: 900, percentage: round(count / 900 * 100)}
  end

  defp count_stamp_refs do
    {output, _} =
      System.cmd("grep", ["-roh", "SC-[A-Z]*", "lib/", "--include=*.ex"],
        stderr_to_stdout: true,
        cd: File.cwd!()
      )

    refs = output |> String.split("\n", trim: true)
    %{total: length(refs), unique: refs |> Enum.uniq() |> length(), target: 500}
  end

  defp assess_prajna do
    prajna_path = Path.join([File.cwd!(), "lib", "indrajaal", "cockpit", "prajna"])
    test_path = Path.join([File.cwd!(), "test", "indrajaal", "cockpit", "prajna"])

    modules =
      Path.wildcard(Path.join(prajna_path, "*.ex"))
      |> Enum.map(&Path.basename(&1, ".ex"))

    tested =
      modules
      |> Enum.count(fn mod ->
        File.exists?(Path.join(test_path, "#{mod}_test.exs"))
      end)

    %{
      total: length(modules),
      tested: tested,
      percentage: round(tested / max(length(modules), 1) * 100)
    }
  end

  defp calculate_eri(metrics) do
    weights = %{
      modules: 0.15,
      tests: 0.20,
      stamp: 0.15,
      prajna: 0.15,
      biomorphic: 0.15,
      sil: 0.20
    }

    scores = %{
      modules: metrics.modules.percentage,
      tests: metrics.tests.percentage,
      stamp: min(metrics.stamp.total / metrics.stamp.target * 100, 100),
      prajna: metrics.prajna.percentage,
      biomorphic: metrics.evolution.biomorphic,
      sil: (metrics.sil.sil1 + metrics.sil.sil2 + metrics.sil.sil3 + metrics.sil.sil4) / 4
    }

    eri =
      Enum.reduce(weights, 0.0, fn {key, weight}, acc ->
        acc + Map.get(scores, key, 0) * weight
      end)
      |> round()

    Map.put(metrics, :eri, eri)
  end

  defp output_dashboard(metrics) do
    Mix.shell().info("""

    #{IO.ANSI.cyan()}╔══════════════════════════════════════════════════════════════════════════════╗#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.bright()}INDRAJAAL CAPABILITY ENVELOPE DASHBOARD#{IO.ANSI.reset()}                                    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} Version: #{metrics.version} | #{metrics.timestamp |> String.slice(0..18)}                            #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.yellow()}GLOBAL METRICS#{IO.ANSI.reset()}                                                                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Modules:     #{format_metric(metrics.modules.total, metrics.modules.target)}                                     #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Tests:       #{format_metric(metrics.tests.total, metrics.tests.target)}                                      #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   STAMP Refs:  #{format_metric(metrics.stamp.total, metrics.stamp.target)}                                     #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Prajna:      #{format_metric(metrics.prajna.tested, metrics.prajna.total)} modules tested                        #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.yellow()}EVOLUTION VECTORS#{IO.ANSI.reset()}                                                             #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Foundation:    #{progress_bar(metrics.evolution.foundation)} #{metrics.evolution.foundation}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Safety:        #{progress_bar(metrics.evolution.safety)} #{metrics.evolution.safety}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Prajna:        #{progress_bar(metrics.evolution.prajna)} #{metrics.evolution.prajna}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Biomorphic:    #{progress_bar(metrics.evolution.biomorphic)} #{metrics.evolution.biomorphic}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Distributed:   #{progress_bar(metrics.evolution.distributed)} #{metrics.evolution.distributed}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   Observability: #{progress_bar(metrics.evolution.observability)} #{metrics.evolution.observability}%                #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.yellow()}SIL CERTIFICATION#{IO.ANSI.reset()}                                                             #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   SIL-1: #{progress_bar(metrics.sil.sil1)} #{metrics.sil.sil1}%  SIL-2: #{progress_bar(metrics.sil.sil2)} #{metrics.sil.sil2}%     #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   SIL-3: #{progress_bar(metrics.sil.sil3)} #{metrics.sil.sil3}%  SIL-4: #{progress_bar(metrics.sil.sil4)} #{metrics.sil.sil4}%     #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.yellow()}SPRINT #{metrics.sprint.number}: #{metrics.sprint.name}#{IO.ANSI.reset()}                            #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{format_sprint_tasks(metrics.sprint.tasks)}
    #{IO.ANSI.cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}║#{IO.ANSI.reset()} #{IO.ANSI.bright()}EVOLUTIONARY READINESS INDEX: #{IO.ANSI.green()}#{metrics.eri}%#{IO.ANSI.reset()}                                     #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}╚══════════════════════════════════════════════════════════════════════════════╝#{IO.ANSI.reset()}
    """)
  end

  defp format_metric(current, target) do
    pct = round(current / target * 100)
    color = if pct >= 100, do: IO.ANSI.green(), else: IO.ANSI.yellow()
    "#{color}#{current}#{IO.ANSI.reset()}/#{target} (#{pct}%)"
  end

  defp progress_bar(pct) do
    filled = round(pct / 10)
    empty = 10 - filled

    color =
      cond do
        pct >= 80 -> IO.ANSI.green()
        pct >= 50 -> IO.ANSI.yellow()
        true -> IO.ANSI.red()
      end

    "#{color}#{String.duplicate("█", filled)}#{String.duplicate("░", empty)}#{IO.ANSI.reset()}"
  end

  defp format_sprint_tasks(tasks) do
    Enum.map_join(tasks, "\n", fn task ->
      icon =
        case task.status do
          :complete -> "#{IO.ANSI.green()}✓#{IO.ANSI.reset()}"
          :in_progress -> "#{IO.ANSI.yellow()}◐#{IO.ANSI.reset()}"
          :blocked -> "#{IO.ANSI.red()}✗#{IO.ANSI.reset()}"
          _ -> "○"
        end

      "#{IO.ANSI.cyan()}║#{IO.ANSI.reset()}   #{icon} #{task.id} #{String.pad_trailing(task.name, 22)} #{String.pad_leading("#{task.progress}%", 4)}                            #{IO.ANSI.cyan()}║#{IO.ANSI.reset()}"
    end)
  end

  defp output_json(metrics) do
    IO.puts(Jason.encode!(metrics, pretty: true))
  end

  defp output_markdown(metrics) do
    IO.puts("""
    # Capability Envelope Report
    **Generated**: #{metrics.timestamp}
    **Version**: #{metrics.version}
    **ERI**: #{metrics.eri}%

    ## Global Metrics
    | Metric | Current | Target | % |
    |--------|---------|--------|---|
    | Modules | #{metrics.modules.total} | #{metrics.modules.target} | #{metrics.modules.percentage}% |
    | Tests | #{metrics.tests.total} | #{metrics.tests.target} | #{metrics.tests.percentage}% |
    | STAMP | #{metrics.stamp.total} | #{metrics.stamp.target} | #{round(metrics.stamp.total / metrics.stamp.target * 100)}% |

    ## Evolution Vectors
    | Dimension | Progress |
    |-----------|----------|
    | Foundation | #{metrics.evolution.foundation}% |
    | Safety | #{metrics.evolution.safety}% |
    | Prajna | #{metrics.evolution.prajna}% |
    | Biomorphic | #{metrics.evolution.biomorphic}% |
    | Distributed | #{metrics.evolution.distributed}% |
    | Observability | #{metrics.evolution.observability}% |

    ## SIL Progress
    | Level | Progress |
    |-------|----------|
    | SIL-1 | #{metrics.sil.sil1}% |
    | SIL-2 | #{metrics.sil.sil2}% |
    | SIL-3 | #{metrics.sil.sil3}% |
    | SIL-4 | #{metrics.sil.sil4}% |
    """)
  end

  defp save_to_journal(metrics) do
    date = Date.utc_today() |> to_string() |> String.replace("-", "")
    time = Time.utc_now() |> Time.to_string() |> String.slice(0..3) |> String.replace(":", "")
    filename = "#{date}-#{time}-capability-envelope-sprint#{metrics.sprint.number}.md"

    journal_dir = Path.join([File.cwd!(), "journal", "2026-01"])
    File.mkdir_p!(journal_dir)

    path = Path.join(journal_dir, filename)

    content = """
    # Capability Envelope Report - Sprint #{metrics.sprint.number}
    **Generated**: #{metrics.timestamp}
    **Version**: #{metrics.version}
    **ERI**: #{metrics.eri}%

    ## Summary
    - Modules: #{metrics.modules.total}/#{metrics.modules.target} (#{metrics.modules.percentage}%)
    - Tests: #{metrics.tests.total}/#{metrics.tests.target} (#{metrics.tests.percentage}%)
    - STAMP: #{metrics.stamp.total} references

    ## Evolution Vectors
    - Foundation: #{metrics.evolution.foundation}%
    - Safety: #{metrics.evolution.safety}%
    - Prajna: #{metrics.evolution.prajna}%
    - Biomorphic: #{metrics.evolution.biomorphic}%
    - Distributed: #{metrics.evolution.distributed}%
    - Observability: #{metrics.evolution.observability}%

    ## SIL Progress
    - SIL-1: #{metrics.sil.sil1}%
    - SIL-2: #{metrics.sil.sil2}%
    - SIL-3: #{metrics.sil.sil3}%
    - SIL-4: #{metrics.sil.sil4}%
    """

    File.write!(path, content)
    Mix.shell().info("📝 Saved to #{path}")
  end

  defp output_summary(metrics) do
    Mix.shell().info("""

    #{IO.ANSI.green()}✓ Capability Envelope Summary#{IO.ANSI.reset()}
      Version: #{metrics.version}
      ERI: #{metrics.eri}%
      Modules: #{metrics.modules.total}
      Tests: #{metrics.tests.total}
    """)
  end
end
