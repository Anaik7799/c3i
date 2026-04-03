#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FinalCacheParameterFixer do
  @moduledoc """
  Final fix for ALL remaining cache parameter naming mismatches.

  AEE SOPv5.11 Compliance: Systematic resolution of cache parameter-body mismatches
  TPS Jidoka Principle: Complete stop-and-fix for zero-error validation checkpoint
  """

  def run do
    IO.puts("🚀 AEE SOPv5.11: Final Cache Parameter Fixing")
    IO.puts("============================================")

    files = [
      "lib/indrajaal/cache.ex",
      "lib/indrajaal/cache/key_generator.ex"
    ]

    Enum.each(files, &fix_file/1)

    IO.puts("✅ AEE Final Cache Parameter Fixing Complete")
  end

  defp fix_file(file_path) do
    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          original_content = content

          fixed_content = content
          |> fix_cache_parameters()
          |> fix_key_generator_parameters()

          if fixed_content != original_content do
            File.write!(file_path, fixed_content)
            IO.puts("✅ Fixed: #{Path.relative_to_cwd(file_path)}")
          else
            IO.puts("ℹ️  No changes needed: #{Path.relative_to_cwd(file_path)}")
          end

        {:error, reason} ->
          IO.puts("❌ Error reading #{file_path}: #{reason}")
      end
    else
      IO.puts("❌ File not found: #{file_path}")
    end
  end

  defp fix_cache_parameters(content) do
    content
    # Fix cache.ex parameter naming mismatches
    |> String.replace(~r/def get_entity\(type, id, sourcefn/, "def get_entity(type, id, source_fn")
    |> String.replace(~r/def get_query\(queryhash\)/, "def get_query(query_hash)")
  end

  defp fix_key_generator_parameters(content) do
    content
    # Fix key_generator.ex parameter naming mismatches
    |> String.replace(~r/def entity_key\(type, id, tenantid/, "def entity_key(type, id, __tenant_id")
  end
end

# Execute the final cache parameter fixing
FinalCacheParameterFixer.run()