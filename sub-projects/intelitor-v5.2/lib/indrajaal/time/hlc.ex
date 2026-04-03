defmodule Indrajaal.Time.HLC do
  @moduledoc """
  ## HYBRID LOGICAL CLOCK (L1-CELLULAR)
  Captures Causal Time across the Fractal Mesh.

  **Structure**: `{wall_time, counter, node}`
  **Property**: Monotonic increase guarantees causality tracking.
  """

  @type t :: {integer(), integer(), atom()}

  def new do
    {System.system_time(:millisecond), 0, Node.self()}
  end

  def update({l_wall, l_count, _node} = _local_hlc, {r_wall, r_count, _r_node} = _remote_hlc) do
    now = System.system_time(:millisecond)

    new_wall = Enum.max([l_wall, r_wall, now])

    new_count =
      cond do
        new_wall == l_wall and new_wall == r_wall ->
          max(l_count, r_count) + 1

        new_wall == l_wall ->
          l_count + 1

        new_wall == r_wall ->
          r_count + 1

        true ->
          0
      end

    {new_wall, new_count, Node.self()}
  end

  def to_string({wall, count, node}) do
    "HLC[#{wall}:#{count}:#{node}]"
  end
end
