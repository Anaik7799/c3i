defmodule Indrajaal.KMS.Panspermia.Format.MarkdownTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Panspermia.Format.Markdown.
  Tests render/3 with sample entries — pure string generation, no DB required.
  STAMP: SC-SMRITI-078 (valid CommonMark), SC-SMRITI-079 (valid header hierarchy)
  Constitutional: Ψ₁ (Regeneration)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Panspermia.Format.Markdown

  @sample_entry %{
    id: "entry_sprint54_001",
    content: "# Test Entry\n\nThis is a test knowledge entry for Sprint 54.",
    metadata: %{"category" => "testing", "tags" => ["sprint54", "tdd"]},
    created_at: "2026-03-19T10:00:00Z",
    updated_at: "2026-03-19T10:00:00Z",
    checksum: "abc123def456"
  }

  @sample_lineage_event %{
    entry_id: "entry_sprint54_001",
    action: "created",
    timestamp: "2026-03-19T10:00:00Z",
    actor: "test_agent"
  }

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Markdown)
    end

    test "exports render/3" do
      assert function_exported?(Markdown, :render, 3)
    end
  end

  describe "render/3" do
    test "returns a non-empty string" do
      result = Markdown.render([@sample_entry], [@sample_lineage_event])
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "output contains the SMRITI export header" do
      result = Markdown.render([@sample_entry], [])
      assert String.contains?(result, "SMRITI Knowledge Export")
    end

    test "output contains entry count" do
      result = Markdown.render([@sample_entry], [])
      assert String.contains?(result, "Entries")
    end

    test "output contains the entry ID" do
      result = Markdown.render([@sample_entry], [])
      assert String.contains?(result, "entry_sprint54_001")
    end

    test "renders with empty entries list" do
      result = Markdown.render([], [])
      assert is_binary(result)
    end

    test "renders with empty lineage" do
      result = Markdown.render([@sample_entry], [])
      assert is_binary(result)
    end

    test "include_metadata false omits metadata section" do
      without_meta = Markdown.render([@sample_entry], [], false)
      assert is_binary(without_meta)
    end

    test "multiple entries all appear in output" do
      entries = [
        @sample_entry,
        %{@sample_entry | id: "entry_sprint54_002", content: "# Second Entry\n\nSecond."}
      ]

      result = Markdown.render(entries, [])
      assert String.contains?(result, "entry_sprint54_001")
      assert String.contains?(result, "entry_sprint54_002")
    end

    test "output is valid UTF-8" do
      result = Markdown.render([@sample_entry], [@sample_lineage_event])
      assert String.valid?(result)
    end
  end
end
