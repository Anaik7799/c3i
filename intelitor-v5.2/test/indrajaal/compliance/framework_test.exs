defmodule Indrajaal.Compliance.FrameworkTest do
  use Indrajaal.DataCase

  alias Indrajaal.Compliance.{Framework, Requirement, Assessment, Report}
  alias Indrajaal.Core.Tenant

  describe "Framework resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)

      {:ok, tenant: tenant, organization: organization}
    end

    test "creates a compliance framework with valid attributes", %{
      tenant: tenant,
      organization: organization
    } do
      attrs = %{
        name: "ISO 27_001:2022",
        version: "2022",
        framework_type: :security,
        status: :active,
        description: "Information Security Management System standard",
        authority: "International Organization for Standardization",
        effective_date: ~D[2022-10-25],
        review_cycle_months: 12,
        framework_details: %{
          "domain" => "Information Security",
          "scope" => "Organization - wide ISMS",
          "certification_required" => true,
          "external_audit" => true,
          "controls_count" => 93
        },
        compliance_requirements: %{
          "mandatory_controls" => [
            "A.5.1 - Information security policies",
            "A.6.1 - Internal organization",
            "A.8.1 - Responsibility for assets"
          ],
          "risk_assessment" => true,
          "documentation" => ["ISMS policy", "Risk register", "SOA"]
        },
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, framework} = Framework.create(attrs)

      assert framework.name == "ISO 27_001:2022"
      assert framework.version == "2022"
      assert framework.framework_type == :security
      assert framework.status == :active
      assert framework.authority == "International Organization for Standardization"
      assert framework.review_cycle_months == 12
      assert framework.framework_details["controls_count"] == 93

      assert length(framework.compliance_requirements["mandatory_controls"]) ==
               3

      assert framework.organization_id == organization.id
      assert framework.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Framework.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:framework_type]
      assert changeset.errors[:organization_id]
    end

    test "manages framework status transitions",
         %{tenant: tenant, organization: organization} do
      framework =
        insert(:framework,
          status: :draft,
          tenant: tenant,
          organization: organization
        )

      # Draft -> Active
      {:ok, active_framework} =
        Framework.activate(framework, %{
          activated_by: "compliance_officer",
          activation_notes: "Framework reviewed and approved"
        })

      assert active_framework.status == :active
      assert active_framework.metadata["activation_record"]

      # Active -> Deprecated
      {:ok, deprecated_framework} =
        Framework.deprecate(active_framework, %{
          deprecated_by: "compliance_officer",
          deprecation_reason: "Replaced by newer version",
          replacement_framework_id: "framework - new-123"
        })

      assert deprecated_framework.status == :deprecated

      assert deprecated_framework.metadata["deprecation_record"]["reason"] ==
               "Replaced by newer version"
    end

    test "manages framework requirements",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      requirements = [
        %{
          "control_id" => "A.5.1",
          "title" => "Information security policies",
          "description" => "Establish and maintain information security policies",
          "implementation_guidance" => "Document and communicate security policies",
          "evidence_required" => ["Policy document", "Approval records"]
        },
        %{
          "control_id" => "A.6.1",
          "title" => "Internal organization",
          "description" => "Establish management framework for information security",
          "implementation_guidance" => "Define roles and responsibilities",
          "evidence_required" => ["Organization chart", "Role definitions"]
        }
      ]

      {:ok, framework_with_reqs} =
        Framework.add_requirements(framework, %{
          requirements: requirements
        })

      assert length(framework_with_reqs.requirements) == 2
      req_a5 = Enum.find(framework_with_reqs.requirements, &(&1["control_id"] == "A.5.1"))
      assert req_a5["title"] == "Information security policies"
    end

    test "tracks compliance assessment progress",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      # Create assessments for the framework
      for i <- 1..5 do
        insert(:assessment,
          framework: framework,
          status: if(i <= 3, do: :completed, else: :in_progress),
          tenant: tenant,
          organization: organization
        )
      end

      framework_with_calc = Framework.read!(framework.id, load: [:compliance_percentage])
      # 3 / 5 = 60%
      assert framework_with_calc.compliance_percentage == 60.0
    end

    test "generates compliance reports",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      {:ok, report} =
        Framework.generate_report(framework, %{
          report_type: "compliance_status",
          period_start: Date.utc_today() |> Date.add(-90),
          period_end: Date.utc_today(),
          include_details: true
        })

      assert report.metadata["generated_report"]
      report_data = report.metadata["generated_report"]
      assert report_data["framework_id"] == framework.id
      assert report_data["report_type"] == "compliance_status"
      assert report_data["generated_at"]
    end

    test "manages framework documentation",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      documents = [
        %{
          "document_type" => "policy",
          "title" => "Information Security Policy",
          "filename" => "isms - policy.pdf",
          "url" => "https://docs.example.com / isms - policy.pdf",
          "version" => "1.2",
          "approved_by" => "CISO",
          "approval_date" => Date.utc_today()
        },
        %{
          "document_type" => "procedure",
          "title" => "Risk Assessment Procedure",
          "filename" => "risk - assessment.pdf",
          "url" => "https://docs.example.com / risk - assessment.pdf",
          "version" => "2.0"
        }
      ]

      {:ok, framework_with_docs} =
        Framework.attach_documents(framework, %{
          documents: documents
        })

      assert length(framework_with_docs.documents) == 2
      policy_doc = Enum.find(framework_with_docs.documents, &(&1["document_type"] == "policy"))
      assert policy_doc["title"] == "Information Security Policy"
    end

    test "tracks audit findings",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      audit_findings = [
        %{
          "finding_id" => "FIND - 001",
          "severity" => "major",
          "control_reference" => "A.8.1",
          "description" => "Asset inventory not up to date",
          "recommendation" => "Update asset inventory quarterly",
          "due_date" => Date.utc_today() |> Date.add(30),
          "status" => "open"
        },
        %{
          "finding_id" => "FIND - 002",
          "severity" => "minor",
          "control_reference" => "A.12.1",
          "description" => "Backup testing documentation incomplete",
          "recommendation" => "Document all backup test results",
          "due_date" => Date.utc_today() |> Date.add(14),
          "status" => "open"
        }
      ]

      {:ok, framework_with_findings} =
        Framework.record_audit_findings(framework, %{
          audit_findings: audit_findings,
          audit_date: Date.utc_today(),
          auditor: "External Audit Firm"
        })

      assert length(framework_with_findings.audit_findings) == 2

      major_finding =
        Enum.find(framework_with_findings.audit_findings, &(&1["severity"] == "major"))

      assert major_finding["control_reference"] == "A.8.1"
    end

    test "calculates framework maturity level",
         %{tenant: tenant, organization: organization} do
      framework = insert(:framework, tenant: tenant, organization: organization)

      # Add maturity indicators
      maturity_data = %{
        "process_maturity" => %{
          "documented" => true,
          "implemented" => true,
          "monitored" => true,
          "optimized" => false
        },
        "control_effectiveness" => %{
          "design_effective" => true,
          "operating_effective" => true,
          "tested_regularly" => false
        },
        "risk_management" => %{
          "risk_identified" => true,
          "risk_assessed" => true,
          "risk_treated" => true,
          "risk_monitored" => false
        }
      }

      {:ok, framework_with_maturity} =
        Framework.assess_maturity(framework, %{
          maturity_assessment: maturity_data
        })

      framework_with_calc = Framework.read!(framework_with_maturity.id, load: [:maturity_level])
      assert framework_with_calc.maturity_level in [1, 2, 3, 4, 5]
    end

    test "manages certification status",
         %{tenant: tenant, organization: organization} do
      framework =
        insert(:framework,
          framework_details: %{"certification_required" => true},
          tenant: tenant,
          organization: organization
        )

      certification_data = %{
        "certificate_number" => "ISO27001 - 2024 - 001",
        "issued_by" => "Certification Body Ltd",
        "issued_date" => Date.utc_today(),
        # 3 years
        "expiry_date" => Date.utc_today() |> Date.add(1095),
        "scope" => "Information security management for all operations",
        "certificate_url" => "https://certs.example.com / iso27001 - 001.pdf"
      }

      {:ok, certified_framework} =
        Framework.record_certification(framework, %{
          certification: certification_data
        })

      assert certified_framework.certification["certificate_number"] ==
               "ISO27001 - 2024 - 001"

      assert certified_framework.certification["issued_by"] == "Certification
        Body Ltd"

      # Check expiry calculation
      framework_with_calc =
        Framework.read!(certified_framework.id, load: [:certification_expires_in_days])

      assert framework_with_calc.certification_expires_in_days > 1000
    end

    test "enforces tenant isolation", %{organization: organization} do
      tenant1 = organization.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)

      framework1 = insert(:framework, tenant: tenant1, organization: organization)
      framework2 = insert(:framework, tenant: tenant2, organization: organization2)

      tenant1_frameworks = Framework.read!(tenant: tenant1)
      tenant2_frameworks = Framework.read!(tenant: tenant2)

      assert length(tenant1_frameworks) == 1
      assert length(tenant2_frameworks) == 1
      assert Enum.any?(tenant1_frameworks, &(&1.id == framework1.id))
      assert Enum.any?(tenant2_frameworks, &(&1.id == framework2.id))
      refute Enum.any?(tenant1_frameworks, &(&1.id == framework2.id))
      refute Enum.any?(tenant2_frameworks, &(&1.id == framework1.id))
    end

    test "validates framework version management",
         %{tenant: tenant, organization: organization} do
      # Create original framework
      original_framework =
        insert(:framework,
          name: "ISO 27_001",
          version: "2013",
          status: :active,
          tenant: tenant,
          organization: organization
        )

      # Create new version
      {:ok, new_version} =
        Framework.create_new_version(original_framework, %{
          version: "2022",
          changes_summary: "Updated controls and risk management approach",
          migration_plan: "6 - month transition period"
        })

      assert new_version.version == "2022"
      assert new_version.status == :draft
      assert new_version.parent_framework_id == original_framework.id
      assert new_version.metadata["version_info"]["changes_summary"]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
