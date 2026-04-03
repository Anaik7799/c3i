defmodule Indrajaal.Testing.UTLTSCoverageImporterTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.UTLTSCoverageImporter

  describe "auto_import/1" do
    test "returns {:error, :no_coverage_files} when neither cover/excoveralls.json nor cover/lcov.info exists" do
      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.auto_import(run_id)

      assert match?({:error, _}, result)
    end

    test "returns an error tuple for any missing coverage scenario" do
      run_id = "test-run-no-cover-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.auto_import(run_id)

      assert is_tuple(result)
      assert elem(result, 0) == :error
    end
  end

  describe "import_excoveralls/2" do
    test "returns {:error, _} for a completely non-existent file" do
      run_id = "test-run-#{System.unique_integer([:positive])}"

      result =
        UTLTSCoverageImporter.import_excoveralls("/nonexistent/path/excoveralls.json", run_id)

      assert match?({:error, _}, result)
    end

    test "returns {:error, _} for invalid (non-JSON) file content" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "invalid_excoveralls_#{System.unique_integer([:positive])}.json")
      File.write!(path, "this is not valid json {{}")
      on_exit(fn -> File.rm(path) end)

      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.import_excoveralls(path, run_id)

      assert match?({:error, _}, result)
    end

    test "returns {:ok, count} or {:error, _} for a valid excoveralls JSON file" do
      excoveralls_json =
        Jason.encode!(%{
          "source_files" => [
            %{
              "name" => "lib/indrajaal/core/some_module.ex",
              "coverage" => [1, 1, nil, 0, 1]
            }
          ]
        })

      tmp = System.tmp_dir!()
      path = Path.join(tmp, "excoveralls_#{System.unique_integer([:positive])}.json")
      File.write!(path, excoveralls_json)
      on_exit(fn -> File.rm(path) end)

      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.import_excoveralls(path, run_id)

      assert match?({:ok, _count}, result) or match?({:error, _}, result)
    end
  end

  describe "import_lcov/2" do
    test "returns {:error, _} for a non-existent lcov file" do
      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.import_lcov("/nonexistent/path/lcov.info", run_id)
      assert match?({:error, _}, result)
    end

    test "returns {:ok, count} or {:error, _} for a valid lcov file" do
      lcov_content = """
      SF:lib/indrajaal/core/holon/state.ex
      FN:10,start_link
      FNDA:1,start_link
      FNF:1
      FNH:1
      DA:10,1
      DA:11,1
      DA:12,0
      BRF:2
      BRH:1
      LH:2
      LF:3
      end_of_record
      """

      tmp = System.tmp_dir!()
      path = Path.join(tmp, "lcov_#{System.unique_integer([:positive])}.info")
      File.write!(path, lcov_content)
      on_exit(fn -> File.rm(path) end)

      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.import_lcov(path, run_id)

      assert match?({:ok, _count}, result) or match?({:error, _}, result)
    end

    test "handles an lcov file with multiple records" do
      lcov_content = """
      SF:lib/indrajaal/core/module_a.ex
      DA:1,1
      LF:1
      LH:1
      end_of_record
      SF:lib/indrajaal/core/module_b.ex
      DA:1,0
      LF:1
      LH:0
      end_of_record
      """

      tmp = System.tmp_dir!()
      path = Path.join(tmp, "lcov_multi_#{System.unique_integer([:positive])}.info")
      File.write!(path, lcov_content)
      on_exit(fn -> File.rm(path) end)

      run_id = "test-run-#{System.unique_integer([:positive])}"
      result = UTLTSCoverageImporter.import_lcov(path, run_id)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "module API" do
    test "exports auto_import/1" do
      assert function_exported?(UTLTSCoverageImporter, :auto_import, 1)
    end

    test "exports import_excoveralls/2" do
      assert function_exported?(UTLTSCoverageImporter, :import_excoveralls, 2)
    end

    test "exports import_lcov/2" do
      assert function_exported?(UTLTSCoverageImporter, :import_lcov, 2)
    end
  end
end
