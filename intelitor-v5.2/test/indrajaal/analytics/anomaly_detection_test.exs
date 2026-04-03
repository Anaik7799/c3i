defmodule Indrajaal.Analytics.AnomalyDetectionTest do
  @moduledoc """
  Comprehensive test suite for AnomalyDetection resource.
  Tests automated anomaly detection,
    classification, and investigation workflows.
  """

  use Indrajaal.DataCase, async: true

  alias Indrajaal.Analytics
  alias Indrajaal.Analytics.AnomalyDetection

  describe "AnomalyDetection.create / 1" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      %{tenant: tenant, organization: organization}
    end

    test "creates anomaly detection with required attributes",
         %{tenant: tenant} do
      entity_id = Faker.UUID.v4()

      attrs = %{
        anomaly_type: :behavioral,
        entity_type: :user,
        entity_id: entity_id,
        confidence_score: 0.85,
        description:
          "Unusual login pattern detected: multiple failed attempts followed by successful login from new location",
        anomaly_data: %{
          "failed_attempts" => 15,
          "success_after_failures" => true,
          "new_location" => "New York, NY",
          "usual_location" => "San Francisco, CA",
          "time_difference" => "3 hours unusual"
        },
        baseline_data: %{
          "average_daily_logins" => 3,
          "usual_hours" => "9AM - 5PM PST",
          "typical_locations" => ["San Francisco, CA", "Oakland, CA"],
          "average_failures_per_week" => 1
        }
      }

      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
      assert detection.anomaly_type == :behavioral
      assert detection.entity_type == :user
      assert detection.entity_id == entity_id
      assert detection.confidence_score == 0.85
      # Default
      assert detection.severity == :medium
      # Default
      assert detection.status == :new
      assert detection.tenant_id == tenant.id
      assert detection.anomaly_data["failed_attempts"] == 15
      assert detection.baseline_data["average_daily_logins"] == 3
    end

    test "supports all anomaly types", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      anomaly_types = [:behavioral, :statistical, :temporal, :spatial, :network]

      Enum.each(anomaly_types, fn anomaly_type ->
        attrs = %{
          anomaly_type: anomaly_type,
          entity_type: :device,
          entity_id: Faker.UUID.v4(),
          confidence_score: 0.75,
          description: "Anomaly of type #{anomaly_type}"
        }

        assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
        assert detection.anomaly_type == anomaly_type
      end)
    end

    test "supports all entity types", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      entity_types = [:user, :device, :site, :system]

      Enum.each(entity_types, fn entity_type ->
        attrs = %{
          anomaly_type: :statistical,
          entity_type: entity_type,
          entity_id: Faker.UUID.v4(),
          confidence_score: 0.80,
          description: "Anomaly for #{entity_type} entity"
        }

        assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
        assert detection.entity_type == entity_type
      end)
    end

    test "supports all severity levels", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      severities = [:low, :medium, :high, :critical]

      Enum.each(severities, fn severity ->
        attrs = %{
          anomaly_type: :behavioral,
          entity_type: :user,
          entity_id: Faker.UUID.v4(),
          confidence_score: 0.90,
          description: "#{severity} severity anomaly",
          severity: severity
        }

        assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
        assert detection.severity == severity
      end)
    end

    test "validates confidence_score constraints", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Test minimum confidence (0.0)
      attrs_min = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: Faker.UUID.v4(),
        confidence_score: 0.0,
        description: "Minimum confidence anomaly"
      }

      assert {:ok, detection} = AnomalyDetection.create(attrs_min, actor: actor)
      assert detection.confidence_score == 0.0

      # Test maximum confidence (1.0)
      attrs_max = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: Faker.UUID.v4(),
        confidence_score: 1.0,
        description: "Maximum confidence anomaly"
      }

      assert {:ok, detection} = AnomalyDetection.create(attrs_max, actor: actor)
      assert detection.confidence_score == 1.0

      # Test invalid confidence (> 1.0)
      attrs_invalid_high = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: Faker.UUID.v4(),
        confidence_score: 1.5,
        description: "Invalid high confidence"
      }

      assert {:error, changeset} = AnomalyDetection.create(attrs_invalid_high, actor: actor)
      assert "must be less than or equal to 1.0" in errors_on(changeset).confidence_score

      # Test invalid confidence (< 0.0)
      attrs_invalid_low = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: Faker.UUID.v4(),
        confidence_score: -0.1,
        description: "Invalid low confidence"
      }

      assert {:error, changeset} = AnomalyDetection.create(attrs_invalid_low, actor: actor)
      assert "must be greater than or equal to 0.0" in errors_on(changeset).confidence_score
    end

    test "handles complex anomaly and baseline data", %{tenant: tenant} do
      complex_anomaly_data = %{
        "detection_algorithm" => "isolation_forest",
        "anomaly_score" => 0.92,
        "features_analyzed" => [
          "login_frequency",
          "access_patterns",
          "geographic_location",
          "time_of_access",
          "data_volume"
        ],
        "deviations" => %{
          "login_frequency" => %{
            "expected" => 3.2,
            "actual" => 15.7,
            "std_deviations" => 4.8
          },
          "geographic_location" => %{
            "expected_countries" => ["US"],
            "actual_countries" => ["US", "RU", "CN"],
            "risk_countries" => ["RU", "CN"]
          },
          "time_patterns" => %{
            "usual_hours" => "09:00 - 17:00 PST",
            "anomalous_hours" => "02:00 - 04:00 PST",
            "weekend_activity" => true
          }
        },
        "correlated_events" => [
          "multiple_device_access",
          "privilege_escalation_attempt",
          "unusual_data_download"
        ]
      }

      complex_baseline_data = %{
        "learning_period_days" => 90,
        "data_points_count" => 2847,
        "statistical_model" => "gaussian_mixture",
        "confidence_intervals" => %{
          "95_percent" => %{
            "login_frequency" => [1.5, 4.9],
            "session_duration" => [15, 180],
            "data_access_volume" => [50, 500]
          }
        },
        "seasonal_patterns" => %{
          "weekly" => %{
            "monday" => 4.2,
            "tuesday" => 4.1,
            "wednesday" => 3.9,
            "thursday" => 4.0,
            "friday" => 3.7,
            "saturday" => 0.8,
            "sunday" => 0.5
          },
          "hourly" => %{
            "peak_hours" => ["09:00", "11:00", "14:00", "16:00"],
            "low_activity" => ["00:00 - 06:00", "22:00 - 23:59"]
          }
        }
      }

      attrs = %{
        anomaly_type: :behavioral,
        entity_type: :user,
        entity_id: Faker.UUID.v4(),
        severity: :high,
        confidence_score: 0.92,
        description: "Complex multi - factor behavioral anomaly detected",
        anomaly_data: complex_anomaly_data,
        baseline_data: complex_baseline_data
      }

      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
      assert detection.anomaly_data["detection_algorithm"] == "isolation_forest"

      assert detection.anomaly_data["deviations"]["login_frequency"]["std_deviations"] ==
               4.8

      assert detection.baseline_data["learning_period_days"] == 90

      assert length(
               detection.baseline_data["seasonal_patterns"]["weekly"]
               |> Map.keys()
             ) == 7
    end
  end

  describe "AnomalyDetection status workflow" do
    setup do
      tenant = insert(:tenant)

      detection =
        insert(:anomaly_detection, %{
          tenant_id: tenant.id,
          status: :new
        })

      %{tenant: tenant, detection: detection}
    end

    test "investigates anomaly", %{tenant: tenant, detection: detection} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, investigating_detection} =
               AnomalyDetection.investigate(detection, actor: actor)

      assert investigating_detection.status == :investigating
    end

    test "confirms anomaly", %{tenant: tenant, detection: detection} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, confirmed_detection} = AnomalyDetection.confirm(detection, actor: actor)
      assert confirmed_detection.status == :confirmed
    end

    test "marks as false positive", %{tenant: tenant, detection: detection} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, fp_detection} = AnomalyDetection.mark_false_positive(detection, actor: actor)
      assert fp_detection.status == :false_positive
    end

    test "supports complete investigation workflow",
         %{tenant: tenant, detection: detection} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # New → Investigating → Confirmed
      assert detection.status == :new

      assert {:ok, investigating} = AnomalyDetection.investigate(detection, actor: actor)
      assert investigating.status == :investigating

      assert {:ok, confirmed} = AnomalyDetection.confirm(investigating, actor: actor)
      assert confirmed.status == :confirmed
    end

    test "supports false positive workflow",
         %{tenant: tenant, detection: detection} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # New → Investigating → False Positive
      assert {:ok, investigating} = AnomalyDetection.investigate(detection, actor: actor)

      assert {:ok, false_positive} =
               AnomalyDetection.mark_false_positive(investigating, actor: actor)

      assert false_positive.status == :false_positive
    end
  end

  describe "AnomalyDetection authorization and tenant isolation" do
    setup do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      detection1 = insert(:anomaly_detection, %{tenant_id: tenant1.id})
      detection2 = insert(:anomaly_detection, %{tenant_id: tenant2.id})

      %{
        tenant1: tenant1,
        tenant2: tenant2,
        detection1: detection1,
        detection2: detection2
      }
    end

    test "users can only access detections in their tenant", %{
      tenant1: tenant1,
      tenant2: tenant2,
      detection1: detection1,
      detection2: detection2
    } do
      actor1 = %{tenant_id: tenant1.id, role: "security_analyst"}
      actor2 = %{tenant_id: tenant2.id, role: "security_analyst"}

      # Actor1 can access detection1 but not detection2
      assert {:ok, [found_detection]} = AnomalyDetection.read([detection1.id], actor: actor1)
      assert found_detection.id == detection1.id

      assert {:ok, []} = AnomalyDetection.read([detection2.id], actor: actor1)

      # Actor2 can access detection2 but not detection1
      assert {:ok, [found_detection]} = AnomalyDetection.read([detection2.id], actor: actor2)
      assert found_detection.id == detection2.id

      assert {:ok, []} = AnomalyDetection.read([detection1.id], actor: actor2)
    end

    test "list queries respect tenant isolation",
         %{tenant1: tenant1, tenant2: tenant2} do
      actor1 = %{tenant_id: tenant1.id, role: "viewer"}
      actor2 = %{tenant_id: tenant2.id, role: "viewer"}

      assert {:ok, detections1} = AnomalyDetection.read(actor: actor1)
      assert {:ok, detections2} = AnomalyDetection.read(actor: actor2)

      assert Enum.all?(detections1, &(&1.tenant_id == tenant1.id))
      assert Enum.all?(detections2, &(&1.tenant_id == tenant2.id))

      # Should not overlap
      detection1_map = Enum.map(detections1, & &1.id)
      detection1_ids = detection1_map |> MapSet.new()
      detection2_map = Enum.map(detections2, & &1.id)
      detection2_ids = detection2_map |> MapSet.new()
      assert MapSet.disjoint?(detection1_ids, detection2_ids)
    end
  end

  describe "AnomalyDetection enterprise scenarios" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      %{tenant: tenant, organization: organization}
    end

    test "handles behavioral anomaly detection for user activity",
         %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      user_id = Faker.UUID.v4()

      # Suspicious user behavior: Unusual access patterns
      behavioral_anomaly = %{
        anomaly_type: :behavioral,
        entity_type: :user,
        entity_id: user_id,
        severity: :high,
        confidence_score: 0.89,
        description:
          "User exhibiting suspicious behavior: accessing sensitive data outside normal hours from unusual location",
        anomaly_data: %{
          "detection_time" => DateTime.to_iso8601(DateTime.utc_now()),
          "triggers" => [
            "out_of_hours_access",
            "unusual_geographic_location",
            "sensitive_data_access",
            "rapid_successive_logins",
            "privilege_escalation_attempt"
          ],
          "access_details" => %{
            "time" => "03:24 AM",
            "usual_hours" => "9 AM - 5 PM",
            "location" => "Moscow, Russia",
            "usual_locations" => ["San Francisco, CA", "New York, NY"],
            "ip_address" => "185.220.101.42",
            "device_fingerprint" => "unknown_device_linux"
          },
          "data_accessed" => [
            "customer_database",
            "financial_records",
            "employee_personal_info",
            "security_configurations"
          ],
          "volume_metrics" => %{
            "files_accessed" => 247,
            "usual_daily_average" => 15,
            "data_downloaded_mb" => 4500,
            "usual_daily_mb" => 50
          },
          "risk_indicators" => %{
            "tor_network_usage" => true,
            "vpn_usage" => true,
            "multiple_simultaneous_sessions" => 4,
            "failed_mfa_attempts" => 12
          }
        },
        baseline_data: %{
          "profile_established_date" => "2023 - 01 - 15",
          "learning_period_days" => 180,
          "normal_patterns" => %{
            "typical_login_times" => ["08:30", "09:15", "13:00", "17:30"],
            "average_session_duration_minutes" => 120,
            "common_access_resources" => [
              "email_system",
              "project_management",
              "code_repository",
              "development_tools"
            ],
            "geographic_baseline" => %{
              "primary_location" => "San Francisco, CA",
              "secondary_locations" => ["New York, NY", "Los Angeles, CA"],
              "travel_patterns" => "minimal_business_travel"
            }
          },
          "statistical_thresholds" => %{
            "login_frequency_daily" => %{"mean" => 3.2, "std_dev" => 1.1},
            "session_duration" => %{"mean" => 120, "std_dev" => 45},
            "file_access_count" => %{"mean" => 15, "std_dev" => 8}
          }
        }
      }

      assert {:ok, detection} = AnomalyDetection.create(behavioral_anomaly, actor: actor)
      assert detection.severity == :high
      assert detection.confidence_score == 0.89
      assert detection.anomaly_data["triggers"] |> length() == 5
      assert detection.anomaly_data["volume_metrics"]["files_accessed"] == 247
      assert detection.baseline_data["learning_period_days"] == 180

      # Investigate the anomaly
      assert {:ok, investigating} = AnomalyDetection.investigate(detection, actor: actor)
      assert investigating.status == :investigating

      # Confirm as genuine threat
      assert {:ok, confirmed} = AnomalyDetection.confirm(investigating, actor: actor)
      assert confirmed.status == :confirmed
    end

    test "handles network anomaly detection for device behavior",
         %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "network_analyst"}

      device_id = Faker.UUID.v4()

      # Network - based anomaly: Unusual traffic patterns
      network_anomaly = %{
        anomaly_type: :network,
        entity_type: :device,
        entity_id: device_id,
        severity: :critical,
        confidence_score: 0.94,
        description: "IoT device exhibiting botnet - like network behavior
          with command
      and control communication",
        anomaly_data: %{
          "detection_algorithm" => "deep_packet_inspection",
          "network_signatures" => [
            "c2_communication_pattern",
            "dns_tunneling",
            "unusual_port_usage",
            "encrypted_payload_anomalies",
            "timing_attack_patterns"
          ],
          "traffic_analysis" => %{
            "outbound_connections" => 1547,
            "baseline_daily_connections" => 23,
            "suspicious_domains" => [
              "malicious - c2 - server.tk",
              "bot - controller.suspicious.com",
              "encrypted - tunnel.darkweb.onion"
            ],
            "port_usage" => %{
              "unusual_ports" => [8080, 9050, 4444, 31_337],
              "normal_ports" => [80, 443, 22],
              "port_scanning_detected" => true
            },
            "data_exfiltration" => %{
              "uploaded_mb" => 2400,
              "baseline_daily_upload_mb" => 5,
              "encrypted_ratio" => 0.98,
              "compression_indicators" => true
            }
          },
          "temporal_patterns" => %{
            "communication_intervals" => "every_3_minutes",
            "activity_burst_periods" => ["02:00 - 04:00", "14:00 - 16:00"],
            "persistence_indicators" => true
          },
          "threat_intelligence" => %{
            "ioc_matches" => [
              "known_botnet_ip",
              "malware_family_mirai",
              "cryptocurrency_mining_pool"
            ],
            "reputation_scores" => %{
              "destination_ips" => [0.1, 0.2, 0.0, 0.3],
              "domains" => [0.0, 0.1, 0.0]
            }
          }
        },
        baseline_data: %{
          "device_profile" => %{
            "type" => "smart_camera",
            "manufacturer" => "SecureCam Inc",
            "model" => "SC - 4000",
            "firmware_version" => "2.1.4",
            "deployment_date" => "2023 - 03 - 20"
          },
          "normal_behavior" => %{
            "daily_connections" => 23,
            "common_destinations" => [
              "ntp_servers",
              "firmware_update_server",
              "video_storage_server"
            ],
            "typical_bandwidth_usage" => %{
              "upload_mbps" => 2.1,
              "download_mbps" => 0.3
            },
            "communication_schedule" => "business_hours_only"
          },
          "network_topology" => %{
            "vlan" => "iot_devices",
            "subnet" => "192.168.100.0 / 24",
            "access_controls" => ["no_internet_access", "monitoring_enabled"]
          }
        }
      }

      assert {:ok, detection} = AnomalyDetection.create(network_anomaly, actor: actor)
      assert detection.severity == :critical
      assert detection.confidence_score == 0.94

      assert detection.anomaly_data["traffic_analysis"]["outbound_connections"] ==
               1547

      assert detection.anomaly_data["threat_intelligence"]["ioc_matches"]
             |> length() == 3

      assert detection.baseline_data["device_profile"]["type"] == "smart_camera"

      # Immediate investigation due to critical severity
      assert {:ok, investigating} = AnomalyDetection.investigate(detection, actor: actor)

      # Confirm as compromise
      assert {:ok, confirmed} = AnomalyDetection.confirm(investigating, actor: actor)
      assert confirmed.status == :confirmed
    end

    test "handles statistical anomaly for system performance",
         %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "system_analyst"}

      system_id = Faker.UUID.v4()

      # Statistical anomaly: Performance degradation
      statistical_anomaly = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: system_id,
        severity: :medium,
        confidence_score: 0.76,
        description:
          "Database system showing statistical performance anomalies indicating potential degradation",
        anomaly_data: %{
          "metrics_analyzed" => [
            "query_response_time",
            "cpu_utilization",
            "memory_usage",
            "disk_io_operations",
            "network_throughput",
            "connection_pool_usage"
          ],
          "statistical_deviations" => %{
            "query_response_time" => %{
              "current_mean_ms" => 2400,
              "baseline_mean_ms" => 150,
              "z_score" => 8.2,
              "percentile_95" => 4500,
              "baseline_percentile_95" => 300
            },
            "cpu_utilization" => %{
              "current_avg_percent" => 87,
              "baseline_avg_percent" => 35,
              "spike_frequency" => "every_5_minutes",
              "sustained_high_duration" => "45_minutes"
            },
            "memory_usage" => %{
              "current_usage_gb" => 14.8,
              "baseline_usage_gb" => 8.2,
              "growth_rate_per_hour" => 0.3,
              "swap_usage_mb" => 2400
            }
          },
          "correlations_detected" => %{
            "cpu_memory_correlation" => 0.89,
            "query_time_cpu_correlation" => 0.94,
            "temporal_degradation_pattern" => "exponential_decline"
          },
          "root_cause_indicators" => [
            "inefficient_query_patterns",
            "memory_leak_suspected",
            "index_fragmentation",
            "lock_contention",
            "disk_space_pressure"
          ]
        },
        baseline_data: %{
          "measurement_period" => "30_days",
          "data_points" => 43_200,
          "statistical_model" => "time_series_arima",
          "seasonal_adjustments" => true,
          "normal_operating_ranges" => %{
            "query_response_time_ms" => %{"min" => 50, "max" => 300, "mean" => 150},
            "cpu_utilization_percent" => %{"min" => 20, "max" => 60, "mean" => 35},
            "memory_usage_gb" => %{"min" => 6, "max" => 12, "mean" => 8.2},
            "concurrent_connections" => %{"min" => 50, "max" => 200, "mean" => 120}
          },
          "performance_thresholds" => %{
            "warning_levels" => %{
              "query_response_time_ms" => 500,
              "cpu_utilization_percent" => 70,
              "memory_usage_percent" => 80
            },
            "critical_levels" => %{
              "query_response_time_ms" => 1000,
              "cpu_utilization_percent" => 90,
              "memory_usage_percent" => 95
            }
          }
        }
      }

      assert {:ok, detection} = AnomalyDetection.create(statistical_anomaly, actor: actor)
      assert detection.severity == :medium
      assert detection.confidence_score == 0.76

      assert detection.anomaly_data["statistical_deviations"]["query_response_time"]["z_score"] ==
               8.2

      assert detection.baseline_data["measurement_period"] == "30_days"

      # Start investigation to determine root cause
      assert {:ok, investigating} = AnomalyDetection.investigate(detection, actor: actor)
      assert investigating.status == :investigating
    end

    test "handles bulk anomaly detection processing", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Create multiple related anomalies for correlation analysis
      base_time = DateTime.utc_now()

      anomaly_scenarios = [
        # Coordinated attack across multiple users
        {
          :behavioral,
          :user,
          :high,
          0.91,
          "Suspicious credential stuffing pattern",
          %{"attack_type" => "credential_stuffing", "source_ips" => 12}
        },
        {
          :behavioral,
          :user,
          :high,
          0.87,
          "Mass login failures followed by successful breaches",
          %{"attack_type" => "credential_stuffing", "successful_breaches" => 3}
        },
        {
          :network,
          :device,
          :critical,
          0.95,
          "Lateral movement detected",
          %{"attack_type" => "lateral_movement", "compromised_systems" => 5}
        },
        {
          :temporal,
          :system,
          :medium,
          0.73,
          "Unusual activity during maintenance window",
          %{"attack_type" => "privilege_abuse", "maintenance_window" => true}
        },
        {
          :spatial,
          :device,
          :high,
          0.83,
          "Geographic anomaly in device locations",
          %{"attack_type" => "device_cloning", "impossible_travel" => true}
        }
      ]

      scenarios_with_index = Enum.with_index(anomaly_scenarios, 1)

      detections =
        scenarios_with_index
        |> Enum.map(fn {{anom_type, entity_type, severity, confidence, description, attack_data},
                        i} ->
          entity_id = Faker.UUID.v4()

          attrs = %{
            anomaly_type: anom_type,
            entity_type: entity_type,
            entity_id: entity_id,
            severity: severity,
            confidence_score: confidence,
            description: description,
            # 5 minutes apart
            detected_at: DateTime.add(base_time, i * 300, :second),
            anomaly_data:
              Map.merge(attack_data, %{
                "detection_sequence" => i,
                "campaign_correlation_id" => "CAMPAIGN - 2024 - 001",
                "analyst_priority" => if(severity == :critical, do: 1, else: i)
              }),
            baseline_data: %{
              "correlation_window_minutes" => 30,
              "related_detections" => i - 1,
              "threat_actor_profile" => "apt_group_candidate"
            }
          }

          assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)
          detection
        end)

      # Verify coordinated detection campaign
      assert length(detections) == 5
      assert Enum.all?(detections, &(&1.tenant_id == tenant.id))

      # Check attack correlation
      campaign_detections =
        Enum.filter(detections, fn d ->
          d.anomaly_data["campaign_correlation_id"] == "CAMPAIGN - 2024 - 001"
        end)

      assert length(campaign_detections) == 5

      # Verify severity distribution
      critical_count = Enum.count(detections, &(&1.severity == :critical))
      high_count = Enum.count(detections, &(&1.severity == :high))
      assert critical_count == 1
      assert high_count == 3

      # Process detections in priority order
      priority_detections =
        Enum.sort_by(detections, fn d ->
          d.anomaly_data["analyst_priority"]
        end)

      # Investigate highest priority first
      highest_priority = List.first(priority_detections)
      assert {:ok, investigating} = AnomalyDetection.investigate(highest_priority, actor: actor)
      assert investigating.severity == :critical
    end
  end

  describe "AnomalyDetection validation and constraints" do
    test "validates required fields and data integrity" do
      tenant = insert(:tenant)
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Test missing required fields
      incomplete_attrs = %{
        anomaly_type: :behavioral
        # Missing entity_type, entity_id, confidence_score, description
      }

      assert {:error, changeset} = AnomalyDetection.create(incomplete_attrs, actor: actor)

      errors = errors_on(changeset)
      assert "is required" in (errors[:entity_type] || [])
      assert "is required" in (errors[:entity_id] || [])
      assert "is required" in (errors[:confidence_score] || [])
      assert "is required" in (errors[:description] || [])
    end

    test "handles edge cases for timestamps and data structures" do
      tenant = insert(:tenant)
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Create detection with complex nested data
      complex_data = %{
        "nested_metrics" => %{
          "level_1" => %{
            "level_2" => %{
              "level_3" => %{
                "deep_value" => 42,
                "array_data" => [1, 2, 3, 4, 5],
                "mixed_array" => ["string", 123, true, nil]
              }
            }
          }
        },
        "large_array" => Enum.to_list(1..1000),
        "unicode_text" => "Detection with unicode: 日本語 العربية мати Español",
        "special_chars" => "!@#$%^&*()_+-=[]{}|;':\",./<>?"
      }

      attrs = %{
        anomaly_type: :statistical,
        entity_type: :system,
        entity_id: Faker.UUID.v4(),
        confidence_score: 0.85,
        description: "Complex data structure test",
        anomaly_data: complex_data,
        baseline_data: %{
          "empty_object" => %{},
          "empty_array" => [],
          "null_values" => %{"key1" => nil, "key2" => nil}
        }
      }

      assert {:ok, detection} = AnomalyDetection.create(attrs, actor: actor)

      assert detection.anomaly_data["nested_metrics"]["level_1"]["level_2"]["level_3"][
               "deep_value"
             ] == 42

      assert length(detection.anomaly_data["large_array"]) == 1000
      assert detection.anomaly_data["unicode_text"] |> String.contains?("日本語")
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
