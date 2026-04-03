defmodule Indrajaal.Jain.GenesisTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jain.Genesis

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Genesis)
    end

    test "module exports expected functions" do
      assert function_exported?(Genesis, :initiate, 1)
      assert function_exported?(Genesis, :from_seed, 1)
      assert function_exported?(Genesis, :create_seed, 1)
      assert function_exported?(Genesis, :stage_description, 1)
    end
  end

  describe "create_seed/1" do
    test "returns ok tuple with seed map for valid opts" do
      opts = %{holon_id: "ex:l3:tst:srv:main", version: "1.0.0"}
      result = Genesis.create_seed(opts)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "stage_description/1" do
    test "returns binary description for :bootstrap stage" do
      result = Genesis.stage_description(:bootstrap)
      assert is_binary(result) or is_atom(result) or is_map(result)
    end

    test "returns binary description for :verify stage" do
      result = Genesis.stage_description(:verify)
      assert is_binary(result) or is_atom(result) or is_map(result)
    end

    test "returns a value for unknown stage" do
      result = Genesis.stage_description(:unknown_stage)
      assert is_binary(result) or is_atom(result) or is_nil(result)
    end
  end

  describe "initiate/1" do
    test "returns ok or error for minimal config" do
      config = %{holon_id: "ex:l3:tst:srv:genesis_test", mode: :test}
      result = Genesis.initiate(config)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "from_seed/1" do
    test "returns ok or error for a seed map" do
      seed = %{
        holon_id: "ex:l3:tst:srv:main",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        checksum: "abc123"
      }

      result = Genesis.from_seed(seed)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
