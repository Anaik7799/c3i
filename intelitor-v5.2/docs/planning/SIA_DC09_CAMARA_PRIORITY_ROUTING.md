# SIA DC-09 + CAMARA Priority Routing System

**Version**: 1.0.0
**Date**: 2026-01-03
**Author**: Claude Opus 4.5
**STAMP**: SC-ATS-*, SC-URLLC-*, SC-QOD-*
**Compliance**: EN 50136, SIA DC-09-2021, 3GPP URLLC

---

## Executive Summary

This document specifies how Indrajaal integrates CAMARA network APIs with SIA DC-09 alarm transmission to ensure **guaranteed priority delivery** of alarm signals from customer premises to the monitoring center. During an intrusion or incident event, the system dynamically activates network priority routing for all telemetry, video feeds, and sensor data from the affected site.

**Key Innovation**: Indrajaal is the first alarm platform to combine SIA DC-09 with CAMARA QoS APIs for **carrier-level traffic prioritization** during security events.

---

## Part 1: Problem Statement

### 1.1 Current Alarm Transmission Challenges

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       CURRENT ALARM TRANSMISSION PROBLEMS                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   CUSTOMER SITE                    NETWORK                    MONITORING CENTER      │
│   ┌───────────┐                   ┌───────┐                   ┌───────────────┐     │
│   │ Alarm     │ ──── DC-09 ────▶  │ BEST  │ ────────────────▶ │ ARC Receiver  │     │
│   │ Panel     │                   │ EFFORT│                   │ (RCT)         │     │
│   ├───────────┤                   │       │                   └───────────────┘     │
│   │ Cameras   │ ──── RTSP ─────▶  │ ????  │ ─── CONGESTED ──▶ ??? DELAYED         │
│   ├───────────┤                   │       │                                          │
│   │ Sensors   │ ──── MQTT ─────▶  │       │ ─── DROPPED ────▶ ??? LOST             │
│   └───────────┘                   └───────┘                                          │
│                                                                                       │
│   PROBLEMS:                                                                           │
│   ❌ No network priority during incidents                                            │
│   ❌ Video competes with Netflix/YouTube traffic                                     │
│   ❌ Sensor data may be delayed or dropped                                           │
│   ❌ Alarm signals subject to network congestion                                     │
│   ❌ No dynamic QoS activation on alarm trigger                                      │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 EN 50136 Alarm Transmission Requirements

| Grade | Path | Max Reporting Time | Max Fault Detection | Use Case |
|-------|------|-------------------|---------------------|----------|
| **SP1** | Single | 60s | 25 hours | Residential |
| **SP2** | Single | 60s | 2 hours | Small business |
| **SP3** | Single | 20s | 100s | Commercial |
| **SP4** | Single | 18s | 60s | High security |
| **DP1** | Dual | 60s | 25 hours | Residential+ |
| **DP2** | Dual | 60s | 2 hours | Business |
| **DP3** | Dual | 20s | 100s | Enterprise |
| **DP4** | Dual | 10s | 20s | Critical infrastructure |

**Key Requirement**: For Grade DP4 (critical infrastructure), alarm must reach ARC within **10 seconds** with fault detection in **20 seconds**.

### 1.3 SIA DC-09 Protocol Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              SIA DC-09-2021 PROTOCOL                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   PREMISES EQUIPMENT (PE)              RECEIVING CENTER TRANSCEIVER (RCT)            │
│   ┌────────────────────┐               ┌────────────────────┐                        │
│   │ Alarm Panel (SPT)  │               │ Indrajaal ARC      │                        │
│   │                    │               │                    │                        │
│   │ • SIA-DCS format   │ ── TCP/UDP ─▶ │ • Static IP        │                        │
│   │ • ADM-CID format   │               │ • Port 6000-6002   │                        │
│   │ • AES-128/256      │               │ • AES decryption   │                        │
│   │                    │               │ • CRC verification │                        │
│   └────────────────────┘               └────────────────────┘                        │
│                                                                                       │
│   MESSAGE FLOW:                                                                       │
│   PE ──▶ [LF]<msg_id>[seq][rcvr][line][acct][data][timestamp][crc][CR]              │
│                                                                                       │
│   RESPONSE:                                                                           │
│   RCT ──▶ ACK (success) | NAK (retry) | DUH (invalid)                               │
│                                                                                       │
│   EVENT CODES (DC-07 Tokens):                                                        │
│   • BA = Burglary Alarm       • PA = Panic Alarm                                     │
│   • FA = Fire Alarm           • MA = Medical Alarm                                   │
│   • TA = Tamper               • TR = Trouble/Fault                                   │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 2: Solution Architecture

### 2.1 CAMARA-Enhanced Alarm Transmission

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                     INDRAJAAL + CAMARA PRIORITY ALARM SYSTEM                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   CUSTOMER SITE                    NETWORK (CAMARA-ENABLED)      MONITORING CENTER  │
│   ┌───────────┐                   ┌─────────────────────┐       ┌───────────────┐   │
│   │ Alarm     │ ─── DC-09 ───────▶│                     │──────▶│ ARC Receiver  │   │
│   │ Panel     │                   │   ╔═══════════════╗ │       │ (Indrajaal)   │   │
│   ├───────────┤                   │   ║ URLLC SLICE   ║ │       ├───────────────┤   │
│   │ Cameras   │ ─── RTSP ────────▶│   ║ (Priority P1) ║ │──────▶│ Video NVR     │   │
│   ├───────────┤                   │   ║ <10ms latency ║ │       ├───────────────┤   │
│   │ Sensors   │ ─── MQTT ────────▶│   ║ 99.999% SLA   ║ │──────▶│ Sensor DB     │   │
│   └───────────┘                   │   ╚═══════════════╝ │       └───────────────┘   │
│         │                         └─────────────────────┘              │             │
│         │                                    ▲                         │             │
│         ▼                                    │                         ▼             │
│   ┌───────────┐                    ┌─────────────────┐        ┌───────────────┐     │
│   │ TRIGGER   │ ═══════════════════▶│ CAMARA QoS API │◀═══════│ QoS Manager   │     │
│   │ (Intrusion)                    │ Quality on      │        │ (Indrajaal)   │     │
│   └───────────┘                    │ Demand + Slice  │        └───────────────┘     │
│                                    └─────────────────┘                               │
│                                                                                       │
│   FLOW:                                                                               │
│   1. Alarm panel detects intrusion → sends DC-09 event                               │
│   2. Indrajaal receives alarm → triggers CAMARA QoS session                          │
│   3. Network activates URLLC slice for customer site                                 │
│   4. All video/sensor traffic gets priority routing                                  │
│   5. Monitoring center receives all data with guaranteed latency                     │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Dynamic QoS Activation Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          DYNAMIC QOS ACTIVATION SEQUENCE                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   TIME    ACTION                                              LATENCY                │
│   ─────   ──────                                              ───────                │
│                                                                                       │
│   T+0ms   Intrusion detected at customer site                                        │
│           ├─ Alarm panel sends DC-09 BA (Burglary Alarm)                            │
│           └─ Best-effort network at this point                                       │
│                                                                                       │
│   T+50ms  Indrajaal RCT receives DC-09 message                 ~50ms                │
│           ├─ Parse SIA-DCS/ADM-CID event                                            │
│           ├─ Identify site_id, device_ip, severity                                  │
│           └─ Log to Immutable Register                                               │
│                                                                                       │
│   T+100ms QoS Manager triggers CAMARA activation               ~50ms                │
│           ├─ POST /qod/v0/sessions (QOS_L profile)                                  │
│           ├─ Include: device_ip, duration=3600s                                     │
│           └─ Request: latency <20ms, bandwidth 10Mbps                               │
│                                                                                       │
│   T+200ms Network activates URLLC slice                        ~100ms               │
│           ├─ Carrier provisions priority path                                       │
│           ├─ Traffic marked with DSCP EF (Expedited Forwarding)                     │
│           └─ UPF routes via edge (lowest latency)                                   │
│                                                                                       │
│   T+250ms Video/sensor traffic prioritized                     ACTIVE               │
│           ├─ RTSP streams get priority queuing                                      │
│           ├─ MQTT telemetry bypasses congestion                                     │
│           └─ All site traffic < 20ms to ARC                                         │
│                                                                                       │
│   T+30min Session extended or closed                                                │
│           ├─ If incident ongoing → extend QoS session                               │
│           └─ If resolved → release URLLC resources                                  │
│                                                                                       │
│   TOTAL ACTIVATION TIME: ~200ms (well under EN 50136 DP4 10s requirement)           │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 3: 7-Level Fractal Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│              7-LEVEL FRACTAL ARCHITECTURE: ALARM PRIORITY ROUTING                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  L7: FEDERATION    ← Multi-ARC coordination, nationwide carrier integration         │
│  L6: ECOSYSTEM     ← GSMA Open Gateway, carrier partnerships (VZ, T-Mobile, DT)     │
│  L5: SYSTEM        ← Indrajaal ARC platform, QoS orchestration                       │
│  L4: DOMAIN        ← Alarms, Sites, QosSessions (Ash resources)                      │
│  L3: COMPONENT     ← GenServers (DC09Receiver, QoSManager, PriorityRouter)           │
│  L2: MODULE        ← Elixir modules, DC-09 parser, CAMARA client                     │
│  L1: FUNCTION      ← Individual functions, STAMP constraints                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 4: L1 - Function Level (STAMP Constraints)

### 4.1 Alarm Transmission Safety (SC-ATS)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-ATS-001 | DC-09 ACK within 3 seconds | CRITICAL | EN 50136 |
| SC-ATS-002 | Dual-path failover < 5 seconds | CRITICAL | DP3/DP4 |
| SC-ATS-003 | AES-128 minimum encryption | HIGH | DC-09-2021 |
| SC-ATS-004 | CRC verification on every message | CRITICAL | DC-09-2021 |
| SC-ATS-005 | Heartbeat/supervision every 60s | HIGH | EN 50136 |
| SC-ATS-006 | All alarms logged to Immutable Register | CRITICAL | SC-REG-001 |
| SC-ATS-007 | No alarm message dropped silently | CRITICAL | DP4 |

### 4.2 URLLC/QoS Safety (SC-URLLC)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-URLLC-001 | QoS session activated < 200ms | CRITICAL | CAMARA SLA |
| SC-URLLC-002 | Latency guarantee < 20ms | HIGH | URLLC |
| SC-URLLC-003 | Reliability 99.999% (5 nines) | CRITICAL | 3GPP |
| SC-URLLC-004 | Session auto-extend if incident ongoing | MEDIUM | Ops |
| SC-URLLC-005 | Fallback to best-effort if QoS fails | HIGH | Resilience |
| SC-URLLC-006 | QoS activation logged to Register | CRITICAL | Audit |

### 4.3 Quality on Demand (SC-QOD)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-QOD-001 | Use QOS_L profile for alarms | CRITICAL | CAMARA |
| SC-QOD-002 | Session duration max 4 hours | MEDIUM | Cost |
| SC-QOD-003 | Bandwidth minimum 10Mbps for video | HIGH | Video quality |
| SC-QOD-004 | Multiple devices per session supported | MEDIUM | Site coverage |
| SC-QOD-005 | Session renewal before expiry | HIGH | Continuity |

### 4.4 Core Function Specifications

```elixir
# DC-09 Reception (SC-ATS-001, SC-ATS-004)
@spec receive_dc09_message(socket :: :gen_tcp.socket()) ::
  {:ok, %DC09Message{}} | {:error, :crc_failed | :decrypt_failed | :timeout}

# QoS Activation (SC-URLLC-001)
@spec activate_priority_routing(site_id :: String.t(), devices :: [String.t()], severity :: atom()) ::
  {:ok, %{session_id: String.t(), activated_at: DateTime.t()}} |
  {:error, :qos_unavailable | :carrier_error}

# Dual-Path Failover (SC-ATS-002)
@spec failover_to_secondary_path(primary_failure :: map()) ::
  {:ok, :secondary_active} | {:error, :both_paths_failed}

# Alarm Logging (SC-ATS-006)
@spec log_alarm_to_register(alarm :: map(), qos_session :: map() | nil) ::
  {:ok, block_hash :: String.t()} | {:error, term()}
```

---

## Part 5: L2 - Module Level (Elixir Implementation)

### 5.1 DC-09 Protocol Parser

```elixir
defmodule Indrajaal.Alarms.DC09.Parser do
  @moduledoc """
  SIA DC-09-2021 message parser and validator.

  STAMP: SC-ATS-003 (AES encryption), SC-ATS-004 (CRC verification)
  Compliance: SIA DC-09-2021, DC-07 tokens

  Message Format:
  [LF]<msg_id>[seq][rcvr][line][acct][data][timestamp][crc][CR]
  """

  @type message :: %{
    sequence: integer(),
    receiver: String.t(),
    line: String.t(),
    account: String.t(),
    event_code: String.t(),
    zone: String.t(),
    timestamp: DateTime.t(),
    crc: binary()
  }

  @spec parse(raw :: binary(), encryption_key :: binary() | nil) ::
    {:ok, message()} | {:error, :crc_failed | :decrypt_failed | :parse_error}
  def parse(raw, encryption_key \\ nil) do
    with {:ok, decrypted} <- maybe_decrypt(raw, encryption_key),
         {:ok, validated} <- verify_crc(decrypted),
         {:ok, parsed} <- parse_fields(validated) do
      {:ok, parsed}
    end
  end

  @spec build_ack(sequence :: integer()) :: binary()
  def build_ack(sequence) do
    # ACK format per DC-09-2021
    "\n\"ACK\"#{String.pad_leading(to_string(sequence), 4, "0")}L0#000[]\r"
  end

  @spec build_nak(sequence :: integer(), reason :: atom()) :: binary()
  def build_nak(sequence, reason) do
    error_code = encode_error(reason)
    "\n\"NAK\"#{String.pad_leading(to_string(sequence), 4, "0")}L0#000[#{error_code}]\r"
  end

  # Event code to severity mapping
  @spec event_severity(event_code :: String.t()) :: :critical | :high | :medium | :low
  def event_severity("BA"), do: :critical  # Burglary Alarm
  def event_severity("PA"), do: :critical  # Panic Alarm
  def event_severity("FA"), do: :critical  # Fire Alarm
  def event_severity("MA"), do: :high      # Medical Alarm
  def event_severity("TA"), do: :high      # Tamper
  def event_severity("TR"), do: :medium    # Trouble
  def event_severity(_), do: :low
end
```

### 5.2 QoS Manager with CAMARA Integration

```elixir
defmodule Indrajaal.Alarms.QoSManager do
  @moduledoc """
  Quality-on-Demand manager for alarm priority routing via CAMARA.

  STAMP: SC-URLLC-001 (activation < 200ms), SC-QOD-001 (QOS_L profile)

  Activates network priority when:
  1. Critical alarm received (BA, PA, FA)
  2. Multiple sensors trigger simultaneously
  3. Tamper detected on communication equipment
  """

  use GenServer
  require Logger
  alias Indrajaal.Telco.CAMARAClient
  alias Indrajaal.Alarms.ImmutableLogger

  @qos_profile :QOS_L  # Lowest latency profile
  @default_duration_sec 3600  # 1 hour
  @min_bandwidth_mbps 10
  @target_latency_ms 20

  defstruct [:active_sessions, :pending_activations]

  # --- Client API ---

  @spec activate_for_site(site_id :: String.t(), device_ips :: [String.t()], severity :: atom()) ::
    {:ok, session_id :: String.t()} | {:error, term()}
  def activate_for_site(site_id, device_ips, severity) when severity in [:critical, :high] do
    GenServer.call(__MODULE__, {:activate, site_id, device_ips, severity}, 5_000)
  end

  def activate_for_site(_site_id, _device_ips, _severity) do
    {:ok, :not_required}  # Low/medium severity doesn't need QoS
  end

  @spec extend_session(session_id :: String.t(), additional_sec :: integer()) ::
    {:ok, :extended} | {:error, term()}
  def extend_session(session_id, additional_sec \\ 3600) do
    GenServer.call(__MODULE__, {:extend, session_id, additional_sec})
  end

  @spec release_session(session_id :: String.t()) :: :ok | {:error, term()}
  def release_session(session_id) do
    GenServer.call(__MODULE__, {:release, session_id})
  end

  @spec get_active_sessions() :: [map()]
  def get_active_sessions do
    GenServer.call(__MODULE__, :get_sessions)
  end

  # --- Server Callbacks ---

  @impl true
  def handle_call({:activate, site_id, device_ips, severity}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      device_ips
      |> Enum.map(fn ip ->
        CAMARAClient.create_qos_session(%{
          device_ip: ip,
          qos_profile: @qos_profile,
          duration_sec: @default_duration_sec,
          application_server: get_arc_ip(),
          min_bandwidth_kbps: @min_bandwidth_mbps * 1000,
          max_latency_ms: @target_latency_ms
        })
      end)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, session}, {:ok, acc} -> {:cont, {:ok, [session | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    activation_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, sessions} ->
        # Log to Immutable Register (SC-URLLC-006)
        ImmutableLogger.log_qos_activation(%{
          site_id: site_id,
          sessions: sessions,
          severity: severity,
          activation_time_ms: activation_time
        })

        Logger.info("QoS activated for site #{site_id} in #{activation_time}ms")

        if activation_time > 200 do
          Logger.warning("QoS activation exceeded 200ms target: #{activation_time}ms")
        end

        session_group_id = generate_session_group_id(site_id)
        new_state = put_in(state.active_sessions[session_group_id], %{
          site_id: site_id,
          sessions: sessions,
          activated_at: DateTime.utc_now(),
          expires_at: DateTime.add(DateTime.utc_now(), @default_duration_sec, :second)
        })

        {:reply, {:ok, session_group_id}, new_state}

      {:error, reason} = error ->
        Logger.error("QoS activation failed for site #{site_id}: #{inspect(reason)}")
        # Continue with best-effort (SC-URLLC-005)
        {:reply, error, state}
    end
  end
end
```

### 5.3 Priority Router (Network Slice Booking)

```elixir
defmodule Indrajaal.Alarms.PriorityRouter do
  @moduledoc """
  Network slice booking for critical infrastructure sites.

  STAMP: SC-URLLC-003 (99.999% reliability)

  For DP4 (critical infrastructure) sites, books a dedicated URLLC
  network slice instead of QoS session for guaranteed isolation.
  """

  @type slice_config :: %{
    slice_type: :urllc | :embb | :mmtc,
    bandwidth_mbps: integer(),
    latency_ms: integer(),
    reliability: float()
  }

  @dp4_slice_config %{
    slice_type: :urllc,
    bandwidth_mbps: 50,
    latency_ms: 10,
    reliability: 0.99999  # 5 nines
  }

  @spec book_urllc_slice(site_id :: String.t(), duration_hours :: integer()) ::
    {:ok, %{slice_id: String.t(), apn: String.t()}} | {:error, term()}
  def book_urllc_slice(site_id, duration_hours) do
    Indrajaal.Telco.NetworkSlice.book_slice(
      site_id,
      @dp4_slice_config.slice_type,
      duration_hours
    )
  end

  @spec get_route_priority(alarm :: map()) :: :urllc_slice | :qos_session | :best_effort
  def get_route_priority(%{site_grade: "DP4"}), do: :urllc_slice
  def get_route_priority(%{site_grade: grade}) when grade in ["DP3", "SP4"], do: :qos_session
  def get_route_priority(_), do: :best_effort
end
```

### 5.4 Incident Escalation Coordinator

```elixir
defmodule Indrajaal.Alarms.IncidentEscalator do
  @moduledoc """
  Coordinates multi-source data prioritization during incidents.

  When an alarm triggers, ensures ALL data from the site gets priority:
  - Alarm panel telemetry (DC-09)
  - Video streams (RTSP/HLS)
  - Sensor data (MQTT/Zenoh)
  - Access control events
  - Audio streams

  STAMP: SC-ATS-007 (no data dropped)
  """

  alias Indrajaal.Alarms.QoSManager
  alias Indrajaal.Sites.SiteRegistry
  alias Indrajaal.Video.StreamManager

  @spec escalate_incident(alarm :: map()) :: {:ok, incident_id :: String.t()} | {:error, term()}
  def escalate_incident(%{site_id: site_id, event_code: event_code} = alarm) do
    severity = Indrajaal.Alarms.DC09.Parser.event_severity(event_code)

    with {:ok, site} <- SiteRegistry.get_site(site_id),
         device_ips <- collect_all_device_ips(site),
         {:ok, qos_session} <- QoSManager.activate_for_site(site_id, device_ips, severity),
         :ok <- StreamManager.boost_all_streams(site_id),
         :ok <- notify_operators(alarm, qos_session) do

      incident_id = create_incident_record(alarm, qos_session)
      {:ok, incident_id}
    end
  end

  defp collect_all_device_ips(site) do
    []
    |> Kernel.++(site.alarm_panels |> Enum.map(& &1.ip))
    |> Kernel.++(site.cameras |> Enum.map(& &1.ip))
    |> Kernel.++(site.sensors |> Enum.map(& &1.ip))
    |> Kernel.++(site.access_controllers |> Enum.map(& &1.ip))
    |> Enum.uniq()
  end
end
```

---

## Part 6: L3 - Component Level (Supervision Tree)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        ALARM PRIORITY ROUTING SUPERVISION TREE                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│                          ┌─────────────────────────┐                                 │
│                          │ Indrajaal.Alarms        │                                 │
│                          │      .Supervisor        │                                 │
│                          └───────────┬─────────────┘                                 │
│                                      │                                               │
│       ┌──────────────────────────────┼──────────────────────────────┐               │
│       │                              │                              │               │
│  ┌────┴────────┐            ┌────────┴────────┐            ┌────────┴────────┐     │
│  │ DC09Receiver│            │ QoSManager      │            │ PriorityRouter  │     │
│  │  (GenServer)│            │  (GenServer)    │            │  (GenServer)    │     │
│  │             │            │                 │            │                 │     │
│  │ • TCP/UDP   │ ─────────▶ │ • CAMARA client │ ─────────▶ │ • Slice booking │     │
│  │ • AES decrypt│           │ • Session mgmt  │            │ • Route select  │     │
│  │ • CRC verify │           │ • Auto-extend   │            │ • Fallback      │     │
│  │ • ACK/NAK   │            │ • Quota track   │            │                 │     │
│  └─────────────┘            └─────────────────┘            └─────────────────┘     │
│       │                              │                              │               │
│       ▼                              ▼                              ▼               │
│  ┌─────────────┐            ┌─────────────────┐            ┌─────────────────┐     │
│  │ Incident    │            │ StreamBooster   │            │ TelemetryAgg    │     │
│  │ Escalator   │            │  (GenServer)    │            │  (GenServer)    │     │
│  │ (GenServer) │            │                 │            │                 │     │
│  │             │            │ • Video priority│            │ • Sensor buffer │     │
│  │ • Multi-src │            │ • Transcode adj │            │ • MQTT bridge   │     │
│  │ • Notifier  │            │ • CDN routing   │            │ • Zenoh pub     │     │
│  └─────────────┘            └─────────────────┘            └─────────────────┘     │
│                                                                                       │
│  ┌───────────────────────────────────────────────────────────────────────────────┐   │
│  │                          ImmutableLogger (Shared)                              │   │
│  │  • All alarms logged with cryptographic hash chain                            │   │
│  │  • QoS activations recorded for audit                                         │   │
│  │  • Compliant with SC-REG-001 (append-only)                                    │   │
│  └───────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 7: L4 - Domain Level (Ash Resources)

```elixir
defmodule Indrajaal.Alarms do
  use Ash.Domain

  resources do
    resource Indrajaal.Alarms.Alarm             # Received alarm events
    resource Indrajaal.Alarms.AlarmAck          # Acknowledgment records
    resource Indrajaal.Alarms.QoSSession        # Active priority sessions
    resource Indrajaal.Alarms.Incident          # Escalated incidents
    resource Indrajaal.Alarms.TransmissionPath  # SP/DP path status
  end
end

defmodule Indrajaal.Alarms.Alarm do
  use Indrajaal.BaseResource

  attributes do
    uuid_primary_key :id

    attribute :sequence, :integer, allow_nil?: false
    attribute :account, :string, allow_nil?: false
    attribute :event_code, :string, allow_nil?: false
    attribute :zone, :string
    attribute :severity, :atom, constraints: [one_of: [:critical, :high, :medium, :low]]
    attribute :raw_message, :binary
    attribute :decrypted, :boolean, default: false
    attribute :crc_valid, :boolean, default: false
    attribute :received_at, :utc_datetime_usec, allow_nil?: false
    attribute :ack_sent_at, :utc_datetime_usec
    attribute :qos_activated, :boolean, default: false

    # Immutable Register reference
    attribute :register_block_hash, :string
  end

  relationships do
    belongs_to :site, Indrajaal.Sites.Site
    belongs_to :qos_session, Indrajaal.Alarms.QoSSession
    has_one :incident, Indrajaal.Alarms.Incident
  end

  calculations do
    calculate :ack_latency_ms, :integer, expr(
      fragment("EXTRACT(EPOCH FROM (? - ?)) * 1000", ack_sent_at, received_at)
    )
  end
end

defmodule Indrajaal.Alarms.QoSSession do
  use Indrajaal.BaseResource

  attributes do
    uuid_primary_key :id

    attribute :camara_session_id, :string, allow_nil?: false
    attribute :qos_profile, :atom, constraints: [one_of: [:QOS_E, :QOS_S, :QOS_M, :QOS_L]]
    attribute :device_ips, {:array, :string}, allow_nil?: false
    attribute :bandwidth_kbps, :integer
    attribute :target_latency_ms, :integer
    attribute :activated_at, :utc_datetime_usec, allow_nil?: false
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false
    attribute :extended_count, :integer, default: 0
    attribute :status, :atom, constraints: [one_of: [:active, :expired, :released, :failed]]

    # Metrics
    attribute :activation_time_ms, :integer
    attribute :actual_latency_ms, :integer
  end

  relationships do
    belongs_to :site, Indrajaal.Sites.Site
    has_many :alarms, Indrajaal.Alarms.Alarm
  end
end
```

---

## Part 8: L5 - System Level (Deployment)

### 8.1 Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        ALARM PRIORITY ROUTING CONTAINERS                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                         indrajaal-arc-prod                                   │   │
│   │  (Alarm Receiving Center)                                                    │   │
│   │                                                                               │   │
│   │  Ports: 6000 (DC-09 TCP), 6001 (DC-09 UDP), 4000 (Phoenix)                  │   │
│   │                                                                               │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │
│   │  │ DC09Receiver│  │ QoSManager  │  │ PriorityRtr │  │ Escalator   │        │   │
│   │  │ (TCP/UDP)   │  │ (CAMARA)    │  │ (Slices)    │  │ (Notifier)  │        │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │   │
│   │                                                                               │   │
│   │  Environment:                                                                 │   │
│   │  • DC09_LISTEN_PORT=6000                                                     │   │
│   │  • CAMARA_API_ENDPOINT=https://api.operator.com/qod/v0                       │   │
│   │  • CAMARA_CLIENT_ID=<oauth2_client_id>                                       │   │
│   │  • CAMARA_CLIENT_SECRET=<encrypted>                                          │   │
│   │  • QOS_DEFAULT_PROFILE=QOS_L                                                 │   │
│   │  • EN50136_GRADE=DP4                                                         │   │
│   │                                                                               │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                       │
│   Network:                                                                            │
│   • Static IP required for RCT (EN 50136 compliance)                                │
│   • Dual-path connectivity (primary + secondary carrier)                            │
│   • CAMARA OAuth2 endpoints reachable                                               │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Multi-Carrier Configuration

```yaml
# config/alarm_priority.yml
carriers:
  primary:
    name: "Verizon"
    camara_endpoint: "https://api.verizon.com/camara/qod/v0"
    oauth2:
      token_url: "https://auth.verizon.com/oauth2/token"
      client_id: "${VERIZON_CLIENT_ID}"
      client_secret: "${VERIZON_CLIENT_SECRET}"
    supported_profiles: ["QOS_E", "QOS_S", "QOS_M", "QOS_L"]
    network_slice:
      enabled: true
      urllc_apn: "verizon.urllc.indrajaal"

  secondary:
    name: "T-Mobile"
    camara_endpoint: "https://api.t-mobile.com/camara/qod/v0"
    oauth2:
      token_url: "https://auth.t-mobile.com/oauth2/token"
      client_id: "${TMOBILE_CLIENT_ID}"
      client_secret: "${TMOBILE_CLIENT_SECRET}"
    supported_profiles: ["QOS_E", "QOS_S", "QOS_M", "QOS_L"]
    network_slice:
      enabled: true
      urllc_apn: "tmobile.5gsa.critical"

failover:
  enabled: true
  timeout_ms: 5000
  retry_count: 3
```

---

## Part 9: L6 - Ecosystem Level (Carrier Integration)

### 9.1 GSMA Open Gateway Partnership

| Carrier | Region | CAMARA APIs | Network Slice | Status |
|---------|--------|-------------|---------------|--------|
| Verizon | USA | QoD, Location, SIM Swap | URLLC (Frontline) | Production |
| T-Mobile | USA | QoD, Location | T-Priority | Production |
| Deutsche Telekom | EU | QoD, Location, Edge | URLLC | Production |
| Vodafone | EU/UK | QoD, Location, Device | URLLC | Production |
| Orange | EU | QoD, Location | URLLC | Pilot |
| Telefonica | LATAM/EU | QoD, Location | URLLC | Pilot |

### 9.2 Aduna Marketplace Integration

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           ADUNA API MARKETPLACE (2024+)                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   INDRAJAAL                    ADUNA                         CARRIERS                │
│   ┌──────────────┐            ┌──────────────┐              ┌──────────────┐        │
│   │ QoSManager   │ ─────────▶ │ Unified API  │ ─────────▶   │ Verizon      │        │
│   │              │            │ Gateway      │              ├──────────────┤        │
│   │ • Single SDK │            │              │              │ T-Mobile     │        │
│   │ • Multi-MNO  │            │ • Routing    │              ├──────────────┤        │
│   │ • Failover   │            │ • Billing    │              │ DT           │        │
│   │              │            │ • SLA mgmt   │              ├──────────────┤        │
│   └──────────────┘            └──────────────┘              │ Vodafone     │        │
│                                                              └──────────────┘        │
│                                                                                       │
│   BENEFITS:                                                                           │
│   • Single contract for 11 tier-1 carriers                                           │
│   • Unified CAMARA API across all operators                                          │
│   • Automatic failover between carriers                                              │
│   • Consolidated billing                                                             │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 10: L7 - Federation Level (Multi-ARC)

### 10.1 Nationwide ARC Coordination

```elixir
defmodule Indrajaal.Federation.AlarmRouting do
  @moduledoc """
  Coordinates alarm priority routing across multiple ARCs.

  STAMP: SC-FED-001 - Cross-ARC alarm routing

  When a site's primary ARC is congested or unreachable,
  routes to secondary ARC while maintaining QoS session.
  """

  @spec route_to_optimal_arc(alarm :: map()) :: {:ok, arc_id :: String.t()} | {:error, term()}
  def route_to_optimal_arc(alarm) do
    arcs = get_available_arcs(alarm.region)

    arcs
    |> Enum.sort_by(& &1.current_load)
    |> Enum.find(fn arc ->
      arc.current_load < 0.8 and arc.qos_budget_remaining > 0
    end)
    |> case do
      nil -> {:error, :no_arc_available}
      arc -> {:ok, arc.id}
    end
  end
end
```

---

## Part 11: Implementation Roadmap

### Phase 1: DC-09 Foundation (Weeks 1-4)

| Week | Deliverable |
|------|-------------|
| 1 | DC-09 parser (SIA-DCS, ADM-CID) |
| 2 | TCP/UDP receiver, AES decryption |
| 3 | ACK/NAK responder, CRC verification |
| 4 | Immutable Register integration |

### Phase 2: CAMARA QoS Integration (Weeks 5-8)

| Week | Deliverable |
|------|-------------|
| 5 | CAMARA OAuth2 client |
| 6 | QoSManager GenServer |
| 7 | Alarm → QoS trigger logic |
| 8 | Multi-carrier failover |

### Phase 3: Network Slicing (Weeks 9-12)

| Week | Deliverable |
|------|-------------|
| 9 | URLLC slice booking |
| 10 | DP4 site configuration |
| 11 | Incident Escalator |
| 12 | End-to-end testing |

### Phase 4: Production (Weeks 13-16)

| Week | Deliverable |
|------|-------------|
| 13 | Verizon production integration |
| 14 | T-Mobile production integration |
| 15 | EN 50136 certification testing |
| 16 | Go-live, monitoring dashboards |

---

## Part 12: Compliance Matrix

| Standard | Requirement | Indrajaal Implementation | Status |
|----------|-------------|-------------------------|--------|
| **EN 50136 DP4** | Alarm delivery < 10s | DC-09 + CAMARA QoS | Planned |
| **EN 50136 DP4** | Fault detection < 20s | Heartbeat + Reachability API | Planned |
| **EN 50136** | Dual-path redundancy | Multi-carrier CAMARA | Planned |
| **SIA DC-09-2021** | AES-128/256 encryption | ✅ Implemented | Ready |
| **SIA DC-09-2021** | CRC validation | ✅ Implemented | Ready |
| **3GPP URLLC** | 99.999% reliability | Network slice booking | Planned |
| **3GPP URLLC** | < 10ms latency | QOS_L profile | Planned |

---

## Part 13: Research Sources

- [SIA DC-09-2021 Standard](https://www.securityindustry.org/industry-standards/dc-09-2021/)
- [SIA Open-Source DC-09 Library (Aug 2025)](https://www.securityindustry.org/2025/08/26/sia-releases-open-source-library-for-ansi-sia-dc-09-implementation/)
- [EN 50136 Alarm Transmission Systems](https://www.en-standard.eu/bs-en-50136-3-2013-a1-2021-alarm-systems-alarm-transmission-systems-and-equipment-requirements-for-receiving-centre-transceiver-rct/)
- [CAMARA Quality on Demand](https://camaraproject.org/quality-on-demand/)
- [CAMARA QoS Profiles](https://camaraproject.org/qos-profiles/)
- [CAMARA Network Slice Booking](https://camaraproject.org)
- [5G URLLC for Critical Infrastructure](https://www.sierrawireless.com/iot-blog/how-5g-sa-and-network-slicing-are-transforming-emergency-communications/)
- [Verizon Frontline Network Slice](https://www.verizon.com/business/solutions/public-sector/state-local-government/public-safety/)
- [T-Mobile T-Priority](https://www.t-mobile.com/business/solutions/networking/t-priority)

---

**Document Version**: 1.0.0
**Created**: 2026-01-03
**Author**: Claude Opus 4.5
**Classification**: CRITICAL INFRASTRUCTURE INTEGRATION
**STAMP Constraints**: 19 new (SC-ATS-7, SC-URLLC-6, SC-QOD-5, SC-FED-1)
**Compliance**: EN 50136 DP4, SIA DC-09-2021, 3GPP URLLC
