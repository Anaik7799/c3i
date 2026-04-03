defmodule Indrajaal.AI.GenerationResourceTest do
  @moduledoc """
  Test suite for GenerationResource - Code synthesis with Guardian validation.

  ## Test Coverage

  - Resource creation and validation
  - Generation types
  - Guardian status tracking
  - Confidence calculation
  - Status transitions

  ## STAMP Compliance

  - SC-TEST-001: All public functions tested
  - SC-NEURO-001: Guardian integration tested
  - SC-GDE-061: Confidence scoring tested
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.GenerationResource

  describe "create/1" do
    test "creates generation with required fields" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Create a GenServer for rate limiting"
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.generation_type == :code
      assert generation.requirements == "Create a GenServer for rate limiting"
      assert generation.status == :pending
      assert generation.guardian_status == :pending
    end

    test "creates fix generation" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :fix,
          requirements: "Fix the undefined function error"
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.generation_type == :fix
    end

    test "creates test generation" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :test,
          requirements: "Generate tests for UserResource"
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.generation_type == :test
    end

    test "creates documentation generation" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :documentation,
          requirements: "Document the API module"
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.generation_type == :documentation
    end

    test "creates refactor generation" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :refactor,
          requirements: "Refactor for better performance"
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.generation_type == :refactor
    end

    test "creates with context" do
      context = %{"domain" => "security", "patterns" => ["circuit_breaker"]}

      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Generate with context",
          context: context
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.context == context
    end

    test "creates with affected files" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :fix,
          requirements: "Fix error",
          affected_files: ["lib/module.ex", "test/module_test.exs"]
        })

      assert {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.affected_files == ["lib/module.ex", "test/module_test.exs"]
    end
  end

  describe "read operations" do
    setup do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test generation"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      {:ok, generation: generation}
    end

    test "reads generation by id", %{generation: generation} do
      assert {:ok, found} = Ash.get(GenerationResource, generation.id)
      assert found.id == generation.id
    end

    test "reads by type", %{generation: generation} do
      assert {:ok, code_gens} =
               GenerationResource
               |> Ash.Query.for_read(:by_type, %{generation_type: :code})
               |> Ash.read(authorize?: false)

      assert Enum.any?(code_gens, fn g -> g.id == generation.id end)
    end

    test "reads pending validation", %{generation: generation} do
      assert {:ok, pending} =
               GenerationResource
               |> Ash.Query.for_read(:pending_validation)
               |> Ash.read(authorize?: false)

      assert Enum.any?(pending, fn g -> g.id == generation.id end)
    end
  end

  describe "guardian status" do
    test "starts as pending" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.guardian_status == :pending
    end

    test "can transition to approved" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      update_changeset =
        Ash.Changeset.for_update(generation, :update, %{guardian_status: :approved})

      {:ok, approved} = update_changeset |> Ash.update(authorize?: false)

      assert approved.guardian_status == :approved
    end

    test "can transition to rejected" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      update_changeset =
        Ash.Changeset.for_update(generation, :update, %{guardian_status: :rejected})

      {:ok, rejected} = update_changeset |> Ash.update(authorize?: false)

      assert rejected.guardian_status == :rejected
    end
  end

  describe "status transitions" do
    test "starts as pending" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.status == :pending
    end

    test "can transition through all statuses" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      # pending -> generating
      gen_changeset = Ash.Changeset.for_update(generation, :update, %{status: :generating})
      {:ok, generating} = gen_changeset |> Ash.update(authorize?: false)

      assert generating.status == :generating

      # generating -> validating
      val_changeset = Ash.Changeset.for_update(generating, :update, %{status: :validating})
      {:ok, validating} = val_changeset |> Ash.update(authorize?: false)

      assert validating.status == :validating

      # validating -> complete
      comp_changeset = Ash.Changeset.for_update(validating, :update, %{status: :complete})
      {:ok, complete} = comp_changeset |> Ash.update(authorize?: false)

      assert complete.status == :complete
    end
  end

  describe "validation" do
    test "requires generation_type" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          requirements: "Test"
        })

      assert {:error, _} = changeset |> Ash.create(authorize?: false)
    end

    test "requires requirements" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code
        })

      assert {:error, _} = changeset |> Ash.create(authorize?: false)
    end
  end

  describe "confidence tracking" do
    test "starts with zero confidence" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.confidence == 0.0
    end
  end

  describe "validation_errors" do
    test "starts with empty errors" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert generation.validation_errors == []
    end
  end

  describe "destroy/1" do
    test "destroys generation" do
      changeset =
        Ash.Changeset.for_create(GenerationResource, :create, %{
          generation_type: :code,
          requirements: "Test"
        })

      {:ok, generation} = changeset |> Ash.create(authorize?: false)

      assert :ok = Ash.destroy(generation, authorize?: false)
      assert {:error, _} = Ash.get(GenerationResource, generation.id)
    end
  end
end
