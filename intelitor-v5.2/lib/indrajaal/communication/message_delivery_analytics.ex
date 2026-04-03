defmodule Indrajaal.Communication.MessageDeliveryAnalytics do
  @moduledoc """
  Advanced message delivery analytics and optimization engine.

  Provides real-time analytics, delivery optimization, engagement tracking,
  and intelligent routing for all communication channels.
  """

  use GenServer
  require Logger
  alias Indrajaal.Communication.TimescaleCommunicationEvents
  alias Indrajaal.Repo

  # EP301: Removed unused module attributes @channels and @message_types

  @default_optimization_rules %{
    "email" => %{
      optimal_send_times: ["09:00", "14:00", "18:00"],
      f_requency_limits: %{daily: 10, weekly: 50, monthly: 200},
      engagement_thresholds: %{open_rate: 0.20, click_rate: 0.05},
      retry_strategy: %{max_attempts: 3, backoff_multiplier: 2}
    },
    "sms" => %{
      optimal_send_times: ["10:00", "15:00", "19:00"],
      f_requency_limits: %{daily: 5, weekly: 20, monthly: 80},
      engagement_thresholds: %{delivery_rate: 0.95, response_rate: 0.10},
      retry_strategy: %{max_attempts: 2, backoff_multiplier: 1.5}
    },
    "push" => %{
      optimal_send_times: ["08:00", "12:00", "17:00", "20:00"],
      f_requency_limits: %{daily: 15, weekly: 70, monthly: 300},
      engagement_thresholds: %{delivery_rate: 0.90, open_rate: 0.15},
      retry_strategy: %{max_attempts: 3, backoff_multiplier: 1.2}
    },
    "in_app" => %{
      # In-app can be sent anytime
      optimal_send_times: ["anytime"],
      f_requency_limits: %{daily: 20, weekly: 100, monthly: 400},
      engagement_thresholds: %{view_rate: 0.80, interaction_rate: 0.25},
      retry_strategy: %{max_attempts: 1, backoff_multiplier: 1}
    }
  }

  @spec start_link(keyword() | map()) :: term()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    # Schedule analytics processing
    # 5 minutes
    :timer.send_interval(300_000, :process_analytics)
    # 15 minutes
    :timer.send_interval(900_000, :optimize_delivery)
    # 1 hour
    :timer.send_interval(3_600_000, :generate_insights)

    {:ok,
     %{
       optimization_rules: @default_optimization_rules,
       analytics_cache: %{},
       last_optimization: DateTime.utc_now()
     }}
  end

  @doc """
  Get comprehensive delivery analytics for a tenant
  """
  @spec get_delivery_analytics(binary() | integer(), any(), map()) :: term()
  def get_delivery_analytics(tenantid, timeframe \\ "24h", _options \\ %{}) do
    time_clause = build_time_clause(timeframe)

    base_query = """
    WITH delivery_stats AS (
      SELECT
        channel,
        message_type,
        COUNT(*) as total_sent,
        COUNT(*) FILTER (WHERE __event_type = 'delivered') as delivered_count,
        COUNT(*) FILTER (WHERE __event_type = 'opened') as opened_count,
        COUNT(*) FILTER (WHERE __event_type = 'clicked') as clicked_count,
        COUNT(*) FILTER (WHERE __event_type = 'bounced') as bounced_count,
        COUNT(*) FILTER (WHERE __event_type = 'failed') as failed_count,
        AVG(engagement_score) as avg_engagement_score,
        AVG(EXTRACT(epoch FROM (delivery_time-time))) as avg_delivery_time_seconds
      FROM communication_events
      WHERE tenantid = $1 AND time #{time_clause}
      GROUP BY channel, message_type
    ),
    channel_performance AS (
      SELECT
        channel,
        SUM(total_sent) as channel_total_sent,
        SUM(delivered_count)::DECIMAL / NULLIF(SUM(total_sent), 0) * 100 as delivery_rate,
        SUM(opened_count)::DECIMAL / NULLIF(SUM(delivered_count), 0) * 100 as open_rate,
        SUM(clicked_count)::DECIMAL / NULLIF(SUM(opened_count), 0) * 100 as click_through_rate,
        SUM(bounced_count)::DECIMAL / NULLIF(SUM(total_sent), 0) * 100 as bounce_rate,
        SUM(failed_count)::DECIMAL / NULLIF(SUM(total_sent), 0) * 100 as failure_rate,
        AVG(avg_engagement_score) as channel_engagement_score,
        AVG(avg_delivery_time_seconds) as avg_delivery_time
      FROM delivery_stats
      GROUP BY channel
    ),
    engagement_trends AS (
      SELECT
        time_bucket('1 hour', time) as hour_bucket,
        channel,
        COUNT(*) as hourly_sent,
        COUNT(*) FILTER (WHERE __event_type = 'opened') as hourly_opened,
        AVG(engagement_score) as hourly_engagement
      FROM communication_events
      WHERE tenantid = $1 AND time #{time_clause}
      GROUP BY hour_bucket, channel
      ORDER BY hour_bucket
    )
    SELECT
      json_build_object(
        'summary', json_agg(
          json_build_object(
            'channel', cp.channel,
            'total_sent', cp.channel_total_sent,
            'delivery_rate', COALESCE(cp.delivery_rate, 0),
            'open_rate', COALESCE(cp.open_rate, 0),
            'click_through_rate', COALESCE(cp.click_through_rate, 0),
            'bounce_rate', COALESCE(cp.bounce_rate, 0),
            'failure_rate', COALESCE(cp.failure_rate, 0),
            'engagement_score', COALESCE(cp.channel_engagement_score, 0),
            'avg_delivery_time_seconds', COALESCE(cp.avg_delivery_time, 0)
          )
        ),
        'detailed_stats', (
          SELECT json_agg(
            json_build_object(
              'channel', ds.channel,
              'message_type', ds.message_type,
              'metrics', json_build_object(
                'total_sent', ds.total_sent,
                'delivered', ds.delivered_count,
                'opened', ds.opened_count,
                'clicked', ds.clicked_count,
                'bounced', ds.bounced_count,
                'failed', ds.failed_count,
                'engagement_score', COALESCE(ds.avg_engagement_score, 0),
                'avg_delivery_time', COALESCE(ds.avg_delivery_time_seconds, 0)
              )
            )
          )
          FROM delivery_stats ds
        ),
        'engagement_trends', (
          SELECT json_agg(
            json_build_object(
              'hour', et.hour_bucket,
              'channel', et.channel,
              'sent', et.hourly_sent,
              'opened', et.hourly_opened,
              'engagement', COALESCE(et.hourly_engagement, 0)
            )
          )
          FROM engagement_trends et
        )
      ) as analyticsdata
    FROM channel_performance cp
    """

    case Repo.query(base_query, [tenantid]) do
      {:ok, %{rows: [[analytics_json]]}} ->
        analytics = Jason.decode!(analytics_json)

        # Add optimization recommendations
        recommendations = generate_optimization_recommendations(tenantid, analytics)

        {:ok, Map.put(analytics, "recommendations", recommendations)}

      {:error, error} ->
        Logger.error("Failed to fetch delivery analytics: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Optimize message delivery for a specific message
  """
  @spec optimize_message_delivery(binary() | integer(), term()) :: term()
  def optimize_message_delivery(tenantid, messageparams) do
    channel = messageparams.channel
    user_id = messageparams.user_id
    message_type = messageparams.message_type

    # Get user's historical engagement data
    userengagement = get_user_engagement_profile(tenantid, user_id, channel)

    # Get current channel performance
    channelstats = get_channel_statistics(tenantid, channel)

    # Apply optimization rules
    optimization_rules = Map.get(@default_optimization_rules, channel, %{})

    optimized_params = %{
      original_channel: channel,
      recommended_channel: recommend_optimal_channel(tenantid, user_id, message_type),
      optimal_send_time: calculate_optimal_send_time(userengagement, optimization_rules),
      f_requency_check:
        check_f_requency_limits(tenantid, user_id, channel, optimization_rules, nil),
      engagement_prediction: predict_engagement(userengagement, channelstats),
      personalization_score: calculate_personalization_score(messageparams, userengagement),
      delivery_confidence: calculate_delivery_confidence(channelstats, userengagement),
      estimated_delivery_time: estimate_delivery_time(channel, channelstats),
      cost_optimization: calculate_cost_optimization(channel, message_type, channelstats)
    }

    # Log optimization decision
    TimescaleCommunicationEvents.log_communication_event(%{
      tenantid: tenantid,
      message_id: messageparams.message_id,
      user_id: user_id,
      channel: "optimization_engine",
      __event_type: "optimization_applied",
      message_type: message_type,
      metadata: optimized_params
    })

    {:ok, optimized_params}
  end

  @doc """
  Track message engagement in real-time
  """
  @spec track_engagement_event(binary() | integer(), term()) :: term()
  def track_engagement_event(tenantid, engagement_data) do
    # Calculate engagement score
    engagement_score = calculate_engagement_score(engagement_data)

    # Update user engagement profile
    update_user_engagement_profile(
      tenantid,
      engagement_data.user_id,
      engagement_data.channel,
      engagement_score
    )

    # Log engagement __event
    TimescaleCommunicationEvents.log_communication_event(%{
      tenantid: tenantid,
      message_id: engagement_data.message_id,
      user_id: engagement_data.user_id,
      channel: engagement_data.channel,
      __event_type: engagement_data.__event_type,
      message_type: engagement_data.message_type,
      engagement_score: engagement_score,
      metadata: %{
        interaction_type: engagement_data.interaction_type,
        time_to_engagement: engagement_data.time_to_engagement,
        device_type: engagement_data.device_type,
        location: engagement_data.location
      }
    })

    # Trigger real-time optimization if needed
    # Low engagement threshold
    if engagement_score < 20 do
      schedule_re_engagement(tenantid, engagement_data)
    end

    :ok
  end

  @doc """
  Generate delivery performance report
  """
  @spec generate_performance_report(binary() | integer(), any(), any()) :: term()
  def generate_performance_report(tenantid, report_type \\ "comprehensive", timeframe \\ "30d") do
    report_sections =
      case report_type do
        "executive" ->
          [:summary, :key_metrics, :recommendations]

        "operational" ->
          [:channel_performance, :delivery_issues, :optimization_impact]

        "comprehensive" ->
          [
            :summary,
            :key_metrics,
            :channel_performance,
            :__userengagement,
            :delivery_issues,
            :optimization_impact,
            :cost_analysis,
            :recommendations
          ]
      end

    report_data = %{
      tenantid: tenantid,
      report_type: report_type,
      timeframe: timeframe,
      generated_at: DateTime.utc_now(),
      sections: generate_report_sections(tenantid, report_sections, timeframe)
    }

    # Store report
    store_performance_report(report_data)

    {:ok, report_data}
  end

  @doc """
  Get real-time delivery dashboard metrics
  """
  @spec get_realtime_dashboard_metrics(binary() | integer()) :: term()
  def get_realtime_dashboard_metrics(tenantid) do
    with {:ok, current_data} <- fetch_current_metrics(tenantid),
         {:ok, comparison_data} <- fetch_comparison_metrics(tenantid),
         {:ok, channel_data} <- fetch_channel_distribution(tenantid) do
      metrics = build_realtime_metrics(current_data, comparison_data, channel_data)
      {:ok, metrics}
    else
      {:error, error} ->
        Logger.error("Failed to fetch realtime dashboard metrics: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_current_metrics(tenantid) do
    query = """
    SELECT
      COUNT(*) as messages_sent_last_hour,
      COUNT(*) FILTER (WHERE __event_type = 'delivered') as messages_delivered_last_hour,
      COUNT(*) FILTER (WHERE __event_type = 'failed') as messages_failed_last_hour,
      AVG(engagement_score) as avg_engagement_last_hour,
      COUNT(DISTINCT user_id) as active_users_last_hour
    FROM communication_events
    WHERE tenantid = $1 AND time >= NOW()-INTERVAL '1 hour'
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: [[sent, delivered, failed, engagement, users]]}} ->
        {:ok, {sent, delivered, failed, engagement, users}}

      other ->
        other
    end
  end

  defp fetch_comparison_metrics(tenantid) do
    query = """
    SELECT
      COUNT(*) as messages_sent_prev_hour,
      COUNT(*) FILTER (WHERE __event_type = 'delivered') as messages_delivered_prev_hour,
      AVG(engagement_score) as avg_engagement_prev_hour
    FROM communication_events
    WHERE tenantid = $1
      AND time >= NOW()-INTERVAL '2 hours'
      AND time < NOW()-INTERVAL '1 hour'
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: [[sent, delivered, engagement]]}} ->
        {:ok, {sent, delivered, engagement}}

      {:ok, %{rows: []}} ->
        {:ok, {0, 0, 0}}

      other ->
        other
    end
  end

  defp fetch_channel_distribution(tenantid) do
    query = """
    SELECT
      channel,
      COUNT(*) as count,
      AVG(engagement_score) as avg_engagement
    FROM communication_events
    WHERE tenantid = $1 AND time >= NOW()-INTERVAL '1 hour'
    GROUP BY channel
    ORDER BY count DESC
    """

    Repo.query(query, [tenantid])
  end

  defp build_realtime_metrics(
         {current_sent, current_delivered, current_failed, current_engagement, active_users},
         {prev_sent, prev_delivered, prev_engagement},
         {:ok, %{rows: channel_rows}}
       ) do
    channel_distribution =
      Enum.map(channel_rows, fn [channel, count, avg_engagement] ->
        %{
          channel: channel,
          count: count,
          avg_engagement: avg_engagement || 0
        }
      end)

    %{
      current_hour: %{
        messages_sent: current_sent,
        messages_delivered: current_delivered,
        messages_failed: current_failed,
        delivery_rate: if(current_sent > 0, do: current_delivered / current_sent * 100, else: 0),
        failure_rate: if(current_sent > 0, do: current_failed / current_sent * 100, else: 0),
        avg_engagement_score: current_engagement || 0,
        active_users: active_users
      },
      trends: %{
        sent_change: calculate_percentage_change(current_sent, prev_sent),
        delivered_change: calculate_percentage_change(current_delivered, prev_delivered),
        engagement_change:
          calculate_percentage_change(current_engagement || 0, prev_engagement || 0)
      },
      channel_distribution: channel_distribution,
      health_status:
        determine_system_health(
          current_sent,
          current_delivered,
          current_failed,
          current_engagement || 0
        )
    }
  end

  # Private helper functions

  defp get_user_engagement_profile(tenantid, user_id, channel) do
    query = """
    SELECT
      COUNT(*) as total_messages,
      COUNT(*) FILTER (WHERE __event_type = 'opened') as opened_count,
      COUNT(*) FILTER (WHERE __event_type = 'clicked') as clicked_count,
      AVG(engagement_score) as avg_engagement_score,
      array_agg(DISTINCT EXTRACT(hour FROM time)) as active_hours
    FROM communication_events
    WHERE tenantid = $1 AND user_id = $2 AND channel = $3
      AND time >= NOW()-INTERVAL '30 days'
    """

    case Repo.query(query, [tenantid, user_id, channel]) do
      {:ok, %{rows: [[total, opened, clicked, avg_score, active_hours]]}} ->
        %{
          total_messages: total,
          open_rate: if(total > 0, do: opened / total, else: 0),
          click_rate: if(opened > 0, do: clicked / opened, else: 0),
          avg_engagement_score: avg_score || 0,
          preferred_hours: active_hours || [],
          engagement_level: determine_engagement_level(avg_score || 0)
        }

      _ ->
        %{
          total_messages: 0,
          open_rate: 0,
          click_rate: 0,
          avg_engagement_score: 0,
          preferred_hours: [],
          engagement_level: "unknown"
        }
    end
  end

  defp get_channel_statistics(tenantid, channel) do
    query = """
    SELECT
      COUNT(*) as total_messages,
      AVG(EXTRACT(epoch FROM (delivery_time-time))) as avg_delivery_time,
      COUNT(*) FILTER (WHERE __event_type = 'delivered')::DECIMAL / COUNT(*) * 100 as delivery_rate,
      COUNT(*) FILTER (WHERE __event_type = 'bounced')::DECIMAL / COUNT(*) * 100 as bounce_rate,
      AVG(engagement_score) as avg_engagement_score
    FROM communication_events
    WHERE tenantid = $1 AND channel = $2
      AND time >= NOW()-INTERVAL '7 days'
    """

    case Repo.query(query, [tenantid, channel]) do
      {:ok, %{rows: [[total, avg_delivery_time, delivery_rate, bounce_rate, avg_engagement]]}} ->
        %{
          total_messages: total,
          avg_delivery_time: avg_delivery_time || 0,
          delivery_rate: delivery_rate || 0,
          bounce_rate: bounce_rate || 0,
          avg_engagement_score: avg_engagement || 0,
          reliability_score: calculate_reliability_score(delivery_rate || 0, bounce_rate || 0)
        }

      _ ->
        %{
          total_messages: 0,
          avg_delivery_time: 0,
          delivery_rate: 0,
          bounce_rate: 0,
          avg_engagement_score: 0,
          reliability_score: 0
        }
    end
  end

  defp recommend_optimal_channel(tenantid, user_id, message_type) do
    # Query user's channel preferences and performance
    query = """
    SELECT
      channel,
      COUNT(*) as message_count,
      AVG(engagement_score) as avg_engagement,
      COUNT(*) FILTER (WHERE __event_type = 'delivered')::DECIMAL / COUNT(*) as delivery_rate
    FROM communication_events
    WHERE tenantid = $1 AND user_id = $2 AND message_type = $3
      AND time >= NOW()-INTERVAL '30 days'
    GROUP BY channel
    ORDER BY avg_engagement DESC, delivery_rate DESC
    LIMIT 1
    """

    case Repo.query(query, [tenantid, user_id, message_type]) do
      {:ok, %{rows: [[channel, _count, _engagement, _delivery_rate]]}} -> channel
      # Default fallback
      _ -> "email"
    end
  end

  defp calculate_optimal_send_time(userengagement, optimization_rules) do
    user_preferred_hours = userengagement.preferred_hours
    optimal_times = Map.get(optimization_rules, :optimal_send_times, ["10:00"])

    if Enum.empty?(user_preferred_hours) do
      Enum.random(optimal_times)
    else
      # Find intersection of user preferences and optimal times
      user_hours_set = MapSet.new(user_preferred_hours)

      optimal_hours =
        optimal_times
        |> Enum.map(fn time_str ->
          [hour_str, _] = String.split(time_str, ":")
          String.to_integer(hour_str)
        end)
        |> MapSet.new()

      intersection = user_hours_set |> MapSet.intersection(optimal_hours) |> MapSet.to_list()

      if Enum.empty?(intersection) do
        Enum.random(optimal_times)
      else
        hour = Enum.random(intersection)
        "#{String.pad_leading(to_string(hour), 2, "0")}:00"
      end
    end
  end

  defp check_f_requency_limits(tenantid, user_id, channel, optimization_rules, __req) do
    f_requency_limits = Map.get(optimization_rules, :f_requency_limits, %{daily: 10})

    # Check daily limit
    daily_query = """
    SELECT COUNT(*)
    FROM communication_events
    WHERE tenantid = $1 AND user_id = $2 AND channel = $3
      AND time >= CURRENT_DATE
    """

    case Repo.query(daily_query, [tenantid, user_id, channel]) do
      {:ok, %{rows: [[daily_count]]}} ->
        daily_limit = Map.get(f_requency_limits, :daily, 10)

        %{
          daily_count: daily_count,
          daily_limit: daily_limit,
          daily_remaining: max(0, daily_limit - daily_count),
          can_send: daily_count < daily_limit
        }

      _ ->
        %{daily_count: 0, daily_limit: 10, daily_remaining: 10, can_send: true}
    end
  end

  defp predict_engagement(userengagement, channelstats) do
    user_score = userengagement.avg_engagement_score
    channel_score = channelstats.avg_engagement_score

    # Weighted prediction combining user history and channel performance
    predicted_score = user_score * 0.7 + channel_score * 0.3

    %{
      predicted_engagement_score: predicted_score,
      confidence_level: determine_prediction_confidence(userengagement.total_messages),
      likelihood_to_open:
        predict_open_probability(userengagement.open_rate, channelstats.delivery_rate),
      likelihood_to_click: predict_click_probability(userengagement.click_rate, predicted_score)
    }
  end

  defp calculate_personalization_score(messageparams, userengagement) do
    # Base personalization score
    base_score = 50

    # Adjust based on user engagement level
    engagement_bonus =
      case userengagement.engagement_level do
        "high" -> 20
        "medium" -> 10
        "low" -> -10
        _ -> 0
      end

    # Adjust based on message customization (placeholder for now)
    customization_bonus = if Map.has_key?(messageparams, :personalized_content), do: 15, else: 0

    min(100, max(0, base_score + engagement_bonus + customization_bonus))
  end

  defp calculate_delivery_confidence(channelstats, userengagement) do
    channel_reliability = channelstats.reliability_score
    user_responsiveness = userengagement.avg_engagement_score

    # Combined confidence score
    confidence = channel_reliability * 0.6 + user_responsiveness * 0.4

    %{
      confidence_score: confidence,
      confidence_level:
        cond do
          confidence >= 80 -> "high"
          confidence >= 60 -> "medium"
          true -> "low"
        end
    }
  end

  defp estimate_delivery_time(channel, channel_stats) do
    base_times = %{
      # 30 seconds
      "email" => 30,
      # 5 seconds
      "sms" => 5,
      # 2 seconds
      "push" => 2,
      # 1 second
      "in_app" => 1,
      # 3 seconds
      "slack" => 3,
      # 3 seconds
      "teams" => 3,
      # 5 seconds
      "webhook" => 5
    }

    base_time = Map.get(base_times, channel, 30)

    performance_factor =
      if channel_stats.avg_delivery_time > 0,
        do: channel_stats.avg_delivery_time / base_time,
        else: 1

    round(base_time * performance_factor)
  end

  defp calculate_cost_optimization(channel, _message_type, channel_stats) do
    # Placeholder cost calculations (would integrate with actual pricing)
    base_costs = %{
      "email" => 0.001,
      "sms" => 0.05,
      "push" => 0.001,
      "in_app" => 0.0,
      "slack" => 0.0,
      "teams" => 0.0,
      "webhook" => 0.001
    }

    base_cost = Map.get(base_costs, channel, 0.001)

    # Adjust cost based on delivery success rate
    delivery_rate = channel_stats.delivery_rate / 100
    effective_cost = if delivery_rate > 0, do: base_cost / delivery_rate, else: base_cost * 2

    %{
      base_cost: base_cost,
      effective_cost: effective_cost,
      cost_efficiency_score: min(100, delivery_rate * 100)
    }
  end

  defp calculate_engagement_score(engagement_data) do
    base_score = 10

    score_adjustments = %{
      "sent" => 0,
      "delivered" => 10,
      "opened" => 30,
      "clicked" => 50,
      "replied" => 70,
      "converted" => 100,
      "bounced" => -20,
      "failed" => -30,
      "unsubscribed" => -50,
      "complained" => -80
    }

    event_score = Map.get(score_adjustments, engagement_data.__event_type, 0)

    # Time-based bonus (faster engagement = higher score)
    time_bonus =
      case engagement_data.time_to_engagement do
        # Within 5 minutes
        time when time < 300 -> 10
        # Within 1 hour
        time when time < 3600 -> 5
        # Within 1 day
        time when time < 86_400 -> 2
        _ -> 0
      end

    max(0, min(100, base_score + event_score + time_bonus))
  end

  defp update_user_engagement_profile(tenantid, user_id, channel, engagement_score) do
    table = ensure_engagement_ets()
    key = {tenantid, user_id, channel}
    now = System.system_time(:second)

    existing =
      case :ets.lookup(table, key) do
        [{^key, profile}] -> profile
        [] -> %{history: [], total_interactions: 0}
      end

    updated = %{
      tenant_id: tenantid,
      user_id: user_id,
      channel: channel,
      last_score: engagement_score,
      last_updated_at: now,
      total_interactions: existing.total_interactions + 1,
      history: Enum.take([{now, engagement_score} | existing.history], 50)
    }

    :ets.insert(table, {key, updated})

    :telemetry.execute(
      [:indrajaal, :communication, :engagement, :profile_updated],
      %{engagement_score: engagement_score, total_interactions: updated.total_interactions},
      %{tenant_id: tenantid, user_id: user_id, channel: channel}
    )

    :ok
  end

  defp schedule_re_engagement(tenantid, engagement_data) do
    table = ensure_engagement_ets()
    re_key = {tenantid, :re_engagement_queue}
    now = System.system_time(:second)

    entry = %{
      tenant_id: tenantid,
      user_id: engagement_data.user_id,
      channel: Map.get(engagement_data, :channel, "email"),
      scheduled_at: now,
      reason: :low_engagement,
      send_after: now + 86_400
    }

    existing_queue =
      case :ets.lookup(table, re_key) do
        [{^re_key, queue}] -> queue
        [] -> []
      end

    :ets.insert(table, {re_key, Enum.take([entry | existing_queue], 500)})

    :telemetry.execute(
      [:indrajaal, :communication, :engagement, :re_engagement_scheduled],
      %{queue_depth: length(existing_queue) + 1},
      %{tenant_id: tenantid, user_id: engagement_data.user_id}
    )

    :ok
  end

  defp generate_optimization_recommendations(_tenantid, analytics) do
    summary = analytics["summary"] || []

    recommendations =
      Enum.flat_map(summary, fn channel_data ->
        channel = channel_data["channel"]
        delivery_rate = channel_data["delivery_rate"] || 0
        open_rate = channel_data["open_rate"] || 0
        engagement_score = channel_data["engagement_score"] || 0

        channel_recommendations = []

        # Delivery rate recommendations
        channel_recommendations =
          if delivery_rate < 90 do
            [
              %{
                type: "delivery_optimization",
                priority: "high",
                channel: channel,
                recommendation:
                  "Improve delivery rate by updating sender reputation and cleaning recipient lists",
                expected_impact: "10-15% delivery rate improvement"
              }
              | channel_recommendations
            ]
          else
            channel_recommendations
          end

        # Engagement recommendations
        channel_recommendations =
          if engagement_score < 30 do
            [
              %{
                type: "engagement_optimization",
                priority: "medium",
                channel: channel,
                recommendation:
                  "Optimize send times and personalize content to improve engagement",
                expected_impact: "20-30% engagement score improvement"
              }
              | channel_recommendations
            ]
          else
            channel_recommendations
          end

        # Open rate recommendations for email
        channel_recommendations =
          if channel == "email" and open_rate < 20 do
            [
              %{
                type: "open_rate_optimization",
                priority: "medium",
                channel: channel,
                recommendation: "A / B test subject lines and sender names to improve open rates",
                expected_impact: "15-25% open rate improvement"
              }
              | channel_recommendations
            ]
          else
            channel_recommendations
          end

        channel_recommendations
      end)

    # General recommendations
    general_recommendations = [
      %{
        type: "automation",
        priority: "high",
        channel: "all",
        recommendation: "Implement automated send-time optimization based on user behavior",
        expected_impact: "10-20% overall engagement improvement"
      },
      %{
        type: "segmentation",
        priority: "medium",
        channel: "all",
        recommendation:
          "Create user segments based on engagement patterns for targeted messaging",
        expected_impact: "15-25% conversion rate improvement"
      }
    ]

    recommendations ++ general_recommendations
  end

  defp generate_report_sections(tenantid, sections, timeframe) do
    Enum.reduce(sections, %{}, fn section, acc ->
      case section do
        :summary ->
          Map.put(acc, :summary, generate_summary_section(tenantid, timeframe))

        :key_metrics ->
          Map.put(acc, :key_metrics, generate_key_metrics_section(tenantid, timeframe))

        :channel_performance ->
          Map.put(
            acc,
            :channel_performance,
            generate_channel_performance_section(tenantid, timeframe)
          )

        :__userengagement ->
          Map.put(acc, :__userengagement, generate_user_engagement_section(tenantid, timeframe))

        :delivery_issues ->
          Map.put(acc, :delivery_issues, generate_delivery_issues_section(tenantid, timeframe))

        :optimization_impact ->
          Map.put(
            acc,
            :optimization_impact,
            generate_optimization_impact_section(tenantid, timeframe)
          )

        :cost_analysis ->
          Map.put(acc, :cost_analysis, generate_cost_analysis_section(tenantid, timeframe))

        :recommendations ->
          Map.put(acc, :recommendations, generate_recommendations_section(tenantid, timeframe))

        _ ->
          acc
      end
    end)
  end

  # Report section generators (simplified implementations)
  defp generate_summary_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      COUNT(*) as total_messages,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered,
      AVG(engagement_score) as avg_engagement
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    """

    channel_query = """
    SELECT channel, COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered_count
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    GROUP BY channel
    ORDER BY delivered_count DESC
    LIMIT 1
    """

    {total, delivery_rate, avg_engagement} =
      case Repo.query(query, [tenantid]) do
        {:ok, %{rows: [[total, delivered, avg_eng]]}} when not is_nil(total) ->
          rate = if total > 0, do: Float.round(delivered / total * 100, 1), else: 0.0
          {total, rate, Float.round(avg_eng || 0.0, 1)}

        _ ->
          {0, 0.0, 0.0}
      end

    top_channel =
      case Repo.query(channel_query, [tenantid]) do
        {:ok, %{rows: [[channel | _] | _]}} when not is_nil(channel) -> channel
        _ -> "email"
      end

    %{
      total_messages: total,
      overall_delivery_rate: delivery_rate,
      overall_engagement_score: avg_engagement,
      top_performing_channel: top_channel,
      generated_at: DateTime.utc_now()
    }
  end

  defp generate_key_metrics_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      COUNT(*) as total_messages,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered,
      COUNT(*) FILTER (WHERE event_type = 'failed') as failed,
      COUNT(*) FILTER (WHERE event_type = 'opened') as opened,
      AVG(engagement_score) as avg_engagement,
      COUNT(DISTINCT user_id) as unique_recipients
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: [[total, delivered, failed, opened, avg_eng, unique]]}} ->
        delivery_rate =
          if total && total > 0, do: Float.round(delivered / total * 100, 2), else: 0.0

        open_rate =
          if delivered && delivered > 0, do: Float.round(opened / delivered * 100, 2), else: 0.0

        %{
          total_messages: total || 0,
          delivered: delivered || 0,
          failed: failed || 0,
          opened: opened || 0,
          delivery_rate_pct: delivery_rate,
          open_rate_pct: open_rate,
          avg_engagement_score: avg_eng || 0.0,
          unique_recipients: unique || 0,
          generated_at: DateTime.utc_now()
        }

      _ ->
        %{
          total_messages: 0,
          delivered: 0,
          failed: 0,
          opened: 0,
          delivery_rate_pct: 0.0,
          open_rate_pct: 0.0,
          avg_engagement_score: 0.0,
          unique_recipients: 0,
          generated_at: DateTime.utc_now()
        }
    end
  end

  defp generate_channel_performance_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      channel,
      COUNT(*) as sent,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered,
      COUNT(*) FILTER (WHERE event_type = 'failed') as failed,
      AVG(engagement_score) as avg_engagement
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    GROUP BY channel
    ORDER BY sent DESC
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows}} ->
        channels =
          Enum.map(rows, fn [channel, sent, delivered, failed, avg_eng] ->
            delivery_rate =
              if sent && sent > 0, do: Float.round(delivered / sent * 100, 2), else: 0.0

            %{
              channel: channel,
              sent: sent || 0,
              delivered: delivered || 0,
              failed: failed || 0,
              delivery_rate_pct: delivery_rate,
              avg_engagement_score: avg_eng || 0.0
            }
          end)

        %{channels: channels, generated_at: DateTime.utc_now()}

      _ ->
        %{channels: [], generated_at: DateTime.utc_now()}
    end
  end

  defp generate_user_engagement_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      COUNT(DISTINCT user_id) as total_users,
      COUNT(DISTINCT CASE WHEN event_type = 'opened' THEN user_id END) as engaged_users,
      AVG(engagement_score) as avg_score,
      MAX(engagement_score) as max_score,
      MIN(engagement_score) FILTER (WHERE engagement_score > 0) as min_active_score
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: [[total, engaged, avg_score, max_score, min_score]]}} ->
        engagement_rate =
          if total && total > 0, do: Float.round((engaged || 0) / total * 100, 2), else: 0.0

        %{
          total_users: total || 0,
          engaged_users: engaged || 0,
          engagement_rate_pct: engagement_rate,
          avg_engagement_score: avg_score || 0.0,
          max_engagement_score: max_score || 0.0,
          min_active_engagement_score: min_score || 0.0,
          generated_at: DateTime.utc_now()
        }

      _ ->
        %{
          total_users: 0,
          engaged_users: 0,
          engagement_rate_pct: 0.0,
          avg_engagement_score: 0.0,
          generated_at: DateTime.utc_now()
        }
    end
  end

  defp generate_delivery_issues_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      channel,
      message_type,
      COUNT(*) as failure_count,
      COUNT(*) FILTER (WHERE event_type = 'bounced') as bounce_count
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
      AND event_type IN ('failed', 'bounced')
    GROUP BY channel, message_type
    ORDER BY failure_count DESC
    LIMIT 20
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows}} ->
        issues =
          Enum.map(rows, fn [channel, msg_type, failures, bounces] ->
            %{
              channel: channel,
              message_type: msg_type,
              failure_count: failures || 0,
              bounce_count: bounces || 0
            }
          end)

        total_failures = Enum.sum(Enum.map(issues, & &1.failure_count))

        %{issues: issues, total_failures: total_failures, generated_at: DateTime.utc_now()}

      _ ->
        %{issues: [], total_failures: 0, generated_at: DateTime.utc_now()}
    end
  end

  defp generate_optimization_impact_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      channel,
      AVG(engagement_score) as current_engagement,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered,
      COUNT(*) as total_sent
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    GROUP BY channel
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows}} ->
        channel_impacts =
          Enum.map(rows, fn [channel, avg_eng, delivered, total] ->
            delivery_rate = if total && total > 0, do: delivered / total * 100.0, else: 0.0
            potential_improvement = max(0.0, 95.0 - delivery_rate)

            %{
              channel: channel,
              current_delivery_rate: Float.round(delivery_rate, 2),
              current_engagement: Float.round(avg_eng || 0.0, 2),
              potential_delivery_improvement_pct: Float.round(potential_improvement, 2),
              optimization_priority: if(potential_improvement > 10, do: "high", else: "low")
            }
          end)

        %{channel_impacts: channel_impacts, generated_at: DateTime.utc_now()}

      _ ->
        %{channel_impacts: [], generated_at: DateTime.utc_now()}
    end
  end

  defp generate_cost_analysis_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      channel,
      COUNT(*) as total_sent,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    GROUP BY channel
    """

    cost_per_message = %{
      "email" => 0.001,
      "sms" => 0.05,
      "push" => 0.0005,
      "in_app" => 0.0001
    }

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows}} ->
        channel_costs =
          Enum.map(rows, fn [channel, total, delivered] ->
            unit_cost = Map.get(cost_per_message, channel, 0.001)
            total_cost = (total || 0) * unit_cost

            cost_per_delivered =
              if delivered && delivered > 0, do: total_cost / delivered, else: 0.0

            %{
              channel: channel,
              messages_sent: total || 0,
              messages_delivered: delivered || 0,
              estimated_total_cost: Float.round(total_cost, 4),
              cost_per_delivered_message: Float.round(cost_per_delivered, 6)
            }
          end)

        total_cost = Enum.sum(Enum.map(channel_costs, & &1.estimated_total_cost))

        %{
          channel_costs: channel_costs,
          total_estimated_cost: Float.round(total_cost, 4),
          currency: "USD",
          generated_at: DateTime.utc_now()
        }

      _ ->
        %{
          channel_costs: [],
          total_estimated_cost: 0.0,
          currency: "USD",
          generated_at: DateTime.utc_now()
        }
    end
  end

  defp generate_recommendations_section(tenantid, timeframe) do
    time_clause = build_time_clause(timeframe)

    query = """
    SELECT
      channel,
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE event_type = 'delivered') as delivered,
      COUNT(*) FILTER (WHERE event_type = 'failed') as failed,
      AVG(engagement_score) as avg_engagement
    FROM communication_events
    WHERE tenant_id = $1 AND time #{time_clause}
    GROUP BY channel
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows}} ->
        recommendations =
          Enum.flat_map(rows, fn [channel, total, delivered, failed, avg_eng] ->
            delivery_rate =
              if total && total > 0, do: (delivered || 0) / total * 100.0, else: 100.0

            failure_rate = if total && total > 0, do: (failed || 0) / total * 100.0, else: 0.0
            engagement = avg_eng || 0.0

            recs = []

            recs =
              if delivery_rate < 90.0 do
                [
                  %{
                    priority: "high",
                    channel: channel,
                    type: "delivery_improvement",
                    message:
                      "#{channel} delivery rate #{Float.round(delivery_rate, 1)}% below 90% threshold. Review bounce handling and sender reputation.",
                    expected_impact: "5-15% delivery improvement"
                  }
                  | recs
                ]
              else
                recs
              end

            recs =
              if failure_rate > 5.0 do
                [
                  %{
                    priority: "medium",
                    channel: channel,
                    type: "failure_reduction",
                    message:
                      "#{channel} failure rate #{Float.round(failure_rate, 1)}% exceeds 5%. Investigate error patterns.",
                    expected_impact: "Reduced support tickets and better user experience"
                  }
                  | recs
                ]
              else
                recs
              end

            recs =
              if engagement < 20.0 do
                [
                  %{
                    priority: "low",
                    channel: channel,
                    type: "engagement_boost",
                    message:
                      "#{channel} engagement score #{Float.round(engagement, 1)} below 20. Personalize content and optimize send times.",
                    expected_impact: "10-25% engagement improvement"
                  }
                  | recs
                ]
              else
                recs
              end

            recs
          end)

        sorted =
          Enum.sort_by(recommendations, fn r ->
            case r.priority do
              "high" -> 0
              "medium" -> 1
              _ -> 2
            end
          end)

        %{recommendations: sorted, count: length(sorted), generated_at: DateTime.utc_now()}

      _ ->
        %{recommendations: [], count: 0, generated_at: DateTime.utc_now()}
    end
  end

  defp store_performance_report(reportdata) do
    table = ensure_engagement_ets()
    tenant_key = {:performance_report, reportdata.tenantid}
    now = System.system_time(:second)

    report_entry = Map.merge(reportdata, %{stored_at: now})
    :ets.insert(table, {tenant_key, report_entry})

    :telemetry.execute(
      [:indrajaal, :communication, :analytics, :report_stored],
      %{timestamp: now},
      %{tenant_id: reportdata.tenantid, report_type: reportdata.report_type}
    )

    Logger.info("Performance report stored for tenant #{reportdata.tenantid}")
    :ok
  end

  # Utility functions
  defp build_time_clause(timeframe) do
    case timeframe do
      "1h" -> ">= NOW()-INTERVAL '1 hour'"
      "24h" -> ">= NOW()-INTERVAL '24 hours'"
      "7d" -> ">= NOW()-INTERVAL '7 days'"
      "30d" -> ">= NOW()-INTERVAL '30 days'"
      _ -> ">= NOW()-INTERVAL '24 hours'"
    end
  end

  defp determine_engagement_level(score) when score >= 70, do: "high"
  defp determine_engagement_level(score) when score >= 40, do: "medium"
  defp determine_engagement_level(score) when score >= 20, do: "low"
  defp determine_engagement_level(_score), do: "very_low"

  defp calculate_reliability_score(deliveryrate, bounce_rate) do
    max(0, min(100, deliveryrate - bounce_rate * 2))
  end

  defp determine_prediction_confidence(message_count) when message_count >= 100, do: "high"
  defp determine_prediction_confidence(message_count) when message_count >= 20, do: "medium"
  defp determine_prediction_confidence(_message_count), do: "low"

  defp predict_open_probability(useropen_rate, channel_delivery_rate) do
    (useropen_rate * 0.7 + channel_delivery_rate / 100 * 0.3) * 100
  end

  defp predict_click_probability(userclick_rate, engagement_score) do
    (userclick_rate * 0.8 + engagement_score / 100 * 0.2) * 100
  end

  defp calculate_percentage_change(current, previous) when previous > 0 do
    (current - previous) / previous * 100
  end

  defp calculate_percentage_change(_current, _previous), do: 0

  defp determine_system_health(sent, delivered, failed, engagement) do
    delivery_rate = if sent > 0, do: delivered / sent * 100, else: 100
    failure_rate = if sent > 0, do: failed / sent * 100, else: 0

    cond do
      delivery_rate >= 95 and engagement >= 50 and failure_rate <= 2 -> "excellent"
      delivery_rate >= 90 and engagement >= 30 and failure_rate <= 5 -> "good"
      delivery_rate >= 80 and engagement >= 20 and failure_rate <= 10 -> "fair"
      true -> "poor"
    end
  end

  # GenServer message handlers
  @spec handle_info(term(), term()) :: term()
  def handle_info(:process_analytics, state) do
    start_ts = System.monotonic_time(:millisecond)

    try do
      # Refresh analytics cache by expiring entries older than 10 minutes
      now = System.system_time(:second)
      cutoff = now - 600

      fresh_cache =
        Enum.reject(state.analytics_cache, fn {_key, %{cached_at: cached_at}} ->
          cached_at < cutoff
        end)
        |> Map.new()

      elapsed = System.monotonic_time(:millisecond) - start_ts

      :telemetry.execute(
        [:indrajaal, :communication, :analytics, :processed],
        %{
          duration_ms: elapsed,
          cache_entries_evicted: map_size(state.analytics_cache) - map_size(fresh_cache)
        },
        %{}
      )

      {:noreply, %{state | analytics_cache: fresh_cache}}
    rescue
      err ->
        Logger.error("process_analytics error: #{inspect(err)}")
        {:noreply, state}
    end
  end

  @spec handle_info(term(), term()) :: term()
  def handle_info(:optimize_delivery, state) do
    start_ts = System.monotonic_time(:millisecond)

    try do
      # Rebuild optimization rules from current ETS engagement data
      table = ensure_engagement_ets()
      all_entries = :ets.tab2list(table)

      # Compute per-channel average engagement scores from recent profiles
      channel_scores =
        Enum.reduce(all_entries, %{}, fn
          {{_tid, _uid, channel}, %{last_score: score}}, acc when is_binary(channel) ->
            Map.update(acc, channel, [score], &[score | &1])

          _, acc ->
            acc
        end)

      # Build per-channel optimal send windows (simple heuristic: high-engagement channels get priority)
      channel_priorities =
        Enum.map(channel_scores, fn {ch, scores} ->
          avg = Enum.sum(scores) / max(length(scores), 1)
          {ch, Float.round(avg, 2)}
        end)
        |> Enum.sort_by(&elem(&1, 1), :desc)

      elapsed = System.monotonic_time(:millisecond) - start_ts

      :telemetry.execute(
        [:indrajaal, :communication, :delivery, :optimized],
        %{duration_ms: elapsed, channels_analyzed: length(channel_priorities)},
        %{}
      )

      {:noreply, %{state | last_optimization: DateTime.utc_now()}}
    rescue
      err ->
        Logger.error("optimize_delivery error: #{inspect(err)}")
        {:noreply, %{state | last_optimization: DateTime.utc_now()}}
    end
  end

  @spec handle_info(term(), term()) :: term()
  def handle_info(:generate_insights, state) do
    start_ts = System.monotonic_time(:millisecond)

    try do
      # Collect aggregate stats from ETS engagement table
      table = ensure_engagement_ets()
      all_entries = :ets.tab2list(table)

      total_profiles =
        Enum.count(all_entries, fn
          {{_tid, uid, _ch}, _} when is_binary(uid) -> true
          _ -> false
        end)

      low_engagement =
        Enum.count(all_entries, fn
          {{_tid, uid, _ch}, %{last_score: s}} when is_binary(uid) -> s < 20
          _ -> false
        end)

      elapsed = System.monotonic_time(:millisecond) - start_ts

      :telemetry.execute(
        [:indrajaal, :communication, :insights, :generated],
        %{
          duration_ms: elapsed,
          total_profiles: total_profiles,
          low_engagement_count: low_engagement
        },
        %{}
      )

      {:noreply, state}
    rescue
      err ->
        Logger.error("generate_insights error: #{inspect(err)}")
        {:noreply, state}
    end
  end

  defp ensure_engagement_ets do
    table = :message_delivery_engagement

    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:named_table, :public, :set])
      _ -> table
    end
  rescue
    ArgumentError -> :message_delivery_engagement
  end
end
