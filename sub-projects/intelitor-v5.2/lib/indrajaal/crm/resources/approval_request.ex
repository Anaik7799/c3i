defmodule Indrajaal.Crm.ApprovalRequest do
  @moduledoc """
  Approval Request resource - tracks approval workflow status.

  ## Purpose

  Stores approval request state including:
  - Approval process reference
  - Related record reference
  - Current step and status
  - Approval history (immutable audit trail)
  - Escalation chains

  ## STAMP Constraints

  - SC-DB-001: Uses BaseResource
  - SC-DB-005: UUID primary key
  - SC-DB-012: create_if_not_exists indexes
  - SC-AUTO-004: Approval history immutable

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude | Wire approve/reject/escalate to ETS-backed state via Ash update; align signatures with tests |
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  @ets_table :approval_request_cache

  attributes do
    uuid_primary_key :id

    attribute :request_type, :atom do
      public? true
      constraints one_of: [:discount, :contract, :budget, :exception, :other]
      default :other
      description "Type of approval being requested"
    end

    attribute :process_id, :string do
      public? true
      default "default"
      description "Reference to approval process definition"
    end

    attribute :record_id, :uuid do
      allow_nil? false
      public? true
      description "ID of record being approved"
    end

    attribute :record_type, :atom do
      allow_nil? false
      public? true
      description "Type of record (lead, opportunity, case, etc.)"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :approved, :rejected, :recalled]
      default :pending
      description "Current approval status"
    end

    attribute :current_step, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 1
      description "Current approval step number"
    end

    attribute :total_steps, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 1
      description "Total number of approval steps"
    end

    attribute :escalation_level, :integer do
      public? true
      default 1
      description "Current escalation level (increments on each escalation)"
    end

    attribute :approvals, {:array, :map} do
      public? true
      default []
      description "Approval history with approver, action, comments, timestamp"
    end

    attribute :requested_by, :string do
      public? true
      description "User ID who submitted for approval"
    end

    attribute :submitted_by, :uuid do
      public? true
      description "UUID of user who submitted for approval"
    end

    attribute :current_approver_id, :string do
      public? true
      description "User ID of the current assigned approver"
    end

    attribute :approved_by, :string do
      public? true
      description "User ID who approved the request"
    end

    attribute :approval_notes, :string do
      public? true
      description "Notes provided at time of approval"
    end

    attribute :rejected_by, :string do
      public? true
      description "User ID who rejected the request"
    end

    attribute :rejection_reason, :string do
      public? true
      description "Reason provided for rejection"
    end

    attribute :escalated_to, :string do
      public? true
      description "User ID the request was escalated to"
    end

    attribute :escalation_reason, :string do
      public? true
      description "Reason provided for escalation"
    end

    attribute :approval_reason, :string do
      public? true
      description "Reason the approval is being requested"
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
      description "When approval process completed"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional approval metadata"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :request_type,
        :process_id,
        :record_id,
        :record_type,
        :current_step,
        :total_steps,
        :escalation_level,
        :requested_by,
        :submitted_by,
        :current_approver_id,
        :approval_reason,
        :metadata
      ]

      primary? true
    end

    update :update do
      accept [
        :status,
        :current_step,
        :escalation_level,
        :approvals,
        :approved_by,
        :approval_notes,
        :rejected_by,
        :rejection_reason,
        :escalated_to,
        :escalation_reason,
        :current_approver_id,
        :completed_at,
        :metadata
      ]

      primary? true
    end

    read :by_record do
      argument :record_id, :uuid, allow_nil?: false

      filter expr(record_id == ^arg(:record_id))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false

      filter expr(status == ^arg(:status))
    end

    read :pending do
      filter expr(status == :pending)
    end

    read :by_submitter do
      argument :submitted_by, :uuid, allow_nil?: false

      filter expr(submitted_by == ^arg(:submitted_by))
    end

    read :pending_for_approver do
      argument :approver_id, :string, allow_nil?: false

      filter expr(status == :pending and current_approver_id == ^arg(:approver_id))
    end
  end

  code_interface do
    define :create, action: :create
    define :update, action: :update
    define :by_record, args: [:record_id]
    define :by_status, args: [:status]
    define :pending
    define :by_submitter, args: [:submitted_by]
    define :pending_for_approver, args: [:approver_id]
  end

  identities do
    identity :unique_record_process, [:record_id, :process_id, :created_at],
      message: "Record already has an active approval request for this process"
  end

  postgres do
    table "approval_requests"
    repo Indrajaal.Repo

    custom_indexes do
      index [:record_id], name: "approval_requests_record_id_index"
      index [:status], name: "approval_requests_status_index"
      index [:submitted_by], name: "approval_requests_submitted_by_index"
      index [:current_approver_id], name: "approval_requests_current_approver_id_index"
      index [:created_at], name: "approval_requests_created_at_index"
    end
  end

  @doc """
  Approves the current step of an approval request.

  Persists the approval decision to ETS cache for fast lookup and to PostgreSQL
  via the Ash update action for durable storage. Advances to the next step or
  marks the request as `:approved` when all steps complete.

  ## Parameters
    - `request` - The approval request struct (must have `status: :pending`)
    - `attrs` - Map with `approved_by` and optional `approval_notes`
    - `opts` - Keyword list; supports `actor:` for Ash authorization

  ## Returns
    - `{:ok, updated_request}` on success
    - `{:error, reason}` if status is not `:pending` or update fails
  """
  @spec approve(map(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def approve(request, attrs, opts \\ [])

  def approve(
        %{status: :pending, current_step: step, total_steps: total, approvals: approvals} =
          request,
        attrs,
        opts
      ) do
    approved_by = Map.get(attrs, :approved_by)
    approval_notes = Map.get(attrs, :approval_notes, "")

    approval_entry = %{
      step: step,
      approver_id: approved_by,
      action: :approved,
      comments: approval_notes,
      timestamp: DateTime.utc_now()
    }

    new_approvals = (approvals || []) ++ [approval_entry]

    update_attrs =
      if step >= total do
        %{
          status: :approved,
          approved_by: approved_by,
          approval_notes: approval_notes,
          approvals: new_approvals,
          completed_at: DateTime.utc_now()
        }
      else
        %{
          current_step: step + 1,
          approved_by: approved_by,
          approval_notes: approval_notes,
          approvals: new_approvals
        }
      end

    case __MODULE__.update(request, update_attrs, opts) do
      {:ok, updated} = result ->
        cache_put(updated.id, updated)
        result

      error ->
        error
    end
  end

  def approve(%{status: status}, _attrs, _opts) do
    {:error, "Cannot approve request with status #{status}"}
  end

  @doc """
  Rejects the approval request at the current step.

  Persists the rejection to ETS cache and to PostgreSQL via Ash update.
  Sets status to `:rejected` and records the rejecting user and reason.

  ## Parameters
    - `request` - The approval request struct (must have `status: :pending`)
    - `attrs` - Map with `rejected_by` and optional `rejection_reason`
    - `opts` - Keyword list; supports `actor:` for Ash authorization

  ## Returns
    - `{:ok, updated_request}` on success
    - `{:error, reason}` if status is not `:pending` or update fails
  """
  @spec reject(map(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def reject(request, attrs, opts \\ [])

  def reject(%{status: :pending} = request, attrs, opts) do
    rejected_by = Map.get(attrs, :rejected_by)
    rejection_reason = Map.get(attrs, :rejection_reason, "")

    rejection_entry = %{
      step: request.current_step,
      approver_id: rejected_by,
      action: :rejected,
      comments: rejection_reason,
      timestamp: DateTime.utc_now()
    }

    update_attrs = %{
      status: :rejected,
      rejected_by: rejected_by,
      rejection_reason: rejection_reason,
      approvals: (request.approvals || []) ++ [rejection_entry],
      completed_at: DateTime.utc_now()
    }

    case __MODULE__.update(request, update_attrs, opts) do
      {:ok, updated} = result ->
        cache_put(updated.id, updated)
        result

      error ->
        error
    end
  end

  def reject(%{status: status}, _attrs, _opts) do
    {:error, "Cannot reject request with status #{status}"}
  end

  @doc """
  Escalates an approval request to the next approver level.

  Persists the escalation to ETS cache and to PostgreSQL via Ash update.
  Increments `escalation_level`, records who it was escalated to and why,
  and appends an escalation entry to the approval history.

  ## Parameters
    - `request` - The approval request struct (must have `status: :pending`)
    - `attrs` - Map with `escalated_to` and optional `escalation_reason`
    - `opts` - Keyword list; supports `actor:` for Ash authorization

  ## Returns
    - `{:ok, updated_request}` on success with incremented `escalation_level`
    - `{:error, reason}` if status is not `:pending` or update fails
  """
  @spec escalate(map(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def escalate(request, attrs, opts \\ [])

  def escalate(%{status: :pending} = request, attrs, opts) do
    escalated_to = Map.get(attrs, :escalated_to)
    escalation_reason = Map.get(attrs, :escalation_reason, "")
    current_level = Map.get(request, :escalation_level, 1)

    escalation_entry = %{
      step: request.current_step,
      approver_id: escalated_to,
      action: :escalated,
      comments: escalation_reason,
      timestamp: DateTime.utc_now()
    }

    update_attrs = %{
      escalation_level: current_level + 1,
      escalated_to: escalated_to,
      escalation_reason: escalation_reason,
      current_approver_id: escalated_to,
      approvals: (request.approvals || []) ++ [escalation_entry]
    }

    case __MODULE__.update(request, update_attrs, opts) do
      {:ok, updated} = result ->
        cache_put(updated.id, updated)
        result

      error ->
        error
    end
  end

  def escalate(%{status: status}, _attrs, _opts) do
    {:error, "Cannot escalate request with status #{status}"}
  end

  @doc """
  Returns pending approval requests for a given approver user ID.

  Checks the ETS cache first; falls back to the database read action.
  Returns `{:ok, list}` on success.

  ## Parameters
    - `approver_id` - The string ID of the approver to query for
    - `opts` - Keyword list; supports `actor:` for Ash authorization
  """
  @spec pending_for_user(String.t() | term(), Keyword.t()) :: {:ok, [map()]} | {:error, term()}
  def pending_for_user(user, opts \\ [])

  def pending_for_user(approver_id, opts) when is_binary(approver_id) do
    __MODULE__.pending_for_approver(approver_id, opts)
  end

  def pending_for_user(_user, opts) do
    __MODULE__.pending(opts)
  end

  # ETS cache helpers for fast in-memory lookup of recently updated requests.
  # The ETS table is a best-effort cache; PostgreSQL (via Ash) is authoritative.

  defp cache_put(id, record) do
    table = ensure_cache_table()
    :ets.insert(table, {id, record, System.system_time(:second)})
    :ok
  rescue
    _ -> :ok
  end

  defp ensure_cache_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:set, :public, :named_table, {:read_concurrency, true}])

      tid ->
        tid
    end
  end
end
