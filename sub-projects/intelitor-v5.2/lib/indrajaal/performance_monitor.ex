defmodule PerformanceMonitor do
  @moduledoc """
  Top-level performance monitoring facade (L4 Intelligence).

  WHAT: Thin adapter module that provides a simple, module-name-stable API
        over Indrajaal.Telemetry.PerformanceMonitor for callers that use
        the bare `PerformanceMonitor` module name.
  WHY: Compilation warnings arose from references to this bare module name.
       This module proxies to the telemetry namespace implementation.
  CONSTRAINTS: SC-MON-002, SC-PERF-001, AOR-MON-001.

  ## Change History
  | Version | Date       | Author             | Change                          |
  |---------|------------|--------------------|---------------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6  | Replaced stub with real adapter |
  """

  @impl_module Indrajaal.Telemetry.PerformanceMonitor

  @doc "Returns the latest performance snapshot from the real monitor."
  @spec get_snapshot() :: map()
  def get_snapshot do
    if Code.ensure_loaded?(@impl_module) and
         function_exported?(@impl_module, :get_snapshot, 0) do
      @impl_module.get_snapshot()
    else
      %{status: :unavailable}
    end
  end

  @doc "Returns active performance alerts from the real monitor."
  @spec get_alerts() :: [map()]
  def get_alerts do
    if Code.ensure_loaded?(@impl_module) and
         function_exported?(@impl_module, :get_alerts, 0) do
      @impl_module.get_alerts()
    else
      []
    end
  end
end
