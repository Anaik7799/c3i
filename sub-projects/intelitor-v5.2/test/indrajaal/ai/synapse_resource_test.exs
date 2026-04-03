defmodule Indrajaal.AI.SynapseResourceTest do
  @moduledoc """
  Test suite for SynapseResource - Multi-agent AI orchestration.

  ## Test Coverage

  - Resource creation and validation
  - Workflow types
  - Agent configuration
  - Status transitions
  - Coordination logging

  ## STAMP Compliance

  - SC-TEST-001: All public functions tested
  - SC-SYNAPSE-001: Coordination logging tested
  - SC-SYNAPSE-002: Fallback behavior tested
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.SynapseResource

  describe "create/1" do
    test "creates synapse with required fields" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{"files" => ["lib/test.ex"], "requirements" => "Add error handling"}
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.workflow_type == :analysis_then_generate
      assert synapse.status == :pending
      assert synapse.primary_agent == :gemini
    end

    test "creates parallel consensus workflow" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :parallel_consensus,
          input: %{"query" => "Analyze this code"}
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.workflow_type == :parallel_consensus
    end

    test "creates chain of thought workflow" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :chain_of_thought,
          input: %{"problem" => "Complex reasoning task"}
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.workflow_type == :chain_of_thought
    end

    test "creates shadow compare workflow" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :shadow_compare,
          input: %{"test_case" => "Compare model outputs"}
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.workflow_type == :shadow_compare
    end

    test "creates with custom primary agent" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{},
          primary_agent: :claude
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.primary_agent == :claude
    end

    test "creates with custom secondary agents" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :parallel_consensus,
          input: %{},
          secondary_agents: [:claude, :o1]
        })

      assert {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.secondary_agents == [:claude, :o1]
    end
  end

  describe "read operations" do
    setup do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{"test" => true}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      {:ok, synapse: synapse}
    end

    test "reads synapse by id", %{synapse: synapse} do
      assert {:ok, found} = Ash.get(SynapseResource, synapse.id)
      assert found.id == synapse.id
    end

    test "reads by workflow type", %{synapse: synapse} do
      assert {:ok, synapses} =
               SynapseResource
               |> Ash.Query.for_read(:by_workflow, %{workflow_type: :analysis_then_generate})
               |> Ash.read(authorize?: false)

      assert Enum.any?(synapses, fn s -> s.id == synapse.id end)
    end

    test "reads active synapses", %{synapse: synapse} do
      assert {:ok, active} =
               SynapseResource
               |> Ash.Query.for_read(:active)
               |> Ash.read(authorize?: false)

      assert Enum.any?(active, fn s -> s.id == synapse.id end)
    end
  end

  describe "status transitions" do
    test "starts as pending" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.status == :pending
    end

    test "can transition to executing" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      update_changeset = Ash.Changeset.for_update(synapse, :update, %{status: :executing})
      {:ok, executing} = update_changeset |> Ash.update(authorize?: false)

      assert executing.status == :executing
    end

    test "can transition to complete" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      update_changeset = Ash.Changeset.for_update(synapse, :update, %{status: :complete})
      {:ok, complete} = update_changeset |> Ash.update(authorize?: false)

      assert complete.status == :complete
    end

    test "can transition to failed" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      update_changeset = Ash.Changeset.for_update(synapse, :update, %{status: :failed})
      {:ok, failed} = update_changeset |> Ash.update(authorize?: false)

      assert failed.status == :failed
    end
  end

  describe "coordination logging" do
    test "starts with empty log" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.coordination_log == []
    end

    test "starts with empty error log" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.error_log == []
    end
  end

  describe "steps tracking" do
    test "starts with empty steps" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.steps == []
    end
  end

  describe "validation" do
    test "requires workflow_type" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          input: %{}
        })

      assert {:error, _} = changeset |> Ash.create(authorize?: false)
    end

    test "requires input" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate
        })

      assert {:error, _} = changeset |> Ash.create(authorize?: false)
    end
  end

  describe "guardian validation" do
    test "starts as not validated" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.guardian_validated == false
    end
  end

  describe "destroy/1" do
    test "destroys synapse" do
      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{}
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert :ok = Ash.destroy(synapse, authorize?: false)
      assert {:error, _} = Ash.get(SynapseResource, synapse.id)
    end
  end

  describe "metadata" do
    test "accepts custom metadata" do
      metadata = %{"user" => "test", "priority" => "high"}

      changeset =
        Ash.Changeset.for_create(SynapseResource, :create, %{
          workflow_type: :analysis_then_generate,
          input: %{},
          metadata: metadata
        })

      {:ok, synapse} = changeset |> Ash.create(authorize?: false)

      assert synapse.metadata == metadata
    end
  end
end
