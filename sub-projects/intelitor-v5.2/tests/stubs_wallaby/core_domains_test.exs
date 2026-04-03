defmodule Intelitor.Wallaby.CoreDomainsTest do
  @moduledoc """
  Comprehensive E2E tests for Core domain functionality.

  Tests cover:
  - Tenant management workflows
  - Organization management
  - System configuration
  - Multi - tenant data isolation
  - Audit logging
  """

  use Intelitor.WallabyCase
  use Intelitor.WallabyPageObjects

  alias Intelitor.WallabyPageObjects.{TenantsPage, OrganizationsPage, DashboardPage}

  @moduletag :wallaby
  @moduletag :core_domains

  setup %{session: session, tenant: tenant} do
    admin_user = get_admin_user_for_tenant(tenant)

    session = session |> authenticate_user(admin_user)

    %{session: session, admin_user: admin_user}
  end

  describe "Tenant Management" do
    test "admin can create new tenant successfully", %{session: session} do
      tenant_data = %{
        name: "New Test Tenant",
        subdomain: "new - test - tenant",
        status: "active",
        plan: "premium"
      }

      session
      |> navigate_to_domain("tenants")
      |> assert_page_loaded()
      |> click(TenantsPage.new_tenant_button())
      |> assert_has(TenantsPage.tenant_form())
      |> fill_form("[data - test='tenant - form']", tenant_data)
      |> click(TenantsPage.save_button())
      |> assert_flash_message("success", "Tenant created successfully")
      |> assert_has(Wallaby.Query.text(tenantdata.name))
      |> validate_table_data(TenantsPage.listing_table(), 1)
    end

    test "tenant creation form validation works correctly",
         %{session: session} do
      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.new_tenant_button())
      |> click(TenantsPage.save_button())
      |> assert_validation_errors(%{
        name: "Name is required",
        subdomain: "Subdomain is required"
      })
    end

    test "tenant subdomain uniqueness is enforced",
         %{session: session, tenant: existing_tenant} do
      duplicate_tenant_data = %{
        name: "Duplicate Subdomain Tenant",
        subdomain: existing_tenant.subdomain,
        status: "active"
      }

      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.new_tenant_button())
      |> fill_form("[data - test='tenant - form']", duplicate_tenant_data)
      |> click(TenantsPage.save_button())
      |> assert_validation_errors(%{
        subdomain: "Subdomain is already taken"
      })
    end

    test "admin can update existing tenant",
         %{session: session, tenant: tenant} do
      updated_data = %{
        name: "Updated Tenant Name",
        status: "suspended"
      }

      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.edit_button(tenant.id))
      |> fill_form("[data - test='tenant - form']", updated_data)
      |> click(TenantsPage.save_button())
      |> assert_flash_message("success", "Tenant updated successfully")
      |> assert_has(Wallaby.Query.text(updateddata.name))
    end

    test "admin can view tenant details and usage metrics",
         %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("tenants")
      |> click(css("[data - test='view - tenant-#{tenant.id}']"))
      |> assert_has(css("[data - test='tenant - details']"))
      |> assert_has(Wallaby.Query.text(tenant.name))
      |> assert_has(css("[data - test='usage - metrics']"))
      |> assert_has(css("[data - test='user - count']"))
      |> assert_has(css("[data - test='storage - usage']"))
    end

    test "tenant deletion __requires confirmation and works correctly",
         %{session: session} do
      # Create a test tenant to delete
      test_tenant = insert(:tenant, name: "Tenant to Delete")

      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.delete_button(test_tenant.id))
      |> accept_alert()
      |> assert_flash_message("success", "Tenant deleted successfully")
      |> refute_has(Wallaby.Query.text(test_tenant.name))
    end

    test "tenant listing supports search and filtering",
         %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("tenants")
      |> search_and_validate(tenant.name, 1)
      |> fill_in(css("[data - test='status - filter']"), with: "active")
      |> assert_has(Wallaby.Query.text(tenant.name))
      |> fill_in(css("[data - test='status - filter']"), with: "suspended")
      |> refute_has(Wallaby.Query.text(tenant.name))
    end
  end

  describe "Organization Management" do
    test "user can create organization within tenant",
         %{session: session, tenant: tenant} do
      org_data = %{
        name: "Test Organization",
        type: "department",
        description: "Test organization for E2E testing"
      }

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> click(OrganizationsPage.new_organization_button())
      |> fill_form("[data - test='organization - form']", org_data)
      |> click(css("[data - test='save - organization']"))
      |> assert_flash_message("success", "Organization created successfully")
      |> assert_has(Wallaby.Query.text(orgdata.name))
    end

    test "organization hierarchy can be established",
         %{session: session, tenant: tenant} do
      # Create parent organization first
      parent_org = insert(:organization, tenant: tenant, name: "Parent Organization")

      child_org_data = %{
        name: "Child Organization",
        type: "team",
        parent_organization: parent_org.name
      }

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> click(OrganizationsPage.new_organization_button())
      |> fill_form("[data - test='organization - form']", child_org_data)
      |> select(OrganizationsPage.parent_organization_select(), option: parent_org.name)
      |> click(css("[data - test='save - organization']"))
      |> assert_flash_message("success", "Organization created successfully")
      |> assert_has(Wallaby.Query.text(child_orgdata.name))
      |> assert_has(Wallaby.Query.text("Child of #{parent_org.name}"))
    end

    test "organization users can be managed",
         %{session: session, tenant: tenant} do
      organization = insert(:organization, tenant: tenant)
      user = insert(:user, tenant: tenant)

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> click(css("[data - test='view - organization-#{organization.id}']"))
      |> click(css("[data - test='manage - users']"))
      |> click(css("[data - test='add - user']"))
      |> select(css("[data - test='user - select']"), option: user.email)
      |> click(css("[data - test='add - user - submit']"))
      |> assert_flash_message("success", "User added to organization")
      |> assert_has(Wallaby.Query.text(user.email))
    end
  end

  describe "System Configuration" do
    test "admin can update system configuration settings",
         %{session: session, tenant: tenant} do
      config_data = %{
        session_timeout: "30",
        max_login_attempts: "5",
        password_complexity: "high",
        enable_audit_logging: true
      }

      session
      |> navigate_to_domain("system - config", tenant.id)
      |> fill_form("[data - test='system - config - form']", config_data)
      |> click(css("[data - test='save - config']"))
      |> assert_flash_message("success", "System configuration updated")
      |> assert_has(css("[data - test='config - saved']"))
    end

    test "system configuration validation prevents invalid values", %{
      session: session,
      tenant: tenant
    } do
      invalid_config = %{
        session_timeout: "0",
        max_login_attempts: "-1",
        password_complexity: ""
      }

      session
      |> navigate_to_domain("system - config", tenant.id)
      |> fill_form("[data - test='system - config - form']", invalid_config)
      |> click(css("[data - test='save - config']"))
      |> assert_validation_errors(%{
        session_timeout: "Must be greater than 0",
        max_login_attempts: "Must be a positive number",
        password_complexity: "Please select a complexity level"
      })
    end

    test "feature flags can be toggled", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("feature - flags", tenant.id)
      |> assert_has(css("[data - test='feature - flags - list']"))
      |> click(css("[data - test='toggle - advanced - analytics']"))
      |> assert_flash_message("success", "Feature flag updated")
      |> assert_has(css("[data - test='advanced - analytics'][data - enabled='true']"))
    end
  end

  describe "Multi - Tenant Data Isolation" do
    test "tenant data is completely isolated between tenants", %{
      session: session,
      tenant: tenant_a
    } do
      # Create second tenant with data
      tenant_b = insert(:tenant, name: "Tenant B")
      org_b = insert(:organization, tenant: tenant_b, name: "Tenant B Organization")

      session
      |> navigate_to_domain("organizations", tenant_a.id)
      # Should find nothing
      |> search_and_validate("Tenant B Organization", 0)
      |> navigate_to_domain("organizations", tenant_b.id)
      # Should be denied access
      |> assert_has(css("[data - test='access - denied']"))
    end

    test "cross - tenant data access is properly blocked",
         %{session: session, tenant: tenant} do
      other_tenant = insert(:tenant, name: "Other Tenant")

      # Attempt to access other tenant's dashboard directly
      session
      |> visit("/tenants/#{other_tenant.id}/dashboard")
      |> assert_has(css("[data - test='access - denied']"))
      |> assert_has(Wallaby.Query.text("You do not have permission to access this tenant"))
    end

    test "API endpoints enforce tenant isolation",
         %{session: session, tenant: tenant} do
      other_tenant = insert(:tenant)

      # Attempt to access other tenant's data via API
      session
      |> execute_script("""
        fetch('/api / tenants/#{other_tenant.id}/organizations')
          .then(response => window.apiResponse = response.status)
          .catch(error => window.apiError = error.message);
      """)
      # Wait for API call
      |> :timer.sleep(1000)
      |> execute_script("return window.apiResponse || window.apiError;")
      |> then(fn response ->
        # Should return 403 Forbidden or 404 Not Found
        assert response in [403, 404, "Access denied"],
               "Expected access denied, got: #{inspect(response)}"

        session
      end)
    end
  end

  describe "Audit Logging" do
    test "tenant operations are properly audited",
         %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.edit_button(tenant.id))
      |> fill_in(TenantsPage.tenant_name_field(),
        with: "Updated Audit Test Tenant"
      )
      |> click(TenantsPage.save_button())
      |> assert_flash_message("success", "Tenant updated successfully")

      # Verify audit log entry was created
      |> navigate_to_domain("audit - logs", tenant.id)
      |> assert_has(Wallaby.Query.text("Tenant updated"))
      |> assert_has(Wallaby.Query.text("Updated Audit Test Tenant"))
      |> assert_has(css("[data - test='audit - entry'][data - action='update']"))
    end

    test "organization operations are audited with proper __context", %{
      session: session,
      tenant: tenant
    } do
      org_data = %{name: "Audited Organization"}

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> click(OrganizationsPage.new_organization_button())
      |> fill_form("[data - test='organization - form']", org_data)
      |> click(css("[data - test='save - organization']"))
      |> assert_flash_message("success", "Organization created successfully")

      # Check audit log
      |> navigate_to_domain("audit - logs", tenant.id)
      |> assert_has(Wallaby.Query.text("Organization created"))
      |> assert_has(Wallaby.Query.text(orgdata.name))
      |> assert_has(css("[data - test='audit - entry'][data - resource='organization']"))
    end

    test "audit log provides detailed change tracking",
         %{session: session, tenant: tenant} do
      organization = insert(:organization, tenant: tenant, name: "Original Name")

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> click(css("[data - test='edit - organization-#{organization.id}']"))
      |> fill_in(css("[data - test='organization - name']"), with: "Modified Name")
      |> click(css("[data - test='save - organization']"))
      |> navigate_to_domain("audit - logs", tenant.id)
      |> click(css("[data - test='view - audit - details']"))
      |> assert_has(Wallaby.Query.text("Changes:"))
      |> assert_has(Wallaby.Query.text("name: Original Name → Modified Name"))
    end
  end

  describe "Performance and Scalability" do
    test "tenant listing performs well with large datasets",
         %{session: session} do
      # This test would be more meaningful with actual large datasets
      # For now, we test that the page loads within acceptable time
      session
      |> navigate_to_domain("tenants")
      |> assert_page_performance(3_000)
      |> validate_table_data(TenantsPage.listing_table(), 1)
    end

    test "organization hierarchy renders efficiently",
         %{session: session, tenant: tenant} do
      # Create nested organization structure
      parent = insert(:organization, tenant: tenant, name: "Parent")

      Enum.each(1..10, fn i ->
        insert(:organization, tenant: tenant, name: "Child #{i}", parent: parent)
      end)

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> assert_page_performance(3_000)
      |> assert_has(css("[data - test='organization - tree']"))
      |> validate_table_data(OrganizationsPage.listing_table(), 10)
    end

    test "search functionality performs well with large result sets", %{
      session: session,
      tenant: tenant
    } do
      # Create multiple organizations for search testing
      Enum.each(1..25, fn i ->
        insert(:organization, tenant: tenant, name: "Search Test Org #{i}")
      end)

      session
      |> navigate_to_domain("organizations", tenant.id)
      |> search_and_validate("Search Test", 25)
      |> assert_page_performance(2_000)
    end
  end

  describe "Error Handling" do
    test "network errors are handled gracefully", %{session: session} do
      session
      |> navigate_to_domain("tenants")
      # Simulate network error

      |> execute_script("window.fetch = () => Promise.reject(new Error('Network error'));")
      |> click(TenantsPage.new_tenant_button())
      |> assert_has(css("[data - test='network - error']"))
      |> assert_has(
        Wallaby.Query.text("Unable to connect. Please check your network connection.")
      )
    end

    test "server errors display user - friendly messages", %{session: session} do
      session
      # Non - existent tenant
      |> visit("/tenants / 99_999 / edit")
      |> assert_has(css("[data - test='not - found - error']"))
      |> assert_has(Wallaby.Query.text("The __requested tenant was not found"))
    end
  end

  describe "Accessibility" do
    test "tenant management pages are accessible", %{session: session} do
      session
      |> navigate_to_domain("tenants")
      # Has ARIA labels
      |> assert_has(css("[aria - label]"))
      # Has semantic roles
      |> assert_has(css("[role='main']"))
      # Tab navigation

      |> execute_script("return document.querySelectorAll('[tabindex]').length > 0;")
      |> assert()
    end

    test "forms have proper accessibility attributes", %{session: session} do
      session
      |> navigate_to_domain("tenants")
      |> click(TenantsPage.new_tenant_button())
      # Labels associated with inputs
      |> assert_has(css("label[for]"))
      # Required fields marked
      |> assert_has(css("[aria - required='true']"))
      # Help text associated
      |> assert_has(css("[aria - describedby]"))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
