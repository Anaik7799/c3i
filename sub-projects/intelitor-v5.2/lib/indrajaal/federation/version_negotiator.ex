defmodule Indrajaal.Federation.VersionNegotiator do
  @moduledoc """
  Federation Version Negotiator - Protocol handshake and compatibility matrix.

  ## WHAT
  Negotiates protocol versions between federation peers to ensure compatibility.
  Implements graceful degradation for backward compatibility.

  ## WHY
  Distributed holons may run different versions. Negotiation ensures communication
  uses the highest mutually-supported protocol version.

  ## STAMP Constraints
  - SC-REG-010: Protocol version in every block
  - SC-REG-013: Cross-holon attestation for federation
  - SC-RECONFIG-010: Federation notification required

  ## AOR Rules
  - AOR-REG-010: Negotiate protocol version before cross-holon communication
  - AOR-RECONFIG-007: May migrate to any substrate that supports regeneration

  ## Protocol Versions
  | Version | Features |
  |---------|----------|
  | 1 | Basic announce/ack/commit |
  | 2 | Version vectors, merkle proofs |
  | 3 | Reed-Solomon error correction |

  ## Compatibility Matrix
  - Version 3 can communicate with 1, 2, 3
  - Version 2 can communicate with 1, 2
  - Version 1 can communicate with 1 only

  ## Negotiation Protocol
  1. HELLO: Send supported protocol versions
  2. SELECT: Choose highest mutual version
  3. CONFIRM: Acknowledge selected version
  4. READY: Begin communication
  """

  use GenServer
  require Logger

  @type holon_id :: String.t()
  @type protocol_version :: pos_integer()
  @type negotiation_state :: :pending | :negotiating | :confirmed | :failed
  @type negotiation :: %{
          peer_id: holon_id(),
          our_versions: list(protocol_version()),
          peer_versions: list(protocol_version()),
          selected_version: protocol_version() | nil,
          state: negotiation_state(),
          started_at: DateTime.t()
        }

  @current_protocol_version 3
  @supported_versions [1, 2, 3]
  @negotiation_timeout_ms 10_000

  # Compatibility matrix: version -> compatible_with
  @compatibility_matrix %{
    3 => [1, 2, 3],
    2 => [1, 2],
    1 => [1]
  }

  # Feature matrix: version -> features
  @feature_matrix %{
    1 => [:basic_announce, :basic_ack, :basic_commit],
    2 => [:basic_announce, :basic_ack, :basic_commit, :version_vectors, :merkle_proofs],
    3 => [
      :basic_announce,
      :basic_ack,
      :basic_commit,
      :version_vectors,
      :merkle_proofs,
      :reed_solomon
    ]
  }

  # GenServer API

  @doc """
  Starts the VersionNegotiator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initiates protocol negotiation with a peer.

  Returns `{:ok, negotiated_version}` on success,
  or `{:error, reason}` on failure.

  ## STAMP: SC-REG-010 - Protocol version negotiation
  """
  @spec negotiate(holon_id()) :: {:ok, protocol_version()} | {:error, term()}
  def negotiate(peer_id) do
    GenServer.call(__MODULE__, {:negotiate, peer_id}, @negotiation_timeout_ms)
  end

  @doc """
  Returns the negotiated protocol version for a peer.
  """
  @spec get_version(holon_id()) :: {:ok, protocol_version()} | {:error, :not_negotiated}
  def get_version(peer_id) do
    GenServer.call(__MODULE__, {:get_version, peer_id})
  end

  @doc """
  Returns all active negotiations.
  """
  @spec active_negotiations() :: list(negotiation())
  def active_negotiations do
    GenServer.call(__MODULE__, :active)
  end

  @doc """
  Returns the current protocol version of this holon.
  """
  @spec current_version() :: protocol_version()
  def current_version, do: @current_protocol_version

  @doc """
  Returns all supported protocol versions.
  """
  @spec supported_versions() :: list(protocol_version())
  def supported_versions, do: @supported_versions

  @doc """
  Checks if a specific version is supported.
  """
  @spec version_supported?(protocol_version()) :: boolean()
  def version_supported?(version), do: version in @supported_versions

  @doc """
  Returns features available for a protocol version.
  """
  @spec features_for_version(protocol_version()) :: list(atom())
  def features_for_version(version) do
    Map.get(@feature_matrix, version, [])
  end

  @doc """
  Checks if a feature is available at a specific version.
  """
  @spec feature_available?(atom(), protocol_version()) :: boolean()
  def feature_available?(feature, version) do
    feature in features_for_version(version)
  end

  @doc """
  Returns all versions that a given version can communicate with.

  Uses the compatibility matrix to determine which protocol versions
  can interoperate through graceful degradation.

  ## Examples

      iex> VersionNegotiator.compatible_versions(3)
      [1, 2, 3]

      iex> VersionNegotiator.compatible_versions(1)
      [1]
  """
  @spec compatible_versions(protocol_version()) :: list(protocol_version())
  def compatible_versions(version) do
    Map.get(@compatibility_matrix, version, [])
  end

  @doc """
  Returns the highest mutually compatible version between two peers.
  """
  @spec find_compatible_version(list(protocol_version()), list(protocol_version())) ::
          {:ok, protocol_version()} | {:error, :incompatible}
  def find_compatible_version(our_versions, peer_versions) do
    # Find highest version that both sides support
    mutual = our_versions -- (our_versions -- peer_versions)

    if Enum.empty?(mutual) do
      {:error, :incompatible}
    else
      {:ok, Enum.max(mutual)}
    end
  end

  @doc """
  Handles incoming HELLO message from a peer.
  """
  @spec handle_hello(holon_id(), list(protocol_version())) ::
          {:ok, protocol_version()} | {:error, term()}
  def handle_hello(peer_id, peer_versions) do
    GenServer.call(__MODULE__, {:hello_received, peer_id, peer_versions})
  end

  @doc """
  Handles incoming SELECT message from a peer.
  """
  @spec handle_select(holon_id(), protocol_version()) :: :ok | {:error, term()}
  def handle_select(peer_id, selected_version) do
    GenServer.call(__MODULE__, {:select_received, peer_id, selected_version})
  end

  @doc """
  Gracefully degrades to a lower protocol version if needed.

  ## STAMP: SC-RECONFIG-007 - Graceful degradation
  """
  @spec degrade_version(holon_id(), protocol_version()) :: :ok | {:error, term()}
  def degrade_version(peer_id, target_version) do
    GenServer.call(__MODULE__, {:degrade, peer_id, target_version})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[SC-REG-010] VersionNegotiator started (protocol v#{@current_protocol_version})")

    state = %{
      current_version: @current_protocol_version,
      supported_versions: @supported_versions,
      negotiations: %{},
      confirmed_versions: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:negotiate, peer_id}, from, state) do
    negotiation = %{
      peer_id: peer_id,
      our_versions: @supported_versions,
      peer_versions: [],
      selected_version: nil,
      state: :pending,
      started_at: DateTime.utc_now(),
      caller: from
    }

    # Send HELLO to peer
    send_hello(peer_id, @supported_versions)

    # Schedule timeout
    Process.send_after(self(), {:negotiation_timeout, peer_id}, @negotiation_timeout_ms)

    new_negotiations = Map.put(state.negotiations, peer_id, negotiation)

    emit_telemetry(:negotiate_start, %{peer_id: peer_id})

    {:noreply, %{state | negotiations: new_negotiations}}
  end

  @impl true
  def handle_call({:get_version, peer_id}, _from, state) do
    case Map.get(state.confirmed_versions, peer_id) do
      nil -> {:reply, {:error, :not_negotiated}, state}
      version -> {:reply, {:ok, version}, state}
    end
  end

  @impl true
  def handle_call(:active, _from, state) do
    active =
      state.negotiations
      |> Map.values()
      |> Enum.filter(&(&1.state in [:pending, :negotiating]))

    {:reply, active, state}
  end

  @impl true
  def handle_call({:hello_received, peer_id, peer_versions}, _from, state) do
    Logger.debug("[SC-REG-010] HELLO received from #{peer_id}: #{inspect(peer_versions)}")

    case find_compatible_version(@supported_versions, peer_versions) do
      {:ok, version} ->
        # Send SELECT with chosen version
        send_select(peer_id, version)

        # Update or create negotiation
        negotiation =
          Map.get(state.negotiations, peer_id, %{
            peer_id: peer_id,
            our_versions: @supported_versions,
            state: :negotiating,
            started_at: DateTime.utc_now()
          })

        negotiation = %{
          negotiation
          | peer_versions: peer_versions,
            selected_version: version,
            state: :negotiating
        }

        new_negotiations = Map.put(state.negotiations, peer_id, negotiation)
        {:reply, {:ok, version}, %{state | negotiations: new_negotiations}}

      {:error, :incompatible} ->
        Logger.warning("[SC-REG-010] Incompatible peer #{peer_id}: #{inspect(peer_versions)}")
        emit_telemetry(:incompatible, %{peer_id: peer_id, peer_versions: peer_versions})
        {:reply, {:error, :incompatible}, state}
    end
  end

  @impl true
  def handle_call({:select_received, peer_id, selected_version}, _from, state) do
    Logger.debug("[SC-REG-010] SELECT received from #{peer_id}: v#{selected_version}")

    if selected_version in @supported_versions do
      # Confirm the version
      send_confirm(peer_id, selected_version)

      # Update confirmed versions
      new_confirmed = Map.put(state.confirmed_versions, peer_id, selected_version)

      # Complete negotiation
      case Map.get(state.negotiations, peer_id) do
        nil ->
          {:reply, :ok, %{state | confirmed_versions: new_confirmed}}

        negotiation ->
          updated = %{negotiation | selected_version: selected_version, state: :confirmed}
          new_negotiations = Map.put(state.negotiations, peer_id, updated)

          # Reply to original caller if exists
          if negotiation[:caller] do
            GenServer.reply(negotiation.caller, {:ok, selected_version})
          end

          emit_telemetry(:confirmed, %{peer_id: peer_id, version: selected_version})

          Logger.info("[SC-REG-010] Protocol v#{selected_version} confirmed with #{peer_id}")

          {:reply, :ok,
           %{state | negotiations: new_negotiations, confirmed_versions: new_confirmed}}
      end
    else
      Logger.warning("[SC-REG-010] Unsupported version #{selected_version} from #{peer_id}")
      {:reply, {:error, :unsupported_version}, state}
    end
  end

  @impl true
  def handle_call({:degrade, peer_id, target_version}, _from, state) do
    current = Map.get(state.confirmed_versions, peer_id)

    cond do
      is_nil(current) ->
        {:reply, {:error, :not_negotiated}, state}

      target_version > current ->
        {:reply, {:error, :cannot_upgrade}, state}

      target_version not in @supported_versions ->
        {:reply, {:error, :unsupported_version}, state}

      true ->
        Logger.info("[SC-RECONFIG-007] Degrading to v#{target_version} with #{peer_id}")
        new_confirmed = Map.put(state.confirmed_versions, peer_id, target_version)
        emit_telemetry(:degraded, %{peer_id: peer_id, from: current, to: target_version})
        {:reply, :ok, %{state | confirmed_versions: new_confirmed}}
    end
  end

  @impl true
  def handle_info({:negotiation_timeout, peer_id}, state) do
    case Map.get(state.negotiations, peer_id) do
      nil ->
        {:noreply, state}

      negotiation when negotiation.state in [:pending, :negotiating] ->
        Logger.warning("[SC-REG-010] Negotiation timeout with #{peer_id}")

        # Notify original caller
        if negotiation[:caller] do
          GenServer.reply(negotiation.caller, {:error, :timeout})
        end

        updated = %{negotiation | state: :failed}
        new_negotiations = Map.put(state.negotiations, peer_id, updated)

        emit_telemetry(:timeout, %{peer_id: peer_id})

        {:noreply, %{state | negotiations: new_negotiations}}

      _ ->
        {:noreply, state}
    end
  end

  # Private Functions

  defp send_hello(peer_id, versions) do
    Logger.debug("[SC-REG-010] Sending HELLO to #{peer_id}: #{inspect(versions)}")
    # Production: Send via Zenoh
    send_to_peer(peer_id, {:hello, versions})
  end

  defp send_select(peer_id, version) do
    Logger.debug("[SC-REG-010] Sending SELECT to #{peer_id}: v#{version}")
    send_to_peer(peer_id, {:select, version})
  end

  defp send_confirm(peer_id, version) do
    Logger.debug("[SC-REG-010] Sending CONFIRM to #{peer_id}: v#{version}")
    send_to_peer(peer_id, {:confirm, version})
  end

  defp send_to_peer(_peer_id, _message) do
    # Production: Use Zenoh pub/sub
    :ok
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :federation, :negotiation, event],
      %{timestamp: System.monotonic_time()},
      metadata
    )
  end
end
