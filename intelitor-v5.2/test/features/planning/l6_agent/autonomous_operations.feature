# L6 Agent Level BDD Tests - Autonomous Operations
# STAMP: SC-CHAYA-001 to SC-CHAYA-010, SC-OODA-001 to SC-OODA-005
# Coverage: 55 scenarios for autonomous agent operations

@l6_agent @autonomous @ai
Feature: Autonomous Agent Task Operations
  As an AI agent (Claude, Gemini, Grok)
  I need to autonomously manage tasks
  So that I can efficiently work without human intervention

  Background:
    Given the Planning System is in autonomous mode
    And agent "claude" is authenticated
    And the OODA cycle is enabled
    And access control is enforced

  # ==========================================================================
  # OODA Cycle Operations (SC-OODA-001 to SC-OODA-005)
  # ==========================================================================

  @ooda @observe
  Scenario: Agent observes current task state
    Given agent has active assignment
    When agent enters OBSERVE phase
    Then agent should gather:
      | information          |
      | Current task status  |
      | Blocking dependencies|
      | Resource availability|
      | System health        |
    And observation should complete within 20ms

  @ooda @orient
  Scenario: Agent orients based on observations
    Given agent has observed task state
    When agent enters ORIENT phase
    Then agent should analyze:
      | analysis              |
      | Priority ranking      |
      | Dependency resolution |
      | Optimal execution path|
      | Risk assessment       |
    And orientation should complete within 30ms

  @ooda @decide
  Scenario: Agent decides on next action
    Given agent has completed orientation
    When agent enters DECIDE phase
    Then agent should select:
      | decision             |
      | Next task to work on |
      | Required resources   |
      | Execution strategy   |
      | Fallback options     |
    And decision should complete within 20ms

  @ooda @act
  Scenario: Agent executes decided action
    Given agent has decided on action
    When agent enters ACT phase
    Then agent should:
      | action              |
      | Execute task work   |
      | Update task status  |
      | Log progress        |
      | Report completion   |
    And action should include telemetry

  @ooda @cycle_timing
  Scenario: Complete OODA cycle within 100ms (SC-OODA-001)
    Given agent has active tasks
    When agent executes full OODA cycle
    Then cycle should complete within 100ms
    And all four phases should execute
    And cycle metrics should be logged

  @ooda @continuous
  Scenario: Agent runs continuous OODA cycles
    Given agent is in continuous mode
    When agent runs for 60 seconds
    Then at least 600 OODA cycles should execute
    And each cycle should maintain timing constraint
    And no cycles should be skipped

  # ==========================================================================
  # Autonomous Task Selection
  # ==========================================================================

  @autonomous @task_selection
  Scenario: Agent selects highest priority task
    Given tasks with priorities P0, P1, P2, P3 are available
    When agent selects next task
    Then agent should select P0 task first
    And selection reason should be logged

  @autonomous @selection_with_dependencies
  Scenario: Agent respects task dependencies
    Given task "1.2" depends on "1.1"
    And "1.1" is not completed
    When agent evaluates task "1.2"
    Then agent should not select "1.2"
    And agent should work on "1.1" first

  @autonomous @workload_balancing
  Scenario: Agents balance workload among themselves
    Given tasks are available for multiple agents
    When "claude", "gemini", "grok" are active
    Then each agent should select different tasks
    And workload should be distributed evenly

  @autonomous @specialization
  Scenario: Agent selects tasks matching specialization
    Given agent "claude" specializes in "safety" tasks
    And tasks with various tags exist
    When agent selects next task
    Then agent should prefer "safety" tagged tasks
    And specialization should influence selection weight

  # ==========================================================================
  # Autonomous Task Execution
  # ==========================================================================

  @autonomous @execute_task
  Scenario: Agent autonomously executes task
    Given agent has selected task "1.0"
    When agent begins execution
    Then task status should change to "in_progress"
    And agent should work on task
    And progress should be logged periodically

  @autonomous @complete_task
  Scenario: Agent autonomously completes task
    Given agent is working on task "1.0"
    When work is finished successfully
    Then agent should mark task "completed"
    And completion should be logged
    And agent should select next task

  @autonomous @handle_failure
  Scenario: Agent handles task failure gracefully
    Given agent is working on task "1.0"
    When task execution fails
    Then agent should log failure reason
    And task should be marked "blocked"
    And agent should attempt recovery or move on

  @autonomous @subtask_creation
  Scenario: Agent creates subtasks when needed
    Given agent is working on complex task "1.0"
    When agent determines subtasks are needed
    Then agent should create subtasks under "1.0"
    And subtask IDs should follow hierarchy
    And parent task should be updated

  # ==========================================================================
  # Multi-Agent Coordination
  # ==========================================================================

  @multiagent @coordination
  Scenario: Multiple agents coordinate on shared project
    Given project has 20 tasks
    And agents "claude", "gemini", "grok" are assigned
    When agents work concurrently
    Then no task should be worked on by multiple agents
    And progress should be tracked per agent
    And overall project progress should aggregate

  @multiagent @handoff_protocol
  Scenario: Agent hands off task to another agent
    Given "claude" is working on task "1.0"
    And "claude" needs to hand off to "gemini"
    When handoff is initiated
    Then context should be transferred to "gemini"
    And "gemini" should continue from checkpoint
    And handoff should be logged

  @multiagent @conflict_prevention
  Scenario: Prevent conflicting updates from agents
    Given task "1.0" is being modified
    When two agents try to update simultaneously
    Then version vectors should prevent conflict
    And one update should succeed
    And other agent should retry

  @multiagent @mesh_distribution
  Scenario: Tasks distributed across mesh nodes
    Given Zenoh mesh has 3 active nodes
    And 30 tasks are pending
    When mesh distribution runs
    Then tasks should be distributed across nodes
    And distribution should be based on capacity
    And each node should receive subset of tasks

  # ==========================================================================
  # Autonomous Access Control (SC-TODO-001 to SC-TODO-008)
  # ==========================================================================

  @access @authorized_cli
  Scenario: Agent uses authorized F# CLI for tasks
    Given agent needs to read task list
    When agent uses "sa-plan list"
    Then access should be allowed
    And access should be logged with "FSharpCLI" method

  @access @blocked_direct
  Scenario: Agent direct access to todolist is blocked
    Given agent attempts to read PROJECT_TODOLIST.md
    When access control validates request
    Then access should be blocked
    And violation should be logged
    And agent should receive guidance to use CLI

  @access @chaya_allowed
  Scenario: Agent can use Chaya TUI interface
    Given agent needs task information
    When agent uses "chaya tasks"
    Then access should be allowed
    And access should be logged with "ChayaCLI" method

  @access @api_allowed
  Scenario: Agent can use F# API directly
    Given agent calls Planning API
    When API access is validated
    Then access should be allowed
    And access should be logged with "FSharpAPI" method

  # ==========================================================================
  # Autonomous Reporting
  # ==========================================================================

  @autonomous @progress_reporting
  Scenario: Agent reports progress automatically
    Given agent is working on task
    When 5 minutes have elapsed
    Then agent should report progress
    And progress should include:
      | metric           |
      | Work completed   |
      | Estimated remaining|
      | Blockers found   |
      | Next steps       |

  @autonomous @completion_summary
  Scenario: Agent provides completion summary
    Given agent completes task "1.0"
    When completion is recorded
    Then agent should generate summary:
      | item             |
      | Work performed   |
      | Files modified   |
      | Tests run        |
      | Time spent       |

  @autonomous @daily_digest
  Scenario: Agent generates daily work digest
    Given agent has worked on multiple tasks today
    When end of day is reached
    Then agent should generate digest:
      | section              |
      | Tasks completed      |
      | Tasks in progress    |
      | Blockers encountered |
      | Tomorrow's plan      |

  # ==========================================================================
  # Learning and Adaptation
  # ==========================================================================

  @learning @pattern_recognition
  Scenario: Agent learns from task patterns
    Given agent has completed similar tasks before
    When agent encounters new similar task
    Then agent should recognize pattern
    And agent should apply learned optimizations
    And learning should improve execution time

  @learning @failure_analysis
  Scenario: Agent learns from failures
    Given task execution has failed
    When agent analyzes failure
    Then root cause should be identified
    And prevention strategy should be recorded
    And future similar failures should be avoided

  @learning @performance_optimization
  Scenario: Agent optimizes based on metrics
    Given historical task metrics exist
    When agent selects execution strategy
    Then agent should use metrics to optimize
    And strategy selection should improve over time

  # ==========================================================================
  # Guardian Integration
  # ==========================================================================

  @guardian @approval
  Scenario: Agent requests Guardian approval for risky actions
    Given agent wants to delete completed tasks
    When agent submits proposal to Guardian
    Then Guardian should evaluate proposal
    And approval/rejection should be returned
    And decision should be logged

  @guardian @constitutional_check
  Scenario: Agent actions checked against constitution
    Given agent proposes action
    When action is evaluated
    Then constitutional invariants should be checked
    And Founder's Directive should be verified
    And any violations should block action

  @guardian @emergency_stop
  Scenario: Guardian can emergency stop agent
    Given agent is executing potentially harmful action
    When Guardian triggers emergency stop
    Then agent should halt immediately
    And current state should be preserved
    And stop should complete within 5 seconds
