defmodule Indrajaal.Substrate.L3.CapacityGovernor do
  @moduledoc """
  ## Design Intent
  L3 substrate capacity governor — pure functional module that enforces hard
  capacity limits across named resource dimensions.

  Biological metaphor: cell membrane transport limits — each channel has a
  maximum throughput and a burst tolerance. When pressure exceeds the channel
  limit, excess is dropped or queued; the governor decides which.

  Algorithm:
    - Each dimension has: limit (hard cap), burst_factor (≥1.0), and current usage.
    - Effective limit = limit × burst_factor (short-burst allowance).
    - `enforce/2` accepts a usage map and returns `{allowed, rejected}` maps.
    - Dimensions at or above `limit` are at :saturated status; below :nominal.
    - Headroom = (limit - usage) / limit, clamped to [0.0, 1.0].

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-S3-002: VSM S3 audit and accountability — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type dimension :: %{
          limit: float(),
          burst_factor: float()
        }

  @type t :: %__MODULE__{
          dimensions: %{String.t() => dimension()},
          violation_count: non_neg_integer(),
          cycle: non_neg_integer()
        }

  defstruct dimensions: %{},
            violation_count: 0,
            cycle: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new CapacityGovernor.

  Options:
    - `:dimensions` — map of `%{name => %{limit: float, burst_factor: float}}`
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    dims = Keyword.get(opts, :dimensions, %{})

    cond do
      not is_map(dims) ->
        {:error, "dimensions must be a map"}

      not all_dims_valid?(dims) ->
        {:error, "each dimension requires limit > 0 and burst_factor >= 1.0"}

      true ->
        {:ok, %__MODULE__{dimensions: dims}}
    end
  end

  @doc """
  Register a new dimension or update an existing one.
  Returns `{:error, reason}` if parameters are invalid.
  """
  @spec register_dimension(t(), String.t(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def register_dimension(%__MODULE__{} = state, name, limit, burst_factor)
      when is_binary(name) do
    cond do
      limit <= 0.0 ->
        {:error, "limit must be > 0"}

      burst_factor < 1.0 ->
        {:error, "burst_factor must be >= 1.0"}

      true ->
        dim = %{limit: limit, burst_factor: burst_factor}
        {:ok, %{state | dimensions: Map.put(state.dimensions, name, dim)}}
    end
  end

  def register_dimension(%__MODULE__{}, _name, _limit, _burst_factor),
    do: {:error, "name must be a string"}

  @doc """
  Enforce capacity limits on a usage map.

  Returns `{allowed_map, rejected_map, updated_state}` where:
  - `allowed_map` contains dimensions within their burst limit.
  - `rejected_map` contains dimensions that exceeded the burst limit.
  """
  @spec enforce(t(), %{String.t() => float()}) ::
          {%{String.t() => float()}, %{String.t() => float()}, t()}
  def enforce(%__MODULE__{} = state, usage) when is_map(usage) do
    {allowed, rejected} =
      Enum.reduce(usage, {%{}, %{}}, fn {name, value}, {allow_acc, reject_acc} ->
        case Map.get(state.dimensions, name) do
          nil ->
            # Unknown dimension passes through unchecked
            {Map.put(allow_acc, name, value), reject_acc}

          %{limit: limit, burst_factor: bf} ->
            effective_limit = limit * bf

            if value <= effective_limit do
              {Map.put(allow_acc, name, value), reject_acc}
            else
              {allow_acc, Map.put(reject_acc, name, value)}
            end
        end
      end)

    new_violations = state.violation_count + map_size(rejected)
    new_state = %{state | violation_count: new_violations, cycle: state.cycle + 1}
    {allowed, rejected, new_state}
  end

  @doc "Compute headroom for each known dimension given current usage."
  @spec headroom(t(), %{String.t() => float()}) :: %{String.t() => float()}
  def headroom(%__MODULE__{} = state, usage) when is_map(usage) do
    Map.new(state.dimensions, fn {name, %{limit: limit}} ->
      current = Map.get(usage, name, 0.0)
      hr = max(0.0, min(1.0, (limit - current) / limit))
      {name, Float.round(hr, 4)}
    end)
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      dimension_count: map_size(state.dimensions),
      violation_count: state.violation_count,
      cycle: state.cycle,
      dimensions: state.dimensions
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec all_dims_valid?(map()) :: boolean()
  defp all_dims_valid?(dims) do
    Enum.all?(dims, fn
      {_k, %{limit: l, burst_factor: bf}} when is_float(l) and is_float(bf) ->
        l > 0.0 and bf >= 1.0

      _ ->
        false
    end)
  end
end
