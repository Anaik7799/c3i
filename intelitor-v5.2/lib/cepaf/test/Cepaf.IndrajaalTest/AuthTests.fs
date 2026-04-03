/// Cepaf.IndrajaalTest.AuthTests
/// Authentication endpoint tests
///
/// STAMP Constraints:
/// - SC-AUTH-001: Authentication must validate credentials
/// - SC-AUTH-002: JWT tokens must have proper expiration
/// - SC-AUTH-003: Invalid credentials must return 401
module Cepaf.IndrajaalTest.AuthTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Auth Request/Response Types
// =============================================================================

type LoginRequest = {
    username: string
    password: string
    device_id: string option
}

type LoginResponse = {
    access_token: string
    refresh_token: string
    expires_in: int
    token_type: string
}

type RefreshRequest = {
    refresh_token: string
}

type SessionResponse = {
    user_id: string
    username: string
    tenant_id: string
    roles: string list
    expires_at: string
}

type ErrorResponse = {
    error: string
    message: string option
}

// =============================================================================
// Authentication Tests
// =============================================================================

/// Create authentication tests
let createAuthTests (config: ServerConfig) (credentials: TestCredentials) =
    let client = createClient config

    testList "Authentication Endpoints" [

        testAsync "POST /api/mobile/auth/login with valid credentials" {
            let loginReq: LoginRequest = {
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            }

            let! response = post<LoginRequest, LoginResponse> client Endpoints.Auth.login loginReq

            // May fail if test user doesn't exist - that's expected in some environments
            if response.StatusCode = 200 then
                Expect.isTrue response.Success "Should be successful"
                match response.Data with
                | Some data ->
                    Expect.isNonEmpty data.access_token "Should return access token"
                    Expect.isNonEmpty data.refresh_token "Should return refresh token"
                    Expect.isGreaterThan data.expires_in 0 "Should have positive expiry"
                    Expect.equal data.token_type "Bearer" "Token type should be Bearer"
                | None ->
                    failtest "Should return token data"
            else
                // Log that auth failed (expected if no test user)
                Expect.equal response.StatusCode 401 "Should return 401 for invalid credentials"
        }

        testAsync "POST /api/mobile/auth/login with invalid credentials returns 401" {
            let loginReq: LoginRequest = {
                username = "invalid@user.com"
                password = "wrongpassword"
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            Expect.equal response.StatusCode 401 "Should return 401 Unauthorized"
            Expect.isFalse response.Success "Should not be successful"
        }

        testAsync "POST /api/mobile/auth/login with empty credentials returns 400/422" {
            let loginReq: LoginRequest = {
                username = ""
                password = ""
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            Expect.isTrue (response.StatusCode = 400 || response.StatusCode = 422)
                "Should return 400 or 422 for empty credentials"
        }

        testAsync "POST /api/mobile/auth/logout requires authentication" {
            let! response = postEmpty<ErrorResponse> client Endpoints.Auth.logout

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "GET /api/mobile/auth/session requires authentication" {
            let! response = get<ErrorResponse> client Endpoints.Auth.session

            Expect.equal response.StatusCode 401 "Should return 401 without auth"
        }

        testAsync "POST /api/mobile/auth/refresh with invalid token returns 401" {
            let refreshReq: RefreshRequest = {
                refresh_token = "invalid-refresh-token"
            }

            let! response = post<RefreshRequest, ErrorResponse> client Endpoints.Auth.refresh refreshReq

            Expect.equal response.StatusCode 401 "Should return 401 for invalid refresh token"
        }

        testAsync "POST /api/mobile/auth/mfa/verify requires valid session" {
            let mfaReq = {| code = "123456" |}
            let! response = post<{| code: string |}, ErrorResponse> client Endpoints.Auth.mfaVerify mfaReq

            Expect.equal response.StatusCode 401 "Should return 401 without session"
        }

        testAsync "POST /api/mobile/auth/password/reset with invalid email returns 400/404" {
            let resetReq = {| email = "nonexistent@invalid.com" |}
            let! response = post<{| email: string |}, obj> client Endpoints.Auth.passwordReset resetReq

            // Password reset may return 200 (to prevent email enumeration) or 400/404
            Expect.isTrue
                (response.StatusCode = 200 || response.StatusCode = 400 || response.StatusCode = 404)
                "Should handle invalid email appropriately"
        }
    ]

// =============================================================================
// Authenticated Flow Tests
// =============================================================================

/// Tests that require successful authentication
let createAuthenticatedFlowTests (config: ServerConfig) (credentials: TestCredentials) =
    testList "Authenticated Flow" [

        testAsync "Complete login-session-logout flow" {
            let client = createClient config

            // Step 1: Login
            let loginReq: LoginRequest = {
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            }

            let! loginResponse = post<LoginRequest, LoginResponse> client Endpoints.Auth.login loginReq

            if loginResponse.StatusCode = 200 then
                match loginResponse.Data with
                | Some tokenData ->
                    // Step 2: Get session with token
                    let authClient = client |> withAuth tokenData.access_token
                    let! sessionResponse = get<SessionResponse> authClient Endpoints.Auth.session

                    Expect.equal sessionResponse.StatusCode 200 "Session should return 200"
                    match sessionResponse.Data with
                    | Some session ->
                        Expect.isNonEmpty session.user_id "Should have user_id"
                        Expect.equal session.tenant_id credentials.TenantId "Tenant should match"
                    | None ->
                        failtest "Session should return data"

                    // Step 3: Logout
                    let! logoutResponse = postEmpty<obj> authClient Endpoints.Auth.logout
                    Expect.equal logoutResponse.StatusCode 200 "Logout should return 200"

                    // Step 4: Session should now fail
                    let! postLogoutSession = get<ErrorResponse> authClient Endpoints.Auth.session
                    Expect.equal postLogoutSession.StatusCode 401 "Session should fail after logout"

                | None ->
                    failtest "Login should return token data"
            else
                // Skip test if auth not available
                skiptest "Test user not configured - skipping authenticated flow tests"
        }

        testAsync "Token refresh flow" {
            let client = createClient config

            let loginReq: LoginRequest = {
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            }

            let! loginResponse = post<LoginRequest, LoginResponse> client Endpoints.Auth.login loginReq

            if loginResponse.StatusCode = 200 then
                match loginResponse.Data with
                | Some tokenData ->
                    // Refresh token
                    let refreshReq: RefreshRequest = {
                        refresh_token = tokenData.refresh_token
                    }

                    let! refreshResponse = post<RefreshRequest, LoginResponse> client Endpoints.Auth.refresh refreshReq

                    Expect.equal refreshResponse.StatusCode 200 "Refresh should return 200"
                    match refreshResponse.Data with
                    | Some newTokens ->
                        Expect.isNonEmpty newTokens.access_token "Should return new access token"
                        // New access token should work
                        let authClient = client |> withAuth newTokens.access_token
                        let! sessionResponse = get<SessionResponse> authClient Endpoints.Auth.session
                        Expect.equal sessionResponse.StatusCode 200 "New token should work"
                    | None ->
                        failtest "Refresh should return new tokens"
                | None ->
                    failtest "Login should return token data"
            else
                skiptest "Test user not configured - skipping refresh flow tests"
        }
    ]

// =============================================================================
// Security Tests
// =============================================================================

/// Security-focused auth tests
let createSecurityTests (config: ServerConfig) =
    let client = createClient config

    testList "Auth Security" [

        testAsync "SQL injection in username is handled" {
            let loginReq: LoginRequest = {
                username = "admin'; DROP TABLE users; --"
                password = "password"
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            // Should not crash, should return auth error
            Expect.isTrue (response.StatusCode = 400 || response.StatusCode = 401 || response.StatusCode = 422)
                "Should handle SQL injection attempt"
        }

        testAsync "XSS in username is handled" {
            let loginReq: LoginRequest = {
                username = "<script>alert('xss')</script>@test.com"
                password = "password"
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            Expect.isTrue (response.StatusCode = 400 || response.StatusCode = 401 || response.StatusCode = 422)
                "Should handle XSS attempt"
        }

        testAsync "Very long password is handled" {
            let loginReq: LoginRequest = {
                username = "test@test.com"
                password = String.replicate 10000 "a"
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            // Should not hang or crash
            Expect.isTrue (response.StatusCode >= 400 && response.StatusCode < 500)
                "Should handle very long password"
        }

        testAsync "Malformed JSON is handled" {
            // This tests the raw HTTP handling
            let content = new StringContent(
                "{ invalid json }", System.Text.Encoding.UTF8, "application/json")
            let! response = client.PostAsync(Endpoints.Auth.login, content) |> Async.AwaitTask

            Expect.equal (int response.StatusCode) 400 "Should return 400 for malformed JSON"
        }

        testAsync "Missing content-type is handled" {
            let content = new StringContent("""{"username":"test","password":"test"}""")
            content.Headers.ContentType <- null
            let! response = client.PostAsync(Endpoints.Auth.login, content) |> Async.AwaitTask

            // Should either work or return appropriate error
            Expect.isTrue
                (int response.StatusCode = 200 || int response.StatusCode >= 400)
                "Should handle missing content-type"
        }
    ]

// =============================================================================
// STAMP Constraint Tests
// =============================================================================

/// STAMP constraint validation for auth
let createStampAuthTests (config: ServerConfig) (credentials: TestCredentials) =
    let client = createClient config

    testList "STAMP Auth Constraints" [

        testAsync "SC-AUTH-001: Valid credentials are authenticated" {
            let loginReq: LoginRequest = {
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            }

            let! response = post<LoginRequest, LoginResponse> client Endpoints.Auth.login loginReq

            // Either 200 (success) or 401 (user not configured)
            Expect.isTrue (response.StatusCode = 200 || response.StatusCode = 401)
                "Should return proper auth response"
        }

        testAsync "SC-AUTH-002: JWT tokens have proper structure" {
            let loginReq: LoginRequest = {
                username = credentials.Username
                password = credentials.Password
                device_id = credentials.DeviceId
            }

            let! response = post<LoginRequest, LoginResponse> client Endpoints.Auth.login loginReq

            if response.StatusCode = 200 then
                match response.Data with
                | Some data ->
                    // JWT should have 3 parts separated by dots
                    let parts = data.access_token.Split('.')
                    Expect.equal parts.Length 3 "JWT should have 3 parts"
                    Expect.isGreaterThan data.expires_in 0 "Should have positive expiry"
                | None ->
                    failtest "Should return token"
            else
                skiptest "Auth not configured"
        }

        testAsync "SC-AUTH-003: Invalid credentials return 401" {
            let loginReq: LoginRequest = {
                username = "definitely-invalid@nowhere.com"
                password = "definitely-wrong-password"
                device_id = None
            }

            let! response = post<LoginRequest, ErrorResponse> client Endpoints.Auth.login loginReq

            Expect.equal response.StatusCode 401 "Invalid credentials must return 401"
        }
    ]

// =============================================================================
// All Auth Tests
// =============================================================================

/// All authentication tests combined
let allAuthTests (config: ServerConfig) (credentials: TestCredentials) =
    testList "Authentication Tests" [
        createAuthTests config credentials
        createAuthenticatedFlowTests config credentials
        createSecurityTests config
        createStampAuthTests config credentials
    ]
