defmodule Indrajaal.Runtime.SSLFixTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Runtime.SSLFix

  test "module exists" do
    assert Code.ensure_loaded?(SSLFix)
  end

  test "init/0 is exported" do
    assert function_exported?(SSLFix, :init, 0)
  end

  test "init/0 returns :ok or :error atom" do
    result = SSLFix.init()
    assert result in [:ok, :error]
  end
end
