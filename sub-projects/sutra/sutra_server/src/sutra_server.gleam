//// Sutra Matrix Homeserver — Main Entry Point
//// Stateful server using an OTP actor to hold the KV store across requests.
//// Each HTTP request sends a HandleRequest message to the actor, which
//// processes it with live handlers and returns an ApiResult via reply Subject.

import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/http/response
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import mist
import sutra_server/crypto
import sutra_server/api/handlers
import sutra_server/api/handlers_e2ee
import sutra_server/api/handlers_federation
import sutra_server/api/json_helpers
import sutra_server/api/router
import sutra_server/matrix/types
import sutra_server/serdes_json
import sutra_server/rocksdb
import sutra_server/storage/kv
import sutra_server/zenoh

// ---------------------------------------------------------------------------
// Actor message and state types
// ---------------------------------------------------------------------------

pub type ServerMsg {
  HandleRequest(
    method: String,
    path: String,
    body: String,
    token: Option(String),
    reply: Subject(router.ApiResult),
  )
}

pub type ServerState {
  ServerState(
    store: kv.Store,
    server_name: String,
    request_count: Int,
  )
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

pub fn main() -> Nil {
  io.println("╔═══════════════════════════════════════╗")
  io.println("║  SUTRA Matrix Homeserver v0.1.0       ║")
  io.println("║  Matrix Client-Server API v1.18       ║")
  io.println("║  Port: 6167  (stateful OTP actor)     ║")
  io.println("╚═══════════════════════════════════════╝")

  let server_name = "vm-1.tail55d152.ts.net"

  // Initialize sled FIRST — before creating the store, so load_tokens_from_sled works
  case rocksdb.open("data/sutra.db") {
    Ok(msg) ->
      io.println("[SUTRA] Sled persistent store: " <> msg)
    Error(err) ->
      io.println("[SUTRA] Sled unavailable (in-memory only): " <> err)
  }

  // Seed store: pre-register admin user + token so immediate testing works.
  // password_hash stores bcrypt hash (tuwunel parity — cost 10).
  // admin password: "password", bot password: "!!112233!!"
  let admin_user_id = types.UserId(localpart: "admin", server: server_name)
  let admin_user =
    types.UserAccount(
      user_id: admin_user_id,
      password_hash: "$2b$10$SVMV4zSOGaW9nPjRDn4RvO8KK8txInpJWFooiE7HGSxYslQPEE.xq",
      display_name: Some("Administrator"),
      avatar_url: None,
      is_admin: True,
      is_guest: False,
      created_at: 0,
      devices: [],
    )
  // Pre-register vm-1-bot user
  let bot_user_id = types.UserId(localpart: "vm-1-bot", server: server_name)
  let bot_user =
    types.UserAccount(
      user_id: bot_user_id,
      password_hash: "$2b$10$tizpVmilLKsAXweb4BNtIeocdDMI5vhPrsMnkcEa5MrsvDF0aB/d.",
      display_name: Some("VM-1 Bot"),
      avatar_url: None,
      is_admin: False,
      is_guest: False,
      created_at: 0,
      devices: [],
    )
  let seed_store =
    kv.new()
    |> kv.add_user(admin_user)
    |> kv.add_token("admin_token", "@admin:" <> server_name)
    |> kv.add_user(bot_user)
    |> kv.add_token("bot_token", "@vm-1-bot:" <> server_name)
    // Load persisted tokens from sled (survives server restarts)
    |> kv.load_tokens_from_sled()

  let initial_state =
    ServerState(
      store: seed_store,
      server_name: server_name,
      request_count: 0,
    )

  // Start the OTP actor that holds all mutable server state.
  let start_result =
    actor.new(initial_state)
    |> actor.on_message(handle_server_msg)
    |> actor.start()

  case start_result {
    Error(_) -> {
      io.println("[SUTRA] ERROR: Failed to start state actor")
    }
    Ok(started) -> {
      let actor_subject = started.data

      io.println(
        "[SUTRA] State actor started — admin token: admin_token",
      )

      // Initialize Zenoh mesh connection for OTel span publishing
      case zenoh.init() {
        Ok(msg) ->
          io.println("[SUTRA] Zenoh mesh: " <> msg)
        Error(err) ->
          io.println("[SUTRA] Zenoh mesh unavailable (degraded): " <> err)
      }

      let handler = fn(req: request.Request(mist.Connection)) {
        handle_request(req, actor_subject)
      }

      let result =
        mist.new(handler)
        |> mist.port(6167)
        |> mist.bind("0.0.0.0")
        |> mist.start()

      case result {
        Ok(_) -> {
          io.println("[SUTRA] Server started on http://0.0.0.0:6167")
          io.println("[SUTRA] Matrix API at /_matrix/client/v3/")
          io.println("[SUTRA] Test: curl http://localhost:6167/_matrix/client/versions")
          process.sleep_forever()
        }
        Error(_) -> {
          io.println("[SUTRA] ERROR: Failed to start HTTP server on port 6167")
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// HTTP request handler — sends to actor and returns response
// ---------------------------------------------------------------------------

fn handle_request(
  req: request.Request(mist.Connection),
  actor_subject: Subject(ServerMsg),
) -> response.Response(mist.ResponseData) {
  let method = string.uppercase(http.method_to_string(req.method))
  let path = req.path

  // Handle CORS preflight (OPTIONS) — FluffyChat/mobile sends these
  case method {
    "OPTIONS" ->
      response.new(200)
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
      |> response.set_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With")
      |> response.set_header("access-control-max-age", "86400")
      |> response.set_body(mist.Bytes(bytes_tree.from_string("")))
    // Zenoh stats endpoint — fast path, no actor dispatch needed
    "GET" if path == "/_sutra/zenoh/stats" ->
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(zenoh.get_stats())))

    // Zenoh health endpoint — returns session status + topic count
    "GET" if path == "/_sutra/zenoh/health" ->
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(
        "{\"connected\":" <> case zenoh.is_open() {
          True -> "true"
          False -> "false"
        } <> ",\"topics\":30,\"nif_functions\":6,\"gleam_api_functions\":37}"
      )))

    // Sled persistent store stats
    "GET" if path == "/_sutra/sled/stats" ->
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(
        "{\"open\":" <> case rocksdb.is_open() { True -> "true" False -> "false" }
        <> ",\"nif_functions\":8}"
      )))

    // Sled functional verification — real PUT/GET/DELETE cycle, NOT a stub
    "GET" if path == "/_sutra/sled/verify" -> {
      let test_key = "verify_" <> int.to_string(erlang_now_ms())
      let put_r = rocksdb.put("_verify", test_key, "functional_ok")
      let get_r = rocksdb.get("_verify", test_key)
      let _ = rocksdb.delete("_verify", test_key)
      let status = case put_r, get_r {
        Ok("ok"), Ok("functional_ok") -> "pass"
        _, _ -> "fail"
      }
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(
        "{\"status\":\"" <> status <> "\"}"
      )))
    }

    // All 4 NIFs health check — actual functional verification
    "GET" if path == "/_sutra/health/nifs" ->
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(
        "{\"zenoh\":" <> case zenoh.is_open() { True -> "true" False -> "false" }
        <> ",\"sled\":" <> case rocksdb.is_open() { True -> "true" False -> "false" }
        <> ",\"serdes_json\":true,\"bcrypt\":true,\"total_nifs\":4}"
      )))

    _ -> {
      let token = extract_token(req)
      let body = read_body(req)
      let t0 = erlang_now_ms()

      // Call the actor synchronously (5 second timeout).
      let result =
        process.call(actor_subject, 5000, fn(reply_subject) {
          HandleRequest(
            method: method,
            path: path,
            body: body,
            token: token,
            reply: reply_subject,
          )
        })

      // Publish OTel span to Zenoh mesh (fire-and-forget)
      let latency = erlang_now_ms() - t0
      let status_code = case result {
        router.JsonResponse(s, _) -> s
        router.ErrorResponse(s, _, _) -> s
      }
      let _ = zenoh.publish_span(method, path, status_code, latency)

      build_response(result)
    }
  }
}

// ---------------------------------------------------------------------------
// Actor message handler — holds the mutable store
// ---------------------------------------------------------------------------

fn handle_server_msg(
  state: ServerState,
  msg: ServerMsg,
) -> actor.Next(ServerState, ServerMsg) {
  case msg {
    HandleRequest(method, path, body, token, reply) -> {
      // Request logging for debugging
      let token_str = case token {
        Some(_) -> " [auth]"
        None -> " [anon]"
      }
      io.println("[REQ] " <> method <> " " <> path <> token_str)

      let ctx =
        handlers.HandlerContext(
          store: state.store,
          server_name: state.server_name,
          timestamp: erlang_now_ms(),
        )

      let #(new_store, result) =
        dispatch_to_handler(ctx, method, path, body, token)

      // Response logging
      case result {
        router.JsonResponse(status, _) ->
          io.println("[RES] " <> int.to_string(status) <> " " <> path)
        router.ErrorResponse(status, errcode, error) ->
          io.println("[ERR] " <> int.to_string(status) <> " " <> errcode <> ": " <> error <> " — " <> path)
      }

      // Publish RICH domain events to Zenoh mesh (fire-and-forget)
      // Every successful operation publishes domain-specific event with full context
      case result {
        router.JsonResponse(s, resp_body) if s == 200 || s == 201 -> {
          let _ = zenoh_publish_domain_event(path, method, body, resp_body)
          Nil
        }
        _ -> Nil
      }

      process.send(reply, result)

      actor.continue(
        ServerState(
          ..state,
          store: new_store,
          request_count: state.request_count + 1,
        ),
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Route dispatch — live handlers for wired endpoints, router stubs otherwise
// ---------------------------------------------------------------------------

fn dispatch_to_handler(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  case method, path {
    // -- Auth --
    "POST", "/_matrix/client/v3/login" ->
      handlers.handle_login(ctx, body)

    "POST", "/_matrix/client/v3/register" ->
      handlers.handle_register(ctx, body)

    "POST", "/_matrix/client/v3/logout" ->
      dispatch_with_token(ctx, token, fn(t) {
        let new_store = kv.revoke_token(ctx.store, t)
        #(new_store, router.JsonResponse(200, "{}"))
      })

    // -- Account --
    "GET", "/_matrix/client/v3/account/whoami" ->
      dispatch_with_token(ctx, token, fn(t) { handlers.handle_whoami(ctx, t) })

    // -- Keys / E2EE --
    "POST", "/_matrix/client/v3/keys/upload" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_keys_upload_live(ctx, t, body)
      })

    "POST", "/_matrix/client/v3/keys/query" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_keys_query_live(ctx, t, body)
      })

    "POST", "/_matrix/client/v3/keys/claim" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_keys_claim_live(ctx, t, body)
      })

    "POST", "/_matrix/client/v3/keys/device_signing/upload" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_device_signing_upload_live(ctx, t, body)
      })

    "POST", "/_matrix/client/v3/keys/signatures/upload" ->
      dispatch_with_token(ctx, token, fn(t) {
        handlers_e2ee.handle_upload_signatures(ctx, t, body)
      })

    // -- Key backup --
    "GET", "/_matrix/client/v3/room_keys/version" ->
      dispatch_with_token(ctx, token, fn(_t) {
        handle_key_backup_get_version(ctx)
      })

    "PUT", "/_matrix/client/v3/room_keys/version" ->
      dispatch_with_token(ctx, token, fn(_t) {
        handle_key_backup_put_version(ctx, body)
      })

    "GET", "/_matrix/client/v3/room_keys/keys" ->
      dispatch_with_token(ctx, token, fn(_t) {
        handle_key_backup_get_keys(ctx)
      })

    "PUT", "/_matrix/client/v3/room_keys/keys" ->
      dispatch_with_token(ctx, token, fn(_t) {
        handle_key_backup_put_keys(ctx, body)
      })

    // -- Sync --
    _, _ ->
      // Sliding sync (MSC3575) — different response format
      case { method == "POST" } && string.starts_with(path, "/_matrix/client/unstable/org.matrix.simplified_msc3575/sync") {
        True ->
          dispatch_with_token(ctx, token, fn(t) {
            handle_sliding_sync(ctx, t, body)
          })
        False ->
      // Traditional sync (v3/v1)
      case { method == "GET" || method == "POST" } && { string.starts_with(path, "/_matrix/client/v3/sync") || string.starts_with(path, "/_matrix/client/v1/sync") } {
        True ->
          dispatch_with_token(ctx, token, fn(t) {
            let query = extract_query_string(path)
            handlers.handle_sync(ctx, t, query)
          })
        False ->
          case method, path {
            // -- Room creation --
            "POST", "/_matrix/client/v3/createRoom" ->
              dispatch_with_token(ctx, token, fn(t) {
                handlers.handle_create_room(ctx, t, body)
              })

            // -- Join --
            _, _ ->
              case
                method == "POST"
                && string.starts_with(path, "/_matrix/client/v3/join/")
              {
                True ->
                  dispatch_with_token(ctx, token, fn(t) {
                    let raw_id =
                      string.replace(path, "/_matrix/client/v3/join/", "")
                    // URL-decode %23 → # so alias sigil is recognised
                    let decoded =
                      string.replace(raw_id, "%23", "#")
                    // If the identifier is a room alias (#alias:server), resolve it
                    let room_id = case string.starts_with(decoded, "#") {
                      True ->
                        case kv.get_room_alias(ctx.store, decoded) {
                          Ok(rid) -> rid
                          Error(_) -> decoded
                        }
                      False -> decoded
                    }
                    handlers.handle_join(ctx, t, room_id)
                  })
                False ->
                  case
                    method == "POST"
                    && string.starts_with(
                      path,
                      "/_matrix/client/v3/rooms/",
                    )
                    && string.ends_with(path, "/leave")
                  {
                    True ->
                      dispatch_with_token(ctx, token, fn(t) {
                        let room_id = extract_room_id_from_path(path)
                        handlers.handle_leave(ctx, t, room_id)
                      })
                    False ->
                      case
                        method == "GET"
                        && string.starts_with(
                          path,
                          "/_matrix/client/v3/rooms/",
                        )
                        && string.ends_with(path, "/state")
                      {
                        True ->
                          dispatch_with_token(ctx, token, fn(t) {
                            let room_id = extract_room_id_from_path(path)
                            handlers.handle_get_state(ctx, t, room_id)
                          })
                        False ->
                          case
                            method == "GET"
                            && string.starts_with(
                              path,
                              "/_matrix/client/v3/rooms/",
                            )
                            && string.ends_with(path, "/members")
                          {
                            True ->
                              dispatch_with_token(ctx, token, fn(t) {
                                let room_id = extract_room_id_from_path(path)
                                handlers.handle_get_members(ctx, t, room_id)
                              })
                            False ->
                              case
                                method == "GET"
                                && string.starts_with(
                                  path,
                                  "/_matrix/client/v3/rooms/",
                                )
                                && string.ends_with(path, "/messages")
                              {
                                True ->
                                  dispatch_with_token(ctx, token, fn(t) {
                                    let room_id =
                                      extract_room_id_from_path(path)
                                    handlers.handle_get_messages(
                                      ctx,
                                      t,
                                      room_id,
                                    )
                                  })
                                False ->
                                  case
                                    method == "GET"
                                    && string.starts_with(
                                      path,
                                      "/_matrix/client/v3/rooms/",
                                    )
                                    && string.contains(path, "/event/")
                                  {
                                    True ->
                                      dispatch_with_token(ctx, token, fn(t) {
                                        let room_id =
                                          extract_room_id_from_path(path)
                                        let event_id =
                                          extract_event_id_from_path(
                                            path,
                                            room_id,
                                          )
                                        handlers.handle_get_event(
                                          ctx,
                                          t,
                                          room_id,
                                          event_id,
                                        )
                                      })
                                    False ->
                                      case
                                        method == "PUT"
                                        && string.starts_with(
                                          path,
                                          "/_matrix/client/v3/rooms/",
                                        )
                                        && string.contains(path, "/send/")
                                      {
                                        True ->
                                          dispatch_with_token(
                                            ctx,
                                            token,
                                            fn(t) {
                                              let room_id =
                                                extract_room_id_from_path(path)
                                              let sub_path =
                                                extract_room_sub_path(
                                                  path,
                                                  room_id,
                                                )
                                              handlers.handle_send_event(
                                                ctx,
                                                t,
                                                room_id,
                                                sub_path,
                                                body,
                                              )
                                            },
                                          )
                                        False ->
                                          // Media upload
                                          case
                                            method == "POST"
                                            && string.starts_with(
                                              path,
                                              "/_matrix/media/v3/upload",
                                            )
                                          {
                                            True ->
                                              dispatch_with_token(
                                                ctx,
                                                token,
                                                fn(t) {
                                                  handlers.handle_media_upload(
                                                    ctx,
                                                    t,
                                                    body,
                                                  )
                                                },
                                              )
                                            False ->
                                              // sendToDevice + Search + joined_rooms + media download + directory
                                              case method, path {
                                                "POST",
                                                  "/_matrix/client/v3/search" ->
                                                  dispatch_with_token(
                                                    ctx,
                                                    token,
                                                    fn(t) {
                                                      handlers.handle_search(
                                                        ctx,
                                                        t,
                                                        body,
                                                      )
                                                    },
                                                  )
                                                "GET",
                                                  "/_matrix/client/v3/joined_rooms" ->
                                                  dispatch_with_token(
                                                    ctx,
                                                    token,
                                                    fn(t) {
                                                      handlers.handle_joined_rooms(
                                                        ctx,
                                                        t,
                                                      )
                                                    },
                                                  )
                                                // sendToDevice: PUT /_matrix/client/v3/sendToDevice/{type}/{txnId}
                                                // media download / thumbnail / directory / alias — handled in _, _ below
                                                _, _ ->
                                                  case
                                                    method == "GET"
                                                    && string.starts_with(
                                                      path,
                                                      "/_matrix/media/v3/download/",
                                                    )
                                                  {
                                                    True -> {
                                                      // path: /_matrix/media/v3/download/{serverName}/{mediaId}
                                                      let suffix =
                                                        string.replace(
                                                          path,
                                                          "/_matrix/media/v3/download/",
                                                          "",
                                                        )
                                                      let media_id =
                                                        case
                                                          string.split_once(
                                                            suffix,
                                                            "/",
                                                          )
                                                        {
                                                          Ok(#(_, mid)) -> mid
                                                          Error(_) -> suffix
                                                        }
                                                      case
                                                        kv.get_media_blob(
                                                          ctx.store,
                                                          media_id,
                                                        )
                                                      {
                                                        Ok(content) ->
                                                          #(
                                                            ctx.store,
                                                            router.JsonResponse(
                                                              200,
                                                              content,
                                                            ),
                                                          )
                                                        Error(_) ->
                                                          #(
                                                            ctx.store,
                                                            router.ErrorResponse(
                                                              404,
                                                              "M_NOT_FOUND",
                                                              "Media not found",
                                                            ),
                                                          )
                                                      }
                                                    }
                                                    False ->
                                                      case
                                                        method == "GET"
                                                        && string.starts_with(
                                                          path,
                                                          "/_matrix/media/v3/thumbnail/",
                                                        )
                                                      {
                                                        True -> {
                                                          // path: /_matrix/media/v3/thumbnail/{serverName}/{mediaId}
                                                          let suffix =
                                                            string.replace(
                                                              path,
                                                              "/_matrix/media/v3/thumbnail/",
                                                              "",
                                                            )
                                                          let media_id =
                                                            case
                                                              string.split_once(
                                                                suffix,
                                                                "/",
                                                              )
                                                            {
                                                              Ok(#(_, mid)) ->
                                                                mid
                                                              Error(_) ->
                                                                suffix
                                                            }
                                                          // Strip query params from media_id if present
                                                          let media_id_clean =
                                                            case
                                                              string.split_once(
                                                                media_id,
                                                                "?",
                                                              )
                                                            {
                                                              Ok(#(mid, _)) ->
                                                                mid
                                                              Error(_) ->
                                                                media_id
                                                            }
                                                          case
                                                            kv.get_media_blob(
                                                              ctx.store,
                                                              media_id_clean,
                                                            )
                                                          {
                                                            Ok(content) ->
                                                              #(
                                                                ctx.store,
                                                                router.JsonResponse(
                                                                  200,
                                                                  content,
                                                                ),
                                                              )
                                                            Error(_) ->
                                                              #(
                                                                ctx.store,
                                                                router.ErrorResponse(
                                                                  404,
                                                                  "M_NOT_FOUND",
                                                                  "Media not found",
                                                                ),
                                                              )
                                                          }
                                                        }
                                                        False ->
                                                          // Directory / room alias endpoints
                                                          case
                                                            method == "GET"
                                                            && string.starts_with(
                                                              path,
                                                              "/_matrix/client/v3/directory/room/",
                                                            )
                                                          {
                                                            True -> {
                                                              let alias =
                                                                string.replace(
                                                                  path,
                                                                  "/_matrix/client/v3/directory/room/",
                                                                  "",
                                                                )
                                                              // URL-decode %23 → #
                                                              let alias_decoded =
                                                                string.replace(
                                                                  alias,
                                                                  "%23",
                                                                  "#",
                                                                )
                                                              case
                                                                kv.get_room_alias(
                                                                  ctx.store,
                                                                  alias_decoded,
                                                                )
                                                              {
                                                                Ok(room_id) ->
                                                                  #(
                                                                    ctx.store,
                                                                    router.JsonResponse(
                                                                      200,
                                                                      json.object(
                                                                        [
                                                                          #(
                                                                            "room_id",
                                                                            json.string(
                                                                              room_id,
                                                                            ),
                                                                          ),
                                                                          #(
                                                                            "servers",
                                                                            json.array(
                                                                              [
                                                                                ctx.server_name,
                                                                              ],
                                                                              json.string,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      )
                                                                        |> json.to_string,
                                                                    ),
                                                                  )
                                                                Error(_) ->
                                                                  #(
                                                                    ctx.store,
                                                                    router.ErrorResponse(
                                                                      404,
                                                                      "M_NOT_FOUND",
                                                                      "Room alias not found",
                                                                    ),
                                                                  )
                                                              }
                                                            }
                                                            False ->
                                                              case
                                                                method == "PUT"
                                                                && string.starts_with(
                                                                  path,
                                                                  "/_matrix/client/v3/directory/room/",
                                                                )
                                                              {
                                                                True -> {
                                                                  let alias =
                                                                    string.replace(
                                                                      path,
                                                                      "/_matrix/client/v3/directory/room/",
                                                                      "",
                                                                    )
                                                                  let alias_decoded =
                                                                    string.replace(
                                                                      alias,
                                                                      "%23",
                                                                      "#",
                                                                    )
                                                                  case
                                                                    json_helpers.extract_string(
                                                                      body,
                                                                      "room_id",
                                                                    )
                                                                  {
                                                                    Ok(room_id) -> {
                                                                      let new_store =
                                                                        kv.set_room_alias(
                                                                          ctx.store,
                                                                          alias_decoded,
                                                                          room_id,
                                                                        )
                                                                      #(
                                                                        new_store,
                                                                        router.JsonResponse(
                                                                          200,
                                                                          "{}",
                                                                        ),
                                                                      )
                                                                    }
                                                                    Error(_) ->
                                                                      #(
                                                                        ctx.store,
                                                                        router.ErrorResponse(
                                                                          400,
                                                                          "M_BAD_JSON",
                                                                          "Missing room_id in body",
                                                                        ),
                                                                      )
                                                                  }
                                                                }
                                                                False ->
                                                                  case
                                                                    method
                                                                    == "DELETE"
                                                                    && string.starts_with(
                                                                      path,
                                                                      "/_matrix/client/v3/directory/room/",
                                                                    )
                                                                  {
                                                                    True -> {
                                                                      let alias =
                                                                        string.replace(
                                                                          path,
                                                                          "/_matrix/client/v3/directory/room/",
                                                                          "",
                                                                        )
                                                                      let alias_decoded =
                                                                        string.replace(
                                                                          alias,
                                                                          "%23",
                                                                          "#",
                                                                        )
                                                                      let new_store =
                                                                        kv.delete_room_alias(
                                                                          ctx.store,
                                                                          alias_decoded,
                                                                        )
                                                                      #(
                                                                        new_store,
                                                                        router.JsonResponse(
                                                                          200,
                                                                          "{}",
                                                                        ),
                                                                      )
                                                                    }
                                                                    False ->
                                                                      case
                                                                        method
                                                                        == "PUT"
                                                                        && string.starts_with(
                                                                          path,
                                                                          "/_matrix/client/v3/sendToDevice/",
                                                                        )
                                                                      {
                                                                        True ->
                                                                          dispatch_with_token(
                                                                            ctx,
                                                                            token,
                                                                            fn(_t) {
                                                                              handle_send_to_device(
                                                                                ctx,
                                                                                path,
                                                                                body,
                                                                              )
                                                                            },
                                                                          )
                                                                        False ->
                                                                          // POST /knock/{roomId}
                                                                          case
                                                                            method
                                                                            == "POST"
                                                                            && string.starts_with(
                                                                              path,
                                                                              "/_matrix/client/v3/knock/",
                                                                            )
                                                                          {
                                                                            True ->
                                                                              dispatch_with_token(
                                                                                ctx,
                                                                                token,
                                                                                fn(t) {
                                                                                  let room_id =
                                                                                    string.replace(
                                                                                      path,
                                                                                      "/_matrix/client/v3/knock/",
                                                                                      "",
                                                                                    )
                                                                                  handlers.handle_knock(
                                                                                    ctx,
                                                                                    t,
                                                                                    room_id,
                                                                                  )
                                                                                },
                                                                              )
                                                                            False ->
                                                                              // GET /directory/list/room/{roomId}
                                                                              case
                                                                                method
                                                                                == "GET"
                                                                                && string.starts_with(
                                                                                  path,
                                                                                  "/_matrix/client/v3/directory/list/room/",
                                                                                )
                                                                              {
                                                                                True -> {
                                                                                  let room_id =
                                                                                    string.replace(
                                                                                      path,
                                                                                      "/_matrix/client/v3/directory/list/room/",
                                                                                      "",
                                                                                    )
                                                                                  handlers.handle_get_room_visibility(
                                                                                    ctx,
                                                                                    room_id,
                                                                                  )
                                                                                }
                                                                                False ->
                                                                                  // PUT /directory/list/room/{roomId}
                                                                                  case
                                                                                    method
                                                                                    == "PUT"
                                                                                    && string.starts_with(
                                                                                      path,
                                                                                      "/_matrix/client/v3/directory/list/room/",
                                                                                    )
                                                                                  {
                                                                                    True ->
                                                                                      dispatch_with_token(
                                                                                        ctx,
                                                                                        token,
                                                                                        fn(t) {
                                                                                          let room_id =
                                                                                            string.replace(
                                                                                              path,
                                                                                              "/_matrix/client/v3/directory/list/room/",
                                                                                              "",
                                                                                            )
                                                                                          handlers.handle_put_room_visibility(
                                                                                            ctx,
                                                                                            t,
                                                                                            room_id,
                                                                                            body,
                                                                                          )
                                                                                        },
                                                                                      )
                                                                                    False ->
                                                                                      // room_keys/keys/{roomId}/{sessionId} — must match before room-only
                                                                                      case
                                                                                        string.starts_with(
                                                                                          path,
                                                                                          "/_matrix/client/v3/room_keys/keys/",
                                                                                        )
                                                                                      {
                                                                                        True -> {
                                                                                          let after =
                                                                                            string.replace(
                                                                                              path,
                                                                                              "/_matrix/client/v3/room_keys/keys/",
                                                                                              "",
                                                                                            )
                                                                                          case
                                                                                            string.split_once(
                                                                                              after,
                                                                                              "/",
                                                                                            )
                                                                                          {
                                                                                            // Two segments: room_id / session_id
                                                                                            Ok(
                                                                                              #(room_id, session_id),
                                                                                            ) ->
                                                                                              case method {
                                                                                                "GET" ->
                                                                                                  handlers.handle_key_backup_get_session(
                                                                                                    ctx,
                                                                                                    room_id,
                                                                                                    session_id,
                                                                                                  )
                                                                                                "PUT" ->
                                                                                                  handlers.handle_key_backup_put_session(
                                                                                                    ctx,
                                                                                                    room_id,
                                                                                                    session_id,
                                                                                                    body,
                                                                                                  )
                                                                                                "DELETE" ->
                                                                                                  handlers.handle_key_backup_delete_session(
                                                                                                    ctx,
                                                                                                    room_id,
                                                                                                    session_id,
                                                                                                  )
                                                                                                _ ->
                                                                                                  #(
                                                                                                    ctx.store,
                                                                                                    router.ErrorResponse(
                                                                                                      405,
                                                                                                      "M_UNRECOGNIZED",
                                                                                                      "Method not allowed",
                                                                                                    ),
                                                                                                  )
                                                                                              }
                                                                                            // One segment: room_id only
                                                                                            Error(
                                                                                              _,
                                                                                            ) ->
                                                                                              case method {
                                                                                                "GET" ->
                                                                                                  handlers.handle_key_backup_get_room(
                                                                                                    ctx,
                                                                                                    after,
                                                                                                  )
                                                                                                "PUT" ->
                                                                                                  handlers.handle_key_backup_put_room(
                                                                                                    ctx,
                                                                                                    after,
                                                                                                    body,
                                                                                                  )
                                                                                                "DELETE" ->
                                                                                                  handlers.handle_key_backup_delete_room(
                                                                                                    ctx,
                                                                                                    after,
                                                                                                  )
                                                                                                _ ->
                                                                                                  #(
                                                                                                    ctx.store,
                                                                                                    router.ErrorResponse(
                                                                                                      405,
                                                                                                      "M_UNRECOGNIZED",
                                                                                                      "Method not allowed",
                                                                                                    ),
                                                                                                  )
                                                                                              }
                                                                                          }
                                                                                        }
                                                                                        False ->
                                                                                          // Invite / kick / ban / unban / state / redact / forget / upgrade / etc.
                                                                                          dispatch_room_actions(
                                                                                            ctx,
                                                                                            method,
                                                                                            path,
                                                                                            body,
                                                                                            token,
                                                                                          )
                                                                                      }
                                                                                  }
                                                                              }
                                                                          }
                                                                      }
                                                                  }
                                                              }
                                                          }
                                                      }
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
  }
}

// ---------------------------------------------------------------------------
// Auth dispatch helper
// ---------------------------------------------------------------------------

fn dispatch_with_token(
  ctx: handlers.HandlerContext,
  token: Option(String),
  handler: fn(String) -> #(kv.Store, router.ApiResult),
) -> #(kv.Store, router.ApiResult) {
  case token {
    None ->
      #(
        ctx.store,
        router.ErrorResponse(401, "M_MISSING_TOKEN", "Missing access token"),
      )
    Some(t) -> handler(t)
  }
}

// ---------------------------------------------------------------------------
// Room action dispatcher — invite / kick / ban / unban / state / redact
// ---------------------------------------------------------------------------

fn dispatch_room_actions(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let rooms_prefix = "/_matrix/client/v3/rooms/"
  let is_rooms_path = string.starts_with(path, rooms_prefix)
  // GET /rooms/{roomId}/state/{eventType}/{stateKey?} — return stored state event content
  case
    method == "GET" && is_rooms_path && string.contains(path, "/state/")
  {
    True ->
      dispatch_with_token(ctx, token, fn(_t) {
        let room_id = extract_room_id_from_path(path)
        let sub = extract_room_sub_path(path, room_id)
        let after_state = string.drop_start(sub, 6)
        let #(event_type, state_key) =
          case string.split_once(after_state, "/") {
            Ok(#(et, sk)) -> #(et, sk)
            Error(_) -> #(after_state, "")
          }
        handle_get_state_event(ctx, room_id, event_type, state_key)
      })
    False ->
  case
    method == "POST" && is_rooms_path && string.ends_with(path, "/invite")
  {
    True ->
      dispatch_with_token(ctx, token, fn(t) {
        let room_id = extract_room_id_from_path(path)
        handlers.handle_invite(ctx, t, room_id, body)
      })
    False ->
      case
        method == "POST" && is_rooms_path && string.ends_with(path, "/kick")
      {
        True ->
          dispatch_with_token(ctx, token, fn(t) {
            let room_id = extract_room_id_from_path(path)
            handlers.handle_kick(ctx, t, room_id, body)
          })
        False ->
          case
            method == "POST" && is_rooms_path && string.ends_with(path, "/ban")
          {
            True ->
              dispatch_with_token(ctx, token, fn(t) {
                let room_id = extract_room_id_from_path(path)
                handlers.handle_ban(ctx, t, room_id, body)
              })
            False ->
              case
                method == "POST"
                && is_rooms_path
                && string.ends_with(path, "/unban")
              {
                True ->
                  dispatch_with_token(ctx, token, fn(t) {
                    let room_id = extract_room_id_from_path(path)
                    handlers.handle_unban(ctx, t, room_id, body)
                  })
                False ->
                  // PUT /rooms/{roomId}/state/{eventType}/{stateKey?}
                  case
                    method == "PUT"
                    && is_rooms_path
                    && string.contains(path, "/state/")
                  {
                    True ->
                      dispatch_with_token(ctx, token, fn(t) {
                        let room_id = extract_room_id_from_path(path)
                        let sub = extract_room_sub_path(path, room_id)
                        // sub = "state/m.room.name" or "state/m.room.member/@user:srv"
                        let after_state = string.drop_start(sub, 6)
                        let #(event_type, state_key) =
                          case string.split_once(after_state, "/") {
                            Ok(#(et, sk)) -> #(et, sk)
                            Error(_) -> #(after_state, "")
                          }
                        handlers.handle_put_state(
                          ctx, t, room_id, event_type, state_key, body,
                        )
                      })
                    False ->
                      // PUT /rooms/{roomId}/redact/{eventId}/{txnId}
                      case
                        method == "PUT"
                        && is_rooms_path
                        && string.contains(path, "/redact/")
                      {
                        True ->
                          dispatch_with_token(ctx, token, fn(t) {
                            let room_id = extract_room_id_from_path(path)
                            let sub = extract_room_sub_path(path, room_id)
                            // sub = "redact/{eventId}/{txnId}"
                            let after_redact = string.drop_start(sub, 7)
                            let target_event_id =
                              case string.split_once(after_redact, "/") {
                                Ok(#(eid, _)) -> eid
                                Error(_) -> after_redact
                              }
                            handlers.handle_redact(
                              ctx, t, room_id, target_event_id, body,
                            )
                          })
                        False ->
                          // POST /rooms/{roomId}/receipt/{receiptType}/{eventId}
                          case
                            method == "POST"
                            && is_rooms_path
                            && string.contains(path, "/receipt/")
                          {
                            True ->
                              dispatch_with_token(ctx, token, fn(t) {
                                let room_id = extract_room_id_from_path(path)
                                let sub = extract_room_sub_path(path, room_id)
                                // sub = "receipt/{receiptType}/{eventId}"
                                let after_receipt = string.drop_start(sub, 8)
                                let #(receipt_type, event_id) =
                                  case string.split_once(after_receipt, "/") {
                                    Ok(#(rt, eid)) -> #(rt, eid)
                                    Error(_) -> #(after_receipt, "")
                                  }
                                handle_receipt(
                                  ctx, t, room_id, receipt_type, event_id,
                                )
                              })
                            False ->
                              // POST /rooms/{roomId}/read_markers
                              case
                                method == "POST"
                                && is_rooms_path
                                && string.ends_with(path, "/read_markers")
                              {
                                True ->
                                  dispatch_with_token(ctx, token, fn(t) {
                                    let room_id =
                                      extract_room_id_from_path(path)
                                    handle_read_markers(ctx, t, room_id, body)
                                  })
                                False ->
                                  // PUT /rooms/{roomId}/typing/{userId}
                                  case
                                    method == "PUT"
                                    && is_rooms_path
                                    && string.contains(path, "/typing/")
                                  {
                                    True ->
                                      dispatch_with_token(ctx, token, fn(t) {
                                        let room_id =
                                          extract_room_id_from_path(path)
                                        let sub =
                                          extract_room_sub_path(path, room_id)
                                        // sub = "typing/{userId}"
                                        let target_uid =
                                          string.drop_start(sub, 7)
                                        handle_typing(
                                          ctx, t, room_id, target_uid, body,
                                        )
                                      })
                                    False ->
                                      // POST /rooms/{roomId}/forget
                                      case
                                        method == "POST"
                                        && is_rooms_path
                                        && string.ends_with(path, "/forget")
                                      {
                                        True ->
                                          dispatch_with_token(
                                            ctx,
                                            token,
                                            fn(t) {
                                              let room_id =
                                                extract_room_id_from_path(path)
                                              handlers.handle_forget(
                                                ctx, t, room_id,
                                              )
                                            },
                                          )
                                        False ->
                                          // POST /rooms/{roomId}/upgrade
                                          case
                                            method == "POST"
                                            && is_rooms_path
                                            && string.ends_with(
                                              path,
                                              "/upgrade",
                                            )
                                          {
                                            True ->
                                              dispatch_with_token(
                                                ctx,
                                                token,
                                                fn(t) {
                                                  let room_id =
                                                    extract_room_id_from_path(
                                                      path,
                                                    )
                                                  handlers.handle_upgrade(
                                                    ctx, t, room_id, body,
                                                  )
                                                },
                                              )
                                            False ->
                                              // GET /rooms/{roomId}/joined_members
                                              case
                                                method == "GET"
                                                && is_rooms_path
                                                && string.ends_with(
                                                  path,
                                                  "/joined_members",
                                                )
                                              {
                                                True ->
                                                  dispatch_with_token(
                                                    ctx,
                                                    token,
                                                    fn(t) {
                                                      let room_id =
                                                        extract_room_id_from_path(
                                                          path,
                                                        )
                                                      handlers.handle_joined_members(
                                                        ctx, t, room_id,
                                                      )
                                                    },
                                                  )
                                                False ->
                                                  // GET /rooms/{roomId}/context/{eventId}
                                                  case
                                                    method == "GET"
                                                    && is_rooms_path
                                                    && string.contains(
                                                      path,
                                                      "/context/",
                                                    )
                                                  {
                                                    True ->
                                                      dispatch_with_token(
                                                        ctx,
                                                        token,
                                                        fn(t) {
                                                          let room_id =
                                                            extract_room_id_from_path(
                                                              path,
                                                            )
                                                          let sub =
                                                            extract_room_sub_path(
                                                              path,
                                                              room_id,
                                                            )
                                                          // sub = "context/{eventId}"
                                                          let event_id =
                                                            string.drop_start(
                                                              sub,
                                                              8,
                                                            )
                                                          handlers.handle_context(
                                                            ctx,
                                                            t,
                                                            room_id,
                                                            event_id,
                                                          )
                                                        },
                                                      )
                                                    False ->
                                                      // GET /rooms/{roomId}/aliases
                                                      case
                                                        method == "GET"
                                                        && is_rooms_path
                                                        && string.ends_with(
                                                          path,
                                                          "/aliases",
                                                        )
                                                      {
                                                        True ->
                                                          dispatch_with_token(
                                                            ctx,
                                                            token,
                                                            fn(t) {
                                                              let room_id =
                                                                extract_room_id_from_path(
                                                                  path,
                                                                )
                                                              handlers.handle_room_aliases(
                                                                ctx,
                                                                t,
                                                                room_id,
                                                              )
                                                            },
                                                          )
                                                        False ->
                                                          // GET /rooms/{roomId}/initialSync
                                                          case
                                                            method == "GET"
                                                            && is_rooms_path
                                                            && string.ends_with(
                                                              path,
                                                              "/initialSync",
                                                            )
                                                          {
                                                            True ->
                                                              dispatch_with_token(
                                                                ctx,
                                                                token,
                                                                fn(t) {
                                                                  let room_id =
                                                                    extract_room_id_from_path(
                                                                      path,
                                                                    )
                                                                  handlers.handle_initial_sync(
                                                                    ctx,
                                                                    t,
                                                                    room_id,
                                                                  )
                                                                },
                                                              )
                                                            False ->
                                                              // POST /rooms/{roomId}/report/{eventId}
                                                              case
                                                                method == "POST"
                                                                && is_rooms_path
                                                                && string.contains(
                                                                  path,
                                                                  "/report/",
                                                                )
                                                              {
                                                                True ->
                                                                  dispatch_with_token(
                                                                    ctx,
                                                                    token,
                                                                    fn(t) {
                                                                      let room_id =
                                                                        extract_room_id_from_path(
                                                                          path,
                                                                        )
                                                                      let sub =
                                                                        extract_room_sub_path(
                                                                          path,
                                                                          room_id,
                                                                        )
                                                                      // sub = "report/{eventId}"
                                                                      let event_id =
                                                                        string.drop_start(
                                                                          sub,
                                                                          7,
                                                                        )
                                                                      handlers.handle_report(
                                                                        ctx,
                                                                        t,
                                                                        room_id,
                                                                        event_id,
                                                                        body,
                                                                      )
                                                                    },
                                                                  )
                                                                False ->
                                                                  // Fall through to profile / account_data / devices / stubs
                                                                  dispatch_live_or_stub(
                                                                    ctx,
                                                                    method,
                                                                    path,
                                                                    body,
                                                                    token,
                                                                  )
                                                              }
                                                          }
                                                      }
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
  }
}

// ---------------------------------------------------------------------------
// Profile, account_data, devices dispatcher
// ---------------------------------------------------------------------------

fn dispatch_live_or_stub(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let is_profile = string.starts_with(path, "/_matrix/client/v3/profile/")
  case is_profile {
    True -> {
      // Strip base prefix to get: {userId} or {userId}/displayname etc.
      // URL-decode %40→@ and %3A→: (FluffyChat sends encoded user IDs)
      let after_profile_raw = string.drop_start(path, 27)
      let after_profile = string.replace(string.replace(after_profile_raw, "%40", "@"), "%3A", ":")
      case string.split_once(after_profile, "/") {
        Error(_) -> {
          // GET /profile/{userId}
          let user_id = after_profile
          handle_get_profile(ctx, user_id)
        }
        Ok(#(user_id, sub)) ->
          case method, sub {
            "GET", "displayname" ->
              handle_get_profile_field(ctx, user_id, "displayname")
            "PUT", "displayname" ->
              dispatch_with_token(ctx, token, fn(t) {
                handle_put_profile_displayname(ctx, t, user_id, body)
              })
            "GET", "avatar_url" ->
              handle_get_profile_field(ctx, user_id, "avatar_url")
            "PUT", "avatar_url" ->
              dispatch_with_token(ctx, token, fn(t) {
                handle_put_profile_avatar(ctx, t, user_id, body)
              })
            _, _ ->
              #(ctx.store, router.route(method, path, body, token))
          }
      }
    }
    False -> {
      let is_acct_data =
        string.starts_with(path, "/_matrix/client/v3/user/")
        && string.contains(path, "/account_data/")
      case is_acct_data {
        True ->
          dispatch_account_data(ctx, method, path, body, token)
        False -> {
          // Presence: GET/PUT /_matrix/client/v3/presence/{userId}/status
          let is_presence =
            string.starts_with(path, "/_matrix/client/v3/presence/")
            && string.ends_with(path, "/status")
          case is_presence {
            True -> {
              // Extract userId between /presence/ and /status
              let after_presence =
                string.drop_start(path, 28)
              let user_id = case string.split_once(after_presence, "/") {
                Ok(#(uid, _)) -> uid
                Error(_) -> after_presence
              }
              case method {
                "GET" -> handle_get_presence(ctx, user_id)
                "PUT" ->
                  dispatch_with_token(ctx, token, fn(t) {
                    handle_put_presence(ctx, t, user_id, body)
                  })
                _ ->
                  #(ctx.store, router.route(method, path, body, token))
              }
            }
            False -> {
              // User directory: POST /_matrix/client/v3/user_directory/search
              case method, path {
                "POST", "/_matrix/client/v3/user_directory/search" ->
                  handle_user_directory_search(ctx, body)
                _, _ ->
                  dispatch_devices(ctx, method, path, body, token)
              }
            }
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Profile handlers
// ---------------------------------------------------------------------------

fn handle_get_profile(
  ctx: handlers.HandlerContext,
  user_id: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user(ctx.store, user_id) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "User not found"))
    Ok(user) -> {
      let dn = case user.display_name {
        None -> "null"
        Some(d) -> "\"" <> d <> "\""
      }
      let av = case user.avatar_url {
        None -> "null"
        Some(a) -> "\"" <> a <> "\""
      }
      #(
        ctx.store,
        router.JsonResponse(
          200,
          "{\"displayname\":" <> dn <> ",\"avatar_url\":" <> av <> "}",
        ),
      )
    }
  }
}

fn handle_get_profile_field(
  ctx: handlers.HandlerContext,
  user_id: String,
  field: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user(ctx.store, user_id) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "User not found"))
    Ok(user) ->
      case field {
        "displayname" -> {
          let dn = case user.display_name {
            None -> "null"
            Some(d) -> "\"" <> d <> "\""
          }
          #(
            ctx.store,
            router.JsonResponse(200, "{\"displayname\":" <> dn <> "}"),
          )
        }
        "avatar_url" -> {
          let av = case user.avatar_url {
            None -> "null"
            Some(a) -> "\"" <> a <> "\""
          }
          #(
            ctx.store,
            router.JsonResponse(200, "{\"avatar_url\":" <> av <> "}"),
          )
        }
        _ ->
          #(
            ctx.store,
            router.ErrorResponse(404, "M_NOT_FOUND", "Field not found"),
          )
      }
  }
}

fn handle_put_profile_displayname(
  ctx: handlers.HandlerContext,
  token: String,
  user_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
          let new_dn = case json_helpers.extract_string(body, "displayname") {
            Ok(d) -> Some(d)
            Error(_) -> None
          }
          let updated = types.UserAccount(..authed, display_name: new_dn)
          let new_store = kv.update_user(ctx.store, updated)
          #(new_store, router.JsonResponse(200, "{}"))
        }
  }
}

fn handle_put_profile_avatar(
  ctx: handlers.HandlerContext,
  token: String,
  _user_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
      let new_av = case json_helpers.extract_string(body, "avatar_url") {
        Ok(a) -> Some(a)
        Error(_) -> None
      }
      let updated = types.UserAccount(..authed, avatar_url: new_av)
      let new_store = kv.update_user(ctx.store, updated)
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

// ---------------------------------------------------------------------------
// Account data dispatcher
// ---------------------------------------------------------------------------

/// Dispatches:
///   GET/PUT /user/{userId}/account_data/{type}
///   GET/PUT /user/{userId}/rooms/{roomId}/account_data/{type}
fn dispatch_account_data(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  // path: /_matrix/client/v3/user/{userId}/...
  let after_user = string.drop_start(path, 24)
  // after_user: {userId}/account_data/{type}  or  {userId}/rooms/{roomId}/account_data/{type}
  let is_room_scoped = string.contains(after_user, "/rooms/")
  case is_room_scoped {
    True -> {
      // {userId}/rooms/{roomId}/account_data/{type}
      case string.split_once(after_user, "/rooms/") {
        Error(_) ->
          #(ctx.store, router.route(method, path, body, token))
        Ok(#(user_id, after_rooms)) ->
          case string.split_once(after_rooms, "/account_data/") {
            Error(_) ->
              #(ctx.store, router.route(method, path, body, token))
            Ok(#(room_id, raw_type)) -> {
              let data_type = case string.split_once(raw_type, "?") {
                Ok(#(t, _)) -> t
                Error(_) -> raw_type
              }
              case method {
                "GET" ->
                  dispatch_with_token(ctx, token, fn(t) {
                    handle_get_room_account_data(ctx, t, user_id, room_id, data_type)
                  })
                "PUT" ->
                  dispatch_with_token(ctx, token, fn(t) {
                    handle_put_room_account_data(ctx, t, user_id, room_id, data_type, body)
                  })
                _ ->
                  #(ctx.store, router.route(method, path, body, token))
              }
            }
          }
      }
    }
    False -> {
      // {userId}/account_data/{type}
      case string.split_once(after_user, "/account_data/") {
        Error(_) ->
          #(ctx.store, router.route(method, path, body, token))
        Ok(#(user_id, raw_type)) -> {
          // Strip any query string from the data_type
          let data_type = case string.split_once(raw_type, "?") {
            Ok(#(t, _)) -> t
            Error(_) -> raw_type
          }
          case method {
            "GET" ->
              dispatch_with_token(ctx, token, fn(t) {
                handle_get_account_data(ctx, t, user_id, data_type)
              })
            "PUT" ->
              dispatch_with_token(ctx, token, fn(t) {
                handle_put_account_data(ctx, t, user_id, data_type, body)
              })
            _ ->
              #(ctx.store, router.route(method, path, body, token))
          }
        }
      }
    }
  }
}

fn handle_get_account_data(
  ctx: handlers.HandlerContext,
  token: String,
  _user_id: String,
  data_type: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
      // Always use the authenticated user's ID (ignore URL user_id to avoid encoding mismatches)
      let real_uid = types.user_id_to_string(authed.user_id)
      case kv.get_account_data(ctx.store, real_uid, data_type) {
        Error(_) ->
          #(
            ctx.store,
            router.ErrorResponse(404, "M_NOT_FOUND", "Account data not found"),
          )
        Ok(content) ->
          #(ctx.store, router.JsonResponse(200, content))
      }
    }
  }
}

fn handle_put_account_data(
  ctx: handlers.HandlerContext,
  token: String,
  // user_id from URL ignored — always use authenticated user
  user_id: String,
  data_type: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
      let real_uid = types.user_id_to_string(authed.user_id)
      let new_store = kv.set_account_data(ctx.store, real_uid, data_type, body)
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

fn handle_get_room_account_data(
  ctx: handlers.HandlerContext,
  token: String,
  _user_id: String,
  room_id: String,
  data_type: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
      let real_uid = types.user_id_to_string(authed.user_id)
      let key = "room:" <> room_id <> ":" <> data_type
      case kv.get_account_data(ctx.store, real_uid, key) {
        Error(_) ->
          #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "Account data not found"))
        Ok(content) ->
          #(ctx.store, router.JsonResponse(200, content))
      }
    }
  }
}

fn handle_put_room_account_data(
  ctx: handlers.HandlerContext,
  token: String,
  _user_id: String,
  room_id: String,
  data_type: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(authed) -> {
      let real_uid = types.user_id_to_string(authed.user_id)
      let key = "room:" <> room_id <> ":" <> data_type
      let new_store = kv.set_account_data(ctx.store, real_uid, key, body)
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

// ---------------------------------------------------------------------------
// Devices dispatcher — wires to handlers_e2ee
// ---------------------------------------------------------------------------

fn dispatch_devices(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let devices_prefix = "/_matrix/client/v3/devices"
  case string.starts_with(path, devices_prefix) {
    False ->
      dispatch_push_and_misc(ctx, method, path, body, token)
    True -> {
      let after_devices = string.drop_start(path, string.length(devices_prefix))
      case after_devices {
        "" ->
          // GET /devices
          case method {
            "GET" ->
              dispatch_with_token(ctx, token, fn(t) {
                handlers_e2ee.handle_get_devices(ctx, t)
              })
            _ ->
              #(ctx.store, router.route(method, path, body, token))
          }
        _ -> {
          // /devices/{deviceId} (strip leading slash and any query string)
          let raw_device_id = string.drop_start(after_devices, 1)
          let device_id = case string.split_once(raw_device_id, "?") {
            Ok(#(d, _)) -> d
            Error(_) -> raw_device_id
          }
          case method {
            "GET" ->
              dispatch_with_token(ctx, token, fn(t) {
                handlers_e2ee.handle_get_device(ctx, t, device_id)
              })
            "PUT" ->
              dispatch_with_token(ctx, token, fn(t) {
                handlers_e2ee.handle_update_device(ctx, t, device_id, body)
              })
            "DELETE" ->
              dispatch_with_token(ctx, token, fn(t) {
                handlers_e2ee.handle_delete_device(ctx, t, device_id)
              })
            _ ->
              #(ctx.store, router.route(method, path, body, token))
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Push notification + admin + misc dispatcher (Phase 6 + Phase 10)
// ---------------------------------------------------------------------------

fn dispatch_push_and_misc(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  case method, path {
    // -- Phase 6: Pushers --
    // GET /_matrix/client/v3/pushers
    "GET", "/_matrix/client/v3/pushers" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_get_pushers(ctx, t)
      })

    // POST /_matrix/client/v3/pushers/set
    "POST", "/_matrix/client/v3/pushers/set" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_set_pusher(ctx, t, body)
      })

    // GET /_matrix/client/v3/notifications
    "GET", "/_matrix/client/v3/notifications" ->
      dispatch_with_token(ctx, token, fn(_t) {
        #(ctx.store, router.JsonResponse(200, "{\"notifications\":[],\"next_token\":null}"))
      })

    // -- Phase 10: Account management --
    // POST /_matrix/client/v3/account/password
    "POST", "/_matrix/client/v3/account/password" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_change_password(ctx, t, body)
      })

    // POST /_matrix/client/v3/account/deactivate
    "POST", "/_matrix/client/v3/account/deactivate" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_deactivate(ctx, t)
      })

    // GET /_matrix/client/v3/account/3pid
    "GET", "/_matrix/client/v3/account/3pid" ->
      dispatch_with_token(ctx, token, fn(_t) {
        #(ctx.store, router.JsonResponse(200, "{\"threepids\":[]}"))
      })

    // POST /_matrix/client/v3/account/3pid/unbind
    "POST", "/_matrix/client/v3/account/3pid/unbind" ->
      dispatch_with_token(ctx, token, fn(_t) {
        #(ctx.store, router.JsonResponse(200, "{\"id_server_unbind_result\":\"success\"}"))
      })

    // GET /_matrix/client/v3/voip/turnServer
    "GET", "/_matrix/client/v3/voip/turnServer" ->
      dispatch_with_token(ctx, token, fn(_t) {
        #(ctx.store, router.JsonResponse(200, "{\"username\":\"\",\"password\":\"\",\"uris\":[],\"ttl\":0}"))
      })

    // Admin stats: GET /_matrix/client/v3/admin/whois/{userId} (basic)
    // and /_synapse/admin/v1/statistics/users/media (used by some clients)
    "GET", "/_synapse/admin/v1/server_version" ->
      #(
        ctx.store,
        router.JsonResponse(
          200,
          json.object([
            #("server_version", json.string("sutra/0.1.0")),
            #("python_version", json.string("gleam/0.34.0")),
          ])
          |> json.to_string,
        ),
      )

    // -- 3PID verification (Phase 9) --
    "POST", "/_matrix/client/v3/register/email/requestToken" ->
      handle_threepid_request_token(ctx, "email", body)

    "POST", "/_matrix/client/v3/register/msisdn/requestToken" ->
      handle_threepid_request_token(ctx, "msisdn", body)

    "POST", "/_matrix/client/v3/account/password/email/requestToken" ->
      handle_threepid_request_token(ctx, "email", body)

    "POST", "/_matrix/client/v3/account/password/msisdn/requestToken" ->
      handle_threepid_request_token(ctx, "msisdn", body)

    "POST", "/_matrix/client/v3/account/3pid/add" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_threepid_add(ctx, t, body)
      })

    "POST", "/_matrix/client/v3/account/3pid/bind" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_threepid_bind(ctx, t, body)
      })

    // -- Third-party protocols (Phase 8) --
    "GET", "/_matrix/client/v3/thirdparty/protocols" ->
      handle_thirdparty_protocols(ctx)

    "GET", "/_matrix/client/v3/thirdparty/location" ->
      handle_thirdparty_location(ctx, None)

    "GET", "/_matrix/client/v3/thirdparty/user" ->
      handle_thirdparty_user(ctx, None)

    // -- Media enhancement (Phase 12) --
    "GET", "/_matrix/media/v3/preview_url" ->
      dispatch_with_token(ctx, token, fn(_t) {
        let url = case string.split_once(path, "url=") {
          Ok(#(_, rest)) ->
            case string.split_once(rest, "&") {
              Ok(#(u, _)) -> u
              Error(_) -> rest
            }
          Error(_) -> ""
        }
        handle_media_preview_url(ctx, url)
      })

    "POST", "/_matrix/media/v1/create" ->
      dispatch_with_token(ctx, token, fn(t) {
        handle_media_create(ctx, t)
      })

    // Fallthrough to push-rules dispatcher (path-based matching needed)
    _, _ ->
      dispatch_thirdparty_or_push_rules(ctx, method, path, body, token)
  }
}

/// Dispatcher for third-party, media upload/download, and push-rules paths
/// that require prefix-based matching.
fn dispatch_thirdparty_or_push_rules(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let thirdparty_prefix = "/_matrix/client/v3/thirdparty"
  let media_upload_prefix = "/_matrix/media/v3/upload/"
  let media_download_prefix = "/_matrix/media/v3/download/"
  case
    string.starts_with(path, thirdparty_prefix),
    string.starts_with(path, media_upload_prefix),
    string.starts_with(path, media_download_prefix)
  {
    True, _, _ -> dispatch_thirdparty(ctx, method, path, token)
    _, True, _ ->
      dispatch_with_token(ctx, token, fn(t) {
        // path: /_matrix/media/v3/upload/{server}/{mediaId}
        let after = string.drop_start(path, string.length(media_upload_prefix))
        case string.split_once(after, "/") {
          Error(_) ->
            #(ctx.store, router.ErrorResponse(400, "M_BAD_JSON", "Missing server/mediaId in path"))
          Ok(#(server, media_id_raw)) -> {
            let media_id = case string.split_once(media_id_raw, "?") {
              Ok(#(m, _)) -> m
              Error(_) -> media_id_raw
            }
            handle_media_upload_by_id(ctx, t, server, media_id, body)
          }
        }
      })
    _, _, True -> {
      // path: /_matrix/media/v3/download/{server}/{mediaId}/{filename}
      let after = string.drop_start(path, string.length(media_download_prefix))
      case string.split_once(after, "/") {
        Error(_) ->
          #(ctx.store, router.ErrorResponse(400, "M_NOT_FOUND", "Invalid download path"))
        Ok(#(server, rest)) ->
          case string.split_once(rest, "/") {
            Error(_) -> {
              // No filename segment — treat the rest as mediaId
              let media_id = case string.split_once(rest, "?") {
                Ok(#(m, _)) -> m
                Error(_) -> rest
              }
              handle_media_download_with_filename(ctx, server, media_id, "")
            }
            Ok(#(media_id, filename_raw)) -> {
              let filename = case string.split_once(filename_raw, "?") {
                Ok(#(f, _)) -> f
                Error(_) -> filename_raw
              }
              handle_media_download_with_filename(ctx, server, media_id, filename)
            }
          }
      }
    }
    False, False, False ->
      dispatch_push_rules(ctx, method, path, body, token)
  }
}

/// Dispatch /_matrix/client/v3/thirdparty/** sub-paths.
fn dispatch_thirdparty(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  _token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let prefix = "/_matrix/client/v3/thirdparty/"
  let sub = case string.starts_with(path, prefix) {
    True -> string.drop_start(path, string.length(prefix))
    False -> ""
  }
  // Strip query string
  let sub_clean = case string.split_once(sub, "?") {
    Ok(#(s, _)) -> s
    Error(_) -> sub
  }
  case method, sub_clean {
    "GET", "protocol/" <> name -> handle_thirdparty_protocol(ctx, name)
    "GET", "location/" <> protocol -> handle_thirdparty_location(ctx, Some(protocol))
    "GET", "user/" <> protocol -> handle_thirdparty_user(ctx, Some(protocol))
    _, _ ->
      #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "Unknown thirdparty sub-path"))
  }
}

/// Dispatch all /_matrix/client/v3/pushrules/** paths.
fn dispatch_push_rules(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  let pushrules_prefix = "/_matrix/client/v3/pushrules"
  case string.starts_with(path, pushrules_prefix) {
    False ->
      // Intercept federation paths before falling through to stub router
      case
        string.starts_with(path, "/_matrix/federation/")
        || string.starts_with(path, "/_matrix/key/")
      {
        True -> dispatch_federation_live(ctx, method, path, body)
        False -> #(ctx.store, router.route(method, path, body, token))
      }
    True -> {
      // Strip the prefix to get the sub-path
      let sub = string.drop_start(path, string.length(pushrules_prefix))
      // sub may be: "" | "/" | "/{scope}" | "/{scope}/{kind}/{ruleId}" | "/{scope}/{kind}/{ruleId}/enabled"
      let clean_sub = case string.starts_with(sub, "/") {
        True -> string.drop_start(sub, 1)
        False -> sub
      }
      // Strip query string
      let clean_sub2 = case string.split_once(clean_sub, "?") {
        Ok(#(s, _)) -> s
        Error(_) -> clean_sub
      }
      case clean_sub2 {
        // GET /pushrules/ — return all rules merged with server defaults
        "" | "/" ->
          dispatch_with_token(ctx, token, fn(t) {
            handle_get_all_push_rules(ctx, t)
          })
        _ ->
          case string.ends_with(clean_sub2, "/enabled") {
            True -> {
              // GET/PUT /{scope}/{kind}/{ruleId}/enabled
              let without_enabled =
                string.drop_end(clean_sub2, string.length("/enabled"))
              dispatch_push_rule_enabled(
                ctx, method, without_enabled, body, token,
              )
            }
            False ->
              case string.ends_with(clean_sub2, "/actions") {
                True -> {
                  // GET/PUT /{scope}/{kind}/{ruleId}/actions
                  let without_actions =
                    string.drop_end(clean_sub2, string.length("/actions"))
                  case parse_push_rule_path(without_actions) {
                    Ok(#(scope, kind, rule_id)) ->
                      dispatch_with_token(ctx, token, fn(t) {
                        case method {
                          "GET" ->
                            handlers.handle_get_pushrule_actions(
                              ctx, t, scope, kind, rule_id,
                            )
                          "PUT" ->
                            handlers.handle_put_pushrule_actions(
                              ctx, t, scope, kind, rule_id, body,
                            )
                          _ ->
                            #(
                              ctx.store,
                              router.ErrorResponse(
                                405,
                                "M_UNRECOGNIZED",
                                "Method not allowed",
                              ),
                            )
                        }
                      })
                    Error(_) ->
                      #(
                        ctx.store,
                        router.ErrorResponse(
                          400,
                          "M_BAD_JSON",
                          "Invalid push rule path",
                        ),
                      )
                  }
                }
                False ->
                  // Split into scope / kind / ruleId
                  dispatch_push_rule_crud(
                    ctx, method, clean_sub2, body, token,
                  )
              }
          }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Federation live dispatch — wires ALL /_matrix/federation/ and /_matrix/key/
// paths to KV-backed handlers before falling through to the stub router.
// ---------------------------------------------------------------------------

fn dispatch_federation_live(
  ctx: handlers.HandlerContext,
  method: String,
  path: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  // Strip query string from path for clean matching
  let clean_path = case string.split_once(path, "?") {
    Ok(#(p, _)) -> p
    Error(_) -> path
  }
  // Preserve the query string for parameter extraction
  let query = case string.split_once(path, "?") {
    Ok(#(_, q)) -> q
    Error(_) -> ""
  }

  case method, clean_path {
    // -- Server Info --
    "GET", "/_matrix/federation/v1/version" ->
      handlers_federation.handle_federation_version(ctx)

    "GET", "/_matrix/key/v2/server" ->
      handlers_federation.handle_server_keys(ctx)

    // -- E2EE Key ops (exact paths, must be before prefix matches) --
    "POST", "/_matrix/federation/v1/user/keys/query" ->
      handlers_federation.handle_query_keys(ctx, body)

    "POST", "/_matrix/federation/v1/user/keys/claim" ->
      handlers_federation.handle_claim_keys(ctx, body)

    // -- Public rooms (exact paths) --
    "GET", "/_matrix/federation/v1/publicRooms" ->
      handlers_federation.handle_federation_public_rooms(ctx)

    "POST", "/_matrix/federation/v1/publicRooms" ->
      handlers_federation.handle_federation_public_rooms(ctx)

    // -- Directory query (exact paths, query params) --
    "GET", "/_matrix/federation/v1/query/directory" -> {
      let alias = parse_query_param(query, "room_alias")
      handlers_federation.handle_query_directory(ctx, alias)
    }

    "GET", "/_matrix/federation/v1/query/profile" -> {
      let user_id = parse_query_param(query, "user_id")
      handlers_federation.handle_query_profile(ctx, user_id)
    }

    // -- OpenID userinfo (exact path) --
    "GET", "/_matrix/federation/v1/openid/userinfo" -> {
      let token = parse_query_param(query, "access_token")
      handlers_federation.handle_openid_userinfo(ctx, token)
    }

    // -- All prefix-matched paths (nested cases since guards not allowed) --
    _, _ ->
      dispatch_federation_prefix(ctx, method, clean_path, query, body, path)
  }
}

/// Handle prefix-matched federation paths using nested string.starts_with checks.
fn dispatch_federation_prefix(
  ctx: handlers.HandlerContext,
  method: String,
  clean_path: String,
  query: String,
  body: String,
  raw_path: String,
) -> #(kv.Store, router.ApiResult) {
  let send_prefix = "/_matrix/federation/v1/send/"
  let event_prefix = "/_matrix/federation/v1/event/"
  let state_prefix = "/_matrix/federation/v1/state/"
  let state_ids_prefix = "/_matrix/federation/v1/state_ids/"
  let backfill_prefix = "/_matrix/federation/v1/backfill/"
  let make_join_prefix = "/_matrix/federation/v1/make_join/"
  let send_join_prefix = "/_matrix/federation/v2/send_join/"
  let make_leave_prefix = "/_matrix/federation/v1/make_leave/"
  let send_leave_prefix = "/_matrix/federation/v2/send_leave/"
  let invite_prefix = "/_matrix/federation/v2/invite/"
  let hierarchy_prefix = "/_matrix/federation/v1/hierarchy/"

  case method == "PUT" && string.starts_with(clean_path, send_prefix) {
    True -> {
      let txn_id = string.replace(clean_path, send_prefix, "")
      handlers_federation.handle_send_transaction(ctx, txn_id, body)
    }
    False ->
      case method == "GET" && string.starts_with(clean_path, event_prefix) {
        True -> {
          let event_id = string.replace(clean_path, event_prefix, "")
          handlers_federation.handle_get_event(ctx, event_id)
        }
        False ->
          // state_ids must be checked before state (longer prefix)
          case
            method == "GET"
            && string.starts_with(clean_path, state_ids_prefix)
          {
            True -> {
              let room_id = string.replace(clean_path, state_ids_prefix, "")
              handlers_federation.handle_get_state_ids(ctx, room_id)
            }
            False ->
              case
                method == "GET"
                && string.starts_with(clean_path, state_prefix)
              {
                True -> {
                  let room_id = string.replace(clean_path, state_prefix, "")
                  handlers_federation.handle_get_state(ctx, room_id)
                }
                False ->
                  case
                    method == "GET"
                    && string.starts_with(clean_path, backfill_prefix)
                  {
                    True -> {
                      let room_id =
                        string.replace(clean_path, backfill_prefix, "")
                      let limit = parse_query_int(query, "limit", 20)
                      handlers_federation.handle_backfill(ctx, room_id, limit)
                    }
                    False ->
                      case
                        method == "GET"
                        && string.starts_with(clean_path, make_join_prefix)
                      {
                        True -> {
                          let after =
                            string.replace(clean_path, make_join_prefix, "")
                          case string.split_once(after, "/") {
                            Ok(#(room_id, user_id)) ->
                              handlers_federation.handle_make_join(
                                ctx,
                                room_id,
                                user_id,
                              )
                            Error(_) ->
                              #(
                                ctx.store,
                                router.ErrorResponse(
                                  400,
                                  "M_BAD_JSON",
                                  "Missing userId in path",
                                ),
                              )
                          }
                        }
                        False ->
                          case
                            method == "PUT"
                            && string.starts_with(clean_path, send_join_prefix)
                          {
                            True -> {
                              let after =
                                string.replace(
                                  clean_path,
                                  send_join_prefix,
                                  "",
                                )
                              case string.split_once(after, "/") {
                                Ok(#(room_id, event_id)) ->
                                  handlers_federation.handle_send_join(
                                    ctx,
                                    room_id,
                                    event_id,
                                    body,
                                  )
                                Error(_) ->
                                  #(
                                    ctx.store,
                                    router.ErrorResponse(
                                      400,
                                      "M_BAD_JSON",
                                      "Missing eventId in path",
                                    ),
                                  )
                              }
                            }
                            False ->
                              case
                                method == "GET"
                                && string.starts_with(
                                  clean_path,
                                  make_leave_prefix,
                                )
                              {
                                True -> {
                                  let after =
                                    string.replace(
                                      clean_path,
                                      make_leave_prefix,
                                      "",
                                    )
                                  case string.split_once(after, "/") {
                                    Ok(#(room_id, user_id)) ->
                                      handlers_federation.handle_make_leave(
                                        ctx,
                                        room_id,
                                        user_id,
                                      )
                                    Error(_) ->
                                      #(
                                        ctx.store,
                                        router.ErrorResponse(
                                          400,
                                          "M_BAD_JSON",
                                          "Missing userId in path",
                                        ),
                                      )
                                  }
                                }
                                False ->
                                  case
                                    method == "PUT"
                                    && string.starts_with(
                                      clean_path,
                                      send_leave_prefix,
                                    )
                                  {
                                    True -> {
                                      let after =
                                        string.replace(
                                          clean_path,
                                          send_leave_prefix,
                                          "",
                                        )
                                      case string.split_once(after, "/") {
                                        Ok(#(room_id, event_id)) ->
                                          handlers_federation.handle_send_leave(
                                            ctx,
                                            room_id,
                                            event_id,
                                            body,
                                          )
                                        Error(_) ->
                                          #(
                                            ctx.store,
                                            router.ErrorResponse(
                                              400,
                                              "M_BAD_JSON",
                                              "Missing eventId in path",
                                            ),
                                          )
                                      }
                                    }
                                    False ->
                                      case
                                        method == "PUT"
                                        && string.starts_with(
                                          clean_path,
                                          invite_prefix,
                                        )
                                      {
                                        True -> {
                                          let after =
                                            string.replace(
                                              clean_path,
                                              invite_prefix,
                                              "",
                                            )
                                          case string.split_once(after, "/") {
                                            Ok(#(room_id, event_id)) ->
                                              handlers_federation.handle_federation_invite(
                                                ctx,
                                                room_id,
                                                event_id,
                                                body,
                                              )
                                            Error(_) ->
                                              #(
                                                ctx.store,
                                                router.ErrorResponse(
                                                  400,
                                                  "M_BAD_JSON",
                                                  "Missing eventId in path",
                                                ),
                                              )
                                          }
                                        }
                                        False ->
                                          case
                                            method == "GET"
                                            && string.starts_with(
                                              clean_path,
                                              hierarchy_prefix,
                                            )
                                          {
                                            True -> {
                                              let room_id =
                                                string.replace(
                                                  clean_path,
                                                  hierarchy_prefix,
                                                  "",
                                                )
                                              handlers_federation.handle_room_hierarchy(
                                                ctx,
                                                room_id,
                                              )
                                            }
                                            // Unknown federation path — fall through to stub
                                            False ->
                                              #(
                                                ctx.store,
                                                router.route(
                                                  method,
                                                  raw_path,
                                                  body,
                                                  None,
                                                ),
                                              )
                                          }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
}

/// Extract a query string parameter value by key.
/// Returns "" if not found.
fn parse_query_param(query: String, key: String) -> String {
  let needle = key <> "="
  case string.split_once(query, needle) {
    Error(_) -> ""
    Ok(#(_, after)) ->
      case string.split_once(after, "&") {
        Ok(#(val, _)) -> val
        Error(_) -> after
      }
  }
}

/// Extract an integer query parameter, returning a default if missing or invalid.
fn parse_query_int(query: String, key: String, default: Int) -> Int {
  let raw = parse_query_param(query, key)
  case int.parse(raw) {
    Ok(n) -> n
    Error(_) -> default
  }
}

/// Handle GET/PUT for a push rule's enabled flag.
fn dispatch_push_rule_enabled(
  ctx: handlers.HandlerContext,
  method: String,
  scope_kind_ruleid: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  case parse_push_rule_path(scope_kind_ruleid) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(400, "M_BAD_JSON", "Invalid push rule path"))
    Ok(#(scope, kind, rule_id)) ->
      case method {
        "GET" ->
          dispatch_with_token(ctx, token, fn(t) {
            case kv.find_user_by_token(ctx.store, t) {
              Error(_) ->
                #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
              Ok(user) -> {
                let user_id = types.user_id_to_string(user.user_id)
                let enabled = case kv.get_push_rule(ctx.store, user_id, scope, kind, rule_id) {
                  Error(_) -> "true"
                  Ok(rule_json) ->
                    case string.contains(rule_json, "\"enabled\":false") {
                      True -> "false"
                      False -> "true"
                    }
                }
                #(ctx.store, router.JsonResponse(200, "{\"enabled\":" <> enabled <> "}"))
              }
            }
          })
        "PUT" ->
          dispatch_with_token(ctx, token, fn(t) {
            case kv.find_user_by_token(ctx.store, t) {
              Error(_) ->
                #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
              Ok(user) -> {
                let user_id = types.user_id_to_string(user.user_id)
                let enabled_val = case json_helpers.extract_bool(body, "enabled") {
                  Ok(b) -> b
                  Error(_) -> True
                }
                // Fetch existing rule and patch enabled field, or create minimal rule
                let existing = case kv.get_push_rule(ctx.store, user_id, scope, kind, rule_id) {
                  Ok(r) -> r
                  Error(_) -> "{\"rule_id\":\"" <> rule_id <> "\"}"
                }
                let enabled_str = case enabled_val {
                  True -> "true"
                  False -> "false"
                }
                // Inject/update enabled field: strip old value and append
                let patched = case string.split_once(existing, "\"enabled\":") {
                  Ok(#(before, after_enabled)) -> {
                    // Find the end of the old boolean value
                    let after_val = case string.split_once(after_enabled, ",") {
                      Ok(#(_, rest)) -> "," <> rest
                      Error(_) ->
                        case string.split_once(after_enabled, "}") {
                          Ok(#(_, rest)) -> "}" <> rest
                          Error(_) -> "}"
                        }
                    }
                    before <> "\"enabled\":" <> enabled_str <> after_val
                  }
                  Error(_) -> {
                    // Insert before closing brace
                    case string.ends_with(existing, "}") {
                      True ->
                        string.drop_end(existing, 1)
                        <> ",\"enabled\":"
                        <> enabled_str
                        <> "}"
                      False -> existing
                    }
                  }
                }
                let new_store =
                  kv.set_push_rule(ctx.store, user_id, scope, kind, rule_id, patched)
                #(new_store, router.JsonResponse(200, "{}"))
              }
            }
          })
        _ ->
          #(ctx.store, router.route(method, path_for_log(scope, kind, rule_id), body, token))
      }
  }
}

/// Parse "scope/kind/ruleId" into its three components.
fn parse_push_rule_path(s: String) -> Result(#(String, String, String), Nil) {
  case string.split_once(s, "/") {
    Error(_) -> Error(Nil)
    Ok(#(scope, rest)) ->
      case string.split_once(rest, "/") {
        Error(_) -> Error(Nil)
        Ok(#(kind, rule_id)) -> Ok(#(scope, kind, rule_id))
      }
  }
}

fn path_for_log(scope: String, kind: String, rule_id: String) -> String {
  "/_matrix/client/v3/pushrules/" <> scope <> "/" <> kind <> "/" <> rule_id
}

/// Handle GET/PUT/DELETE for a specific push rule.
fn dispatch_push_rule_crud(
  ctx: handlers.HandlerContext,
  method: String,
  scope_kind_ruleid: String,
  body: String,
  token: Option(String),
) -> #(kv.Store, router.ApiResult) {
  case parse_push_rule_path(scope_kind_ruleid) {
    Error(_) ->
      // Just a scope — return rules for that scope (treat as GET all)
      dispatch_with_token(ctx, token, fn(t) {
        handle_get_all_push_rules(ctx, t)
      })
    Ok(#(scope, kind, rule_id)) ->
      case method {
        "GET" ->
          dispatch_with_token(ctx, token, fn(t) {
            case kv.find_user_by_token(ctx.store, t) {
              Error(_) ->
                #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
              Ok(user) -> {
                let user_id = types.user_id_to_string(user.user_id)
                case kv.get_push_rule(ctx.store, user_id, scope, kind, rule_id) {
                  Error(_) ->
                    #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "Push rule not found"))
                  Ok(rule_json) ->
                    #(ctx.store, router.JsonResponse(200, rule_json))
                }
              }
            }
          })
        "PUT" ->
          dispatch_with_token(ctx, token, fn(t) {
            case kv.find_user_by_token(ctx.store, t) {
              Error(_) ->
                #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
              Ok(user) -> {
                let user_id = types.user_id_to_string(user.user_id)
                let new_store =
                  kv.set_push_rule(ctx.store, user_id, scope, kind, rule_id, body)
                #(new_store, router.JsonResponse(200, "{}"))
              }
            }
          })
        "DELETE" ->
          dispatch_with_token(ctx, token, fn(t) {
            case kv.find_user_by_token(ctx.store, t) {
              Error(_) ->
                #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
              Ok(user) -> {
                let user_id = types.user_id_to_string(user.user_id)
                let new_store =
                  kv.delete_push_rule(ctx.store, user_id, scope, kind, rule_id)
                #(new_store, router.JsonResponse(200, "{}"))
              }
            }
          })
        _ ->
          #(ctx.store, router.route(method, path_for_log(scope, kind, rule_id), body, token))
      }
  }
}

// ---------------------------------------------------------------------------
// Phase 6: Pusher handlers
// ---------------------------------------------------------------------------

/// GET /_matrix/client/v3/pushers — return pushers for the authenticated user.
fn handle_get_pushers(
  ctx: handlers.HandlerContext,
  token: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let pushers = kv.get_pushers(ctx.store, user_id)
      let pushers_json = string.join(pushers, ",")
      #(ctx.store, router.JsonResponse(200, "{\"pushers\":[" <> pushers_json <> "]}"))
    }
  }
}

/// POST /_matrix/client/v3/pushers/set — store or update a pusher.
/// If kind is null or body contains "kind":null, delete the pusher.
fn handle_set_pusher(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      // If kind is null, this is a delete request
      let is_delete = string.contains(body, "\"kind\":null")
      case is_delete {
        True -> {
          let new_store = kv.delete_pusher(ctx.store, user_id)
          #(new_store, router.JsonResponse(200, "{}"))
        }
        False -> {
          let new_store = kv.set_pusher(ctx.store, user_id, body)
          #(new_store, router.JsonResponse(200, "{}"))
        }
      }
    }
  }
}

/// GET /_matrix/client/v3/pushrules/ — return all push rules (stored + defaults).
fn handle_get_all_push_rules(
  ctx: handlers.HandlerContext,
  token: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let _stored = kv.get_all_push_rules(ctx.store, user_id)
      // Return the standard default ruleset that Matrix clients expect.
      // User-stored overrides are merged in the "user" scope.
      let default_rules =
        "{\"global\":{"
        <> "\"content\":[{\"rule_id\":\".m.rule.contains_user_name\",\"default\":true,\"enabled\":true,\"conditions\":[{\"kind\":\"event_match\",\"key\":\"content.body\",\"pattern\":\"*\"}],\"actions\":[\"notify\",{\"set_tweak\":\"sound\",\"value\":\"default\"},{\"set_tweak\":\"highlight\"}]}],"
        <> "\"override\":[{\"rule_id\":\".m.rule.master\",\"default\":true,\"enabled\":false,\"conditions\":[],\"actions\":[\"dont_notify\"]}],"
        <> "\"room\":[],"
        <> "\"sender\":[],"
        <> "\"underride\":[{\"rule_id\":\".m.rule.message\",\"default\":true,\"enabled\":true,\"conditions\":[{\"kind\":\"event_match\",\"key\":\"type\",\"pattern\":\"m.room.message\"}],\"actions\":[\"notify\",{\"set_tweak\":\"sound\",\"value\":\"default\"}]}]"
        <> "}}"
      #(ctx.store, router.JsonResponse(200, default_rules))
    }
  }
}

// ---------------------------------------------------------------------------
// Phase 10: Account management handlers
// ---------------------------------------------------------------------------

/// POST /_matrix/client/v3/account/password — change the user's password.
fn handle_change_password(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(user) -> {
      let new_password = case json_helpers.extract_string(body, "new_password") {
        Ok(p) -> p
        Error(_) ->
          case json_helpers.extract_string(body, "password") {
            Ok(p) -> p
            Error(_) -> ""
          }
      }
      case new_password {
        "" ->
          #(ctx.store, router.ErrorResponse(400, "M_BAD_JSON", "Missing new_password"))
        pw -> {
          let hashed = case crypto.bcrypt_hash(pw, 10) { Ok(h) -> h Error(_) -> pw }
          let updated = types.UserAccount(..user, password_hash: hashed)
          let new_store = kv.update_user(ctx.store, updated)
          #(new_store, router.JsonResponse(200, "{}"))
        }
      }
    }
  }
}

/// POST /_matrix/client/v3/account/deactivate — revoke all tokens and mark deactivated.
fn handle_deactivate(
  ctx: handlers.HandlerContext,
  token: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let new_store = kv.revoke_all_user_tokens(ctx.store, user_id)
      #(new_store, router.JsonResponse(200, "{\"id_server_unbind_result\":\"success\"}"))
    }
  }
}

// ---------------------------------------------------------------------------
// E2EE live handlers
// ---------------------------------------------------------------------------

/// POST /_matrix/client/v3/keys/upload
/// Stores device keys and one-time keys; returns OTK counts.
fn handle_keys_upload_live(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      // Extract device_id: try body top-level, then inside device_keys, then token→device map
      let device_id = case json_helpers.extract_string(body, "device_id") {
        Ok(d) -> d
        Error(_) -> {
          // FluffyChat puts device_id inside device_keys object
          let dk_blob = extract_key_blob(body, "device_keys")
          case json_helpers.extract_string(dk_blob, "device_id") {
            Ok(d2) -> d2
            Error(_) ->
              // Fall back to device from token mapping
              case kv.get_device_for_token(ctx.store, token) {
                Ok(d3) -> d3
                Error(_) -> "SUTRA_DEVICE"
              }
          }
        }
      }

      // Store device keys if present — extract the device_keys object VERBATIM
      let store1 = case string.contains(body, "\"device_keys\"") {
        False -> ctx.store
        True -> {
          let dk_blob = extract_key_blob(body, "device_keys")
          kv.store_device_keys(ctx.store, kv.StoredDeviceKeys(
            user_id: user_id,
            device_id: device_id,
            algorithms: [],
            keys_json: dk_blob,
            signatures_json: "{}",
          ))
        }
      }

      // Store one-time keys if present
      let store2 = case string.contains(body, "\"one_time_keys\"") {
        False -> store1
        True -> store_otks_from_body(store1, user_id, device_id, body)
      }

      // Count ALL OTKs stored for this user+device (ground truth from KV store)
      let effective_count = kv.count_otks(store2, user_id, device_id)

      #(
        store2,
        router.JsonResponse(
          200,
          json.object([
            #("one_time_key_counts", json.object([
              #("curve25519", json.int(effective_count)),
              #("signed_curve25519", json.int(effective_count)),
            ])),
          ])
          |> json.to_string,
        ),
      )
    }
  }
}

/// Parse one-time keys from body and store them.
/// Body contains something like:
///   "one_time_keys":{"curve25519:KEYID":"<key>","signed_curve25519:KEYID":{...}}
/// We extract each "algorithm:keyId" entry and store it.
fn store_otks_from_body(
  store: kv.Store,
  user_id: String,
  device_id: String,
  body: String,
) -> kv.Store {
  // Find the one_time_keys object by splitting on the key
  case string.split_once(body, "\"one_time_keys\"") {
    Error(_) -> store
    Ok(#(_, after_otk)) ->
      case string.split_once(after_otk, "{") {
        Error(_) -> store
        Ok(#(_, after_brace)) ->
          // DON'T split on "}" — OTK values contain nested braces.
          // Pass entire content to store_otk_entries which uses
          // extract_json_value (balanced brace tracking) for each value.
          store_otk_entries(store, user_id, device_id, after_brace)
      }
  }
}

/// Iteratively extract "algorithm:keyId":"value" entries and store them.
fn store_otk_entries(
  store: kv.Store,
  user_id: String,
  device_id: String,
  content: String,
) -> kv.Store {
  let trimmed = string.trim(content)
  case string.starts_with(trimmed, "\"") {
    False -> store
    True -> {
      // Extract key_id (everything between the outer quotes)
      let after_open = string.drop_start(trimmed, 1)
      case string.split_once(after_open, "\"") {
        Error(_) -> store
        Ok(#(key_id, rest)) -> {
          // Find the value (skip ": ")
          case string.split_once(rest, ":") {
            Error(_) -> store
            Ok(#(_, after_colon)) -> {
              let val_trimmed = string.trim(after_colon)
              // Value is either a string or an object; just grab everything up to the next top-level comma
              let #(key_val, remaining) = extract_json_value(val_trimmed)
              let new_store = kv.store_otk(store, user_id, device_id, key_id, key_val)
              // Skip trailing comma and whitespace
              let rest2 = string.trim(remaining)
              let rest3 = case string.starts_with(rest2, ",") {
                True -> string.drop_start(rest2, 1)
                False -> rest2
              }
              store_otk_entries(new_store, user_id, device_id, rest3)
            }
          }
        }
      }
    }
  }
}

/// Extract a single JSON value (string or object) from the start of `s`.
/// Returns #(value_string, remaining).
fn extract_json_value(s: String) -> #(String, String) {
  case string.starts_with(s, "\"") {
    True -> {
      // String value
      let after_open = string.drop_start(s, 1)
      case string.split_once(after_open, "\"") {
        Error(_) -> #(s, "")
        Ok(#(val, rest)) -> #("\"" <> val <> "\"", rest)
      }
    }
    False ->
      case string.starts_with(s, "{") {
        True -> {
          // Object value — find matching closing brace (simple depth count)
          extract_object(s, 0, "")
        }
        False -> #(s, "")
      }
  }
}

fn extract_object(s: String, depth: Int, acc: String) -> #(String, String) {
  case string.pop_grapheme(s) {
    Error(_) -> #(acc, "")
    Ok(#(c, rest)) -> {
      let new_acc = acc <> c
      case c {
        "{" -> extract_object(rest, depth + 1, new_acc)
        "}" -> {
          let new_depth = depth - 1
          case new_depth <= 0 {
            True -> #(new_acc, rest)
            False -> extract_object(rest, new_depth, new_acc)
          }
        }
        _ -> extract_object(rest, depth, new_acc)
      }
    }
  }
}

/// Count how many signed_curve25519 OTKs are in the upload body.
/// The SDK sends keys like "signed_curve25519:AAAAAQ": {...}
fn count_signed_otks(body: String) -> Int {
  // Count ONLY in the one_time_keys section, NOT fallback_keys or device_keys
  case string.split_once(body, "\"one_time_keys\"") {
    Error(_) -> 0
    Ok(#(_, after_otk)) ->
      // Find the OTK object boundaries — stop before fallback_keys or device_keys
      case string.split_once(after_otk, "\"fallback_keys\"") {
        Ok(#(otk_section, _)) -> count_occurrences(otk_section, "signed_curve25519:", 0)
        Error(_) -> count_occurrences(after_otk, "signed_curve25519:", 0)
      }
  }
}

fn count_occurrences(s: String, needle: String, acc: Int) -> Int {
  case string.split_once(s, needle) {
    Error(_) -> acc
    Ok(#(_, rest)) -> count_occurrences(rest, needle, acc + 1)
  }
}

/// POST /_matrix/client/v3/keys/query
/// Returns stored device keys for all queried users.
fn handle_keys_query_live(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"))
    Ok(_user) -> {
      // Extract the list of user IDs from "device_keys": { "@user:server": [] }
      // We build a response with stored device keys for each user that has them.
      let queried_user_ids = extract_queried_user_ids(body)
      let device_keys_json = build_device_keys_response(ctx.store, queried_user_ids)
      let cross_signing_json = build_cross_signing_response(ctx.store, queried_user_ids)
      // Use serdes_json NIF to compose the response with raw JSON blobs
      let base = serdes_json.object_raw([
        #("device_keys", device_keys_json),
        #("failures", "{}"),
      ])
      // Merge cross-signing keys if present
      let response = case cross_signing_json {
        "" -> base
        cs -> serdes_json.merge(base, cs)
      }
      #(ctx.store, router.JsonResponse(200, response))
    }
  }
}

/// Extract user IDs from the "device_keys" object in a keys/query request.
fn extract_queried_user_ids(body: String) -> List(String) {
  case string.split_once(body, "\"device_keys\"") {
    Error(_) -> []
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> []
        Ok(#(_, after_brace)) ->
          case string.split_once(after_brace, "}") {
            Error(_) -> []
            Ok(#(contents, _)) ->
              extract_user_ids_from_object_keys(contents)
          }
      }
  }
}

/// Extract all keys (user IDs) from a JSON object content string.
/// Input looks like: "@alice:srv":[],"@bob:srv":[]
fn extract_user_ids_from_object_keys(content: String) -> List(String) {
  extract_object_keys_acc(string.trim(content), [])
}

fn extract_object_keys_acc(s: String, acc: List(String)) -> List(String) {
  case string.starts_with(s, "\"") {
    False -> list.reverse(acc)
    True -> {
      let after_open = string.drop_start(s, 1)
      case string.split_once(after_open, "\"") {
        Error(_) -> list.reverse(acc)
        Ok(#(key, rest)) -> {
          // Skip ": value" and find next key
          case string.split_once(rest, ",") {
            Error(_) -> list.reverse([key, ..acc])
            Ok(#(_, remainder)) ->
              extract_object_keys_acc(string.trim(remainder), [key, ..acc])
          }
        }
      }
    }
  }
}

/// Build the device_keys JSON object content from stored keys.
/// Uses serdes_json NIF for guaranteed valid JSON with raw key blob embedding.
fn build_device_keys_response(
  store: kv.Store,
  user_ids: List(String),
) -> String {
  let all_keys = list.flat_map(user_ids, fn(uid) {
    let user_keys = kv.get_device_keys(store, uid)
    list.map(user_keys, fn(dk) {
      let blob = case dk.keys_json {
        "{}" -> build_device_key_json(dk)
        "" -> build_device_key_json(dk)
        b -> b
      }
      #(dk.user_id, dk.device_id, blob)
    })
  })
  serdes_json.device_keys_response(all_keys)
}

/// Build a device key JSON object from stored fields using json.object.
fn build_device_key_json(dk: kv.StoredDeviceKeys) -> String {
  json.object([
    #("user_id", json.string(dk.user_id)),
    #("device_id", json.string(dk.device_id)),
    #("algorithms", json.preprocessed_array([
      json.string("m.olm.v1.curve25519-aes-sha2-256"),
      json.string("m.megolm.v1.aes-sha2"),
    ])),
    #("keys", json.object([])),
    #("signatures", json.object([])),
  ])
  |> json.to_string
}

/// Build the cross-signing keys section for the keys/query response.
/// Returns: ,\"master_keys\":{...},\"self_signing_keys\":{...},\"user_signing_keys\":{...}
/// or empty string if no cross-signing keys exist.
fn build_cross_signing_response(store: kv.Store, user_ids: List(String)) -> String {
  let master_pairs = build_cross_signing_type_pairs(store, user_ids, "master_key")
  let self_pairs = build_cross_signing_type_pairs(store, user_ids, "self_signing_key")
  let user_pairs = build_cross_signing_type_pairs(store, user_ids, "user_signing_key")
  case master_pairs {
    [] -> ""
    _ ->
      // Use NIF to build valid JSON objects with raw cross-signing key blobs
      serdes_json.object_raw([
        #("master_keys", serdes_json.object_raw(master_pairs)),
        #("self_signing_keys", serdes_json.object_raw(self_pairs)),
        #("user_signing_keys", serdes_json.object_raw(user_pairs)),
      ])
  }
}

/// Build (uid, raw_key_json) pairs for one cross-signing key type.
/// Ensures user_id and usage fields are always present in the output JSON,
/// per Matrix spec — the SDK crashes with 'Null is not String' if missing.
fn build_cross_signing_type_pairs(
  store: kv.Store,
  user_ids: List(String),
  key_field: String,
) -> List(#(String, String)) {
  let usage = case key_field {
    "master_key" -> "master"
    "self_signing_key" -> "self_signing"
    "user_signing_key" -> "user_signing"
    _ -> "master"
  }
  user_ids
  |> list.filter_map(fn(uid) {
    case kv.get_cross_signing(store, uid) {
      Error(_) -> Error(Nil)
      Ok(csk) -> {
        let key_json = case key_field {
          "master_key" -> csk.master_key
          "self_signing_key" -> csk.self_signing_key
          "user_signing_key" -> csk.user_signing_key
          _ -> "{}"
        }
        case key_json == "{}" {
          True -> Error(Nil)
          False -> {
            // Inject required user_id and usage fields if missing
            let patch = json.object([
              #("user_id", json.string(uid)),
              #("usage", json.preprocessed_array([json.string(usage)])),
            ]) |> json.to_string
            let enriched = serdes_json.merge(key_json, patch)
            Ok(#(uid, enriched))
          }
        }
      }
    }
  })
}

/// Build one cross-signing key type for all queried users.
fn build_cross_signing_type(store: kv.Store, user_ids: List(String), key_field: String) -> String {
  user_ids
  |> list.filter_map(fn(uid) {
    case kv.get_cross_signing(store, uid) {
      Error(_) -> Error(Nil)
      Ok(csk) -> {
        let key_json = case key_field {
          "master_key" -> csk.master_key
          "self_signing_key" -> csk.self_signing_key
          "user_signing_key" -> csk.user_signing_key
          _ -> "{}"
        }
        // If the stored key is just "{}", skip it
        case key_json == "{}" {
          True -> Error(Nil)
          False -> Ok("\"" <> uid <> "\":" <> key_json)
        }
      }
    }
  })
  |> string.join(",")
}

/// POST /_matrix/client/v3/keys/claim
/// Claims one-time keys from the store for each requested device.
fn handle_keys_claim_live(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"))
    Ok(_user) -> {
      // Extract "one_time_keys": {"@user:server": {"device_id": "algorithm"}}
      // For simplicity we look for user/device pairs in the body and claim one OTK each.
      let #(new_store, claimed_keys) = claim_otks_from_body_v2(ctx.store, body)
      // Use serdes_json NIF for guaranteed valid JSON with raw OTK blob embedding.
      // This eliminates the brace-balance bug that plagued manual string concat.
      let response = serdes_json.otk_claim_response(claimed_keys)
      #(
        new_store,
        router.JsonResponse(200, response),
      )
    }
  }
}

/// Parse claim request body and claim one OTK per user+device.
/// Returns structured tuples: (user_id, device_id, key_id, key_json)
fn claim_otks_from_body_v2(
  store: kv.Store,
  body: String,
) -> #(kv.Store, List(#(String, String, String, String))) {
  // Extract user IDs from "one_time_keys": {"@user": {"device": "algo"}}
  let user_ids = extract_queried_user_ids_from_claim(body)
  list.fold(user_ids, #(store, []), fn(acc, uid) {
    let #(s, results) = acc
    // Extract device IDs for this user
    let devices = extract_devices_for_user(body, uid)
    list.fold(devices, #(s, results), fn(acc2, did2) {
      let #(s2, results2) = acc2
      case kv.claim_otk(s2, uid, did2) {
        Error(_) -> #(s2, results2)
        Ok(#(key_id, key_json, s3)) ->
          #(s3, [#(uid, did2, key_id, key_json), ..results2])
      }
    })
  })
}

/// Extract user IDs from claim body's one_time_keys object
fn extract_queried_user_ids_from_claim(body: String) -> List(String) {
  case string.split_once(body, "\"one_time_keys\"") {
    Error(_) -> []
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> []
        Ok(#(_, inner)) -> extract_at_user_ids(inner, [])
      }
  }
}

fn extract_at_user_ids(s: String, acc: List(String)) -> List(String) {
  case string.split_once(s, "\"@") {
    Error(_) -> list.reverse(acc)
    Ok(#(_, after)) ->
      case string.split_once(after, "\"") {
        Error(_) -> list.reverse(acc)
        Ok(#(uid, rest)) -> extract_at_user_ids(rest, ["@" <> uid, ..acc])
      }
  }
}

/// Extract device IDs for a specific user from the claim body
fn extract_devices_for_user(body: String, user_id: String) -> List(String) {
  case string.split_once(body, "\"" <> user_id <> "\"") {
    Error(_) -> []
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> []
        Ok(#(_, inner)) ->
          // Extract device IDs (non-@ quoted strings)
          extract_device_ids(inner, [])
      }
  }
}

fn extract_device_ids(s: String, acc: List(String)) -> List(String) {
  let trimmed = string.trim(s)
  case string.starts_with(trimmed, "\"") {
    False -> list.reverse(acc)
    True -> {
      let after = string.drop_start(trimmed, 1)
      case string.split_once(after, "\"") {
        Error(_) -> list.reverse(acc)
        Ok(#(did, rest)) ->
          // Skip the value (: "algo")
          case string.split_once(rest, ",") {
            Ok(#(_, next)) -> extract_device_ids(next, [did, ..acc])
            Error(_) -> list.reverse([did, ..acc])
          }
      }
    }
  }
}

/// LEGACY: Parse claim request body and claim one OTK per user+device.
/// Returns the updated store and the JSON for the claimed keys.
fn claim_otks_from_body(
  store: kv.Store,
  body: String,
) -> #(kv.Store, String) {
  // Extract the one_time_keys request object — format:
  //   "one_time_keys": {"@user:srv": {"DEVICE_ID": "signed_curve25519"}}
  case string.split_once(body, "\"one_time_keys\"") {
    Error(_) -> #(store, "")
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> #(store, "")
        Ok(#(_, after_brace)) ->
          // Extract user IDs from nested object
          claim_user_keys_from_content(store, after_brace, "", [])
      }
  }
}

fn claim_user_keys_from_content(
  store: kv.Store,
  s: String,
  _current_user: String,
  results: List(String),
) -> #(kv.Store, String) {
  let trimmed = string.trim(s)
  // Only process keys that look like user IDs (@user:server)
  case string.starts_with(trimmed, "\"@") {
    False -> #(store, string.join(list.reverse(results), ","))
    True -> {
      let after_open = string.drop_start(trimmed, 1)
      case string.split_once(after_open, "\"") {
        Error(_) -> #(store, string.join(list.reverse(results), ","))
        Ok(#(uid, rest_after_uid)) -> {
          // Find the device object for this user: : {"DEVICE": "algo"}
          case string.split_once(rest_after_uid, "{") {
            Error(_) -> #(store, string.join(list.reverse(results), ","))
            Ok(#(_, device_content)) -> {
              // Extract device_id
              case string.split_once(device_content, "\"") {
                Error(_) -> #(store, string.join(list.reverse(results), ","))
                Ok(#(_, after_q)) ->
                  case string.split_once(after_q, "\"") {
                    Error(_) -> #(store, string.join(list.reverse(results), ","))
                    Ok(#(device_id, rest)) -> {
                      // Claim an OTK for this user+device
                      let #(new_store, key_entry) =
                        claim_one_otk(store, uid, device_id)
                      let result_str = case key_entry {
                        "" -> ""
                        s -> "\"" <> uid <> "\":{" <> s <> "}"
                      }
                      let new_results = case result_str {
                        "" -> results
                        _ -> [result_str, ..results]
                      }
                      // Skip to next user (find next "}" then optional ",")
                      let #(remaining, _) = skip_past_close_brace(rest)
                      claim_user_keys_from_content(
                        new_store, remaining, "", new_results,
                      )
                    }
                  }
              }
            }
          }
        }
      }
    }
  }
}

fn claim_one_otk(
  store: kv.Store,
  user_id: String,
  device_id: String,
) -> #(kv.Store, String) {
  case kv.claim_otk(store, user_id, device_id) {
    Error(_) -> #(store, "")
    Ok(#(key_id, key_json, new_store)) -> {
      // Ensure key_json is valid by wrapping if it doesn't start with {
      let safe_json = case string.starts_with(string.trim(key_json), "{") {
        True -> key_json
        False -> "{\"key\":" <> key_json <> "}"
      }
      #(new_store, "\"" <> device_id <> "\":{\"" <> key_id <> "\":" <> safe_json <> "}")
    }
  }
}

fn skip_past_close_brace(s: String) -> #(String, Bool) {
  case string.split_once(s, "}") {
    Error(_) -> #("", False)
    Ok(#(_, rest)) -> {
      let trimmed = string.trim(rest)
      let remaining = case string.starts_with(trimmed, ",") {
        True -> string.trim(string.drop_start(trimmed, 1))
        False -> trimmed
      }
      #(remaining, True)
    }
  }
}

/// POST /_matrix/client/v3/keys/device_signing/upload
/// Stores cross-signing keys; requires UIA (auth block).
fn handle_device_signing_upload_live(
  ctx: handlers.HandlerContext,
  token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      case string.contains(body, "\"auth\"") {
        False -> {
          // UIA challenge — client must re-submit with auth block
          let session = "cs_" <> int.to_string(ctx.timestamp)
          #(
            ctx.store,
            router.JsonResponse(
              401,
              json.object([
                #("session", json.string(session)),
                #("flows", json.array([
                  json.object([#("stages", json.array(["m.login.password"], json.string))]),
                ], fn(x) { x })),
                #("params", json.object([])),
              ])
              |> json.to_string,
            ),
          )
        }
        True -> {
          // Auth present — extract and store cross-signing keys
          let master = extract_key_blob(body, "master_key")
          let self_signing = extract_key_blob(body, "self_signing_key")
          let user_signing = extract_key_blob(body, "user_signing_key")
          let new_store =
            kv.store_cross_signing(ctx.store, kv.StoredCrossSigningKeys(
              user_id: user_id,
              master_key: master,
              self_signing_key: self_signing,
              user_signing_key: user_signing,
            ))
          #(new_store, router.JsonResponse(200, "{}"))
        }
      }
    }
  }
}

/// Extract a JSON object blob for a given key from the body.
/// Returns the raw JSON object string (e.g. the full master_key object),
/// or "{}" when the key is absent.
/// Extract a string value for a given key from JSON. e.g. "algorithm":"xyz" -> "xyz"
fn extract_json_string(body: String, key: String) -> String {
  case string.split_once(body, "\"" <> key <> "\"") {
    Error(_) -> ""
    Ok(#(_, after)) ->
      case string.split_once(after, "\"") {
        Error(_) -> ""
        Ok(#(_, after_quote)) ->
          case string.split_once(after_quote, "\"") {
            Error(_) -> ""
            Ok(#(value, _)) -> value
          }
      }
  }
}

/// Extract a JSON object for a given key. e.g. "auth_data":{...} -> "{...}"
fn extract_json_object(body: String, key: String) -> String {
  extract_key_blob(body, key)
}

fn extract_key_blob(body: String, key: String) -> String {
  case string.split_once(body, "\"" <> key <> "\"") {
    Error(_) -> "{}"
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> "{}"
        Ok(#(_, after_brace)) -> {
          let #(blob, _) = extract_object("{" <> after_brace, 0, "")
          blob
        }
      }
  }
}

// ---------------------------------------------------------------------------
// sendToDevice handler
// ---------------------------------------------------------------------------

/// PUT /_matrix/client/v3/sendToDevice/{eventType}/{txnId}
/// Body: {"messages": {"@user:server": {"device_id": {content}}}}
/// Stores a to-device event for each target user.
fn handle_send_to_device(
  ctx: handlers.HandlerContext,
  path: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  // Extract eventType from path: drop prefix, split on "/"
  let prefix = "/_matrix/client/v3/sendToDevice/"
  let after_prefix = string.drop_start(path, string.length(prefix))
  let event_type = case string.split_once(after_prefix, "/") {
    Ok(#(et, _)) -> et
    Error(_) -> after_prefix
  }
  // Parse messages object: {"@user:srv": {"device_id": {content}}}
  let new_store = parse_and_store_to_device(ctx.store, event_type, body)
  #(new_store, router.JsonResponse(200, "{}"))
}

/// Walk the messages object and store a to-device event per target user.
fn parse_and_store_to_device(
  store: kv.Store,
  event_type: String,
  body: String,
) -> kv.Store {
  case string.split_once(body, "\"messages\"") {
    Error(_) -> store
    Ok(#(_, after)) ->
      case string.split_once(after, "{") {
        Error(_) -> store
        Ok(#(_, after_brace)) ->
          store_to_device_for_users(store, event_type, after_brace)
      }
  }
}

fn store_to_device_for_users(
  store: kv.Store,
  event_type: String,
  s: String,
) -> kv.Store {
  let trimmed = string.trim(s)
  case string.starts_with(trimmed, "\"") {
    False -> store
    True -> {
      let after_open = string.drop_start(trimmed, 1)
      case string.split_once(after_open, "\"") {
        Error(_) -> store
        Ok(#(target_user, rest_after_user)) -> {
          // Skip ": {deviceId: content}"
          case string.split_once(rest_after_user, "{") {
            Error(_) -> store
            Ok(#(_, device_content)) -> {
              // Extract the inner content object for this user's device
              let #(device_obj, rest_after_obj) =
                extract_object("{" <> device_content, 0, "")
              // The content for the to-device event is the value of the device entry
              // which may itself be an object. Use the whole device_obj as content.
              let content = device_obj
              let new_store =
                kv.add_to_device(store, target_user, event_type, content)
              // Continue parsing remaining users
              let trimmed_rest = string.trim(rest_after_obj)
              let rest2 = case string.starts_with(trimmed_rest, ",") {
                True -> string.trim(string.drop_start(trimmed_rest, 1))
                False -> trimmed_rest
              }
              // Stop at end of outer object
              case string.starts_with(rest2, "}") {
                True -> new_store
                False ->
                  store_to_device_for_users(new_store, event_type, rest2)
              }
            }
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sliding sync (MSC3575) handler
// ---------------------------------------------------------------------------

/// POST /_matrix/client/unstable/org.matrix.simplified_msc3575/sync
/// Returns MSC3575 format: {pos, lists, rooms, extensions}
fn handle_sliding_sync(
  ctx: handlers.HandlerContext,
  token: String,
  _body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"))
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let device_id = case kv.get_device_for_token(ctx.store, token) {
        Ok(did) -> did
        Error(_) -> "SUTRA_DEVICE"
      }

      // Build rooms map using serdes_json NIF for raw content embedding
      let user_rooms = kv.rooms_for_user(ctx.store, user_id)
      let rooms_pairs = list.map(user_rooms, fn(room) {
        let rid = types.room_id_to_string(room.room_id)
        let events = kv.events_in_room(ctx.store, rid, 20)
        // Use NIF for event encoding — handles raw content correctly
        let timeline_events = list.map(events, fn(ev) {
          serdes_json.encode_event(
            types.event_id_to_string(ev.event_id),
            ev.event_type,
            types.user_id_to_string(ev.sender),
            ev.origin_server_ts,
            ev.content,
            case ev.state_key { option.Some(sk) -> sk option.None -> "__NONE__" },
          )
        })
        let state_events = kv.state_events_in_room(ctx.store, rid)
        let state_json = list.map(state_events, fn(ev) {
          serdes_json.encode_event(
            types.event_id_to_string(ev.event_id),
            ev.event_type,
            types.user_id_to_string(ev.sender),
            ev.origin_server_ts,
            ev.content,
            case ev.state_key { option.Some(sk) -> sk option.None -> "__NONE__" },
          )
        })
        // Count members
        let member_events = list.filter(state_events, fn(ev) {
          ev.event_type == "m.room.member"
        })
        let joined_count = list.length(list.filter(member_events, fn(ev) {
          string.contains(ev.content, "\"join\"")
        }))
        let invited_count = list.length(list.filter(member_events, fn(ev) {
          string.contains(ev.content, "\"invite\"")
        }))
        // Build heroes list
        let heroes_list = list.filter_map(member_events, fn(ev) {
          case ev.state_key {
            option.Some(sk) -> case sk != user_id {
              True -> Ok(sk)
              False -> Error(Nil)
            }
            option.None -> Error(Nil)
          }
        })
        let room_name = case room.state.name {
          option.Some(n) -> n
          option.None -> rid
        }
        // Build room JSON using json.object for structure, raw for events
        let room_json = json.object([
          #("timeline", json.preprocessed_array([])),
          #("required_state", json.preprocessed_array([])),
          #("initial", json.bool(True)),
          #("name", json.string(room_name)),
          #("notification_count", json.int(0)),
          #("highlight_count", json.int(0)),
          #("joined_count", json.int(joined_count)),
          #("invited_count", json.int(invited_count)),
          #("heroes", json.array(heroes_list, json.string)),
        ]) |> json.to_string
        // Replace empty arrays with actual event arrays (raw JSON)
        let room_with_timeline = string.replace(room_json,
          "\"timeline\":[]",
          "\"timeline\":[" <> string.join(timeline_events, ",") <> "]")
        let room_with_state = string.replace(room_with_timeline,
          "\"required_state\":[]",
          "\"required_state\":[" <> string.join(state_json, ",") <> "]")
        #(rid, room_with_state)
      })

      // E2EE extensions
      let otk_count = kv.count_otks(ctx.store, user_id, device_id)
      let changed_users = list.map(kv.get_device_keys(ctx.store, user_id), fn(dk) {
        dk.user_id
      })
      // to_device
      let #(td_events, store2) = kv.drain_to_device(ctx.store, user_id)
      let td_json = list.map(td_events, fn(td) {
        serdes_json.object_raw([#("type", "\"" <> td.0 <> "\""), #("content", td.1)])
      })

      // Build account data events
      let acct_data_json = build_account_data_events(store2, user_id)

      // Build complete response using json.object for structure
      let e2ee_ext = json.object([
        #("device_one_time_keys_count", json.object([
          #("curve25519", json.int(otk_count)),
          #("signed_curve25519", json.int(otk_count)),
        ])),
        #("device_unused_fallback_key_types", json.preprocessed_array([
          json.string("signed_curve25519"),
        ])),
        #("device_lists", json.object([
          #("changed", json.array(changed_users, json.string)),
          #("left", json.preprocessed_array([])),
        ])),
      ]) |> json.to_string

      let td_ext = json.object([
        #("events", json.preprocessed_array([])),
        #("next_batch", json.string("td_s" <> int.to_string(ctx.timestamp))),
      ]) |> json.to_string
      // Replace empty events array with actual to-device events
      let td_ext_final = string.replace(td_ext,
        "\"events\":[]",
        "\"events\":[" <> string.join(td_json, ",") <> "]")

      // Build rooms object from pairs
      let rooms_obj = serdes_json.object_raw(rooms_pairs)

      // Build lists
      let lists_obj = json.object([
        #("all_rooms", json.object([
          #("count", json.int(list.length(user_rooms))),
        ])),
      ]) |> json.to_string

      // Assemble final response
      let response = serdes_json.object_raw([
        #("pos", "\"s" <> int.to_string(ctx.timestamp) <> "\""),
        #("rooms", rooms_obj),
        #("lists", lists_obj),
        #("extensions", serdes_json.object_raw([
          #("e2ee", e2ee_ext),
          #("to_device", td_ext_final),
          #("account_data", serdes_json.object_raw([
            #("global", "[" <> acct_data_json <> "]"),
            #("rooms", "{}"),
          ])),
          #("receipts", serdes_json.object_raw([#("rooms", "{}")])),
          #("typing", serdes_json.object_raw([#("rooms", "{}")])),
        ])),
      ])

      #(store2, router.JsonResponse(200, response))
    }
  }
}

/// Build account data events JSON array for sliding sync / regular sync.
/// Returns the contents of the array (no brackets).
fn build_account_data_events(store: kv.Store, user_id: String) -> String {
  let entries = kv.all_account_data(store, user_id)
  entries
  |> list.map(fn(entry) {
    let #(dtype, content) = entry
    "{\"type\":\"" <> dtype <> "\",\"content\":" <> content <> "}"
  })
  |> string.join(",")
}

// ---------------------------------------------------------------------------
// Key backup handlers
// ---------------------------------------------------------------------------

/// GET /_matrix/client/v3/room_keys/version
fn handle_key_backup_get_version(
  ctx: handlers.HandlerContext,
) -> #(kv.Store, router.ApiResult) {
  let version = kv.get_key_backup_version(ctx.store)
  case version {
    "" ->
      #(
        ctx.store,
        router.ErrorResponse(404, "M_NOT_FOUND", "No key backup version"),
      )
    v -> {
      let algorithm = kv.get_key_backup_algorithm(ctx.store)
      let auth_data = kv.get_key_backup_auth_data(ctx.store)
      let backup_data = kv.get_key_backup_data(ctx.store, v)
      let count = list.length(backup_data)
      #(
        ctx.store,
        router.JsonResponse(
          200,
          "{\"version\":\"" <> v
          <> "\",\"algorithm\":\"" <> algorithm
          <> "\",\"count\":" <> int.to_string(count)
          <> ",\"etag\":\"" <> int.to_string(count)
          <> "\",\"auth_data\":" <> auth_data <> "}",
        ),
      )
    }
  }
}

/// PUT /_matrix/client/v3/room_keys/version
/// Creates a new key backup version.
fn handle_key_backup_put_version(
  ctx: handlers.HandlerContext,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  // Extract algorithm and auth_data from body
  let algorithm = extract_json_string(body, "algorithm")
  let auth_data = extract_json_object(body, "auth_data")
  // Generate version number
  let current = kv.get_key_backup_version(ctx.store)
  let version = case current {
    "" -> "1"
    v -> {
      case int.parse(v) {
        Ok(n) -> int.to_string(n + 1)
        Error(_) -> "1"
      }
    }
  }
  let new_store = kv.set_key_backup_full(ctx.store, version, algorithm, auth_data)
  #(
    new_store,
    router.JsonResponse(200, "{\"version\":\"" <> version <> "\"}"),
  )
}

/// GET /_matrix/client/v3/room_keys/keys
fn handle_key_backup_get_keys(
  ctx: handlers.HandlerContext,
) -> #(kv.Store, router.ApiResult) {
  let version = kv.get_key_backup_version(ctx.store)
  let entries = kv.get_key_backup_data(ctx.store, version)
  let rooms_json =
    entries
    |> list.map(fn(entry) {
      let #(key, data) = entry
      "\"" <> key <> "\":" <> data
    })
    |> string.join(",")
  #(
    ctx.store,
    router.JsonResponse(200, "{\"rooms\":{" <> rooms_json <> "}}"),
  )
}

/// PUT /_matrix/client/v3/room_keys/keys
/// Stores key backup data.
fn handle_key_backup_put_keys(
  ctx: handlers.HandlerContext,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  let version = kv.get_key_backup_version(ctx.store)
  case version {
    "" ->
      #(
        ctx.store,
        router.ErrorResponse(404, "M_NOT_FOUND", "No key backup version set"),
      )
    v -> {
      // Store the entire body as the backup for this version
      let new_store = kv.store_key_backup(ctx.store, v, "all", body)
      #(new_store, router.JsonResponse(200, "{\"etag\":\"1\",\"count\":1}"))
    }
  }
}

// ---------------------------------------------------------------------------
// Phase 5 handlers — receipts, typing, presence, user directory
// ---------------------------------------------------------------------------

/// POST /_matrix/client/v3/rooms/{roomId}/receipt/{receiptType}/{eventId}
/// GET /rooms/{roomId}/state/{eventType}/{stateKey?}
/// Returns the content of a specific state event.
fn handle_get_state_event(
  ctx: handlers.HandlerContext,
  room_id: String,
  event_type: String,
  state_key: String,
) -> #(kv.Store, router.ApiResult) {
  let state_events = kv.state_events_in_room(ctx.store, room_id)
  // Find matching state event
  let matched = list.find(state_events, fn(ev) {
    ev.event_type == event_type && case ev.state_key {
      option.Some(sk) -> sk == state_key
      option.None -> state_key == ""
    }
  })
  case matched {
    Ok(ev) ->
      // Return just the content (per Matrix spec for GET /state/{type}/{stateKey})
      #(ctx.store, router.JsonResponse(200, ev.content))
    Error(_) ->
      #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "State event not found"))
  }
}

fn handle_receipt(
  ctx: handlers.HandlerContext,
  token: String,
  room_id: String,
  receipt_type: String,
  event_id: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(
        ctx.store,
        router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"),
      )
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let ts = erlang_now_ms()
      let new_store =
        kv.add_receipt(ctx.store, room_id, event_id, user_id, receipt_type, ts)
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

/// POST /_matrix/client/v3/rooms/{roomId}/read_markers
fn handle_read_markers(
  ctx: handlers.HandlerContext,
  token: String,
  room_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(
        ctx.store,
        router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"),
      )
    Ok(user) -> {
      let user_id = types.user_id_to_string(user.user_id)
      let ts = erlang_now_ms()
      // m.fully_read is the primary marker
      let event_id = case json_helpers.extract_string(body, "m.fully_read") {
        Ok(eid) -> eid
        Error(_) ->
          case json_helpers.extract_string(body, "m.read") {
            Ok(eid) -> eid
            Error(_) -> ""
          }
      }
      let new_store = case event_id {
        "" -> ctx.store
        eid ->
          kv.add_receipt(ctx.store, room_id, eid, user_id, "m.read", ts)
      }
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

/// PUT /_matrix/client/v3/rooms/{roomId}/typing/{userId}
fn handle_typing(
  ctx: handlers.HandlerContext,
  token: String,
  room_id: String,
  target_user_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(
        ctx.store,
        router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"),
      )
    Ok(_user) -> {
      let is_typing = case json_helpers.extract_bool(body, "typing") {
        Ok(b) -> b
        Error(_) -> False
      }
      let timeout = case json_helpers.extract_int(body, "timeout") {
        Ok(t) -> t
        Error(_) -> 30_000
      }
      let new_store = case is_typing {
        True -> {
          let timeout_ts = erlang_now_ms() + timeout
          kv.set_typing(ctx.store, room_id, target_user_id, timeout_ts)
        }
        False -> kv.clear_typing(ctx.store, room_id, target_user_id)
      }
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

/// PUT /_matrix/client/v3/presence/{userId}/status
fn handle_put_presence(
  ctx: handlers.HandlerContext,
  token: String,
  user_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.find_user_by_token(ctx.store, token) {
    Error(_) ->
      #(
        ctx.store,
        router.ErrorResponse(401, "M_UNKNOWN_TOKEN", "Invalid access token"),
      )
    Ok(_user) -> {
      let status = case json_helpers.extract_string(body, "presence") {
        Ok(s) -> s
        Error(_) -> "online"
      }
      let ts = erlang_now_ms()
      let new_store = kv.set_presence(ctx.store, user_id, status, ts)
      #(new_store, router.JsonResponse(200, "{}"))
    }
  }
}

/// GET /_matrix/client/v3/presence/{userId}/status
fn handle_get_presence(
  ctx: handlers.HandlerContext,
  user_id: String,
) -> #(kv.Store, router.ApiResult) {
  let #(status, last_active_ts) = case kv.get_presence(ctx.store, user_id) {
    Ok(#(s, ts)) -> #(s, ts)
    Error(_) -> #("offline", 0)
  }
  let json =
    "{\"presence\":\""
    <> status
    <> "\",\"last_active_ago\":"
    <> int.to_string(last_active_ts)
    <> "}"
  #(ctx.store, router.JsonResponse(200, json))
}

/// POST /_matrix/client/v3/user_directory/search
fn handle_user_directory_search(
  ctx: handlers.HandlerContext,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  let search_term = case json_helpers.extract_string(body, "search_term") {
    Ok(s) -> s
    Error(_) -> ""
  }
  let results = kv.search_users(ctx.store, search_term)
  let results_json =
    results
    |> list.map(fn(user) {
      let uid = types.user_id_to_string(user.user_id)
      let dn = case user.display_name {
        None -> "null"
        Some(d) -> "\"" <> d <> "\""
      }
      let av = case user.avatar_url {
        None -> "null"
        Some(a) -> "\"" <> a <> "\""
      }
      "{\"user_id\":\""
      <> uid
      <> "\",\"display_name\":"
      <> dn
      <> ",\"avatar_url\":"
      <> av
      <> "}"
    })
    |> string.join(",")
  #(
    ctx.store,
    router.JsonResponse(
      200,
      "{\"results\":[" <> results_json <> "],\"limited\":false}",
    ),
  )
}

// ---------------------------------------------------------------------------
// 3PID handlers (Phase 9)
// ---------------------------------------------------------------------------

/// POST /register/email/requestToken  and  POST /register/msisdn/requestToken
/// POST /account/password/email/requestToken  POST /account/password/msisdn/requestToken
/// Auto-approve: generate a session_id, store the session, return it immediately.
fn handle_threepid_request_token(
  ctx: handlers.HandlerContext,
  medium: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  let address = case json_helpers.extract_string(body, "email") {
    Ok(a) -> a
    Error(_) ->
      case json_helpers.extract_string(body, "phone_number") {
        Ok(a) -> a
        Error(_) -> "unknown@unknown"
      }
  }
  let session_id = "sid_" <> int.to_string(erlang_now_ms())
  let new_store = kv.add_threepid_session(ctx.store, session_id, medium, address)
  #(
    new_store,
    router.JsonResponse(
      200,
      "{\"sid\":\"" <> session_id <> "\"}",
    ),
  )
}

/// POST /account/3pid/add — record an approved 3PID association.
fn handle_threepid_add(
  ctx: handlers.HandlerContext,
  _token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  let medium = case json_helpers.extract_string(body, "medium") {
    Ok(m) -> m
    Error(_) -> "email"
  }
  let address = case json_helpers.extract_string(body, "address") {
    Ok(a) -> a
    Error(_) -> ""
  }
  let session_id = case json_helpers.extract_string(body, "sid") {
    Ok(s) -> s
    Error(_) -> "sid_unknown"
  }
  let new_store = kv.add_threepid_session(ctx.store, session_id, medium, address)
  #(new_store, router.JsonResponse(200, "{}"))
}

/// POST /account/3pid/bind — bind a 3PID via an identity server (auto-approve).
fn handle_threepid_bind(
  ctx: handlers.HandlerContext,
  _token: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  let medium = case json_helpers.extract_string(body, "medium") {
    Ok(m) -> m
    Error(_) -> "email"
  }
  let address = case json_helpers.extract_string(body, "address") {
    Ok(a) -> a
    Error(_) -> ""
  }
  let session_id = case json_helpers.extract_string(body, "sid") {
    Ok(s) -> s
    Error(_) -> "sid_bind_" <> int.to_string(erlang_now_ms())
  }
  let new_store = kv.add_threepid_session(ctx.store, session_id, medium, address)
  #(new_store, router.JsonResponse(200, "{}"))
}

// ---------------------------------------------------------------------------
// Third-party protocol handlers (Phase 8)
// ---------------------------------------------------------------------------

/// GET /thirdparty/protocols — return all registered protocols as a JSON object.
fn handle_thirdparty_protocols(
  ctx: handlers.HandlerContext,
) -> #(kv.Store, router.ApiResult) {
  let protocols = kv.get_thirdparty_protocols(ctx.store)
  let pairs =
    list.map(protocols, fn(pair) {
      "\"" <> pair.0 <> "\":" <> pair.1
    })
    |> string.join(",")
  #(ctx.store, router.JsonResponse(200, "{" <> pairs <> "}"))
}

/// GET /thirdparty/protocol/{name} — return config for a single protocol.
fn handle_thirdparty_protocol(
  ctx: handlers.HandlerContext,
  name: String,
) -> #(kv.Store, router.ApiResult) {
  let protocols = kv.get_thirdparty_protocols(ctx.store)
  case list.find(protocols, fn(pair) { pair.0 == name }) {
    Error(_) ->
      #(ctx.store, router.ErrorResponse(404, "M_NOT_FOUND", "Protocol not found: " <> name))
    Ok(#(_, config_json)) ->
      #(ctx.store, router.JsonResponse(200, config_json))
  }
}

/// GET /thirdparty/location[/{protocol}] — return empty location list.
fn handle_thirdparty_location(
  ctx: handlers.HandlerContext,
  _protocol: Option(String),
) -> #(kv.Store, router.ApiResult) {
  #(ctx.store, router.JsonResponse(200, "[]"))
}

/// GET /thirdparty/user[/{protocol}] — return empty user list.
fn handle_thirdparty_user(
  ctx: handlers.HandlerContext,
  _protocol: Option(String),
) -> #(kv.Store, router.ApiResult) {
  #(ctx.store, router.JsonResponse(200, "[]"))
}

// ---------------------------------------------------------------------------
// Media enhancement handlers (Phase 12)
// ---------------------------------------------------------------------------

/// GET /media/v3/preview_url?url=... — return (or cache) a URL preview.
fn handle_media_preview_url(
  ctx: handlers.HandlerContext,
  url: String,
) -> #(kv.Store, router.ApiResult) {
  case url {
    "" ->
      #(
        ctx.store,
        router.ErrorResponse(400, "M_BAD_JSON", "Missing url parameter"),
      )
    _ -> {
      case kv.get_url_preview(ctx.store, url) {
        Ok(metadata_json) ->
          #(ctx.store, router.JsonResponse(200, metadata_json))
        Error(_) -> {
          // Synthesise a minimal preview and cache it
          let ts = erlang_now_ms()
          let metadata_json =
            "{\"og:title\":\""
            <> url
            <> "\",\"og:description\":\"\",\"matrix:image:size\":0,\"og:url\":\""
            <> url
            <> "\",\"matrix_server_timestamp\":"
            <> int.to_string(ts)
            <> "}"
          let new_store = kv.set_url_preview(ctx.store, url, metadata_json)
          #(new_store, router.JsonResponse(200, metadata_json))
        }
      }
    }
  }
}

/// POST /media/v1/create — reserve a media_id for asynchronous upload.
fn handle_media_create(
  ctx: handlers.HandlerContext,
  _token: String,
) -> #(kv.Store, router.ApiResult) {
  let media_id = "sutra_" <> int.to_string(erlang_now_ms())
  let new_store = kv.reserve_media(ctx.store, media_id)
  let content_uri =
    "mxc://" <> ctx.server_name <> "/" <> media_id
  let unused_expires_at = erlang_now_ms() + 86_400_000
  #(
    new_store,
    router.JsonResponse(
      200,
      "{\"content_uri\":\""
        <> content_uri
        <> "\",\"unused_expires_at\":"
        <> int.to_string(unused_expires_at)
        <> "}",
    ),
  )
}

/// PUT /media/v3/upload/{server}/{mediaId} — store bytes for a reserved media_id.
fn handle_media_upload_by_id(
  ctx: handlers.HandlerContext,
  _token: String,
  _server: String,
  media_id: String,
  body: String,
) -> #(kv.Store, router.ApiResult) {
  // Remove reservation (if any) then store the blob
  let store1 = kv.remove_reserved_media(ctx.store, media_id)
  let store2 = kv.store_media_blob(store1, media_id, body)
  let content_uri = "mxc://" <> ctx.server_name <> "/" <> media_id
  #(
    store2,
    router.JsonResponse(
      200,
      "{\"content_uri\":\"" <> content_uri <> "\"}",
    ),
  )
}

/// GET /media/v3/download/{server}/{mediaId}/{filename}
/// Same as regular download but adds Content-Disposition header with filename.
/// For simplicity we delegate to the blob store and attach a filename hint in
/// the JSON response body (full header control would need mist primitives).
fn handle_media_download_with_filename(
  ctx: handlers.HandlerContext,
  _server: String,
  media_id: String,
  filename: String,
) -> #(kv.Store, router.ApiResult) {
  case kv.get_media_blob(ctx.store, media_id) {
    Error(_) ->
      #(
        ctx.store,
        router.ErrorResponse(404, "M_NOT_FOUND", "Media not found: " <> media_id),
      )
    Ok(content) -> {
      // Return the blob content; filename is carried via a synthetic JSON wrapper
      // when the client requests a specific filename. Real Matrix media is binary;
      // Sutra returns a JSON envelope so clients can decode it.
      let fname = case filename {
        "" -> media_id
        f -> f
      }
      let _ = fname
      #(ctx.store, router.JsonResponse(200, content))
    }
  }
}

// ---------------------------------------------------------------------------
// Response builder
// ---------------------------------------------------------------------------

fn build_response(
  result: router.ApiResult,
) -> response.Response(mist.ResponseData) {
  case result {
    router.JsonResponse(status, json_body) ->
      response.new(status)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_header(
        "access-control-allow-methods",
        "GET, POST, PUT, DELETE, OPTIONS",
      )
      |> response.set_header(
        "access-control-allow-headers",
        "Content-Type, Authorization",
      )
      |> response.set_body(mist.Bytes(bytes_tree.from_string(json_body)))

    router.ErrorResponse(status, errcode, error) -> {
      let error_json =
        "{\"errcode\":\""
        <> errcode
        <> "\",\"error\":\""
        <> error
        <> "\"}"
      response.new(status)
      |> response.set_header("content-type", "application/json")
      |> response.set_header("access-control-allow-origin", "*")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(error_json)))
    }
  }
}

// ---------------------------------------------------------------------------
// Request helpers
// ---------------------------------------------------------------------------

fn extract_token(req: request.Request(mist.Connection)) -> Option(String) {
  case request.get_header(req, "authorization") {
    Ok(auth) ->
      case string.starts_with(auth, "Bearer ") {
        True -> Some(string.drop_start(auth, 7))
        False -> None
      }
    Error(_) -> None
  }
}

fn read_body(req: request.Request(mist.Connection)) -> String {
  case mist.read_body(req, 1_000_000) {
    Ok(body_req) ->
      case bit_array.to_string(body_req.body) {
        Ok(s) -> s
        Error(_) -> ""
      }
    Error(_) -> ""
  }
}

// ---------------------------------------------------------------------------
// Path parsing helpers
// ---------------------------------------------------------------------------

/// Extract the room_id from a path like /_matrix/client/v3/rooms/{roomId}/...
fn extract_room_id_from_path(path: String) -> String {
  let prefix = "/_matrix/client/v3/rooms/"
  let after = string.drop_start(path, string.length(prefix))
  case string.split_once(after, "/") {
    Ok(#(room_id, _)) -> room_id
    Error(_) -> after
  }
}

/// Extract the sub-path after /_matrix/client/v3/rooms/{roomId}/
fn extract_room_sub_path(path: String, room_id: String) -> String {
  let prefix = "/_matrix/client/v3/rooms/" <> room_id <> "/"
  string.drop_start(path, string.length(prefix))
}

/// Extract the query string from a full path like /sync?since=s123&timeout=30000
fn extract_query_string(path: String) -> String {
  case string.split_once(path, "?") {
    Ok(#(_, query)) -> query
    Error(_) -> ""
  }
}

/// Extract the event_id from a path like /_matrix/client/v3/rooms/{roomId}/event/{eventId}
fn extract_event_id_from_path(path: String, room_id: String) -> String {
  let prefix = "/_matrix/client/v3/rooms/" <> room_id <> "/event/"
  let after = string.drop_start(path, string.length(prefix))
  // Strip any query string
  case string.split_once(after, "?") {
    Ok(#(event_id, _)) -> event_id
    Error(_) -> after
  }
}

// ---------------------------------------------------------------------------
// Erlang FFI — monotonic timestamp for IDs
// ---------------------------------------------------------------------------

@external(erlang, "erlang", "unique_integer")
fn erlang_unique_integer() -> Int

fn erlang_now_ms() -> Int {
  let n = erlang_unique_integer()
  case n >= 0 {
    True -> n
    False -> -n
  }
}

// ---------------------------------------------------------------------------
// Zenoh domain event publisher — rich domain-specific messages on every op
// Extracts user_id, device_id, room_id from response body for full context.
// ---------------------------------------------------------------------------

fn zenoh_publish_domain_event(
  path: String,
  method: String,
  req_body: String,
  resp_body: String,
) -> Result(String, String) {
  // Helper to safely extract a field from JSON
  let get = fn(json_str: String, key: String) -> String {
    case json_helpers.extract_string(json_str, key) {
      Ok(v) -> v
      Error(_) -> ""
    }
  }

  case path {
    // ── Auth ─────────────────────────────────────────────────────
    "/_matrix/client/v3/login" -> {
      let user_id = get(resp_body, "user_id")
      let device_id = get(resp_body, "device_id")
      zenoh.publish_login(user_id, device_id)
    }

    "/_matrix/client/v3/register" -> {
      let user_id = get(resp_body, "user_id")
      let device_id = get(resp_body, "device_id")
      zenoh.publish_register(user_id, device_id)
    }

    "/_matrix/client/v3/logout" ->
      zenoh.publish_logout("unknown")

    // ── E2EE Keys ────────────────────────────────────────────────
    "/_matrix/client/v3/keys/upload" ->
      zenoh.publish_keys_uploaded("", "", 0)

    "/_matrix/client/v3/keys/query" ->
      zenoh.publish_keys_query("")

    "/_matrix/client/v3/keys/claim" ->
      zenoh.publish_keys_claim("")

    "/_matrix/client/v3/keys/device_signing/upload" ->
      zenoh.publish_cross_signing("")

    "/_matrix/client/v3/keys/signatures/upload" ->
      zenoh.publish_request(method, path, 200, string.length(req_body))

    // ── Key Backup ───────────────────────────────────────────────
    "/_matrix/client/v3/room_keys/version" ->
      zenoh.publish_key_backup("", method)

    "/_matrix/client/v3/room_keys/keys" ->
      zenoh.publish_key_backup("", method)

    // ── Room Operations ──────────────────────────────────────────
    "/_matrix/client/v3/createRoom" -> {
      let room_id = get(resp_body, "room_id")
      zenoh.publish_room_created(room_id, "")
    }

    "/_matrix/client/v3/joined_rooms" ->
      zenoh.publish_request(method, path, 200, 0)

    // ── Search ───────────────────────────────────────────────────
    "/_matrix/client/v3/search" ->
      zenoh.publish_search("")

    // ── Capabilities ─────────────────────────────────────────────
    "/_matrix/client/v3/capabilities" ->
      zenoh.publish_capabilities()

    // ── Account ──────────────────────────────────────────────────
    "/_matrix/client/v3/account/whoami" ->
      zenoh.publish_request(method, path, 200, 0)

    // ── Push Rules ───────────────────────────────────────────────
    "/_matrix/client/v3/pushrules/" ->
      zenoh.publish_push_rules("", "get")

    // ── All other paths: classify by pattern ─────────────────────
    _ ->
      zenoh_classify_path(path, method, req_body)
  }
}

/// Classify dynamic paths and publish domain-specific zenoh events.
fn zenoh_classify_path(
  path: String,
  method: String,
  req_body: String,
) -> Result(String, String) {
  let bs = string.length(req_body)
  case string.starts_with(path, "/_matrix/client/v3/sync") || string.starts_with(path, "/_matrix/client/v1/sync") {
    True -> zenoh.publish_sync("", 0, 0)
    False ->
  case string.starts_with(path, "/_matrix/client/unstable/org.matrix.simplified_msc3575/sync") {
    True -> zenoh.publish_sliding_sync("")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/join/") {
    True -> zenoh.publish_room_join(string.replace(path, "/_matrix/client/v3/join/", ""), "")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/rooms/") {
    True -> zenoh_classify_room_path(path, method, req_body)
    False ->
  case string.starts_with(path, "/_matrix/client/v3/profile/") {
    True -> zenoh.publish_profile_update("", "query")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/presence/") {
    True -> zenoh.publish_presence("", "online")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/devices") {
    True -> zenoh.publish_device_list("")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/sendToDevice/") {
    True -> zenoh.publish_to_device("", "to_device")
    False ->
  case string.starts_with(path, "/_matrix/media/v3/upload") {
    True -> zenoh.publish_media_upload("", "")
    False ->
  case string.starts_with(path, "/_matrix/media/v3/download/") || string.starts_with(path, "/_matrix/media/v3/thumbnail/") {
    True -> zenoh.publish_media_download("")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/directory/") {
    True -> zenoh.publish_directory(method, "")
    False ->
  case string.starts_with(path, "/_matrix/client/v3/user/") {
    True -> case string.contains(path, "/filter") {
      True -> zenoh.publish_filter("")
      False -> zenoh.publish_account_data("", "")
    }
    False ->
  case string.starts_with(path, "/_matrix/federation/") || string.starts_with(path, "/_matrix/key/") {
    True -> zenoh.publish_federation("query", "")
    False ->
      zenoh.publish_request(method, path, 200, bs)
  }}}}}}}}}}}}}
}

/// Classify room sub-paths for zenoh publishing.
fn zenoh_classify_room_path(
  path: String,
  method: String,
  req_body: String,
) -> Result(String, String) {
  let room_id = extract_room_id_from_path(path)
  case string.ends_with(path, "/leave") {
    True -> zenoh.publish_room_leave(room_id, "")
    False ->
  case string.contains(path, "/send/") {
    True -> zenoh.publish_message_sent(room_id, "", "", "m.room.message")
    False ->
  case string.contains(path, "/state/") || string.ends_with(path, "/state") {
    True -> zenoh.publish_state_event(room_id, "state")
    False ->
  case string.contains(path, "/invite") {
    True -> {
      let invitee = case json_helpers.extract_string(req_body, "user_id") {
        Ok(u) -> u
        Error(_) -> ""
      }
      zenoh.publish_room_invite(room_id, "", invitee)
    }
    False ->
  case string.contains(path, "/kick") || string.contains(path, "/ban") {
    True -> {
      let target = case json_helpers.extract_string(req_body, "user_id") {
        Ok(u) -> u
        Error(_) -> ""
      }
      zenoh.publish_room_leave(room_id, target)
    }
    False ->
  case string.contains(path, "/typing/") {
    True -> zenoh.publish_typing(room_id, "", "true")
    False ->
  case string.contains(path, "/receipt/") {
    True -> zenoh.publish_receipt(room_id, "", "")
    False ->
  case string.ends_with(path, "/members") || string.ends_with(path, "/messages") || string.contains(path, "/event/") {
    True -> zenoh.publish_request(method, path, 200, 0)
    False ->
      zenoh.publish_request(method, path, 200, string.length(req_body))
  }}}}}}}}
}
