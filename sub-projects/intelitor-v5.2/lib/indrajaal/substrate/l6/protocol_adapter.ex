defmodule Indrajaal.Substrate.L6.ProtocolAdapter do
  @moduledoc """
  ## Design Intent
  L6 substrate Protocol Adapter — pure functional communication protocol
  translation for the Indrajaal inter-holon federation layer.

  Models membrane receptor biology: this adapter acts as a receptor complex
  that translates signals from foreign holons (using their native protocol
  encoding) into the canonical internal message format, and vice-versa.

  Supported protocol families:
    - :zenoh     — native Zenoh pub/sub key expressions
    - :pubsub    — Phoenix PubSub topic format
    - :mqtt      — MQTT topic hierarchy (external IoT bridge)
    - :amqp      — AMQP routing-key format (enterprise gateway)
    - :internal  — canonical Indrajaal tuple format

  Translation is purely structural: no I/O occurs. The adapter transforms
  the routing address and wraps/unwraps the payload envelope.

  ## STAMP Constraints
  - SC-FED-002: Maintain node autonomy — adapters never mutate payload semantics
  - SC-FED-003: Detect constitution divergence — unknown protocol returns error
  - SC-ECO-001: Ecosystem boundaries — protocol translation at the edge only
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type protocol :: :zenoh | :pubsub | :mqtt | :amqp | :internal

  @type message :: %{
          source_protocol: protocol(),
          target_protocol: protocol(),
          address: String.t(),
          payload: map(),
          translated_at: integer()
        }

  @type t :: %__MODULE__{
          supported_protocols: [protocol()],
          translation_count: non_neg_integer(),
          error_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct supported_protocols: [:zenoh, :pubsub, :mqtt, :amqp, :internal],
            translation_count: 0,
            error_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    extra = Keyword.get(opts, :extra_protocols, [])

    cond do
      not is_list(extra) ->
        {:error, "extra_protocols must be a list of atoms"}

      true ->
        defaults = [:zenoh, :pubsub, :mqtt, :amqp, :internal]

        state = %__MODULE__{
          supported_protocols: Enum.uniq(defaults ++ extra),
          translation_count: 0,
          error_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Translate a message address from `source` protocol to `target` protocol.
  Returns `{:ok, updated_adapter, translated_message}` or `{:error, reason}`.
  """
  @spec translate(t(), protocol(), protocol(), String.t(), map()) ::
          {:ok, t(), message()} | {:error, String.t()}
  def translate(%__MODULE__{} = adapter, source, target, address, payload)
      when is_atom(source) and is_atom(target) and is_binary(address) and is_map(payload) do
    cond do
      source not in adapter.supported_protocols ->
        updated = %{adapter | error_count: adapter.error_count + 1}
        {:error, updated, "unsupported source protocol: #{source}"}

      target not in adapter.supported_protocols ->
        updated = %{adapter | error_count: adapter.error_count + 1}
        {:error, updated, "unsupported target protocol: #{target}"}

      true ->
        translated_address = convert_address(source, target, address)

        msg = %{
          source_protocol: source,
          target_protocol: target,
          address: translated_address,
          payload: payload,
          translated_at: System.monotonic_time(:millisecond)
        }

        updated = %{adapter | translation_count: adapter.translation_count + 1}
        {:ok, updated, msg}
    end
  end

  @doc """
  Check whether a protocol is supported by this adapter instance.
  """
  @spec supports?(t(), protocol()) :: boolean()
  def supports?(%__MODULE__{} = adapter, protocol) when is_atom(protocol) do
    protocol in adapter.supported_protocols
  end

  @doc """
  Return a summary of adapter activity.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = adapter) do
    %{
      supported_protocols: adapter.supported_protocols,
      translation_count: adapter.translation_count,
      error_count: adapter.error_count,
      success_rate:
        if adapter.translation_count + adapter.error_count > 0 do
          Float.round(
            adapter.translation_count / (adapter.translation_count + adapter.error_count),
            4
          )
        else
          1.0
        end
    }
  end

  # ---------------------------------------------------------------------------
  # Private — address conversion rules
  # ---------------------------------------------------------------------------

  @spec convert_address(protocol(), protocol(), String.t()) :: String.t()
  defp convert_address(:zenoh, :pubsub, addr) do
    # "indrajaal/domain/topic" → "indrajaal:domain:topic"
    String.replace(addr, "/", ":")
  end

  defp convert_address(:pubsub, :zenoh, addr) do
    # "indrajaal:domain:topic" → "indrajaal/domain/topic"
    String.replace(addr, ":", "/")
  end

  defp convert_address(:mqtt, :zenoh, addr) do
    # MQTT uses "/" but with wildcard "+" → replace
    addr
    |> String.replace("+", "*")
    |> String.replace("#", "**")
  end

  defp convert_address(:zenoh, :mqtt, addr) do
    addr
    |> String.replace("**", "#")
    |> String.replace("*", "+")
  end

  defp convert_address(:amqp, :internal, addr) do
    # AMQP routing key "domain.subdomain.event" → "{:domain, :subdomain, :event}"
    parts = String.split(addr, ".") |> Enum.map(&String.to_atom/1)
    inspect(List.to_tuple(parts))
  end

  defp convert_address(_source, _target, addr), do: addr
end
