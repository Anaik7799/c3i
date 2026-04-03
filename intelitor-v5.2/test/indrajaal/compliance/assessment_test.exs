defmodule Indrajaal.Compliance.AssessmentTest do
  use Indrajaal.DataCase

  alias Indrajaal.Compliance.{Assessment, Framework, Requirement, Report}
  alias Indrajaal.Core.{Tenant, Organization}

  describe "Assessment resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      framework = insert(:compliance_framework, tenant: tenant)

      {:ok, tenant: tenant, organization: organization, framework: framework}
    end

    test "creates assessment with valid attributes", %{
      tenant: tenant,
      organization: organization,
      framework: framework
    } do
      attrs = %{
        assessment_type: :annual_audit,
        status: :planned,
        title: "ISO 27_001 Annual Assessment",
        description: "Comprehensive security management system assessment",
        scope: "Information security management across all business units",
        start_date: Date.utc_today(),
        target_completion_date: Date.utc_today() |> Date.add(30),
        assessor_name: "External Auditor Inc.",
        assessment_criteria: %{
          "compliance_percentage_required" => 95,
          "critical_findings_allowed" => 0,
          "major_findings_allowed" => 2
        },
        framework_id: framework.id,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, assessment} = Assessment.create(attrs)

      assert assessment.assessment_type == :annual_audit
      assert assessment.status == :planned
      assert assessment.title == "ISO 27_001 Annual Assessment"
      assert assessment.scope == "Information security management across all business units"
      assert assessment.assessor_name == "External Auditor Inc."

      assert assessment.assessment_criteria["compliance_percentage_required"] ==
               95

      assert assessment.framework_id == framework.id
      assert assessment.organization_id == organization.id
      assert assessment.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Assessment.create(%{tenant_id: tenant.id})

      assert changeset.errors[:assessment_type]
      assert changeset.errors[:title]
      assert changeset.errors[:start_date]
      assert changeset.errors[:organization_id]
      assert changeset.errors[:framework_id]
    end

    test "validates assessment type", %{
      tenant: tenant,
      organization: organization,
      framework: framework
    } do
      valid_types = [
        :annual_audit,
        :internal_review,
        :certification_audit,
        :surveillance_audit,
        :gap_analysis,
        :risk_assessment
      ]

      for type <- valid_types do
        {:ok, _assessment} =
          Assessment.create(%{
            assessment_type: type,
            title: "Test Assessment",
            start_date: Date.utc_today(),
            organization_id: organization.id,
            framework_id: framework.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Assessment.create(%{
          assessment_type: :invalid_type,
          title: "Test Assessment",
          start_date: Date.utc_today(),
          organization_id: organization.id,
          framework_id: framework.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:assessment_type]
    end

    test "manages assessment lifecycle", %{
      tenant: tenant,
      organization: organization,
      framework: framework
    } do
      assessment =
        insert(:assessment,
          tenant: tenant,
          organization: organization,
          framework: framework,
          status: :planned
        )

      # Start assessment
      {:ok, started_assessment} =
        Assessment.start_assessment(assessment, %{
          started_by: "Lead Auditor",
          actual_start_date: Date.utc_today(),
          initial_notes: "Assessment kicked off with opening meeting"
        })

      assert started_assessment.status == :in_progress
      assert started_assessment.actual_start_date
      assert started_assessment.metadata["started_by"] == "Lead Auditor"

      # Complete assessment
      {:ok, completed_assessment} =
        Assessment.complete_assessment(started_assessment, %{
          completion_date: Date.utc_today(),
          overall_compliance_score: 92.5,
          findings_count: %{
            "critical" => 0,
            "major" => 1,
            "minor" => 5,
            "opportunities" => 8
          },
          completion_notes: "Assessment completed successfully"
        })

      assert completed_assessment.status == :completed
      assert completed_assessment.completion_date
      assert completed_assessment.overall_compliance_score == 92.5
      assert completed_assessment.findings_count["major"] == 1
    end

    test "tracks assessment findings", %{
      tenant: tenant,
      organization: organization,
      framework: framework
    } do
      assessment =
        insert(:assessment,
          tenant: tenant,
          organization: organization,
          framework: framework,
          status: :in_progress
        )

      finding_data = %{
        finding_type: "major",
        control_reference: "A.12.2.1",
        control_title: "Management of technical vulnerabilities",
        description: "Vulnerability management process not fully documented",
        evidence: "No documented procedure for vulnerability scanning schedule",
        recommendation: "Develop and implement formal vulnerability management procedure",
        target_date: Date.utc_today() |> Date.add(60)
      }

      {:ok, assessment_with_finding} = Assessment.add_finding(assessment, finding_data)

      assert assessment_with_finding.metadata["findings"]
      finding = List.first(assessment_with_finding.metadata["findings"])
      assert finding["type"] == "major"
      assert finding["control_reference"] == "A.12.2.1"
      assert finding["description"] == "Vulnerability management process
        not fully documented"
    end

    test "calculates compliance percentage", %{
      tenant: tenant,
      organization: organization,
      framework: framework
    } do
      assessment =
        insert(:assessment,
          tenant: tenant,
          organization: organization,
          framework: framework,
          metadata: %{
            "total_controls_assessed" => 50,
            "compliant_controls" => 46,
            "non_compliant_controls" => 4
          }
        )

      assessment_with_calc = Assessment.read!(assessment.id, load: [:compliance_percentage])

      # 46 / 50 * 100
      assert assessment_with_calc.compliance_percentage == 92.0
    end

    test "enforces tenant isolation",
         %{organization: organization, framework: framework} do
      tenant1 = organization.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      framework2 = insert(:compliance_framework, tenant: tenant2)

      assessment1 =
        insert(:assessment, tenant: tenant1, organization: organization, framework: framework)

      assessment2 =
        insert(:assessment, tenant: tenant2, organization: organization2, framework: framework2)

      tenant1_assessments = Assessment.read!(tenant: tenant1)
      tenant2_assessments = Assessment.read!(tenant: tenant2)

      assert length(tenant1_assessments) == 1
      assert length(tenant2_assessments) == 1
      assert Enum.any?(tenant1_assessments, &(&1.id == assessment1.id))
      assert Enum.any?(tenant2_assessments, &(&1.id == assessment2.id))
      refute Enum.any?(tenant1_assessments, &(&1.id == assessment2.id))
      refute Enum.any?(tenant2_assessments, &(&1.id == assessment1.id))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
