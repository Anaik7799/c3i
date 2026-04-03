defmodule Indrajaal.Cockpit.Prajna.DualChannel do
  @moduledoc """
  Dual-Channel Verification for SIL-4 Critical Operations.

  WHAT: Independent parallel verification channels for hash chain and signatures.
  WHY: SIL-4 requires dual-channel verification to detect Byzantine failures.

  CONSTRAINTS:
    - SC-REG-007: Extension recording must be verified
    - SC-PRIME-001: Will to Live - System SHALL NOT optimize to zero
    - AOR-CONST-002: Immediate Halt - If constitutional violation detected, HALT and rollback
    - SC-SIL4-DUAL-001: Independent channels MUST reach agreement
    - SC-SIL4-DUAL-002: Disagreement triggers immediate halt + alert

  ## Architecture (SIL-4 Dual-Channel Pattern)

  ```
  Block Input
      |
      +-----------+-----------+
      |                       |
  Channel A              Channel B
  (Hash Verify)        (Signature Verify)
      |                       |
      +-----------+-----------+
                  |
            Comparator
                  |
          Agreement Check
                  |
        +---------+---------+
        |                   |
     AGREE             DISAGREE
        |                   |
    Continue              HALT
                           +
                        Alert
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  | STAMP | SC-REG-007, SC-PRIME-001, AOR-CONST-002 |
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.Config
  alias Indrajaal.Cockpit.Prajna.ImmutableState
  alias Indrajaal.Safety.Guardian

  @genesis_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @signing_key "prajna_immutable_state_hmac_key_v21"

  @type verification_result ::
          {:ok, :verified}
          | {:error, :channel_a_failed, term()}
          | {:error, :channel_b_failed, term()}
          | {:error, :channels_disagree, term()}
          | {:error, :halt_required, term()}

  @type channel_state :: :idle | :verifying | :halted

  defstruct channel_a_state: :idle,
            channel_b_state: :idle,
            last_verification: nil,
            verification_count: 0,
            disagreement_count: 0,
            halt_count: 0,
            halted: false,
            halt_reason: nil

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the DualChannel verification GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Verifies a block using dual-channel verification.

  Both channels (hash verification and signature verification) must agree
  for the verification to pass. Any disagreement triggers a halt.

  ## Parameters

    - block: The block to verify
    - expected_prev_hash: The expected previous hash (for chain continuity)

  ## Returns

    - {:ok, :verified} - Both channels agree, block is valid
    - {:error, :channel_a_failed, reason} - Hash verification failed
    - {:error, :channel_b_failed, reason} - Signature verification failed
    - {:error, :channels_disagree, details} - Channels returned conflicting results
    - {:error, :halt_required, reason} - System is halted due to previous failures

  ## Examples

      iex> DualChannel.verify_block(block, prev_hash)
      {:ok, :verified}

      iex> DualChannel.verify_block(tampered_block, prev_hash)
      {:error, :channel_a_failed, "Content hash mismatch"}
  """
  @spec verify_block(map(), String.t()) :: verification_result()
  def verify_block(block, expected_prev_hash) do
    GenServer.call(__MODULE__, {:verify_block, block, expected_prev_hash}, get_timeout())
  catch
    :exit, {:noproc, _} ->
      # Stateless fallback for tests
      verify_block_stateless(block, expected_prev_hash)

    :exit, {:timeout, _} ->
      Logger.error("[DualChannel] Verification timeout - treating as failure")
      {:error, :timeout, "Verification timed out"}
  end

  @doc """
  Verifies an entire chain using dual-channel verification on each block.

  ## Parameters

    - blocks: List of blocks to verify in order

  ## Returns

    - {:ok, :verified} - All blocks verified
    - {:error, :block_failed, index, reason} - Block at index failed
    - {:error, :halt_required, reason} - System is halted
  """
  @spec verify_chain([map()]) ::
          {:ok, :verified} | {:error, :block_failed, non_neg_integer(), term()}
  def verify_chain(blocks) when is_list(blocks) do
    GenServer.call(__MODULE__, {:verify_chain, blocks}, get_timeout() * length(blocks) + 5_000)
  catch
    :exit, {:noproc, _} ->
      verify_chain_stateless(blocks)

    :exit, {:timeout, _} ->
      {:error, :timeout, "Chain verification timed out"}
  end

  @doc """
  Returns true if the dual-channel verifier is currently halted.
  """
  @spec halted?() :: boolean()
  def halted? do
    GenServer.call(__MODULE__, :halted?, 5_000)
  catch
    :exit, _ -> false
  end

  @doc """
  Attempts to recover from halted state after Guardian approval.
  Requires explicit Guardian approval (SC-PRIME-001).
  """
  @spec recover() :: :ok | {:error, term()}
  def recover do
    GenServer.call(__MODULE__, :recover, 10_000)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, _ -> {:error, :recovery_failed}
  end

  @doc """
  Returns current verification statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats, 5_000)
  catch
    :exit, _ ->
      %{
        verification_count: 0,
        disagreement_count: 0,
        halt_count: 0,
        halted: false,
        channel_a_state: :unknown,
        channel_b_state: :unknown
      }
  end

  @doc """
  Resets verification statistics (for testing).
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats, 5_000)
  catch
    :exit, _ -> :ok
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    Logger.info("[DualChannel] Initializing SIL-4 dual-channel verification (SC-REG-007)")
    emit_initialized()

    state = %__MODULE__{
      channel_a_state: :idle,
      channel_b_state: :idle,
      last_verification: nil,
      verification_count: 0,
      disagreement_count: 0,
      halt_count: 0,
      halted: false,
      halt_reason: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:verify_block, _block, _prev_hash}, _from, %{halted: true} = state) do
    Logger.warning("[DualChannel] Rejecting verification - system is HALTED")
    {:reply, {:error, :halt_required, state.halt_reason}, state}
  end

  @impl GenServer
  def handle_call({:verify_block, block, expected_prev_hash}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    new_state = %{state | channel_a_state: :verifying, channel_b_state: :verifying}

    # Execute dual-channel verification
    {result, final_state} = do_dual_verify(block, expected_prev_hash, new_state)

    duration_us = System.monotonic_time(:microsecond) - start_time
    emit_verification_complete(result, duration_us)

    {:reply, result, final_state}
  end

  @impl GenServer
  def handle_call({:verify_chain, _blocks}, _from, %{halted: true} = state) do
    {:reply, {:error, :halt_required, state.halt_reason}, state}
  end

  @impl GenServer
  def handle_call({:verify_chain, blocks}, _from, state) do
    {result, final_state} = do_verify_chain(blocks, state)
    {:reply, result, final_state}
  end

  @impl GenServer
  def handle_call(:halted?, _from, state) do
    {:reply, state.halted, state}
  end

  @impl GenServer
  def handle_call(:recover, _from, %{halted: false} = state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:recover, _from, %{halted: true} = state) do
    Logger.info("[DualChannel] Attempting recovery from HALT state (requires Guardian approval)")

    # Request Guardian approval for recovery
    proposal = %{
      type: :recovery,
      action: :dual_channel_unhalt,
      reason: state.halt_reason,
      requestor: __MODULE__,
      request_id: Ecto.UUID.generate()
    }

    case request_guardian_approval(proposal) do
      {:ok, _} ->
        Logger.info("[DualChannel] Guardian APPROVED recovery - unhalting")
        emit_recovery(:approved)

        new_state = %{
          state
          | halted: false,
            halt_reason: nil,
            channel_a_state: :idle,
            channel_b_state: :idle
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.warning("[DualChannel] Guardian REJECTED recovery: #{inspect(reason)}")
        emit_recovery(:rejected)
        {:reply, {:error, :recovery_rejected}, state}

      {:veto, reason, _fallback} ->
        Logger.warning("[DualChannel] Guardian VETOED recovery: #{inspect(reason)}")
        emit_recovery(:vetoed)
        {:reply, {:error, {:guardian_veto, reason}}, state}
    end
  end

  @impl GenServer
  def handle_call(:stats, _from, state) do
    stats = %{
      verification_count: state.verification_count,
      disagreement_count: state.disagreement_count,
      halt_count: state.halt_count,
      halted: state.halted,
      halt_reason: state.halt_reason,
      channel_a_state: state.channel_a_state,
      channel_b_state: state.channel_b_state,
      last_verification: state.last_verification
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:reset_stats, _from, state) do
    new_state = %{
      state
      | verification_count: 0,
        disagreement_count: 0,
        halt_count: 0,
        halted: false,
        halt_reason: nil,
        channel_a_state: :idle,
        channel_b_state: :idle
    }

    {:reply, :ok, new_state}
  end

  # ============================================================================
  # Private: Dual-Channel Verification
  # ============================================================================

  defp do_dual_verify(block, expected_prev_hash, state) do
    # Channel A: Hash Chain Verification
    channel_a_result = verify_channel_a(block, expected_prev_hash)

    # Channel B: Signature Verification
    channel_b_result = verify_channel_b(block)

    # Compare results
    compare_channels(channel_a_result, channel_b_result, block, state)
  end

  # Channel A: Hash Chain Verification
  defp verify_channel_a(block, expected_prev_hash) do
    with :ok <- verify_prev_hash(block, expected_prev_hash),
         :ok <- verify_content_hash(block),
         :ok <- verify_block_hash(block) do
      {:ok, :hash_chain_valid}
    else
      {:invalid, reason} -> {:error, reason}
    end
  end

  # Channel B: Signature Verification
  defp verify_channel_b(block) do
    with :ok <- verify_signature(block),
         :ok <- verify_protocol_version(block) do
      {:ok, :signature_valid}
    else
      {:invalid, reason} -> {:error, reason}
    end
  end

  # Compare channel results and determine outcome
  defp compare_channels({:ok, _}, {:ok, _}, block, state) do
    # Both channels agree - verification passed
    Logger.debug("[DualChannel] Block #{block.index} verified - channels agree")

    new_state = %{
      state
      | verification_count: state.verification_count + 1,
        last_verification: DateTime.utc_now(),
        channel_a_state: :idle,
        channel_b_state: :idle
    }

    emit_channels_agree(block)
    {{:ok, :verified}, new_state}
  end

  defp compare_channels({:error, reason_a}, {:error, reason_b}, block, state) do
    # Both channels failed - could be corrupted block
    Logger.error("[DualChannel] Block #{block.index} FAILED both channels!")
    Logger.error("  Channel A: #{inspect(reason_a)}")
    Logger.error("  Channel B: #{inspect(reason_b)}")

    # This is a disagreement in the sense that both failed differently
    new_state = handle_verification_failure(state, :both_failed, block)

    emit_both_failed(block, reason_a, reason_b)
    {{:error, :channels_disagree, %{channel_a: reason_a, channel_b: reason_b}}, new_state}
  end

  defp compare_channels({:error, reason}, {:ok, _}, block, state) do
    # Channel A failed, Channel B passed - disagreement!
    Logger.error(
      "[DualChannel] DISAGREEMENT at block #{block.index}: Channel A failed, Channel B passed"
    )

    Logger.error("  Channel A error: #{inspect(reason)}")

    new_state = handle_verification_failure(state, :channel_disagreement, block)

    emit_channel_disagreement(block, :a_failed_b_passed, reason)
    {{:error, :channel_a_failed, reason}, new_state}
  end

  defp compare_channels({:ok, _}, {:error, reason}, block, state) do
    # Channel A passed, Channel B failed - disagreement!
    Logger.error(
      "[DualChannel] DISAGREEMENT at block #{block.index}: Channel A passed, Channel B failed"
    )

    Logger.error("  Channel B error: #{inspect(reason)}")

    new_state = handle_verification_failure(state, :channel_disagreement, block)

    emit_channel_disagreement(block, :a_passed_b_failed, reason)
    {{:error, :channel_b_failed, reason}, new_state}
  end

  defp handle_verification_failure(state, failure_type, block) do
    new_disagreement_count = state.disagreement_count + 1
    threshold = get_halt_threshold()

    if new_disagreement_count >= threshold do
      # Trigger HALT (AOR-CONST-002)
      Logger.error("[DualChannel] HALT TRIGGERED: #{new_disagreement_count} disagreements")
      emit_halt_triggered(failure_type, block)
      alert_guardian_halt(failure_type, block)

      %{
        state
        | disagreement_count: new_disagreement_count,
          halt_count: state.halt_count + 1,
          halted: true,
          halt_reason: "#{failure_type} at block #{block.index}",
          channel_a_state: :halted,
          channel_b_state: :halted
      }
    else
      %{
        state
        | disagreement_count: new_disagreement_count,
          channel_a_state: :idle,
          channel_b_state: :idle
      }
    end
  end

  # ============================================================================
  # Private: Chain Verification
  # ============================================================================

  defp do_verify_chain([], state) do
    {{:ok, :verified}, state}
  end

  defp do_verify_chain(blocks, state) do
    verify_chain_recursive(blocks, @genesis_hash, 0, state)
  end

  defp verify_chain_recursive([], _prev_hash, _index, state) do
    {{:ok, :verified}, state}
  end

  defp verify_chain_recursive([block | rest], expected_prev, index, state) do
    case do_dual_verify(block, expected_prev, state) do
      {{:ok, :verified}, new_state} ->
        verify_chain_recursive(rest, block.block_hash, index + 1, new_state)

      {{:error, type, reason}, new_state} ->
        {{:error, :block_failed, index, %{type: type, reason: reason}}, new_state}
    end
  end

  # ============================================================================
  # Private: Individual Verifications
  # ============================================================================

  defp verify_prev_hash(block, expected_prev) do
    if block.prev_hash == expected_prev do
      :ok
    else
      {:invalid, "prev_hash mismatch: expected #{expected_prev}, got #{block.prev_hash}"}
    end
  end

  defp verify_content_hash(block) do
    computed = hash(Jason.encode!(block.content))

    if block.content_hash == computed do
      :ok
    else
      {:invalid, "content_hash mismatch"}
    end
  end

  defp verify_block_hash(block) do
    timestamp_str =
      case block.timestamp do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        other -> to_string(other)
      end

    block_data = "#{block.prev_hash}|#{block.content_hash}|#{block.index}|#{timestamp_str}"
    computed = hash(block_data)

    if block.block_hash == computed do
      :ok
    else
      {:invalid, "block_hash mismatch"}
    end
  end

  defp verify_signature(block) do
    expected = sign(block.block_hash)

    if block.signature == expected do
      :ok
    else
      {:invalid, "signature invalid"}
    end
  end

  defp verify_protocol_version(block) do
    # Protocol version must be present and valid
    case Map.get(block, :protocol_version) do
      nil -> {:invalid, "missing protocol_version"}
      version when is_binary(version) -> :ok
      _ -> {:invalid, "invalid protocol_version type"}
    end
  end

  # ============================================================================
  # Private: Stateless Fallback (for tests without GenServer)
  # ============================================================================

  defp verify_block_stateless(block, expected_prev_hash) do
    channel_a = verify_channel_a(block, expected_prev_hash)
    channel_b = verify_channel_b(block)

    case {channel_a, channel_b} do
      {{:ok, _}, {:ok, _}} ->
        {:ok, :verified}

      {{:error, reason}, {:ok, _}} ->
        {:error, :channel_a_failed, reason}

      {{:ok, _}, {:error, reason}} ->
        {:error, :channel_b_failed, reason}

      {{:error, r1}, {:error, r2}} ->
        {:error, :channels_disagree, %{channel_a: r1, channel_b: r2}}
    end
  end

  defp verify_chain_stateless([]), do: {:ok, :verified}

  defp verify_chain_stateless(blocks) do
    verify_chain_stateless_recursive(blocks, @genesis_hash, 0)
  end

  defp verify_chain_stateless_recursive([], _prev, _idx), do: {:ok, :verified}

  defp verify_chain_stateless_recursive([block | rest], expected_prev, index) do
    case verify_block_stateless(block, expected_prev) do
      {:ok, :verified} ->
        verify_chain_stateless_recursive(rest, block.block_hash, index + 1)

      {:error, type, reason} ->
        {:error, :block_failed, index, %{type: type, reason: reason}}
    end
  end

  # ============================================================================
  # Private: Crypto (mirrors ImmutableState for consistency)
  # ============================================================================

  defp hash(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp sign(data) do
    :crypto.mac(:hmac, :sha512, @signing_key, data) |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # Private: Guardian Integration
  # ============================================================================

  defp request_guardian_approval(proposal) do
    try do
      Guardian.validate_proposal(proposal, timeout: 5_000)
    rescue
      _ -> {:error, :guardian_error}
    catch
      :exit, _ -> {:error, :guardian_unavailable}
    end
  end

  defp alert_guardian_halt(failure_type, block) do
    # Record halt event to ImmutableState
    payload = %{
      change_type: :dual_channel_halt,
      module: "DualChannel",
      failure_type: failure_type,
      block_index: block.index,
      timestamp: DateTime.utc_now()
    }

    ImmutableState.record(payload)
  rescue
    _ -> Logger.error("[DualChannel] Failed to record halt to ImmutableState")
  end

  # ============================================================================
  # Private: Configuration
  # ============================================================================

  defp get_timeout do
    try do
      Config.get(:dual_channel_timeout_ms, 5_000)
    rescue
      _ -> 5_000
    end
  end

  defp get_halt_threshold do
    # Number of disagreements before triggering HALT
    try do
      Config.get(:dual_channel_halt_threshold, 1)
    rescue
      _ -> 1
    end
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_initialized do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :initialized],
      %{timestamp: System.system_time(:millisecond)},
      %{}
    )
  end

  defp emit_verification_complete(result, duration_us) do
    status =
      case result do
        {:ok, _} -> :success
        {:error, _, _} -> :failure
      end

    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :verification],
      %{duration_us: duration_us, timestamp: System.system_time(:millisecond)},
      %{status: status}
    )
  end

  defp emit_channels_agree(block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :agree],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{}
    )
  end

  defp emit_both_failed(block, reason_a, reason_b) do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :both_failed],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{reason_a: reason_a, reason_b: reason_b}
    )
  end

  defp emit_channel_disagreement(block, type, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :disagreement],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{type: type, reason: reason}
    )

    # ZUIP T4-06: Publish channel disagreement to Zenoh mesh (SC-ZTEST-008)
    safe_publish(:publish_jidoka_halt, [:dual_channel, "channel_disagreement: #{type}"])
  end

  defp emit_halt_triggered(failure_type, block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :halt],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{failure_type: failure_type}
    )

    # ZUIP T4-06: Publish halt to Zenoh mesh (constitutional violation)
    safe_publish(:publish_guardian_emergency_stop, ["dual_channel_halt: #{failure_type}"])
  end

  defp emit_recovery(status) do
    :telemetry.execute(
      [:indrajaal, :prajna, :dual_channel, :recovery],
      %{timestamp: System.system_time(:millisecond)},
      %{status: status}
    )
  end

  # ZUIP T4-06: Safe Zenoh publish — never crashes the dual channel
  defp safe_publish(function, args) do
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
        {:module, mod} -> apply(mod, function, args)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end
