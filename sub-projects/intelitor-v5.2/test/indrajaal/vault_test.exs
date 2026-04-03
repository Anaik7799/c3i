defmodule Indrajaal.VaultTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Vault

  test "module exists" do
    assert Code.ensure_loaded?(Vault)
  end

  test "encrypt!/2 is exported" do
    assert function_exported?(Vault, :encrypt!, 2)
  end

  test "decrypt!/2 is exported" do
    assert function_exported?(Vault, :decrypt!, 2)
  end
end
