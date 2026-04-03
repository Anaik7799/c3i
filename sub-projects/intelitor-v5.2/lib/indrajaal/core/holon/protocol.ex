defmodule Indrajaal.Core.Holon.Protocol do
  @moduledoc """
  Holon Protocol - Communication Contract for v20.0.0

  Defines the protocol for inter-holon communication:
  1. Parent-Child messages (hierarchical)
  2. Peer-Peer messages (horizontal)
  3. Broadcast messages (fan-out)
  4. Request-Response patterns

  ## Message Types
  - `:health_report` - Child → Parent health status
  - `:resource_request` - Child → Parent resource allocation
  - `:coordination` - Peer ↔ Peer anti-oscillation
  - `:policy_update` - Parent → Child constitution enforcement
  - `:observation` - Any → S4 Intelligence input

  ## STAMP Constraints
  - SC-PROT-001: All messages MUST be authenticated
  - SC-PROT-002: Parent reports MUST complete within 100ms
  - SC-PROT-003: Failed messages MUST be retried with backoff
  - SC-PROT-004: Message ordering MUST be preserved per-sender

  ## Category Theory
  Protocol forms a Kleisli Category over IO Monad
  - Objects: Holon IDs
  - Morphisms: Messages
  - Composition: Message sequencing
  """

  alias Indrajaal.Core.Holon

  @type message_type ::
          :health_report
          | :resource_request
          | :resource_grant
          | :coordination
          | :policy_update
          | :observation
          | :command
          | :response

  @type message :: %{
          type: message_type(),
          from: Holon.holon_id(),
          to: Holon.holon_id(),
          payload: term(),
          timestamp: DateTime.t(),
          correlation_id: String.t()
        }

  @type delivery_result :: :ok | {:error, :timeout | :unreachable | :rejected}

  @doc """
  Creates a new protocol message.
  """
  @spec new_message(message_type(), Holon.holon_id(), Holon.holon_id(), term()) :: message()
  def new_message(type, from, to, payload) do
    %{
      type: type,
      from: from,
      to: to,
      payload: payload,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
  end

  @doc """
  Creates a health report message from child to parent.
  """
  @spec health_report(Holon.holon_id(), Holon.holon_id(), Holon.health(), map()) :: message()
  def health_report(child_id, parent_id, health_status, metrics \\ %{}) do
    new_message(:health_report, child_id, parent_id, %{
      health: health_status,
      metrics: metrics,
      layer: :unknown
    })
  end

  @doc """
  Creates a resource request message.
  """
  @spec resource_request(Holon.holon_id(), Holon.holon_id(), atom(), non_neg_integer()) ::
          message()
  def resource_request(requester_id, allocator_id, resource_type, amount) do
    new_message(:resource_request, requester_id, allocator_id, %{
      resource_type: resource_type,
      amount: amount,
      priority: :normal
    })
  end

  @doc """
  Creates a coordination message for peer synchronization.
  """
  @spec coordination(Holon.holon_id(), Holon.holon_id(), term()) :: message()
  def coordination(from_id, to_id, coordination_data) do
    new_message(:coordination, from_id, to_id, coordination_data)
  end

  @doc """
  Creates a policy update message from parent to child.
  """
  @spec policy_update(Holon.holon_id(), Holon.holon_id(), map()) :: message()
  def policy_update(parent_id, child_id, policy) do
    new_message(:policy_update, parent_id, child_id, policy)
  end

  @doc """
  Creates an observation message for S4 Intelligence.
  """
  @spec observation(Holon.holon_id(), Holon.holon_id(), term()) :: message()
  def observation(observer_id, intelligence_id, observation_data) do
    new_message(:observation, observer_id, intelligence_id, observation_data)
  end

  @doc """
  Creates a command message.
  """
  @spec command(Holon.holon_id(), Holon.holon_id(), atom(), term()) :: message()
  def command(commander_id, target_id, command_name, args) do
    new_message(:command, commander_id, target_id, %{
      command: command_name,
      args: args
    })
  end

  @doc """
  Creates a response message to a previous command.
  """
  @spec response(Holon.holon_id(), Holon.holon_id(), String.t(), term()) :: message()
  def response(responder_id, requester_id, correlation_id, result) do
    msg = new_message(:response, responder_id, requester_id, result)
    %{msg | correlation_id: correlation_id}
  end

  @doc """
  Validates a message structure.
  """
  @spec validate(message()) :: :ok | {:error, String.t()}
  def validate(%{type: type, from: from, to: to} = _message)
      when is_atom(type) and is_binary(from) and is_binary(to) do
    :ok
  end

  def validate(_), do: {:error, "Invalid message structure"}

  @doc """
  Checks if a message is a request that expects a response.
  """
  @spec expects_response?(message()) :: boolean()
  def expects_response?(%{type: type}) do
    type in [:resource_request, :command]
  end

  @doc """
  Checks if a message is a parent-to-child message.
  """
  @spec parent_to_child?(message()) :: boolean()
  def parent_to_child?(%{type: type}) do
    type in [:policy_update, :resource_grant]
  end

  @doc """
  Checks if a message is a child-to-parent message.
  """
  @spec child_to_parent?(message()) :: boolean()
  def child_to_parent?(%{type: type}) do
    type in [:health_report, :resource_request]
  end

  @doc """
  Serializes a message for network transmission.
  """
  @spec serialize(message()) :: binary()
  def serialize(message) do
    :erlang.term_to_binary(message)
  end

  @doc """
  Deserializes a message from binary.
  """
  @spec deserialize(binary()) :: {:ok, message()} | {:error, :invalid_message}
  def deserialize(binary) do
    try do
      {:ok, :erlang.binary_to_term(binary, [:safe])}
    rescue
      _ -> {:error, :invalid_message}
    end
  end

  # Private

  defp generate_correlation_id do
    random_bytes = :crypto.strong_rand_bytes(16)
    random_bytes |> Base.encode16(case: :lower)
  end
end
