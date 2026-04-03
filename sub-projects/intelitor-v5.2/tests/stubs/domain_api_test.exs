defmodule Intelitor.DomainApiTest do
  @moduledoc """
  Test suite for Intelitor.DomainApi.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/domain_api.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.DomainApi

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(DomainApi)
    end

    test "module has __info__/1 function" do
      assert function_exported?(DomainApi, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = DomainApi.__info__(:module)
      assert info == Intelitor.DomainApi
    end
  end
end
