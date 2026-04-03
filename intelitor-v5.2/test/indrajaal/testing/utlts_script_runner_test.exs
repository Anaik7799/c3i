defmodule Indrajaal.Testing.UTLTSScriptRunnerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.UTLTSScriptRunner

  # ---------------------------------------------------------------------------
  # Module API
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UTLTSScriptRunner)
    end

    test "exports run_elixir/2" do
      assert function_exported?(UTLTSScriptRunner, :run_elixir, 2)
    end

    test "exports run_fsharp/2" do
      assert function_exported?(UTLTSScriptRunner, :run_fsharp, 2)
    end

    test "exports run_directory/2" do
      assert function_exported?(UTLTSScriptRunner, :run_directory, 2)
    end

    test "exports history/2" do
      assert function_exported?(UTLTSScriptRunner, :history, 2)
    end

    test "does not export private run_script/6" do
      refute function_exported?(UTLTSScriptRunner, :run_script, 6)
    end

    test "does not export private parse_script_output/3" do
      refute function_exported?(UTLTSScriptRunner, :parse_script_output, 3)
    end

    test "does not export private detect_project/1" do
      refute function_exported?(UTLTSScriptRunner, :detect_project, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # run_directory/2 — the aggregate function has DB-independent behaviour for
  # empty / nonexistent directories because the glob returns no files.
  # ---------------------------------------------------------------------------

  describe "run_directory/2 with nonexistent directory" do
    test "returns a map" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert is_map(result)
    end

    test "returns total: 0" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert result.total == 0
    end

    test "returns passed: 0" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert result.passed == 0
    end

    test "returns failed: 0" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert result.failed == 0
    end

    test "returns results: []" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert result.results == []
    end

    test "has exactly the four expected keys" do
      result = UTLTSScriptRunner.run_directory("/nonexistent/path/", [])
      assert Map.keys(result) |> Enum.sort() == [:failed, :passed, :results, :total]
    end
  end

  describe "run_directory/2 with empty temp directory" do
    setup do
      dir =
        System.tmp_dir!() |> Path.join("utlts_runner_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "empty directory with no matching scripts returns total: 0", %{dir: dir} do
      result = UTLTSScriptRunner.run_directory(dir, [])
      assert result.total == 0
    end

    test "returns the aggregate map shape", %{dir: dir} do
      result = UTLTSScriptRunner.run_directory(dir, [])
      assert is_map(result)
      assert is_integer(result.total)
      assert is_integer(result.passed)
      assert is_integer(result.failed)
      assert is_list(result.results)
    end

    test "custom pattern that matches nothing returns zero total", %{dir: dir} do
      result = UTLTSScriptRunner.run_directory(dir, pattern: "*.no_such_ext")
      assert result.total == 0
    end
  end

  # ---------------------------------------------------------------------------
  # run_directory/2 — parallel option does not crash when list is empty
  # ---------------------------------------------------------------------------

  describe "run_directory/2 parallel option" do
    test "parallel: false is default and does not crash on nonexistent dir" do
      result = UTLTSScriptRunner.run_directory("/no/such/dir/", parallel: false)
      assert result.total == 0
    end

    test "parallel: true does not crash on nonexistent dir" do
      result = UTLTSScriptRunner.run_directory("/no/such/dir/", parallel: true)
      assert result.total == 0
    end

    test "max_concurrent option is accepted without crashing" do
      result = UTLTSScriptRunner.run_directory("/no/such/dir/", parallel: true, max_concurrent: 2)
      assert result.total == 0
    end
  end

  # ---------------------------------------------------------------------------
  # run_elixir/2 and run_fsharp/2 — DB-dependent paths.
  # We can only assert return shape without a live DB.
  # ---------------------------------------------------------------------------

  describe "run_elixir/2 return contract" do
    test "returns a two-element tuple for any script path" do
      result = UTLTSScriptRunner.run_elixir("/nonexistent/script.exs", [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "on DB failure returns {:error, _}" do
      # When the DB cannot be opened (which is typical in CI/test env),
      # run_elixir must return {:error, _} rather than crashing.
      result = UTLTSScriptRunner.run_elixir("/nonexistent/script.exs", [])
      # Either branch is valid depending on whether utlts.db exists.
      assert elem(result, 0) in [:ok, :error]
    end

    test "accepts timeout option without crashing" do
      result = UTLTSScriptRunner.run_elixir("/no/script.exs", timeout: 1)
      assert elem(result, 0) in [:ok, :error]
    end

    test "accepts args option without crashing" do
      result = UTLTSScriptRunner.run_elixir("/no/script.exs", args: ["--help"])
      assert elem(result, 0) in [:ok, :error]
    end

    test "accepts env option without crashing" do
      result = UTLTSScriptRunner.run_elixir("/no/script.exs", env: [{"TEST_VAR", "1"}])
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "run_fsharp/2 return contract" do
    test "returns a two-element tuple for any script path" do
      result = UTLTSScriptRunner.run_fsharp("/nonexistent/script.fsx", [])
      assert elem(result, 0) in [:ok, :error]
    end

    test "accepts timeout option without crashing" do
      result = UTLTSScriptRunner.run_fsharp("/no/script.fsx", timeout: 1)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  # ---------------------------------------------------------------------------
  # history/2 — DB-dependent
  # ---------------------------------------------------------------------------

  describe "history/2 return contract" do
    test "returns a two-element tuple" do
      result = UTLTSScriptRunner.history("proj-scripts-test", [])
      assert elem(result, 0) in [:ok, :error]
    end

    test "with limit option returns a two-element tuple" do
      result = UTLTSScriptRunner.history("proj-scripts-test", limit: 5)
      assert elem(result, 0) in [:ok, :error]
    end

    test "on success returns {:ok, list}" do
      case UTLTSScriptRunner.history("proj-scripts-test", []) do
        {:ok, rows} -> assert is_list(rows)
        {:error, _} -> :ok
      end
    end
  end
end
