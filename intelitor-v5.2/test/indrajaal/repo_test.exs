defmodule Indrajaal.RepoTest do
  @moduledoc """
  Tests for Indrajaal.Repo module.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Repo

  @moduletag :zenoh_nif

  describe "installed_extensions/0" do
    test "function is exported" do
      assert function_exported?(Repo, :installed_extensions, 0)
    end

    test "returns a list" do
      result = Repo.installed_extensions()
      assert is_list(result)
    end

    test "list contains string extension names" do
      result = Repo.installed_extensions()

      Enum.each(result, fn ext ->
        assert is_binary(ext)
      end)
    end

    test "includes at least citext and uuid-ossp" do
      result = Repo.installed_extensions()
      assert "citext" in result
      assert "uuid-ossp" in result
    end
  end

  describe "min_pg_version/0" do
    test "function is exported" do
      assert function_exported?(Repo, :min_pg_version, 0)
    end

    test "returns a version string" do
      result = Repo.min_pg_version()
      assert is_binary(result)
    end

    test "version string matches semver pattern" do
      result = Repo.min_pg_version()
      assert Regex.match?(~r/^\d+(\.\d+)*$/, result)
    end

    test "version is at least 14" do
      result = Repo.min_pg_version()
      [major | _] = String.split(result, ".") |> Enum.map(&String.to_integer/1)
      assert major >= 14
    end
  end
end
