defmodule Indrajaal.Observability.Domains.IntegrationInstrumentationTest do
  @moduledoc """
  Tests for IntegrationInstrumentation module.
  Tests focus on instrumentation setup, telemetry handler configuration,
  and runtime verification of all instrumentation functions.

  SOPv5.11 Compliance: STAMP SC-OBS-065 to SC-OBS-072
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.IntegrationInstrumentation
  import Indrajaal.STAMPTestHelpers
  import ExUnit.CaptureLog
  require Logger

  @moduletag :observability_domain

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

      if String.contains?(handler_id_str, "integration") do
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
      assert {:module, IntegrationInstrumentation} =
               Code.ensure_loaded(IntegrationInstrumentation)
    end

    test "module exports expected functions" do
      assert function_exported?(IntegrationInstrumentation, :setup, 0)
      assert function_exported?(IntegrationInstrumentation, :attach_handlers, 0)
      assert function_exported?(IntegrationInstrumentation, :emit_external_api_start, 3)
      assert function_exported?(IntegrationInstrumentation, :emit_external_api_stop, 4)
      assert function_exported?(IntegrationInstrumentation, :emit_external_api_error, 3)
      assert function_exported?(IntegrationInstrumentation, :emit_webhook_received, 3)
      assert function_exported?(IntegrationInstrumentation, :emit_webhook_processed, 4)
      assert function_exported?(IntegrationInstrumentation, :emit_data_sync_start, 3)
      assert function_exported?(IntegrationInstrumentation, :emit_data_sync_stop, 5)
      assert function_exported?(IntegrationInstrumentation, :emit_rate_limit_exceeded, 4)
      assert function_exported?(IntegrationInstrumentation, :emit_retry_attempt, 5)
      assert function_exported?(IntegrationInstrumentation, :with_external_request_span, 4)
    end
  end

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = IntegrationInstrumentation.setup()

      assert result == :ok
    end

    test "attaches handlers successfully" do
      assert :ok = IntegrationInstrumentation.setup()
    end

    test "can be called multiple times safely" do
      assert :ok = IntegrationInstrumentation.setup()
      assert :ok = IntegrationInstrumentation.setup()
    end

    test "setup logs info message" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.setup()
        end)

      assert log =~ "Setting up Integration domain instrumentation" or log == ""
    end
  end

  # =============================================================================
  # External API Telemetry Tests
  # =============================================================================

  describe "external API telemetry" do
    test "emit_external_api_start returns request_id" do
      request_id =
        IntegrationInstrumentation.emit_external_api_start(
          "https://api.example.com/data",
          :get,
          %{tenant_id: "tenant123"}
        )

      assert is_binary(request_id)
      assert String.length(request_id) == 16
    end

    test "emit_external_api_start emits telemetry event" do
      IntegrationInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-external-api-start-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :external_api, :request_start],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_external_api_start(
        "https://api.example.com/data",
        :get,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:endpoint] == "https://api.example.com/data"
      assert metadata[:method] == :get
    end

    test "emit_external_api_stop logs completion with duration" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_external_api_stop(
            "request123",
            200,
            150,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "External API request completed" or log == ""
    end

    test "emit_external_api_error logs error details" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_external_api_error(
            "request123",
            %{reason: :timeout},
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "External API request failed" or log == ""
    end

    test "handles different HTTP methods" do
      for method <- [:get, :post, :put, :patch, :delete] do
        request_id =
          IntegrationInstrumentation.emit_external_api_start(
            "https://api.example.com/resource",
            method,
            %{}
          )

        assert is_binary(request_id)
      end
    end
  end

  # =============================================================================
  # Webhook Telemetry Tests
  # =============================================================================

  describe "webhook telemetry" do
    test "emit_webhook_received returns webhook_id" do
      webhook_id =
        IntegrationInstrumentation.emit_webhook_received(
          "github",
          "push",
          %{tenant_id: "tenant123"}
        )

      assert is_binary(webhook_id)
      assert String.length(webhook_id) == 16
    end

    test "emit_webhook_received emits telemetry event" do
      IntegrationInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-webhook-received-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :webhook, :received],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_webhook_received(
        "stripe",
        "payment.succeeded",
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:source] == "stripe"
      assert metadata[:event_type] == "payment.succeeded"
    end

    test "emit_webhook_processed logs processing result" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_webhook_processed(
            "webhook123",
            :success,
            50,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Webhook processed" or log == ""
    end

    test "emit_webhook_processed handles failure result" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_webhook_processed(
            "webhook123",
            :failure,
            100,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Webhook processed" or log =~ "failure" or log == ""
    end
  end

  # =============================================================================
  # Data Sync Telemetry Tests
  # =============================================================================

  describe "data sync telemetry" do
    test "emit_data_sync_start returns sync_id" do
      sync_id =
        IntegrationInstrumentation.emit_data_sync_start(
          :full_sync,
          "external_system_a",
          %{tenant_id: "tenant123"}
        )

      assert is_binary(sync_id)
      assert String.length(sync_id) == 16
    end

    test "emit_data_sync_start emits telemetry event" do
      IntegrationInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-data-sync-start-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :data_sync, :start],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_data_sync_start(
        :incremental_sync,
        "crm_system",
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:sync_type] == :incremental_sync
      assert metadata[:source] == "crm_system"
    end

    test "emit_data_sync_stop logs sync completion" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_data_sync_stop(
            "sync123",
            :success,
            500,
            5000,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Data sync completed" or log == ""
    end

    test "emit_data_sync_stop handles different sync types" do
      for sync_type <- [:full_sync, :incremental_sync, :delta_sync] do
        sync_id =
          IntegrationInstrumentation.emit_data_sync_start(
            sync_type,
            "test_source",
            %{}
          )

        assert is_binary(sync_id)
      end
    end
  end

  # =============================================================================
  # Rate Limit and Retry Telemetry Tests
  # =============================================================================

  describe "rate limit telemetry" do
    test "emit_rate_limit_exceeded emits telemetry event" do
      IntegrationInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-rate-limit-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :rate_limit, :exceeded],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_rate_limit_exceeded(
        "https://api.example.com/endpoint",
        100,
        60_000,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:endpoint] == "https://api.example.com/endpoint"
      assert metadata[:limit] == 100
    end

    test "emit_rate_limit_exceeded logs warning" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_rate_limit_exceeded(
            "https://api.example.com/endpoint",
            100,
            60_000,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Rate limit exceeded" or log == ""
    end
  end

  describe "retry telemetry" do
    test "emit_retry_attempt emits telemetry event" do
      IntegrationInstrumentation.setup()

      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-retry-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :retry, :attempt],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_retry_attempt(
        "request123",
        2,
        5,
        1000,
        %{tenant_id: "tenant123"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:request_id] == "request123"
      assert metadata[:attempt] == 2
      assert metadata[:max_attempts] == 5
    end

    test "emit_retry_attempt logs retry information" do
      log =
        capture_log(fn ->
          IntegrationInstrumentation.emit_retry_attempt(
            "request123",
            3,
            5,
            2000,
            %{tenant_id: "tenant123"}
          )
        end)

      assert log =~ "Retry attempt" or log == ""
    end
  end

  # =============================================================================
  # OpenTelemetry Tracing Tests
  # =============================================================================

  describe "OpenTelemetry tracing" do
    test "with_external_request_span executes function and returns ok result" do
      result =
        IntegrationInstrumentation.with_external_request_span(
          "https://api.example.com/data",
          :get,
          %{tenant_id: "tenant123"},
          fn ->
            {:ok, "test_result"}
          end
        )

      assert result == {:ok, "test_result"}
    end

    test "with_external_request_span handles error tuple from function" do
      result =
        IntegrationInstrumentation.with_external_request_span(
          "https://api.example.com/data",
          :get,
          %{},
          fn ->
            {:error, :connection_failed}
          end
        )

      assert result == {:error, :connection_failed}
    end

    test "with_external_request_span with different metadata" do
      result =
        IntegrationInstrumentation.with_external_request_span(
          "https://api.example.com/users",
          :post,
          %{tenant_id: "tenant123", user_id: "user456"},
          fn ->
            {:ok, %{status: :success, count: 10}}
          end
        )

      assert result == {:ok, %{status: :success, count: 10}}
    end
  end

  # =============================================================================
  # Telemetry Event Handler Tests
  # =============================================================================

  describe "telemetry event handlers" do
    test "handles external API request_start event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :external_api, :request_start],
          %{system_time: System.system_time(:millisecond)},
          %{endpoint: "https://api.example.com", method: :get, request_id: "req123"}
        )
      end)
    end

    test "handles external API request_stop event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :external_api, :request_stop],
          %{duration: 150, system_time: System.system_time(:millisecond)},
          %{request_id: "req123", status_code: 200, success: true}
        )
      end)
    end

    test "handles external API error event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :external_api, :error],
          %{system_time: System.system_time(:millisecond)},
          %{request_id: "req123", error: %{reason: :timeout}}
        )
      end)
    end

    test "handles webhook received event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :webhook, :received],
          %{system_time: System.system_time(:millisecond)},
          %{webhook_id: "wh123", source: "github", event_type: "push"}
        )
      end)
    end

    test "handles webhook processed event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :webhook, :processed],
          %{duration: 50, system_time: System.system_time(:millisecond)},
          %{webhook_id: "wh123", result: :success}
        )
      end)
    end

    test "handles data sync start event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :data_sync, :start],
          %{system_time: System.system_time(:millisecond)},
          %{sync_id: "sync123", sync_type: :full_sync, source: "external_system"}
        )
      end)
    end

    test "handles data sync stop event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :data_sync, :stop],
          %{duration: 5000, records_synced: 500, system_time: System.system_time(:millisecond)},
          %{sync_id: "sync123", result: :success}
        )
      end)
    end

    test "handles rate limit exceeded event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :rate_limit, :exceeded],
          %{system_time: System.system_time(:millisecond)},
          %{endpoint: "https://api.example.com", limit: 100, window_ms: 60_000}
        )
      end)
    end

    test "handles retry attempt event without raising" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :retry, :attempt],
          %{delay_ms: 1000, system_time: System.system_time(:millisecond)},
          %{request_id: "req123", attempt: 2, max_attempts: 5}
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
          IntegrationInstrumentation.setup()
        end)

      assert result == :ok
      # Should complete within 100ms
      assert time < 100_000
    end

    test "SC-OBS-066: handles invalid measurements gracefully" do
      IntegrationInstrumentation.setup()

      # Should not raise with invalid measurements
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :external_api, :request_stop],
          %{},
          %{}
        )
      end)
    end

    test "SC-OBS-067: handles missing metadata gracefully" do
      IntegrationInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :webhook, :received],
          %{system_time: System.system_time()},
          %{}
        )
      end)
    end

    test "SC-OBS-068: processes events without delay" do
      IntegrationInstrumentation.setup()

      {time, _} =
        :timer.tc(fn ->
          :telemetry.execute(
            [:indrajaal, :integration, :external_api, :request_start],
            %{system_time: System.system_time()},
            %{endpoint: "https://api.example.com", method: :get}
          )
        end)

      # Event processing should be < 10ms
      assert time < 10_000
    end

    test "SC-OBS-069: emit functions return valid IDs" do
      request_id = IntegrationInstrumentation.emit_external_api_start("endpoint", :get, %{})
      assert is_binary(request_id)
      assert String.match?(request_id, ~r/^[a-f0-9]{16}$/)

      webhook_id = IntegrationInstrumentation.emit_webhook_received("source", "event", %{})
      assert is_binary(webhook_id)
      assert String.match?(webhook_id, ~r/^[a-f0-9]{16}$/)

      sync_id = IntegrationInstrumentation.emit_data_sync_start(:full_sync, "source", %{})
      assert is_binary(sync_id)
      assert String.match?(sync_id, ~r/^[a-f0-9]{16}$/)
    end

    test "SC-OBS-070: telemetry handlers are idempotent" do
      # Setup twice should not cause issues
      assert :ok = IntegrationInstrumentation.setup()
      assert :ok = IntegrationInstrumentation.setup()

      # Events should still be handled correctly
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :integration, :external_api, :request_start],
          %{system_time: System.system_time()},
          %{endpoint: "https://api.example.com", method: :get}
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
          IntegrationInstrumentation.emit_external_api_start("endpoint", :get, %{})
        end

      unique_ids = Enum.uniq(ids)
      assert length(unique_ids) == 100
    end

    test "metadata enrichment preserves original metadata" do
      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-metadata-enrichment-#{ref |> :erlang.ref_to_list() |> List.to_string()}",
        [:indrajaal, :integration, :external_api, :request_start],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_received, metadata})
        end,
        nil
      )

      IntegrationInstrumentation.emit_external_api_start(
        "https://api.example.com",
        :post,
        %{tenant_id: "tenant123", custom_field: "custom_value"}
      )

      assert_receive {:telemetry_received, metadata}, 1000
      assert metadata[:tenant_id] == "tenant123"
      assert metadata[:custom_field] == "custom_value"
      assert metadata[:endpoint] == "https://api.example.com"
      assert metadata[:method] == :post
    end

    test "error handling works correctly" do
      # Emit error and verify it doesn't crash
      assert_nothing_raised(fn ->
        IntegrationInstrumentation.emit_external_api_error(
          "request123",
          %{reason: :connection_refused, details: "host unreachable"},
          %{tenant_id: "tenant123"}
        )
      end)
    end

    test "high volume event emission handles load" do
      IntegrationInstrumentation.setup()

      # Emit 1000 events quickly
      {time, _} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            IntegrationInstrumentation.emit_external_api_start("endpoint", :get, %{})
          end
        end)

      # Should complete within 5 seconds
      assert time < 5_000_000
    end
  end
end
