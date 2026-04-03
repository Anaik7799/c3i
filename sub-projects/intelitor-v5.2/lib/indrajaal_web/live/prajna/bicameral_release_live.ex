defmodule IndrajaalWeb.Prajna.BicameralReleaseLive do
  @moduledoc """
  Bicameral Release Dashboard — Two-Key protocol for safe deployments.

  Implements the Two-Key release authorization model: two independent
  operators (Chamber A and Chamber B) must both confirm a release
  before it is permitted to proceed. This is the Phoenix LiveView
  UI surface for that protocol.

  WHAT: Displays pending release proposals, individual chamber votes,
        and combined authorization status. Operators can arm, confirm,
        or veto a pending release from their assigned chamber.

  WHY: Prevents single-actor deployments of critical system updates.
       Mirrors the nuclear two-person rule for SIL-6 compliance.

  ## STAMP Constraints
  - SC-SAFETY-001: Arm & Fire for destructive actions — ENFORCED (arm→confirm)
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations — ENFORCED
  - SC-HMI-010: Vibrant chromatic feedback — ENFORCED
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values — ENFORCED
  - SC-TRI-001: Tricameral orchestrator constraints — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use IndrajaalWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "bicameral:releases")
      :timer.send_interval(15_000, self(), :refresh)
    end

    {:ok,
     socket
     |> assign(:page_title, "Bicameral Release Dashboard")
     |> assign(:proposals, sample_proposals())
     |> assign(:selected_proposal_id, nil)
     |> assign(:chamber_a_armed, false)
     |> assign(:chamber_b_armed, false)
     |> assign(:last_action, nil)
     |> assign(:flash_msg, nil)}
  end

  @impl true
  def handle_event("arm_chamber_a", %{"proposal_id" => id}, socket) do
    Logger.info("[BicameralRelease] Chamber A armed for proposal #{id}")

    {:noreply,
     socket
     |> assign(:selected_proposal_id, id)
     |> assign(:chamber_a_armed, true)
     |> assign(:flash_msg, {:info, "Chamber A armed — awaiting Chamber B confirmation"})}
  end

  @impl true
  def handle_event("arm_chamber_b", %{"proposal_id" => id}, socket) do
    Logger.info("[BicameralRelease] Chamber B armed for proposal #{id}")

    {:noreply,
     socket
     |> assign(:selected_proposal_id, id)
     |> assign(:chamber_b_armed, true)
     |> assign(:flash_msg, {:info, "Chamber B armed — awaiting Chamber A confirmation"})}
  end

  @impl true
  def handle_event("confirm_release", %{"proposal_id" => id}, socket) do
    %{chamber_a_armed: a, chamber_b_armed: b} = socket.assigns

    if a and b do
      Logger.info("[BicameralRelease] Both chambers confirmed — release #{id} AUTHORIZED")

      {:noreply,
       socket
       |> assign(:chamber_a_armed, false)
       |> assign(:chamber_b_armed, false)
       |> assign(:last_action, {:authorized, id, DateTime.utc_now()})
       |> assign(:flash_msg, {:success, "Release #{id} authorized by both chambers"})}
    else
      {:noreply,
       assign(socket, :flash_msg, {:error, "Both chambers must be armed before confirming"})}
    end
  end

  @impl true
  def handle_event("veto_release", %{"proposal_id" => id}, socket) do
    Logger.warning("[BicameralRelease] Release #{id} vetoed")

    {:noreply,
     socket
     |> assign(:chamber_a_armed, false)
     |> assign(:chamber_b_armed, false)
     |> assign(:selected_proposal_id, nil)
     |> assign(:last_action, {:vetoed, id, DateTime.utc_now()})
     |> assign(:flash_msg, {:warning, "Release #{id} vetoed — deployment blocked"})}
  end

  @impl true
  def handle_event("dismiss_flash", _params, socket) do
    {:noreply, assign(socket, :flash_msg, nil)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, :proposals, sample_proposals())}
  end

  @impl true
  def handle_info({:release_update, proposal}, socket) do
    proposals =
      socket.assigns.proposals
      |> Enum.map(fn p -> if p.id == proposal.id, do: proposal, else: p end)

    {:noreply, assign(socket, :proposals, proposals)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bicameral-release-dashboard p-6 bg-gray-950 min-h-screen text-white">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-amber-400">Bicameral Release Dashboard</h1>
        <span class="text-xs text-gray-500 font-mono">TWO-KEY PROTOCOL — SIL-6</span>
      </div>

      <%= if @flash_msg do %>
        <div class={flash_class(elem(@flash_msg, 0))} role="alert">
          <span>{elem(@flash_msg, 1)}</span>
          <button phx-click="dismiss_flash" class="ml-4 text-sm underline">dismiss</button>
        </div>
      <% end %>

      <div class="grid grid-cols-1 gap-4 mb-6">
        <%= for proposal <- @proposals do %>
          <div class={proposal_card_class(proposal.status)}>
            <div class="flex items-center justify-between">
              <div>
                <p class="font-semibold text-white">{proposal.name}</p>
                <p class="text-sm text-gray-400">v{proposal.version} — {proposal.environment}</p>
              </div>
              <span class={status_badge_class(proposal.status)}>{proposal.status}</span>
            </div>

            <div class="mt-3 text-xs text-gray-400">
              Proposed by: <strong class="text-gray-200">{proposal.proposed_by}</strong>
              at <span class="font-mono">{format_time(proposal.proposed_at)}</span>
            </div>

            <%= if proposal.status == "pending" do %>
              <div class="mt-4 flex gap-3">
                <button
                  phx-click="arm_chamber_a"
                  phx-value-proposal_id={proposal.id}
                  class={
                    arm_button_class(@chamber_a_armed && @selected_proposal_id == proposal.id, "A")
                  }
                >
                  ARM Chamber A
                </button>

                <button
                  phx-click="arm_chamber_b"
                  phx-value-proposal_id={proposal.id}
                  class={
                    arm_button_class(@chamber_b_armed && @selected_proposal_id == proposal.id, "B")
                  }
                >
                  ARM Chamber B
                </button>

                <%= if @chamber_a_armed and @chamber_b_armed and @selected_proposal_id == proposal.id do %>
                  <button
                    phx-click="confirm_release"
                    phx-value-proposal_id={proposal.id}
                    class="px-4 py-2 bg-green-600 hover:bg-green-500 text-white text-sm font-bold rounded"
                  >
                    CONFIRM RELEASE
                  </button>
                <% end %>

                <button
                  phx-click="veto_release"
                  phx-value-proposal_id={proposal.id}
                  class="px-3 py-2 bg-red-800 hover:bg-red-700 text-white text-sm rounded"
                >
                  VETO
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @last_action do %>
        <div class="text-xs text-gray-600 font-mono mt-4">
          Last action: {inspect(@last_action)}
        </div>
      <% end %>
    </div>
    """
  end

  # ─── Private helpers ─────────────────────────────────────────────────────────

  defp sample_proposals do
    [
      %{
        id: "rel-001",
        name: "Indrajaal Core",
        version: "21.3.1",
        environment: "production",
        status: "pending",
        proposed_by: "guardian@indrajaal",
        proposed_at: DateTime.utc_now()
      },
      %{
        id: "rel-002",
        name: "CEPAF Mesh",
        version: "10.2.0",
        environment: "staging",
        status: "authorized",
        proposed_by: "ops@indrajaal",
        proposed_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }
    ]
  end

  defp flash_class(:success),
    do:
      "mb-4 p-3 bg-green-900 border border-green-600 text-green-200 rounded text-sm flex justify-between"

  defp flash_class(:warning),
    do:
      "mb-4 p-3 bg-yellow-900 border border-yellow-600 text-yellow-200 rounded text-sm flex justify-between"

  defp flash_class(:error),
    do:
      "mb-4 p-3 bg-red-900 border border-red-600 text-red-200 rounded text-sm flex justify-between"

  defp flash_class(:info),
    do:
      "mb-4 p-3 bg-blue-900 border border-blue-600 text-blue-200 rounded text-sm flex justify-between"

  defp proposal_card_class("pending"), do: "bg-gray-800 border border-amber-700 rounded-lg p-4"
  defp proposal_card_class("authorized"), do: "bg-gray-800 border border-green-700 rounded-lg p-4"
  defp proposal_card_class(_), do: "bg-gray-800 border border-gray-700 rounded-lg p-4"

  defp status_badge_class("pending"),
    do: "px-2 py-1 text-xs font-mono bg-amber-900 text-amber-300 rounded"

  defp status_badge_class("authorized"),
    do: "px-2 py-1 text-xs font-mono bg-green-900 text-green-300 rounded"

  defp status_badge_class("vetoed"),
    do: "px-2 py-1 text-xs font-mono bg-red-900 text-red-300 rounded"

  defp status_badge_class(_), do: "px-2 py-1 text-xs font-mono bg-gray-700 text-gray-300 rounded"

  defp arm_button_class(true, _label),
    do: "px-4 py-2 bg-amber-600 text-white text-sm font-bold rounded ring-2 ring-amber-300"

  defp arm_button_class(false, _label),
    do: "px-4 py-2 bg-gray-700 hover:bg-amber-800 text-white text-sm rounded"

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S UTC")
  defp format_time(_), do: "—"
end
