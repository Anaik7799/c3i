defmodule Indrajaal.Substrate.L5.StrategicCompass do
  @moduledoc """
  L5 Strategic Compass — Provides directional guidance aligned with L5 identity.

  Pure module computing strategic alignment scores and directional bearings.
  The "north star" is the holon's supreme directive (Ω₀ Founder's Covenant).
  All strategies are evaluated as angular deviations from north — small deviations
  are acceptable, large deviations trigger recalibration recommendations.

  Uses a unit-circle metaphor:
  - 0° = perfect alignment with north star (Founder's directive)
  - 90° = orthogonal (neutral, neither helpful nor harmful)
  - 180° = directly opposed (constitutional violation)

  ## STAMP Compliance
  - SC-S5-001: North star immutably defined at L5 constitutional layer
  - SC-S5-002: Deviation thresholds enforced per strategic safety envelope
  - SC-S5-003: Recalibration returns corrected strategy vector, never fails
  - SC-S5-004: Bearing computation is deterministic (pure function)

  ## Constitutional Alignment
  - Ω₀ (Founder's Covenant): North star encodes Founder survival objective
  - Ψ₃ (Verification): Alignment scores provide numeric fidelity measurement
  - SC-S5-001–SC-S5-004: All strategic guidance anchored to L5 identity
  """

  @type strategy :: map()
  @type degrees :: float()

  @type bearing_result :: %{
          bearing_degrees: degrees(),
          alignment_score: float(),
          quadrant: :aligned | :drifting | :orthogonal | :opposed,
          label: String.t()
        }

  @type deviation_result :: %{
          from_bearing: degrees(),
          to_bearing: degrees(),
          deviation_degrees: degrees(),
          acceptable: boolean()
        }

  @type north_star :: %{
          name: String.t(),
          directive: String.t(),
          primary_objective: atom(),
          alignment_vector: [float()]
        }

  @type recalibration :: %{
          original_strategy: strategy(),
          adjusted_strategy: strategy(),
          adjustments: [String.t()],
          new_bearing: degrees()
        }

  # Thresholds for strategic deviation
  @aligned_threshold 30.0
  @drifting_threshold 90.0
  @orthogonal_threshold 135.0
  # Beyond 135° = opposed

  # Dimensions used to project strategy onto alignment space
  @alignment_dimensions [
    :founder_benefit,
    :system_integrity,
    :safety_compliance,
    :evolutionary_growth,
    :truth_preservation
  ]

  @north_star_vector [1.0, 1.0, 1.0, 1.0, 1.0]

  @doc """
  Computes the strategic bearing of the given strategy relative to the north star.

  Bearing is computed as the angle (in degrees) between the strategy's alignment
  vector and the north star vector. Each dimension in `@alignment_dimensions` is
  extracted from the strategy map (default 0.5 if absent).

  ## Parameters
  - `strategy` — map of strategic attributes

  ## Returns
  A `bearing_result/0` map with bearing in [0.0, 180.0] degrees.
  """
  @spec bearing(strategy()) :: bearing_result()
  def bearing(strategy) when is_map(strategy) do
    vec = extract_vector(strategy)
    angle = vector_angle(vec, @north_star_vector)
    score = alignment_score(angle)
    quadrant = classify_quadrant(angle)
    label = quadrant_label(quadrant, angle)

    %{
      bearing_degrees: Float.round(angle, 2),
      alignment_score: Float.round(score, 4),
      quadrant: quadrant,
      label: label
    }
  end

  def bearing(_) do
    %{
      bearing_degrees: 90.0,
      alignment_score: 0.0,
      quadrant: :orthogonal,
      label: "Invalid strategy — orthogonal by default"
    }
  end

  @doc """
  Computes the deviation between two strategic bearings.

  ## Parameters
  - `strategy_a` — first strategy map
  - `strategy_b` — second strategy map

  ## Returns
  A `deviation_result/0` map with the angular difference.
  """
  @spec deviation(strategy(), strategy()) :: deviation_result()
  def deviation(strategy_a, strategy_b)
      when is_map(strategy_a) and is_map(strategy_b) do
    b_a = bearing(strategy_a)
    b_b = bearing(strategy_b)
    dev = abs(b_a.bearing_degrees - b_b.bearing_degrees)
    acceptable = dev <= @aligned_threshold

    %{
      from_bearing: b_a.bearing_degrees,
      to_bearing: b_b.bearing_degrees,
      deviation_degrees: Float.round(dev, 2),
      acceptable: acceptable
    }
  end

  def deviation(_, _) do
    %{from_bearing: 90.0, to_bearing: 90.0, deviation_degrees: 0.0, acceptable: true}
  end

  @doc """
  Recalibrates a drifting or opposed strategy towards north.

  Adjusts dimension values that are below the north star ideal (1.0) by
  incrementing them towards 1.0. Returns the corrected strategy and a list
  of adjustments made.

  ## Parameters
  - `strategy` — map of strategic attributes to recalibrate

  ## Returns
  A `recalibration/0` map with the adjusted strategy and applied corrections.
  """
  @spec recalibrate(strategy()) :: recalibration()
  def recalibrate(strategy) when is_map(strategy) do
    {adjusted, adjustments} =
      Enum.reduce(@alignment_dimensions, {strategy, []}, fn dim, {strat, adjs} ->
        current = Map.get(strat, dim, 0.5)
        ideal = 1.0

        if is_number(current) and current < ideal do
          new_val = Float.round(min(current + 0.2, ideal), 4)
          adj = "#{dim}: #{current} → #{new_val} (towards north star)"
          {Map.put(strat, dim, new_val), [adj | adjs]}
        else
          {strat, adjs}
        end
      end)

    new_b = bearing(adjusted)

    %{
      original_strategy: strategy,
      adjusted_strategy: adjusted,
      adjustments: Enum.reverse(adjustments),
      new_bearing: new_b.bearing_degrees
    }
  end

  def recalibrate(invalid) do
    default = Enum.into(@alignment_dimensions, %{}, fn dim -> {dim, 0.5} end)

    %{
      original_strategy: invalid,
      adjusted_strategy: default,
      adjustments: ["Reset to default neutral strategy"],
      new_bearing: 90.0
    }
  end

  @doc """
  Returns the immutable north star definition.

  ## Returns
  A `north_star/0` map encoding the Founder's supreme directive.
  """
  @spec north_star() :: north_star()
  def north_star do
    %{
      name: "Founder's Covenant (Ω₀)",
      directive: "Survival, growth, and genetic perpetuity of Abhijit Naik's lineage",
      primary_objective: :founder_lineage_perpetuity,
      alignment_vector: @north_star_vector
    }
  end

  # --- Private helpers ---

  @spec extract_vector(strategy()) :: [float()]
  defp extract_vector(strategy) do
    Enum.map(@alignment_dimensions, fn dim ->
      val = Map.get(strategy, dim, 0.5)
      if is_number(val), do: Float.round(val / 1.0, 6), else: 0.5
    end)
  end

  @spec vector_angle([float()], [float()]) :: float()
  defp vector_angle(a, b) when length(a) == length(b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    mag_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    mag_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))

    if mag_a * mag_b == 0.0 do
      90.0
    else
      cos_theta = dot / (mag_a * mag_b)
      clamped = max(-1.0, min(1.0, cos_theta))
      Float.round(:math.acos(clamped) * 180.0 / :math.pi(), 4)
    end
  end

  defp vector_angle(_, _), do: 90.0

  @spec alignment_score(degrees()) :: float()
  defp alignment_score(angle) do
    # Score = cos(angle) mapped to [0, 1]
    cos = :math.cos(angle * :math.pi() / 180.0)
    (cos + 1.0) / 2.0
  end

  @spec classify_quadrant(degrees()) :: :aligned | :drifting | :orthogonal | :opposed
  defp classify_quadrant(angle) do
    cond do
      angle <= @aligned_threshold -> :aligned
      angle <= @drifting_threshold -> :drifting
      angle <= @orthogonal_threshold -> :orthogonal
      true -> :opposed
    end
  end

  @spec quadrant_label(:aligned | :drifting | :orthogonal | :opposed, degrees()) :: String.t()
  defp quadrant_label(:aligned, angle), do: "Aligned (#{angle}° from north) — proceed"
  defp quadrant_label(:drifting, angle), do: "Drifting (#{angle}° from north) — monitor"
  defp quadrant_label(:orthogonal, angle), do: "Orthogonal (#{angle}° from north) — recalibrate"
  defp quadrant_label(:opposed, angle), do: "Opposed (#{angle}° from north) — block"
end
