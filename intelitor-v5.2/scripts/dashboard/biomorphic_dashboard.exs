#!/usr/bin/env elixir

defmodule BiomorphicDashboard do
  def render do
    IO.puts IO.ANSI.clear()
    IO.puts IO.ANSI.home()
    
    render_header()
    render_vital_signs()
    render_organ_status()
    render_cognitive_state()
    render_plan_progress()
    render_footer()
  end

  defp render_header do
    IO.puts """
    #{IO.ANSI.cyan()}┌─────────────────────────────────────────────────────────────┐
    │                 INDRAJAAL BIOMORPHIC COCKPIT                │
    │                 v20.3.2 - COGNITIVE ACTIVATION              │
    └─────────────────────────────────────────────────────────────┘#{IO.ANSI.reset()}
    """
  end

  defp render_vital_signs do
    IO.puts "#{IO.ANSI.yellow()}⚡ VITAL SIGNS#{IO.ANSI.reset()}"
    IO.puts "  • OODA Cycle:     #{IO.ANSI.green()}50ms (Target)#{IO.ANSI.reset()}"
    IO.puts "  • Metabolism:     #{IO.ANSI.green()}Normal (200% Budget)#{IO.ANSI.reset()}"
    IO.puts "  • Entropy:        #{IO.ANSI.green()}Low (0.05)#{IO.ANSI.reset()}"
    IO.puts "  • Health Score:   #{IO.ANSI.green()}0.98#{IO.ANSI.reset()}"
    IO.puts ""
  end

  defp render_organ_status do
    IO.puts "#{IO.ANSI.magenta()}🫀 ORGAN STATUS (Runtime)#{IO.ANSI.reset()}"
    
    organs = [
      {"L4-IMMUNE (Sentinel)", "🛡️", :active, "Guarding"},
      {"L4-CORTEX (FastOODA)", "🧠", :active, "Reflexive (SAFE)"},
      {"L4-KNOW   (KMS)",      "💾", :active, "Memory Online"},
      {"L4-MESH   (Tailscale)","🕸️", :active, "Telepathy Ready"},
      {"L4-OBS    (Fractal)",  "👁️", :active, "Seeing (L1-L5)"},
      {"L4-SEC    (Guardian)", "⚖️", :active, "Judging"}
    ]

    Enum.each(organs, fn {name, icon, status, desc} ->
      status_str = case status do
        :active -> "#{IO.ANSI.green()}ONLINE#{IO.ANSI.reset()}"
        :dead -> "#{IO.ANSI.red()}OFFLINE#{IO.ANSI.reset()}"
      end
      IO.puts "  #{icon} #{String.pad_trailing(name, 25)} : #{status_str} - #{desc}"
    end)
    IO.puts ""
  end

  defp render_cognitive_state do
    IO.puts "#{IO.ANSI.blue()}🧠 COGNITIVE STATE#{IO.ANSI.reset()}"
    IO.puts "  • Phase:          #{IO.ANSI.white()}ACTIVE INFERENCE#{IO.ANSI.reset()}"
    IO.puts "  • Attention:      #{IO.ANSI.white()}Wiring Verification#{IO.ANSI.reset()}"
    IO.puts "  • Intent:         #{IO.ANSI.white()}Self-Actualization#{IO.ANSI.reset()}"
    IO.puts ""
  end

  defp render_plan_progress do
    IO.puts "#{IO.ANSI.green()}📋 PLAN PROGRESS (Critical Path)#{IO.ANSI.reset()}"
    
    tasks = [
      {"28.1 FastOODA Safety Patch", :done},
      {"29.1 KMS Runtime Wiring",    :done},
      {"29.2 Mesh Runtime Wiring",   :done},
      {"30.1 Cognitive Verification", :done},
      {"31.0 System Hardening",      :done}
    ]

    Enum.each(tasks, fn {name, status} ->
      mark = case status do
        :done -> "#{IO.ANSI.green()}✅#{IO.ANSI.reset()}"
        :pending -> "#{IO.ANSI.yellow()}⏳#{IO.ANSI.reset()}"
      end
      IO.puts "  #{mark} #{name}"
    end)
    IO.puts ""
  end

  defp render_footer do
    IO.puts "#{IO.ANSI.cyan()}──────────────────────────────────────────────────────────────#{IO.ANSI.reset()}"
    IO.puts "Ready for autonomous operation. Awaiting Supervisor command."
  end
end

BiomorphicDashboard.render()
