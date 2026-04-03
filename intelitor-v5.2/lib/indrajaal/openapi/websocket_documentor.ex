defmodule Indrajaal.OpenAPI.WebSocketDocumentor do
  @moduledoc """
  Generates WebSocket documentation for OpenAPI specification.

  Documents WebSocket channels, __events, and protocols as
  OpenAPI extensions.

  Agent: Helper - 3 documents WebSocket protocols
  SOPv5.1 Compliance: ✅
  """

  @doc """
  Generates complete WebSocket documentation.
  """
  def generate_documentation do
    %{
      "endpoint" => "/mobile / socket",
      "protocol" => "wss",
      "description" => """
      Real - time bidirectional communication for mobile clients.

      The WebSocket endpoint provides channels for different __data domains
      with automatic reconnection, presence tracking, and offline support.
      """,
      "authentication" => %{
        "type" => "jwt",
        "description" => "Pass JWT token as query parameter: ?token = YOUR_JWT_TOKEN",
        "example" => "wss://api.intelitor.com / mobile / socket / websocket?token = eyJhbGci..."
      },
      "connection_params" => %{
        "token" => %{
          "type" => "string",
          "_required" => true,
          "description" => "JWT authentication token"
        },
        "device_id" => %{
          "type" => "string",
          "_required" => false,
          "description" => "Unique device identifier for tracking"
        },
        "app_version" => %{
          "type" => "string",
          "_required" => false,
          "description" => "Mobile app version"
        }
      },
      "limits" => %{
        "max_connections_per_user" => 5,
        "connection_timeout_seconds" => 45,
        "message_size_limit_kb" => 1024,
        "rate_limits" => %{
          "connection_attempts" => "5 per minute",
          "messages" => "100 per minute per channel"
        }
      },
      "channels" => generate_channel_docs(),
      "error_codes" => generate_error_codes(),
      "examples" => generate_connection_examples()
    }
  end

  defp generate_channel_docs do
    %{
      "alarm" => %{
        "pattern" => "alarm:{alarm_id}",
        "description" => "Real - time alarm updates and lifecycle management",
        "__events" => %{
          "incoming" => %{
            "acknowledge_alarm" => %{
              "description" => "Acknowledge an alarm",
              "payload" => %{
                "notes" => %{"type" => "string", "_required" => false}
              },
              "response" => %{"status" => "ok", "__data" => %{}}
            },
            "resolve_alarm" => %{
              "description" => "Resolve an alarm",
              "payload" => %{
                "resolution" => %{"type" => "string", "_required" => true},
                "root_cause" => %{"type" => "string", "_required" => false}
              }
            },
            "escalate_alarm" => %{
              "description" => "Escalate an alarm",
              "payload" => %{
                "reason" => %{"type" => "string", "_required" => true},
                "urgency" => %{"type" => "string", "enum" => ["low", "medium", "high"]}
              }
            },
            "add_comment" => %{
              "description" => "Add a comment to the alarm",
              "payload" => %{
                "text" => %{"type" => "string", "_required" => true}
              }
            },
            "get_history" => %{
              "description" => "Get alarm history",
              "payload" => %{
                "limit" => %{"type" => "integer", "default" => 20}
              }
            }
          },
          "outgoing" => %{
            "alarm_state" => %{
              "description" => "Initial alarm state when joining channel",
              "payload" => %{"alarm" => "Alarm object"}
            },
            "alarm_updated" => %{
              "description" => "Alarm __data has changed",
              "payload" => %{"alarm" => "Updated alarm object"}
            },
            "alarm_acknowledged" => %{
              "description" => "Alarm was acknowledged",
              "payload" => %{
                "alarm_id" => "string",
                "acknowledged_by" => "string",
                "acknowledged_at" => "datetime"
              }
            },
            "alarm_resolved" => %{
              "description" => "Alarm was resolved",
              "payload" => %{
                "alarm_id" => "string",
                "resolved_by" => "string",
                "resolution" => "string"
              }
            },
            "alarm_escalated" => %{
              "description" => "Alarm was escalated",
              "payload" => %{
                "alarm_id" => "string",
                "escalated_by" => "string",
                "reason" => "string"
              }
            },
            "comment_added" => %{
              "description" => "New comment added to alarm",
              "payload" => %{
                "comment_id" => "string",
                "user_id" => "string",
                "text" => "string",
                "created_at" => "datetime"
              }
            }
          }
        },
        "examples" => [
          %{
            "title" => "Join alarm channel",
            "code" => """
            const channel = socket.channel("alarm:12_345", {});
            channel.join()
              .receive("ok", resp => console.log("Joined"))
              .receive("error", resp => console.log("Failed"));
            """
          },
          %{
            "title" => "Acknowledge alarm",
            "code" => """
            channel.push("acknowledge_alarm", {notes: "Checking camera"})
              .receive("ok", resp => console.log("Acknowledged"))
              .receive("error", err => console.log("Error:", err));
            """
          }
        ]
      },
      "device" => %{
        "pattern" => "device:{device_id}",
        "description" => "Real - time device status monitoring and control",
        "__events" => %{
          "incoming" => %{
            "get_status" => %{
              "description" => "Get current device status",
              "payload" => %{}
            },
            "send_command" => %{
              "description" => "Send command to device",
              "payload" => %{
                "command" => %{"type" => "string", "_required" => true},
                "parameters" => %{"type" => "object"}
              }
            },
            "get_diagnostics" => %{
              "description" => "Get device diagnostics",
              "payload" => %{}
            },
            "get_history" => %{
              "description" => "Get device __event history",
              "payload" => %{
                "hours" => %{"type" => "integer", "default" => 24, "max" => 24}
              }
            },
            "set_maintenance_mode" => %{
              "description" => "Toggle maintenance mode",
              "payload" => %{
                "enabled" => %{"type" => "boolean", "_required" => true},
                "reason" => %{"type" => "string"}
              }
            }
          },
          "outgoing" => %{
            "device_state" => %{
              "description" => "Current device state",
              "payload" => "Device object with current status"
            },
            "device_event" => %{
              "description" => "Device __event occurred",
              "payload" => %{
                "__event_type" => "string",
                "device_id" => "string",
                "__data" => "object"
              }
            },
            "maintenance_mode_changed" => %{
              "description" => "Maintenance mode was toggled",
              "payload" => %{
                "device_id" => "string",
                "enabled" => "boolean",
                "changed_by" => "string"
              }
            }
          }
        }
      },
      "site" => %{
        "pattern" => "site:{site_id}",
        "description" => "Site - wide monitoring and statistics",
        "__events" => %{
          "incoming" => %{
            "get_overview" => %{
              "description" => "Get site overview",
              "payload" => %{}
            },
            "get_device_summary" => %{
              "description" => "Get device statistics for site",
              "payload" => %{}
            },
            "get_alarm_summary" => %{
              "description" => "Get alarm statistics for site",
              "payload" => %{}
            },
            "get_occupancy" => %{
              "description" => "Get current occupancy __data",
              "payload" => %{}
            },
            "get_zones" => %{
              "description" => "Get site zones",
              "payload" => %{}
            },
            "get_activity_feed" => %{
              "description" => "Get recent site activities",
              "payload" => %{
                "limit" => %{"type" => "integer", "default" => 20, "max" => 50}
              }
            }
          },
          "outgoing" => %{
            "site_state" => %{
              "description" => "Current site state and statistics",
              "payload" => "Site object with stats"
            },
            "site_event" => %{
              "description" => "Site - level __event occurred",
              "payload" => %{
                "__event_type" => "string",
                "site_id" => "string",
                "__data" => "object"
              }
            }
          }
        }
      },
      "config" => %{
        "pattern" => "config:{scope}",
        "description" => "Real - time configuration updates with collaborative editing",
        "scopes" => ["global", "site", "device_type", "alarm_rules", "notification_rules"],
        "__events" => %{
          "incoming" => %{
            "update_config" => %{
              "description" => "Update configuration",
              "payload" => %{
                "changes" => %{"type" => "object", "_required" => true},
                "version" => %{"type" => "integer"}
              }
            },
            "validate_config" => %{
              "description" => "Validate configuration changes",
              "payload" => %{
                "config" => %{"type" => "object", "_required" => true}
              }
            },
            "get_schema" => %{
              "description" => "Get configuration schema",
              "payload" => %{}
            },
            "get_history" => %{
              "description" => "Get configuration change history",
              "payload" => %{
                "limit" => %{"type" => "integer", "default" => 50}
              }
            },
            "revert_to_version" => %{
              "description" => "Revert to previous version",
              "payload" => %{
                "version" => %{"type" => "integer", "_required" => true}
              }
            },
            "start_editing" => %{
              "description" => "Signal start of editing a field",
              "payload" => %{
                "field" => %{"type" => "string", "_required" => true}
              }
            },
            "stop_editing" => %{
              "description" => "Signal stop of editing a field",
              "payload" => %{
                "field" => %{"type" => "string", "_required" => true}
              }
            }
          },
          "outgoing" => %{
            "config_state" => %{
              "description" => "Current configuration state",
              "payload" => %{
                "scope" => "string",
                "config" => "object",
                "version" => "integer"
              }
            },
            "config_changed" => %{
              "description" => "Configuration was updated",
              "payload" => %{
                "scope" => "string",
                "changes" => "object",
                "version" => "integer",
                "changed_by" => "string"
              }
            },
            "__user_editing" => %{
              "description" => "User started / stopped editing",
              "payload" => %{
                "user_id" => "string",
                "field" => "string",
                "action" => "start|stop"
              }
            },
            "editors_update" => %{
              "description" => "List of current editors",
              "payload" => %{
                "editors" => "array of user objects"
              }
            }
          }
        }
      },
      "notification" => %{
        "pattern" => "notification:user:{user_id}",
        "description" => "In - app notifications and preference management",
        "__events" => %{
          "incoming" => %{
            "mark_read" => %{
              "description" => "Mark notification as read",
              "payload" => %{
                "notification_id" => %{"type" => "string", "_required" => true}
              }
            },
            "mark_all_read" => %{
              "description" => "Mark all notifications as read",
              "payload" => %{}
            },
            "dismiss" => %{
              "description" => "Dismiss a notification",
              "payload" => %{
                "notification_id" => %{"type" => "string", "_required" => true}
              }
            },
            "get_recent" => %{
              "description" => "Get recent notifications",
              "payload" => %{
                "limit" => %{"type" => "integer", "default" => 20, "max" => 50}
              }
            },
            "update_preferences" => %{
              "description" => "Update notification preferences",
              "payload" => %{
                "preferences" => %{"type" => "object", "_required" => true}
              }
            },
            "send_test" => %{
              "description" => "Send test notification",
              "payload" => %{}
            }
          },
          "outgoing" => %{
            "new_notification" => %{
              "description" => "New notification received",
              "payload" => %{
                "id" => "string",
                "type" => "string",
                "title" => "string",
                "body" => "string",
                "__data" => "object",
                "priority" => "string"
              }
            },
            "unread_count" => %{
              "description" => "Unread notification count changed",
              "payload" => %{
                "count" => "integer"
              }
            },
            "preferences" => %{
              "description" => "Current notification preferences",
              "payload" => "NotificationPreferences object"
            },
            "preferences_updated" => %{
              "description" => "Preferences were updated",
              "payload" => "Updated NotificationPreferences object"
            }
          }
        }
      },
      "sync" => %{
        "pattern" => "sync:{device_id}",
        "description" => "Data synchronization for offline support",
        "__events" => %{
          "incoming" => %{
            "_request_sync" => %{
              "description" => "Request __data synchronization",
              "payload" => %{
                "last_sync" => %{"type" => "string", "format" => "datetime"}
              }
            },
            "push_changes" => %{
              "description" => "Push local changes to server",
              "payload" => %{
                "changes" => %{"type" => "array", "_required" => true}
              }
            },
            "resolve_conflict" => %{
              "description" => "Resolve sync conflict",
              "payload" => %{
                "change_id" => %{"type" => "string", "_required" => true},
                "resolution" => %{
                  "type" => "string",
                  "enum" => ["last_write_wins", "merge", "server_wins"]
                }
              }
            },
            "ack_sync" => %{
              "description" => "Acknowledge sync completion",
              "payload" => %{
                "sync_id" => %{"type" => "string", "_required" => true}
              }
            }
          },
          "outgoing" => %{
            "sync_ready" => %{
              "description" => "Channel ready for sync",
              "payload" => %{
                "device_id" => "string",
                "sync_version" => "string"
              }
            },
            "sync_data" => %{
              "description" => "Sync __data batch",
              "payload" => %{
                "type" => "string",
                "__data" => "array",
                "total" => "integer"
              }
            },
            "sync_changes" => %{
              "description" => "Differential changes",
              "payload" => %{
                "batch" => "integer",
                "total_batches" => "integer",
                "changes" => "array"
              }
            },
            "push_results" => %{
              "description" => "Results of pushed changes",
              "payload" => %{
                "accepted" => "integer",
                "rejected" => "integer",
                "conflicts" => "array"
              }
            }
          }
        }
      }
    }
  end

  defp generate_error_codes do
    %{
      "unauthorized" => %{
        "description" => "Authentication failed or token expired",
        "recovery" => "Obtain new JWT token and reconnect"
      },
      "rate_limited" => %{
        "description" => "Too many _requests",
        "recovery" => "Wait for retry_after milliseconds before retrying",
        "payload" => %{
          "reason" => "rate_limited",
          "retry_after" => "integer (milliseconds)"
        }
      },
      "channel_not_found" => %{
        "description" => "Requested channel does not exist",
        "recovery" => "Verify channel ID and permissions"
      },
      "invalid_params" => %{
        "description" => "Invalid parameters in _request",
        "recovery" => "Check parameter types and _required fields"
      },
      "timeout" => %{
        "description" => "Request timed out",
        "recovery" => "Retry with exponential backoff"
      }
    }
  end

  defp generate_connection_examples do
    [
      %{
        "title" => "JavaScript / Phoenix.js Connection",
        "language" => "javascript",
        "code" => """
        import {Socket} from "phoenix"

        // Create socket connection
        const socket = new Socket("/mobile / socket", {
          __params: {token: authToken}
        })

        // Connect
        socket.connect()

        // Join alarm channel
        const alarmChannel = socket.channel("alarm:12_345", {})

        alarmChannel.join()
          .receive("ok", resp => {
            console.log("Joined alarm channel", resp)
          })
          .receive("error", resp => {
            console.log("Unable to join", resp)
          })

        // Listen for __events
        alarmChannel.on("alarm_updated", payload => {
          console.log("Alarm updated:", payload)
        })

        // Send __events
        alarmChannel.push("acknowledge_alarm", {notes: "Investigating"})
          .receive("ok", resp => console.log("Acknowledged"))
          .receive("error", err => console.log("Error:", err))
        """
      },
      %{
        "title" => "Swift / iOS Connection",
        "language" => "swift",
        "code" => """
        import Phoenix

        // Create socket
        let socket = Socket(endPoint: "wss://api.intelitor.com", transport: { url in
            return URLSessionTransport(url: url)
        })

        // Set connection __params
        socket._defaultPayload = ["token": authToken]

        // Connect
        socket.connect()

        // Join channel
        let channel = socket.channel("alarm:12_345", payload: [:])

        channel.join()
          .receive("ok") { response in
              print("Joined channel")
          }
          .receive("error") { reason in
              print("Failed to join: \\(reason)")
          }

        // Listen for __events
        channel.on("alarm_updated") { payload in
            print("Alarm updated: \\(payload)")
        }

        // Send __events
        channel.push("acknowledge_alarm", payload: ["notes": "Investigating"])
          .receive("ok") { response in
              print("Acknowledged")
          }
        """
      },
      %{
        "title" => "Kotlin / Android Connection",
        "language" => "kotlin",
        "code" => """
        import org.phoenixframework.Channel
        import org.phoenixframework.Socket

        // Create socket
        val socket =
        _socket.__params = hashMapOf("token" to authToken)

        // Connect
        socket.connect()

        // Join channel
        val channel =
        _channel.join()
            .receive("ok") { response ->
                Log.d("Socket", "Joined channel")
            }
            .receive("error") { reason ->
                Log.e("Socket", "Failed to join: $reason")
            }

        // Listen for __events
        channel.on("alarm_updated") { payload ->
            Log.d("Socket", "Alarm updated: $payload")
        }

        // Send __events
        channel.push("acknowledge_alarm", mapOf("notes" to "Investigating"))
            .receive("ok") { response ->
                Log.d("Socket", "Acknowledged")
            }
        """
      }
    ]
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
