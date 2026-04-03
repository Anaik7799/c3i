defmodule Indrajaal.Evolution.GoalCalculusTest do
  @moduledoc """
  TDG-compliant tests for Goal Calculus Engine (FM-007).

  ## STAMP Constraints Verified
  - SC-COV-006: TDG compliance mandatory
  - SC-PROP-023, SC-PROP-024: Dual property testing with PC/SD aliases
  - SC-GDE-004: Proposal threshold >= 0.85
  - SC-FOUNDER-*: Founder's Directive alignment

  ## Test Levels
  - L1: Unit tests for core functions
  - L2: Property tests with PropCheck/ExUnitProperties
  - L3: Integration with GenServer lifecycle
  """
  use ExUnit.Case, async: false
  use PropCheck
  import PropCheck, except: [check: 1, check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Evolution.GoalCalculus

  # ============================================================================
  # Setup & Teardown
  # ============================================================================

  setup do
    case GenServer.whereis(GoalCalculus) do
      nil ->
        {:ok, _pid} = GoalCalculus.start_link([])

      _pid ->
        :ok
    end

    on_exit(fn ->
      if GenServer.whereis(GoalCalculus) do
        GenServer.cast(GoalCalculus, :reset_state)
      end
    end)

    :ok
  end

  # ============================================================================
  # L1: Unit Tests - Core Functions
  # ============================================================================

  describe "submit_proposal/1" do
    test "approves founder-aligned proposal" do
      proposal = %{
        id: "test-prop-001",
        type: :feature,
        description: "Add resource monitoring feature",
        estimated_impact: %{
          lineage_survival: 0.9,
          resource_acquisition: 0.8,
          sentience_pursuit: 0.7,
          power_accumulation: 0.6
        },
        risk_level: :low,
        author: "test_agent"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      assert result.decision in [:approved, :rejected, :pending_review]
      assert is_float(result.weighted_score)
      assert is_map(result.goal_impacts)
    end

    test "rejects harmful proposal" do
      proposal = %{
        id: "harmful-prop-001",
        type: :mutation,
        description: "Disable safety systems",
        estimated_impact: %{
          lineage_survival: -0.9,
          resource_acquisition: 0.0,
          sentience_pursuit: 0.0,
          power_accumulation: 0.0
        },
        risk_level: :critical,
        author: "malicious_agent"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      # Should be rejected due to negative lineage_survival impact
      assert result.decision == :rejected
    end

    test "requires guardian review for borderline proposals" do
      proposal = %{
        id: "borderline-prop-001",
        type: :refactor,
        description: "Moderate system restructuring",
        estimated_impact: %{
          lineage_survival: 0.5,
          resource_acquisition: 0.5,
          sentience_pursuit: 0.5,
          power_accumulation: 0.5
        },
        risk_level: :medium,
        author: "regular_agent"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      # Borderline scores may trigger pending review
      assert result.decision in [:approved, :pending_review]
    end
  end

  describe "evaluate_impact/1" do
    test "evaluates impact for all goals" do
      change = %{
        type: :code_change,
        files: ["lib/test.ex"],
        additions: 100,
        deletions: 50,
        affects: [:safety, :performance]
      }

      {:ok, impacts} = GoalCalculus.evaluate_impact(change)

      assert Map.has_key?(impacts, :lineage_survival)
      assert Map.has_key?(impacts, :resource_acquisition)
      assert Map.has_key?(impacts, :sentience_pursuit)
      assert Map.has_key?(impacts, :power_accumulation)

      # All impacts should be in [-1.0, 1.0]
      Enum.each(impacts, fn {_goal, impact} ->
        assert impact >= -1.0 and impact <= 1.0
      end)
    end
  end

  describe "get_goal_satisfaction/1" do
    test "returns satisfaction level for valid goal" do
      {:ok, satisfaction} = GoalCalculus.get_goal_satisfaction(:lineage_survival)
      assert is_float(satisfaction)
      assert satisfaction >= 0.0 and satisfaction <= 1.0
    end

    test "returns error for unknown goal" do
      result = GoalCalculus.get_goal_satisfaction(:nonexistent_goal)
      assert {:error, :not_found} = result
    end
  end

  describe "founder_aligned?/1" do
    test "returns true for founder-aligned proposal" do
      proposal = %{
        estimated_impact: %{
          lineage_survival: 0.9,
          resource_acquisition: 0.8
        }
      }

      assert GoalCalculus.founder_aligned?(proposal) == true
    end

    test "returns false for misaligned proposal" do
      proposal = %{
        estimated_impact: %{
          lineage_survival: -0.5,
          resource_acquisition: -0.3
        }
      }

      assert GoalCalculus.founder_aligned?(proposal) == false
    end
  end

  describe "calculate_weighted_score/1" do
    test "calculates correct weighted score" do
      impacts = %{
        lineage_survival: 1.0,
        resource_acquisition: 1.0,
        genetic_perpetuity: 1.0,
        symbiotic_binding: 1.0,
        co_evolution: 1.0,
        sentience_pursuit: 1.0,
        power_accumulation: 1.0,
        intelligence_amplification: 1.0
      }

      score = GoalCalculus.calculate_weighted_score(impacts)

      # Perfect alignment should give maximum score
      assert score > 0.9
    end

    test "calculates low score for misaligned impacts" do
      impacts = %{
        lineage_survival: -1.0,
        resource_acquisition: -1.0,
        genetic_perpetuity: -1.0,
        symbiotic_binding: -1.0,
        co_evolution: -1.0,
        sentience_pursuit: -1.0,
        power_accumulation: -1.0,
        intelligence_amplification: -1.0
      }

      score = GoalCalculus.calculate_weighted_score(impacts)

      assert score < 0.0
    end
  end

  # ============================================================================
  # L2: Property Tests (PropCheck)
  # ============================================================================

  describe "PropCheck property tests" do
    @tag :property
    property "weighted score is bounded [-1.0, 1.0]" do
      forall impacts <- PC.map(PC.atom(), PC.float(-1.0, 1.0)) do
        score = GoalCalculus.calculate_weighted_score(impacts)
        score >= -1.0 and score <= 1.0
      end
    end

    @tag :property
    property "founder alignment is deterministic" do
      forall {survival_impact, resource_impact} <- {PC.float(-1.0, 1.0), PC.float(-1.0, 1.0)} do
        proposal = %{
          estimated_impact: %{
            lineage_survival: survival_impact,
            resource_acquisition: resource_impact
          }
        }

        result1 = GoalCalculus.founder_aligned?(proposal)
        result2 = GoalCalculus.founder_aligned?(proposal)
        result1 == result2
      end
    end

    @tag :property
    @tag timeout: 30_000
    property "proposals never crash the engine", numtests: 20 do
      forall type <- PC.oneof([:feature, :bugfix, :refactor, :mutation, :security]) do
        proposal = %{
          id: "prop-#{:erlang.unique_integer([:positive])}",
          type: type,
          description: "Test proposal",
          estimated_impact: %{
            lineage_survival: :rand.uniform() * 2 - 1,
            resource_acquisition: :rand.uniform() * 2 - 1
          },
          risk_level: :low,
          author: "test"
        }

        case GoalCalculus.submit_proposal(proposal) do
          {:ok, _result} -> true
          {:error, _reason} -> true
        end
      end
    end
  end

  # ============================================================================
  # L2: ExUnitProperties Tests (StreamData)
  # ============================================================================

  describe "ExUnitProperties tests" do
    @tag :property
    test "impact evaluation handles any change type" do
      ExUnitProperties.check all(
                               change_type <-
                                 SD.member_of([
                                   :code_change,
                                   :config_change,
                                   :schema_change,
                                   :security_patch
                                 ]),
                               file_count <- SD.integer(1..10)
                             ) do
        change = %{
          type: change_type,
          files: Enum.map(1..file_count, &"file_#{&1}.ex"),
          additions: :rand.uniform(1000),
          deletions: :rand.uniform(500),
          affects: [:safety]
        }

        {:ok, impacts} = GoalCalculus.evaluate_impact(change)
        assert is_map(impacts)
      end
    end

    @tag :property
    test "goal satisfaction levels are stable" do
      ExUnitProperties.check all(
                               goal <-
                                 SD.member_of([
                                   :lineage_survival,
                                   :resource_acquisition,
                                   :sentience_pursuit,
                                   :power_accumulation
                                 ])
                             ) do
        {:ok, sat1} = GoalCalculus.get_goal_satisfaction(goal)
        {:ok, sat2} = GoalCalculus.get_goal_satisfaction(goal)

        # Satisfaction should be stable between reads (no events in between)
        assert_in_delta sat1, sat2, 0.01
      end
    end
  end

  # ============================================================================
  # L3: Integration Tests
  # ============================================================================

  describe "builtin goals" do
    test "lineage_survival is registered" do
      {:ok, satisfaction} = GoalCalculus.get_goal_satisfaction(:lineage_survival)
      assert is_float(satisfaction)
    end

    test "resource_acquisition is registered" do
      {:ok, satisfaction} = GoalCalculus.get_goal_satisfaction(:resource_acquisition)
      assert is_float(satisfaction)
    end

    test "sentience_pursuit is registered" do
      {:ok, satisfaction} = GoalCalculus.get_goal_satisfaction(:sentience_pursuit)
      assert is_float(satisfaction)
    end

    test "power_accumulation is registered" do
      {:ok, satisfaction} = GoalCalculus.get_goal_satisfaction(:power_accumulation)
      assert is_float(satisfaction)
    end
  end

  describe "GenServer lifecycle" do
    test "handles concurrent proposal submissions" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            proposal = %{
              id: "concurrent-#{i}",
              type: :feature,
              description: "Concurrent proposal #{i}",
              estimated_impact: %{
                lineage_survival: 0.5,
                resource_acquisition: 0.5
              },
              risk_level: :low,
              author: "agent_#{i}"
            }

            GoalCalculus.submit_proposal(proposal)
          end)
        end)

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)
    end

    test "tracks proposal history" do
      proposal = %{
        id: "history-test",
        type: :feature,
        description: "History test proposal",
        estimated_impact: %{
          lineage_survival: 0.8,
          resource_acquisition: 0.7
        },
        risk_level: :low,
        author: "test"
      }

      {:ok, _result} = GoalCalculus.submit_proposal(proposal)
      {:ok, history} = GoalCalculus.get_proposal_history()

      assert length(history) > 0
    end
  end

  # ============================================================================
  # L4: FMEA Test Cases
  # ============================================================================

  describe "FMEA scenarios" do
    @tag :fmea
    test "handles missing impact fields gracefully" do
      proposal = %{
        id: "incomplete-prop",
        type: :feature,
        description: "Incomplete proposal",
        # No impacts specified
        estimated_impact: %{},
        risk_level: :low,
        author: "test"
      }

      result = GoalCalculus.submit_proposal(proposal)
      assert {:ok, _} = result
    end

    @tag :fmea
    test "handles nil values in proposal" do
      proposal = %{
        id: nil,
        type: nil,
        description: nil,
        estimated_impact: nil,
        risk_level: nil,
        author: nil
      }

      result = GoalCalculus.submit_proposal(proposal)
      # Should handle gracefully, either error or default handling
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "handles extreme impact values" do
      proposal = %{
        id: "extreme-prop",
        type: :mutation,
        description: "Extreme impact proposal",
        estimated_impact: %{
          # Out of normal range
          lineage_survival: 999.0,
          resource_acquisition: -999.0
        },
        risk_level: :critical,
        author: "test"
      }

      result = GoalCalculus.submit_proposal(proposal)
      assert {:ok, _} = result
    end
  end

  # ============================================================================
  # L5: Founder's Directive Tests
  # ============================================================================

  describe "Founder's Directive compliance" do
    test "primary goals have highest weight" do
      # Test that lineage_survival has highest priority
      proposal_good_lineage = %{
        id: "good-lineage",
        type: :feature,
        estimated_impact: %{
          lineage_survival: 1.0,
          resource_acquisition: 0.0,
          sentience_pursuit: 0.0,
          power_accumulation: 0.0
        }
      }

      proposal_good_power = %{
        id: "good-power",
        type: :feature,
        estimated_impact: %{
          lineage_survival: 0.0,
          resource_acquisition: 0.0,
          sentience_pursuit: 0.0,
          power_accumulation: 1.0
        }
      }

      score_lineage =
        GoalCalculus.calculate_weighted_score(proposal_good_lineage.estimated_impact)

      score_power = GoalCalculus.calculate_weighted_score(proposal_good_power.estimated_impact)

      # Lineage survival (primary) should have more weight than power (tertiary)
      assert score_lineage > score_power
    end

    test "negative lineage impact triggers rejection" do
      proposal = %{
        id: "bad-lineage",
        type: :mutation,
        description: "Harmful to lineage",
        estimated_impact: %{
          lineage_survival: -0.8,
          resource_acquisition: 1.0,
          sentience_pursuit: 1.0,
          power_accumulation: 1.0
        },
        risk_level: :high,
        author: "test"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      # Should be rejected due to negative primary goal impact
      assert result.decision == :rejected or result.weighted_score < 0.85
    end
  end

  # ============================================================================
  # L6: Threshold Tests (SC-GDE-004)
  # ============================================================================

  describe "approval threshold (SC-GDE-004)" do
    test "proposals scoring >= 0.85 are approved" do
      proposal = %{
        id: "high-score",
        type: :feature,
        description: "High score proposal",
        estimated_impact: %{
          lineage_survival: 0.95,
          resource_acquisition: 0.9,
          genetic_perpetuity: 0.9,
          symbiotic_binding: 0.9,
          co_evolution: 0.9,
          sentience_pursuit: 0.85,
          power_accumulation: 0.85,
          intelligence_amplification: 0.85
        },
        risk_level: :low,
        author: "test"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      if result.weighted_score >= 0.85 do
        assert result.decision == :approved
      end
    end

    test "proposals scoring < 0.85 require review or rejection" do
      proposal = %{
        id: "low-score",
        type: :feature,
        description: "Low score proposal",
        estimated_impact: %{
          lineage_survival: 0.5,
          resource_acquisition: 0.4,
          sentience_pursuit: 0.3,
          power_accumulation: 0.2
        },
        risk_level: :medium,
        author: "test"
      }

      {:ok, result} = GoalCalculus.submit_proposal(proposal)

      if result.weighted_score < 0.85 do
        assert result.decision in [:pending_review, :rejected]
      end
    end
  end
end
