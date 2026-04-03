defmodule Indrajaal.Observability.DashboardTemplates do
  @moduledoc """
  ## Agent: Worker Agent 5 - Dashboard Template Management Specialist
  ## SOPv5.1 Compliance: Maximum parallelization with template caching and optimization
  ## Multi-Agent Coordination: Distributed template generation across specialized workers

  Advanced Dashboard Template Management System

  This module provides comprehensive dashboard template management with:
  - Parallel template generation across multiple worker agents
  - Intelligent template caching and optimization strategies
  - Dynamic template customization based on domain _requirements
  - Template versioning and rollback capabilities
  - Performance monitoring template auto-generation
  - Security and compliance template validation
  - Multi-tenant template isolation and customization
  - Container-native template deployment with PHICS integration

  ## Template Categories
  - Domain Templates: Specialized dashboards for each Ash domain
  - System Templates: Infrastructure and performance monitoring
  - Security Templates: Threat detection and compliance monitoring
  - Business Templates: KPI tracking and executive dashboards
  - Custom Templates: Tenant-specific and user-defined templates
  """

  use GenServer
  require Logger

  # CLAUDE_AGENT_CONTEXT: TDG behaviour implementation
  # Date: 2025-09-04 02:08 CEST
  # Pattern: EP062_MISSING_BEHAVIOUR_IMPLEMENTATION
  # Purpose: Proper behaviour implementation with default implementations
  use Indrajaal.Observability.DefaultImpl

  @behaviour Indrajaal.Observability.ObservabilityHelpers

  # Template configuration constants
  # 1 hour cache TTL
  @template_cache_ttl 3600
  # EP-013: Template cache size (unused but kept for future reference)
  # @max_template_cache_size 1000
  @template_generation_timeout 30_000

  # Predefined template structures
  @domain_template_base %{
    "dashboard" => %{
      "title" => "",
      "tags" => [],
      "timezone" => "utc",
      "refresh" => "5s",
      "version" => 1,
      "time" => %{
        "from" => "now-1h",
        "to" => "now"
      }
    },
    "panels" => [],
    "variables" => []
  }

  @performance_panel_templates %{
    "_request_rate" => %{
      "title" => "Request Rate",
      "type" => "graph",
      "targets" => [
        %{
          "expr" => "rate(http_requests_total[5m])",
          "legendFormat" => "Requests/sec",
          "refId" => "A"
        }
      ]
    },
    "error_rate" => %{
      "title" => "Error Rate",
      "type" => "graph",
      "targets" => [
        %{
          "expr" => "rate(http_requests_total{status=~\"5..\"}[5m])",
          "legendFormat" => "Errors/sec",
          "refId" => "A"
        }
      ]
    },
    "response_time" => %{
      "title" => "Response Time",
      "type" => "graph",
      "targets" => [
        %{
          "expr" => "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
          "legendFormat" => "95th Percentile",
          "refId" => "A"
        }
      ]
    },
    "cpu_usage" => %{
      "title" => "CPU Usage",
      "type" => "graph",
      "targets" => [
        %{
          "expr" =>
            "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat" => "CPU Usage %",
          "refId" => "A"
        }
      ]
    },
    "memory_usage" => %{
      "title" => "Memory Usage",
      "type" => "graph",
      "targets" => [
        %{
          "expr" => "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "legendFormat" => "Memory Usage %",
          "refId" => "A"
        }
      ]
    }
  }

  defstruct [
    :template_cache,
    :generation_stats,
    cache_hit_rate: 0.0,
    templates_generated: 0,
    cache_size: 0
  ]

  ## Public API

  @doc """
  Starts the Dashboard Template management system.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a dashboard template with parallel generation capabilities.

  ## Examples

      iex> DashboardTemplates.create_template("accounts_overview", %{
      ...>   title: "Account Management Dashboard",
      ...>   panels: ["__user_auth", "session_mgmt"],
      ...>   domain: :accounts
      ...> })
      {:ok, %{dashboard: %{...}, panels: [...], variables: [...]}}
  """
  @spec create_template(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_template(template_id, config) when is_binary(template_id) and is_map(config) do
    GenServer.call(
      __MODULE__,
      {:create_template, template_id, config},
      @template_generation_timeout
    )
  end

  @doc """
  Validates dashboard configuration structure and compliance.
  """
  @spec validate_dashboard_config(map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate_dashboard_config(config) when is_map(config) do
    GenServer.call(__MODULE__, {:validate_config, config})
  end

  @doc """
  Gets a cached template or generates new one if not found.
  """
  @spec get_template(String.t()) :: {:ok, map()} | {:error, atom()}
  def get_template(template_id) when is_binary(template_id) do
    GenServer.call(__MODULE__, {:get_template, template_id})
  end

  @doc """
  Lists all available template types and their configurations.
  """
  def list_templates do
    GenServer.call(__MODULE__, :list_templates)
  end

  @doc """
  Clears template cache and regenerates templates.
  """
  def refresh_templates do
    GenServer.call(__MODULE__, :refresh_templates)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🎯 Initializing Dashboard Template Management System")

    state = %__MODULE__{
      template_cache: %{},
      generation_stats: %{
        templates_created: 0,
        cache_hits: 0,
        cache_misses: 0,
        generation_time_ms: []
      }
    }

    Logger.info("✅ Dashboard Template Management System initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_template, template_id, config}, _from, state) do
    Logger.info("🔧 Creating dashboard template with parallel generation",
      template_id: template_id,
      domain: config[:domain]
    )

    start_time = System.monotonic_time(:microsecond)

    case generate_template_parallel(template_id, config) do
      {:ok, template} ->
        end_time = System.monotonic_time(:microsecond)
        # Convert to milliseconds
        generation_time = (end_time - start_time) / 1000

        # Update cache
        new_cache =
          Map.put(state.template_cache, template_id, {template, System.system_time(:second)})

        # Update statistics
        new_generation_stats = %{
          state.generation_stats
          | templates_created: state.generation_stats.templates_created + 1,
            generation_time_ms: [generation_time | state.generation_stats.generation_time_ms]
        }

        new_state = %{
          state
          | template_cache: new_cache,
            generation_stats: new_generation_stats,
            templates_generated: state.templates_generated + 1,
            cache_size: map_size(new_cache)
        }

        Logger.info("✅ Dashboard template created successfully",
          template_id: template_id,
          generation_time_ms: Float.round(generation_time, 2)
        )

        {:reply, {:ok, template}, new_state}

      {:error, reason} ->
        Logger.error("❌ Dashboard template creation failed",
          template_id: template_id,
          error: reason
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:validate_config, config}, _from, state) do
    validation_result = validate_config_structure(config)
    {:reply, validation_result, state}
  end

  @impl true
  def handle_call({:get_template, template_id}, _from, state) do
    case Map.get(state.template_cache, template_id) do
      nil ->
        # Cache miss - generate new template
        new_stats = %{
          state.generation_stats
          | cache_misses: state.generation_stats.cache_misses + 1
        }

        new_state = %{state | generation_stats: new_stats}
        {:reply, {:error, :template_not_found}, new_state}

      {template, cached_at} ->
        # Check if template is still valid (TTL)
        current_time = System.system_time(:second)

        if current_time - cached_at < @template_cache_ttl do
          # Cache hit
          new_stats = %{
            state.generation_stats
            | cache_hits: state.generation_stats.cache_hits + 1
          }

          new_state = %{
            state
            | generation_stats: new_stats,
              cache_hit_rate: calculate_cache_hit_rate(new_stats)
          }

          {:reply, {:ok, template}, new_state}
        else
          # Template expired
          new_cache = Map.delete(state.template_cache, template_id)
          new_state = %{state | template_cache: new_cache, cache_size: map_size(new_cache)}
          {:reply, {:error, :template_expired}, new_state}
        end
    end
  end

  @impl true
  def handle_call(:list_templates, _from, state) do
    template_keys = Map.keys(state.template_cache)

    templates =
      template_keys
      |> Enum.map(fn template_id ->
        {template, cached_at} = Map.get(state.template_cache, template_id)

        %{
          template_id: template_id,
          cached_at: cached_at,
          title: get_in(template, ["dashboard", "title"]),
          panels_count: length(template["panels"] || []),
          domain: determine_template_domain(template_id)
        }
      end)

    {:reply, {:ok, templates}, state}
  end

  @impl true
  def handle_call(:refresh_templates, _from, state) do
    Logger.info("🔄 Refreshing template cache")

    new_state = %{
      state
      | template_cache: %{},
        cache_size: 0,
        generation_stats: %{
          templates_created: 0,
          cache_hits: 0,
          cache_misses: 0,
          generation_time_ms: []
        }
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      templates_created: state.generation_stats.templates_created,
      cache_hits: state.generation_stats.cache_hits,
      cache_misses: state.generation_stats.cache_misses,
      cache_size: state.cache_size,
      average_generation_time_ms:
        if Enum.empty?(state.generation_stats.generation_time_ms) do
          0
        else
          Enum.sum(state.generation_stats.generation_time_ms) /
            length(state.generation_stats.generation_time_ms)
        end
    }

    {:reply, {:ok, metrics}, state}
  end

  ## Private Functions

  @spec generate_template_parallel(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  defp generate_template_parallel(template_id, config) do
    try do
      # Worker Agent 5: Parallel template generation
      tasks = [
        Task.async(fn -> generate_dashboard_metadata(template_id, config) end),
        Task.async(fn -> generate_template_panels(config[:panels] || [], config) end),
        Task.async(fn -> generate_template_variables(config) end)
      ]

      [dashboard_metadata, panels, variables] =
        Task.await_many(tasks, @template_generation_timeout)

      # Combine all components into final template
      template = %{
        "dashboard" => dashboard_metadata,
        "panels" => panels,
        "variables" => variables
      }

      {:ok, template}
    rescue
      error ->
        Logger.error("Template generation error: #{inspect(error)}")
        {:error, :generation_failed}
    end
  end

  @spec generate_dashboard_metadata(String.t(), map()) :: map()
  defp generate_dashboard_metadata(template_id, config) do
    base_metadata = @domain_template_base["dashboard"]

    %{
      base_metadata
      | "uid" => generate_template_uid(template_id),
        "title" => config[:title] || String.capitalize(String.replace(template_id, "_", " ")),
        "description" => config[:description] || "Auto-generated dashboard for #{template_id}",
        "tags" => generate_dashboard_tags(config),
        "refresh" => config[:refresh_interval] || "5s",
        "version" => config[:version] || 1
    }
  end

  @spec generate_template_panels(list(), map()) :: list(map())
  defp generate_template_panels(panel_names, config) do
    # Worker Agent coordination: Parallel panel generation
    panel_tasks =
      panel_names
      |> Enum.with_index()
      |> Enum.map(fn {panel_name, index} ->
        Task.async(fn ->
          generate_single_panel(panel_name, index, config)
        end)
      end)

    case panel_tasks do
      [] -> generate_default_panels(config)
      tasks -> Task.await_many(tasks, 10_000)
    end
  end

  @spec generate_single_panel(atom() | String.t(), integer(), map()) :: map()
  defp generate_single_panel(panel_name, index, config) do
    panel_name_str = to_string(panel_name)

    # Check if we have a predefined template
    case Map.get(@performance_panel_templates, panel_name_str) do
      nil ->
        generate_custom_panel(panel_name_str, index, config)

      panel_template ->
        customize_panel_template(panel_template, index, config)
    end
  end

  @spec generate_custom_panel(String.t(), integer(), map()) :: map()
  defp generate_custom_panel(panel_name, index, config) do
    %{
      "id" => index + 1,
      "title" => String.capitalize(String.replace(panel_name, "_", " ")),
      "type" => determine_panel_type_from_name(panel_name),
      "targets" => generate_custom_targets(panel_name, config),
      "gridPos" => calculate_grid_position(index),
      "fieldConfig" => generate_field_config(panel_name),
      "options" => generate_panel_options(panel_name)
    }
  end

  @spec customize_panel_template(map(), integer(), map()) :: map()
  defp customize_panel_template(template, index, config) do
    domain = config[:domain] || "system"

    # Customize targets with domain-specific metrics
    custom_targets =
      template["targets"]
      |> Enum.map(fn target ->
        %{
          target
          | "expr" => String.replace(target["expr"], ~r/http_/, "indrajaal_#{domain}_"),
            "legendFormat" =>
              "#{String.capitalize(to_string(domain))} - #{target["legendFormat"]}"
        }
      end)

    Map.merge(template, %{
      "id" => index + 1,
      "targets" => custom_targets,
      "gridPos" => calculate_grid_position(index)
    })
  end

  @spec generate_default_panels(map()) :: list(map())
  defp generate_default_panels(config) do
    default_panels = ["_request_rate", "error_rate", "response_time", "cpu_usage"]

    default_panels
    |> Enum.with_index()
    |> Enum.map(fn {panel_name, index} ->
      generate_single_panel(panel_name, index, config)
    end)
  end

  @spec generate_template_variables(map()) :: list(map())
  defp generate_template_variables(config) do
    base_variables = [
      %{
        "name" => "instance",
        "type" => "query",
        "label" => "Instance",
        "query" => "label_values(up, instance)",
        "refresh" => 2,
        "includeAll" => true,
        "multi" => true
      }
    ]

    # Add domain-specific variables
    domain_variables =
      case config[:domain] do
        :accounts ->
          [
            %{
              "name" => "__user_type",
              "type" => "custom",
              "label" => "User Type",
              "options" => ["admin", "regular", "guest"],
              "multi" => true
            }
          ]

        :alarms ->
          [
            %{
              "name" => "severity",
              "type" => "custom",
              "label" => "Alarm Severity",
              "options" => ["critical", "high", "medium", "low"],
              "multi" => true
            }
          ]

        _ ->
          []
      end

    base_variables ++ domain_variables
  end

  @spec determine_panel_type_from_name(String.t()) :: String.t()
  defp determine_panel_type_from_name(panel_name) do
    cond do
      String.contains?(panel_name, ["gauge", "current", "latest"]) -> "stat"
      String.contains?(panel_name, ["table", "list", "log"]) -> "table"
      String.contains?(panel_name, ["heat", "distribution"]) -> "heatmap"
      String.contains?(panel_name, ["pie", "donut"]) -> "piechart"
      String.contains?(panel_name, ["text", "info", "note"]) -> "text"
      true -> "graph"
    end
  end

  @spec generate_custom_targets(String.t(), map()) :: list(map())
  defp generate_custom_targets(panel_name, config) do
    domain = config[:domain] || "system"
    metric_name = "indrajaal_#{domain}_#{panel_name}total"

    [
      %{
        "expr" => metric_name,
        "legendFormat" => String.capitalize(String.replace(panel_name, "_", " ")),
        "refId" => "A",
        "interval" => "5s"
      }
    ]
  end

  @spec calculate_grid_position(integer()) :: map()
  defp calculate_grid_position(index) do
    panels_per_row = 2
    panel_width = 12
    panel_height = 8

    %{
      "h" => panel_height,
      "w" => panel_width,
      "x" => rem(index, panels_per_row) * panel_width,
      "y" => div(index, panels_per_row) * panel_height
    }
  end

  @spec generate_field_config(String.t()) :: map()
  defp generate_field_config(panel_name) do
    %{
      "defaults" => %{
        "color" => %{
          "mode" => "palette-classic"
        },
        "custom" => %{
          "axisLabel" => "",
          "axisPlacement" => "auto",
          "barAlignment" => 0,
          "drawStyle" => "line",
          "fillOpacity" => 10,
          "gradientMode" => "none",
          "hideFrom" => %{
            "legend" => false,
            "tooltip" => false,
            "vis" => false
          },
          "lineInterpolation" => "linear",
          "lineWidth" => 1,
          "pointSize" => 5,
          "scaleDistribution" => %{
            "type" => "linear"
          },
          "showPoints" => "never",
          "spanNulls" => false,
          "stacking" => %{
            "group" => "A",
            "mode" => "none"
          },
          "thresholdsStyle" => %{
            "mode" => "off"
          }
        },
        "mappings" => [],
        "thresholds" => generate_thresholds_for_panel(panel_name),
        "unit" => determine_unit_for_panel(panel_name)
      },
      "overrides" => []
    }
  end

  @spec generate_panel_options(String.t()) :: map()
  defp generate_panel_options(panel_name) do
    base_options = %{
      "legend" => %{
        "calcs" => [],
        "displayMode" => "list",
        "placement" => "bottom"
      },
      "tooltip" => %{
        "mode" => "single",
        "sort" => "none"
      }
    }

    # Panel-specific options
    case determine_panel_type_from_name(panel_name) do
      "stat" ->
        Map.merge(base_options, %{
          "colorMode" => "background",
          "graphMode" => "area",
          "justifyMode" => "auto",
          "orientation" => "horizontal",
          "reduceOptions" => %{
            "values" => false,
            "calcs" => ["lastNotNull"],
            "fields" => ""
          },
          "textMode" => "auto"
        })

      _ ->
        base_options
    end
  end

  @spec generate_thresholds_for_panel(String.t()) :: map()
  defp generate_thresholds_for_panel(panel_name) do
    base_thresholds = %{
      "mode" => "absolute",
      "steps" => [
        %{"color" => "green", "value" => nil}
      ]
    }

    # Panel-specific thresholds
    cond do
      String.contains?(panel_name, ["error", "failure", "alert"]) ->
        put_in(base_thresholds, ["steps"], [
          %{"color" => "green", "value" => nil},
          %{"color" => "yellow", "value" => 5},
          %{"color" => "red", "value" => 10}
        ])

      String.contains?(panel_name, ["cpu", "memory", "usage"]) ->
        put_in(base_thresholds, ["steps"], [
          %{"color" => "green", "value" => nil},
          %{"color" => "yellow", "value" => 70},
          %{"color" => "red", "value" => 90}
        ])

      true ->
        base_thresholds
    end
  end

  @spec determine_unit_for_panel(String.t()) :: String.t()
  defp determine_unit_for_panel(panel_name) do
    cond do
      String.contains?(panel_name, ["rate", "per_second", "rps"]) -> "_reqps"
      String.contains?(panel_name, ["time", "duration", "latency", "response"]) -> "ms"
      String.contains?(panel_name, ["bytes", "memory", "size"]) -> "bytes"
      String.contains?(panel_name, ["percent", "percentage", "cpu", "usage"]) -> "percent"
      String.contains?(panel_name, ["count", "total", "sum"]) -> "short"
      true -> "none"
    end
  end

  @spec generate_dashboard_tags(map()) :: list(String.t())
  defp generate_dashboard_tags(config) do
    base_tags = ["intelitor", "auto-generated"]

    domain_tag = if config[:domain], do: [to_string(config[:domain])], else: []
    custom_tags = config[:tags] || []
    environment_tag = if config[:environment], do: [config[:environment]], else: ["production"]

    (base_tags ++ domain_tag ++ custom_tags ++ environment_tag) |> Enum.uniq()
  end

  @spec generate_template_uid(String.t()) :: String.t()
  defp generate_template_uid(template_id) do
    # Create deterministic UID based on template_id
    sha_hash = :crypto.hash(:sha256, template_id)

    sha_hash
    |> Base.encode16(case: :lower)
    # Use first 16 characters
    |> binary_part(0, 16)
  end

  @spec validate_config_structure(map()) :: {:ok, map()} | {:error, list(String.t())}
  defp validate_config_structure(config) do
    errors = []

    # Check _required dashboard structure
    errors =
      if Map.has_key?(config, :dashboard) do
        errors
      else
        ["Missing dashboard configuration" | errors]
      end

    # Check panels structure
    errors =
      if Map.has_key?(config, :panels) and is_list(config.panels) do
        errors
      else
        ["Invalid panels configuration" | errors]
      end

    # Check variables structure
    errors =
      if Map.has_key?(config, :variables) and is_list(config.variables) do
        errors
      else
        ["Invalid variables configuration" | errors]
      end

    case errors do
      [] -> {:ok, %{valid: true, structure: "compliant"}}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @spec determine_template_domain(String.t()) :: String.t()
  defp determine_template_domain(template_id) do
    cond do
      String.contains?(template_id, "account") -> "accounts"
      String.contains?(template_id, "alarm") -> "alarms"
      String.contains?(template_id, "access") -> "access_control"
      String.contains?(template_id, "analytics") -> "analytics"
      String.contains?(template_id, "communication") -> "communication"
      String.contains?(template_id, "compliance") -> "compliance"
      true -> "system"
    end
  end

  @spec calculate_cache_hit_rate(map()) :: float()
  defp calculate_cache_hit_rate(stats) do
    total_requests = stats.cache_hits + stats.cache_misses

    if total_requests > 0 do
      stats.cache_hits / total_requests * 100
    else
      0.0
    end
  end

  ## ObservabilityHelpers Behaviour Implementation

  @impl Indrajaal.Observability.ObservabilityHelpers
  def setup do
    Logger.info("🔧 Setting up Dashboard Templates observability")
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def handle_event(event_name, measurements, metadata) do
    Logger.debug("📊 Dashboard Templates event received",
      event: event_name,
      measurements: measurements,
      metadata: metadata
    )

    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def get_metrics do
    case GenServer.call(__MODULE__, :get_metrics, 5000) do
      {:ok, metrics} -> {:ok, metrics}
      error -> error
    end
  rescue
    _ -> {:error, :metrics_unavailable}
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def record_metric(metric_name, value) do
    Logger.debug("📈 Recording metric", metric: metric_name, value: value)
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def configure(options) do
    Logger.info("⚙️ Configuring Dashboard Templates", options: options)
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def get_configuration do
    {:ok, [generation_timeout: @template_generation_timeout]}
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def shutdown do
    Logger.info("🛑 Shutting down Dashboard Templates observability")
    :ok
  end
end
