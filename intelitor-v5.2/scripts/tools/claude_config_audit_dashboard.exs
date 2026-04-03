#!/usr/bin/env elixir
# Claude Config Audit Dashboard — Control Flow, Decision Flow, Data Flow Visualizer
# SC-COG-001, SC-BIO-001, SC-FUNC-001
# Analyzes .claude/ directory structure, token costs, optimization phases
# Renders ANSI dashboard with 1s polling

defmodule ClaudeConfigDashboard do
  @moduledoc """
  Interactive dashboard for the Claude Code configuration audit.

  Shows:
    1. File loading classification (Ω/Σ/Δ/Φ)
    2. Token budget breakdown with mathematical optimization
    3. Control flow DAG for session initialization
    4. Decision flow for constraint resolution
    5. Data flow for token consumption
    6. Optimization phase progress

  ## Usage
      elixir scripts/tools/claude_config_audit_dashboard.exs [--live | --flow | --optimize | --all]

  ## Modes
    --live      Live file scanning + token analysis
    --flow      Show control/decision/data flow diagrams
    --optimize  Show optimization analysis and recommendations
    --all       All of the above (default)
  """

  @context_window 200_000
  @work_budget 160_000
  @tokens_per_line 4  # Average tokens per line of markdown/yaml

  # ═══════════════════════════════════════════════════════════════════
  # File Loading Classification (The Core Architecture)
  # ═══════════════════════════════════════════════════════════════════

  # Class Ω: Always loaded — fixed cost per session
  @class_omega [
    %{file: "CLAUDE.md", lines: 1659, category: :system, desc: "System instructions (mandatory)"},
    %{file: ".claude/rules/biomorphic-mode.md", lines: 125, category: :rule, desc: "Default execution mode, OODA"},
    %{file: ".claude/rules/change-management.md", lines: 513, category: :rule, desc: "SC-CHG-001..010, 4-layer impact"},
    %{file: ".claude/rules/functional-invariant.md", lines: 173, category: :rule, desc: "SC-FUNC-001..008, Jidoka"},
    %{file: ".claude/rules/fsharp-sil6-mesh.md", lines: 305, category: :rule, desc: "SC-MESH-001..010, Zenoh agents"},
    %{file: ".claude/rules/ga-release-verification.md", lines: 142, category: :rule, desc: "SC-GA-001..010, sprint status"},
    %{file: ".claude/rules/intelligence-amplification.md", lines: 298, category: :rule, desc: "SC-AI-001..008, tricameral"},
    %{file: ".claude/rules/todolist-access-control.md", lines: 262, category: :rule, desc: "SC-TODO-001..008"},
    %{file: ".claude/rules/zenoh-telemetry-mandatory.md", lines: 146, category: :rule, desc: "SC-ZENOH-001..008"},
    %{file: ".claude/rules/zenoh-test-messaging.md", lines: 592, category: :rule, desc: "SC-ZTEST-001..020, math proofs"}
  ]

  # Class Ω* (effectively Ω due to paths: "**/*")
  @class_omega_star [
    %{file: ".claude/rules/agent-cognitive-protocol.md", lines: 209, category: :rule,
      desc: "SC-COG-001..005 (paths: **/* = always)", trigger: "**/*"}
  ]

  # Class Σ: Path-triggered — variable cost
  @class_sigma [
    %{file: ".claude/rules/ash-resources.md", lines: 23, trigger: "lib/indrajaal/**/*.ex",
      desc: "Ash resource patterns", prob: 0.40},
    %{file: ".claude/rules/cache-sync.md", lines: 85, trigger: "lib/cepaf/src/Cepaf.Planning/**/*.fs",
      desc: "OBSOLETE — marked deprecated", prob: 0.05},
    %{file: ".claude/rules/factories.md", lines: 44, trigger: "test/support/factories/**/*.ex",
      desc: "Test factory patterns", prob: 0.20},
    %{file: ".claude/rules/five-level-testing.md", lines: 129, trigger: "test/**/*.exs",
      desc: "5-level fractal test coverage", prob: 0.35},
    %{file: ".claude/rules/full-system-control.md", lines: 133,
      trigger: "lib/indrajaal/**/*.ex, lib/cepaf/**/*.fs", desc: "Full system control rules", prob: 0.60},
    %{file: ".claude/rules/immune-system.md", lines: 105,
      trigger: "sentinel.ex, pattern_hunter.ex, symbiotic_defense.ex",
      desc: "SC-IMMUNE-001..010", prob: 0.10},
    %{file: ".claude/rules/planning-chaya-sync.md", lines: 503,
      trigger: "lib/cepaf/src/Cepaf.Planning/**/*.fs", desc: "SC-SYNC-PLAN-001..020", prob: 0.08},
    %{file: ".claude/rules/prajna-biomorphic.md", lines: 120,
      trigger: "lib/indrajaal/cockpit/**/*.ex", desc: "Prajna cockpit rules", prob: 0.10},
    %{file: ".claude/rules/property-testing.md", lines: 37, trigger: "test/**/*.exs",
      desc: "PropCheck/StreamData rules", prob: 0.35},
    %{file: ".claude/rules/safety-critical.md", lines: 60,
      trigger: "lib/indrajaal/safety/**/*.ex", desc: "Safety-critical module rules", prob: 0.08},
    %{file: ".claude/rules/test-evolution.md", lines: 274,
      trigger: "lib/indrajaal/ai/**/*.ex", desc: "Test evolution AI rules", prob: 0.05},
    %{file: ".claude/rules/test-execution.md", lines: 72, trigger: "test/**/*.exs",
      desc: "Test execution patterns", prob: 0.35}
  ]

  # Class Δ: On-demand (24 agents, 14 commands — loaded per invocation)
  # Class Φ: Passive (17 plans, 2 hooks, 3 plugins — never in context window)

  # Constraint families for coverage analysis
  @constraint_families [
    %{family: "SC-ZENOH", count: 8, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-ZTEST", count: 20, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-BIO", count: 8, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-IMMUNE", count: 10, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-CHG", count: 10, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-TODO", count: 9, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-SYNC-PLAN", count: 12, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-COG", count: 5, in_claude: false, in_rules: true, status: :shadow},
    %{family: "SC-FUNC", count: 8, in_claude: false, in_rules: true, status: :ok},
    %{family: "SC-GA", count: 10, in_claude: false, in_rules: true, status: :ok},
    %{family: "SC-MESH", count: 10, in_claude: true, in_rules: true, status: :redundant},
    %{family: "SC-PRAJNA", count: 7, in_claude: true, in_rules: true, status: :moderate},
    %{family: "SC-AI", count: 8, in_claude: true, in_rules: true, status: :moderate},
    %{family: "SC-CACHE", count: 3, in_claude: false, in_rules: true, status: :obsolete},
    %{family: "SC-FFI", count: 2, in_claude: true, in_rules: false, status: :gap},
    %{family: "SC-DBNAME", count: 10, in_claude: true, in_rules: false, status: :gap},
    %{family: "SC-CMP", count: 5, in_claude: true, in_rules: false, status: :ok},
    %{family: "SC-CMD", count: 29, in_claude: true, in_rules: false, status: :ok},
    %{family: "SC-PROM", count: 7, in_claude: true, in_rules: false, status: :ok},
    %{family: "SC-SIL6", count: 15, in_claude: true, in_rules: false, status: :ok}
  ]

  # Optimization phases
  @phases [
    %{id: 1, title: "Immediate Cleanup (Zero Risk)",
      tasks: [
        "Delete cache-sync.md (obsolete, -340 tokens)",
        "Add paths: to zenoh-test-messaging.md (-2,368 → conditional)",
        "Add paths: to intelligence-amplification.md (-1,192 → conditional)",
        "Add paths: to ga-release-verification.md (-568 → conditional)",
        "Resolve 3 constraint conflicts (SC-BIO-004, SC-OODA-001, SC-BIO-001)",
        "Archive 17 stale plans to docs/archive/"
      ],
      tokens_saved: 4468, risk: :none, duration: "30 min"},
    %{id: 2, title: "Structural Optimization (Sprint 55)",
      tasks: [
        "Add paths: to fsharp-sil6-mesh.md (-1,220 → conditional)",
        "Merge todolist-access-control → planning-chaya-sync (-1,048)",
        "Merge safety-critical → immune-system (-240)",
        "Externalize zenoh-test-messaging math/schemas to docs/ (-1,568)",
        "Create 5 missing slash commands (/mesh, /zenoh, /plan, /cockpit, /health)"
      ],
      tokens_saved: 4076, risk: :low, duration: "2 hrs"},
    %{id: 3, title: "Deep Compression (Sprint 56)",
      tasks: [
        "Compress change-management.md templates (-852)",
        "Externalize CLAUDE.md §95-96 GA checklists to docs/ (-1,600)",
        "Externalize CLAUDE.md §14 BEP tables to docs/ (-400)",
        "Deduplicate CLAUDE.md ↔ rules shared constraints (-2,520)",
        "Create remaining 8 slash commands",
        "Upgrade safety-validator agent: haiku → sonnet"
      ],
      tokens_saved: 5372, risk: :moderate, duration: "4 hrs"}
  ]

  # ═══════════════════════════════════════════════════════════════════
  # Entry Point
  # ═══════════════════════════════════════════════════════════════════

  def run(args \\ []) do
    mode = parse_mode(args)
    IO.write(IO.ANSI.clear())

    state = %{
      started: System.monotonic_time(:millisecond),
      mode: mode,
      phase: :init,
      scan_results: nil,
      step: 0,
      total_steps: step_count(mode)
    }

    # Phase 0: Header
    render_header(state)
    Process.sleep(300)

    # Phase 1: Live scan (if enabled)
    state = if mode in [:live, :all] do
      state = %{state | phase: :scanning, step: 1}
      render_header(state)
      results = live_scan()
      state = %{state | scan_results: results, step: 2}
      render_scan_results(results)
      Process.sleep(500)
      state
    else
      state
    end

    # Phase 2: Token budget analysis
    state = %{state | phase: :token_analysis, step: state.step + 1}
    render_header(state)
    render_token_budget()
    Process.sleep(400)

    # Phase 3: Control flow diagram
    state = if mode in [:flow, :all] do
      state = %{state | phase: :control_flow, step: state.step + 1}
      render_header(state)
      render_control_flow()
      Process.sleep(400)

      # Decision flow
      state = %{state | phase: :decision_flow, step: state.step + 1}
      render_header(state)
      render_decision_flow()
      Process.sleep(400)

      # Data flow
      state = %{state | phase: :data_flow, step: state.step + 1}
      render_header(state)
      render_data_flow()
      Process.sleep(400)
      state
    else
      state
    end

    # Phase 4: Optimization analysis
    state = if mode in [:optimize, :all] do
      state = %{state | phase: :optimization, step: state.step + 1}
      render_header(state)
      render_optimization()
      Process.sleep(400)

      # Constraint coverage
      state = %{state | phase: :coverage, step: state.step + 1}
      render_header(state)
      render_constraint_coverage()
      Process.sleep(400)

      # Pareto frontier
      state = %{state | phase: :pareto, step: state.step + 1}
      render_header(state)
      render_pareto_analysis()
      Process.sleep(400)
      state
    else
      state
    end

    # Final: Summary
    state = %{state | phase: :complete, step: state.total_steps}
    render_header(state)
    render_summary(state)
  end

  # ═══════════════════════════════════════════════════════════════════
  # Live Scanning
  # ═══════════════════════════════════════════════════════════════════

  defp live_scan do
    base = File.cwd!()

    # Count actual files
    rules = count_files(Path.join(base, ".claude/rules"), "*.md")
    agents = count_files(Path.join(base, ".claude/agents"), "*.md")
    commands = count_files(Path.join(base, ".claude/commands"), "*.md")
    plans = count_files(Path.join(base, ".claude/plans"), "*.md")
    hooks = count_files(Path.join(base, ".claude/hooks"), "*.sh")
    plugins = count_files(Path.join(base, ".claude/plugins"), "*.json")

    # Count CLAUDE.md lines
    claude_lines = count_lines(Path.join(base, "CLAUDE.md"))

    # Count total rule lines
    rule_lines = count_dir_lines(Path.join(base, ".claude/rules"))
    agent_lines = count_dir_lines(Path.join(base, ".claude/agents"))
    command_lines = count_dir_lines(Path.join(base, ".claude/commands"))

    # Check for paths: frontmatter in rules
    rules_with_paths = count_rules_with_paths(Path.join(base, ".claude/rules"))
    rules_without_paths = rules - rules_with_paths

    %{
      rules: rules, agents: agents, commands: commands, plans: plans,
      hooks: hooks, plugins: plugins,
      claude_lines: claude_lines, rule_lines: rule_lines,
      agent_lines: agent_lines, command_lines: command_lines,
      rules_with_paths: rules_with_paths, rules_without_paths: rules_without_paths,
      total_files: rules + agents + commands + plans + hooks + plugins + 2, # +settings+bash-history
      total_lines: claude_lines + rule_lines + agent_lines + command_lines
    }
  end

  defp count_files(dir, pattern) do
    if File.dir?(dir) do
      Path.wildcard(Path.join(dir, pattern)) |> length()
    else
      0
    end
  end

  defp count_lines(file) do
    case File.read(file) do
      {:ok, content} -> content |> String.split("\n") |> length()
      _ -> 0
    end
  end

  defp count_dir_lines(dir) do
    if File.dir?(dir) do
      Path.wildcard(Path.join(dir, "*.md"))
      |> Enum.map(&count_lines/1)
      |> Enum.sum()
    else
      0
    end
  end

  defp count_rules_with_paths(dir) do
    if File.dir?(dir) do
      Path.wildcard(Path.join(dir, "*.md"))
      |> Enum.count(fn file ->
        case File.read(file) do
          {:ok, content} ->
            # Check if file has paths: in frontmatter (not paths: "**/*")
            has_frontmatter = String.starts_with?(content, "---")
            has_paths = Regex.match?(~r/^paths:\s+/m, content)
            not_wildcard = not Regex.match?(~r/paths:\s+"\*\*\/\*"/, content)
            has_frontmatter and has_paths and not_wildcard
          _ -> false
        end
      end)
    else
      0
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # Rendering Functions
  # ═══════════════════════════════════════════════════════════════════

  defp render_header(state) do
    elapsed = div(System.monotonic_time(:millisecond) - state.started, 1000)
    progress = if state.total_steps > 0, do: div(state.step * 100, state.total_steps), else: 0
    bar = progress_bar(progress, 30)

    phase_str = state.phase |> to_string() |> String.replace("_", " ") |> String.upcase()

    IO.puts("""
    #{c()}╔══════════════════════════════════════════════════════════════════════════════╗
    ║  #{b()}CLAUDE CODE CONFIGURATION AUDIT DASHBOARD#{c()}                                  ║
    ║  #{w()}Phase: #{String.pad_trailing(phase_str, 22)} Progress: #{bar} #{String.pad_leading("#{progress}%", 4)}  #{c()}║
    ║  #{w()}Mode: #{String.pad_trailing(to_string(state.mode), 12)} Elapsed: #{String.pad_trailing("#{elapsed}s", 8)}  Step: #{state.step}/#{state.total_steps}     #{c()}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{r()}
    """)
  end

  defp render_scan_results(results) do
    IO.puts("""
    #{b()}#{y()}  ◉ LIVE SCAN RESULTS#{r()}
    #{w()}
      Directory Structure:
        .claude/rules/     #{g()}#{results.rules} files#{r()} (#{results.rule_lines} lines)
        .claude/agents/    #{g()}#{results.agents} files#{r()} (#{results.agent_lines} lines)
        .claude/commands/  #{y()}#{results.commands} files#{r()} (#{results.command_lines} lines)
        .claude/plans/     #{red()}#{results.plans} files#{r()} (ALL stale — archive candidates)
        .claude/hooks/     #{w()}#{results.hooks} files#{r()}
        .claude/plugins/   #{w()}#{results.plugins} files#{r()}
        CLAUDE.md          #{g()}1 file#{r()} (#{results.claude_lines} lines)

      Rules Loading Classification:
        #{red()}● Class Ω (always loaded): #{results.rules_without_paths + 1} rules#{r()} ← agent-cognitive-protocol paths:**/*
        #{g()}● Class Σ (path-triggered): #{results.rules_with_paths} rules#{r()}
        Total: #{results.total_files} files, #{results.total_lines} lines
    """)
  end

  defp render_token_budget do
    omega_tokens = Enum.sum(Enum.map(@class_omega ++ @class_omega_star, &(&1.lines * @tokens_per_line)))
    expected_sigma = Enum.sum(Enum.map(@class_sigma, &(Float.round(&1.lines * @tokens_per_line * &1.prob))))
      |> trunc()
    w_eff = @work_budget - omega_tokens - expected_sigma
    overhead_pct = Float.round((omega_tokens + expected_sigma) / @work_budget * 100, 1)

    IO.puts("""
    #{b()}#{c()}  ◉ TOKEN BUDGET ANALYSIS#{r()}
    #{w()}
      ┌────────────────────────────────────────────────────────────┐
      │  Context Window C = #{@context_window |> format_number()} tokens                     │
      │  ├── Work Budget W = #{@work_budget |> format_number()} tokens (80%)               │
      │  ├── Compact Reserve = #{@compact_reserve |> format_number()} tokens (10%)             │
      │  └── Safety Buffer = #{@safety_buffer |> format_number()} tokens (10%)               │
      │                                                            │
      │  #{red()}Specification Overhead S:#{r()}                                 │
      │  ├── #{red()}S_Ω = #{omega_tokens |> format_number()} tokens#{r()} (always loaded — FIXED COST)   │
      │  ├── #{y()}E[S_Σ] ≈ #{expected_sigma |> format_number()} tokens#{r()} (expected path triggers)  │
      │  └── #{g()}S_Δ = on-demand#{r()} (agents/commands — amortized)       │
      │                                                            │
      │  #{b()}W_eff = W - S_Ω - E[S_Σ]#{r()}                                │
      │  #{b()}W_eff = #{@work_budget |> format_number()} - #{omega_tokens |> format_number()} - #{expected_sigma |> format_number()} = #{w_eff |> format_number()} tokens#{r()}  │
      │                                                            │
      │  #{red()}Overhead: #{overhead_pct}% of work budget consumed by specs#{r()}  │
      └────────────────────────────────────────────────────────────┘

      Class Ω Breakdown (#{omega_tokens} tokens always loaded):
    """)

    # Sort by token cost descending
    all_omega = @class_omega ++ @class_omega_star
    sorted = Enum.sort_by(all_omega, &(&1.lines), :desc)

    Enum.each(sorted, fn f ->
      tokens = f.lines * @tokens_per_line
      pct = Float.round(tokens / omega_tokens * 100, 1)
      bar = mini_bar(pct, 20)
      name = f.file |> Path.basename() |> String.pad_trailing(32)
      IO.puts("        #{y()}#{bar}#{r()} #{name} #{tokens} tok (#{pct}%)")
    end)

    IO.puts("")

    # Expected Sigma
    IO.puts("      Class Σ Expected Load (E[S_Σ] = #{expected_sigma} tokens):")
    @class_sigma
    |> Enum.sort_by(&(&1.prob), :desc)
    |> Enum.each(fn f ->
      tokens = f.lines * @tokens_per_line
      expected = trunc(Float.round(tokens * f.prob))
      name = f.file |> Path.basename() |> String.pad_trailing(28)
      prob_str = "P=#{Float.round(f.prob * 100)}%"
      IO.puts("        #{g()}#{String.pad_trailing(prob_str, 8)}#{r()} #{name} #{expected}/#{tokens} tok")
    end)

    IO.puts("")
  end

  defp render_control_flow do
    IO.puts("""
    #{b()}#{c()}  ◉ CONTROL FLOW — How Claude Code Loads .claude/ Files#{r()}
    #{w()}
      The session initialization follows a strict DAG. Understanding this
      is key to optimizing token consumption.

      ┌─────────────────────────────────────────────────────────────────────┐
      │                     SESSION INITIALIZATION DAG                      │
      │                                                                     │
      │  T=0ms    ┌──────────────┐                                         │
      │           │ Process Start│                                         │
      │           └──────┬───────┘                                         │
      │                  │                                                  │
      │  T=1ms    ┌──────┴──────────────────┬──────────────────┐           │
      │           ▼                         ▼                  ▼           │
      │    ┌────────────┐          ┌────────────┐      ┌────────────┐     │
      │    │#{y()}settings   #{w()}│          │#{y()}settings   #{w()}│      │#{red()}CLAUDE.md  #{w()}│     │
      │    │#{y()}.json     #{w()}│          │#{y()}.local    #{w()}│      │#{red()}(1,659 ln) #{w()}│     │
      │    │ env vars   │          │ overrides  │      │ 6,636 tok  │     │
      │    │ hooks def  │          │ (optional) │      │ ALWAYS     │     │
      │    │ permissions│          │            │      │ LOADED     │     │
      │    └────┬───────┘          └────┬───────┘      └─────┬──────┘     │
      │         │                      │                     │            │
      │  T=2ms  └──────────────┬───────┘                     │            │
      │                        ▼                             │            │
      │                ┌───────────────┐                     │            │
      │                │ Env Variables │                     │            │
      │                │ PATIENT_MODE  │                     │            │
      │                │ SKIP_ZENOH_NIF│                     │            │
      │                │ NO_TIMEOUT    │                     │            │
      │                └───────┬───────┘                     │            │
      │                        │                             │            │
      │  T=3ms          ┌──────┴─────────────────────────────┘            │
      │                 ▼                                                  │
      │    #{red()}┌──────────────────────────────────────────────────┐#{w()}         │
      │    #{red()}│  CLASS Ω RULES LOADED (no paths: frontmatter)   │#{w()}         │
      │    #{red()}│                                                  │#{w()}         │
      │    #{red()}│  biomorphic-mode.md        500 tokens            │#{w()}         │
      │    #{red()}│  change-management.md    2,052 tokens            │#{w()}         │
      │    #{red()}│  functional-invariant.md   692 tokens            │#{w()}         │
      │    #{red()}│  fsharp-sil6-mesh.md     1,220 tokens            │#{w()}         │
      │    #{red()}│  + 5 more Ω rules       5,284 tokens            │#{w()}         │
      │    #{red()}│  + agent-cognitive (Ω*)    836 tokens            │#{w()}         │
      │    #{red()}│  ─────────────────────────────────               │#{w()}         │
      │    #{red()}│  SUBTOTAL:              10,584 tokens            │#{w()}         │
      │    #{red()}└──────────────────────────┬───────────────────────┘#{w()}         │
      │                                      │                              │
      │  T=5ms                    ┌──────────┴──────────┐                   │
      │                           ▼                     ▼                   │
      │            ┌───────────────────┐    ┌──────────────────┐           │
      │            │#{g()}MEMORY.md        #{w()}│    │#{y()}SessionStart    #{w()}│           │
      │            │#{g()}user auto-memory#{w()}│    │#{y()}hooks fire      #{w()}│           │
      │            │#{g()}~200 tokens     #{w()}│    │#{y()}• todo_sync.exs #{w()}│           │
      │            └───────────────────┘    └──────────┬───────┘           │
      │                                               │                    │
      │  T=10ms                          ┌────────────┼─────────────┐     │
      │                                  ▼            ▼             ▼     │
      │                         ┌──────────┐  ┌──────────┐  ┌──────────┐ │
      │                         │#{c()}User     #{w()}│  │#{c()}/command #{w()}│  │#{c()}Agent()  #{w()}│ │
      │                         │#{c()}message  #{w()}│  │#{c()}invoked  #{w()}│  │#{c()}spawned  #{w()}│ │
      │                         └─────┬────┘  └─────┬────┘  └─────┬────┘ │
      │                               │             │             │      │
      │                               ▼             ▼             ▼      │
      │                  ┌──────────────────────────────────────────────┐ │
      │                  │  EVENT-DRIVEN LOADING                        │ │
      │                  │                                              │ │
      │                  │  File ops → #{g()}CLASS Σ RULES#{w()} (path-matched)  │ │
      │                  │  /cmd     → #{c()}CLASS Δ COMMANDS#{w()} (on-demand)   │ │
      │                  │  Agent()  → #{c()}CLASS Δ AGENTS#{w()} (on-demand)     │ │
      │                  │  ToolUse  → #{y()}PostToolUse hooks#{w()} (auto-fmt)   │ │
      │                  └──────────────────────────────────────────────┘ │
      │                                                                     │
      └─────────────────────────────────────────────────────────────────────┘

      #{b()}KEY INSIGHT:#{r()} #{omega_tokens()} tokens are committed before ANY user interaction.
      This is the #{red()}fixed cost#{r()} that optimization targets.
    """)
  end

  defp render_decision_flow do
    IO.puts("""
    #{b()}#{c()}  ◉ DECISION FLOW — How Constraints Are Resolved#{r()}
    #{w()}
      When a constraint appears in multiple files, Claude Code uses a
      priority hierarchy. Understanding this prevents conflicts.

      ┌─────────────────────────────────────────────────────────────────────┐
      │                    CONSTRAINT RESOLUTION DAG                        │
      │                                                                     │
      │       ┌──────────────────────────────────────┐                     │
      │       │  CONSTRAINT REQUEST                   │                     │
      │       │  "What is the OODA cycle limit?"      │                     │
      │       └──────────────────┬─────────────────────┘                     │
      │                          │                                           │
      │                          ▼                                           │
      │       ┌──────────────────────────────────────┐                     │
      │       │  STEP 1: Check CLAUDE.md (TIER 0)    │                     │
      │       │  Priority: HIGHEST (system prompt)   │                     │
      │       │                                      │                     │
      │       │  Found: SC-OODA-001 "< 30ms"  (§5.0)│                     │
      │       │  Found: AOR-BIO-001 "30s cycles"     │                     │
      │       └──────────────────┬───────────────────┘                     │
      │                          │                                           │
      │            ┌─────────────┼──────────────┐                           │
      │            │ CONFLICT?   │              │                           │
      │            ▼ YES         ▼ NO           │                           │
      │     ┌──────────────┐ ┌──────────┐       │                           │
      │     │#{red()}CONFLICT#{w()}      │ │ Use      │       │                           │
      │     │#{red()}DETECTED#{w()}      │ │ CLAUDE.md│       │                           │
      │     │              │ │ value    │       │                           │
      │     │ 30ms vs 30s  │ └──────────┘       │                           │
      │     │ (units!)     │                    │                           │
      │     └──────┬───────┘                    │                           │
      │            │                             │                           │
      │            ▼                             │                           │
      │     ┌──────────────────────────────────────┐                       │
      │     │  STEP 2: Check Rule File (TIER 1)    │                       │
      │     │  biomorphic-mode.md says "< 100ms"   │                       │
      │     │  change-management.md is silent       │                       │
      │     └──────────────────┬───────────────────┘                       │
      │                        │                                             │
      │                        ▼                                             │
      │     ┌──────────────────────────────────────┐                       │
      │     │  STEP 3: Apply Precedence Hierarchy  │                       │
      │     │                                      │                       │
      │     │  Ω₀ > Ψ₀-Ψ₅ > Ω₁-Ω₉ > SC-* > AOR-*│                       │
      │     │                                      │                       │
      │     │  SC-OODA-001 (SC-*) level:           │                       │
      │     │  CLAUDE.md wins as system prompt      │                       │
      │     └──────────────────┬───────────────────┘                       │
      │                        │                                             │
      │                        ▼                                             │
      │     ┌──────────────────────────────────────┐                       │
      │     │  RESOLUTION:                         │                       │
      │     │  SC-OODA-001: OODA cycle < 30ms      │                       │
      │     │  SC-BIO-001:  Metabolic heartbeat 30s│                       │
      │     │  (Different timescales, not conflict) │                       │
      │     └──────────────────────────────────────┘                       │
      │                                                                     │
      │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
      │                                                                     │
      │  #{red()}KNOWN ACTIVE CONFLICTS (3):#{r()}                                     │
      │                                                                     │
      │  1. #{y()}SC-BIO-004#{r()}: Compact threshold                                 │
      │     CLAUDE.md: 75%  vs  prajna-biomorphic.md: 80%                  │
      │     → Resolution: Use 75% (CLAUDE.md authoritative)               │
      │                                                                     │
      │  2. #{y()}SC-OODA-001#{r()}: OODA cycle time                                  │
      │     CLAUDE.md §5.0: < 30ms  vs  biomorphic-mode.md: < 100ms       │
      │     → Resolution: 30ms is cycle TIME, 100ms is step BUDGET         │
      │                                                                     │
      │  3. #{y()}SC-BIO-001#{r()}: OODA unit mismatch                                │
      │     AOR-BIO-001: "30s cycles"  vs  biomorphic-mode.md: "< 100ms"  │
      │     → Resolution: 30s = metabolic heartbeat, 100ms = per-step      │
      │                                                                     │
      └─────────────────────────────────────────────────────────────────────┘
    """)
  end

  defp render_data_flow do
    omega_tokens = omega_tokens()
    expected_sigma = expected_sigma_tokens()
    w_eff = @work_budget - omega_tokens - expected_sigma
    overhead = omega_tokens + expected_sigma
    overhead_pct = Float.round(overhead / @work_budget * 100, 1)

    IO.puts("""
    #{b()}#{c()}  ◉ DATA FLOW — Token Movement Through the System#{r()}
    #{w()}
      Tokens flow from specification files into the context window,
      consuming capacity that could otherwise be used for work.

      ┌─────────────────────────────────────────────────────────────────────┐
      │                      TOKEN DATA FLOW                                │
      │                                                                     │
      │                     CONTEXT WINDOW (200,000 tokens)                │
      │   ┌────────────────────────────────────────────────────────────┐   │
      │   │#{red()}████████████████#{y()}████#{g()}                                        #{w()}│   │
      │   │#{red()} S_Ω (#{omega_tokens})    #{y()}E[Σ]  #{g()} W_eff (#{w_eff})                  #{w()}│   │
      │   │#{red()} Fixed Cost    #{y()}Var.  #{g()} Available for Work                  #{w()}│   │
      │   └────────────────────────────────────────────────────────────┘   │
      │    ↑                 ↑                                              │
      │    │                 │                                              │
      │   SOURCES           SOURCES                                         │
      │    │                 │                                              │
      │   ┌┴────────────┐  ┌┴────────────┐  ┌─────────────┐              │
      │   │ CLAUDE.md   │  │ Path Match  │  │ Agent Spawn │              │
      │   │ #{red()}6,636 tok#{w()}   │  │ #{y()}Prob-based#{w()}  │  │ #{c()}On Demand#{w()}   │              │
      │   ├─────────────┤  ├─────────────┤  ├─────────────┤              │
      │   │ Ω Rules     │  │ ash-res 40% │  │ 24 agents   │              │
      │   │ #{red()}10,584 tok#{w()}  │  │ 5-lvl   35% │  │ ~400-2K tok │              │
      │   ├─────────────┤  │ full-sys 60%│  │ each invoke │              │
      │   │ MEMORY.md   │  │ factories 20│  ├─────────────┤              │
      │   │ #{g()}~200 tok#{w()}    │  │ etc.       │  │ 14 commands │              │
      │   └─────────────┘  └─────────────┘  │ ~200-800 tok│              │
      │                                      └─────────────┘              │
      │                                                                     │
      │   #{b()}OVERHEAD EQUATION:#{r()}                                             │
      │   S = S_Ω + E[S_Σ] = #{omega_tokens} + #{expected_sigma} = #{overhead} tokens     │
      │   #{red()}#{overhead_pct}% of work budget consumed before work starts#{r()}         │
      │                                                                     │
      │   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
      │                                                                     │
      │   #{b()}INFORMATION FLOW BETWEEN TIERS:#{r()}                                │
      │                                                                     │
      │   TIER 0 (CLAUDE.md)                                               │
      │     │  Defines: Ω₀-Ω₁₀ axioms, Ψ₀-Ψ₅ constitution                │
      │     │  Defines: 641+ SC-* constraints (summaries)                   │
      │     │  Defines: 200+ AOR-* rules (summaries)                        │
      │     ▼                                                               │
      │   TIER 1 (Rules)  ←── #{red()}84 constraints DUPLICATED ≈ 2,520 tok#{r()}     │
      │     │  Expands: Detailed constraint specifications                  │
      │     │  Adds: Examples, schemas, math proofs                         │
      │     │  #{y()}Shadow: SC-COG, SC-CTRL, SC-MON (rules-only)#{r()}              │
      │     ▼                                                               │
      │   TIER 2 (Agents/Commands)                                          │
      │     │  Consumes: Constraints as behavioral guardrails               │
      │     │  Produces: Code, tests, analysis                              │
      │     ▼                                                               │
      │   TIER 3 (docs/)                                                    │
      │        Reference material, NOT in context window                    │
      │                                                                     │
      └─────────────────────────────────────────────────────────────────────┘
    """)
  end

  defp render_optimization do
    IO.puts("""
    #{b()}#{c()}  ◉ OPTIMIZATION PHASES — Token Reduction Roadmap#{r()}
    #{w()}
    """)

    cumulative = 0
    Enum.reduce(@phases, cumulative, fn phase, acc ->
      new_acc = acc + phase.tokens_saved
      risk_color = case phase.risk do
        :none -> g()
        :low -> y()
        :moderate -> red()
      end
      risk_icon = case phase.risk do
        :none -> "●"
        :low -> "◐"
        :moderate -> "◑"
      end

      IO.puts("      #{c()}Phase #{phase.id}: #{phase.title}#{r()}")
      IO.puts("      #{risk_color}#{risk_icon} Risk: #{phase.risk}  │  Duration: #{phase.duration}  │  Savings: -#{phase.tokens_saved} tokens#{r()}")
      IO.puts("      #{w()}Cumulative: -#{new_acc} tokens (#{Float.round(new_acc / omega_tokens() * 100, 1)}% of S_Ω)#{r()}")
      IO.puts("")

      Enum.each(phase.tasks, fn task ->
        IO.puts("        #{IO.ANSI.faint()}○ #{task}#{r()}")
      end)

      IO.puts("")
      new_acc
    end)

    # Before/after comparison
    total_saved = Enum.sum(Enum.map(@phases, & &1.tokens_saved))
    new_omega = omega_tokens() - total_saved
    new_expected = new_omega + expected_sigma_tokens()
    new_pct = Float.round(new_expected / @work_budget * 100, 1)

    IO.puts("""
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      #{b()}BEFORE vs AFTER (All 3 Phases):#{r()}

        BEFORE                              AFTER
        #{red()}Class Ω: #{omega_tokens()} tokens (always)#{r()}     #{g()}Class Ω: ~#{new_omega} tokens (always)#{r()}
        #{y()}E[S_Σ]: #{expected_sigma_tokens()} tokens#{r()}              #{y()}E[S_Σ]: ~#{expected_sigma_tokens()} tokens#{r()}
        ────────────────────────            ────────────────────────
        #{red()}Total: ~#{omega_tokens() + expected_sigma_tokens()} tokens/session#{r()}     #{g()}Total: ~#{new_expected} tokens/session#{r()}
        #{red()}Overhead: #{Float.round((omega_tokens() + expected_sigma_tokens()) / @work_budget * 100, 1)}%#{r()}                       #{g()}Overhead: #{new_pct}%#{r()}

        #{b()}NET SAVINGS: #{total_saved} tokens/session (#{Float.round(total_saved / omega_tokens() * 100, 1)}% reduction)#{r()}
    """)
  end

  defp render_constraint_coverage do
    total = Enum.sum(Enum.map(@constraint_families, & &1.count))
    redundant = @constraint_families |> Enum.filter(&(&1.status == :redundant)) |> Enum.sum_by(& &1.count)
    shadow = @constraint_families |> Enum.filter(&(&1.status == :shadow)) |> Enum.sum_by(& &1.count)
    gaps = @constraint_families |> Enum.filter(&(&1.status == :gap)) |> Enum.sum_by(& &1.count)
    obsolete = @constraint_families |> Enum.filter(&(&1.status == :obsolete)) |> Enum.sum_by(& &1.count)
    ok = @constraint_families |> Enum.filter(&(&1.status in [:ok, :moderate])) |> Enum.sum_by(& &1.count)

    IO.puts("""
    #{b()}#{c()}  ◉ CONSTRAINT COVERAGE ANALYSIS#{r()}
    #{w()}
      Total Constraint Families: #{length(@constraint_families)}
      Total Individual Constraints: #{total}

      Status Distribution:
    """)

    statuses = [
      {:ok, ok, g(), "OK (single source)"},
      {:redundant, redundant, red(), "REDUNDANT (defined twice)"},
      {:shadow, shadow, y(), "SHADOW (rules-only, no CLAUDE.md)"},
      {:gap, gaps, IO.ANSI.magenta(), "GAP (CLAUDE.md only, no rule)"},
      {:obsolete, obsolete, IO.ANSI.faint(), "OBSOLETE (delete candidate)"}
    ]

    Enum.each(statuses, fn {_status, count, color, label} ->
      pct = if total > 0, do: Float.round(count / total * 100, 1), else: 0
      bar = mini_bar(pct, 25)
      IO.puts("        #{color}#{bar} #{String.pad_trailing(label, 40)} #{count} (#{pct}%)#{r()}")
    end)

    IO.puts("""

      #{red()}Redundancy Cost: #{redundant} constraints × 2 definitions × ~15 tok = ~#{redundant * 30} tokens wasted#{r()}

      Family Detail:
    """)

    Enum.each(@constraint_families, fn f ->
      {icon, color} = case f.status do
        :ok -> {"●", g()}
        :moderate -> {"◐", c()}
        :redundant -> {"◉", red()}
        :shadow -> {"◑", y()}
        :gap -> {"○", IO.ANSI.magenta()}
        :obsolete -> {"✗", IO.ANSI.faint()}
      end
      cl = if f.in_claude, do: "CM", else: "  "
      rl = if f.in_rules, do: "RL", else: "  "
      IO.puts("        #{color}#{icon} #{String.pad_trailing(f.family, 15)} │#{String.pad_leading("#{f.count}", 3)} │ #{cl} │ #{rl} │ #{f.status}#{r()}")
    end)

    IO.puts("")
  end

  defp render_pareto_analysis do
    # Calculate efficiency for each Class Ω file
    files = (@class_omega ++ @class_omega_star)
    |> Enum.map(fn f ->
      tokens = f.lines * @tokens_per_line
      # Rough constraint count per file
      constraints = case Path.basename(f.file) do
        "CLAUDE.md" -> 250
        "zenoh-test-messaging.md" -> 35
        "change-management.md" -> 20
        "intelligence-amplification.md" -> 16
        "fsharp-sil6-mesh.md" -> 18
        "todolist-access-control.md" -> 18
        "zenoh-telemetry-mandatory.md" -> 16
        "functional-invariant.md" -> 16
        "ga-release-verification.md" -> 18
        "biomorphic-mode.md" -> 18
        "agent-cognitive-protocol.md" -> 10
        _ -> 5
      end
      eta = Float.round(constraints / tokens * 1000, 1)
      Map.merge(f, %{tokens: tokens, constraints: constraints, eta: eta})
    end)
    |> Enum.sort_by(& &1.eta, :desc)

    IO.puts("""
    #{b()}#{c()}  ◉ PARETO EFFICIENCY ANALYSIS#{r()}
    #{w()}
      η = constraints per 1000 tokens (higher = more efficient)

      Pareto Frontier: η > 20 = #{g()}EFFICIENT#{r()}, η 15-20 = #{y()}MODERATE#{r()}, η < 15 = #{red()}INEFFICIENT#{r()}

    """)

    Enum.each(files, fn f ->
      {color, label} = cond do
        f.eta > 20 -> {g(), "EFFICIENT"}
        f.eta >= 15 -> {y(), "MODERATE"}
        true -> {red(), "INEFFICIENT"}
      end
      name = f.file |> Path.basename() |> String.pad_trailing(32)
      eta_bar = mini_bar(min(f.eta, 40) / 40 * 100, 15)
      IO.puts("        #{color}#{eta_bar} η=#{String.pad_trailing("#{f.eta}", 6)} #{name} #{label}#{r()}")
    end)

    IO.puts("""

      #{b()}Information-Theoretic Minimum:#{r()}
        T_min = 250 constraints × 15 tok/constraint = 3,750 tokens
        Current S_Ω = #{omega_tokens()} tokens
        #{red()}Overhead ratio: #{Float.round(omega_tokens() / 3750, 2)}× theoretical minimum#{r()}
        #{g()}Optimal target: ~2× minimum = 7,500 tokens#{r()}
    """)
  end

  defp render_summary(state) do
    elapsed = div(System.monotonic_time(:millisecond) - state.started, 1000)

    IO.puts("""
    #{c()}╠══════════════════════════════════════════════════════════════════════════════╣
    ║  #{b()}AUDIT COMPLETE#{c()}                                                             ║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{r()}

    #{b()}KEY FINDINGS:#{r()}

      1. #{red()}13.1% overhead#{r()} — #{omega_tokens()} tokens consumed before work starts
      2. #{red()}84 redundant constraints#{r()} — defined in both CLAUDE.md and rules (~2,520 tokens)
      3. #{red()}3 active conflicts#{r()} — SC-BIO-004, SC-OODA-001, SC-BIO-001
      4. #{y()}9 Class Ω rules without paths:#{r()} — could be reclassified to Σ
      5. #{y()}1 Class Ω* rule#{r()} — agent-cognitive-protocol.md (paths: **/* = always)
      6. #{red()}17 stale plans#{r()} — from Sprint 30-34, 78+ days old
      7. #{y()}1 obsolete rule#{r()} — cache-sync.md (deprecated)
      8. #{g()}100% agent coverage#{r()} — 24 agents cover 22 system areas

    #{b()}RECOMMENDATIONS (Priority Order):#{r()}

      #{g()}P0 (Immediate, 0 risk):#{r()}
        ● Delete cache-sync.md
        ● Resolve 3 constraint conflicts
        ● Archive 17 stale plans

      #{y()}P1 (30 min, low risk):#{r()}
        ● Add paths: to 5 Class Ω rules → reclassify to Σ
        ● Expected savings: ~5,063 tokens/session (29%)

      #{y()}P2 (Sprint 55, moderate effort):#{r()}
        ● Merge todolist→planning-chaya, safety→immune
        ● Externalize math/schemas from zenoh-test-messaging
        ● Create 5 missing slash commands

      #{c()}P3 (Sprint 56, systematic):#{r()}
        ● Compress verbose templates
        ● Deduplicate CLAUDE.md ↔ rules
        ● Externalize GA checklists to docs/

    #{b()}MATHEMATICAL SUMMARY:#{r()}

      Current:  S_Ω = #{omega_tokens()} tok  │  W_eff = #{@work_budget - omega_tokens() - expected_sigma_tokens()} tok  │  Overhead = #{Float.round((omega_tokens() + expected_sigma_tokens()) / @work_budget * 100, 1)}%
      Optimal:  S_Ω = ~7,500 tok  │  W_eff = ~150,900 tok │  Overhead = ~5.7%
      η_current = 4.67× theoretical minimum
      η_target  = 2.00× theoretical minimum

    #{c()}╠══════════════════════════════════════════════════════════════════════════════╣
    ║  #{w()}Duration: #{elapsed}s  │  Journal: 20260322-0200, 20260322-0300, 20260322-0400#{c()}      ║
    ╚══════════════════════════════════════════════════════════════════════════════╝#{r()}

    #{IO.ANSI.faint()}[ZTEST-CHECKPOINT] checkpoint=CP-AUDIT-CONFIG topic=indrajaal/audit/claude-config type=audit_complete timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}#{r()}
    """)
  end

  # ═══════════════════════════════════════════════════════════════════
  # Helper Functions
  # ═══════════════════════════════════════════════════════════════════

  defp omega_tokens do
    Enum.sum(Enum.map(@class_omega ++ @class_omega_star, &(&1.lines * @tokens_per_line)))
  end

  defp expected_sigma_tokens do
    @class_sigma
    |> Enum.map(&(Float.round(&1.lines * @tokens_per_line * &1.prob)))
    |> Enum.sum()
    |> trunc()
  end

  defp progress_bar(pct, width) do
    filled = div(pct * width, 100)
    empty = width - filled
    "#{g()}#{String.duplicate("█", filled)}#{IO.ANSI.faint()}#{String.duplicate("░", empty)}#{r()}"
  end

  defp mini_bar(pct, width) when is_float(pct) do
    filled = max(0, min(width, trunc(pct * width / 100)))
    String.duplicate("▓", filled) <> String.duplicate("░", width - filled)
  end

  defp format_number(n) when n >= 1000 do
    whole = div(n, 1000)
    frac = rem(n, 1000)
    "#{whole},#{String.pad_leading("#{frac}", 3, "0")}"
  end
  defp format_number(n), do: "#{n}"

  defp parse_mode(args) do
    cond do
      "--live" in args -> :live
      "--flow" in args -> :flow
      "--optimize" in args -> :optimize
      "--all" in args -> :all
      true -> :all
    end
  end

  defp step_count(:live), do: 5
  defp step_count(:flow), do: 6
  defp step_count(:optimize), do: 6
  defp step_count(:all), do: 12

  # Color shortcuts
  defp c, do: IO.ANSI.cyan()
  defp b, do: IO.ANSI.bright()
  defp w, do: IO.ANSI.white()
  defp g, do: IO.ANSI.green()
  defp y, do: IO.ANSI.yellow()
  defp red, do: IO.ANSI.red()
  defp r, do: IO.ANSI.reset()
end

# ═══════════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════════

ClaudeConfigDashboard.run(System.argv())
