defmodule Indrajaal.KMS.WebKnowledgeTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.WebKnowledge.
  Tests module existence and public API surface.
  GenServer init sets up cache state — safe to start with supervised.
  STAMP: SC-KMS-020 (1h cache TTL), SC-KMS-021 (max 5 concurrent requests)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.WebKnowledge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(WebKnowledge)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(WebKnowledge, :start_link, 1)
      assert function_exported?(WebKnowledge, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports search/2" do
      assert function_exported?(WebKnowledge, :search, 2)
    end

    test "exports fetch_url/2" do
      assert function_exported?(WebKnowledge, :fetch_url, 2)
    end

    test "exports ask_augmented/2" do
      assert function_exported?(WebKnowledge, :ask_augmented, 2)
    end

    test "exports cache_stats/0" do
      assert function_exported?(WebKnowledge, :cache_stats, 0)
    end

    test "exports clear_cache/0" do
      assert function_exported?(WebKnowledge, :clear_cache, 0)
    end

    test "exports stamp_constraints/0" do
      assert function_exported?(WebKnowledge, :stamp_constraints, 0)
    end
  end

  describe "stamp_constraints/0" do
    test "returns a non-empty map" do
      constraints = WebKnowledge.stamp_constraints()
      assert is_map(constraints)
      assert map_size(constraints) > 0
    end

    test "includes SC-KMS-020" do
      constraints = WebKnowledge.stamp_constraints()
      assert Map.has_key?(constraints, "SC-KMS-020")
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({WebKnowledge, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state has empty cache" do
      {:ok, pid} = start_supervised({WebKnowledge, []})
      state = :sys.get_state(pid)
      assert state.cache == %{}
    end

    test "initial state has zero pending requests" do
      {:ok, pid} = start_supervised({WebKnowledge, []})
      state = :sys.get_state(pid)
      assert state.pending_requests == 0
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = WebKnowledge.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
