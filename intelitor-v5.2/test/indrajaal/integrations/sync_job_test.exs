defmodule Indrajaal.Integrations.SyncJobTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integrations.SyncJob

  describe "module structure" do
    test "module is loadable" do
      assert Code.ensure_loaded?(SyncJob)
    end

    test "is an Ash.Resource (exposes spark_dsl_config/0)" do
      assert function_exported?(SyncJob, :spark_dsl_config, 0)
    end

    test "spark_dsl_config/0 returns a non-nil value" do
      config = SyncJob.spark_dsl_config()
      assert not is_nil(config)
    end
  end

  describe "attribute definitions" do
    test "has expected public attributes" do
      attrs = Ash.Resource.Info.public_attributes(SyncJob)
      attr_names = Enum.map(attrs, & &1.name)

      assert :name in attr_names
      assert :job_type in attr_names
      assert :status in attr_names
      assert :direction in attr_names
      assert :batch_size in attr_names
      assert :records_processed in attr_names
      assert :records_succeeded in attr_names
      assert :records_failed in attr_names
      assert :enabled? in attr_names
      assert :retry_count in attr_names
      assert :max_retries in attr_names
    end

    test "status attribute defaults to :pending" do
      attr = Ash.Resource.Info.attribute(SyncJob, :status)
      assert not is_nil(attr)
      assert attr.default == :pending
    end

    test "job_type attribute defaults to :scheduled" do
      attr = Ash.Resource.Info.attribute(SyncJob, :job_type)
      assert not is_nil(attr)
      assert attr.default == :scheduled
    end

    test "batch_size attribute defaults to 100" do
      attr = Ash.Resource.Info.attribute(SyncJob, :batch_size)
      assert not is_nil(attr)
      assert attr.default == 100
    end

    test "enabled? attribute defaults to true" do
      attr = Ash.Resource.Info.attribute(SyncJob, :enabled?)
      assert not is_nil(attr)
      assert attr.default == true
    end

    test "records_processed defaults to 0" do
      attr = Ash.Resource.Info.attribute(SyncJob, :records_processed)
      assert not is_nil(attr)
      assert attr.default == 0
    end

    test "max_retries defaults to 3" do
      attr = Ash.Resource.Info.attribute(SyncJob, :max_retries)
      assert not is_nil(attr)
      assert attr.default == 3
    end

    test "retry_count defaults to 0" do
      attr = Ash.Resource.Info.attribute(SyncJob, :retry_count)
      assert not is_nil(attr)
      assert attr.default == 0
    end
  end

  describe "actions" do
    test "has standard CRUD actions" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :create in action_names
      assert :read in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has :start action" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :start in action_names
    end

    test "has :complete action" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :complete in action_names
    end

    test "has :fail action" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :fail in action_names
    end

    test "has :cancel action" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :cancel in action_names
    end

    test "has :enable and :disable actions" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :enable in action_names
      assert :disable in action_names
    end

    test "has :update_progress action" do
      action_names = SyncJob |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :update_progress in action_names
    end
  end

  describe "calculations" do
    test "has duration_seconds calculation" do
      calc_names = SyncJob |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :duration_seconds in calc_names
    end

    test "has success_rate calculation" do
      calc_names = SyncJob |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :success_rate in calc_names
    end

    test "has is_overdue? calculation" do
      calc_names = SyncJob |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :is_overdue? in calc_names
    end

    test "has should_retry? calculation" do
      calc_names = SyncJob |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :should_retry? in calc_names
    end
  end
end
