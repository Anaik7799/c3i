defmodule Indrajaal.KMS.Panspermia.Format.ObsidianTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Panspermia.Format.Obsidian.
  Tests render_index/1 and render_note/2 — pure string generation.
  STAMP: SC-SMRITI-082 (vault config), SC-SMRITI-083 (YAML frontmatter)
  Constitutional: Ψ₁ (Regeneration), Ψ₂ (History)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Panspermia.Format.Obsidian

  @sample_entry %{
    id: "entry_sprint54_obs_001",
    content: "# Obsidian Test Entry\n\nThis entry tests Obsidian vault rendering.",
    metadata: %{"category" => "testing", "tags" => ["sprint54", "obsidian"]},
    created_at: "2026-03-19T10:00:00Z",
    updated_at: "2026-03-19T10:00:00Z",
    checksum: "dead1234beef5678"
  }

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Obsidian)
    end

    test "exports render_index/1" do
      assert function_exported?(Obsidian, :render_index, 1)
    end

    test "exports render_note/2" do
      assert function_exported?(Obsidian, :render_note, 2)
    end
  end

  describe "render_index/1" do
    test "returns a non-empty string" do
      result = Obsidian.render_index([@sample_entry])
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "output contains YAML frontmatter" do
      result = Obsidian.render_index([@sample_entry])
      assert String.contains?(result, "---")
    end

    test "output contains title" do
      result = Obsidian.render_index([@sample_entry])
      assert String.contains?(result, "SMRITI Knowledge Index")
    end

    test "renders empty entry list" do
      result = Obsidian.render_index([])
      assert is_binary(result)
    end

    test "output is valid UTF-8" do
      result = Obsidian.render_index([@sample_entry])
      assert String.valid?(result)
    end
  end

  describe "render_note/2" do
    test "returns a non-empty string" do
      result = Obsidian.render_note(@sample_entry)
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "output contains YAML frontmatter with entry ID" do
      result = Obsidian.render_note(@sample_entry)
      assert String.contains?(result, "entry_sprint54_obs_001")
    end

    test "output contains the entry content" do
      result = Obsidian.render_note(@sample_entry)
      assert String.contains?(result, "Obsidian Test Entry")
    end

    test "render_note without metadata works" do
      result = Obsidian.render_note(@sample_entry, false)
      assert is_binary(result)
    end

    test "output is valid UTF-8" do
      result = Obsidian.render_note(@sample_entry)
      assert String.valid?(result)
    end
  end
end
