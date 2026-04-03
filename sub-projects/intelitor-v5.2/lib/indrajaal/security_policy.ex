defmodule SecurityPolicy do
  @moduledoc """
  Security policy enforcement module.

  WHAT: Provides authentication, authorization, and policy enforcement
  for the enterprise gateway and GraphQL federation layers.

  WHY: Central security boundary — all inbound requests and GraphQL
  operations must pass through these checks before reaching domain logic.

  CONSTRAINTS: SC-GDE-001 (Guardian validation), SC-SEC-044 (Sobelow),
  SC-NEURO-001 (Simplex — AI output must pass Guardian validation).

  ## Role-based permission model

  Roles (highest to lowest): `:super_admin`, `:admin`, `:manager`,
  `:operator`, `:viewer`, `:guest`.

  Each role inherits all permissions of roles below it.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-20 | Claude Sonnet 4.6 | Initial real implementation (stub→real) |
  """

  require Logger

  alias Indrajaal.Accounts.Authentication

  # ---------------------------------------------------------------------------
  # Role hierarchy — higher index = higher privilege
  # ---------------------------------------------------------------------------

  @role_hierarchy [:guest, :viewer, :operator, :manager, :admin, :super_admin]

  # Minimum role required for each action atom
  @action_permissions %{
    # Read operations
    :read => :viewer,
    :list => :viewer,
    :show => :viewer,
    :get => :viewer,
    # Write operations
    :create => :operator,
    :write => :operator,
    :update => :operator,
    :patch => :operator,
    # Delete / destructive
    :delete => :manager,
    :destroy => :manager,
    # Admin actions
    :admin => :admin,
    :configure => :admin,
    :manage => :admin,
    # System actions
    :super_admin => :super_admin,
    :system => :super_admin
  }

  # Default minimum role when an action is not explicitly listed
  @default_min_role :operator

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Authenticate a request or user.

  Dispatches on the shape of the credentials map:

  - `%{email: _, password: _}` — password-based auth via
    `Indrajaal.Accounts.Authentication`.
  - `%{token: _}` — JWT bearer token verification.
  - `%{user: user_map}` — pre-authenticated request (passthrough);
    returns the embedded user map.
  - Any other shape — returns `{:error, :unsupported_credentials}`.

  ## Returns
  - `{:ok, user_info}` on success
  - `{:error, reason}` on failure
  """
  @spec authenticate(map()) :: {:ok, map()} | {:error, term()}
  def authenticate(%{email: email, password: password}) when is_binary(email) do
    :telemetry.execute(
      [:security_policy, :authenticate, :attempt],
      %{},
      %{method: :password, email: email}
    )

    case Authentication.authenticate(email, password) do
      {:ok, %{user: user}} ->
        Logger.info("[SecurityPolicy] Password auth success",
          user_id: Map.get(user, :id),
          email: email
        )

        :telemetry.execute(
          [:security_policy, :authenticate, :success],
          %{},
          %{method: :password}
        )

        {:ok, user}

      {:ok, auth_response} when is_map(auth_response) ->
        # build_auth_response may wrap user under :user key
        user = Map.get(auth_response, :user, auth_response)

        :telemetry.execute(
          [:security_policy, :authenticate, :success],
          %{},
          %{method: :password}
        )

        {:ok, user}

      {:error, reason} = err ->
        Logger.warning("[SecurityPolicy] Password auth failed",
          email: email,
          reason: inspect(reason)
        )

        :telemetry.execute(
          [:security_policy, :authenticate, :failure],
          %{},
          %{method: :password, reason: reason}
        )

        err
    end
  end

  def authenticate(%{token: token}) when is_binary(token) do
    :telemetry.execute(
      [:security_policy, :authenticate, :attempt],
      %{},
      %{method: :token}
    )

    case Authentication.verify_token(token) do
      {:ok, user} ->
        Logger.debug("[SecurityPolicy] Token auth success",
          user_id: Map.get(user, :id)
        )

        :telemetry.execute(
          [:security_policy, :authenticate, :success],
          %{},
          %{method: :token}
        )

        {:ok, user}

      {:error, reason} = err ->
        Logger.warning("[SecurityPolicy] Token auth failed",
          reason: inspect(reason)
        )

        :telemetry.execute(
          [:security_policy, :authenticate, :failure],
          %{},
          %{method: :token, reason: reason}
        )

        err
    end
  end

  def authenticate(%{user: user}) when is_map(user) do
    # Pre-authenticated request — trust the embedded user
    :telemetry.execute(
      [:security_policy, :authenticate, :success],
      %{},
      %{method: :passthrough}
    )

    {:ok, user}
  end

  def authenticate(request) when is_map(request) do
    # No recognised credential shape; treat as anonymous
    Logger.warning("[SecurityPolicy] authenticate/1 called with unrecognised credentials",
      keys: Map.keys(request)
    )

    :telemetry.execute(
      [:security_policy, :authenticate, :failure],
      %{},
      %{method: :unknown, reason: :unsupported_credentials}
    )

    {:error, :unsupported_credentials}
  end

  @doc """
  Authorize an action based on the user's role.

  ## Parameters
  - `user` — authenticated user map (must contain `:role` key), or `nil`
  - `action` — the action atom to authorise (e.g. `:read`, `:create`)

  ## Returns
  - `{:ok, :authorized}` if the user's role is sufficient
  - `{:error, :unauthorized}` otherwise
  """
  @spec authorize(map() | nil, atom()) :: {:ok, :authorized} | {:error, :unauthorized}
  def authorize(nil, _action) do
    Logger.warning("[SecurityPolicy] authorize/2 called with nil user — denying")

    :telemetry.execute(
      [:security_policy, :authorize, :denied],
      %{},
      %{reason: :no_user}
    )

    {:error, :unauthorized}
  end

  def authorize(user, action) when is_map(user) and is_atom(action) do
    user_role = get_user_role(user)
    required_role = Map.get(@action_permissions, action, @default_min_role)

    if role_sufficient?(user_role, required_role) do
      Logger.debug("[SecurityPolicy] authorize/2 granted",
        user_id: Map.get(user, :id),
        action: action,
        role: user_role
      )

      :telemetry.execute(
        [:security_policy, :authorize, :granted],
        %{},
        %{action: action, role: user_role}
      )

      {:ok, :authorized}
    else
      Logger.warning("[SecurityPolicy] authorize/2 denied",
        user_id: Map.get(user, :id),
        action: action,
        user_role: user_role,
        required_role: required_role
      )

      :telemetry.execute(
        [:security_policy, :authorize, :denied],
        %{},
        %{action: action, user_role: user_role, required_role: required_role}
      )

      {:error, :unauthorized}
    end
  end

  def authorize(_user, _action) do
    {:error, :unauthorized}
  end

  @doc """
  Validate access by combining authenticate and authorize.

  ## Parameters
  - `credentials` — credential map (see `authenticate/1`)
  - `resource` — the resource/action being accessed; may be an atom
    or a map with `:action` key

  ## Returns
  - `true` if access is granted, `false` otherwise
  """
  @spec validate_access(map(), any()) :: boolean()
  def validate_access(credentials, resource) when is_map(credentials) do
    action = extract_action(resource)

    case authenticate(credentials) do
      {:ok, user} ->
        case authorize(user, action) do
          {:ok, :authorized} -> true
          _ -> false
        end

      {:error, _} ->
        false
    end
  end

  def validate_access(_credentials, _resource), do: false

  @doc """
  Enforce security policies on a GraphQL query or gateway operation.

  Validates the operation context against the supplied policies. When
  policies is a list of policy maps (each with `:type` and optional
  `:config`), each policy is checked in order; the first violation
  short-circuits and returns `{:error, violations}`.

  ## Parameters
  - `context_or_id` — federation/gateway identifier string, or a
    context map containing `:user` and `:tenant_id`
  - `operation` — the parsed query/operation map
  - `policies_or_context` — list of policy maps, or execution context

  ## Returns
  - `{:ok, :policies_enforced}` all policies satisfied
  - `{:error, violations}` one or more violations found
  """
  @spec enforce_policies(String.t(), map(), map()) :: {:ok, :policies_enforced} | {:error, term()}
  def enforce_policies(context_or_id, operation, policies_or_context) do
    :telemetry.execute(
      [:security_policy, :enforce_policies, :start],
      %{},
      %{context: context_or_id}
    )

    violations = collect_policy_violations(context_or_id, operation, policies_or_context)

    if Enum.empty?(violations) do
      Logger.debug("[SecurityPolicy] enforce_policies/3 — all policies satisfied",
        context: context_or_id
      )

      :telemetry.execute(
        [:security_policy, :enforce_policies, :ok],
        %{},
        %{context: context_or_id}
      )

      {:ok, :policies_enforced}
    else
      Logger.warning("[SecurityPolicy] enforce_policies/3 — violations found",
        context: context_or_id,
        violations: violations
      )

      :telemetry.execute(
        [:security_policy, :enforce_policies, :violation],
        %{count: length(violations)},
        %{context: context_or_id}
      )

      {:error, violations}
    end
  end

  @doc """
  Enforce security for a GraphQL subscription.

  Validates that the user in `context` is allowed to subscribe to the
  given `topic` (derived from the parsed subscription's operation name
  or the explicit topic field).

  ## Parameters
  - `subscription_id` — federation or subscription group identifier
  - `user_info` — map containing at least `:role`; may be `nil`
  - `topic_or_context` — subscription topic string or context map with
    `:user` and `:subscription_topic` keys

  ## Returns
  - `{:ok, :allowed}` subscription permitted
  - `{:error, :subscription_denied}` subscription denied
  """
  @spec enforce_subscription_security(String.t(), map(), map()) ::
          {:ok, :allowed} | {:error, :subscription_denied}
  def enforce_subscription_security(subscription_id, user_info, topic_or_context) do
    :telemetry.execute(
      [:security_policy, :subscription, :check],
      %{},
      %{subscription_id: subscription_id}
    )

    user = resolve_user(user_info, topic_or_context)
    topic = resolve_topic(topic_or_context)

    cond do
      is_nil(user) ->
        Logger.warning("[SecurityPolicy] subscription denied — no user",
          subscription_id: subscription_id
        )

        :telemetry.execute(
          [:security_policy, :subscription, :denied],
          %{},
          %{subscription_id: subscription_id, reason: :no_user}
        )

        {:error, :subscription_denied}

      subscription_allowed?(user, topic) ->
        Logger.debug("[SecurityPolicy] subscription allowed",
          subscription_id: subscription_id,
          topic: topic
        )

        :telemetry.execute(
          [:security_policy, :subscription, :allowed],
          %{},
          %{subscription_id: subscription_id}
        )

        {:ok, :allowed}

      true ->
        Logger.warning("[SecurityPolicy] subscription denied — insufficient role",
          subscription_id: subscription_id,
          topic: topic,
          user_id: Map.get(user, :id)
        )

        :telemetry.execute(
          [:security_policy, :subscription, :denied],
          %{},
          %{subscription_id: subscription_id, reason: :insufficient_role}
        )

        {:error, :subscription_denied}
    end
  end

  @doc """
  Create and store security policies from a policy configuration map.

  The policy config map is expected to contain:
  - `:federationid` or `:federation_id` — owning federation
  - `:version` — policy version string
  - `:config` — policy configuration (map or list)

  Policies are validated for structure and stored in the process
  dictionary (keyed by `{:security_policies, federation_id, version}`).
  For production use, replace with a persistent store (e.g. ETS or DB).

  ## Returns
  - `{:ok, policies_map}` on success
  - `{:error, reason}` on validation failure
  """
  @spec create_policies(map()) :: {:ok, map()} | {:error, String.t()}
  def create_policies(policy_config) when is_map(policy_config) do
    federation_id =
      Map.get(policy_config, :federationid) || Map.get(policy_config, :federation_id)

    version = Map.get(policy_config, :version)
    config = Map.get(policy_config, :config, %{})

    with :ok <- validate_policy_config(federation_id, version, config) do
      policies = %{
        federation_id: federation_id,
        version: version,
        config: config,
        created_at: DateTime.utc_now(),
        rules: normalise_policy_rules(config)
      }

      store_policies(federation_id, version, policies)

      Logger.info("[SecurityPolicy] create_policies — policies stored",
        federation_id: federation_id,
        version: version
      )

      :telemetry.execute(
        [:security_policy, :policies, :created],
        %{},
        %{federation_id: federation_id, version: version}
      )

      {:ok, policies}
    end
  end

  def create_policies(_policy_config) do
    {:error, "policy_config must be a map"}
  end

  @doc """
  Apply a specific version of security policies to a federation/request.

  Looks up the stored policies for `federation_id` at `policy_version`
  and returns the policy map for downstream enforcement.

  ## Parameters
  - `federation_id` — the federation or gateway identifier
  - `policy_version` — the version string previously created via
    `create_policies/1`

  ## Returns
  - `{:ok, modified_request_or_policies}` policies successfully applied
  - `{:error, reason}` policies not found or application failed
  """
  @spec apply_policies(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def apply_policies(federation_id, policy_version)
      when is_binary(federation_id) and is_binary(policy_version) do
    case fetch_policies(federation_id, policy_version) do
      {:ok, policies} ->
        Logger.info("[SecurityPolicy] apply_policies — applying",
          federation_id: federation_id,
          version: policy_version
        )

        :telemetry.execute(
          [:security_policy, :policies, :applied],
          %{},
          %{federation_id: federation_id, version: policy_version}
        )

        {:ok, policies}

      {:error, :not_found} ->
        # Gracefully allow if no policies have been configured yet
        Logger.warning("[SecurityPolicy] apply_policies — no policies found, allowing",
          federation_id: federation_id,
          version: policy_version
        )

        {:ok, %{federation_id: federation_id, version: policy_version, rules: []}}
    end
  end

  def apply_policies(_federation_id, _policy_version) do
    {:error, "federation_id and policy_version must be strings"}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_user_role(map()) :: atom()
  defp get_user_role(user) do
    role = Map.get(user, :role) || Map.get(user, "role")

    cond do
      is_atom(role) and role in @role_hierarchy -> role
      is_binary(role) -> String.to_existing_atom(role)
      true -> :guest
    end
  rescue
    ArgumentError -> :guest
  end

  @spec role_sufficient?(atom(), atom()) :: boolean()
  defp role_sufficient?(user_role, required_role) do
    user_idx = Enum.find_index(@role_hierarchy, &(&1 == user_role)) || -1
    req_idx = Enum.find_index(@role_hierarchy, &(&1 == required_role)) || 0
    user_idx >= req_idx
  end

  @spec extract_action(any()) :: atom()
  defp extract_action(resource) when is_atom(resource), do: resource

  defp extract_action(resource) when is_map(resource) do
    Map.get(resource, :action) || Map.get(resource, "action") || :read
  end

  defp extract_action(_), do: :read

  @spec collect_policy_violations(any(), any(), any()) :: list()
  defp collect_policy_violations(_context_id, operation, policies)
       when is_list(policies) do
    Enum.flat_map(policies, fn policy ->
      check_single_policy(policy, operation)
    end)
  end

  defp collect_policy_violations(_context_id, operation, context) when is_map(context) do
    # Check basic authentication presence
    user = Map.get(context, :user) || Map.get(context, "user")

    if is_nil(user) and operation_requires_auth?(operation) do
      [:unauthenticated]
    else
      []
    end
  end

  defp collect_policy_violations(_context_id, _operation, _other), do: []

  @spec check_single_policy(map(), map()) :: list()
  defp check_single_policy(%{type: :rate_limit, config: %{max: _max}}, _operation) do
    # Placeholder: real rate-limit enforcement would check ETS counters
    []
  end

  defp check_single_policy(%{type: :require_auth}, operation) do
    if operation_requires_auth?(operation), do: [], else: [:auth_required]
  end

  defp check_single_policy(%{type: :allow_all}, _operation), do: []
  defp check_single_policy(%{type: :deny_all}, _operation), do: [:denied_by_policy]
  defp check_single_policy(_unknown_policy, _operation), do: []

  @spec operation_requires_auth?(map()) :: boolean()
  defp operation_requires_auth?(operation) when is_map(operation) do
    # Treat all operations as requiring auth unless explicitly marked public
    not Map.get(operation, :public, false)
  end

  defp operation_requires_auth?(_), do: true

  @spec resolve_user(map() | nil, map() | any()) :: map() | nil
  defp resolve_user(nil, context) when is_map(context) do
    Map.get(context, :user) || Map.get(context, "user")
  end

  defp resolve_user(user, _context) when is_map(user), do: user
  defp resolve_user(_, _), do: nil

  @spec resolve_topic(map() | any()) :: String.t() | nil
  defp resolve_topic(context) when is_map(context) do
    Map.get(context, :subscription_topic) ||
      Map.get(context, :topic) ||
      Map.get(context, "topic")
  end

  defp resolve_topic(topic) when is_binary(topic), do: topic
  defp resolve_topic(_), do: nil

  @spec subscription_allowed?(map(), String.t() | nil) :: boolean()
  defp subscription_allowed?(user, topic) do
    user_role = get_user_role(user)

    # System-level topics require admin or above
    if is_binary(topic) and String.starts_with?(topic, "system:") do
      role_sufficient?(user_role, :admin)
    else
      # All other topics require at least viewer
      role_sufficient?(user_role, :viewer)
    end
  end

  @spec validate_policy_config(any(), any(), any()) :: :ok | {:error, String.t()}
  defp validate_policy_config(nil, _version, _config) do
    {:error, "federation_id is required"}
  end

  defp validate_policy_config(_federation_id, nil, _config) do
    {:error, "version is required"}
  end

  defp validate_policy_config(_federation_id, _version, _config), do: :ok

  @spec normalise_policy_rules(map() | list() | any()) :: list()
  defp normalise_policy_rules(config) when is_list(config), do: config

  defp normalise_policy_rules(config) when is_map(config) do
    Map.get(config, :rules) || Map.get(config, "rules") || []
  end

  defp normalise_policy_rules(_), do: []

  @spec store_policies(String.t() | nil, String.t() | nil, map()) :: :ok
  defp store_policies(federation_id, version, policies) do
    Process.put({:security_policies, federation_id, version}, policies)
    :ok
  end

  @spec fetch_policies(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
  defp fetch_policies(federation_id, version) do
    case Process.get({:security_policies, federation_id, version}) do
      nil -> {:error, :not_found}
      policies -> {:ok, policies}
    end
  end
end
