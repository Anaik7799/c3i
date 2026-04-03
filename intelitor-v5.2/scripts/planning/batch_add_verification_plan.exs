defmodule BatchPlanner do
  def run do
    # Level 1
    add("23.0", "root", "Formal Verification Triad (Mathematica/Quint/Agda) [Layer 3 Safety]")

    # Level 2
    add("23.1", "23.0", "Layer 2: Quint Model Checking (Behavioral Verification)")
    add("23.2", "23.0", "Layer 3: Agda Eternal Proofs (Certifiable Truth)")
    add("23.3", "23.0", "Layer 1: Mathematica Specification (Blueprint Sync)")

    # Level 3 - Quint
    add("23.1.1", "23.1", "Quint Infrastructure Setup")
    add("23.1.2", "23.1", "Core System Models Implementation")
    add("23.1.3", "23.1", "CI/CD Integration for Quint")

    # Level 4 - Quint Infra
    add("23.1.1.1", "23.1.1", "Install Quint toolchain and vscode extensions")
    add("23.1.1.2", "23.1.1", "Create quint directory structure and Type definitions")

    # Level 4 - Quint Models
    add("23.1.2.1", "23.1.2", "Model AgentStateMachine.qnt")
    add("23.1.2.2", "23.1.2", "Model OODALoop.qnt")
    add("23.1.2.3", "23.1.2", "Model STAMPConstraints.qnt")

    # Level 3 - Agda
    add("23.2.1", "23.2", "Agda Environment Configuration")
    add("23.2.2", "23.2", "Critical Invariant Proofs")

    # Level 4 - Agda
    add("23.2.1.1", "23.2.1", "Setup Agda Standard Library and Compiler")
    add("23.2.2.1", "23.2.2", "Prove Patient Mode Invariant (Axiom 1)")
    add("23.2.2.2", "23.2.2", "Prove Container Isolation (Axiom 2)")

    # Level 3 - Mathematica
    add("23.3.1", "23.3", "Specification Formalization")

    # Level 4 - Mathematica
    add("23.3.1.1", "23.3.1", "Sync GEMINI.md Section 0-22 with Math Notation")
    add("23.3.1.2", "23.3.1", "Define Deontic Logic Operators")

    IO.puts("Plan injection complete.")
  end

  defp add(id, parent, content) do
    # Using sigil ~s to avoid quote escaping issues
    # Parent and Content must be quoted for the shell command
    cmd = ~s(elixir scripts/planning/todolist_manager.exs --add --parent "#{parent}" "#{id} - #{content}")
    IO.puts("Executing: #{cmd}")
    System.shell(cmd)
    # Small sleep to allow lock release/jitter
    Process.sleep(100)
  end
end

BatchPlanner.run()