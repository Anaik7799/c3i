defmodule Indrajaal.Cache.TTLManager do
  @moduledoc """
  Manages Time - To - Live (TTL) values for different cache types.

  Provides intelligent TTL management based on:
  - Data type and volatility
  - Access patterns
  - System load
  - Time of day

  Agent: Helper - 3 optimizes cache TTLs
  SOPv5.1 Compliance: ✅
  """

  # Base TTL values in milliseconds
  @ttl_config %{
    # Session __data - longer TTL
    session: %{
      base: :timer.hours(1),
      min: :timer.minutes(30),
      max: :timer.hours(4)
    },

    # Entity __data - medium TTL
    entity: %{
      base: :timer.minutes(10),
      min: :timer.minutes(5),
      max: :timer.minutes(30)
    },

    # Query results - shorter TTL
    query: %{
      base: :timer.minutes(5),
      min: :timer.minutes(1),
      max: :timer.minutes(15)
    },

    # API responses - very short TTL
    api: %{
      base: :timer.minutes(1),
      min: :timer.seconds(30),
      max: :timer.minutes(5)
    },

    # Real - time __data - minimal TTL
    realtime: %{
      base: :timer.seconds(30),
      min: :timer.seconds(10),
      max: :timer.minutes(1)
    }
  }

  @doc """
  Get TTL for a specific cache type with optional adjustments.
  """
  @spec get_ttl(any(), any()) :: any()
  def get_ttl(type, opts \\ []) do
    config = Map.get(@ttl_config, type, @ttl_config.entity)
    base_ttl = config.base

    # Apply adjustments
    ttl =
      base_ttl
      |> adjust_for_load(opts[:load_factor])
      |> adjust_for_time_of_day()
      |> adjust_for_access_pattern(opts[:access_pattern])
      |> clamp(config.min, config.max)

    # Allow override
    Keyword.get(opts, :ttl, ttl)
  end

  @doc """
  Get TTL for specific entity types.
  """
  @spec entity_ttl(any()) :: any()
  def entity_ttl(entitytype) do
    case entitytype do
      # Devices change less f_requently
      :device -> :timer.minutes(15)
      # Alarms are more dynamic
      :alarm -> :timer.minutes(5)
      # Sites are mostly static
      :site -> :timer.minutes(30)
      # User __data is moderately dynamic
      :user -> :timer.minutes(10)
      # Configuration is rarely changed
      :config -> :timer.hours(1)
      _ -> get_ttl(:entity)
    end
  end

  @doc """
  Get TTL for API endpoints based on endpoint pattern.
  """
  @spec api_ttl(any()) :: any()
  def api_ttl(endpoint) do
    cond do
      # List endpoints - shorter TTL
      String.ends_with?(endpoint, "s") -> :timer.seconds(30)
      # Individual resource - longer TTL
      String.contains?(endpoint, "/") -> :timer.minutes(2)
      # Statistics / aggregations - medium TTL
      String.contains?(endpoint, "stats") -> :timer.minutes(5)
      String.contains?(endpoint, "count") -> :timer.minutes(5)
      # Real - time endpoints - minimal TTL
      String.contains?(endpoint, "realtime") -> :timer.seconds(10)
      String.contains?(endpoint, "live") -> :timer.seconds(10)
      # Default
      true -> get_ttl(:api)
    end
  end

  @doc """
  Calculate dynamic TTL based on hit rate.
  """
  @spec dynamicttl(any(), any()) :: any()
  def dynamicttl(hitrate, currentttl) do
    adjusted_ttl =
      cond do
        # High hit rate - increase TTL
        hitrate > 0.9 -> min(currentttl * 1.5, :timer.hours(1))
        # Good hit rate - keep current
        hitrate > 0.7 -> currentttl
        # Low hit rate - decrease TTL
        hitrate > 0.5 -> max(currentttl * 0.8, :timer.seconds(30))
        # Very low hit rate - minimize TTL
        true -> :timer.seconds(30)
      end

    round(adjusted_ttl)
  end

  @doc """
  Get cache warmup TTL (shorter for initial population).
  """
  @spec warmup_ttl(any()) :: any()
  def warmup_ttl(type) do
    config = Map.get(@ttl_config, type, @ttl_config.entity)
    div(config.base, 2)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @spec adjust_for_load(term(), term()) :: term()
  defp adjust_for_load(ttl, nil), do: ttl

  defp adjust_for_load(ttl, load_factor) when load_factor > 0.8 do
    # High load - increase TTL to reduce cache misses
    min(ttl * 1.5, :timer.hours(2))
  end

  @spec adjust_for_load(term(), term()) :: term()
  defp adjust_for_load(ttl, load_factor) when load_factor < 0.3 do
    # Low load - can afford shorter TTL for fresher __data
    max(ttl * 0.7, :timer.seconds(30))
  end

  @spec adjust_for_load(term(), term()) :: term()
  defp adjust_for_load(ttl, _), do: ttl

  @spec adjust_for_time_of_day(integer()) :: integer()
  defp adjust_for_time_of_day(ttl) do
    hour = DateTime.utc_now().hour

    adjusted_ttl =
      if hour >= 9 and hour <= 18 do
        # Peak hours (9 AM - 6 PM UTC) - increase TTL
        ttl * 1.2
      else
        # Off - peak hours - normal TTL
        ttl
      end

    round(adjusted_ttl)
  end

  @spec adjust_for_access_pattern(term(), term()) :: term()
  defp adjust_for_access_pattern(ttl, nil), do: ttl

  defp adjust_for_access_pattern(ttl, :writeheavy) do
    # Write - heavy pattern - shorter TTL to avoid stale __data
    max(ttl * 0.5, :timer.seconds(30))
  end

  @spec adjust_for_access_pattern(term(), term()) :: term()
  defp adjust_for_access_pattern(ttl, :readheavy) do
    # Read - heavy pattern - longer TTL to improve performance
    min(ttl * 2, :timer.hours(2))
  end

  @spec adjust_for_access_pattern(term(), term()) :: term()
  defp adjust_for_access_pattern(ttl, _), do: ttl

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
