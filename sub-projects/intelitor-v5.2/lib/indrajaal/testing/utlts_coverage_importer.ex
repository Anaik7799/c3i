defmodule Indrajaal.Testing.UTLTSCoverageImporter do
  @moduledoc """
  Imports coverage data from excoveralls/lcov into the UTLTS database.

  Reads coverage output files and writes module-level coverage metrics
  to the `coverage_data` table, enabling cross-run coverage trend analysis.

  ## What
  Coverage data importer supporting excoveralls JSON and lcov formats.

  ## Why
  - Coverage data is ephemeral (generated per run, not persisted)
  - No historical coverage trend analysis without persistence
  - Need per-module coverage with fractal layer classification

  ## Constraints
  - SC-UTLTS-008: Coverage data import (lcov/excoveralls)
  - SC-COV-001: Static coverage >= 100% for critical paths
  - SC-COV-002: Runtime coverage >= 95% overall

  ## Usage
  ```elixir
  # Import excoveralls JSON output
  UTLTSCoverageImporter.import_excoveralls("cover/excoveralls.json", run_id)

  # Import lcov format
  UTLTSCoverageImporter.import_lcov("cover/lcov.info", run_id)

  # Auto-detect and import from default paths
  UTLTSCoverageImporter.auto_import(run_id)
  ```

  ## Change History
  | Version | Date       | Author      | Change                    |
  |---------|------------|-------------|---------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  require Logger

  @db_path "data/holons/test/utlts.db"

  @doc """
  Auto-detect and import coverage data from standard locations.
  """
  @spec auto_import(String.t()) :: {:ok, integer()} | {:error, term()}
  def auto_import(run_id) do
    cond do
      File.exists?("cover/excoveralls.json") ->
        import_excoveralls("cover/excoveralls.json", run_id)

      File.exists?("cover/lcov.info") ->
        import_lcov("cover/lcov.info", run_id)

      File.exists?("cover/lcov.coverdata") ->
        Logger.info(
          "[UTLTS-Coverage] Found coverdata but no lcov.info — run `mix test --cover` to generate"
        )

        {:error, :no_lcov_output}

      true ->
        {:error, :no_coverage_files}
    end
  end

  @doc """
  Import excoveralls JSON format.
  """
  @spec import_excoveralls(String.t(), String.t()) :: {:ok, integer()} | {:error, term()}
  def import_excoveralls(json_path, run_id) do
    with {:ok, content} <- File.read(json_path),
         {:ok, data} <- Jason.decode(content) do
      source_files = Map.get(data, "source_files", [])

      records =
        Enum.map(source_files, fn file ->
          coverage = Map.get(file, "coverage", [])
          lines_total = Enum.count(coverage, &(not is_nil(&1)))
          lines_covered = Enum.count(coverage, &(&1 != nil and &1 > 0))
          lines_missed = lines_total - lines_covered

          uncovered =
            coverage
            |> Enum.with_index(1)
            |> Enum.filter(fn {cov, _} -> cov == 0 end)
            |> Enum.map(fn {_, line} -> line end)

          %{
            runtime: "elixir",
            module_name: extract_module_name(Map.get(file, "name", "")),
            file_path: Map.get(file, "name", ""),
            lines_total: lines_total,
            lines_covered: lines_covered,
            lines_missed: lines_missed,
            fractal_layer: estimate_layer(Map.get(file, "name", "")),
            domain: extract_domain(Map.get(file, "name", "")),
            uncovered_lines: Jason.encode!(Enum.take(uncovered, 100))
          }
        end)

      count = write_coverage(run_id, records)

      # Update run-level coverage
      update_run_coverage(run_id, records)

      Logger.info("[UTLTS-Coverage] Imported #{count} module coverage records from excoveralls")
      {:ok, count}
    end
  end

  @doc """
  Import lcov format.
  """
  @spec import_lcov(String.t(), String.t()) :: {:ok, integer()} | {:error, term()}
  def import_lcov(lcov_path, run_id) do
    case File.read(lcov_path) do
      {:ok, content} ->
        records = parse_lcov(content)
        count = write_coverage(run_id, records)
        update_run_coverage(run_id, records)
        Logger.info("[UTLTS-Coverage] Imported #{count} module coverage records from lcov")
        {:ok, count}

      error ->
        error
    end
  end

  # ============================================================
  # LCOV PARSING
  # ============================================================

  defp parse_lcov(content) do
    content
    |> String.split("end_of_record")
    |> Enum.filter(&String.contains?(&1, "SF:"))
    |> Enum.map(&parse_lcov_record/1)
  end

  defp parse_lcov_record(record) do
    lines = String.split(record, "\n")

    file_path =
      Enum.find_value(lines, "", fn line ->
        case String.split(line, ":", parts: 2) do
          ["SF", path] -> String.trim(path)
          _ -> nil
        end
      end)

    # Parse line coverage data
    line_data =
      lines
      |> Enum.filter(&String.starts_with?(&1, "DA:"))
      |> Enum.map(fn line ->
        case String.split(String.trim_leading(line, "DA:"), ",") do
          [_line_no, count] -> String.to_integer(count)
          _ -> 0
        end
      end)

    lines_total = length(line_data)
    lines_covered = Enum.count(line_data, &(&1 > 0))

    # Parse function coverage
    fn_total =
      Enum.find_value(lines, 0, fn line ->
        if String.starts_with?(line, "FNF:"),
          do: String.trim_leading(line, "FNF:") |> String.trim() |> String.to_integer()
      end)

    fn_covered =
      Enum.find_value(lines, 0, fn line ->
        if String.starts_with?(line, "FNH:"),
          do: String.trim_leading(line, "FNH:") |> String.trim() |> String.to_integer()
      end)

    # Parse branch coverage
    br_total =
      Enum.find_value(lines, 0, fn line ->
        if String.starts_with?(line, "BRF:"),
          do: String.trim_leading(line, "BRF:") |> String.trim() |> String.to_integer()
      end)

    br_covered =
      Enum.find_value(lines, 0, fn line ->
        if String.starts_with?(line, "BRH:"),
          do: String.trim_leading(line, "BRH:") |> String.trim() |> String.to_integer()
      end)

    %{
      runtime: "elixir",
      module_name: extract_module_name(file_path),
      file_path: file_path,
      lines_total: lines_total,
      lines_covered: lines_covered,
      lines_missed: lines_total - lines_covered,
      branches_total: br_total,
      branches_covered: br_covered,
      functions_total: fn_total,
      functions_covered: fn_covered,
      fractal_layer: estimate_layer(file_path),
      domain: extract_domain(file_path),
      uncovered_lines: "[]"
    }
  end

  # ============================================================
  # DATABASE
  # ============================================================

  defp write_coverage(run_id, records) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")
    Exqlite.Sqlite3.execute(db, "PRAGMA busy_timeout = 5000")

    sql = """
    INSERT INTO coverage_data (run_id, runtime, module_name, file_path,
      lines_total, lines_covered, lines_missed,
      branches_total, branches_covered,
      functions_total, functions_covered,
      fractal_layer, domain, uncovered_lines)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)
    """

    Exqlite.Sqlite3.execute(db, "BEGIN TRANSACTION")
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Enum.each(records, fn r ->
      Exqlite.Sqlite3.bind(stmt, [
        run_id,
        r.runtime,
        r.module_name,
        r.file_path,
        r.lines_total,
        r.lines_covered,
        r.lines_missed,
        Map.get(r, :branches_total, 0),
        Map.get(r, :branches_covered, 0),
        Map.get(r, :functions_total, 0),
        Map.get(r, :functions_covered, 0),
        r.fractal_layer,
        r.domain,
        r.uncovered_lines
      ])

      Exqlite.Sqlite3.step(db, stmt)
      Exqlite.Sqlite3.reset(stmt)
    end)

    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.execute(db, "COMMIT")
    Exqlite.Sqlite3.close(db)

    length(records)
  end

  defp update_run_coverage(run_id, records) do
    total_lines = records |> Enum.map(& &1.lines_total) |> Enum.sum()
    covered_lines = records |> Enum.map(& &1.lines_covered) |> Enum.sum()

    coverage_pct =
      if total_lines > 0 do
        Float.round(covered_lines / total_lines * 100, 2)
      else
        0.0
      end

    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")

    sql = "UPDATE test_runs SET line_coverage = ?1 WHERE id = ?2"
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [coverage_pct, run_id])
    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp extract_module_name(path) do
    path
    |> Path.basename(".ex")
    |> Macro.camelize()
  end

  defp estimate_layer(path) do
    cond do
      String.contains?(path, "/core/") -> "L1"
      String.contains?(path, "/holon/") -> "L3"
      String.contains?(path, "/mesh/") -> "L4"
      String.contains?(path, "/cluster/") -> "L6"
      String.contains?(path, "/web/") -> "L5"
      String.contains?(path, "/cockpit/") -> "L5"
      true -> "L2"
    end
  end

  defp extract_domain(path) do
    cond do
      String.contains?(path, "/analytics/") -> "analytics"
      String.contains?(path, "/mesh/") -> "mesh"
      String.contains?(path, "/observability/") -> "observability"
      String.contains?(path, "/security/") -> "security"
      String.contains?(path, "/holon/") -> "holon"
      String.contains?(path, "/cortex/") -> "cortex"
      String.contains?(path, "/ai/") -> "ai"
      String.contains?(path, "/cockpit/") -> "cockpit"
      String.contains?(path, "/testing/") -> "testing"
      String.contains?(path, "/validation/") -> "validation"
      true -> "general"
    end
  end
end
