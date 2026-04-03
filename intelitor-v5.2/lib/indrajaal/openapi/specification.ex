defmodule Indrajaal.OpenAPI.Specification do
  @moduledoc """
  OpenAPI 3.1 specification generator for the Indrajaal Mobile API.

  Generates a complete OpenAPI specification including all REST endpoints,
  schemas, examples, and WebSocket documentation.

  Agent: Helper - 1 generates OpenAPI specification
  SOPv5.1 Compliance: OK
  """

  alias Indrajaal.OpenAPI.{
    SchemaExtractor,
    ExampleGenerator,
    WebSocketDocumentor,
    SecuritySchemes
  }

  @version "1.0.0"
  @api_title "Indrajaal Security Monitoring API"

  @doc """
  Generates the complete OpenAPI 3.1 specification.
  """
  def generate do
    %{
      "openapi" => "3.1.0",
      "info" => generate_info(),
      "servers" => generate_servers(),
      "paths" => generate_paths(),
      "components" => generate_components(),
      "security" => [%{"bearerAuth" => []}],
      "tags" => generate_tags(),
      "x - websockets" => generate_websocket_docs()
    }
  end

  @doc """
  Exports the specification to a file.
  """
  @spec export_to_file(String.t()) :: {:ok, String.t()}
  def export_to_file(path \\ "priv / static / openapi.json") do
    spec = generate()

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(spec, pretty: true))

    {:ok, path}
  end

  @doc """
  Exports specification in YAML format.
  """
  @spec export_to_yaml(String.t()) :: {:ok, String.t()}
  def export_to_yaml(path \\ "priv / static / openapi.yaml") do
    spec = generate()

    File.mkdir_p!(Path.dirname(path))

    # Convert to YAML (would use a YAML library in production)
    yaml_content = json_to_yaml(spec)
    File.write!(path, yaml_content)

    {:ok, path}
  end

  # Private functions

  defp generate_info do
    %{
      "title" => @api_title,
      "version" => @version,
      "description" => """
      The Indrajaal Security Monitoring API provides comprehensive access to security
      monitoring capabilities including alarm management, device control, visitor
      management, and real - time notifications.

      ## Authentication

      Most endpoints require JWT authentication. Include the JWT token in the
      Authorization header:

      ```
      Authorization: Bearer YOUR_JWT_TOKEN
      ```

      ## Rate Limiting

      API calls are rate limited per user. Rate limit information is included
      in response headers:

      - `X - RateLimit - Limit`: Maximum _requests per window
      - `X - RateLimit - Remaining`: Remaining _requests in current window
      - `X - RateLimit - Reset`: Unix timestamp when window resets

      ## WebSocket Support

      Real - time features are available via WebSocket connections. See the
      x - websockets section for details.
      """,
      "termsOfService" => "https://api.intelitor.com / terms",
      "contact" => %{
        "name" => "Indrajaal API Support",
        "email" => "api - support@intelitor.com",
        "url" => "https://support.intelitor.com"
      },
      "license" => %{
        "name" => "Proprietary",
        "url" => "https://intelitor.com / licenses / api"
      },
      "x - logo" => %{
        "url" => "https://intelitor.com / assets / logo.png",
        "altText" => "Indrajaal Logo"
      },
      "x - api - id" => "intelitor - mobile - api",
      "x - audience" => "external - partner"
    }
  end

  defp generate_servers do
    [
      %{
        "url" => "https://api.intelitor.com",
        "description" => "Production server",
        "variables" => %{}
      },
      %{
        "url" => "https://staging - api.intelitor.com",
        "description" => "Staging server",
        "variables" => %{}
      },
      %{
        "url" => "http://localhost:4000",
        "description" => "Development server",
        "variables" => %{}
      },
      %{
        "url" => "https://{tenant}.api.intelitor.com",
        "description" => "Tenant - specific server",
        "variables" => %{
          "tenant" => %{
            "default" => "demo",
            "description" => "Tenant identifier"
          }
        }
      }
    ]
  end

  defp generate_paths do
    %{}
    |> add_auth_endpoints()
    |> add_domain_endpoints()
    |> add_mobile_specific_endpoints()
    |> add_health_endpoints()
  end

  @spec add_auth_endpoints(map()) :: map()
  defp add_auth_endpoints(paths) do
    Map.merge(paths, %{
      "/api / mobile / auth / login" => %{
        "post" => %{
          "summary" => "Mobile user login",
          "description" => "Authenticates a mobile user and returns JWT tokens",
          "operationId" => "mobileLogin",
          "tags" => ["Authentication"],
          "security" => [],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / LoginRequest"},
                "examples" => %{
                  "default" => %{
                    "value" => %{
                      "__username" => "john.doe@example.com",
                      "password" => "SecurePassword123!",
                      "device_id" => "iPhone - 12_345",
                      "device_name" => "John's iPhone",
                      "app_version" => "2.1.0"
                    }
                  }
                }
              }
            }
          },
          "responses" => generate_auth_responses()
        }
      },
      "/api / mobile / auth / biometric_login" => %{
        "post" => %{
          "summary" => "Biometric authentication",
          "description" => "Authenticates using biometric token",
          "operationId" => "biometricLogin",
          "tags" => ["Authentication"],
          "security" => [],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / BiometricLoginRequest"}
              }
            }
          },
          "responses" => generate_auth_responses()
        }
      },
      "/api / mobile / auth / verify_mfa" => %{
        "post" => %{
          "summary" => "Verify MFA code",
          "description" => "Completes login by verifying MFA code",
          "operationId" => "verifyMFA",
          "tags" => ["Authentication"],
          "security" => [],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / MFAVerificationRequest"}
              }
            }
          },
          "responses" => generate_auth_responses()
        }
      },
      "/api / mobile / auth / refresh_token" => %{
        "post" => %{
          "summary" => "Refresh access token",
          "description" => "Exchanges refresh token for new access token",
          "operationId" => "refreshToken",
          "tags" => ["Authentication"],
          "security" => [],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / TokenRefreshRequest"}
              }
            }
          },
          "responses" => generate_auth_responses()
        }
      },
      "/api / mobile / auth / logout" => %{
        "post" => %{
          "summary" => "Logout user",
          "description" => "Invalidates tokens and ends session",
          "operationId" => "logout",
          "tags" => ["Authentication"],
          "responses" => %{
            "200" => %{
              "description" => "Successfully logged out",
              "content" => %{
                "application / json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "message" => %{"type" => "string"}
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  end

  @spec add_domain_endpoints(map()) :: map()
  defp add_domain_endpoints(paths) do
    domains = [
      {"alarms", "Alarm configurations"},
      {"devices", "Device configurations"},
      {"sites", "Site configurations"},
      {"__users", "User configurations"},
      {"guards", "Guard configurations"},
      {"visitors", "Visitor configurations"},
      {"incidents", "Incident configurations"},
      {"patrols", "Patrol configurations"},
      {"shifts", "Shift configurations"},
      {"analytics", "Analytics configurations"},
      {"intelligence", "Intelligence configurations"},
      {"integration", "Integration configurations"},
      {"communication", "Communication configurations"},
      {"fleet_management", "Fleet management configurations"},
      {"environmental", "Environmental configurations"},
      {"compliance", "Compliance configurations"},
      {"training", "Training configurations"},
      {"accounts", "Account configurations"}
    ]

    Enum.reduce(domains, paths, fn {domain, description}, acc ->
      acc
      |> add_crud_endpoints(domain, description)
      |> add_bulk_endpoints(domain, description)
      |> add_import_export_endpoints(domain, description)
    end)
  end

  @spec add_crud_endpoints(map(), String.t(), String.t()) :: map()
  defp add_crud_endpoints(paths, domain, description) do
    base_path = "/api / mobile / config/#{domain}"
    item_path = "#{base_path}/{id}"
    tag = String.capitalize(domain) <> " Configuration"

    paths
    |> Map.put(base_path, %{
      "get" => %{
        "summary" => "List #{domain}",
        "description" => "Retrieves a paginated list of #{description}",
        "operationId" => "list#{String.capitalize(domain)}",
        "tags" => [tag],
        "parameters" => [
          %{"$ref" => "#/components / parameters / PageParam"},
          %{"$ref" => "#/components / parameters / PageSizeParam"},
          %{"$ref" => "#/components / parameters / SortByParam"},
          %{"$ref" => "#/components / parameters / SortOrderParam"},
          %{"$ref" => "#/components / parameters / SearchParam"}
        ],
        "responses" => %{
          "200" => %{
            "description" => "List of #{domain}",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" => "#/components / schemas/#{String.capitalize(domain)}List"
                }
              }
            }
          }
        }
      },
      "post" => %{
        "summary" => "Create #{Inflex.singularize(domain)}",
        "description" => "Creates a new #{Inflex.singularize(description)}",
        "operationId" => "create#{String.capitalize(Inflex.singularize(domain))}",
        "tags" => [tag],
        "_requestBody" => %{
          "_required" => true,
          "content" => %{
            "application / json" => %{
              "schema" => %{
                "$ref" =>
                  "#/components / schemas/#{String.capitalize(Inflex.singularize(domain))}Create"
              }
            }
          }
        },
        "responses" => %{
          "201" => %{
            "description" => "Created successfully",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" =>
                    "#/components / schemas/#{String.capitalize(Inflex.singularize(domain))}"
                }
              }
            }
          }
        }
      }
    })
    |> Map.put(item_path, %{
      "parameters" => [
        %{
          "name" => "id",
          "in" => "path",
          "_required" => true,
          "schema" => %{"type" => "string", "format" => "uuid"}
        }
      ],
      "get" => %{
        "summary" => "Get #{Inflex.singularize(domain)}",
        "description" => "Retrieves a specific #{Inflex.singularize(description)}",
        "operationId" => "get#{String.capitalize(Inflex.singularize(domain))}",
        "tags" => [tag],
        "responses" => %{
          "200" => %{
            "description" => "#{String.capitalize(Inflex.singularize(domain))} details",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" =>
                    "#/components / schemas/#{String.capitalize(Inflex.singularize(domain))}"
                }
              }
            }
          },
          "404" => %{"$ref" => "#/components / responses / NotFound"}
        }
      },
      "put" => %{
        "summary" => "Update #{Inflex.singularize(domain)}",
        "description" => "Updates a specific #{Inflex.singularize(description)}",
        "operationId" => "update#{String.capitalize(Inflex.singularize(domain))}",
        "tags" => [tag],
        "_requestBody" => %{
          "_required" => true,
          "content" => %{
            "application / json" => %{
              "schema" => %{
                "$ref" =>
                  "#/components / schemas/#{String.capitalize(Inflex.singularize(domain))}Update"
              }
            }
          }
        },
        "responses" => %{
          "200" => %{
            "description" => "Updated successfully",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" =>
                    "#/components / schemas/#{String.capitalize(Inflex.singularize(domain))}"
                }
              }
            }
          },
          "404" => %{"$ref" => "#/components / responses / NotFound"}
        }
      },
      "delete" => %{
        "summary" => "Delete #{Inflex.singularize(domain)}",
        "description" => "Deletes a specific #{Inflex.singularize(description)}",
        "operationId" => "delete#{String.capitalize(Inflex.singularize(domain))}",
        "tags" => [tag],
        "responses" => %{
          "204" => %{"description" => "Deleted successfully"},
          "404" => %{"$ref" => "#/components / responses / NotFound"}
        }
      }
    })
  end

  @spec add_bulk_endpoints(map(), String.t(), String.t()) :: map()
  defp add_bulk_endpoints(paths, domain, description) do
    bulk_path = "/api / mobile / config/#{domain}/bulk"
    tag = String.capitalize(domain) <> " Configuration"

    Map.put(paths, bulk_path, %{
      "post" => %{
        "summary" => "Bulk create #{domain}",
        "description" => "Creates multiple #{description} in a single transaction",
        "operationId" => "bulkCreate#{String.capitalize(domain)}",
        "tags" => [tag],
        "_requestBody" => %{
          "_required" => true,
          "content" => %{
            "application / json" => %{
              "schema" => %{
                "$ref" => "#/components / schemas / BulkCreateRequest"
              }
            }
          }
        },
        "responses" => %{
          "200" => %{
            "description" => "Bulk creation results",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" => "#/components / schemas / BulkOperationResponse"
                }
              }
            }
          }
        }
      }
    })
  end

  @spec add_import_export_endpoints(map(), String.t(), String.t()) :: map()
  defp add_import_export_endpoints(paths, domain, _description) do
    import_path = "/api / mobile / config/#{domain}/import"
    export_path = "/api / mobile / config/#{domain}/export"
    tag = String.capitalize(domain) <> " Configuration"

    paths
    |> Map.put(import_path, %{
      "post" => %{
        "summary" => "Import #{domain}",
        "description" => "Imports #{domain} from CSV or JSON",
        "operationId" => "import#{String.capitalize(domain)}",
        "tags" => [tag],
        "_requestBody" => %{
          "_required" => true,
          "content" => %{
            "multipart / form - __data" => %{
              "schema" => %{
                "$ref" => "#/components / schemas / ImportRequest"
              }
            }
          }
        },
        "responses" => %{
          "200" => %{
            "description" => "Import results",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "$ref" => "#/components / schemas / ImportResponse"
                }
              }
            }
          }
        }
      }
    })
    |> Map.put(export_path, %{
      "get" => %{
        "summary" => "Export #{domain}",
        "description" => "Exports #{domain} to CSV or JSON",
        "operationId" => "export#{String.capitalize(domain)}",
        "tags" => [tag],
        "parameters" => [
          %{
            "name" => "format",
            "in" => "query",
            "schema" => %{
              "type" => "string",
              "enum" => ["csv", "json"],
              "default" => "csv"
            }
          }
        ],
        "responses" => %{
          "200" => %{
            "description" => "Export file",
            "content" => %{
              "text / csv" => %{
                "schema" => %{"type" => "string"}
              },
              "application / json" => %{
                "schema" => %{"type" => "array"}
              }
            }
          }
        }
      }
    })
  end

  @spec add_mobile_specific_endpoints(map()) :: map()
  defp add_mobile_specific_endpoints(paths) do
    Map.merge(paths, %{
      "/api / mobile / dashboard" => %{
        "get" => %{
          "summary" => "Mobile dashboard __data",
          "description" => "Retrieves dashboard __data optimized for mobile display",
          "operationId" => "getMobileDashboard",
          "tags" => ["Mobile"],
          "responses" => %{
            "200" => %{
              "description" => "Dashboard __data",
              "content" => %{
                "application / json" => %{
                  "schema" => %{"$ref" => "#/components / schemas / DashboardResponse"}
                }
              }
            }
          }
        }
      },
      "/api / mobile / notifications / register" => %{
        "post" => %{
          "summary" => "Register device for push notifications",
          "description" => "Registers a mobile device to receive push notifications",
          "operationId" => "registerDevice",
          "tags" => ["Notifications"],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / DeviceRegistrationRequest"}
              }
            }
          },
          "responses" => %{
            "200" => %{
              "description" => "Device registered",
              "content" => %{
                "application / json" => %{
                  "schema" => %{"$ref" => "#/components / schemas / DeviceRegistrationResponse"}
                }
              }
            }
          }
        }
      },
      "/api / mobile / notifications / preferences" => %{
        "get" => %{
          "summary" => "Get notification preferences",
          "description" => "Retrieves user's notification preferences",
          "operationId" => "getNotificationPreferences",
          "tags" => ["Notifications"],
          "responses" => %{
            "200" => %{
              "description" => "Notification preferences",
              "content" => %{
                "application / json" => %{
                  "schema" => %{"$ref" => "#/components / schemas / NotificationPreferences"}
                }
              }
            }
          }
        },
        "put" => %{
          "summary" => "Update notification preferences",
          "description" => "Updates user's notification preferences",
          "operationId" => "updateNotificationPreferences",
          "tags" => ["Notifications"],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / NotificationPreferencesUpdate"}
              }
            }
          },
          "responses" => %{
            "200" => %{
              "description" => "Preferences updated",
              "content" => %{
                "application / json" => %{
                  "schema" => %{"$ref" => "#/components / schemas / NotificationPreferences"}
                }
              }
            }
          }
        }
      },
      "/api / mobile / sync" => %{
        "post" => %{
          "summary" => "Sync __data",
          "description" => "Synchronizes __data between mobile device and server",
          "operationId" => "syncData",
          "tags" => ["Synchronization"],
          "_requestBody" => %{
            "_required" => true,
            "content" => %{
              "application / json" => %{
                "schema" => %{"$ref" => "#/components / schemas / SyncRequest"}
              }
            }
          },
          "responses" => %{
            "200" => %{
              "description" => "Sync response",
              "content" => %{
                "application / json" => %{
                  "schema" => %{"$ref" => "#/components / schemas / SyncResponse"}
                }
              }
            }
          }
        }
      }
    })
  end

  @spec add_health_endpoints(map()) :: map()
  defp add_health_endpoints(paths) do
    Map.put(paths, "/api / mobile / health", %{
      "get" => %{
        "summary" => "Health check",
        "description" => "Checks API health and connectivity",
        "operationId" => "healthCheck",
        "tags" => ["System"],
        "security" => [],
        "responses" => %{
          "200" => %{
            "description" => "API is healthy",
            "content" => %{
              "application / json" => %{
                "schema" => %{
                  "type" => "object",
                  "properties" => %{
                    "status" => %{"type" => "string", "enum" => ["ok"]},
                    "timestamp" => %{"type" => "string", "format" => "date - time"},
                    "version" => %{"type" => "string"}
                  }
                }
              }
            }
          }
        }
      }
    })
  end

  defp generate_auth_responses do
    %{
      "200" => %{
        "description" => "Authentication successful",
        "content" => %{
          "application / json" => %{
            "schema" => %{"$ref" => "#/components / schemas / LoginResponse"},
            "examples" => %{
              "success" => %{
                "value" => %{
                  "token" => "eyJhbGciOiJIUzI1NiIs...",
                  "refresh_token" => "eyJhbGciOiJIUzI1NiIs...",
                  "expires_in" => 3600,
                  "user" => %{
                    "id" => "123e4567 - e89b - 12d3 - a456 - 426_614_174_000",
                    "email" => "john.doe@example.com",
                    "name" => "John Doe",
                    "role" => "admin",
                    "tenant_id" => "456e7890 - e89b - 12d3 - a456 - 426_614_174_000"
                  },
                  "permissions" => ["alarm.view", "alarm.acknowledge", "device.control"]
                }
              }
            }
          }
        }
      },
      "401" => %{
        "$ref" => "#/components / responses / Unauthorized"
      },
      "422" => %{
        "$ref" => "#/components / responses / ValidationError"
      },
      "429" => %{
        "$ref" => "#/components / responses / RateLimited"
      }
    }
  end

  defp generate_components do
    %{
      "schemas" => SchemaExtractor.generate_all_schemas(),
      "responses" => generate_common_responses(),
      "parameters" => generate_common_parameters(),
      "securitySchemes" => SecuritySchemes.generate(),
      "examples" => ExampleGenerator.generate_all()
    }
  end

  defp generate_common_responses do
    %{
      "NotFound" => %{
        "description" => "Resource not found",
        "content" => %{
          "application / json" => %{
            "schema" => %{"$ref" => "#/components / schemas / ErrorResponse"}
          }
        }
      },
      "Unauthorized" => %{
        "description" => "Authentication _required",
        "content" => %{
          "application / json" => %{
            "schema" => %{"$ref" => "#/components / schemas / ErrorResponse"},
            "examples" => %{
              "invalid_credentials" => %{
                "value" => %{
                  "error" => "unauthorized",
                  "message" => "Invalid email or password"
                }
              },
              "token_expired" => %{
                "value" => %{
                  "error" => "token_expired",
                  "message" => "JWT token has expired"
                }
              }
            }
          }
        }
      },
      "ValidationError" => %{
        "description" => "Validation error",
        "content" => %{
          "application / json" => %{
            "schema" => %{"$ref" => "#/components / schemas / ValidationErrorResponse"}
          }
        }
      },
      "RateLimited" => %{
        "description" => "Rate limit exceeded",
        "headers" => %{
          "X - RateLimit - Limit" => %{
            "schema" => %{"type" => "integer"},
            "description" => "Request limit per window"
          },
          "X - RateLimit - Remaining" => %{
            "schema" => %{"type" => "integer"},
            "description" => "Remaining _requests in window"
          },
          "X - RateLimit - Reset" => %{
            "schema" => %{"type" => "integer"},
            "description" => "Unix timestamp when window resets"
          }
        },
        "content" => %{
          "application / json" => %{
            "schema" => %{"$ref" => "#/components / schemas / RateLimitResponse"}
          }
        }
      }
    }
  end

  defp generate_common_parameters do
    %{
      "PageParam" => %{
        "name" => "page",
        "in" => "query",
        "description" => "Page number (1 - based)",
        "schema" => %{
          "type" => "integer",
          "minimum" => 1,
          "default" => 1
        }
      },
      "PageSizeParam" => %{
        "name" => "page_size",
        "in" => "query",
        "description" => "Number of items per page",
        "schema" => %{
          "type" => "integer",
          "minimum" => 1,
          "maximum" => 100,
          "default" => 20
        }
      },
      "SortByParam" => %{
        "name" => "sort_by",
        "in" => "query",
        "description" => "Field to sort by",
        "schema" => %{"type" => "string"}
      },
      "SortOrderParam" => %{
        "name" => "sort_order",
        "in" => "query",
        "description" => "Sort order",
        "schema" => %{
          "type" => "string",
          "enum" => ["asc", "desc"],
          "default" => "asc"
        }
      },
      "SearchParam" => %{
        "name" => "search",
        "in" => "query",
        "description" => "Search query",
        "schema" => %{"type" => "string"}
      }
    }
  end

  defp generate_tags do
    [
      %{
        "name" => "Authentication",
        "description" => "Authentication and authorization endpoints"
      },
      %{
        "name" => "Mobile",
        "description" => "Mobile - specific endpoints"
      },
      %{
        "name" => "Notifications",
        "description" => "Push notification management"
      },
      %{
        "name" => "Synchronization",
        "description" => "Data synchronization for offline support"
      },
      %{
        "name" => "System",
        "description" => "System health and status"
      }
    ] ++ generate_domain_tags()
  end

  defp generate_domain_tags do
    [
      "Alarms",
      "Devices",
      "Sites",
      "Users",
      "Guards",
      "Visitors",
      "Incidents",
      "Patrols",
      "Shifts",
      "Analytics",
      "Intelligence",
      "Integration",
      "Communication",
      "Fleet Management",
      "Environmental",
      "Compliance",
      "Training",
      "Accounts"
    ]
    |> Enum.map(fn domain ->
      %{
        "name" => "#{domain} Configuration",
        "description" => "#{domain} configuration management"
      }
    end)
  end

  defp generate_websocket_docs do
    WebSocketDocumentor.generate_documentation()
  end

  # Helper to convert JSON to YAML - like format (simplified)
  @spec json_to_yaml(map()) :: String.t()
  defp json_to_yaml(json) when is_map(json) do
    json
    |> Jason.encode!(pretty: true)
    |> String.replace("\":", ":")
    |> String.replace("{", "")
    |> String.replace("}", "")
    |> String.replace("[", "- ")
    |> String.replace("],", "")
    |> String.replace(",", "")
  end
end
