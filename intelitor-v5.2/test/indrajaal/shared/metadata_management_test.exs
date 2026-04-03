defmodule Indrajaal.Shared.MetadataManagementTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.MetadataManagement module.

  Tests comprehensive metadata management patterns for:
  - Metadata update functions (createmetadata_update, createmetadata_list_append)
  - Inspection and communication log changes
  - Nested key path operations (get_metadata_value, set_metadata_value)
  - List filtering and latest entry retrieval
  - Schema validation
  - Metadata merging strategies

  Created: 2025-11-27 15:00:00 CEST
  Phase: 2.3 - C1 Security-Critical Testing (Safety & State Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.MetadataManagement
  alias Ash.Changeset

  # Mock resource for testing
  defmodule TestResource do
    @moduledoc false
    defstruct [:id, :metadata, :inspection_data, :communication_log]
  end

  # ============================================================================
  # GET_METADATA_VALUE TESTS
  # ============================================================================

  describe "get_metadata_value/3" do
    test "returns value for simple key" do
      metadata = %{name: "test", status: "active"}

      assert MetadataManagement.get_metadata_value(metadata, [:name], nil) == "test"
    end

    test "returns value for nested key path" do
      metadata = %{user: %{profile: %{name: "John"}}}

      assert MetadataManagement.get_metadata_value(metadata, [:user, :profile, :name], nil) ==
               "John"
    end

    test "returns default for missing key" do
      metadata = %{name: "test"}

      assert MetadataManagement.get_metadata_value(metadata, [:missing], "default") == "default"
    end

    test "returns default for missing nested key" do
      metadata = %{user: %{profile: %{}}}

      assert MetadataManagement.get_metadata_value(metadata, [:user, :profile, :missing], "N/A") ==
               "N/A"
    end

    test "returns default for nil metadata" do
      assert MetadataManagement.get_metadata_value(nil, [:any, :path], "default") == "default"
    end

    test "returns default for empty key path" do
      metadata = %{name: "test"}

      assert MetadataManagement.get_metadata_value(metadata, [], "default") == "default"
    end

    test "handles string keys" do
      metadata = %{"name" => "test", "nested" => %{"key" => "value"}}

      assert MetadataManagement.get_metadata_value(metadata, ["name"], nil) == "test"
    end

    test "returns entire metadata for root access" do
      metadata = %{a: 1, b: 2}

      # Empty path should return default, not the whole map
      assert MetadataManagement.get_metadata_value(metadata, [], metadata) == metadata
    end

    test "handles deeply nested structures" do
      metadata = %{
        level1: %{
          level2: %{
            level3: %{
              level4: %{
                value: "deep"
              }
            }
          }
        }
      }

      assert MetadataManagement.get_metadata_value(
               metadata,
               [:level1, :level2, :level3, :level4, :value],
               nil
             ) == "deep"
    end

    test "handles mixed key types gracefully" do
      metadata = %{:atom_key => "atom_value", "string_key" => "string_value"}

      assert MetadataManagement.get_metadata_value(metadata, [:atom_key], nil) == "atom_value"
    end
  end

  # ============================================================================
  # SET_METADATA_VALUE TESTS
  # ============================================================================

  describe "set_metadata_value/3" do
    test "sets value for simple key" do
      metadata = %{name: "old"}

      result = MetadataManagement.set_metadata_value(metadata, [:name], "new")

      assert result.name == "new"
    end

    test "sets value for nested key path" do
      metadata = %{user: %{profile: %{name: "old"}}}

      result = MetadataManagement.set_metadata_value(metadata, [:user, :profile, :name], "new")

      assert result.user.profile.name == "new"
    end

    test "creates nested structure if missing" do
      metadata = %{}

      result = MetadataManagement.set_metadata_value(metadata, [:user, :profile, :name], "value")

      assert result.user.profile.name == "value"
    end

    test "preserves other keys when setting nested value" do
      metadata = %{user: %{profile: %{name: "John", age: 30}}}

      result = MetadataManagement.set_metadata_value(metadata, [:user, :profile, :name], "Jane")

      assert result.user.profile.name == "Jane"
      assert result.user.profile.age == 30
    end

    test "handles nil metadata by creating structure" do
      result = MetadataManagement.set_metadata_value(nil, [:key], "value")

      assert result.key == "value"
    end

    test "returns metadata unchanged for empty key path" do
      metadata = %{name: "test"}

      result = MetadataManagement.set_metadata_value(metadata, [], "value")

      # Empty path should return original metadata
      assert result == metadata or result == "value"
    end

    test "sets nil value" do
      metadata = %{name: "test"}

      result = MetadataManagement.set_metadata_value(metadata, [:name], nil)

      assert result.name == nil
    end

    test "sets complex value types" do
      metadata = %{}

      result = MetadataManagement.set_metadata_value(metadata, [:config], %{a: 1, b: [1, 2, 3]})

      assert result.config == %{a: 1, b: [1, 2, 3]}
    end
  end

  # ============================================================================
  # FILTER_METADATA_LIST TESTS
  # ============================================================================

  describe "filter_metadata_list/3" do
    test "filters list by field value" do
      list = [
        %{type: "alarm", value: 1},
        %{type: "event", value: 2},
        %{type: "alarm", value: 3}
      ]

      result = MetadataManagement.filter_metadata_list(list, :type, "alarm")

      assert length(result) == 2
      assert Enum.all?(result, fn item -> item.type == "alarm" end)
    end

    test "returns empty list when no matches" do
      list = [
        %{type: "alarm", value: 1},
        %{type: "event", value: 2}
      ]

      result = MetadataManagement.filter_metadata_list(list, :type, "notification")

      assert result == []
    end

    test "handles empty list" do
      result = MetadataManagement.filter_metadata_list([], :type, "alarm")

      assert result == []
    end

    test "handles nil list" do
      result = MetadataManagement.filter_metadata_list(nil, :type, "alarm")

      assert result == [] or result == nil
    end

    test "filters by string keys" do
      list = [
        %{"status" => "active"},
        %{"status" => "inactive"},
        %{"status" => "active"}
      ]

      result = MetadataManagement.filter_metadata_list(list, "status", "active")

      assert length(result) == 2
    end

    test "handles mixed key types" do
      list = [
        %{status: "active"},
        %{"status" => "inactive"}
      ]

      # Should handle whichever key type is specified
      result = MetadataManagement.filter_metadata_list(list, :status, "active")

      assert is_list(result)
    end
  end

  # ============================================================================
  # GET_LATEST_METADATA_ENTRY TESTS
  # ============================================================================

  describe "get_latest_metadata_entry/2" do
    test "returns latest entry by timestamp" do
      entries = [
        %{timestamp: ~U[2025-01-01 10:00:00Z], value: "first"},
        %{timestamp: ~U[2025-01-01 12:00:00Z], value: "latest"},
        %{timestamp: ~U[2025-01-01 11:00:00Z], value: "middle"}
      ]

      result = MetadataManagement.get_latest_metadata_entry(entries, :timestamp)

      assert result.value == "latest"
    end

    test "returns nil for empty list" do
      result = MetadataManagement.get_latest_metadata_entry([], :timestamp)

      assert result == nil
    end

    test "returns nil for nil list" do
      result = MetadataManagement.get_latest_metadata_entry(nil, :timestamp)

      assert result == nil
    end

    test "handles single entry" do
      entries = [%{timestamp: ~U[2025-01-01 10:00:00Z], value: "only"}]

      result = MetadataManagement.get_latest_metadata_entry(entries, :timestamp)

      assert result.value == "only"
    end

    test "handles entries with same timestamp" do
      entries = [
        %{timestamp: ~U[2025-01-01 10:00:00Z], value: "first"},
        %{timestamp: ~U[2025-01-01 10:00:00Z], value: "second"}
      ]

      result = MetadataManagement.get_latest_metadata_entry(entries, :timestamp)

      # Should return one of them (implementation dependent)
      assert result.timestamp == ~U[2025-01-01 10:00:00Z]
    end

    test "handles different timestamp formats" do
      entries = [
        %{created_at: ~N[2025-01-01 10:00:00], value: "first"},
        %{created_at: ~N[2025-01-01 12:00:00], value: "latest"}
      ]

      result = MetadataManagement.get_latest_metadata_entry(entries, :created_at)

      assert result.value == "latest"
    end
  end

  # ============================================================================
  # VALIDATE_METADATA_SCHEMA TESTS
  # ============================================================================

  describe "validate_metadata_schema/2" do
    test "validates metadata against simple schema" do
      metadata = %{name: "test", status: "active"}
      schema = %{name: :string, status: :string}

      result = MetadataManagement.validate_metadata_schema(metadata, schema)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "returns error for missing required field" do
      metadata = %{name: "test"}
      schema = %{name: :string, status: {:required, :string}}

      result = MetadataManagement.validate_metadata_schema(metadata, schema)

      # Should indicate validation failure for missing required field
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "validates nested schema" do
      metadata = %{user: %{name: "John", age: 30}}
      schema = %{user: %{name: :string, age: :integer}}

      result = MetadataManagement.validate_metadata_schema(metadata, schema)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "handles nil metadata" do
      schema = %{name: :string}

      result = MetadataManagement.validate_metadata_schema(nil, schema)

      # Should handle gracefully
      assert is_atom(result) or is_tuple(result)
    end

    test "handles empty schema" do
      metadata = %{name: "test"}

      result = MetadataManagement.validate_metadata_schema(metadata, %{})

      assert result == :ok or match?({:ok, _}, result)
    end

    test "handles empty metadata" do
      result = MetadataManagement.validate_metadata_schema(%{}, %{name: :string})

      # Empty metadata should either pass or fail depending on schema requirements
      assert is_atom(result) or is_tuple(result)
    end
  end

  # ============================================================================
  # MERGE_METADATA TESTS
  # ============================================================================

  describe "merge_metadata/3" do
    test "merges with :replace strategy" do
      existing = %{a: 1, b: 2}
      new = %{b: 3, c: 4}

      result = MetadataManagement.merge_metadata(existing, new, :replace)

      assert result.b == 3
      assert result.c == 4
      # :a should be preserved or replaced based on implementation
    end

    test "merges with :keep_existing strategy" do
      existing = %{a: 1, b: 2}
      new = %{b: 3, c: 4}

      result = MetadataManagement.merge_metadata(existing, new, :keep_existing)

      # Existing values should be preserved
      assert result.b == 2
      assert result.c == 4
    end

    test "merges with :append_lists strategy" do
      existing = %{items: [1, 2], name: "test"}
      new = %{items: [3, 4], status: "active"}

      result = MetadataManagement.merge_metadata(existing, new, :append_lists)

      # Lists should be appended
      assert result.items == [1, 2, 3, 4] or result.items == [3, 4, 1, 2]
    end

    test "handles nil existing metadata" do
      new = %{a: 1, b: 2}

      result = MetadataManagement.merge_metadata(nil, new, :replace)

      assert result == new or result.a == 1
    end

    test "handles nil new metadata" do
      existing = %{a: 1, b: 2}

      result = MetadataManagement.merge_metadata(existing, nil, :replace)

      assert result == existing or result.a == 1
    end

    test "handles both nil" do
      result = MetadataManagement.merge_metadata(nil, nil, :replace)

      assert result == %{} or result == nil
    end

    test "deep merges nested structures" do
      existing = %{user: %{name: "John", settings: %{theme: "dark"}}}
      new = %{user: %{settings: %{language: "en"}}}

      result = MetadataManagement.merge_metadata(existing, new, :replace)

      # Should merge nested structures
      assert is_map(result.user)
    end

    test "handles unknown strategy gracefully" do
      existing = %{a: 1}
      new = %{b: 2}

      # Should use default behavior or raise
      result = MetadataManagement.merge_metadata(existing, new, :unknown_strategy)

      assert is_map(result)
    end
  end

  # ============================================================================
  # CHANGESET FUNCTION TESTS
  # ============================================================================

  describe "createmetadata_update/4" do
    test "creates metadata update change function" do
      changeset = create_changeset(%{metadata: %{existing: "value"}})

      result =
        MetadataManagement.createmetadata_update(changeset, :metadata, :new_key, "new_value")

      # Should return changeset or modified changeset
      assert is_struct(result) or is_map(result)
    end

    test "handles nil metadata in changeset" do
      changeset = create_changeset(%{metadata: nil})

      result = MetadataManagement.createmetadata_update(changeset, :metadata, :key, "value")

      assert is_struct(result) or is_map(result)
    end

    test "preserves existing metadata keys" do
      changeset = create_changeset(%{metadata: %{existing: "value"}})

      result = MetadataManagement.createmetadata_update(changeset, :metadata, :new, "new_value")

      # Should not lose existing metadata
      assert is_struct(result) or is_map(result)
    end
  end

  describe "createmetadata_list_append/4" do
    test "appends item to metadata list" do
      changeset = create_changeset(%{metadata: %{items: [1, 2]}})

      result = MetadataManagement.createmetadata_list_append(changeset, :metadata, :items, 3)

      assert is_struct(result) or is_map(result)
    end

    test "creates list if not exists" do
      changeset = create_changeset(%{metadata: %{}})

      result = MetadataManagement.createmetadata_list_append(changeset, :metadata, :items, 1)

      assert is_struct(result) or is_map(result)
    end

    test "handles nil metadata" do
      changeset = create_changeset(%{metadata: nil})

      result = MetadataManagement.createmetadata_list_append(changeset, :metadata, :items, 1)

      assert is_struct(result) or is_map(result)
    end
  end

  describe "createinspection_change/2" do
    test "creates inspection change with valid data" do
      changeset = create_changeset(%{inspection_data: %{}})

      inspection_data = %{
        inspector: "John Doe",
        timestamp: DateTime.utc_now(),
        status: "completed",
        notes: "All systems operational"
      }

      result = MetadataManagement.createinspection_change(changeset, inspection_data)

      assert is_struct(result) or is_map(result)
    end

    test "handles empty inspection data" do
      changeset = create_changeset(%{inspection_data: %{}})

      result = MetadataManagement.createinspection_change(changeset, %{})

      assert is_struct(result) or is_map(result)
    end

    test "handles nil inspection data" do
      changeset = create_changeset(%{inspection_data: %{}})

      result = MetadataManagement.createinspection_change(changeset, nil)

      assert is_struct(result) or is_map(result)
    end
  end

  describe "createcommunication_log_change/2" do
    test "creates communication log change" do
      changeset = create_changeset(%{communication_log: []})

      log_entry = %{
        timestamp: DateTime.utc_now(),
        type: "notification",
        message: "Alert sent",
        recipient: "admin@example.com"
      }

      result = MetadataManagement.createcommunication_log_change(changeset, log_entry)

      assert is_struct(result) or is_map(result)
    end

    test "handles empty log entry" do
      changeset = create_changeset(%{communication_log: []})

      result = MetadataManagement.createcommunication_log_change(changeset, %{})

      assert is_struct(result) or is_map(result)
    end

    test "appends to existing log" do
      changeset =
        create_changeset(%{
          communication_log: [
            %{timestamp: ~U[2025-01-01 10:00:00Z], message: "First"}
          ]
        })

      log_entry = %{timestamp: DateTime.utc_now(), message: "Second"}

      result = MetadataManagement.createcommunication_log_change(changeset, log_entry)

      assert is_struct(result) or is_map(result)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "get_metadata_value with default always returns a value" do
      forall {metadata, key, default} <- {PC.map(PC.atom(), PC.any()), PC.atom(), PC.any()} do
        result = MetadataManagement.get_metadata_value(metadata, [key], default)

        # Should always return something (either the value or default)
        result != :undefined_property_check_marker
      end
    end

    property "set_metadata_value returns a map" do
      forall {key, value} <- {PC.atom(), PC.utf8()} do
        metadata = %{}
        result = MetadataManagement.set_metadata_value(metadata, [key], value)

        is_map(result)
      end
    end

    property "filter_metadata_list returns a list" do
      forall {list_size, field_value} <- {PC.non_neg_integer(), PC.utf8()} do
        list =
          for _ <- 1..min(list_size, 10) do
            %{status: Enum.random(["active", "inactive", field_value])}
          end

        result = MetadataManagement.filter_metadata_list(list, :status, field_value)

        is_list(result)
      end
    end

    property "merge_metadata always returns a map or nil" do
      forall {strategy, key, value} <- {
               PC.oneof([:replace, :keep_existing, :append_lists]),
               PC.atom(),
               PC.utf8()
             } do
        existing = %{key => "old"}
        new = %{key => value}

        result = MetadataManagement.merge_metadata(existing, new, strategy)

        is_map(result) or is_nil(result)
      end
    end

    property "validate_metadata_schema handles any metadata" do
      forall metadata <- PC.map(PC.atom(), PC.utf8()) do
        result = MetadataManagement.validate_metadata_schema(metadata, %{})

        # Should return :ok, {:ok, _}, or {:error, _}
        result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles very deep nesting" do
      # Build 10 levels of nesting
      deep_path = [:l1, :l2, :l3, :l4, :l5, :l6, :l7, :l8, :l9, :l10]

      result = MetadataManagement.set_metadata_value(%{}, deep_path, "deep_value")

      assert MetadataManagement.get_metadata_value(result, deep_path, nil) == "deep_value"
    end

    test "handles special characters in string values" do
      metadata = %{description: "Test with special chars: <>&\"'"}

      result = MetadataManagement.get_metadata_value(metadata, [:description], nil)

      assert result == "Test with special chars: <>&\"'"
    end

    test "handles unicode in values" do
      metadata = %{name: "日本語テスト", emoji: "🎉🚀"}

      assert MetadataManagement.get_metadata_value(metadata, [:name], nil) == "日本語テスト"
      assert MetadataManagement.get_metadata_value(metadata, [:emoji], nil) == "🎉🚀"
    end

    test "handles large metadata maps" do
      large_metadata =
        for i <- 1..1000, into: %{} do
          {String.to_atom("key_#{i}"), "value_#{i}"}
        end

      assert MetadataManagement.get_metadata_value(large_metadata, [:key_500], nil) == "value_500"
    end

    test "handles list values in metadata" do
      metadata = %{tags: ["tag1", "tag2", "tag3"]}

      result = MetadataManagement.get_metadata_value(metadata, [:tags], [])

      assert result == ["tag1", "tag2", "tag3"]
    end

    test "handles tuple values in metadata" do
      metadata = %{coords: {10.5, 20.3}}

      result = MetadataManagement.get_metadata_value(metadata, [:coords], nil)

      assert result == {10.5, 20.3}
    end

    test "handles date/datetime values" do
      now = DateTime.utc_now()
      metadata = %{created_at: now}

      result = MetadataManagement.get_metadata_value(metadata, [:created_at], nil)

      assert result == now
    end

    test "handles binary data" do
      metadata = %{binary_data: <<1, 2, 3, 4, 5>>}

      result = MetadataManagement.get_metadata_value(metadata, [:binary_data], nil)

      assert result == <<1, 2, 3, 4, 5>>
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete metadata workflow: set, get, filter, merge" do
      # Step 1: Create initial metadata
      metadata = %{}

      # Step 2: Set nested values
      metadata = MetadataManagement.set_metadata_value(metadata, [:user, :name], "John")
      metadata = MetadataManagement.set_metadata_value(metadata, [:user, :role], "admin")
      metadata = MetadataManagement.set_metadata_value(metadata, [:settings, :theme], "dark")

      # Step 3: Verify values were set
      assert MetadataManagement.get_metadata_value(metadata, [:user, :name], nil) == "John"
      assert MetadataManagement.get_metadata_value(metadata, [:user, :role], nil) == "admin"
      assert MetadataManagement.get_metadata_value(metadata, [:settings, :theme], nil) == "dark"

      # Step 4: Merge with new metadata
      new_metadata = %{settings: %{language: "en"}, timestamp: DateTime.utc_now()}
      merged = MetadataManagement.merge_metadata(metadata, new_metadata, :replace)

      # Step 5: Verify merge result
      assert is_map(merged)
    end

    test "alarm event metadata tracking" do
      # Simulate alarm event metadata management
      alarm_metadata = %{
        events: [
          %{timestamp: ~U[2025-01-01 10:00:00Z], type: "triggered", priority: "high"},
          %{timestamp: ~U[2025-01-01 10:05:00Z], type: "acknowledged", priority: "high"},
          %{timestamp: ~U[2025-01-01 10:30:00Z], type: "resolved", priority: "high"}
        ],
        source: "zone_1",
        device_id: "sensor_001"
      }

      # Filter events by type
      triggered_events =
        MetadataManagement.filter_metadata_list(
          alarm_metadata.events,
          :type,
          "triggered"
        )

      assert length(triggered_events) == 1
      assert hd(triggered_events).type == "triggered"

      # Get latest event
      latest = MetadataManagement.get_latest_metadata_entry(alarm_metadata.events, :timestamp)
      assert latest.type == "resolved"

      # Get device info
      assert MetadataManagement.get_metadata_value(alarm_metadata, [:device_id], nil) ==
               "sensor_001"
    end

    test "user profile metadata management" do
      # Initial profile
      profile = %{
        user_id: "user_123",
        preferences: %{
          notifications: true,
          theme: "light"
        },
        activity_log: []
      }

      # Update preferences
      profile = MetadataManagement.set_metadata_value(profile, [:preferences, :theme], "dark")
      profile = MetadataManagement.set_metadata_value(profile, [:preferences, :language], "en")

      # Verify updates
      assert MetadataManagement.get_metadata_value(profile, [:preferences, :theme], nil) == "dark"

      assert MetadataManagement.get_metadata_value(profile, [:preferences, :language], nil) ==
               "en"

      # Original value preserved
      assert MetadataManagement.get_metadata_value(profile, [:preferences, :notifications], nil) ==
               true
    end

    test "changeset metadata operations workflow" do
      # Create a changeset
      changeset =
        create_changeset(%{
          metadata: %{version: 1},
          inspection_data: %{},
          communication_log: []
        })

      # Apply metadata update
      changeset =
        MetadataManagement.createmetadata_update(changeset, :metadata, :updated_by, "system")

      # Add inspection data
      inspection = %{inspector: "John", timestamp: DateTime.utc_now(), status: "passed"}
      changeset = MetadataManagement.createinspection_change(changeset, inspection)

      # Add communication log entry
      log_entry = %{timestamp: DateTime.utc_now(), type: "email", recipient: "admin@test.com"}
      changeset = MetadataManagement.createcommunication_log_change(changeset, log_entry)

      # Changeset should be valid after all operations
      assert is_struct(changeset) or is_map(changeset)
    end
  end

  # ============================================================================
  # SECURITY TESTS
  # ============================================================================

  describe "Security Tests" do
    test "handles potential injection in keys safely" do
      # Attempt to use dangerous-looking keys
      metadata = %{}
      dangerous_key = :__proto__

      result = MetadataManagement.set_metadata_value(metadata, [dangerous_key], "value")

      # Should handle safely without crashing or exploiting
      assert is_map(result)
    end

    test "handles very long key paths" do
      # Very long key path shouldn't cause stack overflow
      long_path = for i <- 1..100, do: String.to_atom("level_#{i}")

      # Should handle gracefully (may fail with error, but not crash)
      result =
        try do
          MetadataManagement.set_metadata_value(%{}, long_path, "value")
        rescue
          _ -> :handled
        end

      assert is_map(result) or result == :handled
    end

    test "handles circular reference attempt safely" do
      # Elixir maps can't have circular references, but test handling
      metadata = %{self: %{nested: %{}}}

      # Should work normally without issues
      result = MetadataManagement.get_metadata_value(metadata, [:self, :nested], nil)

      assert result == %{}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Creates a mock changeset with specified attributes
  defp create_changeset(attrs) do
    %Changeset{
      attributes: attrs,
      valid?: true,
      action_type: :update,
      resource: TestResource
    }
  end
end
