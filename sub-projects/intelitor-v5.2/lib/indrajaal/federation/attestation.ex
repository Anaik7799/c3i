defmodule Indrajaal.Federation.Attestation do
  @moduledoc """
  Cross-Holon Attestation Protocol.

  ## WHAT
  Verifies the integrity and authenticity of peer holons in the federation
  using HMAC-SHA512 signed attestation proofs with SHA3-256 state hashes.

  ## WHY
  Ensures that only trusted, uncorrupted nodes can participate in the
  global knowledge sharing and consensus processes.

  ## CONSTRAINTS
  - SC-FED-006: Attestation Ed25519-verified (HMAC-SHA512 used per Sprint 52)
  - SC-HASH-001: Deterministic hash computation
  - SC-HASH-002: Constant-time comparison (timing attack prevention)
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1hr

  @version "21.3.0"
  @last_modified "2026-03-23"
  """

  require Logger

  @attestation_ttl_ms 3_600_000
  @table :federation_attestation_cache

  @doc """
  Generate an attestation proof for the local holon.

  Computes a SHA3-256 hash of the local holon's state metadata and signs
  it with HMAC-SHA512 using the federation secret key.
  """
  @spec generate_proof() :: {:ok, map()} | {:error, term()}
  def generate_proof do
    ensure_table()
    now = DateTime.utc_now()
    node_id = node_identifier()
    state_hash = compute_state_hash(node_id, now)
    secret = get_secret_key()
    signature = sign_attestation(state_hash, node_id, now, secret)

    proof = %{
      node_id: node_id,
      timestamp: now,
      state_hash: Base.encode16(state_hash, case: :lower),
      signature: Base.encode16(signature, case: :lower),
      ttl_ms: @attestation_ttl_ms
    }

    :ets.insert(@table, {node_id, proof, System.system_time(:millisecond)})

    :telemetry.execute(
      [:indrajaal, :federation, :attestation],
      %{generated: 1},
      %{node_id: node_id}
    )

    {:ok, proof}
  rescue
    e ->
      Logger.error("[Attestation] generate_proof failed: #{inspect(e)}")
      {:error, {:attestation_error, e}}
  end

  @doc """
  Verify an attestation proof from a peer.

  Checks HMAC-SHA512 signature validity and attestation freshness (1-hour TTL).
  Uses constant-time comparison to prevent timing-oracle attacks (SC-HASH-002).
  """
  @spec verify_peer_proof(String.t(), map()) :: {:ok, :verified} | {:error, term()}
  def verify_peer_proof(peer_id, proof) do
    ensure_table()

    with :ok <- check_freshness(proof),
         :ok <- check_signature(proof) do
      :ets.insert(@table, {peer_id, proof, System.system_time(:millisecond)})

      :telemetry.execute(
        [:indrajaal, :federation, :attestation],
        %{verified: 1},
        %{peer_id: peer_id}
      )

      {:ok, :verified}
    else
      {:error, reason} = err ->
        :telemetry.execute(
          [:indrajaal, :federation, :attestation],
          %{rejected: 1},
          %{peer_id: peer_id, reason: reason}
        )

        Logger.warning("[Attestation] Peer #{peer_id} proof rejected: #{reason}")
        err
    end
  end

  @doc """
  Check if a peer's attestation is still valid (not expired).
  """
  @spec peer_attested?(String.t()) :: boolean()
  def peer_attested?(peer_id) do
    ensure_table()

    case :ets.lookup(@table, peer_id) do
      [{^peer_id, _proof, cached_at}] ->
        System.system_time(:millisecond) - cached_at < @attestation_ttl_ms

      [] ->
        false
    end
  rescue
    ArgumentError -> false
  end

  # ── Private ──────────────────────────────────────────────────────

  defp compute_state_hash(node_id, timestamp) do
    data =
      :erlang.term_to_binary(%{
        node: node_id,
        otp_release: :erlang.system_info(:otp_release) |> List.to_string(),
        beam_files: length(:code.all_loaded()),
        timestamp_unix: DateTime.to_unix(timestamp)
      })

    :crypto.hash(:sha3_256, data)
  end

  defp sign_attestation(state_hash, node_id, timestamp, secret) do
    payload =
      state_hash <>
        :erlang.term_to_binary(node_id) <>
        :erlang.term_to_binary(DateTime.to_unix(timestamp))

    :crypto.mac(:hmac, :sha512, secret, payload)
  end

  defp check_freshness(%{timestamp: ts, ttl_ms: ttl}) do
    age_ms = DateTime.diff(DateTime.utc_now(), ts, :millisecond)

    if age_ms <= ttl do
      :ok
    else
      {:error, :expired}
    end
  end

  defp check_freshness(%{timestamp: ts}) do
    check_freshness(%{timestamp: ts, ttl_ms: @attestation_ttl_ms})
  end

  defp check_signature(%{
         state_hash: hash_hex,
         signature: sig_hex,
         node_id: node_id,
         timestamp: ts
       }) do
    secret = get_secret_key()
    state_hash = Base.decode16!(hash_hex, case: :mixed)
    provided_sig = Base.decode16!(sig_hex, case: :mixed)
    expected_sig = sign_attestation(state_hash, node_id, ts, secret)

    if :crypto.hash_equals(expected_sig, provided_sig) do
      :ok
    else
      {:error, :invalid_signature}
    end
  rescue
    _ -> {:error, :malformed_proof}
  end

  defp check_signature(_), do: {:error, :missing_fields}

  defp get_secret_key do
    case Application.get_env(:indrajaal, :federation_secret_key) do
      nil -> :crypto.strong_rand_bytes(32)
      key when is_binary(key) -> key
    end
  end

  defp node_identifier do
    node() |> Atom.to_string()
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])

      _ ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
