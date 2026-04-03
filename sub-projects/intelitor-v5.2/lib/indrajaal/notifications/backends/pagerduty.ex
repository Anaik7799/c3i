defmodule Indrajaal.Notifications.Backends.PagerDuty do
  @moduledoc """
  PagerDuty notification backend.

  Provides real PagerDuty incident and event delivery via Events API v2.

  STAMP Compliance:
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels
  - SC-EMR-059: Escalation support

  Reference: CLAUDE.md §35 (Extended Command Reference)
  """

  require Logger

  @behaviour Indrajaal.Notifications.Backends.Behaviour

  @events_api_url "https://events.pagerduty.com/v2/enqueue"
  @default_timeout 10_000
  @retry_attempts 3
  @retry_delay 1_000

  @type event_action :: :trigger | :acknowledge | :resolve
  @type severity :: :critical | :error | :warning | :info

  @type event_params :: %{
          routing_key: String.t(),
          event_action: event_action(),
          dedup_key: String.t() | nil,
          summary: String.t(),
          source: String.t(),
          severity: severity(),
          timestamp: DateTime.t() | nil,
          component: String.t() | nil,
          group: String.t() | nil,
          class: String.t() | nil,
          custom_details: map() | nil
        }

  @type delivery_result :: {:ok, map()} | {:error, term()}

  @doc """
  Delivers an event to PagerDuty.

  ## Parameters
    - params: Event parameters including routing_key, summary, severity, etc.
    - opts: Optional parameters (timeout, retry settings, etc.)

  ## Returns
    - {:ok, %{status: :delivered, dedup_key: key}}
    - {:error, reason}
  """
  @impl true
  @spec deliver(map(), keyword()) :: delivery_result()
  def deliver(params, opts \\ [])

  def deliver(%{routing_key: _routing_key, summary: _summary} = params, opts) do
    emit_telemetry(:start, %{
      channel: :pagerduty,
      action: Map.get(params, :event_action, :trigger)
    })

    payload = build_payload(params)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retry_count = Keyword.get(opts, :retry_count, @retry_attempts)

    result = send_with_retry(payload, timeout, retry_count)

    case result do
      {:ok, _} = success ->
        emit_telemetry(:success, %{channel: :pagerduty})
        success

      {:error, _} = error ->
        emit_telemetry(:failure, %{channel: :pagerduty, error: error})
        error
    end
  end

  def deliver(params, _opts) do
    missing_fields =
      [:routing_key, :summary]
      |> Enum.filter(fn field -> not Map.has_key?(params, field) end)

    {:error, {:missing_required_fields, missing_fields}}
  end

  @doc """
  Triggers a new incident in PagerDuty.

  ## Parameters
    - routing_key: PagerDuty integration/routing key
    - alert: Alert data map with severity, title, description, etc.
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, dedup_key: key}}
    - {:error, reason}
  """
  @spec trigger_incident(String.t(), map(), keyword()) :: delivery_result()
  def trigger_incident(routing_key, alert, opts \\ []) do
    params = %{
      routing_key: routing_key,
      event_action: :trigger,
      dedup_key: Map.get(alert, :dedup_key) || generate_dedup_key(alert),
      summary: Map.get(alert, :title, "Alert"),
      source: Map.get(alert, :source, "intelitor"),
      severity: map_severity(Map.get(alert, :severity, :info)),
      timestamp: Map.get(alert, :timestamp, DateTime.utc_now()),
      component: Map.get(alert, :component),
      group: Map.get(alert, :group),
      class: Map.get(alert, :class),
      custom_details: %{
        description: Map.get(alert, :description, ""),
        details: Map.get(alert, :details, %{}),
        source_system: "intelitor"
      }
    }

    deliver(params, opts)
  end

  @doc """
  Acknowledges an existing incident in PagerDuty.

  ## Parameters
    - routing_key: PagerDuty integration/routing key
    - dedup_key: The dedup_key of the incident to acknowledge
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, dedup_key: key}}
    - {:error, reason}
  """
  @spec acknowledge_incident(String.t(), String.t(), keyword()) :: delivery_result()
  def acknowledge_incident(routing_key, dedup_key, opts \\ []) do
    params = %{
      routing_key: routing_key,
      event_action: :acknowledge,
      dedup_key: dedup_key,
      summary: "Incident acknowledged"
    }

    deliver(params, opts)
  end

  @doc """
  Resolves an existing incident in PagerDuty.

  ## Parameters
    - routing_key: PagerDuty integration/routing key
    - dedup_key: The dedup_key of the incident to resolve
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, dedup_key: key}}
    - {:error, reason}
  """
  @spec resolve_incident(String.t(), String.t(), keyword()) :: delivery_result()
  def resolve_incident(routing_key, dedup_key, opts \\ []) do
    params = %{
      routing_key: routing_key,
      event_action: :resolve,
      dedup_key: dedup_key,
      summary: "Incident resolved"
    }

    deliver(params, opts)
  end

  @doc """
  Validates a PagerDuty routing key format.
  """
  @spec valid_routing_key?(String.t()) :: boolean()
  def valid_routing_key?(key) when is_binary(key) do
    # PagerDuty routing keys are 32-character hex strings
    String.length(key) == 32 and Regex.match?(~r/^[a-f0-9]+$/, key)
  end

  def valid_routing_key?(_), do: false

  # Private Functions

  defp build_payload(params) do
    event_action = Map.get(params, :event_action, :trigger)
    dedup_key = Map.get(params, :dedup_key) || generate_dedup_key(params)

    base_payload = %{
      routing_key: Map.get(params, :routing_key),
      event_action: to_string(event_action),
      dedup_key: dedup_key
    }

    if event_action == :trigger do
      Map.put(base_payload, :payload, build_trigger_payload(params))
    else
      base_payload
    end
  end

  defp build_trigger_payload(params) do
    payload = %{
      summary: Map.get(params, :summary, "Alert"),
      source: Map.get(params, :source, "intelitor"),
      severity: to_string(Map.get(params, :severity, :warning))
    }

    payload
    |> maybe_add_timestamp(Map.get(params, :timestamp))
    |> maybe_add_component(Map.get(params, :component))
    |> maybe_add_group(Map.get(params, :group))
    |> maybe_add_class(Map.get(params, :class))
    |> maybe_add_custom_details(Map.get(params, :custom_details))
  end

  defp maybe_add_timestamp(payload, nil), do: payload

  defp maybe_add_timestamp(payload, %DateTime{} = dt) do
    Map.put(payload, :timestamp, DateTime.to_iso8601(dt))
  end

  defp maybe_add_timestamp(payload, ts) when is_binary(ts) do
    Map.put(payload, :timestamp, ts)
  end

  defp maybe_add_component(payload, nil), do: payload
  defp maybe_add_component(payload, component), do: Map.put(payload, :component, component)

  defp maybe_add_group(payload, nil), do: payload
  defp maybe_add_group(payload, group), do: Map.put(payload, :group, group)

  defp maybe_add_class(payload, nil), do: payload
  defp maybe_add_class(payload, class), do: Map.put(payload, :class, class)

  defp maybe_add_custom_details(payload, nil), do: payload
  defp maybe_add_custom_details(payload, details) when details == %{}, do: payload

  defp maybe_add_custom_details(payload, details) do
    Map.put(payload, :custom_details, details)
  end

  defp map_severity(:critical), do: :critical
  defp map_severity(:high), do: :error
  defp map_severity(:medium), do: :warning
  defp map_severity(:low), do: :info
  defp map_severity(:info), do: :info
  defp map_severity(other) when is_atom(other), do: other
  defp map_severity(_), do: :warning

  defp generate_dedup_key(params) do
    source = Map.get(params, :source, "intelitor")
    summary = Map.get(params, :summary, "")
    timestamp = System.system_time(:second)

    hash = :crypto.hash(:sha256, "#{source}:#{summary}:#{timestamp}")

    hash
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  defp send_with_retry(payload, timeout, attempts_remaining) do
    case do_send(payload, timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} when attempts_remaining > 1 ->
        Logger.warning("PagerDuty notification failed, retrying",
          reason: inspect(reason),
          attempts_remaining: attempts_remaining - 1
        )

        Process.sleep(@retry_delay)
        send_with_retry(payload, timeout, attempts_remaining - 1)

      {:error, reason} ->
        Logger.error("PagerDuty notification failed after all retries", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp do_send(payload, timeout) do
    case Req.post(@events_api_url,
           json: payload,
           receive_timeout: timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        dedup_key = Map.get(body, "dedup_key") || Map.get(payload, :dedup_key)
        {:ok, %{status: :delivered, dedup_key: dedup_key, response: body}}

      {:ok, %Req.Response{status: 429, body: body}} ->
        {:error, {:rate_limited, body}}

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
      [:indrajaal, :notifications, :pagerduty, event],
      %{count: 1, timestamp: System.monotonic_time()},
      metadata
    )
  end
end
