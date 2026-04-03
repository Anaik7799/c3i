defmodule Indrajaal.Analytics.PerformanceMetricTest do
  @moduledoc """
  Comprehensive Test-Driven Generation (TDG) test suite for Indrajaal.Analytics.PerformanceMetric.

  This test suite follows TDG methodology where tests are written FIRST to define
  the expected behavior, then implementation follows to satisfy these tests.

  Coverage Areas:
  - Unit tests for all PerformanceMetric attributes and validations
  - Integration tests for performance monitoring workflows
  - Property-based testing using PropCheck and ExUnitProperties
  - STAMP safety constraints for performance monitoring reliability
  - Enterprise scenarios for large-scale performance tracking
  - Performance tests for high-volume metrics processing
  """

  use ExUnit.Case, async: true
  use Indrajaal.DataCase
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Analytics.PerformanceMetric

  describe "PerformanceMetric Creation - TDG Unit Tests" do
    test "creates performance metric for __database response time" do
      attrs = %{
        metric_name: "__database_response_time",
        component: "postgresql",
        value: Decimal.new("45.7"),
        unit: "milliseconds",
        threshold_warning: Decimal.new("100.0"),
        threshold_critical: Decimal.new("500.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "__database_response_time"
      assert metric.component == "postgresql"
      assert Decimal.equal?(metric.value, Decimal.new("45.7"))
      assert metric.unit == "milliseconds"
      assert Decimal.equal?(metric.threshold_warning, Decimal.new("100.0"))
      assert Decimal.equal?(metric.threshold_critical, Decimal.new("500.0"))
      assert metric.timestamp != nil
    end

    test "creates performance metric for CPU utilization" do
      attrs = %{
        metric_name: "cpu_utilization",
        component: "web_server",
        value: Decimal.new("73.2"),
        unit: "percent",
        threshold_warning: Decimal.new("80.0"),
        threshold_critical: Decimal.new("95.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "cpu_utilization"
      assert metric.component == "web_server"
      assert Decimal.equal?(metric.value, Decimal.new("73.2"))
      assert metric.unit == "percent"

      # Verify thresholds are properly set for alerting
      assert Decimal.lt?(metric.value, metric.threshold_warning)
      assert Decimal.lt?(metric.value, metric.threshold_critical)
    end

    test "creates performance metric for memory usage" do
      attrs = %{
        metric_name: "memory_usage",
        component: "application_server",
        value: Decimal.new("2048.5"),
        unit: "megabytes",
        threshold_warning: Decimal.new("3072.0"),
        threshold_critical: Decimal.new("4096.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "memory_usage"
      assert metric.component == "application_server"
      assert Decimal.equal?(metric.value, Decimal.new("2048.5"))
      assert metric.unit == "megabytes"
    end

    test "creates performance metric for network throughput" do
      attrs = %{
        metric_name: "network_throughput",
        component: "load_balancer",
        value: Decimal.new("1024.8"),
        unit: "mbps",
        threshold_warning: Decimal.new("800.0"),
        threshold_critical: Decimal.new("1500.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "network_throughput"
      assert metric.component == "load_balancer"
      assert Decimal.equal?(metric.value, Decimal.new("1024.8"))
      assert metric.unit == "mbps"

      # Verify value exceeds warning threshold
      assert Decimal.gt?(metric.value, metric.threshold_warning)
      assert Decimal.lt?(metric.value, metric.threshold_critical)
    end

    test "creates performance metric for disk I/O operations" do
      attrs = %{
        metric_name: "disk_io_operations",
        component: "storage_array",
        value: Decimal.new("15_670"),
        unit: "iops",
        threshold_warning: Decimal.new("20_000"),
        threshold_critical: Decimal.new("30_000")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "disk_io_operations"
      assert metric.component == "storage_array"
      assert Decimal.equal?(metric.value, Decimal.new("15_670"))
      assert metric.unit == "iops"
    end

    test "creates performance metric for application response time" do
      attrs = %{
        metric_name: "application_response_time",
        component: "phoenix_app",
        value: Decimal.new("120.3"),
        unit: "milliseconds",
        threshold_warning: Decimal.new("200.0"),
        threshold_critical: Decimal.new("1000.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.metric_name == "application_response_time"
      assert metric.component == "phoenix_app"
      assert Decimal.equal?(metric.value, Decimal.new("120.3"))
    end

    test "validates __required metric_name attribute" do
      attrs = %{
        component: "web_server",
        value: Decimal.new("50.0")
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "validates __required component attribute" do
      attrs = %{
        metric_name: "cpu_utilization",
        value: Decimal.new("50.0")
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "validates __required value attribute" do
      attrs = %{
        metric_name: "cpu_utilization",
        component: "web_server"
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "validates metric_name max length constraint" do
      attrs = %{
        # Exceeds 100 character limit
        metric_name: String.duplicate("a", 101),
        component: "web_server",
        value: Decimal.new("50.0")
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "validates component max length constraint" do
      attrs = %{
        metric_name: "cpu_utilization",
        # Exceeds 50 character limit
        component: String.duplicate("a", 51),
        value: Decimal.new("50.0")
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "validates unit max length constraint" do
      attrs = %{
        metric_name: "cpu_utilization",
        component: "web_server",
        value: Decimal.new("50.0"),
        # Exceeds 20 character limit
        unit: String.duplicate("a", 21)
      }

      assert {:error, %Ash.Error.Invalid{}} = PerformanceMetric.create(attrs)
    end

    test "automatically sets timestamp to current time" do
      before_creation = DateTime.utc_now()

      attrs = %{
        metric_name: "test_metric",
        component: "test_component",
        value: Decimal.new("100.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)

      after_creation = DateTime.utc_now()

      assert DateTime.compare(metric.timestamp, before_creation) in [:gt, :eq]
      assert DateTime.compare(metric.timestamp, after_creation) in [:lt, :eq]
    end

    test "allows optional threshold values to be nil" do
      attrs = %{
        metric_name: "test_metric",
        component: "test_component",
        value: Decimal.new("50.0")
      }

      assert {:ok, metric} = PerformanceMetric.create(attrs)
      assert metric.threshold_warning == nil
      assert metric.threshold_critical == nil
    end
  end

  describe "PerformanceMetric Updates - TDG Integration Tests" do
    test "updates performance metric value with new measurement" do
      {:ok, metric} =
        PerformanceMetric.create(%{
          metric_name: "cpu_utilization",
          component: "web_server",
          value: Decimal.new("60.0")
        })

      # Simulate metric update with new reading
      assert {:ok, updated_metric} =
               PerformanceMetric.update(metric, %{
                 value: Decimal.new("75.2")
               })

      assert Decimal.equal?(updated_metric.value, Decimal.new("75.2"))
      assert updated_metric.id == metric.id
      assert updated_metric.metric_name == metric.metric_name
    end

    test "updates threshold values for dynamic alerting" do
      {:ok, metric} =
        PerformanceMetric.create(%{
          metric_name: "memory_usage",
          component: "application_server",
          value: Decimal.new("1024.0"),
          threshold_warning: Decimal.new("2048.0"),
          threshold_critical: Decimal.new("4096.0")
        })

      # Adjust thresholds based on capacity changes
      assert {:ok, updated_metric} =
               PerformanceMetric.update(metric, %{
                 threshold_warning: Decimal.new("3072.0"),
                 threshold_critical: Decimal.new("6144.0")
               })

      assert Decimal.equal?(updated_metric.threshold_warning, Decimal.new("3072.0"))
      assert Decimal.equal?(updated_metric.threshold_critical, Decimal.new("6144.0"))
    end

    test "updates component name for infrastructure changes" do
      {:ok, metric} =
        PerformanceMetric.create(%{
          metric_name: "__database_connections",
          component: "postgresql_primary",
          value: Decimal.new("150")
        })

      # Rename component after infrastructure update
      assert {:ok, updated_metric} =
               PerformanceMetric.update(metric, %{
                 component: "postgresql_cluster"
               })

      assert updated_metric.component == "postgresql_cluster"
      assert updated_metric.metric_name == metric.metric_name
      assert Decimal.equal?(updated_metric.value, metric.value)
    end

    test "updates unit for metric standardization" do
      {:ok, metric} =
        PerformanceMetric.create(%{
          metric_name: "response_time",
          component: "api_gateway",
          value: Decimal.new("500"),
          unit: "microseconds"
        })

      # Convert to standard milliseconds
      assert {:ok, updated_metric} =
               PerformanceMetric.update(metric, %{
                 value: Decimal.new("0.5"),
                 unit: "milliseconds"
               })

      assert updated_metric.unit == "milliseconds"
      assert Decimal.equal?(updated_metric.value, Decimal.new("0.5"))
    end
  end

  describe "Property-Based Testing - PropCheck" do
    property "propcheck: performance metric creation with valid decimal values" do
      forall {metric_name, component, value_float} <- {
               PC.string(),
               PC.string(),
               PC.float()
             } do
        # Ensure strings meet length constraints
        valid_metric_name = String.slice(metric_name, 0, 99)
        valid_component = String.slice(component, 0, 49)

        # Skip if strings are empty after truncation
        if String.length(valid_metric_name) > 0 and String.length(valid_component) > 0 do
          value = Decimal.from_float(abs(value_float))

          attrs = %{
            metric_name: valid_metric_name,
            component: valid_component,
            value: value
          }

          case PerformanceMetric.create(attrs) do
            {:ok, metric} ->
              metric.metric_name == valid_metric_name and
                metric.component == valid_component and
                Decimal.equal?(metric.value, value)

            {:error, _} ->
              false
          end
        else
          # Skip invalid test case
          true
        end
      end
    end

    property "propcheck: threshold validation with warning < critical" do
      forall {warning_val, critical_val} <- {PC.float(), PC.float()} do
        if warning_val < critical_val and warning_val >= 0 and critical_val >= 0 do
          warning = Decimal.from_float(warning_val)
          critical = Decimal.from_float(critical_val)

          attrs = %{
            metric_name: "test_metric",
            component: "test_component",
            value: Decimal.new("10.0"),
            threshold_warning: warning,
            threshold_critical: critical
          }

          case PerformanceMetric.create(attrs) do
            {:ok, metric} ->
              Decimal.lt?(metric.threshold_warning, metric.threshold_critical)

            {:error, _} ->
              false
          end
        else
          # Skip invalid combinations
          true
        end
      end
    end
  end

  describe "Property-Based Testing - ExUnitProperties" do
    test "exunitproperties: timestamp consistency and ordering" do
      ExUnitProperties.check all(
                               metric_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               component <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 30),
                               value <- SD.float(min: 0.0, max: 1_000_000.0),
                               max_runs: 50
                             ) do
        before_creation = DateTime.utc_now()

        attrs = %{
          metric_name: metric_name,
          component: component,
          value: Decimal.from_float(value)
        }

        assert {:ok, metric} = PerformanceMetric.create(attrs)

        after_creation = DateTime.utc_now()

        # Verify timestamp is within reasonable bounds
        assert DateTime.diff(metric.timestamp, before_creation, :second) >= 0
        assert DateTime.diff(after_creation, metric.timestamp, :second) >= 0
        assert DateTime.diff(after_creation, metric.timestamp, :second) < 5
      end
    end

    test "exunitproperties: decimal precision preservation" do
      ExUnitProperties.check all(
                               value_str <- SD.string(:printable, min_length: 1, max_length: 10),
                               max_runs: 30
                             ) do
        # Try to create valid decimal from string
        case Decimal.parse(value_str) do
          {decimal_value, ""} ->
            attrs = %{
              metric_name: "precision_test",
              component: "test_component",
              value: decimal_value
            }

            case PerformanceMetric.create(attrs) do
              {:ok, metric} ->
                assert Decimal.equal?(metric.value, decimal_value)

              {:error, _} ->
                # Acceptable for invalid values
                :ok
            end

          _ ->
            # Skip invalid decimal strings
            :ok
        end
      end
    end
  end

  describe "STAMP Safety Constraints - Performance Metrics" do
    test "SC-PM-001: System SHALL maintain metric accuracy and pr__event __data corruption" do
      original_value = Decimal.new("123.456")

      {:ok, metric} =
        PerformanceMetric.create(%{
          metric_name: "accurate_measurement",
          component: "precision_sensor",
          value: original_value,
          unit: "units"
        })

      # Verify exact value preservation
      assert Decimal.equal?(metric.value, original_value)

      # Update metric and verify accuracy maintained
      updated_value = Decimal.new("789.012")

      {:ok, updated_metric} =
        PerformanceMetric.update(metric, %{
          value: updated_value
        })

      assert Decimal.equal?(updated_metric.value, updated_value)
      assert not Decimal.equal?(updated_metric.value, original_value)

      # Verify no __data corruption in other fields
      assert updated_metric.metric_name == metric.metric_name
      assert updated_metric.component == metric.component
      assert updated_metric.unit == metric.unit
    end

    test "SC-PM-002: System SHALL enforce threshold logical consistency" do
      # Valid threshold configuration (warning < critical)
      attrs_valid = %{
        metric_name: "threshold_test",
        component: "monitoring_system",
        value: Decimal.new("50.0"),
        threshold_warning: Decimal.new("75.0"),
        threshold_critical: Decimal.new("95.0")
      }

      {:ok, metric} = PerformanceMetric.create(attrs_valid)

      # Verify threshold ordering
      assert Decimal.lt?(metric.threshold_warning, metric.threshold_critical)

      # Test update maintaining logical consistency
      {:ok, updated_metric} =
        PerformanceMetric.update(metric, %{
          threshold_warning: Decimal.new("80.0"),
          threshold_critical: Decimal.new("98.0")
        })

      assert Decimal.lt?(updated_metric.threshold_warning, updated_metric.threshold_critical)
    end

    test "SC-PM-003: System SHALL preserve metric temporal ordering and history" do
      component_name = "temporal_test_component"

      # Create metrics with different timestamps
      {:ok, metric_1} =
        PerformanceMetric.create(%{
          metric_name: "temporal_metric",
          component: component_name,
          value: Decimal.new("10.0")
        })

      # Small delay to ensure different timestamps
      :timer.sleep(10)

      {:ok, metric_2} =
        PerformanceMetric.create(%{
          metric_name: "temporal_metric",
          component: component_name,
          value: Decimal.new("20.0")
        })

      # Verify temporal ordering
      assert DateTime.compare(metric_1.timestamp, metric_2.timestamp) == :lt

      # Verify both metrics exist independently
      all_metrics = PerformanceMetric.read!()
      component_metrics = Enum.filter(all_metrics, &(&1.component == component_name))

      assert length(component_metrics) >= 2

      # Verify historical __data preservation
      first_metric = Enum.find(component_metrics, &(&1.id == metric_1.id))
      second_metric = Enum.find(component_metrics, &(&1.id == metric_2.id))

      assert first_metric != nil
      assert second_metric != nil
      assert Decimal.equal?(first_metric.value, Decimal.new("10.0"))
      assert Decimal.equal?(second_metric.value, Decimal.new("20.0"))
    end

    test "SC-PM-004: System SHALL validate metric values within reasonable bounds" do
      # Test normal positive values
      {:ok, metric_normal} =
        PerformanceMetric.create(%{
          metric_name: "normal_metric",
          component: "test_component",
          value: Decimal.new("100.5")
        })

      assert Decimal.positive?(metric_normal.value)

      # Test zero value (valid for some metrics)
      {:ok, metric_zero} =
        PerformanceMetric.create(%{
          metric_name: "zero_metric",
          component: "test_component",
          value: Decimal.new("0.0")
        })

      assert Decimal.equal?(metric_zero.value, Decimal.new("0.0"))

      # Test large values (should be acceptable)
      {:ok, metric_large} =
        PerformanceMetric.create(%{
          metric_name: "large_metric",
          component: "test_component",
          value: Decimal.new("999_999.999")
        })

      assert Decimal.gt?(metric_large.value, Decimal.new("999_999"))

      # Test negative values (may be valid for some metrics like temperature)
      {:ok, metric_negative} =
        PerformanceMetric.create(%{
          metric_name: "temperature_metric",
          component: "sensor",
          value: Decimal.new("-10.5")
        })

      assert Decimal.negative?(metric_negative.value)
    end

    test "SC-PM-005: System SHALL ensure metric naming consistency and pr__event duplication conflicts" do
      base_attrs = %{
        metric_name: "consistency_test_metric",
        component: "test_component",
        value: Decimal.new("50.0")
      }

      {:ok, metric_1} = PerformanceMetric.create(base_attrs)

      # Create metric with same name but different component (should be allowed)
      {:ok, metric_2} =
        PerformanceMetric.create(Map.put(base_attrs, :component, "different_component"))

      # Create metric with same name and component but different value (should be allowed - time series)
      {:ok, metric_3} = PerformanceMetric.create(Map.put(base_attrs, :value, Decimal.new("75.0")))

      # Verify all metrics exist with consistent naming
      all_metrics = PerformanceMetric.read!()

      consistency_metrics =
        Enum.filter(all_metrics, &(&1.metric_name == "consistency_test_metric"))

      assert length(consistency_metrics) >= 3

      # Verify naming consistency maintained
      assert Enum.all?(consistency_metrics, &(&1.metric_name == "consistency_test_metric"))

      # Verify different components and values are properly stored
      component_list = Enum.map(consistency_metrics, & &1.component)
      components = component_list |> Enum.uniq()
      assert length(components) >= 2
    end
  end

  describe "Enterprise Scenarios - TDG Business Logic Tests" do
    test "creates comprehensive application performance monitoring dashboard" do
      # Simulate APM system with multiple performance metrics
      apm_metrics = [
        %{
          metric_name: "__request_throughput",
          component: "web_application",
          value: Decimal.new("1250.5"),
          unit: "__requests_per_second",
          threshold_warning: Decimal.new("1000.0"),
          threshold_critical: Decimal.new("2000.0")
        },
        %{
          metric_name: "average_response_time",
          component: "web_application",
          value: Decimal.new("95.3"),
          unit: "milliseconds",
          threshold_warning: Decimal.new("200.0"),
          threshold_critical: Decimal.new("1000.0")
        },
        %{
          metric_name: "error_rate",
          component: "web_application",
          value: Decimal.new("0.2"),
          unit: "percent",
          threshold_warning: Decimal.new("1.0"),
          threshold_critical: Decimal.new("5.0")
        },
        %{
          metric_name: "active_connections",
          component: "web_application",
          value: Decimal.new("340"),
          unit: "connections",
          threshold_warning: Decimal.new("500"),
          threshold_critical: Decimal.new("1000")
        }
      ]

      created_metrics =
        Enum.map(apm_metrics, fn attrs ->
          {:ok, metric} = PerformanceMetric.create(attrs)
          metric
        end)

      # Verify comprehensive APM metrics
      assert length(created_metrics) == 4

      # Verify throughput metric
      throughput_metric = Enum.find(created_metrics, &(&1.metric_name == "__request_throughput"))
      assert throughput_metric != nil
      assert Decimal.gt?(throughput_metric.value, throughput_metric.threshold_warning)
      assert Decimal.lt?(throughput_metric.value, throughput_metric.threshold_critical)

      # Verify response time is within acceptable limits
      response_time_metric =
        Enum.find(created_metrics, &(&1.metric_name == "average_response_time"))

      assert Decimal.lt?(response_time_metric.value, response_time_metric.threshold_warning)

      # Verify error rate is low
      error_rate_metric = Enum.find(created_metrics, &(&1.metric_name == "error_rate"))
      assert Decimal.lt?(error_rate_metric.value, error_rate_metric.threshold_warning)
    end

    test "creates infrastructure monitoring with multi-layer system metrics" do
      # Simulate enterprise infrastructure monitoring
      infrastructure_metrics = [
        # Hardware layer
        %{
          metric_name: "cpu_utilization",
          component: "server_node_1",
          value: Decimal.new("68.5"),
          unit: "percent"
        },
        %{
          metric_name: "memory_utilization",
          component: "server_node_1",
          value: Decimal.new("72.3"),
          unit: "percent"
        },
        %{
          metric_name: "disk_utilization",
          component: "server_node_1",
          value: Decimal.new("45.8"),
          unit: "percent"
        },

        # Network layer
        %{
          metric_name: "network_throughput_in",
          component: "load_balancer",
          value: Decimal.new("850.2"),
          unit: "mbps"
        },
        %{
          metric_name: "network_throughput_out",
          component: "load_balancer",
          value: Decimal.new("920.7"),
          unit: "mbps"
        },
        %{
          metric_name: "packet_loss_rate",
          component: "load_balancer",
          value: Decimal.new("0.01"),
          unit: "percent"
        },

        # Database layer
        %{
          metric_name: "query_response_time",
          component: "postgresql_primary",
          value: Decimal.new("12.8"),
          unit: "milliseconds"
        },
        %{
          metric_name: "active_connections",
          component: "postgresql_primary",
          value: Decimal.new("85"),
          unit: "connections"
        },
        %{
          metric_name: "cache_hit_ratio",
          component: "postgresql_primary",
          value: Decimal.new("94.2"),
          unit: "percent"
        },

        # Application layer
        %{
          metric_name: "heap_memory_usage",
          component: "elixir_application",
          value: Decimal.new("450.3"),
          unit: "megabytes"
        },
        %{
          metric_name: "process_count",
          component: "elixir_application",
          value: Decimal.new("2847"),
          unit: "processes"
        },
        %{
          metric_name: "garbage_collection_f__requency",
          component: "elixir_application",
          value: Decimal.new("125"),
          unit: "per_minute"
        }
      ]

      created_metrics =
        Enum.map(infrastructure_metrics, fn attrs ->
          {:ok, metric} = PerformanceMetric.create(attrs)
          metric
        end)

      # Verify multi-layer monitoring
      assert length(created_metrics) == 12

      # Verify hardware layer metrics
      hardware_metrics = Enum.filter(created_metrics, &(&1.component == "server_node_1"))
      assert length(hardware_metrics) == 3

      # Verify network layer metrics
      network_metrics = Enum.filter(created_metrics, &(&1.component == "load_balancer"))
      assert length(network_metrics) == 3

      # Verify __database performance
      db_metrics = Enum.filter(created_metrics, &(&1.component == "postgresql_primary"))
      assert length(db_metrics) == 3

      query_time_metric = Enum.find(db_metrics, &(&1.metric_name == "query_response_time"))
      # Good performance
      assert Decimal.lt?(query_time_metric.value, Decimal.new("50.0"))

      # Verify application metrics
      app_metrics = Enum.filter(created_metrics, &(&1.component == "elixir_application"))
      assert length(app_metrics) == 3

      process_count_metric = Enum.find(app_metrics, &(&1.metric_name == "process_count"))
      # Healthy process count
      assert Decimal.gt?(process_count_metric.value, Decimal.new("1000"))
    end

    test "creates business KPI performance tracking system" do
      # Simulate business-level performance indicators
      business_kpis = [
        %{
          metric_name: "__user_session_duration",
          component: "__user_engagement",
          value: Decimal.new("480.5"),
          unit: "seconds",
          threshold_warning: Decimal.new("300.0"),
          threshold_critical: Decimal.new("120.0")
        },
        %{
          metric_name: "conversion_rate",
          component: "sales_funnel",
          value: Decimal.new("3.8"),
          unit: "percent",
          threshold_warning: Decimal.new("2.0"),
          threshold_critical: Decimal.new("1.0")
        },
        %{
          metric_name: "customer_satisfaction_score",
          component: "customer_service",
          value: Decimal.new("4.6"),
          unit: "rating_scale_5",
          threshold_warning: Decimal.new("4.0"),
          threshold_critical: Decimal.new("3.0")
        },
        %{
          metric_name: "revenue_per_user",
          component: "monetization",
          value: Decimal.new("45.75"),
          unit: "dollars",
          threshold_warning: Decimal.new("30.0"),
          threshold_critical: Decimal.new("15.0")
        },
        %{
          metric_name: "churn_rate",
          component: "customer_retention",
          value: Decimal.new("2.1"),
          unit: "percent_monthly",
          threshold_warning: Decimal.new("5.0"),
          threshold_critical: Decimal.new("10.0")
        }
      ]

      created_kpis =
        Enum.map(business_kpis, fn attrs ->
          {:ok, metric} = PerformanceMetric.create(attrs)
          metric
        end)

      # Verify business KPI tracking
      assert length(created_kpis) == 5

      # Verify engagement metrics
      session_duration = Enum.find(created_kpis, &(&1.metric_name == "__user_session_duration"))
      assert Decimal.gt?(session_duration.value, session_duration.threshold_warning)

      # Verify sales performance
      conversion_rate = Enum.find(created_kpis, &(&1.metric_name == "conversion_rate"))
      assert Decimal.gt?(conversion_rate.value, conversion_rate.threshold_warning)

      # Verify customer satisfaction
      satisfaction = Enum.find(created_kpis, &(&1.metric_name == "customer_satisfaction_score"))
      assert Decimal.gt?(satisfaction.value, satisfaction.threshold_warning)

      # Verify revenue metrics
      revenue_per_user = Enum.find(created_kpis, &(&1.metric_name == "revenue_per_user"))
      assert Decimal.gt?(revenue_per_user.value, revenue_per_user.threshold_warning)

      # Verify retention (lower churn is better)
      churn_rate = Enum.find(created_kpis, &(&1.metric_name == "churn_rate"))
      assert Decimal.lt?(churn_rate.value, churn_rate.threshold_warning)
    end

    test "performs performance trend analysis with time-series __data" do
      metric_name = "cpu_utilization_trend"
      component = "production_server"

      # Create time series __data (simulating hourly measurements)
      time_series_data =
        Enum.map(1..24, fn hour ->
          # Simulate daily CPU pattern (higher during business hours)
          base_cpu = if hour in 9..17, do: 70.0, else: 30.0
          # ±10% variation
          variation = :rand.uniform() * 20 - 10
          cpu_value = max(0.0, base_cpu + variation)

          timestamp = DateTime.add(DateTime.utc_now(), -24 * 3600 + hour * 3600, :second)

          {:ok, metric} =
            PerformanceMetric.create(%{
              metric_name: metric_name,
              component: component,
              value: Decimal.from_float(cpu_value),
              unit: "percent",
              timestamp: timestamp,
              threshold_warning: Decimal.new("80.0"),
              threshold_critical: Decimal.new("95.0")
            })

          metric
        end)

      # Verify time series creation
      assert length(time_series_data) == 24

      # Analyze trend __data
      all_metrics = PerformanceMetric.read!()

      trend_metrics =
        Enum.filter(all_metrics, fn metric ->
          metric.metric_name == metric_name and metric.component == component
        end)

      assert length(trend_metrics) >= 24

      # Sort by timestamp for trend analysis
      sorted_metrics =
        Enum.sort(trend_metrics, &(DateTime.compare(&1.timestamp, &2.timestamp) != :gt))

      # Verify temporal ordering
      timestamps = Enum.map(sorted_metrics, & &1.timestamp)
      timestamp_pairs = Enum.zip(timestamps, Enum.drop(timestamps, 1))

      assert Enum.all?(timestamp_pairs, fn {earlier, later} ->
               DateTime.compare(earlier, later) in [:lt, :eq]
             end)

      # Analyze business hours vs off-hours performance
      business_hours_metrics =
        Enum.filter(sorted_metrics, fn metric ->
          hour = metric.timestamp.hour
          hour >= 9 and hour <= 17
        end)

      off_hours_metrics =
        Enum.filter(sorted_metrics, fn metric ->
          hour = metric.timestamp.hour
          hour < 9 or hour > 17
        end)

      # Calculate average CPU during business vs off hours
      if length(business_hours_metrics) > 0 and length(off_hours_metrics) > 0 do
        business_avg =
          business_hours_metrics
          |> Enum.map(&Decimal.to_float(&1.value))
          |> Enum.sum()
          |> Kernel./(length(business_hours_metrics))

        off_hours_avg =
          off_hours_metrics
          |> Enum.map(&Decimal.to_float(&1.value))
          |> Enum.sum()
          |> Kernel./(length(off_hours_metrics))

        # Business hours should generally have higher CPU utilization
        assert business_avg > off_hours_avg
      end
    end
  end

  describe "Performance Testing - TDG Scalability Tests" do
    test "handles high-volume metric ingestion efficiently" do
      # Simulate enterprise-scale metric collection
      metric_count = 1000
      components = ["web_server", "__database", "cache", "load_balancer", "storage"]
      metric_names = ["cpu_util", "memory_util", "disk_io", "network_throughput", "response_time"]

      start_time = System.monotonic_time(:millisecond)

      created_metrics =
        Enum.map(1..metric_count, fn i ->
          component = Enum.at(components, rem(i, length(components)))
          metric_name = Enum.at(metric_names, rem(i, length(metric_names)))

          attrs = %{
            metric_name: "#{metric_name}_#{i}",
            component: component,
            value: Decimal.from_float(:rand.uniform() * 100),
            unit: "percent"
          }

          {:ok, metric} = PerformanceMetric.create(attrs)
          metric
        end)

      end_time = System.monotonic_time(:millisecond)
      ingestion_time = end_time - start_time

      # Verify performance and __data integrity
      assert length(created_metrics) == metric_count
      # Should complete within 60 seconds
      assert ingestion_time < 60_000

      # Verify __data integrity sampling
      sample_metric = Enum.at(created_metrics, 500)
      assert sample_metric.component in components
      assert String.contains?(sample_metric.metric_name, "_")
      assert Decimal.gt?(sample_metric.value, Decimal.new("0"))
      assert Decimal.lt?(sample_metric.value, Decimal.new("100"))

      # Verify ingestion rate
      ingestion_rate = metric_count / (ingestion_time / 1000)
      # At least 10 metrics per second
      assert ingestion_rate > 10
    end

    test "performs efficient metric querying and aggregation" do
      component_name = "performance_test_component"
      metric_name = "test_query_metric"

      # Create test __dataset
      _test_metrics =
        Enum.map(1..200, fn i ->
          {:ok, metric} =
            PerformanceMetric.create(%{
              metric_name: metric_name,
              component: component_name,
              value: Decimal.from_float(i * 1.5),
              unit: "test_units"
            })

          metric
        end)

      # Performance test for querying
      start_time = System.monotonic_time(:millisecond)

      all_metrics = PerformanceMetric.read!()
      component_metrics = Enum.filter(all_metrics, &(&1.component == component_name))

      high_value_metrics =
        Enum.filter(component_metrics, &Decimal.gt?(&1.value, Decimal.new("150")))

      end_time = System.monotonic_time(:millisecond)
      query_time = end_time - start_time

      # Verify query performance and accuracy
      assert length(component_metrics) == 200
      # Values > 150
      assert length(high_value_metrics) > 50
      # Should complete within 5 seconds
      assert query_time < 5000

      # Verify filtering accuracy
      assert Enum.all?(component_metrics, &(&1.component == component_name))
      assert Enum.all?(high_value_metrics, &Decimal.gt?(&1.value, Decimal.new("150")))

      # Perform aggregation calculations
      values = Enum.map(component_metrics, &Decimal.to_float(&1.value))
      min_value = Enum.min(values)
      max_value = Enum.max(values)
      avg_value = Enum.sum(values) / length(values)

      # First value
      assert min_value == 1.5
      # Last value (200 * 1.5)
      assert max_value == 300.0
      # Reasonable average
      assert avg_value > 100.0
    end

    test "handles concurrent metric updates efficiently" do
      # Create base metrics for concurrent updates
      base_metrics =
        Enum.map(1..50, fn i ->
          {:ok, metric} =
            PerformanceMetric.create(%{
              metric_name: "concurrent_test_#{i}",
              component: "concurrent_component",
              value: Decimal.new("50.0"),
              threshold_warning: Decimal.new("80.0")
            })

          metric
        end)

      # Simulate concurrent updates
      start_time = System.monotonic_time(:millisecond)

      update_tasks =
        Enum.map(base_metrics, fn metric ->
          Task.async(fn ->
            new_value = Decimal.from_float(:rand.uniform() * 100)
            {:ok, updated_metric} = PerformanceMetric.update(metric, %{value: new_value})
            updated_metric
          end)
        end)

      updated_metrics = Enum.map(update_tasks, &Task.await(&1, 30_000))

      end_time = System.monotonic_time(:millisecond)
      concurrent_update_time = end_time - start_time

      # Verify concurrent update performance
      assert length(updated_metrics) == 50
      # Should complete within 30 seconds
      assert concurrent_update_time < 30_000

      # Verify all updates succeeded
      assert Enum.all?(updated_metrics, fn metric ->
               # Value was changed
               not Decimal.equal?(metric.value, Decimal.new("50.0"))
             end)

      # Verify __data integrity after concurrent updates
      sample_updated = Enum.at(updated_metrics, 25)
      assert sample_updated.component == "concurrent_component"
      assert String.starts_with?(sample_updated.metric_name, "concurrent_test_")
      assert Decimal.equal?(sample_updated.threshold_warning, Decimal.new("80.0"))
    end
  end
end
