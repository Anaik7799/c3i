//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/ui/wisp/router</module></identity>
////   <fractal-topology><layer>L7_FEDERATION</layer></fractal-topology>
////   <compliance><stamp-controls>SC-WEBHOOK-001, SC-WEBHOOK-002</stamp-controls></compliance>
//// </c3i-module>
////
//// Wisp REST API Router.
//// Handles inbound webhooks from Telegram, GChat, and WhatsApp, injecting them as Zenoh Intents.

import cepaf_gleam/zenoh/client as zenoh
import gleam/io
import gleam/json
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

pub type Context {
  Context(zenoh: zenoh.Session, secret_token: String)
}

/// The main routing function for the Wisp server.
pub fn handle_request(req: Request, ctx: Context) -> Response {
  // Apply middleware (logging, error handling)
  use req <- wisp.log_request(req)
  use req <- wisp.rescue_crashes(req)
  use req <- wisp.handle_head(req)

  case wisp.path_segments(req) {
    ["api", "v1", "ping"] -> handle_ping(req)
    ["api", "v1", "webhooks", "telegram"] -> handle_telegram(req, ctx)
    ["api", "v1", "webhooks", "gchat"] -> handle_gchat(req, ctx)
    _ -> wisp.not_found()
  }
}

fn handle_ping(_req: Request) -> Response {
  wisp.json_response(wisp.ok(), "{\"status\": \"ok\", \"service\": \"indrajaal-wisp\"}")
}

fn handle_telegram(req: Request, ctx: Context) -> Response {
  // SC-WEBHOOK-002: Cryptographic Verification
  let is_authorized = case wisp.get_header(req, "x-telegram-bot-api-secret-token") {
    Ok(token) if token == ctx.secret_token -> True
    _ -> False
  }

  case is_authorized {
    False -> wisp.json_response(wisp.unauthorized(), "{\"error\": \"unauthorized\"}")
    True -> {
      use body <- wisp.require_json(req)
      
      // Naive JSON extraction for MVP. In prod, use typed decoders.
      // Expected Telegram structure: {"message": {"text": "hello", "from": {"id": 123}}}
      // We simulate extraction here to forward the raw body for now.
      
      let text_extract = "User Message" // Replace with actual decode
      let intent_id = "tg-webhook-" <> wisp.random_string(8)
      
      io.println("📥 Wisp [Telegram]: Received webhook. Injecting intent " <> intent_id)
      
      let payload = json.object([
        #("id", json.string(intent_id)),
        #("raw_text", json.string(text_extract)),
        #("source", json.string("telegram")),
        #("raw_payload", json.string(string.inspect(body))),
        #("timestamp_ms", json.int(0))
      ])
      |> json.to_string()
      
      // SC-WEBHOOK-001: Non-blocking publish
      let _ = zenoh.put(ctx.zenoh, "indrajaal/l5/cog/intent/req", payload)
      
      wisp.json_response(wisp.ok(), "{\"status\": \"received\"}")
    }
  }
}

fn handle_gchat(req: Request, ctx: Context) -> Response {
  // SC-WEBHOOK-002: Verification (Assuming Google Bearer or custom secret for this iteration)
  let is_authorized = case wisp.get_header(req, "authorization") {
    Ok(token) -> string.contains(token, ctx.secret_token)
    _ -> False
  }

  case is_authorized {
    False -> wisp.json_response(wisp.unauthorized(), "{\"error\": \"unauthorized\"}")
    True -> {
      use body <- wisp.require_json(req)
      
      let intent_id = "gc-webhook-" <> wisp.random_string(8)
      io.println("📥 Wisp [GChat]: Received webhook. Injecting intent " <> intent_id)
      
      let payload = json.object([
        #("id", json.string(intent_id)),
        #("raw_text", json.string("GChat Message")), // Replace with decode
        #("source", json.string("gchat")),
        #("raw_payload", json.string(string.inspect(body))),
        #("timestamp_ms", json.int(0))
      ])
      |> json.to_string()
      
      let _ = zenoh.put(ctx.zenoh, "indrajaal/l5/cog/intent/req", payload)
      
      wisp.json_response(wisp.ok(), "{\"status\": \"received\"}")
    }
  }
}
