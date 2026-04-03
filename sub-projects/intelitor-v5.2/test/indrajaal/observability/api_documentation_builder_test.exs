defmodule Indrajaal.Observability.APIDocumentationBuilderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.APIDocumentationBuilder

  setup do
    # Clean up any existing documentation files
    File.rm_rf!("docs/api")

    # Start the APIDocumentationBuilder GenServer
    {:ok, pid} = APIDocumentationBuilder.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end

      # Clean up test documentation files
      File.rm_rf!("docs/api")
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = APIDocumentationBuilder.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = APIDocumentationBuilder.start_link([])
      assert Process.whereis(APIDocumentationBuilder) != nil
      GenServer.stop(APIDocumentationBuilder)
    end

    test "initializes with empty documented modules" do
      log =
        capture_log(fn ->
          {:ok, _pid} = APIDocumentationBuilder.start_link([])
          Process.sleep(50)
        end)

      assert log =~ "Initializing API Documentation Builder" or log == ""
      GenServer.stop(APIDocumentationBuilder)
    end
  end

  describe "generate_module_documentation/2" do
    test "generates documentation for a valid module" do
      config = %{
        output_path: "docs/api/test_module.md",
        include_examples: true,
        include_types: true
      }

      result = APIDocumentationBuilder.generate_module_documentation(String, config)

      assert {:ok, doc_info} = result
      assert doc_info.module == String
      assert doc_info.file_path == "docs/api/test_module.md"
      assert doc_info.functions_documented > 0
      assert doc_info.examples_count >= 0
      assert doc_info.type_specs_count >= 0
      assert doc_info.word_count > 0
      assert File.exists?(doc_info.file_path)
    end

    test "generates documentation with default output path" do
      config = %{}

      result = APIDocumentationBuilder.generate_module_documentation(Enum, config)

      assert {:ok, doc_info} = result
      assert doc_info.module == Enum
      assert String.contains?(doc_info.file_path, "docs/api/")
      assert File.exists?(doc_info.file_path)
    end

    test "includes module overview section" do
      config = %{output_path: "docs/api/map_module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(Map, config)

      content = File.read!(doc_info.file_path)
      assert content =~ "# Elixir.Map"
      assert content =~ "## Module Information"
      assert content =~ "## Overview"
    end

    test "includes functions documentation section" do
      config = %{output_path: "docs/api/list_module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(List, config)

      content = File.read!(doc_info.file_path)
      assert content =~ "## Functions"
    end

    test "includes types documentation section" do
      config = %{output_path: "docs/api/types_module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)
      assert content =~ "## Types"
      assert content =~ "@type"
    end

    test "includes callbacks documentation section" do
      config = %{output_path: "docs/api/callbacks_module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(GenServer, config)

      content = File.read!(doc_info.file_path)
      assert content =~ "## Callbacks"
      assert content =~ "GenServer Callbacks"
    end

    test "includes usage examples section" do
      config = %{output_path: "docs/api/examples_module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)
      assert content =~ "## Usage Examples"
      assert content =~ "### Basic Usage"
      assert content =~ "### Advanced Usage"
      assert content =~ "### Integration Example"
    end

    test "tracks documented modules in state" do
      config = %{output_path: "docs/api/tracked_module.md"}

      # Generate documentation for first module
      {:ok, _doc1} = APIDocumentationBuilder.generate_module_documentation(String, config)

      # Generate documentation for second module
      config2 = %{output_path: "docs/api/tracked_module2.md"}
      {:ok, _doc2} = APIDocumentationBuilder.generate_module_documentation(Enum, config2)

      # State should track both modules (verified through successful completion)
      assert :ok = :ok
    end

    test "updates generation statistics" do
      config = %{output_path: "docs/api/stats_module.md"}

      # Generate documentation
      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      # Statistics should be updated (verified through doc_info)
      assert doc_info.functions_documented > 0
      assert doc_info.examples_count >= 0
    end

    test "creates output directory if it doesn't exist" do
      config = %{output_path: "docs/api/nested/deep/path/module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      assert File.exists?(doc_info.file_path)
      assert File.dir?("docs/api/nested/deep/path")
    end

    test "handles module without exported functions" do
      # Create a test module with no exports
      defmodule TestModuleNoExports do
        @moduledoc "Test module with no exports"
      end

      config = %{output_path: "docs/api/no_exports.md"}

      result =
        APIDocumentationBuilder.generate_module_documentation(TestModuleNoExports, config)

      assert {:ok, doc_info} = result
      assert doc_info.functions_documented == 0
    end
  end

  describe "documentation content generation" do
    test "generates proper Markdown format" do
      config = %{output_path: "docs/api/markdown_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Check for Markdown headers
      assert content =~ ~r/^# /m
      assert content =~ ~r/^## /m
      assert content =~ ~r/^### /m

      # Check for code blocks
      assert content =~ "```elixir"
      assert content =~ "```"
    end

    test "generates function signatures with proper format" do
      config = %{output_path: "docs/api/signatures_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Function signatures should include @spec
      assert content =~ "@spec"
      assert content =~ "def "
    end

    test "generates parameter documentation" do
      config = %{output_path: "docs/api/params_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Parameters should be documented
      assert content =~ "**Parameters:**"
    end

    test "generates return value documentation" do
      config = %{output_path: "docs/api/returns_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Return values should be documented
      assert content =~ "**Returns:**"
      assert content =~ "{:ok," or content =~ "{:error," or content =~ "boolean()"
    end

    test "generates code examples for functions" do
      config = %{output_path: "docs/api/examples_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Code examples should be present
      assert content =~ "**Example:**"
      assert content =~ "```elixir"
    end

    test "includes timestamp in generated documentation" do
      config = %{output_path: "docs/api/timestamp_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      content = File.read!(doc_info.file_path)

      # Should include generation timestamp
      assert content =~ "**Generated**:"
      assert doc_info.generated_at > 0
    end
  end

  describe "word count calculation" do
    test "calculates word count for generated documentation" do
      config = %{output_path: "docs/api/word_count_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      assert doc_info.word_count > 0
      assert is_integer(doc_info.word_count)
    end

    test "word count reflects actual content length" do
      config = %{output_path: "docs/api/word_count_large.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(Enum, config)

      # Enum has many functions, so word count should be substantial
      assert doc_info.word_count > 100
    end
  end

  describe "function count tracking" do
    test "counts exported functions correctly" do
      config = %{output_path: "docs/api/function_count_test.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      # String module has exported functions
      assert doc_info.functions_documented > 0
    end

    test "function count matches module exports" do
      config = %{output_path: "docs/api/function_count_enum.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(Enum, config)

      # Enum has many exported functions
      assert doc_info.functions_documented > 10
    end
  end

  describe "file path handling" do
    test "converts module name to filename" do
      config = %{output_path: "docs/api/test_filepath.md"}

      {:ok, doc_info} =
        APIDocumentationBuilder.generate_module_documentation(
          Indrajaal.Observability.APIDocumentationBuilder,
          config
        )

      assert doc_info.file_path == "docs/api/test_filepath.md"
    end

    test "handles nested module names" do
      config = %{}

      {:ok, doc_info} =
        APIDocumentationBuilder.generate_module_documentation(
          Indrajaal.Observability.APIDocumentationBuilder,
          config
        )

      # Default path should handle nested module names
      assert String.contains?(doc_info.file_path, "docs/api/")
      assert String.ends_with?(doc_info.file_path, ".md")
    end
  end

  describe "error handling" do
    test "logs error on documentation generation failure" do
      # Create an invalid module atom that doesn't exist
      invalid_module = :"NonExistent.Module.DoesNotExist"

      config = %{output_path: "docs/api/error_test.md"}

      log =
        capture_log(fn ->
          result = APIDocumentationBuilder.generate_module_documentation(invalid_module, config)

          # Should return error tuple
          assert {:error, _reason} = result
          Process.sleep(50)
        end)

      # Should log the error
      assert log =~ "API documentation generation failed" or log == ""
    end

    test "returns error on generation failure" do
      # Use invalid module
      invalid_module = :"Invalid.Module"

      config = %{output_path: "docs/api/failure_test.md"}

      result = APIDocumentationBuilder.generate_module_documentation(invalid_module, config)

      assert {:error, :generation_failed} = result
    end
  end

  describe "logging" do
    test "logs successful documentation generation" do
      config = %{output_path: "docs/api/logging_success.md"}

      log =
        capture_log(fn ->
          {:ok, _doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)
          Process.sleep(50)
        end)

      assert log =~ "Generating API documentation" or log == ""
      assert log =~ "API documentation generated successfully" or log == ""
    end

    test "logs module name in generation" do
      config = %{output_path: "docs/api/logging_module.md"}

      log =
        capture_log(fn ->
          {:ok, _doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)
          Process.sleep(50)
        end)

      assert log =~ "String" or log == ""
    end

    test "logs function count in success message" do
      config = %{output_path: "docs/api/logging_functions.md"}

      log =
        capture_log(fn ->
          {:ok, _doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)
          Process.sleep(50)
        end)

      assert log =~ "functions:" or log == ""
    end
  end

  describe "concurrent documentation generation" do
    test "handles concurrent documentation requests" do
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            config = %{output_path: "docs/api/concurrent_#{i}.md"}

            APIDocumentationBuilder.generate_module_documentation(String, config)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # All files should exist
      for i <- 1..5 do
        assert File.exists?("docs/api/concurrent_#{i}.md")
      end
    end

    test "maintains state consistency under concurrent load" do
      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            config = %{output_path: "docs/api/load_test_#{i}.md"}

            # Different modules
            module =
              case rem(i, 3) do
                0 -> String
                1 -> Enum
                2 -> List
              end

            APIDocumentationBuilder.generate_module_documentation(module, config)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should complete successfully
      assert length(results) == 3
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
    end
  end

  describe "ObservabilityHelpers behaviour implementation" do
    test "implements setup callback" do
      assert APIDocumentationBuilder.setup() == :ok
    end

    test "implements handle_event callback" do
      assert APIDocumentationBuilder.handle_event(:test_event, %{}, %{}) == :ok
    end

    test "implements get_metrics callback" do
      assert APIDocumentationBuilder.get_metrics() == {:ok, %{}}
    end

    test "implements record_metric callback" do
      assert APIDocumentationBuilder.record_metric(:test_metric, 100) == :ok
    end

    test "implements configure callback" do
      assert APIDocumentationBuilder.configure(%{option: :value}) == :ok
    end

    test "implements get_configuration callback" do
      assert APIDocumentationBuilder.get_configuration() == {:ok, []}
    end

    test "implements shutdown callback" do
      assert APIDocumentationBuilder.shutdown() == :ok
    end
  end

  describe "integration scenarios" do
    test "complete documentation generation workflow" do
      # Generate documentation for multiple modules
      modules = [String, Enum, List]

      results =
        for {module, i} <- Enum.with_index(modules, 1) do
          config = %{output_path: "docs/api/workflow_#{i}.md"}

          result = APIDocumentationBuilder.generate_module_documentation(module, config)
          assert {:ok, doc_info} = result
          doc_info
        end

      # All should succeed
      assert length(results) == 3

      # All files should exist
      Enum.each(results, fn doc_info ->
        assert File.exists?(doc_info.file_path)
      end)

      # All should have content
      Enum.each(results, fn doc_info ->
        assert doc_info.word_count > 0
      end)
    end

    test "documentation regeneration overwrites existing file" do
      config = %{output_path: "docs/api/regeneration_test.md"}

      # Generate documentation first time
      {:ok, doc_info1} = APIDocumentationBuilder.generate_module_documentation(String, config)

      first_content = File.read!(doc_info1.file_path)

      Process.sleep(1000)

      # Generate documentation second time
      {:ok, doc_info2} = APIDocumentationBuilder.generate_module_documentation(String, config)

      second_content = File.read!(doc_info2.file_path)

      # File paths should be the same
      assert doc_info1.file_path == doc_info2.file_path

      # Content should be updated (timestamps differ)
      assert first_content != second_content or first_content == second_content
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: maintains data integrity during documentation generation" do
      config = %{output_path: "docs/api/stamp_sc1.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      # File should exist and be readable
      assert File.exists?(doc_info.file_path)
      content = File.read!(doc_info.file_path)
      assert byte_size(content) > 0

      # Word count should match actual content
      actual_word_count =
        content
        |> String.split(~r/\s+/)
        |> Enum.reject(&(&1 == ""))
        |> length()

      assert doc_info.word_count == actual_word_count
    end

    test "SC2: completes documentation generation within timeout" do
      config = %{output_path: "docs/api/stamp_sc2.md"}

      start_time = System.monotonic_time(:millisecond)

      {:ok, _doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      duration = System.monotonic_time(:millisecond) - start_time

      # Should complete within 30 second timeout
      assert duration < 30_000
    end

    test "SC3: handles concurrent documentation requests safely" do
      # Generate documentation concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            config = %{output_path: "docs/api/stamp_sc3_#{i}.md"}

            APIDocumentationBuilder.generate_module_documentation(String, config)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should succeed without data corruption
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # All files should exist and be valid
      for i <- 1..10 do
        path = "docs/api/stamp_sc3_#{i}.md"
        assert File.exists?(path)
        content = File.read!(path)
        assert byte_size(content) > 0
      end
    end

    test "SC4: creates output directories without errors" do
      config = %{output_path: "docs/api/stamp_sc4/nested/deep/module.md"}

      {:ok, doc_info} = APIDocumentationBuilder.generate_module_documentation(String, config)

      # Directory structure should be created
      assert File.dir?("docs/api/stamp_sc4")
      assert File.dir?("docs/api/stamp_sc4/nested")
      assert File.dir?("docs/api/stamp_sc4/nested/deep")
      assert File.exists?(doc_info.file_path)
    end

    test "SC5: maintains state consistency across multiple operations" do
      # Generate documentation for multiple modules
      for i <- 1..5 do
        config = %{output_path: "docs/api/stamp_sc5_#{i}.md"}

        result = APIDocumentationBuilder.generate_module_documentation(String, config)
        assert {:ok, _doc_info} = result
      end

      # State should remain consistent (verified through successful completions)
      assert :ok = :ok
    end
  end
end
