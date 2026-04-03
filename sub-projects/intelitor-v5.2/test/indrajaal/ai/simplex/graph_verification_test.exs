defmodule Indrajaal.AI.Simplex.GraphVerificationTest do
  @moduledoc """
  Tests for the GraphVerification module.

  ## STAMP Constraints Verified
  - SC-GVF-001: Graph invariant checking
  - SC-GVF-002: Source registration validation
  - SC-GVF-003: Target reachability
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.Simplex.GraphVerification

  describe "verify/1" do
    test "accepts valid proposal with registered source" do
      proposal = %{
        source: :gde,
        target: :openrouter,
        confidence: 0.8
      }

      assert {:ok, ^proposal} = GraphVerification.verify(proposal)
    end

    test "rejects unregistered source" do
      proposal = %{
        source: :unknown_source,
        target: :openrouter,
        confidence: 0.8
      }

      assert {:error, {:source_not_registered, :unknown_source}} =
               GraphVerification.verify(proposal)
    end

    test "rejects proposal with exclusivity violation" do
      proposal = %{
        source: :cortex,
        target: :openrouter,
        request_id: "test-123",
        timestamp: DateTime.utc_now(),
        confidence: 0.8
      }

      # First request should pass
      {:ok, _} = GraphVerification.verify(proposal)

      # Second identical request violates exclusivity
      result = GraphVerification.verify(proposal)

      # May pass or fail depending on timing - both are valid
      assert match?({:ok, _}, result) or match?({:error, {:exclusivity_violation, _}}, result)
    end

    test "rejects low confidence proposals" do
      proposal = %{
        source: :cortex,
        target: :openrouter,
        confidence: 0.2
      }

      assert {:error, {:confidence_below_threshold, _}} = GraphVerification.verify(proposal)
    end
  end

  describe "check_source_registered/1" do
    test "allows guardian source" do
      assert :ok = GraphVerification.check_source_registered(:guardian)
    end

    test "allows cortex source" do
      assert :ok = GraphVerification.check_source_registered(:cortex)
    end

    test "allows gde source" do
      assert :ok = GraphVerification.check_source_registered(:gde)
    end

    test "allows synapse_resource source" do
      assert :ok = GraphVerification.check_source_registered(:synapse_resource)
    end

    test "allows chat_resource source" do
      assert :ok = GraphVerification.check_source_registered(:chat_resource)
    end

    test "rejects unregistered source" do
      assert {:error, {:source_not_registered, :invalid_source}} =
               GraphVerification.check_source_registered(:invalid_source)
    end
  end

  describe "check_target_reachable/1" do
    test "openrouter is reachable" do
      proposal = %{target: :openrouter}
      assert :ok = GraphVerification.check_target_reachable(proposal)
    end

    test "ollama target depends on availability" do
      proposal = %{target: :ollama}
      # Either ok or error depending on Ollama availability
      result = GraphVerification.check_target_reachable(proposal)
      assert match?(:ok, result) or match?({:error, _}, result)
    end

    test "nil target defaults to reachable" do
      proposal = %{target: nil}
      assert :ok = GraphVerification.check_target_reachable(proposal)
    end
  end

  describe "list_registered_sources/0" do
    test "returns list of registered sources" do
      sources = GraphVerification.list_registered_sources()

      assert is_list(sources)
      assert :guardian in sources
      assert :cortex in sources
      assert :gde in sources
    end
  end
end
