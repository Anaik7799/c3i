defmodule Indrajaal.OpenAPI.SchemaExtractor do
  @moduledoc """
  Extracts and generates OpenAPI schemas from Elixir modules.

  Analyzes Ecto schemas, _request / response structures, and
  generates complete OpenAPI schema definitions.

  Agent: Helper - 2 extracts schemas
  SOPv5.1 Compliance: OK
  """

  @doc """
  Generates all schemas for the OpenAPI specification.
  """
  def generate_all_schemas do
    %{}
    |> add_auth_schemas()
    |> add_domain_schemas()
    |> add_common_schemas()
    |> add_error_schemas()
    |> add_mobile_specific_schemas()
  end

  @spec add_auth_schemas(map()) :: map()
  defp add_auth_schemas(schemas) do
    Map.merge(schemas, %{
      # Login _request
      "LoginRequest" => %{
        "type" => "object",
        "_required" => ["__username", "password"],
        "properties" => %{
          "__username" => %{
            "type" => "string",
            "format" => "email",
            "description" => "User's email address"
          },
          "password" => %{
            "type" => "string",
            "format" => "password",
            "minLength" => 8,
            "description" => "User's password"
          },
          "device_id" => %{
            "type" => "string",
            "description" => "Unique device identifier"
          },
          "device_name" => %{
            "type" => "string",
            "description" => "Human - readable device name"
          },
          "platform" => %{
            "type" => "string",
            "enum" => ["ios", "android"],
            "description" => "Mobile platform"
          },
          "app_version" => %{
            "type" => "string",
            "pattern" => "^\\d+\\.\\d+\\.\\d+\\z",
            "description" => "Mobile app version"
          },
          "push_token" => %{
            "type" => "string",
            "description" => "Push notification token"
          }
        }
      },

      # Login response
      "LoginResponse" => %{
        "type" => "object",
        "_required" => ["token", "refresh_token", "user"],
        "properties" => %{
          "token" => %{
            "type" => "string",
            "description" => "JWT access token"
          },
          "refresh_token" => %{
            "type" => "string",
            "description" => "JWT refresh token"
          },
          "expires_in" => %{
            "type" => "integer",
            "description" => "Token expiry time in seconds"
          },
          "token_type" => %{
            "type" => "string",
            "default" => "Bearer"
          },
          "user" => %{
            "$ref" => "#/components / schemas / UserProfile"
          },
          "permissions" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "description" => "User's permissions"
          },
          "_requires_mfa" => %{
            "type" => "boolean",
            "description" => "Whether MFA is _required"
          },
          "mfa_token" => %{
            "type" => "string",
            "description" => "Temporary token for MFA verification"
          }
        }
      },

      # Biometric login
      "BiometricLoginRequest" => %{
        "type" => "object",
        "_required" => ["biometric_token", "device_id"],
        "properties" => %{
          "biometric_token" => %{
            "type" => "string",
            "description" => "Encrypted biometric authentication token"
          },
          "device_id" => %{
            "type" => "string",
            "description" => "Registered device identifier"
          }
        }
      },

      # MFA verification
      "MFAVerificationRequest" => %{
        "type" => "object",
        "_required" => ["mfa_token", "code"],
        "properties" => %{
          "mfa_token" => %{
            "type" => "string",
            "description" => "Temporary MFA token from login"
          },
          "code" => %{
            "type" => "string",
            "pattern" => "^\\d{6}\\z",
            "description" => "6 - digit TOTP code"
          }
        }
      },

      # Token refresh
      "TokenRefreshRequest" => %{
        "type" => "object",
        "_required" => ["refresh_token"],
        "properties" => %{
          "refresh_token" => %{
            "type" => "string",
            "description" => "Valid refresh token"
          }
        }
      },

      # User profile
      "UserProfile" => %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "format" => "uuid"
          },
          "email" => %{
            "type" => "string",
            "format" => "email"
          },
          "name" => %{
            "type" => "string"
          },
          "role" => %{
            "type" => "string",
            "enum" => ["admin", "supervisor", "operator", "viewer"]
          },
          "tenant_id" => %{
            "type" => "string",
            "format" => "uuid"
          },
          "avatar_url" => %{
            "type" => "string",
            "format" => "uri"
          },
          "locale" => %{
            "type" => "string",
            "default" => "en"
          },
          "timezone" => %{
            "type" => "string",
            "default" => "UTC"
          }
        }
      }
    })
  end

  @spec add_domain_schemas(map()) :: map()
  defp add_domain_schemas(schemas) do
    # Generate schemas for each domain
    domains = [
      {"Alarm", alarm_schema()},
      {"Device", device_schema()},
      {"Site", site_schema()},
      {"User", __user_schema()},
      {"Guard", guard_schema()},
      {"Visitor", visitor_schema()},
      {"Incident", incident_schema()},
      {"Patrol", patrol_schema()},
      {"Shift", shift_schema()}
    ]

    Enum.reduce(domains, schemas, fn {name, schema}, acc ->
      acc
      |> Map.put(name, schema)
      |> Map.put("#{name}CreateRequest", generate_create_request(schema))
      |> Map.put("#{name}UpdateRequest", generate_update_request(schema))
      |> Map.put("#{name}ListResponse", generate_list_response(name))
    end)
  end

  defp alarm_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "name" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "priority" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high", "critical"]
        },
        "status" => %{
          "type" => "string",
          "enum" => ["active", "acknowledged", "resolved", "escalated"]
        },
        "device_id" => %{"type" => "string", "format" => "uuid"},
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "triggered_at" => %{"type" => "string", "format" => "date - time"},
        "acknowledged_at" => %{"type" => "string", "format" => "date - time"},
        "acknowledged_by" => %{"type" => "string", "format" => "uuid"},
        "resolved_at" => %{"type" => "string", "format" => "date - time"},
        "resolved_by" => %{"type" => "string", "format" => "uuid"},
        "resolution" => %{"type" => "string"},
        "meta_data" => %{"type" => "object"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp device_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "name" => %{"type" => "string"},
        "type" => %{
          "type" => "string",
          "enum" => ["camera", "sensor", "access_control", "alarm_panel", "other"]
        },
        "model" => %{"type" => "string"},
        "serial_number" => %{"type" => "string"},
        "firmware_version" => %{"type" => "string"},
        "status" => %{
          "type" => "string",
          "enum" => ["online", "offline", "maintenance", "error"]
        },
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "location" => %{
          "type" => "object",
          "properties" => %{
            "building" => %{"type" => "string"},
            "floor" => %{"type" => "string"},
            "room" => %{"type" => "string"},
            "coordinates" => %{
              "type" => "object",
              "properties" => %{
                "latitude" => %{"type" => "number"},
                "longitude" => %{"type" => "number"}
              }
            }
          }
        },
        "ip_address" => %{"type" => "string", "format" => "ipv4"},
        "mac_address" => %{"type" => "string"},
        "last_seen" => %{"type" => "string", "format" => "date - time"},
        "attributes" => %{"type" => "object"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp site_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "name" => %{"type" => "string"},
        "code" => %{"type" => "string"},
        "type" => %{
          "type" => "string",
          "enum" => ["office", "warehouse", "retail", "residential", "industrial"]
        },
        "address" => %{
          "type" => "object",
          "properties" => %{
            "street" => %{"type" => "string"},
            "city" => %{"type" => "string"},
            "state" => %{"type" => "string"},
            "postal_code" => %{"type" => "string"},
            "country" => %{"type" => "string"}
          }
        },
        "coordinates" => %{
          "type" => "object",
          "properties" => %{
            "latitude" => %{"type" => "number"},
            "longitude" => %{"type" => "number"}
          }
        },
        "timezone" => %{"type" => "string"},
        "operating_hours" => %{
          "type" => "object",
          "properties" => %{
            "monday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "tuesday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "wednesday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "thursday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "friday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "saturday" => %{"$ref" => "#/components / schemas / DaySchedule"},
            "sunday" => %{"$ref" => "#/components / schemas / DaySchedule"}
          }
        },
        "contact_info" => %{
          "type" => "object",
          "properties" => %{
            "primary_contact" => %{"type" => "string"},
            "phone" => %{"type" => "string"},
            "email" => %{"type" => "string", "format" => "email"}
          }
        },
        "attributes" => %{"type" => "object"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp __user_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "email" => %{"type" => "string", "format" => "email"},
        "name" => %{"type" => "string"},
        "role" => %{
          "type" => "string",
          "enum" => ["admin", "supervisor", "operator", "viewer"]
        },
        "status" => %{
          "type" => "string",
          "enum" => ["active", "inactive", "suspended"]
        },
        "phone" => %{"type" => "string"},
        "department" => %{"type" => "string"},
        "employee_id" => %{"type" => "string"},
        "permissions" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "sites" => %{
          "type" => "array",
          "items" => %{"type" => "string", "format" => "uuid"}
        },
        "last_login" => %{"type" => "string", "format" => "date - time"},
        "mfa_enabled" => %{"type" => "boolean"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp guard_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "user_id" => %{"type" => "string", "format" => "uuid"},
        "badge_number" => %{"type" => "string"},
        "license_number" => %{"type" => "string"},
        "license_expiry" => %{"type" => "string", "format" => "date"},
        "certifications" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "issuer" => %{"type" => "string"},
              "expiry" => %{"type" => "string", "format" => "date"}
            }
          }
        },
        "assigned_sites" => %{
          "type" => "array",
          "items" => %{"type" => "string", "format" => "uuid"}
        },
        "shift_pattern" => %{"type" => "string"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp visitor_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "name" => %{"type" => "string"},
        "email" => %{"type" => "string", "format" => "email"},
        "phone" => %{"type" => "string"},
        "company" => %{"type" => "string"},
        "purpose" => %{"type" => "string"},
        "host_name" => %{"type" => "string"},
        "host_email" => %{"type" => "string", "format" => "email"},
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "check_in_time" => %{"type" => "string", "format" => "date - time"},
        "check_out_time" => %{"type" => "string", "format" => "date - time"},
        "badge_number" => %{"type" => "string"},
        "photo_url" => %{"type" => "string", "format" => "uri"},
        "id_type" => %{"type" => "string"},
        "id_number" => %{"type" => "string"},
        "vehicle_info" => %{
          "type" => "object",
          "properties" => %{
            "make" => %{"type" => "string"},
            "model" => %{"type" => "string"},
            "license_plate" => %{"type" => "string"}
          }
        },
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp incident_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "incident_number" => %{"type" => "string"},
        "type" => %{
          "type" => "string",
          "enum" => ["security", "safety", "medical", "fire", "environmental", "other"]
        },
        "severity" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high", "critical"]
        },
        "status" => %{
          "type" => "string",
          "enum" => ["open", "investigating", "resolved", "closed"]
        },
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "location" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "reported_by" => %{"type" => "string", "format" => "uuid"},
        "reported_at" => %{"type" => "string", "format" => "date - time"},
        "assigned_to" => %{"type" => "string", "format" => "uuid"},
        "resolution" => %{"type" => "string"},
        "resolved_at" => %{"type" => "string", "format" => "date - time"},
        "attachments" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "url" => %{"type" => "string", "format" => "uri"},
              "type" => %{"type" => "string"}
            }
          }
        },
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp patrol_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "name" => %{"type" => "string"},
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "route" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "checkpoint_id" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "coordinates" => %{
                "type" => "object",
                "properties" => %{
                  "latitude" => %{"type" => "number"},
                  "longitude" => %{"type" => "number"}
                }
              },
              "qr_code" => %{"type" => "string"},
              "tasks" => %{
                "type" => "array",
                "items" => %{"type" => "string"}
              }
            }
          }
        },
        "f_requency" => %{"type" => "string"},
        "duration_minutes" => %{"type" => "integer"},
        "active" => %{"type" => "boolean"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  defp shift_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string", "format" => "uuid"},
        "tenant_id" => %{"type" => "string", "format" => "uuid"},
        "guard_id" => %{"type" => "string", "format" => "uuid"},
        "site_id" => %{"type" => "string", "format" => "uuid"},
        "start_time" => %{"type" => "string", "format" => "date - time"},
        "end_time" => %{"type" => "string", "format" => "date - time"},
        "actual_start" => %{"type" => "string", "format" => "date - time"},
        "actual_end" => %{"type" => "string", "format" => "date - time"},
        "status" => %{
          "type" => "string",
          "enum" => ["scheduled", "in_progress", "completed", "cancelled"]
        },
        "notes" => %{"type" => "string"},
        "handover_notes" => %{"type" => "string"},
        "created_at" => %{"type" => "string", "format" => "date - time"},
        "updated_at" => %{"type" => "string", "format" => "date - time"}
      }
    }
  end

  @spec generate_create_request(map()) :: map()
  defp generate_create_request(schema) do
    # Remove read - only fields from create _request
    properties =
      schema["properties"]
      |> Map.drop(["id", "tenant_id", "created_at", "updated_at"])

    %{
      "type" => "object",
      "properties" => properties,
      "_required" => extract_required_fields(properties)
    }
  end

  @spec generate_update_request(map()) :: map()
  defp generate_update_request(schema) do
    # Remove read - only fields and make all fields optional
    properties =
      schema["properties"]
      |> Map.drop(["id", "tenant_id", "created_at", "updated_at"])

    %{
      "type" => "object",
      "properties" => properties
    }
  end

  @spec generate_list_response(String.t()) :: map()
  defp generate_list_response(name) do
    %{
      "type" => "object",
      "properties" => %{
        "__data" => %{
          "type" => "array",
          "items" => %{"$ref" => "#/components / schemas/#{name}"}
        },
        "pagination" => %{
          "$ref" => "#/components / schemas / PaginationInfo"
        }
      }
    }
  end

  @spec extract_required_fields(map()) :: list(String.t())
  defp extract_required_fields(properties) do
    # Determine which fields should be _required based on type
    properties
    |> Enum.filter(fn {key, _schema} ->
      key in ["name", "email", "type", "status", "priority"]
    end)
    |> Enum.map(fn {key, _} -> key end)
  end

  @spec add_common_schemas(map()) :: map()
  defp add_common_schemas(schemas) do
    Map.merge(schemas, %{
      # Pagination
      "PaginationInfo" => %{
        "type" => "object",
        "properties" => %{
          "page" => %{"type" => "integer"},
          "page_size" => %{"type" => "integer"},
          "total_pages" => %{"type" => "integer"},
          "total_items" => %{"type" => "integer"},
          "has_next" => %{"type" => "boolean"},
          "has_previous" => %{"type" => "boolean"}
        }
      },

      # Bulk operations
      "BulkCreateRequest" => %{
        "type" => "object",
        "_required" => ["records"],
        "properties" => %{
          "records" => %{
            "type" => "array",
            "minItems" => 1,
            "maxItems" => 100,
            "items" => %{"type" => "object"}
          },
          "options" => %{
            "type" => "object",
            "properties" => %{
              "all_or_nothing" => %{
                "type" => "boolean",
                "default" => false,
                "description" => "Rollback all if any record fails"
              }
            }
          }
        }
      },
      "BulkOperationResponse" => %{
        "type" => "object",
        "properties" => %{
          "created" => %{"type" => "integer"},
          "failed" => %{"type" => "integer"},
          "errors" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "index" => %{"type" => "integer"},
                "error" => %{"type" => "string"},
                "details" => %{"type" => "object"}
              }
            }
          },
          "records" => %{
            "type" => "array",
            "items" => %{"type" => "object"}
          }
        }
      },

      # Import / Export
      "ImportRequest" => %{
        "type" => "object",
        "_required" => ["file"],
        "properties" => %{
          "file" => %{
            "type" => "string",
            "format" => "binary",
            "description" => "CSV or JSON file"
          },
          "format" => %{
            "type" => "string",
            "enum" => ["csv", "json"],
            "default" => "csv"
          },
          "options" => %{
            "type" => "object",
            "properties" => %{
              "update_existing" => %{"type" => "boolean", "default" => false},
              "validate_only" => %{"type" => "boolean", "default" => false}
            }
          }
        }
      },
      "ImportResponse" => %{
        "type" => "object",
        "properties" => %{
          "imported" => %{"type" => "integer"},
          "updated" => %{"type" => "integer"},
          "failed" => %{"type" => "integer"},
          "errors" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "row" => %{"type" => "integer"},
                "error" => %{"type" => "string"},
                "__data" => %{"type" => "object"}
              }
            }
          }
        }
      },

      # Day schedule for operating hours
      "DaySchedule" => %{
        "type" => "object",
        "properties" => %{
          "open" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"},
          "close" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"},
          "closed" => %{"type" => "boolean", "default" => false}
        }
      }
    })
  end

  @spec add_error_schemas(map()) :: map()
  defp add_error_schemas(schemas) do
    Map.merge(schemas, %{
      "ErrorResponse" => %{
        "type" => "object",
        "_required" => ["error", "message"],
        "properties" => %{
          "error" => %{
            "type" => "string",
            "description" => "Error code"
          },
          "message" => %{
            "type" => "string",
            "description" => "Human - readable error message"
          },
          "details" => %{
            "type" => "object",
            "description" => "Additional error details"
          },
          "_request_id" => %{
            "type" => "string",
            "description" => "Request ID for support"
          }
        }
      },
      "ValidationErrorResponse" => %{
        "type" => "object",
        "_required" => ["error", "message", "errors"],
        "properties" => %{
          "error" => %{
            "type" => "string",
            "default" => "validation_error"
          },
          "message" => %{
            "type" => "string",
            "default" => "Validation failed"
          },
          "errors" => %{
            "type" => "object",
            "additionalProperties" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            },
            "description" => "Field - specific validation errors"
          }
        }
      },
      "RateLimitResponse" => %{
        "type" => "object",
        "_required" => ["error", "message", "retry_after"],
        "properties" => %{
          "error" => %{
            "type" => "string",
            "default" => "rate_limit_exceeded"
          },
          "message" => %{
            "type" => "string",
            "default" => "Rate limit exceeded"
          },
          "retry_after" => %{
            "type" => "integer",
            "description" => "Seconds until rate limit resets"
          }
        }
      }
    })
  end

  @spec add_mobile_specific_schemas(map()) :: map()
  defp add_mobile_specific_schemas(schemas) do
    Map.merge(schemas, %{
      # Dashboard response
      "DashboardResponse" => %{
        "type" => "object",
        "properties" => %{
          "summary" => %{
            "type" => "object",
            "properties" => %{
              "active_alarms" => %{"type" => "integer"},
              "devices_online" => %{"type" => "integer"},
              "devices_total" => %{"type" => "integer"},
              "visitors_today" => %{"type" => "integer"},
              "incidents_open" => %{"type" => "integer"}
            }
          },
          "recent_alarms" => %{
            "type" => "array",
            "items" => %{"$ref" => "#/components / schemas / Alarm"}
          },
          "upcoming_shifts" => %{
            "type" => "array",
            "items" => %{"$ref" => "#/components / schemas / Shift"}
          },
          "site_status" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "site_id" => %{"type" => "string", "format" => "uuid"},
                "name" => %{"type" => "string"},
                "status" => %{"type" => "string"},
                "alarm_count" => %{"type" => "integer"}
              }
            }
          }
        }
      },

      # Device registration
      "DeviceRegistrationRequest" => %{
        "type" => "object",
        "_required" => ["device_id", "platform", "push_token"],
        "properties" => %{
          "device_id" => %{
            "type" => "string",
            "description" => "Unique device identifier"
          },
          "device_name" => %{
            "type" => "string",
            "description" => "Human - readable device name"
          },
          "platform" => %{
            "type" => "string",
            "enum" => ["ios", "android"]
          },
          "push_token" => %{
            "type" => "string",
            "description" => "FCM or APNS token"
          },
          "app_version" => %{
            "type" => "string"
          },
          "os_version" => %{
            "type" => "string"
          }
        }
      },
      "DeviceRegistrationResponse" => %{
        "type" => "object",
        "properties" => %{
          "device_id" => %{"type" => "string"},
          "registered" => %{"type" => "boolean"},
          "preferences_synced" => %{"type" => "boolean"}
        }
      },

      # Notification preferences
      "NotificationPreferences" => %{
        "type" => "object",
        "properties" => %{
          "alarm_notifications" => %{"type" => "boolean", "default" => true},
          "critical_alarm_notifications" => %{"type" => "boolean", "default" => true},
          "device_notifications" => %{"type" => "boolean", "default" => true},
          "maintenance_notifications" => %{"type" => "boolean", "default" => true},
          "system_notifications" => %{"type" => "boolean", "default" => true},
          "push_enabled" => %{"type" => "boolean", "default" => true},
          "email_enabled" => %{"type" => "boolean", "default" => false},
          "quiet_hours_enabled" => %{"type" => "boolean", "default" => false},
          "quiet_hours_start" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"},
          "quiet_hours_end" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"}
        }
      },

      # Notification preferences update
      "NotificationPreferencesUpdate" => %{
        "type" => "object",
        "properties" => %{
          "alarm_notifications" => %{"type" => "boolean"},
          "critical_alarm_notifications" => %{"type" => "boolean"},
          "device_notifications" => %{"type" => "boolean"},
          "maintenance_notifications" => %{"type" => "boolean"},
          "system_notifications" => %{"type" => "boolean"},
          "push_enabled" => %{"type" => "boolean"},
          "email_enabled" => %{"type" => "boolean"},
          "quiet_hours_enabled" => %{"type" => "boolean"},
          "quiet_hours_start" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"},
          "quiet_hours_end" => %{"type" => "string", "pattern" => "^\\d{2}:\\d{2}\\z"}
        }
      },

      # Sync _request / response
      "SyncRequest" => %{
        "type" => "object",
        "properties" => %{
          "last_sync" => %{
            "type" => "string",
            "format" => "date - time",
            "description" => "Last successful sync timestamp"
          },
          "device_id" => %{
            "type" => "string",
            "description" => "Device identifier"
          },
          "changes" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "entity_type" => %{"type" => "string"},
                "entity_id" => %{"type" => "string"},
                "operation" => %{"type" => "string", "enum" => ["create", "update", "delete"]},
                "__data" => %{"type" => "object"},
                "client_timestamp" => %{"type" => "string", "format" => "date - time"}
              }
            }
          }
        }
      },
      "SyncResponse" => %{
        "type" => "object",
        "properties" => %{
          "sync_id" => %{"type" => "string"},
          "server_timestamp" => %{"type" => "string", "format" => "date - time"},
          "changes_applied" => %{"type" => "integer"},
          "conflicts" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "entity_type" => %{"type" => "string"},
                "entity_id" => %{"type" => "string"},
                "conflict_type" => %{"type" => "string"},
                "server_version" => %{"type" => "object"},
                "client_version" => %{"type" => "object"}
              }
            }
          },
          "__data" => %{
            "type" => "object",
            "properties" => %{
              "alarms" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components / schemas / Alarm"}
              },
              "devices" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components / schemas / Device"}
              },
              "sites" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components / schemas / Site"}
              }
            }
          }
        }
      }
    })
  end
end
