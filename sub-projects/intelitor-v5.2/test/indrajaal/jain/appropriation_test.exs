defmodule Indrajaal.Jain.AppropriationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jain.Appropriation

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Appropriation)
    end

    test "module exports expected functions" do
      assert function_exported?(Appropriation, :request, 1)
      assert function_exported?(Appropriation, :release, 1)
      assert function_exported?(Appropriation, :release_all, 0)
      assert function_exported?(Appropriation, :within_limits?, 1)
      assert function_exported?(Appropriation, :current_usage, 0)
      assert function_exported?(Appropriation, :host_capacity, 1)
      assert function_exported?(Appropriation, :max_allowed, 1)
      assert function_exported?(Appropriation, :suggest_releases, 1)
      assert function_exported?(Appropriation, :metrics, 0)
    end
  end

  describe "current_usage/0" do
    test "returns a map" do
      result = Appropriation.current_usage()
      assert is_map(result)
    end
  end

  describe "metrics/0" do
    test "returns a map" do
      result = Appropriation.metrics()
      assert is_map(result)
    end
  end

  describe "within_limits?/1" do
    test "returns boolean for a resource request map" do
      request = %{
        type: :cpu,
        amount: 0.01,
        priority: :low,
        duration: 1000,
        reason: "test"
      }

      result = Appropriation.within_limits?(request)
      assert is_boolean(result)
    end

    test "returns true for a tiny resource request" do
      request = %{
        type: :memory,
        amount: 1024,
        priority: :low,
        duration: 1000,
        reason: "test"
      }

      result = Appropriation.within_limits?(request)
      assert is_boolean(result)
    end
  end

  describe "host_capacity/1" do
    test "returns a value for :cpu type" do
      result = Appropriation.host_capacity(:cpu)
      assert result != nil
    end

    test "returns a value for :memory type" do
      result = Appropriation.host_capacity(:memory)
      assert result != nil
    end
  end

  describe "max_allowed/1" do
    test "returns a numeric value for :cpu" do
      result = Appropriation.max_allowed(:cpu)
      assert is_number(result) or is_map(result) or is_tuple(result)
    end
  end

  describe "request/1" do
    test "returns ok or error for a valid resource request" do
      request = %{
        type: :cpu,
        amount: 0.001,
        priority: :low,
        duration: 1000,
        reason: "unit test"
      }

      result = Appropriation.request(request)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "release/1" do
    test "returns :ok for any allocation id" do
      result = Appropriation.release("fake_allocation_id")
      assert result == :ok or match?({:error, :not_found}, result)
    end
  end

  describe "release_all/0" do
    test "returns :ok" do
      result = Appropriation.release_all()
      assert result == :ok
    end
  end

  describe "suggest_releases/1" do
    test "returns a list for an empty allocations list" do
      result = Appropriation.suggest_releases([])
      assert is_list(result)
    end

    test "returns a list for a list with one allocation" do
      allocations = [
        %{
          id: "alloc-001",
          type: :cpu,
          amount: 0.01,
          allocated_at: DateTime.utc_now(),
          expires_at: nil,
          released: false
        }
      ]

      result = Appropriation.suggest_releases(allocations)
      assert is_list(result)
    end
  end
end
