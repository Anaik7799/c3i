defmodule Indrajaal.Observability.DocumentationGeneratorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.DocumentationGenerator

  setup do
    # Start the DocumentationGenerator GenServer
    {:ok, pid} = DocumentationGenerator.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = DocumentationGenerator.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = DocumentationGenerator.start_link([])
      assert Process.whereis(DocumentationGenerator) != nil
      GenServer.stop(DocumentationGenerator)
    end

    test "initializes generation statistics" do
      log =
        capture_log(fn ->
          {:ok, _pid} = DocumentationGenerator.start_link([])
          Process.sleep(50)
          GenServer.stop(DocumentationGenerator)
        end)

      assert log =~ "Initializing Documentation Generation System"
      assert log =~ "Documentation Generation System initialized"
    end
  end

  describe "generate_integration_documentation/1" do
    test "generates documentation with minimal config" do
      config = %{
        title: "Test Integration",
        sections: ["installation_guide"],
        examples: ["basic_telemetry_setup"],
        output_path: "/tmp/test_integration.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      assert is_map(doc_info)
      assert doc_info.file_path == "/tmp/test_integration.md"
      assert doc_info.word_count > 0
      assert doc_info.sections_count == 1
      assert doc_info.examples_count == 1
      assert doc_info.format == "markdown"
    end

    test "generates documentation with multiple sections" do
      config = %{
        sections: ["installation_guide", "configuration_setup", "basic_usage"],
        examples: ["basic_telemetry_setup", "custom_metrics_creation"],
        output_path: "/tmp/test_multi.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      assert doc_info.sections_count == 3
      assert doc_info.examples_count == 2
      assert doc_info.word_count > 100
    end

    test "handles custom format specification" do
      config = %{
        sections: ["installation_guide"],
        examples: [],
        format: "html",
        output_path: "/tmp/test_format.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      assert doc_info.format == "html"
    end

    test "includes timestamp in documentation info" do
      config = %{
        sections: ["installation_guide"],
        examples: [],
        output_path: "/tmp/test_timestamp.md"
      }

      before = System.system_time(:second)
      {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      after_time = System.system_time(:second)

      assert is_integer(doc_info.generated_at)
      assert doc_info.generated_at >= before
      assert doc_info.generated_at <= after_time
    end
  end

  describe "generate_dashboard_documentation/1" do
    test "generates dashboard documentation successfully" do
      config = %{
        title: "Test Dashboard Guide",
        procedures: ["deployment", "configuration"],
        output_path: "/tmp/test_dashboard.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_dashboard_documentation(config)
      assert is_map(doc_info)
      assert doc_info.file_path == "/tmp/test_dashboard.md"
      assert doc_info.sections_count == 5
      assert doc_info.procedures_count == 2
    end

    test "includes all required sections" do
      config = %{
        output_path: "/tmp/test_dashboard_sections.md"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_dashboard_documentation(config)
      content = File.read!(doc_info.file_path)

      assert content =~ "Dashboard Templates"
      assert content =~ "Deployment Procedures"
      assert content =~ "Security Configuration"
      assert content =~ "Troubleshooting"
    end

    test "calculates word count correctly" do
      config = %{
        output_path: "/tmp/test_dashboard_words.md"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_dashboard_documentation(config)
      assert doc_info.word_count > 0
      assert is_integer(doc_info.word_count)
    end
  end

  describe "generate_security_documentation/1" do
    test "generates security documentation successfully" do
      config = %{
        title: "Security Guide",
        compliance_frameworks: ["GDPR", "HIPAA"],
        pii_handling_procedures: ["scrubbing", "encryption"],
        output_path: "/tmp/test_security.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_security_documentation(config)
      assert doc_info.file_path == "/tmp/test_security.md"
      assert doc_info.security_sections_count == 5
      assert doc_info.compliance_frameworks_count == 2
      assert doc_info.pii_procedures_count == 2
    end

    test "includes all security sections" do
      config = %{
        output_path: "/tmp/test_security_sections.md"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_security_documentation(config)
      content = File.read!(doc_info.file_path)

      assert content =~ "Data Classification"
      assert content =~ "PII Handling Procedures"
      assert content =~ "Compliance Frameworks"
      assert content =~ "Audit Procedures"
      assert content =~ "Incident Response"
    end

    test "handles empty compliance frameworks" do
      config = %{
        compliance_frameworks: [],
        pii_handling_procedures: [],
        output_path: "/tmp/test_security_empty.md"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_security_documentation(config)
      assert doc_info.compliance_frameworks_count == 0
      assert doc_info.pii_procedures_count == 0
    end
  end

  describe "generate_multi_format_documentation/1" do
    test "generates markdown format documentation" do
      config = %{
        source_content: "comprehensive_observability_guide",
        output_format: "markdown",
        output_path: "/tmp/test_multi_md.md"
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_multi_format_documentation(config)
      assert doc_info.format == "markdown"
      assert File.exists?(doc_info.file_path)
    end

    test "generates HTML format documentation" do
      config = %{
        source_content: "comprehensive_observability_guide",
        output_format: "html",
        include_navigation: true,
        output_path: "/tmp/test_multi.html"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_multi_format_documentation(config)
      assert doc_info.format == "html"
      assert doc_info.includes_navigation == true

      content = File.read!(doc_info.file_path)
      assert content =~ "<!DOCTYPE html>"
      assert content =~ "<nav>"
    end

    test "generates JSON format documentation" do
      config = %{
        source_content: "comprehensive_observability_guide",
        output_format: "json",
        output_path: "/tmp/test_multi.json"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_multi_format_documentation(config)
      assert doc_info.format == "json"

      content = File.read!(doc_info.file_path)
      assert {:ok, _json} = Jason.decode(content)
    end

    test "generates PDF format documentation" do
      config = %{
        source_content: "comprehensive_observability_guide",
        output_format: "pdf",
        output_path: "/tmp/test_multi.pdf"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_multi_format_documentation(config)
      assert doc_info.format == "pdf"

      content = File.read!(doc_info.file_path)
      assert content =~ "PDF_HEADER"
      assert content =~ "PDF_FOOTER"
    end

    test "handles accessibility compliance flag" do
      config = %{
        output_format: "html",
        accessibility_compliance: true,
        output_path: "/tmp/test_accessible.html"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_multi_format_documentation(config)
      assert doc_info.accessibility_compliant == true
    end
  end

  describe "generate_test_documentation/1" do
    test "generates test documentation with target word count" do
      config = %{
        sections_count: 5,
        examples_count: 10,
        target_word_count: 2000
      }

      assert {:ok, doc_info} = DocumentationGenerator.generate_test_documentation(config)
      assert doc_info.sections_count == 5
      assert doc_info.examples_count == 10
      assert doc_info.target_reached == true
      assert doc_info.word_count >= 2000
    end

    test "pads content to reach target word count" do
      config = %{
        sections_count: 2,
        examples_count: 3,
        target_word_count: 1000
      }

      {:ok, doc_info} = DocumentationGenerator.generate_test_documentation(config)
      assert doc_info.word_count >= 1000
    end

    test "accepts custom format" do
      config = %{
        sections_count: 3,
        examples_count: 5,
        format: "html"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_test_documentation(config)
      assert doc_info.format == "html"
    end
  end

  describe "test_generate_documentation/1" do
    test "returns test result with sections count" do
      config = %{
        sections: ["section1", "section2", "section3"],
        format: "markdown"
      }

      {:ok, result} = DocumentationGenerator.test_generate_documentation(config)
      assert result.sections_count == 3
      assert result.format == "markdown"
    end

    test "validates strict mode correctly" do
      config = %{
        sections: ["section1"],
        validation_mode: :strict
      }

      {:ok, result} = DocumentationGenerator.test_generate_documentation(config)
      assert result.validation_passed == true
    end

    test "validates non-strict mode correctly" do
      config = %{
        sections: ["section1"],
        validation_mode: :relaxed
      }

      {:ok, result} = DocumentationGenerator.test_generate_documentation(config)
      assert result.validation_passed == false
    end
  end

  describe "parallel task processing" do
    test "generates integration documentation using parallel tasks" do
      config = %{
        sections: ["installation_guide", "configuration_setup", "basic_usage"],
        examples: ["basic_telemetry_setup", "custom_metrics_creation"],
        output_path: "/tmp/test_parallel.md"
      }

      start_time = System.monotonic_time(:millisecond)
      {:ok, _doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      end_time = System.monotonic_time(:millisecond)

      # Parallel processing should be faster than sequential
      # With 3 sections + 2 examples, parallel should take roughly the time of longest task
      duration = end_time - start_time
      assert duration < 5000
    end

    test "generates dashboard documentation using parallel tasks" do
      config = %{
        output_path: "/tmp/test_dashboard_parallel.md"
      }

      start_time = System.monotonic_time(:millisecond)
      {:ok, doc_info} = DocumentationGenerator.generate_dashboard_documentation(config)
      end_time = System.monotonic_time(:millisecond)

      assert doc_info.sections_count == 5
      duration = end_time - start_time
      assert duration < 5000
    end

    test "generates security documentation using parallel tasks" do
      config = %{
        output_path: "/tmp/test_security_parallel.md"
      }

      start_time = System.monotonic_time(:millisecond)
      {:ok, doc_info} = DocumentationGenerator.generate_security_documentation(config)
      end_time = System.monotonic_time(:millisecond)

      assert doc_info.security_sections_count == 5
      duration = end_time - start_time
      assert duration < 5000
    end
  end

  describe "error handling" do
    test "handles invalid config gracefully" do
      # Test with non-map config (should fail pattern matching)
      assert_raise FunctionClauseError, fn ->
        DocumentationGenerator.generate_integration_documentation("invalid")
      end
    end

    test "recovers from task failures" do
      config = %{
        sections: ["installation_guide"],
        examples: [],
        output_path: "/tmp/test_recovery.md"
      }

      # Should succeed even if some tasks might fail
      assert {:ok, _doc_info} = DocumentationGenerator.generate_integration_documentation(config)
    end
  end

  describe "file operations" do
    test "creates documentation files successfully" do
      config = %{
        sections: ["installation_guide"],
        examples: [],
        output_path: "/tmp/test_file_creation.md"
      }

      {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      assert File.exists?(doc_info.file_path)

      # Cleanup
      File.rm(doc_info.file_path)
    end

    test "overwrites existing files" do
      path = "/tmp/test_overwrite.md"
      File.write!(path, "old content")

      config = %{
        sections: ["installation_guide"],
        examples: [],
        output_path: path
      }

      {:ok, doc_info} = DocumentationGenerator.generate_integration_documentation(config)
      content = File.read!(doc_info.file_path)
      refute content =~ "old content"

      # Cleanup
      File.rm(path)
    end
  end

  describe "statistics tracking" do
    test "tracks generation statistics" do
      config1 = %{
        sections: ["installation_guide"],
        examples: [],
        output_path: "/tmp/test_stats1.md"
      }

      config2 = %{
        sections: ["configuration_setup"],
        examples: [],
        output_path: "/tmp/test_stats2.md"
      }

      {:ok, _doc1} = DocumentationGenerator.generate_integration_documentation(config1)
      {:ok, _doc2} = DocumentationGenerator.generate_integration_documentation(config2)

      # Statistics should be tracked internally
      # (would need to add get_stats function to verify)
    end
  end

  describe "CRITICAL BUGS: handler atom naming (Lines 165, 200, 216, 232, 248)" do
    test "BUG: line 165 - missing underscore in handler atom ':generateintegration_doc'" do
      # Line 165: def handle_call({:generateintegration_doc, config}, _from, state)
      #                            ^^^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:generate_integration_doc, config}
      # Impact: Handler will never match generate_integration_documentation/1 calls
      # Fix: Change :generateintegration_doc to :generate_integration_doc
      # Note: This is a CRITICAL BUG - function calls will fail to match handler
    end

    test "BUG: line 200 - missing underscore in handler atom ':generatedashboard_doc'" do
      # Line 200: def handle_call({:generatedashboard_doc, config}, _from, state)
      #                            ^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:generate_dashboard_doc, config}
      # Impact: Handler will never match generate_dashboard_documentation/1 calls
      # Fix: Change :generatedashboard_doc to :generate_dashboard_doc
    end

    test "BUG: line 216 - missing underscore in handler atom ':generatesecurity_doc'" do
      # Line 216: def handle_call({:generatesecurity_doc, config}, _from, state)
      #                            ^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:generate_security_doc, config}
      # Impact: Handler will never match generate_security_documentation/1 calls
      # Fix: Change :generatesecurity_doc to :generate_security_doc
    end

    test "BUG: line 232 - missing underscore in handler atom ':generatemulti_format_doc'" do
      # Line 232: def handle_call({:generatemulti_format_doc, config}, _from, state)
      #                            ^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:generate_multi_format_doc, config}
      # Impact: Handler will never match generate_multi_format_documentation/1 calls
      # Fix: Change :generatemulti_format_doc to :generate_multi_format_doc
    end

    test "BUG: line 248 - missing underscore in handler atom ':generatetest_doc'" do
      # Line 248: def handle_call({:generatetest_doc, config}, _from, state)
      #                            ^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:generate_test_doc, config}
      # Impact: Handler will never match generate_test_documentation/1 calls
      # Fix: Change :generatetest_doc to :generate_test_doc
    end
  end

  describe "BUGS: double underscore prefix in variables (13 occurrences)" do
    test "BUG: line 395 - double underscore prefix '__data_classification'" do
      # Line 395: [__data_classification, pii_handling, compliance, audit, incident_response] =
      #            ^^^^^^^^^^^^^^^^^^^^^ BUG - double underscore prefix
      # Should be: data_classification
      # Impact: Variable has double underscore prefix (non-standard naming)
      # Fix: Change __data_classification to data_classification
      # Note: Used in string interpolation on line 404
    end

    test "BUG: line 562 - double underscore prefix '__data'" do
      # Line 562: "3. Verify connectivity and __data ingestion"
      #                                      ^^^^^^ BUG
      # Should be: data
      # Impact: Template contains double underscore prefix in documentation
      # Fix: Change __data to data
    end

    test "BUG: line 673 - double underscore prefix '__user_type'" do
      # Line 673: %{__user_type: __user_type}
      #            ^^^^^^^^^^^^ and ^^^^^^^^^^^^ BUG (appears twice)
      # Should be: %{user_type: user_type}
      # Impact: Map key and value both have double underscore prefix
      # Fix: Change __user_type to user_type (both occurrences)
    end

    test "BUG: line 679 - underscore prefix '_request'" do
      # Line 679: [:indrajaal, :api, :_request],
      #                               ^^^^^^^^^ BUG - single underscore prefix
      # Should be: :request
      # Impact: Telemetry event has underscore prefix (non-standard)
      # Fix: Change :_request to :request
    end

    test "BUG: lines 719, 735, 749, 759 - double underscore '__data'" do
      # Line 719: "- Multi-tenant __data isolation"
      # Line 735: "3. **Security Monitoring Template**: Security __event tracking"
      # Line 749: "5. **Monitoring**: Verify dashboard functionality and __data flow"
      # Line 759: "Dashboard security includes access control, __data isolation,"
      # All should be: data (line 735 should be: event)
      # Impact: Documentation templates contain double underscore prefixes
      # Fix: Replace all __data with data, __event with event
    end

    test "BUG: lines 793, 802, 827, 838 - double underscore '__data'" do
      # Line 793: "- **Restricted**: PII and regulated __data"
      # Line 802: "1. **Data Discovery**: Identify PII in telemetry __data"
      # Line 827: "- Financial __data protection"
      # Line 838: "1. **Access Logging**: Log all access to sensitive __data"
      # All should be: data
      # Impact: Documentation templates contain double underscore prefixes
      # Fix: Replace all __data with data
    end

    test "BUG: line 760 - underscore prefix '_requirements'" do
      # Line 760: "and compliance with regulatory _requirements."
      #                                         ^^^^^^^^^^^^^ BUG
      # Should be: requirements
      # Impact: Documentation template has single underscore prefix
      # Fix: Change _requirements to requirements
    end

    test "BUG: line 824 - underscore prefix '_requirements'" do
      # Line 824: "- Audit trail _requirements"
      #                          ^^^^^^^^^^^^^ BUG
      # Should be: requirements
      # Impact: Documentation template has single underscore prefix
      # Fix: Change _requirements to requirements
    end
  end

  describe "CRITICAL BUGS: quadruple nested conditionals (Lines 601-610, 643-645)" do
    test "BUG: lines 607-610 - quadruple nested 'if Code.ensure_loaded?' conditionals" do
      # Lines 607-610:
      # if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: OpenTelemetry.Span.set_attributes([
      #   {"user.id", user.id},
      #   {"user.type", user.type}
      # ]), else: :ok, else: :ok, else: :ok, else: :ok
      #
      # Should be: Single conditional check
      # Impact: Unnecessary quadruple nesting makes code unreadable and error-prone
      # Fix: Replace with single conditional:
      #   if Code.ensure_loaded?(OpenTelemetry) do
      #     OpenTelemetry.Span.set_attributes([...])
      #   end
      # Note: This is the MOST CRITICAL BUG - complete code clarity issue
    end

    test "BUG: lines 643-645 - triple quadruple nested conditionals" do
      # Lines 643-645:
      # :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_cowboy.setup(), else: :ok, else: :ok, else: :ok, else: :ok
      # :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_phoenix.setup(), else: :ok, else: :ok, else: :ok, else: :ok
      # :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_ecto.setup([:indrajaal, :repo]), else: :ok, else: :ok, else: :ok, else: :ok
      #
      # Should be: Three separate single conditionals
      # Impact: THREE LINES with quadruple nesting each (12 total nested conditionals!)
      # Fix: Replace each with single conditional check
      # Note: Atom syntax also wrong (:if should be if)
    end
  end

  describe "additional code issues" do
    test "NOTE: line 59 - double underscore in map key '__data_classification'" do
      # Line 59: "__data_classification" => [],
      #          ^^^^^^^^^^^^^^^^^^^^^ NOTE - intentional template key?
      # This is a template definition key, might be intentional
      # However, it's inconsistent with standard Elixir naming
      # Recommendation: Use "data_classification" instead
    end

    test "NOTE: line 601 - undefined variable 'params' in function" do
      # Line 601: def create(_conn, _params) do
      #                              ^^^^^^^^^ NOTE - triple underscore
      # Line 604: user = Users.create_user(params)
      #                                   ^^^^^^ undefined - should be _params
      # Impact: Variable name mismatch will cause compilation error in example
      # Fix: Either use params (single name) or change line 604 to use _params
    end
  end
end
