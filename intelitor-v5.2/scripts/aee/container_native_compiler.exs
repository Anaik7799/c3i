#!/usr/bin/env elixir

defmodule ContainerNativeCompiler do
  @moduledoc """
  AEE Container-Native Compilation System
  
  Bypasses SSL certificate issues by working directly with Elixir compiler
  without depending on Mix/Hex infrastructure.
  
  Created: 2025-09-05 11:54 CEST
  Framework: TPS Jidoka + AEE + SOPv5.1
  """

  def main(args) do
    IO.puts("🚀 AEE Container-Native Compilation System")
    IO.puts("⚡ Framework: TPS Jidoka + SOPv5.1 + Container-Native")
    IO.puts("📅 Started: #{DateTime.utc_now()}")
    
    case args do
      ["--analyze"] -> analyze_source_files()
      ["--compile"] -> compile_files_systematically()
      ["--warnings"] -> analyze_warnings()
      _ -> show_usage()
    end
  end

  def analyze_source_files do
    IO.puts("\n🔍 Analyzing Elixir source files...")
    
    files = find_elixir_files()
    IO.puts("📊 Found #{length(files)} Elixir files")
    
    Enum.take(files, 10)
    |> Enum.each(fn file ->
      IO.puts("  ✅ #{file}")
    end)
    
    :ok
  end
  
  def compile_files_systematically do
    IO.puts("\n🔨 Starting systematic compilation...")
    
    files = find_elixir_files()
    
    # Compile in dependency order (simplified approach)
    foundation_files = Enum.filter(files, &foundation_file?/1)
    business_files = Enum.filter(files, &business_file?/1)
    
    IO.puts("📋 Compiling #{length(foundation_files)} foundation files first...")
    compile_file_group(foundation_files, "Foundation")
    
    IO.puts("📋 Compiling #{length(business_files)} business files...")
    compile_file_group(business_files, "Business")
    
    :ok
  end
  
  def analyze_warnings do
    IO.puts("\n⚠️ Analyzing warning patterns...")
    
    files = find_elixir_files()
    
    warning_patterns = []
    
    Enum.take(files, 5)
    |> Enum.each(fn file ->
      IO.puts("🔍 Checking #{file}")
      content = File.read!(file)
      
      # Basic pattern detection
      unused_vars = count_unused_variables(content)
      if unused_vars > 0 do
        IO.puts("  ⚠️ Found #{unused_vars} potential unused variables")
      end
    end)
    
    :ok
  end
  
  defp find_elixir_files do
    {output, 0} = System.cmd("find", ["lib", "-name", "*.ex", "-type", "f"])
    
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
  end
  
  defp foundation_file?(file) do
    String.contains?(file, ["base_", "core", "repo", "types", "errors"])
  end
  
  defp business_file?(file) do
    String.contains?(file, ["__context", "domain", "resource"])
  end
  
  defp compile_file_group(files, group_name) do
    IO.puts("🔨 Compiling #{group_name} group (#{length(files)} files)")
    
    Enum.each(files, fn file ->
      try do
        # Basic syntax check using Code.compile_file
        Code.compile_file(file)
        IO.puts("  ✅ #{file}")
      rescue
        e ->
          IO.puts("  ❌ #{file}: #{Exception.message(e)}")
      end
    end)
  end
  
  defp count_unused_variables(content) do
    # Simple regex pattern for unused variables (starts with _)
    Regex.scan(~r/\b_[a-z_]+\b/, content)
    |> length()
  end
  
  defp show_usage do
    IO.puts("""
    🚀 AEE Container-Native Compilation System
    
    Usage:
      elixir scripts/aee/container_native_compiler.exs --analyze
      elixir scripts/aee/container_native_compiler.exs --compile  
      elixir scripts/aee/container_native_compiler.exs --warnings
    """)
  end
end

# Run if called directly
if System.argv() != [] do
  ContainerNativeCompiler.main(System.argv())
end