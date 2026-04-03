defmodule Indrajaal.Performance.Shared do
  @moduledoc """
  WHAT: Shared state and utilities for Performance GenServer modules.
  WHY: Eliminates duplicate default state initialization across 18+ performance modules.
  CONSTRAINTS: SC-DB-001, SC-DOC-001 - All performance modules MUST use this shared state.

  This module provides:
  - Default state map used by all performance GenServers
  - Common state helper functions
  - Consistent initialization pattern
  """

  @doc """
  Returns the default state map for performance GenServers.

  All performance modules share this common state structure to ensure
  consistent behavior and reduce code duplication.

  ## Examples

      iex> Indrajaal.Performance.Shared.default_state()
      %{metrics: %{cpu: 10, memory: 20, iops: 100}, status: :ok, ...}
  """
  @spec default_state() :: map()
  def default_state do
    %{
      metrics: %{cpu: 10, memory: 20, iops: 100},
      status: :ok,
      # Robust default state shared across all performance modules
      optimization_stats: %{count: 0},
      cache_stats: %{hits: 0, misses: 0},
      scaling_history: [],
      thermal_metrics: %{temp: 45.0},
      power_usage: 120.0,
      numa_stats: %{nodes: 2},
      feature_importance: %{f1: 0.9},
      isolation_status: %{},
      allocation_stats: %{allocated: 0},
      cluster_status: :healthy,
      network_stats: %{latency: 10},
      memory_stats: %{used: 1024},
      active_optimizations: [],
      system_health: :ok,
      trends: [],
      coordination_status: :active,
      resource_status: :available,
      thermal_status: :normal
    }
  end

  @doc """
  Returns the default state merged with custom overrides.

  ## Examples

      iex> Indrajaal.Performance.Shared.default_state(%{status: :initializing})
      %{metrics: %{cpu: 10, ...}, status: :initializing, ...}
  """
  @spec default_state(map()) :: map()
  def default_state(overrides) when is_map(overrides) do
    Map.merge(default_state(), overrides)
  end

  @doc """
  Standard init/1 implementation that returns {:ok, default_state()}.
  Can be used via defdelegate or called directly.
  """
  @spec init(any()) :: {:ok, map()}
  def init(_opts) do
    {:ok, default_state()}
  end

  @doc """
  Standard init with custom state overrides.
  """
  @spec init_with_overrides(any(), map()) :: {:ok, map()}
  def init_with_overrides(_opts, overrides) when is_map(overrides) do
    {:ok, default_state(overrides)}
  end
end
