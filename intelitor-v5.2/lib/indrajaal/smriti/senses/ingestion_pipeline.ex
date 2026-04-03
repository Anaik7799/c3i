defmodule Indrajaal.Smriti.Senses.IngestionPipeline do
  @moduledoc """
  Context module for SMRITI Ingestion.
  Orchestrates the flow between Gatekeeper and Curator.
  """
  require Logger
  alias Indrajaal.Smriti.Senses.Gatekeeper
  alias Indrajaal.Smriti.Cognition.Curator

  def ingest(content, metadata) do
    # 1. Estimate cost/size
    size = byte_size(content)
    # Mock cost
    cost = size * 0.000001

    # 2. Ask Gatekeeper
    case Gatekeeper.request_ingest(1, cost) do
      {:ok, token} ->
        # 3. Async processing to not block caller
        Task.start(fn ->
          process_ingest(content, metadata, token)
        end)

        {:ok, :queued}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_ingest(content, metadata, token) do
    try do
      # 4. Curate
      case Curator.curate(content, metadata) do
        {:ok, curated} ->
          Logger.info("[Ingestion] Content curated: #{String.slice(curated, 0, 50)}...")

          # 5. Store via VectorStore + embedding
          holon_id = Map.get(metadata, :holon_id, "hln_#{:erlang.phash2({curated, metadata})}")
          store_curated_content(holon_id, curated, metadata)

        error ->
          Logger.warning("[Ingestion] Curation failed: #{inspect(error)}")
      end
    after
      # 6. Release token
      Gatekeeper.report_completion(token)
    end
  end

  defp store_curated_content(holon_id, curated, metadata) do
    alias Indrajaal.SMRITI.Mesh.VectorStore

    # Generate a simple hash-based embedding for storage
    # Real embedding generation happens via KMS.AI when GenServer is running
    embedding = hash_pseudo_embedding(curated)

    case VectorStore.store(holon_id, embedding, metadata: metadata) do
      :ok ->
        Logger.info(
          "[Ingestion] Stored holon #{holon_id} with #{length(embedding)}-dim embedding"
        )

        :ok

      {:error, reason} ->
        Logger.warning("[Ingestion] VectorStore.store failed for #{holon_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp hash_pseudo_embedding(text) do
    # Deterministic embedding from text hash — placeholder until KMS.AI GenServer provides real embeddings
    hash = :crypto.hash(:sha256, text)
    for <<byte <- hash>>, do: (byte - 128) / 128.0
  end
end
