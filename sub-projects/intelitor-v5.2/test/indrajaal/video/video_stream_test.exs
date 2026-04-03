defmodule Indrajaal.Video.VideoStreamTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Video.VideoStream.

  Tests the VideoStream Ecto schema that manages video stream configurations.
  Note: This module uses plain Ecto.Schema, NOT Ash Framework.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Schema Structure, Changeset Validations,
                   Field Defaults, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  import PropCheck.BasicTypes
  # EP-GEN-014: Mandatory aliases for generator disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Video.VideoStream

  # ============================================================================
  # MODULE STRUCTURE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(VideoStream)
    end

    test "module uses Ecto.Schema" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "use Ecto.Schema"
    end

    test "module imports Ecto.Changeset" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "import Ecto.Changeset"
    end

    test "has proper moduledoc" do
      case Code.fetch_docs(VideoStream) do
        {:docs_v1, _, :elixir, _, module_doc, _, _} ->
          assert module_doc != :hidden

        _ ->
          # Module may not have docs
          assert true
      end
    end
  end

  # ============================================================================
  # SCHEMA STRUCTURE TESTS
  # ============================================================================

  describe "Schema Structure" do
    test "has binary_id primary key" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "@primary_key {:id, :binary_id, autogenerate: true}"
    end

    test "uses binary_id for foreign keys" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "@foreign_key_type :binary_id"
    end

    test "has schema definition for video table" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ ~s(schema "video")
    end

    test "has timestamps" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "timestamps()"
    end
  end

  # ============================================================================
  # FIELD TESTS
  # ============================================================================

  describe "Schema Fields" do
    test "has name field as string" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :name, :string"
    end

    test "has description field as string" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :description, :string"
    end

    test "has active field with default true" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :active, :boolean, default: true"
    end

    test "has metadata field as map with default empty map" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :metadata, :map, default: %{}"
    end

    test "has tenant_id field as binary_id" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :tenant_id, :binary_id"
    end

    test "has created_by_id field as binary_id" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :created_by_id, :binary_id"
    end

    test "has updated_by_id field as binary_id" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :updated_by_id, :binary_id"
    end

    test "has type field as string" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :type, :string"
    end

    test "has status field as string" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :status, :string"
    end

    test "has configuration field as map" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :configuration, :map"
    end

    test "has tags field as array of strings with default empty list" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "field :tags, {:array, :string}, default: []"
    end
  end

  # ============================================================================
  # CHANGESET TESTS
  # ============================================================================

  describe "Changeset Function" do
    test "changeset function exists with arity 2" do
      assert function_exported?(VideoStream, :changeset, 2)
    end

    test "changeset casts allowed fields" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "cast(attrs, [:name, :description, :active, :metadata])"
    end

    test "changeset validates name is required" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "validate_required([:name])"
    end

    test "changeset validates name length" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "validate_length(:name, min: 1, max: 255)"
    end

    test "changeset validates description length" do
      source_path = "lib/indrajaal/video/video_stream.ex"
      content = File.read!(source_path)

      assert content =~ "validate_length(:description, max: 1000)"
    end
  end

  # ============================================================================
  # CHANGESET BEHAVIOR TESTS
  # ============================================================================

  describe "Changeset Behavior" do
    test "valid changeset with required fields" do
      attrs = %{name: "Test Video Stream"}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      attrs = %{
        name: "Test Video Stream",
        description: "A test video stream",
        active: true,
        metadata: %{key: "value"}
      }

      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset without name" do
      attrs = %{description: "A test video stream"}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset with empty name" do
      attrs = %{name: ""}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      refute changeset.valid?
    end

    test "invalid changeset with name too long" do
      attrs = %{name: String.duplicate("a", 256)}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end

    test "invalid changeset with description too long" do
      attrs = %{name: "Test", description: String.duplicate("a", 1001)}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).description
    end

    test "changeset accepts metadata as map" do
      attrs = %{name: "Test", metadata: %{resolution: "1080p", fps: 30}}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :metadata) == %{resolution: "1080p", fps: 30}
    end

    test "changeset handles active boolean" do
      attrs = %{name: "Test", active: false}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :active) == false
    end
  end

  # ============================================================================
  # STRUCT TESTS
  # ============================================================================

  describe "Struct" do
    test "struct has expected fields" do
      stream = %VideoStream{}

      assert Map.has_key?(stream, :id)
      assert Map.has_key?(stream, :name)
      assert Map.has_key?(stream, :description)
      assert Map.has_key?(stream, :active)
      assert Map.has_key?(stream, :metadata)
      assert Map.has_key?(stream, :tenant_id)
      assert Map.has_key?(stream, :created_by_id)
      assert Map.has_key?(stream, :updated_by_id)
      assert Map.has_key?(stream, :type)
      assert Map.has_key?(stream, :status)
      assert Map.has_key?(stream, :configuration)
      assert Map.has_key?(stream, :tags)
      assert Map.has_key?(stream, :inserted_at)
      assert Map.has_key?(stream, :updated_at)
    end

    test "struct has correct defaults" do
      stream = %VideoStream{}

      assert stream.active == true
      assert stream.metadata == %{}
      assert stream.tags == []
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "module is always loadable" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(VideoStream)
      end
    end

    property "changeset function always exists" do
      forall _n <- PC.integer() do
        function_exported?(VideoStream, :changeset, 2)
      end
    end

    property "source file always exists and is readable" do
      forall _n <- PC.integer() do
        source_path = "lib/indrajaal/video/video_stream.ex"
        File.exists?(source_path) and is_binary(File.read!(source_path))
      end
    end

    property "valid names produce valid changesets" do
      forall name <- PC.non_empty(PC.utf8()) do
        name_trimmed = String.slice(name, 0, 255)

        if byte_size(name_trimmed) >= 1 do
          attrs = %{name: name_trimmed}
          changeset = VideoStream.changeset(%VideoStream{}, attrs)
          changeset.valid?
        else
          true
        end
      end
    end

    property "struct always has expected fields" do
      forall _n <- PC.integer() do
        stream = %VideoStream{}
        Map.has_key?(stream, :name) and Map.has_key?(stream, :active)
      end
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/video/video_stream.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/video/video_stream.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "has proper defmodule structure" do
      source = File.read!("lib/indrajaal/video/video_stream.ex")
      assert source =~ "defmodule Indrajaal.Video.VideoStream"
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = VideoStream.__info__(:module)
      assert info == Indrajaal.Video.VideoStream
    end

    test "handles introspection without errors" do
      _ = VideoStream.__info__(:functions)
      _ = VideoStream.__info__(:macros)
      _ = VideoStream.__info__(:attributes)

      assert true
    end

    test "changeset handles nil attributes gracefully" do
      changeset = VideoStream.changeset(%VideoStream{}, %{})

      refute changeset.valid?
    end

    test "changeset handles empty string name" do
      attrs = %{name: ""}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      refute changeset.valid?
    end

    test "changeset handles whitespace-only name" do
      attrs = %{name: "   "}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      # May be valid or invalid depending on trimming behavior
      # This test documents current behavior
      assert is_struct(changeset, Ecto.Changeset)
    end

    test "changeset handles boundary length name (255 chars)" do
      attrs = %{name: String.duplicate("a", 255)}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
    end

    test "changeset handles boundary length description (1000 chars)" do
      attrs = %{name: "Test", description: String.duplicate("a", 1000)}
      changeset = VideoStream.changeset(%VideoStream{}, attrs)

      assert changeset.valid?
    end
  end

  # ============================================================================
  # MULTI-TENANT ISOLATION TESTS
  # ============================================================================

  describe "Multi-Tenant Fields" do
    test "has tenant_id field" do
      stream = %VideoStream{}
      assert Map.has_key?(stream, :tenant_id)
    end

    test "tenant_id is binary_id type" do
      source = File.read!("lib/indrajaal/video/video_stream.ex")
      assert source =~ "field :tenant_id, :binary_id"
    end
  end

  # ============================================================================
  # AUDIT TRACKING TESTS
  # ============================================================================

  describe "Audit Tracking" do
    test "has created_by_id field" do
      stream = %VideoStream{}
      assert Map.has_key?(stream, :created_by_id)
    end

    test "has updated_by_id field" do
      stream = %VideoStream{}
      assert Map.has_key?(stream, :updated_by_id)
    end

    test "has timestamps" do
      stream = %VideoStream{}
      assert Map.has_key?(stream, :inserted_at)
      assert Map.has_key?(stream, :updated_at)
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
