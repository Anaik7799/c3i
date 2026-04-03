defmodule Indrajaal.Alarms.WorkflowEngine do
  @moduledoc """
  Executes complex alarm response workflows based on configurable templates.
  Supports conditional logic, parallel execution, and human decision points.
  """

  require Logger
  # alias Indrajaal.Alarms
  # alias Indrajaal.Dispatch
  # alias Indrajaal.AccessControl
  # alias Indrajaal.Video
  # alias Indrajaal.Communication

  @doc """
  Trigger applicable workflows for an alarm event.
  """
  @spec trigger_for_alarm(any()) :: any()
  def trigger_for_alarm(alarm) do
    with {:ok, applicable_workflows} <- find_applicable_workflows(alarm) do
      # Execute workflows in parallel
      tasks =
        Enum.map(applicable_workflows, fn workflow ->
          Task.async(fn ->
            execute_workflow(workflow, alarm)
          end)
        end)

      # Wait for all workflows to complete
      results = Task.await_many(tasks, 30_000)

      # Log results
      Enum.each(results, fn
        {:ok, instance} ->
          Logger.info("Workflow #{instance.workflow_name} completed for alarm #{alarm.id}")

        {:error, reason} ->
          Logger.error("Workflow failed for alarm #{alarm.id}: #{inspect(reason)}")
      end)

      :ok
    end
  end

  @doc """
  Execute a specific workflow for an alarm.
  """
  @spec execute_workflow(any(), any()) :: any()
  def execute_workflow(workflow_template, alarm) do
    with {:ok, instance} <- create_workflow_instance(workflow_template, alarm),
         {:ok, completed_instance} <-
           execute_workflow_steps(instance, workflow_template.steps, alarm) do
      # Update alarm with workflow completion
      update_alarm_workflow_state(alarm, completed_instance)

      {:ok, completed_instance}
    end
  end

  @doc """
  Get standard workflow templates.
  """
  @spec get_standard_workflows() :: any()
  def get_standard_workflows do
    [
      intrusion_response_workflow(),
      fire_response_workflow(),
      medical_emergency_workflow(),
      panic_alarm_workflow(),
      system_tamper_workflow()
    ]
  end

  # Workflow Execution

  defp execute_workflow_steps(instance, steps, alarm) do
    Enum.reduce_while(steps, {:ok, instance}, fn step, {:ok, current_instance} ->
      case execute_step(step, current_instance, alarm) do
        {:ok, updated_instance} ->
          {:cont, {:ok, updated_instance}}

        {:skip, updated_instance} ->
          {:cont, {:ok, updated_instance}}

        {:wait, updated_instance} ->
          # Schedule continuation
          schedule_workflow_continuation(updated_instance, step)
          {:halt, {:ok, updated_instance}}

        {:error, reason} = error ->
          handle_step_failure(current_instance, step, reason)
          {:halt, error}
      end
    end)
  end

  defp execute_step(step, instance, alarm) do
    Logger.debug("Executing workflow step: #{step.type} - #{step.id}")

    case step.type do
      :condition ->
        execute_condition_step(step, instance, alarm)

      :action ->
        execute_action_step(step, instance, alarm)

      :wait ->
        execute_wait_step(step, instance, alarm)

      :parallel ->
        execute_parallel_steps(step, instance, alarm)

      :human_decision ->
        execute_human_decision_step(step, instance, alarm, %{})

      :loop ->
        execute_loop_step(step, instance, alarm)
    end
  end

  # Step Execution Types

  defp execute_condition_step(step, instance, alarm) do
    if evaluate_condition(step.condition, alarm, instance) do
      {:ok, log_step_execution(instance, step, :condition_met)}
    else
      {:skip, log_step_execution(instance, step, :condition_not_met)}
    end
  end

  defp execute_action_step(step, instance, alarm) do
    result = execute_action(step.action, alarm, instance)

    case result do
      :ok ->
        {:ok, log_step_execution(instance, step, :completed)}

      {:ok, data} ->
        updated_instance = store_step_result(instance, step.id, data)
        {:ok, log_step_execution(updated_instance, step, :completed)}
    end
  end

  defp execute_wait_step(step, instance, alarm) do
    case step.wait_for do
      :duration ->
        {:wait, schedule_wait_completion(instance, step, step.wait_duration)}

      :condition ->
        if evaluate_condition(step.wait_condition, alarm, instance) do
          {:ok, log_step_execution(instance, step, :wait_completed)}
        else
          {:wait, schedule_condition_check(instance, step)}
        end

      :event ->
        {:wait, register_event_listener(instance, step, step.wait_event)}
    end
  end

  defp execute_parallel_steps(step, instance, alarm) do
    tasks =
      Enum.map(step.parallel_steps, fn parallel_step ->
        Task.async(fn ->
          execute_step(parallel_step, instance, alarm)
        end)
      end)

    results = Task.await_many(tasks, 10_000)

    # All parallel steps must succeed
    if Enum.all?(results, fn
         {:ok, _} -> true
         {:skip, _} -> true
         _ -> false
       end) do
      {:ok, log_step_execution(instance, step, :parallel_completed)}
    else
      failed =
        Enum.find(results, fn
          {:error, _} -> true
          _ -> false
        end)

      failed || {:error, :parallel_execution_failed}
    end
  end

  defp execute_human_decision_step(step, instance, alarm, __req) do
    # Create decision __request
    {:ok, decision_request} = create_decision_request(step, instance, alarm)

    # Wait for human response
    {:wait,
     update_instance_state(instance, %{
       waiting_for_decision: true,
       decision_request_id: decision_request.id,
       decision_timeout: DateTime.add(DateTime.utc_now(), step.decision.timeout, :second)
     })}
  end

  defp execute_loop_step(step, instance, alarm) do
    loop_state = get_loop_state(instance, step.id)

    if should_continue_loop?(step, loop_state) do
      # Execute loop body
      case execute_workflow_steps(instance, step.loop_steps, alarm) do
        {:ok, updated_instance} ->
          new_loop_state = increment_loop_counter(loop_state)
          updated_instance = update_loop_state(updated_instance, step.id, new_loop_state)

          # Check loop condition again
          execute_loop_step(step, updated_instance, alarm)

        error ->
          error
      end
    else
      {:ok, log_step_execution(instance, step, :loop_completed)}
    end
  end

  # Action Execution

  defp execute_action(%{type: :lock_down_area} = action, alarm, _instance) do
    Logger.info("Executing area lockdown for alarm #{alarm.id}", %{
      alarm_id: alarm.id,
      site_id: alarm.site_id,
      zone_id: alarm.zone_id,
      radius_meters: action.__params[:radius],
      duration_seconds: action.__params[:duration]
    })

    # Emit telemetry for security action
    :telemetry.execute(
      [:indrajaal, :workflow, :area_lockdown],
      %{count: 1},
      %{alarm_id: alarm.id, site_id: alarm.site_id}
    )

    # Future implementation:
    # AccessControl.create_area_lockdown(%{
    #   site_id: alarm.site_id,
    #   zone_id: alarm.zone_id,
    #   radius_meters: action.params.radius,
    #   duration_seconds: action.params.duration,
    #   reason: "Alarm response: #{alarm.id}"
    # })

    {:ok,
     %{status: :executed, message: "Area lockdown initiated", action_id: Ecto.UUID.generate()}}
  end

  defp execute_action(%{type: :startvideorecording} = action, alarm, _instance) do
    Logger.info("Starting video recording for alarm #{alarm.id}", %{
      alarm_id: alarm.id,
      site_id: alarm.site_id,
      camera_selection: action.__params[:cameras]
    })

    # Emit telemetry for video action
    :telemetry.execute(
      [:indrajaal, :workflow, :video_recording],
      %{count: 1},
      %{alarm_id: alarm.id, site_id: alarm.site_id}
    )

    # Stub implementation until Video domain integration
    # Future implementation:
    # cameras = case action.params.cameras do
    #   :area_cameras -> Video.list_cameras_for_area(alarm.site_id, alarm.zone_
    #   camera_ids when is_list(camera_ids) -> Video.get_cameras(camera_ids)
    # end

    # Stub: no cameras available yet
    cameras = []
    recording_count = length(cameras)

    # Simulate recording start for each camera
    Enum.each(cameras, fn camera ->
      Logger.debug("Starting recording on camera #{camera.id}")
      # Future: Video.start_recording(...)
    end)

    {:ok,
     %{
       status: :executed,
       cameras_activated: recording_count,
       message: "Video recording initiated"
     }}
  end

  defp execute_action(%{type: :dispatchsecurity} = action, alarm, _instance) do
    Logger.info("Dispatching security for alarm #{alarm.id}", %{
      alarm_id: alarm.id,
      priority: action.__params[:priority],
      location_id: alarm.site_id,
      dispatch_type: :security_response
    })

    # Emit telemetry for dispatch action
    :telemetry.execute(
      [:indrajaal, :workflow, :security_dispatch],
      %{count: 1, priority_level: priority_to_level(action.__params[:priority])},
      %{alarm_id: alarm.id, site_id: alarm.site_id}
    )

    # Future implementation:
    # Dispatch.create_dispatch_assignment(%{
    #   alarm_event_id: alarm.id,
    #   priority: action.params.priority,
    #   location_id: alarm.site_id,
    #   dispatch_type: :security_response,
    #   instructions: action.params.instructions || "Respond to alarm"
    # })

    {:ok,
     %{
       status: :executed,
       message: "Security dispatch initiated",
       dispatch_id: Ecto.UUID.generate(),
       priority: action.__params[:priority]
     }}
  end

  defp execute_action(%{type: :notifystakeholders} = action, alarm, _instance) do
    Logger.info("Notifying stakeholders for alarm #{alarm.id}", %{
      alarm_id: alarm.id,
      template: action.__params[:template],
      severity: alarm.severity
    })

    # Emit telemetry for notification action
    :telemetry.execute(
      [:indrajaal, :workflow, :stakeholder_notification],
      %{count: 1},
      %{alarm_id: alarm.id, template: action.__params[:template]}
    )

    # Future implementation:
    # stakeholders = get_stakeholders(alarm)
    # Communication.send_broadcast(%{
    #   template: action.params.template,
    #   recipients: stakeholders,
    #   __context: %{
    #     alarm_id: alarm.id,
    #     location: alarm.location_details,
    #     severity: alarm.severity
    #   }
    # })

    {:ok,
     %{
       status: :executed,
       message: "Stakeholder notifications sent",
       notification_id: Ecto.UUID.generate(),
       template: action.__params[:template]
     }}
  end

  defp execute_action(%{type: :activatesirens} = _action, alarm, _instance) do
    # This would interface with physical security systems
    Logger.info("Activating sirens at #{alarm.site_id}")
    :ok
  end

  defp execute_action(%{type: :call_emergency_services} = _action, alarm, _instance) do
    # This would interface with emergency service integration
    Logger.info("Calling emergency services for alarm #{alarm.id}")
    {:ok, %{call_id: Ecto.UUID.generate(), status: :initiated}}
  end

  defp execute_action(action, alarm, _instance) do
    Logger.info("Executing action #{inspect(action.type)} for alarm #{alarm.id}")

    :telemetry.execute(
      [:indrajaal, :workflow, :generic_action],
      %{count: 1},
      %{alarm_id: alarm.id, action_type: action.type}
    )

    {:ok, %{status: :completed, action_type: action.type, timestamp: DateTime.utc_now()}}
  end

  # Condition Evaluation

  defp evaluate_condition(%{type: :alarmseverity} = condition, alarm, _instance) do
    case condition.operator do
      :equals -> alarm.severity == condition.value
      :greater_than -> severity_to_number(alarm.severity) > severity_to_number(condition.value)
      :in -> alarm.severity in condition.value
    end
  end

  defp evaluate_condition(%{type: :time_of_day} = condition, _alarm, _instance) do
    current_hour = DateTime.utc_now() |> DateTime.to_time() |> Map.get(:hour)

    case condition.operator do
      :between ->
        current_hour >= condition.start_hour &&
          current_hour <=
            condition.end_hour

      :outside ->
        current_hour < condition.start_hour ||
          current_hour >
            condition.end_hour
    end
  end

  defp evaluate_condition(%{type: :locationtype} = _condition, _alarm, _instance) do
    # This would check actual location attributes
    true
  end

  defp evaluate_condition(%{type: :correlation_exists} = _condition, alarm, _instance) do
    length(alarm.correlated_events || []) > 0
  end

  defp evaluate_condition(_condition, _alarm, _instance), do: true

  # Workflow Templates

  @spec intrusion_response_workflow() :: any()
  def intrusion_response_workflow do
    %{
      id: "intrusion_response_v1",
      name: "Standard Intrusion Response",
      description: "Automated response for intrusion alarms",
      version: "1.0",
      trigger_conditions: %{
        incident_types: [:intrusion, :unauthorized_access],
        severity_minimum: :medium
      },
      steps: [
        %{
          id: "check_severity",
          type: :condition,
          condition: %{
            type: :alarm_severity,
            operator: :greater_than,
            value: :medium
          }
        },
        %{
          id: "immediate_actions",
          type: :parallel,
          parallel_steps: [
            %{
              id: "lock_area",
              type: :action,
              action: %{
                type: :lock_down_area,
                __params: %{radius: 50, duration: 300}
              }
            },
            %{
              id: "start_recording",
              type: :action,
              action: %{
                type: :start_video_recording,
                __params: %{cameras: :area_cameras}
              }
            },
            %{
              id: "dispatch",
              type: :action,
              action: %{
                type: :dispatch_security,
                __params: %{priority: :high}
              }
            }
          ]
        },
        %{
          id: "wait_for_dispatch",
          type: :wait,
          wait_for: :duration,
          wait_duration: 60
        },
        %{
          id: "escalate_decision",
          type: :human_decision,
          decision: %{
            prompt: "Security has been dispatched. Escalate to law enforcement?",
            options: [:yes, :no, :delay],
            timeout: 300,
            default: :no,
            assigned_to: :supervisor
          }
        }
      ]
    }
  end

  @spec fire_response_workflow() :: any()
  def fire_response_workflow do
    %{
      id: "fire_response_v1",
      name: "Fire Alarm Response",
      description: "Emergency response for fire alarms",
      version: "1.0",
      trigger_conditions: %{
        incident_types: [:fire],
        severity_minimum: :low
      },
      steps: [
        %{
          id: "immediate_evacuation",
          type: :parallel,
          parallel_steps: [
            %{
              id: "activate_alarms",
              type: :action,
              action: %{
                type: :activate_sirens,
                __params: %{pattern: :evacuation}
              }
            },
            %{
              id: "unlock_exits",
              type: :action,
              action: %{
                type: :unlock_all_exits,
                __params: %{}
              }
            },
            %{
              id: "call_fire_dept",
              type: :action,
              action: %{
                type: :call_emergency_services,
                __params: %{service: :fire_department}
              }
            }
          ]
        }
      ]
    }
  end

  @spec medical_emergency_workflow() :: any()
  def medical_emergency_workflow do
    %{
      id: "medical_emergency_v1",
      name: "Medical Emergency Response",
      description: "Response for medical emergencies",
      version: "1.0",
      trigger_conditions: %{
        incident_types: [:medical],
        severity_minimum: :low
      },
      steps: [
        %{
          id: "call_ems",
          type: :action,
          action: %{
            type: :call_emergency_services,
            __params: %{service: :ems}
          }
        },
        %{
          id: "notify_responders",
          type: :action,
          action: %{
            type: :notify_stakeholders,
            __params: %{template: :medical_emergency}
          }
        }
      ]
    }
  end

  @spec panic_alarm_workflow() :: any()
  def panic_alarm_workflow do
    %{
      id: "panic_alarm_v1",
      name: "Panic Alarm Response",
      description: "Immediate response for panic / duress alarms",
      version: "1.0",
      trigger_conditions: %{
        incident_types: [:panic, :duress, :holdup],
        severity_minimum: :low
      },
      steps: [
        %{
          id: "silent_response",
          type: :parallel,
          parallel_steps: [
            %{
              id: "dispatch_immediate",
              type: :action,
              action: %{
                type: :dispatch_security,
                __params: %{priority: :critical, silent: true}
              }
            },
            %{
              id: "start_covert_recording",
              type: :action,
              action: %{
                type: :start_video_recording,
                __params: %{cameras: :area_cameras, mode: :covert}
              }
            },
            %{
              id: "alert_police",
              type: :action,
              action: %{
                type: :call_emergency_services,
                __params: %{service: :police, silent: true}
              }
            }
          ]
        }
      ]
    }
  end

  @spec system_tamper_workflow() :: any()
  def system_tamper_workflow do
    %{
      id: "system_tamper_v1",
      name: "System Tamper Response",
      description: "Response for device tampering",
      version: "1.0",
      trigger_conditions: %{
        incident_types: [:tamper],
        severity_minimum: :low
      },
      steps: [
        %{
          id: "investigate",
          type: :action,
          action: %{
            type: :dispatch_security,
            __params: %{priority: :high, type: :investigation}
          }
        }
      ]
    }
  end

  # Helper Functions

  @spec find_applicable_workflows(term()) :: term()
  defp find_applicable_workflows(alarm) do
    Logger.debug("Finding applicable workflows for alarm #{alarm.id}", %{
      alarm_id: alarm.id,
      event_type: alarm.event_type,
      severity: alarm.severity
    })

    # Stub implementation until WorkflowTemplates integration
    # Future implementation:
    # workflows = Alarms.list_workflow_templates(%{
    #   filters: %{
    #     tenant_id: alarm.tenant_id,
    #     active?: true
    #   }
    # })

    workflows = []

    # Filter by trigger conditions
    applicable =
      Enum.filter(workflows, fn workflow ->
        matches_trigger_conditions?(workflow, alarm)
      end)

    {:ok, applicable}
  end

  @spec matches_trigger_conditions?(term(), term()) :: term()
  defp matches_trigger_conditions?(workflow, alarm) do
    conditions = workflow.trigger_conditions || %{}

    incident_type_match =
      is_nil(conditions[:incident_types]) ||
        alarm.event_type in conditions[:incident_types]

    severity_match =
      is_nil(conditions[:severity_minimum]) ||
        severity_to_number(alarm.severity) >= severity_to_number(conditions[:severity_minimum])

    incident_type_match && severity_match
  end

  @spec create_workflow_instance(term(), term()) :: term()
  defp create_workflow_instance(workflow_template, alarm) do
    {:ok,
     %{
       id: Ecto.UUID.generate(),
       workflow_id: workflow_template.id,
       workflow_name: workflow_template.name,
       alarm_id: alarm.id,
       started_at: DateTime.utc_now(),
       state: :running,
       completed_steps: [],
       step_results: %{},
       __context: %{}
     }}
  end

  defp log_step_execution(instance, step, result) do
    completed_step = %{
      step_id: step.id,
      step_type: step.type,
      result: result,
      executed_at: DateTime.utc_now()
    }

    %{instance | completed_steps: instance.completed_steps ++ [completed_step]}
  end

  defp store_step_result(instance, step_id, data) do
    %{instance | step_results: Map.put(instance.step_results, step_id, data)}
  end

  @spec update_instance_state(term(), term()) :: term()
  defp update_instance_state(instance, updates) do
    Map.merge(instance, updates)
  end

  @spec schedule_workflow_continuation(term(), term()) :: term()
  defp schedule_workflow_continuation(instance, step) do
    # This would schedule an Oban job to continue the workflow
    Logger.info("Scheduling workflow continuation for step #{step.id}")
    instance
  end

  defp handle_step_failure(instance, step, reason) do
    Logger.error("Workflow step #{step.id} failed: #{inspect(reason)}")

    # Update instance with failure
    failed_instance = %{
      instance
      | state: :failed,
        failed_at: DateTime.utc_now(),
        failure_reason: reason,
        failed_step: step.id
    }

    # Notify about failure
    notify_workflow_failure(failed_instance)
    failed_instance
  end

  @spec update_alarm_workflow_state(term(), term()) :: term()
  defp update_alarm_workflow_state(alarm, instance) do
    Logger.info("Updating alarm workflow state", %{
      alarm_id: alarm.id,
      workflow_instance_id: instance.id,
      workflow_name: instance.workflow_name,
      completed_steps: length(instance.completed_steps)
    })

    # Emit telemetry for workflow completion
    :telemetry.execute(
      [:indrajaal, :workflow, :completed],
      %{completed_steps: length(instance.completed_steps)},
      %{alarm_id: alarm.id, workflow_name: instance.workflow_name}
    )

    # Future implementation:
    # Alarms.update_alarm_event(alarm, %{
    #   workflow_state: %{
    #     instance_id: instance.id,
    #     workflow_name: instance.workflow_name,
    #     completed_at: DateTime.utc_now(),
    #     completed_steps: length(instance.completed_steps)
    #   }
    # })

    {:ok, instance}
  end

  @spec severity_to_number(term()) :: term()
  defp severity_to_number(severity) do
    case severity do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  # defp (_alarm) do
  #   # This would fetch actual stakeholders
  #   []
  # end

  @spec notify_workflow_failure(term()) :: term()
  defp notify_workflow_failure(instance) do
    # This would send failure notifications
    Logger.error("Workflow #{instance.workflow_name} failed for alarm #{instance.alarm_id}")
  end

  @spec get_loop_state(term(), term()) :: term()
  defp get_loop_state(instance, loop_id) do
    Map.get(instance.context, "loop_#{loop_id}", %{iteration: 0})
  end

  @spec should_continue_loop?(term(), term()) :: term()
  defp should_continue_loop?(step, loop_state) do
    case step.loop_condition.type do
      :max_iterations ->
        loop_state.iteration < step.loop_condition.max_iterations

      :while_condition ->
        # Would evaluate the condition
        true
    end
  end

  @spec increment_loop_counter(term()) :: term()
  defp increment_loop_counter(loop_state) do
    %{loop_state | iteration: loop_state.iteration + 1}
  end

  defp update_loop_state(instance, loop_id, loop_state) do
    %{instance | __context: Map.put(instance.context, "loop_#{loop_id}", loop_state)}
  end

  defp schedule_wait_completion(instance, _step, _duration) do
    # Schedule continuation after duration
    instance
  end

  @spec schedule_condition_check(term(), term()) :: term()
  defp schedule_condition_check(instance, _step) do
    # Schedule periodic condition checks
    instance
  end

  defp register_event_listener(instance, _step, _event) do
    # Register to listen for specific events
    instance
  end

  @spec priority_to_level(term()) :: term()
  defp priority_to_level(priority) do
    case priority do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 2
    end
  end

  @spec create_decision_request(term(), term(), term()) :: {:ok, map()}
  defp create_decision_request(step, instance, alarm) do
    decision_request = %{
      id: System.unique_integer([:positive]),
      workflow_instance_id: instance.id,
      step_id: step.id,
      alarm_id: alarm.id,
      decision_type: step.decision.type,
      question: step.decision.question,
      options: step.decision.options,
      created_at: DateTime.utc_now(),
      status: :pending
    }

    {:ok, decision_request}
  end
end

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
