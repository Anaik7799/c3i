defmodule Indrajaal.Analytics.HeatMapPropertyTest do
  @moduledoc """
  Property-based testing for Heat Map Analytics module using dual testing frameworks.

  This module validates heat map generation, spatial data visualization, intensity mapping,
  and geographic analytics functionality using Test-Driven Generation (TDG) methodology
  with comprehensive STAMP safety constraints.

  Testing Framework: Dual PropCheck + ExUnitProperties
  STAMP Constraints: SC-HM-001 through SC-HM-005
  Coverage: Core functions, integration, end-to-end workflows

  Key Functions Tested:
  - generate_heat_map/4: Multi-dimensional heat map visualization generation
  - calculate_intensity_matrix/3: Spatial intensity calculation with geographic weighting
  - apply_spatial_clustering/3: Geographic clustering and hotspot identification
  - create_temporal_heat_series/4: Time-based heat map animation and trending
  - optimize_heat_map_rendering/2: Performance optimization for large datasets
  """

  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing - import except check to avoid conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.HeatMap

  # Test data generators for comprehensive property testing
  @heat_map_types [
    :geographic,
    :temporal,
    :categorical,
    :intensity_based,
    :risk_assessment,
    :performance_matrix
  ]
  @intensity_algorithms [
    :gaussian,
    :inverse_distance,
    :kriging,
    :nearest_neighbor,
    :bilinear_interpolation
  ]
  @clustering_methods [:kmeans, :dbscan, :hierarchical, :density_based, :spatial_autocorrelation]
  @visualization_formats [:svg, :canvas, :webgl, :png, :interactive_d3]
  @geographic_projections [
    :mercator,
    :albers,
    :lambert_conformal,
    :equirectangular,
    :orthographic
  ]

  # ==========================================
  # CORE FUNCTION TESTING: generate_heat_map/4
  # ==========================================

  describe "generate_heat_map/4 - Multi-dimensional heat map visualization generation" do
    # PropCheck property test - Advanced shrinking capabilities
    test "propcheck: heat map generation maintains spatial consistency and visual integrity" do
      assert PropCheck.quickcheck(
               forall {tenant_id, data_points, heat_map_config, visualization_params} <- {
                        tenant_id_generator(),
                        spatial_data_points_generator(),
                        heat_map_config_generator(),
                        visualization_params_generator()
                      } do
                 result =
                   HeatMap.generate_heat_map(
                     tenant_id,
                     data_points,
                     heat_map_config,
                     visualization_params
                   )

                 # Core heat map properties
                 result.heat_map_type == heat_map_config.type and
                   is_list(result.intensity_grid) and
                   length(result.intensity_grid) > 0 and
                   is_map(result.spatial_bounds) and
                   Map.has_key?(result, :color_scale) and
                   Map.has_key?(result, :legend_data) and
                   Map.has_key?(result, :rendering_metadata) and
                   result.data_point_count == length(data_points)
               end
             )
    end

    # ExUnitProperties test - StreamData integration
    test "exunitproperties: heat map generation handles edge cases and sparse data correctly" do
      ExUnitProperties.check all(
                               tenant_id <- tenant_id_generator(),
                               data_points <- spatial_data_points_generator(),
                               heat_map_config <- heat_map_config_generator(),
                               visualization_params <- visualization_params_generator(),
                               max_runs: 100
                             ) do
        result =
          HeatMap.generate_heat_map(tenant_id, data_points, heat_map_config, visualization_params)

        # Heat map structure validation
        assert is_list(result.intensity_grid)
        assert Map.has_key?(result, :spatial_bounds)
        assert Map.has_key?(result, :color_scale)
        assert result.tenant_id == tenant_id
        assert Map.has_key?(result, :generation_timestamp)

        # Intensity grid validation
        unless Enum.empty?(result.intensity_grid) do
          first_row = List.first(result.intensity_grid)
          assert is_list(first_row)
          assert length(first_row) > 0

          # All intensity values should be valid numbers
          Enum.each(result.intensity_grid, fn row ->
            Enum.each(row, fn intensity ->
              assert is_number(intensity)
              assert intensity >= 0.0
            end)
          end)
        end
      end
    end

    # Integration test with multi-tenant isolation
    test "generate_heat_map respects tenant isolation and geographic boundaries" do
      tenant_alpha = "security_tenant_alpha"
      tenant_beta = "security_tenant_beta"

      # Generate overlapping geographic data for different tenants
      base_coordinates = [
        %{lat: 40.7128, lng: -74.0060, intensity: 85.0, category: "high_security"},
        %{lat: 40.7589, lng: -73.9851, intensity: 92.0, category: "critical_zone"},
        %{lat: 40.6782, lng: -73.9442, intensity: 78.0, category: "medium_security"}
      ]

      heat_map_config = %{
        type: :geographic,
        algorithm: :gaussian,
        resolution: :high,
        geographic_projection: :mercator
      }

      visualization_params = %{
        format: :svg,
        color_scheme: :security_gradient,
        include_legend: true,
        width: 800,
        height: 600
      }

      # Generate heat maps for different tenants
      heat_map_alpha =
        HeatMap.generate_heat_map(
          tenant_alpha,
          base_coordinates,
          heat_map_config,
          visualization_params
        )

      heat_map_beta =
        HeatMap.generate_heat_map(
          tenant_beta,
          base_coordinates,
          heat_map_config,
          visualization_params
        )

      # Tenant isolation verification
      assert heat_map_alpha.tenant_id == tenant_alpha
      assert heat_map_beta.tenant_id == tenant_beta
      assert heat_map_alpha.tenant_id != heat_map_beta.tenant_id

      # Geographic boundaries should be tenant-specific even with same input coordinates
      assert Map.has_key?(heat_map_alpha, :tenant_boundary_constraints)
      assert Map.has_key?(heat_map_beta, :tenant_boundary_constraints)

      # Security context validation
      assert heat_map_alpha.security_context.tenant_isolation == true
      assert heat_map_beta.security_context.tenant_isolation == true
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: calculate_intensity_matrix/3
  # ==========================================

  describe "calculate_intensity_matrix/3 - Spatial intensity calculation with geographic weighting" do
    # PropCheck property test
    test "propcheck: intensity matrix calculation maintains mathematical consistency" do
      assert PropCheck.quickcheck(
               forall {data_points, algorithm_config, grid_resolution} <- {
                        spatial_data_points_generator(),
                        intensity_algorithm_config_generator(),
                        grid_resolution_generator()
                      } do
                 result =
                   HeatMap.calculate_intensity_matrix(
                     data_points,
                     algorithm_config,
                     grid_resolution
                   )

                 # Intensity matrix properties
                 is_list(result.intensity_matrix) and
                   result.algorithm == algorithm_config.algorithm and
                   result.grid_resolution == grid_resolution and
                   Map.has_key?(result, :calculation_metadata) and
                   Map.has_key?(result, :statistical_summary) and
                   result.statistical_summary.total_data_points == length(data_points)
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: intensity matrix handles various interpolation algorithms correctly" do
      ExUnitProperties.check all(
                               data_points <- spatial_data_points_generator(),
                               algorithm_config <- intensity_algorithm_config_generator(),
                               grid_resolution <- grid_resolution_generator(),
                               max_runs: 100
                             ) do
        result =
          HeatMap.calculate_intensity_matrix(data_points, algorithm_config, grid_resolution)

        # Matrix structure validation
        assert is_list(result.intensity_matrix)
        assert result.algorithm == algorithm_config.algorithm
        assert Map.has_key?(result, :bounds)

        # Statistical validation
        if length(data_points) > 0 do
          stats = result.statistical_summary
          assert Map.has_key?(stats, :min_intensity)
          assert Map.has_key?(stats, :max_intensity)
          assert Map.has_key?(stats, :mean_intensity)
          assert stats.min_intensity <= stats.max_intensity
        end
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: apply_spatial_clustering/3
  # ==========================================

  describe "apply_spatial_clustering/3 - Geographic clustering and hotspot identification" do
    # PropCheck property test
    test "propcheck: spatial clustering maintains cluster validity and geographic coherence" do
      assert PropCheck.quickcheck(
               forall {data_points, clustering_config, analysis_params} <- {
                        geographic_data_points_generator(),
                        clustering_config_generator(),
                        spatial_analysis_params_generator()
                      } do
                 result =
                   HeatMap.apply_spatial_clustering(
                     data_points,
                     clustering_config,
                     analysis_params
                   )

                 # Clustering properties
                 is_list(result.clusters) and
                   result.clustering_method == clustering_config.method and
                   Map.has_key?(result, :cluster_statistics) and
                   Map.has_key?(result, :hotspots_identified) and
                   Map.has_key?(result, :outliers) and
                   result.total_points_clustered <= length(data_points)
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: spatial clustering handles different density patterns effectively" do
      ExUnitProperties.check all(
                               data_points <- geographic_data_points_generator(),
                               clustering_config <- clustering_config_generator(),
                               analysis_params <- spatial_analysis_params_generator(),
                               max_runs: 100
                             ) do
        result = HeatMap.apply_spatial_clustering(data_points, clustering_config, analysis_params)

        # Clustering validation
        assert is_list(result.clusters)
        assert Map.has_key?(result, :cluster_statistics)
        assert result.clustering_method == clustering_config.method

        # Validate cluster structure
        unless Enum.empty?(result.clusters) do
          Enum.each(result.clusters, fn cluster ->
            assert Map.has_key?(cluster, :centroid)
            assert Map.has_key?(cluster, :points)
            assert Map.has_key?(cluster, :density_score)
            assert is_list(cluster.points)
            assert cluster.density_score >= 0.0
          end)
        end
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: create_temporal_heat_series/4
  # ==========================================

  describe "create_temporal_heat_series/4 - Time-based heat map animation and trending" do
    # PropCheck property test
    test "propcheck: temporal heat series maintains chronological consistency" do
      assert PropCheck.quickcheck(
               forall {tenant_id, temporal_data, time_config, animation_params} <- {
                        tenant_id_generator(),
                        temporal_spatial_data_generator(),
                        time_series_config_generator(),
                        animation_params_generator()
                      } do
                 result =
                   HeatMap.create_temporal_heat_series(
                     tenant_id,
                     temporal_data,
                     time_config,
                     animation_params
                   )

                 # Temporal series properties
                 is_list(result.time_series_frames) and
                   length(result.time_series_frames) > 0 and
                   result.time_config.start_time <= result.time_config.end_time and
                   Map.has_key?(result, :temporal_trends) and
                   Map.has_key?(result, :animation_metadata) and
                   result.tenant_id == tenant_id
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: temporal heat series handles irregular time intervals correctly" do
      ExUnitProperties.check all(
                               tenant_id <- tenant_id_generator(),
                               temporal_data <- temporal_spatial_data_generator(),
                               time_config <- time_series_config_generator(),
                               animation_params <- animation_params_generator(),
                               max_runs: 100
                             ) do
        result =
          HeatMap.create_temporal_heat_series(
            tenant_id,
            temporal_data,
            time_config,
            animation_params
          )

        # Temporal validation
        assert is_list(result.time_series_frames)
        assert result.tenant_id == tenant_id
        assert Map.has_key?(result, :temporal_trends)

        # Frame validation
        unless Enum.empty?(result.time_series_frames) do
          # Frames should be chronologically ordered
          timestamps = Enum.map(result.time_series_frames, & &1.timestamp)
          sorted_timestamps = Enum.sort(timestamps, DateTime)
          assert timestamps == sorted_timestamps

          # Each frame should have required structure
          Enum.each(result.time_series_frames, fn frame ->
            assert Map.has_key?(frame, :timestamp)
            assert Map.has_key?(frame, :heat_map_data)
            assert Map.has_key?(frame, :frame_index)
          end)
        end
      end
    end
  end

  # ==========================================
  # INTEGRATION TESTING
  # ==========================================

  describe "Integration Testing - End-to-end heat map analytics workflows" do
    test "complete heat map generation with spatial clustering and temporal analysis" do
      tenant_id = "geographic_analytics_tenant"

      # Step 1: Generate base geographic data points
      data_points = [
        %{
          lat: 37.7749,
          lng: -122.4194,
          intensity: 95.0,
          timestamp: ~U[2024-01-15 10:00:00Z],
          category: "high_activity"
        },
        %{
          lat: 37.7849,
          lng: -122.4094,
          intensity: 88.0,
          timestamp: ~U[2024-01-15 11:00:00Z],
          category: "medium_activity"
        },
        %{
          lat: 37.7649,
          lng: -122.4294,
          intensity: 76.0,
          timestamp: ~U[2024-01-15 12:00:00Z],
          category: "low_activity"
        },
        %{
          lat: 37.7949,
          lng: -122.3994,
          intensity: 92.0,
          timestamp: ~U[2024-01-15 13:00:00Z],
          category: "high_activity"
        },
        %{
          lat: 37.7549,
          lng: -122.4394,
          intensity: 84.0,
          timestamp: ~U[2024-01-15 14:00:00Z],
          category: "medium_activity"
        }
      ]

      # Step 2: Generate comprehensive heat map
      heat_map_config = %{
        type: :geographic,
        algorithm: :gaussian,
        resolution: :high,
        geographic_projection: :mercator,
        smoothing_factor: 0.5
      }

      visualization_params = %{
        format: :svg,
        color_scheme: :viridis,
        include_legend: true,
        width: 1200,
        height: 800,
        interactive: true
      }

      heat_map =
        HeatMap.generate_heat_map(tenant_id, data_points, heat_map_config, visualization_params)

      assert heat_map.heat_map_type == :geographic
      assert length(heat_map.intensity_grid) > 0
      assert Map.has_key?(heat_map, :color_scale)

      # Step 3: Calculate detailed intensity matrix
      algorithm_config = %{
        algorithm: :gaussian,
        bandwidth: 0.05,
        decay_factor: 0.8,
        edge_correction: true
      }

      grid_resolution = %{
        width: 100,
        height: 100,
        precision: :high
      }

      intensity_matrix =
        HeatMap.calculate_intensity_matrix(data_points, algorithm_config, grid_resolution)

      assert intensity_matrix.algorithm == :gaussian
      assert length(intensity_matrix.intensity_matrix) == 100
      assert Map.has_key?(intensity_matrix, :statistical_summary)

      # Step 4: Apply spatial clustering for hotspot identification
      clustering_config = %{
        method: :dbscan,
        # 1km radius approximately
        epsilon: 0.01,
        min_points: 2,
        distance_metric: :haversine
      }

      analysis_params = %{
        identify_hotspots: true,
        outlier_detection: true,
        cluster_validation: true,
        statistical_significance: 0.05
      }

      clustering_result =
        HeatMap.apply_spatial_clustering(data_points, clustering_config, analysis_params)

      assert clustering_result.clustering_method == :dbscan
      assert is_list(clustering_result.clusters)
      assert Map.has_key?(clustering_result, :hotspots_identified)

      # Step 5: Create temporal heat series
      temporal_data =
        Enum.with_index(data_points, fn point, index ->
          Map.put(
            point,
            :timestamp,
            DateTime.add(~U[2024-01-15 10:00:00Z], index * 3600, :second)
          )
        end)

      time_config = %{
        start_time: ~U[2024-01-15 10:00:00Z],
        end_time: ~U[2024-01-15 14:00:00Z],
        time_resolution: :hourly,
        interpolation_method: :linear
      }

      animation_params = %{
        # 2 FPS
        frame_rate: 2,
        # 500ms
        transition_duration: 500,
        loop_animation: true,
        include_controls: true
      }

      temporal_series =
        HeatMap.create_temporal_heat_series(
          tenant_id,
          temporal_data,
          time_config,
          animation_params
        )

      # Hourly frames
      assert length(temporal_series.time_series_frames) == 5
      assert Map.has_key?(temporal_series, :temporal_trends)
      assert Map.has_key?(temporal_series, :animation_metadata)

      # Integration validation
      assert heat_map.tenant_id == tenant_id
      assert clustering_result.total_points_clustered == length(data_points)
      assert temporal_series.tenant_id == tenant_id

      # Cross-component consistency validation
      assert heat_map.data_point_count == length(data_points)
      assert intensity_matrix.statistical_summary.total_data_points == length(data_points)
      assert clustering_result.total_points_clustered == length(data_points)

      # Geographic bounds consistency
      heat_map_bounds = heat_map.spatial_bounds
      matrix_bounds = intensity_matrix.bounds

      # Bounds should overlap significantly (allowing for algorithm differences)
      lat_overlap =
        max(heat_map_bounds.min_lat, matrix_bounds.min_lat) <
          min(heat_map_bounds.max_lat, matrix_bounds.max_lat)

      lng_overlap =
        max(heat_map_bounds.min_lng, matrix_bounds.min_lng) <
          min(heat_map_bounds.max_lng, matrix_bounds.max_lng)

      assert lat_overlap
      assert lng_overlap
    end
  end

  # ==========================================
  # STAMP SAFETY CONSTRAINTS (SC-HM-001 through SC-HM-005)
  # ==========================================

  describe "STAMP Safety Constraints - Heat Map System Safety" do
    test "SC-HM-001: System SHALL ensure heat map spatial accuracy and geographic projection integrity" do
      # Test spatial accuracy across different projections and coordinate systems
      tenant_id = "spatial_accuracy_tenant"

      # Test data with known geographic coordinates (San Francisco Bay Area)
      precise_coordinates = [
        %{lat: 37.7749, lng: -122.4194, intensity: 100.0, name: "San Francisco City Hall"},
        %{lat: 37.8044, lng: -122.2712, intensity: 85.0, name: "Oakland City Center"},
        %{lat: 37.4419, lng: -122.1430, intensity: 92.0, name: "Palo Alto Downtown"}
      ]

      # Test multiple geographic projections
      projections = [:mercator, :albers, :lambert_conformal, :equirectangular]

      Enum.each(projections, fn projection ->
        heat_map_config = %{
          type: :geographic,
          algorithm: :gaussian,
          resolution: :high,
          geographic_projection: projection
        }

        visualization_params = %{
          format: :svg,
          coordinate_precision: :high,
          validate_projections: true
        }

        result =
          HeatMap.generate_heat_map(
            tenant_id,
            precise_coordinates,
            heat_map_config,
            visualization_params
          )

        # Spatial accuracy validation
        assert result.spatial_accuracy.projection == projection
        assert result.spatial_accuracy.coordinate_precision == :high
        assert Map.has_key?(result.spatial_accuracy, :projection_parameters)

        # Geographic integrity validation
        bounds = result.spatial_bounds
        # Bay Area minimum latitude
        assert bounds.min_lat >= 37.0
        # Bay Area maximum latitude
        assert bounds.max_lat <= 38.0
        # Bay Area minimum longitude
        assert bounds.min_lng >= -123.0
        # Bay Area maximum longitude
        assert bounds.max_lng <= -121.0

        # Projection consistency validation
        proj_params = result.spatial_accuracy.projection_parameters

        assert Map.has_key?(proj_params, :central_meridian) ||
                 Map.has_key?(proj_params, :standard_parallels)

        # WGS84
        assert proj_params.coordinate_system == "EPSG:4326"

        # Distance accuracy validation (using Haversine formula verification)
        if length(result.spatial_validation.distance_checks) > 0 do
          Enum.each(result.spatial_validation.distance_checks, fn distance_check ->
            # Within 100m accuracy
            assert distance_check.calculated_error_meters <= 100.0
            # <5% distortion
            assert distance_check.projection_distortion_factor <= 1.05
          end)
        end
      end)
    end

    test "SC-HM-002: System SHALL maintain heat map data integrity and prevent spatial data corruption" do
      # Test data integrity across various operations and transformations
      tenant_id = "data_integrity_tenant"

      # Original high-precision data
      original_data = [
        %{
          lat: 40.748_817,
          lng: -73.985_428,
          intensity: 87.5,
          id: "point_001",
          checksum: "abc123"
        },
        %{
          lat: 40.758_896,
          lng: -73.985_130,
          intensity: 94.2,
          id: "point_002",
          checksum: "def456"
        },
        %{lat: 40.741_895, lng: -73.989_308, intensity: 79.8, id: "point_003", checksum: "ghi789"}
      ]

      # Generate heat map with integrity checking enabled
      heat_map_config = %{
        type: :geographic,
        algorithm: :gaussian,
        resolution: :high,
        data_integrity_checks: true,
        preserve_original_data: true
      }

      visualization_params = %{
        format: :svg,
        data_validation: true,
        checksum_verification: true
      }

      result =
        HeatMap.generate_heat_map(tenant_id, original_data, heat_map_config, visualization_params)

      # Data integrity validation
      integrity_report = result.data_integrity

      assert Map.has_key?(integrity_report, :original_data_preserved)
      assert integrity_report.original_data_preserved == true
      assert Map.has_key?(integrity_report, :checksum_validations)
      assert length(integrity_report.checksum_validations) == length(original_data)

      # Verify each data point's integrity
      Enum.each(integrity_report.checksum_validations, fn validation ->
        assert validation.checksum_verified == true
        assert validation.coordinate_precision_maintained == true
        assert validation.intensity_value_preserved == true
      end)

      # Spatial transformation integrity
      assert Map.has_key?(integrity_report, :spatial_transformations)
      transformations = integrity_report.spatial_transformations

      assert transformations.coordinate_system_preserved == true
      assert transformations.projection_accuracy_maintained == true
      assert transformations.no_data_loss_detected == true

      # Verify original data can be recovered
      recovered_data = result.recoverable_original_data
      assert length(recovered_data) == length(original_data)

      zipped_data = Enum.zip(original_data, recovered_data)

      zipped_data
      |> Enum.each(fn {original, recovered} ->
        # Precision within 6 decimal places
        assert abs(original.lat - recovered.lat) < 0.000_001
        assert abs(original.lng - recovered.lng) < 0.000_001
        # Intensity within 0.01
        assert abs(original.intensity - recovered.intensity) < 0.01
        assert original.id == recovered.id
        assert original.checksum == recovered.checksum
      end)
    end

    test "SC-HM-003: System SHALL ensure heat map visualization performance meets real-time requirements" do
      # Test performance requirements for real-time heat map applications
      tenant_id = "performance_test_tenant"

      # Generate large dataset for performance testing
      large_dataset =
        Enum.map(1..10_000, fn i ->
          %{
            # Bay Area coordinates
            lat: 37.0 + :rand.uniform() * 2.0,
            lng: -123.0 + :rand.uniform() * 2.0,
            intensity: :rand.uniform() * 100.0,
            id: "point_#{i}",
            # 1 minute intervals
            timestamp: DateTime.add(DateTime.utc_now(), -i * 60, :second)
          }
        end)

      # High-performance heat map configuration
      performance_config = %{
        type: :geographic,
        # Faster than Gaussian for large datasets
        algorithm: :inverse_distance,
        # Balance between quality and speed
        resolution: :medium,
        performance_optimization: true,
        parallel_processing: true,
        memory_optimization: true
      }

      visualization_params = %{
        # Hardware-accelerated rendering
        format: :webgl,
        progressive_rendering: true,
        level_of_detail: true,
        performance_monitoring: true
      }

      # Measure generation performance
      start_time = System.monotonic_time(:millisecond)

      result =
        HeatMap.generate_heat_map(
          tenant_id,
          large_dataset,
          performance_config,
          visualization_params
        )

      generation_time = System.monotonic_time(:millisecond) - start_time

      # Real-time performance requirements
      # Must complete within 5 seconds
      assert generation_time <= 5000

      performance_metrics = result.performance_metrics
      # Data processing under 3 seconds
      assert performance_metrics.data_processing_time_ms <= 3000
      # Rendering under 2 seconds
      assert performance_metrics.visualization_rendering_time_ms <= 2000
      # Memory usage under 256MB
      assert performance_metrics.memory_usage_mb <= 256

      # Real-time update capabilities
      assert Map.has_key?(result, :update_capabilities)
      update_caps = result.update_capabilities

      assert update_caps.incremental_update_supported == true
      assert update_caps.streaming_data_support == true
      # 30 FPS minimum for smooth updates
      assert update_caps.real_time_refresh_rate_fps >= 30

      # Scalability validation
      scalability_metrics = performance_metrics.scalability
      assert scalability_metrics.max_data_points_supported >= 50_000
      assert scalability_metrics.concurrent_user_capacity >= 100
      # Linear memory scaling
      assert scalability_metrics.memory_scaling_factor <= 1.5

      # Quality vs Performance trade-off validation
      quality_metrics = result.quality_metrics
      # 80% visual quality maintained
      assert quality_metrics.visual_quality_score >= 0.8
      # <5% accuracy loss
      assert quality_metrics.spatial_accuracy_degradation <= 0.05
      # 90% color fidelity
      assert quality_metrics.color_resolution_maintained >= 0.9
    end

    test "SC-HM-004: System SHALL provide heat map accessibility compliance and multi-format output support" do
      # Test accessibility compliance and format support for diverse user needs
      tenant_id = "accessibility_test_tenant"

      # Test data with accessibility considerations
      accessibility_data = [
        %{
          lat: 42.3601,
          lng: -71.0589,
          intensity: 88.0,
          category: "emergency_services",
          priority: :high
        },
        %{
          lat: 42.3751,
          lng: -71.0489,
          intensity: 72.0,
          category: "public_transport",
          priority: :medium
        },
        %{
          lat: 42.3501,
          lng: -71.0689,
          intensity: 95.0,
          category: "healthcare",
          priority: :critical
        }
      ]

      # Accessibility-focused configuration
      heat_map_config = %{
        type: :categorical,
        algorithm: :nearest_neighbor,
        resolution: :high,
        accessibility_compliance: :wcag_aa,
        colorblind_support: true
      }

      # Test multiple output formats
      output_formats = [:svg, :png, :canvas, :interactive_d3, :text_description]

      Enum.each(output_formats, fn format ->
        visualization_params = %{
          format: format,
          accessibility_features: true,
          alt_text_generation: true,
          keyboard_navigation: format in [:svg, :interactive_d3],
          screen_reader_support: true,
          high_contrast_mode: true
        }

        result =
          HeatMap.generate_heat_map(
            tenant_id,
            accessibility_data,
            heat_map_config,
            visualization_params
          )

        # Format-specific validation
        assert result.output_format == format
        assert Map.has_key?(result, :accessibility_features)

        accessibility = result.accessibility_features

        # WCAG AA compliance validation
        assert accessibility.wcag_compliance_level == :aa
        # WCAG AA requirement
        assert accessibility.color_contrast_ratio >= 4.5
        assert Map.has_key?(accessibility, :colorblind_adaptations)

        # Colorblind support validation
        colorblind_support = accessibility.colorblind_adaptations
        assert colorblind_support.deuteranopia_support == true
        assert colorblind_support.protanopia_support == true
        assert colorblind_support.tritanopia_support == true
        assert Map.has_key?(colorblind_support, :alternative_patterns)

        # Alternative text and descriptions
        assert Map.has_key?(accessibility, :alternative_descriptions)
        alt_desc = accessibility.alternative_descriptions

        assert String.length(alt_desc.short_description) > 10
        assert String.length(alt_desc.detailed_description) > 50
        assert Map.has_key?(alt_desc, :data_table_alternative)

        # Interactive accessibility (for applicable formats)
        if format in [:svg, :interactive_d3] do
          interactive = accessibility.interactive_features
          assert interactive.keyboard_navigation_enabled == true
          assert interactive.focus_indicators_visible == true
          assert interactive.aria_labels_present == true
          assert Map.has_key?(interactive, :keyboard_shortcuts)
        end

        # Screen reader support
        screen_reader = accessibility.screen_reader_support
        assert screen_reader.aria_live_regions == true
        assert screen_reader.role_attributes_present == true
        assert Map.has_key?(screen_reader, :structured_navigation)

        # Format-specific accessibility features
        case format do
          :svg ->
            assert Map.has_key?(result.output_data, :svg_accessibility_elements)
            assert result.output_data.svg_accessibility_elements.title_element_present == true
            assert result.output_data.svg_accessibility_elements.desc_element_present == true

          :interactive_d3 ->
            assert Map.has_key?(result.output_data, :d3_accessibility_bindings)
            assert result.output_data.d3_accessibility_bindings.keyboard_event_handlers == true

          :text_description ->
            text_output = result.output_data.text_representation
            assert String.contains?(text_output, "heat map")
            assert String.contains?(text_output, "intensity")
            # Comprehensive text description
            assert String.length(text_output) >= 200

          _ ->
            # All formats should have basic accessibility metadata
            assert Map.has_key?(result.output_data, :accessibility_metadata)
        end
      end)
    end

    test "SC-HM-005: System SHALL maintain heat map temporal consistency and historical data preservation" do
      # Test temporal consistency and historical data preservation across time series
      tenant_id = "temporal_consistency_tenant"

      # Generate historical data with temporal patterns
      base_time = ~U[2024-01-01 00:00:00Z]

      # 31 days of data
      historical_data =
        Enum.flat_map(0..30, fn day ->
          # Hourly data points
          Enum.map(0..23, fn hour ->
            timestamp = DateTime.add(base_time, (day * 24 + hour) * 3600, :second)

            # Simulate realistic temporal patterns (morning and evening peaks)
            hour_intensity =
              cond do
                # Morning peak
                hour in [7, 8, 9] -> 80.0 + :rand.uniform() * 20.0
                # Evening peak
                hour in [17, 18, 19] -> 85.0 + :rand.uniform() * 15.0
                # Night low
                hour in [22, 23, 0, 1, 2, 3, 4, 5] -> 10.0 + :rand.uniform() * 20.0
                # Regular hours
                true -> 40.0 + :rand.uniform() * 30.0
              end

            %{
              # SF with small variations
              lat: 37.7749 + (:rand.uniform() - 0.5) * 0.1,
              lng: -122.4194 + (:rand.uniform() - 0.5) * 0.1,
              intensity: hour_intensity,
              timestamp: timestamp,
              day_of_week: Date.day_of_week(DateTime.to_date(timestamp)),
              hour_of_day: hour
            }
          end)
        end)

      # Create temporal heat series with historical preservation
      time_config = %{
        start_time: base_time,
        # 31 days
        end_time: DateTime.add(base_time, 30 * 24 * 3600, :second),
        time_resolution: :daily,
        historical_preservation: true,
        temporal_validation: true,
        consistency_checking: true
      }

      animation_params = %{
        # 1 FPS for daily progression
        frame_rate: 1,
        temporal_smoothing: true,
        historical_comparison: true,
        trend_analysis: true
      }

      temporal_result =
        HeatMap.create_temporal_heat_series(
          tenant_id,
          historical_data,
          time_config,
          animation_params
        )

      # Temporal consistency validation
      consistency = temporal_result.temporal_consistency

      assert Map.has_key?(consistency, :chronological_order_verified)
      assert consistency.chronological_order_verified == true

      assert Map.has_key?(consistency, :temporal_gaps_detected)
      assert is_list(consistency.temporal_gaps_detected)

      assert Map.has_key?(consistency, :data_continuity_score)
      # 95% continuity minimum
      assert consistency.data_continuity_score >= 0.95

      # Historical data preservation validation
      historical_preservation = temporal_result.historical_preservation

      assert Map.has_key?(historical_preservation, :original_timestamps_preserved)
      assert historical_preservation.original_timestamps_preserved == true

      assert Map.has_key?(historical_preservation, :data_integrity_maintained)
      assert historical_preservation.data_integrity_maintained == true

      # Verify temporal patterns are preserved
      temporal_patterns = temporal_result.temporal_trends.identified_patterns

      assert Map.has_key?(temporal_patterns, :daily_cycles)
      daily_cycles = temporal_patterns.daily_cycles
      assert daily_cycles.morning_peak_detected == true
      assert daily_cycles.evening_peak_detected == true
      assert daily_cycles.night_low_detected == true

      assert Map.has_key?(temporal_patterns, :weekly_patterns)
      weekly_patterns = temporal_patterns.weekly_patterns
      assert Map.has_key?(weekly_patterns, :weekday_weekend_difference)

      # Historical comparison capabilities
      historical_comparison = temporal_result.historical_comparison

      assert Map.has_key?(historical_comparison, :baseline_established)
      assert historical_comparison.baseline_established == true

      assert Map.has_key?(historical_comparison, :anomaly_detection)
      anomaly_detection = historical_comparison.anomaly_detection
      assert Map.has_key?(anomaly_detection, :statistical_outliers)
      assert Map.has_key?(anomaly_detection, :trend_deviations)

      # Time series frame validation
      frames = temporal_result.time_series_frames
      # One frame per day
      assert length(frames) == 31

      # Verify chronological ordering
      timestamps = Enum.map(frames, & &1.timestamp)
      sorted_timestamps = Enum.sort(timestamps, DateTime)
      assert timestamps == sorted_timestamps

      # Verify each frame maintains spatial consistency
      Enum.each(frames, fn frame ->
        assert Map.has_key?(frame, :spatial_bounds)
        assert Map.has_key?(frame, :intensity_statistics)
        assert Map.has_key?(frame, :temporal_context)

        # Spatial bounds should be consistent across time
        bounds = frame.spatial_bounds
        # Within expected variation
        assert abs(bounds.center_lat - 37.7749) <= 0.1
        assert abs(bounds.center_lng - -122.4194) <= 0.1
      end)

      # Long-term trend preservation
      trend_analysis = temporal_result.temporal_trends.trend_analysis
      assert Map.has_key?(trend_analysis, :long_term_trends)
      assert Map.has_key?(trend_analysis, :seasonal_patterns)
      assert Map.has_key?(trend_analysis, :cyclical_behaviors)

      # Verify trend calculation consistency
      long_term = trend_analysis.long_term_trends
      # :increasing, :decreasing, :stable
      assert Map.has_key?(long_term, :overall_direction)
      # Statistical significance
      assert Map.has_key?(long_term, :trend_strength)
      # 70% confidence minimum
      assert long_term.trend_strength >= 0.7
    end
  end

  # ==========================================
  # HELPER FUNCTIONS FOR TEST DATA GENERATION
  # ==========================================

  defp tenant_id_generator do
    PC.oneof([
      "geographic_tenant_001",
      "mapping_services_002",
      "spatial_analytics_003",
      "location_intelligence_004",
      "geospatial_enterprise_005"
    ])
  end

  defp spatial_data_points_generator do
    PC.list(
      Indrajaal.PropCheckHelpers.fixed_map(%{
        lat: PC.float(-90.0, 90.0),
        lng: PC.float(-180.0, 180.0),
        intensity: PC.float(0.0, 100.0),
        category:
          PC.oneof([
            "high_activity",
            "medium_activity",
            "low_activity",
            "critical_zone",
            "safe_zone"
          ]),
        timestamp: datetime_generator()
      })
    )
  end

  defp heat_map_config_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      type: PC.oneof(@heat_map_types),
      algorithm: PC.oneof(@intensity_algorithms),
      resolution: PC.oneof([:low, :medium, :high, :ultra_high]),
      geographic_projection: PC.oneof(@geographic_projections),
      smoothing_factor: PC.float(0.1, 2.0)
    })
  end

  defp visualization_params_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      format: PC.oneof(@visualization_formats),
      color_scheme: PC.oneof([:viridis, :plasma, :inferno, :magma, :security_gradient]),
      include_legend: PC.boolean(),
      width: PC.integer(400, 2000),
      height: PC.integer(300, 1500),
      interactive: PC.boolean()
    })
  end

  defp geographic_data_points_generator do
    PC.list(
      Indrajaal.PropCheckHelpers.fixed_map(%{
        # Continental US bounds
        lat: PC.float(25.0, 49.0),
        lng: PC.float(-125.0, -66.0),
        intensity: PC.float(0.0, 100.0),
        category: PC.utf8(),
        weight: PC.float(0.1, 2.0)
      })
    )
  end

  defp intensity_algorithm_config_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      algorithm: PC.oneof(@intensity_algorithms),
      bandwidth: PC.float(0.01, 0.2),
      decay_factor: PC.float(0.1, 1.0),
      edge_correction: PC.boolean(),
      normalization: PC.oneof([:none, :standard, :min_max, :z_score])
    })
  end

  defp grid_resolution_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      width: PC.integer(50, 500),
      height: PC.integer(50, 500),
      precision: PC.oneof([:low, :medium, :high, :ultra_high])
    })
  end

  defp clustering_config_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      method: PC.oneof(@clustering_methods),
      epsilon: PC.float(0.005, 0.1),
      min_points: PC.integer(2, 10),
      distance_metric: PC.oneof([:euclidean, :haversine, :manhattan, :chebyshev])
    })
  end

  defp spatial_analysis_params_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      identify_hotspots: PC.boolean(),
      outlier_detection: PC.boolean(),
      cluster_validation: PC.boolean(),
      statistical_significance: PC.float(0.01, 0.1),
      spatial_autocorrelation: PC.boolean()
    })
  end

  defp temporal_spatial_data_generator do
    PC.list(
      Indrajaal.PropCheckHelpers.fixed_map(%{
        lat: PC.float(25.0, 49.0),
        lng: PC.float(-125.0, -66.0),
        intensity: PC.float(0.0, 100.0),
        timestamp: datetime_generator(),
        category: PC.utf8()
      })
    )
  end

  defp time_series_config_generator do
    # 30 days ago
    start_time = DateTime.add(DateTime.utc_now(), -86_400 * 30, :second)
    end_time = DateTime.utc_now()

    Indrajaal.PropCheckHelpers.fixed_map(%{
      start_time: SD.constant(start_time),
      end_time: SD.constant(end_time),
      time_resolution: PC.oneof([:hourly, :daily, :weekly, :monthly]),
      interpolation_method:
        PC.oneof([:linear, :cubic_spline, :nearest_neighbor, :weighted_average])
    })
  end

  defp animation_params_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      frame_rate: PC.integer(1, 30),
      transition_duration: PC.integer(100, 2000),
      loop_animation: PC.boolean(),
      include_controls: PC.boolean(),
      progressive_loading: PC.boolean()
    })
  end

  defp datetime_generator do
    # Generate datetime within last year for realistic testing
    # 1 year ago
    start_date = DateTime.add(DateTime.utc_now(), -365 * 24 * 3600, :second)
    end_date = DateTime.utc_now()

    seconds_diff = DateTime.diff(end_date, start_date, :second)
    random_seconds = :rand.uniform(seconds_diff)

    DateTime.add(start_date, random_seconds, :second)
  end
end
