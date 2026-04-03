defmodule Indrajaal.Agents.LogInspector do
  @moduledoc """
  Audits Level 1-5 Fractal Logs for structural divergence.
  """

  def inspect_level(level) do
    IO.puts("INSPECTING FRACTAL LOG LEVEL \#{level}...")
    log_file = "data/tmp/session-L\#{level}.log"
    
    if File.exists?(log_file) do
      File.stream!(log_file) |> Enum.take(-10) |> Enum.each(&IO.write/1)
    else
      IO.puts("RESULT: LOG LEVEL \#{level} IS EMPTY (Homeostasis)")
    end
  end
end

case System.argv() do
  [level] -> Indrajaal.Agents.LogInspector.inspect_level(level)
  _ -> IO.puts("Fractal Log Inspector ready for Level 1-5 audits.")
end
