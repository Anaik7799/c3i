defmodule Indrajaal.Testing.TPSFiveLevelRCAIntegrationTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.TPSFiveLevelRCAIntegration

  @valid_failure %{
    test_name: "Indrajaal.AlarmTest.test alarm processing",
    module: "Indrajaal.AlarmTest",
    error_message: "assertion failed: expected :ok, got {:error, :timeout}",
    duration_ms: 142
  }

  # The module writes to ./data/tmp/ — ensure that path exists for tests
  setup_all do
    File.mkdir_p!("./data/tmp")
    :ok
  end

  describe "analyze_test_failure/1" do
    test "returns a map" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      assert is_map(result)
    end

    test "result contains all five RCA levels" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)

      assert Map.has_key?(result, :level_1)
      assert Map.has_key?(result, :level_2)
      assert Map.has_key?(result, :level_3)
      assert Map.has_key?(result, :level_4)
      assert Map.has_key?(result, :level_5)
    end

    test "level_1 contains symptom description and test name" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      l1 = result.level_1

      assert is_map(l1)
      assert Map.has_key?(l1, :description)
      assert Map.has_key?(l1, :test_name)
      assert l1.test_name == @valid_failure.test_name
    end

    test "level_1 contains error message from input" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      assert result.level_1.error_message == @valid_failure.error_message
    end

    test "level_1 classifies failure type" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      assert Map.has_key?(result.level_1, :failure_type)
    end

    test "level_1 assesses immediate impact" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      assert Map.has_key?(result.level_1, :immediate_impact)
    end

    test "level_2 describes surface cause analysis" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      l2 = result.level_2

      assert is_map(l2)
      assert Map.has_key?(l2, :description)
      assert Map.has_key?(l2, :code_location)
    end

    test "level_3 describes system behavior" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      l3 = result.level_3

      assert is_map(l3)
      assert Map.has_key?(l3, :description)
    end

    test "level_4 identifies configuration gaps" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      l4 = result.level_4

      assert is_map(l4)
      assert Map.has_key?(l4, :description)
    end

    test "level_5 includes prevention strategies" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      l5 = result.level_5

      assert is_map(l5)
      assert Map.has_key?(l5, :description)
      assert Map.has_key?(l5, :prevention_strategies)
    end

    test "works with minimal failure map containing only test_name and error_message" do
      minimal = %{test_name: "some test", error_message: "failed"}
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(minimal)

      assert is_map(result)
      assert Map.has_key?(result, :level_1)
    end

    test "result has exactly five top-level keys" do
      result = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      assert map_size(result) == 5
    end

    test "produces consistent output for the same input" do
      result_1 = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)
      result_2 = TPSFiveLevelRCAIntegration.analyze_test_failure(@valid_failure)

      assert result_1.level_1.test_name == result_2.level_1.test_name
      assert result_1.level_1.error_message == result_2.level_1.error_message
    end
  end
end
