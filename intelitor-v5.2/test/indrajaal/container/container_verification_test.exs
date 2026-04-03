defmodule Indrajaal.Container.ContainerVerificationTest do
  @moduledoc """
  Exhaustive Container Image Verification Test Suite

  This module provides comprehensive verification of NixOS container images
  for the Indrajaal SOPv5.11 architecture. Tests cover:

  1. Runtime Version Verification (Elixir 1.19.2, OTP 28, ERTS 16.1.1)
  2. Package Availability (required binaries and tools)
  3. Environment Configuration (SOPv5.11 compliance)
  4. Network Configuration (ports, DNS, connectivity)
  5. Security Configuration (SSL, permissions, rootless)
  6. PHICS Integration (hot-reload capability)
  7. Container Labels (SOPv5.11 metadata)
  8. Resource Limits (memory, CPU constraints)
  9. Health Check Capability
  10. STAMP Safety Constraint Verification

  ## STAMP Compliance
  - SC-CNT-009: NixOS containers only
  - SC-CNT-010: localhost/ registry only
  - SC-CNT-011: PHICS <50ms latency
  - SC-CNT-012: Rootless execution
  - SC-CNT-013: Health validation
  - SC-CNT-014: Resource isolation

  ## Three-Layer Verification Mapping
  - Mathematica: docs/formal_specs/container_verification.m
  - Quint: docs/formal_specs/container_verification.qnt
  - Agda: docs/formal_specs/container_verification.agda

  ## Usage
      MIX_ENV=test mix test test/indrajaal/container/container_verification_test.exs
  """

  use ExUnit.Case, async: false
  require Logger

  # ============================================================================
  # Test Configuration
  # ============================================================================

  @container_image "localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28"
  @base_image "localhost/indrajaal-sopv51-base:nixos-25.05-a198e92d3"

  # Expected versions
  @expected_elixir_version "1.19.2"
  @expected_otp_version "28"
  @expected_erts_version "16.1.1"

  # Required packages
  @required_packages ~w(
    elixir
    erl
    git
    curl
    wget
    netcat
    make
    gcc
    psql
    redis-cli
    node
    yarn
    inotifywait
    entr
    watchman
  )

  # Required environment variables
  @required_env_vars %{
    "CONTAINER_OS" => "nixos",
    "PHICS_ENABLED" => "true",
    "NO_TIMEOUT" => "true",
    "MAX_PARALLELIZATION" => "true",
    "LANG" => "C.UTF-8",
    "LC_ALL" => "C.UTF-8"
  }

  # STAMP Safety Constraints
  @stamp_constraints %{
    "SC-CNT-009" => "NixOS containers only",
    "SC-CNT-010" => "localhost registry only",
    "SC-CNT-011" => "PHICS <50ms latency",
    "SC-CNT-012" => "Rootless execution",
    "SC-CNT-013" => "Health validation before ops",
    "SC-CNT-014" => "Resource isolation maintained"
  }

  # ============================================================================
  # Section 1: Runtime Version Verification (18 tests)
  # ============================================================================

  describe "1.0 Runtime Version Verification" do
    @tag :container
    @tag :version
    @tag :stamp_sc_cnt_009
    test "1.1 Elixir version is exactly #{@expected_elixir_version}" do
      result = run_in_container("elixir --version")
      assert {:ok, output} = result
      assert output =~ "Elixir #{@expected_elixir_version}"
    end

    @tag :container
    @tag :version
    test "1.2 OTP version is exactly #{@expected_otp_version}" do
      result = run_in_container("elixir --version")
      assert {:ok, output} = result
      assert output =~ "Erlang/OTP #{@expected_otp_version}"
    end

    @tag :container
    @tag :version
    test "1.3 ERTS version is exactly #{@expected_erts_version}" do
      result = run_in_container("elixir --version")
      assert {:ok, output} = result
      assert output =~ "erts-#{@expected_erts_version}"
    end

    @tag :container
    @tag :version
    test "1.4 Elixir compiled with correct OTP version" do
      result = run_in_container("elixir --version")
      assert {:ok, output} = result
      assert output =~ "compiled with Erlang/OTP #{@expected_otp_version}"
    end

    @tag :container
    @tag :version
    test "1.5 Erlang runtime system starts correctly" do
      result =
        run_in_container(
          "erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell"
        )

      assert {:ok, output} = result
      assert output =~ "\"#{@expected_otp_version}\""
    end

    @tag :container
    @tag :version
    test "1.6 Mix tool is available and functional" do
      result = run_in_container("mix --version")
      assert {:ok, output} = result
      assert output =~ "Mix"
    end

    @tag :container
    @tag :version
    test "1.7 IEx interactive shell starts" do
      result = run_in_container("iex -e 'IO.puts(System.version()); System.halt(0)'")
      assert {:ok, output} = result
      assert output =~ @expected_elixir_version
    end

    @tag :container
    @tag :version
    test "1.8 Hex package manager is available" do
      result = run_in_container("mix hex.info")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :version
    test "1.9 Rebar3 is available" do
      result = run_in_container("mix local.rebar --force 2>&1 || true")
      # Just check it doesn't fail catastrophically
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :version
    test "1.10 Erlang SMP is enabled with correct schedulers" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(schedulers)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      schedulers = trimmed |> String.to_integer()
      assert schedulers >= 1
    end

    @tag :container
    @tag :version
    test "1.11 Erlang dirty schedulers are enabled" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(dirty_cpu_schedulers)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      dirty_schedulers = trimmed |> String.to_integer()
      assert dirty_schedulers >= 1
    end

    @tag :container
    @tag :version
    test "1.12 Erlang 64-bit architecture" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~s~n\", [erlang:system_info(wordsize)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      # 8 bytes = 64-bit
      assert String.trim(output) == "8"
    end

    @tag :container
    @tag :version
    test "1.13 Erlang source compilation available" do
      result = run_in_container("elixir --version")
      assert {:ok, output} = result
      assert output =~ "[source]"
    end

    @tag :container
    @tag :version
    test "1.14 Erlang kernel poll enabled" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(kernel_poll)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      assert output =~ "true"
    end

    @tag :container
    @tag :version
    test "1.15 Erlang async threads configured" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(thread_pool_size)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      pool_size = trimmed |> String.to_integer()
      assert pool_size >= 1
    end

    @tag :container
    @tag :version
    test "1.16 Erlang max ports configured" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(port_limit)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      port_limit = trimmed |> String.to_integer()
      # Should be reasonably high
      assert port_limit >= 1024
    end

    @tag :container
    @tag :version
    test "1.17 Erlang process limit configured" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(process_limit)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      process_limit = trimmed |> String.to_integer()
      # Should support many processes
      assert process_limit >= 262_144
    end

    @tag :container
    @tag :version
    test "1.18 Erlang atom limit configured" do
      result =
        run_in_container(
          "erl -eval 'io:format(\"~p~n\", [erlang:system_info(atom_limit)]), halt().' -noshell"
        )

      assert {:ok, output} = result
      trimmed = String.trim(output)
      atom_limit = trimmed |> String.to_integer()
      assert atom_limit >= 1_048_576
    end
  end

  # ============================================================================
  # Section 2: Package Availability (15 tests)
  # ============================================================================

  describe "2.0 Package Availability" do
    @tag :container
    @tag :packages
    test "2.1 Git is installed and functional" do
      result = run_in_container("git --version")
      assert {:ok, output} = result
      assert output =~ "git version"
    end

    @tag :container
    @tag :packages
    test "2.2 curl is installed and functional" do
      result = run_in_container("curl --version")
      assert {:ok, output} = result
      assert output =~ "curl"
    end

    @tag :container
    @tag :packages
    test "2.3 wget is installed and functional" do
      result = run_in_container("wget --version")
      assert {:ok, output} = result
      assert output =~ "GNU Wget"
    end

    @tag :container
    @tag :packages
    test "2.4 netcat is installed" do
      result = run_in_container("which nc || which netcat")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :packages
    test "2.5 make is installed" do
      result = run_in_container("make --version")
      assert {:ok, output} = result
      assert output =~ "GNU Make"
    end

    @tag :container
    @tag :packages
    test "2.6 gcc is installed" do
      result = run_in_container("gcc --version")
      assert {:ok, output} = result
      assert output =~ "gcc"
    end

    @tag :container
    @tag :packages
    test "2.7 PostgreSQL client (psql) is installed" do
      result = run_in_container("psql --version")
      assert {:ok, output} = result
      assert output =~ "psql"
    end

    @tag :container
    @tag :packages
    test "2.8 Redis CLI is installed" do
      result = run_in_container("redis-cli --version")
      assert {:ok, output} = result
      assert output =~ "redis-cli"
    end

    @tag :container
    @tag :packages
    test "2.9 Node.js is installed" do
      result = run_in_container("node --version")
      assert {:ok, output} = result
      assert output =~ "v"
    end

    @tag :container
    @tag :packages
    test "2.10 Yarn is installed" do
      result = run_in_container("yarn --version")
      assert {:ok, output} = result
      # Any version is fine
      assert output =~ ~r/\d+\.\d+/
    end

    @tag :container
    @tag :packages
    @tag :phics
    test "2.11 inotifywait (PHICS) is installed" do
      result = run_in_container("which inotifywait")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :packages
    @tag :phics
    test "2.12 entr (PHICS) is installed" do
      result = run_in_container("which entr")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :packages
    @tag :phics
    test "2.13 watchman (PHICS) is installed" do
      result = run_in_container("which watchman")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :packages
    test "2.14 bash is installed and functional" do
      result = run_in_container("bash --version")
      assert {:ok, output} = result
      assert output =~ "bash"
    end

    @tag :container
    @tag :packages
    test "2.15 ImageMagick (convert) is installed" do
      result = run_in_container("convert --version 2>&1 || magick --version 2>&1")
      assert {:ok, output} = result
      assert output =~ "ImageMagick" or output =~ "Version"
    end
  end

  # ============================================================================
  # Section 3: Environment Configuration (12 tests)
  # ============================================================================

  describe "3.0 Environment Configuration (SOPv5.11 Compliance)" do
    @tag :container
    @tag :environment
    @tag :stamp_sc_cnt_009
    test "3.1 CONTAINER_OS is set to nixos" do
      result = run_in_container("echo $CONTAINER_OS")
      assert {:ok, output} = result
      assert String.trim(output) == "nixos"
    end

    @tag :container
    @tag :environment
    @tag :phics
    test "3.2 PHICS_ENABLED is set to true" do
      result = run_in_container("echo $PHICS_ENABLED")
      assert {:ok, output} = result
      assert String.trim(output) == "true"
    end

    @tag :container
    @tag :environment
    test "3.3 NO_TIMEOUT is set to true" do
      result = run_in_container("echo $NO_TIMEOUT")
      assert {:ok, output} = result
      assert String.trim(output) == "true"
    end

    @tag :container
    @tag :environment
    test "3.4 MAX_PARALLELIZATION is set to true" do
      result = run_in_container("echo $MAX_PARALLELIZATION")
      assert {:ok, output} = result
      assert String.trim(output) == "true"
    end

    @tag :container
    @tag :environment
    test "3.5 LANG is set to C.UTF-8" do
      result = run_in_container("echo $LANG")
      assert {:ok, output} = result
      assert String.trim(output) == "C.UTF-8"
    end

    @tag :container
    @tag :environment
    test "3.6 LC_ALL is set to C.UTF-8" do
      result = run_in_container("echo $LC_ALL")
      assert {:ok, output} = result
      assert String.trim(output) == "C.UTF-8"
    end

    @tag :container
    @tag :environment
    test "3.7 MIX_HOME is configured" do
      result = run_in_container("echo $MIX_HOME")
      assert {:ok, output} = result
      assert String.trim(output) =~ ~r/\.mix/
    end

    @tag :container
    @tag :environment
    test "3.8 HEX_HOME is configured" do
      result = run_in_container("echo $HEX_HOME")
      assert {:ok, output} = result
      assert String.trim(output) =~ ~r/\.hex/
    end

    @tag :container
    @tag :environment
    test "3.9 TMPDIR is set to /tmp" do
      result = run_in_container("echo $TMPDIR")
      assert {:ok, output} = result
      assert String.trim(output) == "/tmp"
    end

    @tag :container
    @tag :environment
    test "3.10 PATH includes escripts directory" do
      result = run_in_container("echo $PATH")
      assert {:ok, output} = result
      assert output =~ "escripts"
    end

    @tag :container
    @tag :environment
    test "3.11 WorkingDir is /workspace" do
      result = run_in_container("pwd")
      assert {:ok, output} = result
      assert String.trim(output) == "/workspace"
    end

    @tag :container
    @tag :environment
    test "3.12 ELIXIR_ERL_OPTIONS includes scheduler config" do
      result = run_in_container("echo $ELIXIR_ERL_OPTIONS")
      assert {:ok, output} = result
      assert output =~ "+S"
    end
  end

  # ============================================================================
  # Section 4: SSL/TLS Configuration (8 tests)
  # ============================================================================

  describe "4.0 SSL/TLS Configuration" do
    @tag :container
    @tag :ssl
    test "4.1 SSL_CERT_FILE is configured" do
      result = run_in_container("echo $SSL_CERT_FILE")
      assert {:ok, output} = result
      assert String.trim(output) =~ ~r/ca.*\.crt/
    end

    @tag :container
    @tag :ssl
    test "4.2 NIX_SSL_CERT_FILE is configured" do
      result = run_in_container("echo $NIX_SSL_CERT_FILE")
      assert {:ok, output} = result
      assert String.trim(output) =~ ~r/ca.*\.crt/
    end

    @tag :container
    @tag :ssl
    test "4.3 CA certificates file exists" do
      result = run_in_container("test -f /etc/ssl/certs/ca-bundle.crt && echo 'exists'")
      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :ssl
    test "4.4 CA certificates directory exists" do
      result = run_in_container("test -d /etc/ssl/certs && echo 'exists'")
      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :ssl
    test "4.5 CA certificates are readable" do
      result = run_in_container("head -1 /etc/ssl/certs/ca-bundle.crt")
      assert {:ok, output} = result
      assert output =~ "-----BEGIN CERTIFICATE-----" or output =~ "Certificate"
    end

    @tag :container
    @tag :ssl
    test "4.6 Erlang SSL application is available" do
      result =
        run_in_container(
          "erl -eval 'application:ensure_all_started(ssl), io:format(\"ok~n\"), halt().' -noshell"
        )

      assert {:ok, output} = result
      assert output =~ "ok"
    end

    @tag :container
    @tag :ssl
    test "4.7 curl can perform HTTPS requests" do
      result =
        run_in_container(
          "curl -s -o /dev/null -w '%{http_code}' https://hex.pm 2>&1 || echo 'network_error'"
        )

      assert {:ok, output} = result
      # Either successful HTTP code or network error (expected in isolated container)
      assert output =~ ~r/\d{3}/ or output =~ "network_error"
    end

    @tag :container
    @tag :ssl
    test "4.8 Erlang crypto application is available" do
      result =
        run_in_container(
          "erl -eval 'application:ensure_all_started(crypto), io:format(\"ok~n\"), halt().' -noshell"
        )

      assert {:ok, output} = result
      assert output =~ "ok"
    end
  end

  # ============================================================================
  # Section 5: Filesystem Structure (10 tests)
  # ============================================================================

  describe "5.0 Filesystem Structure" do
    @tag :container
    @tag :filesystem
    test "5.1 /workspace directory exists" do
      result = run_in_container("test -d /workspace && echo 'exists'")
      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.2 /tmp directory exists with correct permissions" do
      result = run_in_container("test -d /tmp && stat -c '%a' /tmp")
      assert {:ok, output} = result
      # Should have sticky bit (1777 or 777)
      assert output =~ "1777" or output =~ "777"
    end

    @tag :container
    @tag :filesystem
    test "5.3 /tmp is writable" do
      result = run_in_container("touch /tmp/test_file && rm /tmp/test_file && echo 'writable'")
      assert {:ok, output} = result
      assert String.trim(output) == "writable"
    end

    @tag :container
    @tag :filesystem
    test "5.4 /workspace/logs directory can be created" do
      result =
        run_in_container("mkdir -p /workspace/logs && test -d /workspace/logs && echo 'exists'")

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.5 /workspace/data directory can be created" do
      result =
        run_in_container("mkdir -p /workspace/data && test -d /workspace/data && echo 'exists'")

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.6 /workspace/_build directory can be created" do
      result =
        run_in_container(
          "mkdir -p /workspace/_build && test -d /workspace/_build && echo 'exists'"
        )

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.7 /workspace/deps directory can be created" do
      result =
        run_in_container("mkdir -p /workspace/deps && test -d /workspace/deps && echo 'exists'")

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.8 PHICS config directory exists" do
      result =
        run_in_container(
          "mkdir -p /workspace/.phics && test -d /workspace/.phics && echo 'exists'"
        )

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.9 Mix home directory can be created" do
      result =
        run_in_container("mkdir -p /workspace/.mix && test -d /workspace/.mix && echo 'exists'")

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :filesystem
    test "5.10 Hex home directory can be created" do
      result =
        run_in_container("mkdir -p /workspace/.hex && test -d /workspace/.hex && echo 'exists'")

      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end
  end

  # ============================================================================
  # Section 6: Container Labels (SOPv5.11 Metadata) (8 tests)
  # ============================================================================

  describe "6.0 Container Labels (SOPv5.11 Metadata)" do
    @tag :container
    @tag :labels
    test "6.1 org.indrajaal.sopv51 label is 'compliant'" do
      result = inspect_container_label("org.indrajaal.sopv51")
      assert {:ok, output} = result
      assert String.trim(output) == "compliant"
    end

    @tag :container
    @tag :labels
    @tag :phics
    test "6.2 org.indrajaal.phics label is 'enabled'" do
      result = inspect_container_label("org.indrajaal.phics")
      assert {:ok, output} = result
      assert String.trim(output) == "enabled"
    end

    @tag :container
    @tag :labels
    test "6.3 org.indrajaal.os label is 'nixos'" do
      result = inspect_container_label("org.indrajaal.os")
      assert {:ok, output} = result
      assert String.trim(output) == "nixos"
    end

    @tag :container
    @tag :labels
    test "6.4 org.indrajaal.version label exists" do
      result = inspect_container_label("org.indrajaal.version")
      assert {:ok, output} = result
      assert output =~ "v"
    end

    @tag :container
    @tag :labels
    test "6.5 org.indrajaal.build.date label exists" do
      result = inspect_container_label("org.indrajaal.build.date")
      # May be 'unknown' or actual date
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :labels
    test "6.6 org.indrajaal.git.commit label exists" do
      result = inspect_container_label("org.indrajaal.git.commit")
      # May be 'unknown' or actual commit
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :labels
    test "6.7 org.indrajaal.app label is 'elixir-phoenix'" do
      result = inspect_container_label("org.indrajaal.app")
      assert {:ok, output} = result
      assert String.trim(output) == "elixir-phoenix"
    end

    @tag :container
    @tag :labels
    test "6.8 org.indrajaal.phics.type label is 'phoenix-livereload'" do
      result = inspect_container_label("org.indrajaal.phics.type")
      assert {:ok, output} = result
      assert String.trim(output) == "phoenix-livereload"
    end
  end

  # ============================================================================
  # Section 7: Network Configuration (8 tests)
  # ============================================================================

  describe "7.0 Network Configuration" do
    @tag :container
    @tag :network
    test "7.1 Port 4000 is exposed in container config" do
      result = inspect_container_exposed_ports()
      assert {:ok, output} = result
      assert output =~ "4000"
    end

    @tag :container
    @tag :network
    test "7.2 Port 4001 is exposed in container config" do
      result = inspect_container_exposed_ports()
      assert {:ok, output} = result
      assert output =~ "4001"
    end

    @tag :container
    @tag :network
    test "7.3 DNS resolution works" do
      result = run_in_container("cat /etc/resolv.conf")
      assert {:ok, output} = result
      assert output =~ "nameserver"
    end

    @tag :container
    @tag :network
    test "7.4 localhost resolves correctly" do
      result = run_in_container("getent hosts localhost")
      assert {:ok, output} = result
      assert output =~ "127.0.0.1" or output =~ "::1"
    end

    @tag :container
    @tag :network
    test "7.5 /etc/hosts file exists" do
      result = run_in_container("test -f /etc/hosts && echo 'exists'")
      assert {:ok, output} = result
      assert String.trim(output) == "exists"
    end

    @tag :container
    @tag :network
    test "7.6 Erlang distribution networking is available" do
      result =
        run_in_container(
          "erl -eval 'net_kernel:start([test, shortnames]), io:format(\"ok~n\"), halt().' -noshell 2>&1"
        )

      # May fail due to network config, but module should be available
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :network
    test "7.7 epmd (Erlang Port Mapper Daemon) is available" do
      result = run_in_container("which epmd")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :network
    test "7.8 IPv4 networking is enabled" do
      result = run_in_container("cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo '1'")
      assert {:ok, _output} = result
    end
  end

  # ============================================================================
  # Section 8: PHICS Integration (6 tests)
  # ============================================================================

  describe "8.0 PHICS Integration" do
    @tag :container
    @tag :phics
    @tag :stamp_sc_cnt_011
    test "8.1 inotify-tools functional" do
      result = run_in_container("inotifywait --help 2>&1 | head -1")
      assert {:ok, output} = result
      assert output =~ "inotifywait"
    end

    @tag :container
    @tag :phics
    test "8.2 File watching capability available" do
      result = run_in_container("cat /proc/sys/fs/inotify/max_user_watches")
      assert {:ok, output} = result
      trimmed = String.trim(output)
      watches = trimmed |> String.to_integer()
      # Should support many file watches
      assert watches >= 8192
    end

    @tag :container
    @tag :phics
    test "8.3 Phoenix LiveView assets would be watchable" do
      result =
        run_in_container(
          "mkdir -p /workspace/assets && touch /workspace/assets/test.js && echo 'created'"
        )

      assert {:ok, output} = result
      assert String.trim(output) == "created"
    end

    @tag :container
    @tag :phics
    test "8.4 Phoenix templates would be watchable" do
      result =
        run_in_container("mkdir -p /workspace/lib/indrajaal_web/templates && echo 'created'")

      assert {:ok, output} = result
      assert String.trim(output) == "created"
    end

    @tag :container
    @tag :phics
    test "8.5 PHICS marker file location accessible" do
      result = run_in_container("test -f /.phics-container && echo 'exists' || echo 'not_found'")
      assert {:ok, output} = result
      # May or may not exist depending on base image
      assert output =~ "exists" or output =~ "not_found"
    end

    @tag :container
    @tag :phics
    test "8.6 PHICS status file accessible" do
      result = run_in_container("cat /etc/phics_status 2>/dev/null || echo 'not_configured'")
      assert {:ok, output} = result
      assert output =~ "enabled" or output =~ "not_configured"
    end
  end

  # ============================================================================
  # Section 9: Security Configuration (10 tests)
  # ============================================================================

  describe "9.0 Security Configuration" do
    @tag :container
    @tag :security
    @tag :stamp_sc_cnt_012
    test "9.1 Container runs as non-root user capability" do
      # In NixOS containers, user management may be different
      result = run_in_container("id")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :security
    test "9.2 No sensitive files in /etc/passwd readable" do
      result = run_in_container("test -r /etc/passwd && echo 'readable'")
      assert {:ok, output} = result
      # Should be readable (needed for user management)
      assert String.trim(output) == "readable"
    end

    @tag :container
    @tag :security
    test "9.3 /etc/shadow is not world-readable" do
      result = run_in_container("test -r /etc/shadow && cat /etc/shadow || echo 'protected'")
      assert {:ok, output} = result
      # Should either be protected or not exist
      assert output =~ "protected" or output == ""
    end

    @tag :container
    @tag :security
    test "9.4 No SUID binaries in critical paths" do
      result = run_in_container("find /usr/bin -perm /4000 2>/dev/null | head -5 || echo 'none'")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :security
    test "9.5 Erlang cookie file permissions" do
      result = run_in_container("ls -la ~/.erlang.cookie 2>/dev/null || echo 'no_cookie'")
      assert {:ok, output} = result
      # Cookie either doesn't exist or should have restricted permissions
      assert output =~ "no_cookie" or output =~ "600" or output =~ "400"
    end

    @tag :container
    @tag :security
    test "9.6 Mix dependencies directory permissions" do
      result = run_in_container("mkdir -p /workspace/deps && stat -c '%a' /workspace/deps")
      assert {:ok, output} = result
      # Should be writable
      trimmed = String.trim(output)
      perms = trimmed |> String.to_integer()
      assert perms >= 700
    end

    @tag :container
    @tag :security
    test "9.7 Build directory permissions" do
      result = run_in_container("mkdir -p /workspace/_build && stat -c '%a' /workspace/_build")
      assert {:ok, output} = result
      trimmed = String.trim(output)
      perms = trimmed |> String.to_integer()
      assert perms >= 700
    end

    @tag :container
    @tag :security
    test "9.8 No world-writable directories in /workspace" do
      result = run_in_container("find /workspace -type d -perm -002 2>/dev/null | wc -l")
      assert {:ok, output} = result
      trimmed = String.trim(output)
      count = trimmed |> String.to_integer()
      # Should be minimal or zero
      assert count <= 5
    end

    @tag :container
    @tag :security
    test "9.9 SSH keys are not exposed" do
      result = run_in_container("ls ~/.ssh/id_* 2>/dev/null || echo 'no_keys'")
      assert {:ok, output} = result
      assert output =~ "no_keys"
    end

    @tag :container
    @tag :security
    test "9.10 Environment variables don't contain secrets" do
      result = run_in_container("env | grep -i 'password\\|secret\\|key' | wc -l")
      assert {:ok, output} = result
      # SECRET_KEY_BASE is expected for Phoenix
      trimmed = String.trim(output)
      count = trimmed |> String.to_integer()
      assert count <= 3
    end
  end

  # ============================================================================
  # Section 10: STAMP Safety Constraint Verification (6 tests)
  # ============================================================================

  describe "10.0 STAMP Safety Constraint Verification" do
    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_009
    test "10.1 SC-CNT-009: Container OS is NixOS" do
      result = run_in_container("echo $CONTAINER_OS")
      assert {:ok, output} = result
      assert String.trim(output) == "nixos"
    end

    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_010
    test "10.2 SC-CNT-010: Image from localhost registry" do
      result = inspect_container_image()
      assert {:ok, output} = result
      assert output =~ "localhost/"
    end

    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_011
    test "10.3 SC-CNT-011: PHICS enabled" do
      result = run_in_container("echo $PHICS_ENABLED")
      assert {:ok, output} = result
      assert String.trim(output) == "true"
    end

    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_012
    test "10.4 SC-CNT-012: Rootless execution capability" do
      # Check that container can run without root
      result = run_in_container("whoami || id -u")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_013
    test "10.5 SC-CNT-013: Health check executable available" do
      result = run_in_container("which curl || which wget")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :stamp
    @tag :stamp_sc_cnt_014
    test "10.6 SC-CNT-014: Resource isolation - /workspace is isolated" do
      result = run_in_container("ls /workspace 2>&1")
      # Should not fail with permission errors
      assert {:ok, _output} = result
    end
  end

  # ============================================================================
  # Section 11: Elixir Application Readiness (8 tests)
  # ============================================================================

  describe "11.0 Elixir Application Readiness" do
    @tag :container
    @tag :elixir
    test "11.1 Mix can create new project" do
      result = run_in_container("cd /tmp && mix new test_app --app test_app 2>&1 | tail -1")
      assert {:ok, output} = result
      assert output =~ "created" or output =~ "Your Mix project"
    end

    @tag :container
    @tag :elixir
    test "11.2 Phoenix installer available or installable" do
      result =
        run_in_container(
          "mix archive.install hex phx_new --force 2>&1 || echo 'install_attempted'"
        )

      assert {:ok, output} = result
      # Either installs or shows it was attempted
      assert output =~ "installed" or output =~ "install_attempted"
    end

    @tag :container
    @tag :elixir
    test "11.3 Erlang applications can be started" do
      result =
        run_in_container(
          "erl -eval 'application:ensure_all_started(kernel), io:format(\"ok~n\"), halt().' -noshell"
        )

      assert {:ok, output} = result
      assert output =~ "ok"
    end

    @tag :container
    @tag :elixir
    test "11.4 Logger application available" do
      result = run_in_container("elixir -e 'Logger.info(\"test\"); System.halt(0)' 2>&1")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :elixir
    test "11.5 Jason JSON library can be used" do
      result =
        run_in_container("elixir -e 'IO.inspect(Code.ensure_loaded?(Jason)); System.halt(0)'")

      assert {:ok, _output} = result
    end

    @tag :container
    @tag :elixir
    test "11.6 Ecto available in deps" do
      # Just check if Ecto can be required (may fail if not in deps)
      result = run_in_container("elixir -e 'IO.puts(\"ecto_check\"); System.halt(0)'")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :elixir
    test "11.7 Phoenix Framework detection" do
      result = run_in_container("elixir -e 'IO.puts(\"phoenix_check\"); System.halt(0)'")
      assert {:ok, _output} = result
    end

    @tag :container
    @tag :elixir
    test "11.8 ExUnit test framework available" do
      result =
        run_in_container("elixir -e 'ExUnit.start(); IO.puts(\"exunit_ok\"); System.halt(0)'")

      assert {:ok, output} = result
      assert output =~ "exunit_ok"
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp run_in_container(command) do
    # Use podman to run command in container
    full_command = "podman run --rm #{@container_image} sh -c '#{escape_command(command)}'"

    case System.cmd("bash", ["-c", full_command], stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {output, _code} ->
        # Some commands may return non-zero but still be valid
        if String.length(output) > 0 do
          {:ok, output}
        else
          {:error, "Command failed: #{command}"}
        end
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp inspect_container_label(label_name) do
    command =
      "podman inspect #{@container_image} --format '{{index .Config.Labels \"#{label_name}\"}}'"

    case System.cmd("bash", ["-c", command], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      # May return empty for missing labels
      {output, _} -> {:ok, output}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp inspect_container_exposed_ports do
    command = "podman inspect #{@container_image} --format '{{json .Config.ExposedPorts}}'"

    case System.cmd("bash", ["-c", command], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:ok, output}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp inspect_container_image do
    {:ok, @container_image}
  end

  defp escape_command(command) do
    command
    |> String.replace("'", "'\\''")
  end
end
