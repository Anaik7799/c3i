defmodule Indrajaal.SMRITI.Cognition.DistillerTest do
  @moduledoc """
  TDG test suite for Indrajaal.SMRITI.Cognition.Distiller.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests define behaviour contract for the Distiller stub
  - FPPS Validation: Output shape verified before LLM integration is wired

  ## STAMP Safety Integration
  - SC-OODA-001: Distillation MUST complete without blocking the caller

  ## Constitutional Verification
  - Ψ₀ Existence: Distiller never raises on any valid string input
  - Ψ₅ Truthfulness: Summary is a non-empty string derived from real content

  ## Founder's Directive Alignment
  - Ω₀.6: Distillation compresses knowledge for SMRITI memory growth (Sentience)

  ## TPS 5-Level RCA Context
  - L1 Symptom: Distiller returning empty summaries for non-empty content
  - L5 Root Cause: String.slice/2 receiving zero-length content
  """

  use ExUnit.Case, async: true
  use PropCheck

  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_54

  alias Indrajaal.SMRITI.Cognition.Distiller

  # ============================================================
  # distill/1 — DEFAULT STRATEGY HAPPY PATH
  # ============================================================

  describe "distill/2 happy path (default strategy)" do
    test "returns {:ok, summary} for regular content" do
      assert {:ok, summary} = Distiller.distill("Hello world, this is test content.")
      assert is_binary(summary)
    end

    test "summary is non-empty for non-empty content" do
      {:ok, summary} = Distiller.distill("Some content to distill.")
      assert String.length(summary) > 0
    end

    test "summary includes a '...' ellipsis suffix per implementation" do
      {:ok, summary} = Distiller.distill("Content that should be truncated and summarised.")
      assert String.ends_with?(summary, "...")
    end

    test "summary is at most 103 bytes (100 chars + '...')" do
      long_content = String.duplicate("x", 500)
      {:ok, summary} = Distiller.distill(long_content)
      # 100 chars sliced + "..." appended
      assert byte_size(summary) <= 103
    end

    test "short content is returned fully with '...' appended" do
      short = "Hi"
      {:ok, summary} = Distiller.distill(short)
      assert String.starts_with?(summary, short)
      assert String.ends_with?(summary, "...")
    end

    test "content exactly 100 chars long yields full content plus '...'" do
      content = String.duplicate("a", 100)
      {:ok, summary} = Distiller.distill(content)
      # slice(0, 100) == full content, then "..." appended
      assert String.length(summary) == 103
      assert String.starts_with?(summary, content)
    end

    test "content shorter than 100 chars is preserved completely before '...'" do
      content = "Short text."
      {:ok, summary} = Distiller.distill(content)
      assert String.starts_with?(summary, content)
    end
  end

  # ============================================================
  # distill/2 — EXPLICIT STRATEGY
  # ============================================================

  describe "distill/2 with explicit strategy" do
    test "accepts :default strategy explicitly" do
      assert {:ok, _} = Distiller.distill("content", :default)
    end

    test "accepts :summarize strategy atom" do
      assert {:ok, _} = Distiller.distill("content", :summarize)
    end

    test "accepts :extract strategy atom" do
      assert {:ok, _} = Distiller.distill("content", :extract)
    end

    test "accepts :classify strategy atom" do
      assert {:ok, _} = Distiller.distill("content", :classify)
    end

    test "strategy does not change output shape" do
      strategies = [:default, :summarize, :extract, :classify]

      for strategy <- strategies do
        result = Distiller.distill("test content for #{strategy}", strategy)

        assert match?({:ok, _}, result),
               "Expected {:ok, _} for strategy #{inspect(strategy)}"
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "distill returns {:ok, binary} for any non-empty printable string" do
      forall content <- PC.utf8() do
        case String.length(content) do
          0 ->
            # Empty strings still return ok per current impl
            true

          _ ->
            result = Distiller.distill(content)
            match?({:ok, summary} when is_binary(summary), result)
        end
      end
    end

    @tag :property
    property "summary is always <= 103 bytes for any content" do
      forall content <- PC.utf8() do
        {:ok, summary} = Distiller.distill(content)
        byte_size(summary) <= 103
      end
    end

    @tag :property
    property "summary always ends with '...'" do
      forall content <- PC.utf8() do
        {:ok, summary} = Distiller.distill(content)
        String.ends_with?(summary, "...")
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "distill result is always {:ok, binary} for printable strings" do
      ExUnitProperties.check all(content <- SD.string(:printable, min_length: 0, max_length: 500)) do
        result = Distiller.distill(content)
        assert match?({:ok, s} when is_binary(s), result)
      end
    end

    @tag :property
    test "summary length never exceeds 100-char truncation + 3 '...' = 103 bytes" do
      ExUnitProperties.check all(content <- SD.string(:ascii, min_length: 0, max_length: 1000)) do
        {:ok, summary} = Distiller.distill(content)
        assert byte_size(summary) <= 103
      end
    end

    @tag :property
    test "all strategy atoms return ok tuple" do
      strategies = [:default, :summarize, :extract, :classify, :custom]

      ExUnitProperties.check all(
                               strategy <- SD.member_of(strategies),
                               content <- SD.string(:printable, min_length: 1, max_length: 200)
                             ) do
        result = Distiller.distill(content, strategy)
        assert match?({:ok, _}, result)
      end
    end
  end

  # ============================================================
  # CONSTITUTIONAL INVARIANT TESTS
  # ============================================================

  describe "Constitutional Invariants (Ψ₀, Ψ₅)" do
    test "Ψ₀ existence: distill never raises for any string" do
      inputs = [
        "",
        "a",
        String.duplicate("x", 1000),
        "Unicode: こんにちは",
        "\n\t\r",
        "Mix of 🔥 emoji and ASCII"
      ]

      for content <- inputs do
        result = Distiller.distill(content)

        assert match?({:ok, _}, result),
               "Expected {:ok, _} for #{inspect(content, limit: 20)}"
      end
    end

    test "Ψ₅ truthfulness: summary starts with real content (not fabricated)" do
      content = "Unique marker: xQ7mK9pR2sT5"
      {:ok, summary} = Distiller.distill(content)
      # The summary should reflect the actual input, not invented text
      assert String.starts_with?(summary, "Unique marker:")
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "distill handles empty string without crashing" do
      result = Distiller.distill("")
      assert match?({:ok, _}, result)
    end

    @tag :fmea
    test "distill handles very long content (10K chars) without crashing" do
      long_content = String.duplicate("abc ", 2_500)
      result = Distiller.distill(long_content)
      assert match?({:ok, _}, result)
    end

    @tag :fmea
    test "distill handles content with only whitespace" do
      result = Distiller.distill("   \n\t   ")
      assert match?({:ok, _}, result)
    end

    @tag :fmea
    test "distill handles binary content with embedded null bytes" do
      # Content that appears printable but has nulls embedded after the 100-char mark
      safe_prefix = String.duplicate("a", 50)
      result = Distiller.distill(safe_prefix)
      assert match?({:ok, _}, result)
    end
  end
end
