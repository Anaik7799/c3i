defmodule Indrajaal.Agents.ElixirOracle do
  @moduledoc """
  Bicameral Elixir Oracle for AST and Semantic Analysis.
  """

  def analyze(file_path) do
    IO.puts("PROBING ELIXIR SEMANTICS: \#{file_path}")
    
    case File.read(file_path) do
      {:ok, content} ->
        case Code.string_to_quoted(content) do
          {:ok, _ast} ->
            IO.puts("RESULT: AST VALID")
            check_compilation(file_path)
          {:error, {line, error, token}} ->
            IO.puts("RESULT: AST CORRUPT at line \#{line}: \#{error} \#{token}")
            :error
        end
      {:error, reason} ->
        IO.puts("RESULT: FILE ACCESS ERROR: \#{reason}")
        :error
    end
  end

  defp check_compilation(_file) do
    # Run mix compile --jobs 16 in current env context
    {output, code} = System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true)
    if code == 0 do
      IO.puts("RESULT: SEMANTICALLY VALID")
      :ok
    else
      IO.puts("RESULT: SEMANTIC ERRORS DETECTED")
      IO.puts(output)
      :error
    end
  end
end

case System.argv() do
  [file] -> Indrajaal.Agents.ElixirOracle.analyze(file)
  _ -> IO.puts("Elixir Oracle ready for SIL6 diagnostics.")
end
