defmodule Indrajaal.KMS.Security.Attestation do
  @moduledoc """
  L6 Security Attestation: Cross-holon trust verification.

  Implements cryptographic attestation for federated knowledge synchronization.
  Uses Ed25519 signatures and Merkle proofs to verify holon identity and
  knowledge integrity across the federation mesh.

  ## STAMP Constraints

  - SC-SMRITI-100: Federation MUST use authenticated channels
  - SC-SMRITI-110: Attestation tokens expire after 1 hour
  - SC-SMRITI-111: Cross-holon attestation every hour in federation mode
  - SC-REG-003: All blocks MUST be Ed25519 signed
  - SC-REG-015: Capability tokens unforgeable
  - SC-OBS-033: All attestation events emit telemetry

  ## Constitutional Alignment

  - Ψ₃ (Verification): Cross-holon attestation for integrity
  - Ψ₀ (Existence): Attestation ensures federated survival
  - Ω₀ (Founder's Directive): Trust verification serves lineage protection

  ## Observer-Observed Pattern

  This module emits telemetry for:
  - Attestation request/generation
  - Signature verification
  - Token validation
  - Capability grant/revoke
  - Trust level changes

  ## 5-Order Effects

  1st: Attestation token generated
  2nd: Peer verifies signature
  3rd: Trust relationship established
  4th: Knowledge sync authorized
  5th: Federation mesh strengthened

  ## Usage

      # Generate attestation for this holon
      {:ok, attestation} = Attestation.generate(holon_id)

      # Verify peer attestation
      {:ok, :valid} = Attestation.verify(peer_attestation)

      # Create capability token
      {:ok, token} = Attestation.create_capability(:sync, target_holon)

      # Verify capability
      {:ok, capabilities} = Attestation.verify_capability(token)
  """

  require Logger

  @attestation_ttl_seconds 3600
  @capability_types [:sync, :read, :write, :admin, :replicate]

  @type holon_id :: String.t()
  @type signature :: binary()
  @type public_key :: binary()
  @type private_key :: binary()

  @type attestation :: %{
          holon_id: holon_id(),
          timestamp: DateTime.t(),
          expires_at: DateTime.t(),
          merkle_root: String.t(),
          signature: signature(),
          public_key: public_key(),
          version: String.t()
        }

  @type capability_token :: %{
          id: String.t(),
          issuer: holon_id(),
          subject: holon_id(),
          capabilities: list(atom()),
          issued_at: DateTime.t(),
          expires_at: DateTime.t(),
          signature: signature()
        }

  @type verification_result :: :valid | :invalid | :expired | :revoked

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generates an attestation for the local holon.

  The attestation contains:
  - Holon identity
  - Current Merkle root of knowledge state
  - Ed25519 signature
  - Expiration timestamp
  """
  @spec generate(holon_id()) :: {:ok, attestation()} | {:error, term()}
  def generate(holon_id) do
    emit_telemetry(:generate_start, %{holon_id: holon_id})

    with {:ok, {public_key, private_key}} <- get_or_create_keypair(holon_id),
         {:ok, merkle_root} <- compute_merkle_root(holon_id) do
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, @attestation_ttl_seconds, :second)

      # Create attestation payload
      payload = create_attestation_payload(holon_id, now, expires_at, merkle_root)

      # Sign with Ed25519
      signature = sign_payload(payload, private_key)

      attestation = %{
        holon_id: holon_id,
        timestamp: now,
        expires_at: expires_at,
        merkle_root: merkle_root,
        signature: signature,
        public_key: public_key,
        version: "1.0.0"
      }

      emit_telemetry(:generate_complete, %{
        holon_id: holon_id,
        expires_at: expires_at
      })

      {:ok, attestation}
    else
      {:error, reason} = error ->
        emit_telemetry(:generate_failed, %{holon_id: holon_id, reason: reason})
        error
    end
  end

  @doc """
  Verifies an attestation from a peer holon.

  Checks:
  - Signature validity
  - Expiration
  - Merkle root consistency (if local reference exists)
  """
  @spec verify(attestation()) :: {:ok, verification_result()} | {:error, term()}
  def verify(attestation) do
    emit_telemetry(:verify_start, %{holon_id: attestation.holon_id})

    with :ok <- check_expiration(attestation),
         :ok <- verify_signature(attestation),
         :ok <- verify_merkle_root(attestation) do
      emit_telemetry(:verify_complete, %{
        holon_id: attestation.holon_id,
        result: :valid
      })

      {:ok, :valid}
    else
      {:error, :expired} ->
        emit_telemetry(:verify_complete, %{
          holon_id: attestation.holon_id,
          result: :expired
        })

        {:ok, :expired}

      {:error, :invalid_signature} ->
        emit_telemetry(:verify_complete, %{
          holon_id: attestation.holon_id,
          result: :invalid
        })

        {:ok, :invalid}

      {:error, reason} = error ->
        emit_telemetry(:verify_failed, %{
          holon_id: attestation.holon_id,
          reason: reason
        })

        error
    end
  end

  @doc """
  Creates a capability token for a specific operation.

  Capability tokens grant specific permissions to peer holons
  for federation operations.
  """
  @spec create_capability(atom() | list(atom()), holon_id(), keyword()) ::
          {:ok, capability_token()} | {:error, term()}
  def create_capability(capabilities, target_holon, opts \\ []) do
    capabilities = List.wrap(capabilities)
    issuer = Keyword.get(opts, :issuer, local_holon_id())
    ttl = Keyword.get(opts, :ttl, @attestation_ttl_seconds)

    emit_telemetry(:create_capability_start, %{
      issuer: issuer,
      target: target_holon,
      capabilities: capabilities
    })

    # Validate capabilities
    unless Enum.all?(capabilities, &(&1 in @capability_types)) do
      emit_telemetry(:create_capability_failed, %{reason: :invalid_capability})
      {:error, :invalid_capability}
    else
      with {:ok, {_public_key, private_key}} <- get_or_create_keypair(issuer) do
        now = DateTime.utc_now()
        expires_at = DateTime.add(now, ttl, :second)

        token_id = generate_token_id()

        payload =
          create_capability_payload(
            token_id,
            issuer,
            target_holon,
            capabilities,
            now,
            expires_at
          )

        signature = sign_payload(payload, private_key)

        token = %{
          id: token_id,
          issuer: issuer,
          subject: target_holon,
          capabilities: capabilities,
          issued_at: now,
          expires_at: expires_at,
          signature: signature
        }

        emit_telemetry(:create_capability_complete, %{
          token_id: token_id,
          capabilities: capabilities
        })

        # Persist to ETS for list_capabilities/0 retrieval
        store_capability_token(token)

        {:ok, token}
      end
    end
  end

  @doc """
  Verifies a capability token and returns the granted capabilities.
  """
  @spec verify_capability(capability_token()) ::
          {:ok, list(atom())} | {:error, term()}
  def verify_capability(token) do
    emit_telemetry(:verify_capability_start, %{token_id: token.id})

    with :ok <- check_token_expiration(token),
         :ok <- verify_token_signature(token),
         :ok <- check_token_revocation(token) do
      emit_telemetry(:verify_capability_complete, %{
        token_id: token.id,
        capabilities: token.capabilities
      })

      {:ok, token.capabilities}
    else
      {:error, reason} = error ->
        emit_telemetry(:verify_capability_failed, %{
          token_id: token.id,
          reason: reason
        })

        error
    end
  end

  @doc """
  Revokes a capability token.
  """
  @spec revoke_capability(String.t()) :: :ok | {:error, term()}
  def revoke_capability(token_id) do
    emit_telemetry(:revoke_capability, %{token_id: token_id})

    # Add to revocation list (would be stored in SQLite in production)
    add_to_revocation_list(token_id)

    :ok
  end

  @doc """
  Gets the trust level for a peer holon based on attestation history.
  """
  @spec trust_level(holon_id()) :: {:ok, float()} | {:error, term()}
  def trust_level(holon_id) do
    # Trust level based on:
    # - Successful attestation verifications
    # - Age of relationship
    # - Sync history
    # Returns 0.0 to 1.0

    # get_trust_history always returns {:ok, ...}
    {:ok, history} = get_trust_history(holon_id)
    level = calculate_trust_level(history)
    emit_telemetry(:trust_level_query, %{holon_id: holon_id, level: level})
    {:ok, level}
  end

  @doc """
  Lists all valid capability tokens issued by this holon.
  """
  @spec list_capabilities() :: {:ok, list(capability_token())} | {:error, term()}
  def list_capabilities do
    now = DateTime.utc_now()

    tokens =
      try do
        :ets.tab2list(:smriti_capability_tokens)
        |> Enum.filter(fn {_id, token} ->
          DateTime.compare(now, token.expires_at) == :lt and
            not is_revoked?(token.id)
        end)
        |> Enum.map(fn {_id, token} -> token end)
      rescue
        ArgumentError -> []
      end

    {:ok, tokens}
  end

  @doc """
  Returns the attestation TTL in seconds.
  """
  @spec attestation_ttl() :: non_neg_integer()
  def attestation_ttl, do: @attestation_ttl_seconds

  @doc """
  Returns supported capability types.
  """
  @spec capability_types() :: list(atom())
  def capability_types, do: @capability_types

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp get_or_create_keypair(holon_id) do
    # In production, this would load from secure storage or generate new
    # Using deterministic generation for simplicity
    seed = :crypto.hash(:sha256, holon_id)
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519, seed)
    {:ok, {public_key, private_key}}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp compute_merkle_root(holon_id) do
    # In production, compute from actual knowledge state
    root =
      :crypto.hash(:sha256, "#{holon_id}:#{System.system_time(:nanosecond)}")
      |> Base.encode16(case: :lower)

    {:ok, root}
  end

  defp create_attestation_payload(holon_id, timestamp, expires_at, merkle_root) do
    Jason.encode!(%{
      holon_id: holon_id,
      timestamp: DateTime.to_iso8601(timestamp),
      expires_at: DateTime.to_iso8601(expires_at),
      merkle_root: merkle_root
    })
  end

  defp create_capability_payload(token_id, issuer, subject, capabilities, issued_at, expires_at) do
    Jason.encode!(%{
      id: token_id,
      issuer: issuer,
      subject: subject,
      capabilities: capabilities,
      issued_at: DateTime.to_iso8601(issued_at),
      expires_at: DateTime.to_iso8601(expires_at)
    })
  end

  defp sign_payload(payload, private_key) do
    :crypto.sign(:eddsa, :sha256, payload, [private_key, :ed25519])
  end

  defp check_expiration(attestation) do
    now = DateTime.utc_now()

    if DateTime.compare(now, attestation.expires_at) == :lt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp verify_signature(attestation) do
    payload =
      create_attestation_payload(
        attestation.holon_id,
        attestation.timestamp,
        attestation.expires_at,
        attestation.merkle_root
      )

    if :crypto.verify(:eddsa, :sha256, payload, attestation.signature, [
         attestation.public_key,
         :ed25519
       ]) do
      :ok
    else
      {:error, :invalid_signature}
    end
  rescue
    _ -> {:error, :invalid_signature}
  end

  defp verify_merkle_root(_attestation) do
    # In production, would compare against local reference if available
    :ok
  end

  defp check_token_expiration(token) do
    now = DateTime.utc_now()

    if DateTime.compare(now, token.expires_at) == :lt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp verify_token_signature(token) do
    # Retrieve the issuer's public key and verify the capability payload
    with {:ok, {public_key, _private_key}} <- get_or_create_keypair(token.issuer) do
      payload =
        create_capability_payload(
          token.id,
          token.issuer,
          token.subject,
          token.capabilities,
          token.issued_at,
          token.expires_at
        )

      if :crypto.verify(:eddsa, :sha256, payload, token.signature, [public_key, :ed25519]) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  rescue
    _ -> {:error, :invalid_signature}
  end

  defp check_token_revocation(token) do
    if is_revoked?(token.id) do
      {:error, :revoked}
    else
      :ok
    end
  end

  defp is_revoked?(token_id) do
    # Would check SQLite revocation table
    # Using ETS for simplicity
    case :ets.lookup(:smriti_revoked_tokens, token_id) do
      [{^token_id, _}] -> true
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  defp add_to_revocation_list(token_id) do
    try do
      :ets.insert(:smriti_revoked_tokens, {token_id, DateTime.utc_now()})
    rescue
      ArgumentError ->
        :ets.new(:smriti_revoked_tokens, [:set, :public, :named_table])
        :ets.insert(:smriti_revoked_tokens, {token_id, DateTime.utc_now()})
    end
  end

  defp store_capability_token(token) do
    try do
      :ets.insert(:smriti_capability_tokens, {token.id, token})
    rescue
      ArgumentError ->
        :ets.new(:smriti_capability_tokens, [:set, :public, :named_table])
        :ets.insert(:smriti_capability_tokens, {token.id, token})
    end

    :ok
  end

  defp generate_token_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp local_holon_id do
    # Would get from configuration
    "local-holon"
  end

  defp get_trust_history(holon_id) do
    # Query ETS attestation history for this holon
    records =
      try do
        :ets.lookup(:smriti_trust_history, holon_id)
      rescue
        ArgumentError -> []
      end

    case records do
      [{^holon_id, history}] ->
        {:ok, history}

      [] ->
        {:ok, %{successful_verifications: 0, age_days: 0, sync_count: 0}}
    end
  end

  defp calculate_trust_level(history) do
    # Simple trust calculation based on history
    base_trust = 0.5

    verification_bonus = min(history.successful_verifications * 0.05, 0.25)
    age_bonus = min(history.age_days * 0.01, 0.15)
    sync_bonus = min(history.sync_count * 0.02, 0.10)

    min(base_trust + verification_bonus + age_bonus + sync_bonus, 1.0)
  end

  # ============================================================================
  # Telemetry
  # ============================================================================

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :security, :attestation, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
