defmodule Indrajaal.Compliance.Approval do
  @moduledoc """
  Approval workflow engine for compliance request management.

  ## What
  Manages approval requests including escalation, delegation, recall, and
  auto-approval logic. State is backed by an ETS table (:approval_store)
  that is lazily initialised on first use.

  ## Why
  Compliance workflows require durable, low-latency access to request state
  during the approval lifecycle without depending on the PostgreSQL domain
  database for hot-path operations.

  ## Constraints
  - SC-ENFORCE-001: access to approval state is guarded
  - SC-SAFETY-003: full audit trail via telemetry
  - SC-ORCH-004: operations complete within OODA budget (< 100 ms)
  - AOR-CONST-005: Human primacy — approvals protect human decisions

  ## Change History
  | Version | Date       | Author           | Change           |
  |---------|------------|------------------|------------------|
  | 21.3.0  | 2026-03-23 | Claude Sonnet 4.6 | Initial implementation |
  """

  require Logger

  @approval_store :approval_store
  @auto_approval_threshold 10_000
  @default_chain ["manager", "director", "vp"]

  # ---------------------------------------------------------------------------
  # ETS helpers
  # ---------------------------------------------------------------------------

  defp ensure_table do
    case :ets.whereis(@approval_store) do
      :undefined ->
        :ets.new(@approval_store, [:named_table, :set, :public, read_concurrency: true])

      _tid ->
        @approval_store
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Recalls a pending approval request, marking it as :recalled.

  Returns `{:ok, :recalled}` if the request existed, `{:error, :not_found}`
  otherwise.
  """
  @spec recall_request(String.t(), map()) :: {:ok, :recalled} | {:error, term()}
  def recall_request(request_id, opts \\ %{}) do
    ensure_table()
    start = System.monotonic_time()

    result =
      case :ets.lookup(@approval_store, request_id) do
        [] ->
          Logger.warning("[Approval] recall_request: not found", request_id: request_id)
          {:error, :not_found}

        [{^request_id, record}] ->
          updated = Map.merge(record, %{status: :recalled, recalled_at: DateTime.utc_now()})
          :ets.insert(@approval_store, {request_id, updated})

          Logger.info("[Approval] Request recalled",
            request_id: request_id,
            previous_status: record[:status]
          )

          {:ok, :recalled}
      end

    :telemetry.execute(
      [:approval, :recall],
      %{duration: System.monotonic_time() - start},
      %{request_id: request_id, result: elem(result, 0), opts: opts}
    )

    result
  end

  @doc """
  Escalates an approval request to the next approver in the chain.

  Increments the `escalation_level` field and records the escalation timestamp.
  Returns `{:ok, updated_record}` or `{:error, reason}`.
  """
  @spec escalate_request(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def escalate_request(request_id, opts \\ %{}) do
    ensure_table()
    start = System.monotonic_time()

    result =
      case :ets.lookup(@approval_store, request_id) do
        [] ->
          Logger.warning("[Approval] escalate_request: not found", request_id: request_id)
          {:error, :not_found}

        [{^request_id, record}] ->
          current_level = Map.get(record, :escalation_level, 0)
          new_level = current_level + 1
          chain = Map.get(record, :approval_chain, @default_chain)
          next_approver = Enum.at(chain, new_level)

          updated =
            Map.merge(record, %{
              escalation_level: new_level,
              current_approver: next_approver,
              escalated_at: DateTime.utc_now(),
              status: :escalated
            })

          :ets.insert(@approval_store, {request_id, updated})

          Logger.info("[Approval] Request escalated",
            request_id: request_id,
            escalation_level: new_level,
            next_approver: next_approver
          )

          notify_approvers(request_id, [next_approver])

          {:ok, updated}
      end

    :telemetry.execute(
      [:approval, :escalate],
      %{duration: System.monotonic_time() - start},
      %{request_id: request_id, result: elem(result, 0), opts: opts}
    )

    result
  end

  @doc """
  Notifies the listed approvers of a pending request.

  Emits `[:approval, :notify]` telemetry and logs each notification.
  Always returns `:ok`.
  """
  @spec notify_approvers(String.t(), [String.t()]) :: :ok
  def notify_approvers(request_id, approvers) do
    ensure_table()
    start = System.monotonic_time()

    Enum.each(approvers, fn approver ->
      Logger.info("[Approval] Notifying approver",
        request_id: request_id,
        approver: approver
      )

      :telemetry.execute(
        [:approval, :notify],
        %{duration: System.monotonic_time() - start},
        %{request_id: request_id, approver: approver}
      )
    end)

    :ok
  end

  @doc """
  Delegates an approval request from the current approver to a delegate.

  Stores the `{request_id, delegate}` mapping in ETS and updates the record's
  `current_approver` field. Returns `{:ok, :delegated}` or `{:error, reason}`.
  """
  @spec delegate_request(String.t(), String.t(), map()) ::
          {:ok, :delegated} | {:error, term()}
  def delegate_request(request_id, delegate, opts \\ %{}) do
    ensure_table()
    start = System.monotonic_time()

    result =
      case :ets.lookup(@approval_store, request_id) do
        [] ->
          Logger.warning("[Approval] delegate_request: not found", request_id: request_id)
          {:error, :not_found}

        [{^request_id, record}] ->
          previous_approver = Map.get(record, :current_approver)

          updated =
            Map.merge(record, %{
              current_approver: delegate,
              delegated_from: previous_approver,
              delegated_at: DateTime.utc_now(),
              status: :delegated
            })

          :ets.insert(@approval_store, {request_id, updated})
          # Store delegation index for reverse lookup
          delegation_key = {:delegation, request_id}
          :ets.insert(@approval_store, {delegation_key, delegate})

          Logger.info("[Approval] Request delegated",
            request_id: request_id,
            from: previous_approver,
            to: delegate
          )

          notify_approvers(request_id, [delegate])

          {:ok, :delegated}
      end

    :telemetry.execute(
      [:approval, :delegate],
      %{duration: System.monotonic_time() - start},
      %{request_id: request_id, delegate: delegate, result: elem(result, 0), opts: opts}
    )

    result
  end

  @doc """
  Returns the ordered list of approver IDs for a given request.

  Looks up the approval chain stored in ETS for the request; falls back to
  a configurable default chain if no record is found.
  """
  @spec get_approval_chain(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def get_approval_chain(request_id) do
    ensure_table()
    start = System.monotonic_time()

    result =
      case :ets.lookup(@approval_store, request_id) do
        [] ->
          # No record — return the system-level default chain
          {:ok, @default_chain}

        [{^request_id, record}] ->
          chain = Map.get(record, :approval_chain, @default_chain)
          {:ok, chain}
      end

    :telemetry.execute(
      [:approval, :get_chain],
      %{duration: System.monotonic_time() - start},
      %{request_id: request_id}
    )

    result
  end

  @doc """
  Checks whether a request qualifies for automatic approval.

  Returns `{:ok, :auto_approved}` when the request amount is below
  `@auto_approval_threshold`, or `{:ok, :manual_required}` otherwise.
  When no record is found the safe default is `:manual_required`.
  """
  @spec check_auto_approval(String.t()) ::
          {:ok, :auto_approved} | {:ok, :manual_required} | {:error, term()}
  def check_auto_approval(request_id) do
    ensure_table()
    start = System.monotonic_time()

    result =
      case :ets.lookup(@approval_store, request_id) do
        [] ->
          # Fail-safe: unknown requests require manual review
          {:ok, :manual_required}

        [{^request_id, record}] ->
          amount = Map.get(record, :amount, 0)

          if is_number(amount) and amount < @auto_approval_threshold do
            {:ok, :auto_approved}
          else
            {:ok, :manual_required}
          end
      end

    :telemetry.execute(
      [:approval, :check_auto],
      %{duration: System.monotonic_time() - start},
      %{request_id: request_id, result: elem(result, 1)}
    )

    result
  end

  @doc """
  Validates that an approval request contains all required fields and
  has coherent field values.

  Returns `:ok` or `{:error, [reason]}`.
  """
  @spec validate_approval_rules(map()) :: :ok | {:error, [String.t()]}
  def validate_approval_rules(request) do
    start = System.monotonic_time()

    required_fields = [:request_id, :requester_id, :amount, :description]

    missing =
      Enum.reject(required_fields, fn field ->
        Map.has_key?(request, field) and not is_nil(Map.get(request, field))
      end)

    errors =
      missing
      |> Enum.map(fn field -> "missing required field: #{field}" end)
      |> then(fn errs ->
        amount = Map.get(request, :amount)

        if not is_nil(amount) and is_number(amount) and amount < 0 do
          ["amount must be non-negative" | errs]
        else
          errs
        end
      end)

    result =
      case errors do
        [] -> :ok
        reasons -> {:error, reasons}
      end

    :telemetry.execute(
      [:approval, :validate],
      %{duration: System.monotonic_time() - start},
      %{
        valid: result == :ok,
        error_count: length(if(result == :ok, do: [], else: elem(result, 1)))
      }
    )

    result
  end

  @doc """
  Stores a new approval request in the ETS backing store.

  Utility function that allows callers to seed the store without depending
  on PostgreSQL for unit tests.
  """
  @spec store_request(String.t(), map()) :: :ok
  def store_request(request_id, record) do
    ensure_table()
    :ets.insert(@approval_store, {request_id, Map.put(record, :request_id, request_id)})
    :ok
  end
end
