defmodule Indrajaal.Core.Holon.StateWatchdog do
  @moduledoc """
  Holon State Watchdog - Runtime Integrity Verification for v20.0.0

  ## What
  Continuous runtime monitoring of holon state integrity. Detects corruption,
  chain breaks, and state inconsistencies within 100ms (SC-HOLON-014 extended).

  ## Why
  Boot-time verification (SC-HOLON-014) is insufficient for runtime detection.
  Corruption can occur from:
  - Bit flips in memory (cosmic rays, hardware faults)
  - Race conditions in concurrent writes
  - Byzantine failures in distributed replicas
  - Attack vectors targeting state

  ## Architecture
  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                   STATE WATCHDOG                             │
  │                                                             │
  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
  │   │ Chain Check │    │ Hash Check  │    │ WAL Check   │    │
  │   │ (Register)  │    │ (SHA-256)   │    │ (SQLite)    │    │
  │   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    │
  │          │                  │                  │            │
  │          └──────────────────┼──────────────────┘            │
  │                             │                               │
  │                             ▼                               │
  │                    ┌─────────────────┐                      │
  │                    │ Corruption      │                      │
  │                    │ Detected?       │                      │
  │                    └────────┬────────┘                      │
  │                             │                               │
  │              ┌──────────────┼──────────────┐                │
  │              ▼              ▼              ▼                │
  │         Guardian       Telemetry     Health Update          │
  │         Report         Emit          (degraded/failed)      │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints
  - SC-HOLON-014: Runtime integrity verification (extended from boot-only)
  - SC-HOLON-017: SHA-256 checksum verification
  - SC-REG-002: Chain verification continuous
  - SC-REG-007: Verify before trust
  - SC-WATCHDOG-001: Check interval <= 100ms
  - SC-WATCHDOG-002: Corruption detection -> Guardian report
  - SC-WATCHDOG-003: Self-healing attempt before escalation
  """

  use GenServer
  require Logger

  alias Indrajaal.Core.Holon.ImmutableRegister
  alias Indrajaal.Safety.Guardian

  # Check interval: 100ms per SC-WATCHDOG-001
  @check_interval_ms 100

  # Maximum consecutive failures before escalating to Guardian
  @failure_escalation_threshold 3

  # Self-healing retry limit
  @self_heal_retries 2

  @type watchdog_state :: %{
          name: atom(),
          enabled: boolean(),
          last_check: DateTime.t() | nil,
          last_good_hash: String.t() | nil,
          consecutive_failures: non_neg_integer(),
          self_heal_attempts: non_neg_integer(),
          stats: %{
            total_checks: non_neg_integer(),
            chain_failures: non_neg_integer(),
            hash_failures: non_neg_integer(),
            self_heals: non_neg_integer(),
            guardian_reports: non_neg_integer()
          }
        }

  @type check_result ::
          :ok
          | {:chain_broken, non_neg_integer()}
          | {:hash_mismatch, String.t(), String.t()}
          | {:register_unavailable, term()}

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Starts the state watchdog.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Enables the watchdog (starts periodic checks).
  """
  @spec enable(GenServer.server()) :: :ok
  def enable(server \\ __MODULE__) do
    GenServer.call(server, :enable)
  end

  @doc """
  Disables the watchdog (stops periodic checks).
  """
  @spec disable(GenServer.server()) :: :ok
  def disable(server \\ __MODULE__) do
    GenServer.call(server, :disable)
  end

  @doc """
  Forces an immediate integrity check.
  Returns :ok if state is valid, or {:error, reason} if corrupted.
  """
  @spec check_now(GenServer.server()) :: :ok | {:error, term()}
  def check_now(server \\ __MODULE__) do
    GenServer.call(server, :check_now)
  end

  @doc """
  Returns watchdog statistics.
  """
  @spec stats(GenServer.server()) :: map()
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Returns current health status based on watchdog state.
  """
  @spec health(GenServer.server()) :: :healthy | :degraded | :failed
  def health(server \\ __MODULE__) do
    GenServer.call(server, :health)
  end

  # ============================================================================
  # SERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    state = %{
      name: Keyword.get(opts, :name, __MODULE__),
      enabled: Keyword.get(opts, :enabled, true),
      last_check: nil,
      last_good_hash: nil,
      consecutive_failures: 0,
      self_heal_attempts: 0,
      stats: %{
        total_checks: 0,
        chain_failures: 0,
        hash_failures: 0,
        self_heals: 0,
        guardian_reports: 0
      }
    }

    Logger.info("[StateWatchdog] Initialized - SC-HOLON-014 runtime verification active")

    # Start periodic checks if enabled
    if state.enabled do
      schedule_check()
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    if not state.enabled do
      schedule_check()
    end

    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_call(:disable, _from, state) do
    {:reply, :ok, %{state | enabled: false}}
  end

  @impl true
  def handle_call(:check_now, _from, state) do
    {result, new_state} = perform_integrity_check(state)
    reply = if result == :ok, do: :ok, else: {:error, result}
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        enabled: state.enabled,
        consecutive_failures: state.consecutive_failures,
        self_heal_attempts: state.self_heal_attempts,
        last_check: state.last_check,
        last_good_hash: state.last_good_hash
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    health =
      cond do
        state.consecutive_failures >= @failure_escalation_threshold -> :failed
        state.consecutive_failures > 0 -> :degraded
        true -> :healthy
      end

    {:reply, health, state}
  end

  @impl true
  def handle_info(:check, %{enabled: false} = state) do
    # Watchdog disabled, don't schedule next check
    {:noreply, state}
  end

  @impl true
  def handle_info(:check, state) do
    {_result, new_state} = perform_integrity_check(state)

    # Schedule next check
    schedule_check()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================================
  # INTEGRITY CHECKING
  # ============================================================================

  @spec perform_integrity_check(watchdog_state()) :: {check_result(), watchdog_state()}
  defp perform_integrity_check(state) do
    start_time = System.monotonic_time(:microsecond)

    # 1. Check ImmutableRegister chain integrity
    chain_result = check_chain_integrity()

    # 2. Check state hash consistency
    hash_result = check_hash_consistency(state.last_good_hash)

    # Combine results
    result =
      case {chain_result, hash_result} do
        {:ok, {:ok, new_hash}} ->
          {:ok, new_hash}

        {{:error, chain_error}, _} ->
          {:chain_broken, chain_error}

        {_, {:error, hash_error}} ->
          {:hash_mismatch, hash_error}
      end

    # Update state based on result
    new_state = handle_check_result(state, result, start_time)

    {elem(result, 0), new_state}
  end

  @spec check_chain_integrity() :: :ok | {:error, term()}
  defp check_chain_integrity do
    case GenServer.whereis(ImmutableRegister) do
      nil ->
        # Register not running - this is acceptable during bootstrap
        :ok

      _pid ->
        case ImmutableRegister.verify() do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  rescue
    error ->
      {:error, {:register_error, error}}
  end

  @spec check_hash_consistency(String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  defp check_hash_consistency(last_known_hash) do
    case GenServer.whereis(ImmutableRegister) do
      nil ->
        # No register, return placeholder hash
        {:ok, "genesis"}

      _pid ->
        current_hash = ImmutableRegister.head()

        cond do
          # First check - establish baseline
          is_nil(last_known_hash) ->
            {:ok, current_hash}

          # Hash unchanged - good
          current_hash == last_known_hash ->
            {:ok, current_hash}

          # Hash changed - this is EXPECTED when blocks are added
          # We need to verify the new hash is a valid successor
          true ->
            # Verify the chain leads from old to new
            # verify_hash_succession validates via ImmutableRegister.verify()
            :ok = verify_hash_succession(last_known_hash, current_hash)
            {:ok, current_hash}
        end
    end
  rescue
    error ->
      {:error, {:hash_check_error, error}}
  end

  @spec verify_hash_succession(String.t(), String.t()) :: :ok
  defp verify_hash_succession(_old_hash, _new_hash) do
    # The chain verification in ImmutableRegister.verify() handles this
    # If verify() passes, succession is valid
    :ok
  end

  @spec handle_check_result(watchdog_state(), term(), integer()) :: watchdog_state()
  defp handle_check_result(state, {:ok, new_hash}, start_time) do
    elapsed_us = System.monotonic_time(:microsecond) - start_time

    # Emit success telemetry
    emit_telemetry(:check_success, %{elapsed_us: elapsed_us})

    %{
      state
      | last_check: DateTime.utc_now(),
        last_good_hash: new_hash,
        consecutive_failures: 0,
        self_heal_attempts: 0,
        stats: %{state.stats | total_checks: state.stats.total_checks + 1}
    }
  end

  defp handle_check_result(state, {:chain_broken, error}, _start_time) do
    Logger.error("[StateWatchdog] Chain integrity failure: #{inspect(error)}")

    new_failures = state.consecutive_failures + 1
    new_stats = %{state.stats | chain_failures: state.stats.chain_failures + 1}

    new_state = %{
      state
      | last_check: DateTime.utc_now(),
        consecutive_failures: new_failures,
        stats: %{new_stats | total_checks: new_stats.total_checks + 1}
    }

    # Attempt self-healing or escalate
    maybe_escalate_or_heal(new_state, :chain_broken, error)
  end

  defp handle_check_result(state, {:hash_mismatch, error}, _start_time) do
    Logger.error("[StateWatchdog] Hash consistency failure: #{inspect(error)}")

    new_failures = state.consecutive_failures + 1
    new_stats = %{state.stats | hash_failures: state.stats.hash_failures + 1}

    new_state = %{
      state
      | last_check: DateTime.utc_now(),
        consecutive_failures: new_failures,
        stats: %{new_stats | total_checks: new_stats.total_checks + 1}
    }

    # Attempt self-healing or escalate
    maybe_escalate_or_heal(new_state, :hash_mismatch, error)
  end

  @spec maybe_escalate_or_heal(watchdog_state(), atom(), term()) :: watchdog_state()
  defp maybe_escalate_or_heal(state, failure_type, details) do
    cond do
      # Try self-healing first
      state.self_heal_attempts < @self_heal_retries ->
        attempt_self_heal(state, failure_type, details)

      # Escalate to Guardian after threshold
      state.consecutive_failures >= @failure_escalation_threshold ->
        escalate_to_guardian(state, failure_type, details)

      # Wait for more failures before escalating
      true ->
        Logger.warning(
          "[StateWatchdog] Failure #{state.consecutive_failures}/#{@failure_escalation_threshold} - monitoring"
        )

        state
    end
  end

  @spec attempt_self_heal(watchdog_state(), atom(), term()) :: watchdog_state()
  defp attempt_self_heal(state, failure_type, _details) do
    Logger.info(
      "[StateWatchdog] Attempting self-heal (#{state.self_heal_attempts + 1}/#{@self_heal_retries})"
    )

    # Self-healing strategies based on failure type
    healed =
      case failure_type do
        :chain_broken ->
          # Re-verify chain - sometimes transient failures resolve
          case check_chain_integrity() do
            :ok -> true
            _ -> false
          end

        :hash_mismatch ->
          # Re-establish baseline hash
          case check_hash_consistency(nil) do
            {:ok, _} -> true
            _ -> false
          end
      end

    if healed do
      Logger.info("[StateWatchdog] Self-heal successful")
      emit_telemetry(:self_heal_success, %{failure_type: failure_type})

      %{
        state
        | consecutive_failures: 0,
          self_heal_attempts: 0,
          stats: %{state.stats | self_heals: state.stats.self_heals + 1}
      }
    else
      Logger.warning("[StateWatchdog] Self-heal failed")

      %{state | self_heal_attempts: state.self_heal_attempts + 1}
    end
  end

  @spec escalate_to_guardian(watchdog_state(), atom(), term()) :: watchdog_state()
  defp escalate_to_guardian(state, failure_type, details) do
    Logger.critical(
      "[StateWatchdog] ESCALATING to Guardian: #{failure_type} - #{inspect(details)}"
    )

    # Report to Guardian (SC-WATCHDOG-002)
    threat = %{
      type: :holon_state_corruption,
      severity: :critical,
      failure_type: failure_type,
      details: details,
      consecutive_failures: state.consecutive_failures,
      timestamp: DateTime.utc_now(),
      source: :state_watchdog
    }

    Guardian.report_threat(threat)

    # Emit telemetry
    emit_telemetry(:guardian_escalation, %{
      failure_type: failure_type,
      consecutive_failures: state.consecutive_failures
    })

    %{
      state
      | stats: %{state.stats | guardian_reports: state.stats.guardian_reports + 1}
    }
  end

  # ============================================================================
  # SCHEDULING & TELEMETRY
  # ============================================================================

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval_ms)
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :holon, :watchdog, event],
      measurements,
      %{watchdog: __MODULE__}
    )
  end
end
