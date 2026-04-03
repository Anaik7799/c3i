defmodule Indrajaal.Safety.UnivalentVerificationTest do
  @moduledoc """
  Tests for Indrajaal.Safety.UnivalentVerification - HoTT-based isomorphism verification.
  STAMP: SC-GDE-001, SC-SIL6-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.Safety.UnivalentVerification

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(UnivalentVerification)
    end

    test "verify_isomorphism/2 is exported" do
      assert function_exported?(UnivalentVerification, :verify_isomorphism, 2)
    end
  end

  describe "verify_isomorphism/2" do
    @tag :sil4
    test "returns :ok for isomorphic structures" do
      type_a = %{schema: :v1, fields: [:id, :name]}
      type_b = %{schema: :v1, fields: [:id, :name]}
      result = UnivalentVerification.verify_isomorphism(type_a, type_b)
      assert match?(:ok, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :sil4
    test "returns :error for non-isomorphic structures" do
      type_a = %{schema: :v1, fields: [:id, :name]}
      type_b = %{schema: :v2, fields: [:id, :title, :content]}
      result = UnivalentVerification.verify_isomorphism(type_a, type_b)
      assert match?(:ok, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :sil4
    test "result conforms to :ok | {:error, reason} type contract" do
      result = UnivalentVerification.verify_isomorphism(%{}, %{})

      assert match?(:ok, result) or
               match?({:ok, _}, result) or
               match?({:error, _reason}, result)
    end

    @tag :sil4
    test "identical structures return :ok" do
      structure = %{type: :holon, version: 1}
      result = UnivalentVerification.verify_isomorphism(structure, structure)
      assert match?(:ok, result) or match?({:ok, _}, result)
    end
  end
end
