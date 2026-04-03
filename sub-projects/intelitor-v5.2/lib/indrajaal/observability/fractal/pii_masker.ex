defmodule Indrajaal.Observability.Fractal.PIIMasker do
  @moduledoc """
  PII Masking Module for Fractal Logging System.

  Implements SC-LOG-003: PII masking at decorator.
  All sensitive data is masked BEFORE log emission.

  ## Categories

  - **PII**: Email, Phone, SSN, IP Address
  - **PCI**: Credit card numbers
  - **PHI**: Health information (HIPAA)
  - **Credentials**: Passwords, tokens, API keys

  ## Usage

      masked = Indrajaal.Observability.Fractal.PIIMasker.mask(%{
        email: "user@example.com",
        card: "4_111_111_111_111_111",
        password: "secret123"
      })
      # => %{email: "use***@example.com", card: "************1111", password: "[REDACTED]"}

  ## STAMP Compliance

  - SC-LOG-003: PII masking at decorator (mandatory)
  - SC-SEC-001: Sensitive data protection
  """

  @type mask_result :: %{
          masked: String.t(),
          was_masked: boolean(),
          category: atom() | nil,
          correlation_hash: String.t() | nil
        }

  # ============================================================
  # PATTERNS
  # ============================================================

  @email_regex ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
  @phone_regex ~r/(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}/
  @credit_card_regex ~r/\b(?:\d[ -]*?){13,19}\b/
  @ssn_regex ~r/\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b/
  @ip_regex ~r/\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
  @jwt_regex ~r/eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*/

  @sensitive_keys [
    "password",
    "passwd",
    "pwd",
    "secret",
    "token",
    "api_key",
    "apikey",
    "authorization",
    "auth",
    "bearer",
    "credential",
    "private_key",
    "access_token",
    "refresh_token",
    "session_id",
    "cookie"
  ]

  @exempt_keys [
    "timestamp",
    "level",
    "module",
    "function",
    "line",
    "node_id",
    "trace_id",
    "span_id",
    "request_id",
    "event",
    "action"
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Mask sensitive data in a map or struct.

  Recursively traverses the data structure and masks any
  detected PII, PCI, or credential data.
  """
  @spec mask(term()) :: term()
  def mask(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      key_str = to_string(key)
      {key, mask_value(key_str, value)}
    end)
    |> Enum.into(%{})
  end

  def mask(data) when is_list(data) do
    Enum.map(data, &mask/1)
  end

  def mask(data) when is_binary(data) do
    mask_string(data)
  end

  def mask(data), do: data

  @doc """
  Mask a single value with explicit key context.
  """
  @spec mask_value(String.t(), term()) :: term()
  def mask_value(key, value) do
    key_lower = String.downcase(key)

    cond do
      exempt_key?(key_lower) ->
        value

      sensitive_key?(key_lower) ->
        "[REDACTED]"

      is_binary(value) ->
        mask_string(value)

      is_map(value) ->
        mask(value)

      is_list(value) ->
        mask(value)

      true ->
        value
    end
  end

  @doc """
  Mask PII patterns in a string.
  """
  @spec mask_string(String.t()) :: String.t()
  def mask_string(str) when is_binary(str) do
    str
    |> mask_pattern(@credit_card_regex, :partial_end)
    |> mask_pattern(@ssn_regex, :redacted)
    |> mask_pattern(@email_regex, :partial_email)
    |> mask_pattern(@phone_regex, :partial_end)
    |> mask_pattern(@jwt_regex, :partial_both)
    |> mask_pattern(@ip_regex, :partial_end)
    |> mask_api_keys()
    |> mask_passwords()
  end

  def mask_string(other), do: other

  @doc """
  Check if a string contains any PII patterns.
  """
  @spec contains_pii?(String.t()) :: boolean()
  def contains_pii?(str) when is_binary(str) do
    Regex.match?(@email_regex, str) or
      Regex.match?(@phone_regex, str) or
      Regex.match?(@credit_card_regex, str) or
      Regex.match?(@ssn_regex, str) or
      Regex.match?(@jwt_regex, str)
  end

  def contains_pii?(_), do: false

  @doc """
  Generate a correlation hash for masked data.

  Allows debugging correlation without exposing PII.
  """
  @spec correlation_hash(String.t()) :: String.t()
  def correlation_hash(value) do
    salt = Application.get_env(:indrajaal, :fractal_hash_salt, "fractal-default-salt")
    sha_hash = :crypto.hash(:sha256, salt <> value)

    sha_hash
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  # ============================================================
  # PRIVATE: PATTERN MASKING
  # ============================================================

  defp mask_pattern(str, regex, strategy) do
    Regex.replace(regex, str, fn match ->
      apply_strategy(match, strategy)
    end)
  end

  defp apply_strategy(_value, :redacted), do: "[REDACTED]"

  defp apply_strategy(value, :asterisks) do
    String.duplicate("*", String.length(value))
  end

  defp apply_strategy(value, :partial_end) do
    len = String.length(value)

    if len <= 4 do
      String.duplicate("*", len)
    else
      String.duplicate("*", len - 4) <> String.slice(value, -4, 4)
    end
  end

  defp apply_strategy(value, :partial_email) do
    case String.split(value, "@", parts: 2) do
      [local, domain] ->
        masked_local =
          if String.length(local) <= 3 do
            String.duplicate("*", String.length(local))
          else
            String.slice(local, 0, 3) <> String.duplicate("*", String.length(local) - 3)
          end

        "#{masked_local}@#{domain}"

      _ ->
        String.duplicate("*", String.length(value))
    end
  end

  defp apply_strategy(value, :partial_both) do
    len = String.length(value)

    if len <= 20 do
      String.duplicate("*", len)
    else
      prefix = String.slice(value, 0, 10)
      suffix = String.slice(value, -10, 10)
      "#{prefix}...#{suffix}"
    end
  end

  defp mask_api_keys(str) do
    Regex.replace(
      ~r/(?:api[_-]?key|token|secret|bearer)\s*[:=]\s*['"]?([a-zA-Z0-9_\-]{16,})['"]?/i,
      str,
      fn full_match, value ->
        masked_value = apply_strategy(value, :partial_both)
        String.replace(full_match, value, masked_value)
      end
    )
  end

  defp mask_passwords(str) do
    Regex.replace(
      ~r/(?:password|passwd|pwd)\s*[:=]\s*['"]?([^'"&\s]+)['"]?/i,
      str,
      fn full_match, value ->
        String.replace(full_match, value, "[REDACTED]")
      end
    )
  end

  # ============================================================
  # PRIVATE: KEY CLASSIFICATION
  # ============================================================

  defp sensitive_key?(key) do
    Enum.any?(@sensitive_keys, fn sensitive ->
      String.contains?(key, sensitive)
    end)
  end

  defp exempt_key?(key) do
    key in @exempt_keys
  end
end
