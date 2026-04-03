defmodule Indrajaal.Cybernetic.OODA.OrientTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Orient.

  CRITICAL API notes (the previous version of this file had wrong argument order):
  - new/1 takes a KEYWORD LIST (not a map): Orient.new([ai_enabled: false])
  - orient/2 signature: orient(observation, state) — observation is FIRST arg, state is SECOND
  - local_analyze/2 signature: local_analyze(synthesis_map, mental_model_map)
  - synthesize/3 signature: synthesize(observation, history_list, mental_model_map)
  - generate_hypothesis/2 signature: generate_hypothesis(synthesis_map, analysis_map)
  - assess/3 signature: assess(synthesis_map, analysis_map, hypothesis_map)
  - summary/1 signature: summary(orientation_map) — takes an orientation(), not an orient_state()
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Orient

  # Helper: build a minimal observation (as returned by Observe.collect/1)
  defp build_observation(opts \\ []) do
    %{
      readings: [],
      fused: Keyword.get(opts, :fused, %{}),
      quality: Keyword.get(opts, :quality, 0.8),
      timestamp: DateTime.utc_now()
    }
  end

  # Helper: build an orient_state (as returned by new/1), with ai disabled
  defp new_state(extra_opts \\ []) do
    Orient.new([ai_enabled: false] ++ extra_opts)
  end

  # Helper: build a minimal synthesis map (as returned by synthesize/3)
  defp minimal_synthesis do
    %{
      metrics: %{},
      historical: %{trend: :unknown, stability: 1.0},
      patterns: [],
      quality: 0.8,
      timestamp: DateTime.utc_now()
    }
  end

  # Helper: build a minimal analysis map (as returned by local_analyze/2)
  defp minimal_analysis do
    %{method: :local, alerts: [], pattern_confidence: 0.5, anomaly_score: 0.0}
  end

  # Helper: build a minimal mental model map
  defp minimal_mental_model do
    %{patterns: [], correlations: %{}, confidence: 0.5, updated_at: DateTime.utc_now()}
  end

  # Helper: build a valid orientation map (as returned by orient/2 first element)
  defp minimal_orientation do
    %{
      situation: :normal,
      confidence: 1.0,
      threats: [],
      opportunities: [],
      hypothesis: %{
        primary: %{type: :normal, probability: 0.8},
        alternatives: [],
        evidence: %{anomaly_score: 0.0, quality: 0.8}
      },
      context: %{synthesis: minimal_synthesis(), analysis: minimal_analysis()}
    }
  end

  describe "new/1 — takes keyword list" do
    test "returns a map (orient_state)" do
      assert is_map(Orient.new([]))
    end

    test "has :mental_model key" do
      assert Map.has_key?(Orient.new([]), :mental_model)
    end

    test "has :history key initialised to empty list" do
      assert Orient.new([]).history == []
    end

    test "has :ai_enabled key" do
      assert Map.has_key?(Orient.new([]), :ai_enabled)
    end

    test "has :hysteresis key" do
      assert Map.has_key?(Orient.new([]), :hysteresis)
    end

    test "has :ai_recovery key" do
      assert Map.has_key?(Orient.new([]), :ai_recovery)
    end

    test "ai_enabled defaults to true when not specified" do
      state = Orient.new([])
      assert state.ai_enabled == true
    end

    test "ai_enabled can be set to false" do
      state = Orient.new(ai_enabled: false)
      assert state.ai_enabled == false
    end

    test "hysteresis has :last_situation key" do
      state = Orient.new([])
      assert Map.has_key?(state.hysteresis, :last_situation)
    end

    test "hysteresis.last_situation starts as nil" do
      assert Orient.new([]).hysteresis.last_situation == nil
    end
  end

  describe "orient/2 — orient(observation, state)" do
    test "returns a 2-tuple" do
      obs = build_observation()
      state = new_state()
      result = Orient.orient(obs, state)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "first element is an orientation map" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert is_map(orientation)
    end

    test "orientation has :situation key" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert Map.has_key?(orientation, :situation)
    end

    test "orientation has :confidence key" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert Map.has_key?(orientation, :confidence)
    end

    test "orientation has :threats key" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert Map.has_key?(orientation, :threats)
    end

    test "orientation has :opportunities key" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert Map.has_key?(orientation, :opportunities)
    end

    test "orientation has :hypothesis key" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert Map.has_key?(orientation, :hypothesis)
    end

    test "threats is a list" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert is_list(orientation.threats)
    end

    test "opportunities is a list" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert is_list(orientation.opportunities)
    end

    test "situation is an atom" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert is_atom(orientation.situation)
    end

    test "confidence is a float" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      assert is_float(orientation.confidence)
    end

    test "second element is an updated orient_state" do
      {_, new_state} = Orient.orient(build_observation(), new_state())
      assert is_map(new_state)
    end

    test "updated state history grows by one entry" do
      state = new_state()
      {_, state2} = Orient.orient(build_observation(), state)
      assert length(state2.history) == 1
    end

    test "multiple orient calls accumulate history" do
      state = new_state()
      {_, state2} = Orient.orient(build_observation(), state)
      {_, state3} = Orient.orient(build_observation(), state2)
      assert length(state3.history) == 2
    end

    test "high quality observation produces valid orientation" do
      {orientation, _} = Orient.orient(build_observation(quality: 1.0), new_state())
      assert is_map(orientation)
    end

    test "low quality observation produces valid orientation" do
      {orientation, _} = Orient.orient(build_observation(quality: 0.1), new_state())
      assert is_map(orientation)
    end
  end

  describe "synthesize/3 — synthesize(observation, history, mental_model)" do
    test "returns a map" do
      obs = build_observation()
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert is_map(result)
    end

    test "result has :metrics key" do
      obs = build_observation()
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert Map.has_key?(result, :metrics)
    end

    test "result has :historical key" do
      obs = build_observation()
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert Map.has_key?(result, :historical)
    end

    test "result has :patterns key" do
      obs = build_observation()
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert Map.has_key?(result, :patterns)
    end

    test "result has :quality key matching observation quality" do
      obs = build_observation(quality: 0.65)
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert result.quality == 0.65
    end

    test "empty history yields :unknown trend" do
      obs = build_observation()
      result = Orient.synthesize(obs, [], minimal_mental_model())
      assert result.historical.trend == :unknown
    end

    test "patterns is a list" do
      result = Orient.synthesize(build_observation(), [], minimal_mental_model())
      assert is_list(result.patterns)
    end
  end

  describe "local_analyze/2 — local_analyze(synthesis, mental_model)" do
    test "returns a map" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert is_map(result)
    end

    test "result has :method key with value :local" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert result.method == :local
    end

    test "result has :alerts key" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert Map.has_key?(result, :alerts)
    end

    test "alerts is a list" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert is_list(result.alerts)
    end

    test "result has :anomaly_score key" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert Map.has_key?(result, :anomaly_score)
    end

    test "anomaly_score is a float" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert is_float(result.anomaly_score)
    end

    test "result has :pattern_confidence key" do
      result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
      assert Map.has_key?(result, :pattern_confidence)
    end

    test "returns :local method for all inputs" do
      for _i <- 1..3 do
        result = Orient.local_analyze(minimal_synthesis(), minimal_mental_model())
        assert result.method == :local
      end
    end
  end

  describe "generate_hypothesis/2 — generate_hypothesis(synthesis, analysis)" do
    test "returns a map" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert is_map(result)
    end

    test "result has :primary key" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert Map.has_key?(result, :primary)
    end

    test "result has :alternatives key" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert Map.has_key?(result, :alternatives)
    end

    test "result has :evidence key" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert Map.has_key?(result, :evidence)
    end

    test "primary is a map" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert is_map(result.primary)
    end

    test "alternatives is a list" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert is_list(result.alternatives)
    end

    test "primary has :type key" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert Map.has_key?(result.primary, :type)
    end

    test "primary has :probability key" do
      result = Orient.generate_hypothesis(minimal_synthesis(), minimal_analysis())
      assert Map.has_key?(result.primary, :probability)
    end

    test "low anomaly_score produces :normal hypothesis" do
      low_alert_analysis = %{minimal_analysis() | anomaly_score: 0.0}
      result = Orient.generate_hypothesis(minimal_synthesis(), low_alert_analysis)
      assert result.primary.type == :normal
    end

    test "high anomaly_score produces :system_degradation as primary hypothesis" do
      high_alert_analysis = %{minimal_analysis() | anomaly_score: 0.8}
      result = Orient.generate_hypothesis(minimal_synthesis(), high_alert_analysis)
      assert result.primary.type == :system_degradation
    end
  end

  describe "assess/3 — assess(synthesis, analysis, hypothesis)" do
    test "returns a 2-tuple" do
      result =
        Orient.assess(minimal_synthesis(), minimal_analysis(), %{primary: %{type: :normal}})

      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "first element is a list of threats" do
      {threats, _} = Orient.assess(minimal_synthesis(), minimal_analysis(), %{})
      assert is_list(threats)
    end

    test "second element is a list of opportunities" do
      {_, opportunities} = Orient.assess(minimal_synthesis(), minimal_analysis(), %{})
      assert is_list(opportunities)
    end

    test "no threats when alerts list is empty" do
      analysis = %{minimal_analysis() | alerts: []}
      {threats, _} = Orient.assess(minimal_synthesis(), analysis, %{})
      assert threats == []
    end

    test "no opportunities for low quality high anomaly observation" do
      synthesis = %{minimal_synthesis() | quality: 0.3}
      analysis = %{minimal_analysis() | anomaly_score: 0.5}
      {_, opportunities} = Orient.assess(synthesis, analysis, %{})
      assert opportunities == []
    end

    test "opportunity appears for high quality low anomaly observation" do
      synthesis = %{minimal_synthesis() | quality: 0.9}
      analysis = %{minimal_analysis() | anomaly_score: 0.1}
      {_, opportunities} = Orient.assess(synthesis, analysis, %{})
      assert length(opportunities) > 0
    end
  end

  describe "summary/1 — takes orientation(), not orient_state()" do
    test "returns a map" do
      assert is_map(Orient.summary(minimal_orientation()))
    end

    test "has :situation key" do
      assert Map.has_key?(Orient.summary(minimal_orientation()), :situation)
    end

    test "has :confidence key" do
      assert Map.has_key?(Orient.summary(minimal_orientation()), :confidence)
    end

    test "has :num_threats key" do
      assert Map.has_key?(Orient.summary(minimal_orientation()), :num_threats)
    end

    test "has :num_opportunities key" do
      assert Map.has_key?(Orient.summary(minimal_orientation()), :num_opportunities)
    end

    test "has :primary_hypothesis key" do
      assert Map.has_key?(Orient.summary(minimal_orientation()), :primary_hypothesis)
    end

    test "num_threats is 0 for orientation with no threats" do
      assert Orient.summary(minimal_orientation()).num_threats == 0
    end

    test "situation matches orientation.situation" do
      orientation = %{minimal_orientation() | situation: :degraded}
      assert Orient.summary(orientation).situation == :degraded
    end

    test "confidence matches orientation.confidence" do
      orientation = %{minimal_orientation() | confidence: 0.42}
      assert Orient.summary(orientation).confidence == 0.42
    end

    test "summary is valid after a real orient/2 call" do
      {orientation, _} = Orient.orient(build_observation(), new_state())
      result = Orient.summary(orientation)
      assert is_map(result)
      assert Map.has_key?(result, :situation)
    end
  end

  describe "ai_analyze/2 — ai_analyze(synthesis, mental_model)" do
    test "returns a map" do
      result = Orient.ai_analyze(minimal_synthesis(), minimal_mental_model())
      assert is_map(result)
    end

    test "has :method key" do
      result = Orient.ai_analyze(minimal_synthesis(), minimal_mental_model())
      assert Map.has_key?(result, :method)
    end

    test "has :alerts key" do
      result = Orient.ai_analyze(minimal_synthesis(), minimal_mental_model())
      assert Map.has_key?(result, :alerts)
    end
  end

  describe "ai_analyze_with_recovery/3" do
    test "returns a 2-tuple" do
      recovery_state = %{
        consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        last_timeout_at: nil,
        current_timeout_ms: 20
      }

      result =
        Orient.ai_analyze_with_recovery(
          minimal_synthesis(),
          minimal_mental_model(),
          recovery_state
        )

      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "first element is an analysis map" do
      recovery_state = %{
        consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        last_timeout_at: nil,
        current_timeout_ms: 20
      }

      {analysis, _} =
        Orient.ai_analyze_with_recovery(
          minimal_synthesis(),
          minimal_mental_model(),
          recovery_state
        )

      assert is_map(analysis)
    end

    test "second element is updated recovery state" do
      recovery_state = %{
        consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        last_timeout_at: nil,
        current_timeout_ms: 20
      }

      {_, new_recovery} =
        Orient.ai_analyze_with_recovery(
          minimal_synthesis(),
          minimal_mental_model(),
          recovery_state
        )

      assert is_map(new_recovery)
    end

    test "recovery mode bypasses AI and uses local analysis" do
      in_recovery = %{
        consecutive_timeouts: 5,
        in_recovery_mode: true,
        successful_local_count: 0,
        last_timeout_at: DateTime.utc_now(),
        current_timeout_ms: 40
      }

      {analysis, _} =
        Orient.ai_analyze_with_recovery(minimal_synthesis(), minimal_mental_model(), in_recovery)

      assert is_map(analysis)
      assert Map.has_key?(analysis, :method)
    end
  end
end
