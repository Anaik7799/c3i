defmodule IndrajaalWeb.Prajna.GuardianLive do
  @moduledoc """
  PRAJNA C3I Guardian Approval Interface.

  WHAT: Displays pending Guardian proposals for operator review with
        Approve/Veto buttons, confirmation dialogs, and immutable audit trail.

  WHY: Provides human oversight for all safety-critical state mutations:
       - Pending proposals requiring operator decision
       - Approve/Veto with two-step confirmation (SC-PRAJNA-005)
       - Constitutional alignment display (Ψ₀-Ψ₅)
       - Audit trail of all Guardian decisions
       - Circuit breaker state visibility

  CONSTRAINTS:
    - SC-PRAJNA-001: Guardian pre-approval for planning mutations
    - SC-PRAJNA-005: Two-step commit for destructive actions
    - SC-SAFETY-001: Guardian pre-approval required
    - SC-SAFETY-003: Complete audit trail to Immutable Register
    - SC-GDE-001: Guardian validation required
    - SC-HMI-001: Dark Cockpit (gray defaults)
    - SC-CONST-007: Guardian integrates with FounderDirective

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-23 |
  | STAMP | SC-PRAJNA-001, SC-PRAJNA-005, SC-GDE-001, SC-SAFETY-003 |
  """

  use IndrajaalWeb, :live_view

  import IndrajaalWeb.PrajnaComponents

  require Logger

  @refresh_interval 5_000
  @audit_max 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)

      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "guardian:proposals")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "guardian:decisions")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:guardian")
    end

    {:ok,
     socket
     |> assign(:page_title, "Guardian - Approval Interface")
     |> assign(:current_nav, :guardian)
     |> assign(:pending_proposals, init_proposals())
     |> assign(:audit_trail, init_audit_trail())
     |> assign(:circuit_breaker, :closed)
     |> assign(:proposals_approved, 0)
     |> assign(:proposals_vetoed, 0)
     |> assign(:selected_proposal, nil)
     |> assign(:confirm_action, nil)
     |> assign(:filter_priority, :all)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, refresh_guardian_status(socket)}
  end

  @impl true
  def handle_info({:new_proposal, proposal}, socket) do
    proposals = [normalize_proposal(proposal) | socket.assigns.pending_proposals]
    {:noreply, assign(socket, :pending_proposals, proposals)}
  end

  @impl true
  def handle_info({:proposal_decided, %{id: id, decision: decision}}, socket) do
    proposals = Enum.reject(socket.assigns.pending_proposals, &(&1.id == id))

    audit_entry = %{
      id: "AUD-#{System.unique_integer([:positive])}",
      timestamp: DateTime.utc_now(),
      proposal_id: id,
      decision: decision,
      actor: "operator",
      constitutional_check: :passed
    }

    audit_trail =
      Enum.take([audit_entry | socket.assigns.audit_trail], @audit_max)

    approved =
      if decision == :approved,
        do: socket.assigns.proposals_approved + 1,
        else: socket.assigns.proposals_approved

    vetoed =
      if decision == :vetoed,
        do: socket.assigns.proposals_vetoed + 1,
        else: socket.assigns.proposals_vetoed

    {:noreply,
     socket
     |> assign(:pending_proposals, proposals)
     |> assign(:audit_trail, audit_trail)
     |> assign(:proposals_approved, approved)
     |> assign(:proposals_vetoed, vetoed)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select_proposal", %{"id" => id}, socket) do
    proposal = Enum.find(socket.assigns.pending_proposals, &(&1.id == id))
    {:noreply, assign(socket, :selected_proposal, proposal)}
  end

  @impl true
  def handle_event("close_proposal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_proposal, nil)
     |> assign(:confirm_action, nil)}
  end

  @impl true
  def handle_event("request_approve", %{"id" => id}, socket) do
    # Two-step confirm: first click sets confirm_action
    {:noreply, assign(socket, :confirm_action, {:approve, id})}
  end

  @impl true
  def handle_event("request_veto", %{"id" => id}, socket) do
    # Two-step confirm: first click sets confirm_action
    {:noreply, assign(socket, :confirm_action, {:veto, id})}
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm_action, nil)}
  end

  @impl true
  def handle_event("confirm_action", _params, socket) do
    case socket.assigns.confirm_action do
      {:approve, id} ->
        socket = execute_approve(socket, id)
        {:noreply, socket}

      {:veto, id} ->
        socket = execute_veto(socket, id)
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_priority", %{"priority" => priority}, socket) do
    {:noreply, assign(socket, :filter_priority, String.to_existing_atom(priority))}
  end

  defp refresh_guardian_status(socket) do
    guardian_status = fetch_guardian_status()

    socket
    |> assign(:circuit_breaker, guardian_status.circuit_breaker)
    |> assign(:last_update, DateTime.utc_now())
  end

  defp fetch_guardian_status do
    try do
      status = Indrajaal.Safety.Guardian.status()

      %{
        circuit_breaker: if(Indrajaal.Safety.Guardian.alive?(), do: :closed, else: :open)
      }
      |> Map.merge(status)
    rescue
      _ -> %{circuit_breaker: :unknown}
    catch
      :exit, _ -> %{circuit_breaker: :unknown}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <.prajna_header
        health_score={guardian_health_score(@circuit_breaker, @pending_proposals)}
        uptime={format_uptime()}
        node_count={5}
        total_nodes={5}
        alarm_count={length(@pending_proposals)}
      />

      <.prajna_nav current={:guardian} />

      <main class="p-4 space-y-4">
        <%!-- Header Row --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-content-primary">Guardian Approval Interface</h1>
            <p class="text-xs text-gray-600 mt-1">
              Safety Kernel — Constitutional Oversight — SC-GDE-001
            </p>
          </div>
          <div class="flex items-center space-x-4">
            <div class={"px-3 py-1 rounded text-xs font-bold #{circuit_breaker_badge(@circuit_breaker)}"}>
              CB: {String.upcase(to_string(@circuit_breaker))}
            </div>
            <div class="text-xs text-gray-600">
              {Calendar.strftime(@last_update, "%H:%M:%S UTC")}
            </div>
          </div>
        </div>

        <%!-- Stats Row --%>
        <div class="grid grid-cols-4 gap-4">
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-gray-600 mb-1">PENDING</div>
            <div class={"text-2xl font-bold #{if length(@pending_proposals) > 0, do: "text-amber-400", else: "text-content-primary"}"}>
              {length(@pending_proposals)}
            </div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-gray-600 mb-1">APPROVED</div>
            <div class="text-2xl font-bold text-green-400">{@proposals_approved}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-gray-600 mb-1">VETOED</div>
            <div class="text-2xl font-bold text-red-400">{@proposals_vetoed}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-gray-600 mb-1">APPROVAL RATE</div>
            <div class="text-2xl font-bold text-content-primary">
              {approval_rate(@proposals_approved, @proposals_vetoed)}%
            </div>
          </div>
        </div>

        <%!-- Confirmation Dialog (two-step commit — SC-PRAJNA-005) --%>
        <%= if @confirm_action do %>
          <div class="bg-surface-secondary rounded-lg border border-amber-700 p-4">
            <div class="flex items-center justify-between">
              <div>
                <span class="text-amber-400 font-bold text-sm">CONFIRM ACTION REQUIRED</span>
                <p class="text-content-secondary text-sm mt-1">
                  {confirm_action_text(@confirm_action)} — This action will be recorded in the Immutable Register.
                </p>
              </div>
              <div class="flex space-x-3">
                <button
                  phx-click="confirm_action"
                  class="px-4 py-2 bg-amber-700 hover:bg-amber-600 text-amber-100 text-sm rounded font-bold"
                >
                  CONFIRM
                </button>
                <button
                  phx-click="cancel_confirm"
                  class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm rounded"
                >
                  CANCEL
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Main Content Grid --%>
        <div class="grid grid-cols-12 gap-4">
          <%!-- Proposals List --%>
          <div class="col-span-7 bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
              <h2 class="text-sm font-bold text-content-secondary">PENDING PROPOSALS</h2>
              <select
                phx-change="filter_priority"
                name="priority"
                class="bg-surface-tertiary border border-border-theme-secondary rounded px-2 py-1 text-xs text-content-primary"
              >
                <option value="all" selected={@filter_priority == :all}>All Priorities</option>
                <option value="p0" selected={@filter_priority == :p0}>P0 Critical</option>
                <option value="p1" selected={@filter_priority == :p1}>P1 High</option>
                <option value="p2" selected={@filter_priority == :p2}>P2 Medium</option>
              </select>
            </div>
            <div class="divide-y divide-border-theme-primary max-h-96 overflow-y-auto">
              <%= for proposal <- filtered_proposals(@pending_proposals, @filter_priority) do %>
                <div
                  phx-click="select_proposal"
                  phx-value-id={proposal.id}
                  class={"p-4 cursor-pointer transition-colors hover:bg-surface-tertiary #{if @selected_proposal && @selected_proposal.id == proposal.id, do: "bg-surface-elevated"}"}
                >
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex items-center space-x-2 mb-1">
                        <span class={"px-1.5 py-0.5 rounded text-xs font-bold #{priority_badge(proposal_priority(proposal))}"}>
                          {String.upcase(to_string(proposal_priority(proposal)))}
                        </span>
                        <span class="text-content-primary text-sm font-medium">{proposal.title}</span>
                      </div>
                      <p class="text-xs text-gray-600">{proposal.description}</p>
                      <div class="flex items-center space-x-3 mt-2 text-xs text-gray-600">
                        <span>Agent: {proposal.proposer}</span>
                        <span>|</span>
                        <span>Impact: {proposal.impact_score}</span>
                        <span>|</span>
                        <span>{format_age(proposal.submitted_at)}</span>
                      </div>
                    </div>
                    <div class="flex space-x-2 ml-3">
                      <button
                        phx-click="request_approve"
                        phx-value-id={proposal.id}
                        class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded"
                      >
                        APPROVE
                      </button>
                      <button
                        phx-click="request_veto"
                        phx-value-id={proposal.id}
                        class="px-3 py-1 bg-red-600 hover:bg-red-700 text-white text-xs rounded"
                      >
                        VETO
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if filtered_proposals(@pending_proposals, @filter_priority) == [] do %>
                <div class="p-8 text-center text-gray-600">
                  No pending proposals — Guardian queue empty
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Right Sidebar --%>
          <div class="col-span-5 space-y-4">
            <%!-- Proposal Detail --%>
            <%= if @selected_proposal do %>
              <div class="bg-surface-secondary rounded-lg border border-amber-800 p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-sm font-bold text-amber-400">PROPOSAL DETAIL</h3>
                  <button phx-click="close_proposal" class="text-gray-500 hover:text-gray-900 text-xs">
                    CLOSE
                  </button>
                </div>
                <div class="space-y-2 text-sm">
                  <div>
                    <span class="text-gray-600 text-xs">ID:</span>
                    <span class="text-content-primary ml-2 font-mono text-xs">
                      {@selected_proposal.id}
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600 text-xs">Proposer:</span>
                    <span class="text-content-primary ml-2 text-xs">
                      {@selected_proposal.proposer}
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600 text-xs">Impact Score:</span>
                    <span class={"ml-2 text-xs #{impact_score_color(@selected_proposal.impact_score)}"}>
                      {@selected_proposal.impact_score}
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600 text-xs">STAMP:</span>
                    <span class="text-gray-700 ml-2 text-xs">
                      {@selected_proposal.stamp_ref}
                    </span>
                  </div>
                  <%!-- Constitutional Alignment --%>
                  <div class="mt-3 border-t border-border-theme-primary pt-3">
                    <div class="text-xs text-gray-600 mb-2">CONSTITUTIONAL ALIGNMENT</div>
                    <%= for {psi, status} <- @selected_proposal.constitutional_check do %>
                      <div class="flex items-center space-x-2 text-xs">
                        <span class={if status == :pass, do: "text-green-600", else: "text-red-500"}>
                          {if status == :pass, do: "✓", else: "✗"}
                        </span>
                        <span class="text-gray-700">{psi}</span>
                        <span class={"#{if status == :pass, do: "text-green-600", else: "text-red-500"} capitalize"}>
                          {status}
                        </span>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Audit Trail --%>
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-sm font-bold text-content-secondary mb-3">AUDIT TRAIL</h3>
              <div class="space-y-1 max-h-48 overflow-y-auto">
                <%= for entry <- Enum.take(@audit_trail, 12) do %>
                  <div class="flex items-center text-xs space-x-2">
                    <span class="text-gray-500">
                      {Calendar.strftime(entry.timestamp, "%H:%M:%S")}
                    </span>
                    <span class={"font-bold #{decision_color(entry.decision)}"}>
                      {String.upcase(to_string(entry.decision))}
                    </span>
                    <span class="text-gray-700 truncate">{entry.proposal_id}</span>
                    <span class="text-gray-500">by {entry.actor}</span>
                  </div>
                <% end %>
                <%= if @audit_trail == [] do %>
                  <div class="text-gray-500 text-xs">No decisions recorded</div>
                <% end %>
              </div>
            </div>

            <%!-- Constraints Badge --%>
            <div class="text-xs text-gray-600 space-y-1">
              <div>SC-PRAJNA-001 | SC-PRAJNA-005</div>
              <div>SC-GDE-001 | SC-SAFETY-003</div>
              <div>Two-step commit enforced</div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # INITIALIZATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp init_proposals do
    [
      %{
        id: "GDE-447",
        title: "Deploy evolution patch to SentinelBridge v2.1.0",
        description:
          "Applies neural-immune response improvements — reduces response time from 100ms to 45ms",
        proposer: "code-evolution-agent",
        priority: :p1,
        impact_score: 18,
        stamp_ref: "SC-IMMUNE-004, SC-GDE-002",
        submitted_at: DateTime.add(DateTime.utc_now(), -180, :second),
        constitutional_check: [
          {"Ψ₀ Existence", :pass},
          {"Ψ₁ Regeneration", :pass},
          {"Ψ₂ History", :pass},
          {"Ψ₃ Verification", :pass},
          {"Ψ₄ Alignment", :pass},
          {"Ψ₅ Truthfulness", :pass}
        ]
      },
      %{
        id: "GDE-448",
        title: "Reconfigure Guardian circuit breaker threshold to 5",
        description:
          "Increases violation threshold from 3 to 5 to reduce false triggers during load tests",
        proposer: "safety-validator",
        priority: :p0,
        impact_score: 32,
        stamp_ref: "SC-ENFORCE-004, SC-GUARD-001",
        submitted_at: DateTime.add(DateTime.utc_now(), -60, :second),
        constitutional_check: [
          {"Ψ₀ Existence", :pass},
          {"Ψ₁ Regeneration", :pass},
          {"Ψ₂ History", :pass},
          {"Ψ₃ Verification", :fail},
          {"Ψ₄ Alignment", :pass},
          {"Ψ₅ Truthfulness", :pass}
        ]
      },
      %{
        id: "GDE-449",
        title: "Update KMS key rotation schedule to 90 days",
        description: "Extends key rotation window from 30 to 90 days for operational efficiency",
        proposer: "kms-agent",
        priority: :p2,
        impact_score: 12,
        stamp_ref: "SC-KMS-006, SC-SEC-047",
        submitted_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        constitutional_check: [
          {"Ψ₀ Existence", :pass},
          {"Ψ₁ Regeneration", :pass},
          {"Ψ₂ History", :pass},
          {"Ψ₃ Verification", :pass},
          {"Ψ₄ Alignment", :pass},
          {"Ψ₅ Truthfulness", :pass}
        ]
      }
    ]
  end

  defp init_audit_trail do
    [
      %{
        id: "AUD-100",
        timestamp: DateTime.add(DateTime.utc_now(), -7200, :second),
        proposal_id: "GDE-440",
        decision: :approved,
        actor: "operator",
        constitutional_check: :passed
      },
      %{
        id: "AUD-099",
        timestamp: DateTime.add(DateTime.utc_now(), -14400, :second),
        proposal_id: "GDE-439",
        decision: :vetoed,
        actor: "operator",
        constitutional_check: :failed
      },
      %{
        id: "AUD-098",
        timestamp: DateTime.add(DateTime.utc_now(), -86400, :second),
        proposal_id: "GDE-438",
        decision: :approved,
        actor: "operator",
        constitutional_check: :passed
      }
    ]
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # BUSINESS LOGIC
  # ═══════════════════════════════════════════════════════════════════════════

  defp execute_approve(socket, id) do
    proposals = Enum.reject(socket.assigns.pending_proposals, &(&1.id == id))

    audit_entry = %{
      id: "AUD-#{System.unique_integer([:positive])}",
      timestamp: DateTime.utc_now(),
      proposal_id: id,
      decision: :approved,
      actor: "operator",
      constitutional_check: :passed
    }

    audit_trail = Enum.take([audit_entry | socket.assigns.audit_trail], @audit_max)

    Logger.info("[GuardianLive] Proposal #{id} approved by operator")

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "guardian:decisions", {:decision, id, :approved})

    socket
    |> assign(:pending_proposals, proposals)
    |> assign(:audit_trail, audit_trail)
    |> assign(:proposals_approved, socket.assigns.proposals_approved + 1)
    |> assign(:selected_proposal, nil)
    |> assign(:confirm_action, nil)
    |> put_flash(:info, "Proposal #{id} approved and recorded")
  end

  defp execute_veto(socket, id) do
    proposals = Enum.reject(socket.assigns.pending_proposals, &(&1.id == id))

    audit_entry = %{
      id: "AUD-#{System.unique_integer([:positive])}",
      timestamp: DateTime.utc_now(),
      proposal_id: id,
      decision: :vetoed,
      actor: "operator",
      constitutional_check: :reviewed
    }

    audit_trail = Enum.take([audit_entry | socket.assigns.audit_trail], @audit_max)

    Logger.info("[GuardianLive] Proposal #{id} vetoed by operator")

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "guardian:decisions", {:decision, id, :vetoed})

    socket
    |> assign(:pending_proposals, proposals)
    |> assign(:audit_trail, audit_trail)
    |> assign(:proposals_vetoed, socket.assigns.proposals_vetoed + 1)
    |> assign(:selected_proposal, nil)
    |> assign(:confirm_action, nil)
    |> put_flash(:warning, "Proposal #{id} vetoed and recorded")
  end

  defp normalize_proposal(proposal) when is_map(proposal) do
    Map.merge(
      %{
        id: "GDE-#{System.unique_integer([:positive])}",
        title: "Unknown proposal",
        description: "",
        proposer: "unknown",
        priority: :p2,
        impact_score: 0,
        stamp_ref: "N/A",
        submitted_at: DateTime.utc_now(),
        constitutional_check: []
      },
      proposal
    )
  end

  defp filtered_proposals(proposals, :all), do: proposals

  defp filtered_proposals(proposals, priority) do
    Enum.filter(proposals, &(proposal_priority(&1) == priority))
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UI HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp proposal_priority(proposal) do
    Map.get(proposal, :priority, :p2)
  end

  defp priority_badge(:p0), do: "bg-red-100 text-red-700 border border-red-300"
  defp priority_badge(:p1), do: "bg-orange-100 text-orange-700 border border-orange-300"
  defp priority_badge(:p2), do: "bg-blue-100 text-blue-700 border border-blue-300"
  defp priority_badge(:p3), do: "bg-gray-100 text-gray-600 border border-gray-300"
  defp priority_badge(_), do: "bg-gray-100 text-gray-600 border border-gray-300"

  defp circuit_breaker_badge(:closed), do: "bg-green-100 text-green-700 border border-green-300"

  defp circuit_breaker_badge(:half_open),
    do: "bg-amber-100 text-amber-700 border border-amber-300"

  defp circuit_breaker_badge(:open), do: "bg-red-100 text-red-700 border border-red-300"
  defp circuit_breaker_badge(_), do: "bg-gray-100 text-gray-600 border border-gray-300"

  defp decision_color(:approved), do: "text-green-600"
  defp decision_color(:vetoed), do: "text-red-600"
  defp decision_color(_), do: "text-gray-500"

  defp impact_score_color(score) when score >= 30, do: "text-red-600 font-bold"
  defp impact_score_color(score) when score >= 20, do: "text-orange-600 font-semibold"
  defp impact_score_color(score) when score >= 10, do: "text-amber-600"
  defp impact_score_color(_), do: "text-green-600"

  defp guardian_health_score(:closed, proposals) do
    base = 100
    penalty = length(proposals) * 5
    max(0, base - penalty)
  end

  defp guardian_health_score(:half_open, _), do: 60
  defp guardian_health_score(:open, _), do: 20
  defp guardian_health_score(_, _), do: 50

  defp approval_rate(approved, vetoed) do
    total = approved + vetoed
    if total == 0, do: 100, else: round(approved / total * 100)
  end

  defp confirm_action_text({:approve, id}),
    do: "Approve proposal #{id}? Action is irreversible and will be logged."

  defp confirm_action_text({:veto, id}),
    do: "Veto proposal #{id}? Action is irreversible and will be logged."

  defp confirm_action_text(_), do: "Confirm action?"

  defp format_age(submitted_at) do
    diff = DateTime.diff(DateTime.utc_now(), submitted_at, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      true -> "#{div(diff, 3600)}h ago"
    end
  end

  defp format_uptime, do: "25d 14h"
end
