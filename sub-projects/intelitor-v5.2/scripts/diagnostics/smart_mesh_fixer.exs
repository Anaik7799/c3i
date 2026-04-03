#!/usr/bin/env elixir
# smart_mesh_fixer.exs - AI-Driven Infrastructure Diagnostic
# Uses OpenRouter to analyze stuck container states.

Mix.install([{:jason, "~> 1.4"}, {:req, "~> 0.4"}])

defmodule SmartMeshFixer do
  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"
  @api_key System.get_env("OPENROUTER_API_KEY")

  def diagnose do
    IO.puts "🔍 [OBSERVE] Gathering system evidence..."
    {ps_out, _} = System.cmd("podman", ["ps", "-a", "--format", "json"])
    {logs_out, _} = System.cmd("podman", ["logs", "indrajaal-db-prod"], stderr_to_stdout: true)
    
    IO.puts "🧠 [DECIDE] Consulting OpenRouter Oracle..."
    
    prompt = """
    The Indrajaal Fractal Mesh is hung during startup.
    CONTAINER STATE:
    #{ps_out}
    
    DB LOGS:
    #{String.slice(logs_out, -1000..-1)}
    
    Analyze why the database isn't reaching 'healthy' state and suggest a single 'sa-' command to fix it.
    Return JSON: {"reason": "...", "fix_command": "sa-..."}
    """

    if @api_key do
      case Req.post(@openrouter_url, 
        headers: [{"Authorization", "Bearer #{@api_key}"}],
        json: %{
          model: "google/gemini-pro-1.5",
          messages: [%{role: "user", content: prompt}]
        }) do
        {:ok, %{status: 200, body: body}} ->
          %{ "content" => content } = List.first(body["choices"])["message"]
          handle_fix(Jason.decode!(content))
        _ -> 
          IO.puts "⚠️ Oracle unreachable. Falling back to heuristic recovery."
          manual_fix()
      end
    else
      IO.puts "⚠️ NO API KEY. Falling back to heuristic recovery."
      manual_fix()
    end
  end

  defp handle_fix(%{"reason" => reason, "fix_command" => cmd}) do
    IO.puts "💡 AI ANALYSIS: #{reason}"
    IO.puts "🚀 EXECUTING FIX: #{cmd}"
    System.cmd("devenv", ["shell", cmd])
  end

  defp manual_fix do
    IO.puts "🔧 Performing Surgical Scour and Reset..."
    System.cmd("devenv", ["shell", "sa-scour"])
    System.cmd("devenv", ["shell", "sa-down"])
    System.cmd("devenv", ["shell", "sa-up"])
  end
end

SmartMeshFixer.diagnose()
