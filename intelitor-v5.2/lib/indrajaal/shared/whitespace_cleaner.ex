defmodule WhitespaceCleaner do
  @moduledoc """
  Removes trailing whitespace from all Elixir files
  """

  def clean_all_files do
    Path.wildcard(
      "{lib,test,scripts}/**/*.{ex,exs}"
      |> Task.async_stream(&clean_file/1,
        max_concurrency:
          8
          |> Enum.reduce({0, 0}, fn
            {:ok, :modified}, {files, lines} -> {files + 1, lines + 1}
            {:ok, :unchanged}, acc -> acc
          end)
      )
    )
  end

  defp clean_file(path) do
    with {:ok, content} <- File.read(path) do
      cleaned = clean_content(content)

      if cleaned != content do
        File.write!(path, cleaned)
        :modified
      else
        :unchanged
      end
    end
  end

  defp clean_content(content) do
    content
    |> String.split("\n" |> Enum.map_join(&String.trim_trailing/1, "\n"))
  end
end
