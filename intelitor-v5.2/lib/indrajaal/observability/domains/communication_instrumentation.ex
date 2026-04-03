defmodule Indrajaal.Observability.Domains.CommunicationInstrumentation do
  @moduledoc """
  require Logger
  Instrumentation for the Communication domain.

  Provides comprehensive telemetry,
    metrics, and tracing for notification delivery,
  messaging systems,
    email / SMS / push notifications, and communication preferences.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :communication

  # Telemetry event prefixes
  @notification_prefix [:indrajaal, :communication, :notification]
  @message_prefix [:indrajaal, :communication, :message]
  @channel_prefix [:indrajaal, :communication, :channel]
  @preference_prefix [:indrajaal, :communication, :preference]

  @doc """
  Attaches all communication telemetry handlers.
  """
  def setup do
    attach_notification_handlers()
    attach_message_handlers()
    attach_channel_handlers()
    attach_preference_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :communication, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :communication}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :communication, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :communication,
       notification_event_prefix: @notification_prefix,
       message_event_prefix: @message_prefix,
       channel_event_prefix: @channel_prefix,
       preference_event_prefix: @preference_prefix
     ]}
  end

  def shutdown do
    :ok
  end

  # Notification Handlers
  defp attach_notification_handlers do
    events = [
      @notification_prefix ++ [:send, :start],
      @notification_prefix ++ [:send, :stop],
      @notification_prefix ++ [:send, :exception],
      @notification_prefix ++ [:delivery, :confirmed],
      @notification_prefix ++ [:delivery, :failed],
      @notification_prefix ++ [:batch, :start],
      @notification_prefix ++ [:batch, :stop]
    ]

    :telemetry.attach_many(
      "communication - notification - handlers",
      events,
      &handle_notification_event/4,
      nil
    )
  end

  # Message Queue Handlers
  defp attach_message_handlers do
    events = [
      @message_prefix ++ [:queue, :enqueued],
      @message_prefix ++ [:queue, :processed],
      @message_prefix ++ [:queue, :failed],
      @message_prefix ++ [:retry, :attempted],
      @message_prefix ++ [:dlq, :moved]
    ]

    :telemetry.attach_many(
      "communication - message - handlers",
      events,
      &handle_message_event/4,
      nil
    )
  end

  # Channel - Specific Handlers
  defp attach_channel_handlers do
    events = [
      @channel_prefix ++ [:email, :sent],
      @channel_prefix ++ [:email, :bounced],
      @channel_prefix ++ [:sms, :sent],
      @channel_prefix ++ [:sms, :delivered],
      @channel_prefix ++ [:push, :sent],
      @channel_prefix ++ [:push, :received],
      @channel_prefix ++ [:webhook, :triggered]
    ]

    :telemetry.attach_many(
      "communication - channel - handlers",
      events,
      &handle_channel_event/4,
      nil
    )
  end

  # Preference Management Handlers
  defp attach_preference_handlers do
    events = [
      @preference_prefix ++ [:updated],
      @preference_prefix ++ [:opt_out],
      @preference_prefix ++ [:opt_in],
      @preference_prefix ++ [:compliance, :checked]
    ]

    :telemetry.attach_many(
      "communication - preference - handlers",
      events,
      &handle_preference_event/4,
      nil
    )
  end

  # Event Handlers
  defp handle_notification_event(event, measurements, metadata, _config) do
    case event do
      [@notification_prefix | [:send, :start]] ->
        Logger.info("Notification send started",
          notification_type: metadata[:type],
          channel: metadata[:channel],
          recipient_count: metadata[:recipient_count],
          trace_id: metadata[:trace_id]
        )

        Telemetry.create_span(
          "communication.notification.send",
          metadata[:trace_id],
          %{
            "notification.type" => metadata[:type],
            "notification.channel" => metadata[:channel],
            "notification.priority" => metadata[:priority],
            "notification.recipient_count" => metadata[:recipient_count]
          }
        )

      [@notification_prefix | [:send, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Logger.info("Notification sent",
          notification_type: metadata[:type],
          duration_ms: duration_ms,
          success: metadata[:success]
        )

        Telemetry.record_metric(
          "communication.notification.send_duration",
          duration_ms,
          :histogram,
          %{
            type: metadata[:type],
            channel: metadata[:channel],
            success: metadata[:success]
          }
        )

      [@notification_prefix | [:delivery, :confirmed]] ->
        Telemetry.record_metric(
          "communication.notification.delivered",
          1,
          :counter,
          %{
            type: metadata[:type],
            channel: metadata[:channel]
          }
        )

      [@notification_prefix | [:delivery, :failed]] ->
        Logger.error("Notification delivery failed",
          notification_type: metadata[:type],
          channel: metadata[:channel],
          error: metadata[:error],
          retry_count: metadata[:retry_count]
        )

        Telemetry.record_metric(
          "communication.notification.failed",
          1,
          :counter,
          %{
            type: metadata[:type],
            channel: metadata[:channel],
            error_type: metadata[:error_type]
          }
        )

      [@notification_prefix | [:batch, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Telemetry.record_metric(
          "communication.batch.processing_time",
          duration_ms,
          :histogram,
          %{
            batch_size: measurements[:batch_size],
            channel: metadata[:channel]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_message_event(event, measurements, metadata, _config) do
    case event do
      [@message_prefix | [:queue, :enqueued]] ->
        Telemetry.record_metric(
          "communication.queue.size",
          measurements[:queue_size],
          :gauge,
          %{
            queue_name: metadata[:queue_name],
            priority: metadata[:priority]
          }
        )

      [@message_prefix | [:queue, :processed]] ->
        processing_time = measurements[:processing_time]

        Telemetry.record_metric(
          "communication.queue.processing_time",
          processing_time,
          :histogram,
          %{
            queue_name: metadata[:queue_name],
            message_type: metadata[:message_type]
          }
        )

      [@message_prefix | [:queue, :failed]] ->
        Telemetry.record_metric(
          "communication.queue.failures",
          1,
          :counter,
          %{
            queue_name: metadata[:queue_name],
            error_type: metadata[:error_type]
          }
        )

      [@message_prefix | [:retry, :attempted]] ->
        Telemetry.record_metric(
          "communication.message.retries",
          1,
          :counter,
          %{
            attempt_number: metadata[:attempt_number],
            max_attempts: metadata[:max_attempts]
          }
        )

      [@message_prefix | [:dlq, :moved]] ->
        Logger.warning("Message moved to DLQ",
          message_id: metadata[:message_id],
          original_queue: metadata[:original_queue],
          failure_reason: metadata[:failure_reason]
        )

        Telemetry.record_metric(
          "communication.dlq.messages",
          1,
          :counter,
          %{original_queue: metadata[:original_queue]}
        )

      _ ->
        :ok
    end
  end

  defp handle_channel_event(event, measurements, metadata, _config) do
    case event do
      [@channel_prefix | [:email, :sent]] ->
        Telemetry.record_metric(
          "communication.email.sent",
          1,
          :counter,
          %{
            provider: metadata[:provider],
            template: metadata[:template]
          }
        )

      [@channel_prefix | [:email, :bounced]] ->
        Telemetry.record_metric(
          "communication.email.bounced",
          1,
          :counter,
          %{
            bounce_type: metadata[:bounce_type],
            provider: metadata[:provider]
          }
        )

      [@channel_prefix | [:sms, :sent]] ->
        Telemetry.record_metric(
          "communication.sms.sent",
          1,
          :counter,
          %{
            provider: metadata[:provider],
            country_code: metadata[:country_code]
          }
        )

        Telemetry.record_metric(
          "communication.sms.cost",
          measurements[:cost],
          :counter,
          %{provider: metadata[:provider]}
        )

      [@channel_prefix | [:push, :sent]] ->
        Telemetry.record_metric(
          "communication.push.sent",
          1,
          :counter,
          %{
            platform: metadata[:platform],
            topic: metadata[:topic]
          }
        )

      [@channel_prefix | [:push, :received]] ->
        delivery_time = measurements[:delivery_time]

        Telemetry.record_metric(
          "communication.push.delivery_time",
          delivery_time,
          :histogram,
          %{platform: metadata[:platform]}
        )

      [@channel_prefix | [:webhook, :triggered]] ->
        response_time = measurements[:response_time]

        Telemetry.record_metric(
          "communication.webhook.response_time",
          response_time,
          :histogram,
          %{
            endpoint: metadata[:endpoint],
            status_code: metadata[:status_code]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_preference_event(event, _measurements, metadata, _config) do
    case event do
      [@preference_prefix | [:updated]] ->
        Telemetry.record_metric(
          "communication.preferences.updated",
          1,
          :counter,
          %{
            channel: metadata[:channel],
            action: metadata[:action]
          }
        )

      [@preference_prefix | [:opt_out]] ->
        Logger.info("User opted out of communications",
          user_id: metadata[:user_id],
          channel: metadata[:channel],
          reason: metadata[:reason]
        )

        Telemetry.record_metric(
          "communication.preferences.opt_outs",
          1,
          :counter,
          %{
            channel: metadata[:channel],
            reason: metadata[:reason]
          }
        )

      [@preference_prefix | [:compliance, :checked]] ->
        Telemetry.record_metric(
          "communication.compliance.checks",
          1,
          :counter,
          %{
            regulation: metadata[:regulation],
            compliant: metadata[:compliant]
          }
        )

      _ ->
        :ok
    end
  end

  @doc """
  Records notification send metrics.
  """
  @spec record_notification_send(term(), term(), integer(), term(), term()) :: term()
  def record_notification_send(type, channel, recipient_count, duration_ms, success) do
    :telemetry.execute(
      @notification_prefix ++ [:send, :stop],
      %{duration: System.convert_time_unit(duration_ms, :millisecond, :native)},
      %{
        type: type,
        channel: channel,
        recipient_count: recipient_count,
        success: success
      }
    )
  end

  @doc """
  Records message queue metrics.
  """
  def record_queue_metrics(queue_name, queue_size, processing_time) do
    :telemetry.execute(
      @message_prefix ++ [:queue, :enqueued],
      %{queue_size: queue_size},
      %{queue_name: queue_name}
    )

    if processing_time do
      :telemetry.execute(
        @message_prefix ++ [:queue, :processed],
        %{processing_time: processing_time},
        %{queue_name: queue_name}
      )
    end
  end

  @doc """
  Records channel - specific delivery metrics.
  """
  @spec record_channel_delivery(term(), term(), term()) :: term()
  def record_channel_delivery(channel, delivery_data, metrics) do
    :telemetry.execute(
      @channel_prefix ++ [channel, :delivery],
      metrics,
      delivery_data
    )
  end

  @doc """
  Records delivery failure information.
  """
  @spec record_delivery_failure(term(), term(), term(), term()) :: term()
  def record_delivery_failure(type, channel, error, retry_count) do
    :telemetry.execute(
      @notification_prefix ++ [:delivery, :failed],
      %{},
      %{
        type: type,
        channel: channel,
        error: error,
        error_type: classify_error(error),
        retry_count: retry_count
      }
    )
  end

  @spec classify_error(term()) :: term()
  defp classify_error(error) do
    cond do
      String.contains?(error, "rate limit") -> "rate_limit"
      String.contains?(error, "invalid recipient") -> "invalid_recipient"
      String.contains?(error, "timeout") -> "timeout"
      String.contains?(error, "auth") -> "authentication"
      true -> "unknown"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
