defmodule Indrajaal.Core.Constitution.Verifier do
  @moduledoc """
  Constitution Verifier - Runtime Integrity Verification for v20.0.0

  Provides runtime verification of constitutional integrity:
  1. Startup verification (mandatory)
  2. Periodic verification (configurable)
  3. On-demand verification (for critical operations)
  4. Violation reporting (telemetry + alerts)

  ## STAMP Constraints
  - SC-VER-001: Startup verification MUST complete before app ready
  - SC-VER-002: Verification failure MUST halt the system
  - SC-VER-003: All violations MUST be logged and reported
  - SC-VER-004: Verification MUST complete within 100ms

  ## Usage
      # At application startup
      Indrajaal.Core.Constitution.Verifier.verify_on_startup!()

      # For critical operations
      with :ok <- Verifier.verify_for_operation(:replicate) do
        perform_replication()
      end
  """

  require Logger

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Hash

  @type verification_result ::
          {:ok, %{hash: binary(), verified_at: DateTime.t()}}
          | {:error, :constitution_violated, map()}

  @type invariant_check ::
          {:ok, atom()}
          | {:error, atom(), String.t()}

  @doc """
  Verifies the constitution on application startup.

  This function MUST be called during application initialization.
  If verification fails, it raises an exception to halt startup.

  ## STAMP Compliance
  - SC-VER-001: Called from Application.start/2
  - SC-VER-002: Raises on failure to prevent compromised startup
  """
  @spec verify_on_startup!() :: :ok
  def verify_on_startup! do
    Logger.info("🔐 Verifying constitution integrity...")
    start_time = System.monotonic_time(:millisecond)

    case verify() do
      {:ok, result} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "✅ Constitution verified in #{elapsed}ms - Hash: #{Hash.compute_hex() |> String.slice(0, 16)}..."
        )

        # Emit telemetry
        :telemetry.execute(
          [:indrajaal, :constitution, :verified],
          %{duration_ms: elapsed},
          %{hash: result.hash, version: Constitution.version()}
        )

        :ok

      {:error, :constitution_violated, details} ->
        Logger.error("❌ CONSTITUTION VIOLATION DETECTED!")
        Logger.error("   Violation: #{inspect(details)}")

        # Emit critical telemetry
        :telemetry.execute(
          [:indrajaal, :constitution, :violated],
          %{severity: :critical},
          details
        )

        raise "Constitution integrity check failed: #{inspect(details)}"
    end
  end

  @doc """
  Performs a full constitution verification.

  Returns detailed verification results including:
  - Hash verification
  - Individual invariant checks
  - Timing information
  """
  @spec verify() :: verification_result()
  def verify do
    current_hash = Hash.compute()

    case Constitution.verify() do
      {:verified, returned_hash} ->
        # In non-strict mode, accept any verified result
        # In strict mode (production), hash must match exactly
        strict_mode = Application.get_env(:indrajaal, :strict_constitution_hash, false)

        if strict_mode and returned_hash != current_hash do
          {:error, :constitution_violated,
           %{
             reason: :hash_mismatch,
             current_hash: Base.encode16(current_hash, case: :lower),
             expected_hash: Base.encode16(returned_hash, case: :lower),
             detected_at: DateTime.utc_now()
           }}
        else
          {:ok,
           %{
             hash: current_hash,
             hash_hex: Base.encode16(current_hash, case: :lower),
             verified_at: DateTime.utc_now(),
             version: Constitution.version(),
             invariants_checked: 7
           }}
        end

      {:violated, invariant, _hash} ->
        {:error, :constitution_violated,
         %{
           reason: :invariant_violated,
           invariant: invariant,
           detected_at: DateTime.utc_now()
         }}
    end
  end

  @doc """
  Verifies constitution before performing a sensitive operation.

  Certain operations require fresh constitution verification:
  - `:replicate` - Node replication
  - `:federate` - Federation join
  - `:mutate` - Configuration mutation
  - `:upgrade` - System upgrade
  """
  @spec verify_for_operation(atom()) :: :ok | {:error, :constitution_violated}
  def verify_for_operation(operation)
      when operation in [:replicate, :federate, :mutate, :upgrade] do
    Logger.debug("Verifying constitution for operation: #{operation}")

    case verify() do
      {:ok, _} -> :ok
      {:error, _, _} -> {:error, :constitution_violated}
    end
  end

  def verify_for_operation(operation) do
    Logger.warning("Unknown operation requested constitution verification: #{operation}")
    {:error, :unknown_operation}
  end

  @doc """
  Checks individual runtime invariants.

  Returns a list of invariant check results.
  """
  @spec check_runtime_invariants() :: [invariant_check()]
  def check_runtime_invariants do
    invariants = [:patient_mode, :container_isolation, :non_aggression]

    Enum.map(invariants, fn invariant ->
      case Constitution.check_invariant(invariant) do
        :ok -> {:ok, invariant}
        {:error, reason} -> {:error, invariant, reason}
      end
    end)
  end

  @doc """
  Returns whether the system is in a verified state.
  """
  @spec verified?() :: boolean()
  def verified? do
    case verify() do
      {:ok, _} -> true
      {:error, _, _} -> false
    end
  end

  @doc """
  Returns verification status for health checks.
  """
  @spec health_check() :: %{status: :ok | :error, details: map()}
  def health_check do
    case verify() do
      {:ok, details} ->
        %{
          status: :ok,
          details: Map.take(details, [:hash_hex, :verified_at, :version])
        }

      {:error, :constitution_violated, details} ->
        %{
          status: :error,
          details: details
        }
    end
  end
end
