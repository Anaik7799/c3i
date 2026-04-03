defmodule Indrajaal.Validation.FPPSLineByLineTest do
  @moduledoc """
  TDG-compliant test suite for FPPSLineByLine.

  Tests the line-by-line validation method used in FPPS 5-point consensus.
  Covers validate_log_content/1, validate_file/1, validate/3, and helper logic.

  ## STAMP Constraints Verified
  - SC-SIL6-023: FPPS 3/5 consensus required
  - SC-VAL-001: Patient Mode validation only
  - SC-DOC-001: moduledoc required
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Validation.FPPSLineByLine

  # ---------------------------------------------------------------------------
  # validate_log_content/1
  # ---------------------------------------------------------------------------

  describe "validate_log_content/1" do
    test "returns method :line_by_line for valid binary" do
      result = FPPSLineByLine.validate_log_content("clean compilation output")
      assert result.method == :line_by_line
    end

    test "returns zero errors and zero warnings for clean log" do
      result = FPPSLineByLine.validate_log_content("Compiled 100 files in 10s")
      assert result.errors == 0
      assert result.warnings == 0
    end

    test "detects 'error:' literal as category 1" do
      result = FPPSLineByLine.validate_log_content("lib/foo.ex:10: error: undefined variable")
      assert result.errors >= 1
    end

    test "detects 'compilation error' as a distinct error category" do
      result = FPPSLineByLine.validate_log_content("compilation error in lib/bar.ex")
      assert result.errors >= 1
    end

    test "detects '** (' exception prefix as error category" do
      result = FPPSLineByLine.validate_log_content("** (ArgumentError) message")
      assert result.errors >= 1
    end

    test "detects named exception types as error category" do
      result = FPPSLineByLine.validate_log_content("an argumenterror occurred")
      assert result.errors >= 1
    end

    test "detects 'undefined variable' as error category 5" do
      result = FPPSLineByLine.validate_log_content("undefined variable x in function foo/0")
      assert result.errors >= 1
    end

    test "detects 'cannot compile module' as error category" do
      result = FPPSLineByLine.validate_log_content("cannot compile module Foo.Bar")
      assert result.errors >= 1
    end

    test "detects 'syntax error' as error category" do
      result = FPPSLineByLine.validate_log_content("syntax error near '}'")
      assert result.errors >= 1
    end

    test "detects 'warning:' as warning category 1" do
      result = FPPSLineByLine.validate_log_content("lib/foo.ex:5: warning: unused variable x")
      assert result.warnings >= 1
    end

    test "detects 'deprecated' as warning category 2" do
      result = FPPSLineByLine.validate_log_content("deprecated function foo/1 use bar/1 instead")
      assert result.warnings >= 1
    end

    test "detects 'unused' as warning category 3" do
      result = FPPSLineByLine.validate_log_content("unused variable _result")
      assert result.warnings >= 1
    end

    test "detects 'shadowed' as warning category 4" do
      result = FPPSLineByLine.validate_log_content("shadowed binding of x")
      assert result.warnings >= 1
    end

    test "detects 'unreachable' as warning category 5" do
      result = FPPSLineByLine.validate_log_content("code unreachable after this expression")
      assert result.warnings >= 1
    end

    test "multiple error categories in one log count distinctly" do
      log = "error: foo\ncompilation error\n** (RuntimeError)"
      result = FPPSLineByLine.validate_log_content(log)
      assert result.errors >= 2
    end

    test "same error category repeated does not double-count" do
      log = "error: foo\nerror: bar\nerror: baz"
      result = FPPSLineByLine.validate_log_content(log)
      # All lines match category 1 — still just 1 category
      assert result.errors == 1
    end

    test "non-binary input returns zero errors and warnings" do
      result = FPPSLineByLine.validate_log_content(nil)
      assert result.method == :line_by_line
      assert result.errors == 0
      assert result.warnings == 0
    end

    test "empty string returns zero errors and warnings" do
      result = FPPSLineByLine.validate_log_content("")
      assert result.errors == 0
      assert result.warnings == 0
    end

    test "maximum category counts do not exceed defined limits" do
      # 10 error categories + 5 warning categories defined
      massive_log = """
      error: e1
      compilation error
      ** (ArgumentError)
      runtimeerror happened
      undefined variable x
      cannot compile module Foo
      syntax error found
      (exit) process terminated
      dialyzed with errors
      found 1 issue
      warning: unused
      deprecated use new/1
      unused variable x
      shadowed variable y
      unreachable code here
      """

      result = FPPSLineByLine.validate_log_content(massive_log)
      assert result.errors <= 10
      assert result.warnings <= 5
    end
  end

  # ---------------------------------------------------------------------------
  # validate_file/1 — public single-file entry point
  # ---------------------------------------------------------------------------

  describe "validate_file/1" do
    test "returns error tuple for unsupported file types" do
      result = FPPSLineByLine.validate_file("some_file.txt")
      assert {:error, {:unsupported_file_type, _}} = result
    end

    test "returns error tuple for unsupported .py extension" do
      result = FPPSLineByLine.validate_file("script.py")
      assert {:error, {:unsupported_file_type, "script.py"}} = result
    end

    test "returns ok tuple with violations list for a .ex path (file may not exist)" do
      # For a non-existent file the analyze step reads nothing and returns empty
      result = FPPSLineByLine.validate_file("/tmp/nonexistent_fpps_test.ex")
      assert {:ok, violations} = result
      assert is_list(violations)
    end

    test "returns ok tuple with violations list for a .exs path" do
      result = FPPSLineByLine.validate_file("/tmp/nonexistent_fpps_test.exs")
      assert {:ok, violations} = result
      assert is_list(violations)
    end

    test "returns ok tuple for a .md file path" do
      result = FPPSLineByLine.validate_file("/tmp/nonexistent_fpps_test.md")
      assert {:ok, violations} = result
      assert is_list(violations)
    end

    test "returns ok tuple for a .fs file path" do
      result = FPPSLineByLine.validate_file("/tmp/nonexistent_fpps_test.fs")
      assert {:ok, violations} = result
      assert is_list(violations)
    end
  end

  # ---------------------------------------------------------------------------
  # get_result/2 — consensus shortcut
  # ---------------------------------------------------------------------------

  describe "get_result/2" do
    test "returns :unknown when no files found at path" do
      result = FPPSLineByLine.get_result("/tmp/no_such_fpps_dir_xyz", :elixir)
      assert result == :unknown
    end

    test "returns a valid result atom for :documentation type" do
      result = FPPSLineByLine.get_result("/tmp/no_such_fpps_dir_xyz", :documentation)
      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end
  end

  # ---------------------------------------------------------------------------
  # validate/3 dispatch
  # ---------------------------------------------------------------------------

  describe "validate/3 dispatch" do
    test "dispatches :elixir type and returns error for missing path" do
      result = FPPSLineByLine.validate("/tmp/no_such_fpps_elixir_dir", :elixir)
      assert {:error, {:no_files_found, _}} = result
    end

    test "dispatches :fsharp type and returns error for missing path" do
      result = FPPSLineByLine.validate("/tmp/no_such_fpps_fs_dir", :fsharp)
      assert {:error, {:no_files_found, _}} = result
    end

    test "dispatches :config type and returns error for missing path" do
      result = FPPSLineByLine.validate("/tmp/no_such_fpps_cfg_dir", :config)
      assert {:error, {:no_files_found, _}} = result
    end

    test "dispatches :documentation type and returns error for missing path" do
      result = FPPSLineByLine.validate("/tmp/no_such_fpps_doc_dir", :documentation)
      assert {:error, {:no_files_found, _}} = result
    end
  end

  # ---------------------------------------------------------------------------
  # validate_elixir_files/2 and validate_fsharp_files/2 directly
  # ---------------------------------------------------------------------------

  describe "validate_elixir_files/2" do
    test "returns error tuple when no .ex files found at path" do
      result = FPPSLineByLine.validate_elixir_files("/tmp/no_such_fpps_dir_abc")
      assert {:error, {:no_files_found, _}} = result
    end

    test "returns ok report when files exist" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "fpps_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(path)
      file = Path.join(path, "test_module.ex")

      File.write!(file, """
      defmodule MyTestModule do
        @moduledoc "hello"
        def foo, do: :ok
      end
      """)

      result = FPPSLineByLine.validate_elixir_files(path)
      assert {:ok, report} = result
      assert report.file_count >= 1
      assert is_integer(report.line_count)
      assert is_list(report.violations)
      assert report.result in [:healthy, :degraded, :unhealthy]
      assert is_float(report.stamp_compliance)
      assert is_float(report.confidence)

      File.rm_rf!(path)
    end
  end

  describe "validate_fsharp_files/2" do
    test "returns error tuple when no .fs files found at path" do
      result = FPPSLineByLine.validate_fsharp_files("/tmp/no_such_fpps_fs_dir_abc")
      assert {:error, {:no_files_found, _}} = result
    end

    test "returns ok report when .fs file exists" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "fpps_fs_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(path)
      file = Path.join(path, "Module.fs")
      File.write!(file, "let x = 1\nlet mutable y = 2\nfailwith \"oops\"\n")

      result = FPPSLineByLine.validate_fsharp_files(path)
      assert {:ok, report} = result
      # Mutable violation should appear
      assert is_list(report.violations)
      assert report.file_count == 1

      File.rm_rf!(path)
    end
  end

  describe "validate_documentation/2" do
    test "returns error when no .md files at path" do
      result = FPPSLineByLine.validate_documentation("/tmp/no_such_fpps_docs_dir_abc")
      assert {:error, {:no_files_found, _}} = result
    end

    test "returns ok report when .md file exists" do
      tmp = System.tmp_dir!()
      path = Path.join(tmp, "fpps_docs_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(path)
      file = Path.join(path, "README.md")
      File.write!(file, "# Title\n\nSome content.\n")

      result = FPPSLineByLine.validate_documentation(path)
      assert {:ok, report} = result
      assert report.file_count == 1

      File.rm_rf!(path)
    end
  end
end
