defmodule Indrajaal.BaseDomainTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.BaseDomain

  test "module exists" do
    assert Code.ensure_loaded?(BaseDomain)
  end

  test "provides __using__ macro" do
    assert macro_exported?(BaseDomain, :__using__, 1)
  end
end
