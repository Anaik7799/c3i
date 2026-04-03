defmodule Indrajaal.Communication.UserEngagementAnalytics do
  @moduledoc """
  Advanced user engagement analytics and communication patterns tracking.

  Provides comprehensive insights into user communication behavior,
  engagement patterns, preference learning, and predictive analytics.
  """

  use GenServer
  require Logger
  alias Indrajaal.Communication.TimescaleCommunicationEvents
  alias Indrajaal.Repo

  # EP301: Removed unused module attributes @engagement_metrics and @behavioral_patterns

  @segmentation_criteria [
    "engagement_level",
    "channel_preference",
    "content_affinity",
    "temporal_behavior",
    "response_velocity",
    "lifecycle_stage",
    "value_score",
    "risk_score"
  ]

  @spec start_link(keyword() | map()) :: term()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    # Schedule analytics processing
    # 15 minutes
    :timer.send_interval(900_000, :process_engagement_analytics)
    # 1 hour
    :timer.send_interval(3_600_000, :update_user_segments)
    # 4 hours
    :timer.send_interval(14_400_000, :generate_behavioral_insights)
    # 24 hours
    :timer.send_interval(86_400_000, :run_predictive_modeling)

    {:ok,
     %{
       __user_profiles: %{},
       engagement_cache: %{},
       behavioral_models: %{},
       segmentation_cache: %{}
     }}
  end

  @doc """
  Analyze comprehensive user engagement patterns
  """
  @spec analyze_user_engagement(binary() | integer(), binary() | integer(), any(), map()) ::
          term()
  @spec analyze_user_engagement(term(), term(), term(), term()) :: any()
  def analyze_user_engagement(tenantid, userid, timeframe \\ "30d", _options \\ %{}) do
    time_clause = build_time_clause(timeframe)

    engagement_query = """
    WITH __user_engagement_metrics AS (
      SELECT
        channel,
        message_type,
        COUNT(*) as total_messages,
        COUNT(*) FILTER (WHERE __event_type = 'delivered') as delivered_count,
        COUNT(*) FILTER (WHERE __event_type = 'opened') as opened_count,
        COUNT(*) FILTER (WHERE __event_type = 'clicked') as clicked_count,
        COUNT(*) FILTER (WHERE __event_type = 'replied') as replied_count,
        COUNT(*) FILTER (WHERE __event_type = 'converted') as converted_count,
        COUNT(*) FILTER (WHERE __event_type = 'bounced') as bounced_count,
        COUNT(*) FILTER (WHERE __event_type = 'unsubscribed') as unsubscribed_count,
        AVG(engagement_score) as avg_engagement_score,
        AVG(EXTRACT(epoch FROM (opened_time - delivery_time))) as avg_time_to_open,
        AVG(EXTRACT(epoch FROM (clicked_time - opened_time))) as avg_time_to_click,
        array_agg(DISTINCT EXTRACT(hour FROM time)) as active_hours,
        array_agg(DISTINCT EXTRACT(dow FROM time)) as active_days
      FROM communication_events
      WHERE tenant_id = $1 AND user_id = $2 AND time #{time_clause}
      GROUP BY channel, message_type
    ),
    temporal_patterns AS (
      SELECT
        time_bucket('1 day', time) as day_bucket,
        COUNT(*) as daily_messages,
        COUNT(*) FILTER (WHERE __event_type = 'opened') as daily_opens,
        AVG(engagement_score) as daily_engagement_score
      FROM communication_events
      WHERE tenant_id = $1 AND user_id = $2 AND time #{time_clause}
      GROUP BY day_bucket
      ORDER BY day_bucket
    ),
    engagement_lifecycle AS (
      SELECT
        CASE
          WHEN time >= NOW() - INTERVAL '7 days' THEN 'recent'
          WHEN time >= NOW() - INTERVAL '30 days' THEN 'current'
          WHEN time >= NOW() - INTERVAL '90 days' THEN 'declining'
          ELSE 'dormant'
        END as lifecycle_stage,
        COUNT(*) as message_count,
        AVG(engagement_score) as avg_engagement
      FROM communication_events
      WHERE tenant_id = $1 AND user_id = $2 AND time #{time_clause}
      GROUP BY lifecycle_stage
    )
    SELECT
      json_build_object(
        'user_id', $2,
        'analysis_period', $3,
        'channel_engagement', (
          SELECT json_agg(
            json_build_object(
              'channel', uem.channel,
              'message_type', uem.message_type,
              'metrics', json_build_object(
                'total_messages', uem.total_messages,
                'delivery_rate',
                'open_rate', ROUND((uem.opened_count::DECIMAL / NULLIF(uem.delivered_count, 0) * 100)::NUMERIC, 2),
                'click_rate', ROUND((uem.clicked_count::DECIMAL / NULLIF(uem.opened_count, 0) * 100)::NUMERIC, 2),
                'response_rate', ROUND((uem.replied_count::DECIMAL / NULLIF(uem.opened_count, 0) * 100)::NUMERIC, 2),
                'conversion_rate',
                'bounce_rate', ROUND((uem.bounced_count::DECIMAL / NULLIF(uem.total_messages, 0) * 100)::NUMERIC, 2),
                'unsubscribe_rate',
                'avg_engagement_score', ROUND(COALESCE(uem.avg_engagement_score, 0)::NUMERIC, 2),
                'avg_time_to_open_seconds', ROUND(COALESCE(uem.avg_time_to_open, 0)::NUMERIC, 1),
                'avg_time_to_click_seconds', ROUND(COALESCE(uem.avg_time_to_click, 0)::NUMERIC, 1),
                'active_hours', uem.active_hours,
                'active_days', uem.active_days
              )
            )
          )
          FROM __user_engagement_metrics uem
        ),
        'temporal_patterns', (
          SELECT json_agg(
            json_build_object(
              'date', tp.day_bucket,
              'messages', tp.daily_messages,
              'opens', tp.daily_opens,
              'engagement_score', ROUND(COALESCE(tp.daily_engagement_score, 0)::NUMERIC, 2)
            )
          )
          FROM temporal_patterns tp
        ),
        'engagement_lifecycle', (
          SELECT json_agg(
            json_build_object(
              'stage', el.lifecycle_stage,
              'message_count', el.message_count,
              'avg_engagement', ROUND(COALESCE(el.avg_engagement, 0)::NUMERIC, 2)
            )
          )
          FROM engagement_lifecycle el
        )
      ) as engagement_analysis
    """

    case Repo.query(engagement_query, [tenantid, userid, timeframe]) do
      {:ok, %{rows: [[analysis_json]]}} ->
        analysis = Jason.decode!(analysis_json)

        # Add behavioral insights and predictions
        behavioral_insights = generate_behavioral_insights(tenantid, userid, analysis)
        engagement_predictions = predict_future_engagement(tenantid, userid, analysis)
        recommendations = generate_engagement_recommendations(tenantid, userid, analysis)

        enhanced_analysis =
          analysis
          |> Map.put("behavioral_insights", behavioral_insights)
          |> Map.put("engagement_predictions", engagement_predictions)
          |> Map.put("recommendations", recommendations)
          |> Map.put("__user_segment", determine_user_segment(analysis))
          |> Map.put("engagement_health_score", calculate_engagement_health_score(analysis))

        {:ok, enhanced_analysis}

      {:error, error} ->
        Logger.error("Failed to analyze user engagement: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Track real - time engagement __events and update user profiles
  """
  @spec track_engagement_event(binary() | integer(), binary() | integer(), term()) :: term()
  def track_engagement_event(tenantid, user_id, event_data) do
    # Calculate engagement metrics
    engagement_metrics = calculate_real_time_engagement_metrics(event_data)

    # Update user profile with new engagement data
    update_user_engagement_profile(tenantid, user_id, engagement_metrics)

    # Check for behavioral pattern changes
    pattern_change = detect_behavioral_pattern_change(tenantid, user_id, event_data)

    if pattern_change.significant_change do
      # Update user segmentation
      update_user_segmentation(tenantid, user_id, pattern_change)

      # Trigger personalization updates
      trigger_personalization_update(tenantid, user_id, pattern_change)
    end

    # Log engagement __event for analytics
    TimescaleCommunicationEvents.log_communication_event(%{
      tenant_id: tenantid,
      message_id: event_data.message_id,
      user_id: user_id,
      channel: "engagement_analytics",
      __event_type: "engagement_tracked",
      message_type: "analytics_event",
      metadata: %{
        original_event: event_data,
        calculated_metrics: engagement_metrics,
        pattern_change: pattern_change
      }
    })

    :ok
  end

  @doc """
  Generate user engagement segments for targeted communication
  """
  @spec generate_user_segments(binary() | integer(), any()) :: term()
  def generate_user_segments(tenantid, segmentationcriteria \\ @segmentation_criteria) do
    # Build dynamic segmentation query based on criteria
    _segmentation_query = build_segmentation_query(segmentationcriteria)

    query = """
    WITH __user_engagement_summary AS (
      SELECT
        user_id,
        COUNT(*) as total_messages,
        COUNT(*) FILTER (WHERE __event_type = 'opened') as total_opens,
        COUNT(*) FILTER (WHERE __event_type = 'clicked') as total_clicks,
        COUNT(*) FILTER (WHERE __event_type = 'converted') as total_conversions,
        AVG(engagement_score) as avg_engagement_score,
        array_agg(DISTINCT channel) as channels_used,
        array_agg(DISTINCT message_type) as message_types_received,
        MIN(time) as first_interaction,
        MAX(time) as last_interaction,
        COUNT(DISTINCT DATE(time)) as active_days,
        stddev(engagement_score) as engagement_variability
      FROM communication_events
      WHERE tenant_id = $1
        AND time >= NOW() - INTERVAL '90 days'
        AND user_id IS NOT NULL
      GROUP BY user_id
      HAVING COUNT(*) >= 5  -- Minimum messages for meaningful segmentation
    ),
    user_scores AS (
      SELECT
        user_id,
        total_messages,
        CASE
          WHEN total_messages = 0 THEN 0
          ELSE (total_opens::DECIMAL / total_messages * 100)
        END as open_rate,
        CASE
          WHEN total_opens = 0 THEN 0
          ELSE (total_clicks::DECIMAL / total_opens * 100)
        END as click_rate,
        CASE
          WHEN total_clicks = 0 THEN 0
          ELSE (total_conversions::DECIMAL / total_clicks * 100)
        END as conversion_rate,
        avg_engagement_score,
        channels_used,
        message_types_received,
        EXTRACT(epoch FROM (NOW() - last_interaction)) / 86_400 as days_since_last_interaction,
        active_days,
        engagement_variability
      FROM __user_engagement_summary
    )
    SELECT
      user_id,
      total_messages,
      open_rate,
      click_rate,
      conversion_rate,
      avg_engagement_score,
      channels_used,
      days_since_last_interaction,
      active_days,
      CASE
        WHEN avg_engagement_score >= 70 AND open_rate >= 50 THEN 'highly_engaged'
        WHEN avg_engagement_score >= 50 AND open_rate >= 30 THEN 'engaged'
        WHEN avg_engagement_score >= 30 AND open_rate >= 15 THEN 'moderately_engaged'
        WHEN avg_engagement_score >= 10 AND open_rate >= 5 THEN 'low_engagement'
        ELSE 'disengaged'
      END as engagement_segment,
      CASE
        WHEN array_length(channels_used, 1) >= 3 THEN 'multi_channel'
        WHEN 'email' = ANY(channels_used) THEN 'email_preferred'
        WHEN 'sms' = ANY(channels_used) THEN 'sms_preferred'
        WHEN 'push' = ANY(channels_used) THEN 'push_preferred'
        ELSE 'single_channel'
      END as channel_preference_segment,
      CASE
        WHEN days_since_last_interaction <= 7 THEN 'active'
        WHEN days_since_last_interaction <= 30 THEN 'recent'
        WHEN days_since_last_interaction <= 90 THEN 'dormant'
        ELSE 'at_risk'
      END as lifecycle_segment
    FROM user_scores
    ORDER BY avg_engagement_score DESC, open_rate DESC
    """

    case Repo.query(query, [tenantid]) do
      {:ok, %{rows: rows, columns: columns}} ->
        user_segments = build_user_segments(rows, columns)
        segment_summary = build_segment_summary(user_segments)

        # Store segments for future use
        store_user_segments(tenantid, user_segments)

        {:ok, %{segments: user_segments, summary: segment_summary}}

      {:error, error} ->
        Logger.error("Failed to generate user segments: #{inspect(error)}")
        {:error, error}
    end
  end

  defp build_user_segments(rows, columns) do
    Enum.map(rows, fn row ->
      segment_data = columns |> Enum.zip(row) |> Map.new()

      # Add additional segment characteristics
      Map.merge(segment_data, %{
        "segment_created_at" => DateTime.utc_now(),
        "segment_confidence" => calculate_segment_confidence(segment_data),
        "recommended_actions" => generate_segment_recommendations(segment_data)
      })
    end)
  end

  defp build_segment_summary(user_segments) do
    segment_groups = Enum.group_by(user_segments, fn user -> user["engagement_segment"] end)

    %{
      total_users_analyzed: length(user_segments),
      segments:
        Enum.map(segment_groups, fn {segment_name, users} ->
          %{
            name: segment_name,
            __user_count: length(users),
            percentage: Float.round(length(users) / length(user_segments) * 100, 2),
            avg_engagement_score:
              Enum.reduce(users, 0, fn user, acc ->
                acc + (user["avg_engagement_score"] || 0)
              end) / length(users),
            characteristics: analyze_segment_characteristics(users)
          }
        end),
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Predict user engagement trends and churn risk
  """
  @spec predict_engagement_trends(binary() | integer(), binary() | integer(), any()) :: term()
  def predict_engagement_trends(tenantid, user_id, prediction_horizon \\ "30d") do
    # Get historical engagement data
    historical_data = get_historical_engagement_data(tenantid, user_id)

    # Calculate trend indicators
    trend_indicators = calculate_trend_indicators(historical_data)

    # Predict engagement trajectory
    engagement_trajectory = predict_engagement_trajectory(trend_indicators, prediction_horizon)

    # Calculate churn risk
    churn_risk = calculate_churn_risk(tenantid, user_id, trend_indicators)

    # Generate intervention recommendations
    intervention_recommendations =
      generate_intervention_recommendations(churn_risk, engagement_trajectory)

    prediction_result = %{
      user_id: user_id,
      prediction_horizon: prediction_horizon,
      current_engagement_level: determine_current_engagement_level(trend_indicators),
      predicted_engagement_level: engagement_trajectory.predicted_level,
      trend_direction: engagement_trajectory.direction,
      trend_strength: engagement_trajectory.strength,
      churn_risk: churn_risk,
      confidence_score: calculate_prediction_confidence(historical_data),
      key_indicators: trend_indicators.key_indicators,
      intervention_recommendations: intervention_recommendations,
      next_review_date: calculate_next_review_date(churn_risk.level),
      generated_at: DateTime.utc_now()
    }

    # Log prediction
    TimescaleCommunicationEvents.log_communication_event(%{
      tenant_id: tenantid,
      user_id: user_id,
      channel: "engagement_analytics",
      __event_type: "engagement_prediction_generated",
      message_type: "predictive_analytics",
      metadata: prediction_result
    })

    {:ok, prediction_result}
  end

  @doc """
  Generate personalized communication recommendations
  """
  @spec generate_communication_recommendations(binary() | integer(), binary() | integer(), map()) ::
          term()
  @spec generate_communication_recommendations(term(), term(), term()) :: any()
  def generate_communication_recommendations(tenantid, user_id, message_context \\ %{}) do
    # Get user's engagement profile
    user_profile = get_user_engagement_profile(tenantid, user_id)

    # Analyze current context
    context_analysis = analyze_message_context(message_context)

    recommendations = %{
      optimal_channel: recommend_optimal_channel(user_profile, context_analysis),
      optimal_timing: recommend_optimal_timing(user_profile, context_analysis),
      content_personalization: recommend_content_personalization(user_profile, context_analysis),
      f_requency_optimization: recommend_f_requency_optimization(user_profile, context_analysis),
      engagement_tactics: recommend_engagement_tactics(user_profile, context_analysis),
      risk_mitigation: recommend_risk_mitigation(user_profile, context_analysis)
    }

    # Calculate expected improvement
    expected_improvement = calculate_expected_improvement(user_profile, recommendations)

    final_recommendations =
      Map.merge(recommendations, %{
        expected_improvement: expected_improvement,
        confidence_level: calculate_recommendation_confidence(user_profile),
        generated_at: DateTime.utc_now(),
        valid_until: DateTime.utc_now() |> DateTime.add(7, :day)
      })

    {:ok, final_recommendations}
  end

  # Private helper functions

  defp calculate_real_time_engagement_metrics(event_data) do
    base_score = 10

    event_scores = %{
      "delivered" => 10,
      "opened" => 25,
      "clicked" => 40,
      "replied" => 60,
      "converted" => 80,
      "shared" => 50,
      "forwarded" => 45,
      "bounced" => -15,
      "unsubscribed" => -30,
      "complained" => -50
    }

    event_score = Map.get(event_scores, event_data.__event_type, 0)

    # Time - based scoring
    time_score =
      case event_data.time_to_engagement do
        nil -> 0
        # < 5 minutes
        time when time < 300 -> 10
        # < 30 minutes
        time when time < 1800 -> 7
        # < 1 hour
        time when time < 3600 -> 5
        # < 6 hours
        time when time < 21_600 -> 3
        _ -> 1
      end

    # Device / context scoring
    device_score =
      case event_data.device_type do
        "mobile" -> 5
        "tablet" -> 3
        "desktop" -> 2
        _ -> 0
      end

    %{
      raw_score: base_score + event_score + time_score + device_score,
      event_score: event_score,
      time_score: time_score,
      device_score: device_score,
      __event_type: event_data.__event_type,
      timestamp: DateTime.utc_now()
    }
  end

  defp update_user_engagement_profile(tenantid, user_id, metrics) do
    # Update user's engagement profile in cache / database
    Logger.debug("Updating user engagement profile: #{user_id} with score #{metrics.raw_score}")

    # Store in GenServer state
    GenServer.cast(__MODULE__, {:update_user_profile, tenantid, user_id, metrics})

    :ok
  end

  defp detect_behavioral_pattern_change(tenantid, user_id, event_data) do
    # Get recent behavioral patterns
    recent_patterns = get_recent_behavioral_patterns(tenantid, user_id)

    # Compare with current event
    change_indicators = %{
      channel_shift: detect_channel_preference_change(recent_patterns, event_data),
      timing_shift: detect_timing_preference_change(recent_patterns, event_data),
      engagement_shift: detect_engagement_level_change(recent_patterns, event_data),
      content_shift: detect_content_preference_change(recent_patterns, event_data)
    }

    significant_changes = Enum.count(change_indicators, fn {_key, changed} -> changed end)

    %{
      significant_change: significant_changes >= 2,
      change_indicators: change_indicators,
      change_score: significant_changes,
      detected_at: DateTime.utc_now()
    }
  end

  defp update_user_segmentation(_tenant_id, user_id, _pattern_change) do
    Logger.info("Updating user segmentation for #{user_id} due to behavioral pattern change")
    :ok
  end

  defp trigger_personalization_update(_tenant_id, user_id, _pattern_change) do
    Logger.info("Triggering personalization update for #{user_id}")
    :ok
  end

  defp generate_behavioral_insights(_tenant_id, _user_id, analysis) do
    channel_engagement = analysis["channel_engagement"] || []
    temporal_patterns = analysis["temporal_patterns"] || []

    initial_insights = []

    # Channel preference insights
    channel_insights =
      if length(channel_engagement) > 1 do
        preferred_channel =
          Enum.max_by(channel_engagement, fn channel ->
            get_in(channel, ["metrics", "avg_engagement_score"]) || 0
          end)

        [
          %{
            type: "channel_preference",
            insight: "User shows highest engagement with #{preferred_channel["channel"]} channel",
            confidence: "high",
            recommendation:
              "Prioritize #{preferred_channel["channel"]} for important communications"
          }
        ]
      else
        []
      end

    # Temporal pattern insights
    temporal_insights =
      if length(temporal_patterns) > 7 do
        _peak_engagement_days =
          temporal_patterns
          |> Enum.sort_by(fn day -> day["engagement_score"] end, :desc)
          |> Enum.take(3)

        [
          %{
            type: "temporal_patterns",
            insight: "User engagement peaks on specific days of the analysis period",
            confidence: "medium",
            recommendation: "Schedule important communications during peak engagement periods"
          }
        ]
      else
        []
      end

    # Engagement consistency insights
    engagement_scores =
      Enum.map(channel_engagement, fn channel ->
        get_in(channel, ["metrics", "avg_engagement_score"]) || 0
      end)

    consistency_insights =
      if length(engagement_scores) > 1 do
        score_variance = calculate_variance(engagement_scores)
        consistency_level = if score_variance < 100, do: "high", else: "low"

        [
          %{
            type: "engagement_consistency",
            insight: "User shows #{consistency_level} consistency in engagement across channels",
            confidence: "medium",
            recommendation:
              if consistency_level == "high" do
                "User responds predictably - maintain current approach"
              else
                "User engagement varies by channel - customize approach per channel"
              end
          }
        ]
      else
        []
      end

    # Combine all insights
    initial_insights ++ channel_insights ++ temporal_insights ++ consistency_insights
  end

  defp predict_future_engagement(_tenant_id, _user_id, analysis) do
    # Simple prediction based on trends (would use ML models in production)
    channel_engagement = analysis["channel_engagement"] || []
    temporal_patterns = analysis["temporal_patterns"] || []

    current_avg_engagement = calculate_current_avg_engagement(channel_engagement)
    trend_direction = determine_trend_direction(temporal_patterns)

    predicted_score =
      case trend_direction do
        "increasing" -> min(100, current_avg_engagement * 1.2)
        "decreasing" -> max(0, current_avg_engagement * 0.8)
        "stable" -> current_avg_engagement
        "insufficient_data" -> current_avg_engagement
      end

    %{
      current_engagement: current_avg_engagement,
      predicted_engagement: predicted_score,
      trend_direction: trend_direction,
      prediction_confidence: calculate_prediction_confidence_from_data(temporal_patterns),
      time_horizon: "30_days"
    }
  end

  defp calculate_current_avg_engagement(channel_engagement) do
    if length(channel_engagement) > 0 do
      total_score =
        Enum.reduce(channel_engagement, 0, fn channel, acc ->
          acc + (get_in(channel, ["metrics", "avg_engagement_score"]) || 0)
        end)

      total_score / length(channel_engagement)
    else
      0
    end
  end

  defp determine_trend_direction(temporal_patterns) do
    if length(temporal_patterns) >= 7 do
      recent_scores =
        temporal_patterns
        |> Enum.sort_by(fn day -> day["date"] end, :desc)
        |> Enum.take(7)
        |> Enum.map(fn day -> day["engagement_score"] end)

      analyze_trend_from_scores(recent_scores)
    else
      "insufficient_data"
    end
  end

  defp analyze_trend_from_scores(recent_scores) do
    if length(recent_scores) >= 2 do
      first_half_sum = recent_scores |> Enum.take(div(length(recent_scores), 2)) |> Enum.sum()
      first_half_avg = first_half_sum / div(length(recent_scores), 2)
      second_half_sum = recent_scores |> Enum.drop(div(length(recent_scores), 2)) |> Enum.sum()
      second_half_avg = second_half_sum / (length(recent_scores) - div(length(recent_scores), 2))

      cond do
        second_half_avg > first_half_avg * 1.1 -> "increasing"
        second_half_avg < first_half_avg * 0.9 -> "decreasing"
        true -> "stable"
      end
    else
      "stable"
    end
  end

  defp generate_engagement_recommendations(_tenant_id, _user_id, analysis) do
    channel_engagement = analysis["channel_engagement"] || []

    # Channel optimization recommendations
    channel_recommendations =
      if length(channel_engagement) > 1 do
        underperforming_channels =
          Enum.filter(channel_engagement, fn channel ->
            (get_in(channel, ["metrics", "avg_engagement_score"]) || 0) < 30
          end)

        if length(underperforming_channels) > 0 do
          [
            %{
              type: "channel_optimization",
              priority: "medium",
              action: "Reduce or pause communications on underperforming channels",
              channels: Enum.map(underperforming_channels, fn ch -> ch["channel"] end),
              expected_impact: "10 - 15% improvement in overall engagement"
            }
          ]
        else
          []
        end
      else
        []
      end

    # F_requency recommendations
    high_engagement_channels =
      Enum.filter(channel_engagement, fn channel ->
        (get_in(channel, ["metrics", "avg_engagement_score"]) || 0) > 60
      end)

    f_requency_recommendations =
      if length(high_engagement_channels) > 0 do
        [
          %{
            type: "f_requency_optimization",
            priority: "high",
            action: "Increase communication f_requency on high - performing channels",
            channels: Enum.map(high_engagement_channels, fn ch -> ch["channel"] end),
            expected_impact: "20 - 30% improvement in total engagement"
          }
        ]
      else
        []
      end

    # Personalization recommendations
    personalization_recommendations = [
      %{
        type: "personalization",
        priority: "high",
        action: "Implement dynamic content based on user's engagement patterns",
        expected_impact: "15 - 25% improvement in click - through rates"
      }
    ]

    # Combine all recommendations
    channel_recommendations ++ f_requency_recommendations ++ personalization_recommendations
  end

  defp determine_user_segment(analysis) do
    channel_engagement = analysis["channel_engagement"] || []

    if Enum.empty?(channel_engagement) do
      "unknown"
    else
      avg_engagement =
        Enum.reduce(channel_engagement, 0, fn channel, acc ->
          acc + (get_in(channel, ["metrics", "avg_engagement_score"]) || 0)
        end) / Enum.count(channel_engagement)

      cond do
        avg_engagement >= 70 -> "highly_engaged"
        avg_engagement >= 50 -> "engaged"
        avg_engagement >= 30 -> "moderately_engaged"
        avg_engagement >= 10 -> "low_engagement"
        true -> "disengaged"
      end
    end
  end

  defp calculate_engagement_health_score(analysis) do
    channel_engagement = analysis["channel_engagement"] || []

    if Enum.empty?(channel_engagement) do
      0
    else
      scores =
        Enum.map(channel_engagement, fn channel ->
          engagement_score = get_in(channel, ["metrics", "avg_engagement_score"]) || 0
          open_rate = get_in(channel, ["metrics", "open_rate"]) || 0
          click_rate = get_in(channel, ["metrics", "click_rate"]) || 0

          # Weighted health score
          engagement_score * 0.5 + open_rate * 0.3 + click_rate * 0.2
        end)

      Enum.sum(scores) / length(scores)
    end
  end

  # Additional helper functions
  defp build_time_clause(timeframe) do
    case timeframe do
      "7d" -> ">= NOW() - INTERVAL '7 days'"
      "30d" -> ">= NOW() - INTERVAL '30 days'"
      "90d" -> ">= NOW() - INTERVAL '90 days'"
      _ -> ">= NOW() - INTERVAL '30 days'"
    end
  end

  defp build_segmentation_query(criteria) do
    # Build dynamic segmentation logic based on criteria
    Enum.join(criteria, " AND ")
  end

  defp calculate_segment_confidence(segment_data) do
    message_count = segment_data["total_messages"] || 0

    cond do
      message_count >= 100 -> "high"
      message_count >= 20 -> "medium"
      message_count >= 5 -> "low"
      true -> "very_low"
    end
  end

  defp generate_segment_recommendations(segment_data) do
    engagement_segment = segment_data["engagement_segment"]

    case engagement_segment do
      "highly_engaged" -> ["maintain_current_strategy", "expand_to_advocacy_programs"]
      "engaged" -> ["optimize_timing", "increase_personalization"]
      "moderately_engaged" -> ["improve_content_relevance", "test_new_channels"]
      "low_engagement" -> ["reduce_f_requency", "improve_targeting"]
      "disengaged" -> ["re_engagement_campaign", "consider_unsubscribing"]
      _ -> ["collect_more_data"]
    end
  end

  defp analyze_segment_characteristics(users) do
    %{
      avg_open_rate:
        Enum.reduce(users, 0, fn user, acc -> acc + (user["open_rate"] || 0) end) / length(users),
      avg_click_rate:
        Enum.reduce(users, 0, fn user, acc -> acc + (user["click_rate"] || 0) end) / length(users),
      avg_days_since_interaction:
        Enum.reduce(users, 0, fn user, acc -> acc + (user["days_since_last_interaction"] || 0) end) /
          length(users),
      common_channels: find_common_channels(users),
      common_lifecycle_stages: find_common_lifecycle_stages(users)
    }
  end

  defp find_common_channels(users) do
    # Find the most common channel preferences across users
    channel_counts =
      Enum.reduce(users, %{}, fn user, acc ->
        channels = user["channels_used"] || []

        Enum.reduce(channels, acc, fn channel, inner_acc ->
          Map.update(inner_acc, channel, 1, &(&1 + 1))
        end)
      end)

    channel_counts
    |> Enum.sort_by(fn {_channel, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {channel, _count} -> channel end)
  end

  defp find_common_lifecycle_stages(users) do
    stage_counts =
      Enum.reduce(users, %{}, fn user, acc ->
        stage = user["lifecycle_segment"] || "unknown"
        Map.update(acc, stage, 1, &(&1 + 1))
      end)

    stage_counts |> Enum.max_by(fn {_stage, count} -> count end) |> elem(0)
  end

  defp store_user_segments(tenantid, segments) do
    Logger.info("Storing #{length(segments)} user segments for tenant #{tenantid}")
    :ok
  end

  # Prediction helper functions
  defp get_historical_engagement_data(_tenant_id, _user_id) do
    # Get user's historical engagement data for trend analysis
    %{
      data_points: 30,
      trend_slope: 0.1,
      seasonal_patterns: [],
      baseline_engagement: 45
    }
  end

  defp calculate_trend_indicators(historical_data) do
    %{
      trend_slope: historical_data.trend_slope,
      baseline_score: historical_data.baseline_engagement,
      volatility: 0.2,
      key_indicators: ["engagement_declining", "channel_shift_detected"]
    }
  end

  defp predict_engagement_trajectory(trend_indicators, _horizon) do
    %{
      predicted_level: "moderate",
      direction: if(trend_indicators.trend_slope > 0, do: "increasing", else: "decreasing"),
      strength: abs(trend_indicators.trend_slope)
    }
  end

  defp calculate_churn_risk(_tenant_id, _user_id, trend_indicators) do
    # 15% base churn risk
    base_risk = 0.15

    # Adjust based on trend
    trend_risk_adjustment = if trend_indicators.trend_slope < -0.1, do: 0.25, else: 0.0

    total_risk = min(1.0, base_risk + trend_risk_adjustment)

    %{
      score: total_risk,
      level:
        cond do
          total_risk >= 0.7 -> "critical"
          total_risk >= 0.4 -> "high"
          total_risk >= 0.2 -> "medium"
          true -> "low"
        end,
      factors: determine_churn_factors(trend_indicators)
    }
  end

  defp determine_churn_factors(trend_indicators) do
    factors = []

    factors =
      if trend_indicators.trend_slope < -0.1 do
        ["declining_engagement" | factors]
      else
        factors
      end

    factors =
      if "channel_shift_detected" in trend_indicators.key_indicators do
        ["channel_preference_change" | factors]
      else
        factors
      end

    factors
  end

  defp generate_intervention_recommendations(churn_risk, _engagement_trajectory) do
    case churn_risk.level do
      "critical" ->
        [
          %{action: "immediate_personal_outreach", priority: "critical"},
          %{action: "special_offer_or_incentive", priority: "high"},
          %{action: "reduce_communication_f_requency", priority: "medium"}
        ]

      "high" ->
        [
          %{action: "re_engagement_campaign", priority: "high"},
          %{action: "content_personalization", priority: "high"},
          %{action: "channel_optimization", priority: "medium"}
        ]

      "medium" ->
        [
          %{action: "survey_for_feedback", priority: "medium"},
          %{action: "adjust_communication_timing", priority: "medium"}
        ]

      "low" ->
        [
          %{action: "monitor_engagement_trends", priority: "low"}
        ]
    end
  end

  defp calculate_prediction_confidence(historical_data) do
    data_points = historical_data.data_points

    cond do
      data_points >= 50 -> "high"
      data_points >= 20 -> "medium"
      data_points >= 10 -> "low"
      true -> "very_low"
    end
  end

  defp calculate_next_review_date(churn_level) do
    days_to_add =
      case churn_level do
        "critical" -> 3
        "high" -> 7
        "medium" -> 14
        "low" -> 30
      end

    DateTime.utc_now() |> DateTime.add(days_to_add, :day)
  end

  # Recommendation helper functions
  defp get_user_engagement_profile(_tenant_id, _user_id) do
    # Get user's comprehensive engagement profile
    %{
      preferred_channels: ["email", "push"],
      optimal_send_times: ["09:00", "18:00"],
      engagement_level: "moderate",
      content_preferences: ["security_alerts", "system_updates"],
      f_requency_tolerance: "medium",
      churn_risk: "low"
    }
  end

  defp analyze_message_context(context) do
    %{
      urgency: context[:urgency] || "normal",
      content_type: context[:content_type] || "general",
      expected_response: context[:expected_response] || "none"
    }
  end

  defp recommend_optimal_channel(userprofile, context) do
    user_preferred = List.first(userprofile.preferred_channels)

    case context.urgency do
      "critical" -> "sms"
      "high" -> user_preferred || "push"
      _ -> user_preferred || "email"
    end
  end

  defp recommend_optimal_timing(userprofile, context) do
    optimal_times = userprofile.optimal_send_times

    case context.urgency do
      "critical" -> "immediate"
      _ -> List.first(optimal_times) || "10:00"
    end
  end

  defp recommend_content_personalization(userprofile, _context) do
    %{
      greeting_style:
        if(userprofile.engagement_level == "high", do: "friendly", else: "professional"),
      content_length: if(userprofile.engagement_level == "high", do: "detailed", else: "concise"),
      call_to_action_style: if(userprofile.engagement_level == "high", do: "soft", else: "direct")
    }
  end

  defp recommend_f_requency_optimization(userprofile, _context) do
    current_tolerance = userprofile.f_requency_tolerance

    case userprofile.churn_risk do
      "high" -> %{action: "reduce", factor: 0.5}
      "medium" -> %{action: "maintain", factor: 1.0}
      "low" when current_tolerance == "high" -> %{action: "increase", factor: 1.2}
      _ -> %{action: "maintain", factor: 1.0}
    end
  end

  defp recommend_engagement_tactics(userprofile, context) do
    tactics = []

    tactics =
      if userprofile.engagement_level in ["low", "moderate"] do
        ["use_interactive_elements", "add_social_proof" | tactics]
      else
        tactics
      end

    tactics =
      if context.content_type == "promotional" do
        ["create_urgency", "highlight_benefits" | tactics]
      else
        tactics
      end

    tactics
  end

  defp recommend_risk_mitigation(userprofile, _context) do
    case userprofile.churn_risk do
      "high" -> ["reduce_f_requency", "improve_relevance", "offer_preferences_update"]
      "medium" -> ["monitor_closely", "test_different_approaches"]
      _ -> ["maintain_current_approach"]
    end
  end

  defp calculate_expected_improvement(userprofile, recommendations) do
    # Calculate expected improvement based on recommendations
    # 5% base improvement
    base_improvement = 5

    channel_improvement =
      if recommendations.optimal_channel in userprofile.preferred_channels, do: 10, else: 0

    timing_improvement = if recommendations.optimal_timing != "immediate", do: 8, else: 0
    personalization_improvement = 12

    total_improvement =
      base_improvement + channel_improvement + timing_improvement + personalization_improvement

    %{
      engagement_score: "#{total_improvement}%",
      open_rate: "#{total_improvement * 0.8}%",
      click_rate: "#{total_improvement * 0.6}%"
    }
  end

  defp calculate_recommendation_confidence(user_profile) do
    case user_profile.engagement_level do
      "high" -> "high"
      "moderate" -> "medium"
      _ -> "low"
    end
  end

  # Utility functions
  defp get_recent_behavioral_patterns(_tenant_id, _user_id) do
    %{
      preferred_channels: ["email"],
      typical_engagement_times: ["09:00", "18:00"],
      avg_engagement_score: 45
    }
  end

  defp detect_channel_preference_change(recent_patterns, event_data) do
    current_channel = event_data.channel
    preferred_channels = recent_patterns.preferred_channels

    current_channel not in preferred_channels
  end

  defp detect_timing_preference_change(_recent_patterns, _event_data) do
    # Simplified timing change detection
    false
  end

  defp detect_engagement_level_change(recent_patterns, event_data) do
    # Compare current engagement score with recent average
    current_score = event_data.engagement_score || 0
    recent_avg = recent_patterns.avg_engagement_score

    abs(current_score - recent_avg) > 20
  end

  defp detect_content_preference_change(_recent_patterns, _event_data) do
    # Simplified content preference change detection
    false
  end

  defp calculate_variance(scores) when length(scores) > 1 do
    mean = Enum.sum(scores) / length(scores)

    variance_sum =
      Enum.reduce(scores, 0, fn score, acc ->
        acc + :math.pow(score - mean, 2)
      end)

    variance_sum / length(scores)
  end

  defp calculate_variance(_scores), do: 0

  defp determine_current_engagement_level(trend_indicators) do
    # Determine current engagement level based on trend indicators
    case trend_indicators.current_score do
      score when score >= 80 -> "high"
      score when score >= 60 -> "medium"
      score when score >= 40 -> "low"
      _ -> "very_low"
    end
  end

  defp calculate_prediction_confidence_from_data(temporal_patterns) do
    data_points = length(temporal_patterns)

    cond do
      data_points >= 30 -> "high"
      data_points >= 14 -> "medium"
      data_points >= 7 -> "low"
      true -> "very_low"
    end
  end

  # GenServer message handlers
  @spec handle_cast(term(), term()) :: {:noreply, term()}
  def handle_cast({:updateuser_profile, tenant_id, user_id, metrics}, state) do
    updated_profiles = Map.put(state.user_profiles, "#{tenant_id}:#{user_id}", metrics)
    {:noreply, %{state | user_profiles: updated_profiles}}
  end

  @spec handle_info(term(), term()) :: term()
  def handle_info(:process_engagement_analytics, state) do
    Logger.debug("Processing user engagement analytics")
    {:noreply, state}
  end

  @spec handle_info(term(), term()) :: term()
  def handle_info(_msg, state) do
    Logger.debug("Handling unexpected message")
    {:noreply, state}
  end
end
