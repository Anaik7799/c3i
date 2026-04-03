defmodule Indrajaal.KmsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS

  test "module exists" do
    assert Code.ensure_loaded?(KMS)
  end

  test "has public API functions" do
    # KMS is a facade, verify key exports
    assert function_exported?(KMS, :store_secret, 2) or
             function_exported?(KMS, :get_secret, 1) or
             function_exported?(KMS, :encrypt, 2) or
             function_exported?(KMS, :decrypt, 2)
  end
end
