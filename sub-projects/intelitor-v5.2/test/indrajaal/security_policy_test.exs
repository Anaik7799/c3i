defmodule SecurityPolicyTest do
  @moduledoc """
  TDG comprehensive test suite for SecurityPolicy.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation per Omega_4
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck (forall) + ExUnitProperties (check all)

  ## STAMP Safety Integration
  - SC-GDE-001: Guardian validation required for all security decisions
  - SC-SEC-044: Sobelow security scan compliance
  - SC-NEURO-001: Simplex principle — AI output passes Guardian validation

  ## Constitutional Verification
  - Psi_0 Existence: Security enforcement continues under all credential shapes
  - Psi_3 Verification: Authorization decisions are deterministically verifiable
  - Psi_4 Human Alignment: RBAC hierarchy enforces Founder's privilege boundary

  ## Founder's Directive Alignment
  - Omega_0.1: Resource acquisition gated by role-sufficient checks
  - Omega_0.2: Lineage protected by admin/super_admin gates on destructive ops

  ## TPS 5-Level RCA Context
  - L1 Symptom: Unauthorized access or spurious denial of legitimate requests
  - L5 Root Cause: Incorrect role comparison index or missing credential dispatch clause

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-20 | Claude Sonnet 4.6 | Initial TDG test suite (Sprint 54) |
  """

  use ExUnit.Case, async: false
  use Mimic

  # EP-GEN-014: Exclude PropCheck's check/2 to avoid conflict with ExUnitProperties
  use PropCheck
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014, SC-PROP-023)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif
  @moduletag :security
  @moduletag :sprint_54

  # ---------------------------------------------------------------------------
  # Setup — Mimic copies for Authentication dependency isolation
  # ---------------------------------------------------------------------------

  setup :verify_on_exit!

  setup do
    # Mimic.copy/1 allows stubbing of a concrete (non-behaviour) module
    Mimic.copy(Indrajaal.Accounts.Authentication)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp user(role) when is_atom(role),
    do: %{id: "user-#{role}", email: "#{role}@example.com", role: role}

  defp capture_telemetry_events(event_prefix, fun) do
    test_pid = self()
    ref = make_ref()
    handler_id = "security-policy-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:security_policy | event_prefix] ++ [:attempt],
        [:security_policy | event_prefix] ++ [:success],
        [:security_policy | event_prefix] ++ [:failure],
        [:security_policy | event_prefix] ++ [:granted],
        [:security_policy | event_prefix] ++ [:denied],
        [:security_policy | event_prefix] ++ [:ok],
        [:security_policy | event_prefix] ++ [:violation],
        [:security_policy | event_prefix] ++ [:start],
        [:security_policy | event_prefix] ++ [:allowed],
        [:security_policy | event_prefix] ++ [:check],
        [:security_policy | event_prefix] ++ [:created],
        [:security_policy | event_prefix] ++ [:applied]
      ],
      fn event, measurements, metadata, _cfg ->
        send(test_pid, {ref, event, measurements, metadata})
      end,
      nil
    )

    result = fun.()

    # Drain all telemetry messages sent during the call
    events =
      Stream.repeatedly(fn ->
        receive do
          {^ref, event, meas, meta} -> {event, meas, meta}
        after
          50 -> nil
        end
      end)
      |> Stream.take_while(&(&1 != nil))
      |> Enum.to_list()

    :telemetry.detach(handler_id)
    {result, events}
  end

  # ---------------------------------------------------------------------------
  # 1. authenticate/1 — passthrough (no external dep)
  # ---------------------------------------------------------------------------

  describe "authenticate/1 — passthrough path" do
    test "returns {:ok, user} when pre-authenticated user map is provided" do
      pre_auth_user = %{id: "u-42", email: "alice@example.com", role: :admin}
      assert {:ok, ^pre_auth_user} = SecurityPolicy.authenticate(%{user: pre_auth_user})
    end

    test "passthrough works with minimal user map" do
      user = %{role: :viewer}
      assert {:ok, ^user} = SecurityPolicy.authenticate(%{user: user})
    end

    test "emits success telemetry on passthrough" do
      pre_auth_user = %{id: "u-1", role: :operator}

      {result, events} =
        capture_telemetry_events([:authenticate], fn ->
          SecurityPolicy.authenticate(%{user: pre_auth_user})
        end)

      assert {:ok, _} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :success] and
                 meta[:method] == :passthrough
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. authenticate/1 — unsupported credentials
  # ---------------------------------------------------------------------------

  describe "authenticate/1 — unsupported credentials" do
    test "returns {:error, :unsupported_credentials} for empty map" do
      assert {:error, :unsupported_credentials} = SecurityPolicy.authenticate(%{})
    end

    test "returns {:error, :unsupported_credentials} for unrecognised keys" do
      assert {:error, :unsupported_credentials} =
               SecurityPolicy.authenticate(%{api_key: "abcdef", secret: "xyz"})
    end

    test "emits failure telemetry for unsupported credentials" do
      {result, events} =
        capture_telemetry_events([:authenticate], fn ->
          SecurityPolicy.authenticate(%{unknown: "cred"})
        end)

      assert {:error, :unsupported_credentials} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :failure] and
                 meta[:reason] == :unsupported_credentials
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. authenticate/1 — password path (stubs Authentication)
  # ---------------------------------------------------------------------------

  describe "authenticate/1 — password path" do
    test "returns {:ok, user} when Authentication succeeds with user-wrapped response" do
      expected_user = %{id: "u-pw", email: "bob@example.com", role: :operator}

      stub(Indrajaal.Accounts.Authentication, :authenticate, fn _email, _password ->
        {:ok, %{user: expected_user}}
      end)

      assert {:ok, ^expected_user} =
               SecurityPolicy.authenticate(%{email: "bob@example.com", password: "S3cr3t!"})
    end

    test "returns {:ok, auth_response} when Authentication returns bare map" do
      bare_map = %{id: "u-bare", role: :viewer, email: "bare@example.com"}

      stub(Indrajaal.Accounts.Authentication, :authenticate, fn _email, _password ->
        {:ok, bare_map}
      end)

      assert {:ok, ^bare_map} =
               SecurityPolicy.authenticate(%{email: "bare@example.com", password: "pw"})
    end

    test "returns {:error, reason} when Authentication fails" do
      stub(Indrajaal.Accounts.Authentication, :authenticate, fn _email, _password ->
        {:error, :invalid_credentials}
      end)

      assert {:error, :invalid_credentials} =
               SecurityPolicy.authenticate(%{email: "bad@example.com", password: "wrong"})
    end

    test "emits attempt and success telemetry on password auth success" do
      stub(Indrajaal.Accounts.Authentication, :authenticate, fn _email, _password ->
        {:ok, %{user: %{id: "u-tel", role: :operator}}}
      end)

      {_result, events} =
        capture_telemetry_events([:authenticate], fn ->
          SecurityPolicy.authenticate(%{email: "tel@example.com", password: "pw"})
        end)

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :attempt] and
                 meta[:method] == :password
             end)

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :success] and
                 meta[:method] == :password
             end)
    end

    test "emits failure telemetry on password auth failure" do
      stub(Indrajaal.Accounts.Authentication, :authenticate, fn _email, _password ->
        {:error, :account_locked}
      end)

      {_result, events} =
        capture_telemetry_events([:authenticate], fn ->
          SecurityPolicy.authenticate(%{email: "locked@example.com", password: "pw"})
        end)

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :failure] and
                 meta[:method] == :password
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. authenticate/1 — token path (stubs Authentication)
  # ---------------------------------------------------------------------------

  describe "authenticate/1 — token path" do
    test "returns {:ok, user} when token is valid" do
      token_user = %{id: "u-tok", email: "tok@example.com", role: :manager}

      stub(Indrajaal.Accounts.Authentication, :verify_token, fn _token ->
        {:ok, token_user}
      end)

      assert {:ok, ^token_user} = SecurityPolicy.authenticate(%{token: "valid.jwt.token"})
    end

    test "returns {:error, reason} when token is invalid" do
      stub(Indrajaal.Accounts.Authentication, :verify_token, fn _token ->
        {:error, :token_expired}
      end)

      assert {:error, :token_expired} =
               SecurityPolicy.authenticate(%{token: "expired.jwt.token"})
    end

    test "emits failure telemetry when token invalid" do
      stub(Indrajaal.Accounts.Authentication, :verify_token, fn _token ->
        {:error, :invalid_signature}
      end)

      {_result, events} =
        capture_telemetry_events([:authenticate], fn ->
          SecurityPolicy.authenticate(%{token: "bad.token"})
        end)

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authenticate, :failure] and
                 meta[:method] == :token
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. authorize/2 — nil user
  # ---------------------------------------------------------------------------

  describe "authorize/2 — nil user" do
    test "always returns {:error, :unauthorized} for nil user regardless of action" do
      for action <- [:read, :create, :delete, :admin, :super_admin] do
        assert {:error, :unauthorized} = SecurityPolicy.authorize(nil, action)
      end
    end

    test "emits denied telemetry with :no_user reason" do
      {result, events} =
        capture_telemetry_events([:authorize], fn ->
          SecurityPolicy.authorize(nil, :read)
        end)

      assert {:error, :unauthorized} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authorize, :denied] and
                 meta[:reason] == :no_user
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. authorize/2 — RBAC hierarchy
  # ---------------------------------------------------------------------------

  describe "authorize/2 — RBAC role hierarchy" do
    test "viewer can perform :read actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:viewer), :read)
    end

    test "viewer can perform :list actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:viewer), :list)
    end

    test "viewer cannot perform :create actions" do
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:viewer), :create)
    end

    test "viewer cannot perform :delete actions" do
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:viewer), :delete)
    end

    test "operator can perform :create actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:operator), :create)
    end

    test "operator can perform :read actions (inherited)" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:operator), :read)
    end

    test "operator cannot perform :delete actions" do
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:operator), :delete)
    end

    test "manager can perform :delete actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:manager), :delete)
    end

    test "manager cannot perform :admin actions" do
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:manager), :admin)
    end

    test "admin can perform :admin actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:admin), :admin)
    end

    test "admin can perform :configure actions" do
      assert {:ok, :authorized} = SecurityPolicy.authorize(user(:admin), :configure)
    end

    test "admin cannot perform :super_admin actions" do
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:admin), :super_admin)
    end

    test "super_admin can perform all actions" do
      for action <- [:read, :create, :delete, :admin, :super_admin, :system] do
        assert {:ok, :authorized} = SecurityPolicy.authorize(user(:super_admin), action)
      end
    end

    test "guest cannot perform any write or destructive actions" do
      for action <- [:create, :delete, :admin, :super_admin] do
        assert {:error, :unauthorized} = SecurityPolicy.authorize(user(:guest), action)
      end
    end

    test "unknown actions fall back to :operator minimum role — viewer denied" do
      assert {:error, :unauthorized} =
               SecurityPolicy.authorize(user(:viewer), :some_unknown_action)
    end

    test "unknown actions fall back to :operator minimum role — operator granted" do
      assert {:ok, :authorized} =
               SecurityPolicy.authorize(user(:operator), :some_unknown_action)
    end

    test "role as string is normalised correctly" do
      user_with_string_role = %{id: "u-str", role: "admin"}
      assert {:ok, :authorized} = SecurityPolicy.authorize(user_with_string_role, :admin)
    end

    test "invalid role string defaults to :guest" do
      user_bad_role = %{id: "u-bad", role: "unicorn_role_xyz"}
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user_bad_role, :create)
    end

    test "missing role key defaults to :guest" do
      user_no_role = %{id: "u-norole", email: "no@role.com"}
      assert {:error, :unauthorized} = SecurityPolicy.authorize(user_no_role, :create)
    end

    test "emits granted telemetry with action and role metadata" do
      {result, events} =
        capture_telemetry_events([:authorize], fn ->
          SecurityPolicy.authorize(user(:admin), :configure)
        end)

      assert {:ok, :authorized} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authorize, :granted] and
                 meta[:action] == :configure
             end)
    end

    test "emits denied telemetry with action and role metadata" do
      {result, events} =
        capture_telemetry_events([:authorize], fn ->
          SecurityPolicy.authorize(user(:viewer), :delete)
        end)

      assert {:error, :unauthorized} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :authorize, :denied] and
                 meta[:action] == :delete
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. validate_access/2 — combined auth+authz
  # ---------------------------------------------------------------------------

  describe "validate_access/2" do
    test "returns true when passthrough user has sufficient role for action" do
      credentials = %{user: user(:admin)}
      assert true == SecurityPolicy.validate_access(credentials, :configure)
    end

    test "returns false when passthrough user has insufficient role for action" do
      credentials = %{user: user(:viewer)}
      assert false == SecurityPolicy.validate_access(credentials, :delete)
    end

    test "returns false when authentication fails (bad token)" do
      stub(Indrajaal.Accounts.Authentication, :verify_token, fn _t ->
        {:error, :token_expired}
      end)

      assert false == SecurityPolicy.validate_access(%{token: "bad"}, :read)
    end

    test "returns false for non-map credentials" do
      assert false == SecurityPolicy.validate_access("not_a_map", :read)
    end

    test "resource as atom is used directly as action" do
      credentials = %{user: user(:operator)}
      assert true == SecurityPolicy.validate_access(credentials, :create)
    end

    test "resource as map uses :action key" do
      credentials = %{user: user(:manager)}
      assert true == SecurityPolicy.validate_access(credentials, %{action: :delete})
    end

    test "resource as map missing :action key defaults to :read" do
      credentials = %{user: user(:viewer)}
      assert true == SecurityPolicy.validate_access(credentials, %{name: "SomeResource"})
    end

    test "resource as unrecognised type defaults to :read action" do
      credentials = %{user: user(:viewer)}
      assert true == SecurityPolicy.validate_access(credentials, 42)
    end

    test "nil resource defaults to :read — viewer is granted" do
      credentials = %{user: user(:viewer)}
      assert true == SecurityPolicy.validate_access(credentials, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. enforce_policies/3
  # ---------------------------------------------------------------------------

  describe "enforce_policies/3" do
    test "returns {:ok, :policies_enforced} when policy list is empty" do
      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-1", %{query: "test"}, [])
    end

    test "returns {:ok, :policies_enforced} for allow_all policy" do
      policies = [%{type: :allow_all}]

      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-1", %{}, policies)
    end

    test "returns {:error, violations} for deny_all policy" do
      policies = [%{type: :deny_all}]

      assert {:error, violations} =
               SecurityPolicy.enforce_policies("fed-2", %{}, policies)

      assert :denied_by_policy in violations
    end

    test "rate_limit policy does not produce violations (placeholder)" do
      policies = [%{type: :rate_limit, config: %{max: 100}}]

      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-3", %{}, policies)
    end

    test "context map with authenticated user and public operation — no violations" do
      context = %{user: user(:viewer), tenant_id: "tenant-1"}
      operation = %{name: "getAlarms", public: true}

      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-4", operation, context)
    end

    test "context map with no user and non-public operation — unauthenticated violation" do
      context = %{tenant_id: "tenant-1"}
      operation = %{name: "createAlarm", public: false}

      assert {:error, violations} =
               SecurityPolicy.enforce_policies("fed-5", operation, context)

      assert :unauthenticated in violations
    end

    test "context map with no user and public operation — no violation" do
      context = %{}
      operation = %{public: true}

      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-6", operation, context)
    end

    test "unknown policy type produces no violations (defensive default)" do
      policies = [%{type: :some_future_policy, config: %{}}]

      assert {:ok, :policies_enforced} =
               SecurityPolicy.enforce_policies("fed-7", %{}, policies)
    end

    test "multiple policies — deny_all overrides allow_all" do
      policies = [%{type: :allow_all}, %{type: :deny_all}]

      assert {:error, violations} =
               SecurityPolicy.enforce_policies("fed-8", %{}, policies)

      assert :denied_by_policy in violations
    end

    test "emits start and ok telemetry on success" do
      {result, events} =
        capture_telemetry_events([:enforce_policies], fn ->
          SecurityPolicy.enforce_policies("fed-tel", %{}, [])
        end)

      assert {:ok, :policies_enforced} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :enforce_policies, :start] and
                 meta[:context] == "fed-tel"
             end)

      assert Enum.any?(events, fn {event, _meas, _meta} ->
               event == [:security_policy, :enforce_policies, :ok]
             end)
    end

    test "emits violation telemetry with violation count" do
      {_result, events} =
        capture_telemetry_events([:enforce_policies], fn ->
          SecurityPolicy.enforce_policies("fed-vio", %{}, [%{type: :deny_all}])
        end)

      assert Enum.any?(events, fn {event, meas, _meta} ->
               event == [:security_policy, :enforce_policies, :violation] and
                 meas[:count] >= 1
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. enforce_subscription_security/3
  # ---------------------------------------------------------------------------

  describe "enforce_subscription_security/3" do
    test "denies when user_info is nil and context has no user" do
      assert {:error, :subscription_denied} =
               SecurityPolicy.enforce_subscription_security("sub-1", nil, %{})
    end

    test "allows viewer on non-system topic via direct user" do
      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-2",
                 user(:viewer),
                 "alarms:all"
               )
    end

    test "allows viewer on non-system topic via context" do
      context = %{user: user(:viewer), subscription_topic: "alarms:zone-1"}

      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security("sub-3", nil, context)
    end

    test "denies viewer on system: topic" do
      assert {:error, :subscription_denied} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-4",
                 user(:viewer),
                 "system:control"
               )
    end

    test "allows admin on system: topic" do
      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-5",
                 user(:admin),
                 "system:control"
               )
    end

    test "allows super_admin on system: topic" do
      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-6",
                 user(:super_admin),
                 "system:alerts"
               )
    end

    test "resolves topic from context :subscription_topic key" do
      context = %{user: user(:admin), subscription_topic: "system:logs"}

      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security("sub-7", nil, context)
    end

    test "resolves topic from context :topic key" do
      context = %{user: user(:viewer), topic: "devices:online"}

      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security("sub-8", nil, context)
    end

    test "nil topic resolves — viewer can subscribe (non-system path)" do
      # nil topic is not a system: topic, so viewer should be allowed
      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security("sub-9", user(:viewer), nil)
    end

    test "guest is denied on system: topic" do
      assert {:error, :subscription_denied} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-10",
                 user(:guest),
                 "system:health"
               )
    end

    test "direct user_info takes priority over context user" do
      # user_info is admin; context user would be viewer — admin should win
      context = %{user: user(:viewer)}

      assert {:ok, :allowed} =
               SecurityPolicy.enforce_subscription_security(
                 "sub-11",
                 user(:admin),
                 context
               )
    end

    test "emits allowed telemetry on success" do
      {result, events} =
        capture_telemetry_events([:subscription], fn ->
          SecurityPolicy.enforce_subscription_security("sub-tel", user(:viewer), "events:all")
        end)

      assert {:ok, :allowed} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :subscription, :allowed] and
                 meta[:subscription_id] == "sub-tel"
             end)
    end

    test "emits denied telemetry on failure" do
      {result, events} =
        capture_telemetry_events([:subscription], fn ->
          SecurityPolicy.enforce_subscription_security("sub-deny", nil, %{})
        end)

      assert {:error, :subscription_denied} = result

      assert Enum.any?(events, fn {event, _meas, _meta} ->
               event == [:security_policy, :subscription, :denied]
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. create_policies/1
  # ---------------------------------------------------------------------------

  describe "create_policies/1" do
    test "stores and returns policy map when all required fields present" do
      config = %{
        federation_id: "fed-create-1",
        version: "v1.0.0",
        config: %{rules: []}
      }

      assert {:ok, policies} = SecurityPolicy.create_policies(config)
      assert policies.federation_id == "fed-create-1"
      assert policies.version == "v1.0.0"
      assert is_list(policies.rules)
      assert %DateTime{} = policies.created_at
    end

    test "accepts :federationid (snake_case variant) as federation identifier" do
      config = %{
        federationid: "fed-create-alt",
        version: "v2.0.0",
        config: %{}
      }

      assert {:ok, policies} = SecurityPolicy.create_policies(config)
      assert policies.federation_id == "fed-create-alt"
    end

    test "returns {:error, reason} when federation_id is missing" do
      config = %{version: "v1.0.0", config: %{}}
      assert {:error, msg} = SecurityPolicy.create_policies(config)
      assert is_binary(msg)
      assert msg =~ "federation_id"
    end

    test "returns {:error, reason} when version is missing" do
      config = %{federation_id: "fed-x", config: %{}}
      assert {:error, msg} = SecurityPolicy.create_policies(config)
      assert is_binary(msg)
      assert msg =~ "version"
    end

    test "returns {:error, reason} when non-map is passed" do
      assert {:error, msg} = SecurityPolicy.create_policies("not_a_map")
      assert msg =~ "map"
    end

    test "normalises list config into rules list" do
      rules = [%{action: :read, resource: "alarms"}]

      config = %{
        federation_id: "fed-list",
        version: "v1.0.0",
        config: rules
      }

      assert {:ok, policies} = SecurityPolicy.create_policies(config)
      assert policies.rules == rules
    end

    test "normalises map config with :rules key" do
      rules = [%{type: :allow_all}]

      config = %{
        federation_id: "fed-map",
        version: "v1.0.0",
        config: %{rules: rules}
      }

      assert {:ok, policies} = SecurityPolicy.create_policies(config)
      assert policies.rules == rules
    end

    test "emits :created telemetry" do
      {result, events} =
        capture_telemetry_events([:policies], fn ->
          SecurityPolicy.create_policies(%{
            federation_id: "fed-tel-create",
            version: "v0.1",
            config: %{}
          })
        end)

      assert {:ok, _} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :policies, :created] and
                 meta[:federation_id] == "fed-tel-create"
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 11. apply_policies/2
  # ---------------------------------------------------------------------------

  describe "apply_policies/2" do
    test "returns {:ok, policies} for a previously created policy set" do
      fed_id = "fed-apply-#{System.unique_integer([:positive])}"
      version = "v1.0"

      {:ok, created} =
        SecurityPolicy.create_policies(%{
          federation_id: fed_id,
          version: version,
          config: %{rules: [:allow]}
        })

      assert {:ok, applied} = SecurityPolicy.apply_policies(fed_id, version)
      assert applied.federation_id == created.federation_id
      assert applied.version == created.version
    end

    test "returns {:ok, empty_policy} when no policies are stored for federation" do
      assert {:ok, fallback} = SecurityPolicy.apply_policies("unknown-fed", "v99")
      assert fallback.federation_id == "unknown-fed"
      assert fallback.version == "v99"
      assert fallback.rules == []
    end

    test "returns {:error, reason} when non-string federation_id passed" do
      assert {:error, msg} = SecurityPolicy.apply_policies(123, "v1")
      assert is_binary(msg)
    end

    test "returns {:error, reason} when non-string version passed" do
      assert {:error, msg} = SecurityPolicy.apply_policies("fed-x", :v1)
      assert is_binary(msg)
    end

    test "emits :applied telemetry when policies found" do
      fed_id = "fed-apply-tel-#{System.unique_integer([:positive])}"
      version = "v-tel"

      SecurityPolicy.create_policies(%{
        federation_id: fed_id,
        version: version,
        config: %{}
      })

      {result, events} =
        capture_telemetry_events([:policies], fn ->
          SecurityPolicy.apply_policies(fed_id, version)
        end)

      assert {:ok, _} = result

      assert Enum.any?(events, fn {event, _meas, meta} ->
               event == [:security_policy, :policies, :applied] and
                 meta[:federation_id] == fed_id
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Property tests — RBAC monotonicity (PropCheck forall)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants — RBAC properties" do
    # Role hierarchy: [:guest, :viewer, :operator, :manager, :admin, :super_admin]
    @roles [:guest, :viewer, :operator, :manager, :admin, :super_admin]
    @read_actions [:read, :list, :show, :get]

    property "super_admin is authorised for every defined action" do
      forall action <-
               PC.elements([:read, :list, :create, :update, :delete, :admin, :super_admin]) do
        {:ok, :authorized} == SecurityPolicy.authorize(user(:super_admin), action)
      end
    end

    property "guest is never authorised for write/destructive actions" do
      write_actions = [:create, :write, :update, :delete, :destroy, :admin, :super_admin]

      forall action <- PC.elements(write_actions) do
        {:error, :unauthorized} == SecurityPolicy.authorize(user(:guest), action)
      end
    end

    property "read actions are always authorised for any role >= viewer" do
      read_roles = [:viewer, :operator, :manager, :admin, :super_admin]

      forall {role, action} <- {PC.elements(read_roles), PC.elements(@read_actions)} do
        {:ok, :authorized} == SecurityPolicy.authorize(user(role), action)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 13. Property tests — validate_access idempotency (ExUnitProperties check all)
  # ---------------------------------------------------------------------------

  describe "validate_access/2 — StreamData property tests" do
    test "validate_access always returns boolean" do
      ExUnitProperties.check all(
                               role <-
                                 SD.member_of([
                                   :guest,
                                   :viewer,
                                   :operator,
                                   :manager,
                                   :admin,
                                   :super_admin
                                 ]),
                               action <-
                                 SD.member_of([:read, :create, :delete, :admin, :super_admin]),
                               max_runs: 100
                             ) do
        credentials = %{user: user(role)}
        result = SecurityPolicy.validate_access(credentials, action)
        assert is_boolean(result)
      end
    end

    test "validate_access returns false for non-map credentials regardless of action" do
      ExUnitProperties.check all(
                               action <- SD.member_of([:read, :create, :delete]),
                               non_map <- SD.one_of([SD.integer(), SD.binary(), SD.boolean()]),
                               max_runs: 50
                             ) do
        assert false == SecurityPolicy.validate_access(non_map, action)
      end
    end
  end
end
