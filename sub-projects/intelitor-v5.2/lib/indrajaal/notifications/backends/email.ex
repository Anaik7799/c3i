defmodule Indrajaal.Notifications.Backends.Email do
  @moduledoc """
  Email notification backend using Swoosh.

  Provides real email notification delivery via configured SMTP/API providers.

  STAMP Compliance:
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels
  - SC-SEC-045: Secure email transmission

  Reference: CLAUDE.md §35 (Extended Command Reference)
  """

  require Logger

  alias Indrajaal.Notifications.Backends.NotificationHelpers

  @behaviour Indrajaal.Notifications.Backends.Behaviour

  import Swoosh.Email

  @default_from {"Indrajaal Alerts", "alerts@intelitor.local"}

  @type email_params :: %{
          to: String.t() | list(String.t()),
          subject: String.t(),
          body: String.t(),
          html_body: String.t() | nil,
          from: {String.t(), String.t()} | nil,
          cc: list(String.t()) | nil,
          bcc: list(String.t()) | nil,
          attachments: list(map()) | nil
        }

  @type delivery_result :: {:ok, map()} | {:error, term()}

  @doc """
  Delivers an email notification.

  ## Parameters
    - params: Email parameters (to, subject, body, etc.)
    - opts: Optional parameters (mailer config, priority, etc.)

  ## Returns
    - {:ok, %{status: :delivered, message_id: id}}
    - {:error, reason}
  """
  @impl true
  @spec deliver(map(), keyword()) :: delivery_result()
  def deliver(params, opts \\ [])

  def deliver(%{to: to, subject: _subject, body: _body} = params, opts) do
    emit_telemetry(:start, %{channel: :email})

    email = build_email(params, opts)
    mailer = get_mailer(opts)

    result = deliver_email(email, mailer)

    case result do
      {:ok, _} = success ->
        emit_telemetry(:success, %{channel: :email, to: normalize_recipients(to)})
        success

      {:error, _} = error ->
        emit_telemetry(:failure, %{channel: :email, error: error})
        error
    end
  end

  def deliver(params, _opts) do
    missing_fields =
      [:to, :subject, :body]
      |> Enum.filter(fn field -> not Map.has_key?(params, field) end)

    {:error, {:missing_required_fields, missing_fields}}
  end

  @doc """
  Sends an alert notification formatted as email.

  ## Parameters
    - recipients: Email address(es) to send to
    - alert: Alert data map with severity, title, description, etc.
    - opts: Optional parameters

  ## Returns
    - {:ok, %{status: :delivered, message_id: id}}
    - {:error, reason}
  """
  @spec send_alert(String.t() | list(String.t()), map(), keyword()) :: delivery_result()
  def send_alert(recipients, alert, opts \\ []) do
    {subject, body, html_body} = format_alert_email(alert)

    params = %{
      to: recipients,
      subject: subject,
      body: body,
      html_body: html_body
    }

    deliver(params, opts)
  end

  @doc """
  Validates an email address format.
  """
  @spec valid_email?(String.t()) :: boolean()
  def valid_email?(email) when is_binary(email) do
    # Basic email validation regex
    Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email)
  end

  def valid_email?(_), do: false

  # Private Functions

  defp build_email(params, opts) do
    from = Map.get(params, :from) || Keyword.get(opts, :from, @default_from)
    to = normalize_recipients(Map.get(params, :to))
    subject = Map.get(params, :subject, "")
    body = Map.get(params, :body, "")
    html_body = Map.get(params, :html_body)

    email =
      new()
      |> from(from)
      |> to(to)
      |> subject(subject)
      |> text_body(body)

    email = if html_body, do: html_body(email, html_body), else: email

    email
    |> maybe_add_cc(Map.get(params, :cc))
    |> maybe_add_bcc(Map.get(params, :bcc))
    |> maybe_add_attachments(Map.get(params, :attachments))
    |> maybe_add_headers(Keyword.get(opts, :headers, []))
  end

  defp normalize_recipients(recipients) when is_list(recipients), do: recipients
  defp normalize_recipients(recipient) when is_binary(recipient), do: [recipient]
  defp normalize_recipients(_), do: []

  defp maybe_add_cc(email, nil), do: email
  defp maybe_add_cc(email, []), do: email
  defp maybe_add_cc(email, cc_list), do: cc(email, cc_list)

  defp maybe_add_bcc(email, nil), do: email
  defp maybe_add_bcc(email, []), do: email
  defp maybe_add_bcc(email, bcc_list), do: bcc(email, bcc_list)

  defp maybe_add_attachments(email, nil), do: email
  defp maybe_add_attachments(email, []), do: email

  defp maybe_add_attachments(email, attachments) do
    Enum.reduce(attachments, email, fn att, acc ->
      attachment(acc, Swoosh.Attachment.new(att.path, filename: att.filename))
    end)
  end

  defp maybe_add_headers(email, []), do: email

  defp maybe_add_headers(email, headers) do
    Enum.reduce(headers, email, fn {key, value}, acc ->
      header(acc, key, value)
    end)
  end

  defp format_alert_email(alert) do
    %{
      severity: severity,
      title: title,
      description: description,
      source: source,
      timestamp: timestamp,
      details: details
    } = NotificationHelpers.extract_alert_fields(alert)

    subject = "[#{String.upcase(to_string(severity))}] #{title}"
    formatted_time = NotificationHelpers.format_timestamp(timestamp)

    text_body = """
    INTELITOR ALERT NOTIFICATION
    =============================

    Severity: #{severity}
    Title: #{title}
    Source: #{source}
    Time: #{formatted_time}

    Description:
    #{description}

    #{format_details_text(details)}

    ---
    This is an automated message from Indrajaal Alert System.
    """

    html_body = """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; }
        .header { background: #{NotificationHelpers.severity_to_email_color(severity)}; color: white; padding: 20px; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { padding: 20px; }
        .field { margin-bottom: 15px; }
        .field-label { font-weight: bold; color: #666; }
        .field-value { margin-top: 5px; }
        .details { background: #f9f9f9; padding: 15px; border-radius: 4px; margin-top: 20px; }
        .footer { padding: 15px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>#{NotificationHelpers.severity_to_unicode_emoji(severity)} #{title}</h1>
        </div>
        <div class="content">
          <div class="field">
            <div class="field-label">Severity</div>
            <div class="field-value">#{severity}</div>
          </div>
          <div class="field">
            <div class="field-label">Source</div>
            <div class="field-value">#{source}</div>
          </div>
          <div class="field">
            <div class="field-label">Time</div>
            <div class="field-value">#{formatted_time}</div>
          </div>
          <div class="field">
            <div class="field-label">Description</div>
            <div class="field-value">#{description}</div>
          </div>
          #{format_details_html(details)}
        </div>
        <div class="footer">
          Indrajaal Alert System | Automated Notification
        </div>
      </div>
    </body>
    </html>
    """

    {subject, text_body, html_body}
  end

  defp format_details_text(details) when details == %{}, do: ""

  defp format_details_text(details) do
    detail_lines =
      details
      |> Enum.map_join("\n", fn {key, value} -> "  #{key}: #{inspect(value)}" end)

    """
    Additional Details:
    #{detail_lines}
    """
  end

  defp format_details_html(details) when details == %{}, do: ""

  defp format_details_html(details) do
    detail_rows =
      details
      |> Enum.map_join("\n", fn {key, value} ->
        "<div><strong>#{key}:</strong> #{inspect(value)}</div>"
      end)

    """
    <div class="details">
      <div class="field-label">Additional Details</div>
      #{detail_rows}
    </div>
    """
  end

  defp get_mailer(opts) do
    Keyword.get(opts, :mailer, Indrajaal.Mailer)
  end

  defp deliver_email(email, mailer) do
    # Check if we're in test/demo mode
    if Application.get_env(:swoosh, :api_client) == false do
      # Local/test mode - log and return success
      Logger.info("Email notification (local mode)",
        to: email.to,
        subject: email.subject
      )

      {:ok, %{status: :delivered, message_id: "local-#{System.unique_integer([:positive])}"}}
    else
      # Production mode - actually deliver
      case mailer.deliver(email) do
        {:ok, result} ->
          {:ok, %{status: :delivered, message_id: inspect(result)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp emit_telemetry(event, metadata) do
    NotificationHelpers.emit_telemetry(event, :email, metadata)
  end
end
