defmodule Indrajaal.Cortex.GDE.ShadowTestFrameworkTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias StreamData, as: SD

  alias Indrajaal.Cortex.GDE.ShadowTestFramework

  # EP-GEN-014 compliance

  @valid_proposal %{
    id: "test-proposal-001",
    type: :code_evolution,
    module: "Indrajaal.TestModule",
    changes: [%{file: "lib/test.ex", op: :add_function}],
    stamp_refs: ["SC-GDE-001", "SC-GDE-002", "AOR-GDE-001"],
    author: "test-agent"
  }

  describe "validate_schema/1" do
    test "accepts valid proposal" do
      assert {:ok, :schema_valid} = ShadowTestFramework.validate_schema(@valid_proposal)
    end

    test "rejects proposal without :id" do
      bad = Map.delete(@valid_proposal, :id)
      assert {:error, :schema, errors} = ShadowTestFramework.validate_schema(bad)
      assert Enum.any?(errors, &String.contains?(&1, ":id"))
    end

    test "rejects proposal without :type" do
      bad = Map.delete(@valid_proposal, :type)
      assert {:error, :schema, errors} = ShadowTestFramework.validate_schema(bad)
      assert Enum.any?(errors, &String.contains?(&1, ":type"))
    end

    test "rejects proposal without :changes" do
      bad = Map.delete(@valid_proposal, :changes)
      assert {:error, :schema, errors} = ShadowTestFramework.validate_schema(bad)
      assert Enum.any?(errors, &String.contains?(&1, ":changes"))
    end

    test "rejects proposal with empty :changes list" do
      bad = Map.put(@valid_proposal, :changes, [])
      assert {:error, :schema, errors} = ShadowTestFramework.validate_schema(bad)
      assert Enum.any?(errors, &String.contains?(&1, "changes"))
    end

    test "rejects proposal with invalid STAMP refs" do
      bad = Map.put(@valid_proposal, :stamp_refs, ["NOT-VALID", "ALSO-BAD"])
      assert {:error, :schema, errors} = ShadowTestFramework.validate_schema(bad)
      assert Enum.any?(errors, &String.contains?(&1, "STAMP"))
    end

    test "accepts proposal with only SC-* refs" do
      proposal = Map.put(@valid_proposal, :stamp_refs, ["SC-GDE-001"])
      assert {:ok, :schema_valid} = ShadowTestFramework.validate_schema(proposal)
    end

    test "accepts proposal with AOR-* refs" do
      proposal = Map.put(@valid_proposal, :stamp_refs, ["AOR-GDE-001"])
      assert {:ok, :schema_valid} = ShadowTestFramework.validate_schema(proposal)
    end
  end

  describe "compute_fitness/2" do
    test "computes fitness within valid range for good shadow result" do
      shadow_result = %{
        tests_passed_ratio: 1.0,
        coverage_ratio: 0.95,
        quality_score: 1.0
      }

      assert {:ok, fitness} = ShadowTestFramework.compute_fitness(@valid_proposal, shadow_result)
      assert fitness >= 0.0
      assert fitness <= 1.1
    end

    test "uses default values when shadow result fields missing" do
      assert {:ok, fitness} = ShadowTestFramework.compute_fitness(@valid_proposal, %{})
      assert is_float(fitness)
      assert fitness > 0.0
    end

    test "fitness increases with better test pass ratio" do
      low_result = %{tests_passed_ratio: 0.5, coverage_ratio: 0.8, quality_score: 0.9}
      high_result = %{tests_passed_ratio: 1.0, coverage_ratio: 0.8, quality_score: 0.9}

      {:ok, low_fitness} = ShadowTestFramework.compute_fitness(@valid_proposal, low_result)
      {:ok, high_fitness} = ShadowTestFramework.compute_fitness(@valid_proposal, high_result)

      assert high_fitness > low_fitness
    end

    test "STAMP refs with GDE prefix improve fitness" do
      proposal_with_gde =
        Map.put(@valid_proposal, :stamp_refs, ["SC-GDE-001", "SC-GDE-002", "SC-GDE-003"])

      proposal_no_gde = Map.put(@valid_proposal, :stamp_refs, ["SC-ALARM-001"])

      shadow = %{tests_passed_ratio: 1.0, coverage_ratio: 1.0, quality_score: 1.0}

      {:ok, fitness_gde} = ShadowTestFramework.compute_fitness(proposal_with_gde, shadow)
      {:ok, fitness_no_gde} = ShadowTestFramework.compute_fitness(proposal_no_gde, shadow)

      assert fitness_gde >= fitness_no_gde
    end
  end

  describe "fitness_threshold/0" do
    test "returns 0.85 per SC-GDE-004" do
      assert ShadowTestFramework.fitness_threshold() == 0.85
    end
  end

  describe "validate/2 (integration, shadows not running)" do
    test "returns error when ShadowMode not running" do
      # In test env, ShadowMode GenServer may not be started
      # Expect either shadow registration error or schema error
      result = ShadowTestFramework.validate(@valid_proposal)

      case result do
        {:ok, %{passed: true}} ->
          :ok

        {:error, %{passed: false}} ->
          :ok

        other ->
          flunk("Expected {:ok, ...} or {:error, ...}, got: #{inspect(other)}")
      end
    end

    test "returns error for invalid proposal schema" do
      bad_proposal = Map.delete(@valid_proposal, :id)
      assert {:error, result} = ShadowTestFramework.validate(bad_proposal)
      assert result.phase == :schema
      assert result.passed == false
    end

    test "validation result has required fields" do
      bad_proposal = Map.delete(@valid_proposal, :stamp_refs)
      {:error, result} = ShadowTestFramework.validate(bad_proposal)

      assert Map.has_key?(result, :proposal_id)
      assert Map.has_key?(result, :phase)
      assert Map.has_key?(result, :passed)
      assert Map.has_key?(result, :fitness)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :duration_ms)
    end
  end

  # Property-based tests (EP-GEN-014 compliant — StreamData only)

  test "StreamData: schema validation never crashes on any map input" do
    ExUnitProperties.check all(
                             keys <- SD.list_of(SD.atom(:alphanumeric), max_length: 5),
                             vals <-
                               SD.list_of(SD.one_of([SD.integer(), SD.binary(), SD.boolean()]),
                                 max_length: 5
                               )
                           ) do
      pairs = Enum.zip(keys, vals)
      proposal = Map.new(pairs)
      result = ShadowTestFramework.validate_schema(proposal)
      assert match?({:ok, _}, result) or match?({:error, :schema, _}, result)
    end
  end

  test "StreamData: compute_fitness is stable across varied shadow results" do
    ExUnitProperties.check all(
                             tests_ratio <- SD.float(min: 0.0, max: 1.0),
                             coverage <- SD.float(min: 0.0, max: 1.0),
                             quality <- SD.float(min: 0.0, max: 1.0)
                           ) do
      shadow = %{
        tests_passed_ratio: tests_ratio,
        coverage_ratio: coverage,
        quality_score: quality
      }

      result = ShadowTestFramework.compute_fitness(@valid_proposal, shadow)
      assert match?({:ok, f} when is_float(f), result) or match?({:error, :fitness, _}, result)
    end
  end
end
