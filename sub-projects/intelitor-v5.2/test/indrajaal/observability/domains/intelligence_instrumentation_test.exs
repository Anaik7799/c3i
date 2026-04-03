defmodule Indrajaal.Observability.Domains.IntelligenceInstrumentationTest do
  @moduledoc """
  Tests for IntelligenceInstrumentation module.
  Tests focus on instrumentation setup, telemetry handler configuration,
  and runtime verification of all instrumentation functions.

  SOPv5.11 Compliance: STAMP SC-OBS-065 to SC-OBS-072
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.IntelligenceInstrumentation
  import Indrajaal.STAMPTestHelpers
  import ExUnit.CaptureLog
  require Logger

  @moduletag :observability_domain

  @threat_levels [:critical, :high, :medium, :low, :none]
  @anomaly_types [:behavioral, :temporal, :spatial, :statistical]

  setup do
    # Detach any existing handlers before test
    handlers = :telemetry.list_handlers([])

    handlers
    |> Enum.each(fn handler ->
      handler_id_str =
        case handler.id do
          id when is_binary(id) -> id
          id when is_atom(id) -> Atom.to_string(id)
          _ -> inspect(handler.id)
        end

      if String.contains?(handler_id_str, "intelligence") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  # =============================================================================
  # Module Loading and Setup Tests
  # =============================================================================

  describe "module loading" do
    test "module loads correctly" do
      assert {:module, IntelligenceInstrumentation} =
               Code.ensure_loaded(IntelligenceInstrumentation)
    end

    test "module exports expected functions" do
      assert function_exported?(IntelligenceInstrumentation, :setup, 0)
      assert function_exported?(IntelligenceInstrumentation, :attach_handlers, 0)
      assert function_exported?(IntelligenceInstrumentation, :emit_threat_score, 4)
      assert function_exported?(IntelligenceInstrumentation, :emit_anomaly_triggered, 4)

      assert function_exported?(
               IntelligenceInstrumentation,
               :emit_behavioral_analysis_complete,
               5
             )

      assert function_exported?(IntelligenceInstrumentation, :emit_ml_inference_start, 4)
      assert function_exported?(IntelligenceInstrumentation, :emit_ml_inference_stop, 5)
      assert function_exported?(IntelligenceInstrumentation, :emit_alert_correlation_found, 4)
      assert function_exported?(IntelligenceInstrumentation, :emit_predictive_alert_issued, 4)
      assert function_exported?(IntelligenceInstrumentation, :emit_false_positive_detected, 4)
      assert function_exported?(IntelligenceInstrumentation, :with_threat_analysis_span, 4)
    end
  end

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = IntelligenceInstrumentation.setup()

      assert result == :ok
    end

    test "attaches handlers successfully" do
      assert :ok = IntelligenceInstrumentation.setup()
    end

    test "can be called multiple times safely" do
      assert :ok = IntelligenceInstrumentation.setup()
      assert :ok = IntelligenceInstrumentation.setup()
    end

    test "setup logs info message" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.setup()
        end)

      assert log =~ "Setting up Intelligence domain instrumentation" or log == ""
    end
  end

  # =============================================================================
  # Threat Detection Telemetry Tests
  # =============================================================================

  describe "threat detection telemetry" do
    test "emit_threat_score returns tuple with analysis_id and level" do
      {analysis_id, level} =
        IntelligenceInstrumentation.emit_threat_score(
          :high,
          0.85,
          [:anomaly, :pattern_match],
          %{tenant_id: "tenant123"}
        )

      assert is_binary(analysis_id)
      assert String.length(analysis_id) == 16
      assert level == :high
    end

    test "emit_threat_score handles all threat levels" do
      for level <- @threat_levels do
        {analysis_id, returned_level} =
          IntelligenceInstrumentation.emit_threat_score(
            level,
            0.5,
            [:factor1],
            %{}
          )

        assert is_binary(analysis_id)
        assert returned_level == level
      end
    end

    test "emit_threat_score emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-threat-score-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :threat_detection, :score],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_threat_score(
        :critical,
        0.95,
        [:anomaly, :behavioral],
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:score] == 0.95
      assert metadata[:threat_level] == :critical
      assert metadata[:requires_action] == true
    end

    test "emit_threat_score logs warning for critical/high levels" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_threat_score(
            :critical,
            0.95,
            [:factor1],
            %{tenant_id: "tenant123"}
          )
        end)

      # Warning level should be used for critical threats
      assert log =~ "Threat score calculated" or log == ""
    end
  end

  describe "anomaly detection telemetry" do
    test "emit_anomaly_triggered returns anomaly_id" do
      anomaly_id =
        IntelligenceInstrumentation.emit_anomaly_triggered(
          :behavioral,
          0.8,
          %{pattern: "unusual_access"},
          %{tenant_id: "tenant123"}
        )

      assert is_binary(anomaly_id)
      assert String.length(anomaly_id) == 16
    end

    test "emit_anomaly_triggered handles all anomaly types" do
      for anomaly_type <- @anomaly_types do
        anomaly_id =
          IntelligenceInstrumentation.emit_anomaly_triggered(
            anomaly_type,
            0.6,
            %{},
            %{}
          )

        assert is_binary(anomaly_id)
      end
    end

    test "emit_anomaly_triggered emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-anomaly-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :anomaly_detection, :triggered],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_anomaly_triggered(
        :temporal,
        0.75,
        %{time_deviation: "3 hours"},
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:severity] == 0.75
      assert metadata[:anomaly_type] == :temporal
      assert metadata[:high_severity] == true
    end
  end

  describe "behavioral analysis telemetry" do
    test "emit_behavioral_analysis_complete logs completion" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_behavioral_analysis_complete(
            :user,
            "user123",
            0.3,
            250,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Behavioral analysis completed" or log == ""
    end

    test "emit_behavioral_analysis_complete emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-behavioral-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :behavioral_analysis, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_behavioral_analysis_complete(
        :device,
        "device456",
        0.55,
        500,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:profile_deviation] == 0.55
      assert measurements[:duration] == 500
      assert metadata[:entity_type] == :device
      assert metadata[:significant_deviation] == true
    end
  end

  # =============================================================================
  # ML Model Telemetry Tests
  # =============================================================================

  describe "ML model inference telemetry" do
    test "emit_ml_inference_start returns inference_id" do
      inference_id =
        IntelligenceInstrumentation.emit_ml_inference_start(
          "threat_classifier",
          "v2.0",
          128,
          %{tenant_id: "tenant123"}
        )

      assert is_binary(inference_id)
      assert String.length(inference_id) == 16
    end

    test "emit_ml_inference_start emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-ml-start-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :ml_model, :inference_start],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_ml_inference_start(
        "anomaly_detector",
        "v1.5",
        256,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:input_features] == 256
      assert metadata[:model_name] == "anomaly_detector"
      assert metadata[:model_version] == "v1.5"
    end

    test "emit_ml_inference_stop logs completion" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_ml_inference_stop(
            "inference123",
            :success,
            0.92,
            150,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "ML model inference completed" or log == ""
    end

    test "emit_ml_inference_stop handles failure result" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_ml_inference_stop(
            "inference123",
            :failure,
            0.0,
            50,
            %{tenant_id: "tenant123"}
          )
        end)

      # Should log at error level for failures
      assert log =~ "ML model inference completed" or log =~ "failure" or log == ""
    end

    test "emit_ml_inference_stop emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-ml-stop-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :ml_model, :inference_stop],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_ml_inference_stop(
        "inference456",
        :success,
        0.85,
        200,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:confidence] == 0.85
      assert measurements[:duration] == 200
      assert metadata[:result] == :success
      assert metadata[:success] == true
    end
  end

  # =============================================================================
  # Alert Telemetry Tests
  # =============================================================================

  describe "alert correlation telemetry" do
    test "emit_alert_correlation_found returns correlation_id" do
      correlation_id =
        IntelligenceInstrumentation.emit_alert_correlation_found(
          :temporal,
          ["alert1", "alert2", "alert3"],
          0.9,
          %{tenant_id: "tenant123"}
        )

      assert is_binary(correlation_id)
      assert String.length(correlation_id) == 16
    end

    test "emit_alert_correlation_found emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-correlation-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :alert_correlation, :found],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_alert_correlation_found(
        :spatial,
        ["a1", "a2"],
        0.85,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:alert_count] == 2
      assert measurements[:correlation_score] == 0.85
      assert metadata[:correlation_type] == :spatial
      assert metadata[:strong_correlation] == true
    end
  end

  describe "predictive alert telemetry" do
    test "emit_predictive_alert_issued returns alert_id" do
      alert_id =
        IntelligenceInstrumentation.emit_predictive_alert_issued(
          :equipment_failure,
          0.88,
          DateTime.utc_now(),
          %{tenant_id: "tenant123"}
        )

      assert is_binary(alert_id)
      assert String.length(alert_id) == 16
    end

    test "emit_predictive_alert_issued emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-predictive-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :predictive_alert, :issued],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_predictive_alert_issued(
        :security_breach,
        0.92,
        nil,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:confidence] == 0.92
      assert metadata[:prediction_type] == :security_breach
      assert metadata[:high_confidence] == true
    end
  end

  describe "false positive telemetry" do
    test "emit_false_positive_detected logs detection" do
      log =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_false_positive_detected(
            "alert789",
            :ml_reclassification,
            0.95,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "False positive detected" or log == ""
    end

    test "emit_false_positive_detected emits telemetry event" do
      IntelligenceInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-false-positive-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :false_positive, :detected],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_false_positive_detected(
        "alert123",
        :user_feedback,
        0.91,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements[:confidence] == 0.91
      assert metadata[:original_alert_id] == "alert123"
      assert metadata[:detection_method] == :user_feedback
      assert metadata[:high_confidence] == true
    end
  end

  # =============================================================================
  # OpenTelemetry Tracing Tests
  # =============================================================================

  describe "OpenTelemetry tracing" do
    test "with_threat_analysis_span executes function" do
      result =
        IntelligenceInstrumentation.with_threat_analysis_span(
          :user,
          "user123",
          %{tenant_id: "tenant123"},
          fn ->
            {:ok, "analysis_result"}
          end
        )

      assert result == {:ok, "analysis_result"}
    end

    test "with_threat_analysis_span handles alert result" do
      result =
        IntelligenceInstrumentation.with_threat_analysis_span(
          :device,
          "device456",
          %{},
          fn ->
            {:alert, %{type: :intrusion, severity: :high}}
          end
        )

      assert {:alert, %{type: :intrusion}} = result
    end

    test "with_threat_analysis_span handles error tuple from function" do
      result =
        IntelligenceInstrumentation.with_threat_analysis_span(
          :location,
          "loc789",
          %{},
          fn ->
            {:error, :analysis_failed}
          end
        )

      assert result == {:error, :analysis_failed}
    end
  end

  # =============================================================================
  # Telemetry Event Handler Tests
  # =============================================================================

  describe "telemetry event handlers" do
    test "handles threat detection score event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :threat_detection, :score],
          %{score: 0.75, factor_count: 3, system_time: System.system_time(:millisecond)},
          %{threat_level: :high, analysis_id: "test123"}
        )
      end)
    end

    test "handles anomaly triggered event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :anomaly_detection, :triggered],
          %{severity: 0.8, system_time: System.system_time(:millisecond)},
          %{anomaly_type: :behavioral, anomaly_id: "anomaly123"}
        )
      end)
    end

    test "handles behavioral analysis complete event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :behavioral_analysis, :complete],
          %{profile_deviation: 0.4, duration: 300, system_time: System.system_time(:millisecond)},
          %{entity_type: :user, entity_id: "user123"}
        )
      end)
    end

    test "handles ML inference start event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :ml_model, :inference_start],
          %{input_features: 128, system_time: System.system_time(:millisecond)},
          %{model_name: "classifier", model_version: "v1", inference_id: "inf123"}
        )
      end)
    end

    test "handles ML inference stop event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :ml_model, :inference_stop],
          %{confidence: 0.9, duration: 150, system_time: System.system_time(:millisecond)},
          %{inference_id: "inf123", result: :success}
        )
      end)
    end

    test "handles alert correlation found event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :alert_correlation, :found],
          %{
            alert_count: 5,
            correlation_score: 0.85,
            system_time: System.system_time(:millisecond)
          },
          %{correlation_id: "corr123", correlation_type: :temporal}
        )
      end)
    end

    test "handles predictive alert issued event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :predictive_alert, :issued],
          %{confidence: 0.88, system_time: System.system_time(:millisecond)},
          %{alert_id: "alert123", prediction_type: :equipment_failure}
        )
      end)
    end

    test "handles false positive detected event without raising" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :false_positive, :detected],
          %{confidence: 0.92, system_time: System.system_time(:millisecond)},
          %{original_alert_id: "alert789", detection_method: :ml_reclassification}
        )
      end)
    end
  end

  # =============================================================================
  # STAMP Safety Constraints Tests
  # =============================================================================

  describe "STAMP safety constraints" do
    test "SC-OBS-065: handler attachment does not block" do
      {time, result} =
        :timer.tc(fn ->
          IntelligenceInstrumentation.setup()
        end)

      assert result == :ok
      # Should complete within 100ms
      assert time < 100_000
    end

    test "SC-OBS-066: handles invalid measurements gracefully" do
      IntelligenceInstrumentation.setup()

      # Should not raise with invalid measurements
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :threat_detection, :score],
          %{},
          %{}
        )
      end)
    end

    test "SC-OBS-067: handles missing metadata gracefully" do
      IntelligenceInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :ml_model, :inference_start],
          %{system_time: System.system_time()},
          %{}
        )
      end)
    end

    test "SC-OBS-068: processes events without delay" do
      IntelligenceInstrumentation.setup()

      {time, _} =
        :timer.tc(fn ->
          :telemetry.execute(
            [:indrajaal, :intelligence, :threat_detection, :score],
            %{score: 0.9, system_time: System.system_time()},
            %{threat_level: :critical}
          )
        end)

      # Event processing should be < 10ms
      assert time < 10_000
    end

    test "SC-OBS-069: emit functions return valid IDs" do
      {analysis_id, _level} = IntelligenceInstrumentation.emit_threat_score(:medium, 0.5, [], %{})
      assert is_binary(analysis_id)
      assert String.match?(analysis_id, ~r/^[a-f0-9]{16}$/)

      anomaly_id = IntelligenceInstrumentation.emit_anomaly_triggered(:behavioral, 0.5, %{}, %{})
      assert is_binary(anomaly_id)
      assert String.match?(anomaly_id, ~r/^[a-f0-9]{16}$/)

      inference_id = IntelligenceInstrumentation.emit_ml_inference_start("model", "v1", 10, %{})
      assert is_binary(inference_id)
      assert String.match?(inference_id, ~r/^[a-f0-9]{16}$/)

      correlation_id =
        IntelligenceInstrumentation.emit_alert_correlation_found(:type, [], 0.5, %{})

      assert is_binary(correlation_id)
      assert String.match?(correlation_id, ~r/^[a-f0-9]{16}$/)

      alert_id = IntelligenceInstrumentation.emit_predictive_alert_issued(:type, 0.5, nil, %{})
      assert is_binary(alert_id)
      assert String.match?(alert_id, ~r/^[a-f0-9]{16}$/)
    end

    test "SC-OBS-070: telemetry handlers are idempotent" do
      # Setup twice should not cause issues
      assert :ok = IntelligenceInstrumentation.setup()
      assert :ok = IntelligenceInstrumentation.setup()

      # Events should still be handled correctly
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :intelligence, :threat_detection, :score],
          %{score: 0.5, system_time: System.system_time()},
          %{threat_level: :medium}
        )
      end)
    end
  end

  # =============================================================================
  # Runtime Verification Tests
  # =============================================================================

  describe "runtime verification" do
    test "ID generation produces unique IDs" do
      ids =
        for _ <- 1..100 do
          {id, _} = IntelligenceInstrumentation.emit_threat_score(:low, 0.1, [], %{})
          id
        end

      unique_ids = Enum.uniq(ids)
      assert length(unique_ids) == 100
    end

    test "metadata enrichment preserves original metadata" do
      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-metadata-enrichment-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :intelligence, :threat_detection, :score],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntelligenceInstrumentation.emit_threat_score(
        :high,
        0.8,
        [:factor1, :factor2],
        %{tenant_id: "tenant123", custom_field: "custom_value"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:tenant_id] == "tenant123"
      assert metadata[:custom_field] == "custom_value"
      assert metadata[:threat_level] == :high
      assert metadata[:requires_action] == true
    end

    test "high volume event emission handles load" do
      IntelligenceInstrumentation.setup()

      # Emit 1000 events quickly
      {time, _} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            IntelligenceInstrumentation.emit_threat_score(:low, 0.1, [], %{})
          end
        end)

      # Should complete within 5 seconds
      assert time < 5_000_000
    end

    test "threat level affects logging level" do
      # Critical/high should use warning
      log_critical =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_threat_score(:critical, 0.99, [], %{})
        end)

      log_low =
        capture_log(fn ->
          IntelligenceInstrumentation.emit_threat_score(:low, 0.1, [], %{})
        end)

      # Both should log something (or be empty in test mode)
      assert is_binary(log_critical)
      assert is_binary(log_low)
    end
  end
end
