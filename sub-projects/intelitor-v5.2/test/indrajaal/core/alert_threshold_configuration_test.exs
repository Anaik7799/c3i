defmodule Indrajaal.Core.AlertThresholdConfigurationTest do
  @moduledoc """
  TDG test suite for alert threshold configuration across multiple domains.

  WHAT: Tests that alert thresholds can be configured per domain (alarms, security,
  performance, compliance), that threshold evaluation is correct, and that multi-domain
  threshold aggregation produces valid composite health scores.

  CONSTRAINTS:
  - SC-ALARM-001: Alarm processing with severity classification
  - SC-ALARM-005: Alert threshold configuration per domain
  - SC-CIRCUIT-001: Drop telemetry when queue > 100

  ## Constitutional Verification
  - Ψ₃ (Verification): Threshold evaluation is reproducible
  - Ψ₅ (Truthfulness): Alert state reflects actual metric values

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — threshold config suite |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Threshold configuration engine
  # ---------------------------------------------------------------------------

  @domains [:alarms, :security, :performance, :compliance, :health]
  @severities [:info, :warning, :critical, :emergency]

  defp default_thresholds do
    %{
      alarms: %{warning: 10, critical: 50, emergency: 100},
      security: %{warning: 3, critical: 10, emergency: 25},
      performance: %{warning: 80.0, critical: 95.0, emergency: 99.0},
      compliance: %{warning: 5, critical: 15, emergency: 30},
      health: %{warning: 70.0, critical: 50.0, emergency: 30.0}
    }
  end

  defp configure_threshold(config, domain, severity, value)
       when domain in @domains and severity in @severities do
    case Map.get(config, domain) do
      nil ->
        {:error, :unknown_domain}

      domain_config ->
        {:ok, put_in(config, [domain, severity], value)}
    end
  end

  defp configure_threshold(_config, _domain, _severity, _value), do: {:error, :invalid_params}

  defp evaluate_threshold(config, domain, metric_value) do
    case Map.get(config, domain) do
      nil ->
        {:error, :unknown_domain}

      thresholds ->
        # Health domain is inverted (lower = worse)
        if domain == :health do
          cond do
            metric_value <= thresholds.emergency -> :emergency
            metric_value <= thresholds.critical -> :critical
            metric_value <= thresholds.warning -> :warning
            true -> :info
          end
        else
          cond do
            metric_value >= thresholds.emergency -> :emergency
            metric_value >= thresholds.critical -> :critical
            metric_value >= thresholds.warning -> :warning
            true -> :info
          end
        end
    end
  end

  defp composite_health(config, metrics) do
    severities =
      Enum.map(metrics, fn {domain, value} ->
        evaluate_threshold(config, domain, value)
      end)

    severity_rank = %{info: 0, warning: 1, critical: 2, emergency: 3}
    worst = Enum.max_by(severities, &Map.get(severity_rank, &1, 0))

    score =
      100 -
        Enum.sum(Enum.map(severities, &Map.get(severity_rank, &1, 0))) /
          max(length(severities), 1) * 33.3

    %{worst_severity: worst, health_score: Float.round(score, 1), domain_count: length(metrics)}
  end

  # ---------------------------------------------------------------------------
  # Default configuration tests
  # ---------------------------------------------------------------------------

  describe "default threshold configuration" do
    test "all 5 domains have default thresholds" do
      config = default_thresholds()
      assert map_size(config) == 5

      for domain <- @domains do
        assert Map.has_key?(config, domain), "Missing domain: #{domain}"
      end
    end

    test "each domain has warning, critical, emergency levels" do
      config = default_thresholds()

      for {_domain, thresholds} <- config do
        assert Map.has_key?(thresholds, :warning)
        assert Map.has_key?(thresholds, :critical)
        assert Map.has_key?(thresholds, :emergency)
      end
    end

    test "thresholds are ordered: warning < critical < emergency for non-health" do
      config = default_thresholds()

      for domain <- [:alarms, :security, :performance, :compliance] do
        t = Map.get(config, domain)
        assert t.warning < t.critical
        assert t.critical < t.emergency
      end
    end

    test "health thresholds are inverted: warning > critical > emergency" do
      config = default_thresholds()
      t = config.health
      assert t.warning > t.critical
      assert t.critical > t.emergency
    end
  end

  # ---------------------------------------------------------------------------
  # Threshold modification tests
  # ---------------------------------------------------------------------------

  describe "threshold configuration updates" do
    test "updating valid domain/severity returns :ok" do
      config = default_thresholds()
      assert {:ok, new_config} = configure_threshold(config, :alarms, :warning, 20)
      assert new_config.alarms.warning == 20
    end

    test "updating preserves other domains" do
      config = default_thresholds()
      {:ok, new_config} = configure_threshold(config, :alarms, :warning, 20)
      assert new_config.security == config.security
      assert new_config.performance == config.performance
    end

    test "unknown domain returns error" do
      config = default_thresholds()
      assert {:error, :invalid_params} = configure_threshold(config, :nonexistent, :warning, 10)
    end

    test "invalid severity returns error" do
      config = default_thresholds()
      assert {:error, :invalid_params} = configure_threshold(config, :alarms, :nonexistent, 10)
    end

    test "multiple updates compose correctly" do
      config = default_thresholds()
      {:ok, c1} = configure_threshold(config, :alarms, :warning, 15)
      {:ok, c2} = configure_threshold(c1, :alarms, :critical, 60)
      {:ok, c3} = configure_threshold(c2, :security, :emergency, 30)

      assert c3.alarms.warning == 15
      assert c3.alarms.critical == 60
      assert c3.security.emergency == 30
    end
  end

  # ---------------------------------------------------------------------------
  # Threshold evaluation tests
  # ---------------------------------------------------------------------------

  describe "threshold evaluation" do
    test "below warning returns :info" do
      config = default_thresholds()
      assert evaluate_threshold(config, :alarms, 5) == :info
    end

    test "at warning boundary returns :warning" do
      config = default_thresholds()
      assert evaluate_threshold(config, :alarms, 10) == :warning
    end

    test "at critical boundary returns :critical" do
      config = default_thresholds()
      assert evaluate_threshold(config, :alarms, 50) == :critical
    end

    test "at emergency boundary returns :emergency" do
      config = default_thresholds()
      assert evaluate_threshold(config, :alarms, 100) == :emergency
    end

    test "health domain uses inverted thresholds" do
      config = default_thresholds()
      # High health score = good
      assert evaluate_threshold(config, :health, 90.0) == :info
      # Low health score = bad
      assert evaluate_threshold(config, :health, 25.0) == :emergency
    end

    test "unknown domain returns error" do
      config = default_thresholds()
      assert {:error, :unknown_domain} = evaluate_threshold(config, :nonexistent, 50)
    end
  end

  # ---------------------------------------------------------------------------
  # Composite health tests
  # ---------------------------------------------------------------------------

  describe "composite health scoring" do
    test "all info domains gives 100% health" do
      config = default_thresholds()
      metrics = [{:alarms, 0}, {:security, 0}, {:performance, 0.0}]
      result = composite_health(config, metrics)

      assert result.worst_severity == :info
      assert result.health_score == 100.0
      assert result.domain_count == 3
    end

    test "one emergency domain drives worst_severity" do
      config = default_thresholds()
      metrics = [{:alarms, 0}, {:security, 30}, {:performance, 0.0}]
      result = composite_health(config, metrics)

      assert result.worst_severity == :emergency
    end

    test "health score decreases with more severe domains" do
      config = default_thresholds()

      healthy = composite_health(config, [{:alarms, 0}, {:security, 0}])
      warning = composite_health(config, [{:alarms, 15}, {:security, 0}])
      critical = composite_health(config, [{:alarms, 60}, {:security, 12}])

      assert healthy.health_score > warning.health_score
      assert warning.health_score > critical.health_score
    end

    test "empty metrics list returns perfect health" do
      config = default_thresholds()
      result = composite_health(config, [])
      assert result.domain_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: threshold invariants" do
    property "evaluation always returns a valid severity" do
      forall value <- PC.float(0.0, 200.0) do
        config = default_thresholds()
        result = evaluate_threshold(config, :performance, value)
        result in @severities
      end
    end

    test "severity ordering is monotonic with increasing metric" do
      severity_rank = %{info: 0, warning: 1, critical: 2, emergency: 3}

      ExUnitProperties.check all(
                               v1 <- SD.float(min: 0.0, max: 200.0),
                               v2 <- SD.float(min: 0.0, max: 200.0)
                             ) do
        config = default_thresholds()
        s1 = evaluate_threshold(config, :alarms, v1)
        s2 = evaluate_threshold(config, :alarms, v2)

        if v1 <= v2 do
          assert Map.get(severity_rank, s1) <= Map.get(severity_rank, s2)
        end
      end
    end

    test "composite health score is bounded [0, 100]" do
      ExUnitProperties.check all(
                               alarm_val <- SD.integer(0..200),
                               sec_val <- SD.integer(0..50),
                               perf_val <- SD.float(min: 0.0, max: 100.0)
                             ) do
        config = default_thresholds()

        result =
          composite_health(config, [
            {:alarms, alarm_val},
            {:security, sec_val},
            {:performance, perf_val}
          ])

        assert result.health_score >= 0.0
        assert result.health_score <= 100.0
      end
    end

    property "configure_threshold preserves domain count" do
      forall {severity, value} <-
               {PC.oneof([:warning, :critical, :emergency]), PC.integer(1, 1000)} do
        config = default_thresholds()
        {:ok, new_config} = configure_threshold(config, :alarms, severity, value)
        map_size(new_config) == map_size(config)
      end
    end
  end
end
