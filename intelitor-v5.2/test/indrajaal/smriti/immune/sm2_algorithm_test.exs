defmodule Indrajaal.Smriti.Immune.SM2AlgorithmTest do
  @moduledoc """
  TDG test suite for Smriti.Immune.SM2Algorithm.

  ## STAMP Safety Integration
  - SC-SMRITI-SRS-001: Interval MUST be non-negative
  - SC-SMRITI-SRS-002: EF MUST NOT drop below 1.3

  ## TPS 5-Level RCA Context
  - L1 Symptom: Knowledge retention intervals incorrect
  - L5 Root Cause: EF floor constraint not enforced
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Immune.SM2Algorithm

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SM2Algorithm)
    end

    test "next_step/4 is exported" do
      assert function_exported?(SM2Algorithm, :next_step, 4)
    end

    test "next_step/3 is exported (default ef)" do
      assert function_exported?(SM2Algorithm, :next_step, 3)
    end
  end

  describe "next_step/3 first repetition" do
    test "first repetition with quality >= 3 returns interval of 1" do
      result = SM2Algorithm.next_step(4, 0, 0)
      assert result.interval == 1
      assert result.repetition == 1
    end

    test "result contains required fields" do
      result = SM2Algorithm.next_step(4, 0, 0)
      assert Map.has_key?(result, :interval)
      assert Map.has_key?(result, :ef)
      assert Map.has_key?(result, :repetition)
      assert Map.has_key?(result, :next_review)
    end
  end

  describe "next_step/3 second repetition" do
    test "second repetition with quality >= 3 returns interval of 6" do
      result = SM2Algorithm.next_step(4, 1, 1)
      assert result.interval == 6
      assert result.repetition == 2
    end
  end

  describe "next_step/3 subsequent repetitions" do
    test "third+ repetition interval grows with EF" do
      result = SM2Algorithm.next_step(5, 2, 6)
      assert result.interval > 6
      assert result.repetition == 3
    end
  end

  describe "EF constraints (SC-SMRITI-SRS-002)" do
    test "EF does not drop below minimum of 1.3" do
      # Quality 0 = complete blackout, should reduce EF
      result = SM2Algorithm.next_step(0, 3, 6, 1.4)
      assert result.ef >= 1.3
    end

    test "EF stays at minimum with repeated poor quality" do
      result = SM2Algorithm.next_step(0, 3, 6, 1.3)
      assert result.ef >= 1.3
    end
  end

  describe "interval non-negative (SC-SMRITI-SRS-001)" do
    test "interval is always positive" do
      result = SM2Algorithm.next_step(5, 0, 0)
      assert result.interval >= 1
    end

    test "interval is positive even after failed quality" do
      result = SM2Algorithm.next_step(0, 5, 30)
      assert result.interval >= 1
    end
  end

  describe "quality below 3 resets repetition" do
    test "quality 2 resets repetition to 1" do
      result = SM2Algorithm.next_step(2, 5, 30)
      assert result.repetition == 1
    end

    test "quality 0 resets repetition to 1" do
      result = SM2Algorithm.next_step(0, 10, 100)
      assert result.repetition == 1
    end
  end

  describe "next_review field" do
    test "next_review is a DateTime struct" do
      result = SM2Algorithm.next_step(4, 0, 0)
      assert %DateTime{} = result.next_review
    end

    test "next_review is in the future" do
      result = SM2Algorithm.next_step(5, 0, 0)
      assert DateTime.compare(result.next_review, DateTime.utc_now()) == :gt
    end
  end
end
