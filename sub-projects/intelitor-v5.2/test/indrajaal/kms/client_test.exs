defmodule Indrajaal.KMS.ClientTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Client.
  Tests module existence and public API surface only.
  NOTE: start_link opens a real Port to F# process — do NOT start_supervised here.
  STAMP: SC-KMS-001, SC-AI-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Client

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Client)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Client, :start_link, 1)
      assert function_exported?(Client, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports get_holon/1" do
      assert function_exported?(Client, :get_holon, 1)
    end

    test "exports upsert_holon/1" do
      assert function_exported?(Client, :upsert_holon, 1)
    end

    test "exports search_vectors/2" do
      assert function_exported?(Client, :search_vectors, 2)
    end

    test "exports ping/0" do
      assert function_exported?(Client, :ping, 0)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Client.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
