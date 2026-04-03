defmodule Indrajaal.Shared.EnumOptimizer do
  @moduledoc """

  Optimizes common Enum anti-patterns for better performance
  """

  @optimization_patterns [
    # map |> join -> map_join
    {~r/Enum\.map\((.*?)\)\s*\|>\s * Enum\.join\((.*?)\)/, "Enum.map_join(\\1, \\2)"},

    # filter |> map -> flat_map with conditional
    {~r/Enum\.filter\((.*?),\s*(.*?)\)\s*\|>\s * Enum\.map\((.*?)\)/,
     "Enum.flat_map(\\1, fn x -> if \\2.(x), do: [\\3.(x)], else: [] end)"},

    # map |> filter -> flat_map with conditional
    {~r/Enum\.map\((.*?),\s*(.*?)\)\s*\|>\s * Enum\.filter\((.*?)\)/,
     "Enum.flat_map(\\1, fn x -> result = \\2.(x); if \\3.(_result), do: [result], else: [] end)"}
  ]

  @spec optimize_file(term()) :: term()
  def optimize_file(file_path) do
    with {:ok, content} <- File.read(file_path) do
      optimized = apply_optimizations(content)

      if optimized != content do
        File.write!(file_path, optimized)
        {:modified, count_optimizations(content, optimized)}
      else
        {:unchanged, 0}
      end
    end
  end

  defp apply_optimizations(content) do
    Enum.reduce(@optimization_patterns, content, fn {pattern, replacement}, acc ->
      Regex.replace(pattern, acc, replacement)
    end)
  end

  defp count_optimizations(_original, _optimized) do
    # Count number of changes
    1
  end
end
