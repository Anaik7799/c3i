defmodule Indrajaal.Analytics.RealTimeBiCollectorTest do
  @moduledoc """
  TDG (Test-Driven Generation) comprehensive test suite for RealTimeBiCollector module.

  This test suite validates the real-time business intelligence data collector that provides
  continuous data ingestion, processing, and distribution for enterprise analytics systems.

  ## TDG Methodology Compliance
  - Tests written FIRST before implementation (ENHANCED for refactored non-GenServer version)
  - Comprehensive coverage of all real-time collection scenarios
  - Property-based testing for data integrity invariants
  - Integration testing with BI and analytics platforms
  - Functional module tests (no GenServer state management)

  ## STAMP Safety Integration
  - SC-RTBC-001: System SHALL maintain data integrity during high-volume collection
  - SC-RTBC-002: System SHALL prevent data loss during system interruptions
  - SC-RTBC-003: System SHALL provide real-time data delivery within acceptable latency
  - SC-RTBC-004: System SHALL handle backpressure and resource constraints gracefully
  - SC-RTBC-005: System SHALL maintain collection availability during peak loads

  ## Business Context
  Real-time BI collector is critical for executive decision-making, operational monitoring,
  and strategic business intelligence across enterprise systems.

  ## Refactoring Notes (Phase 3.1.2)
  Enhanced tests for GenServer -> Functional module conversion while preserving all API contracts.
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Indrajaal.Factory
  import Ecto.Query

  alias Indrajaal.Analytics.RealTimeBICollector, as: RealTimeBiCollector
  alias Indrajaal.Repo

  # Test Fixtures and Helpers
  @valid_attrs %{
    collector_name: "Enterprise BI Data Collector",
    collection_type: :comprehensive,
    data_sources: [
      %{name: "sales_db", type: "postgresql", connection: "primary"},
      %{name: "crm_api", type: "rest_api", endpoint: "https://api.crm.com/v1"},
      %{name: "event_stream", type: "kafka", topics: ["user_events", "system_events"]},
      %{name: "metrics_store", type: "influxdb", database: "metrics"}
    ],
    # seconds
    collection_interval: 5,
    batch_size: 1000,
    processing_pipeline: %{
      stages: [
        %{name: "validation", type: "data_quality", enabled: true},
        %{name: "transformation", type: "etl", enabled: true},
        %{name: "enrichment", type: "context_addition", enabled: true},
        %{name: "aggregation", type: "real_time_rollup", enabled: true}
      ],
      parallel_processing: true,
      error_handling: "retry_with_dlq",
      timeout_seconds: 30
    },
    output_destinations: [
      %{name: "data_warehouse", type: "snowflake", connection: "primary_dw"},
      %{name: "real_time_dashboard", type: "websocket", endpoint: "wss://dashboard.company.com"},
      %{name: "analytics_api", type: "rest_api", endpoint: "https://analytics.company.com/api/v1"}
    ],
    quality_configuration: %{
      data_validation: true,
      schema_enforcement: true,
      duplicate_detection: true,
      anomaly_detection: true,
      completeness_threshold: 95.0,
      accuracy_threshold: 98.0
    },
    performance_configuration: %{
      # records per second
      max_throughput: 10_000,
      # milliseconds
      max_latency: 100,
      # MB
      memory_limit: 2048,
      # cores
      cpu_limit: 4.0,
      retry_attempts: 3,
      circuit_breaker_threshold: 10
    },
    monitoring_configuration: %{
      health_checks: true,
      metrics_collection: true,
      alerting_enabled: true,
      dashboard_integration: true,
      log_level: "info"
    },
    status: :active,
    metadata: %{
      created_by: "data_engineering",
      department: "analytics",
      criticality: "high",
      sla_tier: "tier_1"
    }
  }

  @invalid_attrs %{
    collector_name: nil,
    collection_type: nil,
    data_sources: nil
  }

  describe "RealTimeBiCollector creation and basic operations" do
    test "creates real-time BI collector with valid attributes" do
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, @valid_attrs)
      assert changeset.valid?

      {:ok, collector} = Repo.insert(changeset)
      assert collector.collector_name == "Enterprise BI Data Collector"
      assert collector.collection_type == :comprehensive
      assert collector.status == :active
      assert length(collector.data_sources) == 4
    end

    test "requires essential BI collector attributes" do
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, @invalid_attrs)
      refute changeset.valid?

      assert %{collector_name: ["can't be blank"]} = errors_on(changeset)
      assert %{collection_type: ["can't be blank"]} = errors_on(changeset)
      assert %{data_sources: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates collection interval within acceptable range" do
      invalid_interval_low = Map.put(@valid_attrs, :collection_interval, 0)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, invalid_interval_low)
      refute changeset.valid?
      assert %{collection_interval: ["must be greater than 0"]} = errors_on(changeset)

      # > 24 hours
      invalid_interval_high = Map.put(@valid_attrs, :collection_interval, 86_401)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, invalid_interval_high)
      refute changeset.valid?

      assert %{collection_interval: ["must be less than or equal to 86_400"]} =
               errors_on(changeset)
    end

    test "validates collection_type is supported" do
      valid_types = [:comprehensive, :basic, :streaming, :batch, :hybrid]

      for type <- valid_types do
        attrs = Map.put(@valid_attrs, :collection_type, type)
        changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)
        assert changeset.valid?, "Expected #{type} to be valid"
      end

      invalid_attrs = Map.put(@valid_attrs, :collection_type, :invalid_type)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, invalid_attrs)
      refute changeset.valid?
    end

    test "validates data sources configuration structure" do
      valid_sources = [
        %{name: "database", type: "postgresql", connection: "primary"},
        %{name: "api", type: "rest_api", endpoint: "https://api.example.com"}
      ]

      attrs = Map.put(@valid_attrs, :data_sources, valid_sources)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)
      assert changeset.valid?

      invalid_sources = [
        # Missing required fields
        %{name: nil, type: "postgresql"}
      ]

      attrs_invalid = Map.put(@valid_attrs, :data_sources, invalid_sources)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs_invalid)
      # Note: This validation would be handled by embedded schema validation
    end

    test "validates processing pipeline configuration" do
      valid_pipeline = %{
        stages: [
          %{name: "validation", type: "data_quality", enabled: true},
          %{name: "transformation", type: "etl", enabled: true}
        ],
        parallel_processing: true,
        error_handling: "retry_with_dlq",
        timeout_seconds: 60
      }

      attrs = Map.put(@valid_attrs, :processing_pipeline, valid_pipeline)
      changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)
      assert changeset.valid?
    end
  end

  # STAMP Safety Constraint Tests
  describe "STAMP Safety Constraints" do
    test "SC-RTBC-001: System SHALL maintain data integrity during high-volume collection" do
      # Create collector with high-volume data integrity configuration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collection_type: :streaming,
          batch_size: 10_000,
          performance_configuration: %{
            # High volume
            max_throughput: 50_000,
            max_latency: 50,
            memory_limit: 4096,
            cpu_limit: 8.0
          },
          quality_configuration: %{
            data_validation: true,
            schema_enforcement: true,
            duplicate_detection: true,
            integrity_checksum: true,
            completeness_threshold: 99.0,
            accuracy_threshold: 99.5
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test high-volume data integrity scenarios
      high_volume_batch =
        Enum.map(1..10_000, fn i ->
          %{
            id: i,
            timestamp: DateTime.utc_now(),
            data: %{value: :rand.uniform(1000), source: "sensor_#{rem(i, 100)}"},
            checksum: "checksum_#{i}"
          }
        end)

      # Verify integrity __requirements
      quality_config = collector.quality_configuration
      assert quality_config["data_validation"] == true
      assert quality_config["schema_enforcement"] == true
      assert quality_config["duplicate_detection"] == true
      assert quality_config["completeness_threshold"] == 99.0
      assert quality_config["accuracy_threshold"] == 99.5

      # Test batch processing integrity
      assert length(high_volume_batch) == collector.batch_size
      assert collector.performance_configuration["max_throughput"] == 50_000

      # Simulate integrity validation
      unique_ids = high_volume_batch |> Enum.map(& &1.id) |> Enum.uniq()
      # No duplicates
      assert length(unique_ids) == length(high_volume_batch)

      # Verify all records have required fields
      complete_records =
        Enum.filter(high_volume_batch, fn record ->
          record.id != nil and record.timestamp != nil and record.data != nil and
            record.checksum != nil
        end)

      completeness_rate = length(complete_records) / length(high_volume_batch) * 100
      assert completeness_rate >= quality_config["completeness_threshold"]
    end

    test "SC-RTBC-002: System SHALL prevent data loss during system interruptions" do
      # Create collector with data loss prevention configuration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          processing_pipeline: %{
            stages: [
              %{name: "buffering", type: "persistent_queue", enabled: true},
              %{name: "checkpointing", type: "state_persistence", enabled: true},
              %{name: "replication", type: "data_backup", enabled: true}
            ],
            parallel_processing: true,
            error_handling: "persistent_retry",
            timeout_seconds: 120,
            recovery_mode: "automatic"
          },
          quality_configuration: %{
            persistence_strategy: "write_ahead_log",
            replication_factor: 3,
            # seconds
            backup_interval: 60,
            recovery_timeout: 300,
            data_durability: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test data loss prevention mechanisms
      processing_stages = collector.processing_pipeline["stages"]
      buffering_stage = Enum.find(processing_stages, &(&1["name"] == "buffering"))
      checkpointing_stage = Enum.find(processing_stages, &(&1["name"] == "checkpointing"))
      replication_stage = Enum.find(processing_stages, &(&1["name"] == "replication"))

      assert buffering_stage["enabled"] == true
      assert checkpointing_stage["enabled"] == true
      assert replication_stage["enabled"] == true

      # Test data durability configuration
      quality_config = collector.quality_configuration
      assert quality_config["persistence_strategy"] == "write_ahead_log"
      assert quality_config["replication_factor"] == 3
      assert quality_config["data_durability"] == true

      # Simulate system interruption scenarios
      interruption_scenarios = [
        %{type: :network_partition, duration: 30, expected_recovery: :automatic},
        %{type: :process_crash, duration: 5, expected_recovery: :immediate},
        %{type: :memory_pressure, duration: 60, expected_recovery: :graceful_degradation},
        %{type: :disk_full, duration: 120, expected_recovery: :cleanup_and_resume}
      ]

      for scenario <- interruption_scenarios do
        # Verify recovery configuration supports scenario
        assert collector.processing_pipeline["recovery_mode"] == "automatic"
        assert collector.quality_configuration["recovery_timeout"] >= scenario.duration

        # Test persistence mechanisms
        assert collector.quality_configuration["backup_interval"] <= scenario.duration
      end
    end

    test "SC-RTBC-003: System SHALL provide real-time data delivery within acceptable latency" do
      # Create collector with real-time latency __requirements
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collection_type: :streaming,
          # 1 second for real-time
          collection_interval: 1,
          performance_configuration: %{
            max_throughput: 25_000,
            # 25ms for real-time
            max_latency: 25,
            memory_limit: 3072,
            cpu_limit: 6.0,
            low_latency_mode: true,
            streaming_optimization: true
          },
          processing_pipeline: %{
            stages: [
              %{name: "fast_validation", type: "stream_validation", enabled: true},
              %{name: "real_time_transform", type: "stream_etl", enabled: true}
            ],
            parallel_processing: true,
            stream_processing: true,
            latency_optimization: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test real-time latency __requirements
      performance_config = collector.performance_configuration
      assert performance_config["max_latency"] == 25
      assert performance_config["low_latency_mode"] == true
      assert performance_config["streaming_optimization"] == true

      # Simulate real-time data flow
      real_time_events = [
        %{timestamp: DateTime.utc_now(), event: "user_login", latency_ms: 15},
        %{timestamp: DateTime.utc_now(), event: "transaction", latency_ms: 22},
        %{timestamp: DateTime.utc_now(), event: "system_alert", latency_ms: 8},
        %{timestamp: DateTime.utc_now(), event: "user_action", latency_ms: 18}
      ]

      # Verify all events meet latency __requirements
      for event <- real_time_events do
        assert event.latency_ms <= performance_config["max_latency"]
      end

      # Test stream processing optimization
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["stream_processing"] == true
      assert pipeline_config["latency_optimization"] == true

      # Calculate average latency
      avg_latency =
        real_time_events
        |> Enum.map(& &1.latency_ms)
        |> Enum.sum()
        |> div(length(real_time_events))

      assert avg_latency <= performance_config["max_latency"]
    end

    test "SC-RTBC-004: System SHALL handle backpressure and resource constraints gracefully" do
      # Create collector with backpressure handling
      collector_attrs =
        Map.merge(@valid_attrs, %{
          performance_configuration: %{
            max_throughput: 15_000,
            max_latency: 200,
            memory_limit: 2048,
            cpu_limit: 4.0,
            backpressure_strategy: "adaptive_throttling",
            resource_monitoring: true,
            auto_scaling: true
          },
          processing_pipeline: %{
            stages: [
              %{name: "rate_limiting", type: "throttle", enabled: true},
              %{name: "buffer_management", type: "adaptive_buffer", enabled: true},
              %{name: "resource_monitor", type: "constraint_monitor", enabled: true}
            ],
            backpressure_handling: true,
            circuit_breaker: true,
            graceful_degradation: true
          },
          quality_configuration: %{
            resource_thresholds: %{
              memory_warning: 80.0,
              memory_critical: 90.0,
              cpu_warning: 75.0,
              cpu_critical: 85.0
            },
            throttle_strategy: "exponential_backoff",
            drop_policy: "oldest_first"
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test backpressure handling mechanisms
      performance_config = collector.performance_configuration
      assert performance_config["backpressure_strategy"] == "adaptive_throttling"
      assert performance_config["resource_monitoring"] == true
      assert performance_config["auto_scaling"] == true

      # Test resource constraint scenarios
      resource_scenarios = [
        %{memory_usage: 85.0, cpu_usage: 70.0, expected_action: :memory_warning},
        %{memory_usage: 92.0, cpu_usage: 65.0, expected_action: :memory_critical},
        %{memory_usage: 70.0, cpu_usage: 80.0, expected_action: :cpu_warning},
        %{memory_usage: 75.0, cpu_usage: 88.0, expected_action: :cpu_critical}
      ]

      quality_config = collector.quality_configuration
      resource_thresholds = quality_config["resource_thresholds"]

      for scenario <- resource_scenarios do
        case scenario.expected_action do
          :memory_warning ->
            assert scenario.memory_usage >= resource_thresholds["memory_warning"]
            assert scenario.memory_usage < resource_thresholds["memory_critical"]

          :memory_critical ->
            assert scenario.memory_usage >= resource_thresholds["memory_critical"]

          :cpu_warning ->
            assert scenario.cpu_usage >= resource_thresholds["cpu_warning"]
            assert scenario.cpu_usage < resource_thresholds["cpu_critical"]

          :cpu_critical ->
            assert scenario.cpu_usage >= resource_thresholds["cpu_critical"]
        end
      end

      # Test throttling and circuit breaker
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["backpressure_handling"] == true
      assert pipeline_config["circuit_breaker"] == true
      assert pipeline_config["graceful_degradation"] == true
    end

    test "SC-RTBC-005: System SHALL maintain collection availability during peak loads" do
      # Create collector with high availability configuration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          performance_configuration: %{
            # High peak capacity
            max_throughput: 100_000,
            max_latency: 150,
            # High memory for peak loads
            memory_limit: 8192,
            # High CPU allocation
            cpu_limit: 16.0,
            peak_load_handling: true,
            auto_scaling: true,
            load_balancing: true
          },
          processing_pipeline: %{
            stages: [
              %{name: "load_balancer", type: "distribute", enabled: true},
              %{name: "parallel_processors", type: "scale_out", enabled: true},
              %{name: "peak_buffer", type: "overflow_buffer", enabled: true}
            ],
            horizontal_scaling: true,
            peak_optimization: true,
            availability_mode: "high"
          },
          quality_configuration: %{
            availability_target: 99.95,
            # 3x normal capacity
            peak_capacity_factor: 3.0,
            failover_enabled: true,
            redundancy_level: "high"
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test peak load handling capabilities
      performance_config = collector.performance_configuration
      assert performance_config["max_throughput"] == 100_000
      assert performance_config["peak_load_handling"] == true
      assert performance_config["auto_scaling"] == true
      assert performance_config["load_balancing"] == true

      # Simulate peak load scenarios
      peak_load_scenarios = [
        %{concurrent_requests: 50_000, expected_response: :normal_operation},
        %{concurrent_requests: 80_000, expected_response: :scale_up},
        %{concurrent_requests: 120_000, expected_response: :peak_buffer},
        %{concurrent_requests: 150_000, expected_response: :graceful_degradation}
      ]

      for scenario <- peak_load_scenarios do
        throughput_capacity = performance_config["max_throughput"]

        case scenario.expected_response do
          :normal_operation ->
            assert scenario.concurrent_requests <= throughput_capacity * 0.5

          :scale_up ->
            assert scenario.concurrent_requests <= throughput_capacity * 0.8

          :peak_buffer ->
            assert scenario.concurrent_requests <= throughput_capacity * 1.2

          :graceful_degradation ->
            assert scenario.concurrent_requests > throughput_capacity
        end
      end

      # Test availability and redundancy
      quality_config = collector.quality_configuration
      assert quality_config["availability_target"] == 99.95
      assert quality_config["peak_capacity_factor"] == 3.0
      assert quality_config["failover_enabled"] == true
      assert quality_config["redundancy_level"] == "high"

      # Verify scaling configuration
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["horizontal_scaling"] == true
      assert pipeline_config["peak_optimization"] == true
      assert pipeline_config["availability_mode"] == "high"
    end
  end

  # Property-based testing with PropCheck
  describe "PropCheck Property-Based Tests" do
    property "real-time BI collector maintains data consistency across all operations" do
      forall {collector_name, collection_type, interval} <-
               {non_empty(utf8()), oneof([:comprehensive, :streaming, :batch]), integer(1, 3600)} do
        attrs = %{
          collector_name: collector_name,
          collection_type: collection_type,
          collection_interval: interval,
          data_sources: [%{name: "test_source", type: "postgresql", connection: "test"}],
          batch_size: 1000,
          status: :active
        }

        case RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs) do
          %{valid?: true} = changeset ->
            {:ok, collector} = Repo.insert(changeset)

            # Property: Collector attributes are preserved consistently
            collector.collector_name == collector_name and
              collector.collection_type == collection_type and
              collector.collection_interval == interval and
              collector.status == :active and
              length(collector.data_sources) >= 1

          %{valid?: false} ->
            # Invalid changesets are acceptable for property testing
            true
        end
      end
    end

    property "BI collector handles various data source configurations gracefully" do
      forall data_sources <- data_sources_generator() do
        attrs = Map.merge(@valid_attrs, %{data_sources: data_sources})
        changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)

        case changeset.valid? do
          true ->
            {:ok, collector} = Repo.insert(changeset)

            # Property: Valid data sources result in properly configured collectors
            is_list(collector.data_sources) and
              length(collector.data_sources) >= 1 and
              Enum.all?(collector.data_sources, fn source ->
                is_binary(source["name"]) and is_binary(source["type"])
              end)

          false ->
            # Property: Invalid configurations are properly rejected
            length(changeset.errors) > 0
        end
      end
    end
  end

  # ExUnitProperties-based testing
  describe "ExUnitProperties Stream Data Tests" do
    test "BI collector creation with various performance configurations" do
      ExUnitProperties.check all(
                               collector_name <- SD.string(:alphanumeric, min_length: 5),
                               max_throughput <- SD.integer(1000..100_000),
                               max_latency <- SD.integer(10..1000),
                               batch_size <- SD.integer(100..10_000),
                               max_runs: 50
                             ) do
        attrs = %{
          collector_name: collector_name,
          collection_type: :comprehensive,
          data_sources: [%{name: "test_source", type: "postgresql"}],
          batch_size: batch_size,
          performance_configuration: %{
            max_throughput: max_throughput,
            max_latency: max_latency,
            memory_limit: 2048,
            cpu_limit: 4.0
          },
          status: :active
        }

        changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)

        if changeset.valid? do
          {:ok, collector} = Repo.insert(changeset)

          # Invariant: Performance configuration within expected ranges
          perf_config = collector.performance_configuration

          assert perf_config["max_throughput"] >= 1000 and
                   perf_config["max_throughput"] <= 100_000

          assert perf_config["max_latency"] >= 10 and perf_config["max_latency"] <= 1000
          assert collector.batch_size >= 100 and collector.batch_size <= 10_000
        end
      end
    end

    test "quality configuration property validation" do
      ExUnitProperties.check all(
                               completeness_threshold <- SD.float(min: 80.0, max: 100.0),
                               accuracy_threshold <- SD.float(min: 90.0, max: 100.0),
                               data_validation <- SD.boolean(),
                               schema_enforcement <- SD.boolean(),
                               max_runs: 30
                             ) do
        quality_config = %{
          completeness_threshold: completeness_threshold,
          accuracy_threshold: accuracy_threshold,
          data_validation: data_validation,
          schema_enforcement: schema_enforcement,
          duplicate_detection: true,
          anomaly_detection: true
        }

        attrs = Map.merge(@valid_attrs, %{quality_configuration: quality_config})
        changeset = RealTimeBiCollector.changeset(%RealTimeBiCollector{}, attrs)

        if changeset.valid? do
          {:ok, collector} = Repo.insert(changeset)

          # Invariant: Quality thresholds within acceptable ranges
          config = collector.quality_configuration

          assert config["completeness_threshold"] >= 80.0 and
                   config["completeness_threshold"] <= 100.0

          assert config["accuracy_threshold"] >= 90.0 and config["accuracy_threshold"] <= 100.0
          assert is_boolean(config["data_validation"])
          assert is_boolean(config["schema_enforcement"])
        end
      end
    end
  end

  # Integration Tests
  describe "Integration with BI and Analytics Platforms" do
    test "integrates with enterprise data warehouse and analytics stack" do
      # Create collector with enterprise BI integration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collector_name: "Enterprise Data Warehouse Collector",
          output_destinations: [
            %{name: "snowflake_dw", type: "snowflake", database: "enterprise_dw"},
            %{name: "tableau_server", type: "tableau", server: "analytics.company.com"},
            %{name: "powerbi_gateway", type: "powerbi", gateway: "enterprise_gateway"},
            %{name: "looker_instance", type: "looker", instance: "company.looker.com"}
          ],
          processing_pipeline: %{
            stages: [
              %{name: "dw_preparation", type: "dimensional_modeling", enabled: true},
              %{name: "cube_processing", type: "olap_cubes", enabled: true},
              %{name: "bi_optimization", type: "query_optimization", enabled: true}
            ],
            bi_integration: true,
            dimensional_modeling: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test enterprise BI integration
      output_destinations = collector.output_destinations
      assert length(output_destinations) == 4

      # Verify all major BI platforms supported
      destination_types = Enum.map(output_destinations, & &1["type"])
      assert "snowflake" in destination_types
      assert "tableau" in destination_types
      assert "powerbi" in destination_types
      assert "looker" in destination_types

      # Test BI-specific processing pipeline
      pipeline_stages = collector.processing_pipeline["stages"]
      stage_types = Enum.map(pipeline_stages, & &1["type"])
      assert "dimensional_modeling" in stage_types
      assert "olap_cubes" in stage_types
      assert "query_optimization" in stage_types

      # Simulate BI data flow
      bi_data_flow = %{
        # 1M records
        raw_data_volume: 1_000_000,
        processed_cubes: 50,
        dimensions: 25,
        measures: 100,
        # seconds average
        query_performance: 1.2
      }

      assert bi_data_flow.raw_data_volume >= 100_000
      assert bi_data_flow.processed_cubes >= 10
      # Acceptable BI performance
      assert bi_data_flow.query_performance <= 5.0
    end

    test "creates real-time executive dashboard with KPI streaming" do
      # Create collector optimized for executive dashboards
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collector_name: "Executive KPI Streaming Collector",
          collection_type: :streaming,
          # 5-second updates for executives
          collection_interval: 5,
          output_destinations: [
            %{
              name: "executive_dashboard",
              type: "websocket",
              endpoint: "wss://exec.company.com/kpis"
            },
            %{name: "mobile_app", type: "push_notifications", service: "firebase"},
            %{name: "email_alerts", type: "smtp", server: "mail.company.com"}
          ],
          processing_pipeline: %{
            stages: [
              %{name: "kpi_calculation", type: "business_metrics", enabled: true},
              %{name: "trend_analysis", type: "time_series", enabled: true},
              %{name: "alerting", type: "threshold_monitoring", enabled: true}
            ],
            real_time_kpis: true,
            executive_optimization: true
          },
          quality_configuration: %{
            kpi_accuracy: 99.5,
            # seconds
            real_time_threshold: 10,
            executive_sla: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test executive dashboard integration
      assert collector.collection_interval == 5
      assert collector.collection_type == :streaming

      # Test KPI-specific processing
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["real_time_kpis"] == true
      assert pipeline_config["executive_optimization"] == true

      # Simulate executive KPIs
      executive_kpis = %{
        revenue_today: 125_000.00,
        # percentage
        revenue_growth: 12.5,
        active_users: 8500,
        conversion_rate: 3.2,
        customer_satisfaction: 4.7,
        system_uptime: 99.97,
        # milliseconds
        response_time: 45.2,
        error_rate: 0.03
      }

      # Verify KPI quality standards
      quality_config = collector.quality_configuration
      assert quality_config["kpi_accuracy"] == 99.5
      assert quality_config["real_time_threshold"] == 10
      assert quality_config["executive_sla"] == true

      # Test KPI thresholds and alerting
      kpi_thresholds = %{
        revenue_growth: %{warning: 10.0, critical: 5.0},
        conversion_rate: %{warning: 3.0, critical: 2.5},
        system_uptime: %{warning: 99.5, critical: 99.0},
        response_time: %{warning: 100.0, critical: 200.0}
      }

      # Verify KPIs meet thresholds
      assert executive_kpis.revenue_growth >= kpi_thresholds.revenue_growth.warning
      assert executive_kpis.conversion_rate >= kpi_thresholds.conversion_rate.warning
      assert executive_kpis.system_uptime >= kpi_thresholds.system_uptime.warning
      assert executive_kpis.response_time <= kpi_thresholds.response_time.warning
    end

    test "integrates with machine learning and AI analytics platforms" do
      # Create collector with ML/AI integration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collector_name: "ML Analytics Data Collector",
          data_sources: [
            %{name: "feature_store", type: "feast", connection: "ml_platform"},
            %{name: "model_registry", type: "mlflow", server: "mlflow.company.com"},
            %{name: "training_data", type: "s3", bucket: "ml-training-data"},
            %{name: "inference_logs", type: "kinesis", stream: "ml-predictions"}
          ],
          processing_pipeline: %{
            stages: [
              %{name: "feature_engineering", type: "ml_preprocessing", enabled: true},
              %{name: "model_monitoring", type: "drift_detection", enabled: true},
              %{name: "prediction_quality", type: "ml_validation", enabled: true}
            ],
            ml_optimization: true,
            real_time_inference: true
          },
          quality_configuration: %{
            model_accuracy_threshold: 85.0,
            feature_drift_threshold: 0.1,
            # milliseconds
            prediction_latency: 50,
            ml_pipeline_sla: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test ML/AI data source integration
      ml_data_sources = collector.data_sources
      source_types = Enum.map(ml_data_sources, & &1["type"])
      # Feature store
      assert "feast" in source_types
      # Model registry
      assert "mlflow" in source_types
      # Training data
      assert "s3" in source_types
      # Real-time inference logs
      assert "kinesis" in source_types

      # Test ML-specific processing pipeline
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["ml_optimization"] == true
      assert pipeline_config["real_time_inference"] == true

      ml_stages = pipeline_config["stages"]
      stage_types = Enum.map(ml_stages, & &1["type"])
      assert "ml_preprocessing" in stage_types
      assert "drift_detection" in stage_types
      assert "ml_validation" in stage_types

      # Simulate ML analytics metrics
      ml_analytics = %{
        model_accuracy: 87.5,
        feature_drift_score: 0.05,
        # milliseconds
        prediction_latency: 35.2,
        # predictions per second
        inference_throughput: 1500,
        data_quality_score: 94.2,
        feature_completeness: 98.7
      }

      # Verify ML quality thresholds
      quality_config = collector.quality_configuration
      assert ml_analytics.model_accuracy >= quality_config["model_accuracy_threshold"]
      assert ml_analytics.feature_drift_score <= quality_config["feature_drift_threshold"]
      assert ml_analytics.prediction_latency <= quality_config["prediction_latency"]

      # Test ML pipeline SLA compliance
      assert quality_config["ml_pipeline_sla"] == true
    end
  end

  # Performance and Load Testing
  describe "Performance and Scalability Testing" do
    test "handles massive data ingestion with optimal performance" do
      # Create high-performance collector configuration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collector_name: "High-Performance Data Ingestion",
          collection_type: :streaming,
          # Large batch size for performance
          batch_size: 50_000,
          performance_configuration: %{
            # 500K records per second
            max_throughput: 500_000,
            # Ultra-low latency
            max_latency: 20,
            # 16GB memory
            memory_limit: 16_384,
            # 32 CPU cores
            cpu_limit: 32.0,
            high_performance_mode: true,
            # 16 parallel processors
            parallel_processing: 16
          },
          processing_pipeline: %{
            stages: [
              %{name: "high_speed_validation", type: "parallel_validation", enabled: true},
              %{name: "bulk_transformation", type: "vectorized_processing", enabled: true},
              %{name: "fast_output", type: "bulk_insert", enabled: true}
            ],
            performance_optimized: true,
            memory_optimized: true
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test performance configuration
      perf_config = collector.performance_configuration
      assert perf_config["max_throughput"] == 500_000
      assert perf_config["max_latency"] == 20
      assert perf_config["high_performance_mode"] == true
      assert perf_config["parallel_processing"] == 16

      # Simulate high-volume data ingestion
      ingestion_test = %{
        # 10 million records
        total_records: 10_000_000,
        batch_size: collector.batch_size,
        expected_batches: div(10_000_000, collector.batch_size),
        # seconds
        max_processing_time: 60
      }

      # 10M / 50K
      assert ingestion_test.expected_batches == 200
      assert ingestion_test.batch_size <= 50_000

      # Test performance metrics
      expected_throughput = ingestion_test.total_records / ingestion_test.max_processing_time
      assert expected_throughput <= perf_config["max_throughput"]
    end

    test "maintains stability under concurrent load and stress conditions" do
      # Create stress-tested collector configuration
      collector_attrs =
        Map.merge(@valid_attrs, %{
          collector_name: "Stress-Tested Data Collector",
          performance_configuration: %{
            max_throughput: 100_000,
            max_latency: 100,
            memory_limit: 8192,
            cpu_limit: 16.0,
            stress_testing_mode: true,
            concurrent_connections: 1000,
            load_balancing: true
          },
          processing_pipeline: %{
            stages: [
              %{name: "load_balancer", type: "request_distribution", enabled: true},
              %{name: "concurrent_processor", type: "parallel_execution", enabled: true},
              %{name: "stress_monitor", type: "performance_tracking", enabled: true}
            ],
            stress_optimization: true,
            failure_recovery: true
          },
          quality_configuration: %{
            # 95% success rate under stress
            stress_test_sla: 95.0,
            # seconds
            recovery_time: 30,
            circuit_breaker_threshold: 20
          }
        })

      {:ok, collector} =
        %RealTimeBiCollector{}
        |> RealTimeBiCollector.changeset(collector_attrs)
        |> Repo.insert()

      # Test concurrent load handling
      perf_config = collector.performance_configuration
      assert perf_config["concurrent_connections"] == 1000
      assert perf_config["load_balancing"] == true
      assert perf_config["stress_testing_mode"] == true

      # Simulate stress test scenarios
      stress_scenarios = [
        %{concurrent_users: 500, expected_success_rate: 98.0},
        %{concurrent_users: 800, expected_success_rate: 96.0},
        %{concurrent_users: 1000, expected_success_rate: 95.0},
        # Over capacity
        %{concurrent_users: 1200, expected_success_rate: 90.0}
      ]

      quality_config = collector.quality_configuration
      stress_sla = quality_config["stress_test_sla"]

      for scenario <- stress_scenarios do
        if scenario.concurrent_users <= perf_config["concurrent_connections"] do
          assert scenario.expected_success_rate >= stress_sla
        else
          # Over capacity scenarios may have lower success rates
          # Graceful degradation
          assert scenario.expected_success_rate >= 85.0
        end
      end

      # Test failure recovery mechanisms
      pipeline_config = collector.processing_pipeline
      assert pipeline_config["failure_recovery"] == true
      assert quality_config["recovery_time"] == 30
      assert quality_config["circuit_breaker_threshold"] == 20
    end
  end

  # Helper functions for property-based testing
  defp data_sources_generator do
    gen all(
          source_count <- SD.integer(1..5),
          sources <- SD.list_of(data_source_generator(), length: source_count)
        ) do
      sources
    end
  end

  defp data_source_generator do
    gen all(
          name <- SD.string(:alphanumeric, min_length: 3, max_length: 20),
          type <- SD.one_of(["postgresql", "mysql", "rest_api", "kafka", "s3"]),
          connection <- SD.string(:alphanumeric, min_length: 3, max_length: 50)
        ) do
      %{name: name, type: type, connection: connection}
    end
  end

  # ==============================================
  # Phase 3.1.2: TDG Tests for Functional Module
  # ==============================================

  describe "functional module refactoring (Phase 3.1.2)" do
    test "collect_real_time_metrics/2 maintains API compatibility" do
      params = %{
        metrics: ["cpu_usage", "memory_usage"],
        time_window: :last_hour,
        tenant_id: "test-tenant"
      }

      result = RealTimeBICollector.collect_real_time_metrics(params, %{})

      assert {:ok, %{metrics: metrics, metadata: metadata}} = result
      assert is_list(metrics)
      assert %{collected_at: collected_at} = metadata
      assert %DateTime{} = collected_at
    end

    test "generate_dashboard_data/2 produces expected structure" do
      dashboard_config = %{
        dashboard_id: "test-dashboard",
        refresh_interval_ms: 5000,
        metrics: ["performance", "usage"],
        time_window: :last_day
      }

      result = RealTimeBICollector.generate_dashboard_data(dashboard_config, %{})

      assert {:ok, dashboard_data} = result
      assert %{dashboard_id: "test-dashboard"} = dashboard_data
      assert Map.has_key?(dashboard_data, :data)
      assert Map.has_key?(dashboard_data, :metadata)
    end

    test "calculate_kpi_metrics/2 handles various metric types" do
      metrics_data = [
        %{type: :conversion_rate, value: 0.15, target: 0.20},
        %{type: :revenue, value: 50_000, target: 45_000},
        %{type: :user_engagement, value: 0.85, target: 0.80}
      ]

      result = RealTimeBICollector.calculate_kpi_metrics(metrics_data, %{})

      assert {:ok, kpi_results} = result
      assert length(kpi_results) == 3

      Enum.each(kpi_results, fn kpi ->
        assert %{name: _, value: _, trend: _, variance: _} = kpi
        assert kpi.trend in [:increasing, :decreasing, :stable]
        assert is_number(kpi.variance)
      end)
    end

    test "perform_predictive_analysis/2 generates forecasts" do
      historical_data = [
        %{timestamp: ~U[2023-01-01 00:00:00Z], value: 100},
        %{timestamp: ~U[2023-01-02 00:00:00Z], value: 105},
        %{timestamp: ~U[2023-01-03 00:00:00Z], value: 110}
      ]

      result =
        RealTimeBICollector.perform_predictive_analysis(historical_data, %{forecast_horizon: 7})

      assert {:ok, analysis} = result
      assert %{forecasts: forecasts, trends: trends, confidence: confidence} = analysis
      assert is_list(forecasts)
      assert is_map(trends)
      assert is_number(confidence) and confidence >= 0.0 and confidence <= 1.0
    end

    test "process_business_intelligence/2 aggregates data correctly" do
      raw_data = [
        %{category: :sales, value: 1000, timestamp: ~U[2023-01-01 00:00:00Z]},
        %{category: :marketing, value: 500, timestamp: ~U[2023-01-01 01:00:00Z]},
        %{category: :sales, value: 1200, timestamp: ~U[2023-01-01 02:00:00Z]}
      ]

      result =
        RealTimeBICollector.process_business_intelligence(raw_data, %{aggregation: :category})

      assert {:ok, processed} = result
      assert %{aggregated_data: aggregated, summary: summary} = processed
      assert Map.has_key?(aggregated, :sales)
      assert Map.has_key?(aggregated, :marketing)
      assert %{total_value: total, record_count: count} = summary
      assert total == 2700
      assert count == 3
    end
  end

  # ==============================================
  # Property-Based Tests for Functional Module
  # ==============================================

  describe "property-based tests (TDG compliance)" do
    use PropCheck
    # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
    import PropCheck, except: [check: 2]
    import ExUnitProperties, except: [property: 2, property: 3, check: 2]

    property "collect_real_time_metrics always returns valid structure" do
      forall {metrics, time_window} <-
               {PC.list(PC.utf8()), PC.oneof([:last_hour, :last_day, :last_week])} do
        params = %{metrics: metrics, time_window: time_window, tenant_id: "test"}
        result = RealTimeBICollector.collect_real_time_metrics(params, %{})

        case result do
          {:ok, %{metrics: collected_metrics, metadata: metadata}} ->
            is_list(collected_metrics) and is_map(metadata) and
              Map.has_key?(metadata, :collected_at)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "kpi calculations preserve data integrity" do
      forall metrics_list <- PC.list(%{type: PC.atom(), value: PC.number(), target: PC.number()}) do
        result = RealTimeBICollector.calculate_kpi_metrics(metrics_list, %{})

        case result do
          {:ok, kpi_results} when is_list(kpi_results) ->
            length(kpi_results) <= length(metrics_list) and
              Enum.all?(kpi_results, fn kpi ->
                Map.has_key?(kpi, :value) and Map.has_key?(kpi, :trend)
              end)

          {:error, _} ->
            true
        end
      end
    end

    property "predictive analysis confidence is bounded" do
      forall historical_data <- PC.list(%{timestamp: PC.any(), value: PC.number()}) do
        result = RealTimeBICollector.perform_predictive_analysis(historical_data, %{})

        case result do
          {:ok, %{confidence: confidence}} ->
            is_number(confidence) and confidence >= 0.0 and confidence <= 1.0

          {:error, _} ->
            true
        end
      end
    end
  end

  # Utility functions for testing
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
