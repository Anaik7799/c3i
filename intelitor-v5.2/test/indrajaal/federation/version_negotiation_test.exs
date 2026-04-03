defmodule Indrajaal.Federation.VersionNegotiationTest do
  @moduledoc """
  Tests for Indrajaal.Federation.VersionNegotiation.

  negotiate/1 is a pure function that takes a list of peer version strings
  and returns {:ok, version} for the highest common version, or
  {:error, :no_common_version} when the intersection is empty.

  Supported versions at time of writing: ["1.0", "1.1", "2.0"].
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Federation.VersionNegotiation

  # ---------------------------------------------------------------------------
  # Successful negotiation
  # ---------------------------------------------------------------------------

  describe "negotiate/1 - successful negotiation" do
    test "returns the single common version" do
      assert {:ok, "1.0"} = VersionNegotiation.negotiate(["1.0"])
    end

    test "returns the highest common version when multiple versions match" do
      # Peer supports 1.0 and 2.0; local supports 1.0, 1.1, 2.0 — highest is 2.0
      assert {:ok, "2.0"} = VersionNegotiation.negotiate(["1.0", "2.0"])
    end

    test "returns highest common version from partial overlap" do
      # Peer only supports 1.0 and 1.1; local also supports 2.0 which peer does not
      assert {:ok, "1.1"} = VersionNegotiation.negotiate(["1.0", "1.1"])
    end

    test "returns 1.0 when only 1.0 is shared" do
      assert {:ok, "1.0"} = VersionNegotiation.negotiate(["1.0"])
    end

    test "handles a peer list with all three supported versions" do
      assert {:ok, "2.0"} = VersionNegotiation.negotiate(["1.0", "1.1", "2.0"])
    end

    test "result is always a two-tuple {:ok, string} on success" do
      {:ok, version} = VersionNegotiation.negotiate(["1.1"])
      assert is_binary(version)
    end
  end

  # ---------------------------------------------------------------------------
  # No common version
  # ---------------------------------------------------------------------------

  describe "negotiate/1 - no common version" do
    test "returns {:error, :no_common_version} when peer has no overlap" do
      assert {:error, :no_common_version} = VersionNegotiation.negotiate(["99.0"])
    end

    test "returns {:error, :no_common_version} for empty peer version list" do
      assert {:error, :no_common_version} = VersionNegotiation.negotiate([])
    end

    test "returns {:error, :no_common_version} for a version that predates support" do
      assert {:error, :no_common_version} = VersionNegotiation.negotiate(["0.9"])
    end

    test "returns {:error, :no_common_version} for a future version only" do
      assert {:error, :no_common_version} = VersionNegotiation.negotiate(["3.0", "4.0"])
    end
  end

  # ---------------------------------------------------------------------------
  # Return shape invariants
  # ---------------------------------------------------------------------------

  describe "negotiate/1 - return shape invariants" do
    test "always returns a two-element tuple" do
      result = VersionNegotiation.negotiate(["1.0"])
      assert tuple_size(result) == 2
    end

    test "first element is :ok or :error" do
      {tag, _} = VersionNegotiation.negotiate(["1.0"])
      assert tag in [:ok, :error]
    end

    test "on success, negotiated version is one of the supported versions" do
      supported = ["1.0", "1.1", "2.0"]
      {:ok, version} = VersionNegotiation.negotiate(["2.0"])
      assert version in supported
    end

    test "on error, reason is :no_common_version" do
      assert {:error, :no_common_version} = VersionNegotiation.negotiate(["unsupported"])
    end
  end

  # ---------------------------------------------------------------------------
  # Idempotency / purity
  # ---------------------------------------------------------------------------

  describe "negotiate/1 - purity" do
    test "same input produces the same result on repeated calls" do
      r1 = VersionNegotiation.negotiate(["1.1", "2.0"])
      r2 = VersionNegotiation.negotiate(["1.1", "2.0"])
      assert r1 == r2
    end

    test "input list ordering does not affect the result" do
      assert VersionNegotiation.negotiate(["1.0", "2.0"]) ==
               VersionNegotiation.negotiate(["2.0", "1.0"])
    end

    test "duplicate versions in peer list do not affect result" do
      assert VersionNegotiation.negotiate(["1.0", "1.0", "1.0"]) ==
               VersionNegotiation.negotiate(["1.0"])
    end
  end

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(VersionNegotiation)
    end

    test "negotiate/1 is exported" do
      assert function_exported?(VersionNegotiation, :negotiate, 1)
    end
  end
end
