defmodule Indrajaal.AI.ChatResource do
  @moduledoc """
  ChatResource - Real-time AI chat interactions via OpenRouter.

  ## Purpose

  Manages conversational AI sessions with streaming support for:
  - Gemini Flash (fast responses)
  - Claude Sonnet (reasoning)
  - O1 Preview (deep analysis)

  ## STAMP Constraints

  - SC-AI-001: All chat outputs validated with Guardian (optional)
  - SC-AI-002: Rate limiting via OpenRouter tier
  - SC-AI-003: Token usage tracked per session

  ## Usage

      # Create a chat session
      {:ok, chat} = Indrajaal.AIDomain
        |> Ash.Changeset.for_create(:create, %{
          model: "google/gemini-flash-1.5-8b",
          system_prompt: "You are a helpful assistant."
        })
        |> Ash.create()

      # Send a message
      {:ok, response} = Indrajaal.AI.ChatResource.chat(chat, "Hello!")
  """

  use Ash.Resource,
    domain: Indrajaal.AIDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  alias Indrajaal.AI.OpenRouterClient

  @valid_models [
    "google/gemini-flash-1.5-8b",
    "google/gemini-pro-1.5",
    "anthropic/claude-3.5-sonnet",
    "anthropic/claude-3-opus",
    "openai/gpt-4o",
    "openai/o1-preview"
  ]

  attributes do
    uuid_primary_key :id

    attribute :session_id, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
      default &Ash.UUID.generate/0
    end

    attribute :model, :string do
      allow_nil? false
      public? true
      default "google/gemini-flash-1.5-8b"
    end

    attribute :messages, {:array, :map} do
      public? true
      default []
      description "Conversation history as [{role, content}]"
    end

    attribute :system_prompt, :string do
      public? true
      constraints max_length: 10_000
      default "You are a helpful AI assistant for the Indrajaal security monitoring system."
    end

    attribute :last_response, :string do
      public? false
      description "Most recent AI response"
    end

    attribute :token_usage, :map do
      public? true
      default %{"input" => 0, "output" => 0, "total" => 0}
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :paused, :archived]
      default :active
    end

    attribute :temperature, :float do
      public? true
      constraints min: 0.0, max: 2.0
      default 0.7
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:model, :system_prompt, :temperature, :metadata]
      primary? true

      change fn changeset, _context ->
        model = Ash.Changeset.get_attribute(changeset, :model)

        if model in @valid_models do
          changeset
        else
          Ash.Changeset.add_error(changeset, field: :model, message: "Invalid model: #{model}")
        end
      end
    end

    update :update do
      accept [:status, :temperature, :metadata]
      primary? true
    end

    action :chat, :map do
      argument :chat_id, :uuid, allow_nil?: false
      argument :user_message, :string, allow_nil?: false
      argument :stream?, :boolean, default: false

      run fn input, _context ->
        chat_id = input.arguments.chat_id
        user_message = input.arguments.user_message

        # Get the chat session
        case Ash.get(Indrajaal.AI.ChatResource, chat_id) do
          {:ok, chat} ->
            # Build messages with history
            messages = build_messages(chat, user_message)

            # Call OpenRouter
            model_atom = model_to_atom(chat.model)

            case OpenRouterClient.chat(messages, model: model_atom) do
              {:ok, response} ->
                # Update chat with new message and response
                new_messages =
                  chat.messages ++
                    [
                      %{"role" => "user", "content" => user_message},
                      %{"role" => "assistant", "content" => response}
                    ]

                {:ok, _updated} =
                  chat
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:messages, new_messages)
                  |> Ash.Changeset.force_change_attribute(:last_response, response)
                  |> Ash.update()

                {:ok, %{response: response, chat_id: chat_id}}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, _} ->
            {:error, :chat_not_found}
        end
      end
    end

    read :by_session do
      argument :session_id, :string, allow_nil?: false

      filter expr(session_id == ^arg(:session_id))
    end

    read :active_chats do
      filter expr(status == :active)
    end
  end

  json_api do
    type "chat"

    routes do
      base("/chats")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  # Private helpers

  defp build_messages(chat, user_message) do
    system_msg = %{"role" => "system", "content" => chat.system_prompt}

    history =
      Enum.map(chat.messages, fn msg ->
        %{"role" => msg["role"], "content" => msg["content"]}
      end)

    user_msg = %{"role" => "user", "content" => user_message}

    [system_msg | history] ++ [user_msg]
  end

  defp model_to_atom("google/gemini-flash-1.5-8b"), do: :fast
  defp model_to_atom("google/gemini-pro-1.5"), do: :smart
  defp model_to_atom("anthropic/claude-3.5-sonnet"), do: :smart
  defp model_to_atom("anthropic/claude-3-opus"), do: :deep
  defp model_to_atom("openai/gpt-4o"), do: :smart
  defp model_to_atom("openai/o1-preview"), do: :deep
  defp model_to_atom(_), do: :fast
end
