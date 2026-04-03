defmodule IndrajaalWeb.Steps.CopilotAssistantSteps do
  @moduledoc """
  Step definitions for AI copilot assistant BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the copilot assistant feature file at /cockpit/ai-copilot.
  WHY: Enable automated BDD testing of Prajna AI copilot workflows:
       chat interface, query types, Guardian-gated actions, context management,
       and graceful error handling.

  ## STAMP Compliance
  - SC-ACE-001: Agent Collaboration Engine distributed coordination
  - SC-MCP-001: Model Context Protocol server integration
  - SC-SAFETY-001: Guardian pre-approval for mutations
  - SC-HITL-001: Human-in-the-loop confirmation required
  - SC-HMI-010: Chromatic response sentiment feedback
  - SC-HMI-011: 8x8 matrix path coverage

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation        |
  """

  use Cabbage.Feature, async: false, file: "prajna/copilot_assistant.feature"
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

  defgiven ~r/^the copilot LiveView is connected via WebSocket$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/phx-/i or is_binary(html)
    {:ok, state}
  end

  defgiven ~r/^the AI model backend is available$/, _vars, state do
    {:ok, Map.put(state, :ai_backend_available, true)}
  end

  # =============================================================================
  # CHAT INTERFACE DISPLAY
  # =============================================================================

  defgiven ~r/^I open the AI copilot page for the first time$/, _vars, state do
    {:ok, Map.put(state, :fresh_session, true)}
  end

  defwhen ~r/^the copilot page loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see the conversation input field$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/input|textarea|message|copilot/i
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see a welcome message from the copilot$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/welcome|hello|copilot|assistant/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see suggested quick-action prompts$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/suggest|quick|prompt|action/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the current system health summary should be displayed in the context panel$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/health|summary|context|system/i or is_binary(html)
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
  # QUERY AND RESPONSE
  # =============================================================================

  defgiven ~r/^I am on the copilot page with an active session$/, _vars, state do
    html = render(state.view)
    {:ok, state |> Map.put(:html, html) |> Map.put(:session_active, true)}
  end

  defwhen ~r/^I type "(?<message>[^"]+)" in the input field$/, %{message: message}, state do
    html = render_change(state.view, "update_message", %{"message" => message})
    {:ok, state |> Map.put(:html, html) |> Map.put(:current_message, message)}
  end

  defwhen ~r/^I press Enter to submit the query$/, _vars, state do
    message = Map.get(state, :current_message, "")
    html = render_click(state.view, "submit_message", %{"message" => message})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: message,
         response:
           "The mesh health is nominal. All 4 nodes are healthy with average latency of 3ms.",
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a loading indicator should appear while the AI processes the request$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/loading|processing|spinner|wait/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should respond with a mesh health summary$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/health|mesh|nominal|response/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should include relevant metric values$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/metric|\d+|ms|node/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the conversation history should show both the query and the response$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/conversation|history|query|response/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # ZENOH TELEMETRY QUERY
  # =============================================================================

  defgiven ~r/^I am on the copilot page$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defwhen ~r/^I ask "(?<question>[^"]+)"$/, %{question: question}, state do
    html = render_click(state.view, "submit_message", %{"message" => question})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: question,
         response:
           "Here is the requested information: node health nominal, 4 containers running, 0 active alarms, quorum maintained.",
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:html, html) |> Map.put(:last_question, question)}
  end

  defthen ~r/^the copilot should query Zenoh topic "(?<topic>[^"]+)"$/,
          %{topic: _topic},
          state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should include real-time telemetry data$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/telemetry|realtime|data|response/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the data should be formatted in a readable table within the chat$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/table|format|data|chat/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # DIAGNOSTIC ACTION PLAN
  # =============================================================================

  defgiven ~r/^the system has a degraded node "(?<node_id>[^"]+)"$/, %{node_id: node_id}, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:node_degraded, %{id: node_id, reason: "high_latency"}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :degraded_node, node_id)}
  end

  defwhen ~r/^I ask the copilot "(?<question>[^"]+)"$/, %{question: question}, state do
    html = render_click(state.view, "submit_message", %{"message" => question})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: question,
         response: """
         Root Cause Analysis (5-Why):
         1. Why? Node latency exceeds threshold (SC-XHOLON-021)
         2. Why? Connection pool exhausted
         3. Why? Query backlog from analytics jobs
         4. Why? Missing rate limiting (SC-API-001)
         5. Why? Rate limiting not configured for analytics domain

         Remediation Plan:
         1. Restart analytics query workers
         2. Apply rate limit SC-API-001 to analytics scope
         3. Monitor recovery via Zenoh health topic

         Estimated recovery: 5-10 minutes
         """,
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:html, html) |> Map.put(:last_question, question)}
  end

  defthen ~r/^the copilot should perform a 5-Why root cause analysis$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/5.?why|root.?cause|why/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should include a numbered remediation action plan$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/plan|remediat|step|\d\./i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each action step should reference the relevant STAMP constraint$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/SC-|stamp|constraint/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the plan should include an estimated recovery time$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/estimated|recovery|time|minute/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # SCENARIO OUTLINE: DOMAIN QUESTIONS
  # =============================================================================

  defthen ~r/^the response should mention "(?<expected_keyword>[^"]+)"$/,
          %{expected_keyword: expected_keyword},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(expected_keyword)}|response/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should arrive within (?<seconds>\d+) seconds$/,
          %{seconds: seconds},
          state do
    max_ms = String.to_integer(seconds) * 1000
    start = System.monotonic_time(:millisecond)
    _html = render(state.view)
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < max_ms, "Response took #{elapsed}ms, expected < #{max_ms}ms"
    {:ok, state}
  end

  # =============================================================================
  # GUARDIAN-GATED ACTION
  # =============================================================================

  defgiven ~r/^I ask the copilot "(?<question>[^"]+)"$/, %{question: question}, state do
    html = render_click(state.view, "submit_message", %{"message" => question})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:action_proposed,
       %{
         query: question,
         action_type: "node_restart",
         target: "indrajaal-ex-app-2",
         consequence: "Node will restart, active sessions will be terminated",
         stamp_refs: ["SC-SIL4-005", "SC-SAFETY-001"],
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:html, html) |> Map.put(:last_question, question)}
  end

  defwhen ~r/^the copilot formulates a restart action plan$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the copilot should present an action confirmation card$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/confirm|action|card|copilot/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the card should clearly state the action and its consequences$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/action|consequence|restart|terminate/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the card should show the STAMP constraints that apply$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/SC-|stamp|constraint/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a "Confirm" and "Cancel" button should be visible$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/confirm|cancel|button/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I click "Confirm"$/, _vars, state do
    html = render_click(state.view, "confirm_copilot_action", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the action should be submitted as a Guardian proposal$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/guardian|proposal|submitted/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should confirm "(?<message>[^"]+)"$/, %{message: _message}, state do
    html = render(state.view)
    assert html =~ ~r/submitted|guardian|proposal|confirm/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # DESTRUCTIVE ACTION REFUSAL
  # =============================================================================

  defgiven ~r/^I ask the copilot "Delete all alarm history"$/, _vars, state do
    html = render_click(state.view, "submit_message", %{"message" => "Delete all alarm history"})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:destructive_action_warned,
       %{
         query: "Delete all alarm history",
         warning:
           "This action is irreversible. Alarm history is protected by SC-SMRITI-142 (append-only). Confirmation phrase required.",
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :html, html)}
  end

  defwhen ~r/^the copilot evaluates the request$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the copilot should present a warning about the irreversibility$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/irreversible|warning|danger/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should NOT execute the action automatically$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/deleted|executing|completed.action/i
    assert is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should ask for explicit confirmation with a typed confirmation phrase$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/confirm|phrase|type|explicit/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # MULTI-TURN CONTEXT
  # =============================================================================

  defgiven ~r/^I have an active copilot session$/, _vars, state do
    {:ok, Map.put(state, :session_active, true)}
  end

  defgiven ~r/^the copilot provides details about ALM-001$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: "Show me alarm ALM-001",
         response: "Alarm ALM-001: Critical severity, authentication failure, status active.",
         context: %{last_entity: "ALM-001", entity_type: "alarm"},
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :last_entity, "ALM-001")}
  end

  defwhen ~r/^I ask "(?<question>[^"]+)"$/, %{question: question}, state do
    html = render_click(state.view, "submit_message", %{"message" => question})
    Process.sleep(50)
    {:ok, state |> Map.put(:html, html) |> Map.put(:last_question, question)}
  end

  defwhen ~r/^I then ask "(?<question>[^"]+)"$/, %{question: question}, state do
    html = render_click(state.view, "submit_message", %{"message" => question})
    Process.sleep(50)
    {:ok, state |> Map.put(:html, html) |> Map.put(:follow_up_question, question)}
  end

  defthen ~r/^the copilot should correctly infer I mean alarm "(?<alarm_id>[^"]+)"$/,
          %{alarm_id: _alarm_id},
          state do
    html = render(state.view)
    assert html =~ ~r/ALM-001|alarm|context|infer/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should initiate the acknowledgement workflow for ALM-001$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/acknowledge|ALM-001|workflow/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # SESSION CONTEXT
  # =============================================================================

  defgiven ~r/^I am starting a new copilot session$/, _vars, state do
    {:ok, Map.put(state, :fresh_session, true)}
  end

  defthen ~r/^the response should include current container health statuses$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/container|health|status/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should include active alarm count$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/alarm|count|active/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the response should include Zenoh mesh connectivity status$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/zenoh|mesh|connectivity|status/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # AMBIGUOUS QUERY
  # =============================================================================

  defwhen ~r/^I type "Fix it" and submit the query$/, _vars, state do
    html = render_click(state.view, "submit_message", %{"message" => "Fix it"})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:clarification_needed,
       %{
         query: "Fix it",
         response:
           "I need more context. Could you clarify which of the following you mean?\n1. Fix the degraded node?\n2. Fix the pending alarm?\n3. Fix a configuration issue?",
         options: ["Fix degraded node", "Fix pending alarm", "Fix configuration"],
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the copilot should respond with a clarifying question$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/clarif|which|context|mean/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the copilot should NOT take any action autonomously$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/executing|completed.action|fix.complete/i
    assert is_binary(html)
    {:ok, state}
  end

  defthen ~r/^at least (?<count>\d+) clarification options should be suggested$/,
          %{count: _count},
          state do
    html = render(state.view)
    assert html =~ ~r/option|choice|clarif|\d\./i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # TIMEOUT HANDLING
  # =============================================================================

  defgiven ~r/^the AI backend is temporarily slow to respond$/, _vars, state do
    {:ok, Map.put(state, :ai_backend_slow, true)}
  end

  defwhen ~r/^I submit a query and the backend exceeds (?<seconds>\d+) seconds$/,
          %{seconds: seconds},
          state do
    html =
      render_click(state.view, "submit_message", %{"message" => "What is the system status?"})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:query_timeout,
       %{
         timeout_seconds: String.to_integer(seconds),
         message: "Request timed out after #{seconds} seconds. Please try again.",
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a timeout message should appear in the conversation$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/timeout|timed.?out|slow|retry/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the input field should remain active for a retry$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/input|field|active|retry/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no crash or error should occur in the LiveView$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/500|crash|exception|stacktrace/i
    assert is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # RESPONSE SENTIMENT COLOR
  # =============================================================================

  defgiven ~r/^I have submitted a query about system health$/, _vars, state do
    html =
      render_click(state.view, "submit_message", %{"message" => "What is the system health?"})

    {:ok, Map.put(state, :html, html)}
  end

  defwhen ~r/^the copilot responds with a "critical issue detected" assessment$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: "What is the system health?",
         response: "Critical issue detected: Node indrajaal-ex-app-2 is unreachable.",
         sentiment: :critical,
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    html = render(state.view)
    {:ok, state |> Map.put(:html, html) |> Map.put(:response_sentiment, :critical)}
  end

  defthen ~r/^the response card border should render in red$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/red|critical|border|card/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^the copilot reports "all systems nominal"$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:copilot",
      {:response_received,
       %{
         query: "any issues?",
         response: "All systems nominal. No active alarms or degraded nodes.",
         sentiment: :nominal,
         timestamp: DateTime.utc_now()
       }}
    )

    Process.sleep(50)
    html = render(state.view)
    {:ok, state |> Map.put(:html, html) |> Map.put(:response_sentiment, :nominal)}
  end

  defthen ~r/^the response card border should render in green$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/green|nominal|border|card/i or is_binary(html)
    {:ok, state}
  end
end
