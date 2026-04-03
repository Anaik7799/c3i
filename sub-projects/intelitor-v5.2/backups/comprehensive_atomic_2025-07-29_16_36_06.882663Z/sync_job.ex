defmodule Intelitor.Integrations.SyncJob do
  @moduledoc """
  Manages synchronization jobs for data exchange with external systems.

  Sync jobs handle the scheduled and real-time synchronization of data
  between Intelitor and external systems using defined data mappings.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Integrations,
    table: "integration_sync_jobs"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :job_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:scheduled, :real_time, :manual, :triggered]
      default :scheduled
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :running, :completed, :failed, :cancelled]
      default :pending
    end

    attribute :direction, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pull, :push, :sync]
    end

    attribute :schedule_cron, :string do
      public? true
      constraints max_length: 100
    end

    attribute :batch_size, :integer do
      allow_nil? false
      public? true
      default 100
      constraints min: 1, max: 10000
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :next_run_at, :utc_datetime_usec do
      public? true
    end

    attribute :records_processed, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :records_succeeded, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :records_failed, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :error_details, :map do
      public? true
      default %{}
    end

    attribute :configuration, :map do
      public? true
      default %{}
    end

    attribute :result_summary, :map do
      public? true
      default %{}
    end

    attribute :enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :retry_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :max_retries, :integer do
      allow_nil? false
      public? true
      default 3
      constraints min: 0, max: 10
    end

    attribute :created_by, :uuid do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :api_connection, Intelitor.Integrations.ApiConnection do
      allow_nil? false
      public? true
    end

    belongs_to :data_mapping, Intelitor.Integrations.DataMapping do
      public? true
    end

    belongs_to :creator, Intelitor.Accounts.User do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    update :start do
      require_atomic? false
      accept []

      validate attribute_in(:status, [:pending, :failed])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :running)
        |> Ash.Changeset.change_attribute(:started_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:completed_at, nil)
        |> Ash.Changeset.change_attribute(:error_message, nil)
        |> Ash.Changeset.change_attribute(:records_processed, 0)
        |> Ash.Changeset.change_attribute(:records_succeeded, 0)
        |> Ash.Changeset.change_attribute(:records_failed, 0)
      end
    end

    update :complete do
      require_atomic? false
      argument :summary, :map do
        default %{}
      end

      validate attribute_equals(:status, :running)

      change fn changeset, _context ->
        now = DateTime.utc_now()
        summary = Ash.Changeset.get_argument(changeset, :summary)

        changeset
        |> Ash.Changeset.change_attribute(:status, :completed)
        |> Ash.Changeset.change_attribute(:completed_at, now)
        |> Ash.Changeset.change_attribute(:result_summary, summary)
        |> Ash.Changeset.change_attribute(:retry_count, 0)
      end
    end

    update :fail do
      require_atomic? false
      argument :error_message, :string do
        allow_nil? false
        constraints max_length: 2000
      end

      argument :error_details, :map do
        default %{}
      end

      validate attribute_equals(:status, :running)

      change fn changeset, _context ->
        now = DateTime.utc_now()
        error_message = Ash.Changeset.get_argument(changeset, :error_message)
        error_details = Ash.Changeset.get_argument(changeset, :error_details)
        retry_count = Ash.Changeset.get_attribute(changeset, :retry_count)

        changeset
        |> Ash.Changeset.change_attribute(:status, :failed)
        |> Ash.Changeset.change_attribute(:completed_at, now)
        |> Ash.Changeset.change_attribute(:error_message, error_message)
        |> Ash.Changeset.change_attribute(:error_details, error_details)
        |> Ash.Changeset.change_attribute(:retry_count, retry_count + 1)
      end
    end

    update :cancel do
      require_atomic? false
      accept []
      validate attribute_in(:status, [:pending, :running])
      change set_attribute(:status, :cancelled)
      change set_attribute(:completed_at, DateTime.utc_now())
    end

    update :enable do
      require_atomic? false
      accept []
      change set_attribute(:enabled?, true)
    end

    update :disable do
      require_atomic? false
      accept []
      change set_attribute(:enabled?, false)
    end

    update :update_progress do
      require_atomic? false
      argument :processed, :integer do
        allow_nil? false
        constraints min: 0
      end

      argument :succeeded, :integer do
        allow_nil? false
        constraints min: 0
      end

      argument :failed, :integer do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, _context ->
        processed = Ash.Changeset.get_argument(changeset, :processed)
        succeeded = Ash.Changeset.get_argument(changeset, :succeeded)
        failed = Ash.Changeset.get_argument(changeset, :failed)

        changeset
        |> Ash.Changeset.change_attribute(:records_processed, processed)
        |> Ash.Changeset.change_attribute(:records_succeeded, succeeded)
        |> Ash.Changeset.change_attribute(:records_failed, failed)
      end
    end
  end

  calculations do
    calculate :duration_seconds, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn job ->
          if job.started_at && job.completed_at do
            DateTime.diff(job.completed_at, job.started_at, :second)
          else
            nil
          end
        end)
      end
    end

    calculate :success_rate, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn job ->
          if job.records_processed > 0 do
            Float.round(job.records_succeeded / job.records_processed * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    calculate :is_overdue?, :boolean do
      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn job ->
          job.next_run_at && DateTime.compare(now, job.next_run_at) == :gt &&
            job.status == :pending && job.enabled?
        end)
      end
    end

    calculate :should_retry?, :boolean do
      calculation fn records, _opts ->
        Enum.map(records, fn job ->
          job.status == :failed && job.retry_count < job.max_retries
        end)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
      job_type = Ash.Changeset.get_attribute(changeset, :job_type)
      schedule_cron = Ash.Changeset.get_attribute(changeset, :schedule_cron)

      if job_type == :scheduled && is_nil(schedule_cron) do
        {:error, field: :schedule_cron, message: "required for scheduled jobs"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, _context ->
      processed = Ash.Changeset.get_attribute(changeset, :records_processed)
      succeeded = Ash.Changeset.get_attribute(changeset, :records_succeeded)
      failed = Ash.Changeset.get_attribute(changeset, :records_failed)

      if succeeded + failed > processed do
        {:error, field: :records_processed, message: "cannot be less than succeeded + failed"}
      else
        {:ok, changeset}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "integration_admin")
    end

    policy action([:start, :complete, :fail, :cancel, :update_progress]) do
      # System can update job status
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :start
    define :complete
    define :fail
    define :cancel
    define :enable
    define :disable
    define :update_progress
  end

  postgres do
    table "integration_sync_jobs"
    repo Intelitor.Repo

    custom_indexes do
      index [:api_connection_id]
      index [:data_mapping_id], where: "data_mapping_id IS NOT NULL"
      index [:status]
      index [:job_type]
      index [:enabled?], name: "sync_jobs_enabled_index", where: "enabled? = true"
      index [:next_run_at], where: "next_run_at IS NOT NULL AND enabled? = true"
      index [:created_by]
    end
  end
end
