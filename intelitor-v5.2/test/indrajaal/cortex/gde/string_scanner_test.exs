defmodule Indrajaal.Cortex.GDE.StringScannerTest do
  @moduledoc """
  TDG Tests for GDE StringScanner module.

  Tests pattern-based log parsing for error extraction.

  STAMP Constraints:
  - SC-GDE-030: Patterns must be deterministic
  - SC-GDE-031: Must handle malformed input gracefully
  - SC-GDE-032: Capture groups must be named
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cortex.GDE.StringScanner

  # ============================================================
  # PATTERN CONSTRUCTION TESTS
  # ============================================================

  describe "pattern/1" do
    test "creates pattern from keyword list" do
      pattern =
        StringScanner.pattern(
          literal: "Error:",
          capture: :message
        )

      assert is_list(pattern)
      assert length(pattern) == 2
    end

    test "normalizes pattern elements" do
      pattern =
        StringScanner.pattern([
          {:literal, "test"},
          {:capture, :name},
          {:skip_whitespace, true}
        ])

      assert {:literal, "test"} in pattern
      assert {:capture, :name} in pattern
    end
  end

  describe "pattern_from_string/1" do
    test "parses format string with captures" do
      pattern = StringScanner.pattern_from_string("Error: {message}")

      assert is_list(pattern)
      # Should have literal "Error: " and capture :message
      assert Enum.any?(pattern, fn
               {:literal, "Error: "} -> true
               _ -> false
             end)

      assert Enum.any?(pattern, fn
               {:capture, :message} -> true
               _ -> false
             end)
    end
  end

  # ============================================================
  # SCANNING TESTS
  # ============================================================

  describe "scan/2" do
    test "extracts captures from matching text" do
      pattern =
        StringScanner.pattern([
          {:literal, "Error: "},
          {:capture, :message}
        ])

      result = StringScanner.scan("Error: Something went wrong", pattern)

      assert {:ok, %{message: "Something went wrong"}} = result
    end

    test "returns error for non-matching text" do
      pattern =
        StringScanner.pattern([
          {:literal, "Error: "},
          {:capture, :message}
        ])

      result = StringScanner.scan("Warning: Something", pattern)

      assert {:error, :no_match} = result
    end

    test "handles multiple captures" do
      pattern =
        StringScanner.pattern([
          {:literal, "File: "},
          {:capture, :file},
          {:literal, " Line: "},
          {:capture, :line}
        ])

      result = StringScanner.scan("File: test.ex Line: 42", pattern)

      assert {:ok, captures} = result
      assert captures.file == "test.ex"
      assert captures.line == "42"
    end

    test "handles regex captures" do
      pattern =
        StringScanner.pattern([
          {:literal, "Line "},
          {:capture, :line, ~r/\d+/},
          {:literal, ":"}
        ])

      result = StringScanner.scan("Line 123: error message", pattern)

      assert {:ok, %{line: "123"}} = result
    end

    test "handles skip_whitespace" do
      pattern =
        StringScanner.pattern([
          {:literal, "Error:"},
          {:skip_whitespace},
          {:capture, :message}
        ])

      result = StringScanner.scan("Error:   Some message", pattern)

      assert {:ok, %{message: "Some message"}} = result
    end

    test "handles skip_until" do
      pattern =
        StringScanner.pattern([
          {:skip_until, "Error:"},
          {:literal, "Error: "},
          {:capture, :message}
        ])

      result = StringScanner.scan("Some prefix Error: The actual error", pattern)

      assert {:ok, %{message: "The actual error"}} = result
    end

    test "handles optional sections - present" do
      pattern =
        StringScanner.pattern([
          {:literal, "Error"},
          {:optional, [{:literal, " (fatal)"}]},
          {:literal, ": "},
          {:capture, :message}
        ])

      result = StringScanner.scan("Error (fatal): Critical failure", pattern)

      assert {:ok, %{message: "Critical failure"}} = result
    end

    test "handles optional sections - absent" do
      pattern =
        StringScanner.pattern([
          {:literal, "Error"},
          {:optional, [{:literal, " (fatal)"}]},
          {:literal, ": "},
          {:capture, :message}
        ])

      result = StringScanner.scan("Error: Minor issue", pattern)

      assert {:ok, %{message: "Minor issue"}} = result
    end
  end

  # ============================================================
  # SCAN_ALL TESTS
  # ============================================================

  describe "scan_all/3" do
    test "finds all matches in text" do
      pattern =
        StringScanner.pattern([
          {:literal, "warning: "},
          {:capture, :message}
        ])

      text = """
      warning: First warning
      some other text
      warning: Second warning
      more text
      warning: Third warning
      """

      results = StringScanner.scan_all(text, pattern)

      assert length(results) == 3
      assert Enum.at(results, 0).message == "First warning"
      assert Enum.at(results, 1).message == "Second warning"
      assert Enum.at(results, 2).message == "Third warning"
    end

    test "respects limit option" do
      pattern = StringScanner.builtin(:warning)

      text = """
      warning: One
      warning: Two
      warning: Three
      warning: Four
      """

      results = StringScanner.scan_all(text, pattern, limit: 2)

      assert length(results) == 2
    end
  end

  # ============================================================
  # MATCHES? TESTS
  # ============================================================

  describe "matches?/2" do
    test "returns true for matching text" do
      pattern = StringScanner.builtin(:compile_error)
      text = "** (CompileError) lib/test.ex:10: undefined function foo/0"

      assert StringScanner.matches?(text, pattern)
    end

    test "returns false for non-matching text" do
      pattern = StringScanner.builtin(:compile_error)
      text = "All tests passed"

      refute StringScanner.matches?(text, pattern)
    end
  end

  # ============================================================
  # BUILT-IN PATTERN TESTS
  # ============================================================

  describe "builtin/1" do
    test ":compile_error pattern" do
      pattern = StringScanner.builtin(:compile_error)
      text = "** (CompileError) lib/my_app/context.ex:42: undefined function bar/1"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.file == "lib/my_app/context.ex"
      assert captures.line == "42"
      assert captures.message == "undefined function bar/1"
    end

    test ":warning pattern" do
      pattern = StringScanner.builtin(:warning)
      text = "warning: variable x is unused"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.message == "variable x is unused"
    end

    test ":runtime_error pattern" do
      pattern = StringScanner.builtin(:runtime_error)
      text = "** (ArgumentError) argument error"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.error_type == "ArgumentError"
      assert captures.message == "argument error"
    end

    test ":undefined_function pattern" do
      pattern = StringScanner.builtin(:undefined_function)
      text = "undefined function my_func/2"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.function == "my_func"
      assert captures.arity == "2"
    end

    test ":undefined_module pattern" do
      pattern = StringScanner.builtin(:undefined_module)
      text = "undefined module MyApp.Context"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.module == "MyApp.Context"
    end

    test ":ash_error pattern" do
      pattern = StringScanner.builtin(:ash_error)
      text = "** (Ash.Error.Invalid) some validation failed"

      {:ok, captures} = StringScanner.scan(text, pattern)

      assert captures.error_type == "Invalid"
      assert captures.message == "some validation failed"
    end

    test "unknown pattern returns empty list" do
      pattern = StringScanner.builtin(:unknown_pattern)

      assert pattern == []
    end
  end

  # ============================================================
  # EXTRACTION HELPER TESTS
  # ============================================================

  describe "extract_compile_errors/1" do
    test "extracts all compile errors" do
      text = """
      Compiling 10 files (.ex)
      ** (CompileError) lib/a.ex:1: error one
      Some other output
      ** (CompileError) lib/b.ex:20: error two
      """

      errors = StringScanner.extract_compile_errors(text)

      assert length(errors) == 2
      assert Enum.at(errors, 0).file == "lib/a.ex"
      assert Enum.at(errors, 1).file == "lib/b.ex"
    end
  end

  describe "extract_warnings/1" do
    test "extracts all warnings" do
      text = """
      warning: first warning
      some code
      warning: second warning
      """

      warnings = StringScanner.extract_warnings(text)

      assert length(warnings) == 2
    end
  end

  describe "extract_error/1" do
    test "identifies compile error type" do
      text = "** (CompileError) lib/test.ex:5: undefined function"

      {:ok, result} = StringScanner.extract_error(text)

      assert result.type == :compile_error
      assert result.file == "lib/test.ex"
    end

    test "identifies runtime error type" do
      text = "** (RuntimeError) something went wrong"

      {:ok, result} = StringScanner.extract_error(text)

      assert result.type == :runtime_error
    end

    test "returns unknown for unrecognized errors" do
      text = "some random text with no error pattern"

      result = StringScanner.extract_error(text)

      assert result == {:error, :unknown}
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "scan is deterministic" do
      pattern = StringScanner.builtin(:warning)

      forall msg <- PC.utf8() do
        text = "warning: #{msg}"
        result1 = StringScanner.scan(text, pattern)
        result2 = StringScanner.scan(text, pattern)

        result1 == result2
      end
    end

    property "empty pattern matches any text" do
      forall text <- PC.utf8() do
        result = StringScanner.scan(text, [])
        match?({:ok, %{}}, result)
      end
    end

    property "handles malformed input gracefully" do
      forall text <- PC.binary() do
        # Should never raise, always return ok or error tuple
        try do
          pattern = StringScanner.builtin(:compile_error)
          result = StringScanner.scan(text, pattern)
          match?({:ok, _}, result) or match?({:error, _}, result)
        rescue
          _ -> false
        end
      end
    end
  end
end
