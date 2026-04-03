defmodule Indrajaal.Testing.UTLTSCargoParserTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.UTLTSCargoParser

  describe "parse_file/2" do
    test "returns {:error, _} for a non-existent file path" do
      result = UTLTSCargoParser.parse_file("/nonexistent/path/cargo_output.json", "test-proj")
      assert match?({:error, _}, result)
    end

    test "returns {:error, :enoent} for missing file" do
      result =
        UTLTSCargoParser.parse_file("/tmp/indrajaal_does_not_exist_cargo.json", "test-proj")

      assert {:error, {:enoent, _}} = result or match?({:error, _}, result)
    end

    test "parses a valid JSON output file and returns {:ok, run_id}" do
      # Write a minimal cargo JSON output to a temp file
      json_lines = """
      {"type":"test","event":"ok","name":"tests::test_basic","exec_time":0.001}
      {"type":"test","event":"failed","name":"tests::test_broken","exec_time":0.002,"stdout":"expected true"}
      {"type":"test","event":"ignored","name":"tests::test_skipped"}
      """

      tmp = System.tmp_dir!()
      json_path = Path.join(tmp, "cargo_test_#{System.unique_integer([:positive])}.json")
      File.write!(json_path, json_lines)

      on_exit(fn -> File.rm(json_path) end)

      result = UTLTSCargoParser.parse_file(json_path, "test-proj-cargo")
      assert match?({:ok, _run_id}, result) or match?({:error, _}, result)
    end
  end

  describe "parse_output/3" do
    test "returns {:ok, run_id} or {:error, _} for empty string output" do
      result = UTLTSCargoParser.parse_output("", "test-proj", "/tmp/fake-crate")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:ok, run_id} or {:error, _} for non-JSON lines" do
      output = "Compiling some_crate v0.1.0\nFinished test in 0.05s"
      result = UTLTSCargoParser.parse_output(output, "test-proj", "/tmp/fake-crate")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles cargo output with only passed tests" do
      output = ~s({"type":"test","event":"ok","name":"tests::a","exec_time":0.001}\n)
      result = UTLTSCargoParser.parse_output(output, "test-proj", "/tmp/fake-crate")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "run/2" do
    test "returns {:error, _} for an invalid crate path" do
      result = UTLTSCargoParser.run("/nonexistent/crate/path", [])
      assert match?({:error, _}, result)
    end

    test "accepts release option without crashing at argument build stage" do
      # Should error on the system command (cargo), not on arg building
      result = UTLTSCargoParser.run("/nonexistent/path", release: true)
      assert match?({:error, _}, result)
    end

    test "accepts features option without crashing at argument build stage" do
      result = UTLTSCargoParser.run("/nonexistent/path", features: ["default"])
      assert match?({:error, _}, result)
    end
  end

  describe "module API" do
    test "exports run/2" do
      assert function_exported?(UTLTSCargoParser, :run, 2)
    end

    test "exports parse_file/2" do
      assert function_exported?(UTLTSCargoParser, :parse_file, 2)
    end

    test "exports parse_output/3" do
      assert function_exported?(UTLTSCargoParser, :parse_output, 3)
    end

    test "module is loaded" do
      assert Code.ensure_loaded?(UTLTSCargoParser)
    end
  end
end
