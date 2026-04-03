defmodule Indrajaal.Notifications.Backends.OpsGenie do
  @moduledoc """
  OpsGenie notification backend.

  Provides real OpsGenie alert delivery via Alert API v2.

  STAMP Compliance:
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels
  - SC-EMR-059: Escalation support

  Reference: CLAUDE.md §35 (Extended Command Reference)
  """

  require Logger

  @behaviour Indrajaal.Notifications.Backends.Behaviour

  @alerts_api_url "https://api.opsgenie.com/v2/alerts"
  @default_timeout 10_000
  @retry_attempts 3
  @retry_delay 1_000

  @type priority :: :P1 | :P2 | :P3 | :P4 | :P5

  @type alert_params :: %{
          api_key: String.t(),
          message: String.t(),
          alias: String.t() | nil,
          description: String.t() | nil,
          responders: list(map()) | nil,
          visible_to: list(map()) | nil,
          actions: list(String.t()) | nil,
          tags: list(String.t()) | nil,
          details: map() | nil,
          entity: String.t() | nil,
          source: String.t() | nil,
          priority: priority() | nil,
          user: String.t() | nil,
          note: String.t() | nil
        }

  @type delivery_result :: {:ok, map()} | {:error, term()}

  @doc """
  Delivers an alert to OpsGenie.

  ## Parameters
    - params: Alert parameters including api_key, message, priority, etc.
    - opts: Optional parameters (timeout, retry settings, etc.)

  ## Returns
    - {:ok, %{status: :delivered, request_id: id, alert_id: id}}
    - {:error, reason}
  """
  @impl true
  @spec deliver(map(), keyword()) :: delivery_result()
  def deliver(params, opts \\ [])

  def deliver(%{api_key: api_key, message: _message} = params, opts) do
    emit_telemetry(:start, %{channel: :opsgenie})

    payload = build_payload(params)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retry_count = Keyword.get(opts, :retry_count, @retry_attempts)

    result = send_with_retry(api_key, payload, timeout, retry_count)

    case result do
      {:ok, _} = success ->
        emit_telemetry(:success, %{channel: :opsgenie})
        success

      {:error, _} = error ->
        emit_telemetry(:failure, %{channel: :opsgenie, error: error})
        error
    end
  end

  def deliver(params, _opts) do
    missing_fields =
      [:api_key, :message]
      |> Enum.filter(fn field -> not Map.has_key?(params, field) end)

    {:error, {:missing_required_fields, missing_fields}}
  end

  @doc """
  Creates a new alert in OpsGenie from an Indrajaal alert.

  ## Parameters
    - api_key: OpsGenie API key
    - alert: Alert data map with severity, title, description, etc.
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, request_id: id, alert_id: id}}
    - {:error, reason}
  """
  @spec create_alert(String.t(), map(), keyword()) :: delivery_result()
  def create_alert(api_key, alert, opts \\ []) do
    params = %{
      api_key: api_key,
      message: Map.get(alert, :title, "Alert"),
      alias: Map.get(alert, :alias) || generate_alias(alert),
      description: Map.get(alert, :description, ""),
      source: Map.get(alert, :source, "intelitor"),
      priority: map_severity_to_priority(Map.get(alert, :severity, :info)),
      tags: Map.get(alert, :tags, ["intelitor"]),
      details: %{
        severity: to_string(Map.get(alert, :severity, :info)),
        source_system: "intelitor",
        timestamp: DateTime.to_iso8601(Map.get(alert, :timestamp, DateTime.utc_now())),
        additional_details: Map.get(alert, :details, %{})
      },
      entity: Map.get(alert, :entity),
      responders: Map.get(alert, :responders),
      note: "Created by Indrajaal Alert System"
    }

    deliver(params, opts)
  end

  @doc """
  Acknowledges an existing alert in OpsGenie.

  ## Parameters
    - api_key: OpsGenie API key
    - alert_alias: The alias of the alert to acknowledge
    - opts: Optional parameters (user, note, etc.)

  ## Returns
    - {:ok, %{status: :acknowledged, request_id: id}}
    - {:error, reason}
  """
  @spec acknowledge_alert(String.t(), String.t(), keyword()) :: delivery_result()
  def acknowledge_alert(api_key, alert_alias, opts \\ []) do
    url = "#{@alerts_api_url}/#{alert_alias}/acknowledge?identifierType=alias"
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    payload = %{
      user: Keyword.get(opts, :user, "intelitor"),
      note: Keyword.get(opts, :note, "Acknowledged via Indrajaal")
    }

    case do_post(url, api_key, payload, timeout) do
      {:ok, response} ->
        {:ok, %{status: :acknowledged, request_id: Map.get(response, "requestId")}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Closes an existing alert in OpsGenie.

  ## Parameters
    - api_key: OpsGenie API key
    - alert_alias: The alias of the alert to close
    - opts: Optional parameters (user, note, etc.)

  ## Returns
    - {:ok, %{status: :closed, request_id: id}}
    - {:error, reason}
  """
  @spec close_alert(String.t(), String.t(), keyword()) :: delivery_result()
  def close_alert(api_key, alert_alias, opts \\ []) do
    url = "#{@alerts_api_url}/#{alert_alias}/close?identifierType=alias"
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    payload = %{
      user: Keyword.get(opts, :user, "intelitor"),
      note: Keyword.get(opts, :note, "Closed via Indrajaal")
    }

    case do_post(url, api_key, payload, timeout) do
      {:ok, response} ->
        {:ok, %{status: :closed, request_id: Map.get(response, "requestId")}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates an OpsGenie API key format.
  """
  @spec valid_api_key?(String.t()) :: boolean()
  def valid_api_key?(key) when is_binary(key) do
    # OpsGenie API keys are UUIDs (36 characters with hyphens)
    String.length(key) == 36 and
      Regex.match?(~r/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/, key)
  end

  def valid_api_key?(_), do: false

  # Private Functions

  defp build_payload(params) do
    %{
      message: Map.get(params, :message)
    }
    |> maybe_add_field(:alias, Map.get(params, :alias))
    |> maybe_add_field(:description, Map.get(params, :description))
    |> maybe_add_field(:responders, Map.get(params, :responders))
    |> maybe_add_field(:visibleTo, Map.get(params, :visible_to))
    |> maybe_add_field(:actions, Map.get(params, :actions))
    |> maybe_add_field(:tags, Map.get(params, :tags))
    |> maybe_add_field(:details, Map.get(params, :details))
    |> maybe_add_field(:entity, Map.get(params, :entity))
    |> maybe_add_field(:source, Map.get(params, :source))
    |> maybe_add_field(:priority, Map.get(params, :priority))
    |> maybe_add_field(:user, Map.get(params, :user))
    |> maybe_add_field(:note, Map.get(params, :note))
  end

  defp maybe_add_field(payload, _key, nil), do: payload
  defp maybe_add_field(payload, key, value), do: Map.put(payload, key, value)

  defp map_severity_to_priority(:critical), do: :P1
  defp map_severity_to_priority(:high), do: :P2
  defp map_severity_to_priority(:medium), do: :P3
  defp map_severity_to_priority(:low), do: :P4
  defp map_severity_to_priority(:info), do: :P5
  defp map_severity_to_priority(_), do: :P3

  defp generate_alias(alert) do
    source = Map.get(alert, :source, "intelitor")
    title = Map.get(alert, :title, "alert")
    timestamp = System.system_time(:second)

    "#{source}-#{String.replace(title, ~r/[^a-zA-Z0-9]/, "-")}-#{timestamp}"
    |> String.slice(0, 512)
  end

  defp send_with_retry(api_key, payload, timeout, attempts_remaining) do
    case do_post(@alerts_api_url, api_key, payload, timeout) do
      {:ok, response} ->
        {:ok,
         %{
           status: :delivered,
           request_id: Map.get(response, "requestId"),
           alert_id: get_in(response, ["data", "alertId"])
         }}

      {:error, reason} when attempts_remaining > 1 ->
        Logger.warning("OpsGenie notification failed, retrying",
          reason: inspect(reason),
          attempts_remaining: attempts_remaining - 1
        )

        Process.sleep(@retry_delay)
        send_with_retry(api_key, payload, timeout, attempts_remaining - 1)

      {:error, reason} ->
        Logger.error("OpsGenie notification failed after all retries", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp do_post(url, api_key, payload, timeout) do
    case Req.post(url,
           json: payload,
           headers: [
             {"Authorization", "GenieKey #{api_key}"},
             {"Content-Type", "application/json"}
           ],
           receive_timeout: timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: 429, body: body}} ->
        {:error, {:rate_limited, body}}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :notifications, :opsgenie, event],
      %{count: 1, timestamp: System.monotonic_time()},
      metadata
    )
  end
end
