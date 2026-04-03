defmodule EscalationEngine do
  @moduledoc """
  Escalation Engine stub (non-namespaced).

  This module provides alarm escalation functionality.
  Created as a stub to resolve UNDEFINED_MODULE warnings during Phase 1.

  Note: There is also Indrajaal.EscalationEngine which is the namespaced version.
  This non-namespaced version is used by some legacy code that hasn't been migrated yet.

  Functions to be implemented in Phase 2:
  - trigger_for_alarm/1
  - evaluate_escalation/1
  - notify_escalation_tier/2
  """

  @doc """
  Trigger escalation workflow for an alarm.

  ## Parameters
  - alarm: The alarm to trigger escalation for

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec trigger_for_alarm(map()) :: :ok | {:error, String.t()}
  def trigger_for_alarm(_alarm) do
    {:error, "EscalationEngine.trigger_for_alarm/1 not yet implemented - stub only"}
  end

  @doc """
  Evaluate escalation rules for an alarm.

  ## Parameters
  - alarm: The alarm to evaluate

  ## Returns
  - {:ok, escalation_level} on success
  - {:error, reason} on failure
  """
  @spec evaluate_escalation(map()) :: {:ok, atom()} | {:error, String.t()}
  def evaluate_escalation(_alarm) do
    {:error, "EscalationEngine.evaluate_escalation/1 not yet implemented - stub only"}
  end

  @doc """
  Notify an escalation tier about an alarm.

  ## Parameters
  - tier: The escalation tier to notify
  - alarm: The alarm information

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec notify_escalation_tier(atom(), map()) :: :ok | {:error, String.t()}
  def notify_escalation_tier(_tier, _alarm) do
    {:error, "EscalationEngine.notify_escalation_tier/2 not yet implemented - stub only"}
  end
end
