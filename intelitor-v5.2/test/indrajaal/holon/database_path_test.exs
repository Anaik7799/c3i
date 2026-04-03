defmodule Indrajaal.Holon.DatabasePathTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Holon.DatabasePath

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DatabasePath)
    end

    test "module exports expected functions" do
      assert function_exported?(DatabasePath, :resolve, 1)
      assert function_exported?(DatabasePath, :resolve!, 1)
      assert function_exported?(DatabasePath, :build_uhi, 5)
      assert function_exported?(DatabasePath, :build_fqdn, 2)
      assert function_exported?(DatabasePath, :holon_dir, 1)
      assert function_exported?(DatabasePath, :all_databases, 1)
      assert function_exported?(DatabasePath, :elixir_holon?, 1)
      assert function_exported?(DatabasePath, :fsharp_holon?, 1)
      assert function_exported?(DatabasePath, :zenoh_topic, 2)
      assert function_exported?(DatabasePath, :from_legacy, 1)
      assert function_exported?(DatabasePath, :domains, 0)
      assert function_exported?(DatabasePath, :db_types, 0)
    end
  end

  describe "build_uhi/5" do
    test "returns ok tuple with UHI binary string" do
      result = DatabasePath.build_uhi(:elixir, :l3, :kms, :srv, "main")
      assert match?({:ok, _}, result)
      {:ok, uhi} = result
      assert is_binary(uhi)
      assert String.contains?(uhi, "ex")
      assert String.contains?(uhi, "l3")
      assert String.contains?(uhi, "kms")
    end

    test "returns error for invalid runtime" do
      result = DatabasePath.build_uhi(:invalid_runtime, :l3, :kms, :srv, "main")
      assert match?({:error, _}, result)
    end
  end

  describe "build_fqdn/2" do
    test "returns ok tuple with FQDN binary string" do
      {:ok, uhi} = DatabasePath.build_uhi(:elixir, :l3, :kms, :srv, "main")
      result = DatabasePath.build_fqdn(uhi, :state)
      assert match?({:ok, _}, result)
      {:ok, fqdn} = result
      assert is_binary(fqdn)
      assert String.contains?(fqdn, uhi)
    end

    test "returns error for invalid db type" do
      {:ok, uhi} = DatabasePath.build_uhi(:elixir, :l3, :kms, :srv, "main")
      result = DatabasePath.build_fqdn(uhi, :invalid_type)
      assert match?({:error, _}, result)
    end
  end

  describe "resolve/1" do
    test "returns ok tuple for valid FQDN" do
      result = DatabasePath.resolve("ex:l3:kms:srv:main:state")
      assert match?({:ok, _}, result)
    end

    test "returns error for invalid FQDN format" do
      result = DatabasePath.resolve("not-a-valid-fqdn")
      assert match?({:error, _}, result)
    end

    test "resolved path is a binary" do
      {:ok, path} = DatabasePath.resolve("ex:l3:kms:srv:main:state")
      assert is_binary(path)
    end
  end

  describe "resolve!/1" do
    test "returns binary for valid FQDN" do
      result = DatabasePath.resolve!("ex:l3:kms:srv:main:state")
      assert is_binary(result)
    end

    test "raises for invalid FQDN" do
      assert_raise ArgumentError, fn ->
        DatabasePath.resolve!("not-valid")
      end
    end
  end

  describe "domains/0" do
    test "returns a map of registered domains" do
      result = DatabasePath.domains()
      assert is_map(result)
    end

    test "domains map is non-empty" do
      result = DatabasePath.domains()
      assert map_size(result) > 0
    end

    test "kms domain is registered" do
      result = DatabasePath.domains()
      assert Map.has_key?(result, "kms")
    end
  end

  describe "db_types/0" do
    test "returns a map of database types" do
      result = DatabasePath.db_types()
      assert is_map(result)
    end

    test "state db type is registered" do
      result = DatabasePath.db_types()
      assert Map.has_key?(result, "state")
    end

    test "history db type is registered" do
      result = DatabasePath.db_types()
      assert Map.has_key?(result, "history")
    end
  end

  describe "elixir_holon?/1" do
    test "returns true for ex runtime prefix" do
      result = DatabasePath.elixir_holon?("ex:l3:kms:srv:main")
      assert result == true
    end

    test "returns false for fsharp runtime prefix" do
      result = DatabasePath.elixir_holon?("fs:l4:pln:srv:main")
      assert result == false
    end
  end

  describe "fsharp_holon?/1" do
    test "returns true for fs runtime prefix" do
      result = DatabasePath.fsharp_holon?("fs:l4:pln:srv:main")
      assert result == true
    end

    test "returns false for elixir runtime prefix" do
      result = DatabasePath.fsharp_holon?("ex:l3:kms:srv:main")
      assert result == false
    end
  end

  describe "zenoh_topic/2" do
    test "returns binary topic string for valid UHI" do
      result = DatabasePath.zenoh_topic("ex:l3:kms:srv:main", :query)
      assert is_binary(result)
      assert String.starts_with?(result, "indrajaal/db/")
    end
  end

  describe "from_legacy/1" do
    test "returns ok tuple for known legacy path" do
      result = DatabasePath.from_legacy("data/kms/holons.db")
      assert match?({:ok, _}, result)
    end

    test "returns error for unknown legacy path" do
      result = DatabasePath.from_legacy("data/holons/unknown/state.db")
      assert match?({:error, _}, result)
    end
  end

  describe "holon_dir/1" do
    test "returns ok tuple with binary path string" do
      result = DatabasePath.holon_dir("ex:l3:kms:srv:main")
      assert match?({:ok, _}, result)
      {:ok, dir} = result
      assert is_binary(dir)
    end

    test "returns error for invalid UHI" do
      result = DatabasePath.holon_dir("invalid-uhi")
      assert match?({:error, _}, result)
    end
  end

  describe "all_databases/1" do
    test "returns ok tuple with database map" do
      result = DatabasePath.all_databases("ex:l3:kms:srv:main")
      assert match?({:ok, _}, result)
    end

    test "returned map contains state key" do
      {:ok, databases} = DatabasePath.all_databases("ex:l3:kms:srv:main")
      assert is_map(databases)
      assert Map.has_key?(databases, :state)
    end

    test "returned map contains history key" do
      {:ok, databases} = DatabasePath.all_databases("ex:l3:kms:srv:main")
      assert Map.has_key?(databases, :history)
    end
  end
end
