defmodule Indrajaal.Observability.DefaultImplTest do
  use ExUnit.Case, async: true

  # Create test module using DefaultImpl
  defmodule TestHelper do
    use Indrajaal.Observability.DefaultImpl
  end

  # Create test module with overridden functions
  defmodule CustomHelper do
    use Indrajaal.Observability.DefaultImpl

    def health_check do
      {:ok, %{status: :custom_healthy, module: __MODULE__}}
    end

    def validate_config(_config) do
      {:ok, %{valid: true, custom: true}}
    end
  end

  describe "health_check/0" do
    test "returns ok tuple with status, module, and timestamp" do
      assert {:ok, %{status: :healthy, module: module, timestamp: timestamp}} =
               TestHelper.health_check()

      assert module == TestHelper
      assert is_integer(timestamp)
      assert timestamp > 0
    end

    test "timestamp is current system time" do
      before = System.system_time(:second)
      {:ok, %{timestamp: timestamp}} = TestHelper.health_check()
      after_time = System.system_time(:second)

      assert timestamp >= before
      assert timestamp <= after_time
    end

    test "can be overridden in using module" do
      assert {:ok, %{status: :custom_healthy, module: CustomHelper}} =
               CustomHelper.health_check()
    end
  end

  describe "validate_config/1" do
    test "returns ok tuple with valid true for map config" do
      config = %{key1: "value1", key2: "value2"}

      assert {:ok, %{valid: true, validated_fields: fields}} =
               TestHelper.validate_config(config)

      assert :key1 in fields
      assert :key2 in fields
    end

    test "returns validated fields as map keys" do
      config = %{setting1: true, setting2: false, setting3: "value"}

      assert {:ok, %{validated_fields: fields}} = TestHelper.validate_config(config)

      assert length(fields) == 3
      assert :setting1 in fields
      assert :setting2 in fields
      assert :setting3 in fields
    end

    test "returns error tuple for non-map config" do
      assert {:error, ["Configuration must be a map"]} = TestHelper.validate_config("not a map")
    end

    test "returns error for list config" do
      assert {:error, ["Configuration must be a map"]} = TestHelper.validate_config([1, 2, 3])
    end

    test "returns error for atom config" do
      assert {:error, ["Configuration must be a map"]} = TestHelper.validate_config(:config)
    end

    test "returns error for nil config" do
      assert {:error, ["Configuration must be a map"]} = TestHelper.validate_config(nil)
    end

    test "accepts empty map" do
      assert {:ok, %{valid: true, validated_fields: []}} = TestHelper.validate_config(%{})
    end

    test "can be overridden in using module" do
      assert {:ok, %{valid: true, custom: true}} = CustomHelper.validate_config(%{test: true})
    end
  end

  describe "performance_test/1" do
    test "returns ok tuple with test results for map config" do
      config = %{test: "performance"}

      assert {:ok,
              %{
                module: module,
                test_passed: true,
                performance_grade: "A",
                test_timestamp: timestamp
              }} = TestHelper.performance_test(config)

      assert module == TestHelper
      assert is_integer(timestamp)
    end

    test "performance grade is always A" do
      {:ok, %{performance_grade: grade}} = TestHelper.performance_test(%{})

      assert grade == "A"
    end

    test "test_passed is always true" do
      {:ok, %{test_passed: passed}} = TestHelper.performance_test(%{})

      assert passed == true
    end

    test "includes current timestamp" do
      before = System.system_time(:second)
      {:ok, %{test_timestamp: timestamp}} = TestHelper.performance_test(%{})
      after_time = System.system_time(:second)

      assert timestamp >= before
      assert timestamp <= after_time
    end

    test "returns error for non-map config" do
      assert {:error, :invalid_config} = TestHelper.performance_test("not a map")
    end

    test "returns error for list config" do
      assert {:error, :invalid_config} = TestHelper.performance_test([1, 2])
    end

    test "returns error for nil config" do
      assert {:error, :invalid_config} = TestHelper.performance_test(nil)
    end

    test "accepts empty map" do
      assert {:ok, %{test_passed: true}} = TestHelper.performance_test(%{})
    end
  end

  describe "integration_test/1" do
    test "returns ok tuple with integration results for map config" do
      config = %{integration: "test"}

      assert {:ok,
              %{
                module: module,
                integration_ready: true,
                success_rate: 100.0,
                test_timestamp: timestamp
              }} = TestHelper.integration_test(config)

      assert module == TestHelper
      assert is_integer(timestamp)
    end

    test "integration_ready is always true" do
      {:ok, %{integration_ready: ready}} = TestHelper.integration_test(%{})

      assert ready == true
    end

    test "success_rate is always 100.0" do
      {:ok, %{success_rate: rate}} = TestHelper.integration_test(%{})

      assert rate == 100.0
    end

    test "includes current timestamp" do
      before = System.system_time(:second)
      {:ok, %{test_timestamp: timestamp}} = TestHelper.integration_test(%{})
      after_time = System.system_time(:second)

      assert timestamp >= before
      assert timestamp <= after_time
    end

    test "returns error for non-map config" do
      assert {:error, :invalid_config} = TestHelper.integration_test("not a map")
    end

    test "returns error for atom config" do
      assert {:error, :invalid_config} = TestHelper.integration_test(:config)
    end

    test "accepts empty map" do
      assert {:ok, %{integration_ready: true}} = TestHelper.integration_test(%{})
    end
  end

  describe "get_stats/0" do
    test "returns ok tuple with stats" do
      assert {:ok, %{module: module, status: :running, stats_timestamp: timestamp}} =
               TestHelper.get_stats()

      assert module == TestHelper
      assert is_integer(timestamp)
    end

    test "status is always running" do
      {:ok, %{status: status}} = TestHelper.get_stats()

      assert status == :running
    end

    test "includes current timestamp" do
      before = System.system_time(:second)
      {:ok, %{stats_timestamp: timestamp}} = TestHelper.get_stats()
      after_time = System.system_time(:second)

      assert timestamp >= before
      assert timestamp <= after_time
    end
  end

  describe "reset/0" do
    test "returns :ok atom" do
      assert :ok = TestHelper.reset()
    end

    test "can be called multiple times" do
      assert :ok = TestHelper.reset()
      assert :ok = TestHelper.reset()
      assert :ok = TestHelper.reset()
    end
  end

  describe "defoverridable functionality" do
    test "all 6 functions are overridable" do
      # CustomHelper overrides health_check and validate_config
      # Verify they return custom values
      assert {:ok, %{status: :custom_healthy}} = CustomHelper.health_check()
      assert {:ok, %{custom: true}} = CustomHelper.validate_config(%{})

      # Verify non-overridden functions still work with defaults
      assert {:ok, %{test_passed: true}} = CustomHelper.performance_test(%{})
      assert {:ok, %{integration_ready: true}} = CustomHelper.integration_test(%{})
      assert {:ok, %{status: :running}} = CustomHelper.get_stats()
      assert :ok = CustomHelper.reset()
    end
  end

  describe "using module integration" do
    test "creates module with all expected functions" do
      functions = TestHelper.__info__(:functions)

      assert {:health_check, 0} in functions
      assert {:validate_config, 1} in functions
      assert {:performance_test, 1} in functions
      assert {:integration_test, 1} in functions
      assert {:get_stats, 0} in functions
      assert {:reset, 0} in functions
    end

    test "functions have correct module attribute" do
      {:ok, %{module: module1}} = TestHelper.health_check()
      {:ok, %{module: module2}} = TestHelper.performance_test(%{})
      {:ok, %{module: module3}} = TestHelper.integration_test(%{})
      {:ok, %{module: module4}} = TestHelper.get_stats()

      assert module1 == TestHelper
      assert module2 == TestHelper
      assert module3 == TestHelper
      assert module4 == TestHelper
    end
  end

  describe "timestamp consistency" do
    test "all timestamps use System.system_time(:second)" do
      {:ok, %{timestamp: t1}} = TestHelper.health_check()
      {:ok, %{test_timestamp: t2}} = TestHelper.performance_test(%{})
      {:ok, %{test_timestamp: t3}} = TestHelper.integration_test(%{})
      {:ok, %{stats_timestamp: t4}} = TestHelper.get_stats()

      # All should be within a second of each other
      assert abs(t1 - t2) <= 1
      assert abs(t2 - t3) <= 1
      assert abs(t3 - t4) <= 1
    end
  end

  describe "config validation patterns" do
    test "all test functions accept map and reject non-map" do
      valid_config = %{test: true}

      # All should accept map
      assert {:ok, _} = TestHelper.validate_config(valid_config)
      assert {:ok, _} = TestHelper.performance_test(valid_config)
      assert {:ok, _} = TestHelper.integration_test(valid_config)

      # All should reject non-map (validate_config returns error tuple, others return error atom)
      assert {:error, ["Configuration must be a map"]} = TestHelper.validate_config("string")
      assert {:error, :invalid_config} = TestHelper.performance_test("string")
      assert {:error, :invalid_config} = TestHelper.integration_test("string")
    end
  end

  describe "macro injection" do
    test "module can use DefaultImpl and get all functions" do
      defmodule DynamicHelper do
        use Indrajaal.Observability.DefaultImpl
      end

      assert {:ok, %{status: :healthy}} = DynamicHelper.health_check()
      assert {:ok, %{valid: true}} = DynamicHelper.validate_config(%{})
      assert {:ok, %{test_passed: true}} = DynamicHelper.performance_test(%{})
      assert {:ok, %{integration_ready: true}} = DynamicHelper.integration_test(%{})
      assert {:ok, %{status: :running}} = DynamicHelper.get_stats()
      assert :ok = DynamicHelper.reset()
    end

    test "module can selectively override functions" do
      defmodule PartialOverride do
        use Indrajaal.Observability.DefaultImpl

        def reset do
          {:custom, :reset}
        end
      end

      # Overridden function returns custom value
      assert {:custom, :reset} = PartialOverride.reset()

      # Non-overridden functions use defaults
      assert {:ok, %{status: :healthy}} = PartialOverride.health_check()
      assert {:ok, %{valid: true}} = PartialOverride.validate_config(%{})
    end
  end

  describe "edge cases and error handling" do
    test "validate_config handles complex nested maps" do
      complex_config = %{
        nested: %{
          deep: %{
            value: "test"
          }
        },
        list: [1, 2, 3],
        atom: :test
      }

      assert {:ok, %{valid: true, validated_fields: fields}} =
               TestHelper.validate_config(complex_config)

      assert :nested in fields
      assert :list in fields
      assert :atom in fields
    end

    test "performance_test accepts config with any values" do
      config = %{
        number: 123,
        string: "test",
        atom: :value,
        list: [1, 2, 3],
        map: %{nested: true}
      }

      assert {:ok, %{test_passed: true, performance_grade: "A"}} =
               TestHelper.performance_test(config)
    end

    test "integration_test accepts config with any values" do
      config = %{
        boolean: true,
        float: 3.14,
        tuple: {:ok, "value"}
      }

      assert {:ok, %{integration_ready: true, success_rate: 100.0}} =
               TestHelper.integration_test(config)
    end
  end

  describe "additional code issues found in source" do
    test "BUG: line 12 - double underscore prefix in parameter '__config'" do
      # Line 12: "  def validate_config(__config) when is_map(__config) do"
      #                            ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: config (without double underscore prefix)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to config
      # Note: Used in guard clause and function body on line 13
    end

    test "BUG: line 13 - double underscore prefix in Map.keys call" do
      # Line 13: "    {:ok, %{valid: true, validated_fields: Map.keys(__config)}}"
      #                                                                ^^^^^^^^^^ BUG
      # Should be: Map.keys(config)
      # Impact: Using __config with double underscore prefix
      # Fix: Change __config to config
      # Note: This is the usage of the parameter from line 12
    end

    test "BUG: line 20 - double underscore prefix in parameter '__config'" do
      # Line 20: "  def performance_test(__config) when is_map(__config) do"
      #                              ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: config (without double underscore prefix)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to config
      # Note: Used in guard clause but not in function body
    end

    test "BUG: line 34 - double underscore prefix in parameter '__config'" do
      # Line 34: "  def integration_test(__config) when is_map(__config) do"
      #                               ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: config (without double underscore prefix)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to config
      # Note: Used in guard clause but not in function body
    end

    test "NOTE: line 44 - inconsistent parameter naming (no underscore prefix)" do
      # Line 44: "  def integration_test(config) do"
      #                               ^^^^^^ INCONSISTENT - no prefix
      # Previous function head (line 34) uses __config
      # This catch-all clause uses config (without prefix)
      # Impact: Inconsistent parameter naming between function heads
      # Recommendation: Use _config (single underscore) for unused catch-all parameters
      # Note: This parameter is intentionally unused in the error return
    end
  end
end
