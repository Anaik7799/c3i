defmodule Indrajaal.Container.Configuration do
  @moduledoc """
  Advanced Container Configuration Management

  ## Overview

  This module provides enterprise-grade container configuration management with
  SOPv5.11 cybernetic framework integration, TPS methodology compliance, and
  STAMP safety constraints for production-ready container deployments.

  ## Features

  - **Dynamic Configuration**: Runtime configuration updates with validation
  - **Environment Management**: Multi-environment configuration with inheritance
  - **Security Compliance**: Security-first configuration with compliance validation
  - **Performance Optimization**: Performance-tuned configurations with monitoring
  - **Cloud Integration**: Cloud-native configuration patterns with auto-scaling
  - **PHICS Support**: Hot-reloading configuration updates for development

  ## Usage

      # Get container configuration
      config = Indrajaal.Container.Configuration.get_config(:production)

      # Update configuration
      Indrajaal.Container.Configuration.update_config(:development, new_config)

      # Validate configuration
      {:ok, _} = Indrajaal.Container.Configuration.validate_config(config)
  """

  @type environment :: :development | :test | :production
  @type config_key :: atom()
  @type config_value :: any()
  @type container_config :: %{required(config_key()) => config_value()}

  # Default container configurations
  @default_configs %{
    development: %{
      # Resource limits for development
      resources: %{
        # 1 CPU core
        cpu: "1000m",
        # 2GB RAM
        memory: "2Gi",
        # 10GB storage
        storage: "10Gi"
      },

      # Development-specific settings
      environment: %{
        phics_enabled: true,
        hot_reloading: true,
        debug_mode: true,
        log_level: "debug",
        auto_restart: true
      },

      # Container orchestration
      orchestration: %{
        replicas: 1,
        strategy: "Recreate",
        health_checks: true,
        liveness_probe: %{
          initial_delay_seconds: 30,
          period_seconds: 10,
          timeout_seconds: 5
        }
      },

      # Networking configuration
      networking: %{
        ports: [4000, 4001, 8080],
        service_type: "ClusterIP",
        ingress_enabled: false
      },

      # Security settings
      security: %{
        run_as_non_root: true,
        read_only_root_filesystem: false,
        allow_privilege_escalation: false,
        capabilities: %{
          drop: ["ALL"],
          add: []
        }
      }
    },
    test: %{
      # Resource limits for testing
      resources: %{
        # 0.5 CPU core
        cpu: "500m",
        # 1GB RAM
        memory: "1Gi",
        # 5GB storage
        storage: "5Gi"
      },

      # Test-specific settings
      environment: %{
        phics_enabled: false,
        hot_reloading: false,
        debug_mode: false,
        log_level: "info",
        auto_restart: false,
        test_mode: true
      },

      # Container orchestration
      orchestration: %{
        replicas: 1,
        strategy: "Recreate",
        health_checks: true,
        liveness_probe: %{
          initial_delay_seconds: 15,
          period_seconds: 5,
          timeout_seconds: 3
        }
      },

      # Networking configuration
      networking: %{
        ports: [4000],
        service_type: "ClusterIP",
        ingress_enabled: false
      },

      # Security settings
      security: %{
        run_as_non_root: true,
        read_only_root_filesystem: true,
        allow_privilege_escalation: false,
        capabilities: %{
          drop: ["ALL"],
          add: []
        }
      }
    },
    production: %{
      # Resource limits for production
      resources: %{
        # 2 CPU cores
        cpu: "2000m",
        # 4GB RAM
        memory: "4Gi",
        # 50GB storage
        storage: "50Gi"
      },

      # Production-specific settings
      environment: %{
        phics_enabled: false,
        hot_reloading: false,
        debug_mode: false,
        log_level: "warn",
        auto_restart: true,
        production_mode: true
      },

      # Container orchestration
      orchestration: %{
        replicas: 3,
        strategy: "RollingUpdate",
        max_unavailable: 1,
        max_surge: 1,
        health_checks: true,
        liveness_probe: %{
          initial_delay_seconds: 60,
          period_seconds: 30,
          timeout_seconds: 10
        },
        readiness_probe: %{
          initial_delay_seconds: 30,
          period_seconds: 10,
          timeout_seconds: 5
        }
      },

      # Networking configuration
      networking: %{
        ports: [4000, 8080],
        service_type: "LoadBalancer",
        ingress_enabled: true,
        ingress_class: "nginx",
        ssl_redirect: true
      },

      # Security settings
      security: %{
        run_as_non_root: true,
        read_only_root_filesystem: true,
        allow_privilege_escalation: false,
        capabilities: %{
          drop: ["ALL"],
          add: []
        },
        security_context: %{
          fs_group: 1000,
          run_as_user: 1000,
          run_as_group: 1000
        }
      },

      # Auto-scaling configuration
      auto_scaling: %{
        enabled: true,
        min_replicas: 3,
        max_replicas: 20,
        target_cpu_utilization: 70,
        target_memory_utilization: 80,
        scale_down_stabilization_window: 300,
        scale_up_stabilization_window: 60
      },

      # Monitoring configuration
      monitoring: %{
        metrics_enabled: true,
        prometheus_scrape: true,
        grafana_dashboard: true,
        alerting_enabled: true,
        log_aggregation: true
      }
    }
  }

  @doc """
  Get container configuration for specified environment.

  ## Examples

      iex> Indrajaal.Container.Configuration.get_config(:development)
      %{resources: %{cpu: "1000m", ...}, ...}

      iex> Indrajaal.Container.Configuration.get_config(:production)
      %{resources: %{cpu: "2000m", ...}, auto_scaling: %{enabled: true, ...}, ...}
  """
  @spec get_config(environment()) :: container_config()
  def get_config(environment) when environment in [:development, :test, :production] do
    base_config = @default_configs[environment]

    # Apply environment-specific overrides
    case environment do
      :development -> apply_development_overrides(base_config)
      :test -> apply_test_overrides(base_config)
      :production -> apply_production_overrides(base_config)
    end
  end

  def get_config(_), do: get_config(:development)

  @doc """
  Update container configuration for specified environment.

  ## Examples

      iex> new_config = %{resources: %{cpu: "1500m"}}
      iex> Indrajaal.Container.Configuration.update_config(:development, new_config)
      {:ok, updated_config}
  """
  @spec update_config(environment(), container_config()) ::
          {:ok, container_config()} | {:error, term()}
  def update_config(environment, new_config) when is_map(new_config) do
    case validate_config(new_config) do
      {:ok, validated_config} ->
        current_config = get_config(environment)
        merged_config = deep_merge(current_config, validated_config)

        # Store updated configuration (in production, this would use persistent storage)
        {:ok, merged_config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validate container configuration against SOPv5.11 and STAMP safety constraints.

  ## Examples

      iex> config = %{resources: %{cpu: "1000m", memory: "2Gi"}}
      iex> Indrajaal.Container.Configuration.validate_config(config)
      {:ok, validated_config}
  """
  @spec validate_config(container_config()) :: {:ok, container_config()} | {:error, term()}
  def validate_config(config) when is_map(config) do
    with :ok <- validate_resource_limits(config),
         :ok <- validate_security_settings(config),
         :ok <- validate_networking_config(config),
         :ok <- validate_stamp_constraints(config) do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate Kubernetes manifests from container configuration.

  ## Examples

      iex> config = Indrajaal.Container.Configuration.get_config(:production)
      iex> Indrajaal.Container.Configuration.generate_k8s_manifests(config, "indrajaal-app")
      {:ok, %{deployment: deployment_yaml, service: service_yaml, ...}}
  """
  @spec generate_k8s_manifests(container_config(), String.t()) :: {:ok, map()} | {:error, term()}
  def generate_k8s_manifests(config, app_name) do
    manifests = %{
      deployment: generate_deployment_manifest(config, app_name),
      service: generate_service_manifest(config, app_name),
      configmap: generate_configmap_manifest(config, app_name)
    }

    # Add optional manifests based on configuration
    manifests =
      manifests
      |> maybe_add_ingress_manifest(config, app_name)
      |> maybe_add_hpa_manifest(config, app_name)
      |> maybe_add_pdb_manifest(config, app_name)

    {:ok, manifests}
  end

  @doc """
  Generate Docker Compose configuration from container configuration.

  ## Examples

      iex> config = Indrajaal.Container.Configuration.get_config(:development)
      iex> Indrajaal.Container.Configuration.generate_docker_compose(config, "intelitor")
      {:ok, docker_compose_yaml}
  """
  @spec generate_docker_compose(container_config(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_docker_compose(config, project_name) do
    compose_config = %{
      "version" => "3.8",
      "services" => %{
        "#{project_name}-app" => generate_compose_service_config(config),
        "#{project_name}-db" => generate_compose_db_config(),
        "#{project_name}-redis" => generate_compose_redis_config()
      },
      "networks" => %{
        "#{project_name}-network" => %{
          "driver" => "bridge"
        }
      },
      "volumes" => %{
        "#{project_name}-db-__data" => nil,
        "#{project_name}-redis-__data" => nil
      }
    }

    {:ok, Jason.encode!(compose_config, pretty: true)}
  end

  # Private helper functions

  defp apply_development_overrides(config) do
    # Apply PHICS optimization for development
    config
    |> put_in([:environment, :phics_sync_interval], 100)
    |> put_in([:environment, :file_watcher_enabled], true)
    |> put_in([:environment, :live_reload_enabled], true)
  end

  defp apply_test_overrides(config) do
    # Apply test-specific optimizations
    config
    |> put_in([:environment, :test_parallelization], true)
    |> put_in([:environment, :test_isolation], true)
    |> put_in([:resources, :ephemeral_storage], "2Gi")
  end

  defp apply_production_overrides(config) do
    # Apply production hardening
    config
    |> put_in([:security, :pod_security_standard], "restricted")
    |> put_in([:monitoring, :uptime_requirements], 99.9)
    |> put_in([:networking, :rate_limiting], %{enabled: true, rpm: 1000})
  end

  defp validate_resource_limits(config) do
    case get_in(config, [:resources]) do
      nil ->
        :ok

      resources ->
        cond do
          invalid_cpu?(resources[:cpu]) ->
            {:error, "Invalid CPU specification"}

          invalid_memory?(resources[:memory]) ->
            {:error, "Invalid memory specification"}

          true ->
            :ok
        end
    end
  end

  defp validate_security_settings(config) do
    case get_in(config, [:security]) do
      nil ->
        :ok

      security ->
        cond do
          security[:run_as_non_root] != true ->
            {:error, "Container must run as non-root user"}

          security[:allow_privilege_escalation] == true ->
            {:error, "Privilege escalation must be disabled"}

          true ->
            :ok
        end
    end
  end

  defp validate_networking_config(config) do
    case get_in(config, [:networking, :ports]) do
      nil ->
        :ok

      ports when is_list(ports) ->
        if Enum.all?(ports, &valid_port?/1) do
          :ok
        else
          {:error, "Invalid port specification"}
        end

      _ ->
        {:error, "Ports must be a list"}
    end
  end

  defp validate_stamp_constraints(config) do
    # STAMP Safety Constraint SC-CNT-001: Resource limits must be specified
    if get_in(config, [:resources, :memory]) && get_in(config, [:resources, :cpu]) do
      :ok
    else
      {:error, "STAMP constraint violation: Resource limits must be specified"}
    end
  end

  defp invalid_cpu?(nil), do: false

  defp invalid_cpu?(cpu) when is_binary(cpu) do
    not Regex.match?(~r/^\d+m?$/, cpu)
  end

  defp invalid_cpu?(_), do: true

  defp invalid_memory?(nil), do: false

  defp invalid_memory?(memory) when is_binary(memory) do
    not Regex.match?(~r/^\d+([KMGT]i?)?$/, memory)
  end

  defp invalid_memory?(_), do: true

  defp valid_port?(port) when is_integer(port) do
    port > 0 and port <= 65_535
  end

  defp valid_port?(_), do: false

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _k, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _k, _left_val, right_val ->
        right_val
    end)
  end

  defp deep_merge(_left, right), do: right

  # Kubernetes manifest generators
  defp generate_deployment_manifest(config, app_name) do
    %{
      "apiVersion" => "apps/v1",
      "kind" => "Deployment",
      "meta_data" => %{
        "name" => app_name,
        "labels" => %{
          "app" => app_name,
          "version" => "v1"
        }
      },
      "spec" => %{
        "replicas" => get_in(config, [:orchestration, :replicas]) || 1,
        "strategy" => %{
          "type" => get_in(config, [:orchestration, :strategy]) || "RollingUpdate"
        },
        "selector" => %{
          "matchLabels" => %{
            "app" => app_name
          }
        },
        "template" => %{
          "meta_data" => %{
            "labels" => %{
              "app" => app_name,
              "version" => "v1"
            }
          },
          "spec" => generate_pod_spec(config, app_name)
        }
      }
    }
  end

  defp generate_service_manifest(config, app_name) do
    %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "meta_data" => %{
        "name" => "#{app_name}-service",
        "labels" => %{
          "app" => app_name
        }
      },
      "spec" => %{
        "selector" => %{
          "app" => app_name
        },
        "ports" => generate_service_ports(config),
        "type" => get_in(config, [:networking, :service_type]) || "ClusterIP"
      }
    }
  end

  defp generate_configmap_manifest(config, app_name) do
    %{
      "apiVersion" => "v1",
      "kind" => "ConfigMap",
      "meta_data" => %{
        "name" => "#{app_name}-config"
      },
      "data" => generate_config_data(config)
    }
  end

  defp generate_pod_spec(config, _app_name) do
    %{
      "containers" => [
        %{
          "name" => "app",
          "image" => "localhost/indrajaal-app:latest",
          "ports" => generate_container_ports(config),
          "resources" => generate_resource_limits(config),
          "securityContext" => generate_security_context(config),
          "env" => generate_environment_variables(config),
          "livenessProbe" => generate_liveness_probe(config),
          "readinessProbe" => generate_readiness_probe(config)
        }
      ],
      "securityContext" => get_in(config, [:security, :security_context]) || %{}
    }
  end

  defp generate_container_ports(config) do
    ports = get_in(config, [:networking, :ports]) || [4000]

    Enum.map(ports, fn port ->
      %{
        "containerPort" => port,
        "protocol" => "TCP"
      }
    end)
  end

  defp generate_service_ports(config) do
    ports = get_in(config, [:networking, :ports]) || [4000]

    Enum.map(ports, fn port ->
      %{
        "port" => port,
        "targetPort" => port,
        "protocol" => "TCP",
        "name" => "http-#{port}"
      }
    end)
  end

  defp generate_resource_limits(config) do
    resources = get_in(config, [:resources]) || %{}

    %{
      "limits" => %{
        "cpu" => resources[:cpu] || "1000m",
        "memory" => resources[:memory] || "2Gi"
      },
      "requests" => %{
        "cpu" => calculate_cpu_request(resources[:cpu]),
        "memory" => calculate_memory_request(resources[:memory])
      }
    }
  end

  defp generate_security_context(config) do
    security = get_in(config, [:security]) || %{}

    %{
      "runAsNonRoot" => security[:run_as_non_root] || true,
      "readOnlyRootFilesystem" => security[:read_only_root_filesystem] || false,
      "allowPrivilegeEscalation" => security[:allow_privilege_escalation] || false,
      "capabilities" => security[:capabilities] || %{drop: ["ALL"]}
    }
  end

  defp generate_environment_variables(config) do
    env = get_in(config, [:environment]) || %{}

    [
      %{"name" => "LOG_LEVEL", "value" => env[:log_level] || "info"},
      %{"name" => "PHICS_ENABLED", "value" => to_string(env[:phics_enabled] || false)},
      %{"name" => "DEBUG_MODE", "value" => to_string(env[:debug_mode] || false)}
    ]
  end

  defp generate_liveness_probe(config) do
    probe = get_in(config, [:orchestration, :liveness_probe]) || %{}

    %{
      "httpGet" => %{
        "path" => "/health",
        "port" => 4000
      },
      "initialDelaySeconds" => probe[:initial_delay_seconds] || 30,
      "periodSeconds" => probe[:period_seconds] || 10,
      "timeoutSeconds" => probe[:timeout_seconds] || 5
    }
  end

  defp generate_readiness_probe(config) do
    probe =
      get_in(config, [:orchestration, :readiness_probe]) ||
        get_in(config, [:orchestration, :liveness_probe]) || %{}

    %{
      "httpGet" => %{
        "path" => "/health/ready",
        "port" => 4000
      },
      "initialDelaySeconds" => probe[:initial_delay_seconds] || 15,
      "periodSeconds" => probe[:period_seconds] || 5,
      "timeoutSeconds" => probe[:timeout_seconds] || 3
    }
  end

  defp generate_config_data(config) do
    %{
      "app.config" => generate_app_config_file(config),
      "container.json" => Jason.encode!(config, pretty: true)
    }
  end

  defp generate_app_config_file(config) do
    """
    # Container Application Configuration
    # Generated by Indrajaal Container Configuration Management

    LOG_LEVEL=#{get_in(config, [:environment, :log_level]) || "info"}
    DEBUG_MODE=#{get_in(config, [:environment, :debug_mode]) || false}
    PHICS_ENABLED=#{get_in(config, [:environment, :phics_enabled]) || false}

    # Resource Configuration
    CPU_LIMIT=#{get_in(config, [:resources, :cpu]) || "1000m"}
    MEMORY_LIMIT=#{get_in(config, [:resources, :memory]) || "2Gi"}
    """
  end

  # Docker Compose generators
  defp generate_compose_service_config(config) do
    %{
      "image" => "localhost/indrajaal-app:latest",
      "ports" => generate_compose_ports(config),
      "environment" => generate_compose_environment(config),
      "volumes" => generate_compose_volumes(config),
      "networks" => ["indrajaal-network"],
      "restart" => "unless-stopped",
      "deploy" => %{
        "resources" => %{
          "limits" => %{
            "cpus" => convert_cpu_to_decimal(get_in(config, [:resources, :cpu])),
            "memory" => get_in(config, [:resources, :memory]) || "2G"
          }
        }
      }
    }
  end

  defp generate_compose_db_config do
    %{
      "image" => "postgres:17-alpine",
      "environment" => [
        "POSTGRES_DB=indrajaal_dev",
        "POSTGRES_USER=postgres",
        "POSTGRES_PASSWORD=postgres"
      ],
      "volumes" => ["indrajaal-db-data:/var/lib/postgresql/data"],
      "networks" => ["indrajaal-network"],
      "restart" => "unless-stopped",
      "ports" => ["5433:5432"]
    }
  end

  defp generate_compose_redis_config do
    %{
      "image" => "redis:7-alpine",
      "volumes" => ["indrajaal-redis-data:/data"],
      "networks" => ["indrajaal-network"],
      "restart" => "unless-stopped",
      "ports" => ["6379:6379"]
    }
  end

  defp generate_compose_ports(config) do
    ports = get_in(config, [:networking, :ports]) || [4000]
    Enum.map(ports, &"#{&1}:#{&1}")
  end

  defp generate_compose_environment(config) do
    env = get_in(config, [:environment]) || %{}

    [
      "LOG_LEVEL=#{env[:log_level] || "info"}",
      "PHICS_ENABLED=#{env[:phics_enabled] || false}",
      "DEBUG_MODE=#{env[:debug_mode] || false}",
      "DATABASE_URL=postgres://postgres:postgres@indrajaal-db:5432/indrajaal_dev",
      "REDIS_URL=redis://indrajaal-redis:6379"
    ]
  end

  defp generate_compose_volumes(config) do
    base_volumes = [".:/app"]

    if get_in(config, [:environment, :phics_enabled]) do
      base_volumes ++
        [
          "./lib:/app/lib",
          "./priv:/app/priv",
          "./assets:/app/assets"
        ]
    else
      base_volumes
    end
  end

  # Optional manifest generators
  defp maybe_add_ingress_manifest(manifests, config, app_name) do
    if get_in(config, [:networking, :ingress_enabled]) do
      Map.put(manifests, :ingress, generate_ingress_manifest(config, app_name))
    else
      manifests
    end
  end

  defp maybe_add_hpa_manifest(manifests, config, app_name) do
    if get_in(config, [:auto_scaling, :enabled]) do
      Map.put(manifests, :hpa, generate_hpa_manifest(config, app_name))
    else
      manifests
    end
  end

  defp maybe_add_pdb_manifest(manifests, config, app_name) do
    replicas = get_in(config, [:orchestration, :replicas]) || 1

    if replicas > 1 do
      Map.put(manifests, :pdb, generate_pdb_manifest(config, app_name))
    else
      manifests
    end
  end

  defp generate_ingress_manifest(config, app_name) do
    %{
      "apiVersion" => "networking.k8s.io/v1",
      "kind" => "Ingress",
      "meta_data" => %{
        "name" => "#{app_name}-ingress",
        "annotations" => generate_ingress_annotations(config)
      },
      "spec" => %{
        "ingressClassName" => get_in(config, [:networking, :ingress_class]) || "nginx",
        "rules" => generate_ingress_rules(config, app_name)
      }
    }
  end

  defp generate_hpa_manifest(config, app_name) do
    auto_scaling = get_in(config, [:auto_scaling]) || %{}

    %{
      "apiVersion" => "autoscaling/v2",
      "kind" => "HorizontalPodAutoscaler",
      "meta_data" => %{
        "name" => "#{app_name}-hpa"
      },
      "spec" => %{
        "scaleTargetRef" => %{
          "apiVersion" => "apps/v1",
          "kind" => "Deployment",
          "name" => app_name
        },
        "minReplicas" => auto_scaling[:min_replicas] || 1,
        "maxReplicas" => auto_scaling[:max_replicas] || 10,
        "metrics" => generate_hpa_metrics(auto_scaling)
      }
    }
  end

  defp generate_pdb_manifest(_config, app_name) do
    %{
      "apiVersion" => "policy/v1",
      "kind" => "PodDisruptionBudget",
      "meta_data" => %{
        "name" => "#{app_name}-pdb"
      },
      "spec" => %{
        "minAvailable" => 1,
        "selector" => %{
          "matchLabels" => %{
            "app" => app_name
          }
        }
      }
    }
  end

  # Helper functions
  defp calculate_cpu_request(nil), do: "100m"

  defp calculate_cpu_request(cpu_limit) do
    case Integer.parse(String.replace(cpu_limit, "m", "")) do
      {cpu_millicores, _} when cpu_millicores > 0 ->
        request_millicores = max(100, div(cpu_millicores, 2))
        "#{request_millicores}m"

      _ ->
        "100m"
    end
  end

  defp calculate_memory_request(nil), do: "256Mi"

  defp calculate_memory_request(memory_limit) do
    # Request 50% of limit, minimum 256Mi
    case parse_memory_to_mi(memory_limit) do
      memory_mi when memory_mi > 0 ->
        request_mi = max(256, div(memory_mi, 2))
        "#{request_mi}Mi"

      _ ->
        "256Mi"
    end
  end

  defp parse_memory_to_mi(memory) when is_binary(memory) do
    cond do
      String.ends_with?(memory, "Gi") ->
        {value, _} = Integer.parse(String.replace(memory, "Gi", ""))
        value * 1024

      String.ends_with?(memory, "Mi") ->
        {value, _} = Integer.parse(String.replace(memory, "Mi", ""))
        value

      String.ends_with?(memory, "G") ->
        {value, _} = Integer.parse(String.replace(memory, "G", ""))
        value * 1000

      String.ends_with?(memory, "M") ->
        {value, _} = Integer.parse(String.replace(memory, "M", ""))
        value

      true ->
        0
    end
  end

  defp convert_cpu_to_decimal(nil), do: "1.0"

  defp convert_cpu_to_decimal(cpu) when is_binary(cpu) do
    case Integer.parse(String.replace(cpu, "m", "")) do
      {cpu_millicores, _} -> Float.to_string(cpu_millicores / 1000)
      _ -> "1.0"
    end
  end

  defp generate_ingress_annotations(config) do
    base_annotations = %{
      "nginx.ingress.kubernetes.io/rewrite-target" => "/",
      "nginx.ingress.kubernetes.io/ssl-redirect" =>
        "#{get_in(config, [:networking, :ssl_redirect]) || false}"
    }

    if get_in(config, [:networking, :rate_limiting, :enabled]) do
      rpm = get_in(config, [:networking, :rate_limiting, :rpm]) || 1000
      Map.put(base_annotations, "nginx.ingress.kubernetes.io/rate-limit", "#{rpm}")
    else
      base_annotations
    end
  end

  defp generate_ingress_rules(_config, app_name) do
    [
      %{
        "http" => %{
          "paths" => [
            %{
              "path" => "/",
              "pathType" => "Prefix",
              "backend" => %{
                "service" => %{
                  "name" => "#{app_name}-service",
                  "port" => %{
                    "number" => 4000
                  }
                }
              }
            }
          ]
        }
      }
    ]
  end

  defp generate_hpa_metrics(auto_scaling) do
    metrics = []

    metrics =
      if auto_scaling[:target_cpu_utilization] do
        [
          %{
            "type" => "Resource",
            "resource" => %{
              "name" => "cpu",
              "target" => %{
                "type" => "Utilization",
                "averageUtilization" => auto_scaling[:target_cpu_utilization]
              }
            }
          }
          | metrics
        ]
      else
        metrics
      end

    if auto_scaling[:target_memory_utilization] do
      [
        %{
          "type" => "Resource",
          "resource" => %{
            "name" => "memory",
            "target" => %{
              "type" => "Utilization",
              "averageUtilization" => auto_scaling[:target_memory_utilization]
            }
          }
        }
        | metrics
      ]
    else
      metrics
    end
  end
end
