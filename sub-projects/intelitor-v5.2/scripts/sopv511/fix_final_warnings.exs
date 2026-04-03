#!/usr/bin/env elixir

# SOPv5.11 Final Warning Fixer - Fix all 66 remaining warnings

defmodule FinalWarningFixer do
  @moduledoc """
  Fixes the remaining 66 warnings:
  1. _user used after being set (62 instances)
  2. opts unused (4 instances)
  """

  def run do
    IO.puts("\n🚀 SOPv5.11 FINAL WARNING FIXER")
    IO.puts("=" <> String.duplicate("=", 79))

    # Fix _user warnings in authentication.ex
    fix_authentication()

    # Fix unused opts warnings
    fix_unused_opts()

    IO.puts("\n✅ All warning fixes applied")
  end

  defp fix_authentication do
    file = "lib/indrajaal/accounts/authentication.ex"

    if File.exists?(file) do
      content = File.read!(file)
      original = content

      # Replace all _user with user when it's being used
      content = Regex.replace(
        ~r/(\W)_user(\W)/,
        content,
        fn _full, prefix, suffix ->
          prefix <> "user" <> suffix
        end
      )

      if content != original do
        File.write!(file, content)
        IO.puts("✅ Fixed #{file} - removed underscores from _user")
      end
    end
  end

  defp fix_unused_opts do
    # Fix analytics_engine.ex
    file1 = "lib/indrajaal/access_control/analytics_engine.ex"
    if File.exists?(file1) do
      content = File.read!(file1)

      # Fix line 1135: runarima_prediction
      content = String.replace(content,
        "defp runarima_prediction(data, opts) do",
        "defp runarima_prediction(data, _opts) do")

      File.write!(file1, content)
      IO.puts("✅ Fixed #{file1} - added underscore to unused opts")
    end

    # Fix authentication.ex start_link
    file2 = "lib/indrajaal/accounts/authentication.ex"
    if File.exists?(file2) do
      content = File.read!(file2)

      # Fix line 64: start_link
      content = String.replace(content,
        "def start_link(opts) do",
        "def start_link(_opts) do")

      File.write!(file2, content)
      IO.puts("✅ Fixed #{file2} - added underscore to unused opts")
    end
  end
end

FinalWarningFixer.run()