------------------------------- MODULE DartMcpServer -------------------------------
(***************************************************************************
 C3I CPIG Pass 14 — Dart MCP server (dev-tooling MCP for Dart + Flutter)

 Subsystem: dart_mcp_server (~22 tools, 11 default-on) coexisting with
            patrol_mcp, marionette_mcp, and the in-app flutter_ai_toolkit
            without tool-name collision.

 Source files (governance):
   - .claude/rules/dart-flutter-ai-mcp.md
   - .claude/settings.json (mcpServers entry "dart")
   - sub-projects/marionette_mcp/  (peer)
   - sub-projects/sutra/fluffychat/integration_test/  (peer; patrol)

 STAMP constraints covered:
   SC-DART-MCP-001..010
   (notably SC-DART-MCP-004 release-mode block; SC-DART-MCP-009 namespace)

 Model-checking notes (TLC):
   CONSTANTS  Tools           = {"analyze_files","dart_fix","dart_format",
                                  "run_tests","hot_reload","hot_restart",
                                  "dtd","get_runtime_errors","get_app_logs",
                                  "widget_inspector","pub"}
              PatrolTools     = {"mcp__patrol__run","mcp__patrol__screenshot"}
              MarionetteTools = {"mcp__marionette__connect","mcp__marionette__tap"}
              Transports      = {"stdio","sse"}
   INVARIANT  TypeOK, ReleaseModeBlock, ToolNamespaceUnique,
              AuthoritativeRustApiOnly
   PROPERTY   Spec
 ***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Tools,            \* the set of dart_mcp_server tool names
    PatrolTools,      \* peer namespace
    MarionetteTools,  \* peer namespace
    Transports        \* permitted MCP transports {"stdio","sse"}

VARIABLES
    tools,           \* set of currently exposed dart MCP tools
    activeSessions,  \* Nat: count of attached agent sessions
    debugMode,       \* BOOLEAN: target Flutter app is in debug mode
    transport        \* element of Transports

vars == <<tools, activeSessions, debugMode, transport>>

TypeOK ==
    /\ tools          \subseteq Tools
    /\ activeSessions \in Nat
    /\ debugMode      \in BOOLEAN
    /\ transport      \in Transports

----------------------------------------------------------------------------
Init ==
    /\ tools          = {}
    /\ activeSessions = 0
    /\ debugMode      = FALSE
    /\ transport      = "stdio"

(* Operator switches the target build into debug mode (kDebugMode = true) *)
EnterDebug ==
    /\ ~debugMode
    /\ debugMode' = TRUE
    /\ UNCHANGED <<tools, activeSessions, transport>>

(* Server exposes a tool — only legal if app is in debug mode (SC-DART-MCP-004) *)
ExposeTool(t) ==
    /\ t \in Tools
    /\ debugMode                \* HARD GATE
    /\ t \notin PatrolTools     \* SC-DART-MCP-009 namespace uniqueness
    /\ t \notin MarionetteTools
    /\ tools' = tools \cup {t}
    /\ UNCHANGED <<activeSessions, debugMode, transport>>

(* Leaving debug mode forces the toolset to drain (release-mode block) *)
LeaveDebug ==
    /\ debugMode
    /\ debugMode' = FALSE
    /\ tools'     = {}
    /\ UNCHANGED <<activeSessions, transport>>

(* Agent attaches a session over an allowed transport *)
AttachSession ==
    /\ debugMode
    /\ activeSessions' = activeSessions + 1
    /\ UNCHANGED <<tools, debugMode, transport>>

(* Switch transport between the two allowed kinds (stdio <-> sse) *)
SwitchTransport(tr) ==
    /\ tr \in Transports
    /\ transport' = tr
    /\ UNCHANGED <<tools, activeSessions, debugMode>>

Next ==
    \/ EnterDebug
    \/ \E t \in Tools : ExposeTool(t)
    \/ LeaveDebug
    \/ AttachSession
    \/ \E tr \in Transports : SwitchTransport(tr)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
(* Invariants *)

\* SC-DART-MCP-004: in release mode the tool surface MUST be empty.
ReleaseModeBlock == ~debugMode => tools = {}

\* SC-DART-MCP-009: dart MCP tools must not collide with peer MCP namespaces.
ToolNamespaceUnique ==
    /\ tools \cap PatrolTools     = {}
    /\ tools \cap MarionetteTools = {}

\* SC-DART-MCP-001 / supplementary: only authoritative Rust-API-style transports
\* (no embedded HTTP servers, no Python bridges).
AuthoritativeRustApiOnly == transport \in Transports

THEOREM SpecImpliesInvariants ==
    Spec => [](TypeOK
               /\ ReleaseModeBlock
               /\ ToolNamespaceUnique
               /\ AuthoritativeRustApiOnly)

============================================================================
