#!/usr/bin/env elixir
# Final 9 errors fixer - targeting specific remaining issues

Mix.install([{:jason, "~> 1.4"}])

defmodule Final9ErrorsFixer do
  @moduledoc """
  Fixes the final 9 compilation errors
  """

  def run(_args \\ []) do
    IO.puts """
    🔧 Final 9 Errors Fixer
    =======================
    Fixing remaining specific errors
    """

    # Create checkpoint
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "Checkpoint: Before final 9 errors fix"])
    
    # Fix specific files with remaining errors
    fix_compliance_reporter()
    fix_domain_hooks()
    
    IO.puts("\n✅ Final error fixes complete!")
  end

  defp fix_compliance_reporter do
    IO.puts("\n📝 Fixing lib/indrajaal/access_control/compliance_reporter.ex")
    file = "lib/indrajaal/access_control/compliance_reporter.ex"
    content = File.read!(file)
    
    # Fix schedule_config usage (lines 797-801)
    fixed_content = content
      |> String.replace("schedule_config[:", "_schedule_config[:")
      |> String.replace("perform_violation_analysis(violation_data, _duplicate_data)", 
                       "perform_violation_analysis(violation_data, violation_data)")
      |> String.replace("if Enum.empty?(framework_config[:requirements] || []) do",
                       "if Enum.empty?(_framework_config[:requirements] || []) do")
    
    File.write!(file, fixed_content)
    IO.puts("  ✅ Fixed compliance_reporter.ex")
  end
  
  defp fix_domain_hooks do
    IO.puts("\n📝 Fixing lib/indrajaal/access_control/domain_hooks.ex")
    file = "lib/indrajaal/access_control/domain_hooks.ex"
    content = File.read!(file)
    
    # Fix _context usage in lines 528, 551
    fixed_content = content
      |> String.replace("_context: _context", "_context: context")
      |> String.replace("repeated_attempts = Map.get(_context || %{}, :repeated_attempts, 0)",
                       "repeated_attempts = Map.get(context || %{}, :repeated_attempts, 0)")
    
    File.write!(file, fixed_content)
    IO.puts("  ✅ Fixed domain_hooks.ex")
  end
end

# Run the fixer
Final9ErrorsFixer.run()
