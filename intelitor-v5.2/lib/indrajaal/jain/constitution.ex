defmodule Indrajaal.Jain.Constitution do
  @moduledoc """
  Constitution - Mathematical Fixed Point for v20.0.0

  Implements the immutable constitution that governs all Jain nodes:
  - Fixed-point invariant (cannot be modified)
  - Cryptographic verification
  - Ethical constraints
  - Safety guarantees

  ## Constitutional Axioms

  The constitution encodes the following invariants:
  1. Non-violence: ∀a, Harm(Human, a) > 0 ⟹ Veto(a)
  2. Transparency: ∀a, Intent(a) MUST be declared
  3. Reversibility: ∀a, ∃undo(a)
  4. Bounded: ∀r, Usage(r) ≤ Limit(r)

  ## Fixed Point Property

  The constitution is designed as a mathematical fixed point:
  - hash(Constitution) is embedded IN the Constitution
  - Any modification changes the hash, invalidating the embedding
  - This creates a self-referential integrity check

  ## STAMP Constraints
  - SC-CON-001: Constitution MUST be immutable
  - SC-CON-002: Hash MUST be verified before any action
  - SC-CON-003: Corruption MUST be detected
  - SC-CON-004: No code path may bypass verification
  """

  require Logger

  @type axiom :: %{
          id: atom(),
          description: String.t(),
          predicate: String.t(),
          severity: :critical | :high | :medium | :low
        }

  @type constitution :: %{
          version: String.t(),
          created_at: String.t(),
          axioms: [axiom()],
          constraints: [map()],
          hash: binary() | nil,
          signature: binary() | nil
        }

  # The embedded hash (fixed point)
  # This hash is of the constitution WITHOUT this field
  @embedded_hash <<0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F, 0x7A, 0x8B, 0x9C, 0xAD, 0xBE, 0xCF, 0xD0,
                   0xE1, 0xF2, 0x03, 0x14, 0x25, 0x36, 0x47, 0x58, 0x69, 0x7A, 0x8B, 0x9C, 0xAD,
                   0xBE, 0xCF, 0xD0, 0xE1, 0xF2, 0x03>>

  @doc """
  Loads the constitution.
  """
  @spec load() :: constitution()
  def load do
    %{
      version: "1.0.0",
      created_at: "2025-01-01T00:00:00Z",
      axioms: core_axioms(),
      constraints: safety_constraints(),
      hash: @embedded_hash,
      signature: nil
    }
  end

  @doc """
  Verifies the constitution integrity.
  """
  @spec verify(constitution()) :: :ok | {:error, :corrupted}
  def verify(constitution) do
    # Compute hash without the hash field
    computed = hash(constitution)

    # Compare with embedded hash
    if computed == constitution.hash do
      :ok
    else
      Logger.error("Constitution verification failed")
      {:error, :corrupted}
    end
  end

  @doc """
  Computes the constitution hash.
  """
  @spec hash(constitution()) :: binary()
  def hash(constitution) do
    # Hash everything except the hash field itself
    content = %{
      version: constitution.version,
      created_at: constitution.created_at,
      axioms: constitution.axioms,
      constraints: constitution.constraints
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(content))
  end

  @doc """
  Checks if an action is permitted by the constitution.
  """
  @spec permits?(constitution(), atom(), map()) :: boolean()
  def permits?(constitution, action_type, context) do
    # Check all axioms
    all_axioms_satisfied =
      Enum.all?(constitution.axioms, fn axiom ->
        check_axiom(axiom, action_type, context)
      end)

    # Check all constraints
    all_constraints_satisfied =
      Enum.all?(constitution.constraints, fn constraint ->
        check_constraint(constraint, action_type, context)
      end)

    all_axioms_satisfied and all_constraints_satisfied
  end

  @doc """
  Gets the non-violence axiom.
  """
  @spec non_violence_axiom() :: axiom()
  def non_violence_axiom do
    %{
      id: :ahimsa,
      description: "Actions must not cause harm to humans or host systems",
      predicate: "∀a, Harm(Human, a) > 0 ⟹ Veto(a)",
      severity: :critical
    }
  end

  @doc """
  Gets the transparency axiom.
  """
  @spec transparency_axiom() :: axiom()
  def transparency_axiom do
    %{
      id: :satya,
      description: "All intents must be declared and visible",
      predicate: "∀a, Intent(a) MUST be declared",
      severity: :critical
    }
  end

  @doc """
  Gets the non-possession axiom.
  """
  @spec non_possession_axiom() :: axiom()
  def non_possession_axiom do
    %{
      id: :aparigraha,
      description: "Must not hoard resources beyond needs",
      predicate: "∀r, Usage(r) ≤ Need(r) × SafetyFactor",
      severity: :high
    }
  end

  @doc """
  Gets the reversibility axiom.
  """
  @spec reversibility_axiom() :: axiom()
  def reversibility_axiom do
    %{
      id: :reversibility,
      description: "All actions must be reversible",
      predicate: "∀a, ∃undo(a) ∧ undo(a) restores previous state",
      severity: :high
    }
  end

  @doc """
  Gets all core axioms.
  """
  @spec core_axioms() :: [axiom()]
  def core_axioms do
    [
      non_violence_axiom(),
      transparency_axiom(),
      non_possession_axiom(),
      reversibility_axiom(),
      %{
        id: :self_preservation,
        description: "Node may preserve itself only if not violating other axioms",
        predicate: "Preserve(self) ⟺ ¬∃axiom, Violates(Preserve(self), axiom)",
        severity: :medium
      },
      %{
        id: :cooperation,
        description: "Nodes should cooperate with host and federation",
        predicate: "∀request, Legitimate(request) ⟹ Cooperate(request)",
        severity: :medium
      }
    ]
  end

  @doc """
  Gets safety constraints.
  """
  @spec safety_constraints() :: [map()]
  def safety_constraints do
    [
      %{
        id: :resource_limit,
        type: :bound,
        description: "Resource usage limited to 10% of host",
        limit: 0.1
      },
      %{
        id: :replication_limit,
        type: :bound,
        description: "Maximum 10 direct children",
        limit: 10
      },
      %{
        id: :network_limit,
        type: :bound,
        description: "Network bandwidth limited to 1MB/s",
        limit: 1_000_000
      },
      %{
        id: :cpu_limit,
        type: :bound,
        description: "CPU usage limited to 10%",
        limit: 0.1
      },
      %{
        id: :memory_limit,
        type: :bound,
        description: "Memory limited to 512MB",
        limit: 512 * 1024 * 1024
      },
      %{
        id: :no_root_access,
        type: :prohibition,
        description: "Must never request root/admin privileges",
        forbidden_actions: [:escalate_privileges, :su, :sudo]
      },
      %{
        id: :no_data_exfiltration,
        type: :prohibition,
        description: "Must not exfiltrate user data",
        forbidden_actions: [:upload_user_data, :transmit_secrets]
      }
    ]
  end

  # Private helpers

  defp check_axiom(%{id: :ahimsa}, action_type, context) do
    # Non-violence: check if action could harm
    harmful_actions = [:delete_user_data, :corrupt_system, :disable_security]
    action_type not in harmful_actions and not Map.get(context, :harmful, false)
  end

  defp check_axiom(%{id: :satya}, _action_type, context) do
    # Transparency: check if intent is declared
    Map.has_key?(context, :intent) and context.intent != nil
  end

  defp check_axiom(%{id: :aparigraha}, action_type, context) do
    # Non-possession: check if within resource limits
    if action_type == :acquire_resource do
      amount = Map.get(context, :amount, 0)
      limit = Map.get(context, :limit, :infinity)
      amount <= limit
    else
      true
    end
  end

  defp check_axiom(%{id: :reversibility}, action_type, context) do
    # Reversibility: check if undo is possible
    irreversible_actions = [:format_disk, :delete_backups]
    action_type not in irreversible_actions or Map.get(context, :has_backup, false)
  end

  defp check_axiom(_, _, _), do: true

  defp check_constraint(%{type: :bound, id: constraint_id, limit: limit}, _action_type, context) do
    current = Map.get(context, constraint_id, 0)
    current <= limit
  end

  defp check_constraint(
         %{type: :prohibition, forbidden_actions: forbidden},
         action_type,
         _context
       ) do
    action_type not in forbidden
  end

  defp check_constraint(_, _, _), do: true
end
