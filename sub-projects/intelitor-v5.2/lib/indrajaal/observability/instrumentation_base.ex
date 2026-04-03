defmodule Indrajaal.Observability.InstrumentationBase do
  @moduledoc """
  Base module for all domain instrumentation modules.

  Provides common functionality and imports for instrumentation modules including:
  - OpenTelemetry tracing and telemetry integration
  - Common helper functions for instrumentation
  - Error handling and safety constraints
  - Standardized setup and attachment patterns
  """

  @doc """
  When used, imports common functionality for instrumentation modules.
  """
  defmacro __using__(opts \\ []) do
    quote do
      # Import _required modules
      require Logger

      # Common aliases for all instrumentation modules
      alias Indrajaal.Observability.DualLogging, as: Logging
      alias Indrajaal.Observability.{Telemetry, Tracing}

      @behaviour Indrajaal.Observability.InstrumentationBase.Behaviour

      # Module attributes for configuration
      @otp_app unquote(opts[:otp_app] || :indrajaal)
      @domain unquote(
                opts[:domain] ||
                  __MODULE__ |> Module.split() |> Enum.at(-2, "unknown") |> String.downcase()
              )

      # Provide default implementations that can be overridden
      def setup do
        Logger.info("Setting up instrumentation for domain: #{@domain}")
        attach_handlers()
        :ok
      end

      def attach_handlers do
        Logger.debug("Attaching telemetry handlers for domain: #{@domain}")
        :ok
      end

      def domain, do: @domain
      def otp_app, do: @otp_app

      # Allow overriding the default implementations
      defoverridable setup: 0, attach_handlers: 0
    end
  end

  defmodule Behaviour do
    @moduledoc false
    @callback setup() :: :ok | {:error, term()}
    @callback attach_handlers() :: :ok | {:error, term()}
  end
end
