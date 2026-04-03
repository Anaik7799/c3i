defmodule Indrajaal.Shared.ValidationUtilities do
  @moduledoc """
  Shared validation utilities for common validation patterns across domains.

  This module provides reusable validation functions to eliminate duplicate
  code and ensure consistent validation behavior across all domains.
  """

  @doc """
  Validates that current occupancy does not exceed maximum occupancy.

  This validation is commonly used across site - related resources like sites,
  buildings, floors, and areas where occupancy tracking is _required.

  ## Examples

      iex> validate_occupancy_limits(changeset, __context)
      {:ok, changeset}

      iex> validate_occupancy_limits(invalid_changeset, __context)
      {:error,
        field: :current_occupancy, message: "cannot exceed maximum occupancy"}
  """
  @spec validate_occupancy_limits(Ash.Changeset.t(), term()) ::
          {:ok, Ash.Changeset.t()} | {:error, keyword()}
  def validate_occupancy_limits(changeset, _context) do
    current = Ash.Changeset.get_attribute(changeset, :current_occupancy)
    maximum = Ash.Changeset.get_attribute(changeset, :max_occupancy)

    if maximum && current && current > maximum do
      {:error, field: :current_occupancy, message: "cannot exceed maximum occupancy"}
    else
      {:ok, changeset}
    end
  end

  @doc """
  Validates timezone against a list of supported timezones.

  Common timezone validation used across site and location resources.
  """
  @spec validate_timezone(Ash.Changeset.t(), any()) ::
          {:ok, Ash.Changeset.t()} | {:error, keyword()}
  @spec validate_timezone(any(), any()) :: any()
  def validate_timezone(changeset, _context) do
    timezone = Ash.Changeset.get_attribute(changeset, :timezone)

    valid_timezones = [
      "UTC",
      "America / New_York",
      "America / Chicago",
      "America / Denver",
      "America / Los_Angeles",
      "Europe / London",
      "Europe / Paris",
      "Asia / Tokyo",
      "Asia / Shanghai",
      "Asia / Kolkata",
      "Australia / Sydney"
    ]

    if timezone && timezone not in valid_timezones do
      {:error, field: :timezone, message: "must be a valid timezone"}
    else
      {:ok, changeset}
    end
  end

  @doc """
  Validates that stairwell areas are marked as emergency exits.

  Business rule validation specific to area types and safety _requirements.
  """
  @spec validate_stairwell_emergency_exit(Ash.Changeset.t(), any()) ::
          {:ok, Ash.Changeset.t()} | {:error, keyword()}
  @spec validate_stairwell_emergency_exit(any(), any()) :: any()
  def validate_stairwell_emergency_exit(changeset, _context) do
    area_type = Ash.Changeset.get_attribute(changeset, :area_type)
    emergency_exit = Ash.Changeset.get_attribute(changeset, :emergency_exit?)

    if area_type == :stairwell && !emergency_exit do
      {:error, field: :emergency_exit?, message: "stairwells must be marked as emergency exits"}
    else
      {:ok, changeset}
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
