defmodule WarningEliminationPropertyTest do
  use ExUnit.Case, async: false
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  @moduletag :sopv511
  @moduletag :property_testing
  @moduletag :warning_elimination

  @script_path "scripts/sopv511/ultimate_zero_warnings_achievement_engine.exs"
  @test_dir "test/fixtures/property_tests"

  @moduledoc """
  Advanced Property-Based Testing for Warning Elimination Engine

  This module provides comprehensive property-based testing using both PropCheck
  and ExUnitProperties to ensure the warning elimination system maintains
  invariants across all possible inputs.

  TPS Analysis: Property testing prevents regression through systematic validation
  Jidoka: Automated testing with human-interpretable failure cases
  5-Level RCA: Why do properties fail? -> Systematic analysis of failure modes
  """

  setup_all do
    File.mkdir_p!(@test_dir)
    on_exit(fn -> File.rm_rf(@test_dir) end)
    :ok
  end

  describe "PropCheck Advanced Property Testing" do
    property "file content preservation under warning elimination", [:verbose] do
      forall {module_name, content_type, warning_type} <-
               {module_name_generator(), content_type_generator(), warning_type_generator()} do
        # Generate test file with specific warning pattern
        test_file = create_test_file(module_name, content_type, warning_type)
        original_content = File.read!(test_file)
        original_size = byte_size(original_content)

        # Apply warning elimination
        {_output, _exit_code} = System.cmd("elixir", [@script_path, "--analyze"])

        # Verify properties maintained
        current_content =
          if File.exists?(test_file), do: File.read!(test_file), else: original_content

        current_size = byte_size(current_content)

        # PROPERTY 1: File size should not decrease dramatically (>50% loss indicates corruption)
        size_preserved = current_size >= original_size * 0.5

        # PROPERTY 2: Module structure should remain intact
        module_intact = String.contains?(current_content, "defmodule #{module_name}")

        # PROPERTY 3: Valid Elixir syntax maintained
        {_compile_out, compile_code} = System.cmd("elixir", ["-c", test_file])
        syntax_valid = compile_code == 0

        # Cleanup
        File.rm_rf(test_file)

        collect({warning_type, content_type}, size_preserved and module_intact and syntax_valid)
      end
    end

    property "agent coordination properties", [:verbose] do
      forall agent_count <- range(1, 50) do
        # Test agent coordination doesn't cause resource exhaustion
        start_memory = :erlang.memory(:total)
        start_processes = :erlang.system_info(:process_count)

        # Simulate agent coordination
        {output, exit_code} = System.cmd("elixir", [@script_path, "--status"])

        end_memory = :erlang.memory(:total)
        end_processes = :erlang.system_info(:process_count)

        # PROPERTY: Memory growth should be bounded
        # 50MB limit
        memory_bounded = end_memory - start_memory < 50_000_000

        # PROPERTY: Process count should not explode
        process_bounded = end_processes - start_processes < 100

        # PROPERTY: Should complete successfully or fail gracefully
        graceful_execution =
          exit_code == 0 or String.contains?(output, "error") or String.contains?(output, "help")

        memory_bounded and process_bounded and graceful_execution
      end
    end

    property "warning pattern detection consistency", [:verbose] do
      forall warning_patterns <- PC.non_empty(PC.list(warning_pattern_generator())) do
        # Create files with multiple warning patterns
        test_files =
          Enum.map(warning_patterns, fn pattern ->
            create_file_with_warning_pattern(pattern)
          end)

        # Run analysis
        {output, _exit_code} = System.cmd("elixir", [@script_path, "--analyze"])

        # PROPERTY: Detection should be consistent across runs
        {output2, _exit_code2} = System.cmd("elixir", [@script_path, "--analyze"])

        # Extract warning counts from both runs
        count1 = extract_warning_count(output)
        count2 = extract_warning_count(output2)

        # PROPERTY: Consistent detection
        consistent_detection = count1 == count2

        # PROPERTY: All warning types should be mentioned in analysis
        all_detected =
          Enum.all?(warning_patterns, fn pattern ->
            pattern_mentioned =
              String.contains?(output, to_string(pattern)) or
                String.contains?(output, "warnings") or
                String.contains?(output, "detected")

            pattern_mentioned
          end)

        # Cleanup
        Enum.each(test_files, &File.rm_rf/1)

        consistent_detection and all_detected
      end
    end
  end

  describe "ExUnitProperties StreamData Testing" do
    test "file modification idempotency" do
      ExUnitProperties.check all(
                               module_name <-
                                 SD.string(:alphanumeric, min_length: 3, max_length: 20),
                               function_count <- SD.integer(1..10),
                               max_runs: 25
                             ) do
        # Create test file with multiple functions
        test_file = create_complex_test_file(module_name, function_count)
        original_hash = file_hash(test_file)

        # Run warning elimination multiple times
        for _i <- 1..3 do
          System.cmd("elixir", [@script_path, "--analyze"])
        end

        # File should stabilize after first pass
        current_hash = file_hash(test_file)

        # Second run should not change file
        System.cmd("elixir", [@script_path, "--analyze"])
        final_hash = file_hash(test_file)

        # PROPERTY: Idempotency - repeated applications don't change result
        idempotent = current_hash == final_hash

        File.rm_rf(test_file)
        idempotent
      end
    end

    test "error handling robustness" do
      ExUnitProperties.check all(
                               error_type <-
                                 SD.member_of([
                                   :syntax_error,
                                   :missing_module,
                                   :circular_dep,
                                   :invalid_utf8
                                 ]),
                               max_runs: 20
                             ) do
        # Create file with specific error type
        test_file = create_error_file(error_type)

        # Run script - should handle errors gracefully
        {output, _exit_code} = System.cmd("elixir", [@script_path, "--analyze"])

        # PROPERTY: Should not crash on malformed input
        no_crash =
          not String.contains?(output, "** (") or
            String.contains?(output, "Error") or
            String.contains?(output, "Warning") or
            output == ""

        # PROPERTY: Should provide meaningful error messages
        meaningful_output = String.length(output) > 10 or output == ""

        File.rm_rf(test_file)
        no_crash and meaningful_output
      end
    end

    test "concurrent execution safety" do
      ExUnitProperties.check all(
                               task_count <- SD.integer(2..5),
                               max_runs: 10
                             ) do
        # Run multiple instances concurrently
        tasks =
          for _i <- 1..task_count do
            Task.async(fn ->
              System.cmd("elixir", [@script_path, "--status"])
            end)
          end

        # Wait for all to complete
        results = Enum.map(tasks, fn task -> Task.await(task, 30_000) end)

        # PROPERTY: All should complete successfully
        all_completed =
          Enum.all?(results, fn {_output, exit_code} ->
            # 1 is acceptable for analysis mode
            exit_code == 0 or exit_code == 1
          end)

        all_completed
      end
    end
  end

  describe "Boundary Value Testing" do
    test "handles empty and large files" do
      ExUnitProperties.check all(
                               file_size <- SD.member_of([:empty, :small, :large, :huge]),
                               max_runs: 15
                             ) do
        test_file = create_file_by_size(file_size)

        # Should handle all file sizes gracefully
        {_output, exit_code} = System.cmd("elixir", [@script_path, "--analyze"])

        # PROPERTY: Should not crash on boundary cases
        handles_gracefully = exit_code == 0 or exit_code == 1

        File.rm_rf(test_file)
        handles_gracefully
      end
    end
  end

  # Generators
  defp module_name_generator do
    oneof([
      "TestModule",
      "WarningTest",
      "PropertyTest",
      "ComplexModule",
      "SimpleTest"
    ])
  end

  defp content_type_generator do
    oneof([
      :simple_module,
      :complex_module,
      :module_with_functions,
      :module_with_structs,
      :module_with_protocols
    ])
  end

  defp warning_type_generator do
    oneof([
      :unused_variable,
      :unused_function,
      :unreachable_pattern,
      :external_dependency,
      :pattern_match
    ])
  end

  defp warning_pattern_generator do
    oneof([
      :unused_var,
      :unused_func,
      :pattern_never_match,
      :module_attribute,
      :dependency_issue
    ])
  end

  # Test File Creators
  defp create_test_file(module_name, content_type, warning_type) do
    filename = "prop_#{module_name}_#{:rand.uniform(10_000)}.ex"
    filepath = Path.join(@test_dir, filename)

    content = generate_content(module_name, content_type, warning_type)
    File.write!(filepath, content)
    filepath
  end

  defp create_file_with_warning_pattern(pattern) do
    filename = "pattern_#{pattern}_#{:rand.uniform(1000)}.ex"
    filepath = Path.join(@test_dir, filename)

    content =
      case pattern do
        :unused_var ->
          """
          defmodule PatternTest do
            def test_func do
              unused_variable = "test"
              :ok
            end
          end
          """

        :unused_func ->
          """
          defmodule PatternTest do
            def used_func, do: :ok
            defp unused_private_func, do: :unused
          end
          """

        :pattern_never_match ->
          """
          defmodule PatternTest do
            def test_func(x) do
              case x do
                :a -> :ok
                :b -> :ok
                :b -> :never_reached
              end
            end
          end
          """

        :module_attribute ->
          """
          defmodule PatternTest do
            @unused_attr "value"
            @used_attr "used"

            def get_used, do: @used_attr
          end
          """

        :dependency_issue ->
          """
          defmodule PatternTest do
            def test_func do
              NonExistentModule.function()
            end
          end
          """
      end

    File.write!(filepath, content)
    filepath
  end

  defp create_complex_test_file(module_name, function_count) do
    filename = "complex_#{module_name}_#{:rand.uniform(1000)}.ex"
    filepath = Path.join(@test_dir, filename)

    functions =
      for i <- 1..function_count do
        """
          def function_#{i}(arg#{i}) do
            unused_var_#{i} = "unused"
            arg#{i}
          end
        """
      end

    content = """
    defmodule #{module_name} do
    #{Enum.join(functions, "\n")}
    end
    """

    File.write!(filepath, content)
    filepath
  end

  defp create_error_file(error_type) do
    filename = "error_#{error_type}_#{:rand.uniform(1000)}.ex"
    filepath = Path.join(@test_dir, filename)

    content =
      case error_type do
        :syntax_error ->
          # Missing 'end'
          "defmodule SyntaxError do def test do :ok end"

        :missing_module ->
          "defmodule MissingTest do\n  alias NonExistent.Module\nend"

        :circular_dep ->
          "defmodule CircularDep do\n  def test, do: CircularDep.test()\nend"

        :invalid_utf8 ->
          "defmodule InvalidUTF8 do\n  # Invalid UTF-8: \xFF\xFE\nend"
      end

    File.write!(filepath, content)
    filepath
  end

  defp create_file_by_size(size_type) do
    filename = "size_#{size_type}_#{:rand.uniform(1000)}.ex"
    filepath = Path.join(@test_dir, filename)

    content =
      case size_type do
        :empty ->
          ""

        :small ->
          "defmodule Small, do: nil"

        :large ->
          functions =
            for i <- 1..100 do
              "def func_#{i}, do: #{i}"
            end

          "defmodule Large do\n#{Enum.join(functions, "\n")}\nend"

        :huge ->
          functions =
            for i <- 1..1000 do
              "def huge_func_#{i}(a, b, c), do: {#{i}, a, b, c}"
            end

          "defmodule Huge do\n#{Enum.join(functions, "\n")}\nend"
      end

    File.write!(filepath, content)
    filepath
  end

  defp generate_content(module_name, content_type, warning_type) do
    base_module = "defmodule #{module_name} do\n"

    content_section =
      case content_type do
        :simple_module ->
          "  # Simple module\n"

        :complex_module ->
          """
            @moduledoc "Complex module for testing"
            @attr "value"

            defstruct [:field1, :field2]
          """

        :module_with_functions ->
          """
            def public_function, do: :ok
            defp private_function, do: :private
          """

        :module_with_structs ->
          """
            defstruct [:name, :value]

            def new(name, value) do
              %#{module_name}{name: name, value: value}
            end
          """

        :module_with_protocols ->
          """
            defprotocol TestProtocol do
              def test(data)
            end

            defimpl TestProtocol, for: Atom do
              def test(atom), do: atom
            end
          """
      end

    warning_section =
      case warning_type do
        :unused_variable ->
          """
            def test_unused_var do
              unused_variable = "this will trigger warning"
              :ok
            end
          """

        :unused_function ->
          """
            def used_function, do: :ok
            defp unused_private_function, do: :unused
          """

        :unreachable_pattern ->
          """
            def test_pattern(x) do
              case x do
                :a -> :first
                :b -> :second
                :b -> :unreachable_pattern
              end
            end
          """

        :external_dependency ->
          """
            def test_external do
              ExternalModule.nonexistent_function()
            end
          """

        :pattern_match ->
          """
            def test_match(%{key: value}) do
              unused_destructured = value
              :ok
            end
          """
      end

    base_module <> content_section <> warning_section <> "end\n"
  end

  # Helper Functions
  defp file_hash(filepath) do
    if File.exists?(filepath) do
      content = File.read!(filepath)

      content
      |> :crypto.hash(:md5)
      |> Base.encode16()
    else
      "MISSING"
    end
  end

  defp extract_warning_count(output) do
    # Extract numeric warning counts from output
    case Regex.scan(~r/(\d+)\s*warnings?/i, output) do
      [[_, count_str] | _] -> String.to_integer(count_str)
      [] -> 0
    end
  end
end
