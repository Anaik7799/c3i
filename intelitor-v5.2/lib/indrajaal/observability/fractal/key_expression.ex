defmodule Indrajaal.Observability.Fractal.KeyExpression do
  @moduledoc """
  Zenoh-style Key Expression Engine for Fractal Logging.

  Provides flexible log targeting with wildcards:
  - `*` - Match exactly one path segment
  - `**` - Match zero or more path segments
  - `$*` - Infix match within a segment

  ## Examples

      # Exact match
      matches?("Indrajaal/Alarms/create", "Indrajaal/Alarms/create")  # true

      # Single wildcard
      matches?("Indrajaal/*/create", "Indrajaal/Alarms/create")  # true
      matches?("Indrajaal/*/create", "Indrajaal/A/B/create")  # false

      # Double wildcard
      matches?("Indrajaal/**", "Indrajaal/A/B/C/D")  # true
      matches?("**/error", "Any/Path/To/error")  # true

      # Infix wildcard
      matches?("**/$*Handler", "Module/AlarmHandler")  # true

  ## STAMP Compliance

  - SC-LOG-009: Key aliases pre-registered at startup
  """

  @type compiled_expr :: %{
          original: String.t(),
          regex: Regex.t(),
          segments: [String.t()],
          has_wildcard: boolean(),
          has_double_wildcard: boolean(),
          has_infix_wildcard: boolean(),
          is_exact: boolean()
        }

  # ============================================================
  # COMPILATION
  # ============================================================

  @doc """
  Compile a key expression to an optimized matcher.
  """
  @spec compile(String.t()) :: {:ok, compiled_expr()} | {:error, String.t()}
  def compile(expr) when is_binary(expr) do
    # Normalize separators
    normalized = String.replace(expr, ".", "/")

    has_wildcard = String.contains?(normalized, "*") and not String.contains?(normalized, "**")
    has_double_wildcard = String.contains?(normalized, "**")
    has_infix_wildcard = String.contains?(normalized, "$*")
    is_exact = not (has_wildcard or has_double_wildcard or has_infix_wildcard)

    # Build regex pattern
    # Use placeholders to protect wildcard patterns during escaping
    pattern =
      normalized
      |> String.replace("$*", "\x00INFIX\x00")
      |> String.replace("**", "\x00DOUBLE\x00")
      |> String.replace(~r/(?<!\*)(\*)(?!\*)/, "\x00SINGLE\x00")
      |> escape_regex_special()
      |> String.replace("\x00INFIX\x00", "([^/]*)")
      # Handle ** followed by / - makes both content AND slash optional together
      |> String.replace("\x00DOUBLE\x00/", "(.*/)?")
      # Handle ** at end or standalone - matches anything after
      |> String.replace("\x00DOUBLE\x00", "(.+)?")
      |> String.replace("\x00SINGLE\x00", "([^/]+)")

    case Regex.compile("^#{pattern}$") do
      {:ok, regex} ->
        {:ok,
         %{
           original: expr,
           regex: regex,
           segments: String.split(normalized, "/"),
           has_wildcard: has_wildcard,
           has_double_wildcard: has_double_wildcard,
           has_infix_wildcard: has_infix_wildcard,
           is_exact: is_exact
         }}

      {:error, reason} ->
        {:error, "Failed to compile key expression: #{inspect(reason)}"}
    end
  end

  @doc """
  Compile a key expression, raising on error.
  """
  @spec compile!(String.t()) :: compiled_expr()
  def compile!(expr) do
    case compile(expr) do
      {:ok, compiled} -> compiled
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ============================================================
  # MATCHING
  # ============================================================

  @doc """
  Check if a key matches a compiled expression.
  """
  @spec matches?(compiled_expr(), String.t()) :: boolean()
  def matches?(%{is_exact: true, original: original}, key) do
    normalized_key = String.replace(key, ".", "/")
    normalized_original = String.replace(original, ".", "/")
    normalized_key == normalized_original
  end

  def matches?(%{regex: regex}, key) do
    normalized_key = String.replace(key, ".", "/")
    Regex.match?(regex, normalized_key)
  end

  @spec matches?(String.t(), String.t()) :: boolean()
  def matches?(expr, key) when is_binary(expr) do
    case compile(expr) do
      {:ok, compiled} -> matches?(compiled, key)
      {:error, _} -> false
    end
  end

  @doc """
  Check if two expressions could match the same keys.
  """
  @spec intersects?(compiled_expr(), compiled_expr()) :: boolean()
  def intersects?(a, b) do
    cond do
      a.has_double_wildcard or b.has_double_wildcard -> true
      a.is_exact and b.is_exact -> a.original == b.original
      true -> matches?(a, b.original) or matches?(b, a.original)
    end
  end

  # ============================================================
  # KEY BUILDING
  # ============================================================

  @doc """
  Build a key from module and function.
  """
  @spec build_key(atom() | String.t(), atom() | String.t()) :: String.t()
  def build_key(module, function) do
    module_str = module |> to_string() |> String.replace("Elixir.", "")
    "#{module_str}/#{function}"
  end

  @doc """
  Build a key with event type.
  """
  @spec build_key(atom() | String.t(), atom() | String.t(), atom() | String.t()) :: String.t()
  def build_key(module, function, event_type) do
    "#{build_key(module, function)}/#{event_type}"
  end

  @doc """
  Extract the module name from a key.
  """
  @spec extract_module(String.t()) :: String.t() | nil
  def extract_module(key) do
    key
    |> String.replace(".", "/")
    |> String.split("/")
    |> List.first()
  end

  @doc """
  Extract the function name from a key.
  """
  @spec extract_function(String.t()) :: String.t() | nil
  def extract_function(key) do
    key
    |> String.replace(".", "/")
    |> String.split("/")
    |> List.last()
  end

  # ============================================================
  # VALIDATION
  # ============================================================

  @doc """
  Validate a key expression syntax.
  """
  @spec validate(String.t()) :: :ok | {:error, [String.t()]}
  def validate(expr) do
    errors = []

    errors =
      if String.trim(expr) == "" do
        ["Key expression cannot be empty" | errors]
      else
        errors
      end

    errors =
      if Regex.match?(~r/[<>|\\"]/, expr) do
        ["Invalid characters in key expression" | errors]
      else
        errors
      end

    errors =
      if String.contains?(expr, "***") do
        ["Invalid wildcard sequence '***'" | errors]
      else
        errors
      end

    errors =
      if String.starts_with?(expr, "/") or String.ends_with?(expr, "/") do
        ["Key expression should not start or end with '/'" | errors]
      else
        errors
      end

    case compile(expr) do
      {:ok, _} ->
        if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}

      {:error, reason} ->
        {:error, Enum.reverse([reason | errors])}
    end
  end

  @doc """
  Check if an expression is valid.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(expr) do
    validate(expr) == :ok
  end

  # ============================================================
  # COMMON PATTERNS
  # ============================================================

  @doc """
  Common key expression patterns.
  """
  def patterns do
    %{
      all_in_module: fn module -> "#{module}/**" end,
      all_create: "**/create",
      all_errors: "**/error",
      function_in_any: fn func -> "**/#{func}" end,
      any_handler: "**/$*Handler",
      cortex_cognitive: "Indrajaal/Cortex/**",
      security_audit: "Indrajaal/Security/**",
      all_alarms: "Indrajaal/Alarms/**"
    }
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  defp escape_regex_special(str) do
    # Escape special regex chars (wildcards are already replaced with placeholders)
    String.replace(str, ~r/([.+?^${}()|[\]\\])/, "\\\\\\1")
  end
end
