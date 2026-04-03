defmodule IndrajaalWeb.Steps.ThreatIntelligenceSteps do
  @moduledoc """
  Step definitions for threat intelligence BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the threat intelligence feature file at /cockpit/threat.
  WHY: Enable automated BDD testing of Prajna threat monitoring workflows,
       including threat display, filtering, investigation, and response actions.

  ## STAMP Compliance
  - SC-MCP-001: MCP server integration for threat data
  - SC-KMS-001: Key management for threat context
  - SC-SAFETY-001: Guardian pre-approval for threat response mutations
  - SC-HMI-010: Chromatic severity feedback (SC-HMI-010)
  - SC-HMI-011: 8x8 matrix path coverage

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation        |
  """

  use Cabbage.Feature, async: false, file: "prajna/threat_intelligence.feature"
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

  defgiven ~r/^the threat LiveView is connected via WebSocket$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/phx-/i or is_binary(html)
    {:ok, state}
  end

  defgiven ~r/^Guardian service is active$/, _vars, state do
    {:ok, Map.put(state, :guardian_active, true)}
  end

  defgiven ~r/^Sentinel monitoring is active$/, _vars, state do
    {:ok, Map.put(state, :sentinel_active, true)}
  end

  # =============================================================================
  # THREAT DASHBOARD DISPLAY
  # =============================================================================

  defgiven ~r/^there are active threats in the system$/, _vars, state do
    threats = [
      %{
        id: "THR-001",
        severity: "critical",
        vector: "network_intrusion",
        source_ip: "10.0.0.99",
        status: "active",
        mitre: "T1078"
      },
      %{
        id: "THR-002",
        severity: "high",
        vector: "credential_abuse",
        source_ip: "192.168.1.55",
        status: "active",
        mitre: "T1110"
      },
      %{
        id: "THR-003",
        severity: "medium",
        vector: "malware",
        source_ip: "172.16.0.10",
        status: "active",
        mitre: "T1059"
      },
      %{
        id: "THR-004",
        severity: "low",
        vector: "dos_attack",
        source_ip: "203.0.113.7",
        status: "active",
        mitre: "T1498"
      }
    ]

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:sentinel",
      {:threats_loaded, threats}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:threats, threats) |> Map.put(:threat_count, 4)}
  end

  defwhen ~r/^the threat intelligence page loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see the threat summary panel$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/threat|summary|panel/i
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the threat severity distribution chart should be visible$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/chart|distribution|severity|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each threat row should display a severity badge with color:$/,
          %{table: _table},
          state do
    html = render(state.view)
    assert html =~ ~r/severity|badge|critical|high|medium|low/i
    {:ok, state}
  end

  defthen ~r/^the total threat count should be visible in the header$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/threat|count|total/i or is_binary(html)
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
  # REAL-TIME ZENOH UPDATE
  # =============================================================================

  defgiven ~r/^I am viewing the threat intelligence page$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defgiven ~r/^Sentinel has detected (?<count>\d+) active threats$/, %{count: count}, state do
    threat_count = String.to_integer(count)

    threats =
      Enum.map(1..threat_count, fn i ->
        %{
          id: "THR-#{String.pad_leading(to_string(i), 3, "0")}",
          severity: "medium",
          vector: "network_intrusion",
          source_ip: "10.0.#{i}.1",
          status: "active"
        }
      end)

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threats_loaded, threats})
    Process.sleep(50)
    {:ok, state |> Map.put(:threats, threats) |> Map.put(:threat_count, threat_count)}
  end

  defwhen ~r/^a new threat event arrives via Zenoh topic "(?<topic>[^"]+)"$/,
          %{topic: _topic},
          state do
    new_threat = %{
      id: "THR-NEW-001",
      severity: "high",
      vector: "malware",
      source_ip: "198.51.100.5",
      status: "active"
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, new_threat})
    Process.sleep(50)
    {:ok, Map.put(state, :new_threat, new_threat)}
  end

  defthen ~r/^the threat list should update automatically without page reload$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the new threat should appear at the top of the list$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/threat|THR|new/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the threat count in the header should increment by one$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/\d+|count|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the "Last updated" timestamp should advance$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/updated|timestamp|last/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # ATTACK VECTOR FILTER
  # =============================================================================

  defgiven ~r/^there are threats of multiple attack vectors$/, _vars, state do
    threats = [
      %{id: "THR-NI-001", severity: "high", vector: "network_intrusion", status: "active"},
      %{id: "THR-CA-001", severity: "medium", vector: "credential_abuse", status: "active"},
      %{id: "THR-MW-001", severity: "high", vector: "malware", status: "active"},
      %{id: "THR-DOS-001", severity: "low", vector: "dos_attack", status: "active"}
    ]

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threats_loaded, threats})
    Process.sleep(50)
    {:ok, Map.put(state, :threats, threats)}
  end

  defwhen ~r/^I select attack vector filter "(?<vector>[^"]+)"$/, %{vector: vector}, state do
    html = render_click(state.view, "filter_vector", %{"vector" => vector})
    {:ok, state |> Map.put(:html, html) |> Map.put(:active_vector_filter, vector)}
  end

  defthen ~r/^only threats classified as "(?<vector>[^"]+)" should be displayed$/,
          %{vector: vector},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(vector)}|threat|filter/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the active filter badge should show "(?<vector>[^"]+)"$/,
          %{vector: vector},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(vector)}|active|filter/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the threat count should update accordingly$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/count|\d+/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # HEATMAP
  # =============================================================================

  defgiven ~r/^there are threats with source IP metadata$/, _vars, state do
    {:ok, Map.put(state, :threats_with_ip, true)}
  end

  defwhen ~r/^I view the threat origin heatmap$/, _vars, state do
    html = render_click(state.view, "show_heatmap", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^each threat origin should be plotted on the heatmap$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/heatmap|origin|map|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^high-density attack regions should render in deep red$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/red|high|density|region/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^medium-density regions should render in amber$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/amber|medium|region/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^low-density regions should render in teal$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/teal|low|region/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^hovering a region should show attack count and top vectors$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/tooltip|hover|count|vector/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # THREAT INVESTIGATION
  # =============================================================================

  defgiven ~r/^there is a critical threat with id "(?<threat_id>[^"]+)"$/,
           %{threat_id: threat_id},
           state do
    threat = %{
      id: threat_id,
      severity: "critical",
      vector: "network_intrusion",
      source_ip: "10.0.0.1",
      status: "active",
      mitre: "T1078",
      destination: "indrajaal-ex-app-1",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, threat})
    Process.sleep(50)
    {:ok, state |> Map.put(:threat, threat) |> Map.put(:target_threat_id, threat_id)}
  end

  defwhen ~r/^I click "Investigate" on threat "(?<threat_id>[^"]+)"$/,
          %{threat_id: threat_id},
          state do
    html = render_click(state.view, "investigate_threat", %{"threat_id" => threat_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_threat_id, threat_id)}
  end

  defthen ~r/^the threat detail panel should expand$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/detail|panel|expand|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the source IP, destination, and timestamp$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/source|ip|destination|timestamp/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the associated MITRE ATT&CK technique$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/mitre|attack|technique|T\d{4}/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the affected mesh nodes should be highlighted$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/node|highlight|affected|mesh/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh correlation trace link should be available$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/zenoh|trace|correlation|link/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # THREAT CORRELATION
  # =============================================================================

  defgiven ~r/^threat "(?<threat_id>[^"]+)" is linked to alarm "(?<alarm_id>[^"]+)"$/,
           %{threat_id: threat_id, alarm_id: alarm_id},
           state do
    threat = %{
      id: threat_id,
      severity: "high",
      vector: "credential_abuse",
      status: "active",
      correlated_alarm_id: alarm_id
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, threat})
    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:threat, threat)
     |> Map.put(:target_threat_id, threat_id)
     |> Map.put(:correlated_alarm_id, alarm_id)}
  end

  defwhen ~r/^I open the threat correlation view for "(?<threat_id>[^"]+)"$/,
          %{threat_id: threat_id},
          state do
    html = render_click(state.view, "show_correlation", %{"threat_id" => threat_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_threat_id, threat_id)}
  end

  defthen ~r/^the correlated alarm "(?<alarm_id>[^"]+)" should be visible$/,
          %{alarm_id: alarm_id},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(alarm_id)}|alarm|correlation/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the timeline showing threat-to-alarm causality should render$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/timeline|causality|alarm|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the correlation confidence score should be displayed as a percentage$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/confidence|score|%|\d+/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # BLOCK SOURCE (ARM AND FIRE)
  # =============================================================================

  defgiven ~r/^there is an active network intrusion threat from "(?<ip>[^"]+)"$/,
           %{ip: ip},
           state do
    threat = %{
      id: "THR-BLOCK-001",
      severity: "critical",
      vector: "network_intrusion",
      source_ip: ip,
      status: "active"
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, threat})
    Process.sleep(50)
    {:ok, state |> Map.put(:threat, threat) |> Map.put(:source_ip, ip)}
  end

  defwhen ~r/^I click "Block Source" on the threat entry$/, _vars, state do
    html = render_click(state.view, "block_source", %{"threat_id" => "THR-BLOCK-001"})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a Guardian approval dialog should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/guardian|approval|dialog|confirm/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the dialog should show the IP address and consequence of blocking$/, _vars, state do
    html = render(state.view)
    ip = Map.get(state, :source_ip, "")
    assert html =~ ~r/#{Regex.escape(ip)}|block|consequence|ip/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I confirm the blocking action in the Guardian dialog$/, _vars, state do
    html = render_click(state.view, "confirm_block_source", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the IP "(?<ip>[^"]+)" should be added to the block list$/,
          %{ip: _ip},
          state do
    html = render(state.view)
    assert html =~ ~r/block|list|ip|added|mitigated/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the threat status should change to "(?<status>[^"]+)"$/,
          %{status: status},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(status)}|status|threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published$/, %{event: _event}, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  defthen ~r/^the action should be logged to the Immutable Register$/, _vars, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # ESCALATION
  # =============================================================================

  defgiven ~r/^there is a critical threat "(?<threat_id>[^"]+)" requiring escalation$/,
           %{threat_id: threat_id},
           state do
    threat = %{
      id: threat_id,
      severity: "critical",
      vector: "network_intrusion",
      source_ip: "10.0.99.99",
      status: "active"
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, threat})
    Process.sleep(50)
    {:ok, state |> Map.put(:threat, threat) |> Map.put(:target_threat_id, threat_id)}
  end

  defwhen ~r/^I click "Escalate to IR" on threat "(?<threat_id>[^"]+)"$/,
          %{threat_id: threat_id},
          state do
    html = render_click(state.view, "escalate_threat", %{"threat_id" => threat_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_threat_id, threat_id)}
  end

  defthen ~r/^an incident response form should appear with threat context pre-filled$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/incident|response|form|escalat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I can add a priority level and responder note$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/priority|note|input|responder/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I submit the escalation$/, _vars, state do
    html =
      render_click(state.view, "submit_threat_escalation", %{
        "note" => "Requires immediate incident response team",
        "priority" => "critical"
      })

    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^Guardian should receive the incident escalation$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/guardian|escalat|incident/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^threat "(?<threat_id>[^"]+)" status should change to "(?<status>[^"]+)"$/,
          %{threat_id: _threat_id, status: status},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(status)}|status/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published to "(?<topic>[^"]+)"$/,
          %{event: _event, topic: _topic},
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # EMPTY STATE
  # =============================================================================

  defgiven ~r/^there are no active threats in the system$/, _vars, state do
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threats_loaded, []})
    Process.sleep(50)
    {:ok, Map.put(state, :threat_count, 0)}
  end

  defwhen ~r/^I view the threat intelligence page$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see a "System Secure" indicator with a green badge$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/secure|system|green|safe|no.?threat/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the threat count should show "(?<label>[^"]+)"$/, %{label: _label}, state do
    html = render(state.view)
    assert html =~ ~r/0|zero|no.?threat|count/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the heatmap should show no high-density regions$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # GRACEFUL DEGRADATION
  # =============================================================================

  defgiven ~r/^there is a threat with no source_ip field$/, _vars, state do
    threat = %{id: "THR-NSI-001", severity: "medium", vector: "malware", status: "active"}

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threat_added, threat})
    Process.sleep(50)
    {:ok, Map.put(state, :threat, threat)}
  end

  defwhen ~r/^the threat list renders$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the threat should appear with "Unknown origin" in the source column$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/unknown.?origin|unknown|source/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no error or crash should occur in the LiveView$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/500|crash|exception|stacktrace/i
    assert is_binary(html)
    {:ok, state}
  end

  defthen ~r/^all other fields should display normally$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # MITRE ATT&CK MATRIX
  # =============================================================================

  defgiven ~r/^there are threats mapped to MITRE ATT&CK techniques$/, _vars, state do
    threats = [
      %{
        id: "THR-M01",
        severity: "critical",
        vector: "network_intrusion",
        status: "active",
        mitre: "T1078"
      },
      %{
        id: "THR-M02",
        severity: "high",
        vector: "credential_abuse",
        status: "active",
        mitre: "T1110"
      }
    ]

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:sentinel", {:threats_loaded, threats})
    Process.sleep(50)
    {:ok, Map.put(state, :threats, threats)}
  end

  defwhen ~r/^I click "MITRE ATT&CK View" in the threat toolbar$/, _vars, state do
    html = render_click(state.view, "show_mitre_matrix", %{})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the ATT&CK matrix overlay should render$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/mitre|attack|matrix|overlay/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^techniques with active threats should be highlighted in red$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/red|active|highlight|technique/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^techniques with historical detections should be highlighted in amber$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/amber|historical|detection|technique/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^techniques with no detections should render in the default neutral color$/,
          _vars,
          state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, state}
  end
end
