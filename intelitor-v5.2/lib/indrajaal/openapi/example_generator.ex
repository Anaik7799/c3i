defmodule Indrajaal.OpenAPI.ExampleGenerator do
  @moduledoc """
  Generates realistic examples for OpenAPI specification.

  Creates example _requests, responses, and error scenarios
  with realistic data.

  Agent: Helper - 4 generates examples
  SOPv5.1 Compliance: ✅
  """

  @doc """
  Generates all examples for the specification.
  """
  def generate_all do
    %{
      "auth_examples" => generate_auth_examples(),
      "alarm_examples" => generate_alarm_examples(),
      "device_examples" => generate_device_examples(),
      "error_examples" => generate_error_examples(),
      "bulk_examples" => generate_bulk_examples()
    }
  end

  defp generate_auth_examples do
    %{
      "login_request" => %{
        "summary" => "Standard login _request",
        "value" => %{
          "__username" => "john.smith@acmecorp.com",
          "password" => "SecureP@ssw0rd123!",
          "device_id" => "iPhone - A1B2C3D4",
          "device_name" => "John's iPhone 14 Pro",
          "platform" => "ios",
          "app_version" => "2.3.1",
          "push_token" => "fJzKlmNoPqRsTuVwXyZ123456789abcdefghijk"
        }
      },
      "login_response_success" => %{
        "summary" => "Successful login response",
        "value" => %{
          "token" =>
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1NTBhOGI4YS04MjljLTRiMTAtOWJjZi02MDJmZmE2YjhlNmIiLCJ0ZW5hbnRfaWQiOiI5ODc2NTQzMi0xMjM0LTU2NzgtOTAxMi0zNDU2Nzg5MDEyMzQiLCJyb2xlIjoic3VwZXJ2aXNvciIsInBlcm1pc3Npb25zIjpbImFsYXJtLnZpZXciLCJhbGFybS5hY2tub3dsZWRnZSIsImRldmljZS52aWV3IiwiZGV2aWNlLmNvbnRyb2wiXSwiZGV2aWNlX2lkIjoiaVBob25lLUExQjJDM0Q0IiwiZXhwIjoxNzA0MTIzNjAwLCJpYXQiOjE3MDQxMjAwMDB9.x5K6cm_N7f5X1vH3F5AZxUPGCr4tcE94gWmFyqGqSu8",
          "refresh_token" =>
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1NTBhOGI4YS04MjljLTRiMTAtOWJjZi02MDJmZmE2YjhlNmIiLCJ0eXBlIjoicmVmcmVzaCIsImV4cCI6MTcwNjcxMjAwMH0.abc123def456ghi789jkl012mno345pqr678stu901vwx234yz",
          "expires_in" => 3600,
          "token_type" => "Bearer",
          "user" => %{
            "id" => "550a8b8a - 829c - 4b10 - 9bcf - 602ffa6b8e6b",
            "email" => "john.smith@acmecorp.com",
            "name" => "John Smith",
            "role" => "supervisor",
            "tenant_id" => "98_765_432 - 1234 - 5678 - 9012 - 345_678_901_234",
            "avatar_url" => "https://api.intelitor.com / avatars / 550a8b8a.jpg",
            "locale" => "en",
            "timezone" => "America / New_York"
          },
          "permissions" => [
            "alarm.view",
            "alarm.acknowledge",
            "alarm.resolve",
            "device.view",
            "device.control",
            "site.view",
            "visitor.create",
            "visitor.checkin"
          ]
        }
      },
      "login_response_mfa_required" => %{
        "summary" => "MFA _required response",
        "value" => %{
          "_requires_mfa" => true,
          "mfa_token" => "mfa_tmp_AbCdEfGhIjKlMnOpQrStUvWxYz123456",
          "mfa_methods" => ["totp", "sms"],
          "expires_in" => 300
        }
      },
      "mfa_verification" => %{
        "summary" => "MFA verification _request",
        "value" => %{
          "mfa_token" => "mfa_tmp_AbCdEfGhIjKlMnOpQrStUvWxYz123456",
          "code" => "847_293"
        }
      },
      "biometric_login" => %{
        "summary" => "Biometric login _request",
        "value" => %{
          "biometric_token" =>
            "bio_enc_H4sIAAAAAAAAA61UXW + bMBR951e8 + jmKMSQkr02TKlLXaZPWTZP2hjC + BKvGZrZJ2n + fTQhN2nV7mPZiydxzz / nce3V8w1",
          "device_id" => "iPhone - A1B2C3D4"
        }
      },
      "token_refresh" => %{
        "summary" => "Token refresh _request",
        "value" => %{
          "refresh_token" =>
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1NTBhOGI4YS04MjljLTRiMTAtOWJjZi02MDJmZmE2YjhlNmIiLCJ0eXBlIjoicmVmcmVzaCIsImV4cCI6MTcwNjcxMjAwMH0.abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
        }
      },
      "logout_response" => %{
        "summary" => "Successful logout response",
        "value" => %{
          "message" => "Successfully logged out",
          "devices_logged_out" => 1
        }
      }
    }
  end

  defp generate_alarm_examples do
    %{
      "alarm_acknowledge" => %{
        "summary" => "Acknowledge an alarm",
        "value" => %{
          "notes" => "Security guard on site, investigating the cause"
        }
      },
      "alarm_resolve" => %{
        "summary" => "Resolve an alarm",
        "value" => %{
          "resolution" => "False alarm - motion sensor triggered by maintenance staff",
          "root_cause" => "Maintenance schedule not updated in system"
        }
      },
      "alarm_escalate" => %{
        "summary" => "Escalate an alarm",
        "value" => %{
          "reason" => "Unable to contact on - site personnel",
          "urgency" => "high"
        }
      },
      "alarm_list_response" => %{
        "summary" => "List of active alarms",
        "value" => %{
          "__data" => [
            %{
              "id" => "f47ac10b - 58cc - 4372 - a567 - 0e02b2c3d479",
              "name" => "Motion Detection - Main Entrance",
              "priority" => "high",
              "status" => "active",
              "device_id" => "d290f1ee - 6c54 - 4b01 - 90e6 - d701748f0851",
              "site_id" => "85144b5f - 0e8e - 4d2e - 8b5f - 8c8b9d8e9f9a",
              "triggered_at" => "2024 - 01 - 02T15:30:00Z",
              "description" => "Motion detected at main entrance after hours"
            }
          ],
          "pagination" => %{
            "page" => 1,
            "page_size" => 20,
            "total_pages" => 5,
            "total_items" => 87,
            "has_next" => true,
            "has_previous" => false
          }
        }
      }
    }
  end

  defp generate_device_examples do
    %{
      "device_command" => %{
        "summary" => "Send command to device",
        "value" => %{
          "command" => "arm_device",
          "parameters" => %{
            "mode" => "perimeter_only",
            "duration_minutes" => 480
          }
        }
      },
      "device_status_response" => %{
        "summary" => "Device status response",
        "value" => %{
          "id" => "d290f1ee - 6c54 - 4b01 - 90e6 - d701748f0851",
          "name" => "Main Entrance Camera",
          "type" => "camera",
          "status" => "online",
          "model" => "AXIS P3375 - V",
          "serial_number" => "ACCC8EF55B2C",
          "firmware_version" => "9.80.2.2",
          "last_seen" => "2024 - 01 - 02T16:45:32Z",
          "attributes" => %{
            "resolution" => "1920x1080",
            "fps" => 30,
            "storage_used_gb" => 245.7,
            "storage_total_gb" => 500
          }
        }
      },
      "device_maintenance_mode" => %{
        "summary" => "Set device maintenance mode",
        "value" => %{
          "enabled" => true,
          "reason" => "Scheduled firmware upgrade"
        }
      }
    }
  end

  defp generate_error_examples do
    %{
      "validation_error" => %{
        "summary" => "Validation error response",
        "value" => %{
          "error" => "validation_error",
          "message" => "Validation failed",
          "errors" => %{
            "email" => ["is invalid"],
            "password" => ["is too short (minimum 8 characters)"],
            "device_id" => ["can't be blank"]
          }
        }
      },
      "rate_limit_error" => %{
        "summary" => "Rate limit exceeded",
        "value" => %{
          "error" => "rate_limit_exceeded",
          "message" => "Too many _requests",
          "retry_after" => 45
        }
      },
      "unauthorized_error" => %{
        "summary" => "Unauthorized access",
        "value" => %{
          "error" => "unauthorized",
          "message" => "Invalid or expired token",
          "_request_id" => "_req_2hf8d9h2d982h3d"
        }
      },
      "not_found_error" => %{
        "summary" => "Resource not found",
        "value" => %{
          "error" => "not_found",
          "message" => "The _requested resource was not found",
          "_request_id" => "_req_9j3d8f7g6h5j4k3"
        }
      }
    }
  end

  defp generate_bulk_examples do
    %{
      "bulk_create_request" => %{
        "summary" => "Bulk create devices",
        "value" => %{
          "records" => [
            %{
              "name" => "Camera - Floor 1 North",
              "type" => "camera",
              "model" => "AXIS P3375 - V",
              "site_id" => "85144b5f - 0e8e - 4d2e - 8b5f - 8c8b9d8e9f9a"
            },
            %{
              "name" => "Camera - Floor 1 South",
              "type" => "camera",
              "model" => "AXIS P3375 - V",
              "site_id" => "85144b5f - 0e8e - 4d2e - 8b5f - 8c8b9d8e9f9a"
            }
          ],
          "options" => %{
            "all_or_nothing" => true
          }
        }
      },
      "bulk_operation_response" => %{
        "summary" => "Bulk operation results",
        "value" => %{
          "created" => 2,
          "failed" => 0,
          "errors" => [],
          "records" => [
            %{
              "id" => "a1b2c3d4 - e5f6 - 7890 - abcd - ef1234567890",
              "name" => "Camera - Floor 1 North"
            },
            %{
              "id" => "b2c3d4e5 - f6a7 - 8901 - bcde - f23456789012",
              "name" => "Camera - Floor 1 South"
            }
          ]
        }
      },
      "bulk_operation_partial_failure" => %{
        "summary" => "Bulk operation with failures",
        "value" => %{
          "created" => 1,
          "failed" => 1,
          "errors" => [
            %{
              "index" => 1,
              "error" => "Duplicate name",
              "details" => %{
                "name" => ["has already been taken"]
              }
            }
          ],
          "records" => [
            %{
              "id" => "a1b2c3d4 - e5f6 - 7890 - abcd - ef1234567890",
              "name" => "Camera - Floor 1 North"
            }
          ]
        }
      }
    }
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
