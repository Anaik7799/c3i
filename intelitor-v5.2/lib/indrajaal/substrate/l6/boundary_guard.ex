defmodule Indrajaal.Substrate.L6.BoundaryGuard do
  @moduledoc """
  ## Design Intent
  L6 substrate Boundary Guard — pure functional federation boundary enforcement
  for the Indrajaal inter-holon mesh.

  Models the biological concept of the cell membrane and its selective
  permeability: only messages matching allowed origin patterns, within
  rate-limit budgets, and carrying valid capability claims are admitted.

  Enforcement model:
    - Allow-list: set of permitted origin FQUN patterns (glob-style prefix match)
    - Capability check: each message must declare required capabilities
    - Rate budget: per-origin token bucket (max_tokens, refill_per_tick)
    - Verdict:  :allow | {:deny, reason}

  Token bucket is carried in pure state (no timers); callers must call
  `refill/2` periodically to replenish buckets.

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — guard enforces, never modifies
  - SC-FED-002: Maintain node autonomy — local constitution cannot be overridden
  - SC-FED-006: Attestation Ed25519-verified — capability claims verified externally
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_max_tokens 100
  @default_refill_per_tick 10

  @type verdict :: :allow | {:deny, String.t()}

  @type origin_policy :: %{
          pattern: String.t(),
          required_capabilities: [atom()],
          max_tokens: non_neg_integer(),
          refill_per_tick: non_neg_integer()
        }

  @type bucket :: %{origin: String.t(), tokens: non_neg_integer(), max_tokens: non_neg_integer()}

  @type t :: %__MODULE__{
          policies: [origin_policy()],
          buckets: %{String.t() => bucket()},
          allow_count: non_neg_integer(),
          deny_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct policies: [],
            buckets: %{},
            allow_count: 0,
            deny_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    policies = Keyword.get(opts, :policies, [])

    cond do
      not is_list(policies) ->
        {:error, "policies must be a list"}

      true ->
        state = %__MODULE__{
          policies: policies,
          buckets: %{},
          allow_count: 0,
          deny_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Evaluate whether a message from `origin` with `capabilities` should be admitted.
  Returns `{:ok, updated_guard, verdict}`.
  """
  @spec evaluate(t(), String.t(), [atom()]) :: {:ok, t(), verdict()}
  def evaluate(%__MODULE__{} = guard, origin, capabilities)
      when is_binary(origin) and is_list(capabilities) do
    case find_policy(guard.policies, origin) do
      nil ->
        updated = %{guard | deny_count: guard.deny_count + 1}
        {:ok, updated, {:deny, "no policy for origin #{origin}"}}

      policy ->
        with :ok <- check_capabilities(policy.required_capabilities, capabilities),
             {:ok, updated_guard} <- consume_token(guard, origin, policy) do
          final = %{updated_guard | allow_count: updated_guard.allow_count + 1}
          {:ok, final, :allow}
        else
          {:error, reason} ->
            updated = %{guard | deny_count: guard.deny_count + 1}
            {:ok, updated, {:deny, reason}}
        end
    end
  end

  @doc """
  Refill token buckets for all origins by their policy's `refill_per_tick` amount.
  Call this on a periodic tick.
  """
  @spec refill(t()) :: t()
  def refill(%__MODULE__{} = guard) do
    updated_buckets =
      Map.new(guard.buckets, fn {origin, bucket} ->
        policy = find_policy(guard.policies, origin)
        refill_rate = if policy, do: policy.refill_per_tick, else: @default_refill_per_tick
        new_tokens = min(bucket.tokens + refill_rate, bucket.max_tokens)
        {origin, %{bucket | tokens: new_tokens}}
      end)

    %{guard | buckets: updated_buckets}
  end

  @doc """
  Add an allow-list policy. Replaces any existing policy for the same pattern.
  """
  @spec add_policy(t(), origin_policy()) :: {:ok, t()} | {:error, String.t()}
  def add_policy(%__MODULE__{} = guard, policy) when is_map(policy) do
    cond do
      not Map.has_key?(policy, :pattern) ->
        {:error, "policy must have :pattern key"}

      true ->
        filtered = Enum.reject(guard.policies, &(&1.pattern == policy.pattern))
        {:ok, %{guard | policies: [policy | filtered]}}
    end
  end

  @doc """
  Return a summary of guard activity.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = guard) do
    %{
      policy_count: length(guard.policies),
      active_buckets: map_size(guard.buckets),
      allow_count: guard.allow_count,
      deny_count: guard.deny_count,
      total_evaluated: guard.allow_count + guard.deny_count
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec find_policy([origin_policy()], String.t()) :: origin_policy() | nil
  defp find_policy(policies, origin) do
    Enum.find(policies, fn p -> String.starts_with?(origin, p.pattern) end)
  end

  @spec check_capabilities([atom()], [atom()]) :: :ok | {:error, String.t()}
  defp check_capabilities([], _provided), do: :ok

  defp check_capabilities(required, provided) do
    missing = Enum.reject(required, &(&1 in provided))

    if missing == [] do
      :ok
    else
      {:error, "missing capabilities: #{inspect(missing)}"}
    end
  end

  @spec consume_token(t(), String.t(), origin_policy()) :: {:ok, t()} | {:error, String.t()}
  defp consume_token(guard, origin, policy) do
    max_tok = Map.get(policy, :max_tokens, @default_max_tokens)

    bucket =
      Map.get_lazy(guard.buckets, origin, fn ->
        %{origin: origin, tokens: max_tok, max_tokens: max_tok}
      end)

    if bucket.tokens > 0 do
      updated_bucket = %{bucket | tokens: bucket.tokens - 1}
      {:ok, %{guard | buckets: Map.put(guard.buckets, origin, updated_bucket)}}
    else
      {:error, "rate limit exceeded for origin #{origin}"}
    end
  end
end
