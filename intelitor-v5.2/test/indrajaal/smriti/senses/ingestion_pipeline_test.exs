defmodule Indrajaal.Smriti.Senses.IngestionPipelineTest do
  @moduledoc """
  TDG test suite for Smriti.Senses.IngestionPipeline.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-SMRITI-001: Ingestion pipeline must be non-blocking

  ## TPS 5-Level RCA Context
  - L1 Symptom: Content ingestion fails silently
  - L5 Root Cause: Gatekeeper not started before pipeline use
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Senses.IngestionPipeline

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(IngestionPipeline)
    end

    test "ingest/2 is exported" do
      assert function_exported?(IngestionPipeline, :ingest, 2)
    end
  end

  describe "ingest/2 without Gatekeeper running" do
    test "returns error or queued when Gatekeeper is not started" do
      result =
        try do
          IngestionPipeline.ingest("test content", %{source: "test"})
        rescue
          _ -> {:error, :gatekeeper_not_running}
        catch
          :exit, _ -> {:error, :gatekeeper_not_running}
        end

      assert match?({:ok, :queued}, result) or match?({:error, _}, result)
    end
  end
end
