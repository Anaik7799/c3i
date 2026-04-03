defmodule Indrajaal.Notifications.Backends.Slack do
  @moduledoc """
  Slack webhook notification backend.

  Provides real Slack notification delivery via incoming webhooks.

  STAMP Compliance:
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels

  Reference: CLAUDE.md §35 (Extended Command Reference)
  """

  require Logger

  alias Indrajaal.Notifications.Backends.NotificationHelpers

  @behaviour Indrajaal.Notifications.Backends.Behaviour

  @default_timeout 10_000
  @retry_attempts 3
  @retry_delay 1_000

  @type slack_message :: %{
          text: String.t(),
          channel: String.t() | nil,
          username: String.t() | nil,
          icon_emoji: String.t() | nil,
          attachments: list(map()) | nil,
          blocks: list(map()) | nil
        }

  @type delivery_result :: {:ok, map()} | {:error, term()}

  @doc """
  Delivers a notification to Slack via webhook.

  ## Parameters
    - params: Map containing :webhook_url and :message (string or structured message)
    - opts: Optional parameters (channel override, username, etc.)

  ## Returns
    - {:ok, %{status: :delivered, response: response}}
    - {:error, reason}
  """
  @impl true
  @spec deliver(map(), keyword()) :: delivery_result()
  def deliver(params, opts \\ [])

  def deliver(%{webhook_url: webhook_url, message: message}, opts) when is_binary(message) do
    deliver(%{webhook_url: webhook_url, message: %{text: message}}, opts)
  end

  def deliver(%{webhook_url: webhook_url, message: message}, opts) when is_map(message) do
    payload = build_payload(message, opts)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retry_count = Keyword.get(opts, :retry_count, @retry_attempts)

    emit_telemetry(:start, %{channel: :slack})

    result = send_with_retry(webhook_url, payload, timeout, retry_count)

    case result do
      {:ok, _} = success ->
        emit_telemetry(:success, %{channel: :slack})
        success

      {:error, _} = error ->
        emit_telemetry(:failure, %{channel: :slack, error: error})
        error
    end
  end

  def deliver(params, _opts) do
    missing_fields =
      [:webhook_url, :message]
      |> Enum.filter(fn field -> not Map.has_key?(params, field) end)

    {:error, {:missing_required_fields, missing_fields}}
  end

  @doc """
  Sends an alert notification formatted for Slack.

  ## Parameters
    - webhook_url: The Slack incoming webhook URL
    - alert: Alert data map with severity, title, description, etc.
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, response: response}}
    - {:error, reason}
  """
  @spec send_alert(String.t(), map(), keyword()) :: delivery_result()
  def send_alert(webhook_url, alert, opts \\ []) do
    message = format_alert_message(alert)
    deliver(%{webhook_url: webhook_url, message: message}, opts)
  end

  @doc """
  Validates a Slack webhook URL format.
  """
  @spec valid_webhook_url?(String.t()) :: boolean()
  def valid_webhook_url?(url) when is_binary(url) do
    String.starts_with?(url, "https://hooks.slack.com/services/")
  end

  def valid_webhook_url?(_), do: false

  # Private Functions

  defp build_payload(message, opts) do
    base_payload = %{
      text: Map.get(message, :text, ""),
      username: Keyword.get(opts, :username, "Indrajaal Alerts"),
      icon_emoji: Keyword.get(opts, :icon_emoji, ":warning:")
    }

    base_payload
    |> maybe_add_channel(Keyword.get(opts, :channel))
    |> maybe_add_attachments(Map.get(message, :attachments))
    |> maybe_add_blocks(Map.get(message, :blocks))
  end

  defp maybe_add_channel(payload, nil), do: payload
  defp maybe_add_channel(payload, channel), do: Map.put(payload, :channel, channel)

  defp maybe_add_attachments(payload, nil), do: payload
  defp maybe_add_attachments(payload, []), do: payload

  defp maybe_add_attachments(payload, attachments),
    do: Map.put(payload, :attachments, attachments)

  defp maybe_add_blocks(payload, nil), do: payload
  defp maybe_add_blocks(payload, []), do: payload
  defp maybe_add_blocks(payload, blocks), do: Map.put(payload, :blocks, blocks)

  defp format_alert_message(alert) do
    %{
      severity: severity,
      title: title,
      description: description,
      source: source,
      timestamp: timestamp
    } = NotificationHelpers.extract_alert_fields(alert)

    color = NotificationHelpers.severity_to_slack_color(severity)
    emoji = NotificationHelpers.severity_to_slack_emoji(severity)

    %{
      text: "#{emoji} *#{title}*",
      attachments: [
        %{
          color: color,
          fields: [
            %{title: "Severity", value: to_string(severity), short: true},
            %{title: "Source", value: source, short: true},
            %{title: "Description", value: description, short: false},
            %{
              title: "Timestamp",
              value: NotificationHelpers.format_timestamp(timestamp),
              short: true
            }
          ],
          footer: "Indrajaal Alert System",
          ts: DateTime.to_unix(timestamp)
        }
      ]
    }
  end

  defp send_with_retry(webhook_url, payload, timeout, attempts_remaining) do
    case do_send(webhook_url, payload, timeout) do
      {:ok, response} ->
        {:ok, %{status: :delivered, response: response}}

      {:error, reason} when attempts_remaining > 1 ->
        Logger.warning("Slack notification failed, retrying",
          reason: inspect(reason),
          attempts_remaining: attempts_remaining - 1
        )

        Process.sleep(@retry_delay)
        send_with_retry(webhook_url, payload, timeout, attempts_remaining - 1)

      {:error, reason} ->
        Logger.error("Slack notification failed after all retries", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp do_send(webhook_url, payload, timeout) do
    case Req.post(webhook_url,
           json: payload,
           receive_timeout: timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, %{status_code: status}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp emit_telemetry(event, metadata) do
    NotificationHelpers.emit_telemetry(event, :slack, metadata)
  end
end
