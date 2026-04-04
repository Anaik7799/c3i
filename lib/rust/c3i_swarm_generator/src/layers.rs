/// Fractal layer definitions for FMEA/STAMP directive generation.
///
/// 9 layers mapping the C3I system architecture from Workflow through L7_FEDERATION.

#[derive(Clone)]
pub struct FractalLayer {
    pub key: &'static str,
    pub title: &'static str,
    pub f_features: Vec<&'static str>,
    pub g_targets: Vec<&'static str>,
    pub themes: Vec<&'static str>,
    pub critical_boost: bool,
}

pub static STAMPS: &[&str] = &[
    "SC-PLAN", "SC-ZENOH", "SC-MESH", "SC-GLM", "SC-MATH", "SC-PERF",
    "SC-STATE", "SC-UI", "SC-DB", "SC-SYNC-DOC", "SC-ENV", "SC-CRYPTO",
    "AOR-GLM", "AOR-MESH", "SC-SEC", "SC-MEM", "SC-NET", "SC-TMR",
    "SC-OODA", "SC-ENTROPY", "SC-INFO", "SC-BISIM", "SC-MARKOV",
];

pub static CRITS: &[&str] = &["DAL-A / CRITICAL", "HIGH", "MEDIUM", "LOW"];
pub static CRITS_BOOSTED: &[&str] = &["DAL-A / CRITICAL", "DAL-A / CRITICAL", "HIGH", "HIGH"];

pub fn layers() -> Vec<FractalLayer> {
    vec![
        FractalLayer {
            key: "Workflow",
            title: "1. Workflow Process Steps",
            f_features: vec![
                "MSBuild", "Paket", "Fake", "DocFX", "Nuget",
                "dotnet build", "Assembly Attributes", "F# Scripts (.fsx)",
                "Ionide", "F# Interactive",
            ],
            g_targets: vec![
                "gleam build", "Hex packages", "gleam lsp", "gleam shell",
                "GitHub Actions", "gleam format", "gleam publish", "rebar3",
            ],
            themes: vec![
                "CI/CD Gates", "Lineage Extraction", "Code Evolution",
                "Gleam Linting", "F# Scraping", "STAMP Cross-ref",
                "Hoare Logic Verifier", "AST Verification", "PR Hooks",
                "Semantic Versioning", "Reproducible Builds",
            ],
            critical_boost: false,
        },
        FractalLayer {
            key: "L0_CONSTITUTIONAL",
            title: "2. L0_CONSTITUTIONAL (Core, Types, Safety)",
            f_features: vec![
                "System.Guid", "DateTimeOffset", "IComparable", "Structs",
                "Enums", "Exceptions", "typeof<'T>", "System.String",
                "System.Int32", "System.Double", "System.Uri", "ValueTask",
                "Nullable<T>",
            ],
            g_targets: vec![
                "opaque type", "Result", "BitArray", "Nil", "Float", "Int",
                "Custom Types", "Type Erasure", "Order", "String", "Dict", "Set",
            ],
            themes: vec![
                "Primitive Wrapping", "UUIDs", "Hashing", "Opaque Types",
                "Tuple Arity", "List Immutability", "BitArray Config",
                "Domain Errors", "Result Bindings", "Math Bounds",
                "NaN Avoidance", "Cryptographic Nonces", "Shannon Entropy Bounds",
            ],
            critical_boost: true,
        },
        FractalLayer {
            key: "L1_ATOMIC_DEBUG",
            title: "3. L1_ATOMIC_DEBUG (Telemetry, Tracing)",
            f_features: vec![
                "Activity.Current", "ILogger", "Stopwatch", "Trace.WriteLine",
                "Exception.StackTrace", "Thread.ManagedThreadId",
                "System.Diagnostics.Metrics", "EventSource",
            ],
            g_targets: vec![
                "Dynamic Logging", "erlang.system_time", "Pid", "Zenoh Pub",
                "Wisp Logger", "OTel Context", "telemetry package",
            ],
            themes: vec![
                "OTel Spans", "Zenoh Topics", "Log Levels", "Exception Stacks",
                "Pid Tracking", "Latency Metrics", "Crash Dumps", "Audit Logs",
                "Heartbeats", "Kolmogorov Complexity of Traces",
                "Mutual Information of Logs",
            ],
            critical_boost: false,
        },
        FractalLayer {
            key: "L2_COMPONENT",
            title: "4. L2_COMPONENT (Pure Logic, Transformations)",
            f_features: vec![
                "Active Patterns", "Computation Expressions", "Seq.fold",
                "List.map", "Regex", "System.Text.Json", "String.Format",
                "Extension Methods", "Lazy<T>", "Span<T>",
            ],
            g_targets: vec![
                "case expressions", "use syntax", "list.fold", "regexp",
                "dynamic.decode", "string.concat", "Named Functions",
                "JSON Builders", "Yielder",
            ],
            themes: vec![
                "Regex Compilation", "DU Matching", "List Folds", "Currying",
                "Memoization", "JSON Decoders", "String Formats", "RFC3339 Dates",
                "Pure Math", "Homomorphic Mapping Proofs", "Functor Preservation",
            ],
            critical_boost: false,
        },
        FractalLayer {
            key: "L3_TRANSACTION",
            title: "5. L3_TRANSACTION (State, Actors, Persistence)",
            f_features: vec![
                "MailboxProcessor", "Async", "Task", "ConcurrentDictionary",
                "lock()", "DbConnection", "Timer", "SemaphoreSlim", "Channel<T>",
            ],
            g_targets: vec![
                "gleam/otp/actor", "gleam/yielder", "process.call", "process.send",
                "SQLite single-writer", "Supervisor", "ETS tables", "Subject",
            ],
            themes: vec![
                "OTP Actors", "Mailbox Migration", "Supervisors",
                "SQLite Single-Writer", "Transaction Rollback", "State Hydration",
                "Idempotency", "Process Msg", "Deadlocks",
                "Bisimulation Equivalence", "Markov State Chains",
            ],
            critical_boost: true,
        },
        FractalLayer {
            key: "L4_SYSTEM",
            title: "6. L4_SYSTEM (Host, Podman, File System)",
            f_features: vec![
                "File.ReadAllText", "HttpClient", "UnixDomainSocketEndPoint",
                "Process.Start", "Environment.GetEnvironmentVariable",
                "CancellationToken", "FileShare.None",
            ],
            g_targets: vec![
                "simplifile", "hackney", "UDS Config", "os:cmd", "os.get_env",
                "erlang ports", "gen_tcp", "SIGTERM",
            ],
            themes: vec![
                "Podman HTTP", "Unix Domain Sockets", "File IO", "OS Cmds",
                "Env Vars", "CGroup Limits", "SIGTERM Hooks", "Hardware Info",
                "Zombie Harvesting", "Fault Tree Analysis",
                "Reliability Block Diagrams",
            ],
            critical_boost: false,
        },
        FractalLayer {
            key: "L5_COGNITIVE",
            title: "7. L5_COGNITIVE (UI, MCP, Advisory)",
            f_features: vec![
                "Bolero", "Elmish", "Giraffe", "SignalR", "IAsyncEnumerable",
                "Console.Write", "Fable", "HtmlNode",
            ],
            g_targets: vec![
                "Lustre", "Wisp", "Mist WebSockets", "Cockpit View",
                "TUI Renderer", "JSON Decoders", "html.div",
                "Server-Sent Events",
            ],
            themes: vec![
                "Lustre Updates", "Wisp Routes", "TUI Renders", "MCP Tools",
                "Prompt Context", "Token Limits", "HTML Views", "WebSockets",
                "Rate Limits", "KL Divergence of UI State",
                "Cognitive Load Metrics",
            ],
            critical_boost: false,
        },
        FractalLayer {
            key: "L6_ECOSYSTEM",
            title: "8. L6_ECOSYSTEM (Mesh, Zenoh)",
            f_features: vec![
                "Zenoh.Put", "Zenoh.Subscribe", "UDP Gossip", "Chaos Monkey",
                "System.Net.Sockets", "MessagePack", "Protobuf", "Polly Retry",
            ],
            g_targets: vec![
                "erlang NIFs", "actor.on_message", "Zenoh Router", "Health Probes",
                "Swarm Verification", "BitArray Decoding", "gleam/otp/supervisor",
            ],
            themes: vec![
                "Zenoh Subscriptions", "Mesh Probes", "Chaos Testing",
                "Split-Brain", "Gossip Proto", "Payload Compression",
                "Dead Letters", "Network Partitions", "Byzantine Fault Tolerance",
                "Graph Connectivity Invariants",
            ],
            critical_boost: true,
        },
        FractalLayer {
            key: "L7_FEDERATION",
            title: "9. L7_FEDERATION (Swarm Consensus)",
            f_features: vec![
                "2oo3 Voting", "TMR Execution", "Shadow Universe",
                "Global Shutdown Event", "Multi-node Locks", "Distributed Cache",
            ],
            g_targets: vec![
                "Gleam Reductions", "Distributed Erlang", "Supervisor Trees",
                "Digital Twin State", "Swarm Commands", "pg (process groups)",
            ],
            themes: vec![
                "Quorum Voting", "TMR Logic", "Digital Twin Sync",
                "Resurrection Seq", "Multilayer Maps", "Global Shutdown",
                "Consensus Algos", "OODA Loops", "CAP Theorem Bounds",
                "Paxos/Raft Mapping",
            ],
            critical_boost: true,
        },
    ]
}
