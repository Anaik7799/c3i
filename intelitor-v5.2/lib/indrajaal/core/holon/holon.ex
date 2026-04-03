defmodule Indrajaal.Core.Holon do
  @moduledoc """
  Core Holon Behaviour - The Fractal Atom of Indrajaal v20.0.0

  Every component from function to federation implements this interface.
  Based on Viable System Model (VSM) by Stafford Beer.

  ## The 5 Systems (VSM)
  - S1: Operations (The Doing) - Business logic execution
  - S2: Coordination (The Balancing) - Anti-oscillation, gossip
  - S3: Control (The Guard) - Resource limits, inference
  - S4: Intelligence (The Future) - Monte Carlo, planning
  - S5: Policy (The Identity) - Constitution, STAMP

  ## Holon Hierarchy (7 Fractal Layers)
  1. Function - Smallest unit of work
  2. Module - Collection of functions
  3. Agent - Autonomous actor
  4. Container - Deployment unit
  5. Node - Physical/virtual machine
  6. Cluster - Set of nodes
  7. Federation - Set of clusters

  ## STAMP Constraints
  - SC-HOL-001: All holons MUST implement all 5 systems
  - SC-HOL-002: Holons MUST verify constitution on startup
  - SC-HOL-003: Holons MUST report to parent within 100ms
  - SC-HOL-004: Holons MUST propagate health to children

  ## Category Theory
  - Holon forms an Endofunctor in 𝒞_Indrajaal
  - Children : Holon → List Holon
  - fmap : (Holon → Holon) → List Holon → List Holon
  """

  @type holon_id :: String.t()
  @type layer :: :function | :module | :agent | :container | :node | :cluster | :federation
  @type health :: :healthy | :degraded | :critical | :failed

  @type vsm_state :: %{
          s1: map(),
          s2: map(),
          s3: map(),
          s4: map(),
          s5: map()
        }

  @type holon_state :: %{
          id: holon_id(),
          layer: layer(),
          parent: holon_id() | nil,
          children: [holon_id()],
          health: health(),
          vsm: vsm_state(),
          metadata: map()
        }

  # VSM System Callbacks

  @doc """
  S1: Operations - Execute business logic.

  Returns the result of the operation or an error.
  """
  @callback system1_operations(context :: map()) ::
              {:ok, result :: term()} | {:error, reason :: term()}

  @doc """
  S2: Coordination - Balance with peers, prevent oscillation.

  Called periodically to coordinate with peer holons at the same level.
  """
  @callback system2_coordination(peers :: [holon_id()]) ::
              :ok | {:error, reason :: term()}

  @doc """
  S3: Control - Enforce resource budgets and limits.

  Returns whether the holon is within its resource budget.
  """
  @callback system3_control(budget :: map()) ::
              {:within_budget | :over_budget, metrics :: map()}

  @doc """
  S4: Intelligence - Plan for the future.

  Uses observations to generate plans with confidence scores.
  """
  @callback system4_intelligence(observations :: list()) ::
              {plan :: term(), confidence :: float()}

  @doc """
  S5: Policy - Verify constitution and identity.

  Returns the constitution verification status.
  """
  @callback system5_policy() ::
              {:verified | :violated, constitution_hash :: binary()}

  # Structural Callbacks

  @doc "Returns the unique identifier for this holon."
  @callback holon_id() :: holon_id()

  @doc "Returns the fractal layer of this holon."
  @callback layer() :: layer()

  @doc "Returns the parent holon's ID, or nil if root."
  @callback parent() :: holon_id() | nil

  @doc "Returns the list of child holon IDs."
  @callback children() :: [holon_id()]

  @doc "Returns the current health status."
  @callback health() :: health()

  @doc """
  Injects the Holon behaviour and default implementations.
  """
  defmacro __using__(opts) do
    quote do
      @behaviour Indrajaal.Core.Holon

      use GenServer
      require Logger

      alias Indrajaal.Core.Constitution
      alias Indrajaal.Core.Constitution.Verifier
      alias Indrajaal.Core.Holon.State
      alias Indrajaal.Core.Holon.Metrics
      alias Indrajaal.Core.Holon.Health

      @holon_layer unquote(opts[:layer] || :module)
      @holon_parent unquote(opts[:parent])

      # Default state
      @impl true
      def init(init_arg) do
        # Verify constitution on startup (SC-HOL-002)
        case Verifier.verify() do
          {:ok, _} ->
            state = State.new(__MODULE__, @holon_layer, init_arg)
            {:ok, state}

          {:error, :constitution_violated, details} ->
            Logger.error("Holon startup blocked: constitution violated")
            {:stop, {:constitution_violated, details}}
        end
      end

      # Default S1: Operations
      @impl Indrajaal.Core.Holon
      def system1_operations(_context) do
        {:ok, :default_operation}
      end

      # Default S2: Coordination
      @impl Indrajaal.Core.Holon
      def system2_coordination(_peers) do
        :ok
      end

      # Default S3: Control
      @impl Indrajaal.Core.Holon
      def system3_control(budget) do
        {:within_budget, budget}
      end

      # Default S4: Intelligence
      @impl Indrajaal.Core.Holon
      def system4_intelligence(_observations) do
        {:no_plan, 0.0}
      end

      # Default S5: Policy
      @impl Indrajaal.Core.Holon
      def system5_policy do
        case Verifier.verify() do
          {:ok, %{hash: hash}} -> {:verified, hash}
          {:error, _, _} -> {:violated, <<>>}
        end
      end

      # Default structural callbacks
      @impl Indrajaal.Core.Holon
      def holon_id, do: to_string(__MODULE__)

      @impl Indrajaal.Core.Holon
      def layer, do: @holon_layer

      @impl Indrajaal.Core.Holon
      def parent, do: @holon_parent

      @impl Indrajaal.Core.Holon
      def children, do: []

      @impl Indrajaal.Core.Holon
      def health, do: :healthy

      # Allow overrides
      defoverridable system1_operations: 1,
                     system2_coordination: 1,
                     system3_control: 1,
                     system4_intelligence: 1,
                     system5_policy: 0,
                     holon_id: 0,
                     layer: 0,
                     parent: 0,
                     children: 0,
                     health: 0
    end
  end

  @doc """
  Lists all valid fractal layers in order from smallest to largest.
  """
  @spec layers() :: [layer()]
  def layers do
    [:function, :module, :agent, :container, :node, :cluster, :federation]
  end

  @doc """
  Returns the numeric depth of a layer (0 = function, 6 = federation).
  """
  @spec layer_depth(layer()) :: non_neg_integer()
  def layer_depth(layer) do
    Enum.find_index(layers(), &(&1 == layer)) || 0
  end

  @doc """
  Checks if layer_a is a parent layer of layer_b.
  """
  @spec parent_layer?(layer(), layer()) :: boolean()
  def parent_layer?(layer_a, layer_b) do
    layer_depth(layer_a) > layer_depth(layer_b)
  end
end
