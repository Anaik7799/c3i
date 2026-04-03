defmodule Indrajaal.Observability.Domains.AccountsInstrumentationTest do
  @moduledoc """
  Tests for AccountsInstrumentation module.
  Tests focus on instrumentation setup and telemetry handler configuration.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.AccountsInstrumentation
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

      if String.contains?(handler_id_str, "accounts") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = AccountsInstrumentation.setup()

      assert result == :ok
    end

    test "attaches handlers successfully" do
      assert :ok = AccountsInstrumentation.setup()
    end

    test "can be called multiple times safely" do
      assert :ok = AccountsInstrumentation.setup()
      assert :ok = AccountsInstrumentation.setup()
    end
  end

  describe "telemetry event handlers" do
    test "handles create event without raising" do
      AccountsInstrumentation.setup()

      # Emit create event
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :create, :start],
          %{system_time: System.system_time()},
          %{resource_type: :user}
        )
      end)
    end

    test "handles update event without raising" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :update, :stop],
          %{duration: 1000},
          %{resource_type: :user, success: true}
        )
      end)
    end

    test "handles read event without raising" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :read, :stop],
          %{duration: 500},
          %{resource_type: :user, count: 10}
        )
      end)
    end

    test "handles authentication login_attempt event" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :authentication, :login_attempt],
          %{timestamp: System.monotonic_time()},
          %{email: "user@example.com", ip_address: "10.0.0.1"}
        )
      end)
    end

    test "handles authentication login_success event" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :authentication, :login_success],
          %{login_time_ms: 150},
          %{user_id: "user123", session_id: "session456"}
        )
      end)
    end

    test "handles authentication login_failure event" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :authentication, :login_failure],
          %{attempt_number: 1},
          %{email: "user@example.com", failure_reason: "invalid_credentials"}
        )
      end)
    end

    test "handles security password_change event" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :security, :password_change],
          %{complexity_score: 85},
          %{user_id: "user123", change_reason: "user_requested"}
        )
      end)
    end

    test "handles security mfa_enabled event" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :security, :mfa_enabled],
          %{setup_time_seconds: 45},
          %{user_id: "user123", mfa_type: "totp"}
        )
      end)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: handler attachment does not block" do
      {time, result} =
        :timer.tc(fn ->
          AccountsInstrumentation.setup()
        end)

      assert result == :ok
      # Should complete within 100ms
      assert time < 100_000
    end

    test "SC2: handles invalid measurements gracefully" do
      AccountsInstrumentation.setup()

      # Should not raise with invalid measurements
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :create, :stop],
          %{},
          %{}
        )
      end)
    end

    test "SC3: handles missing metadata gracefully" do
      AccountsInstrumentation.setup()

      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :accounts, :read, :start],
          %{system_time: System.system_time()},
          %{}
        )
      end)
    end
  end
end
