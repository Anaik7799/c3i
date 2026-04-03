defmodule Indrajaal.Video.AnalyticsTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Sites.Site
  alias Indrajaal.Video.{Analytics, Camera, Stream, Recording}

  describe "Analytics resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      camera = insert(:camera, tenant: tenant, site: site)
      stream = insert(:stream, tenant: tenant, camera: camera)

      {:ok,
       tenant: tenant, organization: organization, site: site, camera: camera, stream: stream}
    end

    test "creates analytics with valid attributes",
         %{tenant: tenant, camera: camera} do
      attrs = %{
        analytics_type: :motion_detection,
        timestamp: DateTime.utc_now(),
        confidence_score: 0.95,
        bounding_box: %{
          "x" => 100,
          "y" => 150,
          "width" => 200,
          "height" => 250
        },
        metadata: %{
          "object_type" => "person",
          "velocity" => 2.5,
          "direction" => "north",
          "size_category" => "adult"
        },
        camera_id: camera.id,
        tenant_id: tenant.id
      }

      {:ok, analytics} = Analytics.create(attrs)

      assert analytics.analytics_type == :motion_detection
      assert analytics.confidence_score == 0.95
      assert analytics.bounding_box["x"] == 100
      assert analytics.bounding_box["width"] == 200
      assert analytics.metadata["object_type"] == "person"
      assert analytics.metadata["velocity"] == 2.5
      assert analytics.camera_id == camera.id
      assert analytics.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Analytics.create(%{tenant_id: tenant.id})

      assert changeset.errors[:analytics_type]
      assert changeset.errors[:timestamp]
      assert changeset.errors[:confidence_score]
      assert changeset.errors[:camera_id]
    end

    test "validates analytics type", %{tenant: tenant, camera: camera} do
      valid_types = [
        :motion_detection,
        :object_detection,
        :face_detection,
        :license_plate_recognition,
        :crowd_detection,
        :intrusion_detection,
        :abandoned_object,
        :loitering_detection,
        :people_counting,
        :vehicle_counting
      ]

      for type <- valid_types do
        {:ok, _analytics} =
          Analytics.create(%{
            analytics_type: type,
            timestamp: DateTime.utc_now(),
            confidence_score: 0.8,
            camera_id: camera.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Analytics.create(%{
          analytics_type: :invalid_type,
          timestamp: DateTime.utc_now(),
          confidence_score: 0.8,
          camera_id: camera.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:analytics_type]
    end

    test "validates confidence score range",
         %{tenant: tenant, camera: camera} do
      # Valid confidence scores
      valid_scores = [0.0, 0.5, 0.99, 1.0]

      for score <- valid_scores do
        {:ok, _analytics} =
          Analytics.create(%{
            analytics_type: :motion_detection,
            timestamp: DateTime.utc_now(),
            confidence_score: score,
            camera_id: camera.id,
            tenant_id: tenant.id
          })
      end

      # Invalid confidence scores
      invalid_scores = [-0.1, 1.1, 2.0]

      for score <- invalid_scores do
        {:error, changeset} =
          Analytics.create(%{
            analytics_type: :motion_detection,
            timestamp: DateTime.utc_now(),
            confidence_score: score,
            camera_id: camera.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:confidence_score]
      end
    end

    test "detects motion events", %{tenant: tenant, camera: camera} do
      motion_data = %{
        motion_areas: [
          %{"zone" => "entrance", "intensity" => 0.8},
          %{"zone" => "corridor", "intensity" => 0.3}
        ],
        total_motion_percentage: 15.5,
        motion_vectors: [
          %{"from" => [100, 150], "to" => [120, 170], "magnitude" => 2.5}
        ]
      }

      {:ok, motion_analytics} =
        Analytics.detect_motion(camera, %{
          motion_data: motion_data,
          sensitivity_threshold: 0.5
        })

      assert motion_analytics.analytics_type == :motion_detection
      assert motion_analytics.metadata["motion_areas"]
      assert motion_analytics.metadata["total_motion_percentage"] == 15.5
      assert motion_analytics.confidence_score > 0.5
    end

    test "detects objects in video frames",
         %{tenant: tenant, camera: camera} do
      detection_results = [
        %{
          "object_type" => "person",
          "confidence" => 0.92,
          "bounding_box" => %{"x" => 100, "y" => 50, "width" => 80, "height" => 180},
          "attributes" => %{"gender" => "unknown", "age_group" => "adult"}
        },
        %{
          "object_type" => "vehicle",
          "confidence" => 0.88,
          "bounding_box" => %{"x" => 300, "y" => 200, "width" => 150, "height" => 100},
          "attributes" => %{"vehicle_type" => "car", "color" => "blue"}
        }
      ]

      {:ok, object_analytics} =
        Analytics.detect_objects(camera, %{
          detection_results: detection_results,
          frame_timestamp: DateTime.utc_now()
        })

      assert object_analytics.analytics_type == :object_detection
      assert length(object_analytics.metadata["detected_objects"]) == 2

      person =
        Enum.find(
          object_analytics.metadata["detected_objects"],
          &(&1["object_type"] == "person")
        )

      assert person["confidence"] == 0.92
      assert person["attributes"]["age_group"] == "adult"
    end

    test "recognizes faces", %{tenant: tenant, camera: camera} do
      face_data = %{
        face_id: "FACE_123456",
        known_person_id: "PERSON_789",
        match_confidence: 0.94,
        face_landmarks: %{
          "left_eye" => [120, 80],
          "right_eye" => [160, 82],
          "nose" => [140, 100],
          "mouth" => [140, 130]
        },
        face_attributes: %{
          "age_estimate" => 35,
          "gender_estimate" => "male",
          "emotion" => "neutral",
          "glasses" => false,
          "mask" => false
        }
      }

      {:ok, face_analytics} =
        Analytics.recognize_face(camera, %{
          face_data: face_data,
          recognition_database: "employees"
        })

      assert face_analytics.analytics_type == :face_detection
      assert face_analytics.confidence_score == 0.94
      assert face_analytics.metadata["face_id"] == "FACE_123456"
      assert face_analytics.metadata["known_person_id"] == "PERSON_789"
      assert face_analytics.metadata["face_attributes"]["age_estimate"] == 35
    end

    test "counts people in frame", %{tenant: tenant, camera: camera} do
      counting_data = %{
        total_count: 8,
        entering_count: 3,
        exiting_count: 1,
        net_change: 2,
        zones: [
          %{"zone_name" => "lobby", "count" => 5},
          %{"zone_name" => "hallway", "count" => 3}
        ],
        confidence_level: 0.89
      }

      {:ok, counting_analytics} =
        Analytics.count_people(camera, %{
          counting_data: counting_data,
          counting_method: "deep_learning"
        })

      assert counting_analytics.analytics_type == :people_counting
      assert counting_analytics.metadata["total_count"] == 8
      assert counting_analytics.metadata["entering_count"] == 3
      assert counting_analytics.metadata["net_change"] == 2
      assert counting_analytics.confidence_score == 0.89
    end

    test "detects intrusions", %{tenant: tenant, camera: camera} do
      intrusion_data = %{
        intrusion_zones: ["restricted_area_1", "perimeter_fence"],
        breach_points: [
          %{"zone" => "restricted_area_1", "coordinates" => [250, 300]},
          %{"zone" => "perimeter_fence", "coordinates" => [400, 150]}
        ],
        severity_level: "high",
        object_details: %{
          "object_type" => "person",
          "estimated_size" => "adult",
          "movement_pattern" => "deliberate"
        }
      }

      {:ok, intrusion_analytics} =
        Analytics.detect_intrusion(camera, %{
          intrusion_data: intrusion_data,
          alert_authorities: true
        })

      assert intrusion_analytics.analytics_type == :intrusion_detection
      assert intrusion_analytics.metadata["severity_level"] == "high"
      assert length(intrusion_analytics.metadata["breach_points"]) == 2
      assert intrusion_analytics.metadata["alert_authorities"] == true
    end

    test "analyzes crowd behavior", %{tenant: tenant, camera: camera} do
      crowd_data = %{
        crowd_density: "medium",
        estimated_count: 25,
        movement_pattern: "normal",
        anomaly_detected: false,
        density_hotspots: [
          %{"area" => "entrance", "density" => 0.7},
          %{"area" => "center", "density" => 0.4}
        ],
        flow_analysis: %{
          "primary_direction" => "north",
          "flow_rate" => 2.3,
          "congestion_level" => "low"
        }
      }

      {:ok, crowd_analytics} =
        Analytics.analyze_crowd(camera, %{
          crowd_data: crowd_data,
          analysis_method: "density_estimation"
        })

      assert crowd_analytics.analytics_type == :crowd_detection
      assert crowd_analytics.metadata["crowd_density"] == "medium"
      assert crowd_analytics.metadata["estimated_count"] == 25
      assert crowd_analytics.metadata["anomaly_detected"] == false
    end

    test "tracks analytics over time", %{tenant: tenant, camera: camera} do
      # Create analytics events over time
      times = [
        # 1 hour ago
        DateTime.utc_now() |> DateTime.add(-3600, :second),
        # 30 minutes ago
        DateTime.utc_now() |> DateTime.add(-1800, :second),
        # now
        DateTime.utc_now()
      ]

      for {time, count} <- Enum.with_index(times, 1) do
        insert(:analytics,
          camera: camera,
          tenant: tenant,
          analytics_type: :people_counting,
          timestamp: time,
          metadata: %{"total_count" => count * 3}
        )
      end

      analytics_list =
        Analytics.read!(
          camera: camera,
          analytics_type: :people_counting,
          sort: [timestamp: :asc]
        )

      assert length(analytics_list) == 3

      # Verify chronological order
      timestamps = Enum.map(analytics_list, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end

    test "generates analytics reports", %{tenant: tenant, camera: camera} do
      # Create sample analytics data
      analytics_data = [
        {DateTime.utc_now() |> DateTime.add(-7200, :second), :motion_detection, 0.8},
        {DateTime.utc_now() |> DateTime.add(-3600, :second), :object_detection, 0.9},
        {DateTime.utc_now() |> DateTime.add(-1800, :second), :people_counting, 0.85},
        {DateTime.utc_now(), :face_detection, 0.75}
      ]

      for {timestamp, type, confidence} <- analytics_data do
        insert(:analytics,
          camera: camera,
          tenant: tenant,
          analytics_type: type,
          timestamp: timestamp,
          confidence_score: confidence
        )
      end

      {:ok, report} =
        Analytics.generate_report(camera, %{
          start_time: DateTime.utc_now() |> DateTime.add(-8000, :second),
          end_time: DateTime.utc_now(),
          report_type: "summary"
        })

      assert report.report_type == "summary"
      assert report.metadata["total_events"] == 4
      assert report.metadata["analytics_types"]
      assert report.metadata["average_confidence"]
    end

    test "filters analytics by confidence threshold",
         %{tenant: tenant, camera: camera} do
      # Create analytics with different confidence scores
      confidence_scores = [0.3, 0.6, 0.8, 0.95]

      for score <- confidence_scores do
        insert(:analytics,
          camera: camera,
          tenant: tenant,
          analytics_type: :motion_detection,
          confidence_score: score
        )
      end

      # Filter by minimum confidence of 0.7
      high_confidence =
        Analytics.read!(
          camera: camera,
          confidence_score: [min: 0.7]
        )

      assert length(high_confidence) == 2

      Enum.each(high_confidence, fn analytics ->
        assert analytics.confidence_score >= 0.7
      end)
    end

    test "manages analytics retention policy",
         %{tenant: tenant, camera: camera} do
      # Old analytics (should be eligible for cleanup)
      old_analytics =
        insert(:analytics,
          camera: camera,
          tenant: tenant,
          # 95 days ago
          timestamp: DateTime.utc_now() |> DateTime.add(-95 * 86_400, :second),
          metadata: %{"retention_days" => 90}
        )

      # Recent analytics (should be kept)
      recent_analytics =
        insert(:analytics,
          camera: camera,
          tenant: tenant,
          # 30 days ago
          timestamp: DateTime.utc_now() |> DateTime.add(-30 * 86_400, :second),
          metadata: %{"retention_days" => 90}
        )

      old_with_calc = Analytics.read!(old_analytics.id, load: [:should_be_deleted?])
      recent_with_calc = Analytics.read!(recent_analytics.id, load: [:should_be_deleted?])

      assert old_with_calc.should_be_deleted? == true
      assert recent_with_calc.should_be_deleted? == false
    end

    test "enforces tenant isolation", %{camera: camera} do
      tenant1 = camera.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)
      camera2 = insert(:camera, tenant: tenant2, site: site2)

      analytics1 = insert(:analytics, tenant: tenant1, camera: camera)
      analytics2 = insert(:analytics, tenant: tenant2, camera: camera2)

      tenant1_analytics = Analytics.read!(tenant: tenant1)
      tenant2_analytics = Analytics.read!(tenant: tenant2)

      assert length(tenant1_analytics) == 1
      assert length(tenant2_analytics) == 1
      assert Enum.any?(tenant1_analytics, &(&1.id == analytics1.id))
      assert Enum.any?(tenant2_analytics, &(&1.id == analytics2.id))
      refute Enum.any?(tenant1_analytics, &(&1.id == analytics2.id))
      refute Enum.any?(tenant2_analytics, &(&1.id == analytics1.id))
    end

    test "validates bounding box coordinates",
         %{tenant: tenant, camera: camera} do
      valid_bounding_boxes = [
        %{"x" => 0, "y" => 0, "width" => 100, "height" => 100},
        %{"x" => 50, "y" => 25, "width" => 200, "height" => 150}
      ]

      invalid_bounding_boxes = [
        # negative x
        %{"x" => -10, "y" => 0, "width" => 100, "height" => 100},
        # negative width
        %{"x" => 0, "y" => 0, "width" => -50, "height" => 100},
        # zero width
        %{"x" => 0, "y" => 0, "width" => 0, "height" => 100}
      ]

      for bbox <- valid_bounding_boxes do
        {:ok, _analytics} =
          Analytics.create(%{
            analytics_type: :object_detection,
            timestamp: DateTime.utc_now(),
            confidence_score: 0.8,
            bounding_box: bbox,
            camera_id: camera.id,
            tenant_id: tenant.id
          })
      end

      for bbox <- invalid_bounding_boxes do
        {:error, changeset} =
          Analytics.create(%{
            analytics_type: :object_detection,
            timestamp: DateTime.utc_now(),
            confidence_score: 0.8,
            bounding_box: bbox,
            camera_id: camera.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:bounding_box]
      end
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
