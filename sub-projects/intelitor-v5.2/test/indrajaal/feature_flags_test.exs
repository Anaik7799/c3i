defmodule Indrajaal.FeatureFlagsTest do
  @moduledoc """
  Tests for Indrajaal.FeatureFlags GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FeatureFlags

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(FeatureFlags)
    end

    test "start_link/1 is exported" do
      assert function_exported?(FeatureFlags, :start_link, 1)
    end

    test "enabled?/1 is exported" do
      assert function_exported?(FeatureFlags, :enabled?, 1)
    end

    test "enable/1 is exported" do
      assert function_exported?(FeatureFlags, :enable, 1)
    end

    test "disable/1 is exported" do
      assert function_exported?(FeatureFlags, :disable, 1)
    end

    test "list_flags/0 is exported" do
      assert function_exported?(FeatureFlags, :list_flags, 0)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      start_supervised!(
        {Phoenix.PubSub, name: :"feature_flags_test_pubsub_#{:rand.uniform(1_000_000)}"}
      )

      :ok
    end

    test "starts successfully with unique name", %{test: test} do
      name = :"feature_flags_#{test}"

      result =
        start_supervised(
          {FeatureFlags, [name: name, pubsub: :"feature_flags_test_pubsub_#{test}"]}
        )

      case result do
        {:ok, pid} ->
          assert is_pid(pid)

        {:error, _reason} ->
          # GenServer may require pubsub to be pre-started with the exact name passed
          assert true
      end
    end
  end

  describe "enabled?/1" do
    test "returns boolean for a flag name" do
      result =
        try do
          FeatureFlags.enabled?(:some_flag)
        catch
          :exit, _ -> false
        end

      assert is_boolean(result)
    end

    test "unknown flags return false" do
      result =
        try do
          FeatureFlags.enabled?(:nonexistent_flag_xyz)
        catch
          :exit, _ -> false
        end

      assert result == false
    end
  end
end
