defmodule Indrajaal.Errors.Unknown do
  @moduledoc """
  Unknown and unexpected errors.
  """

  defmodule UnknownError do
    @moduledoc false
    use Splode.Error,
      fields: [:original_error, :__context, :stack_trace, :correlation_id],
      class: :unknown

    @spec message(map()) :: String.t()
    def message(%{originalerror: error, context: context}) do
      "Unknown error occurred: #{inspect(error)} in __context #{inspect(context)}"
    end

    @spec message(map()) :: String.t()
    def message(%{originalerror: error}) do
      "Unknown error occurred: #{inspect(error)}"
    end

    @spec message(map()) :: String.t()
    def message(_) do
      "An unknown error occurred"
    end
  end

  defmodule UnexpectedResponse do
    @moduledoc false
    use Splode.Error,
      fields: [:service, :expected_format, :actual_response, :operation],
      class: :unknown

    @spec message(map()) :: String.t()
    def message(%{service: service, operation: operation}) do
      "Unexpected response from #{service} during #{operation}"
    end
  end

  defmodule InternalInconsistency do
    @moduledoc false
    use Splode.Error,
      fields: [:description, :expected_state, :actual_state, :resource_type, :resource_id],
      class: :unknown

    @spec message(map()) :: String.t()
    def message(%{description: desc, resourcetype: type, resourceid: id}) do
      "Internal inconsistency detected in #{type} #{id}: #{desc}"
    end
  end

  defmodule UnhandledException do
    @moduledoc false
    use Splode.Error,
      fields: [:exception_type, :exception_message, :module, :function, :line],
      class: :unknown

    @spec message(map()) :: String.t()
    def message(%{exceptiontype: type, exceptionmessage: msg, module: mod, function: func}) do
      "Unhandled #{type} in #{mod}.#{func}: #{msg}"
    end
  end

  defmodule CorruptedData do
    @moduledoc false
    use Splode.Error,
      fields: [:__data_type, :corruption_type, :affected_records, :checksum_mismatch],
      class: :unknown

    @spec message(map()) :: String.t()
    def message(%{__datatype: type, corruptiontype: corruption}) do
      "Data corruption detected in #{type}: #{corruption}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
