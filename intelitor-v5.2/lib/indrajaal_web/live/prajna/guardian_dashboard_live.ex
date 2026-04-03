defmodule IndrajaalWeb.Prajna.GuardianDashboardLive do
  @moduledoc """
  Guardian Governance Dashboard - Proposal/Veto Tracking.

  STAMP: SC-PRAJNA-001, SC-CONST-007, SC-GDE-001
  """
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, :refresh)
    {:ok, assign_defaults(socket)}
  end

  defp assign_defaults(socket) do
    assign(socket,
      page_title: "Guardian - Governance",
      proposals_approved: 0,
      proposals_vetoed: 0,
      pending_operations: [],
      circuit_breaker: :closed,
      recent_decisions: [],
      last_update: DateTime.utc_now()
    )
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, refresh_data(socket)}
  end

  defp refresh_data(socket) do
    assign(socket, :last_update, DateTime.utc_now())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary">
      <h1 class="text-2xl font-bold mb-6">⚖️ Guardian - Governance Center</h1>

      <div class="grid grid-cols-4 gap-4 mb-6">
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Approved</div>
          <div class="text-3xl font-bold text-green-600">{@proposals_approved}</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Vetoed</div>
          <div class="text-3xl font-bold text-red-600">{@proposals_vetoed}</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Pending</div>
          <div class="text-3xl font-bold text-yellow-600">{length(@pending_operations)}</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Circuit Breaker</div>
          <div class={"text-2xl font-bold " <> cb_color(@circuit_breaker)}>{@circuit_breaker}</div>
        </div>
      </div>

      <div class="bg-surface-secondary p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-3">Recent Decisions</h2>
        <div class="text-gray-600">No recent decisions</div>
      </div>

      <div class="text-sm text-gray-600 mt-4">
        Last update: {Calendar.strftime(@last_update, "%Y-%m-%d %H:%M:%S UTC")}
      </div>
    </div>
    """
  end

  defp cb_color(:closed), do: "text-green-600"
  defp cb_color(:half_open), do: "text-yellow-600"
  defp cb_color(:open), do: "text-red-600"
  defp cb_color(_), do: "text-gray-600"
end
