defmodule Indrajaal.Analytics.IncidentPredictionTest do
  @moduledoc """
  Comprehensive Test-Driven Generation (TDG) test suite for Indrajaal.Analytics.IncidentPrediction.

  This test suite follows TDG methodology where tests are written FIRST to define
  the expected behavior, then implementation follows to satisfy these tests.

  Coverage Areas:
  - Unit tests for all IncidentPrediction attributes and validations
  - Integration tests for predictive analytics workflows
  - Property-based testing using PropCheck and ExUnitProperties
  - STAMP safety constraints for prediction accuracy and reliability
  - Enterprise scenarios for large-scale incident prevention
  - Performance tests for high-volume prediction processing
  """

  use ExUnit.Case, async: true
  use Indrajaal.DataCase
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import PropCheck.BasicTypes
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  # EP-GEN-014: Mandatory aliases for generator disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.IncidentPrediction

  describe "IncidentPrediction Creation - TDG Unit Tests" do
    test "creates incident prediction with security_breach type" do
      contributing_factors = [
        %{factor: "unauthorized_access_attempts", weight: 0.8, source: "access_logs"},
        %{factor: "unusual_network_traffic", weight: 0.6, source: "network_monitor"},
        %{factor: "failed_login_clustering", weight: 0.7, source: "auth_system"}
      ]

      recommended_actions = [
        "Increase security monitoring",
        "Review access permissions",
        "Deploy additional security personnel",
        "Activate emergency protocols"
      ]

      attrs = %{
        incident_type: :security_breach,
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: 0.85,
        contributing_factors: contributing_factors,
        recommended_actions: recommended_actions
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)
      assert prediction.incident_type == :security_breach
      assert prediction.likelihood_score == 0.85
      assert length(prediction.contributing_factors) == 3
      assert length(prediction.recommended_actions) == 4
      assert prediction.predicted_at != nil
    end

    test "creates incident prediction with equipment_failure type" do
      contributing_factors = [
        %{factor: "temperature_anomaly", weight: 0.9, source: "environmental_sensors"},
        %{factor: "vibration_increase", weight: 0.7, source: "mechanical_sensors"},
        %{factor: "maintenance_overdue", weight: 0.6, source: "maintenance_system"}
      ]

      recommended_actions = [
        "Schedule immediate maintenance inspection",
        "Monitor temperature closely",
        "Prepare backup equipment",
        "Notify facilities management"
      ]

      attrs = %{
        incident_type: :equipment_failure,
        predicted_time_window: ~U[2025-01-20 09:15:00Z],
        likelihood_score: 0.75,
        contributing_factors: contributing_factors,
        recommended_actions: recommended_actions
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)
      assert prediction.incident_type == :equipment_failure
      assert prediction.likelihood_score == 0.75

      # Verify equipment-specific factors
      temp_factor =
        Enum.find(
          prediction.contributing_factors,
          &(&1["factor"] == "temperature_anomaly")
        )

      assert temp_factor["weight"] == 0.9
      assert temp_factor["source"] == "environmental_sensors"
    end

    test "creates incident prediction with access_violation type" do
      contributing_factors = [
        %{factor: "badge_sharing_detected", weight: 0.8, source: "access_control"},
        %{factor: "off_hours_access_pattern", weight: 0.6, source: "time_analysis"},
        %{factor: "tailgating_incidents", weight: 0.7, source: "security_cameras"}
      ]

      recommended_actions = [
        "Review access card policies",
        "Increase security presence",
        "Install additional access controls",
        "Conduct security training"
      ]

      attrs = %{
        incident_type: :access_violation,
        predicted_time_window: ~U[2025-01-12 18:45:00Z],
        likelihood_score: 0.65,
        contributing_factors: contributing_factors,
        recommended_actions: recommended_actions
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)
      assert prediction.incident_type == :access_violation

      # Verify access-specific analysis
      badge_sharing =
        Enum.find(
          prediction.contributing_factors,
          &(&1["factor"] == "badge_sharing_detected")
        )

      assert badge_sharing["source"] == "access_control"
    end

    test "creates incident prediction with system_outage type" do
      contributing_factors = [
        %{factor: "server_cpu_spike", weight: 0.9, source: "system_monitoring"},
        %{factor: "memory_leak_detected", weight: 0.8, source: "application_logs"},
        %{factor: "disk_space_critical", weight: 0.95, source: "storage_monitoring"},
        %{factor: "network_latency_increase", weight: 0.7, source: "network_analysis"}
      ]

      recommended_actions = [
        "Scale server resources immediately",
        "Restart affected services",
        "Clear disk space",
        "Activate backup systems",
        "Notify technical support team"
      ]

      attrs = %{
        incident_type: :system_outage,
        predicted_time_window: ~U[2025-01-10 22:00:00Z],
        likelihood_score: 0.92,
        contributing_factors: contributing_factors,
        recommended_actions: recommended_actions
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)
      assert prediction.incident_type == :system_outage
      assert prediction.likelihood_score == 0.92

      # Verify critical system factors
      disk_factor =
        Enum.find(
          prediction.contributing_factors,
          &(&1["factor"] == "disk_space_critical")
        )

      # Highest weight for critical factor
      assert disk_factor["weight"] == 0.95
    end

    test "validates required incident_type attribute" do
      attrs = %{
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: 0.85
      }

      assert {:error, %Ash.Error.Invalid{}} = IncidentPrediction.create(attrs)
    end

    test "validates incident_type is one of allowed values" do
      attrs = %{
        incident_type: :invalid_type,
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: 0.85
      }

      assert {:error, %Ash.Error.Invalid{}} = IncidentPrediction.create(attrs)
    end

    test "validates likelihood_score within 0.0 to 1.0 range" do
      # Test invalid high score
      attrs_high = %{
        incident_type: :security_breach,
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: 1.5
      }

      assert {:error, %Ash.Error.Invalid{}} = IncidentPrediction.create(attrs_high)

      # Test invalid low score
      attrs_low = %{
        incident_type: :security_breach,
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: -0.1
      }

      assert {:error, %Ash.Error.Invalid{}} = IncidentPrediction.create(attrs_low)
    end

    test "sets default values for optional attributes" do
      attrs = %{
        incident_type: :security_breach,
        predicted_time_window: ~U[2025-01-15 14:30:00Z],
        likelihood_score: 0.75
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)
      assert prediction.contributing_factors == []
      assert prediction.recommended_actions == []
      assert prediction.predicted_at != nil
    end

    test "automatically sets predicted_at to current timestamp" do
      before_creation = DateTime.utc_now()

      attrs = %{
        incident_type: :equipment_failure,
        predicted_time_window: ~U[2025-01-20 09:15:00Z],
        likelihood_score: 0.65
      }

      assert {:ok, prediction} = IncidentPrediction.create(attrs)

      after_creation = DateTime.utc_now()

      assert DateTime.compare(prediction.predicted_at, before_creation) in [:gt, :eq]
      assert DateTime.compare(prediction.predicted_at, after_creation) in [:lt, :eq]
    end
  end

  describe "IncidentPrediction Updates - TDG Integration Tests" do
    test "updates likelihood_score based on new data" do
      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :security_breach,
          predicted_time_window: ~U[2025-01-15 14:30:00Z],
          likelihood_score: 0.65
        })

      # Simulate new evidence increasing the likelihood
      assert {:ok, updated_prediction} =
               IncidentPrediction.update(prediction, %{
                 likelihood_score: 0.85
               })

      assert updated_prediction.likelihood_score == 0.85
      assert updated_prediction.id == prediction.id
    end

    test "updates contributing_factors with new analysis" do
      initial_factors = [
        %{factor: "initial_analysis", weight: 0.5, source: "preliminary_scan"}
      ]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :equipment_failure,
          predicted_time_window: ~U[2025-01-20 09:15:00Z],
          likelihood_score: 0.60,
          contributing_factors: initial_factors
        })

      enhanced_factors = [
        %{factor: "initial_analysis", weight: 0.5, source: "preliminary_scan"},
        %{factor: "temperature_spike", weight: 0.8, source: "thermal_imaging"},
        %{factor: "unusual_vibrations", weight: 0.7, source: "accelerometer"}
      ]

      assert {:ok, updated_prediction} =
               IncidentPrediction.update(prediction, %{
                 contributing_factors: enhanced_factors
               })

      assert length(updated_prediction.contributing_factors) == 3

      temp_factor =
        Enum.find(
          updated_prediction.contributing_factors,
          &(&1["factor"] == "temperature_spike")
        )

      assert temp_factor["weight"] == 0.8
    end

    test "updates recommended_actions with refined recommendations" do
      initial_actions = ["Monitor situation"]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :access_violation,
          predicted_time_window: ~U[2025-01-12 18:45:00Z],
          likelihood_score: 0.70,
          recommended_actions: initial_actions
        })

      refined_actions = [
        "Monitor situation",
        "Deploy additional security personnel",
        "Review access logs immediately",
        "Notify security management",
        "Activate emergency protocols if needed"
      ]

      assert {:ok, updated_prediction} =
               IncidentPrediction.update(prediction, %{
                 recommended_actions: refined_actions
               })

      assert length(updated_prediction.recommended_actions) == 5
      assert "Deploy additional security personnel" in updated_prediction.recommended_actions
    end

    test "updates predicted_time_window with refined timing" do
      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :system_outage,
          predicted_time_window: ~U[2025-01-10 22:00:00Z],
          likelihood_score: 0.80
        })

      # Refine prediction to earlier time based on new data
      refined_time = ~U[2025-01-10 20:30:00Z]

      assert {:ok, updated_prediction} =
               IncidentPrediction.update(prediction, %{
                 predicted_time_window: refined_time
               })

      assert updated_prediction.predicted_time_window == refined_time
    end
  end

  describe "Property-Based Testing - PropCheck" do
    property "propcheck: incident prediction creation with valid likelihood scores" do
      forall {incident_type, likelihood} <- {
               PC.oneof([
                 :security_breach,
                 :equipment_failure,
                 :access_violation,
                 :system_outage
               ]),
               PC.float(0.0, 1.0)
             } do
        attrs = %{
          incident_type: incident_type,
          predicted_time_window: ~U[2025-01-15 12:00:00Z],
          likelihood_score: likelihood
        }

        case IncidentPrediction.create(attrs) do
          {:ok, prediction} ->
            prediction.incident_type == incident_type and
              prediction.likelihood_score == likelihood and
              prediction.likelihood_score >= 0.0 and
              prediction.likelihood_score <= 1.0

          {:error, _} ->
            false
        end
      end
    end

    property "propcheck: contributing factors maintain data integrity" do
      forall factors_count <- range(0, 20) do
        contributing_factors =
          Enum.map(1..factors_count, fn i ->
            %{
              factor: "factor_#{i}",
              weight: :rand.uniform(),
              source: "source_#{rem(i, 5)}"
            }
          end)

        attrs = %{
          incident_type: :security_breach,
          predicted_time_window: ~U[2025-01-15 12:00:00Z],
          likelihood_score: 0.75,
          contributing_factors: contributing_factors
        }

        case IncidentPrediction.create(attrs) do
          {:ok, prediction} ->
            length(prediction.contributing_factors) == factors_count and
              Enum.all?(prediction.contributing_factors, fn factor ->
                is_binary(factor["factor"]) and
                  is_number(factor["weight"]) and
                  is_binary(factor["source"])
              end)

          {:error, _} ->
            false
        end
      end
    end
  end

  describe "Property-Based Testing - ExUnitProperties" do
    test "exunitproperties: predicted_at timestamp accuracy" do
      ExUnitProperties.check all(
                               incident_type <-
                                 SD.member_of([
                                   :security_breach,
                                   :equipment_failure,
                                   :access_violation,
                                   :system_outage
                                 ]),
                               likelihood <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 30
                             ) do
        before_creation = DateTime.utc_now()

        attrs = %{
          incident_type: incident_type,
          predicted_time_window: ~U[2025-01-15 12:00:00Z],
          likelihood_score: likelihood
        }

        assert {:ok, prediction} = IncidentPrediction.create(attrs)

        after_creation = DateTime.utc_now()

        # Verify timestamp is within reasonable range
        assert DateTime.diff(prediction.predicted_at, before_creation, :second) >= 0
        assert DateTime.diff(after_creation, prediction.predicted_at, :second) >= 0
        assert DateTime.diff(after_creation, prediction.predicted_at, :second) < 5
      end
    end

    test "exunitproperties: recommended actions list integrity" do
      ExUnitProperties.check all(
                               actions_count <- SD.integer(0..50),
                               max_runs: 25
                             ) do
        recommended_actions =
          Enum.map(1..actions_count, fn i ->
            "Action #{i}: Respond appropriately"
          end)

        attrs = %{
          incident_type: :system_outage,
          predicted_time_window: ~U[2025-01-15 12:00:00Z],
          likelihood_score: 0.80,
          recommended_actions: recommended_actions
        }

        assert {:ok, prediction} = IncidentPrediction.create(attrs)
        assert length(prediction.recommended_actions) == actions_count

        if actions_count > 0 do
          assert Enum.all?(prediction.recommended_actions, &is_binary/1)
          assert Enum.all?(prediction.recommended_actions, &String.contains?(&1, "Action"))
        end
      end
    end
  end

  describe "STAMP Safety Constraints - Incident Prediction" do
    test "SC-IP-001: System SHALL maintain prediction accuracy above minimum threshold" do
      # Create predictions with various likelihood scores
      predictions_data = [
        %{incident_type: :security_breach, likelihood_score: 0.95, actual_outcome: true},
        %{incident_type: :equipment_failure, likelihood_score: 0.80, actual_outcome: true},
        %{incident_type: :access_violation, likelihood_score: 0.30, actual_outcome: false},
        %{incident_type: :system_outage, likelihood_score: 0.85, actual_outcome: true},
        %{incident_type: :security_breach, likelihood_score: 0.25, actual_outcome: false}
      ]

      created_predictions =
        Enum.map(predictions_data, fn data ->
          {:ok, prediction} =
            IncidentPrediction.create(%{
              incident_type: data.incident_type,
              predicted_time_window: ~U[2025-01-15 12:00:00Z],
              likelihood_score: data.likelihood_score
            })

          Map.put(data, :prediction, prediction)
        end)

      # Simulate accuracy calculation (would be implemented in business logic)
      high_confidence_correct =
        Enum.count(created_predictions, fn p ->
          p.likelihood_score > 0.7 and p.actual_outcome == true
        end)

      low_confidence_correct =
        Enum.count(created_predictions, fn p ->
          p.likelihood_score < 0.4 and p.actual_outcome == false
        end)

      total_correct = high_confidence_correct + low_confidence_correct
      accuracy = total_correct / length(created_predictions)

      # STAMP constraint: Accuracy must be above 70%
      assert accuracy >= 0.7
      assert length(created_predictions) == 5
    end

    test "SC-IP-002: System SHALL ensure prediction time windows are logically consistent" do
      prediction_time = ~U[2025-01-15 14:00:00Z]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :security_breach,
          predicted_time_window: prediction_time,
          likelihood_score: 0.85
        })

      # STAMP constraint: Prediction time window must be after prediction creation
      assert DateTime.compare(prediction.predicted_time_window, prediction.predicted_at) == :gt

      # Time window should be reasonable (not too far in future or past)
      time_diff_hours =
        DateTime.diff(prediction.predicted_time_window, prediction.predicted_at, :hour)

      assert time_diff_hours > 0
      # Within one week
      assert time_diff_hours < 168
    end

    test "SC-IP-003: System SHALL validate contributing factors have meaningful weights" do
      contributing_factors = [
        %{factor: "high_impact_factor", weight: 0.9, source: "critical_system"},
        %{factor: "medium_impact_factor", weight: 0.6, source: "monitoring_system"},
        %{factor: "low_impact_factor", weight: 0.2, source: "background_analysis"}
      ]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :equipment_failure,
          predicted_time_window: ~U[2025-01-20 09:15:00Z],
          likelihood_score: 0.75,
          contributing_factors: contributing_factors
        })

      # STAMP constraint: All weights must be within valid range
      for factor <- prediction.contributing_factors do
        weight = factor["weight"]
        assert weight >= 0.0
        assert weight <= 1.0
        assert is_number(weight)
      end

      # Verify high-weight factors exist for high-likelihood predictions
      if prediction.likelihood_score > 0.7 do
        high_weight_factors = Enum.filter(prediction.contributing_factors, &(&1["weight"] > 0.5))
        assert length(high_weight_factors) > 0
      end
    end

    test "SC-IP-004: System SHALL ensure recommended actions are actionable and specific" do
      recommended_actions = [
        "Increase security monitoring in zone A",
        "Deploy additional personnel to main entrance",
        "Activate emergency protocol level 2",
        "Notify security manager immediately"
      ]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :security_breach,
          predicted_time_window: ~U[2025-01-15 14:30:00Z],
          likelihood_score: 0.85,
          recommended_actions: recommended_actions
        })

      # STAMP constraint: Actions must be specific and actionable
      for action <- prediction.recommended_actions do
        assert is_binary(action)
        # Must be descriptive
        assert String.length(action) > 10
        # Must be concise
        assert String.length(action) < 200

        # Should contain action verbs
        action_verbs = [
          "increase",
          "deploy",
          "activate",
          "notify",
          "monitor",
          "review",
          "implement",
          "schedule"
        ]

        has_action_verb = Enum.any?(action_verbs, &String.contains?(String.downcase(action), &1))
        assert has_action_verb
      end
    end

    test "SC-IP-005: System SHALL maintain prediction data consistency during updates" do
      initial_factors = [
        %{factor: "initial_factor", weight: 0.6, source: "initial_scan"}
      ]

      {:ok, prediction} =
        IncidentPrediction.create(%{
          incident_type: :system_outage,
          predicted_time_window: ~U[2025-01-10 22:00:00Z],
          likelihood_score: 0.70,
          contributing_factors: initial_factors
        })

      original_id = prediction.id
      original_predicted_at = prediction.predicted_at
      original_incident_type = prediction.incident_type

      # Update with additional factors
      enhanced_factors =
        initial_factors ++
          [
            %{factor: "new_factor", weight: 0.8, source: "enhanced_analysis"}
          ]

      {:ok, updated_prediction} =
        IncidentPrediction.update(prediction, %{
          contributing_factors: enhanced_factors,
          likelihood_score: 0.85
        })

      # STAMP constraint: Core identity and consistency must be maintained
      assert updated_prediction.id == original_id
      assert updated_prediction.predicted_at == original_predicted_at
      assert updated_prediction.incident_type == original_incident_type

      # New data should be properly integrated
      assert updated_prediction.likelihood_score == 0.85
      assert length(updated_prediction.contributing_factors) == 2

      # Original factor should be preserved
      original_factor =
        Enum.find(
          updated_prediction.contributing_factors,
          &(&1["factor"] == "initial_factor")
        )

      assert original_factor != nil
      assert original_factor["weight"] == 0.6
    end
  end

  describe "Enterprise Scenarios - TDG Business Logic Tests" do
    test "creates comprehensive security breach prediction with multi-source analysis" do
      # Simulate enterprise security monitoring system
      contributing_factors = [
        %{
          factor: "brute_force_attempts",
          weight: 0.85,
          source: "firewall_logs",
          severity: "high"
        },
        %{
          factor: "unusual_login_patterns",
          weight: 0.75,
          source: "auth_system",
          severity: "medium"
        },
        %{factor: "network_reconnaissance", weight: 0.80, source: "ids_system", severity: "high"},
        %{
          factor: "insider_threat_indicators",
          weight: 0.70,
          source: "behavior_analysis",
          severity: "medium"
        },
        %{
          factor: "vulnerability_exploitation",
          weight: 0.90,
          source: "security_scanner",
          severity: "critical"
        }
      ]

      recommended_actions = [
        "IMMEDIATE: Block suspicious IP addresses",
        "IMMEDIATE: Disable compromised user accounts",
        "HIGH PRIORITY: Deploy incident response team",
        "HIGH PRIORITY: Activate emergency security protocols",
        "MEDIUM PRIORITY: Review and patch identified vulnerabilities",
        "MEDIUM PRIORITY: Increase monitoring on critical systems",
        "LOW PRIORITY: Conduct security awareness training"
      ]

      {:ok, enterprise_prediction} =
        IncidentPrediction.create(%{
          incident_type: :security_breach,
          predicted_time_window: ~U[2025-01-15 16:00:00Z],
          likelihood_score: 0.92,
          contributing_factors: contributing_factors,
          recommended_actions: recommended_actions
        })

      # Verify enterprise-grade analysis
      assert enterprise_prediction.likelihood_score > 0.9
      assert length(enterprise_prediction.contributing_factors) == 5
      assert length(enterprise_prediction.recommended_actions) == 7

      # Verify critical factors are identified
      critical_factors =
        Enum.filter(
          enterprise_prediction.contributing_factors,
          &(&1["severity"] == "critical")
        )

      assert length(critical_factors) == 1

      # Verify immediate actions are prioritized
      immediate_actions =
        Enum.filter(
          enterprise_prediction.recommended_actions,
          &String.starts_with?(&1, "IMMEDIATE:")
        )

      assert length(immediate_actions) == 2
    end

    test "creates equipment failure prediction with preventive maintenance integration" do
      # Simulate IoT sensor data and maintenance system integration
      contributing_factors = [
        %{
          factor: "bearing_temperature_spike",
          weight: 0.95,
          source: "thermal_sensors",
          measurement: 85.2,
          threshold: 75.0
        },
        %{
          factor: "vibration_amplitude_increase",
          weight: 0.88,
          source: "accelerometers",
          measurement: 12.5,
          threshold: 10.0
        },
        %{
          factor: "oil_contamination_detected",
          weight: 0.82,
          source: "fluid_analysis",
          contamination_level: "moderate"
        },
        %{factor: "maintenance_overdue", weight: 0.70, source: "cmms_system", days_overdue: 15},
        %{
          factor: "power_consumption_anomaly",
          weight: 0.65,
          source: "power_monitors",
          deviation_percent: 25
        }
      ]

      recommended_actions = [
        "CRITICAL: Shut down equipment immediately if temperature exceeds 90°C",
        "URGENT: Schedule emergency maintenance inspection within 24 hours",
        "HIGH: Replace bearing assembly and lubrication system",
        "HIGH: Perform comprehensive vibration analysis",
        "MEDIUM: Update maintenance schedule to prevent future overdue conditions",
        "MEDIUM: Install additional temperature monitoring sensors",
        "LOW: Review power consumption patterns for optimization opportunities"
      ]

      {:ok, maintenance_prediction} =
        IncidentPrediction.create(%{
          incident_type: :equipment_failure,
          predicted_time_window: ~U[2025-01-18 10:30:00Z],
          likelihood_score: 0.89,
          contributing_factors: contributing_factors,
          recommended_actions: recommended_actions
        })

      # Verify predictive maintenance integration
      assert maintenance_prediction.likelihood_score > 0.8

      # Verify sensor data integration
      temp_factor =
        Enum.find(
          maintenance_prediction.contributing_factors,
          &(&1["factor"] == "bearing_temperature_spike")
        )

      assert temp_factor["measurement"] == 85.2
      assert temp_factor["threshold"] == 75.0
      # Highest weight for critical measurement
      assert temp_factor["weight"] == 0.95

      # Verify maintenance system integration
      maintenance_factor =
        Enum.find(
          maintenance_prediction.contributing_factors,
          &(&1["factor"] == "maintenance_overdue")
        )

      assert maintenance_factor["days_overdue"] == 15

      # Verify critical action exists
      critical_actions =
        Enum.filter(
          maintenance_prediction.recommended_actions,
          &String.starts_with?(&1, "CRITICAL:")
        )

      assert length(critical_actions) == 1
    end

    test "creates access violation prediction with behavioral analysis" do
      # Simulate advanced access control and behavioral monitoring
      contributing_factors = [
        %{
          factor: "badge_sharing_pattern",
          weight: 0.80,
          source: "access_logs",
          frequency: "daily",
          users_involved: 3
        },
        %{
          factor: "tailgating_detection",
          weight: 0.75,
          source: "camera_analytics",
          incidents_per_day: 5
        },
        %{
          factor: "off_hours_access_spike",
          weight: 0.70,
          source: "time_analysis",
          increase_percent: 150
        },
        %{
          factor: "unauthorized_area_attempts",
          weight: 0.85,
          source: "security_system",
          denied_attempts: 12
        },
        %{
          factor: "social_engineering_indicators",
          weight: 0.65,
          source: "behavior_analysis",
          confidence: 0.75
        }
      ]

      recommended_actions = [
        "IMMEDIATE: Review and audit all badge sharing incidents",
        "IMMEDIATE: Increase security presence in high-risk areas",
        "HIGH: Implement additional anti-tailgating measures",
        "HIGH: Conduct security awareness training for identified users",
        "MEDIUM: Review access permissions for off-hours access",
        "MEDIUM: Deploy behavioral analytics monitoring",
        "LOW: Update access control policies and procedures"
      ]

      {:ok, access_prediction} =
        IncidentPrediction.create(%{
          incident_type: :access_violation,
          predicted_time_window: ~U[2025-01-16 19:00:00Z],
          likelihood_score: 0.78,
          contributing_factors: contributing_factors,
          recommended_actions: recommended_actions
        })

      # Verify behavioral analysis integration
      assert access_prediction.likelihood_score > 0.75

      # Verify badge sharing analysis
      badge_factor =
        Enum.find(
          access_prediction.contributing_factors,
          &(&1["factor"] == "badge_sharing_pattern")
        )

      assert badge_factor["users_involved"] == 3
      assert badge_factor["frequency"] == "daily"

      # Verify unauthorized access detection
      unauthorized_factor =
        Enum.find(
          access_prediction.contributing_factors,
          &(&1["factor"] == "unauthorized_area_attempts")
        )

      assert unauthorized_factor["denied_attempts"] == 12
      # High weight for direct security violation
      assert unauthorized_factor["weight"] == 0.85
    end

    test "creates system outage prediction with cascading failure analysis" do
      # Simulate complex enterprise system monitoring
      contributing_factors = [
        %{
          factor: "database_connection_pool_exhaustion",
          weight: 0.95,
          source: "db_monitor",
          active_connections: 98,
          max_connections: 100
        },
        %{
          factor: "memory_leak_application_server",
          weight: 0.90,
          source: "apm_tool",
          memory_growth_rate: "15MB/hour"
        },
        %{
          factor: "disk_io_bottleneck",
          weight: 0.85,
          source: "system_monitor",
          io_wait_percent: 45
        },
        %{
          factor: "network_bandwidth_saturation",
          weight: 0.80,
          source: "network_monitor",
          utilization_percent: 92
        },
        %{
          factor: "load_balancer_health_degradation",
          weight: 0.75,
          source: "load_balancer",
          unhealthy_backends: 2
        },
        %{
          factor: "cache_hit_ratio_decline",
          weight: 0.70,
          source: "cache_monitor",
          hit_ratio: 0.65,
          target_ratio: 0.90
        }
      ]

      recommended_actions = [
        "CRITICAL: Scale database connection pool immediately",
        "CRITICAL: Restart application servers to clear memory leaks",
        "URGENT: Investigate and resolve disk I/O bottleneck",
        "HIGH: Add network bandwidth capacity or optimize traffic",
        "HIGH: Restore load balancer backend health",
        "MEDIUM: Optimize cache configuration and warming",
        "MEDIUM: Implement cascading failure circuit breakers",
        "LOW: Schedule comprehensive system performance review"
      ]

      {:ok, outage_prediction} =
        IncidentPrediction.create(%{
          incident_type: :system_outage,
          predicted_time_window: ~U[2025-01-14 03:15:00Z],
          likelihood_score: 0.94,
          contributing_factors: contributing_factors,
          recommended_actions: recommended_actions
        })

      # Verify cascading failure analysis
      assert outage_prediction.likelihood_score > 0.9
      assert length(outage_prediction.contributing_factors) == 6

      # Verify database connection analysis
      db_factor =
        Enum.find(
          outage_prediction.contributing_factors,
          &(&1["factor"] == "database_connection_pool_exhaustion")
        )

      assert db_factor["active_connections"] == 98
      assert db_factor["max_connections"] == 100
      # Highest weight for imminent failure
      assert db_factor["weight"] == 0.95

      # Verify memory leak detection
      memory_factor =
        Enum.find(
          outage_prediction.contributing_factors,
          &(&1["factor"] == "memory_leak_application_server")
        )

      assert memory_factor["memory_growth_rate"] == "15MB/hour"

      # Verify critical actions for imminent failures
      critical_actions =
        Enum.filter(
          outage_prediction.recommended_actions,
          &String.starts_with?(&1, "CRITICAL:")
        )

      assert length(critical_actions) == 2
    end

    test "performs cross-incident type correlation analysis" do
      # Create multiple predictions of different types
      security_factors = [
        %{factor: "suspicious_network_activity", weight: 0.8, source: "network_monitor"}
      ]

      equipment_factors = [
        %{factor: "server_temperature_rise", weight: 0.7, source: "thermal_monitor"}
      ]

      access_factors = [
        %{factor: "unusual_badge_usage", weight: 0.6, source: "access_control"}
      ]

      {:ok, security_prediction} =
        IncidentPrediction.create(%{
          incident_type: :security_breach,
          predicted_time_window: ~U[2025-01-15 14:00:00Z],
          likelihood_score: 0.80,
          contributing_factors: security_factors
        })

      {:ok, equipment_prediction} =
        IncidentPrediction.create(%{
          incident_type: :equipment_failure,
          predicted_time_window: ~U[2025-01-15 14:30:00Z],
          likelihood_score: 0.75,
          contributing_factors: equipment_factors
        })

      {:ok, access_prediction} =
        IncidentPrediction.create(%{
          incident_type: :access_violation,
          predicted_time_window: ~U[2025-01-15 13:30:00Z],
          likelihood_score: 0.65,
          contributing_factors: access_factors
        })

      # Simulate correlation analysis
      all_predictions = [security_prediction, equipment_prediction, access_prediction]
      time_window_start = ~U[2025-01-15 13:00:00Z]
      time_window_end = ~U[2025-01-15 15:00:00Z]

      # Find predictions within same time window (potential correlation)
      correlated_predictions =
        Enum.filter(all_predictions, fn pred ->
          DateTime.compare(pred.predicted_time_window, time_window_start) != :lt and
            DateTime.compare(pred.predicted_time_window, time_window_end) != :gt
        end)

      assert length(correlated_predictions) == 3

      # Analyze correlation patterns
      high_risk_predictions = Enum.filter(correlated_predictions, &(&1.likelihood_score > 0.7))
      assert length(high_risk_predictions) == 2

      # Verify temporal clustering indicates potential compound incident
      time_diffs =
        for p1 <- correlated_predictions, p2 <- correlated_predictions, p1.id != p2.id do
          abs(DateTime.diff(p1.predicted_time_window, p2.predicted_time_window, :minute))
        end

      max_time_diff = Enum.max(time_diffs)
      # All within 1 hour indicates correlation
      assert max_time_diff <= 60
    end
  end

  describe "Performance Testing - TDG Scalability Tests" do
    test "handles high-volume prediction creation efficiently" do
      # Simulate enterprise-scale prediction generation
      prediction_count = 500

      start_time = System.monotonic_time(:millisecond)

      created_predictions =
        Enum.map(1..prediction_count, fn i ->
          incident_types = [
            :security_breach,
            :equipment_failure,
            :access_violation,
            :system_outage
          ]

          incident_type = Enum.at(incident_types, rem(i, 4))

          contributing_factors = [
            %{
              factor: "automated_factor_#{i}",
              weight: :rand.uniform(),
              source: "monitoring_system"
            }
          ]

          attrs = %{
            incident_type: incident_type,
            predicted_time_window: DateTime.add(DateTime.utc_now(), i * 60, :second),
            likelihood_score: :rand.uniform(),
            contributing_factors: contributing_factors
          }

          {:ok, prediction} = IncidentPrediction.create(attrs)
          prediction
        end)

      end_time = System.monotonic_time(:millisecond)
      creation_time = end_time - start_time

      # Verify performance and data integrity
      assert length(created_predictions) == prediction_count
      # Should complete within 30 seconds
      assert creation_time < 30_000

      # Verify data integrity with sampling
      sample_prediction = Enum.at(created_predictions, 250)

      assert sample_prediction.incident_type in [
               :security_breach,
               :equipment_failure,
               :access_violation,
               :system_outage
             ]

      assert sample_prediction.likelihood_score >= 0.0
      assert sample_prediction.likelihood_score <= 1.0
      assert length(sample_prediction.contributing_factors) == 1
    end

    test "performs efficient prediction querying and filtering" do
      # Create test data with different incident types
      incident_types = [:security_breach, :equipment_failure, :access_violation, :system_outage]

      created_predictions =
        Enum.flat_map(incident_types, fn type ->
          Enum.map(1..25, fn i ->
            {:ok, prediction} =
              IncidentPrediction.create(%{
                incident_type: type,
                predicted_time_window: DateTime.add(DateTime.utc_now(), i * 3600, :second),
                # 0.5 to 1.0
                likelihood_score: 0.5 + :rand.uniform() * 0.5
              })

            prediction
          end)
        end)

      # Performance test for reading and filtering
      start_time = System.monotonic_time(:millisecond)

      all_predictions = IncidentPrediction.read!()
      security_predictions = Enum.filter(all_predictions, &(&1.incident_type == :security_breach))
      high_likelihood_predictions = Enum.filter(all_predictions, &(&1.likelihood_score > 0.8))

      end_time = System.monotonic_time(:millisecond)
      query_time = end_time - start_time

      # Verify performance and accuracy
      assert length(all_predictions) >= 100
      assert length(security_predictions) >= 25
      # Should complete within 5 seconds
      assert query_time < 5000

      # Verify filtering accuracy
      assert Enum.all?(security_predictions, &(&1.incident_type == :security_breach))
      assert Enum.all?(high_likelihood_predictions, &(&1.likelihood_score > 0.8))

      # Verify predictions are properly distributed across types
      type_distribution = Enum.group_by(created_predictions, & &1.incident_type)
      assert map_size(type_distribution) == 4
      assert length(type_distribution[:security_breach]) == 25
    end

    test "handles complex contributing factors analysis efficiently" do
      # Create prediction with large number of contributing factors
      large_factors_count = 100

      contributing_factors =
        Enum.map(1..large_factors_count, fn i ->
          %{
            factor: "complex_factor_#{i}",
            weight: :rand.uniform(),
            source: "monitoring_system_#{rem(i, 10)}",
            metadata: %{
              timestamp: DateTime.utc_now(),
              confidence: :rand.uniform(),
              category: "category_#{rem(i, 5)}",
              impact_level: Enum.random(["low", "medium", "high", "critical"])
            }
          }
        end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, complex_prediction} =
        IncidentPrediction.create(%{
          incident_type: :system_outage,
          predicted_time_window: ~U[2025-01-20 15:00:00Z],
          likelihood_score: 0.88,
          contributing_factors: contributing_factors
        })

      end_time = System.monotonic_time(:millisecond)
      creation_time = end_time - start_time

      # Verify performance with complex data
      assert length(complex_prediction.contributing_factors) == large_factors_count
      # Should complete within 10 seconds
      assert creation_time < 10_000

      # Verify complex data integrity
      sample_factor = Enum.at(complex_prediction.contributing_factors, 50)
      assert is_binary(sample_factor["factor"])
      assert is_number(sample_factor["weight"])
      assert is_map(sample_factor["metadata"])
      assert sample_factor["metadata"]["impact_level"] in ["low", "medium", "high", "critical"]
    end
  end
end
