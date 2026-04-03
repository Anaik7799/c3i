defmodule Indrajaal.TestSupport.UnifiedTestPatterns do
  @moduledoc """
  Unified test support patterns - Phase N consolidation
  Eliminates remaining test duplications
  """

  import ExUnit.Assertions

  @doc """
  Common async test execution pattern
  """
  @spec run(term(), reference(), non_neg_integer()) :: term()
  def run(_args, task_ref, timeout \\ 5000) do
    receive do
      {^task_ref, result} -> result
    after
      timeout -> flunk("Async operation timed out")
    end
  end

  @doc """
  Common mock helpers (simplified without external dependencies)
  """
  @spec mock_external_service(binary(), term()) :: term()
  def mock_external_service(service_name, response) do
    # Use process-based mocking instead of :meck
    Process.put({:mock, service_name}, response)
    {:ok, :mocked}

    # Note: Call Process.delete({:mock, service_name}) in test teardown
  end

  @spec get_mock_response(binary()) :: term()
  def get_mock_response(service_name) do
    Process.get({:mock, service_name}, {:error, :not_mocked})
  end

  # Removed unused private helper functions to eliminate warnings:
  # - generate_tenant_id/0
  # - build_test_user/0
  # These were template functions not actively used in current implementation
end
