# Fix Exqlite.Sqlite3.bind/3 to bind/2 across the codebase

defmodule FixSqliteBind do
  def run do
    files = [
      "lib/indrajaal/kms/vectors.ex",
      "lib/indrajaal/kms/product.ex",
      "lib/indrajaal/kms/sre.ex",
      "lib/indrajaal/kms/sqlite.ex",
      "lib/indrajaal/kms/developer.ex"
    ]

    Enum.each(files, &fix_file/1)
  end

  def fix_file(path) do
    if File.exists?(path) do
      content = File.read!(path)

      new_content = content
      # Pattern 1: Exqlite.Sqlite3.bind(stmt, 1, value) -> Exqlite.Sqlite3.bind(stmt, [value])
      |> String.replace(~r/Exqlite\.Sqlite3\.bind\(\s*(\w+),\s*\d+,\s*([^)]+)\)/, "Exqlite.Sqlite3.bind(\1, [\2])")
      # Pattern 2: Exqlite.Sqlite3.bind(stmt, [val1, val2...]) remains same if it was already list (but it was bind/2 then)
      # Pattern 3: Enum.each(fn {val, idx} -> Exqlite.Sqlite3.bind(stmt, idx, val) end) -> Exqlite.Sqlite3.bind(stmt, params)
      # This one is tricky with regex, better do it manually or specific patterns.

      # Specific for KMS.SQLite bind_params
      new_content = if path == "lib/indrajaal/kms/sqlite.ex" do
        String.replace(new_content, ~r/defp bind_params\(stmt, params\) do\s+params\s+\|> Enum\.with_index\(1\)\s+\|> Enum\.each\(fn {value, index} ->\s+Exqlite\.Sqlite3\.bind\(stmt, index, value\)\s+end\)\s+:ok\s+end/s, "defp bind_params(stmt, params) do\n    Exqlite.Sqlite3.bind(stmt, params)\n  end")
      else
        new_content
      end

      # Specific for KMS.Product list_features
      new_content = String.replace(new_content, ~r/\(params \+\+ \[limit\]\)\s+\|> Enum\.with_index\(1\)\s+\|> Enum\.each\(fn {val, idx} -> Exqlite\.Sqlite3\.bind\(stmt, idx, val\) end\)/s, "Exqlite.Sqlite3.bind(stmt, params ++ [limit])")

      # Specific for KMS.Product list_kpis
      new_content = String.replace(new_content, ~r/indexed_params\s+\|> Enum\.each\(fn {val, idx} -> Exqlite\.Sqlite3\.bind\(stmt, idx, val\) end\)/s, "Exqlite.Sqlite3.bind(stmt, params)")

      # Specific for KMS.Developer list_decisions
      new_content = String.replace(new_content, ~r/\|> Enum\.each\(fn {val, idx} -> Exqlite\.Sqlite3\.bind\(stmt, idx, val\) end\)/, "Exqlite.Sqlite3.bind(stmt, params)")

      if new_content != content do
        File.write!(path, new_content)
        IO.puts("Fixed #{path}")
      end
    end
  end
end

FixSqliteBind.run()
