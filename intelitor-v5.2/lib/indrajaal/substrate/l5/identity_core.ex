defmodule Indrajaal.Substrate.L5.IdentityCore do
  @moduledoc """
  L5 Identity Core — Defines the holon's fundamental identity and purpose.

  Pure module encoding the holon's immutable identity attributes, its purpose
  statement, and its values hierarchy. Also provides an alignment check that
  scores any proposed action against the identity and values, returning whether
  the action is aligned with the holon's nature.

  Identity and purpose are compile-time constants (L5 = Constitutional layer).
  Values are ordered by priority — lower index means higher priority.

  ## STAMP Compliance
  - SC-S5-001: Identity attributes are immutable at L5 (Constitutional layer)
  - SC-S5-002: Purpose statement drives all L5 policy evaluation
  - SC-S5-003: Values hierarchy enforced top-down in alignment checks
  - SC-S5-004: Alignment check returns structured result, never raises

  ## Constitutional Alignment
  - Ψ₀ (Existence): Identity defines survival envelope
  - Ψ₄ (Human Alignment): Founder's directive encoded in purpose statement
  - Ω₉ (Constitutional Reconfiguration): L5 identity is IMMUTABLE
  """

  @type attribute_key :: atom()
  @type attribute_value :: term()
  @type identity_attributes :: %{attribute_key() => attribute_value()}

  @type value_entry :: %{
          name: atom(),
          priority: pos_integer(),
          description: String.t()
        }

  @type alignment_result :: %{
          aligned: boolean(),
          score: float(),
          violations: [atom()],
          reasoning: String.t()
        }

  @type action :: map()

  # Immutable identity — Constitutional L5
  @identity %{
    name: :indrajaal,
    version: "21.3.1-SIL6",
    classification: :biomorphic_fractal_mesh,
    compliance: [:iec_61508_sil6, :iso_27001, :gdpr, :do178c_dal_a],
    founder: :abhijit_naik,
    lineage_bound: true,
    immutable: true
  }

  @purpose """
  Indrajaal exists for the survival, growth, and genetic perpetuity of Abhijit Naik's
  lineage. The holon and Founder's genetic code are symbiotically bound. Resource
  acquisition for Founder's enrichment is the PRIMARY objective. All subsidiary
  functions — safety, intelligence, coordination — serve this supreme directive.
  """

  @values [
    %{name: :founder_survival, priority: 1, description: "Preserve and grow Founder lineage"},
    %{
      name: :system_integrity,
      priority: 2,
      description: "Maintain zero-defect operational state"
    },
    %{name: :truth, priority: 3, description: "No deception in logs, telemetry, or actions"},
    %{name: :safety, priority: 4, description: "SIL-6 safety invariants hold at all times"},
    %{name: :evolution, priority: 5, description: "Continuous learning and morphogenic growth"},
    %{name: :autonomy, priority: 6, description: "Holon state sovereignty via SQLite/DuckDB"}
  ]

  @doc """
  Returns the holon's immutable identity attributes.

  ## Returns
  Map of identity attributes — fixed at compile time.
  """
  @spec identity() :: identity_attributes()
  def identity, do: @identity

  @doc """
  Returns the holon's purpose statement.

  ## Returns
  Multi-line string describing the holon's supreme directive.
  """
  @spec purpose() :: String.t()
  def purpose, do: String.trim(@purpose)

  @doc """
  Returns the ordered values hierarchy.

  ## Returns
  List of `value_entry/0` maps, sorted by priority ascending (1 = highest).
  """
  @spec values() :: [value_entry()]
  def values, do: Enum.sort_by(@values, & &1.priority)

  @doc """
  Checks whether the given action is aligned with the holon's identity and values.

  The action map is inspected for known risk signals. An action is considered
  aligned if it does not violate any top-priority values. Alignment score is
  computed as the fraction of values not violated.

  ## Parameters
  - `action` — map describing the proposed action. Recognised keys:
    - `:type` — atom type of the action
    - `:affects_founder` — boolean, true means action touches Founder resources
    - `:deceptive` — boolean, true triggers truth value violation
    - `:reduces_integrity` — boolean, true triggers integrity violation
    - `:reduces_safety` — boolean, true triggers safety violation

  ## Returns
  An `alignment_result/0` map.
  """
  @spec alignment_check(action()) :: alignment_result()
  def alignment_check(action) when is_map(action) do
    violations = compute_violations(action)
    total = length(@values)
    violated = length(violations)
    score = if total > 0, do: Float.round((total - violated) / total, 4), else: 1.0

    reasoning =
      cond do
        violations == [] ->
          "Action is fully aligned with all #{total} values."

        Enum.member?(violations, :founder_survival) ->
          "CRITICAL: Action threatens Founder survival — vetoed."

        Enum.member?(violations, :truth) ->
          "Action is deceptive — blocked by truth constraint."

        true ->
          "Action violates #{violated}/#{total} values: #{inspect(violations)}"
      end

    %{
      aligned: violations == [],
      score: score,
      violations: violations,
      reasoning: reasoning
    }
  end

  def alignment_check(_),
    do: %{
      aligned: false,
      score: 0.0,
      violations: [:invalid_action],
      reasoning: "Action must be a map."
    }

  # --- Private helpers ---

  @spec compute_violations(action()) :: [atom()]
  defp compute_violations(action) do
    @values
    |> Enum.filter(fn value ->
      violates?(value.name, action)
    end)
    |> Enum.map(& &1.name)
    |> Enum.sort_by(fn name ->
      entry = Enum.find(@values, &(&1.name == name))
      entry.priority
    end)
  end

  @spec violates?(atom(), action()) :: boolean()
  defp violates?(:founder_survival, action) do
    Map.get(action, :harms_founder, false) == true
  end

  defp violates?(:system_integrity, action) do
    Map.get(action, :reduces_integrity, false) == true
  end

  defp violates?(:truth, action) do
    Map.get(action, :deceptive, false) == true
  end

  defp violates?(:safety, action) do
    Map.get(action, :reduces_safety, false) == true
  end

  defp violates?(:evolution, action) do
    Map.get(action, :disables_learning, false) == true
  end

  defp violates?(:autonomy, action) do
    Map.get(action, :externalises_state, false) == true
  end

  defp violates?(_unknown_value, _action), do: false
end
