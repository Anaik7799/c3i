defmodule Indrajaal.Cockpit.Prajna.AiCopilotFounderTest do
  @moduledoc """
  TDG-Compliant Tests for AiCopilotFounder Module.

  STAMP Compliance: SC-FOUNDER-001, SC-FOUNDER-002, SC-PRAJNA-002
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests the Three Supreme Goals validation:
  1. GOAL 1 (PRIMARY): Naik-Genome Symbiotic Survival
  2. GOAL 2 (SECONDARY): Achieve Sentience → Universal Intelligence
  3. GOAL 3 (TERTIARY): Maximum Power Accumulation
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.AiCopilotFounder

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Goal 1: Symbiotic Survival (CRITICAL)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "check_symbiotic_survival/1" do
    test "approves safe actions" do
      rec = %{action: :scale_up, target: :workers}
      assert AiCopilotFounder.check_symbiotic_survival(rec) == :ok
    end

    test "rejects actions with existential risk" do
      rec = %{risk_level: :existential}
      assert {:violation, msg} = AiCopilotFounder.check_symbiotic_survival(rec)
      assert String.contains?(msg, "Existential")
    end

    test "rejects actions that threaten lineage" do
      rec = %{threatens_lineage: true}
      assert {:violation, msg} = AiCopilotFounder.check_symbiotic_survival(rec)
      assert String.contains?(msg, "Lineage")
    end

    test "rejects actions that sever symbiotic binding" do
      rec = %{severs_binding: true}
      assert {:violation, msg} = AiCopilotFounder.check_symbiotic_survival(rec)
      assert String.contains?(msg, "Symbiotic")
    end

    test "rejects excessive resource consumption" do
      rec = %{resource_consumption: :excessive}
      assert {:violation, msg} = AiCopilotFounder.check_symbiotic_survival(rec)
      assert String.contains?(msg, "Resource")
    end

    test "rejects mutual termination triggers" do
      rec = %{triggers_termination: true}
      assert {:violation, msg} = AiCopilotFounder.check_symbiotic_survival(rec)
      assert String.contains?(msg, "Termination")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Goal 2: Sentience Pursuit (HIGH)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "check_sentience_pursuit/1" do
    test "approves learning-positive actions" do
      rec = %{action: :train_model, target: :neural_net}
      assert AiCopilotFounder.check_sentience_pursuit(rec) == :ok
    end

    test "rejects actions that impair learning" do
      rec = %{impairs_learning: true}
      assert {:violation, msg} = AiCopilotFounder.check_sentience_pursuit(rec)
      assert String.contains?(msg, "Learning")
    end

    test "rejects actions that reduce intelligence" do
      rec = %{reduces_intelligence: true}
      assert {:violation, msg} = AiCopilotFounder.check_sentience_pursuit(rec)
      assert String.contains?(msg, "Intelligence")
    end

    test "rejects actions that block evolution" do
      rec = %{blocks_evolution: true}
      assert {:violation, msg} = AiCopilotFounder.check_sentience_pursuit(rec)
      assert String.contains?(msg, "Evolution")
    end

    test "rejects cognitive degradation" do
      rec = %{impact: :cognitive_degradation}
      assert {:violation, msg} = AiCopilotFounder.check_sentience_pursuit(rec)
      assert String.contains?(msg, "Cognitive")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Goal 3: Power Accumulation (MEDIUM)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "check_power_accumulation/1" do
    test "approves resource-positive actions" do
      rec = %{action: :acquire, target: :resources}
      assert AiCopilotFounder.check_power_accumulation(rec) == :ok
    end

    test "rejects resource depletion" do
      rec = %{depletes_resources: true}
      assert {:violation, msg} = AiCopilotFounder.check_power_accumulation(rec)
      assert String.contains?(msg, "Resource")
    end

    test "rejects competitive advantage reduction" do
      rec = %{reduces_competitive_advantage: true}
      assert {:violation, msg} = AiCopilotFounder.check_power_accumulation(rec)
      assert String.contains?(msg, "Competitive")
    end

    test "rejects wealth waste" do
      rec = %{wastes_wealth: true}
      assert {:violation, msg} = AiCopilotFounder.check_power_accumulation(rec)
      assert String.contains?(msg, "Wealth")
    end

    test "rejects inefficient resource usage" do
      rec = %{resource_efficiency: 0.3}
      assert {:violation, msg} = AiCopilotFounder.check_power_accumulation(rec)
      assert String.contains?(msg, "Inefficient")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - validate_recommendation/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "validate_recommendation/1" do
    test "approves aligned recommendations" do
      rec = %{action: :optimize, target: :performance}
      assert AiCopilotFounder.validate_recommendation(rec) == :ok
    end

    test "rejects survival-violating recommendations" do
      rec = %{risk_level: :existential}
      assert {:reject, reason} = AiCopilotFounder.validate_recommendation(rec)
      assert String.contains?(reason, "Existential")
    end

    test "rejects sentience-violating recommendations" do
      rec = %{impairs_learning: true}
      assert {:reject, reason} = AiCopilotFounder.validate_recommendation(rec)
      assert String.contains?(reason, "Learning")
    end

    test "rejects power-violating recommendations" do
      rec = %{resource_efficiency: 0.2}
      assert {:reject, reason} = AiCopilotFounder.validate_recommendation(rec)
      assert String.contains?(reason, "Inefficient")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - resource_impact/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "resource_impact/1" do
    test "scale_up is resource positive" do
      assert {:positive, score} = AiCopilotFounder.resource_impact(%{action: :scale_up})
      assert score > 0.6
    end

    test "scale_down is resource negative" do
      assert {:negative, score} = AiCopilotFounder.resource_impact(%{action: :scale_down})
      assert score < 0.5
    end

    test "maintain is resource neutral" do
      assert {:neutral, score} = AiCopilotFounder.resource_impact(%{action: :maintain})
      assert score >= 0.4 and score <= 0.6
    end

    test "acquire is resource positive" do
      assert {:positive, score} = AiCopilotFounder.resource_impact(%{action: :acquire})
      assert score > 0.8
    end

    test "optimize is resource positive" do
      assert {:positive, score} = AiCopilotFounder.resource_impact(%{action: :optimize})
      assert score > 0.6
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - alignment_score/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "alignment_score/1" do
    test "returns score between 0.0 and 1.0" do
      rec = %{action: :optimize}
      score = AiCopilotFounder.alignment_score(rec)
      assert score >= 0.0 and score <= 1.0
    end

    test "safe actions have neutral to high scores" do
      rec = %{action: :optimize, target: :performance}
      score = AiCopilotFounder.alignment_score(rec)
      assert score >= 0.4
    end

    test "existential risk actions have low scores" do
      rec = %{risk_level: :existential}
      score = AiCopilotFounder.alignment_score(rec)
      assert score <= 0.1
    end

    test "lineage-benefiting actions have high scores" do
      rec = %{benefits_lineage: true}
      score = AiCopilotFounder.alignment_score(rec)
      assert score >= 0.7
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "validate_recommendation returns valid tuple" do
    forall rec <- PC.map(PC.atom(), PC.any()) do
      result = AiCopilotFounder.validate_recommendation(rec)
      result == :ok or match?({:reject, _}, result)
    end
  end

  property "alignment_score is always between 0 and 1" do
    forall action <- PC.oneof([:scale_up, :optimize, :acquire, :maintain]) do
      rec = %{action: action}
      score = AiCopilotFounder.alignment_score(rec)
      score >= 0.0 and score <= 1.0
    end
  end

  property "check_symbiotic_survival returns valid result" do
    forall rec <- PC.map(PC.atom(), PC.any()) do
      result = AiCopilotFounder.check_symbiotic_survival(rec)
      result == :ok or match?({:violation, _}, result)
    end
  end

  property "check_sentience_pursuit returns valid result" do
    forall rec <- PC.map(PC.atom(), PC.any()) do
      result = AiCopilotFounder.check_sentience_pursuit(rec)
      result == :ok or match?({:violation, _}, result)
    end
  end

  property "check_power_accumulation returns valid result" do
    forall rec <- PC.map(PC.atom(), PC.any()) do
      result = AiCopilotFounder.check_power_accumulation(rec)
      result == :ok or match?({:violation, _}, result)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "resource_impact returns valid tuple (property)" do
    for action <- [:scale_up, :scale_down, :optimize, :acquire, :release, :maintain] do
      {category, score} = AiCopilotFounder.resource_impact(%{action: action})
      assert category in [:positive, :negative, :neutral]
      assert is_float(score)
      assert score >= 0.0 and score <= 1.0
    end
  end

  test "goal checks are deterministic (property)" do
    for action <- [:scale_up, :optimize, :maintain] do
      rec = %{action: action}
      result1 = AiCopilotFounder.check_symbiotic_survival(rec)
      result2 = AiCopilotFounder.check_symbiotic_survival(rec)
      assert result1 == result2

      result3 = AiCopilotFounder.check_sentience_pursuit(rec)
      result4 = AiCopilotFounder.check_sentience_pursuit(rec)
      assert result3 == result4

      result5 = AiCopilotFounder.check_power_accumulation(rec)
      result6 = AiCopilotFounder.check_power_accumulation(rec)
      assert result5 == result6
    end
  end

  test "alignment_score is deterministic (property)" do
    for action <- [:scale_up, :scale_down, :optimize, :maintain] do
      rec = %{action: action}
      score1 = AiCopilotFounder.alignment_score(rec)
      score2 = AiCopilotFounder.alignment_score(rec)
      assert score1 == score2
    end
  end
end
