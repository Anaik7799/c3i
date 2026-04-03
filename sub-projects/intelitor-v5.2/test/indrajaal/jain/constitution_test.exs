defmodule Indrajaal.Jain.ConstitutionTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jain.Constitution

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Constitution)
    end

    test "module exports expected functions" do
      assert function_exported?(Constitution, :load, 0)
      assert function_exported?(Constitution, :verify, 1)
      assert function_exported?(Constitution, :hash, 1)
      assert function_exported?(Constitution, :permits?, 3)
      assert function_exported?(Constitution, :non_violence_axiom, 0)
      assert function_exported?(Constitution, :transparency_axiom, 0)
      assert function_exported?(Constitution, :non_possession_axiom, 0)
      assert function_exported?(Constitution, :reversibility_axiom, 0)
      assert function_exported?(Constitution, :core_axioms, 0)
      assert function_exported?(Constitution, :safety_constraints, 0)
    end
  end

  describe "core_axioms/0" do
    test "returns a non-empty list of axioms" do
      result = Constitution.core_axioms()
      assert is_list(result)
      assert length(result) > 0
    end

    test "each axiom has an :id key" do
      axioms = Constitution.core_axioms()

      for axiom <- axioms do
        assert Map.has_key?(axiom, :id)
      end
    end
  end

  describe "safety_constraints/0" do
    test "returns a list of constraint maps" do
      result = Constitution.safety_constraints()
      assert is_list(result)
      assert length(result) > 0
    end
  end

  describe "non_violence_axiom/0" do
    test "returns a map with id :ahimsa" do
      result = Constitution.non_violence_axiom()
      assert is_map(result)
      assert result.id == :ahimsa
    end
  end

  describe "transparency_axiom/0" do
    test "returns a map with id :satya" do
      result = Constitution.transparency_axiom()
      assert is_map(result)
      assert result.id == :satya
    end
  end

  describe "non_possession_axiom/0" do
    test "returns a map with id :aparigraha" do
      result = Constitution.non_possession_axiom()
      assert is_map(result)
      assert result.id == :aparigraha
    end
  end

  describe "reversibility_axiom/0" do
    test "returns a map with id :reversibility" do
      result = Constitution.reversibility_axiom()
      assert is_map(result)
      assert result.id == :reversibility
    end
  end

  describe "load/0" do
    test "returns a constitution map (not wrapped in ok tuple)" do
      result = Constitution.load()
      assert is_map(result)
    end

    test "loaded constitution has version key" do
      constitution = Constitution.load()
      assert Map.has_key?(constitution, :version)
      assert is_binary(constitution.version)
    end

    test "loaded constitution has axioms list" do
      constitution = Constitution.load()
      assert Map.has_key?(constitution, :axioms)
      assert is_list(constitution.axioms)
    end

    test "loaded constitution has hash field" do
      constitution = Constitution.load()
      assert Map.has_key?(constitution, :hash)
    end
  end

  describe "hash/1" do
    test "returns binary for a constitution map" do
      constitution = Constitution.load()
      result = Constitution.hash(constitution)
      assert is_binary(result)
    end

    test "hash is 32 bytes (SHA-256)" do
      constitution = Constitution.load()
      result = Constitution.hash(constitution)
      assert byte_size(result) == 32
    end
  end

  describe "verify/1" do
    test "returns :ok or {:error, :corrupted} for a loaded constitution" do
      constitution = Constitution.load()
      result = Constitution.verify(constitution)
      assert result == :ok or match?({:error, :corrupted}, result)
    end

    test "returns {:error, :corrupted} for tampered constitution" do
      constitution = %{Constitution.load() | version: "tampered"}
      result = Constitution.verify(constitution)
      assert match?({:error, :corrupted}, result)
    end
  end

  describe "permits?/3" do
    test "returns boolean for a valid action with declared intent" do
      constitution = Constitution.load()
      context = %{intent: "read device list", harmful: false}
      result = Constitution.permits?(constitution, :read, context)
      assert is_boolean(result)
    end

    test "returns false for action without declared intent" do
      constitution = Constitution.load()
      context = %{}
      result = Constitution.permits?(constitution, :read, context)
      # satya (transparency) requires intent to be declared
      assert result == false
    end

    test "returns false for harmful action" do
      constitution = Constitution.load()
      context = %{intent: "harm test", harmful: true}
      result = Constitution.permits?(constitution, :delete_user_data, context)
      assert result == false
    end
  end
end
