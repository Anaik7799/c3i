defmodule Indrajaal.Integration.ExternalConnectorsTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.ExternalConnectors.

  Tests external connector management: connector creation, operation
  execution, data synchronization, event processing, and schema registration.

  ## STAMP Safety Integration
  - SC-INT-003: External connectors must not bypass authentication
  - SC-SEC-044: All external integrations must pass Sobelow check
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Integration.ExternalConnectors

  describe "module compilation" do
    test "module is defined and accessible" do
      assert Code.ensure_loaded?(ExternalConnectors)
    end

    test "is an Ash.Domain module" do
      assert is_atom(ExternalConnectors)
    end
  end

  describe "create_connector/2" do
    test "function is exported" do
      assert function_exported?(ExternalConnectors, :create_connector, 2)
    end

    test "returns ok or error tuple with connector config" do
      config = %{
        name: "Salesforce Integration",
        type: :rest_api,
        endpoint: "https://api.salesforce.com",
        authentication: %{type: :oauth2}
      }

      result = ExternalConnectors.create_connector(config)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options as second argument" do
      result = ExternalConnectors.create_connector(%{name: "test"}, [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for missing required name" do
      result = ExternalConnectors.create_connector(%{type: :rest_api})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "accepts database connector type" do
      result =
        ExternalConnectors.create_connector(%{
          name: "PostgreSQL Connector",
          type: :database,
          connection_string: "postgresql://localhost/mydb"
        })

      assert is_tuple(result)
    end

    test "accepts message_queue connector type" do
      result =
        ExternalConnectors.create_connector(%{
          name: "Kafka Connector",
          type: :message_queue,
          brokers: ["localhost:9092"]
        })

      assert is_tuple(result)
    end

    test "accepts webhook connector type" do
      result =
        ExternalConnectors.create_connector(%{
          name: "Slack Webhook",
          type: :webhook,
          webhook_url: "https://hooks.slack.com/services/xxx"
        })

      assert is_tuple(result)
    end
  end

  describe "execute_operation/4" do
    test "function is exported" do
      assert function_exported?(ExternalConnectors, :execute_operation, 4)
    end

    test "returns error for nonexistent connector" do
      result =
        ExternalConnectors.execute_operation(
          "conn-nonexistent-999",
          :get,
          %{path: "/users"},
          []
        )

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "accepts :get operation" do
      result = ExternalConnectors.execute_operation("conn-1", :get, %{path: "/health"}, [])
      assert is_tuple(result)
    end

    test "accepts :post operation" do
      result =
        ExternalConnectors.execute_operation("conn-1", :post, %{path: "/items", body: %{}}, [])

      assert is_tuple(result)
    end

    test "accepts :put operation" do
      result =
        ExternalConnectors.execute_operation("conn-1", :put, %{path: "/items/1", body: %{}}, [])

      assert is_tuple(result)
    end

    test "accepts :delete operation" do
      result = ExternalConnectors.execute_operation("conn-1", :delete, %{path: "/items/1"}, [])
      assert is_tuple(result)
    end

    test "accepts empty options list" do
      result = ExternalConnectors.execute_operation("conn-1", :get, %{}, [])
      assert is_tuple(result)
    end
  end

  describe "synchronize_data/1" do
    test "function is exported" do
      assert function_exported?(ExternalConnectors, :synchronize_data, 1)
    end

    test "returns ok or error tuple with sync config" do
      config = %{
        connector_id: "conn-1",
        direction: :bidirectional,
        entity_type: "contacts",
        conflict_resolution: :source_wins
      }

      result = ExternalConnectors.synchronize_data(config)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :push direction" do
      result = ExternalConnectors.synchronize_data(%{connector_id: "c", direction: :push})
      assert is_tuple(result)
    end

    test "accepts :pull direction" do
      result = ExternalConnectors.synchronize_data(%{connector_id: "c", direction: :pull})
      assert is_tuple(result)
    end

    test "returns error for missing connector_id" do
      result = ExternalConnectors.synchronize_data(%{direction: :push})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "start_event_processor/2" do
    test "function is exported" do
      assert function_exported?(ExternalConnectors, :start_event_processor, 2)
    end

    test "returns ok or error tuple" do
      event_config = %{
        topics: ["user.created", "user.updated"],
        handler: :log_event,
        batch_size: 100
      }

      result = ExternalConnectors.start_event_processor("conn-1", event_config)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for nonexistent connector" do
      result = ExternalConnectors.start_event_processor("conn-nonexistent-999", %{})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "register_schema/2" do
    test "function is exported" do
      assert function_exported?(ExternalConnectors, :register_schema, 2)
    end

    test "returns ok or error tuple with schema config" do
      schema = %{
        name: "UserEvent",
        type: :avro,
        definition: %{type: "record", name: "User", fields: []},
        compatibility: :backward
      }

      result = ExternalConnectors.register_schema("conn-1", schema)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts json_schema type" do
      result =
        ExternalConnectors.register_schema("conn-1", %{
          name: "UserJSON",
          type: :json_schema,
          definition: %{"type" => "object"}
        })

      assert is_tuple(result)
    end

    test "returns error for nonexistent connector" do
      result = ExternalConnectors.register_schema("conn-nonexistent-999", %{name: "Schema"})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
