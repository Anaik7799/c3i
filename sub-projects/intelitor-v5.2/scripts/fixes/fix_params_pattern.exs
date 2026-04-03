#!/usr/bin/env elixir

defmodule FixParamsPattern do
  @moduledoc """
  Fix the systematic _params vs __params issue across mobile config controllers.

  Issue: Functions defined with `_params` but code uses `__params` without underscore.
  Solution: Remove underscore from function parameter when it's actually used.
  """

  def fix_all do
    controllers_dir = "lib/indrajaal_web/controllers/api/mobile/config/"

    controllers_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.each(fn filename ->
      file_path = Path.join(controllers_dir, filename)
      fix_file(file_path)
    end)
  end

  def fix_file(file_path) do
    content = File.read!(file_path)

    # Pattern: def function_name(conn, __params) do ... __params["key"] ...
    # We need to check if __params (without underscore) is used in the function body

    updated_content =
      content
      |> String.replace(~r/(\s+def\s+\w+\(conn,\s+)_params(\)\s+do)/m, "\\1__params\\2")
      |> String.replace(~r/(\s+def\s+\w+\(\s*conn,\s+)_params(\s*\)\s+do)/m, "\\1__params\\2")

    if updated_content != content do
      File.write!(file_path, updated_content)
      IO.puts("✅ Fixed: #{file_path}")
    else
      IO.puts("ℹ️  No changes needed: #{file_path}")
    end
  end
end

case System.argv() do
  ["--fix-all"] -> FixParamsPattern.fix_all()
  [file] -> FixParamsPattern.fix_file(file)
  _ ->
    IO.puts("Usage:")
    IO.puts("  elixir #{__ENV__.file} --fix-all")
    IO.puts("  elixir #{__ENV__.file} path/to/file.ex")
end