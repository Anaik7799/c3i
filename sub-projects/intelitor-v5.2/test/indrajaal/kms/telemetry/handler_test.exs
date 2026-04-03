defmodule Indrajaal.KMS.Telemetry.HandlerTest do
  @moduledoc """
  Tests for Indrajaal.KMS.Telemetry.Handler.

  Covers:
  - Module existence and public API surface
  - setup/0 — attaches telemetry handlers (idempotent)
  - handle_event/4 — all dispatch clauses:
    - [:smriti, :health, :check] with %{status: status} metadata
    - generic catch-all clause with any event

  STAMP: SC-SMRITI-023 (KMS telemetry), SC-OBS-069 (dual log)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Telemetry.Handler

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Handler)
    end

    test "exports setup/0" do
      assert function_exported?(Handler, :setup, 0)
    end

    test "exports handle_event/4" do
      assert function_exported?(Handler, :handle_event, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # setup/0
  # ---------------------------------------------------------------------------

  describe "setup/0" do
    test "returns :ok" do
      # setup/0 calls :telemetry.attach_many — may already be attached
      result = Handler.setup()
      # :telemetry.attach_many returns :ok on first call, {:error, :already_exists} on repeat
      assert result == :ok or match?({:error, :already_exists}, result)
    end

    test "calling setup/0 twice does not raise" do
      Handler.setup()
      # Second call may fail with :already_exists but must not raise
      result = Handler.setup()
      assert result == :ok or match?({:error, :already_exists}, result)
    end

    test "after setup, smriti-handler is registered with telemetry" do
      Handler.setup()
      handlers = :telemetry.list_handlers([:smriti, :health, :check])
      ids = Enum.map(handlers, & &1.id)
      assert "smriti-handler" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/4 — [:smriti, :health, :check]
  # ---------------------------------------------------------------------------

  describe "handle_event/4 — health check clause" do
    test "returns :ok for :healthy status" do
      result = Handler.handle_event([:smriti, :health, :check], %{}, %{status: :healthy}, nil)
      assert result == :ok
    end

    test "returns :ok for :degraded status" do
      result = Handler.handle_event([:smriti, :health, :check], %{}, %{status: :degraded}, nil)
      assert result == :ok
    end

    test "returns :ok for :critical status" do
      result = Handler.handle_event([:smriti, :health, :check], %{}, %{status: :critical}, nil)
      assert result == :ok
    end

    test "accepts non-nil measurements map" do
      result =
        Handler.handle_event(
          [:smriti, :health, :check],
          %{duration_us: 1234},
          %{status: :healthy},
          nil
        )

      assert result == :ok
    end

    test "accepts non-nil config argument" do
      result =
        Handler.handle_event(
          [:smriti, :health, :check],
          %{},
          %{status: :healthy},
          %{some: "config"}
        )

      assert result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/4 — generic catch-all clause
  # ---------------------------------------------------------------------------

  describe "handle_event/4 — generic catch-all clause" do
    test "handles [:smriti, :metrics] without raising" do
      result = Handler.handle_event([:smriti, :metrics], %{value: 42}, %{}, nil)
      assert result == :ok
    end

    test "handles [:smriti, :agent, :ooda_cycle] without raising" do
      result =
        Handler.handle_event(
          [:smriti, :agent, :ooda_cycle],
          %{duration_ms: 48},
          %{agent: :knowledge},
          nil
        )

      assert result == :ok
    end

    test "handles [:smriti, :immortality, :success] without raising" do
      result =
        Handler.handle_event([:smriti, :immortality, :success], %{}, %{phase: 4}, nil)

      assert result == :ok
    end

    test "handles arbitrary event name without raising" do
      result = Handler.handle_event([:any, :random, :event], %{x: 1}, %{y: 2}, nil)
      assert result == :ok
    end

    test "accepts empty measurements map" do
      result = Handler.handle_event([:smriti, :metrics], %{}, %{}, nil)
      assert result == :ok
    end

    test "accepts nil config" do
      result = Handler.handle_event([:smriti, :metrics], %{value: 0}, %{}, nil)
      assert result == :ok
    end
  end
end
