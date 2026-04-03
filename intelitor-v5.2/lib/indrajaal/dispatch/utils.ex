defmodule Indrajaal.Dispatch.Utils do
  @moduledoc """
  Shared utility functions for dispatch operations.

  Provides common helpers for tracking assignment metrics and managing
  dispatch-related resources across multiple modules.
  """

  @doc """
  Update assignment tracking metrics for officers and teams.

  Increments total assignments and optionally completed assignments
  and response time metrics. Supports optional response time tracking
  for officer-specific metrics.

  Options:
    - `:include_response_time` - Boolean to include response time tracking (default: false)
  """
  @spec update_assignment_tracking(Ash.Changeset.t(), keyword()) :: Ash.Changeset.t()
  def update_assignment_tracking(changeset, opts \\ []) do
    include_response_time? = Keyword.get(opts, :include_response_time, false)

    total = Ash.Changeset.get_attribute(changeset, :total_assignments)
    completed = Ash.Changeset.get_attribute(changeset, :completed_assignments)
    completed? = changeset.arguments.completed?

    changeset
    |> Ash.Changeset.force_change_attribute(:total_assignments, total + 1)
    |> maybe_increment_completed(completed, completed?)
    |> maybe_update_response_time(include_response_time?, changeset)
  end

  @doc false
  @spec maybe_increment_completed(Ash.Changeset.t(), integer(), boolean()) ::
          Ash.Changeset.t()
  defp maybe_increment_completed(changeset, completed, true) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :completed_assignments,
      completed + 1
    )
  end

  defp maybe_increment_completed(changeset, _completed, false) do
    changeset
  end

  @doc false
  @spec maybe_update_response_time(Ash.Changeset.t(), boolean(), Ash.Changeset.t()) ::
          Ash.Changeset.t()
  defp maybe_update_response_time(changeset, false, _changeset_args) do
    changeset
  end

  defp maybe_update_response_time(changeset, true, changeset_args) do
    response_time = changeset_args.arguments.response_time_minutes

    if response_time do
      current_avg =
        Ash.Changeset.get_attribute(
          changeset,
          :average_response_time_minutes
        )

      new_avg =
        if current_avg do
          (current_avg + response_time) / 2.0
        else
          response_time
        end

      Ash.Changeset.force_change_attribute(
        changeset,
        :average_response_time_minutes,
        new_avg
      )
    else
      changeset
    end
  end
end
