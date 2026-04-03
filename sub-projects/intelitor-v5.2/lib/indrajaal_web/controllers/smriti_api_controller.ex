defmodule IndrajaalWeb.SmritiApiController do
  use IndrajaalWeb, :controller
  require Logger
  alias Indrajaal.Smriti.Senses.IngestionPipeline
  alias Indrajaal.Smriti.Evolution.RLHF

  @moduledoc """
  L8: SMRITI External API Gateway.
  Handles inputs from the ecosystem (Browser Extensions, CLIs, External Tools).
  """

  action_fallback IndrajaalWeb.FallbackController

  @doc """
  Captures content from an external source.
  POST /api/smriti/capture
  """
  def capture(conn, %{"content" => content, "type" => type} = params) do
    source = params["source"] || "external_api"
    priority = params["priority"] || "p3"

    Logger.info("[SMRITI.API] Capturing external content from #{source}")

    # Push to L2 Pipeline
    IngestionPipeline.ingest(content, %{
      type: type,
      source: source,
      priority: String.to_atom(priority),
      timestamp: DateTime.utc_now()
    })

    conn
    |> put_status(:accepted)
    |> json(%{status: "accepted", message: "Content queued for ingestion"})
  end

  @doc """
  Records user feedback (RLHF) on a specific Holon or System Action.
  POST /api/smriti/feedback
  """
  def feedback(conn, %{"target_id" => target_id, "score" => score} = params) do
    # score: 1 (upvote) or -1 (downvote)
    comment = params["comment"]

    Logger.info("[SMRITI.API] RLHF Feedback for #{target_id}: #{score}")

    case RLHF.record_feedback(target_id, score, comment) do
      {:ok, _feedback} ->
        conn
        |> put_status(:created)
        |> json(%{status: "recorded"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
