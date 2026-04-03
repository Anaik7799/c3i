defmodule Indrajaal.Cybernetic.OODA.TelemetryTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Telemetry.

  Telemetry is a Supervisor module that provides 4 metrics for the OODA loop:
    1. counter    — [:intelitor, :ooda, :loop, :count]
    2. last_value — [:intelitor, :ooda, :loop, :data_quality]
    3. last_value — [:intelitor, :ooda, :loop, :decision_confidence]
    4. summary    — [:intelitor, :ooda, :loop, :latency]

  NOTE: Telemetry.Metrics stores the metric name as an ATOM LIST (the event path),
  not as a dotted string. All Enum.find calls and name assertions use atom lists.

  NOTE: We alias the production module as OODATelemetry to prevent Elixir from
  resolving Telemetry.* relative to Indrajaal.Cybernetic.OODA.Telemetry.*.
  Struct type assertions use is_struct/2 with the module atom directly.
  """

  use ExUnit.Case, async: true

  # Alias as OODATelemetry to prevent Elixir from resolving
  # Telemetry.Metrics.* relative to Indrajaal.Cybernetic.OODA.Telemetry.*
  alias Indrajaal.Cybernetic.OODA.Telemetry, as: OODATelemetry

  # The four metric names as atom lists (the actual storage format in Telemetry.Metrics)
  @count_name [:intelitor, :ooda, :loop, :count]
  @data_quality_name [:intelitor, :ooda, :loop, :data_quality]
  @decision_confidence_name [:intelitor, :ooda, :loop, :decision_confidence]
  @latency_name [:intelitor, :ooda, :loop, :latency]

  @expected_names [
    @count_name,
    @data_quality_name,
    @decision_confidence_name,
    @latency_name
  ]

  describe "metrics/0 — list contract" do
    test "returns a list" do
      assert is_list(OODATelemetry.metrics())
    end

    test "returns exactly 4 metrics" do
      assert length(OODATelemetry.metrics()) == 4
    end

    test "every element is a struct" do
      for metric <- OODATelemetry.metrics() do
        assert is_struct(metric), "Expected struct, got #{inspect(metric)}"
      end
    end

    test "metric names are all atom lists" do
      for metric <- OODATelemetry.metrics() do
        assert is_list(metric.name), "Expected atom-list name, got #{inspect(metric.name)}"
        assert Enum.all?(metric.name, &is_atom/1)
      end
    end
  end

  describe "metrics/0 — specific metric names" do
    test "includes the loop count metric" do
      names = Enum.map(OODATelemetry.metrics(), & &1.name)
      assert @count_name in names
    end

    test "includes the data_quality metric" do
      names = Enum.map(OODATelemetry.metrics(), & &1.name)
      assert @data_quality_name in names
    end

    test "includes the decision_confidence metric" do
      names = Enum.map(OODATelemetry.metrics(), & &1.name)
      assert @decision_confidence_name in names
    end

    test "includes the latency metric" do
      names = Enum.map(OODATelemetry.metrics(), & &1.name)
      assert @latency_name in names
    end

    test "no unexpected metric names are present" do
      names = Enum.map(OODATelemetry.metrics(), & &1.name)

      for name <- names do
        assert name in @expected_names,
               "Unexpected metric name: #{inspect(name)}"
      end
    end
  end

  describe "metrics/0 — event names" do
    test "all metrics share the same event_name" do
      event_names = Enum.map(OODATelemetry.metrics(), & &1.event_name)
      unique_events = Enum.uniq(event_names)
      assert length(unique_events) == 1
    end

    test "event_name is [:indrajaal, :ooda, :loop]" do
      for metric <- OODATelemetry.metrics() do
        assert metric.event_name == [:indrajaal, :ooda, :loop],
               "Unexpected event_name #{inspect(metric.event_name)} for #{inspect(metric.name)}"
      end
    end
  end

  describe "metrics/0 — metric types (using is_struct/2 with module atom)" do
    # We use is_struct/2 with the fully-qualified module atom to avoid alias
    # resolution issues when the test module name starts with a prefix that
    # shadows Telemetry (since OODATelemetry is aliased from Indrajaal...Telemetry).

    test "loop.count is a Telemetry.Metrics.Counter" do
      count_metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @count_name))

      refute is_nil(count_metric), "Expected to find count metric"
      assert is_struct(count_metric, :"Elixir.Telemetry.Metrics.Counter")
    end

    test "loop.latency is a Telemetry.Metrics.Summary" do
      latency_metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @latency_name))

      refute is_nil(latency_metric), "Expected to find latency metric"
      assert is_struct(latency_metric, :"Elixir.Telemetry.Metrics.Summary")
    end

    test "data_quality is a Telemetry.Metrics.LastValue" do
      metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @data_quality_name))

      refute is_nil(metric), "Expected to find data_quality metric"
      assert is_struct(metric, :"Elixir.Telemetry.Metrics.LastValue")
    end

    test "decision_confidence is a Telemetry.Metrics.LastValue" do
      metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @decision_confidence_name))

      refute is_nil(metric), "Expected to find decision_confidence metric"
      assert is_struct(metric, :"Elixir.Telemetry.Metrics.LastValue")
    end
  end

  describe "metrics/0 — descriptions" do
    test "data_quality metric has a non-nil description" do
      metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @data_quality_name))

      refute is_nil(metric), "Expected to find data_quality metric"
      assert is_binary(metric.description) and byte_size(metric.description) > 0
    end

    test "decision_confidence metric has a non-nil description" do
      metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @decision_confidence_name))

      refute is_nil(metric), "Expected to find decision_confidence metric"
      assert is_binary(metric.description) and byte_size(metric.description) > 0
    end

    test "latency metric has a non-nil description" do
      metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @latency_name))

      refute is_nil(metric), "Expected to find latency metric"
      assert is_binary(metric.description) and byte_size(metric.description) > 0
    end
  end

  describe "metrics/0 — loop count tags" do
    test "loop.count metric has :phase and :event tags" do
      count_metric =
        Enum.find(OODATelemetry.metrics(), &(&1.name == @count_name))

      refute is_nil(count_metric), "Expected to find count metric"
      assert :phase in count_metric.tags
      assert :event in count_metric.tags
    end
  end

  describe "metrics/0 — idempotency" do
    test "calling metrics/0 twice returns equal lists" do
      assert OODATelemetry.metrics() == OODATelemetry.metrics()
    end
  end

  describe "supervisor interface" do
    test "start_link/1 is exported" do
      assert function_exported?(OODATelemetry, :start_link, 1)
    end

    test "child_spec/1 is exported (via use Supervisor)" do
      assert function_exported?(OODATelemetry, :child_spec, 1)
    end
  end
end
