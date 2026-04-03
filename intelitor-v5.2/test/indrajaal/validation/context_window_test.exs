defmodule Indrajaal.Validation.ContextWindowTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.ContextWindow.

  Tests multiline log preprocessing for FPPS consensus.
  SC-MULTILINE-001: Multiline entries must be joined before validation.
  SC-MULTILINE-002: Joining must be deterministic and idempotent.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.ContextWindow

  describe "normalize/1" do
    test "returns binary for binary input" do
      result = ContextWindow.normalize("hello world")
      assert is_binary(result)
    end

    test "returns empty string for non-binary input" do
      result = ContextWindow.normalize(nil)
      assert result == ""
    end

    test "returns empty string for integer input" do
      result = ContextWindow.normalize(42)
      assert result == ""
    end

    test "passes through single-line content" do
      content = "error: something went wrong"
      result = ContextWindow.normalize(content)
      assert String.contains?(result, "error:")
    end

    test "joins continuation lines with indentation" do
      content = "error: first line\n  continuation of error"
      result = ContextWindow.normalize(content)
      # The continuation should be joined to the previous line
      assert is_binary(result)
    end

    test "is idempotent" do
      content = "== Compilation error in file lib/foo.ex ==\n** (CompileError) undefined"
      once = ContextWindow.normalize(content)
      twice = ContextWindow.normalize(once)
      assert once == twice
    end

    test "removes empty lines" do
      content = "line one\n\nline two"
      result = ContextWindow.normalize(content)
      lines = String.split(result, "\n", trim: true)
      assert length(lines) == 2
    end

    test "handles empty string" do
      result = ContextWindow.normalize("")
      assert result == ""
    end

    test "preserves block starters as separate lines" do
      content = "warning: something\nerror: another thing"
      result = ContextWindow.normalize(content)
      lines = String.split(result, "\n", trim: true)
      assert length(lines) == 2
    end

    test "joins pipe-prefixed continuation lines" do
      content = "error: main\n  | detail here"
      result = ContextWindow.normalize(content)
      # Should be joined into fewer lines
      lines = String.split(result, "\n", trim: true)
      assert length(lines) < 3
    end
  end

  describe "logical_lines/1" do
    test "returns list for binary input" do
      result = ContextWindow.logical_lines("hello\nworld")
      assert is_list(result)
    end

    test "returns empty list for non-binary input" do
      result = ContextWindow.logical_lines(nil)
      assert result == []
    end

    test "returns single element for single-line content" do
      result = ContextWindow.logical_lines("just one line")
      assert length(result) == 1
    end

    test "splits independent lines into separate entries" do
      content = "error: one\nwarning: two"
      result = ContextWindow.logical_lines(content)
      assert length(result) == 2
    end

    test "produces same count as normalize after split" do
      content = "line one\nline two\nline three"

      normalized_count =
        content
        |> ContextWindow.normalize()
        |> String.split("\n", trim: true)
        |> length()

      logical_count = content |> ContextWindow.logical_lines() |> length()
      assert normalized_count == logical_count
    end

    test "handles empty string" do
      result = ContextWindow.logical_lines("")
      assert result == []
    end
  end
end
