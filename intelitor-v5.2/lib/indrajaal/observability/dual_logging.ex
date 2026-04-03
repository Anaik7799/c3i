# Agent comment: Warning elimination for GA release - SOPv5.11 compliance
defmodule Indrajaal.Observability.DualLogging do
  @moduledoc """
  Dual logging system configuration for Indrajaal.

  MANDATORY: This module ensures ALL logs are sent to BOTH destinations:
  1. Terminal / Console - For immediate developer visibility
  2. SigNoz (via JSON) - For structured observability

  ## CRITICAL REQUIREMENT

  Every single log statement MUST appear in BOTH:
  - Developer's terminal (formatted for readability)
  - SigNoz platform (JSON structured for analysis)

  There are NO EXCEPTIONS to this rule. Both backends MUST receive
  identical log data with full metadata.
  """

  require Logger

  @doc """
  Validates that dual logging is properly configured and operational.

  This function MUST be called during application startup to ensure
  both logging backends are active and properly configured.

  Note: In Elixir 1.19+, the :console backend is enabled by default
  and doesn't need to be in the :backends configuration list.

  In test environment, dual logging is optional and only console logging
  is required for simplified test output.
  """
  @spec validate_dual_logging!() :: :ok
  def validate_dual_logging! do
    # Check for required backends
    backends = Application.get_env(:logger, :backends, [])
    env = Application.get_env(:indrajaal, :environment, Mix.env())

    # In Elixir 1.19+, console is default and may not be in :backends list
    # We validate console is available by checking if it's configured
    console_enabled =
      :console in backends or
        Application.get_env(:logger, :console) != nil

    unless console_enabled do
      raise """
      Console logging backend not found!
      Please ensure console logging is enabled.
      """
    end

    # LoggerJSON is only required in non-test environments
    # In test, we allow console-only logging for simplicity
    if env != :test do
      unless LoggerJSON in backends do
        raise """
        LoggerJSON backend not found!
        Please add LoggerJSON to the :logger, :backends configuration.
        This is required for dual logging (console + SigNoz) in #{env} environment.
        """
      end
    end

    json_enabled = LoggerJSON in backends

    Logger.info("Dual logging system validated successfully",
      environment: env,
      backends: backends,
      console_enabled: true,
      json_enabled: json_enabled,
      observability: if(json_enabled, do: "dual_mode", else: "console_only")
    )

    :ok
  end

  @doc """
  Configures console output format for optimal developer experience.
  """
  @spec configure_console_format(atom()) :: :ok
  def configure_console_format(format \\ :detailed) do
    console_format =
      case format do
        :minimal ->
          "$time [$level] $message\n"

        :detailed ->
          "$time $metadata[$level] $message\n"

        :verbose ->
          "$date $time [$level] $metadata\n$message\n"

        _ ->
          "$time $metadata[$level] $message\n"
      end

    Application.put_env(:logger, :console, format: console_format)

    Logger.info("Console format configured",
      format: format,
      pattern: console_format
    )

    :ok
  end

  @doc """
  Logs a domain - specific __event ensuring dual backend delivery.
  """
  @spec log_domain_event(atom(), atom(), map(), atom()) :: :ok
  def log_domain_event(domain, event, metadata \\ %{}, level \\ :info) do
    enhanced_metadata =
      Map.merge(metadata, %{
        domain: domain,
        __event: event,
        timestamp: DateTime.utc_now(),
        dual_logging: true
      })

    message = "[#{String.upcase(to_string(domain))}] #{event}"

    Logger.log(level, message, enhanced_metadata)

    :ok
  end

  @doc """
  Logs an important message with enhanced formatting.
  """
  @spec log_important(atom(), binary(), list()) :: :ok
  def log_important(level, message, metadata \\ []) do
    enhanced_metadata =
      Keyword.merge(metadata,
        importance: :high,
        dual_logging: true,
        timestamp: DateTime.utc_now()
      )

    formatted_message = "🚨 #{message} 🚨"

    Logger.log(level, formatted_message, enhanced_metadata)

    :ok
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetic feedback
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
