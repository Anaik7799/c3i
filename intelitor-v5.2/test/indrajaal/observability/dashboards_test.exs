defmodule Indrajaal.Observability.DashboardsTest do
  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # TDG: Test-Driven Generation compliance marker
  # GDE: Goal-Directed Execution compliance
  # This test follows TDG methodology and GDE principles

  alias Indrajaal.Observability.Dashboards

  describe "create_dashboards/1" do
    test "creates all __required dashboards with success" do
      # Mock the SigNoz API client
      mock_client = fn
        :post, "/api/v3/dashboards", _body, _headers ->
          {:ok, %{status: 200, body: %{"__data" => %{"id" => "test-dashboard-id"}}}}
      end

      result = Dashboards.create_dashboards(mock_client)

      assert {:ok, dashboards} = result
      assert length(dashboards) == 5
      assert Enum.all?(dashboards, fn {_name, id} -> id == "test-dashboard-id" end)
    end

    test "handles API errors gracefully" do
      # Mock client that returns error
      mock_client = fn
        :post, "/api/v3/dashboards", _body, _headers ->
          {:error, %{status: 500, body: "Internal Server Error"}}
      end

      result = Dashboards.create_dashboards(mock_client)

      assert {:error, errors} = result
      assert length(errors) == 5
    end
  end

  describe "load_dashboard_config/1" do
    test "loads system overview dashboard configuration" do
      config = Dashboards.load_dashboard_config(:system_overview)

      assert config.title == "System Overview Dashboard"
      assert config.description =~ "comprehensive view"
      assert length(config.widgets) > 0
      assert Enum.any?(config.widgets, &(&1.type == "trace"))
      assert Enum.any?(config.widgets, &(&1.type == "log"))
      assert Enum.any?(config.widgets, &(&1.type == "metric"))
    end

    test "loads alarms dashboard configuration" do
      config = Dashboards.load_dashboard_config(:alarms)

      assert config.title == "Alarms Dashboard"
      assert config.description =~ "alarm monitoring"
      assert length(config.widgets) > 0
      assert Enum.any?(config.widgets, &(&1.query =~ "alarm"))
    end

    test "loads security dashboard configuration" do
      config = Dashboards.load_dashboard_config(:security)

      assert config.title == "Security Dashboard"
      assert config.description =~ "security monitoring"
      assert length(config.widgets) > 0
      assert Enum.any?(config.widgets, &(&1.query =~ "auth"))
    end

    test "loads performance dashboard configuration" do
      config = Dashboards.load_dashboard_config(:performance)

      assert config.title == "Performance Dashboard"
      assert config.description =~ "performance metrics"
      assert length(config.widgets) > 0
      assert Enum.any?(config.widgets, &(&1.query =~ "latency"))
    end

    test "loads business KPIs dashboard configuration" do
      config = Dashboards.load_dashboard_config(:business_kpis)

      assert config.title == "Business KPIs Dashboard"
      assert config.description =~ "executive view"
      assert length(config.widgets) > 0
      assert Enum.any?(config.widgets, &(&1.query =~ "revenue" || &1.query =~ "__users"))
    end

    test "returns error for unknown dashboard type" do
      assert {:error, :unknown_dashboard} = Dashboards.load_dashboard_config(:invalid)
    end
  end

  describe "validate_dashboard_config/1" do
    test "validates correct dashboard configuration" do
      config = %{
        title: "Test Dashboard",
        description: "Test description",
        widgets: [
          %{
            type: "trace",
            query: "service=indrajaal",
            title: "Traces",
            position: %{x: 0, y: 0, w: 6, h: 4}
          }
        ]
      }

      assert :ok = Dashboards.validate_dashboard_config(config)
    end

    test "returns error for missing __required fields" do
      config = %{title: "Test"}

      assert {:error, errors} = Dashboards.validate_dashboard_config(config)
      assert :description in errors
      assert :widgets in errors
    end

    test "returns error for invalid widget configuration" do
      config = %{
        title: "Test Dashboard",
        description: "Test description",
        widgets: [
          %{type: "invalid", query: "test"}
        ]
      }

      assert {:error, errors} = Dashboards.validate_dashboard_config(config)
      assert {:widget, 0, _} = hd(errors)
    end
  end

  describe "create_dashboard/2" do
    test "creates individual dashboard successfully" do
      mock_client = fn
        :post, "/api/v3/dashboards", body, _headers ->
          assert body["title"] == "Test Dashboard"
          {:ok, %{status: 200, body: %{"__data" => %{"id" => "dashboard-123"}}}}
      end

      config = %{
        title: "Test Dashboard",
        description: "Test description",
        widgets: []
      }

      assert {:ok, "dashboard-123"} = Dashboards.create_dashboard(config, mock_client)
    end

    test "handles creation errors" do
      mock_client = fn
        :post, "/api/v3/dashboards", _body, _headers ->
          {:error, %{status: 400, body: "Bad Request"}}
      end

      config = %{
        title: "Test Dashboard",
        description: "Test description",
        widgets: []
      }

      assert {:error, reason} = Dashboards.create_dashboard(config, mock_client)
      assert reason =~ "Bad Request"
    end
  end

  describe "widget creation" do
    test "creates trace widget configuration" do
      widget =
        Dashboards.create_trace_widget(
          "Service Traces",
          "service=indrajaal AND duration>100",
          %{x: 0, y: 0, w: 6, h: 4}
        )

      assert widget.type == "trace"
      assert widget.title == "Service Traces"
      assert widget.query == "service=indrajaal AND duration>100"
      assert widget.position == %{x: 0, y: 0, w: 6, h: 4}
    end

    test "creates log widget configuration" do
      widget =
        Dashboards.create_log_widget(
          "Error Logs",
          "level=error AND service=indrajaal",
          %{x: 6, y: 0, w: 6, h: 4}
        )

      assert widget.type == "log"
      assert widget.title == "Error Logs"
      assert widget.query == "level=error AND service=indrajaal"
      assert widget.position == %{x: 6, y: 0, w: 6, h: 4}
    end

    test "creates metric widget configuration" do
      widget =
        Dashboards.create_metric_widget(
          "Request Rate",
          "http_requests_total",
          %{x: 0, y: 4, w: 6, h: 4},
          %{aggregation: "rate", interval: "1m"}
        )

      assert widget.type == "metric"
      assert widget.title == "Request Rate"
      assert widget.query == "http_requests_total"
      assert widget.position == %{x: 0, y: 4, w: 6, h: 4}
      assert widget.options.aggregation == "rate"
      assert widget.options.interval == "1m"
    end
  end

  describe "dashboard URLs" do
    test "generates correct dashboard URLs" do
      dashboards = %{
        system_overview: "dash-123",
        alarms: "dash-456",
        security: "dash-789"
      }

      urls = Dashboards.get_dashboard_urls(dashboards, "https://signoz.example.com")

      assert urls.system_overview == "https://signoz.example.com/dashboard/dash-123"
      assert urls.alarms == "https://signoz.example.com/dashboard/dash-456"
      assert urls.security == "https://signoz.example.com/dashboard/dash-789"
    end
  end

  describe "integration test" do
    @tag :integration
    test "creates dashboards in real SigNoz instance" do
      # This test would run against a real SigNoz instance
      # Skip if SIGNOZ_API_URL env var not set
      api_url = System.get_env("SIGNOZ_API_URL")
      api_key = System.get_env("SIGNOZ_API_KEY")

      if api_url && api_key do
        client = Dashboards.create_api_client(api_url, api_key)
        result = Dashboards.create_dashboards(client)

        assert {:ok, dashboards} = result
        assert map_size(dashboards) == 5

        # Verify we can fetch the created dashboards
        for {_name, id} <- dashboards do
          assert {:ok, _dashboard} = Dashboards.get_dashboard(id, client)
        end
      end
    end
  end

  # Property-based tests to satisfy STAMP requirements - PropCheck
  describe "property-based testing (PropCheck)" do
    @tag :property
    test "dashboard configurations always have required fields" do
      # PropCheck property test converted to standard test with forall
      import PropCheck

      assert PropCheck.quickcheck(
               PropCheck.forall type <-
                                  PC.oneof([
                                    :system_overview,
                                    :alarms,
                                    :security,
                                    :performance,
                                    :business_kpis
                                  ]) do
                 config = Dashboards.load_dashboard_config(type)

                 is_map(config) and
                   Map.has_key?(config, :title) and
                   Map.has_key?(config, :description) and
                   Map.has_key?(config, :widgets) and
                   is_list(config.widgets)
               end
             )
    end
  end

  # Property-based tests to satisfy STAMP requirements - ExUnitProperties
  describe "property-based testing (ExUnitProperties)" do
    test "widget creation functions produce valid widget structures" do
      ExUnitProperties.check all(
                               title <- SD.string(:printable),
                               query <- SD.string(:printable),
                               x <- SD.integer(0..20),
                               y <- SD.integer(0..20),
                               w <- SD.integer(1..12),
                               h <- SD.integer(1..10)
                             ) do
        position = %{x: x, y: y, w: w, h: h}

        trace_widget = Dashboards.create_trace_widget(title, query, position)
        assert trace_widget.type == "trace"
        assert trace_widget.title == title
        assert trace_widget.query == query
        assert trace_widget.position == position

        log_widget = Dashboards.create_log_widget(title, query, position)
        assert log_widget.type == "log"

        metric_widget = Dashboards.create_metric_widget(title, query, position)
        assert metric_widget.type == "metric"
      end
    end
  end
end
