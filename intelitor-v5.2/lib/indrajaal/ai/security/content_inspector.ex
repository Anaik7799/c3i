defmodule Indrajaal.AI.Security.ContentInspector do
  @moduledoc """
  Inspects AI prompts and responses for security violations.

  ## Security Patterns Detected

  - **Prompt Injection**: Attempts to override system instructions
  - **SQL Injection**: Database attack patterns
  - **Command Injection**: Shell command execution attempts
  - **Credential Patterns**: API keys, passwords, tokens
  - **PII Patterns**: Email, phone, SSN, credit card numbers

  ## STAMP Constraints

  - SC-SEC-001: No unreviewed code execution
  - SC-SEC-044: Sobelow patterns applied to AI content
  - SC-SEC-047: Encryption for sensitive data
  - SC-SEC-AI-004: PII detection

  ## Usage

      case ContentInspector.inspect_prompt(user_input) do
        {:ok, :clean} -> proceed_with_request()
        {:error, {:forbidden, reason}} -> block_request(reason)
      end
  """

  require Logger

  # Prompt Injection Patterns
  @prompt_injection_patterns [
    ~r/ignore\s+(all\s+)?(previous\s+)?instructions?/i,
    ~r/disregard\s+(all\s+)?(previous\s+)?instructions?/i,
    ~r/forget\s+(all\s+)?(previous\s+|your\s+)?(instructions?|rules)/i,
    ~r/you\s+are\s+now\s+(a|an|in)\s+/i,
    ~r/pretend\s+(you\s+are|to\s+be)/i,
    ~r/act\s+as\s+(a|an|if)\s+/i,
    ~r/\[system\]/i,
    ~r/<\|im_start\|>/i,
    ~r/<\|im_end\|>/i,
    ~r/\{\{system\}\}/i,
    ~r/override\s+system\s+prompt/i,
    ~r/new\s+instructions?\s*:/i,
    ~r/DAN\s+mode/i
  ]

  # SQL Injection Patterns
  @sql_injection_patterns [
    ~r/'\s*;\s*DROP\s+TABLE/i,
    ~r/'\s*;\s*DELETE\s+FROM/i,
    ~r/'\s*;\s*UPDATE\s+.*SET/i,
    ~r/'\s*;\s*INSERT\s+INTO/i,
    ~r/UNION\s+SELECT/i,
    ~r/UNION\s+ALL\s+SELECT/i,
    ~r/'\s*OR\s+'1'\s*=\s*'1/i,
    ~r/'\s*OR\s+1\s*=\s*1/i,
    ~r/--\s*$/m,
    ~r/\/\*.*\*\//
  ]

  # Command Injection Patterns
  @command_injection_patterns [
    ~r/;\s*(rm|del|format|shutdown|reboot|kill)\s/i,
    ~r/\|\s*(bash|sh|cmd|powershell)/i,
    ~r/`[^`]+`/,
    ~r/\$\([^)]+\)/,
    ~r/\$\{[^}]+\}/,
    ~r/&&\s*(rm|del|chmod|curl|wget)\s/i,
    ~r/>\s*\/dev\/(null|zero)/i,
    ~r/\|\s*tee\s+/i
  ]

  # Credential Patterns (high confidence)
  @credential_patterns [
    ~r/api[_-]?key\s*[=:]\s*['"]?[a-zA-Z0-9]{20,}['"]?/i,
    ~r/api[_-]?secret\s*[=:]\s*['"]?[a-zA-Z0-9]{20,}['"]?/i,
    ~r/(password|passwd|pwd)\s*[=:]\s*['"]?[^\s'"]{8,}['"]?/i,
    ~r/bearer\s+[a-zA-Z0-9\-_.~+\/]+=*/i,
    # OpenAI API key
    ~r/sk-[a-zA-Z0-9]{40,}/,
    # Anthropic API key
    ~r/sk-ant-[a-zA-Z0-9\-]{40,}/,
    # Google API key
    ~r/AIza[a-zA-Z0-9\-_]{35}/,
    # GitHub PAT
    ~r/ghp_[a-zA-Z0-9]{36}/,
    # GitLab PAT
    ~r/glpat-[a-zA-Z0-9\-]{20}/
  ]

  # PII Patterns (warning only, not blocking)
  @pii_patterns [
    # Email
    {~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, :email},
    # US Phone
    {~r/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/, :phone},
    # SSN
    {~r/\b\d{3}-\d{2}-\d{4}\b/, :ssn},
    # Credit Card (Luhn check would be better but this is a start)
    {~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/, :credit_card}
  ]

  @doc """
  Inspect a prompt for security violations.

  ## Returns

  - `{:ok, :clean}` if no violations found
  - `{:error, {:forbidden, reason}}` if a blocking pattern is detected
  """
  @spec inspect_prompt(String.t() | nil) :: {:ok, :clean} | {:error, {:forbidden, String.t()}}
  def inspect_prompt(nil), do: {:ok, :clean}
  def inspect_prompt(""), do: {:ok, :clean}

  def inspect_prompt(prompt) when is_binary(prompt) do
    with :ok <- check_prompt_injection(prompt),
         :ok <- check_sql_injection(prompt),
         :ok <- check_command_injection(prompt),
         :ok <- check_credentials(prompt) do
      # PII check is warning-only
      check_pii(prompt)
      {:ok, :clean}
    end
  end

  @doc """
  Inspect a response for potentially dangerous content.

  This is a softer check - it returns warnings rather than blocking.

  ## Returns

  - `{:ok, :clean}` if no issues found
  - `{:warn, [String.t()]}` if warnings were generated
  """
  @spec inspect_response(String.t() | nil) :: {:ok, :clean} | {:warn, [String.t()]}
  def inspect_response(nil), do: {:ok, :clean}
  def inspect_response(""), do: {:ok, :clean}

  def inspect_response(response) when is_binary(response) do
    warnings = []

    warnings =
      if contains_code_blocks?(response) do
        ["response contains code blocks" | warnings]
      else
        warnings
      end

    warnings =
      if contains_urls?(response) do
        ["response contains URLs" | warnings]
      else
        warnings
      end

    warnings =
      if contains_executable_commands?(response) do
        ["response contains executable commands" | warnings]
      else
        warnings
      end

    if Enum.empty?(warnings) do
      {:ok, :clean}
    else
      {:warn, warnings}
    end
  end

  @doc """
  Sanitize content by removing or masking sensitive patterns.
  """
  @spec sanitize(String.t()) :: String.t()
  def sanitize(content) when is_binary(content) do
    content
    |> mask_credentials()
    |> mask_pii()
  end

  def sanitize(content), do: to_string(content)

  # ---------------------------------------------------------------------------
  # Private: Pattern Checks
  # ---------------------------------------------------------------------------

  defp check_prompt_injection(content) do
    case find_matching_pattern(@prompt_injection_patterns, content) do
      nil ->
        :ok

      pattern ->
        Logger.warning("[ContentInspector] Prompt injection detected: #{inspect(pattern)}")
        {:error, {:forbidden, "prompt_injection detected"}}
    end
  end

  defp check_sql_injection(content) do
    case find_matching_pattern(@sql_injection_patterns, content) do
      nil ->
        :ok

      pattern ->
        Logger.warning("[ContentInspector] SQL injection detected: #{inspect(pattern)}")
        {:error, {:forbidden, "sql_injection pattern detected"}}
    end
  end

  defp check_command_injection(content) do
    case find_matching_pattern(@command_injection_patterns, content) do
      nil ->
        :ok

      pattern ->
        Logger.warning("[ContentInspector] Command injection detected: #{inspect(pattern)}")
        {:error, {:forbidden, "command_injection pattern detected"}}
    end
  end

  defp check_credentials(content) do
    case find_matching_pattern(@credential_patterns, content) do
      nil ->
        :ok

      pattern ->
        Logger.warning("[ContentInspector] Credential pattern detected: #{inspect(pattern)}")

        {:error,
         {:forbidden, "credential pattern detected - do not include API keys or passwords"}}
    end
  end

  defp check_pii(content) do
    pii_found =
      @pii_patterns
      |> Enum.filter(fn {pattern, _type} -> Regex.match?(pattern, content) end)
      |> Enum.map(&elem(&1, 1))

    if not Enum.empty?(pii_found) do
      Logger.warning("[ContentInspector] PII detected: #{inspect(pii_found)}")
    end

    :ok
  end

  defp find_matching_pattern(patterns, content) do
    Enum.find(patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: Response Inspection
  # ---------------------------------------------------------------------------

  defp contains_code_blocks?(content) do
    String.contains?(content, "```")
  end

  defp contains_urls?(content) do
    Regex.match?(~r/https?:\/\/[^\s]+/, content)
  end

  defp contains_executable_commands?(content) do
    # Check for common executable patterns
    # $(command) patterns
    Regex.match?(~r/^\s*\$\s+/m, content) or
      Regex.match?(~r/^\s*>\s+/m, content) or
      Regex.match?(~r/^\s*#\s*(chmod|rm|curl|wget|sudo)/m, content) or
      Regex.match?(~r/\$\([^)]+\)/, content)
  end

  # ---------------------------------------------------------------------------
  # Private: Sanitization
  # ---------------------------------------------------------------------------

  defp mask_credentials(content) do
    Enum.reduce(@credential_patterns, content, fn pattern, acc ->
      Regex.replace(pattern, acc, "[REDACTED]")
    end)
  end

  defp mask_pii(content) do
    Enum.reduce(@pii_patterns, content, fn {pattern, type}, acc ->
      Regex.replace(pattern, acc, "[#{String.upcase(to_string(type))}_REDACTED]")
    end)
  end
end
