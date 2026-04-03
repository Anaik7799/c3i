defmodule Indrajaal.Shared.TracingUtilitiesTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.TracingUtilities.

  Tests the shared tracing utilities that eliminate duplication between
  tracing modules following Toyota TPS principles.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.TracingUtilities

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(TracingUtilities)
    end

    test "exports emit_operation_telemetry/4" do
      exports = TracingUtilities.__info__(:functions)
      assert {:emit_operation_telemetry, 4} in exports
    end

    test "exports extract_device_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_device_id, 1} in exports
    end

    test "exports extract_alarm_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_alarm_id, 1} in exports
    end

    test "exports extract_camera_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_camera_id, 1} in exports
    end

    test "exports extract_actor_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_actor_id, 1} in exports
    end

    test "exports extractactor_id_from_context/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extractactor_id_from_context, 1} in exports
    end

    test "exports build_device_context/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_device_context, 1} in exports
    end

    test "exports build_alarm_context/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_alarm_context, 1} in exports
    end

    test "exports build_video_context/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_video_context, 1} in exports
    end

    test "exports build_business_context/2" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_business_context, 2} in exports
    end

    test "exports build_business_context/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_business_context, 3} in exports
    end

    test "exports build_security_context/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_security_context, 3} in exports
    end

    test "exports build_security_context/4" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_security_context, 4} in exports
    end

    test "exports build_auth_context/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_auth_context, 3} in exports
    end

    test "exports build_auth_context/4" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_auth_context, 4} in exports
    end

    test "exports build_audit_context/2" do
      exports = TracingUtilities.__info__(:functions)
      assert {:build_audit_context, 2} in exports
    end

    test "exports trace_device_operation_with_telemetry/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:trace_device_operation_with_telemetry, 3} in exports
    end

    test "exports trace_alarm_operation_with_telemetry/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:trace_alarm_operation_with_telemetry, 3} in exports
    end

    test "exports trace_video_operation_with_telemetry/3" do
      exports = TracingUtilities.__info__(:functions)
      assert {:trace_video_operation_with_telemetry, 3} in exports
    end

    test "exports trace_business_critical_with_telemetry/4" do
      exports = TracingUtilities.__info__(:functions)
      assert {:trace_business_critical_with_telemetry, 4} in exports
    end

    test "exports extract_resource_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_resource_id, 1} in exports
    end

    test "exports extract_result_id/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:extract_result_id, 1} in exports
    end

    test "exports priority_to_number/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:priority_to_number, 1} in exports
    end

    test "exports importance_to_number/1" do
      exports = TracingUtilities.__info__(:functions)
      assert {:importance_to_number, 1} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(TracingUtilities)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  # ===========================================================================
  # emit_operation_telemetry/4 Tests
  # ===========================================================================

  describe "emit_operation_telemetry/4" do
    test "emits telemetry event for device operation" do
      # Attach a test handler to verify telemetry emission
      test_pid = self()

      :telemetry.attach(
        "test-handler-device",
        [:indrajaal, :device, :create],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      TracingUtilities.emit_operation_telemetry(:device, "create", %{count: 1}, %{
        device_id: "123"
      })

      assert_receive {:telemetry, [:indrajaal, :device, :create], %{count: 1},
                      %{device_id: "123"}}

      :telemetry.detach("test-handler-device")
    end

    test "emits telemetry event for alarm operation" do
      test_pid = self()

      :telemetry.attach(
        "test-handler-alarm",
        [:indrajaal, :alarm, :trigger],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      TracingUtilities.emit_operation_telemetry(:alarm, "trigger", %{count: 1}, %{alarm_id: "456"})

      assert_receive {:telemetry, [:indrajaal, :alarm, :trigger], %{count: 1}, %{alarm_id: "456"}}

      :telemetry.detach("test-handler-alarm")
    end
  end

  # ===========================================================================
  # Extract ID Functions Tests
  # ===========================================================================

  describe "extract_device_id/1" do
    test "extracts id from changeset data" do
      changeset = %{data: %{id: "device-123"}, changes: %{}}
      assert TracingUtilities.extract_device_id(changeset) == "device-123"
    end

    test "extracts id from changeset changes when data id is nil" do
      changeset = %{data: %{id: nil}, changes: %{id: "device-456"}}
      assert TracingUtilities.extract_device_id(changeset) == "device-456"
    end

    test "extracts device_id from changes as fallback" do
      changeset = %{data: %{id: nil}, changes: %{id: nil, device_id: "device-789"}}
      assert TracingUtilities.extract_device_id(changeset) == "device-789"
    end

    test "extracts device_id from data as last fallback" do
      changeset = %{
        data: %{id: nil, device_id: "device-000"},
        changes: %{id: nil, device_id: nil}
      }

      assert TracingUtilities.extract_device_id(changeset) == "device-000"
    end
  end

  describe "extract_alarm_id/1" do
    test "extracts id from changeset data" do
      changeset = %{data: %{id: "alarm-123"}, changes: %{}}
      assert TracingUtilities.extract_alarm_id(changeset) == "alarm-123"
    end

    test "extracts id from changeset changes when data id is nil" do
      changeset = %{data: %{id: nil}, changes: %{id: "alarm-456"}}
      assert TracingUtilities.extract_alarm_id(changeset) == "alarm-456"
    end

    test "generates UUID as fallback when no id found" do
      changeset = %{data: %{id: nil}, changes: %{id: nil}}
      result = TracingUtilities.extract_alarm_id(changeset)
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "extract_camera_id/1" do
    test "extracts id from changeset data" do
      changeset = %{data: %{id: "camera-123"}, changes: %{}}
      assert TracingUtilities.extract_camera_id(changeset) == "camera-123"
    end

    test "extracts camera_id from changes as fallback" do
      changeset = %{data: %{id: nil}, changes: %{id: nil, camera_id: "camera-789"}}
      assert TracingUtilities.extract_camera_id(changeset) == "camera-789"
    end
  end

  describe "extract_actor_id/1" do
    test "extracts actor id from changeset context" do
      changeset = %{__context: %{actor: %{id: "actor-123"}}}
      assert TracingUtilities.extract_actor_id(changeset) == "actor-123"
    end

    test "returns nil when no actor in context" do
      changeset = %{__context: %{}}
      assert TracingUtilities.extract_actor_id(changeset) == nil
    end

    test "returns nil when actor has no id" do
      changeset = %{__context: %{actor: %{name: "Test"}}}
      assert TracingUtilities.extract_actor_id(changeset) == nil
    end
  end

  describe "extractactor_id_from_context/1" do
    test "extracts id from context with id field" do
      context = %{id: "actor-123"}
      assert TracingUtilities.extractactor_id_from_context(context) == "actor-123"
    end

    test "returns nil for context without id" do
      context = %{name: "Test"}
      assert TracingUtilities.extractactor_id_from_context(context) == nil
    end

    test "returns nil for non-map context" do
      assert TracingUtilities.extractactor_id_from_context("invalid") == nil
    end
  end

  describe "extract_resource_id/1" do
    test "extracts id from changeset data" do
      changeset = %{data: %{id: "resource-123"}, changes: %{}}
      assert TracingUtilities.extract_resource_id(changeset) == "resource-123"
    end

    test "extracts id from changeset changes" do
      changeset = %{data: %{id: nil}, changes: %{id: "resource-456"}}
      assert TracingUtilities.extract_resource_id(changeset) == "resource-456"
    end
  end

  describe "extract_result_id/1" do
    test "extracts id from result map" do
      result = %{id: "result-123"}
      assert TracingUtilities.extract_result_id(result) == "result-123"
    end

    test "returns nil for result without id" do
      result = %{name: "Test"}
      assert TracingUtilities.extract_result_id(result) == nil
    end
  end

  # ===========================================================================
  # Build Context Functions Tests
  # ===========================================================================

  describe "build_device_context/1" do
    test "builds context with device attributes" do
      changeset = %{
        data: %{device_type: :camera, location_id: "loc-1", status: :active},
        changes: %{}
      }

      context = TracingUtilities.build_device_context(changeset)

      assert is_map(context)
      assert context.device_type == :camera
      assert context.location == "loc-1"
      assert context.status == :active
    end

    test "prefers changes over data" do
      changeset = %{
        data: %{device_type: :old_type, status: :inactive},
        changes: %{device_type: :new_type, status: :active}
      }

      context = TracingUtilities.build_device_context(changeset)

      assert context.device_type == :new_type
      assert context.status == :active
    end
  end

  describe "build_alarm_context/1" do
    test "builds context with alarm attributes" do
      changeset = %{
        data: %{incident_type: :intrusion, priority: :high, source_id: "src-1"},
        changes: %{}
      }

      context = TracingUtilities.build_alarm_context(changeset)

      assert is_map(context)
      assert context.incident_type == :intrusion
      assert context.priority == :high
      assert context.source == "src-1"
    end
  end

  describe "build_video_context/1" do
    test "builds context with video attributes" do
      changeset = %{
        data: %{stream_type: :live, resolution: "1080p", codec: "h264"},
        changes: %{}
      }

      context = TracingUtilities.build_video_context(changeset)

      assert is_map(context)
      assert context.stream_type == :live
      assert context.resolution == "1080p"
      assert context.codec == "h264"
    end
  end

  describe "build_business_context/2,3" do
    test "builds business context with default importance" do
      changeset = %{
        resource: "TestResource",
        action: %{name: :create},
        __context: %{actor: %{id: "actor-1"}}
      }

      context = TracingUtilities.build_business_context(changeset, "test_operation")

      assert is_map(context)
      assert context.operation == "test_operation"
      assert context.importance == :medium
      assert context.resource == "TestResource"
      assert context.action == :create
    end

    test "builds business context with custom importance" do
      changeset = %{
        resource: "TestResource",
        action: %{name: :update},
        __context: %{}
      }

      context = TracingUtilities.build_business_context(changeset, "critical_op", :high)

      assert context.importance == :high
    end
  end

  # ===========================================================================
  # Priority and Importance Conversion Tests
  # ===========================================================================

  describe "priority_to_number/1" do
    test "converts :critical to 4" do
      assert TracingUtilities.priority_to_number(:critical) == 4
    end

    test "converts :high to 3" do
      assert TracingUtilities.priority_to_number(:high) == 3
    end

    test "converts :medium to 2" do
      assert TracingUtilities.priority_to_number(:medium) == 2
    end

    test "converts :low to 1" do
      assert TracingUtilities.priority_to_number(:low) == 1
    end

    test "converts string \"critical\" to 4" do
      assert TracingUtilities.priority_to_number("critical") == 4
    end

    test "converts string \"high\" to 3" do
      assert TracingUtilities.priority_to_number("high") == 3
    end

    test "converts string \"medium\" to 2" do
      assert TracingUtilities.priority_to_number("medium") == 2
    end

    test "converts string \"low\" to 1" do
      assert TracingUtilities.priority_to_number("low") == 1
    end

    test "defaults to 2 for unknown values" do
      assert TracingUtilities.priority_to_number(:unknown) == 2
      assert TracingUtilities.priority_to_number(nil) == 2
    end
  end

  describe "importance_to_number/1" do
    test "converts :critical to 4" do
      assert TracingUtilities.importance_to_number(:critical) == 4
    end

    test "converts :high to 3" do
      assert TracingUtilities.importance_to_number(:high) == 3
    end

    test "converts :medium to 2" do
      assert TracingUtilities.importance_to_number(:medium) == 2
    end

    test "converts :low to 1" do
      assert TracingUtilities.importance_to_number(:low) == 1
    end

    test "converts string values" do
      assert TracingUtilities.importance_to_number("critical") == 4
      assert TracingUtilities.importance_to_number("high") == 3
      assert TracingUtilities.importance_to_number("medium") == 2
      assert TracingUtilities.importance_to_number("low") == 1
    end

    test "defaults to 2 for unknown values" do
      assert TracingUtilities.importance_to_number(:unknown) == 2
      assert TracingUtilities.importance_to_number(nil) == 2
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    property "priority_to_number returns integer between 1 and 4" do
      forall priority <- PC.oneof([:critical, :high, :medium, :low, nil, :unknown]) do
        result = TracingUtilities.priority_to_number(priority)
        is_integer(result) and result >= 1 and result <= 4
      end
    end

    property "importance_to_number returns integer between 1 and 4" do
      forall importance <- PC.oneof([:critical, :high, :medium, :low, nil, :unknown]) do
        result = TracingUtilities.importance_to_number(importance)
        is_integer(result) and result >= 1 and result <= 4
      end
    end

    property "extract_device_id returns value from changeset" do
      forall device_id <- PC.utf8() do
        changeset = %{data: %{id: device_id}, changes: %{}}
        TracingUtilities.extract_device_id(changeset) == device_id
      end
    end

    property "extractactor_id_from_context returns id for maps with id" do
      forall actor_id <- PC.utf8() do
        context = %{id: actor_id}
        TracingUtilities.extractactor_id_from_context(context) == actor_id
      end
    end

    property "build_device_context returns map" do
      forall {device_type, status} <- {PC.atom(), PC.atom()} do
        changeset = %{
          data: %{device_type: device_type, status: status},
          changes: %{}
        }

        is_map(TracingUtilities.build_device_context(changeset))
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles nil values in changeset data" do
      changeset = %{data: %{id: nil}, changes: %{id: nil}}
      assert TracingUtilities.extract_device_id(changeset) == nil
    end

    test "handles empty changeset" do
      changeset = %{data: %{}, changes: %{}}
      assert TracingUtilities.extract_device_id(changeset) == nil
    end

    test "handles unicode in device context" do
      changeset = %{
        data: %{device_type: :camera, location_id: "地点-123", status: :active},
        changes: %{}
      }

      context = TracingUtilities.build_device_context(changeset)
      assert context.location == "地点-123"
    end

    test "handles deeply nested context" do
      changeset = %{
        __context: %{
          actor: %{
            id: "actor-deep",
            nested: %{value: "deep"}
          }
        }
      }

      assert TracingUtilities.extract_actor_id(changeset) == "actor-deep"
    end

    test "priority_to_number handles empty string" do
      assert TracingUtilities.priority_to_number("") == 2
    end

    test "importance_to_number handles empty string" do
      assert TracingUtilities.importance_to_number("") == 2
    end

    test "extract_result_id handles struct" do
      result = %{__struct__: SomeStruct, id: "struct-id"}
      assert TracingUtilities.extract_result_id(result) == "struct-id"
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "has proper module structure" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "defmodule Indrajaal.Shared.TracingUtilities"
      assert content =~ "@moduledoc"
    end

    test "defines telemetry emission function" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def emit_operation_telemetry"
      assert content =~ ":telemetry.execute"
    end

    test "defines ID extraction functions" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def extract_device_id"
      assert content =~ "def extract_alarm_id"
      assert content =~ "def extract_camera_id"
      assert content =~ "def extract_actor_id"
    end

    test "defines context building functions" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def build_device_context"
      assert content =~ "def build_alarm_context"
      assert content =~ "def build_video_context"
      assert content =~ "def build_business_context"
    end

    test "defines priority/importance conversion" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def priority_to_number"
      assert content =~ "def importance_to_number"
    end

    test "requires Logger" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "require Logger"
    end

    test "follows TPS principles" do
      source_path = "lib/indrajaal/shared/tracing_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "Toyota TPS principles"
    end
  end
end
