defmodule Indrajaal.Deployment.PrometheusManagerTest do
  @moduledoc """
  TDG tests for Indrajaal.Deployment.PrometheusManager stub module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Deployment.PrometheusManager

  describe "PrometheusManager module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PrometheusManager)
    end

    test "placeholder/0 is exported" do
      assert function_exported?(PrometheusManager, :placeholder, 0)
    end

    test "placeholder/0 returns :ok" do
      assert PrometheusManager.placeholder() == :ok
    end
  end
end
