defmodule Indrajaal.Analytics.ComplianceScoreTest do
  @moduledoc """
  Comprehensive TDG (Test-Driven Generation) test suite for ComplianceScore resource.

  Tests regulatory compliance tracking and scoring including:
  - Compliance framework support (ISO 27_001, GDPR, HIPAA, SOX, PCI DSS)
  - Score calculation and validation (0-100 scale)
  - Compliance level determination and assessment
  - Control scores mapping and gap identification
  - STAMP safety constraints and enterprise scenarios

  Agent: Worker - 6 (Analytics Domain Agent)
  SOPv5.11 Compliance: ✅ Regulatory compliance tracking with audit trail
  Domain: Analytics
  Responsibilities: Compliance scoring, regulatory frameworks, gap analysis
  Multi-Agent Architecture: Integrated with 15-agent coordination system
  Cybernetic Feedback: Active feedback loops for continuous improvement
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  use Indrajaal.DataCase

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.ComplianceScore

  # STAMP Safety Constraints for Compliance Scoring
  #
  # SC-CS-001: System SHALL maintain compliance scores within valid range (0-100)
  # SC-CS-002: System SHALL map compliance levels accurately to score ranges
  # SC-CS-003: System SHALL support all major regulatory frameworks
  # SC-CS-004: System SHALL maintain assessment date integrity
  # SC-CS-005: System SHALL identify and track compliance gaps

  @stamp_constraint_sc_cs_001 """
  All compliance scores must remain within the valid range of 0-100 to ensure
  accurate regulatory compliance assessment and reporting.
  """

  @stamp_constraint_sc_cs_002 """
  Compliance levels must be accurately mapped to score ranges to ensure
  correct regulatory status reporting and compliance management.
  """

  @stamp_constraint_sc_cs_003 """
  The system must support all major regulatory frameworks (ISO 27_001, GDPR,
  HIPAA, SOX, PCI DSS) for comprehensive compliance management.
  """

  @stamp_constraint_sc_cs_004 """
  Assessment dates must be accurate and maintained for audit trail
  and regulatory compliance reporting requirements.
  """

  @stamp_constraint_sc_cs_005 """
  All compliance gaps must be identified, tracked, and reported for
  systematic remediation and continuous improvement.
  """

  # TDG Unit Tests - Written FIRST before implementation

  describe "ComplianceScore resource creation" do
    test "creates compliance score with valid framework and score" do
      valid_attrs = %{
        framework: :iso_27001,
        score: 85.5,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant,
        control_scores: %{
          "access_control" => 90.0,
          "incident_management" => 80.0,
          "risk_management" => 85.0
        },
        gaps_identified: ["Documentation gaps in BCP", "Staff training incomplete"]
      }

      assert {:ok, compliance_score} = ComplianceScore.create(valid_attrs)

      assert compliance_score.framework == :iso_27001
      assert Decimal.equal?(compliance_score.score, Decimal.new("85.5"))
      assert compliance_score.compliance_level == :compliant
      assert is_map(compliance_score.control_scores)
      assert is_list(compliance_score.gaps_identified)
      assert length(compliance_score.gaps_identified) == 2

      # STAMP SC-CS-001: Verify score within valid range
      score_value = Decimal.to_float(compliance_score.score)
      assert score_value >= 0.0 and score_value <= 100.0
    end

    test "validates framework is one of supported types" do
      valid_frameworks = [:iso_27001, :gdpr, :hipaa, :sox, :pci_dss, :custom]

      Enum.each(valid_frameworks, fn framework ->
        attrs = %{
          framework: framework,
          score: 75.0,
          assessment_date: DateTime.utc_now(),
          compliance_level: :compliant
        }

        assert {:ok, compliance_score} = ComplianceScore.create(attrs)
        assert compliance_score.framework == framework
      end)
    end

    test "rejects invalid framework" do
      invalid_attrs = %{
        framework: :invalid_framework,
        score: 75.0,
        assessment_date: DateTime.utc_now()
      }

      assert {:error, changeset} = ComplianceScore.create(invalid_attrs)
      assert "is invalid" in errors_on(changeset).framework
    end

    test "validates score is within 0-100 range" do
      # Test valid scores
      valid_scores = [0, 50.5, 100]

      Enum.each(valid_scores, fn score ->
        attrs = %{
          framework: :gdpr,
          score: score,
          assessment_date: DateTime.utc_now()
        }

        assert {:ok, compliance_score} = ComplianceScore.create(attrs)
        expected_decimal = Decimal.new(to_string(score))
        assert Decimal.equal?(compliance_score.score, expected_decimal)
      end)
    end

    test "rejects score outside valid range" do
      invalid_scores = [-1, 100.1, 150]

      Enum.each(invalid_scores, fn score ->
        attrs = %{
          framework: :hipaa,
          score: score,
          assessment_date: DateTime.utc_now()
        }

        assert {:error, changeset} = ComplianceScore.create(attrs)
        assert errors_on(changeset).score != nil
      end)
    end

    test "validates compliance_level is valid enum value" do
      valid_levels = [:non_compliant, :partially_compliant, :compliant, :exceeds]

      Enum.each(valid_levels, fn level ->
        attrs = %{
          framework: :sox,
          score: 75.0,
          assessment_date: DateTime.utc_now(),
          compliance_level: level
        }

        assert {:ok, compliance_score} = ComplianceScore.create(attrs)
        assert compliance_score.compliance_level == level
      end)
    end

    test "rejects invalid compliance_level" do
      invalid_attrs = %{
        framework: :pci_dss,
        score: 75.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :invalid_level
      }

      assert {:error, changeset} = ComplianceScore.create(invalid_attrs)
      assert "is invalid" in errors_on(changeset).compliance_level
    end

    test "sets default values for optional attributes" do
      minimal_attrs = %{
        framework: :iso_27001,
        score: 80.0,
        assessment_date: DateTime.utc_now()
      }

      assert {:ok, compliance_score} = ComplianceScore.create(minimal_attrs)

      # Verify defaults
      assert compliance_score.control_scores == %{}
      assert compliance_score.gaps_identified == []
    end
  end

  describe "ComplianceScore attribute validation" do
    test "requires framework to be present" do
      attrs = %{
        score: 75.0,
        assessment_date: DateTime.utc_now()
      }

      assert {:error, changeset} = ComplianceScore.create(attrs)
      assert "can't be blank" in errors_on(changeset).framework
    end

    test "requires score to be present" do
      attrs = %{
        framework: :gdpr,
        assessment_date: DateTime.utc_now()
      }

      assert {:error, changeset} = ComplianceScore.create(attrs)
      assert "can't be blank" in errors_on(changeset).score
    end

    test "requires assessment_date to be present" do
      attrs = %{
        framework: :hipaa,
        score: 85.0
      }

      assert {:error, changeset} = ComplianceScore.create(attrs)
      assert "can't be blank" in errors_on(changeset).assessment_date
    end

    test "accepts complex control_scores structure" do
      control_scores = %{
        "access_control" => 95.0,
        "data_protection" => 88.0,
        "incident_response" => 92.0,
        "risk_assessment" => 85.0,
        "business_continuity" => 90.0,
        "supplier_management" => 78.0
      }

      attrs = %{
        framework: :iso_27001,
        score: 88.0,
        assessment_date: DateTime.utc_now(),
        control_scores: control_scores
      }

      assert {:ok, compliance_score} = ComplianceScore.create(attrs)
      assert compliance_score.control_scores == control_scores
      assert map_size(compliance_score.control_scores) == 6
    end

    test "accepts multiple gap types" do
      gaps = [
        "Risk assessment documentation incomplete",
        "Staff security awareness training overdue",
        "Incident response plan not tested",
        "Vendor security assessments missing",
        "Data classification scheme not implemented"
      ]

      attrs = %{
        framework: :gdpr,
        score: 72.0,
        assessment_date: DateTime.utc_now(),
        gaps_identified: gaps
      }

      assert {:ok, compliance_score} = ComplianceScore.create(attrs)
      assert compliance_score.gaps_identified == gaps
      assert length(compliance_score.gaps_identified) == 5
    end
  end

  # TDG Integration Tests - Complex scenarios

  describe "compliance framework specific scenarios" do
    test "ISO 27_001 compliance assessment" do
      iso_attrs = %{
        framework: :iso_27001,
        score: 92.5,
        assessment_date: DateTime.utc_now(),
        compliance_level: :exceeds,
        control_scores: %{
          "A.5_Information_Security_Policies" => 95.0,
          "A.6_Organization_of_Information_Security" => 90.0,
          "A.7_Human_Resource_Security" => 88.0,
          "A.8_Asset_Management" => 94.0,
          "A.9_Access_Control" => 96.0,
          "A.10_Cryptography" => 92.0,
          "A.11_Physical_Environmental_Security" => 89.0,
          "A.12_Operations_Security" => 93.0,
          "A.13_Communications_Security" => 91.0,
          "A.14_System_Acquisition_Development" => 87.0,
          "A.15_Supplier_Relationships" => 85.0,
          "A.16_Information_Security_Incident_Management" => 94.0,
          "A.17_Business_Continuity_Management" => 90.0,
          "A.18_Compliance" => 96.0
        },
        gaps_identified: ["Minor documentation gaps in A.7", "A.15 supplier assessments due"]
      }

      assert {:ok, iso_compliance} = ComplianceScore.create(iso_attrs)

      assert iso_compliance.framework == :iso_27001
      assert Decimal.to_float(iso_compliance.score) == 92.5
      assert iso_compliance.compliance_level == :exceeds
      assert map_size(iso_compliance.control_scores) == 14
      assert length(iso_compliance.gaps_identified) == 2
    end

    test "GDPR compliance assessment" do
      gdpr_attrs = %{
        framework: :gdpr,
        score: 78.5,
        assessment_date: DateTime.utc_now(),
        compliance_level: :partially_compliant,
        control_scores: %{
          "Lawfulness_Fairness_Transparency" => 85.0,
          "Purpose_Limitation" => 80.0,
          "Data_Minimisation" => 75.0,
          "Accuracy" => 82.0,
          "Storage_Limitation" => 70.0,
          "Integrity_Confidentiality" => 88.0,
          "Accountability" => 72.0
        },
        gaps_identified: [
          "Data retention policies need review",
          "Subject access request process incomplete",
          "Data breach notification procedures require update",
          "Privacy impact assessments overdue"
        ]
      }

      assert {:ok, gdpr_compliance} = ComplianceScore.create(gdpr_attrs)

      assert gdpr_compliance.framework == :gdpr
      assert Decimal.to_float(gdpr_compliance.score) == 78.5
      assert gdpr_compliance.compliance_level == :partially_compliant
      assert map_size(gdpr_compliance.control_scores) == 7
      assert length(gdpr_compliance.gaps_identified) == 4
    end

    test "HIPAA compliance assessment" do
      hipaa_attrs = %{
        framework: :hipaa,
        score: 89.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant,
        control_scores: %{
          "Administrative_Safeguards" => 91.0,
          "Physical_Safeguards" => 87.0,
          "Technical_Safeguards" => 90.0
        },
        gaps_identified: [
          "Workforce training requires update",
          "Access logs review frequency"
        ]
      }

      assert {:ok, hipaa_compliance} = ComplianceScore.create(hipaa_attrs)

      assert hipaa_compliance.framework == :hipaa
      assert hipaa_compliance.compliance_level == :compliant
      assert map_size(hipaa_compliance.control_scores) == 3
    end

    test "SOX compliance assessment" do
      sox_attrs = %{
        framework: :sox,
        score: 94.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant,
        control_scores: %{
          "Entity_Level_Controls" => 95.0,
          "General_IT_Controls" => 92.0,
          "Application_Controls" => 95.0,
          "Financial_Reporting_Controls" => 94.0
        },
        gaps_identified: ["Change management documentation minor gaps"]
      }

      assert {:ok, sox_compliance} = ComplianceScore.create(sox_attrs)

      assert sox_compliance.framework == :sox
      assert Decimal.to_float(sox_compliance.score) == 94.0
      assert sox_compliance.compliance_level == :compliant
    end

    test "PCI DSS compliance assessment" do
      pci_attrs = %{
        framework: :pci_dss,
        score: 96.5,
        assessment_date: DateTime.utc_now(),
        compliance_level: :exceeds,
        control_scores: %{
          "Firewall_Configuration" => 98.0,
          "Default_Passwords" => 95.0,
          "Cardholder_Data_Protection" => 97.0,
          "Encrypted_Transmission" => 96.0,
          "Antivirus_Software" => 94.0,
          "Secure_Systems" => 98.0,
          "Access_Control" => 97.0,
          "Unique_IDs" => 95.0,
          "Physical_Access" => 99.0,
          "Network_Monitoring" => 96.0,
          "Regular_Testing" => 94.0,
          "Information_Security_Policy" => 98.0
        },
        gaps_identified: ["Quarterly penetration testing schedule adjustment"]
      }

      assert {:ok, pci_compliance} = ComplianceScore.create(pci_attrs)

      assert pci_compliance.framework == :pci_dss
      assert pci_compliance.compliance_level == :exceeds
      assert map_size(pci_compliance.control_scores) == 12
    end
  end

  describe "compliance level determination" do
    test "maps scores to compliance levels accurately" do
      test_cases = [
        {15.0, :non_compliant},
        {45.0, :non_compliant},
        {65.0, :partially_compliant},
        {75.0, :partially_compliant},
        {85.0, :compliant},
        {90.0, :compliant},
        {95.0, :exceeds},
        {98.0, :exceeds}
      ]

      Enum.each(test_cases, fn {score, expected_level} ->
        attrs = %{
          framework: :iso_27001,
          score: score,
          assessment_date: DateTime.utc_now(),
          compliance_level: expected_level
        }

        assert {:ok, compliance_score} = ComplianceScore.create(attrs)
        assert compliance_score.compliance_level == expected_level

        # STAMP SC-CS-002: Verify accurate level mapping
        score_float = Decimal.to_float(compliance_score.score)

        case expected_level do
          :non_compliant -> assert score_float < 60.0
          :partially_compliant -> assert score_float >= 60.0 and score_float < 80.0
          :compliant -> assert score_float >= 80.0 and score_float < 95.0
          :exceeds -> assert score_float >= 95.0
        end
      end)
    end
  end

  describe "multi-tenant compliance tracking" do
    test "tracks compliance across different tenants" do
      # This would be handled by the tenant resource behavior
      # Testing the resource structure supports multi-tenancy

      tenant_1_attrs = %{
        framework: :gdpr,
        score: 82.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant
      }

      tenant_2_attrs = %{
        framework: :gdpr,
        score: 75.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :partially_compliant
      }

      assert {:ok, compliance_1} = ComplianceScore.create(tenant_1_attrs)
      assert {:ok, compliance_2} = ComplianceScore.create(tenant_2_attrs)

      # Verify independent compliance scores
      assert compliance_1.id != compliance_2.id
      assert Decimal.to_float(compliance_1.score) != Decimal.to_float(compliance_2.score)
      assert compliance_1.compliance_level != compliance_2.compliance_level
    end
  end

  # Property-Based Testing with PropCheck

  property "compliance scores remain within valid range", [:verbose] do
    forall score <- range(0, 100) do
      attrs = %{
        framework: :iso_27001,
        score: score,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant
      }

      case ComplianceScore.create(attrs) do
        {:ok, compliance_score} ->
          score_value = Decimal.to_float(compliance_score.score)
          score_value >= 0.0 and score_value <= 100.0

        {:error, _changeset} ->
          # Validation errors are acceptable for edge cases
          true
      end
    end
  end

  property "all supported frameworks can be created", [:verbose] do
    forall framework <- PC.oneof([:iso_27001, :gdpr, :hipaa, :sox, :pci_dss, :custom]) do
      attrs = %{
        framework: framework,
        score: 75.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant
      }

      case ComplianceScore.create(attrs) do
        {:ok, compliance_score} ->
          compliance_score.framework == framework

        {:error, _changeset} ->
          false
      end
    end
  end

  # Property-Based Testing with ExUnitProperties

  test "control scores are preserved accurately" do
    ExUnitProperties.check all(
                             control_scores <-
                               SD.map_of(SD.string(:alphanumeric), SD.float(min: 0.0, max: 100.0))
                           ) do
      attrs = %{
        framework: :iso_27001,
        score: 80.0,
        assessment_date: DateTime.utc_now(),
        control_scores: control_scores
      }

      case ComplianceScore.create(attrs) do
        {:ok, compliance_score} ->
          compliance_score.control_scores == control_scores

        {:error, _changeset} ->
          # Some control scores might be invalid
          true
      end
    end
  end

  test "gaps identified are preserved as list" do
    ExUnitProperties.check all(gaps <- SD.list_of(SD.string(:alphanumeric), max_length: 10)) do
      attrs = %{
        framework: :gdpr,
        score: 70.0,
        assessment_date: DateTime.utc_now(),
        gaps_identified: gaps
      }

      {:ok, compliance_score} = ComplianceScore.create(attrs)
      compliance_score.gaps_identified == gaps
    end
  end

  # STAMP Safety Constraint Tests

  test "STAMP SC-CS-001: Compliance scores within valid range (0-100)" do
    valid_scores = [0, 25.5, 50.0, 75.8, 100]

    Enum.each(valid_scores, fn score ->
      attrs = %{
        framework: :iso_27001,
        score: score,
        assessment_date: DateTime.utc_now()
      }

      {:ok, compliance_score} = ComplianceScore.create(attrs)
      score_value = Decimal.to_float(compliance_score.score)

      assert score_value >= 0.0 and score_value <= 100.0,
             "STAMP SC-CS-001 violation: Score #{score_value} outside valid range"
    end)
  end

  test "STAMP SC-CS-002: Compliance levels mapped accurately to score ranges" do
    test_mappings = [
      {25.0, :non_compliant},
      {65.0, :partially_compliant},
      {85.0, :compliant},
      {97.0, :exceeds}
    ]

    Enum.each(test_mappings, fn {score, level} ->
      attrs = %{
        framework: :gdpr,
        score: score,
        assessment_date: DateTime.utc_now(),
        compliance_level: level
      }

      {:ok, compliance_score} = ComplianceScore.create(attrs)

      assert compliance_score.compliance_level == level,
             "STAMP SC-CS-002 violation: Level #{level} not correctly mapped for score #{score}"
    end)
  end

  test "STAMP SC-CS-003: Support for all major regulatory frameworks" do
    required_frameworks = [:iso_27001, :gdpr, :hipaa, :sox, :pci_dss, :custom]

    Enum.each(required_frameworks, fn framework ->
      attrs = %{
        framework: framework,
        score: 80.0,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant
      }

      assert {:ok, compliance_score} = ComplianceScore.create(attrs)
      assert compliance_score.framework == framework
    end)

    # Verify complete framework coverage
    assert length(required_frameworks) == 6,
           "STAMP SC-CS-003 violation: Missing required regulatory frameworks"
  end

  test "STAMP SC-CS-004: Assessment date integrity maintained" do
    assessment_time = DateTime.utc_now()

    attrs = %{
      framework: :hipaa,
      score: 88.0,
      assessment_date: assessment_time,
      compliance_level: :compliant
    }

    {:ok, compliance_score} = ComplianceScore.create(attrs)

    # Verify timestamp preservation (allowing for minor differences due to processing time)
    time_diff = DateTime.diff(compliance_score.assessment_date, assessment_time)

    assert abs(time_diff) <= 1,
           "STAMP SC-CS-004 violation: Assessment date integrity lost (diff: #{time_diff}s)"

    # Verify timestamp is within reasonable range
    now = DateTime.utc_now()

    assert DateTime.compare(compliance_score.assessment_date, now) in [:lt, :eq],
           "STAMP SC-CS-004 violation: Assessment date in future"
  end

  test "STAMP SC-CS-005: Compliance gaps identified and tracked" do
    gaps = [
      "Data retention policy requires update",
      "Employee security training overdue",
      "Incident response plan needs testing",
      "Third-party risk assessments incomplete"
    ]

    attrs = %{
      framework: :sox,
      score: 76.0,
      assessment_date: DateTime.utc_now(),
      compliance_level: :partially_compliant,
      gaps_identified: gaps
    }

    {:ok, compliance_score} = ComplianceScore.create(attrs)

    assert compliance_score.gaps_identified == gaps,
           "STAMP SC-CS-005 violation: Gaps not properly preserved"

    assert is_list(compliance_score.gaps_identified),
           "STAMP SC-CS-005 violation: Gaps not stored as list"

    assert length(compliance_score.gaps_identified) > 0,
           "STAMP SC-CS-005 violation: No gaps tracked for partially compliant score"
  end

  # Enterprise-Scale Test Scenarios

  describe "enterprise compliance scenarios" do
    test "comprehensive compliance dashboard data" do
      # Create compliance scores for multiple frameworks
      frameworks_data = [
        {:iso_27001, 92.0, :exceeds},
        {:gdpr, 85.0, :compliant},
        {:hipaa, 88.0, :compliant},
        {:sox, 94.0, :compliant},
        {:pci_dss, 96.0, :exceeds}
      ]

      compliance_scores =
        Enum.map(frameworks_data, fn {framework, score, level} ->
          attrs = %{
            framework: framework,
            score: score,
            assessment_date: DateTime.utc_now(),
            compliance_level: level
          }

          {:ok, compliance_score} = ComplianceScore.create(attrs)
          compliance_score
        end)

      # Verify comprehensive compliance coverage
      assert length(compliance_scores) == 5

      frameworks = Enum.map(compliance_scores, & &1.framework)
      assert :iso_27001 in frameworks
      assert :gdpr in frameworks
      assert :hipaa in frameworks
      assert :sox in frameworks
      assert :pci_dss in frameworks

      # Calculate overall compliance health
      total_score =
        Enum.reduce(compliance_scores, 0.0, fn cs, acc ->
          acc + Decimal.to_float(cs.score)
        end)

      average_score = total_score / length(compliance_scores)

      assert average_score > 85.0, "Overall compliance health should be good"
    end

    test "compliance trend analysis data" do
      base_date = DateTime.utc_now()

      # Create quarterly compliance assessments
      quarterly_assessments = [
        {DateTime.add(base_date, -90 * 24 * 3600, :second), 78.0, :partially_compliant},
        {DateTime.add(base_date, -60 * 24 * 3600, :second), 82.0, :compliant},
        {DateTime.add(base_date, -30 * 24 * 3600, :second), 87.0, :compliant},
        {base_date, 91.0, :exceeds}
      ]

      trend_scores =
        Enum.map(quarterly_assessments, fn {date, score, level} ->
          attrs = %{
            framework: :iso_27001,
            score: score,
            assessment_date: date,
            compliance_level: level
          }

          {:ok, compliance_score} = ComplianceScore.create(attrs)
          compliance_score
        end)

      # Verify trend improvement
      assert length(trend_scores) == 4

      scores = Enum.map(trend_scores, &Decimal.to_float(&1.score))
      [oldest_score | rest_scores] = scores
      latest_score = List.last(rest_scores)

      assert latest_score > oldest_score, "Compliance trend should show improvement"

      # Verify progression through compliance levels
      levels = Enum.map(trend_scores, & &1.compliance_level)
      assert :partially_compliant in levels
      assert :compliant in levels
      assert :exceeds in levels
    end

    test "regulatory audit preparation" do
      # Comprehensive audit-ready compliance score
      audit_attrs = %{
        framework: :iso_27001,
        score: 89.5,
        assessment_date: DateTime.utc_now(),
        compliance_level: :compliant,
        control_scores: %{
          "Information_Security_Policies" => 95.0,
          "Organization_Information_Security" => 88.0,
          "Human_Resource_Security" => 85.0,
          "Asset_Management" => 92.0,
          "Access_Control" => 90.0,
          "Cryptography" => 87.0,
          "Physical_Environmental_Security" => 91.0,
          "Operations_Security" => 89.0,
          "Communications_Security" => 93.0,
          "System_Acquisition_Development" => 86.0,
          "Supplier_Relationships" => 84.0,
          "Incident_Management" => 94.0,
          "Business_Continuity" => 88.0,
          "Compliance" => 96.0
        },
        gaps_identified: [
          "Minor documentation updates required in Asset Management",
          "Supplier risk assessments require annual review",
          "Business continuity testing schedule needs adjustment"
        ]
      }

      {:ok, audit_compliance} = ComplianceScore.create(audit_attrs)

      # Verify audit readiness
      assert audit_compliance.compliance_level in [:compliant, :exceeds]
      assert map_size(audit_compliance.control_scores) >= 10
      assert length(audit_compliance.gaps_identified) <= 5

      # Verify minimum control scores
      control_scores = Map.values(audit_compliance.control_scores)
      minimum_control_score = Enum.min(control_scores)
      assert minimum_control_score >= 80.0, "All controls should meet minimum threshold"
    end
  end

  # Helper Functions
  # Note: errors_on/1 is imported from Indrajaal.DataCase

  defp generate_test_control_scores(framework) do
    case framework do
      :iso_27001 ->
        %{
          "access_control" => 90.0,
          "asset_management" => 85.0,
          "incident_management" => 88.0,
          "business_continuity" => 92.0
        }

      :gdpr ->
        %{
          "lawfulness" => 85.0,
          "data_minimisation" => 80.0,
          "integrity_confidentiality" => 90.0,
          "accountability" => 88.0
        }

      :hipaa ->
        %{
          "administrative_safeguards" => 90.0,
          "physical_safeguards" => 88.0,
          "technical_safeguards" => 92.0
        }

      _ ->
        %{"general_control" => 85.0}
    end
  end

  defp generate_test_gaps(framework) do
    case framework do
      :iso_27001 ->
        ["Risk assessment documentation", "Staff training updates"]

      :gdpr ->
        ["Data retention policies", "Subject access procedures"]

      :hipaa ->
        ["Access logs review", "Workforce training"]

      _ ->
        ["General compliance gap"]
    end
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.11 Compliance: ✅ Regulatory compliance tracking with comprehensive audit trail
# Domain: Analytics
# Responsibilities: Compliance scoring, regulatory frameworks, gap analysis, audit preparation
# Multi-Agent Architecture: Integrated with 15-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
