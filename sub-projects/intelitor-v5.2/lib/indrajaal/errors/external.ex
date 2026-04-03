defmodule Indrajaal.Errors.External do
  @moduledoc """
  External service and integration - related errors.
  """
  defmodule ApiConnectionFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :endpoint, :status_code, :response_body, :retry_count],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{servicename: service, endpoint: endpoint, statuscode: status}) do
      "API connection failed to #{service} at #{endpoint}: HTTP #{status}"
    end
  end

  defmodule ApiRateLimitExceeded do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :rate_limit, :retry_after, :_request_count],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{servicename: service, ratelimit: limit, retryafter: retry}) do
      "Rate limit exceeded for #{service}: #{limit} _requests / period, retry after #{retry} seconds"
    end
  end

  defmodule WebhookDeliveryFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:webhook_id, :target_url, :payload_size, :status_code, :error_response],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{webhookid: id, targeturl: url, status_code: status}) do
      "Webhook delivery failed for #{id} to #{url}: HTTP #{status}"
    end
  end

  defmodule EmailDeliveryFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:recipient, :subject, :provider, :error_code, :bounce_reason],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{recipient: recipient, provider: provider, errorcode: code}) do
      "Email delivery failed to #{recipient} via #{provider}: #{code}"
    end
  end

  defmodule SmsDeliveryFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:phone_number, :provider, :error_code, :delivery_receipt],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{phone_number: phone, provider: provider, error_code: code}) do
      "SMS delivery failed to #{phone} via #{provider}: #{code}"
    end
  end

  defmodule PaymentProcessingFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:payment_id, :amount, :currency, :gateway, :decline_reason],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{paymentid: id, amount: amount, currency: currency, gateway: gateway}) do
      "Payment processing failed for #{id}: #{amount} #{currency} via #{gateway}"
    end
  end

  defmodule CloudStorageError do
    @moduledoc false
    use Splode.Error,
      fields: [:operation, :bucket, :key, :provider, :error_code],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{operation: operation, bucket: bucket, key: key, provider: provider}) do
      "Cloud storage error during #{operation} on #{provider}://#{bucket}/#{key}"
    end
  end

  defmodule ActiveDirectoryError do
    @moduledoc false
    use Splode.Error,
      fields: [:operation, :__user_principal, :domain, :error_code, :ldap_error],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{operation: operation, user_principal: upn, domain: domain}) do
      "Active Directory error during #{operation} for #{upn}@#{domain}"
    end
  end

  defmodule VideoStreamError do
    @moduledoc false
    use Splode.Error,
      fields: [:camera_id, :stream_url, :protocol, :error_type, :connection_details],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{cameraid: id, streamurl: url, protocol: protocol, error_type: type}) do
      "Video stream error for camera #{id} at #{url} (#{protocol}): #{type}"
    end
  end

  defmodule IntegrationSyncFailed do
    @moduledoc false
    use Splode.Error,
      fields: [:integration_name, :sync_type, :records_processed, :errors_count, :last_sync],
      class: :external

    @spec message(map()) :: String.t()
    def message(%{integrationname: name, synctype: type, errors_count: errors}) do
      "Integration sync failed for #{name} (#{type}): #{errors} errors"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
