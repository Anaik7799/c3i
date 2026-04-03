defmodule Indrajaal.Authentication.AuthenticationLogTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Authentication.AuthenticationLog

  test "module exists" do
    assert Code.ensure_loaded?(AuthenticationLog)
  end

  test "is an Ash.Resource" do
    assert function_exported?(AuthenticationLog, :spark_dsl_config, 0)
  end
end
