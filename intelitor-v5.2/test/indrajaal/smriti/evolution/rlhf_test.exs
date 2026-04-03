defmodule Indrajaal.Smriti.Evolution.RLHFTest do
  @moduledoc """
  TDG test suite for Smriti.Evolution.RLHF.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-AI-006: Session distillation to SMRITI holons MANDATORY

  ## TPS 5-Level RCA Context
  - L1 Symptom: Human feedback not recorded
  - L5 Root Cause: Missing score validation (must be -1 or 1)
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Evolution.RLHF

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RLHF)
    end

    test "record_feedback/3 is exported" do
      assert function_exported?(RLHF, :record_feedback, 3)
    end
  end

  describe "record_feedback/3 with valid upvote" do
    test "returns ok tuple with target id and score for upvote" do
      result = RLHF.record_feedback("holon_123", 1, "Great response")
      assert match?({:ok, %{id: "holon_123", score: 1}}, result)
    end
  end

  describe "record_feedback/3 with valid downvote" do
    test "returns ok tuple with target id and score for downvote" do
      result = RLHF.record_feedback("holon_456", -1, "Poor response")
      assert match?({:ok, %{id: "holon_456", score: -1}}, result)
    end
  end

  describe "record_feedback/3 with invalid score" do
    test "returns error for score 0" do
      result = RLHF.record_feedback("holon_789", 0, "Neutral")
      assert match?({:error, _}, result)
    end

    test "returns error for score 2" do
      result = RLHF.record_feedback("holon_789", 2, "Too high")
      assert match?({:error, _}, result)
    end

    test "returns error for score -2" do
      result = RLHF.record_feedback("holon_789", -2, "Too low")
      assert match?({:error, _}, result)
    end

    test "error message describes valid scores" do
      {:error, msg} = RLHF.record_feedback("holon_789", 5, "Invalid")
      assert is_binary(msg)
    end
  end

  describe "record_feedback/3 with empty comment" do
    test "accepts empty comment string" do
      result = RLHF.record_feedback("holon_001", 1, "")
      assert match?({:ok, _}, result)
    end
  end
end
