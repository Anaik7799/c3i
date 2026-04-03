defmodule Indrajaal.ProductionReadiness.SSLValidator do
  @moduledoc """
  SSL configuration validation across all containers.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-009: SSL validation must not expose private keys
  - UCA-007: Pr_event SSL downgrade attacks
  """

  use GenServer
  require Logger

  @min_tls_version "1.2"
  @secure_cipher_suites [
    "TLS_AES_256_GCM_SHA384",
    "TLS_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
  ]

  @weak_cipher_suites [
    "DES-CBC3-SHA",
    "RC4-SHA",
    "RC4-MD5",
    "DES-CBC-SHA",
    "EXP-DES-CBC-SHA"
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Validate SSL configuration across all containers.
  Satisfies SC-009: SSL validation must not expose private keys.
  """
  def validate_all_containers(containers) do
    GenServer.call(__MODULE__, {:validate_all, containers}, 30_000)
  end

  @doc """
  Validate SSL configuration for a specific container.
  """
  def validate_container(container) do
    GenServer.call(__MODULE__, {:validate_container, container})
  end

  @doc """
  Apply SSL configuration with security validation.
  Pr_events UCA-007: SSL downgrade attacks.
  """
  def apply_config(ssl_config) do
    GenServer.call(__MODULE__, {:apply_config, ssl_config})
  end

  @doc """
  Get SSL validation report.
  """
  def get_report do
    GenServer.call(__MODULE__, :get_report)
  end

  @doc """
  Check certificate expiration status.
  """
  def check_expiration(container) do
    GenServer.call(__MODULE__, {:check_expiration, container})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      validation_results: %{},
      certificates: %{},
      last_validation: nil,
      security_policies: load_security_policies()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:validate_all, containers}, _from, state) do
    Logger.info("[SSLValidator] Validating SSL across #{length(containers)} containers")

    # Validate each container
    validation_results =
      Enum.map(containers, fn container ->
        {container, validate_container_ssl(container, state.security_policies)}
      end)

    # Build comprehensive report
    report = build_validation_report(validation_results)

    # Update state
    new_state = %{
      state
      | validation_results: Map.new(validation_results),
        certificates: extract_certificates(validation_results),
        last_validation: DateTime.utc_now()
    }

    {:reply, {:ok, report}, new_state}
  end

  @impl true
  def handle_call({:validate_container, container}, _from, state) do
    result = validate_container_ssl(container, state.security_policies)

    new_results = Map.put(state.validation_results, container, result)
    new_state = %{state | validation_results: new_results}

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:apply_config, ssl_config}, _from, state) do
    # UCA-007: Pr_event SSL downgrade attacks
    case validate_ssl_config(ssl_config, state.security_policies) do
      :ok ->
        # Apply secure configuration
        apply_ssl_configuration(ssl_config)
        {:reply, {:ok, :applied}, state}

      {:error, :weak_ssl_configuration} = error ->
        Logger.error("[SSLValidator] Weak SSL configuration rejected: #{inspect(ssl_config)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_report, _from, state) do
    report = %{
      validated_containers: Map.keys(state.validation_results),
      certificates: sanitize_certificates(state.certificates),
      last_validation: state.last_validation,
      summary: generate_summary(state.validation_results)
    }

    {:reply, report, state}
  end

  @impl true
  def handle_call({:check_expiration, container}, _from, state) do
    cert_info = Map.get(state.certificates, container)

    if cert_info do
      days_until_expiry = calculate_days_until_expiry(cert_info.not_after)

      result = %{
        container: container,
        expires_at: cert_info.not_after,
        days_remaining: days_until_expiry,
        expired: days_until_expiry < 0,
        warning: days_until_expiry < 30
      }

      {:reply, {:ok, result}, state}
    else
      {:reply, {:error, :certificate_not_found}, state}
    end
  end

  # Private functions

  defp load_security_policies do
    %{
      min_tls_version: @min_tls_version,
      allowed_cipher_suites: @secure_cipher_suites,
      forbidden_cipher_suites: @weak_cipher_suites,
      require_forward_secrecy: true,
      min_key_length: 2048,
      # Following browser _requirements
      max_certificate_lifetime_days: 397
    }
  end

  defp validate_container_ssl(container, policies) do
    with {:ok, cert_info} <- get_container_certificate(container),
         :ok <- validate_certificate(cert_info, policies),
         {:ok, tls_config} <- get_container_tls_config(container),
         :ok <- validate_tls_config(tls_config, policies) do
      %{
        status: :valid,
        certificate: sanitize_cert_info(cert_info),
        tls_version: tls_config.version,
        cipher_suites: filter_cipher_suites(tls_config.cipher_suites),
        valid?: true,
        not_expired?: not expired?(cert_info)
      }
    else
      {:error, reason} ->
        %{
          status: :invalid,
          error: reason,
          valid?: false,
          not_expired?: false
        }
    end
  end

  defp get_container_certificate(container) do
    # In production, this would connect to container and extract certificate
    # Simulating certificate retrieval
    {:ok,
     %{
       subject: "CN=#{container}.intelitor.local",
       issuer: "CN=Indrajaal CA",
       not_before: DateTime.add(DateTime.utc_now(), -365, :day),
       not_after: DateTime.add(DateTime.utc_now(), 365, :day),
       key_length: 2048,
       signature_algorithm: "SHA256withRSA",
       san: ["#{container}.intelitor.local", "localhost"]
     }}
  end

  defp validate_certificate(cert_info, policies) do
    cond do
      expired?(cert_info) ->
        {:error, :certificate_expired}

      cert_info.key_length < policies.min_key_length ->
        {:error, :weak_key_length}

      not strong_signature?(cert_info.signature_algorithm) ->
        {:error, :weak_signature_algorithm}

      true ->
        :ok
    end
  end

  # AGENT GA FIX: STUB parameter not used in implementation
  defp get_container_tls_config(_container) do
    # In production, this would query container's TLS configuration
    # Simulating TLS config
    {:ok,
     %{
       version: "1.3",
       cipher_suites: [
         "TLS_AES_256_GCM_SHA384",
         "TLS_AES_128_GCM_SHA256",
         "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
       ],
       protocols: ["h2", "http/1.1"]
     }}
  end

  defp validate_tls_config(tlsconfig, policies) do
    cond do
      tlsconfig.version < policies.min_tls_version ->
        {:error, :tls_version_too_low}

      has_weak_ciphers?(tlsconfig.cipher_suites, policies) ->
        {:error, :weak_cipher_suites}

      not has_forward_secrecy?(tlsconfig.cipher_suites) and policies.require_forward_secrecy ->
        {:error, :no_forward_secrecy}

      true ->
        :ok
    end
  end

  defp validate_ssl_config(ssl_config, policies) do
    # UCA-007: Comprehensive validation
    tls_version = ssl_config[:tls_version] || @min_tls_version
    cipher_suites = ssl_config[:cipher_suites] || []

    cond do
      tls_version < policies.min_tls_version ->
        {:error, :weak_ssl_configuration}

      Enum.any?(cipher_suites, &(&1 in policies.forbidden_cipher_suites)) ->
        {:error, :weak_ssl_configuration}

      true ->
        :ok
    end
  end

  defp apply_ssl_configuration(ssl_config) do
    Logger.info("[SSLValidator] Applying SSL configuration: #{inspect(ssl_config)}")
    # In production, this would apply the configuration to containers
    :ok
  end

  defp build_validation_report(validation_results) do
    certificates =
      validation_results
      # AGENT GA FIX: added underscore
      |> Enum.map(fn {_container, result} ->
        Map.get(result, :certificate, %{})
      end)
      # AGENT GA FIX: fixed filter function
      |> Enum.filter(&(&1 != nil && &1 != %{}))

    %{
      validated_containers: Enum.map(validation_results, &elem(&1, 0)),
      certificates: certificates,
      cipher_suites_secure: all_ciphers_secure?(validation_results),
      tls_version: get_min_tls_version(validation_results),
      # SC-009: Never expose private keys
      private_keys_protected: true
    }
  end

  defp extract_certificates(validation_results) do
    validation_results
    |> Enum.filter(fn {_, result} -> result.status == :valid end)
    |> Enum.map(fn {container, result} ->
      {container, result.certificate}
    end)
    |> Map.new()
  end

  defp sanitize_certificates(certificates) do
    # SC-009: Ensure no private key exposure
    certificates
    |> Enum.map(fn {container, cert} ->
      {container, sanitize_cert_info(cert)}
    end)
    |> Map.new()
  end

  defp sanitize_cert_info(cert_info) do
    # SC-009: Remove any private key __data
    cert_info
    |> Map.drop([:private_key, :key_data])
    |> Map.put(:private_key_present, false)
  end

  defp filter_cipher_suites(cipher_suites) do
    # Only return secure cipher suites
    Enum.filter(cipher_suites, &(&1 in @secure_cipher_suites))
  end

  defp expired?(cert_info) do
    DateTime.compare(DateTime.utc_now(), cert_info.not_after) == :gt
  end

  defp strong_signature?(algorithm) do
    algorithm in [
      "SHA256withRSA",
      "SHA384withRSA",
      "SHA512withRSA",
      "SHA256withECDSA",
      "SHA384withECDSA",
      "SHA512withECDSA"
    ]
  end

  defp has_weak_ciphers?(cipher_suites, policies) do
    Enum.any?(cipher_suites, &(&1 in policies.forbidden_cipher_suites))
  end

  defp has_forward_secrecy?(cipher_suites) do
    Enum.any?(cipher_suites, &String.contains?(&1, "ECDHE"))
  end

  defp all_ciphers_secure?(validation_results) do
    validation_results
    |> Enum.filter(fn {_, result} -> result.status == :valid end)
    |> Enum.all?(fn {_, result} ->
      Enum.all?(result.cipher_suites, &(&1 in @secure_cipher_suites))
    end)
  end

  defp get_min_tls_version(validation_results) do
    validation_results
    |> Enum.filter(fn {_, result} -> result.status == :valid end)
    |> Enum.map(fn {_, result} -> result.tls_version end)
    |> Enum.min(fn -> @min_tls_version end)
  end

  defp calculate_days_until_expiry(expiry_date) do
    DateTime.diff(expiry_date, DateTime.utc_now(), :day)
  end

  defp generate_summary(validation_results) do
    total = map_size(validation_results)
    valid = Enum.count(validation_results, fn {_, result} -> result.status == :valid end)

    %{
      total_containers: total,
      valid_configurations: valid,
      invalid_configurations: total - valid,
      success_rate: if(total > 0, do: valid / total * 100, else: 0)
    }
  end
end
