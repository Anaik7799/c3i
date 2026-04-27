//// scripts/pi/daemon — Pi-mono Node.js runtime lifecycle manager.
////
//// SC-SCRIPT-GLEAM-001 + SC-PI-RUNTIME-001.
////
//// Provides start/stop/health/prompt subcommands for the Pi agent process.
//// The Pi process runs in --print mode for one-shot prompts or --mode rpc
//// for persistent daemon operation.
////
//// Usage:
////   gleam run -m scripts/pi/daemon -- start           # start RPC daemon (background)
////   gleam run -m scripts/pi/daemon -- stop            # stop daemon
////   gleam run -m scripts/pi/daemon -- health          # check if daemon is alive
////   gleam run -m scripts/pi/daemon -- prompt "query"  # one-shot prompt
////   gleam run -m scripts/pi/daemon -- status          # full status report
////   gleam run -m scripts/pi/daemon -- models          # list available models
////   gleam run -m scripts/pi/daemon -- providers       # list providers

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import scripts/common/logx

// =============================================================================
// FFI for process management
// =============================================================================

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_run_in(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

@external(erlang, "scripts_sh_ffi", "run_capture_timeout")
fn sh_run_timeout(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  timeout_ms: Int,
) -> #(charlist.Charlist, Int)

// =============================================================================
// Constants
// =============================================================================

const pi_cli = "sub-projects/pi-mono/packages/coding-agent/dist/cli.js"

const c3i_root = "/home/an/dev/ver/c3i"

const pid_file = "/tmp/c3i-pi-daemon.pid"

const log_file = "/tmp/c3i-pi-daemon.log"

const default_provider = "google"

const default_model = "gemini-2.5-flash"

// =============================================================================
// Entry Point
// =============================================================================

pub fn main() {
  let args = argv.load().arguments
  case args {
    ["start", ..rest] -> cmd_start(rest)
    ["stop"] -> cmd_stop()
    ["health"] -> cmd_health()
    ["prompt", ..rest] -> cmd_prompt(string.join(rest, " "))
    ["status"] -> cmd_status()
    ["models"] -> cmd_models()
    ["providers"] -> cmd_providers()
    ["oneshot", ..rest] -> cmd_prompt(string.join(rest, " "))
    [] -> cmd_status()
    _ -> {
      io.println("Pi Daemon — Node.js runtime lifecycle manager")
      io.println("")
      io.println("Usage:")
      io.println("  gleam run -m scripts/pi/daemon -- start [--provider P] [--model M]")
      io.println("  gleam run -m scripts/pi/daemon -- stop")
      io.println("  gleam run -m scripts/pi/daemon -- health")
      io.println("  gleam run -m scripts/pi/daemon -- prompt 'your query here'")
      io.println("  gleam run -m scripts/pi/daemon -- status")
      io.println("  gleam run -m scripts/pi/daemon -- models")
      io.println("  gleam run -m scripts/pi/daemon -- providers")
      Nil
    }
  }
}

// =============================================================================
// Commands
// =============================================================================

fn cmd_start(args: List(String)) {
  let provider = extract_flag(args, "--provider", default_provider)
  let model = extract_flag(args, "--model", default_model)

  logx.info("pi-daemon", "Starting Pi daemon: " <> provider <> "/" <> model)

  // Check if already running
  case read_pid() {
    Ok(pid) -> {
      case is_process_alive(pid) {
        True -> {
          logx.info("pi-daemon", "Pi daemon already running (PID " <> int.to_string(pid) <> ")")
          Nil
        }
        False -> {
          logx.info("pi-daemon", "Stale PID file found, starting fresh")
          do_start(provider, model)
        }
      }
    }
    Error(_) -> do_start(provider, model)
  }
}

fn do_start(provider: String, model: String) {
  // Start Pi in background using nohup + redirect
  let cmd = "bash"
  let script =
    "source " <> c3i_root <> "/sub-projects/pi-mono/load-env.sh 2>/dev/null; "
    <> "nohup node " <> c3i_root <> "/" <> pi_cli
    <> " --provider " <> provider
    <> " --model " <> model
    <> " --mode rpc"
    <> " > " <> log_file <> " 2>&1 &"
    <> " echo $!"

  let #(out_cl, rc) = sh_run_in(
    charlist.from_string(cmd),
    [charlist.from_string("-c"), charlist.from_string(script)],
    charlist.from_string(c3i_root),
  )
  let out = charlist.to_string(out_cl)
  let pid_str = string.trim(out)

  case rc {
    0 -> {
      // Write PID file
      write_pid_file(pid_str)
      logx.info("pi-daemon", "Pi daemon started (PID " <> pid_str <> ")")
      logx.info("pi-daemon", "Log: " <> log_file)
      logx.info("pi-daemon", "Provider: " <> provider <> "/" <> model)
    }
    _ -> {
      logx.error("pi-daemon", "Failed to start Pi daemon (rc=" <> int.to_string(rc) <> "): " <> out)
    }
  }
}

fn cmd_stop() {
  case read_pid() {
    Ok(pid) -> {
      logx.info("pi-daemon", "Stopping Pi daemon (PID " <> int.to_string(pid) <> ")")
      let #(_, rc) = sh_run_in(
        charlist.from_string("kill"),
        [charlist.from_string(int.to_string(pid))],
        charlist.from_string(c3i_root),
      )
      case rc {
        0 -> {
          remove_pid_file()
          logx.info("pi-daemon", "Pi daemon stopped")
        }
        _ -> {
          logx.info("pi-daemon", "Pi daemon not running (stale PID), cleaning up")
          remove_pid_file()
        }
      }
    }
    Error(_) -> logx.info("pi-daemon", "Pi daemon not running (no PID file)")
  }
}

fn cmd_health() {
  case read_pid() {
    Ok(pid) -> {
      case is_process_alive(pid) {
        True -> {
          io.println("HEALTHY: Pi daemon running (PID " <> int.to_string(pid) <> ")")
        }
        False -> {
          io.println("UNHEALTHY: PID " <> int.to_string(pid) <> " not found")
          remove_pid_file()
        }
      }
    }
    Error(_) -> io.println("STOPPED: No Pi daemon running")
  }
}

fn cmd_prompt(prompt: String) {
  case string.is_empty(string.trim(prompt)) {
    True -> {
      logx.error("pi-daemon", "No prompt provided. Usage: gleam run -m scripts/pi/daemon -- prompt 'your query'")
      Nil
    }
    False -> {
      logx.info("pi-daemon", "Sending prompt to Pi (" <> int.to_string(string.length(prompt)) <> " chars)")

      // Use --print mode for one-shot with 120s timeout.
      // Spawn node directly (not via bash) — the BEAM process already has
      // API keys in env from the parent shell. Avoids bash startup overhead.
      let node_path = "/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/node"

      let #(out_cl, rc) = sh_run_timeout(
        charlist.from_string(node_path),
        [
          charlist.from_string(c3i_root <> "/" <> pi_cli),
          charlist.from_string("--provider"),
          charlist.from_string(default_provider),
          charlist.from_string("--model"),
          charlist.from_string(default_model),
          charlist.from_string("--print"),
          charlist.from_string(prompt),
        ],
        120_000, // 120 second timeout for LLM inference
      )
      let out = charlist.to_string(out_cl)

      case rc {
        0 -> {
          // Filter out env-loading noise
          let response = out
            |> string.split("\n")
            |> list.filter(fn(line) { !string.contains(line, "Loaded environment") })
            |> string.join("\n")
            |> string.trim()
          io.println(response)
        }
        124 -> logx.error("pi-daemon", "Pi timed out after 120s")
        _ -> {
          logx.error("pi-daemon", "Pi returned error (rc=" <> int.to_string(rc) <> ")")
          io.println(string.trim(out))
        }
      }
    }
  }
}

fn cmd_status() {
  io.println("=== Pi-mono Runtime Status ===")
  io.println("CLI: " <> pi_cli)
  io.println("PID file: " <> pid_file)
  io.println("Log file: " <> log_file)

  case read_pid() {
    Ok(pid) -> {
      case is_process_alive(pid) {
        True -> io.println("Status: RUNNING (PID " <> int.to_string(pid) <> ")")
        False -> io.println("Status: DEAD (stale PID " <> int.to_string(pid) <> ")")
      }
    }
    Error(_) -> io.println("Status: STOPPED")
  }

  // Check if Pi binary exists using bash test
  let #(_, build_rc) = sh_run_in(
    charlist.from_string("/usr/bin/bash"),
    [charlist.from_string("-c"), charlist.from_string("test -f " <> c3i_root <> "/" <> pi_cli)],
    charlist.from_string(c3i_root),
  )
  case build_rc {
    0 -> io.println("Binary: BUILT")
    _ -> io.println("Binary: NOT BUILT (run: cd sub-projects/pi-mono && npm run build)")
  }

  // Check Node.js version
  let #(node_cl, _) = sh_run_in(
    charlist.from_string("node"),
    [charlist.from_string("--version")],
    charlist.from_string(c3i_root),
  )
  io.println("Node.js: " <> string.trim(charlist.to_string(node_cl)))
  io.println("Default provider: " <> default_provider <> "/" <> default_model)
}

fn cmd_models() {
  logx.info("pi-daemon", "Querying available models from Pi...")
  let cmd = "bash"
  let script =
    "source " <> c3i_root <> "/sub-projects/pi-mono/load-env.sh 2>/dev/null; "
    <> "node " <> c3i_root <> "/" <> pi_cli
    <> " --provider " <> default_provider
    <> " --model " <> default_model
    <> " --print 'List ALL models available to you right now. Format: provider/model-id, one per line. Only list models you can actually call.'"

  let #(out_cl, rc) = sh_run_in(
    charlist.from_string(cmd),
    [charlist.from_string("-c"), charlist.from_string(script)],
    charlist.from_string(c3i_root),
  )
  let out = charlist.to_string(out_cl)
  case rc {
    0 -> {
      let response = out
        |> string.split("\n")
        |> list.filter(fn(line) { !string.contains(line, "Loaded environment") })
        |> string.join("\n")
        |> string.trim()
      io.println(response)
    }
    _ -> logx.error("pi-daemon", "Failed to query models: " <> string.trim(out))
  }
}

fn cmd_providers() {
  io.println("Supported Pi LLM Providers (15):")
  io.println("  1. google      — Gemini 2.5 Flash/Pro (free tier, recommended)")
  io.println("  2. anthropic   — Claude Sonnet/Opus (paid)")
  io.println("  3. openai      — GPT-4o, o3, o4-mini (paid)")
  io.println("  4. ollama      — Local models: gemma3, llama3, qwen2 (free)")
  io.println("  5. openrouter  — Any model via proxy")
  io.println("  6. bedrock     — AWS Claude, Titan")
  io.println("  7. mistralai   — Mistral Large")
  io.println("  8. groq        — LPU: llama3-70b (fast, free tier)")
  io.println("  9. deepseek    — DeepSeek Chat (cheap)")
  io.println(" 10. xai         — Grok-3")
  io.println(" 11. cerebras    — Fast inference")
  io.println(" 12. qwen        — Qwen2-72b")
  io.println(" 13. sambanova   — Various")
  io.println(" 14. fireworks   — Various")
  io.println(" 15. together    — Various")
}

// =============================================================================
// PID File Management
// =============================================================================

fn read_pid() -> Result(Int, Nil) {
  let #(out_cl, rc) = sh_run_in(
    charlist.from_string("cat"),
    [charlist.from_string(pid_file)],
    charlist.from_string(c3i_root),
  )
  case rc {
    0 -> {
      let pid_str = string.trim(charlist.to_string(out_cl))
      int.parse(pid_str) |> result.replace_error(Nil)
    }
    _ -> Error(Nil)
  }
}

fn write_pid_file(pid: String) {
  let #(_, _) = sh_run_in(
    charlist.from_string("bash"),
    [charlist.from_string("-c"), charlist.from_string("echo " <> pid <> " > " <> pid_file)],
    charlist.from_string(c3i_root),
  )
  Nil
}

fn remove_pid_file() {
  let #(_, _) = sh_run_in(
    charlist.from_string("rm"),
    [charlist.from_string("-f"), charlist.from_string(pid_file)],
    charlist.from_string(c3i_root),
  )
  Nil
}

fn is_process_alive(pid: Int) -> Bool {
  let #(_, rc) = sh_run_in(
    charlist.from_string("kill"),
    [charlist.from_string("-0"), charlist.from_string(int.to_string(pid))],
    charlist.from_string(c3i_root),
  )
  rc == 0
}

// =============================================================================
// Helpers
// =============================================================================

fn extract_flag(args: List(String), flag: String, default: String) -> String {
  case args {
    [] -> default
    [f, val, ..] if f == flag -> val
    [_, ..rest] -> extract_flag(rest, flag, default)
  }
}

fn shell_quote(s: String) -> String {
  "'" <> string.replace(s, "'", "'\\''") <> "'"
}
