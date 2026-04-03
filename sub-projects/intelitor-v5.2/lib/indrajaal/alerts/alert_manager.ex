defmodule Indrajaal.Alerts.AlertManager do
  @moduledoc """
  Claude Agent Generated: EP-084 AlertManager Behaviour Definition
  Purpose: Resolve behaviour compliance warnings
  Created: 2025-09-04T13:18:45.857943Z
  """

  @callback send_alert(alert_type :: atom(), alert_data :: term()) :: :ok | {:error, term()}
  @callback configure_alerts(config :: keyword()) :: :ok | {:error, term()}
  @callback get_alert_status() :: {:ok, map()} | {:error, term()}
end
