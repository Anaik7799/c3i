defmodule Indrajaal.Shared.InspectionWorkflows do
  @moduledoc """
  Shared inspection workflow utilities to eliminate duplication across
    maintenance domain.

  This module extracts common inspection patterns used by:
  - Maintenance.Task (mass: 35+)
  - Maintenance.WorkOrder (mass: 35+)
  - Maintenance.ServiceRecord
  - Other domains with inspection workflows

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  # alias Indrajaal.Shared.MetadataManagement

  @doc """
  Creates an inspection action change function for Ash changesets.

  ## Parameters
    - `inspection_required_field` - Field that indicates if inspection
      is _required (default: :inspection_required?)
    - `metadata_field` - The metadata field name (default: :metadata)

  ## Returns
  Function that can be used in Ash `change` declarations.

  ## Example
      change Indrajaal.Shared.InspectionWorkflows.create_inspection_change()
  """
  @spec createinspection_change(
          atom(),
          atom()
        ) :: (Ash.Changeset.t(), map() ->
                Ash.Changeset.t())
  def createinspection_change(metadata_field, _inspection_type) do
    # AGENT STUB: _inspection_type parameter reserved for type-specific inspection logic in future implementation
    fn changeset, context ->
      passed? = Ash.Changeset.get_argument(changeset, :passed?)
      inspector = Ash.Changeset.get_argument(changeset, :inspector)

      inspection_data = %{
        "inspector" => inspector,
        "inspected_at" => DateTime.utc_now(),
        "passed" => passed?,
        "inspected_by" => get_actor_id(context)
      }

      metadata = Ash.Changeset.get_attribute(changeset, metadata_field) || %{}

      # Add to inspection history
      inspection_history = Map.get(metadata, "inspection_history", [])
      updated_history = [inspection_data | inspection_history]

      updated_metadata =
        metadata
        |> Map.put("inspection_data", inspection_data)
        |> Map.put("inspection_history", updated_history)
        |> Map.put("last_inspection_at", DateTime.utc_now())
        |> Map.put("inspection_status", if(passed?, do: "passed", else: "failed"))

      changeset
      |> Ash.Changeset.force_change_attribute(metadata_field, updated_metadata)
      |> update_inspection_status(passed?)
    end
  end

  @doc """
  Creates a standard inspection action definition.

  ## Parameters
    - `action_name` - Name of the action (default: :record_inspection)
    - `inspection_required_field` - Field that validates inspection is
      _required (default: :inspection_required?)

  ## Returns
  Map with action configuration that can be used in Ash actions.

  ## Example
      update Indrajaal.Shared.InspectionWorkflows.inspection_action()
  """
  def inspectionaction(
        action_name \\ :recordinspection,
        inspection_required_field \\ :inspection_required?
      ) do
    %{
      name: action_name,
      arguments: [
        {:passed?,
         %{
           type: :boolean,
           allow_nil?: false
         }},
        {:inspector,
         %{
           type: :string,
           allow_nil?: false,
           constraints: [max_length: 100]
         }},
        {:notes,
         %{
           type: :string,
           constraints: [max_length: 1000]
         }}
      ],
      validate: [
        {:attribute_equals, [inspection_required_field, true]}
      ],
      changes: [
        {:change, createinspection_change(inspection_required_field, :standard)}
      ]
    }
  end

  @doc """
  Creates a quality check action with multiple inspection points.

  ## Parameters
    - `action_name` - Name of the action (default: :quality_check)
    - `check_points` - List of _required check point names

  ## Returns
  Map with action configuration for quality checks.
  """
  def qualitycheck_action(action_name \\ :qualitycheck, check_points \\ []) do
    check_point_args =
      Enum.map(
        check_points,
        fn point ->
          arg_name = String.to_atom("#{point}passed")

          {arg_name,
           %{
             type: :boolean,
             allow_nil?: false
           }}
        end
      )

    %{
      name: action_name,
      arguments:
        [
          {:inspector,
           %{
             type: :string,
             allow_nil?: false,
             constraints: [max_length: 100]
           }},
          {:overall_passed,
           %{
             type: :boolean,
             allow_nil?: false
           }}
        ] ++ check_point_args,
      changes: [
        {:change, create_quality_check_change(check_points)}
      ]
    }
  end

  @doc """
  Creates a calibration check change function.

  ## Parameters
    - `metadata_field` - The metadata field name (default: :metadata)
    - `tolerance_field` - Field containing acceptable tolerance (default:
      :tolerance)

  ## Returns
  Function for calibration validation and recording.
  """
  @spec createcalibration_change(atom(), atom()) :: (Ash.Changeset.t(), map() ->
                                                       Ash.Changeset.t())
  def createcalibration_change(metadata_field, tolerance_field \\ :tolerance) do
    fn changeset, context ->
      expected_value = Ash.Changeset.get_argument(changeset, :expected_value)
      actual_value = Ash.Changeset.get_argument(changeset, :actual_value)

      tolerance =
        Ash.Changeset.get_attribute(
          changeset,
          tolerance_field
        ) || 0.05

      # Calculate deviation
      deviation = abs(actual_value - expected_value) / expected_value
      within_tolerance = deviation <= tolerance

      calibration_data = %{
        "expected_value" => expected_value,
        "actual_value" => actual_value,
        "deviation" => deviation,
        "tolerance" => tolerance,
        "within_tolerance" => within_tolerance,
        "calibrated_at" => DateTime.utc_now(),
        "calibrated_by" => get_actor_id(context)
      }

      metadata = Ash.Changeset.get_attribute(changeset, metadata_field) || %{}

      # Add to calibration history
      calibration_history = Map.get(metadata, "calibration_history", [])
      updated_history = [calibration_data | calibration_history]

      updated_metadata =
        metadata
        |> Map.put("calibration_data", calibration_data)
        |> Map.put("calibration_history", updated_history)
        |> Map.put("last_calibration_at", DateTime.utc_now())
        |> Map.put("calibration_status", if(within_tolerance, do: "passed", else: "failed"))

      Ash.Changeset.force_change_attribute(
        changeset,
        metadata_field,
        updated_metadata
      )
    end
  end

  @doc """
  Validates inspection _requirements are met.

  ## Parameters
    - `resource` - The resource to validate
    - `_required_inspections` - List of _required inspection types

  ## Returns
    - `{:ok, resource}` if all inspections are current
    - `{:error, missing_inspections}` if inspections are missing or expired
  """
  @spec validate_inspection_requirements(any(), list(String.t())) ::
          {:ok, any()} | {:error, list(String.t())}
  @spec validate_inspection_requirements(any(), any()) :: any()
  def validate_inspection_requirements(resource, required_inspections) do
    metadata = Map.get(resource, :metadata, %{})
    inspection_history = Map.get(metadata, "inspection_history", [])

    missing_inspections =
      Enum.filter(
        required_inspections,
        fn inspection_type ->
          not inspection_current?(
            inspection_history,
            inspection_type
          )
        end
      )

    case missing_inspections do
      [] -> {:ok, resource}
      missing -> {:error, missing}
    end
  end

  @doc """
  Gets the latest inspection result for a specific type.

  ## Parameters
    - `metadata` - The metadata map
    - `inspection_type` - Type of inspection to find

  ## Returns
    - `{:ok, inspection_data}` if found
    - `{:error, :not_found}` if not found
  """
  @spec find_inspection_by_type(
          map(),
          String.t()
        ) :: {:ok, map()} | {:error, :not_found}
  @spec find_inspection_by_type(term(), term()) :: term()
  def find_inspection_by_type(metadata, inspection_type) do
    inspection_history = Map.get(metadata, "inspection_history", [])

    case Enum.find(inspection_history, fn inspection ->
           Map.get(inspection, "type") == inspection_type
         end) do
      nil -> {:error, :not_found}
      inspection -> {:ok, inspection}
    end
  end

  @doc """
  Calculates inspection compliance percentage.

  ## Parameters
    - `metadata` - The metadata map
    - `_required_inspections` - List of _required inspection types
    - `validity_days` - How many days inspections are valid (default: 365)

  ## Returns
  Compliance percentage as float (0.0 to 1.0).
  """
  @spec calculate_inspection_compliance(map(), list(String.t()), integer()) :: float()
  def calculate_inspection_compliance(metadata, required_inspections, validity_days \\ 365) do
    inspection_history = Map.get(metadata, "inspection_history", [])

    cutoff_date =
      DateTime.utc_now()
      |> DateTime.add(-validity_days, :day)

    current_inspections =
      Enum.count(
        required_inspections,
        fn inspection_type ->
          inspection_current_since?(
            inspection_history,
            inspection_type,
            cutoff_date
          )
        end
      )

    case length(required_inspections) do
      0 -> 1.0
      total -> current_inspections / total
    end
  end

  @doc """
  Generates inspection schedule based on f_requency _requirements.

  ## Parameters
    - `start_date` - Start date for schedule
    - `end_date` - End date for schedule
    - `inspection_f_requency` - How often to inspect (:daily,
      :weekly, :monthly, :quarterly, :annual)
    - `inspection_type` - Type of inspection

  ## Returns
  List of scheduled inspection dates.
  """
  def generateinspection_schedule(start_date, end_date, inspection_f_requency, inspection_type) do
    interval_days =
      case inspection_f_requency do
        :daily -> 1
        :weekly -> 7
        :monthly -> 30
        :quarterly -> 90
        :annual -> 365
        _ -> 30
      end

    start_date
    |> Stream.iterate(&Date.add(&1, interval_days))
    |> Stream.take_while(&(Date.compare(&1, end_date) != :gt))
    |> Enum.map(fn due_date ->
      %{
        due_date: due_date,
        inspection_type: inspection_type,
        f_requency: inspection_f_requency,
        status: "scheduled"
      }
    end)
  end

  @doc """
  Creates an inspection report summary.

  ## Parameters
    - `resources` - List of resources to analyze
    - `inspection_types` - Types of inspections to include

  ## Returns
  Map with inspection statistics and compliance data.
  """
  @spec create_inspection_report(list(), list(String.t())) :: map()
  def create_inspection_report(resources, inspection_types) do
    total_resources = length(resources)

    inspection_stats =
      Enum.map(
        inspection_types,
        fn inspection_type ->
          compliant_count =
            Enum.count(
              resources,
              fn resource ->
                metadata =
                  Map.get(
                    resource,
                    :metadata,
                    %{}
                  )

                inspection_history = Map.get(metadata, "inspection_history", [])
                inspection_current?(inspection_history, inspection_type)
              end
            )

          compliance_rate =
            if total_resources > 0, do: compliant_count / total_resources, else: 0.0

          %{
            inspection_type: inspection_type,
            compliant_count: compliant_count,
            total_count: total_resources,
            compliance_rate: compliance_rate
          }
        end
      )

    overall_compliance =
      if total_resources > 0 do
        Enum.sum(Enum.map(inspection_stats, & &1.compliance_rate)) / length(inspection_stats)
      else
        0.0
      end

    %{
      total_resources: total_resources,
      inspection_types: inspection_stats,
      overall_compliance_rate: overall_compliance,
      generated_at: DateTime.utc_now()
    }
  end

  # Private helper functions

  @spec get_actor_id(map()) :: term()
  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{actor: actor}) when is_map(actor), do: Map.get(actor, :id)
  defp get_actor_id(_), do: nil

  @spec update_inspection_status(term(), term()) :: term()
  defp update_inspection_status(changeset, passed?) do
    case passed? do
      true ->
        Ash.Changeset.change_attribute(changeset, :status, :completed)

      false ->
        Ash.Changeset.change_attribute(changeset, :status, :failed)
    end
  end

  @spec create_quality_check_change(term()) :: term()
  defp create_quality_check_change(check_points) do
    fn changeset, context ->
      inspector = Ash.Changeset.get_argument(changeset, :inspector)
      overall_passed = Ash.Changeset.get_argument(changeset, :overall_passed)

      check_results =
        Enum.map(
          check_points,
          fn point ->
            arg_name = String.to_atom("#{point}passed")
            passed = Ash.Changeset.get_argument(changeset, arg_name)

            %{
              "check_point" => point,
              "passed" => passed,
              "checked_at" => DateTime.utc_now()
            }
          end
        )

      quality_check_data = %{
        "inspector" => inspector,
        "overall_passed" => overall_passed,
        "check_results" => check_results,
        "checked_at" => DateTime.utc_now(),
        "checked_by" => get_actor_id(context)
      }

      metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}

      # Add to quality check history
      quality_history = Map.get(metadata, "quality_check_history", [])
      updated_history = [quality_check_data | quality_history]

      updated_metadata =
        metadata
        |> Map.put("quality_check_data", quality_check_data)
        |> Map.put("quality_check_history", updated_history)
        |> Map.put("last_quality_check_at", DateTime.utc_now())

      Ash.Changeset.force_change_attribute(changeset, :metadata, updated_metadata)
    end
  end

  defp inspection_current?(inspection_history, inspection_type, cutoff_date \\ nil) do
    cutoff =
      cutoff_date ||
        DateTime.utc_now()
        |> DateTime.add(-365, :day)

    inspection_current_since?(inspection_history, inspection_type, cutoff)
  end

  defp inspection_current_since?(inspection_history, inspection_type, cutoff_date) do
    Enum.any?(inspection_history, fn inspection ->
      type_match = Map.get(inspection, "type") == inspection_type

      case Map.get(inspection, "inspected_at") do
        nil ->
          false

        inspected_at_str when is_binary(inspected_at_str) ->
          case DateTime.from_iso8601(inspected_at_str) do
            {:ok, inspected_at, _} ->
              type_match and DateTime.compare(inspected_at, cutoff_date) == :gt

            _ ->
              false
          end

        %DateTime{} = inspected_at ->
          type_match and DateTime.compare(inspected_at, cutoff_date) == :gt

        _ ->
          false
      end
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
