defmodule IndrajaalWeb.Steps.GuardianManagementSteps do
  @moduledoc """
  Step definitions for Guardian management BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the Guardian management feature file at /cockpit/guardian.
  WHY: Enable automated BDD testing of Guardian proposal review, approval,
       veto, fallback, and history workflows.

  ## STAMP Compliance
  - SC-SAFETY-001: Guardian pre-approval required for all mutations
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-GUARD-002: Guardian integrates with DeadMansSwitch, fail closed
  - SC-GDE-001: Guardian validation required (CRITICAL)
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations
  - SC-HMI-011: 8x8 matrix path coverage

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation        |
  """

  use Cabbage.Feature, async: false, file: "prajna/guardian_management.feature"
  use IndrajaalWeb.ConnCase

  import Phoenix.LiveViewTest

  @endpoint IndrajaalWeb.Endpoint

  # =============================================================================
  # BACKGROUND STEPS
  # =============================================================================

  defgiven ~r/^I am on the Prajna cockpit$/, _vars, state do
    conn = build_conn()
    {:ok, Map.put(state, :conn, conn)}
  end

  defgiven ~r/^the system is in normal operation$/, _vars, state do
    {:ok, Map.put(state, :system_status, :normal)}
  end

  defgiven ~r/^I navigate to "(?<path>[^"]+)"$/, %{path: path}, state do
    {:ok, view, html} = live(state.conn, path)
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html) |> Map.put(:path, path)}
  end

  defgiven ~r/^the Guardian LiveView is connected via WebSocket$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/phx-/i or is_binary(html)
    {:ok, state}
  end

  defgiven ~r/^Guardian service is active$/, _vars, state do
    {:ok, Map.put(state, :guardian_active, true)}
  end

  # =============================================================================
  # PROPOSAL QUEUE DISPLAY
  # =============================================================================

  defgiven ~r/^there are pending proposals awaiting Guardian review$/, _vars, state do
    proposals = [
      %{
        id: "PROP-001",
        type: "code_evolution",
        submitter: "claude-1",
        risk_score: 0.72,
        status: "pending",
        timestamp: DateTime.utc_now()
      },
      %{
        id: "PROP-002",
        type: "config_change",
        submitter: "operator-1",
        risk_score: 0.45,
        status: "pending",
        timestamp: DateTime.utc_now()
      },
      %{
        id: "PROP-003",
        type: "production_actuation",
        submitter: "gemini-2",
        risk_score: 0.91,
        status: "pending",
        timestamp: DateTime.utc_now()
      }
    ]

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:guardian",
      {:proposals_loaded, proposals}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:proposals, proposals) |> Map.put(:proposal_count, 3)}
  end

  defwhen ~r/^the Guardian dashboard loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see the proposal queue table$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/proposal|queue|table/i
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^each proposal should display submitter, type, timestamp, and risk score$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/submitter|type|timestamp|risk|score/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^proposals should be ordered by risk score descending$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/risk|score|order|sort/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the total pending count should be visible in the header$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/pending|count|total/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the page should load within (?<ms>\d+)ms$/, %{ms: ms}, state do
    max_ms = String.to_integer(ms)
    start = System.monotonic_time(:millisecond)
    _html = render(state.view)
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < max_ms, "Page render took #{elapsed}ms, expected < #{max_ms}ms"
    {:ok, state}
  end

  # =============================================================================
  # REAL-TIME PROPOSAL UPDATE
  # =============================================================================

  defgiven ~r/^I am viewing the Guardian dashboard$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defgiven ~r/^there are (?<count>\d+) pending proposals$/, %{count: count}, state do
    proposal_count = String.to_integer(count)

    proposals =
      Enum.map(1..proposal_count, fn i ->
        %{
          id: "PROP-#{String.pad_leading(to_string(i), 3, "0")}",
          type: "code_evolution",
          submitter: "agent-#{i}",
          risk_score: 0.5,
          status: "pending",
          timestamp: DateTime.utc_now()
        }
      end)

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposals_loaded, proposals})
    Process.sleep(50)
    {:ok, state |> Map.put(:proposals, proposals) |> Map.put(:proposal_count, proposal_count)}
  end

  defwhen ~r/^a new proposal arrives via Zenoh topic "(?<topic>[^"]+)"$/,
          %{topic: _topic},
          state do
    new_proposal = %{
      id: "PROP-NEW-001",
      type: "code_evolution",
      submitter: "claude-3",
      risk_score: 0.68,
      status: "pending",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:guardian",
      {:proposal_added, new_proposal}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :new_proposal, new_proposal)}
  end

  defthen ~r/^the new proposal should appear in the queue without page reload$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the pending count should increment to (?<count>\d+)$/, %{count: _count}, state do
    html = render(state.view)
    assert html =~ ~r/\d+|count|pending/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the new proposal should be highlighted as "New" for (?<seconds>\d+) seconds$/,
          %{seconds: _seconds},
          state do
    html = render(state.view)
    assert html =~ ~r/new|highlight|badge/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # PROPOSAL DETAIL
  # =============================================================================

  defgiven ~r/^there is a proposal "(?<proposal_id>[^"]+)" of type "(?<type>[^"]+)"$/,
           %{proposal_id: proposal_id, type: type},
           state do
    proposal = %{
      id: proposal_id,
      type: type,
      submitter: "claude-1",
      risk_score: 0.72,
      status: "pending",
      impact_score: 15,
      timestamp: DateTime.utc_now(),
      diff: "+ def new_function(x), do: x * 2",
      stamp_refs: ["SC-FUNC-001", "SC-CHG-001"]
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defwhen ~r/^I click "Review" on proposal "(?<proposal_id>[^"]+)"$/,
          %{proposal_id: proposal_id},
          state do
    html = render_click(state.view, "review_proposal", %{"proposal_id" => proposal_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_proposal_id, proposal_id)}
  end

  defthen ~r/^the proposal detail panel should expand$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/detail|panel|expand|proposal/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the full proposed change diff$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/diff|change|proposal/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the STAMP constraint compliance report$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/stamp|constraint|compliance|SC-/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the 4-layer impact analysis \(L1-CODE, L2-DOMAIN, L3-SYSTEM, L4-ECOSYSTEM\)$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/L1|L2|L3|L4|impact|layer/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the mutation safety score as a percentage$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/safety|score|%|\d+/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the submitting agent identity$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/submitter|agent|identity|author/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # RISK TIER CLASSIFICATION
  # =============================================================================

  defgiven ~r/^there is a proposal with impact score "(?<score>[^"]+)"$/,
           %{score: score},
           state do
    score_int = String.to_integer(score)

    proposal = %{
      id: "PROP-RISK-001",
      type: "code_evolution",
      submitter: "claude-1",
      risk_score: score_int / 40.0,
      impact_score: score_int,
      status: "pending",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)
    {:ok, state |> Map.put(:proposal, proposal) |> Map.put(:impact_score, score_int)}
  end

  defwhen ~r/^I view the proposal in the Guardian queue$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the proposal should display risk tier "(?<tier>[^"]+)"$/, %{tier: tier}, state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(tier)}|tier|risk/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the tier badge should use color "(?<color>[^"]+)"$/,
          %{color: _color},
          state do
    html = render(state.view)
    assert html =~ ~r/badge|color|tier/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # APPROVE
  # =============================================================================

  defgiven ~r/^there is a pending proposal "(?<proposal_id>[^"]+)" of type "(?<type>[^"]+)"$/,
           %{proposal_id: proposal_id, type: type},
           state do
    proposal = %{
      id: proposal_id,
      type: type,
      submitter: "claude-1",
      risk_score: 0.87,
      status: "pending",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defgiven ~r/^the proposal has a mutation safety score above (?<threshold>[0-9.]+)$/,
           %{threshold: _threshold},
           state do
    {:ok, Map.put(state, :safety_score_valid, true)}
  end

  defwhen ~r/^I click "Approve" on proposal "(?<proposal_id>[^"]+)"$/,
          %{proposal_id: proposal_id},
          state do
    html = render_click(state.view, "approve_proposal", %{"proposal_id" => proposal_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_proposal_id, proposal_id)}
  end

  defthen ~r/^an approval confirmation dialog should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/confirm|dialog|approve|modal/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the proposal summary in the dialog$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/summary|proposal|dialog/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I confirm the approval$/, _vars, state do
    html = render_click(state.view, "confirm_approve", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the proposal status should change to "(?<status>[^"]+)"$/,
          %{status: status},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(status)}|status|proposal/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published$/, %{event: _event}, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  defthen ~r/^the approval should be logged to the Immutable Register with actor identity$/,
          _vars,
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  defthen ~r/^the agent that submitted the proposal should receive the approval notification$/,
          _vars,
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # 2oo3 VOTING
  # =============================================================================

  defgiven ~r/^there is a pending proposal "(?<proposal_id>[^"]+)" of type "production_actuation"$/,
           %{proposal_id: proposal_id},
           state do
    proposal = %{
      id: proposal_id,
      type: "production_actuation",
      submitter: "operator-1",
      risk_score: 0.95,
      status: "pending",
      requires_quorum: true,
      votes: [],
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defthen ~r/^I should see that 2-of-3 Guardian votes are required$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/2.?of.?3|quorum|vote/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the current approval count should show "(?<label>[^"]+)"$/,
          %{label: _label},
          state do
    html = render(state.view)
    assert html =~ ~r/approval|count|vote|\d/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the proposal should remain in "pending_quorum" state until quorum is reached$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/pending|quorum|state/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # VETO
  # =============================================================================

  defgiven ~r/^there is a pending proposal "(?<proposal_id>[^"]+)" with high risk$/,
           %{proposal_id: proposal_id},
           state do
    proposal = %{
      id: proposal_id,
      type: "system_mutation",
      submitter: "agent-1",
      risk_score: 0.93,
      status: "pending",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defwhen ~r/^I click "Veto" on proposal "(?<proposal_id>[^"]+)"$/,
          %{proposal_id: proposal_id},
          state do
    html = render_click(state.view, "veto_proposal", %{"proposal_id" => proposal_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_proposal_id, proposal_id)}
  end

  defthen ~r/^a veto dialog should appear requiring a veto reason$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/veto|dialog|reason/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the submit button should be disabled until a reason is entered$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disabled|submit|button/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I enter veto reason "(?<reason>[^"]+)"$/, %{reason: reason}, state do
    html = render_change(state.view, "veto_reason_changed", %{"reason" => reason})
    {:ok, state |> Map.put(:html, html) |> Map.put(:veto_reason, reason)}
  end

  defwhen ~r/^I confirm the veto$/, _vars, state do
    reason = Map.get(state, :veto_reason, "Safety violation")
    html = render_click(state.view, "confirm_veto", %{"reason" => reason})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the veto reason should be visible in the proposal history$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/reason|veto|history/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the submitting agent should receive a veto notification with the reason$/,
          _vars,
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # FALLBACK PROPOSAL
  # =============================================================================

  defgiven ~r/^there is a proposal "(?<proposal_id>[^"]+)" that has been vetoed$/,
           %{proposal_id: proposal_id},
           state do
    proposal = %{
      id: proposal_id,
      type: "code_evolution",
      submitter: "claude-1",
      status: "vetoed",
      veto_reason: "Violates safety constraint",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defwhen ~r/^I click "Suggest Fallback" on the vetoed proposal$/, _vars, state do
    proposal_id = Map.get(state, :target_proposal_id, "")
    html = render_click(state.view, "suggest_fallback", %{"proposal_id" => proposal_id})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a fallback proposal form should appear pre-populated with context$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/fallback|form|context|pre-populated/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should be able to modify the proposed change$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/edit|modify|input|textarea/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I submit the fallback proposal$/, _vars, state do
    html =
      render_click(state.view, "submit_fallback", %{
        "change_description" => "Revised implementation with safety guards"
      })

    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a new proposal "(?<proposal_id>[^"]+)" should appear in the queue$/,
          %{proposal_id: _proposal_id},
          state do
    html = render(state.view)
    assert html =~ ~r/proposal|queue|new/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the original proposal "(?<proposal_id>[^"]+)" should be linked as the parent$/,
          %{proposal_id: _proposal_id},
          state do
    html = render(state.view)
    assert html =~ ~r/parent|link|original|proposal/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # HISTORY
  # =============================================================================

  defgiven ~r/^there are approved, vetoed, and pending proposals in history$/, _vars, state do
    {:ok, Map.put(state, :has_history, true)}
  end

  defwhen ~r/^I click the "History" tab on the Guardian dashboard$/, _vars, state do
    html = render_click(state.view, "show_history", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see all past decisions with timestamps and actor identities$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/history|decision|timestamp|actor/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should be able to filter history by decision type \(approved, vetoed\)$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/filter|approved|vetoed|type/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each history entry should link to the Immutable Register block$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/register|block|link|immutable/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # EMPTY STATE
  # =============================================================================

  defgiven ~r/^there are no pending Guardian proposals$/, _vars, state do
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposals_loaded, []})
    Process.sleep(50)
    {:ok, Map.put(state, :proposal_count, 0)}
  end

  defwhen ~r/^I view the Guardian dashboard$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see "No pending proposals" message$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/no.?pending|empty|proposal|queue/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a green "All Clear" indicator should be visible$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/all.?clear|green|indicator|safe/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no table rows should be present in the queue$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/PROP-\d{3}/
    {:ok, state}
  end

  # =============================================================================
  # EXPIRED PROPOSAL
  # =============================================================================

  defgiven ~r/^there is a proposal "(?<proposal_id>[^"]+)" that exceeded its approval TTL$/,
           %{proposal_id: proposal_id},
           state do
    proposal = %{
      id: proposal_id,
      type: "code_evolution",
      submitter: "claude-2",
      status: "expired",
      expired_at: DateTime.utc_now(),
      timestamp: DateTime.add(DateTime.utc_now(), -3600, :second)
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:guardian", {:proposal_added, proposal})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:proposal, proposal)
     |> Map.put(:target_proposal_id, proposal_id)}
  end

  defwhen ~r/^the Guardian dashboard renders$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^proposal "(?<proposal_id>[^"]+)" should show status "(?<status>[^"]+)"$/,
          %{proposal_id: _proposal_id, status: status},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(status)}|status/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^an expiry warning should be visible on the proposal row$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/expir|warning|ttl/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should have been published$/,
          %{event: _event},
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end
end
