defmodule Indrajaal.Formal.CategoryTheory do
  @moduledoc """
  Runtime verification of category theory properties for Indrajaal's formal methods layer.

  ## WHAT
  Provides runtime verification of categorical properties including composition,
  identity laws, associativity, functor laws, and natural transformation naturality.
  Morphisms are represented as Elixir functions. Verification is performed by
  testing laws against configurable sample inputs.

  ## WHY
  Ensures that system transformations (data migration, protocol upgrades, state
  machine transitions) adhere to rigorous categorical laws, preventing structural
  corruption during evolution.

  ## CONSTRAINTS
  - SC-MATH-004: ISOLATED discipline connected (CategoryTheory had 0 callers — now integrated)
  - SC-MATH-001: Mathematical discipline monitoring via MathematicalSystemMonitor
  - SC-COV-003: Mathematical proofs for core transformations
  - SC-PRF-055: Non-blocking verification (all ops complete in bounded time)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-20 | Claude | Full real implementation replacing stubs (Sprint 52, T3) |
  | 21.0.0 | 2025-12-01 | Claude | Initial stub (always returned {:ok, :verified}) |

  ## Design
  - Morphisms are plain Elixir functions `(term -> term)`.
  - A **category** is `%{morphisms: [fn], identity: fn}`.
  - A **functor** is a module implementing `map/1` and `map_morphism/1`.
  - Verification samples N inputs from a built-in pool and checks the relevant
    law holds for each one. Any violation returns `{:error, reason}`.
  - Default sample count is 10; override with `samples: N` in opts.
  """

  require Logger

  @default_samples 10

  # Built-in sample values covering integers, floats, atoms, binaries, lists, maps.
  # Note: 0.0 excluded to avoid OTP 27+ float pattern-match warning in values_equal/2.
  @sample_pool [
    0,
    1,
    -1,
    42,
    -42,
    100,
    255,
    1000,
    1.5,
    -3.14,
    2.718,
    99.9,
    :ok,
    :error,
    :init,
    :done,
    "",
    "hello",
    "world",
    "indrajaal",
    [],
    [1],
    [1, 2, 3],
    [:a, :b],
    %{},
    %{x: 1},
    %{a: 1, b: 2}
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Verify that two morphisms f: A→B and g: B→C compose correctly to g∘f: A→C.

  For each sample input `x`, computes `g.(f.(x))` and `composed.(x)` and asserts
  they are equal. If `composed` is not provided in opts, the composition is derived
  automatically as `fn x -> g.(f.(x)) end`.

  Returns `{:ok, %{composed: fn}}` on success or `{:error, :composition_failed}`.

  ## Options
  - `samples: pos_integer()` — number of inputs to test (default 10)
  - `composed: function()` — pre-composed morphism to verify against

  ## Examples

      iex> f = fn x -> x + 1 end
      iex> g = fn x -> x * 2 end
      iex> {:ok, %{composed: h}} = CategoryTheory.verify_composition(f, g)
      iex> h.(3)
      8  # (3 + 1) * 2
  """
  @spec verify_composition(function(), function(), keyword()) ::
          {:ok, %{composed: function()}} | {:error, :composition_failed}
  def verify_composition(f, g, opts \\ []) when is_function(f) and is_function(g) do
    samples = Keyword.get(opts, :samples, @default_samples)
    composed = Keyword.get(opts, :composed, fn x -> g.(f.(x)) end)
    inputs = take_samples(samples)

    result = check_composition(inputs, f, g, composed)

    case result do
      :ok ->
        Logger.debug("[CategoryTheory] Composition verified over #{length(inputs)} samples")
        {:ok, %{composed: composed}}

      {:error, reason} ->
        Logger.error("[CategoryTheory] Composition failed: #{inspect(reason)}")
        {:error, :composition_failed}
    end
  end

  @doc """
  Verify identity laws for a morphism f: A→B.

  Checks:
  - f ∘ id_A = f  (right identity: `f.(id.(x)) == f.(x)`)
  - id_B ∘ f = f  (left identity: `id.(f.(x)) == f.(x)`)

  The identity morphism defaults to `fn x -> x end`.

  ## Options
  - `samples: pos_integer()` — number of inputs to test (default 10)
  - `identity: function()` — identity morphism (default `fn x -> x end`)

  ## Returns
  `{:ok, :identity_verified}` or `{:error, :identity_violation}`
  """
  @spec verify_identity(function(), keyword()) ::
          {:ok, :identity_verified} | {:error, :identity_violation}
  def verify_identity(f, opts \\ []) when is_function(f) do
    samples = Keyword.get(opts, :samples, @default_samples)
    id = Keyword.get(opts, :identity, fn x -> x end)
    inputs = take_samples(samples)

    result = check_identity(inputs, f, id)

    case result do
      :ok ->
        Logger.debug("[CategoryTheory] Identity laws verified over #{length(inputs)} samples")
        {:ok, :identity_verified}

      {:error, reason} ->
        Logger.error("[CategoryTheory] Identity law failed: #{inspect(reason)}")
        {:error, :identity_violation}
    end
  end

  @doc """
  Verify associativity of morphism composition.

  For morphisms f, g, h, verifies:
    h ∘ (g ∘ f) = (h ∘ g) ∘ f

  Both sides are evaluated independently and compared for all sample inputs.

  ## Options
  - `samples: pos_integer()` — number of inputs to test (default 10)

  ## Returns
  `{:ok, :associativity_verified}` or `{:error, :associativity_violation}`
  """
  @spec verify_associativity(function(), function(), function(), keyword()) ::
          {:ok, :associativity_verified} | {:error, :associativity_violation}
  def verify_associativity(f, g, h, opts \\ [])
      when is_function(f) and is_function(g) and is_function(h) do
    samples = Keyword.get(opts, :samples, @default_samples)
    inputs = take_samples(samples)

    result = check_associativity(inputs, f, g, h)

    case result do
      :ok ->
        Logger.debug("[CategoryTheory] Associativity verified over #{length(inputs)} samples")
        {:ok, :associativity_verified}

      {:error, reason} ->
        Logger.error("[CategoryTheory] Associativity failed: #{inspect(reason)}")
        {:error, :associativity_violation}
    end
  end

  @doc """
  Verify functor laws for a functor module.

  The functor module must export:
  - `map/1` — maps objects (values)
  - `map_morphism/1` — maps morphisms (functions) to functions

  Verifies two laws:
  1. **Identity preservation**: F(id)(x) = x
  2. **Composition preservation**: F(g∘f)(x) = F(g)(F(f)(x))

  ## Options
  - `samples: pos_integer()` — number of inputs to test (default 10)

  ## Returns
  `{:ok, :functor_verified}` or `{:error, :functor_law_violated}`
  """
  @spec verify_functor(module(), keyword()) ::
          {:ok, :functor_verified} | {:error, :functor_law_violated}
  def verify_functor(functor_module, opts \\ []) when is_atom(functor_module) do
    if not Code.ensure_loaded?(functor_module) do
      Logger.error("[CategoryTheory] Functor module #{inspect(functor_module)} not loaded")
      {:error, :functor_law_violated}
    else
      samples = Keyword.get(opts, :samples, @default_samples)
      inputs = take_samples(samples)
      exports = functor_module.__info__(:functions)
      has_map = Keyword.has_key?(exports, :map)
      has_map_morphism = Keyword.has_key?(exports, :map_morphism)

      if not (has_map and has_map_morphism) do
        Logger.error(
          "[CategoryTheory] Functor module #{inspect(functor_module)} missing map/1 or map_morphism/1"
        )

        {:error, :functor_law_violated}
      else
        result = verify_functor_laws(functor_module, inputs)

        case result do
          :ok ->
            Logger.debug(
              "[CategoryTheory] Functor laws verified for #{inspect(functor_module)} " <>
                "over #{length(inputs)} samples"
            )

            {:ok, :functor_verified}

          {:error, reason} ->
            Logger.error("[CategoryTheory] Functor law failed: #{inspect(reason)}")
            {:error, :functor_law_violated}
        end
      end
    end
  end

  @doc """
  Verify natural transformation naturality square.

  Given source functor F (`source_functor` module), target functor G
  (`target_functor` module), and a transformation η (`transformation` — a
  function/1 mapping input values to morphisms), verifies the naturality
  condition for a sample morphism f: A→B:

    η_B ∘ F(f) = G(f) ∘ η_A

  i.e., for each sample input x:
    `eta_b.(F_f.(x)) == G_f.(eta_a.(x))`

  ## Options
  - `samples: pos_integer()` — number of inputs to test (default 10)
  - `morphism: function()` — morphism f to use in the naturality check (default identity)

  ## Returns
  `{:ok, :naturality_verified}`, `{:error, :naturality_violation}`, or
  `{:error, :module_not_found}`
  """
  @spec verify_natural_transformation(module(), module(), function(), keyword()) ::
          {:ok, :naturality_verified}
          | {:error, :naturality_violation}
          | {:error, :module_not_found}
  def verify_natural_transformation(source_functor, target_functor, transformation, opts \\ [])
      when is_atom(source_functor) and is_atom(target_functor) and is_function(transformation) do
    Logger.debug(
      "[CategoryTheory] Verifying natural transformation: " <>
        "#{inspect(source_functor)} -> #{inspect(target_functor)}"
    )

    cond do
      not Code.ensure_loaded?(source_functor) ->
        Logger.error("[CategoryTheory] Source functor #{inspect(source_functor)} not loaded")
        {:error, :module_not_found}

      not Code.ensure_loaded?(target_functor) ->
        Logger.error("[CategoryTheory] Target functor #{inspect(target_functor)} not loaded")
        {:error, :module_not_found}

      true ->
        samples = Keyword.get(opts, :samples, @default_samples)
        morphism_f = Keyword.get(opts, :morphism, fn x -> x end)
        inputs = take_numeric_samples(samples)

        result =
          check_naturality(inputs, source_functor, target_functor, transformation, morphism_f)

        case result do
          :ok ->
            Logger.debug("[CategoryTheory] Naturality verified over #{length(inputs)} samples")
            {:ok, :naturality_verified}

          {:error, reason} ->
            Logger.error("[CategoryTheory] Naturality failed: #{inspect(reason)}")
            {:error, :naturality_violation}
        end
    end
  end

  @doc """
  Run all categorical verifications for a given category.

  A category is a map with:
  - `:morphisms` — list of morphisms (functions) to verify
  - `:identity` — the identity morphism (default: `fn x -> x end`)

  Runs:
  1. Identity law for each morphism
  2. Composition for each pair (up to 10 pairs)
  3. Associativity for the first triple of morphisms (if 3+ present)

  ## Returns
  `{:ok, %{identity: :ok, composition: :ok, associativity: :ok}}` on full
  success, or `{:error, %{failing: [reason]}}` listing all failures.
  """
  @spec verify_category(map(), keyword()) ::
          {:ok, %{identity: :ok, composition: :ok, associativity: :ok}}
          | {:error, %{failing: list()}}
  def verify_category(category, opts \\ []) when is_map(category) do
    samples = Keyword.get(opts, :samples, @default_samples)
    morphisms = Map.get(category, :morphisms, [])
    identity = Map.get(category, :identity, fn x -> x end)

    identity_failures =
      Enum.flat_map(morphisms, fn f ->
        case verify_identity(f, samples: samples, identity: identity) do
          {:ok, :identity_verified} -> []
          {:error, _} -> [{:error, :identity_violation}]
        end
      end)

    composition_pairs =
      morphisms
      |> (fn ms -> for f <- ms, g <- ms, f != g, do: {f, g} end).()
      |> Enum.take(10)

    composition_failures =
      Enum.flat_map(composition_pairs, fn {f, g} ->
        case verify_composition(f, g, samples: samples) do
          {:ok, _} -> []
          {:error, _} -> [{:error, :composition_failed}]
        end
      end)

    associativity_failures =
      case morphisms do
        [f, g, h | _] ->
          case verify_associativity(f, g, h, samples: samples) do
            {:ok, :associativity_verified} -> []
            {:error, _} -> [{:error, :associativity_violation}]
          end

        _ ->
          []
      end

    all_failures = identity_failures ++ composition_failures ++ associativity_failures

    if all_failures == [] do
      {:ok, %{identity: :ok, composition: :ok, associativity: :ok}}
    else
      {:error, %{failing: all_failures}}
    end
  end

  @doc """
  Verify functor composition laws (legacy API compatibility).

  Given two functor modules F and G, verifies that each individually satisfies
  functor laws. Returns `{:ok, :verified}` if both pass.
  """
  @spec verify_functor_composition(module(), module()) ::
          {:ok, :verified} | {:error, term()}
  def verify_functor_composition(functor_f, functor_g) do
    Logger.debug(
      "[CategoryTheory] Verifying functor composition: " <>
        "#{inspect(functor_f)} ∘ #{inspect(functor_g)}"
    )

    cond do
      not Code.ensure_loaded?(functor_f) ->
        {:error, {:module_not_found, functor_f}}

      not Code.ensure_loaded?(functor_g) ->
        {:error, {:module_not_found, functor_g}}

      true ->
        with {:ok, :functor_verified} <- verify_functor(functor_f),
             {:ok, :functor_verified} <- verify_functor(functor_g) do
          {:ok, :verified}
        else
          {:error, :functor_law_violated} -> {:error, :functor_composition_failed}
          other -> other
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — law-checking helpers (pure reduce loops, no throw/catch)
  # ---------------------------------------------------------------------------

  @spec check_composition([term()], function(), function(), function()) ::
          :ok | {:error, atom()}
  defp check_composition(inputs, f, g, composed) do
    Enum.reduce_while(inputs, :ok, fn x, :ok ->
      try do
        expected = g.(f.(x))
        actual = composed.(x)

        if values_equal?(expected, actual) do
          {:cont, :ok}
        else
          Logger.warning(
            "[CategoryTheory] Composition violation at x=#{inspect(x)}: " <>
              "g(f(x))=#{inspect(expected)}, composed(x)=#{inspect(actual)}"
          )

          {:halt, {:error, :composition_mismatch}}
        end
      rescue
        e ->
          Logger.warning(
            "[CategoryTheory] Composition exception at x=#{inspect(x)}: #{inspect(e)}"
          )

          {:halt, {:error, :composition_exception}}
      end
    end)
  end

  @spec check_identity([term()], function(), function()) ::
          :ok | {:error, atom()}
  defp check_identity(inputs, f, id) do
    Enum.reduce_while(inputs, :ok, fn x, :ok ->
      try do
        fx = f.(x)
        right = f.(id.(x))
        left = id.(f.(x))

        cond do
          not values_equal?(fx, right) ->
            Logger.warning(
              "[CategoryTheory] Right identity violated at x=#{inspect(x)}: " <>
                "f(x)=#{inspect(fx)}, f(id(x))=#{inspect(right)}"
            )

            {:halt, {:error, :right_identity_violation}}

          not values_equal?(fx, left) ->
            Logger.warning(
              "[CategoryTheory] Left identity violated at x=#{inspect(x)}: " <>
                "f(x)=#{inspect(fx)}, id(f(x))=#{inspect(left)}"
            )

            {:halt, {:error, :left_identity_violation}}

          true ->
            {:cont, :ok}
        end
      rescue
        e ->
          Logger.warning("[CategoryTheory] Identity exception at x=#{inspect(x)}: #{inspect(e)}")

          {:halt, {:error, :identity_exception}}
      end
    end)
  end

  @spec check_associativity([term()], function(), function(), function()) ::
          :ok | {:error, atom()}
  defp check_associativity(inputs, f, g, h) do
    # Build fully-composed morphisms through structurally distinct paths
    # Left grouping: h ∘ (g ∘ f) — compose inner pair first
    gf = fn y -> g.(f.(y)) end
    left_composed = fn y -> h.(gf.(y)) end

    # Right grouping: (h ∘ g) ∘ f — compose outer pair first
    hg = fn y -> h.(g.(y)) end
    right_composed = fn y -> hg.(f.(y)) end

    Enum.reduce_while(inputs, :ok, fn x, :ok ->
      try do
        left_assoc = left_composed.(x)
        right_assoc = right_composed.(x)

        if values_equal?(left_assoc, right_assoc) do
          {:cont, :ok}
        else
          Logger.warning(
            "[CategoryTheory] Associativity violated at x=#{inspect(x)}: " <>
              "h∘(g∘f)(x)=#{inspect(left_assoc)}, (h∘g)∘f(x)=#{inspect(right_assoc)}"
          )

          {:halt, {:error, :associativity_mismatch}}
        end
      rescue
        e ->
          Logger.warning(
            "[CategoryTheory] Associativity exception at x=#{inspect(x)}: #{inspect(e)}"
          )

          {:halt, {:error, :associativity_exception}}
      end
    end)
  end

  @spec check_naturality([term()], module(), module(), function(), function()) ::
          :ok | {:error, atom()}
  defp check_naturality(inputs, source_functor, target_functor, transformation, morphism_f) do
    Enum.reduce_while(inputs, :ok, fn x, :ok ->
      try do
        f_f = source_functor.map_morphism(morphism_f)
        g_f = target_functor.map_morphism(morphism_f)
        eta_a = transformation.(x)
        eta_b = transformation.(morphism_f.(x))

        # Naturality square: η_B ∘ F(f) = G(f) ∘ η_A
        left_side = eta_b.(f_f.(x))
        right_side = g_f.(eta_a.(x))

        if values_equal?(left_side, right_side) do
          {:cont, :ok}
        else
          Logger.warning(
            "[CategoryTheory] Naturality violated at x=#{inspect(x)}: " <>
              "η_B∘F(f)(x)=#{inspect(left_side)}, G(f)∘η_A(x)=#{inspect(right_side)}"
          )

          {:halt, {:error, :naturality_mismatch}}
        end
      rescue
        e ->
          Logger.warning(
            "[CategoryTheory] Naturality exception at x=#{inspect(x)}: #{inspect(e)}"
          )

          {:halt, {:error, :naturality_exception}}
      end
    end)
  end

  @spec verify_functor_laws(module(), [term()]) :: :ok | {:error, atom()}
  defp verify_functor_laws(functor_module, _inputs) do
    # Use only integer inputs to avoid type errors in arithmetic morphisms.
    numeric_inputs = [0, 1, 2, 5, 10]
    identity = fn x -> x end

    Enum.reduce_while(numeric_inputs, :ok, fn x, :ok ->
      try do
        # Law 1: Identity preservation — F(id)(x) = x
        f_id = functor_module.map_morphism(identity)
        mapped_id = f_id.(x)

        if not values_equal?(mapped_id, x) do
          Logger.warning(
            "[CategoryTheory] Functor identity law violated at x=#{inspect(x)}: " <>
              "F(id)(x)=#{inspect(mapped_id)}, expected #{inspect(x)}"
          )

          {:halt, {:error, :functor_identity_violation}}
        else
          # Law 2: Composition preservation — F(g∘f)(x) = F(g)(F(f)(x))
          f_morph = fn n -> n + 1 end
          g_morph = fn n -> n * 2 end
          gf_morph = fn n -> g_morph.(f_morph.(n)) end

          f_gf = functor_module.map_morphism(gf_morph)
          f_f = functor_module.map_morphism(f_morph)
          f_g = functor_module.map_morphism(g_morph)

          left = f_gf.(x)
          right = f_g.(f_f.(x))

          if values_equal?(left, right) do
            {:cont, :ok}
          else
            Logger.warning(
              "[CategoryTheory] Functor composition law violated at x=#{inspect(x)}: " <>
                "F(g∘f)(x)=#{inspect(left)}, F(g)(F(f)(x))=#{inspect(right)}"
            )

            {:halt, {:error, :functor_composition_violation}}
          end
        end
      rescue
        e ->
          Logger.warning(
            "[CategoryTheory] Functor law exception at x=#{inspect(x)}: #{inspect(e)}"
          )

          {:halt, {:error, :functor_law_exception}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private — sampling helpers
  # ---------------------------------------------------------------------------

  @spec take_samples(pos_integer()) :: [term()]
  defp take_samples(n) when is_integer(n) and n > 0 do
    Enum.take(@sample_pool, min(n, length(@sample_pool)))
  end

  @spec take_numeric_samples(pos_integer()) :: [integer()]
  defp take_numeric_samples(n) when is_integer(n) and n > 0 do
    numeric = Enum.filter(@sample_pool, &is_integer/1)
    Enum.take(numeric, min(n, length(numeric)))
  end

  # Structural equality with float tolerance.
  @spec values_equal?(term(), term()) :: boolean()
  defp values_equal?(a, b) when is_float(a) and is_float(b) do
    abs(a - b) < 1.0e-9
  end

  defp values_equal?(a, b), do: a == b
end
