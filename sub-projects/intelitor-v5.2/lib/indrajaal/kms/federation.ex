defmodule Indrajaal.KMS.Federation do
  @moduledoc """
  L6/L7 Ecosystem Federation with Merkle-Chained Trust.

  WHAT: Provides cryptographic foundation for cross-cluster trust
  negotiation. Uses Merkle trees to verify global state consistency
  across the biomorphic holon federation.

  WHY: L7 federation requires verifiable state integrity across
  autonomous clusters. Merkle trees provide O(log n) proof of
  inclusion and detect divergence efficiently (SC-SIL6-009).

  CONSTRAINTS:
  - SC-SIL6-009: Merkle tree verification for federation state
  - SC-REG-010: Protocol version negotiation before communication
  - SC-REG-011: Merkle proofs on demand
  - SC-REG-012: Federation attestation every hour
  - SC-FRAC-004: Cross-holon attestation for decisions

  TECHNIQUES:
  | Technique | Purpose |
  |-----------|---------|
  | Merkle Tree | Verifiable state hashing |
  | Version Negotiation | Protocol compatibility |
  | Attestation | Periodic trust verification |
  """
  use GenServer
  require Logger

  @type merkle_root :: binary()
  @type merkle_proof :: [%{hash: binary(), side: :left | :right}]
  @type federation_packet :: %{
          origin_cluster: String.t(),
          target_cluster: String.t(),
          merkle_root: merkle_root(),
          version: String.t(),
          proof: merkle_proof()
        }

  @protocol_version "21.2.1"
  @attestation_interval_ms 3_600_000

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Negotiates a trust relationship with a peer cluster."
  def negotiate_federation(peer_id, remote_version) do
    GenServer.call(__MODULE__, {:negotiate, peer_id, remote_version})
  end

  @doc "Generates the Merkle root for the current cluster state."
  def generate_merkle_root do
    GenServer.call(__MODULE__, :generate_root)
  end

  @doc "Generates a Merkle root from a list of data leaves."
  def merkle_root_from(leaves) when is_list(leaves) do
    build_merkle_root(leaves)
  end

  @doc "Verifies a Merkle proof for a given leaf against a root."
  def verify_proof(leaf, proof, expected_root) do
    computed = apply_proof(hash_leaf(leaf), proof)
    computed == expected_root
  end

  @doc "Returns current federation state summary."
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Records an attestation from a peer."
  def attest(peer_id, their_root) do
    GenServer.call(__MODULE__, {:attest, peer_id, their_root})
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.debug("[KMS.Federation] Initializing Federation Kernel")
    schedule_attestation()

    {:ok,
     %{
       peers: %{},
       local_root: nil,
       attestations: %{},
       last_attestation: nil
     }}
  end

  @impl true
  def handle_call({:negotiate, peer_id, remote_version}, _from, state) do
    result =
      with :ok <- verify_version_compatibility(remote_version),
           root <- compute_local_root() do
        peer_info = %{
          version: remote_version,
          negotiated_at: System.system_time(:second),
          root_at_negotiation: root
        }

        new_peers = Map.put(state.peers, peer_id, peer_info)

        Logger.debug("[KMS.Federation] Negotiation succeeded with #{peer_id}")

        {:ok,
         %{
           merkle_root: root,
           protocol_version: @protocol_version,
           capabilities: [:fpps_consensus, :merkle_verify, :version_vectors]
         }}
        |> then(&{&1, %{state | peers: new_peers, local_root: root}})
      else
        {:error, reason} ->
          Logger.warning("[KMS.Federation] Negotiation failed with #{peer_id}: #{reason}")
          {{:error, reason}, state}
      end

    {reply, new_state} = result
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call(:generate_root, _from, state) do
    root = compute_local_root()
    {:reply, root, %{state | local_root: root}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    summary = %{
      peer_count: map_size(state.peers),
      peers: Map.keys(state.peers),
      local_root: state.local_root,
      attestation_count: map_size(state.attestations),
      last_attestation: state.last_attestation
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_call({:attest, peer_id, their_root}, _from, state) do
    our_root = state.local_root || compute_local_root()

    result =
      if our_root == their_root do
        :consistent
      else
        :diverged
      end

    attestation = %{
      peer_id: peer_id,
      their_root: their_root,
      our_root: our_root,
      result: result,
      timestamp: System.system_time(:second)
    }

    new_attestations = Map.put(state.attestations, peer_id, attestation)

    {:reply, {:ok, result},
     %{
       state
       | attestations: new_attestations,
         last_attestation: attestation,
         local_root: our_root
     }}
  end

  @impl true
  def handle_info(:attestation_tick, state) do
    schedule_attestation()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private: Merkle tree construction
  # ---------------------------------------------------------------------------

  defp compute_local_root do
    # Build Merkle root from holon state files in data/holons/
    holon_dir = "data/holons"

    leaves =
      if File.dir?(holon_dir) do
        holon_dir
        |> File.ls!()
        |> Enum.sort()
        |> Enum.flat_map(fn entry ->
          path = Path.join(holon_dir, entry)

          if File.dir?(path) do
            # Hash each holon directory's state.db if it exists
            db_path = Path.join(path, "state.db")

            if File.exists?(db_path) do
              case File.read(db_path) do
                {:ok, content} -> [content]
                _ -> [entry]
              end
            else
              [entry]
            end
          else
            []
          end
        end)
      else
        # No holon directory — use genesis state
        ["genesis_#{@protocol_version}"]
      end

    build_merkle_root(leaves)
  end

  @doc false
  def build_merkle_root([]), do: hash_leaf("")
  def build_merkle_root([single]), do: hash_leaf(single)

  def build_merkle_root(leaves) do
    hashed = Enum.map(leaves, &hash_leaf/1)
    reduce_tree(hashed)
  end

  defp reduce_tree([root]), do: root

  defp reduce_tree(hashes) do
    # Pad with last element if odd number of nodes
    padded =
      if rem(length(hashes), 2) == 1 do
        hashes ++ [List.last(hashes)]
      else
        hashes
      end

    paired =
      padded
      |> Enum.chunk_every(2)
      |> Enum.map(fn [left, right] ->
        :crypto.hash(:sha256, left <> right)
      end)

    reduce_tree(paired)
  end

  defp hash_leaf(data) when is_binary(data) do
    :crypto.hash(:sha256, data)
  end

  defp hash_leaf(data) do
    :crypto.hash(:sha256, :erlang.term_to_binary(data))
  end

  # Applies a Merkle proof path to recompute the root from a leaf hash
  defp apply_proof(current_hash, []), do: current_hash

  defp apply_proof(current_hash, [%{hash: sibling, side: :left} | rest]) do
    apply_proof(:crypto.hash(:sha256, sibling <> current_hash), rest)
  end

  defp apply_proof(current_hash, [%{hash: sibling, side: :right} | rest]) do
    apply_proof(:crypto.hash(:sha256, current_hash <> sibling), rest)
  end

  # ---------------------------------------------------------------------------
  # Private: version negotiation (SC-REG-010)
  # ---------------------------------------------------------------------------

  defp verify_version_compatibility(remote_version) do
    local_parts = String.split(@protocol_version, ".")
    remote_parts = String.split(remote_version, ".")

    case {local_parts, remote_parts} do
      {[lmaj | _], [rmaj | _]} when lmaj == rmaj ->
        :ok

      _ ->
        {:error, :incompatible_major_version}
    end
  rescue
    _ -> {:error, :invalid_version_format}
  end

  defp schedule_attestation do
    Process.send_after(self(), :attestation_tick, @attestation_interval_ms)
  end
end
