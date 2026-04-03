defmodule Indrajaal.Agents.AshOracle do
  @moduledoc """
  Semantic Intelligence for Ash Framework Resources.
  """

  def info(resource) do
    IO.puts("QUERYING ASH GENOME: \#{resource}")
    # In production, this would call Ash.Resource.Info
    {out, code} = System.cmd("mix", ["ash.info", resource])
    
    if code == 0 do
      IO.puts("RESULT: RESOURCE SCHEMA VALID")
      IO.puts(out)
    else
      IO.puts("RESULT: RESOURCE NOT FOUND OR INVALID")
    end
  end
end

case System.argv() do
  [resource] -> Indrajaal.Agents.AshOracle.info(resource)
  _ -> IO.puts("Ash Oracle ready for declarative audits.")
end
