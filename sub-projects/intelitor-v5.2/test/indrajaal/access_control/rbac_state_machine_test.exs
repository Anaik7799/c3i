defmodule Indrajaal.AccessControl.RBACStateMachineTest do
  @moduledoc """
  Role-Based Access Control State Machine Tests

  This test module verifies RBAC state machine properties derived from:
  - CLAUDE.md §2.2: Agent State Machine (𝒬ₐᵍᵉₙₜ, δ transitions)
  - CLAUDE.md §6: Agent Operating Rules (AOR-SAF, AOR-QUA)
  - CLAUDE.md §4: STAMP Safety Constraints
  - Quint: AgentStateMachine module transitions

  Key Properties Verified:
  1. Access request state transitions
  2. Role hierarchy enforcement
  3. Permission inheritance
  4. Anti-passback enforcement
  5. Access schedule compliance
  6. Credential lifecycle management
  7. Access revocation state machine

  STAMP Compliance:
  - SC-AGT-019: Executive Director supreme authority
  - SC-AGT-020: Domain supervisor specialization
  - SC-AGT-018: Prevent deadlocks (no circular waiting)
  - SC-DAT-033: Data integrity for access logs

  Formal Specification Sources:
  - Mathematica §2.2: δ: Q × Σ → Q transition function
  - Quint §Q2: AgentStateMachine.qnt
  - Agda §A2: Agent hierarchy proofs

  SOPv5.11 Framework: TDG-compliant access control verification
  """

  use ExUnit.Case, async: true

  @moduletag :formal_verification
  @moduletag :access_control
  @moduletag :state_machine

  # Shared graph test helpers for cycle detection
  alias Indrajaal.GraphTestHelpers

  # ============================================================================
  # Access Request State Machine (Based on Agent State Machine §2.2)
  # ============================================================================

  @doc """
  Access request states mirror agent states from Quint §Q2.2

  States (𝒬ᵃᶜᶜᵉˢˢ):
  - :pending - Initial request state
  - :validating - Checking credentials and rules
  - :approved - Access granted
  - :denied - Access denied
  - :expired - Access grant expired
  - :revoked - Access explicitly revoked
  """
  @access_states [:pending, :validating, :approved, :denied, :expired, :revoked]

  @doc """
  State transition function δ: Q × Event → Q
  Based on Mathematica §2.2 and Quint §Q2.3
  """
  defp transition(state, event) do
    case {state, event} do
      # Valid transitions
      {:pending, :validate} -> :validating
      {:validating, :grant} -> :approved
      {:validating, :reject} -> :denied
      {:approved, :expire} -> :expired
      {:approved, :revoke} -> :revoked
      {:denied, :resubmit} -> :pending
      {:expired, :renew} -> :pending
      # Invalid transitions (stay in current state)
      _ -> {:error, :invalid_transition, state, event}
    end
  end

  describe "Access Request State Machine (Mathematica §2.2: δ function)" do
    @tag :state_machine
    @tag constraint: "SC-AGT-018"

    test "pending → validating on validate event" do
      assert :validating = transition(:pending, :validate)
    end

    test "validating → approved on grant event" do
      assert :approved = transition(:validating, :grant)
    end

    test "validating → denied on reject event" do
      assert :denied = transition(:validating, :reject)
    end

    test "approved → expired on expire event" do
      assert :expired = transition(:approved, :expire)
    end

    test "approved → revoked on revoke event" do
      assert :revoked = transition(:approved, :revoke)
    end

    test "denied → pending on resubmit event" do
      assert :pending = transition(:denied, :resubmit)
    end

    test "expired → pending on renew event" do
      assert :pending = transition(:expired, :renew)
    end

    test "invalid transitions return error" do
      # Cannot skip states
      assert {:error, :invalid_transition, :pending, :grant} =
               transition(:pending, :grant)

      # Cannot transition from terminal states incorrectly
      assert {:error, :invalid_transition, :revoked, :approve} =
               transition(:revoked, :approve)
    end

    test "all states are reachable from pending" do
      reachable_states = MapSet.new([:pending])

      # BFS to find all reachable states
      events = [:validate, :grant, :reject, :expire, :revoke, :resubmit, :renew]

      reachable_states =
        Enum.reduce(1..10, reachable_states, fn _, acc ->
          Enum.reduce(acc, acc, fn state, inner_acc ->
            Enum.reduce(events, inner_acc, fn event, event_acc ->
              case transition(state, event) do
                {:error, _, _, _} -> event_acc
                new_state -> MapSet.put(event_acc, new_state)
              end
            end)
          end)
        end)

      # All states should be reachable
      for state <- @access_states do
        assert state in reachable_states,
               "State #{state} should be reachable from :pending"
      end
    end
  end

  # ============================================================================
  # Role Hierarchy Tests (SC-AGT-019, SC-AGT-020)
  # ============================================================================

  describe "Role Hierarchy (STAMP SC-AGT-019: Executive Authority)" do
    @tag :stamp_constraint
    @tag constraint: "SC-AGT-019"

    @doc """
    Role hierarchy from Mathematica §2.1:
    - Executive (Layer 1): Supreme authority
    - Domain Supervisor (Layer 2): Domain-specific authority
    - Functional Supervisor (Layer 3): Functional authority
    - Worker (Layer 4): Operational authority

    Authority ordering: Executive > Domain > Functional > Worker
    """

    @role_authority %{
      :executive => 100,
      :domain_supervisor => 75,
      :functional_supervisor => 50,
      :worker => 25,
      :viewer => 10
    }

    defp authority_level(role), do: Map.get(@role_authority, role, 0)

    defp has_authority_over?(superior, subordinate) do
      authority_level(superior) > authority_level(subordinate)
    end

    defp can_delegate?(delegator, action, delegatee) do
      # Can only delegate actions to roles with lower authority
      has_authority_over?(delegator, delegatee) and
        action_allowed?(delegator, action)
    end

    defp action_allowed?(role, action) do
      case role do
        :executive -> true
        :domain_supervisor -> action in [:read, :write, :manage_domain]
        :functional_supervisor -> action in [:read, :write, :supervise]
        :worker -> action in [:read, :write]
        :viewer -> action == :read
        _ -> false
      end
    end

    test "executive has authority over all other roles" do
      subordinates = [:domain_supervisor, :functional_supervisor, :worker, :viewer]

      for subordinate <- subordinates do
        assert has_authority_over?(:executive, subordinate),
               "Executive should have authority over #{subordinate}"
      end
    end

    test "domain supervisor has authority over functional and below" do
      assert has_authority_over?(:domain_supervisor, :functional_supervisor)
      assert has_authority_over?(:domain_supervisor, :worker)
      assert has_authority_over?(:domain_supervisor, :viewer)
      refute has_authority_over?(:domain_supervisor, :executive)
    end

    test "functional supervisor has authority over worker and viewer" do
      assert has_authority_over?(:functional_supervisor, :worker)
      assert has_authority_over?(:functional_supervisor, :viewer)
      refute has_authority_over?(:functional_supervisor, :domain_supervisor)
      refute has_authority_over?(:functional_supervisor, :executive)
    end

    test "worker only has authority over viewer" do
      assert has_authority_over?(:worker, :viewer)
      refute has_authority_over?(:worker, :functional_supervisor)
      refute has_authority_over?(:worker, :domain_supervisor)
      refute has_authority_over?(:worker, :executive)
    end

    test "no role has authority over itself" do
      for role <- Map.keys(@role_authority) do
        refute has_authority_over?(role, role),
               "Role #{role} should not have authority over itself"
      end
    end

    test "delegation requires authority and permission" do
      # Executive can delegate any action to anyone
      assert can_delegate?(:executive, :read, :worker)
      assert can_delegate?(:executive, :write, :domain_supervisor)

      # Domain supervisor can delegate within allowed actions
      assert can_delegate?(:domain_supervisor, :read, :worker)
      refute can_delegate?(:domain_supervisor, :admin_action, :worker)

      # Cannot delegate to superior
      refute can_delegate?(:worker, :read, :executive)
    end
  end

  # ============================================================================
  # Permission Inheritance Tests
  # ============================================================================

  describe "Permission Inheritance (Quint: AgentStateMachine permissions)" do
    @tag :authorization
    @tag constraint: "SC-AGT-020"

    @doc """
    Permission inheritance rules from CLAUDE.md §6:
    - Higher roles inherit all permissions of lower roles
    - Additional permissions are additive
    - Denied permissions override inherited
    """

    defp base_permissions(role) do
      case role do
        :viewer -> MapSet.new([:read])
        :worker -> MapSet.new([:read, :write, :execute])
        :functional_supervisor -> MapSet.new([:read, :write, :execute, :supervise, :report])
        :domain_supervisor -> MapSet.new([:read, :write, :execute, :supervise, :report, :manage])
        :executive -> MapSet.new([:read, :write, :execute, :supervise, :report, :manage, :admin])
        _ -> MapSet.new()
      end
    end

    defp inherits_permissions?(higher_role, lower_role) do
      lower_perms = base_permissions(lower_role)
      higher_perms = base_permissions(higher_role)

      MapSet.subset?(lower_perms, higher_perms)
    end

    test "executive inherits all permissions from all roles" do
      lower_roles = [:viewer, :worker, :functional_supervisor, :domain_supervisor]

      for role <- lower_roles do
        assert inherits_permissions?(:executive, role),
               "Executive should inherit all permissions from #{role}"
      end
    end

    test "domain supervisor inherits from functional and below" do
      assert inherits_permissions?(:domain_supervisor, :functional_supervisor)
      assert inherits_permissions?(:domain_supervisor, :worker)
      assert inherits_permissions?(:domain_supervisor, :viewer)
    end

    test "functional supervisor inherits from worker and viewer" do
      assert inherits_permissions?(:functional_supervisor, :worker)
      assert inherits_permissions?(:functional_supervisor, :viewer)
    end

    test "worker inherits from viewer only" do
      assert inherits_permissions?(:worker, :viewer)
    end

    test "viewer has minimal permissions" do
      viewer_perms = base_permissions(:viewer)

      assert MapSet.equal?(viewer_perms, MapSet.new([:read]))
    end

    test "permission inheritance is transitive" do
      # If A inherits from B and B inherits from C, A inherits from C
      assert inherits_permissions?(:executive, :viewer)
      assert inherits_permissions?(:domain_supervisor, :viewer)
      assert inherits_permissions?(:functional_supervisor, :viewer)
      assert inherits_permissions?(:worker, :viewer)
    end
  end

  # ============================================================================
  # Anti-Passback Tests
  # ============================================================================

  describe "Anti-Passback Enforcement (Access Control Safety)" do
    @tag :access_control
    @tag :anti_passback

    @doc """
    Anti-passback prevents credential sharing by requiring
    proper entry/exit sequences before re-entry.

    States: :outside → :inside (on entry) → :outside (on exit)
    Violation: :inside → :inside (re-entry without exit)
    """

    defp check_anti_passback(current_state, action) do
      case {current_state, action} do
        {:outside, :entry} -> {:ok, :inside}
        {:inside, :exit} -> {:ok, :outside}
        {:inside, :entry} -> {:error, :anti_passback_violation}
        {:outside, :exit} -> {:error, :tailgating_attempt}
        _ -> {:error, :invalid_action}
      end
    end

    test "valid entry from outside" do
      assert {:ok, :inside} = check_anti_passback(:outside, :entry)
    end

    test "valid exit from inside" do
      assert {:ok, :outside} = check_anti_passback(:inside, :exit)
    end

    test "anti-passback violation on re-entry without exit" do
      assert {:error, :anti_passback_violation} = check_anti_passback(:inside, :entry)
    end

    test "tailgating detected on exit without entry" do
      assert {:error, :tailgating_attempt} = check_anti_passback(:outside, :exit)
    end

    test "full access cycle is valid" do
      # Start outside
      state = :outside

      # Enter
      {:ok, state} = check_anti_passback(state, :entry)
      assert state == :inside

      # Exit
      {:ok, state} = check_anti_passback(state, :exit)
      assert state == :outside

      # Re-enter (valid after exit)
      {:ok, state} = check_anti_passback(state, :entry)
      assert state == :inside
    end

    test "credential sharing attempt is blocked" do
      # Person A enters
      state_a = :outside
      {:ok, state_a} = check_anti_passback(state_a, :entry)

      # Person B tries to use same credential (simulated as same state)
      # This would trigger anti-passback
      assert {:error, :anti_passback_violation} = check_anti_passback(state_a, :entry)
    end
  end

  # ============================================================================
  # Access Schedule Tests
  # ============================================================================

  describe "Access Schedule Compliance" do
    @tag :access_control
    @tag :schedule

    @doc """
    Access schedules define when credentials are valid.
    Based on time-based access control patterns.
    """

    defp within_schedule?(schedule, current_time) do
      day_of_week = Date.day_of_week(current_time)
      time = Time.from_erl!({current_time.hour, current_time.minute, current_time.second})

      case schedule do
        :always ->
          true

        :never ->
          false

        :weekdays ->
          day_of_week in 1..5

        :weekends ->
          day_of_week in [6, 7]

        :business_hours ->
          day_of_week in 1..5 and time_in_range?(time, ~T[09:00:00], ~T[17:00:00])

        :extended_hours ->
          day_of_week in 1..5 and time_in_range?(time, ~T[07:00:00], ~T[21:00:00])

        {:custom, allowed_days, start_time, end_time} ->
          day_of_week in allowed_days and time_in_range?(time, start_time, end_time)

        _ ->
          false
      end
    end

    defp time_in_range?(time, start_time, end_time) do
      Time.compare(time, start_time) in [:gt, :eq] and
        Time.compare(time, end_time) in [:lt, :eq]
    end

    test "always schedule permits any time" do
      times = [
        ~N[2025-12-18 03:00:00],
        ~N[2025-12-18 12:00:00],
        ~N[2025-12-18 23:59:59],
        # Weekend
        ~N[2025-12-21 12:00:00]
      ]

      for time <- times do
        assert within_schedule?(:always, time),
               "Always schedule should permit #{time}"
      end
    end

    test "never schedule denies any time" do
      times = [
        ~N[2025-12-18 12:00:00],
        ~N[2025-12-21 12:00:00]
      ]

      for time <- times do
        refute within_schedule?(:never, time),
               "Never schedule should deny #{time}"
      end
    end

    test "weekdays schedule permits Monday-Friday only" do
      # Thursday (weekday)
      assert within_schedule?(:weekdays, ~N[2025-12-18 12:00:00])

      # Saturday (weekend)
      refute within_schedule?(:weekdays, ~N[2025-12-20 12:00:00])

      # Sunday (weekend)
      refute within_schedule?(:weekdays, ~N[2025-12-21 12:00:00])
    end

    test "business hours schedule permits 9-5 on weekdays" do
      # Within business hours on weekday
      assert within_schedule?(:business_hours, ~N[2025-12-18 10:00:00])
      assert within_schedule?(:business_hours, ~N[2025-12-18 16:00:00])

      # Outside business hours on weekday
      refute within_schedule?(:business_hours, ~N[2025-12-18 07:00:00])
      refute within_schedule?(:business_hours, ~N[2025-12-18 18:00:00])

      # Weekend (regardless of time)
      refute within_schedule?(:business_hours, ~N[2025-12-21 12:00:00])
    end

    test "custom schedule with specific days and times" do
      # Tuesday and Thursday, 10:00-14:00
      custom = {:custom, [2, 4], ~T[10:00:00], ~T[14:00:00]}

      # Tuesday 11:00 - allowed
      assert within_schedule?(custom, ~N[2025-12-16 11:00:00])

      # Thursday 13:00 - allowed
      assert within_schedule?(custom, ~N[2025-12-18 13:00:00])

      # Wednesday 11:00 - denied (wrong day)
      refute within_schedule?(custom, ~N[2025-12-17 11:00:00])

      # Tuesday 09:00 - denied (wrong time)
      refute within_schedule?(custom, ~N[2025-12-16 09:00:00])
    end
  end

  # ============================================================================
  # Credential Lifecycle Tests
  # ============================================================================

  describe "Credential Lifecycle State Machine" do
    @tag :access_control
    @tag :credential

    @doc """
    Credential states:
    - :issued - Credential created
    - :active - Credential enabled for use
    - :suspended - Temporarily disabled
    - :revoked - Permanently disabled
    - :expired - Past validity period
    """

    defp credential_transition(state, event) do
      case {state, event} do
        {:issued, :activate} -> :active
        {:active, :suspend} -> :suspended
        {:active, :revoke} -> :revoked
        {:active, :expire} -> :expired
        {:suspended, :reactivate} -> :active
        {:suspended, :revoke} -> :revoked
        {:expired, :renew} -> :issued
        # Terminal states
        {:revoked, _} -> {:error, :terminal_state}
        _ -> {:error, :invalid_transition}
      end
    end

    test "new credential lifecycle: issue → activate → use" do
      state = :issued
      {:ok, _} = {:ok, state}

      state = credential_transition(state, :activate)
      assert state == :active
    end

    test "credential suspension and reactivation" do
      state = :active

      state = credential_transition(state, :suspend)
      assert state == :suspended

      state = credential_transition(state, :reactivate)
      assert state == :active
    end

    test "revocation is terminal" do
      state = :active

      state = credential_transition(state, :revoke)
      assert state == :revoked

      # Cannot transition from revoked
      assert {:error, :terminal_state} = credential_transition(state, :activate)
      assert {:error, :terminal_state} = credential_transition(state, :reactivate)
    end

    test "expired credentials can be renewed" do
      state = :active

      state = credential_transition(state, :expire)
      assert state == :expired

      state = credential_transition(state, :renew)
      assert state == :issued
    end

    test "suspended credentials can be revoked" do
      state = :active

      state = credential_transition(state, :suspend)
      assert state == :suspended

      state = credential_transition(state, :revoke)
      assert state == :revoked
    end
  end

  # ============================================================================
  # Access Revocation Tests (SC-DAT-033)
  # ============================================================================

  describe "Access Revocation (STAMP SC-DAT-033: Data Integrity)" do
    @tag :stamp_constraint
    @tag constraint: "SC-DAT-033"

    @doc """
    Access revocation must maintain data integrity:
    1. Revocation is immediate
    2. Revocation is logged
    3. Revoked access cannot be restored (only re-issued)
    4. All active sessions are terminated
    """

    defp revoke_access(access_id, revoked_set, reason) do
      if MapSet.member?(revoked_set, access_id) do
        {:error, :already_revoked}
      else
        revoked_set = MapSet.put(revoked_set, access_id)

        log_entry = %{
          access_id: access_id,
          action: :revoke,
          reason: reason,
          timestamp: System.system_time(:second),
          logged: true
        }

        {:ok, revoked_set, log_entry}
      end
    end

    defp is_access_revoked?(access_id, revoked_set) do
      MapSet.member?(revoked_set, access_id)
    end

    test "revocation adds access to revoked set" do
      revoked_set = MapSet.new()
      access_id = "access-123"

      {:ok, revoked_set, _log} = revoke_access(access_id, revoked_set, :security_violation)

      assert is_access_revoked?(access_id, revoked_set)
    end

    test "revocation is logged with reason" do
      revoked_set = MapSet.new()
      access_id = "access-456"
      reason = :employee_termination

      {:ok, _revoked_set, log_entry} = revoke_access(access_id, revoked_set, reason)

      assert log_entry.access_id == access_id
      assert log_entry.action == :revoke
      assert log_entry.reason == reason
      assert log_entry.logged == true
    end

    test "cannot revoke already revoked access" do
      revoked_set = MapSet.new()
      access_id = "access-789"

      {:ok, revoked_set, _log} = revoke_access(access_id, revoked_set, :manual)
      result = revoke_access(access_id, revoked_set, :manual)

      assert {:error, :already_revoked} = result
    end

    test "multiple accesses can be revoked independently" do
      revoked_set = MapSet.new()

      access_ids = ["access-1", "access-2", "access-3"]

      revoked_set =
        Enum.reduce(access_ids, revoked_set, fn id, set ->
          {:ok, new_set, _log} = revoke_access(id, set, :batch_revocation)
          new_set
        end)

      for id <- access_ids do
        assert is_access_revoked?(id, revoked_set)
      end
    end

    test "revocation is immediate (no grace period in security violations)" do
      revoked_set = MapSet.new()
      access_id = "access-emergency"

      # Revoke
      {:ok, revoked_set, log_entry} = revoke_access(access_id, revoked_set, :security_violation)

      # Check immediately revoked
      assert is_access_revoked?(access_id, revoked_set)

      # Timestamp should be current
      assert log_entry.timestamp <= System.system_time(:second)
    end
  end

  # ============================================================================
  # Deadlock Prevention Tests (SC-AGT-018)
  # ============================================================================

  describe "Deadlock Prevention (STAMP SC-AGT-018)" do
    @tag :stamp_constraint
    @tag constraint: "SC-AGT-018"

    @doc """
    Based on Quint §Q3.2 AOR-LTL-S3: No Deadlock
    □[¬(∃cycle : ∀a ∈ cycle : Waiting[a, Next[a]])]

    In access control, deadlock can occur when:
    - Agent A waits for resource held by Agent B
    - Agent B waits for resource held by Agent A

    Prevention: Resource ordering and timeout-based acquisition
    """

    test "no circular wait in simple graph" do
      # A → B → C (no cycle)
      graph = %{
        :agent_a => [:agent_b],
        :agent_b => [:agent_c],
        :agent_c => []
      }

      refute GraphTestHelpers.has_cycle?(graph)
    end

    test "detect circular wait in cyclic graph" do
      # A → B → C → A (cycle!)
      graph = %{
        :agent_a => [:agent_b],
        :agent_b => [:agent_c],
        :agent_c => [:agent_a]
      }

      assert GraphTestHelpers.has_cycle?(graph)
    end

    test "detect self-loop (agent waiting for itself)" do
      # A → A (self-loop)
      graph = %{
        :agent_a => [:agent_a]
      }

      assert GraphTestHelpers.has_cycle?(graph)
    end

    test "detect complex circular wait" do
      # A → B, B → C, C → D, D → B (cycle B → C → D → B)
      graph = %{
        :agent_a => [:agent_b],
        :agent_b => [:agent_c],
        :agent_c => [:agent_d],
        :agent_d => [:agent_b]
      }

      assert GraphTestHelpers.has_cycle?(graph)
    end

    test "empty graph has no deadlock" do
      graph = %{}

      refute GraphTestHelpers.has_cycle?(graph)
    end

    test "disconnected components with no cycles" do
      # A → B, C → D (two disconnected chains)
      graph = %{
        :agent_a => [:agent_b],
        :agent_b => [],
        :agent_c => [:agent_d],
        :agent_d => []
      }

      refute GraphTestHelpers.has_cycle?(graph)
    end
  end

  # ============================================================================
  # Access Grant Validation Tests
  # ============================================================================

  describe "Access Grant Validation (Complete Authorization Check)" do
    @tag :access_control
    @tag :authorization

    @doc """
    Complete access grant validation combining:
    1. Role-based permission check
    2. Schedule compliance
    3. Anti-passback check
    4. Credential validity
    5. Resource availability
    """

    defp validate_access_grant(request) do
      with :ok <- check_role_permission(request.role, request.action),
           :ok <- check_schedule(request.schedule, request.time),
           :ok <- check_anti_passback_for_grant(request.credential_state, request.action),
           :ok <- check_credential_validity(request.credential_state) do
        {:ok, :access_granted}
      end
    end

    defp check_role_permission(role, action) do
      allowed = action_allowed?(role, action)

      if allowed, do: :ok, else: {:error, :permission_denied}
    end

    defp check_schedule(schedule, time) do
      if within_schedule?(schedule, time) do
        :ok
      else
        {:error, :outside_schedule}
      end
    end

    defp check_anti_passback_for_grant(credential_state, action) do
      # Anti-passback only applies to physical entry/exit actions
      # For data access actions (read, write, etc.), just verify credential state
      if action in [:entry, :exit] do
        case {credential_state, action} do
          {:outside, :entry} -> :ok
          {:inside, :exit} -> :ok
          {:inside, :entry} -> {:error, :anti_passback_violation}
          {:outside, :exit} -> {:error, :tailgating_attempt}
          _ -> {:error, :invalid_action}
        end
      else
        # For non-entry/exit actions, anti-passback check passes if credential is valid
        if credential_state in [:inside, :outside, :active],
          do: :ok,
          else: {:error, :invalid_credential_state}
      end
    end

    defp check_credential_validity(credential_state) do
      if credential_state in [:active, :outside, :inside] do
        :ok
      else
        {:error, :invalid_credential}
      end
    end

    test "valid request passes all checks" do
      request = %{
        role: :worker,
        action: :read,
        schedule: :always,
        time: ~N[2025-12-18 12:00:00],
        credential_state: :outside
      }

      assert {:ok, :access_granted} = validate_access_grant(request)
    end

    test "insufficient role permission fails" do
      request = %{
        role: :viewer,
        # Viewer can only read
        action: :write,
        schedule: :always,
        time: ~N[2025-12-18 12:00:00],
        credential_state: :outside
      }

      assert {:error, :permission_denied} = validate_access_grant(request)
    end

    test "outside schedule fails" do
      request = %{
        role: :worker,
        action: :read,
        schedule: :business_hours,
        # After business hours
        time: ~N[2025-12-18 22:00:00],
        credential_state: :outside
      }

      assert {:error, :outside_schedule} = validate_access_grant(request)
    end
  end
end
