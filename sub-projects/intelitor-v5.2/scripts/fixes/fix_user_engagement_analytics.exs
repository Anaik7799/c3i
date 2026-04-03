#!/usr/bin/env elixir

defmodule UserEngagementAnalyticsFixer do
  @moduledoc """
  Fix all variable name mismatches in user_engagement_analytics.ex
  """

  def fix_file do
    file_path = "lib/indrajaal/communication/user_engagement_analytics.ex"
    content = File.read!(file_path)

    fixes = [
      # Fix parameter name mismatches in track_engagement_event function
      {"__user_id", "user_id"},
      {"__eventdata", "__event_data"},
      {"tenant_id", "tenantid"},

      # Fix parameter name mismatches in generate_user_segments function
      {"segmentation_criteria", "segmentationcriteria"},
      {"segments", "user_segments"},
      {"__user", "user"},

      # Fix other undefined variables
      {"__state", "state"}
    ]

    # Apply fixes systematically but only where they would be incorrect
    fixed_content = content

    # First, let's read the specific problem areas and fix them manually
    lines = String.split(content, "\n")

    # Fix line 210: tenant_id should be tenantid
    fixed_lines = Enum.map(lines, fn line ->
      cond do
        # Fix line 210: tenant_id should be tenantid in track_engagement_event
        String.contains?(line, "tenant_id: tenant_id,") ->
          String.replace(line, "tenant_id: tenant_id,", "tenant_id: tenantid,")

        # Fix line 211: __eventdata should be __event_data
        String.contains?(line, "__eventdata.message_id") ->
          String.replace(line, "__eventdata.message_id", "__event_data.message_id")

        # Fix line 212: __user_id should be user_id in track_engagement_event
        String.contains?(line, "__user_id: __user_id,") ->
          String.replace(line, "__user_id: __user_id,", "__user_id: user_id,")

        # Fix line 205: tenant_id should be tenantid and __user_id should be user_id
        String.contains?(line, "trigger_personalization_update(tenant_id, __user_id") ->
          String.replace(line, "trigger_personalization_update(tenant_id, __user_id", "trigger_personalization_update(tenantid, user_id")

        # Fix line 232: segmentation_criteria should be segmentationcriteria
        String.contains?(line, "build_segmentation_query(segmentation_criteria)") ->
          String.replace(line, "build_segmentation_query(segmentation_criteria)", "build_segmentation_query(segmentationcriteria)")

        # Fix line 313: tenant_id should be tenantid in generate_user_segments
        String.contains?(line, "case Repo.query(query, [tenant_id]) do") ->
          String.replace(line, "case Repo.query(query, [tenant_id]) do", "case Repo.query(query, [tenantid]) do")

        # Fix line 328: segments should be user_segments and __user should be user
        String.contains?(line, "segment_groups = Enum.group_by(segments, fn user -> __user[") ->
          String.replace(line, "segment_groups = Enum.group_by(segments, fn user -> __user[", "segment_groups = Enum.group_by(user_segments, fn user -> user[")

        # Fix line 331: segments should be user_segments
        String.contains?(line, "total_users_analyzed: length(segments)") ->
          String.replace(line, "total_users_analyzed: length(segments)", "total_users_analyzed: length(user_segments)")

        # Fix line 337: segments should be user_segments
        String.contains?(line, "length(__users) / length(segments)") ->
          String.replace(line, "length(__users) / length(segments)", "length(users) / length(user_segments)")

        # Fix line 340: __user should be user
        String.contains?(line, "acc + (__user[\"avg_engagement_score\"]") ->
          String.replace(line, "acc + (__user[\"avg_engagement_score\"]", "acc + (user[\"avg_engagement_score\"]")

        # Fix line 349: tenant_id should be tenantid and segments should be user_segments
        String.contains?(line, "store_user_segments(tenant_id, segments)") ->
          String.replace(line, "store_user_segments(tenant_id, segments)", "store_user_segments(tenantid, user_segments)")

        # Fix line 351: segments should be user_segments
        String.contains?(line, "{:ok, segments}") ->
          String.replace(line, "{:ok, segments}", "{:ok, user_segments}")

        true ->
          line
      end
    end)

    # We also need to declare user_segments variable properly
    fixed_lines = Enum.map(fixed_lines, fn line ->
      if String.contains?(line, "case Repo.query(query, [tenantid]) do") do
        # Add the declaration of user_segments before this line
        line
      else
        line
      end
    end)

    # Need to insert user_segments declaration right after query execution
    line_index = Enum.find_index(fixed_lines, &String.contains?(&1, "case Repo.query(query, [tenantid]) do"))

    if line_index do
      # Insert user_segments declaration after successful query
      {before, after_lines} = Enum.split(fixed_lines, line_index + 1)

      # Find the line with successful result pattern
      success_line_index = Enum.find_index(after_lines, &String.contains?(&1, "{:ok, %{rows:"))

      if success_line_index do
        {success_before, success_after} = Enum.split(after_lines, success_line_index + 1)

        # Add user_segments declaration
        user_segments_line = "        user_segments = result.rows"

        fixed_lines = before ++ success_before ++ [user_segments_line] ++ success_after
      else
        fixed_lines
      end
    else
      fixed_lines
    end

    final_content = Enum.join(fixed_lines, "\n")

    File.write!(file_path, final_content)
    IO.puts("✅ Fixed user_engagement_analytics.ex variable mismatches")
  end
end

UserEngagementAnalyticsFixer.fix_file()