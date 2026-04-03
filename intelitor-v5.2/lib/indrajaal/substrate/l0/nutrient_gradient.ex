defmodule Indrajaal.Substrate.L0.NutrientGradient do
  @moduledoc """
  ## Design Intent
  L0 substrate nutrient gradient — pure functional resource gradient field that
  models the spatial and categorical distribution of available nutrients across
  the holon's substrate zones.

  In biology, nutrient gradients drive cell migration, morphogenesis, and organ
  formation — cells move up the gradient towards higher concentrations. In the
  substrate layer, a nutrient gradient maps resource categories (CPU, memory,
  I/O, network bandwidth) to normalised availability levels across named zones,
  enabling higher layers to make resource-aware routing decisions.

  Model:
    - Zones are named strings (e.g. "l1", "l2", "federation")
    - Each zone has a map of resource type → concentration float in [0.0, 1.0]
    - `diffuse/2` applies a decay factor to all concentrations (Fick's law
      analogy: concentration equalises over time)
    - `deposit/4` adds concentration to a zone/resource pair
    - `gradient/2` returns the steepest zone for a given resource type

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-S4-001:  Cybernetic VSM S4 — environmental scanning — REFERENCE

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type zone :: String.t()
  @type resource :: atom()
  @type concentration :: float()
  @type zone_map :: %{resource() => concentration()}

  @type t :: %__MODULE__{
          zones: %{zone() => zone_map()},
          diffusion_rate: float(),
          deposit_count: non_neg_integer()
        }

  defstruct zones: %{},
            diffusion_rate: 0.05,
            deposit_count: 0

  @default_diffusion 0.05

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new nutrient gradient field.

  Options:
    - `:diffusion_rate` (float in [0.0, 1.0], default 0.05) — concentration
      decay applied on each `diffuse/1` call

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    rate = Keyword.get(opts, :diffusion_rate, @default_diffusion)

    cond do
      not is_float(rate) or rate < 0.0 or rate > 1.0 ->
        {:error, "diffusion_rate must be a float in [0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{diffusion_rate: rate}}
    end
  end

  @doc """
  Deposit `amount` of `resource` into `zone`.

  `amount` is added to the existing concentration, clamped to 1.0.

  Returns `{:ok, updated_gradient}`.
  """
  @spec deposit(t(), zone(), resource(), concentration()) ::
          {:ok, t()} | {:error, String.t()}
  def deposit(%__MODULE__{} = grad, zone, resource, amount)
      when is_binary(zone) and is_atom(resource) and
             is_float(amount) and amount >= 0.0 do
    zone_resources = Map.get(grad.zones, zone, %{})
    current = Map.get(zone_resources, resource, 0.0)
    updated_zone = Map.put(zone_resources, resource, clamp(current + amount))
    new_zones = Map.put(grad.zones, zone, updated_zone)

    {:ok, %{grad | zones: new_zones, deposit_count: grad.deposit_count + 1}}
  end

  def deposit(%__MODULE__{}, _zone, _resource, _amount),
    do: {:error, "zone must be binary, resource must be atom, amount must be non-negative float"}

  @doc """
  Apply diffusion decay to all concentrations by `diffusion_rate`.

  Models Fickian dissipation: concentrations decay towards zero unless
  continuously replenished.

  Returns `{:ok, updated_gradient}`.
  """
  @spec diffuse(t()) :: {:ok, t()}
  def diffuse(%__MODULE__{} = grad) do
    decay = 1.0 - grad.diffusion_rate

    new_zones =
      Map.new(grad.zones, fn {zone, resources} ->
        decayed = Map.new(resources, fn {res, conc} -> {res, clamp(conc * decay)} end)
        {zone, decayed}
      end)

    {:ok, %{grad | zones: new_zones}}
  end

  @doc """
  Return the zone with the highest concentration for the given `resource`.

  Returns `{:ok, zone_name, concentration}` or `{:error, :not_found}` when
  no zone has a non-zero concentration for that resource.
  """
  @spec gradient(t(), resource()) ::
          {:ok, zone(), concentration()} | {:error, :not_found}
  def gradient(%__MODULE__{zones: zones}, resource) when is_atom(resource) do
    result =
      zones
      |> Enum.map(fn {zone, resources} ->
        {zone, Map.get(resources, resource, 0.0)}
      end)
      |> Enum.filter(fn {_zone, conc} -> conc > 0.0 end)
      |> Enum.max_by(fn {_zone, conc} -> conc end, fn -> nil end)

    case result do
      nil -> {:error, :not_found}
      {zone, conc} -> {:ok, zone, conc}
    end
  end

  @doc """
  Returns a status map summarising the gradient field.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = grad) do
    zone_summaries =
      Map.new(grad.zones, fn {zone, resources} ->
        avg =
          if map_size(resources) > 0 do
            total = Enum.reduce(resources, 0.0, fn {_r, c}, acc -> acc + c end)
            Float.round(total / map_size(resources), 4)
          else
            0.0
          end

        {zone, %{resource_count: map_size(resources), average_concentration: avg}}
      end)

    %{
      zone_count: map_size(grad.zones),
      diffusion_rate: grad.diffusion_rate,
      deposit_count: grad.deposit_count,
      zones: zone_summaries
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(0.0, min(1.0, v))
end
