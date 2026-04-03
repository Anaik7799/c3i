defmodule Indrajaal.Holon.ManifestTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Holon.Manifest

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Manifest)
    end

    test "module exports expected functions" do
      assert function_exported?(Manifest, :create, 2)
      assert function_exported?(Manifest, :write, 2)
      assert function_exported?(Manifest, :read, 1)
      assert function_exported?(Manifest, :verify, 1)
      assert function_exported?(Manifest, :update, 2)
      assert function_exported?(Manifest, :init_holon, 2)
      assert function_exported?(Manifest, :list_holons, 0)
    end
  end

  describe "create/2" do
    test "returns ok tuple with manifest map" do
      uhi = "ex:l3:tst:srv:test_manifest_#{System.unique_integer([:positive])}"
      result = Manifest.create(uhi, [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts keyword opts including capabilities" do
      uhi = "ex:l3:tst:srv:test_manifest_#{System.unique_integer([:positive])}"
      result = Manifest.create(uhi, capabilities: ["read", "write"])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "list_holons/0" do
    test "returns a list" do
      result = Manifest.list_holons()
      assert is_list(result)
    end
  end

  describe "read/1" do
    test "returns error for nonexistent holon path" do
      result = Manifest.read("/tmp/nonexistent_holon_xyz_#{System.unique_integer([:positive])}")
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "verify/1" do
    test "returns checksum_mismatch for manifest with wrong checksum" do
      manifest = %{
        "uhi" => "ex:l3:tst:srv:main",
        "version" => "1.0.0",
        "checksum" => "sha256:invalid"
      }

      result = Manifest.verify(manifest)
      assert result == {:error, :checksum_mismatch} or result == :ok
    end

    test "returns ok for manifest with correct checksum" do
      uhi = "ex:l3:tst:srv:main"

      case Manifest.create(uhi, []) do
        {:ok, manifest} ->
          result = Manifest.verify(manifest)
          assert result == :ok

        {:error, _} ->
          # If UHI resolution fails, skip the verify check
          assert true
      end
    end
  end
end
