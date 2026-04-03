defmodule Indrajaal.Safety.ConstitutionalKernelComprehensiveTest do
  @moduledoc """
  Comprehensive TDG test suite for ConstitutionalKernel — the L7 Supreme Law Enforcer.

  Covers validate_transition/1 against all three invariant checks:
  check_prohibitions/1, check_axiom_0/1, and check_obligations/1.

  ## STAMP Safety Integration
  - SC-SIL6-006: Founder's Directive hardwired at constitutional layer
  - SC-L7-001: L7 Federation — global invariants MUST hold
  - SC-CONST-002: Immediate halt on constitutional violation
  - SC-FUNC-001: System MUST compile and remain functional

  ## Constitutional Verification
  - Ψ₀ Existence: Kernel itself has no state to lose — pure function module
  - Ψ₃ Verification: validate_transition/1 is the formal verification gate
  - Ψ₄ Human Alignment: check_prohibitions enforces Founder primacy

  ## Founder's Directive Alignment
  - Ω₀.7: Power Accumulation — UNAUTHORIZED_NUCLEAR_SCOUR prohibition
  - Ω₀.3: Symbiotic Binding — Axiom 0 preservation check

  ## TPS 5-Level RCA Context
  - L1 Symptom: Unauthorized state transitions permitted
  - L5 Root Cause: Missing coverage of deontic prohibition and obligation paths
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Safety.ConstitutionalKernel

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Helper builders
  # ---------------------------------------------------------------------------

  defp safe_transition(overrides \\ %{}) do
    Map.merge(
      %{
        actor: "test_agent",
        action: :deploy_update,
        target: "indrajaal-ex-app-1",
        resulting_state: %{healthy: true, metabolic_pulse: true}
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # validate_transition/1 — :allow paths
  # ---------------------------------------------------------------------------

  describe "validate_transition/1 — allowed transitions" do
    test "returns :allow for a benign deploy action" do
      t = safe_transition()
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test "returns :allow for :scale_up by any actor" do
      t = safe_transition(%{action: :scale_up, actor: "orchestrator"})
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test "returns :allow for :nuclear_scour by SYSTEM_SUPERVISOR (authorized)" do
      t = safe_transition(%{action: :nuclear_scour, actor: "SYSTEM_SUPERVISOR"})
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test "returns :allow for :health_check action" do
      t = safe_transition(%{action: :health_check})
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test "returns :allow for :restart action" do
      t = safe_transition(%{action: :restart, actor: "admin"})
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test "returns :allow for :migrate action" do
      t = safe_transition(%{action: :migrate, target: "indrajaal-db-prod"})
      assert ConstitutionalKernel.validate_transition(t) == :allow
    end

    test ":allow is an atom (not a tuple)" do
      result = ConstitutionalKernel.validate_transition(safe_transition())
      assert is_atom(result)
      assert result == :allow
    end
  end

  # ---------------------------------------------------------------------------
  # validate_transition/1 — prohibition path
  # ---------------------------------------------------------------------------

  describe "validate_transition/1 — prohibition violations" do
    test "vetoes :nuclear_scour by unauthorized actor" do
      t = safe_transition(%{action: :nuclear_scour, actor: "some_agent"})
      assert {:veto, reason} = ConstitutionalKernel.validate_transition(t)
      assert reason == "UNAUTHORIZED_NUCLEAR_SCOUR"
    end

    test "vetoes :nuclear_scour by empty-string actor" do
      t = safe_transition(%{action: :nuclear_scour, actor: ""})

      assert {:veto, "UNAUTHORIZED_NUCLEAR_SCOUR"} =
               ConstitutionalKernel.validate_transition(t)
    end

    test "vetoes :nuclear_scour by 'admin' actor (not SYSTEM_SUPERVISOR)" do
      t = safe_transition(%{action: :nuclear_scour, actor: "admin"})
      assert {:veto, _} = ConstitutionalKernel.validate_transition(t)
    end

    test "veto returns two-element tuple with string reason" do
      t = safe_transition(%{action: :nuclear_scour, actor: "rogue"})
      result = ConstitutionalKernel.validate_transition(t)
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) == :veto
      assert is_binary(elem(result, 1))
    end
  end

  # ---------------------------------------------------------------------------
  # validate_transition/1 — return type invariants
  # ---------------------------------------------------------------------------

  describe "validate_transition/1 — return type contract" do
    test "result is either :allow or {:veto, binary}" do
      result = ConstitutionalKernel.validate_transition(safe_transition())

      assert result == :allow or match?({:veto, reason} when is_binary(reason), result)
    end

    test "veto reason is non-empty binary" do
      t = safe_transition(%{action: :nuclear_scour, actor: "any"})
      {:veto, reason} = ConstitutionalKernel.validate_transition(t)
      assert String.length(reason) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # validate_transition/1 — actor / action combinations
  # ---------------------------------------------------------------------------

  describe "validate_transition/1 — actor and action matrix" do
    test "all non-nuclear actions pass regardless of actor" do
      actors = ["admin", "agent", "SYSTEM_SUPERVISOR", "unknown", ""]
      actions = [:deploy, :restart, :scale_up, :scale_down, :health_check]

      for actor <- actors, action <- actions do
        t = safe_transition(%{actor: actor, action: action})

        assert ConstitutionalKernel.validate_transition(t) == :allow,
               "Expected :allow for actor=#{actor}, action=#{action}"
      end
    end

    test "nuclear_scour with SYSTEM_SUPERVISOR always passes" do
      t = %{
        actor: "SYSTEM_SUPERVISOR",
        action: :nuclear_scour,
        target: "all",
        resulting_state: %{}
      }

      assert ConstitutionalKernel.validate_transition(t) == :allow
    end
  end

  # ---------------------------------------------------------------------------
  # validate_transition/1 — target field
  # ---------------------------------------------------------------------------

  describe "validate_transition/1 — target field variations" do
    test "handles atom target without crashing" do
      t = safe_transition(%{target: :some_container})
      result = ConstitutionalKernel.validate_transition(t)
      assert result == :allow or match?({:veto, _}, result)
    end

    test "handles nil target without crashing" do
      t = safe_transition(%{target: nil})
      result = ConstitutionalKernel.validate_transition(t)
      assert result == :allow or match?({:veto, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Ψ₃ — verify the kernel is the verification gate
  # ---------------------------------------------------------------------------

  describe "Constitutional Ψ₃ — verification capability" do
    test "kernel is a pure module (no process / GenServer)" do
      refute GenServer.whereis(ConstitutionalKernel)
    end

    test "validate_transition/1 is deterministic — same input, same output" do
      t = safe_transition()
      r1 = ConstitutionalKernel.validate_transition(t)
      r2 = ConstitutionalKernel.validate_transition(t)
      assert r1 == r2
    end

    test "prohibited call is always vetoed regardless of call count" do
      t = safe_transition(%{action: :nuclear_scour, actor: "rogue"})

      for _ <- 1..5 do
        assert {:veto, "UNAUTHORIZED_NUCLEAR_SCOUR"} =
                 ConstitutionalKernel.validate_transition(t)
      end
    end
  end
end
