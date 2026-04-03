defmodule Indrajaal.KMS.Panspermia.FormatTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Panspermia.Format.
  Tests the namespace module: available/0, valid_format?/1, and defdelegate surface.
  STAMP: SC-SMRITI-085 (human-readable), SC-SMRITI-086 (content integrity)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Panspermia.Format

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Format)
    end

    test "exports available/0" do
      assert function_exported?(Format, :available, 0)
    end

    test "exports valid_format?/1" do
      assert function_exported?(Format, :valid_format?, 1)
    end
  end

  describe "available/0" do
    test "returns a list of format modules" do
      formats = Format.available()
      assert is_list(formats)
      assert length(formats) == 3
    end

    test "includes Markdown format" do
      formats = Format.available()
      assert Indrajaal.KMS.Panspermia.Format.Markdown in formats
    end

    test "includes OrgMode format" do
      formats = Format.available()
      assert Indrajaal.KMS.Panspermia.Format.OrgMode in formats
    end

    test "includes Obsidian format" do
      formats = Format.available()
      assert Indrajaal.KMS.Panspermia.Format.Obsidian in formats
    end
  end

  describe "valid_format?/1" do
    test "returns true for :markdown" do
      assert Format.valid_format?(:markdown) == true
    end

    test "returns true for :org_mode" do
      assert Format.valid_format?(:org_mode) == true
    end

    test "returns true for :obsidian" do
      assert Format.valid_format?(:obsidian) == true
    end

    test "returns true for :json" do
      assert Format.valid_format?(:json) == true
    end

    test "returns true for :sqlite" do
      assert Format.valid_format?(:sqlite) == true
    end

    test "returns false for unknown format" do
      assert Format.valid_format?(:word_docx) == false
    end

    test "returns false for non-atom" do
      # Contract: takes atom only
      assert Format.valid_format?(:totally_unknown_sprint54) == false
    end
  end

  describe "delegate functions" do
    test "exports markdown/3" do
      assert function_exported?(Format, :markdown, 3)
    end

    test "exports org_mode/3" do
      assert function_exported?(Format, :org_mode, 3)
    end

    test "exports obsidian_index/1" do
      assert function_exported?(Format, :obsidian_index, 1)
    end

    test "exports obsidian_note/2" do
      assert function_exported?(Format, :obsidian_note, 2)
    end
  end
end
