defmodule Indrajaal.Errors.Unauthorized do
  @moduledoc """
  Authentication - related errors.
  """
  defmodule AuthenticationRequired do
    @moduledoc false
    use Splode.Error,
      fields: [:endpoint, :method, :_required_auth_types],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{endpoint: endpoint, method: method}) do
      "Authentication _required for #{method} #{endpoint}"
    end
  end

  defmodule InvalidToken do
    @moduledoc false
    use Splode.Error,
      fields: [:token_type, :reason, :token_hint],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{tokentype: type, reason: reason}) do
      "Invalid #{type} token: #{reason}"
    end
  end

  defmodule SessionExpired do
    @moduledoc false
    use Splode.Error,
      fields: [:session_id, :expired_at, :current_time, :user_id],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{sessionid: session, expired_at: expired}) do
      "Session #{session} expired at #{expired}"
    end
  end

  defmodule MfaRequired do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :available_methods, :session_id],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{userid: user, availablemethods: methods}) do
      "MFA _required for user #{user}. Available methods: #{Enum.join(methods, ", ")}"
    end
  end

  defmodule InvalidMfaCode do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :method, :attempts_remaining],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{userid: user, method: method, attemptsremaining: attempts}) do
      "Invalid MFA code for user #{user} using #{method}. #{attempts} attempts remaining"
    end
  end

  defmodule AccountLocked do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :locked_at, :lock_reason, :unlock_time],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{userid: user, lockreason: reason, unlocktime: unlock}) do
      "Account #{user} locked due to #{reason}. Unlocks at #{unlock}"
    end
  end

  defmodule AccountDisabled do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :disabled_at, :disabled_reason],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{userid: user, disabledreason: reason}) do
      "Account #{user} disabled: #{reason}"
    end
  end

  defmodule InvalidApiKey do
    @moduledoc false
    use Splode.Error,
      fields: [:api_key_hint, :client_id, :reason],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{apikeyhint: hint, clientid: client, reason: reason}) do
      "Invalid API key ending in #{hint} for client #{client}: #{reason}"
    end
  end

  defmodule CertificateInvalid do
    @moduledoc false
    use Splode.Error,
      fields: [:certificate_cn, :issuer, :validation_error, :client_ip],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{certificatecn: cn, validationerror: error}) do
      "Invalid certificate for #{cn}: #{error}"
    end
  end

  defmodule DeviceNotRegistered do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :device_type, :client_ip, :attempted_action],
      class: :unauthorized

    @spec message(map()) :: String.t()
    def message(%{device_id: device, device_type: type}) do
      "Device #{device} (#{type}) not registered"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cybernetic
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
