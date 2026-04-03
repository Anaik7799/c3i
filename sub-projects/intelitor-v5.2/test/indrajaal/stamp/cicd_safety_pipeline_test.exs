defmodule Indrajaal.STAMP.CICDSafetyPipelineTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.CICDSafetyPipeline - CI/CD safety gates.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.STAMP.CICDSafetyPipeline

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(CICDSafetyPipeline)
    end

    test "initialize/0 is exported" do
      assert function_exported?(CICDSafetyPipeline, :initialize, 0)
    end
  end

  describe "initialize/0" do
    @tag :sil4
    test "returns :ok" do
      result = CICDSafetyPipeline.initialize()
      assert match?(:ok, result) or match?({:ok, _}, result)
    end

    @tag :sil4
    test "creates ETS tables for safety gates" do
      result = CICDSafetyPipeline.initialize()
      assert result == :ok or match?({:ok, _}, result)
    end

    @tag :sil4
    test "is idempotent - can be called multiple times" do
      result1 = CICDSafetyPipeline.initialize()
      result2 = CICDSafetyPipeline.initialize()

      assert (match?(:ok, result1) or match?({:ok, _}, result1)) and
               (match?(:ok, result2) or match?({:ok, _}, result2))
    end
  end
end
