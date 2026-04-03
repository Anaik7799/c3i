defmodule Indrajaal.Errors.Invalid do
  @moduledoc """
  Validation and input - related errors.
  """
  defmodule ValidationFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :value, :constraint, :message],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, constraint: constraint, message: msg}) do
      "Validation failed for #{field} (#{constraint}): #{msg}"
    end
  end

  defmodule FormatError do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :value, :expected_format, :examples],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, expectedformat: format}) do
      "Invalid format for #{field}: expected #{format}"
    end
  end

  defmodule RequiredFieldMissing do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :resource, :action],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, resource: resource, action: action}) do
      "Required field '#{field}' missing for #{action} on #{resource}"
    end
  end

  defmodule InvalidRange do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :value, :min, :max],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, value: value, min: min, max: max}) do
      "Invalid range for #{field}: #{value} not in [#{min}, #{max}]"
    end
  end

  defmodule InvalidEnum do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :value, :valid_values],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, value: value, validvalues: valid}) do
      "Invalid enum value for #{field}: #{value} not in #{inspect(valid)}"
    end
  end

  defmodule DuplicateValue do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :value, :resource, :existing_id],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, value: value, resource: resource}) do
      "Duplicate value for #{field} in #{resource}: #{value} already exists"
    end
  end

  defmodule ReferenceNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:field, :referenced_resource, :referenced_id, :resource],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{field: field, referencedresource: ref_resource, referenced_id: ref_id}) do
      "Reference not found for #{field}: #{ref_resource} with id #{ref_id} does not exist"
    end
  end

  defmodule InvalidDateRange do
    @moduledoc false
    use Splode.Error,
      fields: [:start_field, :end_field, :start_date, :end_date],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{startfield: start_field, end_field: end_field}) do
      "Invalid date range: #{start_field} must be before #{end_field}"
    end
  end

  defmodule InvalidCredentials do
    @moduledoc false
    use Splode.Error,
      fields: [:credential_type, :identifier, :reason],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{credentialtype: type, identifier: id, reason: reason}) do
      "Invalid #{type} credentials for #{id}: #{reason}"
    end
  end

  defmodule TokenExpired do
    @moduledoc false
    use Splode.Error,
      fields: [:token_type, :token_id, :expired_at, :current_time],
      class: :invalid

    @spec message(map()) :: String.t()
    def message(%{tokentype: type, expiredat: expired}) do
      "#{type} token expired at #{expired}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
