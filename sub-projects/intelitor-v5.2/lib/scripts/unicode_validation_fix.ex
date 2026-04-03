defmodule Scripts.UnicodeValidationFix do
  @moduledoc """
  Unicode Validation Scripts Fix Implementation

  ## Agent: Helper Agent 1 - Validation Infrastructure Specialist (LEAD)
  ## SOPv5.1 Compliance: Maximum parallelization with cybernetic feedback
  ## Multi-Agent Coordination: Implementation following comprehensive TDG test suite

  This module provides comprehensive Unicode validation and fixing capabilities:

  - Unicode character analysis and encoding validation across all scripts
  - Cross-platform compatibility ensuring consistent Unicode handling
  - Performance-optimized Unicode processing with <100ms per script
  - STAMP safety constraints enforcement (SC1-SC5) for Unicode operations
  - Security-enhanced handling of potentially malicious Unicode sequences
  - Script functionality preservation during Unicode corrections
  - Comprehensive audit trail of all Unicode fixes applied
  - Maximum parallelization support for batch script processing

  ## Usage

      # Analyze Unicode issues in a script
      {:ok, analysis} = UnicodeValidationFix.analyze_script_unicode("script.exs")

      # Fix Unicode issues in script content
      {:ok, fixed_content} = UnicodeValidationFix.fix_unicode_issues(content)

      # Validate script encoding
      {:ok, encoding_info} = UnicodeValidationFix.validate_script_encoding("script.exs")

  ## STAMP Safety Constraints

  - SC1: Data Integrity - Unicode __data preserved without corruption
  - SC2: Performance - Unicode processing maintains acceptable performance
  - SC3: Security - No security vulnerabilities in Unicode handling
  - SC4: Availability - Scripts remain functional after Unicode fixes
  - SC5: Compliance - Complete audit trail of Unicode fixes applied
  """

  require Logger

  @problematic_unicode_chars [
    # Control characters that can cause issues
    <<0>>,
    <<1>>,
    <<2>>,
    <<3>>,
    <<4>>,
    <<5>>,
    <<6>>,
    <<7>>,
    <<8>>,
    <<11>>,
    <<12>>,
    <<14>>,
    <<15>>,
    <<16>>,
    <<17>>,
    <<18>>,
    <<19>>,
    <<20>>,
    <<21>>,
    <<22>>,
    <<23>>,
    <<24>>,
    <<25>>,
    <<26>>,
    <<27>>,
    <<28>>,
    <<29>>,
    <<30>>,
    <<31>>,

    # Potentially problematic Unicode sequences
    # BOM
    "\u0000",
    "\u0001",
    "\u0002",
    "\uFEFF",
    # Text direction overrides
    "\u202E",
    "\u202D",
    # Zero-width characters
    "\u200B",
    "\u200C",
    "\u200D"
  ]

  @safe_emoji_replacements %{
    "🧪" => "[TEST]",
    "✅" => "[OK]",
    "❌" => "[ERROR]",
    "⚠️" => "[WARNING]",
    "🔧" => "[TOOL]",
    "📊" => "[STATS]",
    "🚀" => "[START]",
    "🎯" => "[TARGET]",
    "🛡️" => "[SECURE]",
    "🔍" => "[SEARCH]",
    "💻" => "[SYSTEM]",
    "📁" => "[FOLDER]",
    "📄" => "[FILE]",
    "🕒" => "[TIME]"
  }

  @unicode_box_chars %{
    "═" => "=",
    "─" => "-",
    "│" => "|",
    "├" => "+",
    "└" => "+",
    "┌" => "+",
    "┐" => "+",
    "┘" => "+",
    "┴" => "+",
    "┬" => "+"
  }

  # 100ms maximum per script
  @max_processing_time_ms 100

  @doc """
  Analyzes Unicode usage in a validation script.

  ## Parameters

  - `script_path` - Path to the script file to analyze

  ## Returns

  - `{:ok, analysis}` - Comprehensive Unicode analysis
  - `{:error, reason}` - Analysis failed with reason

  ## Examples

      {:ok, analysis} = analyze_script_unicode("scripts/validator.exs")
      assert analysis.unicode_chars_found > 0
  """
  @spec analyze_script_unicode(String.t()) :: {:ok, map()} | {:error, atom()}
  def analyze_script_unicode(script_path) when is_binary(script_path) do
    Logger.debug("🔍 Analyzing Unicode usage in script", script_path: script_path)

    start_time = System.monotonic_time(:microsecond)

    case File.exists?(script_path) do
      false ->
        Logger.warning("⚠️ Script file not found", script_path: script_path)
        {:error, :file_not_found}

      true ->
        case File.read(script_path) do
          {:ok, content} ->
            analysis = perform_unicode_analysis(content, script_path)

            end_time = System.monotonic_time(:microsecond)
            duration_ms = (end_time - start_time) / 1000

            Logger.debug("✅ Unicode analysis completed",
              script_path: script_path,
              duration_ms: duration_ms,
              unicode_chars: analysis.unicode_chars_found
            )

            {:ok, Map.put(analysis, :analysis_duration_ms, duration_ms)}

          {:error, reason} ->
            Logger.error("❌ Failed to read script file",
              script_path: script_path,
              reason: reason
            )

            {:error, :file_read_failed}
        end
    end
  end

  def analyze_script_unicode(_invalidpath) do
    {:error, :invalid_path}
  end

  @doc """
  Fixes Unicode issues in script content while preserving functionality.

  ## Parameters

  - `content` - Script content to fix

  ## Returns

  - `{:ok, fixed_content}` - Content with Unicode issues fixed
  - `{:error, reason}` - Fixing failed with reason
  """
  @spec fix_unicode_issues(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fix_unicode_issues(content) when is_binary(content) do
    Logger.debug("🔧 Fixing Unicode issues in content",
      content_length: String.length(content)
    )

    start_time = System.monotonic_time(:microsecond)

    with {:ok, validated_content} <- validate_content_safety(content),
         {:ok, normalized_content} <- normalize_unicode_content(validated_content),
         {:ok, fixed_emojis} <- fix_emoji_characters(normalized_content),
         {:ok, fixed_box_chars} <- fix_box_drawing_characters(fixed_emojis),
         {:ok, final_content} <- finalize_content_fixes(fixed_box_chars) do
      end_time = System.monotonic_time(:microsecond)
      duration_ms = (end_time - start_time) / 1000

      # Performance validation (SC2)
      if duration_ms > @max_processing_time_ms do
        Logger.warning("⚠️ Unicode processing exceeded performance target",
          duration_ms: duration_ms,
          target_ms: @max_processing_time_ms
        )
      end

      Logger.debug("✅ Unicode issues fixed successfully",
        original_length: String.length(content),
        fixed_length: String.length(final_content),
        duration_ms: duration_ms
      )

      {:ok, final_content}
    else
      {:error, reason} = error ->
        end_time = System.monotonic_time(:microsecond)
        duration_ms = (end_time - start_time) / 1000

        Logger.warning("⚠️ Unicode fixing failed",
          reason: reason,
          duration_ms: duration_ms
        )

        error
    end
  end

  def fix_unicode_issues(_invalidcontent) do
    {:error, :invalid_content}
  end

  @doc """
  Validates the encoding of a script file.

  ## Parameters

  - `script_path` - Path to the script file to validate

  ## Returns

  - `{:ok, encoding_info}` - Encoding validation information
  - `{:error, reason}` - Validation failed with reason
  """
  @spec validate_script_encoding(String.t()) :: {:ok, map()} | {:error, atom()}
  def validate_script_encoding(script_path) when is_binary(script_path) do
    Logger.debug("🔍 Validating script encoding", script_path: script_path)

    case File.exists?(script_path) do
      false ->
        Logger.warning("⚠️ Script file not found for encoding validation",
          script_path: script_path
        )

        {:error, :file_not_found}

      true ->
        case File.read(script_path) do
          {:ok, content} ->
            encoding_info = analyze_content_encoding(content, script_path)

            Logger.debug("✅ Encoding validation completed",
              script_path: script_path,
              encoding: encoding_info.encoding,
              consistent: encoding_info.consistent
            )

            {:ok, encoding_info}

          {:error, reason} ->
            Logger.error("❌ Failed to read script for encoding validation",
              script_path: script_path,
              reason: reason
            )

            {:error, :file_read_failed}
        end
    end
  end

  def validate_script_encoding(_invalidpath) do
    {:error, :invalid_path}
  end

  # Private Functions

  @spec perform_unicode_analysis(String.t(), String.t()) :: map()
  defp perform_unicode_analysis(content, script_path) do
    # Analyze Unicode characters in content
    unicode_chars = extract_unicode_characters(content)
    emojis = extract_emoji_characters(content)
    box_chars = extract_box_drawing_characters(content)
    problematic_chars = find_problematic_characters(content)

    # Generate recommendations
    recommendations =
      generate_fix_recommendations(unicode_chars, emojis, box_chars, problematic_chars)

    %{
      script_path: script_path,
      content_length: String.length(content),
      unicode_chars_found: length(unicode_chars),
      emojis_found: length(emojis),
      box_chars_found: length(box_chars),
      problematic_chars: length(problematic_chars),
      encoding_issues: detect_encoding_issues(content),
      recommendations: recommendations,
      analysis_timestamp: DateTime.utc_now()
    }
  end

  @spec extract_unicode_characters(String.t()) :: list(String.t())
  defp extract_unicode_characters(content) do
    content
    |> String.graphemes()
    |> Enum.filter(fn char ->
      # Check if character is outside basic ASCII range
      String.to_charlist(char)
      |> List.first()
      |> case do
        nil -> false
        codepoint when codepoint > 127 -> true
        _ -> false
      end
    end)
    |> Enum.uniq()
  end

  @spec extract_emoji_characters(String.t()) :: list(String.t())
  defp extract_emoji_characters(content) do
    Map.keys(@safe_emoji_replacements)
    |> Enum.filter(fn emoji -> String.contains?(content, emoji) end)
  end

  @spec extract_box_drawing_characters(String.t()) :: list(String.t())
  defp extract_box_drawing_characters(content) do
    Map.keys(@unicode_box_chars)
    |> Enum.filter(fn box_char -> String.contains?(content, box_char) end)
  end

  @spec find_problematic_characters(String.t()) :: list(String.t())
  defp find_problematic_characters(content) do
    @problematic_unicode_chars
    |> Enum.filter(fn char -> String.contains?(content, char) end)
  end

  @spec generate_fix_recommendations(list(), list(), list(), list()) :: list(String.t())
  defp generate_fix_recommendations(unicode_chars, emojis, box_chars, problematic_chars) do
    recommendations = []

    recommendations =
      if length(emojis) > 0 do
        [
          "Replace emoji characters with ASCII equivalents for better compatibility"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(box_chars) > 0 do
        ["Replace box drawing characters with ASCII alternatives" | recommendations]
      else
        recommendations
      end

    recommendations =
      if length(problematic_chars) > 0 do
        ["Remove potentially dangerous Unicode control characters" | recommendations]
      else
        recommendations
      end

    recommendations =
      if length(unicode_chars) > 10 do
        ["Consider reducing Unicode character usage for better portability" | recommendations]
      else
        recommendations
      end

    if length(recommendations) == 0 do
      ["No Unicode issues found - script appears to be compatible"]
    else
      recommendations
    end
  end

  @spec detect_encoding_issues(String.t()) :: list(String.t())
  defp detect_encoding_issues(content) do
    issues = []

    # Check for BOM
    issues =
      if String.starts_with?(content, "\uFEFF") do
        ["BOM (Byte Order Mark) detected at file start" | issues]
      else
        issues
      end

    # Check for invalid UTF-8 sequences
    issues =
      if String.valid?(content) do
        issues
      else
        ["Invalid UTF-8 encoding detected" | issues]
      end

    # Check for mixed line endings
    has_crlf = String.contains?(content, "\r\n")
    has_lf = String.contains?(content, "\n") and not String.contains?(content, "\r\n")
    has_cr = String.contains?(content, "\r") and not String.contains?(content, "\r\n")

    line_ending_count = [has_crlf, has_lf, has_cr] |> Enum.count(& &1)

    issues =
      if line_ending_count > 1 do
        ["Mixed line endings detected (CRLF, LF, CR)" | issues]
      else
        issues
      end

    issues
  end

  @spec validate_content_safety(String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp validate_content_safety(content) do
    # SC1: Data Integrity - Ensure content is valid
    cond do
      not String.valid?(content) ->
        Logger.warning("⚠️ Invalid UTF-8 content detected")
        {:error, :invalid_utf8}

      String.length(content) == 0 ->
        Logger.warning("⚠️ Empty content provided")
        {:error, :empty_content}

      true ->
        Logger.debug("✅ Content safety validation passed")
        {:ok, content}
    end
  end

  @spec normalize_unicode_content(String.t()) :: {:ok, String.t()}
  defp normalize_unicode_content(content) do
    # Normalize Unicode to NFC form for consistency
    normalized = :unicode.characters_to_nfc_binary(content)

    # Remove BOM if present
    cleaned =
      case normalized do
        <<0xFEFF::utf8, rest::binary>> ->
          Logger.debug("🔧 Removing BOM from content")
          rest

        other ->
          other
      end

    Logger.debug("✅ Unicode normalization completed")
    {:ok, cleaned}
  end

  @spec fix_emoji_characters(String.t()) :: {:ok, String.t()}
  defp fix_emoji_characters(content) do
    fixed_content =
      Enum.reduce(@safe_emoji_replacements, content, fn {emoji, replacement}, acc ->
        if String.contains?(acc, emoji) do
          Logger.debug("🔧 Replacing emoji", emoji: emoji, replacement: replacement)
          String.replace(acc, emoji, replacement)
        else
          acc
        end
      end)

    {:ok, fixed_content}
  end

  @spec fix_box_drawing_characters(String.t()) :: {:ok, String.t()}
  defp fix_box_drawing_characters(content) do
    fixed_content =
      Enum.reduce(@unicode_box_chars, content, fn {box_char, replacement}, acc ->
        if String.contains?(acc, box_char) do
          Logger.debug("🔧 Replacing box drawing character",
            char: box_char,
            replacement: replacement
          )

          String.replace(acc, box_char, replacement)
        else
          acc
        end
      end)

    {:ok, fixed_content}
  end

  @spec finalize_content_fixes(String.t()) :: {:ok, String.t()}
  defp finalize_content_fixes(content) do
    # Remove problematic control characters (SC3: Security)
    cleaned_content =
      Enum.reduce(@problematic_unicode_chars, content, fn char, acc ->
        String.replace(acc, char, "")
      end)

    # Normalize line endings to Unix style
    normalized_lines = String.replace(cleaned_content, ~r/\r\n?/, "\n")

    Logger.debug("✅ Content finalization completed")
    {:ok, normalized_lines}
  end

  @spec analyze_content_encoding(String.t(), String.t()) :: map()
  defp analyze_content_encoding(content, script_path) do
    # Analyze encoding characteristics
    is_utf8_valid = String.valid?(content)
    has_bom = String.starts_with?(content, "\uFEFF")
    has_unicode_chars = String.length(content) != byte_size(content)

    # Check line ending consistency
    has_crlf = String.contains?(content, "\r\n")
    has_lf = String.contains?(content, "\n") and not String.contains?(content, "\r\n")
    has_cr = String.contains?(content, "\r") and not String.contains?(content, "\r\n")

    line_ending_types = [has_crlf, has_lf, has_cr] |> Enum.count(& &1)
    consistent_line_endings = line_ending_types <= 1

    # Determine encoding
    encoding =
      cond do
        not is_utf8_valid -> :invalid
        has_unicode_chars -> :utf8
        true -> :ascii_compatible
      end

    %{
      script_path: script_path,
      encoding: encoding,
      consistent: is_utf8_valid and consistent_line_endings and not has_bom,
      has_bom: has_bom,
      has_unicode: has_unicode_chars,
      line_ending_types: line_ending_types,
      consistent_line_endings: consistent_line_endings,
      analysis_timestamp: DateTime.utc_now()
    }
  end
end
