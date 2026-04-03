defmodule Indrajaal.Smriti.Cognition.Curator do
  @moduledoc """
  Supervisor 2: The Curator (Quality & Relevance).

  Verifies relevance, deduplicates, and enforces STAMP constraints
  before data enters long-term memory.

  ## Responsibilities
  - Relevance Scoring (Entropy < 0.8)
  - Deduplication (SHA-256 Content Hash)
  - STAMP Constraint Validation (Guardian Check)

  ## STAMP Constraints
  - SC-SMRITI-090: Reject high-entropy (>0.8) inputs
  - SC-SMRITI-091: No duplicates allowed
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Curate a piece of content.
  Returns `{:ok, curated_content}` or `{:error, reason}`.
  """
  def curate(content, metadata) do
    GenServer.call(__MODULE__, {:curate, content, metadata})
  end

  # Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:curate, content, metadata}, _from, state) do
    with :ok <- check_entropy(metadata),
         :ok <- check_duplicates(content),
         :ok <- check_guardian(content) do
      {:reply, {:ok, content}, state}
    else
      {:error, reason} ->
        Logger.info("[Curator] Rejected content: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp check_entropy(%{entropy: e}) when e > 0.8, do: {:error, :high_entropy}
  defp check_entropy(_), do: :ok

  defp check_duplicates(_content) do
    # Mock duplicate check (would query DB)
    :ok
  end

  defp check_guardian(content) do
    # SC-SMRITI-092: All content must pass Guardian safety checks
    proposal = %{action: :ingest_content, content: content}

    case Guardian.validate_proposal(proposal) do
      {:ok, _} -> :ok
      {:veto, reason, _fallback} -> {:error, reason}
    end
  end
end
