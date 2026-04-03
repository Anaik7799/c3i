defmodule Indrajaal.Distributed.Mesh.Discovery do
  @moduledoc """
  Peer Discovery - Node Discovery Mechanisms for v20.0.0

  Implements multiple discovery mechanisms:
  - DNS-based discovery
  - Multicast/broadcast discovery
  - Seed node discovery
  - Kubernetes-style discovery

  ## Discovery Model

  Discovery sources:
  - Static: Configured seed nodes
  - Dynamic: DNS SRV/TXT records
  - Local: Multicast on LAN
  - Cloud: Service discovery APIs

  ## Discovery Flow
  1. Bootstrap from seeds
  2. Query DNS for service records
  3. Listen for multicast announcements
  4. Periodically refresh

  ## STAMP Constraints
  - SC-DIS-001: Discovery MUST timeout after 30s
  - SC-DIS-002: Multiple discovery methods MUST be tried
  - SC-DIS-003: Discovered nodes MUST be validated
  - SC-DIS-004: Discovery cache MUST expire
  """

  use GenServer
  require Logger

  @type node_id :: String.t()
  @type discovery_method :: :seed | :dns | :multicast | :kubernetes

  @type discovered_node :: %{
          id: node_id(),
          address: String.t(),
          port: non_neg_integer(),
          method: discovery_method(),
          discovered_at: DateTime.t(),
          validated: boolean()
        }

  @type state :: %{
          discovered: map(),
          seeds: [{String.t(), non_neg_integer()}],
          dns_domain: String.t() | nil,
          config: map()
        }

  # Discovery timeout
  @discovery_timeout 30_000

  # Cache expiry (1 hour)
  @cache_expiry 3_600_000

  # Refresh interval
  @refresh_interval 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Discovers peers using all configured methods.
  """
  @spec discover() :: {:ok, [discovered_node()]} | {:error, term()}
  def discover do
    GenServer.call(__MODULE__, :discover, @discovery_timeout)
  end

  @doc """
  Discovers peers using a specific method.
  """
  @spec discover(discovery_method()) :: {:ok, [discovered_node()]} | {:error, term()}
  def discover(method) do
    GenServer.call(__MODULE__, {:discover, method}, @discovery_timeout)
  end

  @doc """
  Adds a seed node.
  """
  @spec add_seed(String.t(), non_neg_integer()) :: :ok
  def add_seed(address, port) do
    GenServer.cast(__MODULE__, {:add_seed, address, port})
  end

  @doc """
  Removes a seed node.
  """
  @spec remove_seed(String.t(), non_neg_integer()) :: :ok
  def remove_seed(address, port) do
    GenServer.cast(__MODULE__, {:remove_seed, address, port})
  end

  @doc """
  Gets currently discovered nodes.
  """
  @spec get_discovered() :: [discovered_node()]
  def get_discovered do
    GenServer.call(__MODULE__, :get_discovered)
  end

  @doc """
  Validates a discovered node.
  """
  @spec validate(node_id()) :: {:ok, :valid} | {:error, term()}
  def validate(node_id) do
    GenServer.call(__MODULE__, {:validate, node_id})
  end

  @doc """
  Clears discovery cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end

  @doc """
  Gets discovery statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      discovered: %{},
      seeds: Keyword.get(opts, :seeds, []),
      dns_domain: Keyword.get(opts, :dns_domain),
      multicast_group: Keyword.get(opts, :multicast_group, {224, 0, 0, 251}),
      multicast_port: Keyword.get(opts, :multicast_port, 5353),
      stats: %{
        discoveries: 0,
        validations: 0,
        failures: 0
      },
      config: %{
        methods: Keyword.get(opts, :methods, [:seed, :dns]),
        auto_refresh: Keyword.get(opts, :auto_refresh, true),
        validate_on_discover: Keyword.get(opts, :validate_on_discover, true)
      }
    }

    # Start refresh timer
    if state.config.auto_refresh do
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    # Start cache expiry timer
    Process.send_after(self(), :expire_cache, @cache_expiry)

    Logger.info("🔍 Discovery service started")

    {:ok, state}
  end

  @impl true
  def handle_call(:discover, _from, state) do
    # Try all configured methods
    results =
      state.config.methods
      |> Enum.flat_map(fn method ->
        case discover_by_method(method, state) do
          {:ok, nodes} -> nodes
          {:error, _} -> []
        end
      end)

    # Validate if configured
    validated_results =
      if state.config.validate_on_discover do
        Enum.map(results, fn node ->
          case validate_node(node) do
            {:ok, _} -> %{node | validated: true}
            {:error, _} -> %{node | validated: false}
          end
        end)
      else
        results
      end

    # Update discovered cache
    new_discovered =
      Enum.reduce(validated_results, state.discovered, fn node, acc ->
        Map.put(acc, node.id, node)
      end)

    # Update stats
    new_stats = %{state.stats | discoveries: state.stats.discoveries + length(validated_results)}

    {:reply, {:ok, validated_results}, %{state | discovered: new_discovered, stats: new_stats}}
  end

  @impl true
  def handle_call({:discover, method}, _from, state) do
    case discover_by_method(method, state) do
      {:ok, nodes} ->
        new_discovered =
          Enum.reduce(nodes, state.discovered, fn node, acc ->
            Map.put(acc, node.id, node)
          end)

        {:reply, {:ok, nodes}, %{state | discovered: new_discovered}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_discovered, _from, state) do
    nodes = Map.values(state.discovered)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:validate, node_id}, _from, state) do
    case Map.get(state.discovered, node_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      node ->
        case validate_node(node) do
          {:ok, _} ->
            updated = %{node | validated: true}
            new_discovered = Map.put(state.discovered, node_id, updated)
            new_stats = %{state.stats | validations: state.stats.validations + 1}
            {:reply, {:ok, :valid}, %{state | discovered: new_discovered, stats: new_stats}}

          {:error, reason} ->
            new_stats = %{state.stats | failures: state.stats.failures + 1}
            {:reply, {:error, reason}, %{state | stats: new_stats}}
        end
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        discovered_count: map_size(state.discovered),
        validated_count: Enum.count(state.discovered, fn {_, n} -> n.validated end),
        seed_count: length(state.seeds)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:add_seed, address, port}, state) do
    new_seeds = [{address, port} | state.seeds] |> Enum.uniq()
    {:noreply, %{state | seeds: new_seeds}}
  end

  @impl true
  def handle_cast({:remove_seed, address, port}, state) do
    new_seeds = Enum.reject(state.seeds, fn {a, p} -> a == address and p == port end)
    {:noreply, %{state | seeds: new_seeds}}
  end

  @impl true
  def handle_cast(:clear_cache, state) do
    {:noreply, %{state | discovered: %{}}}
  end

  @impl true
  def handle_info(:refresh, state) do
    # Trigger discovery refresh
    send(self(), :do_refresh)

    # Schedule next refresh
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:do_refresh, state) do
    # Discover in background
    Task.start(fn ->
      GenServer.call(__MODULE__, :discover)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:expire_cache, state) do
    now = DateTime.utc_now()
    expiry_threshold = DateTime.add(now, -@cache_expiry, :millisecond)

    # Remove expired entries
    filtered =
      Enum.filter(state.discovered, fn {_, node} ->
        DateTime.compare(node.discovered_at, expiry_threshold) == :gt
      end)

    new_discovered = filtered |> Map.new()

    # Schedule next expiry
    Process.send_after(self(), :expire_cache, @cache_expiry)

    {:noreply, %{state | discovered: new_discovered}}
  end

  # Private helpers

  defp discover_by_method(:seed, state) do
    nodes =
      Enum.map(state.seeds, fn {address, port} ->
        %{
          id: generate_node_id(address, port),
          address: address,
          port: port,
          method: :seed,
          discovered_at: DateTime.utc_now(),
          validated: false
        }
      end)

    {:ok, nodes}
  end

  defp discover_by_method(:dns, state) do
    case state.dns_domain do
      nil ->
        {:error, :no_dns_domain}

      domain ->
        # Query DNS SRV records
        case dns_srv_lookup(domain) do
          {:ok, records} ->
            nodes =
              Enum.map(records, fn {address, port} ->
                %{
                  id: generate_node_id(address, port),
                  address: address,
                  port: port,
                  method: :dns,
                  discovered_at: DateTime.utc_now(),
                  validated: false
                }
              end)

            {:ok, nodes}

          error ->
            error
        end
    end
  end

  defp discover_by_method(:multicast, state) do
    # Send multicast discovery request
    case multicast_discover(state.multicast_group, state.multicast_port) do
      {:ok, responses} ->
        nodes =
          Enum.map(responses, fn {address, port} ->
            %{
              id: generate_node_id(address, port),
              address: address,
              port: port,
              method: :multicast,
              discovered_at: DateTime.utc_now(),
              validated: false
            }
          end)

        {:ok, nodes}

      error ->
        error
    end
  end

  defp discover_by_method(:kubernetes, _state) do
    # Query Kubernetes endpoints
    case kubernetes_endpoints() do
      {:ok, endpoints} ->
        nodes =
          Enum.map(endpoints, fn {address, port} ->
            %{
              id: generate_node_id(address, port),
              address: address,
              port: port,
              method: :kubernetes,
              discovered_at: DateTime.utc_now(),
              validated: false
            }
          end)

        {:ok, nodes}

      error ->
        error
    end
  end

  defp discover_by_method(method, _state) do
    {:error, {:unknown_method, method}}
  end

  defp generate_node_id(address, port) do
    hash = :crypto.hash(:sha256, "#{address}:#{port}")
    encoded = Base.encode16(hash, case: :lower)
    "node_#{encoded |> String.slice(0, 16)}"
  end

  defp validate_node(node) do
    # Try to connect and verify
    # Simplified - in production would do actual connection test
    case :gen_tcp.connect(String.to_charlist(node.address), node.port, [], 5000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        {:ok, :valid}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:ok, :valid}
  end

  defp dns_srv_lookup(domain) do
    start_time = System.monotonic_time(:microsecond)

    Logger.debug("[Discovery] DNS SRV lookup for domain: #{domain}")

    result =
      try do
        charlist_domain = String.to_charlist(domain)

        case :inet_res.lookup(charlist_domain, :in, :srv) do
          [] ->
            Logger.debug("[Discovery] DNS SRV: no records for #{domain}")
            {:ok, []}

          records when is_list(records) ->
            peers =
              Enum.flat_map(records, fn
                {_priority, _weight, port, host} when is_list(host) ->
                  host_str = List.to_string(host)
                  Logger.debug("[Discovery] DNS SRV record: #{host_str}:#{port}")
                  [{host_str, port}]

                {_priority, _weight, port, host} when is_tuple(host) ->
                  # inet address tuple e.g. {127, 0, 0, 1}
                  host_str = host |> Tuple.to_list() |> Enum.join(".")
                  Logger.debug("[Discovery] DNS SRV record (ip): #{host_str}:#{port}")
                  [{host_str, port}]

                other ->
                  Logger.warning(
                    "[Discovery] DNS SRV unexpected record format: #{inspect(other)}"
                  )

                  []
              end)

            Logger.info("[Discovery] DNS SRV found #{length(peers)} peer(s) for #{domain}")
            {:ok, peers}
        end
      rescue
        error ->
          Logger.warning("[Discovery] DNS SRV lookup failed for #{domain}: #{inspect(error)}")
          {:ok, []}
      catch
        :exit, reason ->
          Logger.warning("[Discovery] DNS SRV lookup exited for #{domain}: #{inspect(reason)}")
          {:ok, []}
      end

    duration_us = System.monotonic_time(:microsecond) - start_time

    {peer_count, status} =
      case result do
        {:ok, peers} -> {length(peers), :ok}
        _ -> {0, :error}
      end

    :telemetry.execute(
      [:indrajaal, :distributed, :mesh, :discovery, :dns_srv],
      %{duration_us: duration_us, peer_count: peer_count},
      %{domain: domain, status: status}
    )

    result
  end

  defp multicast_discover(group, port) do
    start_time = System.monotonic_time(:microsecond)

    Logger.debug("[Discovery] Multicast discovery on group #{inspect(group)} port #{port}")

    result =
      try do
        udp_opts = [
          :binary,
          active: false,
          reuseaddr: true,
          multicast_loop: false,
          add_membership: {group, {0, 0, 0, 0}}
        ]

        case :gen_udp.open(port, udp_opts) do
          {:ok, socket} ->
            node_identity = %{
              node: node() |> Atom.to_string(),
              host: node() |> Atom.to_string() |> String.split("@") |> List.last(),
              port: port,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }

            probe = Jason.encode!(node_identity)

            # Send multicast probe
            case :gen_udp.send(socket, group, port, probe) do
              :ok ->
                Logger.debug("[Discovery] Multicast probe sent, waiting for responses (2s)")

              {:error, send_err} ->
                Logger.warning("[Discovery] Multicast probe send failed: #{inspect(send_err)}")
            end

            # Collect responses for 2 seconds
            peers = collect_multicast_responses(socket, 2_000, [])

            :gen_udp.close(socket)

            Logger.info("[Discovery] Multicast found #{length(peers)} peer(s)")
            {:ok, peers}

          {:error, reason} ->
            Logger.warning(
              "[Discovery] Could not open UDP socket on port #{port}: #{inspect(reason)}"
            )

            {:ok, []}
        end
      rescue
        error ->
          Logger.warning("[Discovery] Multicast discover failed: #{inspect(error)}")
          {:ok, []}
      catch
        :exit, reason ->
          Logger.warning("[Discovery] Multicast discover exited: #{inspect(reason)}")
          {:ok, []}
      end

    duration_us = System.monotonic_time(:microsecond) - start_time

    {peer_count, status} =
      case result do
        {:ok, peers} -> {length(peers), :ok}
        _ -> {0, :error}
      end

    :telemetry.execute(
      [:indrajaal, :distributed, :mesh, :discovery, :multicast],
      %{duration_us: duration_us, peer_count: peer_count},
      %{group: inspect(group), port: port, status: status}
    )

    result
  end

  # Collect UDP responses until timeout is exhausted.
  # Each response is expected to carry a JSON body with at least
  # "host" and "port" fields identifying the responding peer.
  defp collect_multicast_responses(_socket, remaining_ms, acc) when remaining_ms <= 0 do
    Enum.uniq(acc)
  end

  defp collect_multicast_responses(socket, remaining_ms, acc) do
    tick = min(remaining_ms, 200)

    case :gen_udp.recv(socket, 0, tick) do
      {:ok, {_src_addr, _src_port, data}} ->
        entry =
          try do
            payload = Jason.decode!(data)
            host = Map.get(payload, "host")
            peer_port = Map.get(payload, "port")

            if is_binary(host) and is_integer(peer_port) do
              [{host, peer_port}]
            else
              []
            end
          rescue
            _ -> []
          end

        collect_multicast_responses(socket, remaining_ms - tick, acc ++ entry)

      {:error, :timeout} ->
        collect_multicast_responses(socket, remaining_ms - tick, acc)

      {:error, reason} ->
        Logger.debug("[Discovery] Multicast recv error: #{inspect(reason)}")
        Enum.uniq(acc)
    end
  end

  defp kubernetes_endpoints do
    start_time = System.monotonic_time(:microsecond)

    Logger.debug("[Discovery] Kubernetes endpoints discovery")

    result =
      try do
        token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"

        k8s_host = System.get_env("KUBERNETES_SERVICE_HOST")
        k8s_port = System.get_env("KUBERNETES_SERVICE_PORT", "443")
        namespace_path = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"

        cond do
          is_nil(k8s_host) ->
            Logger.debug("[Discovery] Not in Kubernetes (KUBERNETES_SERVICE_HOST not set)")
            {:ok, []}

          not File.exists?(token_path) ->
            Logger.debug(
              "[Discovery] Kubernetes service account token not found at #{token_path}"
            )

            {:ok, []}

          true ->
            token = File.read!(token_path) |> String.trim()

            namespace =
              if File.exists?(namespace_path) do
                File.read!(namespace_path) |> String.trim()
              else
                System.get_env("POD_NAMESPACE", "default")
              end

            service_name = System.get_env("K8S_SERVICE_NAME", "indrajaal")

            url =
              "https://#{k8s_host}:#{k8s_port}/api/v1/namespaces/#{namespace}/endpoints/#{service_name}"

            Logger.debug("[Discovery] Querying K8s endpoints: #{url}")

            :httpc.set_options([])

            case :httpc.request(
                   :get,
                   {String.to_charlist(url),
                    [
                      {~c"Authorization", String.to_charlist("Bearer #{token}")},
                      {~c"Accept", ~c"application/json"}
                    ]},
                   [ssl: [{:verify, :verify_none}], timeout: 5_000],
                   []
                 ) do
              {:ok, {{_, 200, _}, _headers, body}} ->
                body_str = List.to_string(body)

                case Jason.decode(body_str) do
                  {:ok, %{"subsets" => subsets}} when is_list(subsets) ->
                    peers =
                      Enum.flat_map(subsets, fn subset ->
                        addresses = Map.get(subset, "addresses", [])
                        ports = Map.get(subset, "ports", [])

                        default_port =
                          case ports do
                            [%{"port" => p} | _] when is_integer(p) -> p
                            _ -> 4000
                          end

                        Enum.map(addresses, fn addr ->
                          ip = Map.get(addr, "ip", "")
                          {ip, default_port}
                        end)
                        |> Enum.reject(fn {ip, _} -> ip == "" end)
                      end)

                    Logger.info("[Discovery] Kubernetes found #{length(peers)} endpoint(s)")
                    {:ok, peers}

                  {:ok, _other} ->
                    Logger.debug("[Discovery] Kubernetes response has no subsets")
                    {:ok, []}

                  {:error, decode_err} ->
                    Logger.warning(
                      "[Discovery] Kubernetes response JSON decode failed: #{inspect(decode_err)}"
                    )

                    {:ok, []}
                end

              {:ok, {{_, status, _}, _headers, _body}} ->
                Logger.warning("[Discovery] Kubernetes endpoints API returned HTTP #{status}")
                {:ok, []}

              {:error, http_err} ->
                Logger.warning("[Discovery] Kubernetes HTTP request failed: #{inspect(http_err)}")
                {:ok, []}
            end
        end
      rescue
        error ->
          Logger.warning("[Discovery] Kubernetes endpoints discovery failed: #{inspect(error)}")
          {:ok, []}
      catch
        :exit, reason ->
          Logger.warning("[Discovery] Kubernetes endpoints exited: #{inspect(reason)}")
          {:ok, []}
      end

    duration_us = System.monotonic_time(:microsecond) - start_time

    {peer_count, status} =
      case result do
        {:ok, peers} -> {length(peers), :ok}
        _ -> {0, :error}
      end

    :telemetry.execute(
      [:indrajaal, :distributed, :mesh, :discovery, :kubernetes],
      %{duration_us: duration_us, peer_count: peer_count},
      %{status: status}
    )

    result
  end
end
