defmodule Indrajaal.Safety.GuardianPrometheusTest do
  use ExUnit.Case, async: false
  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Prometheus.Verifier

  @moduledoc """
  Integration tests for Guardian <-> Prometheus.
  Ensures SC-PROM-001 (Gatekeeper) is enforced.
  """

  setup do
    # Ensure Guardian is running (it might be started by application, but good to check)
    {:ok, _pid} = Guardian.start_link()
    :ok
  end

  describe "validate_proposal/1 with Prometheus integration" do
    test "approves valid proposal by auto-verifying" do
      # A simple valid proposal
      proposal = %{
        action: :exec_command,
        command: "echo 'hello'",
        # Trusted source
        source: :guardian,
        target: "system"
      }

      assert {:ok, verified_proposal} = Guardian.validate_proposal(proposal)
      # The verified proposal might be the same map, or enriched depending on implementation.
      # Currently Guardian doesn't attach the token to the return if it auto-verifies inside, 
      # but it returns {:ok, ...}
      assert verified_proposal.action == :exec_command
    end

    test "rejects proposal that fails routing verification" do
      # SC-GVF-003 Violation
      proposal = %{
        action: :route_request,
        source: :synapse,
        # Direct call violation
        target: "gpt-4",
        # Empty graph is acyclic
        dag: %{}
      }

      # Guardian calls Verifier -> Verifier fails -> Guardian Vetoes
      assert {:veto, {:prometheus_verification_failed, _reason}, _fallback} =
               Guardian.validate_proposal(proposal)
    end

    test "accepts proposal with pre-existing valid token" do
      proposal = %{
        action: :exec_command,
        command: "ls",
        source: :guardian,
        target: "system"
      }

      # Manually issue token
      token = Verifier.issue_proof(proposal)
      proposal_with_token = Map.put(proposal, :proof_token, token)

      assert {:ok, _} = Guardian.validate_proposal(proposal_with_token)
    end

    test "rejects proposal with invalid token structure" do
      proposal = %{
        action: :exec_command,
        command: "ls",
        source: :guardian,
        target: "system",
        proof_token: "fake_token_string"
      }

      assert {:veto, :invalid_proof_token_structure, _} = Guardian.validate_proposal(proposal)
    end
  end
end
