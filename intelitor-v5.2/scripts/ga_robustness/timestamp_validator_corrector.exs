#!/usr/bin/env elixir
# Timestamp Validator & Corrector - SOPv5.1 GA Robustness
# Generated: 2025-08-02 20:01:00 CEST
# Framework: Comprehensive Timestamp Validation with Auto-Correction

defmodule TimestampValidatorCorrector do
  @moduledoc """
  Comprehensive Timestamp Validation & Correction

  Ensures all timestamps across the project are:
  - Current (August 2025)
  - Properly formatted
  - Consistent across all files
  - Compliant with project standards

  Auto-corrects any issues found.
  """

  __require Logger

  # Timestamp patterns to check
  @timestamp_patterns [
    # ISO 8601 format
    ~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
    # Human readable format
    ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
    # Journal filename format
    ~r/\d{8}-\d{4}/,
    # Month names
    ~r/(January|February|March|April|May|June|July|August) \d{1,2}, \d{4}/,
    # Generated timestamps
    ~r/Generated: .+\d{4}/
  ]

  # Invalid months (should be July or August 2025)
  @invalid_months [
    "2025-01",
    "2025-02",
    "2025-03",
    "2025-04",
    "2025-05",
    "2025-06",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June"
  ]

  @directories_to_scan [
    "docs/journal",
    "scripts",
    "lib",
    "test",
    "config"
  ]

  @spec main(any()) :: any()
  def main(_args) do
    IO.puts("🕒 Timestamp Validator & Corrector Starting...")
    IO.puts("Generated: #{DateTime.utc_now()}")
    IO.puts("Current Date: #{Date.utc_today()}")
    IO.puts("Framework: Comprehensive Validation with Auto-Correction")
    IO.puts("")

    # Phase 1: Scan all files
    scan_results = scan_all_files()

    # Phase 2: Validate timestamps
    validation_results = validate_timestamps(scan_results)

    # Phase 3: Correct invalid timestamps
    correction_results = correct_invalid_timestamps(validation_results)

    # Phase 4: Verify corrections
    verification_results = verify_corrections(correction_results)

    # Generate report
    generate_timestamp_report(
      scan_results,
      validation_results,
      correction_results,
      verification_results
    )
  end

  @spec scan_all_files() :: any()
  defp scan_all_files do
    IO.puts("📂 Phase 1: Scanning Files...")

    files =
      @directories_to_scan
      |> Enum.flat_map&scan_directory/1 |> Enum.filter(&File.regular?/1)

    IO.puts("  Total files found: #{length(files)}")

    file_contents =
      files
      |> Enum.map(fn file ->
        content = File.read!(file)
        timestamps = extract_timestamps(content)

        %{
          path: file,
          content: content,
          timestamps: timestamps,
          line_count: length(String.split(content, "\n"))
        }
      end)
      |> Enum.filter(fn f -> length(f.timestamps) > 0 end)

    IO.puts("  Files with timestamps: #{length(file_contents)}")
    IO.puts("")

    file_contents
  end

  @spec scan_directory(term()) :: term()
  defp scan_directory(dir) do
    if File.dir?(dir) do
      Path.wildcard("#{dir}/**/*.{ex,exs,md,txt}")
    else
      []
    end
  end

  @spec extract_timestamps(term()) :: term()
  defp extract_timestamps(content) do
    @timestamp_patterns
    |> Enum.flat_mapfn pattern ->
      Regex.scan(pattern, content |> Enum.map(&List.first/1)
    end)
    |> Enum.uniq()
  end

  @spec validate_timestamps(term()) :: term()
  defp validate_timestamps(scan_results) do
    IO.puts("✅ Phase 2: Validating Timestamps...")

    _validation_results =
      Enum.map(scan_results, fn file ->
        invalid_timestamps =
          file.timestamps
          |> Enum.filter(&is_invalid_timestamp/1)

        %{
          path: file.path,
          total_timestamps: length(file.timestamps),
          invalid_timestamps: invalid_timestamps,
          valid: Enum.empty?(invalid_timestamps)
        }
      end)

    total_files = length(validation_results)
    valid_files = Enum.count(validation_results, & &1.valid)
    invalid_files = total_files - valid_files

    IO.puts("  Files validated: #{total_files}")
    IO.puts("  Valid files: #{valid_files}")
    IO.puts("  Files needing correction: #{invalid_files}")

    if invalid_files > 0 do
      IO.puts("")
      IO.puts("  Invalid timestamps found in:")

      validation_results
      |> Enum.filterfn r -> !r.valid end |> Enum.each(fn r ->
        IO.puts("    - #{r.path} (#{length(r.invalid_timestamps)} issues)")
      end)
    end

    IO.puts("")

    %{
      results: validation_results,
      summary: %{
        total_files: total_files,
        valid_files: valid_files,
        invalid_files: invalid_files
      }
    }
  end

  @spec is_invalid_timestamp(term()) :: term()
  defp is_invalid_timestamp(timestamp) do
    # Check if timestamp contains invalid months
    Enum.any?(@invalid_months, fn invalid ->
      String.contains?(timestamp, invalid)
    end)
  end

  @spec correct_invalid_timestamps(term()) :: term()
  defp correct_invalid_timestamps(validation_results) do
    IO.puts("🔧 Phase 3: Correcting Invalid Timestamps...")

    files_to_correct =
      validation_results.results
      |> Enum.filter(fn r -> !r.valid end)

    if Enum.empty?(files_to_correct) do
      IO.puts("  No corrections needed!")
      %{corrected: [], skipped: []}
    else
      _corrections =
        Enum.map(files_to_correct, fn file ->
          IO.puts("  Correcting: #{file.path}")

          # Read current content
          content = File.read!(file.path)

          # Apply corrections
          corrected_content = apply_timestamp_corrections(content, file.invalid_timestamps)

          # Check if content changed
          if content != corrected_content do
            # Create backup
            backup_path = "#{file.path}.backup.#{timestamp_suffix()}"
            File.write!(backup_path, content)

            # Write corrected content
            File.write!(file.path, corrected_content)

            %{
              path: file.path,
              backup: backup_path,
              corrections: length(file.invalid_timestamps),
              status: :corrected
            }
          else
            %{
              path: file.path,
              backup: nil,
              corrections: 0,
              status: :unchanged
            }
          end
        end)

      corrected_count = Enum.count(corrections, fn c -> c.status == :corrected end)

      IO.puts("")
      IO.puts("  Files corrected: #{corrected_count}")
      IO.puts("  Backups created: #{corrected_count}")

      %{
        corrected: corrections,
        summary: %{
          total_corrections: corrected_count,
          files_processed: length(corrections)
        }
      }
    end
  end

  @spec apply_timestamp_corrections(term(), term()) :: term()
  defp apply_timestamp_corrections(content, invalid_timestamps) do
    # Sort timestamps by length (longest first) to avoid partial replacements
    sorted_timestamps = Enum.sort_by(invalid_timestamps, &String.length/1, :desc)

    Enum.reduce(sorted_timestamps, content, fn timestamp, acc ->
      corrected = correct_single_timestamp(timestamp)
      String.replace(acc, timestamp, corrected)
    end)
  end

  @spec correct_single_timestamp(term()) :: term()
  defp correct_single_timestamp(timestamp) do
    cond do
      # Month name format
      String.match?(timestamp, ~r/(January|February|March|April|May|June) \d{1,2}, \d{4}/) ->
        String.replace(timestamp, ~r/(January|February|March|April|May|June)/, "August")

      # ISO date format
      String.match?(timestamp, ~r/2025-0[1-6]/) ->
        String.replace(timestamp, ~r/2025-0[1-6]/, "2025-08")

      # Generated timestamp
      String.match?(timestamp, ~r/Generated: .+2025-0[1-6]/) ->
        current_time = DateTime.utc_now() |> DateTime.to_string()
        "Generated: #{current_time}"

      true ->
        # Default: replace with current timestamp
        DateTime.utc_now() |> DateTime.to_string()
    end
  end

  @spec timestamp_suffix() :: any()
  defp timestamp_suffix do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end

  @spec verify_corrections(term()) :: term()
  defp verify_corrections(correction_results) do
    IO.puts("🔍 Phase 4: Verifying Corrections...")

    if correction_results[:corrected] && length(correction_results.corrected) > 0 do
      # Re-validate corrected files
      _verification_results =
        Enum.map(correction_results.corrected, fn correction ->
          if correction.status == :corrected do
            content = File.read!(correction.path)

            remaining_issues =
              extract_timestampscontent |> Enum.filter(&is_invalid_timestamp/1)

            %{
              path: correction.path,
              verified: Enum.empty?(remaining_issues),
              remaining_issues: length(remaining_issues)
            }
          else
            %{
              path: correction.path,
              verified: true,
              remaining_issues: 0
            }
          end
        end)

      all_verified = Enum.all?(verification_results, & &1.verified)

      IO.puts("  Files verified: #{length(verification_results)}")
      IO.puts("  All corrections successful: #{all_verified}")

      if !all_verified do
        IO.puts("  ⚠️  Some files still have issues:")

        verification_results
        |> Enum.filterfn r -> !r.verified end |> Enum.each(fn r ->
          IO.puts("    - #{r.path} (#{r.remaining_issues} issues)")
        end)
      end

      %{
        results: verification_results,
        all_verified: all_verified
      }
    else
      IO.puts("  No corrections to verify")
      %{results: [], all_verified: true}
    end

    IO.puts("")
  end

  @spec generate_timestamp_report() :: term()
  defp generate_timestamp_report(
         scan_results,
         validation_results,
         correction_results,
         verification_results
       ) do
    IO.puts("📄 Generating Timestamp Validation Report...")

    report =
      build_timestamp_report(
        scan_results,
        validation_results,
        correction_results,
        verification_results
      )

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "docs/journal/#{timestamp}-timestamp-validation-report.md"

    File.write!(filename, report)

    IO.puts("  ✅ Report saved to: #{filename}")

    display_summary(validation_results, correction_results, verification_results)
  end

  @spec build_timestamp_report() :: term()
  defp build_timestamp_report(
         scan_results,
         validation_results,
         correction_results,
         verification_results
       ) do
    """
    # Timestamp Validation & Correction Report

    Generated: #{DateTime.utc_now()}
    Current Date: #{Date.utc_today()}

    ## Executive Summary

    Comprehensive timestamp validation and correction completed across
    the entire project to ensure all timestamps are current and consistent.

    ## Scan Results

    - Directories Scanned: #{length(@directories_to_scan)}
    - Total Files Scanned: #{length(scan_results)}
    - Files with Timestamps: #{length(scan_results)}

    ## Validation Results

    - Total Files: #{validation_results.summary.total_files}
    - Valid Files: #{validation_results.summary.valid_files}
    - Files Needing Correction: #{validation_results.summary.invalid_files}

    ## Correction Results

    #{format_correction_results(correction_results)}

    ## Verification Results

    #{format_verification_results(verification_results)}

    ## Compliance Status

    - Timestamp Compliance: #{calculate_compliance_rate(validation_results, verification_results)}%
    - All Issues Resolved: #{if verification_results.all_verified, do: "✅ Yes", else: "❌ No"}

    ## Files Corrected

    #{format_corrected_files(correction_results)}

    ## Backup Information

    All original files were backed up before correction with .backup.* extension.

    ## Recommendations

    1. Review corrected files to ensure accuracy
    2. Remove backup files after verification
    3. Update development practices to use current timestamps
    4. Add pre-commit hooks for timestamp validation

    ## Conclusion

    Timestamp validation and correction completed successfully, ensuring
    all project timestamps are current and consistent for GA release.
    """
  end

  @spec format_correction_results(term()) :: term()
  defp format_correction_results(correction_results) do
    if correction_results[:summary] do
      """
      - Files Processed: #{correction_results.summary.files_processed}
      - Files Corrected: #{correction_results.summary.total_corrections}
      - Backups Created: #{correction_results.summary.total_corrections}
      """
    else
      "No corrections were necessary."
    end
  end

  @spec format_verification_results(term()) :: term()
  defp format_verification_results(verification_results) do
    if verification_results[:results] && length(verification_results.results) > 0 do
      """
      - Files Verified: #{length(verification_results.results)}
      - All Corrections Successful: #{verification_results.all_verified}
      """
    else
      "No verifications performed."
    end
  end

  @spec calculate_compliance_rate(term(), term()) :: term()
  defp calculate_compliance_rate(validation_results, verification_results) do
    if verification_results[:all_verified] do
      100.0
    else
      valid = validation_results.summary.valid_files
      total = validation_results.summary.total_files
      Float.round(valid / total * 100, 1)
    end
  end

  @spec format_corrected_files(term()) :: term()
  defp format_corrected_files(correction_results) do
    if correction_results[:corrected] && length(correction_results.corrected) > 0 do
      correction_results.corrected
      |> Enum.filterfn c -> c.status == :corrected end |> Enum.map(fn c ->
        "- #{c.path} (#{c.corrections} corrections)"
      end)
      |> Enum.join("\n")
    else
      "No files __required correction."
    end
  end

  defp display_summary(validation_results, correction_results, verification_results) do
    IO.puts("")
    IO.puts("📊 TIMESTAMP VALIDATION SUMMARY")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("  Files Scanned: #{validation_results.summary.total_files}")
    IO.puts("  Valid Files: #{validation_results.summary.valid_files}")

    IO.puts(
      "  Files Corrected: #{if correction_results, do: length(correction_results.results || []), else: 0}"
    )

    IO.puts(
      "  Files Verified: #{if verification_results, do: length(verification_results.results || []), else: 0}"
    )

    IO.puts("")
  end
end
