# Zenoh Integration Analysis for Indrajaal System

**Date:** 2025-12-19
**Status:** DRAFT
**Context:** Integration of Eclipse Zenoh with Indrajaal (Elixir/Phoenix) and Flutter Mobile Apps.

## 1. Executive Summary

Eclipse Zenoh is a high-performance, low-latency, geo-distributed pub/sub/query protocol. Integrating Zenoh into the Indrajaal ecosystem offers significant advantages for **Edge Computing**, **Inter-Service Communication**, and **High-Frequency Telemetry**, complementing the existing Phoenix/Ash architecture.

The recommended approach is a **Hybrid Core-Satellite Architecture** where Zenoh acts as the unified Data Plane for high-volume telemetry and inter-service data, while Phoenix Channels remain the Control Plane for user-facing interactions and authentication during the transition phase.

## 2. Current System Architecture vs. Zenoh Fit

### Current State
*   **Backend:** Elixir 1.19+, Phoenix 1.7+, Ash Framework.
*   **Real-time:** Phoenix Channels (`IndrajaalWeb.Endpoint`) handling `alarm:*`, `device:*`, `site:*`.
*   **Mobile:** Flutter application consuming Phoenix Channels via WebSocket.
*   **Compute:** FLAME for elastic compute, standard Erlang Distribution for clustering.

### The Zenoh Gap
While Phoenix Channels are excellent for web/mobile clients, they are:
1.  **Hub-and-Spoke:** All traffic routes through the Phoenix server.
2.  **TCP/WebSocket based:** Can be heavy for constrained edge devices.
3.  **BEAM-Centric:** Harder to integrate high-performance Rust/C++ sensors or Python AI inference engines directly without HTTP overhead.

**Zenoh** fills this gap by providing:
*   **Peer-to-Peer & Brokerless:** Devices can talk directly or via lightweight routers.
*   **Wire Efficiency:** Extremely low overhead (5 bytes min wire overhead).
*   **Unified Abstraction:** Pub/Sub (Data in Motion) and Query (Data at Rest) in one API.

## 3. Backend Integration (Elixir/NixOS)

### 3.1 Library: Zenohex
The `zenohex` library (based on Rustler) provides native Elixir bindings to the Zenoh Rust crate.

*   **Dependency:** `{:zenohex, "~> 0.7.1"}`
*   **Compatibility:** Matches Zenoh 1.0.0+ protocol.

### 3.2 Architectural Pattern: The "Zenoh Bridge" GenServer
We should introduce a `Indrajaal.Zenoh.Bridge` GenServer to the application supervision tree. This actor will:
1.  Initialize a Zenoh Session (Peer or Client mode).
2.  Declare Subscribers for key prefixes (e.g., `indrajaal/**`).
3.  **Bridge Strategy:** Ingress Zenoh messages -> Broadcast to Phoenix PubSub.

```elixir
# Conceptual Implementation
defmodule Indrajaal.Zenoh.Bridge do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Open Zenoh Session
    {:ok, session} = Zenohex.open()
    
    # Declare Subscriber
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "indrajaal/**", &handle_zenoh_message/1)
    
    Logger.info("Zenoh Bridge Started on 'indrajaal/**'")
    {:ok, %{session: session, subscriber: subscriber}}
  end

  defp handle_zenoh_message(sample) do
    # Convert Zenoh Key to Phoenix Topic
    # indrajaal/site/123/alarm -> site:123
    topic = convert_key_to_topic(sample.key_expr)
    
    # Broadcast to existing Phoenix Channels (Legacy Support)
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, {:zenoh_data, sample.payload})
  end
end
```

## 4. Frontend Integration (Flutter)

### 4.1 Library: zenoh_dart
The `zenoh_dart` package provides FFI bindings to `zenoh-c`.

*   **Platform Support:** Windows, Linux, macOS (Stable). Android/iOS (Experimental/Work-in-Progress).
*   **Challenge:** Shipping the native `libzenohc.so` / `libzenohc.dylib` with the Flutter app requires configuring the build system (Gradle/CMake/CocoaPods) to include these binaries.

### 4.2 Architectural Pattern: Direct Data, Legacy Control
The Flutter app should evolve into a dual-connection client:
1.  **Phoenix WebSocket:** Maintains Authentication, Presence, and RPC calls (Control Plane).
2.  **Zenoh Session:** Subscribes to high-frequency data topics (Data Plane).

```dart
// Conceptual Dart Implementation
import 'package:zenoh_dart/zenoh_dart.dart';

void startZenoh() async {
  // Initialize Config
  var config = Config();
  
  // Open Session (Client Mode - connects to Router/Peer)
  var session = z_open(config);
  
  // Declare Subscriber
  var sub = z_declare_subscriber(session, 'indrajaal/site/+/alarm', (sample) {
    print("Received Alarm via Zenoh: ${sample.payload}");
    // Update UI State
  });
}
```

## 5. Integration Roadmap

### Phase 1: The "Invisible" Bridge (Backend Only)
*   **Goal:** Enable external Zenoh writers (e.g., Rust sensors, Python AI) to feed the current Flutter app.
*   **Action:** Implement `Indrajaal.Zenoh.Bridge` in Elixir.
*   **Benefit:** Zero change to Flutter app. Allows immediate integration of non-BEAM edge devices.

### Phase 2: Hybrid Mobile Client
*   **Goal:** High-frequency data on Mobile.
*   **Action:** Add `zenoh_dart` to Flutter.
*   **Constraint:** Use Zenoh only for read-only telemetry streams initially to avoid write-conflict complexity.
*   **Benefit:** Lower latency for video metadata, sensor graphs, and map tracking.

### Phase 3: Edge Mesh (Advanced)
*   **Goal:** Offline/Local capabilities.
*   **Action:** If Mobile and Edge Device are on same WiFi, Zenoh discovers local peer automatically. Data flows device-to-mobile without cloud roundtrip.
*   **Benefit:** Zero-latency local control; resilience to internet outages.

## 6. Recommendations & Risks

### Risks
1.  **Flutter FFI Complexity:** Cross-compiling Rust/C for iOS/Android is non-trivial. Expect build pipeline friction.
2.  **Security Model:** Zenoh has its own Access Control (Access Control Rules). This must be synchronized with Ash/Phoenix authorization or handled via a strict Gateway.
3.  **Data Duplication:** Bridging all data to Phoenix PubSub doubles serialization cost. Filter carefully.

### Recommendations
1.  Start with **Phase 1** immediately. It is low risk and high value (enables Python/Rust integration).
2.  Use **Zenoh Router** (standalone) as the infrastructure hub, rather than embedding the router *inside* the Elixir app. Let Elixir be a Peer/Client.
3.  Adopt a **Key Mapping Standard**: Define a strict mapping between Ash Resources and Zenoh Keys (e.g., `Domain/Resource/ID/Attribute`).
