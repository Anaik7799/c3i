defmodule Indrajaal.Telemetry.TelemetryHandler do
  @moduledoc """
  Claude Agent Generated: EP-084 TelemetryHandler Behaviour Definition
  Purpose: Resolve behaviour compliance warnings
  Created: 2025-09-04T13:18:45.856954Z
  """

  @callback handle_telemetry_event(__event :: term(), measurements :: term(), meta_data :: term()) ::
              :ok
  @callback setup_telemetry(config :: keyword()) :: :ok | {:error, term()}
  @callback shutdown_telemetry() :: :ok
end
