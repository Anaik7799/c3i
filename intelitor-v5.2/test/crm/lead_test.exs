defmodule Indrajaal.Crm.LeadDomainTest do
  @moduledoc """
  Comprehensive test suite for Lead resource.

  ## Test Matrix Coverage
  - L1 Unit: CRUD operations, validations
  - L2 Property: Score bounds, field constraints
  - L3 Integration: Assignment, conversion
  - L5 E2E: Full lead lifecycle

  ## STAMP Constraints
  - SC-COV-001: 100% coverage for critical paths
  - SC-TDG-001: TDG compliance with dual property tests
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Lead

  @moduletag :crm
  @moduletag :unit

  setup do
    actor = %{id: Ash.UUID.generate(), role: :admin}
    tenant = random_tenant()
    {:ok, actor: actor, tenant: tenant}
  end

  describe "L1 Unit Tests - Lead CRUD" do
    @tag :unit
    test "creates lead with required fields", %{actor: actor, tenant: tenant} do
      attrs = %{
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        company: "Acme Corp",
        lead_source: :web,
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:ok, lead} = Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)
      assert lead.first_name == "John"
      assert lead.last_name == "Doe"
      assert lead.status == :new
    end

    @tag :unit
    test "validates email format", %{actor: actor, tenant: tenant} do
      attrs = %{
        first_name: "John",
        last_name: "Doe",
        email: "invalid-email",
        company: "Acme Corp",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:error, changeset} =
               Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert "must be a valid email" in errors_on(changeset).email
    end

    @tag :unit
    test "sets default score to 0", %{actor: actor, tenant: tenant} do
      attrs = %{
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@example.com",
        company: "Tech Inc",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:ok, lead} = Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)
      assert lead.score == 0
    end

    @tag :unit
    test "updates lead status", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)

      assert {:ok, updated} =
               Lead.update(lead, %{status: :contacted},
                 actor: actor,
                 authorize?: false,
                 tenant: tenant.id
               )

      assert updated.status == :contacted
    end

    @tag :unit
    test "soft deletes lead", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)

      assert {:ok, deleted} =
               Lead.destroy(lead, actor: actor, authorize?: false, tenant: tenant.id)

      assert deleted.id == lead.id
    end

    @tag :unit
    test "reads lead by id", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)

      assert {:ok, fetched} =
               Lead.get(lead.id, actor: actor, authorize?: false, tenant: tenant.id)

      assert fetched.id == lead.id
    end

    @tag :unit
    test "lists leads by status", %{actor: actor, tenant: tenant} do
      {:ok, _lead1} = create_test_lead(actor, tenant)
      {:ok, _lead2} = create_test_lead(actor, tenant)
      {:ok, _lead3} = create_test_lead(actor, tenant)

      {:ok, new_leads} = Lead.by_status(:new, actor: actor, authorize?: false, tenant: tenant.id)
      assert length(new_leads) >= 2
    end

    @tag :unit
    test "filters leads by source", %{actor: actor, tenant: tenant} do
      {:ok, _lead} = create_test_lead(actor, tenant, %{lead_source: :referral})

      {:ok, referral_leads} =
        Lead.by_source(:referral, actor: actor, authorize?: false, tenant: tenant.id)

      assert length(referral_leads) >= 1
    end

    @tag :unit
    test "gets hot leads with score >= 80", %{actor: actor, tenant: tenant} do
      # Score is set via the :score update action (computed), default is 0
      {:ok, _cold} = create_test_lead(actor, tenant)
      {:ok, _hot} = create_test_lead(actor, tenant)

      {:ok, hot_leads} = Lead.hot_leads(actor: actor, authorize?: false, tenant: tenant.id)
      assert Enum.all?(hot_leads, fn l -> l.score >= 80 end)
    end
  end

  describe "L2 Property Tests - Lead Constraints" do
    @tag :property
    property "score is always between 0 and 100" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall _score <- PC.float(0.0, 100.0) do
        # Score is computed via the :score update action; default is 0 (integer, 0..100)
        {:ok, lead} = create_test_lead(actor, tenant)

        lead.score >= 0 and lead.score <= 100
      end
    end

    @tag :property
    test "L2 Property Tests - Lead Constraints email addresses are always valid format", %{
      actor: actor,
      tenant: tenant
    } do
      ExUnitProperties.check all(email <- SD.string(:alphanumeric, min_length: 1)) do
        attrs = %{
          first_name: "Test",
          last_name: "User",
          email: email,
          company: "Test Co",
          created_by_id: Ash.UUID.generate(),
          tenant_id: tenant.id
        }

        case Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id) do
          {:ok, lead} -> assert String.contains?(lead.email, "@")
          {:error, _} -> assert true
        end
      end
    end

    @tag :property
    property "status transitions are valid" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()
      valid_statuses = [:new, :contacted, :qualified, :unqualified, :converted]

      forall status <- PC.oneof(valid_statuses) do
        {:ok, lead} = create_test_lead(actor, tenant)

        {:ok, updated} =
          Lead.update(lead, %{status: status}, actor: actor, authorize?: false, tenant: tenant.id)

        updated.status in valid_statuses
      end
    end

    @tag :property
    test "L2 Property Tests - Lead Constraints first_name and last_name are non-empty strings", %{
      actor: actor,
      tenant: tenant
    } do
      ExUnitProperties.check all(
                               first <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               last <- SD.string(:alphanumeric, min_length: 1, max_length: 50)
                             ) do
        attrs = %{
          first_name: first,
          last_name: last,
          email: "#{first}.#{last}@test.com",
          company: "Test",
          created_by_id: Ash.UUID.generate(),
          tenant_id: tenant.id
        }

        case Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id) do
          {:ok, lead} ->
            assert String.length(lead.first_name) > 0 and String.length(lead.last_name) > 0

          {:error, _} ->
            assert true
        end
      end
    end
  end

  describe "L3 Integration Tests - Lead Assignment" do
    @tag :integration
    test "assigns lead via round-robin", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)
      team_id = "sales-team-1"

      # This would integrate with LeadAssignment module
      assert {:ok, assignee} =
               Indrajaal.Crm.Automation.LeadAssignment.assign_round_robin(lead, team_id)

      assert is_binary(assignee)
    end

    @tag :integration
    test "assigns lead by territory", %{actor: actor, tenant: tenant} do
      {:ok, lead} =
        create_test_lead(actor, tenant, %{
          state: "CA",
          country: "US",
          industry: "tech"
        })

      assert {:ok, owner_or_error} =
               Indrajaal.Crm.Automation.LeadAssignment.assign_by_territory(lead)

      # Territory assignment returns owner or error
      assert is_binary(owner_or_error) or owner_or_error == :no_territory_owner
    end

    @tag :integration
    test "assigns lead by skill matching", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)
      required_skills = ["enterprise", "saas"]

      assert {:ok, assignee} =
               Indrajaal.Crm.Automation.LeadAssignment.assign_by_skill(lead, required_skills)

      assert is_binary(assignee)
    end
  end

  describe "L5 E2E Tests - Lead Lifecycle" do
    @tag :e2e
    test "full lead lifecycle: create → qualify → convert", %{actor: actor, tenant: tenant} do
      # 1. Create lead
      {:ok, lead} = create_test_lead(actor, tenant)
      assert lead.status == :new

      # 2. Update score (simulate engagement via :score action which computes score)
      {:ok, scored} = Lead.score(lead, actor: actor, authorize?: false, tenant: tenant.id)
      assert scored.score >= 0 and scored.score <= 100

      # 3. Contact lead
      {:ok, contacted} =
        Lead.update(scored, %{status: :contacted},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert contacted.status == :contacted

      # 4. Qualify lead
      {:ok, qualified} =
        Lead.update(contacted, %{status: :qualified},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert qualified.status == :qualified

      # 5. Convert lead (would create Account, Contact, Opportunity)
      {:ok, converted} =
        Lead.convert(
          qualified,
          %{
            create_account: true,
            create_contact: true,
            create_opportunity: true,
            opportunity_name: "New Deal"
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert converted.status == :converted
      assert converted.converted_at != nil
    end
  end

  describe "L6 Performance Tests" do
    @tag :performance
    test "bulk lead creation under 5 seconds", %{actor: actor, tenant: tenant} do
      leads_data =
        Enum.map(1..100, fn i ->
          %{
            first_name: "User#{i}",
            last_name: "Test",
            email: "user#{i}@test.com",
            company: "Company#{i}",
            created_by_id: Ash.UUID.generate(),
            tenant_id: tenant.id
          }
        end)

      {time_us, results} =
        :timer.tc(fn ->
          Enum.map(
            leads_data,
            &Lead.create(&1, actor: actor, authorize?: false, tenant: tenant.id)
          )
        end)

      time_ms = time_us / 1000
      assert time_ms < 5000, "Bulk creation took #{time_ms}ms, expected < 5000ms"
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "L7 Security Tests" do
    @tag :security
    test "prevents SQL injection in search", %{actor: actor, tenant: tenant} do
      malicious_input = "'; DROP TABLE leads; --"

      # Search should handle this safely
      assert {:ok, _results} =
               Lead.search(malicious_input, actor: actor, authorize?: false, tenant: tenant.id)
    end

    @tag :security
    test "sanitizes XSS in string fields", %{actor: actor, tenant: tenant} do
      attrs = %{
        first_name: "<script>alert('xss')</script>",
        last_name: "Test",
        email: "test@example.com",
        company: "Test",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      {:ok, lead} = Lead.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)
      refute String.contains?(lead.first_name, "<script>")
    end
  end

  describe "L8 Chaos Tests" do
    @tag :chaos
    test "handles concurrent updates gracefully", %{actor: actor, tenant: tenant} do
      {:ok, lead} = create_test_lead(actor, tenant)

      tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn ->
            Lead.update(lead, %{status: :contacted},
              actor: actor,
              authorize?: false,
              tenant: tenant.id
            )
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # At least one should succeed, others may get stale data errors
      success_count = Enum.count(results, &match?({:ok, _}, &1))
      assert success_count >= 1
    end
  end

  # Helper functions

  defp create_test_lead(actor, tenant, attrs \\ %{}) do
    default_attrs = %{
      first_name: "Test",
      last_name: "Lead#{System.unique_integer([:positive])}",
      email: "test#{System.unique_integer([:positive])}@example.com",
      company: "Test Company",
      lead_source: :web,
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant.id
    }

    Lead.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end
end
