# Genesys Cloud CX Integration for ARC Human-in-the-Loop Operations

**Version**: 1.0.0 | **Date**: 2026-01-03 | **Author**: Claude Opus 4.5
**Status**: DESIGN APPROVED
**STAMP**: SC-GEN-*, SC-ARC-*, SC-CTI-*, SC-WFM-*
**Compliance**: EN 50518, NSI/ANSI, BS 5979, ISO 27001

---

## Executive Summary

This document specifies the integration of **Genesys Cloud CX** with Indrajaal to enable **carrier-grade Alarm Receiving Center (ARC) operations** with human-in-the-loop escalation. The integration transforms Indrajaal from a software platform into a complete **Contact Center as a Service (CCaaS)** for security monitoring operations.

### Strategic Value

**Indrajaal + Genesys Cloud becomes the ONLY platform offering:**
1. **Automated Alarm Processing** - AI-driven triage with Prajna Copilot
2. **Human Escalation** - Genesys Cloud agent routing for complex incidents
3. **Quality Management** - Full call recording, evaluation, and coaching
4. **Workforce Management** - Agent scheduling optimized for alarm patterns
5. **Screen Pop** - Instant context delivery to agents on alarm escalation
6. **Omnichannel** - Voice, video, chat, SMS for subscriber communication
7. **EN 50518 Compliance** - ARC certification-ready operations

---

## Part 1: Genesys Cloud CX API Analysis

### 1.1 Core API Categories

Based on comprehensive research of the [Genesys Cloud Developer Center](https://developer.genesys.cloud/), the following API categories are relevant for ARC integration:

| Category | Purpose | Indrajaal Use Case |
|----------|---------|-------------------|
| **Conversations** | Voice, chat, message handling | Alarm escalation calls, subscriber notifications |
| **Routing** | Queue management, skill-based routing | Alarm severity routing, language routing |
| **Callbacks** | Scheduled callback management | Subscriber callbacks, patrol dispatch |
| **External Contacts** | CRM-style contact database | Subscriber profiles, site information |
| **Data Actions** | Custom API integrations | Indrajaal ↔ Genesys data exchange |
| **Architect Flows** | IVR and routing logic | Alarm triage flows, verification scripts |
| **Outbound** | Proactive dialing campaigns | Subscriber notifications, wellness checks |
| **Quality Management** | Recording, evaluation, coaching | ARC operator quality assurance |
| **Workforce Management** | Scheduling, forecasting, adherence | Operator scheduling for alarm patterns |
| **Notifications** | Real-time events, webhooks | Alarm push to Genesys, status updates |
| **Analytics** | Reporting, dashboards | ARC performance metrics |

### 1.2 Authentication

Genesys Cloud uses OAuth2 with the following grant types:

| Grant Type | Use Case | Indrajaal Implementation |
|------------|----------|-------------------------|
| Client Credentials | Server-to-server | Primary: Backend integration |
| Authorization Code | User authentication | Agent SSO integration |
| PKCE | Mobile/SPA | Mobile app integration |

```elixir
@type oauth2_config :: %{
  client_id: String.t(),
  client_secret: String.t(),
  region: :mypurecloud_com | :mypurecloud_ie | :mypurecloud_de | :mypurecloud_au | :mypurecloud_jp,
  token_endpoint: String.t(),
  scopes: list(String.t())
}
```

### 1.3 Key API Endpoints

#### Conversations API
```
POST   /api/v2/conversations/calls                    # Create outbound call
POST   /api/v2/conversations/callbacks                # Create callback
GET    /api/v2/conversations/{conversationId}         # Get conversation
PATCH  /api/v2/conversations/{conversationId}         # Update conversation
POST   /api/v2/conversations/{id}/participants/{pid}/replace  # Transfer
```

#### Routing API
```
GET    /api/v2/routing/queues                         # List queues
POST   /api/v2/routing/queues                         # Create queue
GET    /api/v2/routing/queues/{queueId}/members       # Queue members
POST   /api/v2/routing/queues/{queueId}/users         # Add user to queue
GET    /api/v2/routing/skills                         # List skills
```

#### External Contacts API
```
GET    /api/v2/externalcontacts/contacts              # List contacts
POST   /api/v2/externalcontacts/contacts              # Create contact
GET    /api/v2/externalcontacts/contacts/{id}         # Get contact
PUT    /api/v2/externalcontacts/contacts/{id}         # Update contact
DELETE /api/v2/externalcontacts/contacts/{id}         # Delete contact
GET    /api/v2/externalcontacts/organizations         # List orgs
POST   /api/v2/externalcontacts/organizations         # Create org
```

#### Notifications API (WebSocket)
```
wss://notifications.{region}/v2/notifications       # WebSocket endpoint
Topics:
- v2.routing.queues.{queueId}.conversations         # Queue conversations
- v2.users.{userId}.conversations                   # User conversations
- v2.conversations.{conversationId}                 # Conversation updates
```

---

## Part 2: ARC Operations Architecture

### 2.1 EN 50518 ARC Requirements

The European standard EN 50518 (Alarm Receiving Centre) defines requirements that the Indrajaal + Genesys integration must meet:

| Requirement | EN 50518 Reference | Implementation |
|-------------|-------------------|----------------|
| Operator response time | 5.2.2 | < 60 seconds acknowledgment |
| Call recording | 5.3.1 | Genesys Quality Management |
| Backup communications | 5.4 | Dual-path routing |
| Operator training records | 6.2 | Genesys WEM coaching |
| Incident documentation | 7.1 | Immutable Register logging |
| Business continuity | 8 | Multi-region Genesys failover |

### 2.2 Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL + GENESYS CLOUD ARC ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   ALARM SOURCES                    INDRAJAAL PLATFORM                GENESYS CLOUD   │
│   ┌───────────┐                   ┌─────────────────┐              ┌─────────────┐   │
│   │ DC-09     │────────────────▶  │                 │              │             │   │
│   │ Alarm     │                   │   PRAJNA        │   REST API   │  ROUTING    │   │
│   │ Panels    │                   │   AI TRIAGE     │─────────────▶│  ENGINE     │   │
│   ├───────────┤                   │                 │              │             │   │
│   │ Video     │────────────────▶  │ • Severity      │              │ • Queues    │   │
│   │ Analytics │                   │ • False alarm   │   WebSocket  │ • Skills    │   │
│   ├───────────┤                   │ • Context       │◀────────────▶│ • Priority  │   │
│   │ Access    │────────────────▶  │                 │              │             │   │
│   │ Control   │                   │ • Auto-resolve  │              └─────────────┘   │
│   ├───────────┤                   │ • Escalate      │                    │           │
│   │ IoT       │────────────────▶  │                 │                    ▼           │
│   │ Sensors   │                   └─────────────────┘              ┌─────────────┐   │
│   └───────────┘                            │                       │             │   │
│                                            │                       │   AGENT     │   │
│   ┌───────────────────────────────────────────────────────────┐   │   DESKTOP   │   │
│   │                  INDRAJAAL GENESYS BRIDGE                  │   │             │   │
│   │                                                            │   │ • Screen    │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │   Pop       │   │
│   │  │ Alarm       │  │ Contact     │  │ Callback    │        │───▶ • Video     │   │
│   │  │ Escalator   │  │ Sync        │  │ Manager     │        │   │   Feed      │   │
│   │  │             │  │             │  │             │        │   │ • Site Map  │   │
│   │  │ • Priority  │  │ • Sites     │  │ • Schedule  │        │   │ • Actions   │   │
│   │  │ • Queue     │  │ • Subs      │  │ • Retry     │        │   │             │   │
│   │  │ • Context   │  │ • Keys      │  │ • Track     │        │   └─────────────┘   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘        │         │           │
│   │                                                            │         ▼           │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   ┌─────────────┐   │
│   │  │ WFM         │  │ Quality     │  │ Analytics   │        │   │             │   │
│   │  │ Sync        │  │ Sync        │  │ Collector   │        │   │  SUBSCRIBER │   │
│   │  │             │  │             │  │             │        │   │  CHANNELS   │   │
│   │  │ • Forecast  │  │ • Scores    │  │ • KPIs      │        │   │             │   │
│   │  │ • Schedule  │  │ • Coaching  │  │ • Reports   │        │   │ • Voice     │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘        │   │ • SMS       │   │
│   └────────────────────────────────────────────────────────────┘   │ • App       │   │
│                                                                     └─────────────┘   │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Alarm Escalation Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         ALARM → GENESYS ESCALATION FLOW                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│   TIME    ACTION                                              COMPONENT              │
│   ─────   ──────                                              ─────────              │
│                                                                                       │
│   T+0ms   Alarm received (DC-09 BA)                           DC09.Receiver          │
│           ├─ Parse SIA-DCS event code                                                │
│           └─ Log to Immutable Register                                               │
│                                                                                       │
│   T+50ms  AI Triage                                           Prajna.AiCopilot       │
│           ├─ Check history (false alarm rate)                                        │
│           ├─ Analyze video feed (if available)                                       │
│           ├─ Calculate severity score (0-100)                                        │
│           └─ Decision: AUTO_RESOLVE | ESCALATE | PATROL                              │
│                                                                                       │
│   T+100ms If ESCALATE: Create Genesys conversation            Genesys.AlarmEscalator │
│           ├─ POST /api/v2/conversations/calls                                        │
│           ├─ Set priority based on severity                                          │
│           ├─ Add context (site, subscriber, video URL)                               │
│           └─ Route to appropriate queue                                              │
│                                                                                       │
│   T+150ms Queue assignment                                    Genesys Routing        │
│           ├─ Skill-based routing (language, cert level)                              │
│           ├─ Priority routing (P1 > P2 > P3)                                         │
│           └─ Available agent selection                                               │
│                                                                                       │
│   T+200ms Agent receives interaction                          Genesys Agent Desktop  │
│           ├─ Screen pop with alarm context                                           │
│           ├─ Live video feed embedded                                                │
│           ├─ Site map with sensor locations                                          │
│           └─ Action buttons (Verify, Dispatch, Close)                                │
│                                                                                       │
│   T+300ms Agent action                                        Genesys → Indrajaal    │
│           ├─ Data action triggers Indrajaal API                                      │
│           ├─ Response dispatched                                                     │
│           └─ Incident logged to Register                                             │
│                                                                                       │
│   TARGET: Alarm to Agent < 60 seconds (EN 50518 compliant)                           │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 3: Module Design (L3 Component Level)

### 3.1 Supervision Tree

```elixir
defmodule Indrajaal.Genesys.Supervisor do
  @moduledoc """
  Top-level supervisor for Genesys Cloud CX integration.
  Manages all Genesys-related GenServers and connection pools.

  ## Supervision Strategy
  - :one_for_one - Isolate failures
  - Max restarts: 5 in 60 seconds

  ## STAMP Compliance
  - SC-GEN-001: OAuth token refresh < 5 minutes before expiry
  - SC-GEN-002: All API calls logged to Immutable Register
  - SC-GEN-003: Circuit breaker on API failures
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # OAuth2 token management
      {Indrajaal.Genesys.Auth.TokenManager, []},

      # Connection pool for HTTP clients
      {Finch, name: Indrajaal.Genesys.Finch, pools: %{
        "https://api.mypurecloud.com" => [size: 10, count: 2],
        "https://api.mypurecloud.ie" => [size: 10, count: 2],
        "https://api.mypurecloud.de" => [size: 10, count: 2]
      }},

      # WebSocket notification handler
      {Indrajaal.Genesys.Notifications.WebSocketClient, []},

      # Core integration GenServers
      {Supervisor,
        strategy: :one_for_one,
        name: Indrajaal.Genesys.Core.Supervisor,
        children: [
          Indrajaal.Genesys.AlarmEscalator,
          Indrajaal.Genesys.ContactSync,
          Indrajaal.Genesys.CallbackManager,
          Indrajaal.Genesys.ScreenPopBuilder
        ]},

      # Routing management
      {Supervisor,
        strategy: :one_for_one,
        name: Indrajaal.Genesys.Routing.Supervisor,
        children: [
          Indrajaal.Genesys.Routing.QueueManager,
          Indrajaal.Genesys.Routing.SkillManager,
          Indrajaal.Genesys.Routing.PriorityRouter
        ]},

      # Workforce Management sync
      {Supervisor,
        strategy: :one_for_one,
        name: Indrajaal.Genesys.WFM.Supervisor,
        children: [
          Indrajaal.Genesys.WFM.ForecastSync,
          Indrajaal.Genesys.WFM.ScheduleSync,
          Indrajaal.Genesys.WFM.AdherenceMonitor
        ]},

      # Quality Management sync
      {Supervisor,
        strategy: :one_for_one,
        name: Indrajaal.Genesys.Quality.Supervisor,
        children: [
          Indrajaal.Genesys.Quality.EvaluationSync,
          Indrajaal.Genesys.Quality.CoachingSync,
          Indrajaal.Genesys.Quality.RecordingRetriever
        ]},

      # Analytics collector
      Indrajaal.Genesys.Analytics.Collector,

      # Telemetry publisher
      Indrajaal.Genesys.Telemetry
    ]

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end
end
```

### 3.2 AlarmEscalator GenServer

```elixir
defmodule Indrajaal.Genesys.AlarmEscalator do
  @moduledoc """
  Escalates alarms to Genesys Cloud for human operator handling.

  ## Workflow
  1. Receive alarm escalation request from Prajna AI Triage
  2. Build conversation context with site/subscriber data
  3. Create Genesys conversation via API
  4. Monitor conversation until resolution
  5. Log resolution to Immutable Register

  ## STAMP Constraints
  - SC-GEN-010: Escalation API call < 500ms
  - SC-GEN-011: Priority mapping matches alarm severity
  - SC-GEN-012: Context includes video URL if available
  - SC-GEN-013: All escalations logged to Register
  """

  use GenServer
  require Logger

  @escalation_timeout_ms 60_000  # 60 seconds for agent pickup
  @api_timeout_ms 5_000          # 5 seconds API timeout

  @type alarm_context :: %{
    alarm_id: String.t(),
    site_id: String.t(),
    subscriber_id: String.t(),
    event_code: String.t(),
    severity: 1..4,
    description: String.t(),
    video_url: String.t() | nil,
    site_address: String.t(),
    contact_phone: String.t(),
    passcode: String.t() | nil,
    history: list(map())
  }

  @type escalation_result :: %{
    conversation_id: String.t(),
    queue_id: String.t(),
    agent_id: String.t() | nil,
    status: :queued | :connected | :resolved | :abandoned,
    created_at: DateTime.t(),
    resolved_at: DateTime.t() | nil
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec escalate_alarm(alarm_context()) :: {:ok, escalation_result()} | {:error, term()}
  def escalate_alarm(context) do
    GenServer.call(__MODULE__, {:escalate, context}, @escalation_timeout_ms)
  end

  @spec get_escalation_status(String.t()) :: {:ok, escalation_result()} | {:error, :not_found}
  def get_escalation_status(alarm_id) do
    GenServer.call(__MODULE__, {:status, alarm_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      active_escalations: %{},
      escalation_count: 0,
      last_api_latency_ms: 0
    }}
  end

  @impl true
  def handle_call({:escalate, context}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, queue_id} <- select_queue(context),
         {:ok, conversation} <- create_genesys_conversation(context, queue_id),
         :ok <- log_escalation(context, conversation) do

      end_time = System.monotonic_time(:millisecond)
      latency = end_time - start_time

      # Emit telemetry
      :telemetry.execute(
        [:indrajaal, :genesys, :escalation, :created],
        %{latency_ms: latency},
        %{alarm_id: context.alarm_id, queue_id: queue_id}
      )

      result = %{
        conversation_id: conversation["id"],
        queue_id: queue_id,
        agent_id: nil,
        status: :queued,
        created_at: DateTime.utc_now(),
        resolved_at: nil
      }

      new_state = %{state |
        active_escalations: Map.put(state.active_escalations, context.alarm_id, result),
        escalation_count: state.escalation_count + 1,
        last_api_latency_ms: latency
      }

      # Subscribe to conversation updates
      subscribe_to_conversation(conversation["id"])

      {:reply, {:ok, result}, new_state}
    else
      {:error, reason} = error ->
        Logger.error("Alarm escalation failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  # Private functions

  defp select_queue(%{severity: 1}), do: {:ok, queue_id("ARC-P1-Critical")}
  defp select_queue(%{severity: 2}), do: {:ok, queue_id("ARC-P2-High")}
  defp select_queue(%{severity: 3}), do: {:ok, queue_id("ARC-P3-Medium")}
  defp select_queue(%{severity: _}), do: {:ok, queue_id("ARC-P4-Low")}

  defp queue_id(name) do
    # Lookup queue ID from cache or API
    Indrajaal.Genesys.Routing.QueueManager.get_queue_id(name)
  end

  defp create_genesys_conversation(context, queue_id) do
    body = %{
      "queueId" => queue_id,
      "priority" => map_priority(context.severity),
      "languageId" => context[:language_id] || default_language_id(),
      "participants" => [
        %{
          "name" => "Alarm: #{context.event_code}",
          "address" => context.contact_phone,
          "attributes" => build_screen_pop_attributes(context)
        }
      ]
    }

    Indrajaal.Genesys.API.post("/api/v2/conversations/calls", body)
  end

  defp build_screen_pop_attributes(context) do
    %{
      "alarm_id" => context.alarm_id,
      "site_id" => context.site_id,
      "event_code" => context.event_code,
      "severity" => to_string(context.severity),
      "description" => context.description,
      "video_url" => context.video_url || "",
      "site_address" => context.site_address,
      "passcode" => context.passcode || "",
      "indrajaal_url" => build_indrajaal_url(context)
    }
  end

  defp build_indrajaal_url(context) do
    "#{indrajaal_base_url()}/prajna/alarms/#{context.alarm_id}"
  end

  defp map_priority(1), do: 1   # Critical → Highest
  defp map_priority(2), do: 3   # High → High
  defp map_priority(3), do: 5   # Medium → Medium
  defp map_priority(_), do: 10  # Low → Low

  defp log_escalation(context, conversation) do
    Indrajaal.Core.ImmutableRegister.append(%{
      type: :genesys_escalation,
      alarm_id: context.alarm_id,
      conversation_id: conversation["id"],
      queue_id: conversation["queueId"],
      timestamp: DateTime.utc_now()
    })
  end

  defp subscribe_to_conversation(conversation_id) do
    Indrajaal.Genesys.Notifications.WebSocketClient.subscribe(
      "v2.conversations.#{conversation_id}"
    )
  end

  defp indrajaal_base_url do
    Application.get_env(:indrajaal, :base_url, "https://localhost:4000")
  end

  defp default_language_id do
    Application.get_env(:indrajaal, :genesys_default_language, "en-US")
  end
end
```

### 3.3 ContactSync GenServer

```elixir
defmodule Indrajaal.Genesys.ContactSync do
  @moduledoc """
  Synchronizes Indrajaal subscribers and sites with Genesys External Contacts.

  ## Sync Strategy
  - Full sync on startup
  - Incremental sync on subscriber/site changes
  - Bi-directional: Indrajaal → Genesys, Genesys → Indrajaal (notes)

  ## STAMP Constraints
  - SC-GEN-020: Full sync completes < 5 minutes
  - SC-GEN-021: Incremental sync < 500ms per contact
  - SC-GEN-022: Contact data encrypted in transit (TLS 1.3)
  """

  use GenServer
  require Logger

  @full_sync_interval_ms 3_600_000  # 1 hour
  @batch_size 100

  @type contact :: %{
    id: String.t(),
    subscriber_id: String.t(),
    first_name: String.t(),
    last_name: String.t(),
    phone: String.t(),
    email: String.t() | nil,
    organization_id: String.t() | nil,
    sites: list(String.t()),
    custom_fields: map()
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec sync_contact(String.t()) :: :ok | {:error, term()}
  def sync_contact(subscriber_id) do
    GenServer.cast(__MODULE__, {:sync_contact, subscriber_id})
  end

  @spec sync_site_as_organization(String.t()) :: :ok | {:error, term()}
  def sync_site_as_organization(site_id) do
    GenServer.cast(__MODULE__, {:sync_organization, site_id})
  end

  @spec get_genesys_contact_id(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_genesys_contact_id(subscriber_id) do
    GenServer.call(__MODULE__, {:get_contact_id, subscriber_id})
  end

  @impl true
  def init(_opts) do
    # Schedule initial full sync
    Process.send_after(self(), :full_sync, 5_000)

    {:ok, %{
      contact_map: %{},        # subscriber_id => genesys_contact_id
      organization_map: %{},   # site_id => genesys_org_id
      last_full_sync: nil,
      sync_in_progress: false
    }}
  end

  @impl true
  def handle_info(:full_sync, state) do
    Logger.info("Starting Genesys contacts full sync")

    # Schedule next full sync
    Process.send_after(self(), :full_sync, @full_sync_interval_ms)

    # Perform sync in background task
    Task.start(fn -> perform_full_sync() end)

    {:noreply, %{state | sync_in_progress: true}}
  end

  @impl true
  def handle_cast({:sync_contact, subscriber_id}, state) do
    case sync_single_contact(subscriber_id) do
      {:ok, genesys_id} ->
        new_map = Map.put(state.contact_map, subscriber_id, genesys_id)
        {:noreply, %{state | contact_map: new_map}}
      {:error, reason} ->
        Logger.error("Contact sync failed for #{subscriber_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  # Private functions

  defp perform_full_sync do
    # Get all Indrajaal subscribers
    subscribers = Indrajaal.Subscribers.list_all()

    # Sync in batches
    subscribers
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      sync_contact_batch(batch)
      # Rate limiting
      Process.sleep(1_000)
    end)
  end

  defp sync_contact_batch(subscribers) do
    Enum.each(subscribers, fn subscriber ->
      sync_single_contact(subscriber.id)
    end)
  end

  defp sync_single_contact(subscriber_id) do
    with {:ok, subscriber} <- Indrajaal.Subscribers.get(subscriber_id),
         {:ok, genesys_contact} <- upsert_genesys_contact(subscriber) do
      {:ok, genesys_contact["id"]}
    end
  end

  defp upsert_genesys_contact(subscriber) do
    contact_data = %{
      "firstName" => subscriber.first_name,
      "lastName" => subscriber.last_name,
      "workPhone" => %{
        "e164" => subscriber.phone
      },
      "workEmail" => subscriber.email,
      "externalSystemUrl" => "#{indrajaal_base_url()}/subscribers/#{subscriber.id}",
      "customFields" => %{
        "indrajaal_subscriber_id" => subscriber.id,
        "passcode" => subscriber.passcode,
        "service_level" => subscriber.service_level
      }
    }

    # Check if contact exists
    case find_existing_contact(subscriber.id) do
      {:ok, existing} ->
        Indrajaal.Genesys.API.put(
          "/api/v2/externalcontacts/contacts/#{existing["id"]}",
          contact_data
        )
      {:error, :not_found} ->
        Indrajaal.Genesys.API.post(
          "/api/v2/externalcontacts/contacts",
          contact_data
        )
    end
  end

  defp find_existing_contact(subscriber_id) do
    # Search by custom field
    case Indrajaal.Genesys.API.get(
      "/api/v2/externalcontacts/contacts?q=indrajaal_subscriber_id:#{subscriber_id}"
    ) do
      {:ok, %{"entities" => [contact | _]}} -> {:ok, contact}
      {:ok, %{"entities" => []}} -> {:error, :not_found}
      error -> error
    end
  end

  defp indrajaal_base_url do
    Application.get_env(:indrajaal, :base_url, "https://localhost:4000")
  end
end
```

### 3.4 CallbackManager GenServer

```elixir
defmodule Indrajaal.Genesys.CallbackManager do
  @moduledoc """
  Manages scheduled callbacks for subscriber follow-ups and patrol confirmations.

  ## Use Cases
  - Post-alarm subscriber callbacks
  - Patrol confirmation calls
  - Wellness check scheduling
  - Service appointment reminders

  ## STAMP Constraints
  - SC-GEN-030: Callbacks created within 100ms of request
  - SC-GEN-031: Retry failed callbacks up to 3 times
  - SC-GEN-032: Callback status updates via webhook
  """

  use GenServer
  require Logger

  @max_retries 3
  @callback_timeout_hours 24

  @type callback_request :: %{
    subscriber_id: String.t(),
    phone: String.t(),
    queue_id: String.t(),
    scheduled_time: DateTime.t() | nil,
    reason: :post_alarm | :patrol_confirm | :wellness_check | :appointment,
    context: map(),
    priority: 1..10
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec schedule_callback(callback_request()) :: {:ok, String.t()} | {:error, term()}
  def schedule_callback(request) do
    GenServer.call(__MODULE__, {:schedule, request})
  end

  @spec cancel_callback(String.t()) :: :ok | {:error, :not_found}
  def cancel_callback(callback_id) do
    GenServer.call(__MODULE__, {:cancel, callback_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      pending_callbacks: %{},
      callback_history: []
    }}
  end

  @impl true
  def handle_call({:schedule, request}, _from, state) do
    callback_body = %{
      "queueId" => request.queue_id,
      "callbackScheduledTime" => format_scheduled_time(request.scheduled_time),
      "callbackNumbers" => [request.phone],
      "countryCode" => detect_country_code(request.phone),
      "data" => %{
        "subscriber_id" => request.subscriber_id,
        "reason" => Atom.to_string(request.reason),
        "alarm_id" => request.context[:alarm_id],
        "indrajaal_context" => Jason.encode!(request.context)
      },
      "priority" => request.priority
    }

    case Indrajaal.Genesys.API.post("/api/v2/conversations/callbacks", callback_body) do
      {:ok, callback} ->
        new_state = %{state |
          pending_callbacks: Map.put(state.pending_callbacks, callback["id"], request)
        }
        {:reply, {:ok, callback["id"]}, new_state}
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  defp format_scheduled_time(nil), do: nil
  defp format_scheduled_time(dt), do: DateTime.to_iso8601(dt)

  defp detect_country_code(phone) do
    cond do
      String.starts_with?(phone, "+1") -> "US"
      String.starts_with?(phone, "+44") -> "GB"
      String.starts_with?(phone, "+49") -> "DE"
      String.starts_with?(phone, "+91") -> "IN"
      true -> "US"
    end
  end
end
```

---

## Part 4: Workflow Integrations

### 4.1 Alarm Triage → Genesys Escalation

```elixir
defmodule Indrajaal.Workflows.AlarmTriageToGenesys do
  @moduledoc """
  Workflow: Alarm received → AI Triage → Genesys Escalation

  ## Flow
  1. Alarm event received from DC-09/video analytics
  2. Prajna AI performs initial triage
  3. If severity >= threshold, escalate to Genesys
  4. Agent handles alarm, takes action
  5. Resolution logged to Register

  ## STAMP Constraints
  - SC-WORKFLOW-001: Complete flow < 60 seconds
  - SC-WORKFLOW-002: No alarm dropped between components
  - SC-WORKFLOW-003: All state transitions logged
  """

  alias Indrajaal.Alarms.AlarmStore
  alias Indrajaal.Cockpit.Prajna.AiCopilot
  alias Indrajaal.Genesys.AlarmEscalator
  alias Indrajaal.Core.ImmutableRegister

  @escalation_threshold 50  # Severity score 0-100

  @spec process_alarm(map()) :: {:ok, map()} | {:error, term()}
  def process_alarm(alarm_event) do
    with {:ok, alarm} <- AlarmStore.create(alarm_event),
         {:ok, triage} <- AiCopilot.triage_alarm(alarm),
         {:ok, result} <- handle_triage_decision(alarm, triage) do
      {:ok, result}
    end
  end

  defp handle_triage_decision(alarm, %{severity_score: score} = triage)
       when score >= @escalation_threshold do
    # Escalate to Genesys
    context = build_escalation_context(alarm, triage)

    case AlarmEscalator.escalate_alarm(context) do
      {:ok, escalation} ->
        log_escalation_decision(alarm, triage, escalation)
        {:ok, %{action: :escalated, escalation: escalation}}
      {:error, reason} ->
        # Fallback: create internal ticket
        create_fallback_ticket(alarm, triage, reason)
    end
  end

  defp handle_triage_decision(alarm, %{recommendation: :auto_resolve} = triage) do
    # Auto-resolve with logging
    AlarmStore.resolve(alarm.id, :auto_resolved, triage.reason)
    log_auto_resolution(alarm, triage)
    {:ok, %{action: :auto_resolved, reason: triage.reason}}
  end

  defp handle_triage_decision(alarm, %{recommendation: :dispatch_patrol} = triage) do
    # Dispatch patrol and create callback
    dispatch_result = dispatch_patrol(alarm, triage)
    schedule_patrol_callback(alarm, triage)
    {:ok, %{action: :patrol_dispatched, dispatch: dispatch_result}}
  end

  defp build_escalation_context(alarm, triage) do
    site = Indrajaal.Sites.get!(alarm.site_id)
    subscriber = Indrajaal.Subscribers.get!(site.subscriber_id)

    %{
      alarm_id: alarm.id,
      site_id: alarm.site_id,
      subscriber_id: subscriber.id,
      event_code: alarm.event_code,
      severity: calculate_genesys_priority(triage.severity_score),
      description: "#{alarm.event_code}: #{alarm.description}",
      video_url: get_video_url(alarm),
      site_address: format_address(site),
      contact_phone: subscriber.phone,
      passcode: subscriber.passcode,
      history: AlarmStore.get_recent_history(alarm.site_id, 10)
    }
  end

  defp calculate_genesys_priority(score) when score >= 90, do: 1  # Critical
  defp calculate_genesys_priority(score) when score >= 70, do: 2  # High
  defp calculate_genesys_priority(score) when score >= 50, do: 3  # Medium
  defp calculate_genesys_priority(_score), do: 4                  # Low

  defp get_video_url(%{video_clip_id: clip_id}) when not is_nil(clip_id) do
    "#{Application.get_env(:indrajaal, :base_url)}/api/v1/video/clips/#{clip_id}"
  end
  defp get_video_url(_), do: nil

  defp format_address(site) do
    "#{site.address_line1}, #{site.city}, #{site.postal_code}"
  end

  defp log_escalation_decision(alarm, triage, escalation) do
    ImmutableRegister.append(%{
      type: :alarm_escalation_decision,
      alarm_id: alarm.id,
      triage_score: triage.severity_score,
      conversation_id: escalation.conversation_id,
      timestamp: DateTime.utc_now()
    })
  end

  defp log_auto_resolution(alarm, triage) do
    ImmutableRegister.append(%{
      type: :alarm_auto_resolved,
      alarm_id: alarm.id,
      triage_score: triage.severity_score,
      reason: triage.reason,
      timestamp: DateTime.utc_now()
    })
  end

  defp create_fallback_ticket(alarm, triage, reason) do
    # Create internal ticket when Genesys unavailable
    Logger.error("Genesys escalation failed, creating internal ticket: #{inspect(reason)}")
    Indrajaal.Tickets.create(%{
      alarm_id: alarm.id,
      severity: triage.severity_score,
      reason: "Genesys escalation failed: #{inspect(reason)}",
      status: :pending_manual_review
    })
  end

  defp dispatch_patrol(alarm, triage) do
    Indrajaal.Patrol.dispatch(%{
      alarm_id: alarm.id,
      site_id: alarm.site_id,
      priority: calculate_genesys_priority(triage.severity_score),
      instructions: triage.patrol_instructions
    })
  end

  defp schedule_patrol_callback(alarm, _triage) do
    Indrajaal.Genesys.CallbackManager.schedule_callback(%{
      subscriber_id: alarm.subscriber_id,
      phone: alarm.contact_phone,
      queue_id: "ARC-Patrol-Confirmation",
      scheduled_time: DateTime.add(DateTime.utc_now(), 30, :minute),
      reason: :patrol_confirm,
      context: %{alarm_id: alarm.id},
      priority: 5
    })
  end
end
```

### 4.2 Genesys Agent Desktop Data Actions

These data actions allow Genesys agents to interact with Indrajaal directly from the agent desktop:

```yaml
# Genesys Architect Data Actions for Indrajaal

dataActions:
  - name: "Indrajaal - Get Alarm Details"
    category: "Indrajaal Integration"
    requestUrlTemplate: "{{#urlEncode}}/api/v1/alarms/{{input.alarmId}}{{/urlEncode}}"
    requestType: "GET"
    headers:
      Authorization: "Bearer {{integrationCredential.token}}"
    responseMapping:
      translationMap:
        alarmId: "$.id"
        eventCode: "$.event_code"
        severity: "$.severity"
        siteAddress: "$.site.address"
        videoUrl: "$.video_clip_url"
        status: "$.status"

  - name: "Indrajaal - Resolve Alarm"
    category: "Indrajaal Integration"
    requestUrlTemplate: "{{#urlEncode}}/api/v1/alarms/{{input.alarmId}}/resolve{{/urlEncode}}"
    requestType: "POST"
    headers:
      Authorization: "Bearer {{integrationCredential.token}}"
    requestBody: |
      {
        "resolution_type": "{{input.resolutionType}}",
        "resolution_notes": "{{input.notes}}",
        "agent_id": "{{context.userId}}"
      }

  - name: "Indrajaal - Dispatch Patrol"
    category: "Indrajaal Integration"
    requestUrlTemplate: "{{#urlEncode}}/api/v1/patrol/dispatch{{/urlEncode}}"
    requestType: "POST"
    headers:
      Authorization: "Bearer {{integrationCredential.token}}"
    requestBody: |
      {
        "alarm_id": "{{input.alarmId}}",
        "site_id": "{{input.siteId}}",
        "priority": "{{input.priority}}",
        "instructions": "{{input.instructions}}"
      }

  - name: "Indrajaal - Get Site Details"
    category: "Indrajaal Integration"
    requestUrlTemplate: "{{#urlEncode}}/api/v1/sites/{{input.siteId}}{{/urlEncode}}"
    requestType: "GET"
    headers:
      Authorization: "Bearer {{integrationCredential.token}}"
    responseMapping:
      translationMap:
        siteId: "$.id"
        siteName: "$.name"
        address: "$.full_address"
        subscriberName: "$.subscriber.name"
        subscriberPhone: "$.subscriber.phone"
        passcode: "$.subscriber.passcode"
        devices: "$.devices"

  - name: "Indrajaal - Get Live Video URL"
    category: "Indrajaal Integration"
    requestUrlTemplate: "{{#urlEncode}}/api/v1/video/live/{{input.cameraId}}{{/urlEncode}}"
    requestType: "GET"
    headers:
      Authorization: "Bearer {{integrationCredential.token}}"
    responseMapping:
      translationMap:
        streamUrl: "$.hls_url"
        rtspUrl: "$.rtsp_url"
        thumbnail: "$.thumbnail_url"
```

### 4.3 Genesys Queue Configuration

```yaml
# Genesys Routing Queues for ARC Operations

queues:
  - name: "ARC-P1-Critical"
    description: "Critical priority alarms (Fire, Panic, Holdup)"
    priority: 1
    serviceLevelTarget: 15  # seconds
    serviceLevelPercentage: 95
    skills:
      - ARC-Certified
      - Critical-Handling
    wrapupTime: 60

  - name: "ARC-P2-High"
    description: "High priority alarms (Burglary, Intrusion)"
    priority: 3
    serviceLevelTarget: 30
    serviceLevelPercentage: 90
    skills:
      - ARC-Certified
    wrapupTime: 45

  - name: "ARC-P3-Medium"
    description: "Medium priority alarms (Supervision, Tamper)"
    priority: 5
    serviceLevelTarget: 60
    serviceLevelPercentage: 85
    skills:
      - ARC-Basic
    wrapupTime: 30

  - name: "ARC-P4-Low"
    description: "Low priority events (Test, Maintenance)"
    priority: 10
    serviceLevelTarget: 120
    serviceLevelPercentage: 80
    skills:
      - ARC-Basic
    wrapupTime: 30

  - name: "ARC-Patrol-Confirmation"
    description: "Outbound patrol confirmation callbacks"
    priority: 5
    skills:
      - ARC-Basic
      - Outbound-Calling
    wrapupTime: 30

  - name: "ARC-Subscriber-Support"
    description: "General subscriber inquiries"
    priority: 8
    skills:
      - Customer-Service
    wrapupTime: 60
```

---

## Part 5: STAMP Constraints

### 5.1 Genesys Integration Constraints (SC-GEN)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-GEN-001 | OAuth token refresh < 5 min before expiry | CRITICAL | OAuth2 |
| SC-GEN-002 | All API calls logged to Immutable Register | CRITICAL | Audit |
| SC-GEN-003 | Circuit breaker on 3 consecutive API failures | HIGH | Resilience |
| SC-GEN-004 | API latency < 500ms P95 | HIGH | Performance |
| SC-GEN-005 | WebSocket reconnection < 5 seconds | CRITICAL | Real-time |
| SC-GEN-010 | Escalation API call < 500ms | CRITICAL | SLA |
| SC-GEN-011 | Priority mapping matches alarm severity | HIGH | Correctness |
| SC-GEN-012 | Screen pop context includes video URL | MEDIUM | UX |
| SC-GEN-013 | All escalations logged to Register | CRITICAL | Audit |
| SC-GEN-020 | Full contact sync < 5 minutes | MEDIUM | Efficiency |
| SC-GEN-021 | Incremental contact sync < 500ms | HIGH | Real-time |
| SC-GEN-022 | Contact data encrypted in transit | CRITICAL | Security |
| SC-GEN-030 | Callbacks created < 100ms | HIGH | SLA |
| SC-GEN-031 | Retry failed callbacks 3 times | MEDIUM | Reliability |
| SC-GEN-032 | Callback status via webhook | HIGH | Real-time |

### 5.2 ARC Operations Constraints (SC-ARC)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-ARC-001 | Agent pickup < 60 seconds | CRITICAL | EN 50518 |
| SC-ARC-002 | All calls recorded | CRITICAL | EN 50518 |
| SC-ARC-003 | Dual communication paths | CRITICAL | EN 50518 |
| SC-ARC-004 | Agent authentication mandatory | CRITICAL | EN 50518 |
| SC-ARC-005 | Incident documentation complete | HIGH | EN 50518 |
| SC-ARC-006 | Training records maintained | HIGH | EN 50518 |
| SC-ARC-007 | Business continuity tested quarterly | MEDIUM | EN 50518 |

### 5.3 CTI Integration Constraints (SC-CTI)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-CTI-001 | Screen pop within 200ms of answer | HIGH | UX |
| SC-CTI-002 | Context data accurate and current | CRITICAL | Operations |
| SC-CTI-003 | Video embed loads < 2 seconds | MEDIUM | UX |
| SC-CTI-004 | Click-to-action response < 100ms | HIGH | UX |
| SC-CTI-005 | Transfer preserves context | CRITICAL | Operations |

### 5.4 Workforce Management Constraints (SC-WFM)

| ID | Constraint | Severity | Compliance |
|----|------------|----------|------------|
| SC-WFM-001 | Forecast sync every 15 minutes | MEDIUM | Planning |
| SC-WFM-002 | Schedule changes reflected < 5 min | HIGH | Operations |
| SC-WFM-003 | Adherence data real-time | HIGH | Monitoring |
| SC-WFM-004 | Alarm pattern integrated in forecast | MEDIUM | Accuracy |

---

## Part 6: Implementation Roadmap

### 6.1 Phase Overview

| Phase | Duration | Focus | Deliverables |
|-------|----------|-------|--------------|
| 1 | Weeks 1-4 | Foundation | OAuth, API client, basic escalation |
| 2 | Weeks 5-8 | Contact Sync | External contacts, organizations |
| 3 | Weeks 9-12 | Routing | Queues, skills, priority routing |
| 4 | Weeks 13-16 | Agent Desktop | Screen pop, data actions, video embed |
| 5 | Weeks 17-20 | WFM/Quality | Scheduling, evaluations, coaching |
| 6 | Weeks 21-24 | Analytics | Dashboards, reports, KPIs |

### 6.2 Detailed Task Breakdown

#### Phase 1: Foundation (Weeks 1-4)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G1.1 | Implement TokenManager GenServer | 3 days | SC-GEN-001 |
| G1.2 | Implement Genesys API client module | 5 days | SC-GEN-004 |
| G1.3 | Implement WebSocket notification client | 4 days | SC-GEN-005 |
| G1.4 | Implement AlarmEscalator GenServer | 5 days | SC-GEN-010-013 |
| G1.5 | Integration tests with Genesys sandbox | 3 days | All |

#### Phase 2: Contact Sync (Weeks 5-8)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G2.1 | Implement ContactSync GenServer | 4 days | SC-GEN-020-022 |
| G2.2 | Organization sync for sites | 3 days | SC-GEN-021 |
| G2.3 | Bi-directional note sync | 3 days | SC-GEN-022 |
| G2.4 | Custom field mapping | 2 days | - |
| G2.5 | Full/incremental sync scheduling | 3 days | SC-GEN-020 |

#### Phase 3: Routing (Weeks 9-12)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G3.1 | Queue configuration (6 queues) | 3 days | SC-ARC-001 |
| G3.2 | Skill definitions and mapping | 2 days | - |
| G3.3 | Priority routing logic | 4 days | SC-GEN-011 |
| G3.4 | Callback queue setup | 2 days | SC-GEN-030 |
| G3.5 | Routing rules in Architect | 4 days | - |

#### Phase 4: Agent Desktop (Weeks 13-16)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G4.1 | Screen pop builder | 4 days | SC-CTI-001 |
| G4.2 | Data actions (5 actions) | 5 days | SC-CTI-002-004 |
| G4.3 | Video embed widget | 4 days | SC-CTI-003 |
| G4.4 | Transfer with context | 3 days | SC-CTI-005 |
| G4.5 | Agent scripts for alarm handling | 4 days | - |

#### Phase 5: WFM/Quality (Weeks 17-20)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G5.1 | Forecast sync module | 4 days | SC-WFM-001 |
| G5.2 | Schedule sync module | 4 days | SC-WFM-002 |
| G5.3 | Adherence monitoring | 3 days | SC-WFM-003 |
| G5.4 | Evaluation form integration | 4 days | SC-ARC-002 |
| G5.5 | Coaching appointment sync | 2 days | SC-ARC-006 |

#### Phase 6: Analytics (Weeks 21-24)

| Task ID | Task | Duration | STAMP |
|---------|------|----------|-------|
| G6.1 | Analytics collector GenServer | 3 days | - |
| G6.2 | Prajna dashboard integration | 4 days | - |
| G6.3 | ARC KPI calculations | 3 days | SC-ARC-001 |
| G6.4 | Service level reporting | 3 days | - |
| G6.5 | EN 50518 compliance reports | 4 days | SC-ARC-* |

---

## Part 7: Module Inventory

### 7.1 GenServer Summary

| Module | Purpose | STAMP Constraints |
|--------|---------|-------------------|
| Genesys.Auth.TokenManager | OAuth2 token lifecycle | SC-GEN-001 |
| Genesys.Notifications.WebSocketClient | Real-time events | SC-GEN-005 |
| Genesys.AlarmEscalator | Alarm → Genesys routing | SC-GEN-010-013 |
| Genesys.ContactSync | Subscriber ↔ ExternalContact | SC-GEN-020-022 |
| Genesys.CallbackManager | Scheduled callbacks | SC-GEN-030-032 |
| Genesys.ScreenPopBuilder | Agent context builder | SC-CTI-001-002 |
| Genesys.Routing.QueueManager | Queue CRUD operations | - |
| Genesys.Routing.SkillManager | Skill CRUD operations | - |
| Genesys.Routing.PriorityRouter | Priority calculations | SC-GEN-011 |
| Genesys.WFM.ForecastSync | Forecast data sync | SC-WFM-001 |
| Genesys.WFM.ScheduleSync | Schedule data sync | SC-WFM-002 |
| Genesys.WFM.AdherenceMonitor | Real-time adherence | SC-WFM-003 |
| Genesys.Quality.EvaluationSync | Evaluation sync | SC-ARC-002 |
| Genesys.Quality.CoachingSync | Coaching appointments | SC-ARC-006 |
| Genesys.Quality.RecordingRetriever | Call recordings | SC-ARC-002 |
| Genesys.Analytics.Collector | KPI collection | - |
| Genesys.Telemetry | Observability | - |
| **TOTAL** | **17 GenServers** | |

### 7.2 Function Count

| Category | Functions | STAMP Coverage |
|----------|-----------|----------------|
| Authentication | 8 | SC-GEN-001 |
| API Client | 15 | SC-GEN-002-004 |
| Notifications | 10 | SC-GEN-005 |
| Escalation | 12 | SC-GEN-010-013 |
| Contacts | 14 | SC-GEN-020-022 |
| Callbacks | 8 | SC-GEN-030-032 |
| Routing | 18 | - |
| WFM | 15 | SC-WFM-* |
| Quality | 12 | SC-ARC-002,006 |
| Analytics | 10 | - |
| **TOTAL** | **122 functions** | |

---

## Part 8: Success Metrics

### 8.1 Technical KPIs

| Metric | Target | Measurement |
|--------|--------|-------------|
| Escalation latency | < 500ms | API timer |
| Agent pickup time | < 60s | Genesys SLA |
| Screen pop latency | < 200ms | CTI timer |
| API availability | 99.9% | Health checks |
| WebSocket uptime | 99.9% | Connection monitor |
| Contact sync delay | < 500ms | Sync timer |

### 8.2 Business KPIs

| Metric | Target | Baseline |
|--------|--------|----------|
| First call resolution | 85% | N/A |
| Average handle time | < 3 min | N/A |
| Service level (60s) | 95% | N/A |
| Agent utilization | 70% | N/A |
| False alarm reduction | 30% | Pre-AI triage |

---

## Appendix A: Genesys API Reference Links

| Resource | URL |
|----------|-----|
| Developer Center | https://developer.genesys.cloud/ |
| API Explorer | https://developer.genesys.cloud/devapps/api-explorer |
| Conversations API | https://developer.genesys.cloud/api/rest/v2/conversations/overview |
| External Contacts | https://developer.genesys.cloud/commdigital/externalcontacts/externalcontacts-apis |
| Callbacks Guide | https://developer.genesys.cloud/routing/conversations/callbacks-guide |
| Routing APIs | https://developer.genesys.cloud/routing/routing/ |
| Webhooks | https://developer.genesys.cloud/platform/webhooks/ |
| Data Actions | https://help.mypurecloud.com/articles/how-the-data-actions-integration-works/ |
| WFM | https://help.mypurecloud.com/articles/about-workforce-management/ |
| Quality Management | https://help.mypurecloud.com/articles/about-quality-management/ |

---

**Document Status**: DESIGN APPROVED
**Next Steps**: Add to implementation roadmap, create detailed technical specifications
**Owner**: Claude Opus 4.5

---

*Generated: 2026-01-03T20:00:00+01:00*
*Compliance: EN 50518, NSI/ANSI, BS 5979, ISO 27001*
