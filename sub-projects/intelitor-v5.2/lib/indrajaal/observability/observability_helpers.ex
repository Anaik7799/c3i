defmodule Indrajaal.Observability.ObservabilityHelpers do
  @moduledoc """
  Claude Agent Generated: EP-084 Behaviour Definition
  Purpose: Resolve 400+ behaviour compliance warnings
  Created: 2025-09-04T13:18:45.850257Z

  This behaviour defines the standard interface for observability helper modules
  across the Indrajaal system. All observability modules should implement this
  behaviour to ensure consistent telemetry and monitoring capabilities.
  """

  @doc """
  Sets up the observability helper with initial configuration.
  This callback should initialize telemetry handlers, configure metrics collection,
  and prepare the module for operation.
  """
  @callback setup() :: :ok | {:error, term()}

  @doc """
  Handles telemetry __events received by the observability helper.
  This callback processes incoming telemetry __events and performs appropriate
  actions such as metric recording, alerting, or data aggregation.
  """
  @callback handle_event(__event_name :: term(), measurements :: term(), metadata :: term()) ::
              :ok

  @doc """
  Retrieves current metrics collected by the observability helper.
  This callback returns a map of metrics data that can be used for monitoring,
  dashboards, or further analysis.
  """
  @callback get_metrics() :: {:ok, map()} | {:error, term()}

  @doc """
  Records a specific metric with the given name and value.
  This callback allows direct metric recording for custom measurements
  not covered by automatic telemetry __event handling.
  """
  @callback record_metric(metric_name :: atom(), value :: term()) :: :ok

  @doc """
  Configures the observability helper with runtime options.
  This callback allows dynamic reconfiguration of the helper's behavior,
  such as changing sampling rates, enabling/disabling features, etc.
  """
  @callback configure(options :: keyword()) :: :ok | {:error, term()}

  @doc """
  Retrieves the current configuration of the observability helper.
  This callback returns the current configuration state for inspection
  or debugging purposes.
  """
  @callback get_configuration() :: {:ok, keyword()} | {:error, term()}

  @doc """
  Performs cleanup and shutdown procedures for the observability helper.
  This callback should properly close connections, flush pending data,
  and release any held resources.
  """
  @callback shutdown() :: :ok | {:error, term()}
end
