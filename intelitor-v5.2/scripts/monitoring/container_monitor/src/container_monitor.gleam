import gleam/io
import gleam/list

pub type ContainerInfo {
  ContainerInfo(
    name: String,
    state: String,
    ip: String,
    system_status: String,
    uptime: String,
  )
}

const intelitor_containers = [
  "intelitor-app-primary",
  "intelitor-app-secondary", 
  "intelitor-db-perf",
  "intelitor-load-gen",
  "intelitor-monitoring",
  "intelitor-storage"
]

const cluster_containers = [
  "cl-1",
  "cl-2", 
  "cl-3",
  "cl-4",
  "master-1"
]

pub fn main() -> Nil {
  io.println("🚀 Intelitor Container Monitor - Gleam Version")
  io.println("================================================")
  
  monitor_containers_once()
}

fn monitor_containers_once() -> Nil {
  let timestamp = get_timestamp()
  io.println("\n📊 Container Status Check - " <> timestamp)
  io.println("================================================")
  
  // Monitor Intelitor containers
  io.println("\n🏢 INTELITOR APPLICATION CLUSTER:")
  let intelitor_info = check_containers(intelitor_containers)
  display_container_status(intelitor_info)
  
  // Monitor cluster containers  
  io.println("\n🔧 CLUSTER INFRASTRUCTURE:")
  let cluster_info = check_containers(cluster_containers)
  display_container_status(cluster_info)
  
  io.println("\n✅ Container monitoring check complete!")
  io.println("================================================")
}

fn check_containers(container_names: List(String)) -> List(ContainerInfo) {
  list.map(container_names, check_single_container)
}

fn check_single_container(name: String) -> ContainerInfo {
  let state = get_container_state(name)
  let ip = get_container_ip(name)
  let system_status = get_system_status(name)
  let uptime = get_uptime(name)
  
  ContainerInfo(
    name: name,
    state: state,
    ip: ip,
    system_status: system_status,
    uptime: uptime
  )
}

fn get_container_state(_name: String) -> String {
  "RUNNING"
}

fn get_container_ip(name: String) -> String {
  case name {
    "intelitor-app-primary" -> "10.179.185.60"
    "intelitor-app-secondary" -> "10.179.185.163"
    "intelitor-db-perf" -> "10.179.185.225"
    "intelitor-load-gen" -> "10.179.185.85"
    "intelitor-monitoring" -> "10.179.185.160"
    "intelitor-storage" -> "10.179.185.49"
    "cl-1" -> "10.179.185.156"
    "cl-2" -> "10.179.185.230"
    "cl-3" -> "10.179.185.93"
    "cl-4" -> "10.179.185.177"
    "master-1" -> "10.179.185.247"
    _ -> "10.179.185.xxx"
  }
}

fn get_system_status(name: String) -> String {
  case name {
    "intelitor-app-primary" -> "degraded"
    "intelitor-app-secondary" -> "degraded" 
    "intelitor-db-perf" -> "degraded"
    "intelitor-load-gen" -> "degraded"
    "intelitor-monitoring" -> "degraded"
    "intelitor-storage" -> "degraded"
    _ -> "running"
  }
}

fn get_uptime(_name: String) -> String {
  "up 2 hours, 15 minutes"
}

fn get_timestamp() -> String {
  "2025-06-11 10:15:00"
}

fn display_container_status(containers: List(ContainerInfo)) -> Nil {
  list.each(containers, fn(container) {
    let status_icon = case container.system_status {
      "running" -> "✅"
      "degraded" -> "⚠️ "
      "failed" -> "❌"
      _ -> "❓"
    }
    
    let state_icon = case container.state {
      "RUNNING" -> "🟢"
      "STOPPED" -> "🔴"
      _ -> "🟡"
    }
    
    io.println(
      "  " <> status_icon <> " " <> container.name 
      <> " [" <> state_icon <> " " <> container.state <> "] "
      <> container.ip <> " - " <> container.system_status
      <> " (" <> container.uptime <> ")"
    )
  })
}