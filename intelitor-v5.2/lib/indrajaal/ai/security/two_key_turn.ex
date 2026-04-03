defmodule Indrajaal.AI.Security.TwoKeyTurn do
  @moduledoc """
  Two-Key Turn authorization for high-risk AI operations.

  ## Concept

  For high-risk operations, two independent authorizations are required:
  1. **Actor Authorization**: The user/system making the request has permission
  2. **System Authorization**: Guardian has approved the request

  ## High-Risk Criteria

  An operation is considered high-risk if ANY of these conditions apply:
  - Estimated cost > $1.00
  - Model is in the expensive tier (o1-preview, claude-3-opus)
  - Intent is :reason (complex reasoning)
  - Estimated tokens > 10,000
  - Production environment with cost > $0.50

  ## STAMP Constraints

  - SC-SEC-AI-001: Two-Key Turn for high-risk operations
  - SC-NEURO-001: Guardian approval required

  ## Usage

      if TwoKeyTurn.requires_two_key?(proposal) do
        case TwoKeyTurn.authorize(proposal, context) do
          {:ok, :authorized} -> proceed()
          {:error, reason} -> deny(reason)
        end
      end
  """

  require Logger

  @high_risk_cost_threshold 1.0
  @production_cost_threshold 0.5
  @high_risk_token_threshold 10_000

  @expensive_models [
    "openai/o1-preview",
    "openai/o1",
    "anthropic/claude-3-opus"
  ]

  @high_risk_intents [:reason]

  @doc """
  Check if a proposal requires Two-Key Turn authorization.

  ## Parameters

  - `proposal`: The AI request proposal

  ## Returns

  `true` if Two-Key Turn is required, `false` otherwise.
  """
  @spec requires_two_key?(map()) :: boolean()
  def requires_two_key?(proposal) do
    cond do
      # High cost requests
      proposal[:estimated_cost_usd] > @high_risk_cost_threshold ->
        true

      # Expensive models
      proposal[:model] in @expensive_models ->
        true

      # Complex reasoning intent
      proposal[:intent] in @high_risk_intents ->
        true

      # High token count
      total_tokens(proposal) > @high_risk_token_threshold ->
        true

      # Production environment with moderate cost
      production?() and proposal[:estimated_cost_usd] > @production_cost_threshold ->
        true

      true ->
        false
    end
  end

  @doc """
  Perform Two-Key Turn authorization.

  Requires both actor authorization and system (Guardian) authorization.

  ## Parameters

  - `proposal`: The AI request proposal
  - `context`: Authorization context including actor information

  ## Returns

  - `{:ok, :authorized}` if both keys turn
  - `{:error, reason}` if authorization fails
  """
  @spec authorize(map(), map()) :: {:ok, :authorized} | {:error, term()}
  def authorize(proposal, context) do
    with {:ok, :actor_authorized} <- check_actor_permission(proposal, context),
         {:ok, :system_authorized} <- check_system_permission(proposal) do
      Logger.debug("[TwoKeyTurn] Authorization granted for #{proposal[:request_id]}")
      {:ok, :authorized}
    else
      {:error, reason} = error ->
        Logger.warning("[TwoKeyTurn] Authorization denied: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Get the required permission level for an intent.

  ## Permission Levels

  - `:ai_basic` - Low-risk operations (triage)
  - `:ai_standard` - Normal operations (analyze, synthesize, validate)
  - `:ai_advanced` - High-risk operations (reason)
  """
  @spec intent_to_permission(atom()) :: atom()
  def intent_to_permission(:triage), do: :ai_basic
  def intent_to_permission(:analyze), do: :ai_standard
  def intent_to_permission(:synthesize), do: :ai_standard
  def intent_to_permission(:validate), do: :ai_standard
  def intent_to_permission(:code), do: :ai_standard
  def intent_to_permission(:reason), do: :ai_advanced
  def intent_to_permission(_), do: :ai_basic

  @doc """
  Check if an actor has the required permission for an operation.
  """
  @spec has_permission?(map() | nil, atom()) :: boolean()
  def has_permission?(nil, _permission), do: false

  def has_permission?(actor, required_permission) do
    permissions = Map.get(actor, :permissions, [])

    # Check if actor has the required permission or higher
    case required_permission do
      :ai_basic ->
        Enum.any?(permissions, &(&1 in [:ai_basic, :ai_standard, :ai_advanced, :admin]))

      :ai_standard ->
        Enum.any?(permissions, &(&1 in [:ai_standard, :ai_advanced, :admin]))

      :ai_advanced ->
        Enum.any?(permissions, &(&1 in [:ai_advanced, :admin]))

      _ ->
        false
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp check_actor_permission(proposal, context) do
    actor = context[:actor]
    required_permission = intent_to_permission(proposal[:intent])

    cond do
      is_nil(actor) and is_nil(context[:actor_id]) ->
        # No actor - could be system-initiated
        if system_initiated?(context) do
          {:ok, :actor_authorized}
        else
          {:error, :no_actor}
        end

      has_permission?(actor, required_permission) ->
        {:ok, :actor_authorized}

      true ->
        {:error, {:actor_not_authorized, required_permission}}
    end
  end

  defp check_system_permission(proposal) do
    # Check if Guardian has already approved this proposal
    if proposal[:guardian_approved] do
      {:ok, :system_authorized}
    else
      {:error, :system_not_authorized}
    end
  end

  defp total_tokens(proposal) do
    (proposal[:estimated_input_tokens] || 0) + (proposal[:estimated_output_tokens] || 0)
  end

  defp production? do
    Application.get_env(:indrajaal, :env) == :prod
  end

  defp system_initiated?(context) do
    # Check for trusted system sources
    context[:source] in [:guardian, :gde, :cortex, :synapse_resource]
  end
end
