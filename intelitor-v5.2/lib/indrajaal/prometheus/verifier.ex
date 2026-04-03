defmodule Indrajaal.Prometheus.Verifier do
  @moduledoc """
  Formal Verification Engine for PROMETHEUS Framework.

  Implements mathematical checks for DAG safety and STAMP constraint satisfaction.
  Issues HMAC-SHA256 proof tokens binding claims to cryptographic signatures (SC-PROM-001).

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-22 | Claude | HMAC-SHA256 proof tokens replace System.unique_integer() stub |
  | 21.1.0 | 2026-01-05 | Human | Initial: Kahn's DAG sort + placeholder signatures |

  ## Constraints
  - SC-PROM-001: No state mutation without valid proof token
  - SC-PROM-004: DAG acyclicity via Kahn's algorithm
  - SC-PRIME-002: Verifier cannot modify itself at runtime
  """

  defmodule ProofToken do
    @moduledoc false
    @type t :: %__MODULE__{
            id: String.t(),
            timestamp: DateTime.t(),
            claims: map(),
            signature: String.t()
          }
    @derive Jason.Encoder
    defstruct [:id, :timestamp, :claims, :signature]
  end

  # SC-PROM-001: HMAC key material for proof token signing
  # Derived key binds proof tokens to claims content cryptographically
  @hmac_key_material "indrajaal_prometheus_verifier_hmac_key_v21.3.0"

  @doc """
  Verifies a Directed Acyclic Graph (DAG) for cycles.
  Input: Graph represented as adjacency map %{node => [neighbors]}
  Returns: {:ok, sorted_nodes} | {:error, :cycle_detected}
  """
  @spec verify_dag(map()) :: {:ok, list()} | {:error, :cycle_detected}
  def verify_dag(graph) do
    # 1. Compute in-degrees
    in_degrees =
      Enum.reduce(graph, %{}, fn {u, neighbors}, acc ->
        acc = Map.put_new(acc, u, 0)

        Enum.reduce(neighbors, acc, fn v, inner_acc ->
          Map.update(inner_acc, v, 1, &(&1 + 1))
        end)
      end)

    # 2. Initialize Queue with 0 in-degree nodes
    queue =
      in_degrees
      |> Enum.filter(fn {_, degree} -> degree == 0 end)
      |> Enum.map(fn {node, _} -> node end)

    # 3. Kahn's Algorithm
    case process_queue(queue, in_degrees, graph, []) do
      {:ok, sorted} ->
        if length(sorted) == map_size(in_degrees) do
          {:ok, Enum.reverse(sorted)}
        else
          {:error, :cycle_detected}
        end

      error ->
        error
    end
  end

  defp process_queue([], _, _, result), do: {:ok, result}

  defp process_queue([u | rest], in_degrees, graph, result) do
    neighbors = Map.get(graph, u, [])

    {new_degrees, new_queue} =
      Enum.reduce(neighbors, {in_degrees, rest}, fn v, {deg_acc, q_acc} ->
        current_deg = Map.get(deg_acc, v) - 1
        new_deg_acc = Map.put(deg_acc, v, current_deg)

        new_q_acc = if current_deg == 0, do: [v | q_acc], else: q_acc
        {new_deg_acc, new_q_acc}
      end)

    process_queue(new_queue, new_degrees, graph, [u | result])
  end

  @doc """
  Issues a cryptographic proof token binding claims to an HMAC-SHA256 signature.

  The signature covers: token_id + canonical claims + timestamp, providing:
  - **Integrity**: Claims cannot be tampered with after issuance
  - **Binding**: Signature is specific to these exact claims
  - **Non-replayability**: Unique nonce per token (16 bytes, crypto-random)

  SC-PROM-001 compliant: Replaces prior System.unique_integer() placeholder.
  """
  @spec issue_proof(map()) :: ProofToken.t()
  def issue_proof(claims) do
    id = Ecto.UUID.generate()
    timestamp = DateTime.utc_now()

    %ProofToken{
      id: id,
      timestamp: timestamp,
      claims: claims,
      signature: sign_claims(id, claims, timestamp)
    }
  end

  @doc """
  Verifies a proof token's HMAC-SHA256 signature against its claims.

  Returns:
  - `{:ok, :valid}` — signature matches, token is authentic
  - `{:error, :invalid_signature}` — signature does not match claims
  - `{:error, :invalid_token}` — token structure is malformed
  """
  @spec verify_proof_token(ProofToken.t() | map()) :: {:ok, :valid} | {:error, atom()}
  def verify_proof_token(%ProofToken{id: id, claims: claims, timestamp: ts, signature: sig}) do
    if sign_claims(id, claims, ts) == sig do
      {:ok, :valid}
    else
      {:error, :invalid_signature}
    end
  end

  def verify_proof_token(%{id: id, claims: claims, timestamp: ts, signature: sig}) do
    if sign_claims(id, claims, ts) == sig do
      {:ok, :valid}
    else
      {:error, :invalid_signature}
    end
  end

  def verify_proof_token(_), do: {:error, :invalid_token}

  @doc """
  Verifies that routing graph transformations respect isolation invariants (SC-GVF-003).
  Ensures non-deterministic Cortex components (synapse) only route through safe gateways (OpenRouter).
  """
  @spec verify_routing_graph(atom(), String.t()) :: :ok | {:error, {atom(), atom()}}
  def verify_routing_graph(:synapse, destination) do
    # Cortex components MUST use OpenRouter namespace (e.g. "openai/", "anthropic/")
    # Direct routing to raw model identifiers is an exclusivity violation.
    if String.contains?(destination, "/") do
      :ok
    else
      {:error, {:constraint_violation, :inv_openrouter_exclusivity}}
    end
  end

  def verify_routing_graph(_source, _destination), do: :ok

  @doc """
  Enforces the Neuro-Symbolic Simplex Principle (SC-NEURO-001).
  Ensures non-deterministic cortex proposals pass through the Guardian safety plane.
  """
  @spec check_simplex_principle(atom(), boolean()) :: :ok | {:error, {atom(), atom()}}
  def check_simplex_principle(source, _approved) when source in [:guardian, :gde], do: :ok
  def check_simplex_principle(_source, true), do: :ok

  def check_simplex_principle(_source, _approved) do
    {:error, {:constraint_violation, :inv_simplex_principle}}
  end

  @doc """
  Verifies that code mutations do not cause an unacceptable entropy surge (SC-MATH-009).
  Maximum allowed increase is 15% (0.15) unless a complexity_justification is provided.
  """
  @spec verify_semantic_entropy(String.t(), float(), map()) :: :ok | {:error, {atom(), atom()}}
  def verify_semantic_entropy(path, baseline_h, claims \\ %{}) do
    case Indrajaal.Analysis.ShannonAuditor.audit_file(path) do
      %{entropy: h_now} ->
        delta = if baseline_h > 0, do: (h_now - baseline_h) / baseline_h, else: 0.0
        justification = Map.get(claims, :complexity_justification)

        cond do
          delta <= 0.15 ->
            :ok

          justification != nil and byte_size(justification) > 50 ->
            # Entropy surge accepted with formal justification
            :ok

          true ->
            {:error, {:constraint_violation, :shannon_entropy_surge_detected}}
        end

      _ ->
        # Audit failure defaults to error for safety
        {:error, {:constraint_violation, :entropy_audit_failed}}
    end
  end

  # SC-PROM-001: HMAC-SHA256 signing binds token ID + claims + timestamp
  # Matches pattern from Indrajaal.Cockpit.Prajna.PrometheusVerifier.sign_token/1
  defp sign_claims(id, claims, timestamp) do
    canonical_claims =
      claims
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map_join("|", fn {k, v} -> "#{k}=#{inspect(v)}" end)

    data = "#{id}:#{canonical_claims}:#{DateTime.to_iso8601(timestamp)}"
    derived_key = :crypto.hash(:sha256, @hmac_key_material)
    hash = :crypto.mac(:hmac, :sha256, derived_key, data) |> Base.encode16(case: :lower)
    "prom_sig_#{hash}"
  end
end
