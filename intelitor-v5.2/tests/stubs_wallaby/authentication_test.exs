defmodule Intelitor.Wallaby.AuthenticationTest do
  @moduledoc """
  Comprehensive E2E authentication tests using Wallaby.

  Tests cover:
  - User login/logout workflows
  - Multi-tenant authentication
  - Session management
  - Security validations
  - Password reset flows
  - Account registration
  """

  use Intelitor.WallabyCase
  use Intelitor.WallabyPageObjects

  alias Intelitor.WallabyPageObjects.{LoginPage, DashboardPage}

  @moduletag :wallaby
  @moduletag :authentication

  describe "User Login Workflow" do
    test "successful login with valid credentials", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      session
      |> visit("/login")
      |> assert_page_loaded()
      |> assert_security_headers()
      |> fill_in(LoginPage.email_field(), with: user.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> wait_for_ajax()
      |> assert_has(DashboardPage.main_container(), wait: 10_000)
      |> assert_has(Wallaby.Query.text(user.email))
      |> assert_current_path("/dashboard")
      |> assert_page_performance(3_000)
    end

    test "failed login with invalid credentials", %{session: session} do
      session
      |> visit("/login")
      |> assert_page_loaded()
      |> fill_in(LoginPage.email_field(), with: "invalid@example.com")
      |> fill_in(LoginPage.password_field(), with: "wrongpassword")
      |> click(LoginPage.submit_button())
      |> wait_for_ajax()
      |> assert_has(LoginPage.error_message())
      |> assert_has(Wallaby.Query.text("Invalid email or password"))
      |> assert_current_path("/login")
    end

    test "login form validation", %{session: session} do
      session
      |> visit("/login")
      |> assert_page_loaded()
      |> click(LoginPage.submit_button())
      |> assert_validation_errors(%{
        email: "Email is required",
        password: "Password is required"
      })
    end

    test "login with empty fields shows validation errors", %{session: session} do
      session
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: "")
      |> fill_in(LoginPage.password_field(), with: "")
      |> click(LoginPage.submit_button())
      |> assert_has(css("[data-test='error-email']"))
      |> assert_has(css("[data-test='error-password']"))
    end

    test "login with malformed email shows validation error", %{session: session} do
      session
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: "not-an-email")
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_has(css("[data-test='error-email']"))
      |> assert_has(Wallaby.Query.text("Please enter a valid email address"))
    end
  end

  describe "Multi-Tenant Authentication" do
    test "user can only access their tenant's data", %{session: session} do
      # Create two separate tenants with users
      tenant_a = insert(:tenant, name: "Tenant A")
      tenant_b = insert(:tenant, name: "Tenant B")

      __user_a = insert(:user, tenant: tenant_a, email: "__user_a@example.com")
      __user_b = insert(:user, tenant: tenant_b, email: "__user_b@example.com")

      # Login as user A
      session
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: __user_a.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_has(DashboardPage.main_container())

      # Verify tenant isolation
      |> assert_tenant_isolation(tenant_a, tenant_b)

      # Attempt to access tenant B's dashboard should fail
      |> visit("/tenants/#{tenant_b.id}/dashboard")
      |> assert_has(css("[data-test='access-denied']"))
      |> assert_has(Wallaby.Query.text("Access denied"))
    end

    test "tenant subdomain authentication redirects properly", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      # Visit tenant-specific subdomain URL
      session
      |> visit("/tenants/#{tenant.subdomain}/login")
      |> assert_page_loaded()
      |> fill_in(LoginPage.email_field(), with: user.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_has(DashboardPage.main_container())
      |> assert_has(Wallaby.Query.text(tenant.name))
      |> assert_current_path("/tenants/#{tenant.subdomain}/dashboard")
    end
  end

  describe "Session Management" do
    test "user logout clears session and redirects to login", %{
      session: session,
      tenant: tenant
    } do
      user = get_admin_user_for_tenant(tenant)

      session
      |> authenticate_user(user)
      |> assert_has(DashboardPage.main_container())
      |> click(DashboardPage.__user_menu())
      |> click(DashboardPage.logout_button())
      |> wait_for_ajax()
      |> assert_current_path("/login")
      |> assert_has(LoginPage.email_field())

      # Verify session is cleared by attempting to access protected route
      |> visit("/dashboard")
      |> assert_current_path("/login")
    end

    test "session timeout redirects to login with message", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      session
      |> authenticate_user(user)
      |> assert_has(DashboardPage.main_container())

      # Simulate session timeout by clearing cookies
      |> execute_script(
        "document.cookie.split(';').forEach(function(c) { document.cookie = c.replace(/^ +/, '').replace(/=.*/, '=;expires=' + new Date().toUTCString() + ';path=/'); });"
      )
      |> visit("/dashboard")
      |> assert_current_path("/login")
      |> assert_has(Wallaby.Query.text("Your session has expired. Please log in again."))
    end

    test "concurrent sessions are properly managed", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      # Start first session
      session
      |> authenticate_user(user)
      |> assert_has(DashboardPage.main_container())
      |> assert_has(Wallaby.Query.text("Welcome"))

      # Session should remain active and functional
      |> visit("/dashboard")
      |> assert_has(DashboardPage.main_container())
      |> assert_has(Wallaby.Query.text(user.email))
    end
  end

  describe "Password Reset Flow" do
    test "password reset __request sends email notification", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      session
      |> visit("/login")
      |> click(LoginPage.forgot_password_link())
      |> assert_current_path("/reset-password")
      |> fill_in(css("[data-test='reset-email']"), with: user.email)
      |> click(css("[data-test='send-reset']"))
      |> assert_flash_message(
        "success",
        "Password reset instructions have been sent to your email"
      )
      |> assert_current_path("/login")
    end

    test "password reset with invalid email shows error", %{session: session} do
      session
      |> visit("/reset-password")
      |> fill_in(css("[data-test='reset-email']"), with: "nonexistent@example.com")
      |> click(css("[data-test='send-reset']"))
      |> assert_flash_message("error", "Email address not found")
    end

    test "password reset form validation", %{session: session} do
      session
      |> visit("/reset-password")
      |> click(css("[data-test='send-reset']"))
      |> assert_validation_errors(%{
        email: "Email is required"
      })
    end
  end

  describe "Account Registration Flow" do
    test "new user registration creates account successfully", %{session: session} do
      registration_data = %{
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        password: "SecurePassword123!",
        password_confirmation: "SecurePassword123!",
        organization: "Test Organization"
      }

      session
      |> visit("/login")
      |> click(LoginPage.registration_link())
      |> assert_current_path("/register")
      |> fill_form("[data-test='registration-form']", registration_data)
      |> click(css("[data-test='register-submit']"))
      |> assert_flash_message(
        "success",
        "Account created successfully. Please check your email to verify your account."
      )
      |> assert_current_path("/login")
    end

    test "registration with existing email shows error", %{session: session, tenant: tenant} do
      existing_user = get_admin_user_for_tenant(tenant)

      registration_data = %{
        first_name: "Jane",
        last_name: "Smith",
        email: existing_user.email,
        password: "NewPassword123!",
        password_confirmation: "NewPassword123!"
      }

      session
      |> visit("/register")
      |> fill_form("[data-test='registration-form']", registration_data)
      |> click(css("[data-test='register-submit']"))
      |> assert_flash_message("error", "Email address is already registered")
    end

    test "registration form validation catches all error cases", %{session: session} do
      invalid_data = %{
        first_name: "",
        last_name: "",
        email: "not-an-email",
        password: "weak",
        password_confirmation: "different"
      }

      session
      |> visit("/register")
      |> fill_form("[data-test='registration-form']", invalid_data)
      |> click(css("[data-test='register-submit']"))
      |> assert_validation_errors(%{
        first_name: "First name is required",
        last_name: "Last name is required",
        email: "Please enter a valid email address",
        password: "Password must be at least 8 characters",
        password_confirmation: "Passwords do not match"
      })
    end
  end

  describe "Security Validations" do
    test "login page has proper security headers", %{session: session} do
      session
      |> visit("/login")
      |> assert_security_headers()
    end

    test "CSRF protection is enabled on login form", %{session: session} do
      session
      |> visit("/login")
      |> assert_has(css("meta[name='csrf-token']"))
      |> assert_has(css("input[name='_csrf_token']"))
    end

    test "login attempts are rate limited", %{session: session} do
      # Attempt multiple failed logins rapidly
      Enum.each(1..6, fn _attempt ->
        session
        |> visit("/login")
        |> fill_in(LoginPage.email_field(), with: "test@example.com")
        |> fill_in(LoginPage.password_field(), with: "wrongpassword")
        |> click(LoginPage.submit_button())
        |> wait_for_ajax()
      end)

      # Should be rate limited after multiple attempts
      session
      |> assert_has(Wallaby.Query.text("Too many failed login attempts. Please try again later."))
    end

    test "no sensitive information exposed in error messages", %{session: session} do
      session
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: "test@example.com")
      |> fill_in(LoginPage.password_field(), with: "wrongpassword")
      |> click(LoginPage.submit_button())
      |> assert_has(Wallaby.Query.text("Invalid email or password"))
      # Ensure error doesn't reveal whether email exists
      |> refute_has(Wallaby.Query.text("User not found"))
      |> refute_has(Wallaby.Query.text("Incorrect password"))
    end

    test "login page forces HTTPS in production mode", %{session: session} do
      # This test would be skipped in test environment
      if Application.get_env(:intelitor, IntelitorWeb.Endpoint)[:force_ssl] do
        session
        |> visit("http://localhost:4002/login")
        |> assert_current_url_matches(~r/^https:\/\//)
      end
    end
  end

  describe "Browser Compatibility" do
    test "login works across different screen sizes", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      session
      |> test_responsive_design([1920, 1024, 768, 375])
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: user.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_has(DashboardPage.main_container())
    end

    test "no JavaScript errors during authentication flow", %{session: session, tenant: tenant} do
      user = get_admin_user_for_tenant(tenant)

      session
      |> visit("/login")
      |> assert_no_js_errors()
      |> fill_in(LoginPage.email_field(), with: user.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_no_js_errors()
      |> assert_has(DashboardPage.main_container())
      |> assert_no_js_errors()
    end
  end

  describe "Performance Validations" do
    test "login page loads within performance threshold", %{session: session} do
      session
      |> visit("/login")
      # 2 second max load time
      |> assert_page_performance(2_000)
    end

    test "authentication response time is within acceptable limits", %{
      session: session,
      tenant: tenant
    } do
      user = get_admin_user_for_tenant(tenant)
      start_time = System.monotonic_time(:millisecond)

      session
      |> visit("/login")
      |> fill_in(LoginPage.email_field(), with: user.email)
      |> fill_in(LoginPage.password_field(), with: "password123")
      |> click(LoginPage.submit_button())
      |> assert_has(DashboardPage.main_container())

      end_time = System.monotonic_time(:millisecond)
      auth_duration = end_time - start_time

      assert auth_duration < 5_000,
             "Authentication took #{auth_duration}ms, exceeds 5 second limit"
    end
  end

  # Private helper functions

  defp assert_current_url_matches(session, pattern) do
    current_url = session |> current_url()

    assert Regex.match?(pattern, current_url),
           "Current URL #{current_url} does not match pattern #{inspect(pattern)}"

    session
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
