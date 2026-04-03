defmodule Indrajaal.Formal.ProofRegistry do
  @moduledoc """
  Proof Registry — L7 Formal Layer

  ## Design Intent
  Maintains a registry of formal proofs and their verification status.
  Proofs can be registered from multiple sources (Agda, QuickCheck, manual)
  and tracked through their lifecycle: :pending → :verified → :invalidated.

  Each proof is associated with a STAMP constraint and a verification method.
  The registry provides coverage metrics showing which constraints have
  formal backing.

  ## STAMP Constraints
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-HASH-001: Deterministic hash computation
  - SC-MATH-001: Discipline health monitored
  - SC-CV-001: Coverage validation framework

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :formal_proofs
  @pubsub_topic "formal:proofs"

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type proof_id :: String.t()
  @type proof_status :: :pending | :verified | :invalidated
  @type verification_method :: :agda | :quickcheck | :property_test | :manual | :model_check

  @type proof :: %{
          id: proof_id(),
          constraint_id: String.t(),
          description: String.t(),
          method: verification_method(),
          status: proof_status(),
          source_file: String.t() | nil,
          verified_at: non_neg_integer() | nil,
          registered_at: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a new proof."
  @spec register_proof(proof_id(), String.t(), String.t(), verification_method(), keyword()) ::
          :ok
  def register_proof(id, constraint_id, description, method, opts \\ []) do
    GenServer.call(@name, {:register, id, constraint_id, description, method, opts})
  end

  @doc "Mark a proof as verified."
  @spec verify(proof_id()) :: :ok | {:error, :not_found}
  def verify(id) do
    GenServer.call(@name, {:verify, id})
  end

  @doc "Mark a proof as invalidated."
  @spec invalidate(proof_id(), String.t()) :: :ok | {:error, :not_found}
  def invalidate(id, reason \\ "Invalidated") do
    GenServer.call(@name, {:invalidate, id, reason})
  end

  @doc "Get a specific proof by ID."
  @spec get(proof_id()) :: {:ok, proof()} | {:error, :not_found}
  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, proof}] -> {:ok, proof}
      [] -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @doc "List all proofs, optionally filtered by status."
  @spec list(proof_status() | nil) :: [proof()]
  def list(status \\ nil) do
    GenServer.call(@name, {:list, status})
  end

  @doc "Get proof coverage metrics."
  @spec coverage() :: map()
  def coverage do
    GenServer.call(@name, :coverage)
  end

  @doc "List all proofs for a specific STAMP constraint."
  @spec for_constraint(String.t()) :: [proof()]
  def for_constraint(constraint_id) do
    GenServer.call(@name, {:for_constraint, constraint_id})
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    register_built_in_proofs()

    Logger.info("[ProofRegistry] Started [SC-VER-074]")

    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, id, constraint_id, description, method, opts}, _from, state) do
    proof = %{
      id: id,
      constraint_id: constraint_id,
      description: description,
      method: method,
      status: :pending,
      source_file: Keyword.get(opts, :source_file),
      verified_at: nil,
      registered_at: System.system_time(:millisecond)
    }

    :ets.insert(@table, {id, proof})

    Logger.debug("[ProofRegistry] Registered: #{id} for #{constraint_id} [SC-VER-074]")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:verify, id}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, proof}] ->
        updated = %{proof | status: :verified, verified_at: System.system_time(:millisecond)}
        :ets.insert(@table, {id, updated})
        broadcast_proof_event(:verified, updated)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:invalidate, id, _reason}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, proof}] ->
        updated = %{proof | status: :invalidated}
        :ets.insert(@table, {id, updated})
        broadcast_proof_event(:invalidated, updated)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:list, nil}, _from, state) do
    proofs = :ets.tab2list(@table) |> Enum.map(fn {_id, p} -> p end)
    {:reply, proofs, state}
  end

  @impl true
  def handle_call({:list, status}, _from, state) do
    proofs =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_id, p} -> p.status == status end)
      |> Enum.map(fn {_id, p} -> p end)

    {:reply, proofs, state}
  end

  @impl true
  def handle_call(:coverage, _from, state) do
    all = :ets.tab2list(@table) |> Enum.map(fn {_id, p} -> p end)
    total = length(all)
    verified = Enum.count(all, &(&1.status == :verified))
    pending = Enum.count(all, &(&1.status == :pending))
    invalidated = Enum.count(all, &(&1.status == :invalidated))

    constraints_covered =
      all
      |> Enum.filter(&(&1.status == :verified))
      |> Enum.map(& &1.constraint_id)
      |> Enum.uniq()
      |> length()

    coverage_pct = if total > 0, do: Float.round(verified / total * 100, 1), else: 0.0

    {:reply,
     %{
       total: total,
       verified: verified,
       pending: pending,
       invalidated: invalidated,
       constraints_covered: constraints_covered,
       coverage_pct: coverage_pct
     }, state}
  end

  @impl true
  def handle_call({:for_constraint, constraint_id}, _from, state) do
    proofs =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_id, p} -> p.constraint_id == constraint_id end)
      |> Enum.map(fn {_id, p} -> p end)

    {:reply, proofs, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp register_built_in_proofs do
    built_ins = [
      {"agda-graph-acyclicity", "SC-BOOT-008", "DAG acyclicity proof", :agda,
       "native/agda/AcyclicityProofs.agda"},
      {"agda-graph-properties", "SC-GRAPH-001", "Graph structural properties", :agda,
       "native/agda/GraphProperties.agda"}
    ]

    for {id, constraint, desc, method, source} <- built_ins do
      proof = %{
        id: id,
        constraint_id: constraint,
        description: desc,
        method: method,
        status: :verified,
        source_file: source,
        verified_at: System.system_time(:millisecond),
        registered_at: System.system_time(:millisecond)
      }

      :ets.insert(@table, {id, proof})
    end
  end

  defp broadcast_proof_event(event, proof) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:proof_event, %{event: event, proof_id: proof.id, constraint_id: proof.constraint_id}}
    )
  rescue
    _ -> :ok
  end
end
