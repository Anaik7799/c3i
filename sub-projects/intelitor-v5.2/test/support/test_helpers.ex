defmodule Indrajaal.TestHelpers do
  @moduledoc """
  Common test helper functions for bulk data creation and testing utilities.
  """

  alias Indrajaal.Factory
  import ExUnit.Assertions

  # ==================== GENERAL TEST HELPERS ====================

  @doc """
  Waits for an async operation to complete
  """
  @spec wait_for(any(), any()) :: any()
  def wait_for(fun, timeout \\ 5000) do
    wait_until(fun, timeout, 100)
  end

  defp wait_until(_fun, timeout, _interval) when timeout <= 0 do
    flunk("Timeout waiting for condition")
  end

  defp wait_until(fun, timeout, interval) do
    if fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(fun, timeout - interval, interval)
    end
  end

  @doc """
  Asserts that an event was published
  """
  @spec assert_event_published(any(), any()) :: any()
  def assert_event_published(event_type, timeout \\ 1000) do
    assert_receive {:event, ^event_type, _payload}, timeout
  end

  @doc """
  Creates multiple records efficiently
  """
  @spec create_many(term(), term(), term()) :: term()
  def create_many(factory_name, count, attrs \\ %{}) do
    Enum.map(1..count, fn _ ->
      Indrajaal.Factory.insert(factory_name, attrs)
    end)
  end

  @doc """
  Measures execution time of a function
  """
  @spec measure_time(any()) :: any()
  def measure_time(fun) do
    start = System.monotonic_time()
    result = fun.()
    time = System.monotonic_time() - start
    {result, System.convert_time_unit(time, :native, :microsecond)}
  end

  @doc """
  Asserts that a function raises a specific exception
  """
  @spec assert_error_raised(term(), term(), term()) :: term()
  def assert_error_raised(fun, exception, message) do
    assert_raise exception, message, fun
  end

  @doc """
  Captures logs during test execution
  """
  @spec capture_log(any()) :: any()
  def capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end

  @doc """
  Sets up a mock for testing
  """
  @spec setup_mock(term(), term(), term()) :: term()
  def setup_mock(module, fun_name, return_value) do
    Mox.stub(module, fun_name, fn _ -> return_value end)
  end

  # ==================== BULK DATA CREATION FUNCTIONS ====================

  @spec bulk_create_organizations(any(), any()) :: any()
  def bulk_create_organizations(tenant, count) do
    Enum.map(1..count, fn i ->
      type = Enum.random([:primary, :subsidiary, :department, :division, :branch])

      Factory.insert(:organization, %{
        tenant: tenant,
        name: "Organization #{i}",
        type: type
      })
    end)
  end

  @spec bulk_create_system_configs(any()) :: any()
  def bulk_create_system_configs(count) do
    tenant = Factory.insert(:tenant)
    categories = [:general, :security, :features, :integrations, :appearance]

    Enum.map(1..count, fn i ->
      Factory.insert(:system_config, %{
        tenant: tenant,
        key: "config.key.#{i}",
        value: %{"value" => "value_#{i}"},
        category: Enum.random(categories)
      })
    end)
  end

  @spec bulk_create_feature_flags(any()) :: any()
  def bulk_create_feature_flags(count) do
    tenant = Factory.insert(:tenant)

    Enum.map(1..count, fn i ->
      Factory.insert(:feature_flag, %{
        tenant: tenant,
        name: "feature_#{i}",
        enabled: Enum.random([true, false]),
        rollout_percentage: Enum.random(0..100)
      })
    end)
  end

  @spec bulk_create_audit_logs(any(), any()) :: any()
  def bulk_create_audit_logs(tenant, count) do
    actions = ["create", "update", "delete", "read", "authenticate"]
    resources = ["user", "organization", "device", "alarm", "config"]

    Enum.map(1..count, fn i ->
      Factory.insert(:audit_log, %{
        tenant: tenant,
        actor_id: Ecto.UUID.generate(),
        actor_type: "user",
        action: Enum.random(actions),
        resource_type: Enum.random(resources),
        resource_id: Ecto.UUID.generate(),
        metadata: %{
          "index" => i,
          "test" => true
        }
      })
    end)
  end

  @spec bulk_create_tenants(any()) :: any()
  def bulk_create_tenants(count) do
    tiers = [:basic, :standard, :professional, :enterprise]
    statuses = [:active, :suspended, :trial]

    Enum.map(1..count, fn i ->
      Factory.insert(:tenant, %{
        name: "Tenant #{i}",
        slug: "tenant-#{i}",
        subscription_tier: Enum.random(tiers),
        status: Enum.random(statuses)
      })
    end)
  end

  # Insert list helper (if not already provided by ExMachina)
  @spec insert_list(term(), term(), term()) :: term()
  def insert_list(count, factory, attrs \\ %{}) do
    Enum.map(1..count, fn _ ->
      Factory.insert(factory, attrs)
    end)
  end
end
