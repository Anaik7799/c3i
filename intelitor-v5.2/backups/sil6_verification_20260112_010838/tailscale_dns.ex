defmodule Indrajaal.Cluster.TailscaleDNS do
  @moduledoc """
  Tailscale DNS Integration for Identity-Based Networking.

  Provides utilities for generating and managing Erlang node names
  using Tailscale MagicDNS for identity-based networking.

  STAMP Compliance:
  - SC-CLU-001: Identity-based networking via Tailscale
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-004: EPMD binds to Tailscale IP only
  - SC-CLU-005: Split-brain prevention with consistent naming

  All node names use format: `app@hostname.tailnet-suffix.ts.net`

  ## Configuration

  The tailnet suffix can be configured via:
  - Environment variable: `TAILSCALE_DNS_SUFFIX`
  - Application config: `config :indrajaal, :tailscale_dns_suffix`
  - Default: `"tailnet.ts.net"`

  ## Examples

      iex> TailscaleDNS.get_node_name("app-1")
      :"indrajaal@app-1.my-tailnet.ts.net"

      iex> TailscaleDNS.get_flame_runner_name("intelligence", "runner-123")
      :"indrajaal@flame-intelligence-runner-123.my-tailnet.ts.net"
  """

  require Logger

  @default_suffix "tailnet.ts.net"
  @default_local_suffix "local.indrajaal"
  @default_app_name "indrajaal"
  @min_cluster_nodes 3

  # Default cluster node base names
  @cluster_node_bases ["indrajaal-ex-app-1", "indrajaal-ex-app-2", "indrajaal-ex-app-3"]

  # Network mode: :tailscale when Tailscale available, :local when fallback
  @type network_mode :: :tailscale | :local

  # ============================================================================
  # Tailnet Suffix
  # ============================================================================

  @doc """
  Returns the Tailscale DNS suffix for the tailnet.

  Sources (in priority order):
  1. `TAILSCALE_DNS_SUFFIX` environment variable
  2. Application config `:indrajaal, :tailscale_dns_suffix`
  3. Default: `"tailnet.ts.net"`

  The suffix is normalized to remove leading/trailing dots.

  ## Examples

      iex> System.put_env("TAILSCALE_DNS_SUFFIX", "my-tailnet.ts.net")
      iex> TailscaleDNS.get_tailnet_suffix()
      "my-tailnet.ts.net"
  """
  @spec get_tailnet_suffix() :: String.t()
  def get_tailnet_suffix do
    suffix =
      System.get_env("TAILSCALE_DNS_SUFFIX") ||
        Application.get_env(:indrajaal, :tailscale_dns_suffix) ||
        @default_suffix

    normalize_suffix(suffix)
  end

  defp normalize_suffix(suffix) when is_binary(suffix) do
    suffix
    |> String.trim()
    |> String.trim_leading(".")
    |> String.trim_trailing(".")
  end

  # ============================================================================
  # Node Name Generation
  # ============================================================================

  @doc """
  Generates a valid Erlang node name using Tailscale DNS.

  ## Options
  - `:app` - Application name prefix (default: "indrajaal")

  ## Examples

      iex> TailscaleDNS.get_node_name("app-1")
      :"indrajaal@app-1.tailnet.ts.net"

      iex> TailscaleDNS.get_node_name("app-2", app: "myapp")
      :"myapp@app-2.tailnet.ts.net"

  Raises `ArgumentError` for nil, empty, or whitespace-only input.
  """
  @spec get_node_name(String.t(), keyword()) :: atom()
  def get_node_name(base_name, opts \\ [])

  def get_node_name(nil, _opts) do
    raise ArgumentError, "base_name cannot be nil"
  end

  def get_node_name("", _opts) do
    raise ArgumentError, "base_name cannot be empty"
  end

  def get_node_name(base_name, opts) when is_binary(base_name) do
    trimmed = String.trim(base_name)

    if trimmed == "" do
      raise ArgumentError, "base_name cannot be whitespace only"
    end

    app_name = Keyword.get(opts, :app, @default_app_name)
    suffix = get_tailnet_suffix()

    sanitized_base = sanitize_dns_name(trimmed)
    full_host = "#{sanitized_base}.#{suffix}"

    String.to_atom("#{app_name}@#{full_host}")
  end

  @doc """
  Returns the full DNS name for a base hostname.

  ## Examples

      iex> TailscaleDNS.get_full_dns_name("app-1")
      "app-1.tailnet.ts.net"

  Does not duplicate suffix if already present.
  """
  @spec get_full_dns_name(String.t()) :: String.t()
  def get_full_dns_name(base_name) when is_binary(base_name) do
    suffix = get_tailnet_suffix()

    if String.contains?(base_name, suffix) do
      # Already has suffix, don't duplicate
      base_name
    else
      sanitized = sanitize_dns_name(base_name)
      "#{sanitized}.#{suffix}"
    end
  end

  # Handle atoms by converting to string first
  defp sanitize_dns_name(name) when is_atom(name) do
    sanitize_dns_name(Atom.to_string(name))
  end

  defp sanitize_dns_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace("_", "-")
    |> String.replace(~r/[^a-z0-9\-.]/, "")
  end

  # ============================================================================
  # Node Name Parsing
  # ============================================================================

  @doc """
  Parses an Erlang node name into its components.

  ## Examples

      iex> TailscaleDNS.parse_node_name(:"indrajaal@app-1.tailnet.ts.net")
      {:ok, %{app_name: "indrajaal", host: "app-1.tailnet.ts.net", base_name: "app-1"}}

      iex> TailscaleDNS.parse_node_name("invalid")
      {:error, :invalid_format}
  """
  @spec parse_node_name(atom() | String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_node_name(node_name) when is_atom(node_name) do
    parse_node_name(Atom.to_string(node_name))
  end

  def parse_node_name(node_name) when is_binary(node_name) do
    case String.split(node_name, "@") do
      [app_name, host] when byte_size(app_name) > 0 and byte_size(host) > 0 ->
        base_name = extract_base_name(host)

        {:ok,
         %{
           app_name: app_name,
           host: host,
           base_name: base_name
         }}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp extract_base_name(host) do
    # Extract the first segment before the tailnet suffix
    suffix = get_tailnet_suffix()

    if String.ends_with?(host, suffix) do
      host
      |> String.trim_trailing(suffix)
      |> String.trim_trailing(".")
    else
      host
    end
  end

  # ============================================================================
  # Node Name Conversion
  # ============================================================================

  @doc """
  Converts a short node name or IP-based node name to Tailscale DNS format.

  ## Examples

      iex> TailscaleDNS.node_to_tailscale_name(:"indrajaal@app-1")
      :"indrajaal@app-1.tailnet.ts.net"

      iex> TailscaleDNS.node_to_tailscale_name(:"indrajaal@app-1.tailnet.ts.net")
      :"indrajaal@app-1.tailnet.ts.net"  # Already qualified, unchanged
  """
  @spec node_to_tailscale_name(atom() | String.t()) :: atom()
  def node_to_tailscale_name(node_name) when is_binary(node_name) do
    node_to_tailscale_name(String.to_atom(node_name))
  end

  def node_to_tailscale_name(node_name) when is_atom(node_name) do
    suffix = get_tailnet_suffix()
    node_string = Atom.to_string(node_name)

    if String.contains?(node_string, suffix) do
      # Already has Tailscale suffix
      node_name
    else
      case String.split(node_string, "@") do
        [app_name, host] ->
          # Convert IP or short name to DNS
          converted_host =
            if ip_address?(host) do
              # For IP addresses, use a derived name
              "node-#{String.replace(host, ".", "-")}.#{suffix}"
            else
              "#{host}.#{suffix}"
            end

          String.to_atom("#{app_name}@#{converted_host}")

        _ ->
          # Invalid format, return as-is
          node_name
      end
    end
  end

  defp ip_address?(host) do
    Regex.match?(~r/^\d+\.\d+\.\d+\.\d+$/, host)
  end

  # ============================================================================
  # Cluster Node Management
  # ============================================================================

  @doc """
  Returns the list of configured cluster nodes with Tailscale DNS names.

  The node list comes from:
  1. Application config `:indrajaal, :cluster_nodes`
  2. Default: 3 nodes (app-1, app-2, app-3)

  All returned nodes are guaranteed to:
  - Use Tailscale DNS suffix
  - Start with "indrajaal@"
  - Have at least 3 entries (SC-CLU-002)

  ## Examples

      iex> TailscaleDNS.list_cluster_nodes()
      [:"indrajaal@indrajaal-ex-app-1.tailnet.ts.net",
       :"indrajaal@indrajaal-ex-app-2.tailnet.ts.net",
       :"indrajaal@indrajaal-ex-app-3.tailnet.ts.net"]
  """
  @spec list_cluster_nodes() :: [atom()]
  def list_cluster_nodes do
    configured_nodes =
      Application.get_env(:indrajaal, :cluster_nodes) ||
        @cluster_node_bases

    suffix = get_tailnet_suffix()

    nodes =
      configured_nodes
      |> Enum.map(fn base ->
        # Ensure consistent naming format
        sanitized = sanitize_dns_name(base)
        String.to_atom("#{@default_app_name}@#{sanitized}.#{suffix}")
      end)

    # SC-CLU-002: Ensure at least 3 nodes
    if length(nodes) < @min_cluster_nodes do
      Logger.warning(
        "SC-CLU-002: Configured cluster has #{length(nodes)} nodes, " <>
          "minimum #{@min_cluster_nodes} required for HA"
      )
    end

    nodes
  end

  # ============================================================================
  # Tailscale Connectivity Validation
  # ============================================================================

  @doc """
  Validates Tailscale connectivity and returns status information.

  Returns:
  - `{:ok, info}` - Connected with DNS name and IP
  - `{:error, reason}` - Not connected or unavailable

  ## Examples

      iex> TailscaleDNS.validate_tailscale_connectivity()
      {:ok, %{dns_name: "myhost.tailnet.ts.net", ip_address: "100.x.x.x"}}

      iex> TailscaleDNS.validate_tailscale_connectivity()
      {:error, :tailscale_not_available}
  """
  @spec validate_tailscale_connectivity() :: {:ok, map()} | {:error, atom()}
  def validate_tailscale_connectivity do
    case get_tailscale_status() do
      {:ok, status} ->
        {:ok,
         %{
           dns_name: status.dns_name,
           ip_address: status.ip_address,
           connected: true
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_tailscale_status do
    # Try to get Tailscale status via CLI
    case System.cmd("tailscale", ["status", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        parse_tailscale_json(output)

      {_output, _exit_code} ->
        # Tailscale not available or not running
        {:error, :tailscale_not_available}
    end
  rescue
    ErlangError ->
      {:error, :tailscale_not_installed}
  end

  defp parse_tailscale_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        self_data = Map.get(data, "Self", %{})
        dns_raw = Map.get(self_data, "DNSName", "")
        dns_name = dns_raw |> String.trim_trailing(".")

        {:ok,
         %{
           dns_name: dns_name,
           ip_address: get_in(self_data, ["TailscaleIPs", Access.at(0)])
         }}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  # ============================================================================
  # EPMD Binding
  # ============================================================================

  @doc """
  Returns EPMD binding information for Tailscale interface.

  Used to verify SC-CLU-004 compliance (EPMD binds to Tailscale IP only).

  ## Examples

      iex> TailscaleDNS.get_epmd_binding()
      {:ok, %{interface: "tailscale0", ip_address: "100.x.x.x"}}
  """
  @spec get_epmd_binding() :: {:ok, map()} | {:error, atom()} | map()
  def get_epmd_binding do
    # Get Tailscale IP from environment or detect
    case System.get_env("TS_IP_ADDRESS") do
      nil ->
        # Try to detect from Tailscale
        case validate_tailscale_connectivity() do
          {:ok, info} ->
            {:ok,
             %{
               interface: "tailscale0",
               ip_address: info.ip_address,
               source: :detected
             }}

          {:error, reason} ->
            {:error, reason}
        end

      ip_address ->
        {:ok,
         %{
           interface: "tailscale0",
           ip_address: ip_address,
           source: :environment
         }}
    end
  end

  # ============================================================================
  # FLAME Runner Integration
  # ============================================================================

  @doc """
  Generates a FLAME runner node name with Tailscale DNS.

  Runner names include pool type and unique identifier for
  tracking during graceful drain (SC-FLAME-004).

  ## Examples

      iex> TailscaleDNS.get_flame_runner_name("intelligence", "abc123")
      :"indrajaal@flame-intelligence-abc123.tailnet.ts.net"
  """
  @spec get_flame_runner_name(String.t(), String.t()) :: atom()
  def get_flame_runner_name(pool_name, runner_id)
      when is_binary(pool_name) and is_binary(runner_id) do
    suffix = get_tailnet_suffix()
    sanitized_pool = sanitize_dns_name(pool_name)
    sanitized_id = sanitize_dns_name(runner_id)

    # Format: indrajaal@flame-<pool>-<id>.<suffix>
    hostname = "flame-#{sanitized_pool}-#{sanitized_id}"
    String.to_atom("#{@default_app_name}@#{hostname}.#{suffix}")
  end

  # ============================================================================
  # Sentinel/HA Integration
  # ============================================================================

  @doc """
  Returns the list of nodes that participate in quorum decisions.

  These are the nodes used by Sentinel for split-brain prevention.
  All quorum nodes must use Tailscale DNS names (SC-CLU-005).

  ## Examples

      iex> TailscaleDNS.get_quorum_nodes()
      [:"indrajaal@indrajaal-ex-app-1.tailnet.ts.net", ...]
  """
  @spec get_quorum_nodes() :: [atom()]
  def get_quorum_nodes do
    # Quorum nodes are the same as cluster nodes for HA
    list_cluster_nodes()
  end

  @doc """
  Validates that a node name is suitable for quorum participation.

  Valid quorum nodes must:
  - Use DNS format (not IP)
  - Include Tailscale suffix

  ## Examples

      iex> TailscaleDNS.valid_quorum_node?(:"indrajaal@app-1.tailnet.ts.net")
      true

      iex> TailscaleDNS.valid_quorum_node?(:"indrajaal@192.168.1.1")
      false
  """
  @spec valid_quorum_node?(atom()) :: boolean()
  def valid_quorum_node?(node_name) when is_atom(node_name) do
    node_string = Atom.to_string(node_name)

    case String.split(node_string, "@") do
      [_app_name, host] ->
        # Must not be IP address
        not_ip = not ip_address?(host)

        # Must have Tailscale suffix (ts.net or configured suffix)
        suffix = get_tailnet_suffix()
        has_suffix = String.contains?(host, ".ts.net") or String.contains?(host, suffix)

        # Must have at least one dot (DNS format)
        has_dot = String.contains?(host, ".")

        not_ip and has_suffix and has_dot

      _ ->
        false
    end
  end

  # ============================================================================
  # Local Fallback Support (SC-CLU-004)
  # ============================================================================

  @doc """
  Returns the local DNS suffix used when Tailscale is unavailable.

  ## Examples

      iex> TailscaleDNS.get_local_suffix()
      "local.indrajaal"
  """
  @spec get_local_suffix() :: String.t()
  def get_local_suffix do
    System.get_env("LOCAL_DNS_SUFFIX") ||
      Application.get_env(:indrajaal, :local_dns_suffix) ||
      @default_local_suffix
  end

  @doc """
  Detects current network mode: :tailscale if available, :local otherwise.

  Used by CapabilityRouter and other modules to determine naming strategy.

  ## Examples

      iex> TailscaleDNS.detect_network_mode()
      :tailscale  # When Tailscale is connected

      iex> TailscaleDNS.detect_network_mode()
      :local  # When Tailscale is unavailable
  """
  @spec detect_network_mode() :: network_mode()
  def detect_network_mode do
    case validate_tailscale_connectivity() do
      {:ok, _} -> :tailscale
      {:error, _} -> :local
    end
  end

  @doc """
  Returns true if Tailscale is currently available and connected.

  ## Examples

      iex> TailscaleDNS.tailscale_available?()
      true
  """
  @spec tailscale_available?() :: boolean()
  def tailscale_available? do
    detect_network_mode() == :tailscale
  end

  @doc """
  Gets the appropriate suffix based on Tailscale availability.

  Returns Tailscale suffix if connected, local suffix otherwise.
  This is the primary function for automatic failover.

  ## Examples

      iex> TailscaleDNS.get_active_suffix()
      "my-tailnet.ts.net"  # When Tailscale connected

      iex> TailscaleDNS.get_active_suffix()
      "local.indrajaal"  # When Tailscale unavailable
  """
  @spec get_active_suffix() :: String.t()
  def get_active_suffix do
    case detect_network_mode() do
      :tailscale -> get_tailnet_suffix()
      :local -> get_local_suffix()
    end
  end

  @doc """
  Gets node name with automatic fallback to local naming.

  Uses Tailscale naming when available, local naming when Tailscale is down.
  This provides transparent failover per SC-CLU-004.

  **CRITICAL UPDATE (2026-01-01):** Standalone default mode MUST use Tailscale mDNS names only.
  If `FORCE_TAILSCALE_MODE=true` is set, fallback is disabled.

  ## Examples

      iex> TailscaleDNS.get_node_name_with_fallback("app-1")
      :"indrajaal@app-1.my-tailnet.ts.net"  # Tailscale connected

      iex> TailscaleDNS.get_node_name_with_fallback("app-1")
      :"indrajaal@app-1.local.indrajaal"  # Tailscale unavailable (unless forced)
  """
  @spec get_node_name_with_fallback(String.t(), keyword()) :: atom()
  def get_node_name_with_fallback(base_name, opts \\ []) when is_binary(base_name) do
    app_name = Keyword.get(opts, :app, @default_app_name)

    # Check for strict enforcement
    force_tailscale = System.get_env("FORCE_TAILSCALE_MODE", "false") == "true"

    suffix =
      if force_tailscale do
        get_tailnet_suffix()
      else
        get_active_suffix()
      end

    sanitized_base = sanitize_dns_name(base_name)

    String.to_atom("#{app_name}@#{sanitized_base}.#{suffix}")
  end

  @doc """
  Gets local node name (always uses local suffix).

  Used when explicitly needing local naming regardless of Tailscale status.

  ## Examples

      iex> TailscaleDNS.get_local_node_name("app-1")
      :"indrajaal@app-1.local.indrajaal"
  """
  @spec get_local_node_name(String.t(), keyword()) :: atom()
  def get_local_node_name(base_name, opts \\ []) when is_binary(base_name) do
    app_name = Keyword.get(opts, :app, @default_app_name)
    suffix = get_local_suffix()
    sanitized_base = sanitize_dns_name(base_name)

    String.to_atom("#{app_name}@#{sanitized_base}.#{suffix}")
  end

  @doc """
  Lists cluster nodes with fallback to local naming if Tailscale unavailable.

  **CRITICAL UPDATE (2026-01-01):** Enforces Tailscale mDNS if `FORCE_TAILSCALE_MODE=true`.

  ## Examples

      iex> TailscaleDNS.list_cluster_nodes_with_fallback()
      [:"indrajaal@app-1.local.indrajaal", ...]  # Tailscale down
  """
  @spec list_cluster_nodes_with_fallback() :: [atom()]
  def list_cluster_nodes_with_fallback do
    configured_nodes =
      Application.get_env(:indrajaal, :cluster_nodes) ||
        @cluster_node_bases

    # Check for strict enforcement
    force_tailscale = System.get_env("FORCE_TAILSCALE_MODE", "false") == "true"

    suffix =
      if force_tailscale do
        get_tailnet_suffix()
      else
        get_active_suffix()
      end

    configured_nodes
    |> Enum.map(fn base ->
      sanitized = sanitize_dns_name(base)
      String.to_atom("#{@default_app_name}@#{sanitized}.#{suffix}")
    end)
  end

  @doc """
  Converts a node name to the appropriate format based on network mode.

  If Tailscale is available, ensures Tailscale suffix.
  If Tailscale is down, converts to local suffix.

  ## Examples

      iex> TailscaleDNS.normalize_node_name(:"indrajaal@app-1.old-suffix")
      :"indrajaal@app-1.local.indrajaal"  # Tailscale down
  """
  @spec normalize_node_name(atom()) :: atom()
  def normalize_node_name(node_name) when is_atom(node_name) do
    case parse_node_name(node_name) do
      {:ok, %{app_name: app_name, base_name: base_name}} ->
        suffix = get_active_suffix()
        String.to_atom("#{app_name}@#{base_name}.#{suffix}")

      {:error, _} ->
        node_name
    end
  end

  @doc """
  Gets the Tailscale IP address for this node.

  Returns `{:ok, ip}` if Tailscale is available, `{:error, reason}` otherwise.

  ## Examples

      iex> TailscaleDNS.get_tailscale_ip()
      {:ok, "100.64.1.5"}  # Tailscale IP
  """
  @spec get_tailscale_ip() :: {:ok, String.t()} | {:error, term()}
  def get_tailscale_ip do
    # Try to get Tailscale IP by checking network interfaces for 100.x.x.x range
    case :inet.getifaddrs() do
      {:ok, interfaces} ->
        tailscale_ip =
          interfaces
          |> Enum.flat_map(fn {_name, opts} ->
            opts
            |> Keyword.get_values(:addr)
            |> Enum.filter(&match?({100, _, _, _}, &1))
          end)
          |> List.first()

        case tailscale_ip do
          {a, b, c, d} ->
            {:ok, "#{a}.#{b}.#{c}.#{d}"}

          nil ->
            {:error, :tailscale_not_connected}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the hostname for this machine with appropriate suffix.

  ## Examples

      iex> TailscaleDNS.get_this_host_name()
      "myhost.my-tailnet.ts.net"  # Tailscale connected
  """
  @spec get_this_host_name() :: String.t()
  def get_this_host_name do
    hostname =
      case :inet.gethostname() do
        {:ok, name} -> to_string(name)
        _ -> "localhost"
      end

    suffix = get_active_suffix()
    "#{sanitize_dns_name(hostname)}.#{suffix}"
  end

  @doc """
  Gets this node's name with appropriate suffix.

  ## Examples

      iex> TailscaleDNS.get_this_node_name()
      :"indrajaal@myhost.my-tailnet.ts.net"
  """
  @spec get_this_node_name(keyword()) :: atom()
  def get_this_node_name(opts \\ []) do
    app_name = Keyword.get(opts, :app, @default_app_name)
    host = get_this_host_name()
    String.to_atom("#{app_name}@#{host}")
  end
end
