defmodule Indrajaal.AI.ChatResourceTest do
  @moduledoc """
  Test suite for ChatResource - Real-time AI chat interactions.

  ## Test Coverage

  - Resource creation and validation
  - Model selection
  - Message handling
  - Session management
  - Status transitions

  ## STAMP Compliance

  - SC-TEST-001: All public functions tested
  - SC-TEST-002: Edge cases covered
  - SC-TEST-003: Error conditions tested
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.ChatResource

  describe "create/1" do
    test "creates chat with default values" do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      assert {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.model == "google/gemini-flash-1.5-8b"
      assert chat.status == :active
      assert chat.temperature == 0.7
      assert chat.messages == []
      assert chat.session_id != nil
    end

    test "creates chat with custom model" do
      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          model: "anthropic/claude-3.5-sonnet"
        })

      assert {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.model == "anthropic/claude-3.5-sonnet"
    end

    test "creates chat with custom system prompt" do
      system_prompt = "You are a security expert."

      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          system_prompt: system_prompt
        })

      assert {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.system_prompt == system_prompt
    end

    test "creates chat with custom temperature" do
      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          temperature: 0.3
        })

      assert {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.temperature == 0.3
    end
  end

  describe "read operations" do
    setup do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      {:ok, chat: chat}
    end

    test "reads chat by id", %{chat: chat} do
      assert {:ok, found} = Ash.get(ChatResource, chat.id)
      assert found.id == chat.id
    end

    test "lists all chats", %{chat: _chat} do
      assert {:ok, chats} = Ash.read(ChatResource, authorize?: false)
      assert length(chats) >= 1
    end

    test "reads active chats", %{chat: chat} do
      assert {:ok, active} =
               ChatResource
               |> Ash.Query.for_read(:active_chats)
               |> Ash.read(authorize?: false)

      assert Enum.any?(active, fn c -> c.id == chat.id end)
    end

    test "reads by session id", %{chat: chat} do
      assert {:ok, [found]} =
               ChatResource
               |> Ash.Query.for_read(:by_session, %{session_id: chat.session_id})
               |> Ash.read(authorize?: false)

      assert found.id == chat.id
    end
  end

  describe "update/2" do
    setup do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      {:ok, chat: chat}
    end

    test "updates status", %{chat: chat} do
      update_changeset = Ash.Changeset.for_update(chat, :update, %{status: :paused})
      assert {:ok, updated} = update_changeset |> Ash.update(authorize?: false)

      assert updated.status == :paused
    end

    test "updates temperature", %{chat: chat} do
      update_changeset = Ash.Changeset.for_update(chat, :update, %{temperature: 1.5})
      assert {:ok, updated} = update_changeset |> Ash.update(authorize?: false)

      assert updated.temperature == 1.5
    end

    test "updates metadata", %{chat: chat} do
      metadata = %{"user_id" => "123", "context" => "security"}

      update_changeset = Ash.Changeset.for_update(chat, :update, %{metadata: metadata})
      assert {:ok, updated} = update_changeset |> Ash.update(authorize?: false)

      assert updated.metadata == metadata
    end
  end

  describe "destroy/1" do
    test "destroys chat" do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert :ok = Ash.destroy(chat, authorize?: false)

      assert {:error, _} = Ash.get(ChatResource, chat.id)
    end
  end

  describe "model validation" do
    test "accepts valid gemini model" do
      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          model: "google/gemini-flash-1.5-8b"
        })

      assert {:ok, _} = changeset |> Ash.create(authorize?: false)
    end

    test "accepts valid claude model" do
      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          model: "anthropic/claude-3.5-sonnet"
        })

      assert {:ok, _} = changeset |> Ash.create(authorize?: false)
    end

    test "accepts valid openai model" do
      changeset =
        Ash.Changeset.for_create(ChatResource, :create, %{
          model: "openai/gpt-4o"
        })

      assert {:ok, _} = changeset |> Ash.create(authorize?: false)
    end
  end

  describe "token_usage tracking" do
    test "initializes with zero usage" do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.token_usage == %{"input" => 0, "output" => 0, "total" => 0}
    end
  end

  describe "status transitions" do
    test "transitions from active to paused" do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      assert chat.status == :active

      update_changeset = Ash.Changeset.for_update(chat, :update, %{status: :paused})
      {:ok, paused} = update_changeset |> Ash.update(authorize?: false)

      assert paused.status == :paused
    end

    test "transitions from paused to archived" do
      changeset = Ash.Changeset.for_create(ChatResource, :create, %{})
      {:ok, chat} = changeset |> Ash.create(authorize?: false)

      # First transition to paused
      pause_changeset = Ash.Changeset.for_update(chat, :update, %{status: :paused})
      {:ok, paused} = pause_changeset |> Ash.update(authorize?: false)

      # Then transition to archived
      archive_changeset = Ash.Changeset.for_update(paused, :update, %{status: :archived})
      {:ok, archived} = archive_changeset |> Ash.update(authorize?: false)

      assert archived.status == :archived
    end
  end
end
