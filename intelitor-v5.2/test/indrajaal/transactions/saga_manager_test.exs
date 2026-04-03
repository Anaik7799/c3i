defmodule Indrajaal.Transactions.SagaManagerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Transactions.SagaManager

  test "module exists" do
    assert Code.ensure_loaded?(SagaManager)
  end

  test "start_link/1 is exported" do
    assert function_exported?(SagaManager, :start_link, 1)
  end

  test "start_saga/3 is exported" do
    assert function_exported?(SagaManager, :start_saga, 3)
  end

  test "compensate/2 is exported" do
    assert function_exported?(SagaManager, :compensate, 2)
  end
end
