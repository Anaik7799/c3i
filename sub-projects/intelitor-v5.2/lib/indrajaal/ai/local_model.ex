defmodule Indrajaal.AI.LocalModel do
  @moduledoc """
  Interface to the Local AI Entity (Ollama).

  Manages the lifecycle of the local model interaction and ensures
  that requests are properly formatted and responses are parsed.

  **SIMPLEX ARCHITECTURE INTEGRATION:**
  This module represents the "Complex Controller". It outputs proposals
  that MUST be validated by the `Indrajaal.Safety.Guardian` before execution.
  """
  use GenServer
  require Logger
  alias Indrajaal.Safety.Guardian

  # Configuration - Ollama URL
  @ollama_url "http://indrajaal-ollama:11434/api/generate"
  @default_model "llama3"

  # -----------------------------------------------------------------------------
  # Client API
  # -----------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @ollama_embed_url "http://indrajaal-ollama:11434/api/embeddings"

  @doc """
  Generates an embedding for the given text using the local model.
  """
  def embed(text) do
    GenServer.call(__MODULE__, {:embed, text}, 30_000)
  end

  @doc """
  Sends a prompt to the local AI and validates the response against safety rules.

  Returns:
  - `{:ok, %{action: action, status: :approved}}` if Guardian approves.
  - `{:ok, %{action: fallback, status: :vetoed}}` if Guardian vetoes.
  """
  def ask(prompt, context \\ %{}) do
    # 60s timeout for local AI inference (may be slower than cloud)
    GenServer.call(__MODULE__, {:ask, prompt, context}, 60_000)
  end

  @doc """
  Directly query the local model without Guardian validation (for triage).
  """
  def query(prompt, context \\ %{}) do
    GenServer.call(__MODULE__, {:query, prompt, context}, 60_000)
  end

  # -----------------------------------------------------------------------------
  # Server Callbacks
  # -----------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.info("🤖 Local AI Model Interface Initialized (Ollama: #{@ollama_url})")
    {:ok, %{model: @default_model, history: []}}
  end

  @impl true
  def handle_call({:embed, text}, _from, state) do
    body = %{
      model: state.model,
      prompt: text
    }

    result =
      case Req.post(@ollama_embed_url, json: body, receive_timeout: 25_000) do
        {:ok, %{status: 200, body: %{"embedding" => embedding}}} ->
          {:ok, %{embedding: embedding}}

        _error ->
          # Fallback to mock in dev/test
          if Application.get_env(:indrajaal, :env) == :prod do
            {:error, :embedding_failed}
          else
            {:ok, %{embedding: mock_embedding()}}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:ask, prompt, context}, _from, state) do
    # 1. Enrich prompt with context
    full_prompt = build_prompt(prompt, context)

    # 2. Call Ollama
    result =
      case call_ollama(full_prompt, state.model) do
        {:ok, response_text} ->
          # 3. Parse Action Proposal
          proposal = parse_proposal(response_text)

          # 4. SAFETY CHECK (The Simplex Switch)
          case Guardian.validate_proposal(proposal) do
            {:ok, valid_proposal} ->
              Logger.info("🤖 AI Proposal Approved by Guardian: #{inspect(valid_proposal)}")
              {:ok, %{response: response_text, action: valid_proposal, status: :approved}}

            {:veto, reason, fallback} ->
              Logger.warning("🛡️ AI Proposal VETOED by Guardian: #{inspect(reason)}")
              {:ok, %{response: response_text, action: fallback, status: :vetoed}}
          end

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:query, prompt, context}, _from, state) do
    full_prompt = build_prompt(prompt, context)

    result =
      case call_ollama(full_prompt, state.model) do
        {:ok, response_text} -> {:ok, %{response: response_text}}
        {:error, reason} -> {:error, reason}
      end

    {:reply, result, state}
  end

  # -----------------------------------------------------------------------------
  # Internals
  # -----------------------------------------------------------------------------

  defp call_ollama(prompt, model) do
    body = %{
      model: model,
      prompt: prompt,
      stream: false
    }

    case Req.post(@ollama_url, json: body, receive_timeout: 55_000) do
      {:ok, %{status: 200, body: %{"response" => response}}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        Logger.error("❌ Ollama error (Status #{status}): #{inspect(body)}")
        {:error, :ollama_failed}

      {:error, reason} ->
        Logger.error("❌ Connection to Ollama failed: #{inspect(reason)}")
        # Fallback to mock in dev/test if Ollama not running
        if Application.get_env(:indrajaal, :env) == :prod do
          {:error, :ollama_unavailable}
        else
          {:ok, mock_inference(prompt)}
        end
    end
  end

  # -----------------------------------------------------------------------------
  # Internals
  # -----------------------------------------------------------------------------

  defp build_prompt(prompt, context) do
    """
    SYSTEM: You are the Cybernetic Cortex of the Indrajaal System.
    CONTEXT: #{inspect(context)}
    TASK: #{prompt}
    OUTPUT: JSON Action Proposal.
    """
  end

  defp parse_proposal(_text) do
    # Mock parser - in production, use a Unicon Scanner or JSON parser
    # Default to a safe 'no-op' for the stub to prevent crashes
    %{action: :analyze, target: :system_state}
  end

  defp mock_inference(_prompt) do
    "Analysis complete. System appears nominal."
  end

  defp mock_embedding do
    # Return a dummy 1536-dim vector
    for _ <- 1..1536, do: 0.0
  end
end
