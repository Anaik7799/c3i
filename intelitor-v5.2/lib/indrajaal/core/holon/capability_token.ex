defmodule Indrajaal.Core.Holon.CapabilityToken do
  @moduledoc """
  Capability Token System - Unforgeable Authorization Tokens.

  ## What
  Cryptographically-signed capability tokens for authorization between holons
  and system components. Each token grants specific capabilities with expiration.

  ## Why
  Implements SC-REG-015 (Capability tokens unforgeable) and SC-GRID-017/018:
  - Cryptographic unforgability via Ed25519 signatures
  - Capability-based access control
  - Token revocation support
  - Federation authorization

  ## 5-Layer Hybrid Grid Integration
  This module implements Layer 3 (Trust Layer) of the Hybrid Grid:
  - Financial Network pattern: Bearer tokens with cryptographic proof
  - Capability-based security model
  - Distributed token verification

  ## Token Structure
  ```
  Token := {
    id: UUID,
    issuer: HolonId,
    subject: HolonId | AgentId,
    capabilities: [Capability],
    issued_at: Timestamp,
    expires_at: Timestamp,
    signature: Ed25519Signature
  }
  ```

  ## Constraints
  - SC-REG-015: Capability tokens unforgeable
  - SC-GRID-017: Token verification required for privileged ops
  - SC-GRID-018: Token revocation propagates within 5s
  - SC-FOUNDER-007: Founder's lineage has SUPREME authority
  """

  use GenServer
  require Logger

  @token_version 1
  @default_ttl_seconds 3600

  @type capability ::
          :read
          | :write
          | :admin
          | :execute
          | :replicate
          | :attest
          | :evolve
          | :founder_access

  @type token :: %{
          id: String.t(),
          version: pos_integer(),
          issuer: String.t(),
          subject: String.t(),
          capabilities: list(capability()),
          issued_at: DateTime.t(),
          expires_at: DateTime.t(),
          signature: binary(),
          revoked: boolean()
        }

  defstruct [
    :keypair,
    :holon_id,
    tokens: %{},
    revoked: MapSet.new(),
    issued_count: 0,
    verified_count: 0
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Generate a new capability token.

  ## Parameters
  - subject: The entity receiving the token (holon_id or agent_id)
  - capabilities: List of capabilities to grant
  - opts: Options including :ttl_seconds (default 3600)

  ## Returns
  - {:ok, token_string} on success
  - {:error, reason} on failure
  """
  @spec generate(String.t(), list(capability()), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate(subject, capabilities, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, subject, capabilities, opts})
  end

  @doc """
  Verify a capability token and check for required capability.

  ## Parameters
  - token_string: The encoded token to verify
  - required_capability: The capability that must be present

  ## Returns
  - :valid if token is valid and has the capability
  - {:invalid, reason} if verification fails
  """
  @spec verify(String.t(), capability()) :: :valid | {:invalid, atom()}
  def verify(token_string, required_capability) do
    GenServer.call(__MODULE__, {:verify, token_string, required_capability})
  end

  @doc """
  Revoke a token by its ID.

  ## Parameters
  - token_id: The UUID of the token to revoke

  ## Returns
  - :ok if revocation succeeded
  - {:error, :not_found} if token doesn't exist
  """
  @spec revoke(String.t()) :: :ok | {:error, :not_found}
  def revoke(token_id) do
    GenServer.call(__MODULE__, {:revoke, token_id})
  end

  @doc """
  Check if a token is revoked.
  """
  @spec revoked?(String.t()) :: boolean()
  def revoked?(token_id) do
    GenServer.call(__MODULE__, {:revoked?, token_id})
  end

  @doc """
  Get token statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Get the public key for external token verification.
  """
  @spec public_key() :: binary()
  def public_key do
    GenServer.call(__MODULE__, :public_key)
  end

  @doc """
  Verify a token using an external issuer's public key.
  Used for cross-holon token verification.
  """
  @spec verify_external(String.t(), binary(), capability()) :: :valid | {:invalid, atom()}
  def verify_external(token_string, issuer_public_key, required_capability) do
    case decode_token(token_string) do
      {:ok, token} ->
        verify_token_internal(token, issuer_public_key, required_capability)

      {:error, reason} ->
        {:invalid, reason}
    end
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    holon_id = Keyword.get(opts, :holon_id, "default_holon")
    keypair = :crypto.generate_key(:eddsa, :ed25519)

    state = %__MODULE__{
      keypair: keypair,
      holon_id: holon_id
    }

    Logger.info("[CapabilityToken] Initialized for holon #{holon_id} - SC-REG-015 compliant")

    {:ok, state}
  end

  @impl true
  def handle_call({:generate, subject, capabilities, opts}, _from, state) do
    ttl = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)

    token = create_token(state, subject, capabilities, ttl)
    token_string = encode_token(token)

    new_state = %{
      state
      | tokens: Map.put(state.tokens, token.id, token),
        issued_count: state.issued_count + 1
    }

    Logger.debug(
      "[CapabilityToken] Generated token #{token.id} for #{subject} with #{inspect(capabilities)}"
    )

    {:reply, {:ok, token_string}, new_state}
  end

  @impl true
  def handle_call({:verify, token_string, required_capability}, _from, state) do
    {public_key, _secret} = state.keypair

    result =
      case decode_token(token_string) do
        {:ok, token} ->
          # Check if token was issued by us
          if token.issuer == state.holon_id do
            verify_token_internal(token, public_key, required_capability, state.revoked)
          else
            {:invalid, :unknown_issuer}
          end

        {:error, reason} ->
          {:invalid, reason}
      end

    new_state =
      if result == :valid do
        %{state | verified_count: state.verified_count + 1}
      else
        state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:revoke, token_id}, _from, state) do
    if Map.has_key?(state.tokens, token_id) do
      new_revoked = MapSet.put(state.revoked, token_id)
      new_state = %{state | revoked: new_revoked}

      Logger.info("[CapabilityToken] Revoked token #{token_id} - SC-GRID-018")

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:revoked?, token_id}, _from, state) do
    {:reply, MapSet.member?(state.revoked, token_id), state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      holon_id: state.holon_id,
      issued_count: state.issued_count,
      verified_count: state.verified_count,
      active_tokens: map_size(state.tokens) - MapSet.size(state.revoked),
      revoked_count: MapSet.size(state.revoked)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:public_key, _from, state) do
    {public_key, _secret} = state.keypair
    {:reply, public_key, state}
  end

  # ============================================================================
  # Token Creation & Encoding
  # ============================================================================

  defp create_token(state, subject, capabilities, ttl_seconds) do
    {_public_key, secret_key} = state.keypair

    now = DateTime.utc_now()
    expires_at = DateTime.add(now, ttl_seconds, :second)
    token_id = generate_token_id()

    # Create payload for signing
    payload =
      build_signing_payload(token_id, state.holon_id, subject, capabilities, now, expires_at)

    signature = :crypto.sign(:eddsa, :none, payload, [secret_key, :ed25519])

    %{
      id: token_id,
      version: @token_version,
      issuer: state.holon_id,
      subject: subject,
      capabilities: capabilities,
      issued_at: now,
      expires_at: expires_at,
      signature: signature,
      revoked: false
    }
  end

  defp generate_token_id do
    # Generate a UUID v4
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    "#{Integer.to_string(a, 16)}-#{Integer.to_string(b, 16)}-#{Integer.to_string(c, 16)}-#{Integer.to_string(d, 16)}-#{Integer.to_string(e, 16)}"
    |> String.downcase()
  end

  defp build_signing_payload(id, issuer, subject, capabilities, issued_at, expires_at) do
    caps_string = capabilities |> Enum.sort() |> Enum.join(",")

    "TOKEN|#{id}|#{issuer}|#{subject}|#{caps_string}|#{DateTime.to_iso8601(issued_at)}|#{DateTime.to_iso8601(expires_at)}"
  end

  defp encode_token(token) do
    # Encode token as base64-encoded term
    token
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  defp decode_token(token_string) do
    try do
      token =
        token_string
        |> Base.url_decode64!(padding: false)
        |> :erlang.binary_to_term([:safe])

      {:ok, token}
    rescue
      _ -> {:error, :decode_failed}
    end
  end

  # ============================================================================
  # Token Verification
  # ============================================================================

  defp verify_token_internal(token, public_key, required_capability, revoked_set \\ MapSet.new()) do
    cond do
      # Check if revoked
      MapSet.member?(revoked_set, token.id) ->
        {:invalid, :revoked}

      # Check expiration
      DateTime.compare(DateTime.utc_now(), token.expires_at) == :gt ->
        {:invalid, :expired}

      # Check capability
      required_capability not in token.capabilities and :admin not in token.capabilities ->
        {:invalid, :missing_capability}

      # Verify signature
      not verify_token_signature(token, public_key) ->
        {:invalid, :invalid_signature}

      # All checks passed
      true ->
        :valid
    end
  end

  defp verify_token_signature(token, public_key) do
    payload =
      build_signing_payload(
        token.id,
        token.issuer,
        token.subject,
        token.capabilities,
        token.issued_at,
        token.expires_at
      )

    try do
      :crypto.verify(:eddsa, :none, payload, token.signature, [public_key, :ed25519])
    rescue
      _ -> false
    end
  end
end
