defmodule Indrajaal.FLAME.Pools do
  @moduledoc """
  FLAME Pool Configuration and Supervisor.
  Defines the elastic compute pools for different workload profiles.

  ## STAMP Compliance
  - SC-FLAME-003: Isolate workloads into pools
  - SC-AUTO-003: Hard resource limits

  ## Pools
  1. Intelligence: CPU-bound, low concurrency, high compute (AI inference)
  2. Video: Memory-bound, low concurrency, stream processing
  3. Analytics: I/O-bound, high concurrency, batch processing
  """

  # This module serves as a namespace and configuration source
  # The actual pools are started in application.ex directly via FLAME.Pool

  def pools do
    [
      %{
        name: Indrajaal.FLAME.IntelligencePool,
        min: 0,
        max: 10,
        max_concurrency: 5,
        idle_shutdown_after: 30_000,
        log: :debug
      },
      %{
        name: Indrajaal.FLAME.VideoPool,
        min: 0,
        max: 20,
        max_concurrency: 2,
        idle_shutdown_after: 60_000,
        log: :debug
      },
      %{
        name: Indrajaal.FLAME.AnalyticsPool,
        min: 0,
        max: 15,
        max_concurrency: 10,
        idle_shutdown_after: 45_000,
        log: :debug
      }
    ]
  end
end
