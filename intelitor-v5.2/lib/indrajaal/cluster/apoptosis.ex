defmodule Indrajaal.Cluster.Apoptosis do
  @moduledoc """
  Protocol for Node Self-Termination.

  ## WHAT
  Triggered when Quorum is lost to prevent Split-Brain.
  Implements a grace period with jitter to prevent dual apoptosis
  where both sides of a split terminate simultaneously.

  ## WHY
  Without a grace period, synchronized split-brain detection causes
  both partition halves to self-terminate, losing the entire cluster.
  FM-ZUIP-003 (RPN 160): 30-60s grace period + jitter + leader election.

  ## CONSTRAINTS
  - SC-SIL4-015: Apoptosis 6-phase protocol
  - FM-ZUIP-003: Grace period prevents dual apoptosis (RPN 160)
  - SC-ZTEST-008: Dual-write log fallback before Zenoh publish
  """

  require Logger

  alias Indrajaal.Observability.ZenohSession

  # Grace period range: 30-60 seconds with random jitter
  @grace_period_min_ms 30_000
  @grace_period_max_ms 60_000

  @doc """
  Initiate apoptosis with a grace period.

  The grace period (30-60s with jitter) allows the cluster to potentially
  re-establish quorum before self-terminating. If quorum is restored during
  the grace period, apoptosis is cancelled.

  ## Parameters
  - `reason` - Human-readable reason for apoptosis
  - `opts` - Options:
    - `:immediate` - Skip grace period (for emergency use only)
    - `:grace_ms` - Override grace period (for testing)
  """
  def initiate(reason \\ "Quorum Lost", opts \\ []) do
    immediate = Keyword.get(opts, :immediate, false)

    Logger.critical("[Apoptosis] APOPTOSIS TRIGGERED: #{reason}")

    # SC-ZTEST-008: Dual-write — log fallback first, then Zenoh
    Logger.critical(
      "[ZTEST-CHECKPOINT] topic=indrajaal/cluster/apoptosis type=intent " <>
        "reason=#{reason} node=#{Node.self()}"
    )

    # Publish intent to Zenoh (fire-and-forget, never blocks apoptosis)
    publish_apoptosis_intent(reason)

    if immediate do
      Logger.critical("[Apoptosis] IMMEDIATE mode — skipping grace period")
      execute_termination(reason)
    else
      grace_ms = Keyword.get(opts, :grace_ms, random_grace_period())

      Logger.critical(
        "[Apoptosis] Grace period: #{grace_ms}ms — " <>
          "cluster may re-establish quorum to cancel"
      )

      # Store cancellation ref in process dictionary for external cancellation
      ref = Process.send_after(self(), {:apoptosis_execute, reason}, grace_ms)
      Process.put(:apoptosis_timer, ref)

      {:grace_period, grace_ms, ref}
    end
  end

  @doc """
  Cancel a pending apoptosis if quorum has been restored.
  """
  def cancel do
    case Process.get(:apoptosis_timer) do
      nil ->
        :ok

      ref ->
        Process.cancel_timer(ref)
        Process.delete(:apoptosis_timer)

        Logger.warning("[Apoptosis] Apoptosis CANCELLED — quorum restored")

        Logger.info(
          "[ZTEST-CHECKPOINT] topic=indrajaal/cluster/apoptosis type=cancelled " <>
            "node=#{Node.self()}"
        )

        publish_apoptosis_cancelled()

        :ok
    end
  end

  @doc """
  Execute the actual termination sequence.
  Called after grace period expires or in immediate mode.
  """
  def execute_termination(reason) do
    Logger.critical("[Apoptosis] EXECUTING TERMINATION: #{reason}")

    Logger.critical(
      "[Apoptosis] Node is initiating graceful self-destruction to protect cluster integrity."
    )

    # Publish final dying gasp
    publish_apoptosis_executing(reason)

    # 1. Stop accepting new traffic
    # 2. Flush logs
    Logger.flush()

    # 3. Terminate VM
    System.stop(1)
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  defp random_grace_period do
    @grace_period_min_ms + :rand.uniform(@grace_period_max_ms - @grace_period_min_ms)
  end

  defp publish_apoptosis_intent(reason) do
    payload =
      Jason.encode!(%{
        type: "apoptosis_intent",
        node: to_string(Node.self()),
        reason: reason,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    ZenohSession.publish_emergency("indrajaal/cluster/apoptosis", payload)
  rescue
    _ -> :ok
  end

  defp publish_apoptosis_cancelled do
    payload =
      Jason.encode!(%{
        type: "apoptosis_cancelled",
        node: to_string(Node.self()),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    ZenohSession.publish_async("indrajaal/cluster/apoptosis", payload, :high)
  rescue
    _ -> :ok
  end

  defp publish_apoptosis_executing(reason) do
    payload =
      Jason.encode!(%{
        type: "apoptosis_executing",
        node: to_string(Node.self()),
        reason: reason,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    ZenohSession.publish_emergency("indrajaal/cluster/apoptosis", payload)
  rescue
    _ -> :ok
  end
end
