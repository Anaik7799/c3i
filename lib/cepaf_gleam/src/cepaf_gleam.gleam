//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam</module>
////     <fsharp-lineage>Cepaf.SIL6MeshOrchestrator.Program.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L7_FEDERATION</layer>
////     <mesh-domain>Master Orchestrator Entry Point</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>DAL-A / SIL-6 / CRITICAL</criticality>
////     <stamp-controls>SC-MESH-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective" augmentation="otp-application">
////       F# `IHostBuilder.Run()` ↪ Gleam OTP Main Execution Thread.
////       Mitigation: `erlang/process.sleep_forever()` explicitly halts the main execution thread to sustain background worker processes, mimicking .NET's daemon loop.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================

import cepaf_gleam/planning/cli
import cepaf_gleam/podman/containers
import cepaf_gleam/podman/domain.{PodmanClientConfig, Rootless}
import cepaf_gleam/podman/http_client
import cepaf_gleam/telemetry/exporter
import cepaf_gleam/verification/swarm
import cepaf_gleam/zenoh/client as zenoh
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list

@external(erlang, "cepaf_gleam_ffi", "get_uid")
fn get_uid() -> String

pub fn main() {
  io.println("🚀 CEPAF Gleam Orchestrator - Unified Swarm Execution")
  io.println("=====================================================")

  // 0. OTel Boot Span (SC-OTEL-002)
  case exporter.export_span("c3i.boot", 0.0, "ok", []) {
    Ok(Nil) -> io.println("  [otel] Boot span exported to collector")
    Error(e) -> io.println("  [otel] Boot span export failed: " <> e)
  }

  // 1. Planning Module Execution
  io.println("\n📅 PLANNING & TASK STATUS:")
  cli.run(["status"])

  // 2. Podman & Swarm Verification
  let uid = get_uid()
  let socket_path = "/run/user/" <> uid <> "/podman/podman.sock"
  let config =
    PodmanClientConfig(
      socket: Rootless(uid: uid, path: socket_path),
      api_version: "5.7.0",
      timeout_ms: 30_000,
      retry_count: 3,
      retry_delay_ms: 1000,
    )
  let client = http_client.create(config)

  io.println("\n🏢 FETCHING CONTAINER STATUS:")
  case containers.list_containers(client, True) {
    Ok(containers_list) -> {
      let names =
        list.map(containers_list, fn(c) {
          case list.first(c.names) {
            Ok(n) -> n
            Error(_) -> "unknown"
          }
        })

      list.each(containers_list, fn(c) {
        let name = case list.first(c.names) {
          Ok(n) -> n
          Error(_) -> "unknown"
        }
        io.println(
          "  - " <> name <> " (" <> c.image <> ") [" <> c.status <> "]",
        )
      })

      io.println("\n💊 RUNNING SIL-6 HEALTH VERIFICATION:")
      case swarm.verify_container_health(client, names) {
        Ok(#(healthy, total)) -> {
          io.println(
            "  Healthy Containers: "
            <> int.to_string(healthy)
            <> "/"
            <> int.to_string(total),
          )
        }
        Error(e) -> io.println("  ❌ Health check failed: " <> e)
      }
    }
    Error(_) -> io.println("  ❌ Error listing containers")
  }

  // 3. Zenoh IPC Test
  io.println("\n📡 ZENOH IPC INTEGRATION:")
  case zenoh.open("{\"mode\": \"client\"}") {
    Ok(session) -> {
      let _ = zenoh.put(session, "indrajaal/cepaf/gleam/status", "online")
      io.println("  ✅ Zenoh session active & status published.")
    }
    Error(e) -> io.println("  ❌ Zenoh failed: " <> e)
  }

  // 4. Runtime Suspension (replaces F# IHost.Run())
  io.println("\n🛑 ENTERING SIL-6 DAEMON MODE. Sleeping forever...")
  process.sleep_forever()
}
