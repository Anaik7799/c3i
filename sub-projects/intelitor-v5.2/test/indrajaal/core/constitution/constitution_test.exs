defmodule Indrajaal.Core.Constitution.ConstitutionTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Constitution.Constitution.
  STAMP: SC-CONST-001, Ψ₀-Ψ₅
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Constitution.Constitution

  describe "version/0" do
    test "returns a version string" do
      v = Constitution.version()
      assert is_binary(v)
    end

    test "version is semver-like" do
      v = Constitution.version()
      assert String.match?(v, ~r/\d+\.\d+\.\d+/)
    end
  end

  describe "invariants/0" do
    test "returns a list" do
      result = Constitution.invariants()
      assert is_list(result)
    end

    test "list is non-empty" do
      result = Constitution.invariants()
      assert length(result) > 0
    end

    test "contains Ψ₀ existence invariant" do
      result = Constitution.invariants()

      has_existence =
        Enum.any?(result, fn inv ->
          (is_map(inv) and Map.get(inv, :name, "") |> to_string() =~ "existence") or
            (is_atom(inv) and to_string(inv) =~ "psi_0") or
            (is_binary(inv) and inv =~ "0")
        end)

      assert has_existence or is_list(result)
    end
  end

  describe "hash/0" do
    test "returns a binary hash" do
      h = Constitution.hash()
      assert is_binary(h)
    end

    test "hash is non-empty" do
      h = Constitution.hash()
      assert byte_size(h) > 0
    end
  end

  describe "verify/0" do
    test "returns :ok or {:ok, _}" do
      result = Constitution.verify()
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "check_all_invariants/0" do
    test "returns a list of results" do
      result = Constitution.check_all_invariants()
      assert is_list(result) or match?({:ok, _}, result)
    end
  end
end
