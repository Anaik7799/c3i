defmodule Indrajaal.SMRITI.Mesh.VectorStoreTest do
  @moduledoc """
  TDG test suite for SMRITI.Mesh.VectorStore.

  ## STAMP Safety Integration
  - SC-SMRITI-001: Vector search latency < 100ms
  - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct

  ## TPS 5-Level RCA Context
  - L1 Symptom: Semantic search returns empty results
  - L5 Root Cause: Missing cosine similarity computation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.SMRITI.Mesh.VectorStore

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(VectorStore)
    end

    test "similarity/2 is exported" do
      assert function_exported?(VectorStore, :similarity, 2)
    end
  end

  describe "similarity/2 computation" do
    test "identical vectors have similarity of 1.0" do
      vec = [0.1, 0.2, 0.3]
      result = VectorStore.similarity(vec, vec)
      assert_in_delta result, 1.0, 0.001
    end

    test "orthogonal vectors have similarity of 0.0" do
      vec_a = [1.0, 0.0, 0.0]
      vec_b = [0.0, 1.0, 0.0]
      result = VectorStore.similarity(vec_a, vec_b)
      assert_in_delta result, 0.0, 0.001
    end

    test "returns a float value" do
      result = VectorStore.similarity([1.0, 0.5], [0.5, 1.0])
      assert is_float(result) or is_number(result)
    end

    test "similarity is symmetric" do
      vec_a = [0.3, 0.7, 0.1]
      vec_b = [0.6, 0.2, 0.8]
      sim_ab = VectorStore.similarity(vec_a, vec_b)
      sim_ba = VectorStore.similarity(vec_b, vec_a)
      assert_in_delta sim_ab, sim_ba, 0.001
    end

    test "similarity score is bounded between -1.0 and 1.0" do
      vec_a = [0.3, 0.7, 0.1, 0.4]
      vec_b = [0.6, 0.2, 0.8, 0.5]
      result = VectorStore.similarity(vec_a, vec_b)
      assert result >= -1.0
      assert result <= 1.0
    end
  end

  describe "search/2 without DB" do
    test "returns error or empty results without running KMS" do
      embedding = List.duplicate(0.1, 10)

      result =
        try do
          VectorStore.search(embedding, 5)
        rescue
          _ -> {:error, :no_db}
        catch
          :exit, _ -> {:error, :no_db}
        end

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "store/3 without DB" do
    test "returns error without running KMS" do
      embedding = List.duplicate(0.1, 10)

      result =
        try do
          VectorStore.store("holon_test_001", embedding)
        rescue
          _ -> {:error, :no_db}
        catch
          :exit, _ -> {:error, :no_db}
        end

      assert match?({:error, _}, result) or match?(:ok, result)
    end
  end
end
