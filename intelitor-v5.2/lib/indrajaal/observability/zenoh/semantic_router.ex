defmodule Indrajaal.Observability.Zenoh.SemanticRouter do
  @moduledoc """
  ## SEMANTIC ROUTER (L3-NERVOUS SYSTEM)
  Routes Zenoh messages based on content priority rather than just path.

  **Mechanism**:
  - Inspects payload for `priority` field.
  - Modifies topic suffix:
    - `:critical` -> `/urgent` (Immediate delivery)
    - `:background` -> `/batch` (Delayed/Batched)
    - Default -> No change

  **Compliance**: SC-ZENOH-INT-001
  """

  def route(topic, payload) when is_map(payload) do
    suffix =
      case Map.get(payload, :priority, :normal) do
        :critical -> "/urgent"
        :background -> "/batch"
        _ -> ""
      end

    {topic <> suffix, payload}
  end

  def route(topic, payload), do: {topic, payload}
end
