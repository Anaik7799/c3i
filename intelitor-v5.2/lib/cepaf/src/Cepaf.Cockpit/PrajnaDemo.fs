namespace Cepaf.Cockpit

open System
open System.Threading
open Cepaf.Cockpit.Prajna
open Cepaf.Cockpit.Prajna.Bio
open Cepaf.Cockpit.Prajna.Immune
open Cepaf.Cockpit.Prajna.Neuro
open Cepaf.Cockpit.Prajna.DarkCockpit
open Cepaf.Cockpit.Prajna.CircuitBreaker
open Cepaf.Cockpit.Prajna.SmartMetrics
open Cepaf.Cockpit.Prajna.Orchestrator
open Cepaf.Cockpit.Domain

module PrajnaDemo =

    let run () =
        DarkCockpitUI.initialize ()
        
        let mutable state = Domain.createCockpitState("operator")
        let mutable running = true
        let mutable lastUpdate = DateTime.UtcNow
        
        // Simulation state
        let mutable metricsHistory = [75.0; 76.0; 74.0]
        
        // Command state
        let mutable pendingCommand: Orchestrator.Command option = None

        while running do
            // 1. Handle Input
            if Console.KeyAvailable then
                let key = Console.ReadKey(true)
                match key.KeyChar with
                | 'q' -> running <- false
                | '?' -> state <- { state with ShowHelp = not state.ShowHelp }
                | 'v' -> 
                    // Simulate mode change by changing view
                    let nextView = 
                        match state.CurrentView with
                        | ViewMode.Overview -> ViewMode.Mesh
                        | ViewMode.Mesh -> ViewMode.Federation
                        | ViewMode.Federation -> ViewMode.Economics
                        | ViewMode.Economics -> ViewMode.Alarms
                        | ViewMode.Alarms -> ViewMode.Overview
                        | _ -> ViewMode.Overview
                    state <- { state with CurrentView = nextView }
                | 'r' ->
                    // Refresh data
                    state <- { state with MessagesReceived = state.MessagesReceived + 1 }
                | 'a' -> // Arm command
                    if pendingCommand.IsNone then
                        let cmd = Orchestrator.createCommand Orchestrator.CommandType.Restart "operator" "indrajaal-app"
                        let armed = Orchestrator.arm cmd
                        pendingCommand <- Some armed
                        
                        // Add alarm for feedback
                        let alarm = {
                            Id = Domain.generateId()
                            NodeId = "indrajaal-app"
                            Level = Domain.AlarmLevel.Advisory
                            Category = "COMMAND"
                            Message = sprintf "Restart armed by %s" armed.IssuedBy
                            Details = None
                            OccurredAt = DateTime.UtcNow
                            AcknowledgedAt = None
                            AcknowledgedBy = None
                            AutoClearable = true
                        }
                        state <- { state with Alarms = Map.add alarm.Id alarm state.Alarms }
                | 'c' -> // Confirm command
                    match pendingCommand with
                    | Some cmd when cmd.Status = Orchestrator.CommandStatus.Armed ->
                        let confirmed = Orchestrator.confirm cmd (Some "supervisor")
                        let _completed = Orchestrator.complete confirmed true "Executed successfully"
                        pendingCommand <- None
                        
                        let alarm = {
                            Id = Domain.generateId()
                            NodeId = "indrajaal-app"
                            Level = Domain.AlarmLevel.Normal
                            Category = "COMMAND"
                            Message = "Restart completed"
                            Details = None
                            OccurredAt = DateTime.UtcNow
                            AcknowledgedAt = Some DateTime.UtcNow
                            AcknowledgedBy = Some "system"
                            AutoClearable = true
                        }
                        state <- { state with Alarms = Map.add alarm.Id alarm state.Alarms }
                    | _ -> ()
                | 'x' -> // Cancel command
                    pendingCommand <- None
                | _ -> ()

            // 2. Simulate System Updates
            if (DateTime.UtcNow - lastUpdate).TotalMilliseconds > 500.0 then
                // Randomly fluctuate metrics
                let currentMetric = 75.0 + (Random().NextDouble() * 10.0 - 5.0)
                metricsHistory <- (currentMetric :: metricsHistory) |> List.take (min 20 (List.length metricsHistory + 1))
                
                // Detect anomalies
                let anomaly = SmartMetrics.detectAnomaly metricsHistory currentMetric 2.0
                if anomaly.IsAnomaly then
                    let alarm = {
                        Id = Domain.generateId()
                        NodeId = "SmartMetrics"
                        Level = Domain.AlarmLevel.Warning
                        Category = "ANOMALY"
                        Message = anomaly.Message
                        Details = None
                        OccurredAt = DateTime.UtcNow
                        AcknowledgedAt = None
                        AcknowledgedBy = None
                        AutoClearable = true
                    }
                    state <- { state with Alarms = Map.add alarm.Id alarm state.Alarms }
                    
                    // Decrease trust for relevant peers on anomaly (Simulation)
                    match state.Federation with
                    | Some fed ->
                        let updatedMembers = 
                            fed.Members 
                            |> Map.map (fun id m -> 
                                if id = "peer-3" then { m with TrustScore = max 0.0 (m.TrustScore - 0.05) }
                                else m)
                        state <- { state with Federation = Some { fed with Members = updatedMembers } }
                    | None -> ()

                // Update metrics in nodes
                let updatedNodes = 
                    state.Nodes 
                    |> Map.map (fun _ node -> 
                        { node with 
                            Cpu = Domain.updateMetric node.Cpu (70.0 + Random().NextDouble() * 20.0)
                            HealthScore = Domain.updateMetric node.HealthScore (90.0 + Random().NextDouble() * 10.0)
                        })
                
                // Update federation health simulation
                let fedHealth = {
                    LocalHolonId = "holon-primary"
                    TotalMembers = 3
                    ActiveMembers = 2
                    AverageTrust = 0.85
                    ProtocolVersion = "1.0.0"
                    Members = 
                        [ "peer-1", { Id = "peer-1"; Name = "Edge-Node-01"; Status = "Active"; TrustScore = 0.95; LastSeen = DateTime.UtcNow; Version = "1.0.0"; Capabilities = ["compute"; "storage"] }
                          "peer-2", { Id = "peer-2"; Name = "Cloud-Relay"; Status = "Active"; TrustScore = 0.88; LastSeen = DateTime.UtcNow; Version = "1.0.0"; Capabilities = ["bridge"] }
                          "peer-3", { Id = "peer-3"; Name = "Unknown-Holon"; Status = "Pending"; TrustScore = 0.50; LastSeen = DateTime.UtcNow; Version = "0.9.0"; Capabilities = [] } ]
                        |> Map.ofList
                }
                
                // Update economics simulation
                let econLedger = {
                    TotalSwarmEnergy = 15420.5
                    SystemCredits = 845.2
                    EfficiencyScore = 0.94
                    Ledger = 
                        [ "cortex", { HolonId = "cortex"; Balance = 850.0; TotalConsumed = 150.0; LastMeteredAt = DateTime.UtcNow }
                          "sentinel", { HolonId = "sentinel"; Balance = 920.0; TotalConsumed = 80.0; LastMeteredAt = DateTime.UtcNow }
                          "app-1", { HolonId = "app-1"; Balance = 450.0; TotalConsumed = 550.0; LastMeteredAt = DateTime.UtcNow } ]
                        |> Map.ofList
                }

                let recentCommits = [
                    { Hash = "1480bd8"; Message = "feat(evolution): reify high-velocity saturation loop targeting 80% CPU/RAM (SC-SING-007)"; Author = "Gemini"; Timestamp = DateTime.UtcNow.AddMinutes(-5.0) }
                    { Hash = "c429667"; Message = "fix(substrate): hardened NIF and reify Singularity Feature Dashboard (SC-DASH-001)"; Author = "Gemini"; Timestamp = DateTime.UtcNow.AddMinutes(-25.0) }
                    { Hash = "4309603"; Message = "fix(substrate): restore KMS Catalog substrate"; Author = "Gemini"; Timestamp = DateTime.UtcNow.AddMinutes(-40.0) }
                ]
                
                state <- { state with 
                            Nodes = updatedNodes
                            Federation = Some fedHealth
                            Economics = Some econLedger
                            RecentCommits = recentCommits
                            MessagesReceived = state.MessagesReceived + 1
                            LastMessageAt = Some DateTime.UtcNow }
                lastUpdate <- DateTime.UtcNow

            // 3. Render
            DarkCockpitUI.render state
            Thread.Sleep(50)

        DarkCockpitUI.shutdown()