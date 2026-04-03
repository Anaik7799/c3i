defmodule Indrajaal.Core.VSM.System5Policy do
  @moduledoc """
  VSM System 5: Policy - The Identity for v20.0.0

  System 5 handles identity and policy enforcement:
  - Maintains system identity (constitution)
  - Enforces invariants
  - Makes meta-level decisions
  - Interacts with S4 on strategic issues

  ## Responsibilities
  - Constitution verification
  - STAMP constraint enforcement
  - Strategic decision making
  - System boundary maintenance

  ## STAMP Constraints
  - SC-S5-001: Constitution MUST be verified < 1ms
  - SC-S5-002: Policy violations MUST halt the system
  - SC-S5-003: Strategic decisions MUST involve S4 input
  - SC-S5-004: Identity MUST be maintained across restarts

  ## Constitution Integration
  - Verifies 7 immutable invariants
  - Derives replication keys
  - Enforces safety constraints

  ## Category Theory
  S5 forms a Terminal Object:
  - All other systems have a unique morphism to S5
  - S5 represents the "identity" of the viable system
  """

  require Logger

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Verifier
  alias Indrajaal.Core.Constitution.DeadMansSwitch
  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Metrics

  @type policy_decision :: :approve | :reject | :defer
  @type constraint_check :: :pass | {:fail, String.t()}

  @type policy_state :: %{
          constitution_verified: boolean(),
          last_verification: DateTime.t() | nil,
          policy_version: String.t(),
          active_constraints: [atom()],
          violations: non_neg_integer(),
          strategic_mode: atom()
        }

  # Strategic modes
  @strategic_modes [:normal, :defensive, :aggressive, :emergency]

  @doc """
  Creates a new policy state.
  """
  @spec new() :: policy_state()
  def new do
    %{
      constitution_verified: false,
      last_verification: nil,
      policy_version: Constitution.version(),
      active_constraints: [],
      violations: 0,
      strategic_mode: :normal
    }
  end

  @doc """
  Verifies the constitution and updates state.
  """
  @spec verify_constitution(policy_state()) :: {:verified | :violated, policy_state()}
  def verify_constitution(state) do
    start_time = System.monotonic_time(:millisecond)

    case Verifier.verify() do
      {:ok, _details} ->
        duration = System.monotonic_time(:millisecond) - start_time

        if duration > 1 do
          Logger.warning("S5: Constitution verification exceeded 1ms (#{duration}ms)")
        end

        new_state = %{
          state
          | constitution_verified: true,
            last_verification: DateTime.utc_now()
        }

        {:verified, new_state}

      {:error, :constitution_violated, _details} ->
        new_state = %{
          state
          | constitution_verified: false,
            violations: state.violations + 1,
            last_verification: DateTime.utc_now()
        }

        {:violated, new_state}
    end
  end

  @doc """
  Makes a policy decision on a proposed action.
  """
  @spec decide(policy_state(), atom(), map()) :: {policy_decision(), policy_state()}
  def decide(state, action_type, context) do
    # First verify constitution
    case verify_constitution(state) do
      {:violated, new_state} ->
        Logger.error("S5: Policy decision blocked - constitution violated")
        {:reject, new_state}

      {:verified, verified_state} ->
        # Check against active constraints
        case check_constraints(verified_state, action_type, context) do
          :pass ->
            decision = make_strategic_decision(verified_state, action_type, context)
            {decision, verified_state}

          {:fail, reason} ->
            Logger.warning("S5: Action #{action_type} rejected - #{reason}")
            {:reject, %{verified_state | violations: verified_state.violations + 1}}
        end
    end
  end

  @doc """
  Checks STAMP constraints for an action.
  """
  @spec check_constraints(policy_state(), atom(), map()) :: constraint_check()
  def check_constraints(_state, action_type, context) do
    constraints = [
      &check_safety_constraint/2,
      &check_resource_constraint/2,
      &check_authorization_constraint/2
    ]

    Enum.reduce_while(constraints, :pass, fn check_fn, _acc ->
      case check_fn.(action_type, context) do
        :pass -> {:cont, :pass}
        {:fail, _} = failure -> {:halt, failure}
      end
    end)
  end

  @doc """
  Sets the strategic mode.
  """
  @spec set_strategic_mode(policy_state(), atom()) :: policy_state()
  def set_strategic_mode(state, mode) when mode in @strategic_modes do
    Logger.info("S5: Strategic mode changed to #{mode}")
    %{state | strategic_mode: mode}
  end

  def set_strategic_mode(state, _), do: state

  @doc """
  Checks if replication is allowed (constitution-based).
  """
  @spec can_replicate?(policy_state()) :: boolean()
  def can_replicate?(state) do
    state.constitution_verified and DeadMansSwitch.can_replicate?()
  end

  @doc """
  Returns the constitution hash for identity verification.
  """
  @spec identity_hash() :: binary()
  def identity_hash do
    Constitution.hash()
  end

  @doc """
  Emits policy metrics.
  """
  @spec emit_metrics(policy_state(), Holon.holon_id(), Holon.layer()) :: :ok
  def emit_metrics(state, holon_id, layer) do
    Metrics.emit_policy(
      holon_id,
      layer,
      state.constitution_verified,
      0
    )
  end

  @doc """
  Returns a summary of the policy state.
  """
  @spec summary(policy_state()) :: map()
  def summary(state) do
    %{
      constitution_verified: state.constitution_verified,
      policy_version: state.policy_version,
      violations: state.violations,
      strategic_mode: state.strategic_mode,
      can_replicate: can_replicate?(state),
      identity_hash: identity_hash() |> Base.encode16(case: :lower) |> String.slice(0, 16)
    }
  end

  # Private helpers

  defp check_safety_constraint(_action_type, context) do
    if Map.get(context, :unsafe, false) do
      {:fail, "Safety constraint violation"}
    else
      :pass
    end
  end

  defp check_resource_constraint(_action_type, context) do
    if Map.get(context, :resource_exhausted, false) do
      {:fail, "Resource constraint violation"}
    else
      :pass
    end
  end

  defp check_authorization_constraint(_action_type, context) do
    if Map.get(context, :authorized, true) do
      :pass
    else
      {:fail, "Authorization constraint violation"}
    end
  end

  defp make_strategic_decision(state, action_type, _context) do
    case {state.strategic_mode, action_type} do
      {:emergency, _} ->
        # In emergency mode, only approve essential actions
        if action_type in [:health_check, :shutdown, :recover] do
          :approve
        else
          :defer
        end

      {:defensive, :expand} ->
        :defer

      {:aggressive, :expand} ->
        :approve

      _ ->
        :approve
    end
  end
end
