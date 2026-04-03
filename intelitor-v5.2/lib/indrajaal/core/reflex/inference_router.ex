defmodule Indrajaal.Core.Reflex.InferenceRouter do
  @moduledoc """
  Symbiotic Dual Mode inference router implementing fallback chain routing.

  Routes inference requests through available backends based on configurable
  strategy, with automatic fallback when backends are unavailable.

  ## Strategies
  - `:best`     — Full chain: OpenRouter → MojoRunner → ReflexCore → error
  - `:fast`     — ReflexCore only (lowest latency, in-process Nx)
  - `:local`    — MojoRunner + ReflexCore (no external APIs)
  - `:external` — OpenRouter only (highest quality, requires network)

  ## Sovereignty Modes
  - `:symbiotic` — Full fallback chain (default)
  - `:airgap`    — Only local backends (Mojo + Reflex)
  - `:degraded`  — Only Reflex (no Mojo, no external)

  ## STAMP Constraints
  - SC-INFERENCE-ROUTER-001: Configurable fallback chain
  - SC-INFERENCE-ROUTER-002: Fast path <100ms for ReflexCore
  - SC-INFERENCE-ROUTER-003: Backend health check before routing
  - SC-INFERENCE-ROUTER-004: All routing decisions logged
  - SC-SOVEREIGNTY-001: Air-gap survival capability

  ## Change History
  | Version | Date       | Author | Change               |
  |---------|------------|--------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation |
  """

  require Logger

  alias Indrajaal.Compute.MojoRunner
  alias Indrajaal.Core.Reflex.ReflexCore

  @type strategy :: :best | :fast | :local | :external
  @type sovereignty_mode :: :symbiotic | :airgap | :degraded
  @type backend :: :openrouter | :mojo | :reflex
  @type backend_status :: :healthy | :degraded | :unavailable | :circuit_open

  @doc """
  Route an inference request through the fallback chain.

  ## Options
  - `:strategy` — routing strategy (default: `:best`)
  - `:timeout` — per-backend timeout in ms (default: 30_000)
  - `:sovereignty` — sovereignty mode override (default: `:symbiotic`)
  """
  @spec route(atom(), term(), keyword()) ::
          {:ok, term(), backend()} | {:error, :all_backends_failed}
  def route(task, input, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :best)
    sovereignty = Keyword.get(opts, :sovereignty, :symbiotic)
    timeout = Keyword.get(opts, :timeout, 30_000)

    chain = build_chain(strategy, sovereignty)

    Logger.debug(
      "[InferenceRouter] routing task=#{inspect(task)} strategy=#{strategy} sovereignty=#{sovereignty} chain=#{inspect(chain)}"
    )

    try_chain(chain, task, input, timeout)
  end

  @doc """
  Returns the health status of all available backends.
  """
  @spec available_backends() :: [{backend(), backend_status()}]
  def available_backends do
    [
      {:openrouter, check_openrouter_health()},
      {:mojo, check_mojo_health()},
      {:reflex, check_reflex_health()}
    ]
  end

  # ─────────────────────────────────────────────────────────────────────
  # CHAIN BUILDING
  # ─────────────────────────────────────────────────────────────────────

  @spec build_chain(strategy(), sovereignty_mode()) :: [backend()]
  defp build_chain(strategy, sovereignty) do
    base_chain =
      case strategy do
        :best -> [:openrouter, :mojo, :reflex]
        :fast -> [:reflex]
        :local -> [:mojo, :reflex]
        :external -> [:openrouter]
      end

    filter_by_sovereignty(base_chain, sovereignty)
  end

  @spec filter_by_sovereignty([backend()], sovereignty_mode()) :: [backend()]
  defp filter_by_sovereignty(chain, :symbiotic), do: chain

  defp filter_by_sovereignty(chain, :airgap) do
    Enum.filter(chain, &(&1 in [:mojo, :reflex]))
  end

  defp filter_by_sovereignty(_chain, :degraded), do: [:reflex]

  # ─────────────────────────────────────────────────────────────────────
  # CHAIN EXECUTION
  # ─────────────────────────────────────────────────────────────────────

  @spec try_chain([backend()], atom(), term(), non_neg_integer()) ::
          {:ok, term(), backend()} | {:error, :all_backends_failed}
  defp try_chain([], _task, _input, _timeout) do
    Logger.error("[InferenceRouter] all backends failed — no fallback available")
    {:error, :all_backends_failed}
  end

  defp try_chain([backend | rest], task, input, timeout) do
    t0 = System.monotonic_time(:millisecond)

    case invoke_backend(backend, task, input, timeout) do
      {:ok, result} ->
        latency = System.monotonic_time(:millisecond) - t0

        Logger.info(
          "[InferenceRouter] #{backend} succeeded in #{latency}ms for task=#{inspect(task)}"
        )

        emit_telemetry(backend, task, latency, :success)
        {:ok, result, backend}

      {:error, reason} ->
        latency = System.monotonic_time(:millisecond) - t0

        Logger.warning(
          "[InferenceRouter] #{backend} failed (#{inspect(reason)}) in #{latency}ms — trying next"
        )

        emit_telemetry(backend, task, latency, :error)
        try_chain(rest, task, input, timeout)
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # BACKEND INVOCATION
  # ─────────────────────────────────────────────────────────────────────

  @spec invoke_backend(backend(), atom(), term(), non_neg_integer()) ::
          {:ok, term()} | {:error, term()}
  defp invoke_backend(:openrouter, task, input, _timeout) do
    invoke_openrouter(task, input)
  end

  defp invoke_backend(:mojo, task, input, timeout) do
    invoke_mojo(task, input, timeout)
  end

  defp invoke_backend(:reflex, task, input, _timeout) do
    invoke_reflex(task, input)
  end

  @spec invoke_openrouter(atom(), term()) :: {:ok, term()} | {:error, term()}
  defp invoke_openrouter(task, input) do
    case check_openrouter_health() do
      :unavailable ->
        {:error, :openrouter_unavailable}

      _ ->
        # Delegate to existing OpenRouter integration if available
        if Code.ensure_loaded?(Indrajaal.AI.OpenRouterClient) and
             function_exported?(Indrajaal.AI.OpenRouterClient, :chat, 2) do
          try do
            result = Indrajaal.AI.OpenRouterClient.chat(to_string(task), to_string(input))

            case result do
              {:ok, response} -> {:ok, response}
              {:error, reason} -> {:error, {:openrouter_error, reason}}
            end
          rescue
            e -> {:error, {:openrouter_exception, Exception.message(e)}}
          end
        else
          {:error, :openrouter_module_not_available}
        end
    end
  end

  @spec invoke_mojo(atom(), term(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  defp invoke_mojo(task, input, timeout) do
    case check_mojo_health() do
      :circuit_open ->
        {:error, :mojo_circuit_open}

      :unavailable ->
        {:error, :mojo_unavailable}

      _ ->
        try do
          MojoRunner.infer(to_string(task), to_string(input), timeout: timeout)
        rescue
          e -> {:error, {:mojo_exception, Exception.message(e)}}
        catch
          :exit, reason -> {:error, {:mojo_exit, reason}}
        end
    end
  end

  @spec invoke_reflex(atom(), term()) :: {:ok, term()} | {:error, term()}
  defp invoke_reflex(task, input) do
    case check_reflex_health() do
      :unavailable ->
        {:error, :reflex_unavailable}

      _ ->
        try do
          ReflexCore.infer(task, input)
        rescue
          e -> {:error, {:reflex_exception, Exception.message(e)}}
        catch
          :exit, reason -> {:error, {:reflex_exit, reason}}
        end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # HEALTH CHECKS
  # ─────────────────────────────────────────────────────────────────────

  @spec check_openrouter_health() :: backend_status()
  defp check_openrouter_health do
    api_key = System.get_env("OPENROUTER_API_KEY")

    cond do
      is_nil(api_key) or api_key == "" -> :unavailable
      true -> :healthy
    end
  end

  @spec check_mojo_health() :: backend_status()
  defp check_mojo_health do
    if Process.whereis(MojoRunner) do
      try do
        health = MojoRunner.health()

        case health do
          %{status: :circuit_open} -> :circuit_open
          %{status: :healthy} -> :healthy
          _ -> :degraded
        end
      catch
        :exit, _ -> :unavailable
      end
    else
      :unavailable
    end
  end

  @spec check_reflex_health() :: backend_status()
  defp check_reflex_health do
    if Process.whereis(ReflexCore) do
      try do
        health = ReflexCore.health()

        case health do
          %{status: :healthy} -> :healthy
          %{status: :degraded} -> :degraded
          _ -> :unavailable
        end
      catch
        :exit, _ -> :unavailable
      end
    else
      :unavailable
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # TELEMETRY
  # ─────────────────────────────────────────────────────────────────────

  @spec emit_telemetry(backend(), atom(), non_neg_integer(), :success | :error) :: :ok
  defp emit_telemetry(backend, task, latency_ms, outcome) do
    :telemetry.execute(
      [:indrajaal, :inference_router, :route],
      %{latency_ms: latency_ms},
      %{backend: backend, task: task, outcome: outcome}
    )

    :ok
  end
end
