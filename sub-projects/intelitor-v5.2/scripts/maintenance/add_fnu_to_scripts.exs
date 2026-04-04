#!/usr/bin/env elixir

defmodule AddFnuToScripts do
  @moduledoc """
  Automated script to add +fnu flag to ELIXIR_ERL_OPTIONS in all scripts.

  Usage:
    elixir scripts/maintenance/add_fnu_to_scripts.exs [--dry-run]

  Options:
    --dry-run    Show what would be changed without making changes
    --fix       Actually apply the changes (default: dry-run)

  This script follows the guidance from:
  - docs/journal/archive/v5_1_legacy/20250905-1335-aee-sopv51-container-infrastructure-comprehensive-documentation.md
  - docs/journal/20260402-1605-elixir-container-fix.md

  The +fnu flag is REQUIRED to fix:
  "warning: the VM is running with native name encoding of latin1 which may cause 
   Elixir to malfunction as it expects utf8."
  """

  @simple_patterns [
    {"ELIXIR_ERL_OPTIONS=\"+S 16\"", "ELIXIR_ERL_OPTIONS=\"+fnu +S 16\""},
    {"ELIXIR_ERL_OPTIONS=\"+S 16:16 +SDio 16\"", "ELIXIR_ERL_OPTIONS=\"+fnu +S 16:16 +SDio 16\""},
    {"ELIXIR_ERL_OPTIONS=\"+S 16 +A 32\"", "ELIXIR_ERL_OPTIONS=\"+fnu +S 16 +A 32\""},
    {"ELIXIR_ERL_OPTIONS='+fnu +S 16'", "ELIXIR_ERL_OPTIONS='+fnu +S 16'"},
    {"ELIXIR_ERL_OPTIONS='+S 16:16 +SDio 16'", "ELIXIR_ERL_OPTIONS='+fnu +S 16:16 +SDio 16'"},
    {"ELIXIR_ERL_OPTIONS=+fnu +S 16", "ELIXIR_ERL_OPTIONS=+fnu +S 16"},
    {"\"ELIXIR_ERL_OPTIONS\", \"+S 16\"", "\"ELIXIR_ERL_OPTIONS\", \"+fnu +S 16\""},
    {"\"ELIXIR_ERL_OPTIONS\", \"+S 16:16 +SDio 16\"",
     "\"ELIXIR_ERL_OPTIONS\", \"+fnu +S 16:16 +SDio 16\""},
    {"\"ELIXIR_ERL_OPTIONS\", '+S 16'", "\"ELIXIR_ERL_OPTIONS\", '+fnu +S 16'"},
    {"'ELIXIR_ERL_OPTIONS', \"+S 16\"", "'ELIXIR_ERL_OPTIONS', \"+fnu +S 16\""},
    {"'ELIXIR_ERL_OPTIONS', '+S 16'", "'ELIXIR_ERL_OPTIONS', '+fnu +S 16'"},
    {"ELIXIR_ERL_OPTIONS => \"+S 16\"", "ELIXIR_ERL_OPTIONS => \"+fnu +S 16\""},
    {"ELIXIR_ERL_OPTIONS => \"+S 16:16 +SDio 16\"",
     "ELIXIR_ERL_OPTIONS => \"+fnu +S 16:16 +SDio 16\""},
    {"\"ELIXIR_ERL_OPTIONS\" => \"+S 16\"", "\"ELIXIR_ERL_OPTIONS\" => \"+fnu +S 16\""},
    {"System.put_env(\"ELIXIR_ERL_OPTIONS\", \"+S 16\")",
     "System.put_env(\"ELIXIR_ERL_OPTIONS\", \"+fnu +S 16\")"},
    {"System.put_env(\"ELIXIR_ERL_OPTIONS\", \"+S 16:16 +SDio 16\")",
     "System.put_env(\"ELIXIR_ERL_OPTIONS\", \"+fnu +S 16:16 +SDio 16\")"},
    {"System.put_env('ELIXIR_ERL_OPTIONS', \"+S 16\")",
     "System.put_env('ELIXIR_ERL_OPTIONS', \"+fnu +S 16\")"},
    {"System.put_env('ELIXIR_ERL_OPTIONS', '+S 16')",
     "System.put_env('ELIXIR_ERL_OPTIONS', '+fnu +S 16')"},
    {"export ELIXIR_ERL_OPTIONS=\"+S 16\"", "export ELIXIR_ERL_OPTIONS=\"+fnu +S 16\""},
    {"export ELIXIR_ERL_OPTIONS=\"+S 16:16 +SDio 16\"",
     "export ELIXIR_ERL_OPTIONS=\"+fnu +S 16:16 +SDio 16\""},
    {"export ELIXIR_ERL_OPTIONS='+fnu +S 16'", "export ELIXIR_ERL_OPTIONS='+fnu +S 16'"},
    {"export ELIXIR_ERL_OPTIONS='+S 16:16 +SDio 16'",
     "export ELIXIR_ERL_OPTIONS='+fnu +S 16:16 +SDio 16'"}
  ]

  @regex_patterns [
    {~r/ELIXIR_ERL_OPTIONS["\']\s*=+\s*["\']\+S 16["\']/, "+fnu +S 16"},
    {~r/ELIXIR_ERL_OPTIONS["\']\s*=+\s*["\']\+S 16:16 \+SDio 16["\']/, "+fnu +S 16:16 +SDio 16"}
  ]

  @skip_patterns [
    "comprehensive_preflight_system.exs",
    "tdg_container_compliance_tests.exs",
    "update_compose_for_sopv51.exs",
    "fix_container_certs.exs",
    "simple_working_container.exs"
  ]

  def main(args) do
    dry_run? = "--dry-run" in args or "--dry" in args
    fix? = "--fix" in args or "--apply" in args

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║           ELIXIR_ERL_OPTIONS +fnu Flag Adder v2                 ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ Purpose: Add +fnu flag to fix UTF-8 encoding warning            ║
    ║ Mode: #{if dry_run?, do: "DRY RUN (no changes)", else: if(fix?, do: "FIX MODE (applying changes)", else: "DRY RUN (use --fix to apply)")}
    ╚══════════════════════════════════════════════════════════════════╝
    """)

    if dry_run? or not fix? do
      IO.puts("⚠️  DRY RUN MODE - No changes will be made")
      IO.puts("   Use --fix to apply changes\n")
    else
      IO.puts("✅ FIX MODE - Changes will be applied\n")
    end

    scripts_dir = Path.join([File.cwd!(), "scripts"])

    unless File.dir?(scripts_dir) do
      IO.puts("❌ Error: scripts/ directory not found")
      System.halt(1)
    end

    {stats, files_to_fix} = scan_and_count(scripts_dir)

    IO.puts("📊 Scan Results:")
    IO.puts("   Total script files: #{stats.total}")
    IO.puts("   Files with ELIXIR_ERL_OPTIONS: #{stats.with_erl_opts}")
    IO.puts("   Files missing +fnu: #{stats.missing_fnu}")
    IO.puts("   Files already have +fnu: #{stats.has_fnu}")
    IO.puts("")

    if files_to_fix == [] do
      IO.puts("✅ All files already have +fnu flag!")
    else
      IO.puts("📝 Files to fix (#{length(files_to_fix)}):")

      Enum.each(files_to_fix, fn file ->
        IO.puts("   • #{Path.relative_to(file, scripts_dir)}")
      end)

      IO.puts("")

      if fix? do
        apply_fixes(files_to_fix)
      else
        IO.puts("Run with --fix to apply these changes")
      end
    end
  end

  defp scan_and_count(scripts_dir) do
    files = Path.wildcard(Path.join(scripts_dir, "**/*.exs"))

    initial_acc = %{
      total: 0,
      with_erl_opts: 0,
      missing_fnu: 0,
      has_fnu: 0,
      files_to_fix: []
    }

    result =
      Enum.reduce(files, initial_acc, fn file, acc ->
        filename = Path.basename(file)

        if Enum.any?(@skip_patterns, &String.contains?(filename, &1)) do
          %{acc | total: acc.total + 1}
        else
          acc = %{acc | total: acc.total + 1}

          case File.read(file) do
            {:ok, content} ->
              if String.contains?(content, "ELIXIR_ERL_OPTIONS") do
                acc = %{acc | with_erl_opts: acc.with_erl_opts + 1}

                if String.contains?(content, "+fnu") do
                  %{acc | has_fnu: acc.has_fnu + 1}
                else
                  if needs_fnu?(content) do
                    %{
                      acc
                      | missing_fnu: acc.missing_fnu + 1,
                        files_to_fix: [file | acc.files_to_fix]
                    }
                  else
                    %{acc | missing_fnu: acc.missing_fnu + 1}
                  end
                end
              else
                acc
              end

            {:error, _} ->
              acc
          end
        end
      end)

    {Map.take(result, [:total, :with_erl_opts, :missing_fnu, :has_fnu]), result.files_to_fix}
  end

  defp needs_fnu?(content) do
    Enum.any?(@simple_patterns, fn {old, _new} ->
      String.contains?(content, old)
    end) or
      Enum.any?(@regex_patterns, fn {regex, _replacement} ->
        Regex.match?(regex, content)
      end)
  end

  defp apply_fixes(files_to_fix) do
    IO.puts("🔧 Applying fixes...")
    IO.puts("")

    success_count =
      Enum.reduce(files_to_fix, 0, fn file, count ->
        case File.read(file) do
          {:ok, content} ->
            new_content = apply_patterns(content)

            if new_content != content do
              case File.write(file, new_content) do
                :ok ->
                  IO.puts("   ✅ Fixed: #{Path.relative_to(file, File.cwd!())}")
                  count + 1

                {:error, reason} ->
                  IO.puts("   ❌ Error writing #{file}: #{reason}")
                  count
              end
            else
              count
            end

          {:error, reason} ->
            IO.puts("   ❌ Error reading #{file}: #{reason}")
            count
        end
      end)

    IO.puts("")
    IO.puts("╔══════════════════════════════════════════════════════════╗")
    IO.puts("║                    Summary                             ║")
    IO.puts("╠══════════════════════════════════════════════════════════╣")
    IO.puts("║ Files fixed: #{success_count}                                        ║")
    IO.puts("╚══════════════════════════════════════════════════════════╝")
  end

  defp apply_patterns(content) do
    content
    |> apply_simple_patterns()
    |> apply_regex_patterns()
  end

  defp apply_simple_patterns(content) do
    Enum.reduce(@simple_patterns, content, fn {old, new}, acc ->
      String.replace(acc, old, new)
    end)
  end

  defp apply_regex_patterns(content) do
    Enum.reduce(@regex_patterns, content, fn {regex, replacement}, acc ->
      Regex.replace(regex, acc, "\"+fnu #{replacement}\"")
    end)
  end
end

args = System.argv()
AddFnuToScripts.main(args)
