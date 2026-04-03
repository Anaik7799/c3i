defmodule Indrajaal.Safety.PatternDatabaseTest do
  @moduledoc """
  Tests for Pattern Database System (STUB Implementation)

  NOTE: PatternDatabase is currently a STUB module.
  Tests verify the existing API contract without expecting full production data.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Safety.PatternDatabase

  describe "load_all_patterns/0" do
    test "loads built-in pattern database" do
      patterns = PatternDatabase.load_all_patterns()

      # Should load some patterns (stub has ~20)
      assert length(patterns) >= 10

      # All patterns should have required structure
      for pattern <- patterns do
        assert Map.has_key?(pattern, :id)
        assert Map.has_key?(pattern, :name)
        assert Map.has_key?(pattern, :pattern)
        assert Map.has_key?(pattern, :type)
        assert Map.has_key?(pattern, :severity)
        assert Map.has_key?(pattern, :success_rate)
        assert Map.has_key?(pattern, :remediation_type)
      end
    end

    test "patterns have valid structure and data types" do
      patterns = PatternDatabase.load_all_patterns()

      for pattern <- patterns do
        # ID should be string starting with "EP"
        assert is_binary(pattern.id)
        assert String.starts_with?(pattern.id, "EP")

        # Pattern should be compiled regex
        assert is_struct(pattern.pattern, Regex)

        # Severity should be valid level
        assert pattern.severity in [:critical, :high, :medium, :low, :info]

        # Success rate should be valid percentage
        assert is_float(pattern.success_rate)
        assert pattern.success_rate >= 0.0
        assert pattern.success_rate <= 1.0
      end
    end

    test "covers multiple pattern types" do
      patterns = PatternDatabase.load_all_patterns()

      # Group by type
      by_type = Enum.group_by(patterns, & &1.type)

      # Should have multiple types represented
      assert map_size(by_type) >= 5
    end

    test "includes patterns across severity levels" do
      patterns = PatternDatabase.load_all_patterns()

      # Group by severity
      by_severity = Enum.group_by(patterns, & &1.severity)

      # Should have patterns at multiple severity levels
      assert Map.has_key?(by_severity, :critical)
      assert Map.has_key?(by_severity, :high)

      # Critical patterns should exist for safety
      assert length(by_severity[:critical]) >= 5
    end
  end

  describe "load_patterns_by_category/1" do
    test "filters patterns by type (category)" do
      database_patterns = PatternDatabase.load_patterns_by_category(:database)

      # All returned patterns should be database type
      for pattern <- database_patterns do
        assert pattern.type == :database
      end
    end

    test "returns empty list for non-existent type" do
      patterns = PatternDatabase.load_patterns_by_category(:non_existent)
      assert patterns == []
    end
  end

  describe "load_patterns_by_severity/1" do
    test "filters patterns by critical severity" do
      critical_patterns = PatternDatabase.load_patterns_by_severity(:critical)

      assert length(critical_patterns) > 0

      # All patterns should be critical severity
      for pattern <- critical_patterns do
        assert pattern.severity == :critical
      end
    end

    test "filters patterns by medium severity" do
      medium_patterns = PatternDatabase.load_patterns_by_severity(:medium)

      assert length(medium_patterns) > 0

      # All patterns should be medium severity
      for pattern <- medium_patterns do
        assert pattern.severity == :medium
      end
    end

    test "returns empty list for invalid severity" do
      patterns = PatternDatabase.load_patterns_by_severity(:invalid)
      assert patterns == []
    end
  end

  describe "get_pattern/1" do
    test "retrieves specific pattern by ID" do
      pattern_ep001 = PatternDatabase.get_pattern("EP001")

      assert pattern_ep001 != nil
      assert pattern_ep001.id == "EP001"
    end

    test "returns nil for non-existent pattern ID" do
      pattern = PatternDatabase.get_pattern("EP999")
      assert pattern == nil
    end

    test "returns nil for invalid pattern ID format" do
      pattern = PatternDatabase.get_pattern("INVALID")
      assert pattern == nil
    end
  end

  describe "get_pattern_statistics/0" do
    test "returns statistics about pattern database" do
      stats = PatternDatabase.get_pattern_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_patterns)
      assert Map.has_key?(stats, :severity_distribution)
      assert Map.has_key?(stats, :category_distribution)
      assert Map.has_key?(stats, :average_success_rate)

      # Total patterns should match loaded patterns
      patterns = PatternDatabase.load_all_patterns()
      assert stats.total_patterns == length(patterns)

      # Average success rate should be reasonable
      assert stats.average_success_rate >= 0.5
      assert stats.average_success_rate <= 1.0
    end
  end

  describe "validate_pattern/1" do
    test "validates complete valid pattern" do
      valid_pattern = %{
        id: "EP-TEST-001",
        name: "Test Pattern",
        pattern: ~r/test.*error/i,
        severity: :medium,
        success_rate: 0.85
      }

      assert {:ok, _} = PatternDatabase.validate_pattern(valid_pattern)
    end

    test "detects missing required fields" do
      incomplete_pattern = %{
        id: "EP-TEST-002"
        # missing required fields
      }

      result = PatternDatabase.validate_pattern(incomplete_pattern)
      assert {:error, {:missing_fields, _}} = result
    end

    test "validates severity levels" do
      invalid_severity_pattern = %{
        id: "EP-TEST-004",
        name: "Test",
        pattern: ~r/test/i,
        severity: :invalid_level
      }

      result = PatternDatabase.validate_pattern(invalid_severity_pattern)
      assert {:error, {:invalid_severity, :invalid_level}} = result
    end

    test "validates success rate range" do
      invalid_success_rate_pattern = %{
        id: "EP-TEST-005",
        name: "Test",
        pattern: ~r/test/i,
        severity: :medium,
        # Invalid: > 1.0
        success_rate: 1.5
      }

      result = PatternDatabase.validate_pattern(invalid_success_rate_pattern)
      assert {:error, {:invalid_success_rate, 1.5}} = result
    end
  end

  describe "get_top_performing_patterns/1" do
    test "returns patterns sorted by success rate" do
      top_patterns = PatternDatabase.get_top_performing_patterns(5)

      assert length(top_patterns) == 5

      # Should be sorted by success rate descending
      success_rates = Enum.map(top_patterns, & &1.success_rate)
      sorted_rates = Enum.sort(success_rates, :desc)

      assert success_rates == sorted_rates
    end

    test "limits results correctly" do
      top_3 = PatternDatabase.get_top_performing_patterns(3)
      assert length(top_3) == 3
    end
  end

  describe "get_underperforming_patterns/1" do
    test "returns patterns below success rate threshold" do
      underperforming = PatternDatabase.get_underperforming_patterns(0.8)

      # All returned patterns should have success rate < 0.8
      for pattern <- underperforming do
        assert pattern.success_rate < 0.8
      end
    end
  end

  describe "get_effectiveness_metrics/0" do
    test "returns effectiveness metrics" do
      metrics = PatternDatabase.get_effectiveness_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :critical_patterns_avg_success)
      assert Map.has_key?(metrics, :high_patterns_avg_success)
      assert Map.has_key?(metrics, :total_critical_patterns)
      assert Map.has_key?(metrics, :total_high_patterns)
      assert Map.has_key?(metrics, :remediation_coverage)

      # Success rates should be valid percentages
      assert metrics.critical_patterns_avg_success >= 0.0
      assert metrics.critical_patterns_avg_success <= 1.0
    end
  end

  describe "get_contextual_patterns/1" do
    test "filters patterns by context conditions" do
      # Get contextual patterns with empty context (should return all with empty conditions)
      contextual_patterns = PatternDatabase.get_contextual_patterns(%{})

      assert is_list(contextual_patterns)
      assert length(contextual_patterns) > 0
    end
  end

  describe "pattern regex quality" do
    test "patterns compile and are usable" do
      patterns = PatternDatabase.load_all_patterns()

      for pattern <- patterns do
        # Each pattern's regex should be valid and usable
        assert is_struct(pattern.pattern, Regex)

        # Should be able to use the regex without errors
        result = Regex.match?(pattern.pattern, "test string that probably won't match")
        assert is_boolean(result)
      end
    end

    test "connection patterns match expected strings" do
      pattern = PatternDatabase.get_pattern("EP001")

      if pattern do
        assert Regex.match?(pattern.pattern, "connection pool exhausted - all slots in use")
        assert Regex.match?(pattern.pattern, "too many connections")
      end
    end
  end
end
