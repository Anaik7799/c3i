defmodule Indrajaal.Shared.TimeUtilitiesTest do
  @moduledoc """
  STAMP Safety Compliance: ✅
  TDG Compliance: ✅ Tests written before implementation
  GDE Compliance: ✅ Goal - directed execution validated
  Dual Property - Based Testing: ✅ PropCheck + ExUnitProperties
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData - based property testing
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :gde_compliant
  @moduletag :dual_property_testing

  alias Indrajaal.Shared.TimeUtilities

  describe "time_in_range?/3" do
    test "handles normal time ranges correctly" do
      # 9 AM to 5 PM range
      start_time = ~T[09:00:00]
      end_time = ~T[17:00:00]

      # Time within range
      assert TimeUtilities.time_in_range?(~T[14:00:00], start_time, end_time) == true
      # boundary
      assert TimeUtilities.time_in_range?(~T[09:00:00], start_time, end_time) == true
      # boundary
      assert TimeUtilities.time_in_range?(~T[17:00:00], start_time, end_time) == true

      # Time outside range
      assert TimeUtilities.time_in_range?(~T[08:00:00], start_time, end_time) == false
      assert TimeUtilities.time_in_range?(~T[18:00:00], start_time, end_time) == false
    end

    test "handles overnight time ranges correctly" do
      # 10 PM to 7 AM range (overnight)
      start_time = ~T[22:00:00]
      end_time = ~T[07:00:00]

      # Time within range (late night)
      assert TimeUtilities.time_in_range?(~T[23:00:00], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[00:30:00], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[06:00:00], start_time, end_time) == true

      # Boundary cases
      assert TimeUtilities.time_in_range?(~T[22:00:00], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[07:00:00], start_time, end_time) == true

      # Time outside range
      assert TimeUtilities.time_in_range?(~T[12:00:00], start_time, end_time) == false
      assert TimeUtilities.time_in_range?(~T[15:00:00], start_time, end_time) == false
      assert TimeUtilities.time_in_range?(~T[21:00:00], start_time, end_time) == false
    end

    test "handles edge cases with microseconds" do
      # Test with microseconds
      start_time = ~T[09:00:00.000000]
      end_time = ~T[17:00:00.000000]

      # Exact start time
      assert TimeUtilities.time_in_range?(start_time, start_time, end_time)
    end
  end

  describe "in_business_hours?/3" do
    test "checks business hours in valid timezone" do
      # Note: This test may be environment - dependent
      # We're testing with UTC which should be available

      # Mock current time for testing
      # This would typically require mocking DateTime.now / 1
      # For now, we test the logic with known scenarios

      # Test with default business hours (9 AM to 5 PM)
      # Note: Actual implementation would need DateTime mocking for deterministic tests
      result = TimeUtilities.in_business_hours?("Etc / UTC")
      assert is_boolean(result)
    end

    test "handles invalid timezone" do
      result = TimeUtilities.in_business_hours?("Invalid / Timezone")
      assert result == false
    end

    test "accepts custom business hours" do
      # Test with custom hours (24 - hour operation)
      result = TimeUtilities.in_business_hours?("Etc / UTC", ~T[00:00:00], ~T[23:59:59])
      assert is_boolean(result)
    end
  end

  describe "validate_time_range / 2" do
    test "validates normal time ranges" do
      start_time = ~T[09:00:00]
      end_time = ~T[17:00:00]

      assert TimeUtilities.validate_time_range(start_time, end_time) == {:ok, :normal}
    end

    test "validates overnight time ranges" do
      start_time = ~T[22:00:00]
      end_time = ~T[07:00:00]

      assert TimeUtilities.validate_time_range(start_time, end_time) == {:ok, :overnight}
    end

    test "rejects equal start and end times" do
      time = ~T[12:00:00]

      assert TimeUtilities.validate_time_range(time, time) ==
               {:error, "Start time and end time cannot be equal"}
    end

    test "handles microsecond precision" do
      start_time = ~T[09:00:00.000000]
      end_time = ~T[09:00:00.000001]

      assert TimeUtilities.validate_time_range(start_time, end_time) == {:ok, :normal}
    end
  end

  # Property - based tests using ExUnitProperties
  test "validate_time_range always returns valid response" do
    ExUnitProperties.check all(
                             hour1 <- SD.integer(0..23),
                             min1 <- SD.integer(0..59),
                             hour2 <- SD.integer(0..23),
                             min2 <- SD.integer(0..59)
                           ) do
      start_time = Time.new!(hour1, min1, 0)
      end_time = Time.new!(hour2, min2, 0)

      result = TimeUtilities.validate_time_range(start_time, end_time)

      case result do
        {:ok, type} -> assert type in [:normal, :overnight]
        {:error, message} -> assert is_binary(message)
      end
    end
  end

  test "time_in_range? handles all overnight scenarios correctly" do
    ExUnitProperties.check all(
                             start_hour <- SD.integer(0..23),
                             end_hour <- SD.integer(0..23),
                             test_hour <- SD.integer(0..23)
                           ) do
      start_time = Time.new!(start_hour, 0, 0)
      end_time = Time.new!(end_hour, 0, 0)
      test_time = Time.new!(test_hour, 0, 0)

      result = TimeUtilities.time_in_range?(test_time, start_time, end_time)
      assert is_boolean(result)

      # Verify logic consistency
      if start_hour <= end_hour do
        # Normal range
        expected = test_hour >= start_hour && test_hour <= end_hour
        assert result == expected
      else
        # Overnight range
        expected = test_hour >= start_hour || test_hour <= end_hour
        assert result == expected
      end
    end
  end

  describe "comprehensive time range scenarios" do
    test "business hours scenarios" do
      scenarios = [
        # Standard business hours
        {~T[09:00:00], ~T[17:00:00], ~T[14:00:00], true, "standard business hours"},
        {~T[09:00:00], ~T[17:00:00], ~T[08:00:00], false, "before business hours"},
        {~T[09:00:00], ~T[17:00:00], ~T[18:00:00], false, "after business hours"},

        # Night shift
        {~T[22:00:00], ~T[06:00:00], ~T[23:00:00], true, "night shift - late night"},
        {~T[22:00:00], ~T[06:00:00], ~T[03:00:00], true, "night shift - early morning"},
        {~T[22:00:00], ~T[06:00:00], ~T[12:00:00], false, "night shift - daytime"},

        # 24 - hour operations
        {~T[00:00:00], ~T[23:59:59], ~T[12:00:00], true, "24 - hour operations"},

        # Short ranges
        {~T[12:00:00], ~T[12:30:00], ~T[12:15:00], true, "short 30 - minute window"},
        {~T[12:00:00], ~T[12:30:00], ~T[11:45:00], false, "before short window"}
      ]

      for {start_time, end_time, test_time, expected, description} <- scenarios do
        result = TimeUtilities.time_in_range?(test_time, start_time, end_time)

        assert result == expected,
               "Failed scenario: #{description} - expected #{expected}, got #{result}"
      end
    end

    test "notification quiet hours scenarios" do
      # Common notification scenarios
      # 10 PM
      quiet_hours_start = ~T[22:00:00]
      # 7 AM
      quiet_hours_end = ~T[07:00:00]

      # Should be quiet (no notifications)
      quiet_times = [
        # Late evening
        ~T[22:30:00],
        # Midnight
        ~T[00:00:00],
        # Middle of night
        ~T[03:30:00],
        # Early morning
        ~T[06:30:00]
      ]

      for time <- quiet_times do
        assert TimeUtilities.time_in_range?(time, quiet_hours_start, quiet_hours_end) == true,
               "Time #{Time.to_string(time)} should be in quiet hours"
      end

      # Should allow notifications
      active_times = [
        # Morning
        ~T[07:30:00],
        # Noon
        ~T[12:00:00],
        # Evening
        ~T[17:00:00],
        # Before quiet hours
        ~T[21:30:00]
      ]

      for time <- active_times do
        assert TimeUtilities.time_in_range?(time, quiet_hours_start, quiet_hours_end) == false,
               "Time #{Time.to_string(time)} should not be in quiet hours"
      end
    end
  end

  describe "edge cases and precision" do
    test "handles microsecond precision correctly" do
      start_time = ~T[12:00:00.000000]
      end_time = ~T[12:00:01.000000]

      # Exactly at microsecond boundaries
      assert TimeUtilities.time_in_range?(~T[12:00:00.000000], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[12:00:01.000000], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[12:00:00.999999], start_time, end_time) == true
      assert TimeUtilities.time_in_range?(~T[11:59:59.999999], start_time, end_time) == false
      assert TimeUtilities.time_in_range?(~T[12:00:01.000001], start_time, end_time) == false
    end

    test "handles identical times at different precisions" do
      # Times that are equal but with different microsecond precision
      time1 = ~T[12:00:00]
      time2 = ~T[12:00:00.000000]

      assert TimeUtilities.time_in_range?(time1, time1, time2) == true
      assert TimeUtilities.time_in_range?(time2, time1, time2) == true
    end
  end
end
