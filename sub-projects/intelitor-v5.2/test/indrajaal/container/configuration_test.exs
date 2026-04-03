defmodule Indrajaal.Container.ConfigurationTest do
  @moduledoc """
  TDG Test Suite for Container Configuration Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: SC-CNT container safety constraint validation
  - SOPv5.11_CYBERNETIC: Container orchestration validation

  Tests container configuration capabilities:
  - Environment-based configuration (development, test, production)
  - Resource limit management
  - Security settings validation
  - Kubernetes manifest generation
  - Docker Compose generation
  - STAMP constraint enforcement
  """
  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData

  alias Indrajaal.Container.Configuration

  @moduletag :tdg_compliant
  @moduletag :container_domain

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(Configuration)
    end

    test "exports get_config/1" do
      assert function_exported?(Configuration, :get_config, 1)
    end

    test "exports update_config/2" do
      assert function_exported?(Configuration, :update_config, 2)
    end

    test "exports validate_config/1" do
      assert function_exported?(Configuration, :validate_config, 1)
    end

    test "exports generate_k8s_manifests/2" do
      assert function_exported?(Configuration, :generate_k8s_manifests, 2)
    end

    test "exports generate_docker_compose/2" do
      assert function_exported?(Configuration, :generate_docker_compose, 2)
    end
  end

  describe "get_config/1" do
    test "returns development configuration" do
      config = Configuration.get_config(:development)

      assert is_map(config)
      assert Map.has_key?(config, :resources)
      assert Map.has_key?(config, :environment)
      assert Map.has_key?(config, :orchestration)
      assert Map.has_key?(config, :networking)
      assert Map.has_key?(config, :security)
    end

    test "returns test configuration" do
      config = Configuration.get_config(:test)

      assert is_map(config)
      assert config.environment.test_mode == true
    end

    test "returns production configuration" do
      config = Configuration.get_config(:production)

      assert is_map(config)
      assert Map.has_key?(config, :auto_scaling)
      assert Map.has_key?(config, :monitoring)
    end

    test "defaults to development for unknown environment" do
      config = Configuration.get_config(:unknown)
      dev_config = Configuration.get_config(:development)

      # Should return development config for unknown environments
      assert is_map(config)
      assert config.resources == dev_config.resources
    end

    test "development has PHICS enabled" do
      config = Configuration.get_config(:development)
      assert config.environment.phics_enabled == true
    end

    test "production has PHICS disabled" do
      config = Configuration.get_config(:production)
      assert config.environment.phics_enabled == false
    end
  end

  describe "resource configuration" do
    test "development has appropriate CPU limits" do
      config = Configuration.get_config(:development)
      assert config.resources.cpu == "1000m"
    end

    test "production has higher CPU limits" do
      config = Configuration.get_config(:production)
      assert config.resources.cpu == "2000m"
    end

    test "test has minimal CPU limits" do
      config = Configuration.get_config(:test)
      assert config.resources.cpu == "500m"
    end
  end

  describe "security configuration" do
    test "all environments run as non-root" do
      for env <- [:development, :test, :production] do
        config = Configuration.get_config(env)
        assert config.security.run_as_non_root == true
      end
    end

    test "all environments disallow privilege escalation" do
      for env <- [:development, :test, :production] do
        config = Configuration.get_config(env)
        assert config.security.allow_privilege_escalation == false
      end
    end

    test "production has read-only root filesystem" do
      config = Configuration.get_config(:production)
      assert config.security.read_only_root_filesystem == true
    end
  end

  describe "validate_config/1" do
    test "validates correct configuration" do
      config = %{
        resources: %{cpu: "1000m", memory: "2Gi"},
        security: %{run_as_non_root: true, allow_privilege_escalation: false},
        networking: %{ports: [4000, 8080]}
      }

      assert {:ok, ^config} = Configuration.validate_config(config)
    end

    test "rejects privilege escalation" do
      config = %{
        resources: %{cpu: "1000m", memory: "2Gi"},
        security: %{run_as_non_root: true, allow_privilege_escalation: true},
        networking: %{ports: [4000]}
      }

      assert {:error, _reason} = Configuration.validate_config(config)
    end

    test "rejects running as root" do
      config = %{
        resources: %{cpu: "1000m", memory: "2Gi"},
        security: %{run_as_non_root: false, allow_privilege_escalation: false},
        networking: %{ports: [4000]}
      }

      assert {:error, _reason} = Configuration.validate_config(config)
    end

    test "validates port ranges" do
      valid_config = %{
        resources: %{cpu: "1000m", memory: "2Gi"},
        security: %{run_as_non_root: true, allow_privilege_escalation: false},
        networking: %{ports: [80, 443, 4000, 8080]}
      }

      assert {:ok, _} = Configuration.validate_config(valid_config)
    end
  end

  describe "update_config/2" do
    test "merges new configuration with existing" do
      new_config = %{resources: %{cpu: "1500m"}}
      {:ok, updated} = Configuration.update_config(:development, new_config)

      # Should deep merge
      assert is_map(updated)
    end

    test "validates before updating" do
      invalid_config = %{security: %{allow_privilege_escalation: true}}
      result = Configuration.update_config(:development, invalid_config)

      assert {:error, _reason} = result
    end
  end

  describe "generate_k8s_manifests/2" do
    test "generates deployment manifest" do
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "indrajaal-app")

      assert Map.has_key?(manifests, :deployment)
      assert manifests.deployment["kind"] == "Deployment"
    end

    test "generates service manifest" do
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "indrajaal-app")

      assert Map.has_key?(manifests, :service)
      assert manifests.service["kind"] == "Service"
    end

    test "generates configmap manifest" do
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "indrajaal-app")

      assert Map.has_key?(manifests, :configmap)
      assert manifests.configmap["kind"] == "ConfigMap"
    end

    test "includes HPA for production with auto-scaling" do
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "indrajaal-app")

      assert Map.has_key?(manifests, :hpa)
      assert manifests.hpa["kind"] == "HorizontalPodAutoscaler"
    end

    test "includes ingress when enabled" do
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "indrajaal-app")

      assert Map.has_key?(manifests, :ingress)
    end
  end

  describe "generate_docker_compose/2" do
    test "generates valid YAML structure" do
      config = Configuration.get_config(:development)
      {:ok, compose_yaml} = Configuration.generate_docker_compose(config, "indrajaal")

      assert is_binary(compose_yaml)
      assert String.contains?(compose_yaml, "version")
      assert String.contains?(compose_yaml, "services")
    end

    test "includes app service" do
      config = Configuration.get_config(:development)
      {:ok, compose_yaml} = Configuration.generate_docker_compose(config, "indrajaal")

      assert String.contains?(compose_yaml, "indrajaal-app")
    end

    test "includes database service" do
      config = Configuration.get_config(:development)
      {:ok, compose_yaml} = Configuration.generate_docker_compose(config, "indrajaal")

      assert String.contains?(compose_yaml, "indrajaal-db")
    end

    test "includes redis service" do
      config = Configuration.get_config(:development)
      {:ok, compose_yaml} = Configuration.generate_docker_compose(config, "indrajaal")

      assert String.contains?(compose_yaml, "indrajaal-redis")
    end
  end

  describe "PropCheck property tests" do
    property "get_config always returns map for valid environments" do
      forall env <- oneof([:development, :test, :production]) do
        config = Configuration.get_config(env)
        is_map(config)
      end
    end

    property "all configs have required top-level keys" do
      forall env <- oneof([:development, :test, :production]) do
        config = Configuration.get_config(env)

        Map.has_key?(config, :resources) and
          Map.has_key?(config, :environment) and
          Map.has_key?(config, :orchestration) and
          Map.has_key?(config, :networking) and
          Map.has_key?(config, :security)
      end
    end

    property "security constraints are always enforced" do
      forall env <- oneof([:development, :test, :production]) do
        config = Configuration.get_config(env)

        config.security.run_as_non_root == true and
          config.security.allow_privilege_escalation == false
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "resource limits are valid strings" do
      ExUnitProperties.check all(env <- SD.member_of([:development, :test, :production])) do
        config = Configuration.get_config(env)

        assert is_binary(config.resources.cpu)
        assert is_binary(config.resources.memory)
        assert Regex.match?(~r/^\d+m?$/, config.resources.cpu)
        assert Regex.match?(~r/^\d+[KMGT]i?$/, config.resources.memory)
      end
    end

    test "ports are valid integers in range" do
      ExUnitProperties.check all(env <- SD.member_of([:development, :test, :production])) do
        config = Configuration.get_config(env)
        ports = config.networking.ports

        assert is_list(ports)
        assert Enum.all?(ports, fn p -> is_integer(p) and p > 0 and p <= 65_535 end)
      end
    end

    test "log levels are valid strings" do
      ExUnitProperties.check all(env <- SD.member_of([:development, :test, :production])) do
        config = Configuration.get_config(env)
        valid_levels = ["debug", "info", "warn", "error"]

        assert config.environment.log_level in valid_levels
      end
    end
  end

  describe "STAMP safety constraints" do
    test "SC-CNT-009: all operations within NixOS containers" do
      # Container configuration should use localhost registry
      config = Configuration.get_config(:production)
      {:ok, manifests} = Configuration.generate_k8s_manifests(config, "test")

      # Check that image uses localhost registry
      pod_spec = get_in(manifests.deployment, ["spec", "template", "spec"])
      container = hd(pod_spec["containers"])
      assert String.starts_with?(container["image"], "localhost/")
    end

    test "SC-CNT-010: uses ONLY localhost registry" do
      config = Configuration.get_config(:development)
      {:ok, compose_yaml} = Configuration.generate_docker_compose(config, "test")

      # Verify localhost images
      assert String.contains?(compose_yaml, "localhost/indrajaal-app")
    end

    test "SC-CNT-012: enforces rootless container execution" do
      for env <- [:development, :test, :production] do
        config = Configuration.get_config(env)
        assert config.security.run_as_non_root == true
      end
    end

    test "SC-CNT-014: maintains container resource isolation" do
      for env <- [:development, :test, :production] do
        config = Configuration.get_config(env)
        assert Map.has_key?(config.resources, :cpu)
        assert Map.has_key?(config.resources, :memory)
      end
    end
  end

  describe "PHICS integration" do
    test "development configuration enables PHICS" do
      config = Configuration.get_config(:development)
      assert config.environment.phics_enabled == true
      assert config.environment.hot_reloading == true
    end

    test "production configuration disables PHICS" do
      config = Configuration.get_config(:production)
      assert config.environment.phics_enabled == false
      assert config.environment.hot_reloading == false
    end

    test "test configuration disables PHICS" do
      config = Configuration.get_config(:test)
      assert config.environment.phics_enabled == false
    end
  end
end
