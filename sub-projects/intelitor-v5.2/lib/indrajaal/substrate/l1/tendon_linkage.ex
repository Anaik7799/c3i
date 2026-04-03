defmodule Indrajaal.Substrate.L1.TendonLinkage do
  @moduledoc """
  ## Design Intent
  L1 substrate tendon linkage — pure functional force transmission chain that
  routes actuation signals from a motor source through a series of linkage
  nodes to a terminal effector.

  In anatomy, tendons transmit the force produced by muscles to the bones they
  move, with no active power of their own. In the substrate layer, a tendon
  linkage chains a sequence of transformation stages — each stage may scale,
  clip, or delay the force signal before it reaches the effector. Stages can
  represent protocol adapters, rate-limiters, or priority encoders.

  Model:
    - A linkage is a list of `stage` descriptors in order
    - Each stage has a `:scale` factor (float, default 1.0) and a `:clip` max
    - `transmit/2` pipes a force value through all stages in sequence
    - `add_stage/3` appends a new stage (linkage extends distally)
    - `loss_ratio/1` returns the fraction of force lost across the chain

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 subsystem — ENFORCED
  - SC-S1-002: S1 operational responsiveness — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type stage_id :: String.t()
  @type force :: float()

  @type stage :: %{
          id: stage_id(),
          scale: float(),
          clip: float()
        }

  @type t :: %__MODULE__{
          stages: [stage()],
          max_stages: pos_integer(),
          transmissions: non_neg_integer(),
          last_input: force(),
          last_output: force()
        }

  defstruct stages: [],
            max_stages: 16,
            transmissions: 0,
            last_input: 0.0,
            last_output: 0.0

  @default_max_stages 16

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new tendon linkage.

  Options:
    - `:max_stages` (pos_integer, default 16) — maximum chain length

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max_stages = Keyword.get(opts, :max_stages, @default_max_stages)

    cond do
      not is_integer(max_stages) or max_stages < 1 ->
        {:error, "max_stages must be a positive integer"}

      true ->
        {:ok, %__MODULE__{max_stages: max_stages}}
    end
  end

  @doc """
  Append a new stage to the distal end of the linkage.

  Options:
    - `:scale` (float > 0.0, default 1.0) — multiply force by this factor
    - `:clip`  (float > 0.0, default 1.0) — maximum output force after scaling

  Returns `{:ok, updated_linkage}` or `{:error, reason}`.
  """
  @spec add_stage(t(), stage_id(), keyword()) ::
          {:ok, t()} | {:error, atom()}
  def add_stage(%__MODULE__{} = linkage, id, opts \\ [])
      when is_binary(id) do
    scale = Keyword.get(opts, :scale, 1.0)
    clip = Keyword.get(opts, :clip, 1.0)

    cond do
      length(linkage.stages) >= linkage.max_stages ->
        {:error, :chain_full}

      Enum.any?(linkage.stages, &(&1.id == id)) ->
        {:error, :duplicate_stage_id}

      not is_float(scale) or scale <= 0.0 ->
        {:error, :invalid_scale}

      not is_float(clip) or clip <= 0.0 ->
        {:error, :invalid_clip}

      true ->
        stage = %{id: id, scale: scale, clip: clip}
        {:ok, %{linkage | stages: linkage.stages ++ [stage]}}
    end
  end

  @doc """
  Transmit a force value through all stages in the chain.

  Each stage applies: `output = min(input * scale, clip)`.

  Returns `{:ok, output_force, updated_linkage}`.
  """
  @spec transmit(t(), force()) :: {:ok, force(), t()} | {:error, String.t()}
  def transmit(%__MODULE__{} = linkage, input)
      when is_float(input) and input >= 0.0 do
    output =
      Enum.reduce(linkage.stages, input, fn stage, force ->
        min(force * stage.scale, stage.clip)
      end)

    updated = %{
      linkage
      | transmissions: linkage.transmissions + 1,
        last_input: input,
        last_output: output
    }

    {:ok, output, updated}
  end

  def transmit(%__MODULE__{}, _input),
    do: {:error, "input must be a non-negative float"}

  @doc """
  Returns the fraction of force lost across the chain on the last transmission.

  Returns 0.0 when no transmission has occurred.
  """
  @spec loss_ratio(t()) :: float()
  def loss_ratio(%__MODULE__{last_input: i}) when i == 0.0, do: 0.0

  def loss_ratio(%__MODULE__{last_input: i, last_output: o}) do
    clamp((i - o) / i)
  end

  @doc """
  Returns a status map summarising the linkage state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = linkage) do
    %{
      stage_count: length(linkage.stages),
      max_stages: linkage.max_stages,
      transmissions: linkage.transmissions,
      last_input: linkage.last_input,
      last_output: linkage.last_output,
      loss_ratio: loss_ratio(linkage),
      stages: Enum.map(linkage.stages, &Map.take(&1, [:id, :scale, :clip]))
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(0.0, min(1.0, v))
end
