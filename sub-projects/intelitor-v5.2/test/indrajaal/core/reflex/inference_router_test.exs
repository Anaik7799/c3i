defmodule Indrajaal.Core.Reflex.InferenceRouterTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Core.Reflex.InferenceRouter

  describe "available_backends/0" do
    test "returns list of backend tuples" do
      backends = InferenceRouter.available_backends()
      assert is_list(backends)
      assert length(backends) == 3

      backend_names = Enum.map(backends, fn {name, _status} -> name end)
      assert :openrouter in backend_names
      assert :mojo in backend_names
      assert :reflex in backend_names
    end

    test "each backend has a valid status" do
      valid_statuses = [:healthy, :degraded, :unavailable, :circuit_open]

      for {_name, status} <- InferenceRouter.available_backends() do
        assert status in valid_statuses,
               "Expected status in #{inspect(valid_statuses)}, got #{inspect(status)}"
      end
    end
  end

  describe "route/3 with :fast strategy" do
    test "only attempts ReflexCore backend" do
      # ReflexCore is not running, so this should fail gracefully
      result = InferenceRouter.route(:test_task, "hello", strategy: :fast)
      assert {:error, :all_backends_failed} = result
    end
  end

  describe "route/3 with :external strategy" do
    test "only attempts OpenRouter backend" do
      # No API key set, should fail
      result = InferenceRouter.route(:test_task, "hello", strategy: :external)
      assert {:error, :all_backends_failed} = result
    end
  end

  describe "route/3 with :local strategy" do
    test "attempts Mojo then Reflex" do
      # Neither running, should fail
      result = InferenceRouter.route(:test_task, "hello", strategy: :local)
      assert {:error, :all_backends_failed} = result
    end
  end

  describe "route/3 with :best strategy" do
    test "falls through all backends when none available" do
      result = InferenceRouter.route(:test_task, "hello", strategy: :best)
      assert {:error, :all_backends_failed} = result
    end
  end

  describe "sovereignty modes" do
    test ":airgap filters out external backends" do
      result =
        InferenceRouter.route(:test_task, "hello",
          strategy: :best,
          sovereignty: :airgap
        )

      assert {:error, :all_backends_failed} = result
    end

    test ":degraded only uses reflex" do
      result =
        InferenceRouter.route(:test_task, "hello",
          strategy: :best,
          sovereignty: :degraded
        )

      assert {:error, :all_backends_failed} = result
    end

    test ":symbiotic uses full chain (default)" do
      result =
        InferenceRouter.route(:test_task, "hello",
          strategy: :best,
          sovereignty: :symbiotic
        )

      assert {:error, :all_backends_failed} = result
    end
  end
end
