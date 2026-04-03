defmodule Indrajaal.AI.AnalysisResourceTest do
  @moduledoc """
  Test suite for AnalysisResource - Deep code and log analysis.

  ## Test Coverage

  - Resource creation and validation
  - Analysis types
  - Content validation
  - Status transitions
  - Query handling

  ## STAMP Compliance

  - SC-TEST-001: All public functions tested
  - SC-TEST-002: Edge cases covered
  - SC-TEST-003: Error conditions tested
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.AnalysisResource

  @sample_code """
  defmodule Example do
    def hello, do: :world
  end
  """

  describe "create/1" do
    test "creates analysis with required fields" do
      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :code,
                 input_content: @sample_code,
                 query: "What does this module do?"
               })
               |> Ash.create(authorize?: false)

      assert analysis.analysis_type == :code
      assert String.trim(analysis.input_content) == String.trim(@sample_code)
      assert analysis.query == "What does this module do?"
      assert analysis.status == :pending
    end

    test "creates log analysis" do
      log_content = "[error] Connection refused"

      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :logs,
                 input_content: log_content,
                 query: "What caused this error?"
               })
               |> Ash.create(authorize?: false)

      assert analysis.analysis_type == :logs
    end

    test "creates pattern analysis" do
      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :patterns,
                 input_content: @sample_code,
                 query: "What patterns are used?"
               })
               |> Ash.create(authorize?: false)

      assert analysis.analysis_type == :patterns
    end

    test "creates architecture analysis" do
      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :architecture,
                 input_content: "Domain: Accounts, Resources: User, Team",
                 query: "Analyze the architecture"
               })
               |> Ash.create(authorize?: false)

      assert analysis.analysis_type == :architecture
    end

    test "creates security analysis" do
      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :security,
                 input_content: @sample_code,
                 query: "Find security issues"
               })
               |> Ash.create(authorize?: false)

      assert analysis.analysis_type == :security
    end

    test "creates with context files" do
      assert {:ok, analysis} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :code,
                 input_content: @sample_code,
                 query: "Analyze with context",
                 context_files: ["lib/module.ex", "lib/helper.ex"]
               })
               |> Ash.create(authorize?: false)

      assert analysis.context_files == ["lib/module.ex", "lib/helper.ex"]
    end
  end

  describe "read operations" do
    setup do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test query"
        })
        |> Ash.create(authorize?: false)

      {:ok, analysis: analysis}
    end

    test "reads analysis by id", %{analysis: analysis} do
      assert {:ok, found} = Ash.get(AnalysisResource, analysis.id)
      assert found.id == analysis.id
    end

    test "lists all analyses", %{analysis: _analysis} do
      assert {:ok, analyses} = Ash.read(AnalysisResource, authorize?: false)
      assert length(analyses) >= 1
    end

    test "reads by type", %{analysis: analysis} do
      assert {:ok, code_analyses} =
               AnalysisResource
               |> Ash.Query.for_read(:by_type, %{analysis_type: :code})
               |> Ash.read(authorize?: false)

      assert Enum.any?(code_analyses, fn a -> a.id == analysis.id end)
    end
  end

  describe "status transitions" do
    test "starts as pending" do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test"
        })
        |> Ash.create(authorize?: false)

      assert analysis.status == :pending
    end

    test "can transition to processing" do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test"
        })
        |> Ash.create(authorize?: false)

      {:ok, processing} =
        analysis
        |> Ash.Changeset.for_update(:update, %{status: :processing})
        |> Ash.update(authorize?: false)

      assert processing.status == :processing
    end
  end

  describe "validation" do
    test "requires analysis_type" do
      assert {:error, _} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 input_content: @sample_code,
                 query: "Test"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires input_content" do
      assert {:error, _} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :code,
                 query: "Test"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires query" do
      assert {:error, _} =
               AnalysisResource
               |> Ash.Changeset.for_create(:create, %{
                 analysis_type: :code,
                 input_content: @sample_code
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "results tracking" do
    test "initializes with empty results" do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test"
        })
        |> Ash.create(authorize?: false)

      assert analysis.results == %{}
    end

    test "guardian_validated defaults to false" do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test"
        })
        |> Ash.create(authorize?: false)

      assert analysis.guardian_validated == false
    end
  end

  describe "destroy/1" do
    test "destroys analysis" do
      {:ok, analysis} =
        AnalysisResource
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: @sample_code,
          query: "Test"
        })
        |> Ash.create(authorize?: false)

      assert :ok = Ash.destroy(analysis, authorize?: false)
      assert {:error, _} = Ash.get(AnalysisResource, analysis.id)
    end
  end
end
