defmodule Indrajaal.Observability.Domains.AccessControlInstrumentationTest do
  @moduledoc """
  Tests for AccessControlInstrumentation module.
  Tests focus on instrumentation setup and telemetry handler configuration.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.AccessControlInstrumentation
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

      if String.contains?(handler_id_str, "access-control") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = AccessControlInstrumentation.setup()

      assert result == :ok
    end

    test "attaches handlers successfully" do
      assert :ok = AccessControlInstrumentation.setup()
    end

    test "can be called multiple times safely" do
      assert :ok = AccessControlInstrumentation.setup()
      assert :ok = AccessControlInstrumentation.setup()
    end
  end

  describe "telemetry event handlers" do
    test "handles create event without raising" do
      AccessControlInstrumentation.setup()

      # Emit create event
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :create, :start],
          %{system_time: System.system_time()},
          %{resource_type: :access_credential}
        )
      end)
    end

    test "handles update event without raising" do
      AccessControlInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :update, :stop],
          %{duration: 1000},
          %{resource_type: :access_rule, success: true}
        )
      end)
    end

    test "handles read event without raising" do
      AccessControlInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :read, :stop],
          %{duration: 500},
          %{resource_type: :access_level, count: 10}
        )
      end)
    end

    test "handles security access_granted event" do
      AccessControlInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :security, :access_granted],
          %{timestamp: System.monotonic_time()},
          %{credential_id: "12_345", reader_id: "front_door"}
        )
      end)
    end

    test "handles security access_denied event" do
      AccessControlInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :security, :access_denied],
          %{timestamp: System.monotonic_time()},
          %{credential_id: "99_999", denial_reason: "invalid_credential"}
        )
      end)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: handler attachment does not block" do
      {time, result} =
        :timer.tc(fn ->
          AccessControlInstrumentation.setup()
        end)

      assert result == :ok
      # Should complete within 100ms
      assert time < 100_000
    end

    test "SC2: handles invalid measurements gracefully" do
      AccessControlInstrumentation.setup()

      # Should not raise with invalid measurements
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :create, :stop],
          %{},
          %{}
        )
      end)
    end

    test "SC3: handles missing metadata gracefully" do
      AccessControlInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :access_control, :read, :start],
          %{system_time: System.system_time()},
          %{}
        )
      end)
    end
  end
end
