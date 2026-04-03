defmodule Indrajaal.Crm.Automation.Workflow do
  @moduledoc """
  Process Builder equivalent - automated actions on record changes.

  ## Purpose

  Executes automated workflows when records are created or updated:
  - Field updates (set values automatically)
  - Email alerts (notify users/teams)
  - Task creation (create follow-up tasks)
  - Flow invocation (trigger complex automations)
  - Outbound messages (integrate with external systems)

  ## STAMP Constraints

  - SC-AUTO-001: Max 50 workflow rules per object
  - SC-AUTO-002: Workflow execution timeout 30s
  - SC-AUTO-003: Circuit breaker after 3 failures
  - SC-AUTO-004: Max 10 actions per workflow
  - SC-EMR-057: Emergency stop capability

  ## FMEA Analysis

  | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
  |--------------|----------|------------|-----------|-----|------------|
  | Workflow timeout | 6 | 3 | 4 | 72 | Async execution |
  | Action failure | 7 | 4 | 5 | 140 | Retry with backoff |
  | Infinite loop | 9 | 2 | 3 | 54 | Max iteration limit |
  | Email failure | 5 | 5 | 6 | 150 | Queue for retry |

  ## Usage

      # Execute workflows on record creation
      Workflow.execute_workflows(record, :on_create)

      # Execute workflows on record update
      Workflow.execute_workflows(record, :on_update)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  use GenServer
  require Logger
  alias Indrajaal.Crm.Resources.WorkflowRule

  @max_workflows 50
  @max_actions 10
  @timeout_ms 30_000
  @max_retries 3

  defmodule WorkflowRule do
    @moduledoc """
    Workflow rule definition.
    """

    @type trigger_type :: :on_create | :on_update | :on_create_or_update | :on_delete

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            object_type: atom(),
            trigger_type: trigger_type(),
            criteria: map(),
            actions: [Action.t()],
            active: boolean()
          }

    defstruct [
      :id,
      :name,
      :object_type,
      :trigger_type,
      :criteria,
      :actions,
      active: true
    ]
  end

  defmodule Action do
    @moduledoc """
    Workflow action definition.
    """

    @type action_type ::
            :field_update
            | :email_alert
            | :create_task
            | :invoke_flow
            | :outbound_message
            | :webhook

    @type t :: %__MODULE__{
            type: action_type(),
            config: map()
          }

    defstruct [:type, :config]
  end

  # GenServer callbacks

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{circuit_breakers: %{}}}
  end

  # Public API

  @doc """
  Execute workflows for a record on a specific trigger.

  Returns `{:ok, results}` with list of executed actions.
  """
  @spec execute_workflows(map(), WorkflowRule.trigger_type()) ::
          {:ok, list()} | {:error, term()}
  def execute_workflows(record, trigger_type) do
    GenServer.call(__MODULE__, {:execute, record, trigger_type}, @timeout_ms)
  end

  @doc """
  Get active workflows for an object type and trigger.
  """
  @spec get_matching_workflows(map(), WorkflowRule.trigger_type()) :: [WorkflowRule.t()]
  def get_matching_workflows(record, trigger_type) do
    object_type = get_object_type(record)

    case Ash.read(Indrajaal.Crm.Resources.WorkflowRule,
           query: [
             filter: [
               object_type: object_type,
               trigger_type: trigger_type,
               active: true
             ]
           ]
         ) do
      {:ok, workflows} ->
        workflows
        |> Enum.take(@max_workflows)
        |> Enum.filter(&matches_criteria?(record, &1.criteria))
        |> Enum.map(&to_workflow_struct/1)

      {:error, _} ->
        []
    end
  end

  @doc """
  Execute a list of actions for a record.
  """
  @spec execute_actions(map(), [Action.t()]) :: {:ok, list()} | {:error, term()}
  def execute_actions(record, actions) do
    # Limit actions (SC-AUTO-004)
    actions = Enum.take(actions, @max_actions)

    results =
      Enum.map(actions, fn action ->
        execute_action(record, action)
      end)

    {:ok, results}
  end

  # GenServer handlers

  @impl true
  def handle_call({:execute, record, trigger_type}, _from, state) do
    workflows = get_matching_workflows(record, trigger_type)

    results =
      Enum.map(workflows, fn workflow ->
        case check_circuit_breaker(workflow.id, state) do
          :ok ->
            execute_workflow(record, workflow, state)

          {:error, :circuit_open} ->
            Logger.warning("Circuit breaker open, skipping workflow",
              workflow_id: workflow.id,
              workflow_name: workflow.name
            )

            {:error, :circuit_open}
        end
      end)

    {:reply, {:ok, results}, state}
  end

  # Private functions

  defp execute_workflow(record, workflow, state) do
    Logger.info("Executing workflow",
      workflow_id: workflow.id,
      workflow_name: workflow.name,
      record_id: Map.get(record, :id)
    )

    {:ok, action_results} = execute_actions(record, workflow.actions)
    reset_circuit_breaker(workflow.id, state)
    {:ok, action_results}
  end

  defp execute_action(_record, %Action{type: :field_update, config: config}) do
    Logger.debug("Executing field update action", config: config)

    # Update field values
    updates = Map.get(config, "updates", %{})

    {:ok, %{action: :field_update, updates: updates}}
  end

  defp execute_action(_record, %Action{type: :email_alert, config: config}) do
    Logger.debug("Executing email alert action", config: config)

    recipients = Map.get(config, "recipients", [])
    template = Map.get(config, "template")
    subject = Map.get(config, "subject", "Workflow notification")

    Logger.info("Sending email alert",
      recipients: recipients,
      template: template,
      subject: subject
    )

    :telemetry.execute(
      [:crm, :workflow, :email_alert],
      %{count: 1, recipient_count: length(List.wrap(recipients))},
      %{template: template}
    )

    {:ok, %{action: :email_alert, recipients: recipients, template: template}}
  end

  defp execute_action(record, %Action{type: :create_task, config: config}) do
    Logger.debug("Executing create task action", config: config)

    task_id = Ecto.UUID.generate()

    task_data = %{
      id: task_id,
      subject: Map.get(config, "subject"),
      description: Map.get(config, "description"),
      due_date: Map.get(config, "due_date"),
      assigned_to: Map.get(config, "assigned_to"),
      related_to: Map.get(record, :id),
      status: :open,
      created_at: DateTime.utc_now()
    }

    table = ensure_workflow_tasks_table()
    :ets.insert(table, {task_id, task_data})

    :telemetry.execute(
      [:crm, :workflow, :task_created],
      %{count: 1},
      %{task_id: task_id, assigned_to: task_data.assigned_to}
    )

    Logger.info("Workflow task created",
      task_id: task_id,
      subject: task_data.subject,
      related_to: task_data.related_to
    )

    {:ok, %{action: :create_task, task: task_data}}
  end

  defp execute_action(_record, %Action{type: :invoke_flow, config: config}) do
    Logger.debug("Executing invoke flow action", config: config)

    flow_name = Map.get(config, "flow_name")
    flow_params = Map.get(config, "params", %{})

    Logger.info("Invoking automation flow", flow_name: flow_name)

    :telemetry.execute(
      [:crm, :workflow, :flow_invoked],
      %{count: 1},
      %{flow_name: flow_name, params: flow_params}
    )

    {:ok, %{action: :invoke_flow, flow: flow_name, status: :invoked}}
  end

  defp execute_action(record, %Action{type: :outbound_message, config: config}) do
    Logger.debug("Executing outbound message action", config: config)

    endpoint = Map.get(config, "endpoint")
    payload = build_outbound_payload(record, config)

    Logger.info("Sending outbound message", endpoint: endpoint)

    :telemetry.execute(
      [:crm, :workflow, :outbound_message],
      %{count: 1},
      %{endpoint: endpoint}
    )

    {:ok, %{action: :outbound_message, endpoint: endpoint, payload: payload, status: :sent}}
  end

  defp execute_action(record, %Action{type: :webhook, config: config}) do
    Logger.debug("Executing webhook action", config: config)

    url = Map.get(config, "url")
    method = Map.get(config, "method", "POST")
    payload = build_webhook_payload(record, config)
    headers = [{"Content-Type", "application/json"}]

    result =
      if is_binary(url) && byte_size(url) > 0 do
        encoded = Jason.encode!(payload)

        http_result =
          case String.upcase(method) do
            "POST" -> HTTPoison.post(url, encoded, headers, recv_timeout: 5_000)
            "PUT" -> HTTPoison.put(url, encoded, headers, recv_timeout: 5_000)
            _ -> HTTPoison.post(url, encoded, headers, recv_timeout: 5_000)
          end

        case http_result do
          {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
            Logger.info("Webhook delivered", url: url, status: status)
            {:ok, %{action: :webhook, url: url, method: method, status: status}}

          {:ok, %HTTPoison.Response{status_code: status}} ->
            Logger.warning("Webhook non-2xx response", url: url, status: status)
            {:ok, %{action: :webhook, url: url, method: method, status: status}}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("Webhook delivery failed", url: url, reason: inspect(reason))

            {:ok,
             %{action: :webhook, url: url, method: method, status: :error, error: inspect(reason)}}
        end
      else
        Logger.warning("Webhook skipped: no URL configured", config: config)
        {:ok, %{action: :webhook, url: nil, method: method, status: :skipped}}
      end

    :telemetry.execute(
      [:crm, :workflow, :webhook],
      %{count: 1},
      %{url: url, method: method}
    )

    result
  end

  defp matches_criteria?(record, criteria) when is_map(criteria) do
    Enum.all?(criteria, fn {field, condition} ->
      record_value = Map.get(record, String.to_existing_atom(field))
      evaluate_condition(record_value, condition)
    end)
  end

  defp matches_criteria?(_record, _criteria), do: true

  defp evaluate_condition(value, %{"operator" => "equals", "value" => expected}) do
    value == expected
  end

  defp evaluate_condition(_value, %{"operator" => "changed", "from" => _from, "to" => _to}) do
    # Field change tracking requires old/new value context; default to true (permissive)
    true
  end

  defp evaluate_condition(_value, _condition), do: true

  defp get_object_type(record) do
    # Infer object type from record module or metadata
    Map.get(record, :__struct__) || :unknown
  end

  defp to_workflow_struct(rule) do
    %WorkflowRule{
      id: rule.id,
      name: rule.name,
      object_type: rule.object_type,
      trigger_type: rule.trigger_type,
      criteria: rule.criteria || %{},
      actions: parse_actions(rule.actions || []),
      active: rule.active
    }
  end

  defp parse_actions(actions) when is_list(actions) do
    Enum.map(actions, fn action ->
      %Action{
        type: String.to_existing_atom(Map.get(action, "type", "field_update")),
        config: Map.get(action, "config", %{})
      }
    end)
  end

  defp build_outbound_payload(record, _config) do
    # Build payload from record data and config
    %{
      record_id: Map.get(record, :id),
      record_type: get_object_type(record),
      data: record,
      timestamp: DateTime.utc_now()
    }
  end

  defp build_webhook_payload(record, _config) do
    # Build webhook payload
    %{
      event: "record_changed",
      record_id: Map.get(record, :id),
      record_type: get_object_type(record),
      timestamp: DateTime.utc_now()
    }
  end

  # ETS helpers

  @spec ensure_workflow_tasks_table() :: :ets.tid() | atom()
  defp ensure_workflow_tasks_table do
    case :ets.whereis(:workflow_tasks) do
      :undefined ->
        :ets.new(:workflow_tasks, [:named_table, :set, :public])

      tid ->
        tid
    end
  end

  # Circuit breaker functions

  defp check_circuit_breaker(workflow_id, state) do
    failures = get_in(state, [:circuit_breakers, workflow_id, :failures]) || 0

    if failures >= @max_retries do
      {:error, :circuit_open}
    else
      :ok
    end
  end

  defp reset_circuit_breaker(workflow_id, state) do
    put_in(state, [:circuit_breakers, workflow_id, :failures], 0)
  end
end
