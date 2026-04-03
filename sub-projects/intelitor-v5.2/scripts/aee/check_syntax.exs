#!/usr/bin/env elixir

file_path = "lib/indrajaal/shared/aggregation_query_builder.ex"
content = File.read!(file_path)

case Code.string_to_quoted(content) do
  {:ok, _ast} ->
    IO.puts("✅ File syntax is valid")
  {:error, {meta, message, _}} ->
    line = Keyword.get(meta, :line, "unknown")
    col = Keyword.get(meta, :column, "unknown")
    IO.puts("❌ Syntax error on line #{line}, column #{col}: #{inspect(message)}")
end