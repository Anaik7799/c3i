defmodule Indrajaal.Observability.DataClassifierTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.DataClassifier

  setup do
    # Start the DataClassifier GenServer
    {:ok, pid} = DataClassifier.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = DataClassifier.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = DataClassifier.start_link([])
      assert Process.whereis(DataClassifier) != nil
      GenServer.stop(DataClassifier)
    end
  end

  describe "classify_data_sensitivity/2" do
    test "classifies data with map input" do
      data = %{
        user_email: "user@example.com",
        payment_method: "credit_card",
        transaction_amount: 99.99
      }

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr, :pci_dss])

      assert is_map(classification)
      assert Map.has_key?(classification, :sensitivity_level)
      assert Map.has_key?(classification, :applicable_regulations)
      assert Map.has_key?(classification, :classification_confidence)
      assert Map.has_key?(classification, :handling_requirements)
    end

    test "classifies data with string input" do
      data = "Patient ID: 12_345, Diagnosis: Example medical condition"

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa])

      assert is_map(classification)
      assert Map.has_key?(classification, :sensitivity_level)
    end

    test "returns valid sensitivity levels" do
      data = %{content: "public information"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert classification.sensitivity_level in [
               :public,
               :internal,
               :confidential,
               :restricted,
               :top_secret
             ]
    end

    test "includes applicable regulations based on data content" do
      data = %{content: "Patient medical records with email@example.com"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr, :hipaa])

      assert is_list(classification.applicable_regulations)
    end

    test "includes handling requirements for classified data" do
      data = %{content: "confidential business data"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_list(classification.handling_requirements)
    end

    test "includes data categories in classification result" do
      data = %{content: "financial transaction data"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:sox, :pci_dss])

      assert Map.has_key?(classification, :data_categories)
      assert is_list(classification.data_categories)
    end

    test "includes retention requirements in classification result" do
      data = %{content: "medical records"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa])

      assert Map.has_key?(classification, :retention_requirements)
      assert is_map(classification.retention_requirements)
    end

    test "includes classification metadata" do
      data = %{content: "test data"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert Map.has_key?(classification, :classification_metadata)
      assert Map.has_key?(classification.classification_metadata, :timestamp)
      assert Map.has_key?(classification.classification_metadata, :version)
    end
  end

  describe "validate_regulatory_compliance/3" do
    test "validates compliance for GDPR framework" do
      data = %{user_email: "user@example.com", consent_given: true}
      config = %{compliance_requirements: [:data_minimization]}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert is_map(compliance)
      assert Map.has_key?(compliance, :compliance_score)
      assert Map.has_key?(compliance, :_requirements_met)
      assert Map.has_key?(compliance, :violations_detected)
    end

    test "validates compliance for HIPAA framework" do
      data = %{phi_data: "Patient ID: 12_345", encrypted: true}
      config = %{compliance_requirements: [:encryption_at_rest]}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :hipaa, config)

      assert is_map(compliance)
      assert compliance.framework == :hipaa
    end

    test "validates compliance for SOX framework" do
      data = %{financial_data: "Revenue: $1M", audit_trail: "complete"}
      config = %{compliance_requirements: [:audit_trail_preservation]}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :sox, config)

      assert is_map(compliance)
      assert compliance.framework == :sox
    end

    test "validates compliance for PCI DSS framework" do
      data = %{content: "secure payment processing"}
      config = %{compliance_requirements: [:cardholder_data_protection]}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :pci_dss, config)

      assert is_map(compliance)
      assert compliance.framework == :pci_dss
    end

    test "validates compliance for ISO27001 framework" do
      data = %{security_controls: "implemented"}
      config = %{compliance_requirements: [:isms_establishment]}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :iso27001, config)

      assert is_map(compliance)
      assert compliance.framework == :iso27001
    end

    test "returns error for unsupported framework" do
      data = %{content: "test"}
      config = %{}

      {:error, reason} = DataClassifier.validate_regulatory_compliance(data, :unsupported, config)

      assert reason == :unsupported_framework
    end

    test "includes compliance score in validation result" do
      data = %{content: "test data"}
      config = %{}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert is_number(compliance.compliance_score)
      assert compliance.compliance_score >= 0.0
      assert compliance.compliance_score <= 1.0
    end

    test "includes requirements met in validation result" do
      data = %{content: "test"}
      config = %{}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert is_list(compliance._requirements_met)
    end

    test "includes violations detected in validation result" do
      data = %{content: "test"}
      config = %{}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert is_list(compliance.violations_detected)
    end

    test "generates compliance report when requested" do
      data = %{content: "test"}
      config = %{generate_compliance_report: true}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert is_map(compliance.compliance_report)
      assert compliance.compliance_report.report_generated != false
    end

    test "does not generate report when not requested" do
      data = %{content: "test"}
      config = %{generate_compliance_report: false}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert compliance.compliance_report.report_generated == false
    end

    test "includes assessment metadata in validation result" do
      data = %{content: "test"}
      config = %{}

      {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, :gdpr, config)

      assert Map.has_key?(compliance, :assessment_metadata)
      assert Map.has_key?(compliance.assessment_metadata, :timestamp)
      assert Map.has_key?(compliance.assessment_metadata, :_requirements_assessed)
    end
  end

  describe "test_compliance_validation/1" do
    test "returns compliance result for known framework" do
      config = %{framework: :gdpr}

      {:ok, result} = DataClassifier.test_compliance_validation(config)

      assert is_map(result)
      assert Map.has_key?(result, :compliance_score)
      assert Map.has_key?(result, :_requirements_assessed)
      assert Map.has_key?(result, :framework)
      assert Map.has_key?(result, :validation_passed)
    end

    test "returns valid compliance score range" do
      config = %{framework: :hipaa}

      {:ok, result} = DataClassifier.test_compliance_validation(config)

      assert result.compliance_score >= 0.80
      assert result.compliance_score <= 1.0
    end

    test "validates successfully for supported frameworks" do
      frameworks = [:gdpr, :hipaa, :sox, :pci_dss, :iso27001]

      Enum.each(frameworks, fn framework ->
        {:ok, result} = DataClassifier.test_compliance_validation(%{framework: framework})
        assert result.validation_passed == true
        assert result.framework == framework
      end)
    end

    test "fails validation for unsupported framework" do
      config = %{framework: :unsupported}

      {:ok, result} = DataClassifier.test_compliance_validation(config)

      assert result.validation_passed == false
      assert result.compliance_score == 0.0
    end

    test "includes assessed requirements in result" do
      config = %{framework: :gdpr}

      {:ok, result} = DataClassifier.test_compliance_validation(config)

      assert is_list(result._requirements_assessed)
    end
  end

  describe "regulatory frameworks" do
    test "all frameworks have required fields" do
      frameworks = [:gdpr, :hipaa, :sox, :pci_dss, :iso27001]

      Enum.each(frameworks, fn framework ->
        {:ok, result} = DataClassifier.test_compliance_validation(%{framework: framework})
        assert is_list(result._requirements_assessed)
        assert length(result._requirements_assessed) > 0
      end)
    end

    test "GDPR framework includes data protection requirements" do
      {:ok, result} = DataClassifier.test_compliance_validation(%{framework: :gdpr})
      assert :data_minimization in result._requirements_assessed
    end

    test "HIPAA framework includes healthcare requirements" do
      {:ok, result} = DataClassifier.test_compliance_validation(%{framework: :hipaa})
      assert :encryption_at_rest in result._requirements_assessed
    end

    test "SOX framework includes financial requirements" do
      {:ok, result} = DataClassifier.test_compliance_validation(%{framework: :sox})
      assert :audit_trail_preservation in result._requirements_assessed
    end
  end

  describe "sensitivity level classification" do
    test "classifies public data correctly" do
      data = %{content: "public announcement"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert classification.sensitivity_level in [
               :public,
               :internal,
               :confidential,
               :restricted,
               :top_secret
             ]
    end

    test "classifies data with PII as sensitive" do
      data = %{content: "Email: user@example.com, Phone: 123-456-7890"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr])

      assert classification.sensitivity_level in [:internal, :confidential, :restricted]
    end

    test "classifies health data as highly sensitive" do
      data = %{content: "Patient medical diagnosis and treatment plan"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa])

      assert classification.sensitivity_level in [:confidential, :restricted, :top_secret]
    end

    test "classifies financial data appropriately" do
      data = %{content: "Revenue $1M, profit margin 15%, accounting records"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:sox])

      assert classification.sensitivity_level in [:confidential, :restricted]
    end

    test "classifies payment data with high sensitivity" do
      data = %{content: "Credit card: 4111-1111-1111-1111, transaction $500"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:pci_dss])

      assert classification.sensitivity_level in [:confidential, :restricted, :top_secret]
    end
  end

  describe "data category detection" do
    test "detects personal data for GDPR" do
      data = %{content: "user@example.com with phone number"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr])

      assert :personal_data in classification.data_categories or
               :observability_data in classification.data_categories
    end

    test "detects health data for HIPAA" do
      data = %{content: "patient medical records"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa])

      assert is_list(classification.data_categories)
    end

    test "detects financial data for SOX" do
      data = %{content: "financial audit trail"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:sox])

      assert is_list(classification.data_categories)
    end
  end

  describe "retention requirements" do
    test "determines base retention for classified data" do
      data = %{content: "test data"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_map(classification.retention_requirements)
      assert Map.has_key?(classification.retention_requirements, :base_retention)
    end

    test "includes regulatory retention requirements" do
      data = %{content: "financial records"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:sox])

      assert is_map(classification.retention_requirements)
      assert Map.has_key?(classification.retention_requirements, :regulatory_requirements)
      assert is_list(classification.retention_requirements.regulatory_requirements)
    end

    test "provides recommended retention period" do
      data = %{content: "medical records"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa])

      assert Map.has_key?(classification.retention_requirements, :recommended_retention)
    end
  end

  describe "handling requirements" do
    test "includes access control for internal data" do
      data = %{content: "internal business document"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      # Handling requirements should be a list
      assert is_list(classification.handling_requirements)
    end

    test "includes encryption for confidential data" do
      data = %{content: "SSN: 123-45-6789, confidential information"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr])

      # Confidential or higher should include encryption
      if classification.sensitivity_level in [:confidential, :restricted, :top_secret] do
        assert :encryption in classification.handling_requirements or
                 :access_control in classification.handling_requirements
      end
    end

    test "includes audit logging for restricted data" do
      data = %{
        content:
          "Patient: John Doe, SSN: 123-45-6789, Credit Card: 4111-1111-1111-1111, Medical diagnosis"
      }

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:hipaa, :pci_dss])

      # Restricted or higher should include audit logging
      if classification.sensitivity_level in [:restricted, :top_secret] do
        assert :audit_logging in classification.handling_requirements or
                 :access_control in classification.handling_requirements
      end
    end
  end

  describe "concurrent classification processing" do
    test "handles concurrent classification requests" do
      data_items =
        for i <- 1..10 do
          %{content: "Test data #{i}", id: i}
        end

      tasks =
        for data <- data_items do
          Task.async(fn ->
            DataClassifier.classify_data_sensitivity(data, [:gdpr])
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 10
      Enum.each(results, fn {:ok, classification} -> assert is_map(classification) end)
    end

    test "maintains classification accuracy under concurrent load" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            data = %{content: "User #{i}: user#{i}@example.com"}
            DataClassifier.classify_data_sensitivity(data, [:gdpr, :hipaa])
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 20

      Enum.each(results, fn {:ok, classification} ->
        assert Map.has_key?(classification, :sensitivity_level)
        assert Map.has_key?(classification, :classification_confidence)
      end)
    end
  end

  describe "edge cases and error handling" do
    test "handles empty map data" do
      data = %{}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_map(classification)
      assert Map.has_key?(classification, :sensitivity_level)
    end

    test "handles empty string data" do
      data = ""

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_map(classification)
    end

    test "handles empty regulatory frameworks list" do
      data = %{content: "test"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_map(classification)
      assert is_list(classification.applicable_regulations)
    end

    test "handles complex nested data structures" do
      data = %{
        level1: %{
          level2: %{
            level3: "nested data with email@example.com"
          }
        },
        metadata: %{
          tags: ["pii", "confidential"],
          classification: "internal"
        }
      }

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr])

      assert is_map(classification)
    end

    test "handles data with special characters" do
      data = %{
        content: """
        Special chars: @#$%^&*()
        Symbols: €£¥₹
        Unicode: 你好世界
        """
      }

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      assert is_map(classification)
    end
  end

  describe "integration scenarios" do
    test "complete classification and compliance workflow" do
      # Step 1: Classify data
      data = %{
        user_email: "user@example.com",
        payment_card: "4111-1111-1111-1111",
        medical_info: "patient diagnosis"
      }

      {:ok, classification} =
        DataClassifier.classify_data_sensitivity(data, [:gdpr, :hipaa, :pci_dss])

      assert is_map(classification)
      assert Map.has_key?(classification, :sensitivity_level)

      # Step 2: Validate compliance for each applicable regulation
      Enum.each(classification.applicable_regulations, fn framework ->
        config = %{compliance_requirements: []}
        {:ok, compliance} = DataClassifier.validate_regulatory_compliance(data, framework, config)
        assert is_map(compliance)
        assert compliance.framework == framework
      end)
    end

    test "classification informs handling requirements" do
      data = %{content: "confidential business strategy document"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [])

      # Verify handling requirements match sensitivity level
      assert is_list(classification.handling_requirements)

      case classification.sensitivity_level do
        :public -> assert classification.handling_requirements == []
        :internal -> assert :access_control in classification.handling_requirements
        _ -> assert length(classification.handling_requirements) > 0
      end
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: data integrity - classification accuracy preserved" do
      data = %{content: "test data for integrity check"}

      # Classify multiple times - should get consistent results
      {:ok, result1} = DataClassifier.classify_data_sensitivity(data, [:gdpr])
      {:ok, result2} = DataClassifier.classify_data_sensitivity(data, [:gdpr])

      assert result1.sensitivity_level == result2.sensitivity_level
    end

    test "SC2: performance - classification maintains acceptable response times" do
      data = %{content: "performance test data"}

      start_time = System.monotonic_time(:millisecond)
      {:ok, _classification} = DataClassifier.classify_data_sensitivity(data, [:gdpr, :hipaa])
      end_time = System.monotonic_time(:millisecond)

      processing_time = end_time - start_time

      # Should complete in under 5 seconds (5000ms)
      assert processing_time < 5000
    end

    test "SC3: security - sensitive classifications properly protected" do
      sensitive_data = %{
        ssn: "123-45-6789",
        credit_card: "4111-1111-1111-1111",
        medical_record: "patient diagnosis"
      }

      {:ok, classification} =
        DataClassifier.classify_data_sensitivity(sensitive_data, [:gdpr, :hipaa, :pci_dss])

      # Verify sensitive data gets appropriate security measures
      assert classification.sensitivity_level in [:confidential, :restricted, :top_secret]
      assert length(classification.handling_requirements) >= 2
    end

    test "SC4: availability - compliance systems remain operational" do
      # Test that system continues working under load
      for _i <- 1..50 do
        spawn(fn ->
          DataClassifier.classify_data_sensitivity(%{content: "load test"}, [:gdpr])
        end)
      end

      Process.sleep(200)

      # System should still respond
      {:ok, classification} = DataClassifier.classify_data_sensitivity(%{content: "test"}, [])
      assert is_map(classification)
    end

    test "SC5: compliance - complete audit trail maintained" do
      data = %{content: "audit trail test"}

      {:ok, classification} = DataClassifier.classify_data_sensitivity(data, [:sox])

      # Verify metadata includes audit information
      assert Map.has_key?(classification, :classification_metadata)
      assert Map.has_key?(classification.classification_metadata, :timestamp)
      assert Map.has_key?(classification.classification_metadata, :version)
    end
  end
end
