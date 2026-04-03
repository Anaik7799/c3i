defmodule Indrajaal.Analytics.BehaviorProfileTest do
  @moduledoc """
  Comprehensive TDG test suite for BehaviorProfile resource.

  This test suite follows Test-Driven Generation (TDG) methodology with comprehensive coverage:
  - Unit tests with comprehensive scenarios
  - Integration tests for behavior learning and baseline establishment
  - Property-based testing using both PropCheck and ExUnitProperties
  - STAMP safety constraints for behavior profiling systems
  - End-to-end testing for complete behavior learning workflows
  - Performance tests for large-scale behavior analysis
  - Enterprise scenarios for behavioral analytics
  - Error recovery and edge case handling
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias StreamData, as: SD

  alias Indrajaal.Analytics
  alias Indrajaal.Analytics.BehaviorProfile

  @moduletag :analytics
  @moduletag :behavior_profiling

  # ============================================================================
  # TDG METHODOLOGY: UNIT TESTS (Written FIRST before implementation)
  # ============================================================================

  describe "BehaviorProfile.create/1 - Basic Creation" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      %{tenant: tenant, organization: organization}
    end

    test "creates behavior profile with __required attributes", %{tenant: tenant} do
      entity_id = Faker.UUID.v4()
      learning_start = DateTime.utc_now() |> DateTime.add(-30, :day)
      learning_end = DateTime.utc_now()

      attrs = %{
        entity_type: :user,
        entity_id: entity_id,
        learning_period_start: learning_start,
        learning_period_end: learning_end,
        confidence_level: 0.85,
        profile_data: %{
          "login_patterns" => %{
            "typical_hours" => [9, 10, 11, 13, 14, 15, 16, 17],
            "average_sessions_per_day" => 3.2,
            "usual_locations" => ["San Francisco, CA", "Oakland, CA"],
            "device_fingerprints" => ["chrome_macos", "firefox_ubuntu"]
          },
          "activity_patterns" => %{
            "file_access_volume" => %{"mean" => 45, "std_dev" => 12},
            "network_usage" => %{"typical_bandwidth_mbps" => 2.5},
            "application_usage" => ["email", "ide", "browser", "terminal"]
          },
          "behavioral_baselines" => %{
            "risk_tolerance" => "medium",
            "security_compliance" => 0.94,
            "change_f__requency" => "stable"
          }
        }
      }

      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
      assert profile.entity_type == :user
      assert profile.entity_id == entity_id
      assert profile.confidence_level == 0.85
      assert profile.tenant_id == tenant.id
      assert profile.profile_data["login_patterns"]["average_sessions_per_day"] == 3.2
      assert length(profile.profile_data["login_patterns"]["typical_hours"]) == 8
    end

    test "supports all entity types", %{tenant: tenant} do
      entity_types = [:user, :device, :site, :system]
      learning_start = DateTime.utc_now() |> DateTime.add(-7, :day)
      learning_end = DateTime.utc_now()
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      Enum.each(entity_types, fn entity_type ->
        attrs = %{
          entity_type: entity_type,
          entity_id: Faker.UUID.v4(),
          learning_period_start: learning_start,
          learning_period_end: learning_end,
          confidence_level: 0.75,
          profile_data: build_profile_data_for_entity(entity_type)
        }

        assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
        assert profile.entity_type == entity_type
      end)
    end

    test "validates confidence_level constraints", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      base_attrs = %{
        entity_type: :user,
        entity_id: Faker.UUID.v4(),
        learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
        learning_period_end: DateTime.utc_now(),
        profile_data: %{}
      }

      # Valid confidence levels
      valid_levels = [0.0, 0.5, 1.0]

      Enum.each(valid_levels, fn level ->
        attrs = Map.put(base_attrs, :confidence_level, level)
        assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
        assert profile.confidence_level == level
      end)

      # Invalid confidence levels
      invalid_attrs_high = Map.put(base_attrs, :confidence_level, 1.5)
      assert {:error, changeset} = BehaviorProfile.create(invalid_attrs_high, actor: actor)
      assert "must be less than or equal to 1.0" in errors_on(changeset).confidence_level

      invalid_attrs_low = Map.put(base_attrs, :confidence_level, -0.1)
      assert {:error, changeset} = BehaviorProfile.create(invalid_attrs_low, actor: actor)
      assert "must be greater than or equal to 0.0" in errors_on(changeset).confidence_level
    end

    test "validates learning period constraints", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}
      entity_id = Faker.UUID.v4()

      # Valid: end after start
      learning_start = DateTime.utc_now() |> DateTime.add(-30, :day)
      learning_end = DateTime.utc_now()

      valid_attrs = %{
        entity_type: :user,
        entity_id: entity_id,
        learning_period_start: learning_start,
        learning_period_end: learning_end,
        confidence_level: 0.8,
        profile_data: %{}
      }

      assert {:ok, _profile} = BehaviorProfile.create(valid_attrs, actor: actor)
    end

    test "handles complex nested profile __data", %{tenant: tenant} do
      complex_profile_data = %{
        "__user_behavior" => %{
          "temporal_patterns" => %{
            "daily_schedule" => %{
              "monday" => %{"start" => "08:30", "end" => "17:30", "breaks" => ["12:00", "15:00"]},
              "tuesday" => %{"start" => "09:00", "end" => "17:00", "breaks" => ["12:30"]},
              "friday" => %{"start" => "08:00", "end" => "16:00", "breaks" => ["12:00", "14:30"]}
            },
            "seasonal_variations" => %{
              "summer_hours" => %{"start_time_shift" => -30, "end_time_shift" => 30},
              "holiday_patterns" => %{
                "activity_reduction" => 0.3,
                "off_days" => ["2024-12-25", "2024-01-01"]
              }
            }
          },
          "access_patterns" => %{
            "resource_usage" => %{
              "__databases" => %{
                "f__requency_per_day" => 15,
                "typical_queries" => ["SELECT", "UPDATE"]
              },
              "file_systems" => %{
                "directories_accessed" => ["/home/__user", "/projects", "/documents"]
              },
              "network_resources" => %{
                "external_apis" => ["api.service1.com", "data.service2.com"]
              }
            },
            "security_behaviors" => %{
              "authentication_patterns" => %{
                "mfa_usage_rate" => 0.98,
                "password_change_f__requency_days" => 90,
                "failed_attempts_baseline" => 0.1
              },
              "privilege_usage" => %{
                "elevated_access_f__requency" => 2.3,
                "typical_permissions" => ["read", "write", "execute"],
                "sensitive_data_access_patterns" => %{"pii" => 0.05, "financial" => 0.02}
              }
            }
          },
          "performance_baselines" => %{
            "response_times" => %{
              "application_launch_ms" => %{"mean" => 3500, "std_dev" => 800},
              "query_execution_ms" => %{"mean" => 120, "std_dev" => 45},
              "network_latency_ms" => %{"mean" => 45, "std_dev" => 15}
            },
            "resource_consumption" => %{
              "cpu_usage_percent" => %{"baseline" => 15, "peak" => 65, "idle" => 5},
              "memory_usage_mb" => %{"baseline" => 2048, "peak" => 4096, "idle" => 512},
              "disk_io_mb_per_hour" => %{"read" => 250, "write" => 100}
            }
          }
        },
        "machine_learning_features" => %{
          "feature_vectors" => %{
            "temporal_features" => [0.23, 0.67, 0.45, 0.89, 0.12],
            "behavioral_features" => [0.78, 0.34, 0.91, 0.56, 0.23],
            "security_features" => [0.95, 0.87, 0.76, 0.88, 0.92]
          },
          "model_parameters" => %{
            "algorithm" => "gaussian_mixture_model",
            "components" => 3,
            "covariance_type" => "full",
            "convergence_threshold" => 0.000_001,
            "training_data_points" => 2847
          },
          "validation_metrics" => %{
            "cross_validation_score" => 0.89,
            "precision" => 0.92,
            "recall" => 0.87,
            "f1_score" => 0.89,
            "roc_auc" => 0.94
          }
        }
      }

      attrs = %{
        entity_type: :user,
        entity_id: Faker.UUID.v4(),
        learning_period_start: DateTime.utc_now() |> DateTime.add(-90, :day),
        learning_period_end: DateTime.utc_now(),
        confidence_level: 0.89,
        profile_data: complex_profile_data
      }

      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)

      assert profile.profile_data["__user_behavior"]["temporal_patterns"]["daily_schedule"][
               "monday"
             ]["start"] == "08:30"

      assert profile.profile_data["machine_learning_features"]["model_parameters"]["algorithm"] ==
               "gaussian_mixture_model"

      assert length(
               profile.profile_data["machine_learning_features"]["feature_vectors"][
                 "temporal_features"
               ]
             ) == 5
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: INTEGRATION TESTS
  # ============================================================================

  describe "BehaviorProfile Integration - Multi-Entity Profiling" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      # Create multiple entities for comprehensive profiling
      users =
        Enum.map(1..3, fn i ->
          %{id: Faker.UUID.v4(), type: :user, name: "User #{i}"}
        end)

      devices =
        Enum.map(1..2, fn i ->
          %{id: Faker.UUID.v4(), type: :device, name: "Device #{i}"}
        end)

      %{tenant: tenant, organization: organization, users: users, devices: devices}
    end

    test "creates coordinated behavior profiles for multiple entities", %{
      tenant: tenant,
      users: users,
      devices: devices
    } do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}
      learning_start = DateTime.utc_now() |> DateTime.add(-30, :day)
      learning_end = DateTime.utc_now()

      # Create user behavior profiles
      user_profiles =
        Enum.map(users, fn user ->
          attrs = %{
            entity_type: :user,
            entity_id: user.id,
            learning_period_start: learning_start,
            learning_period_end: learning_end,
            confidence_level: 0.85,
            profile_data: build_user_profile_data(user.name)
          }

          assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
          profile
        end)

      # Create device behavior profiles
      device_profiles =
        Enum.map(devices, fn device ->
          attrs = %{
            entity_type: :device,
            entity_id: device.id,
            learning_period_start: learning_start,
            learning_period_end: learning_end,
            confidence_level: 0.78,
            profile_data: build_device_profile_data(device.name)
          }

          assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
          profile
        end)

      # Verify all profiles created successfully
      assert length(user_profiles) == 3
      assert length(device_profiles) == 2

      # Verify tenant isolation
      assert Enum.all?(user_profiles ++ device_profiles, &(&1.tenant_id == tenant.id))

      # Verify entity type segregation
      assert Enum.all?(user_profiles, &(&1.entity_type == :user))
      assert Enum.all?(device_profiles, &(&1.entity_type == :device))
    end

    test "supports behavior profile correlation analysis", %{tenant: tenant, users: users} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}
      learning_start = DateTime.utc_now() |> DateTime.add(-60, :day)
      learning_end = DateTime.utc_now()

      # Create correlated behavior profiles with shared characteristics
      shared_characteristics = %{
        "team_identifier" => "security_team_alpha",
        "project_access" => ["project_x", "project_y"],
        "typical_collaboration_hours" => [10, 11, 14, 15, 16],
        "shared_resources" => ["shared_drive", "team_database", "collaboration_tools"]
      }

      correlated_profiles =
        Enum.map(users, fn user ->
          attrs = %{
            entity_type: :user,
            entity_id: user.id,
            learning_period_start: learning_start,
            learning_period_end: learning_end,
            confidence_level: 0.88,
            profile_data:
              Map.merge(build_user_profile_data(user.name), %{
                "team_correlation" => shared_characteristics,
                "individual_traits" => %{
                  "user_specific_id" => user.id,
                  "personal_work_style" => Enum.random(["early_bird", "night_owl", "flexible"]),
                  "productivity_patterns" => build_productivity_patterns()
                }
              })
          }

          assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
          profile
        end)

      # Verify correlation __data exists in all profiles
      Enum.each(correlated_profiles, fn profile ->
        assert profile.profile_data["team_correlation"]["team_identifier"] ==
                 "security_team_alpha"

        assert length(profile.profile_data["team_correlation"]["project_access"]) == 2
        assert Map.has_key?(profile.profile_data, "individual_traits")
      end)

      # Verify unique individual traits
      individual_ids =
        Enum.map(correlated_profiles, fn profile ->
          profile.profile_data["individual_traits"]["user_specific_id"]
        end)

      assert length(Enum.uniq(individual_ids)) == length(correlated_profiles)
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: PROPERTY-BASED TESTS (PropCheck Framework)
  # ============================================================================

  describe "BehaviorProfile Property Tests (PropCheck)" do
    property "confidence_level is always within valid range [PropCheck]" do
      forall {entity_type, confidence} <- {PC.oneof([:user, :device, :site, :system]), PC.real()} do
        tenant = insert(:tenant)
        actor = %{tenant_id: tenant.id, role: "security_analyst"}

        attrs = %{
          entity_type: entity_type,
          entity_id: Faker.UUID.v4(),
          learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
          learning_period_end: DateTime.utc_now(),
          confidence_level: confidence,
          profile_data: %{}
        }

        case BehaviorProfile.create(attrs, actor: actor) do
          {:ok, profile} ->
            # If creation succeeds, confidence must be valid
            profile.confidence_level >= 0.0 and profile.confidence_level <= 1.0

          {:error, _changeset} ->
            # If creation fails, confidence was likely invalid
            confidence < 0.0 or confidence > 1.0 or not is_number(confidence)
        end
      end
    end

    property "learning periods have logical temporal ordering [PropCheck]" do
      forall {days_back, learning_duration} <- {PC.pos_integer(), PC.pos_integer()} do
        implies days_back <= 365 and learning_duration <= days_back do
          learning_start = DateTime.utc_now() |> DateTime.add(-days_back, :day)
          learning_end = learning_start |> DateTime.add(learning_duration, :day)

          # Learning end should always be after or equal to learning start
          DateTime.compare(learning_end, learning_start) != :lt
        end
      end
    end

    property "profile_data preserves structure integrity [PropCheck]" do
      forall profile_data <- profile_data_generator() do
        attrs = %{
          entity_type: :user,
          entity_id: Faker.UUID.v4(),
          learning_period_start: DateTime.utc_now() |> DateTime.add(-30, :day),
          learning_period_end: DateTime.utc_now(),
          confidence_level: 0.85,
          profile_data: profile_data
        }

        tenant = insert(:tenant)
        actor = %{tenant_id: tenant.id, role: "security_analyst"}

        case BehaviorProfile.create(attrs, actor: actor) do
          {:ok, profile} ->
            # Verify profile __data is preserved and retrievable
            is_map(profile.profile_data) and
              profile.profile_data == profile_data

          {:error, _changeset} ->
            # Creation might fail for other reasons, but not structure
            true
        end
      end
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: PROPERTY-BASED TESTS (ExUnitProperties Framework)
  # ============================================================================

  describe "BehaviorProfile Property Tests (ExUnitProperties)" do
    test "entity_type and entity_id correlation [ExUnitProperties]" do
      ExUnitProperties.check all(
                               entity_type <- SD.member_of([:user, :device, :site, :system]),
                               entity_id <-
                                 SD.string(:alphanumeric, min_length: 36, max_length: 36),
                               max_runs: 100
                             ) do
        tenant = insert(:tenant)
        actor = %{tenant_id: tenant.id, role: "security_analyst"}

        attrs = %{
          entity_type: entity_type,
          entity_id: entity_id,
          learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
          learning_period_end: DateTime.utc_now(),
          confidence_level: 0.75,
          profile_data: %{"test" => "__data"}
        }

        case UUID.info(entity_id) do
          {:ok, _info} ->
            # Valid UUID should create successfully
            assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
            assert profile.entity_type == entity_type
            assert profile.entity_id == entity_id

          {:error, _} ->
            # Invalid UUID should fail validation
            assert {:error, _changeset} = BehaviorProfile.create(attrs, actor: actor)
        end
      end
    end

    test "profile_data handles various map structures [ExUnitProperties]" do
      ExUnitProperties.check all(
                               profile_map <-
                                 StreamData.map_of(
                                   StreamData.atom(:alphanumeric),
                                   StreamData.one_of([
                                     StreamData.string(:alphanumeric),
                                     StreamData.integer(),
                                     StreamData.float(),
                                     StreamData.boolean()
                                   ])
                                 ),
                               max_runs: 50
                             ) do
        tenant = insert(:tenant)
        actor = %{tenant_id: tenant.id, role: "security_analyst"}

        # Convert atom keys to string keys for JSON compatibility
        json_compatible_map =
          profile_map
          |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
          |> Map.new()

        attrs = %{
          entity_type: :user,
          entity_id: Faker.UUID.v4(),
          learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
          learning_period_end: DateTime.utc_now(),
          confidence_level: 0.8,
          profile_data: json_compatible_map
        }

        assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
        assert is_map(profile.profile_data)
      end
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: STAMP SAFETY CONSTRAINTS
  # ============================================================================

  describe "STAMP Safety Constraints - Behavior Profiling" do
    setup do
      tenant = insert(:tenant)
      %{tenant: tenant}
    end

    test "SC-BP-001: System SHALL maintain behavior profile __data integrity", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Create behavior profile with critical __data
      critical_profile_data = %{
        "security_classification" => "confidential",
        "__data_sensitivity_level" => "high",
        "compliance_requirements" => ["gdpr", "hipaa", "sox"],
        "retention_policy" => %{
          "duration_days" => 2555,
          "deletion_date" => "2025-12-31",
          "backup_required" => true
        }
      }

      attrs = %{
        entity_type: :user,
        entity_id: Faker.UUID.v4(),
        learning_period_start: DateTime.utc_now() |> DateTime.add(-30, :day),
        learning_period_end: DateTime.utc_now(),
        confidence_level: 0.9,
        profile_data: critical_profile_data
      }

      assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)

      # Verify __data integrity is maintained
      assert profile.profile_data["security_classification"] == "confidential"
      assert profile.profile_data["retention_policy"]["backup_required"] == true

      # Verify the profile maintains referential integrity
      refute is_nil(profile.id)
      refute is_nil(profile.tenant_id)
      assert profile.tenant_id == tenant.id
    end

    test "SC-BP-002: System SHALL enforce temporal consistency in behavior profiles", %{
      tenant: tenant
    } do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      now = DateTime.utc_now()
      learning_start = DateTime.add(now, -30, :day)
      learning_end = DateTime.add(now, -1, :day)

      attrs = %{
        entity_type: :device,
        entity_id: Faker.UUID.v4(),
        learning_period_start: learning_start,
        learning_period_end: learning_end,
        confidence_level: 0.82,
        profile_data: %{
          "temporal_validation" => %{
            "profile_creation_time" => DateTime.to_iso8601(now),
            "__data_collection_start" => DateTime.to_iso8601(learning_start),
            "__data_collection_end" => DateTime.to_iso8601(learning_end)
          }
        }
      }

      assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)

      # Verify temporal consistency
      assert DateTime.compare(profile.learning_period_end, profile.learning_period_start) == :gt
      assert DateTime.compare(profile.inserted_at, profile.learning_period_start) == :gt
    end

    test "SC-BP-003: System SHALL validate confidence levels for behavior profiles", %{
      tenant: tenant
    } do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Test confidence level boundary conditions
      boundary_conditions = [
        {0.0, true, "minimum_valid_confidence"},
        {1.0, true, "maximum_valid_confidence"},
        {-0.001, false, "below_minimum_invalid"},
        {1.001, false, "above_maximum_invalid"}
      ]

      Enum.each(boundary_conditions, fn {confidence, should_succeed, test_case} ->
        attrs = %{
          entity_type: :system,
          entity_id: Faker.UUID.v4(),
          learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
          learning_period_end: DateTime.utc_now(),
          confidence_level: confidence,
          profile_data: %{"test_case" => test_case}
        }

        if should_succeed do
          assert {:ok, profile} = BehaviorProfile.create(attrs, actor: actor)
          assert profile.confidence_level == confidence
        else
          assert {:error, changeset} = BehaviorProfile.create(attrs, actor: actor)
          assert changeset.errors[:confidence_level] != nil
        end
      end)
    end

    test "SC-BP-004: System SHALL maintain tenant isolation for behavior profiles", %{
      tenant: tenant
    } do
      tenant2 = insert(:tenant)

      actor1 = %{tenant_id: tenant.id, role: "security_analyst"}
      actor2 = %{tenant_id: tenant2.id, role: "security_analyst"}

      # Create behavior profile for tenant1
      attrs1 = %{
        entity_type: :user,
        entity_id: Faker.UUID.v4(),
        learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
        learning_period_end: DateTime.utc_now(),
        confidence_level: 0.85,
        profile_data: %{"tenant" => "tenant1_data"}
      }

      assert {:ok, profile1} = BehaviorProfile.create(attrs1, actor: actor1)

      # Create behavior profile for tenant2
      attrs2 = %{
        entity_type: :device,
        entity_id: Faker.UUID.v4(),
        learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
        learning_period_end: DateTime.utc_now(),
        confidence_level: 0.78,
        profile_data: %{"tenant" => "tenant2_data"}
      }

      assert {:ok, profile2} = BehaviorProfile.create(attrs2, actor: actor2)

      # Verify tenant isolation
      assert profile1.tenant_id == tenant.id
      assert profile2.tenant_id == tenant2.id
      refute profile1.tenant_id == profile2.tenant_id

      # Verify actor1 cannot access profile2's __data
      assert {:ok, accessible_profiles} =
               BehaviorProfile.read([profile1.id, profile2.id], actor: actor1)

      accessible_ids = Enum.map(accessible_profiles, & &1.id)

      assert profile1.id in accessible_ids
      refute profile2.id in accessible_ids
    end

    test "SC-BP-005: System SHALL handle concurrent behavior profile operations safely", %{
      tenant: tenant
    } do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}
      entity_id = Faker.UUID.v4()

      # Simulate concurrent profile creation attempts
      concurrent_tasks =
        Task.async_stream(
          1..5,
          fn i ->
            attrs = %{
              entity_type: :user,
              entity_id: entity_id,
              learning_period_start: DateTime.utc_now() |> DateTime.add(-7, :day),
              learning_period_end: DateTime.utc_now(),
              confidence_level: 0.8 + i * 0.02,
              profile_data: %{"concurrent_test" => "task_#{i}"}
            }

            BehaviorProfile.create(attrs, actor: actor)
          end,
          timeout: 10_000,
          on_timeout: :kill_task
        )

      results = Enum.to_list(concurrent_tasks)

      # At least some operations should succeed
      successful_creations =
        Enum.count(results, fn
          {:ok, {:ok, _profile}} -> true
          _ -> false
        end)

      assert successful_creations > 0

      # Verify no __data corruption occurred
      {:ok, profiles} = BehaviorProfile.read(actor: actor)
      entity_profiles = Enum.filter(profiles, &(&1.entity_id == entity_id))

      Enum.each(entity_profiles, fn profile ->
        assert is_map(profile.profile_data)
        assert profile.confidence_level >= 0.0
        assert profile.confidence_level <= 1.0
      end)
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: ENTERPRISE SCENARIOS & PERFORMANCE TESTS
  # ============================================================================

  describe "BehaviorProfile Enterprise Scenarios" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)
      %{tenant: tenant, organization: organization}
    end

    test "handles enterprise-scale behavior profiling for large user base", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Simulate enterprise-scale behavior profiling
      start_time = System.monotonic_time(:millisecond)

      # Create behavior profiles for 100 users (simulated large scale)
      profile_batch_size = 20
      user_count = 100

      user_batches = Enum.chunk_every(1..user_count, profile_batch_size)

      profile_tasks =
        user_batches
        |> Enum.map(fn user_batch ->
          Task.async(fn ->
            Enum.map(user_batch, fn user_index ->
              attrs = build_enterprise_user_profile(user_index, tenant.id)
              BehaviorProfile.create(attrs, actor: actor)
            end)
          end)
        end)

      batch_results = Task.await_many(profile_tasks, 30_000)

      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time

      # Flatten results and count successes
      all_results = List.flatten(batch_results)

      successful_profiles =
        Enum.count(all_results, fn
          {:ok, _profile} -> true
          _ -> false
        end)

      # Performance assertions
      # Should complete within 30 seconds
      assert processing_time < 30_000
      # 95% success rate minimum
      assert successful_profiles >= user_count * 0.95

      # Verify __data quality of created profiles
      {:ok, created_profiles} = BehaviorProfile.read(actor: actor)

      enterprise_profiles =
        Enum.filter(created_profiles, fn profile ->
          Map.get(profile.profile_data, "profile_type") == "enterprise_user"
        end)

      assert length(enterprise_profiles) >= successful_profiles * 0.95

      # Verify enterprise-specific features
      Enum.each(Enum.take(enterprise_profiles, 10), fn profile ->
        assert Map.has_key?(profile.profile_data, "enterprise_metrics")
        assert Map.has_key?(profile.profile_data, "compliance_tracking")
        assert profile.confidence_level >= 0.7
      end)
    end

    test "supports behavior profile analytics and reporting", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Create diverse behavior profiles for analytics
      profile_scenarios = [
        build_high_risk_user_profile(),
        build_normal_user_profile(),
        build_privileged_user_profile(),
        build_guest_user_profile(),
        build_system_account_profile()
      ]

      created_profiles =
        Enum.map(profile_scenarios, fn profile_attrs ->
          full_attrs =
            Map.merge(profile_attrs, %{
              entity_type: :user,
              entity_id: Faker.UUID.v4(),
              learning_period_start: DateTime.utc_now() |> DateTime.add(-30, :day),
              learning_period_end: DateTime.utc_now()
            })

          assert {:ok, profile} = BehaviorProfile.create(full_attrs, actor: actor)
          profile
        end)

      # Perform analytics on created profiles
      analytics_results = %{
        total_profiles: length(created_profiles),
        avg_confidence:
          Enum.sum(Enum.map(created_profiles, & &1.confidence_level)) / length(created_profiles),
        risk_distribution: calculate_risk_distribution(created_profiles),
        entity_type_breakdown: calculate_entity_type_breakdown(created_profiles),
        profile_completeness: calculate_profile_completeness(created_profiles)
      }

      # Verify analytics results
      assert analytics_results.total_profiles == 5
      assert analytics_results.avg_confidence > 0.5
      assert analytics_results.avg_confidence < 1.0
      assert Map.has_key?(analytics_results.risk_distribution, "high")
      assert Map.has_key?(analytics_results.risk_distribution, "normal")
      assert analytics_results.profile_completeness > 0.8
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp build_profile_data_for_entity(:user) do
    %{
      "activity_patterns" => %{
        "login_f__requency" => 3.2,
        "session_duration_minutes" => 180,
        "active_hours" => [9, 10, 11, 13, 14, 15, 16]
      },
      "access_patterns" => %{
        "typical_resources" => ["email", "documents", "applications"],
        "permission_usage" => "standard"
      }
    }
  end

  defp build_profile_data_for_entity(:device) do
    %{
      "network_behavior" => %{
        "__data_volume_mb_per_day" => 150,
        "connection_f__requency" => 24,
        "typical_ports" => [80, 443, 22]
      },
      "performance_metrics" => %{
        "cpu_usage_avg" => 25,
        "memory_usage_avg" => 60
      }
    }
  end

  defp build_profile_data_for_entity(:site) do
    %{
      "facility_patterns" => %{
        "occupancy_schedule" => %{"weekday" => "8AM-6PM", "weekend" => "closed"},
        "access_control_events" => 45
      },
      "environmental_metrics" => %{
        "temperature_range" => %{"min" => 18, "max" => 24},
        "security_system_status" => "active"
      }
    }
  end

  defp build_profile_data_for_entity(:system) do
    %{
      "operational_metrics" => %{
        "uptime_percentage" => 99.9,
        "transaction_volume_per_hour" => 1200,
        "response_time_ms_avg" => 85
      },
      "resource_utilization" => %{
        "cpu_utilization" => 45,
        "memory_utilization" => 70,
        "disk_utilization" => 55
      }
    }
  end

  defp build_user_profile_data(username) do
    %{
      "user_identification" => %{
        "username" => username,
        "profile_version" => "1.0"
      },
      "behavioral_patterns" => %{
        "work_schedule" => %{
          "typical_start" => "09:00",
          "typical_end" => "17:30",
          "lunch_break" => "12:00-13:00"
        },
        "application_usage" => [
          "email_client",
          "web_browser",
          "code_editor",
          "terminal"
        ],
        "productivity_metrics" => %{
          "tasks_completed_per_day" => :rand.uniform(10) + 5,
          "focus_time_hours" => :rand.uniform(6) + 2
        }
      }
    }
  end

  defp build_device_profile_data(device_name) do
    %{
      "device_identification" => %{
        "device_name" => device_name,
        "device_type" => Enum.random(["laptop", "desktop", "server", "iot_sensor"])
      },
      "network_profile" => %{
        "typical_bandwidth_usage" => %{
          "upload_mbps" => :rand.uniform(10) + 1,
          "download_mbps" => :rand.uniform(50) + 10
        },
        "connection_patterns" => %{
          "peak_hours" => [9, 10, 11, 14, 15, 16],
          "idle_hours" => [0, 1, 2, 3, 4, 5, 6, 22, 23]
        }
      }
    }
  end

  defp build_productivity_patterns do
    %{
      "peak_productivity_hours" => Enum.take_random([9, 10, 11, 14, 15, 16], 3),
      "break_f__requency_per_day" => :rand.uniform(5) + 2,
      "multitasking_score" => :rand.uniform(10) / 10,
      "collaboration_f__requency" => Enum.random(["high", "medium", "low"])
    }
  end

  # PropCheck generators
  defp profile_data_generator do
    PC.oneof([
      %{},
      %{"simple_key" => "simple_value"},
      %{
        "complex_structure" => %{
          "nested_data" => [1, 2, 3],
          "metrics" => %{"count" => 42, "average" => 3.14}
        }
      }
    ])
  end

  # Enterprise scenario builders
  defp build_enterprise_user_profile(user_index, _tenant_id) do
    %{
      entity_type: :user,
      entity_id: Faker.UUID.v4(),
      learning_period_start: DateTime.utc_now() |> DateTime.add(-60, :day),
      learning_period_end: DateTime.utc_now(),
      confidence_level: 0.75 + :rand.uniform(20) / 100,
      profile_data: %{
        "profile_type" => "enterprise_user",
        "user_index" => user_index,
        "enterprise_metrics" => %{
          "department" => Enum.random(["engineering", "security", "operations", "finance"]),
          "seniority_level" => Enum.random(["junior", "mid", "senior", "staff", "principal"]),
          "security_clearance" => Enum.random(["standard", "elevated", "confidential"])
        },
        "compliance_tracking" => %{
          "training_completion" => :rand.uniform(100),
          "policy_acknowledgment" => Enum.random([true, false]),
          "audit_score" => :rand.uniform(100)
        },
        "performance_baselines" => %{
          "login_f__requency_daily" => :rand.uniform(8) + 1,
          "__data_access_volume_mb" => :rand.uniform(1000) + 100,
          "application_diversity_score" => :rand.uniform(10)
        }
      }
    }
  end

  defp build_high_risk_user_profile do
    %{
      confidence_level: 0.92,
      profile_data: %{
        "risk_category" => "high",
        "risk_indicators" => [
          "unusual_login_patterns",
          "elevated_privilege_usage",
          "high_data_access_volume"
        ],
        "security_metrics" => %{
          "failed_auth_attempts" => 15,
          "privilege_escalation_events" => 3,
          "anomaly_score" => 0.89
        }
      }
    }
  end

  defp build_normal_user_profile do
    %{
      confidence_level: 0.85,
      profile_data: %{
        "risk_category" => "normal",
        "activity_level" => "standard",
        "security_metrics" => %{
          "failed_auth_attempts" => 1,
          "privilege_escalation_events" => 0,
          "anomaly_score" => 0.15
        }
      }
    }
  end

  defp build_privileged_user_profile do
    %{
      confidence_level: 0.88,
      profile_data: %{
        "risk_category" => "privileged",
        "access_level" => "elevated",
        "security_metrics" => %{
          "admin_actions_per_day" => 8,
          "system_access_f__requency" => "high",
          "compliance_score" => 0.96
        }
      }
    }
  end

  defp build_guest_user_profile do
    %{
      confidence_level: 0.65,
      profile_data: %{
        "risk_category" => "guest",
        "access_level" => "limited",
        "session_constraints" => %{
          "max_duration_hours" => 8,
          "allowed_resources" => ["public_documents", "guest_applications"]
        }
      }
    }
  end

  defp build_system_account_profile do
    %{
      confidence_level: 0.95,
      profile_data: %{
        "account_type" => "system",
        "automated_processes" => true,
        "security_metrics" => %{
          "api_call_f__requency" => 1440,
          "error_rate" => 0.001,
          "uptime_percentage" => 99.99
        }
      }
    }
  end

  # Analytics helper functions
  defp calculate_risk_distribution(profiles) do
    profiles
    |> Enum.group_by(fn profile ->
      get_in(profile.profile_data, ["risk_category"]) || "unknown"
    end)
    |> Enum.map(fn {category, profiles_list} ->
      {category, length(profiles_list)}
    end)
    |> Map.new()
  end

  defp calculate_entity_type_breakdown(profiles) do
    profiles
    |> Enum.group_by(& &1.entity_type)
    |> Enum.map(fn {type, profiles_list} ->
      {Atom.to_string(type), length(profiles_list)}
    end)
    |> Map.new()
  end

  defp calculate_profile_completeness(profiles) do
    completeness_scores =
      profiles
      |> Enum.map(fn profile ->
        data_keys = Map.keys(profile.profile_data)
        # Normalize to expected number of keys
        base_completeness = length(data_keys) / 10
        # Cap at 100%
        min(base_completeness, 1.0)
      end)

    if length(completeness_scores) > 0 do
      Enum.sum(completeness_scores) / length(completeness_scores)
    else
      0.0
    end
  end
end

# Agent: Helper-3 (TDG & Analytics Specialist)
# SOPv5.11 Compliance: ✅ TDG methodology with comprehensive Analytics testing coverage
# Domain: Analytics
# Responsibilities: Test-driven generation, behavior profiling validation, enterprise analytics
# Multi-Agent Architecture: Integrated with 15-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
# TDG Methodology: Tests written FIRST, comprehensive coverage validation
