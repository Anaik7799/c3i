# L5 System Level BDD Tests - End-to-End Workflows
# STAMP: SC-PLAN-040 to SC-PLAN-050
# Coverage: 65 scenarios for complete workflow validation

@l5_system @e2e @workflows
Feature: Planning System End-to-End Workflows
  As a user managing a complex project
  I need complete task management workflows
  So that I can effectively plan and track work from start to finish

  Background:
    Given the full Planning System is deployed
    And the Elixir backend is running
    And the F# Planning CLI is available
    And the Chaya Digital Twin is active

  # ==========================================================================
  # Sprint Planning Workflow
  # ==========================================================================

  @workflow @sprint_planning
  Scenario: Complete sprint planning workflow
    Given a new sprint "Sprint 46" is initialized
    When the product owner adds 10 user stories
    And the team estimates each story
    And stories are prioritized by business value
    And the sprint capacity is set to 40 points
    Then stories within capacity should be selected
    And the sprint backlog should be created
    And PROJECT_TODOLIST.md should be updated

  @workflow @story_breakdown
  Scenario: Break down user story into tasks
    Given user story "US-101: Implement login" exists
    When the developer breaks it into tasks:
      | task                    | estimate |
      | Create login form       | 2h       |
      | Implement auth API      | 4h       |
      | Write unit tests        | 2h       |
      | Integration testing     | 2h       |
    Then 4 subtasks should be created under US-101
    And the total estimate should be 10h
    And each task should be linked to parent story

  @workflow @daily_standup
  Scenario: Daily standup status update
    Given sprint tasks exist with various statuses
    When I run daily status report
    Then I should see:
      | metric              | display |
      | Tasks completed     | count   |
      | Tasks in progress   | count   |
      | Blocked tasks       | list    |
      | Sprint progress     | percent |
    And blocked tasks should show blockers

  @workflow @sprint_retrospective
  Scenario: Generate sprint retrospective data
    Given sprint "Sprint 45" is completed
    When I generate retrospective report
    Then the report should include:
      | metric               | data           |
      | Velocity achieved    | story points   |
      | Planned vs actual    | comparison     |
      | Task cycle time      | average days   |
      | Blocked time         | total hours    |
      | Completion rate      | percentage     |

  # ==========================================================================
  # Task Lifecycle Workflow
  # ==========================================================================

  @workflow @task_lifecycle
  Scenario: Complete task lifecycle from creation to completion
    When I create a new task "Implement feature X"
    Then the task status should be "pending"
    When I start working on the task
    Then the task status should be "in_progress"
    And start_time should be recorded
    When I complete the task
    Then the task status should be "completed"
    And completion_time should be recorded
    And cycle_time should be calculated

  @workflow @blocked_task_resolution
  Scenario: Handle blocked task through resolution
    Given task "1.0" is in progress
    When task becomes blocked with reason "Waiting for API access"
    Then the task status should be "blocked"
    And a blocker record should be created
    When the blocker is resolved
    And I unblock the task
    Then the task status should be "in_progress"
    And blocked_time should be recorded

  @workflow @task_reassignment
  Scenario: Reassign task between team members
    Given task "1.0" is assigned to "claude"
    And task is in progress
    When task is reassigned to "gemini"
    Then task should be assigned to "gemini"
    And assignment history should be preserved
    And notification should be sent to both parties

  @workflow @task_dependencies
  Scenario: Manage task dependencies
    Given tasks "1.1", "1.2", "1.3" exist
    When I set "1.2" as dependent on "1.1"
    And I set "1.3" as dependent on "1.2"
    Then a dependency chain should be created
    And completing "1.1" should unblock "1.2"
    And the dependency graph should be validated for cycles

  # ==========================================================================
  # Multi-Agent Collaboration Workflow
  # ==========================================================================

  @workflow @agent_collaboration
  Scenario: Multiple agents working on related tasks
    Given task "1.0" is assigned to "claude"
    And task "1.1" is assigned to "gemini"
    And task "1.2" is assigned to "grok"
    When all agents work concurrently
    Then task updates should not conflict
    And version vectors should prevent overwrites
    And final state should be consistent

  @workflow @handoff
  Scenario: Task handoff between agents
    Given task "1.0" is in progress by "claude"
    And claude reaches a checkpoint
    When claude hands off to "gemini"
    Then gemini should receive:
      | item              |
      | Task context      |
      | Progress notes    |
      | Remaining work    |
      | Known issues      |
    And the handoff should be logged

  @workflow @parallel_execution
  Scenario: Parallel task execution with synchronization
    Given independent tasks "2.1", "2.2", "2.3" exist
    When I assign all tasks for parallel execution
    Then agents should work concurrently
    And progress should be tracked independently
    And parent task "2.0" progress should aggregate child progress

  # ==========================================================================
  # Hierarchical Task Management
  # ==========================================================================

  @workflow @hierarchy_create
  Scenario: Create hierarchical task structure
    When I create project structure:
      """
      1.0 Main Project
        1.1 Phase 1
          1.1.1 Design
          1.1.2 Implementation
          1.1.3 Testing
        1.2 Phase 2
          1.2.1 Deployment
          1.2.2 Documentation
      """
    Then all tasks should be created with proper parent relationships
    And depth levels should be correctly assigned

  @workflow @hierarchy_propagation
  Scenario: Status propagation in hierarchy
    Given hierarchical task structure exists
    When all children of "1.1" are completed
    Then "1.1" should be automatically marked complete
    And "1.0" progress should update accordingly

  @workflow @hierarchy_rollup
  Scenario: Estimate rollup in hierarchy
    Given task "1.0" has children with estimates:
      | task | estimate |
      | 1.1  | 8h       |
      | 1.2  | 4h       |
      | 1.3  | 6h       |
    When I view task "1.0"
    Then the rolled-up estimate should be 18h

  # ==========================================================================
  # Reporting and Analytics Workflow
  # ==========================================================================

  @workflow @progress_report
  Scenario: Generate project progress report
    Given project with 50 tasks at various stages
    When I generate progress report
    Then the report should include:
      | section             |
      | Executive summary   |
      | Milestone status    |
      | Risk assessment     |
      | Burndown chart data |
      | Team allocation     |

  @workflow @burndown
  Scenario: Track sprint burndown
    Given sprint with 40 story points
    And sprint started 5 days ago
    When I check burndown
    Then I should see:
      | metric           | value      |
      | Total points     | 40         |
      | Completed points | calculated |
      | Ideal burndown   | line       |
      | Actual burndown  | line       |
      | Trend projection | days       |

  @workflow @velocity_tracking
  Scenario: Track team velocity over time
    Given completed sprints exist
    When I query velocity metrics
    Then I should see:
      | metric              |
      | Average velocity    |
      | Velocity trend      |
      | Variance analysis   |
      | Capacity prediction |

  # ==========================================================================
  # Integration Workflows
  # ==========================================================================

  @workflow @git_integration
  Scenario: Link tasks to git commits
    Given task "1.0" exists
    When a commit is made with message "Fixes #1.0"
    Then task "1.0" should be linked to the commit
    And commit metadata should be attached

  @workflow @zenoh_sync
  Scenario: Real-time sync via Zenoh
    Given two planning instances are connected via Zenoh
    When task is updated on instance 1
    Then instance 2 should receive update within 100ms
    And both instances should have consistent state

  @workflow @prajna_integration
  Scenario: Display tasks in Prajna Cockpit
    Given tasks exist in the planning system
    When I access Prajna dashboard
    Then tasks should be visible in task panel
    And I should be able to update tasks from cockpit
    And updates should sync back to F# backend

  # ==========================================================================
  # Error Recovery Workflows
  # ==========================================================================

  @workflow @conflict_resolution
  Scenario: Resolve concurrent update conflict
    Given task "1.0" is being edited by two users
    When both users save simultaneously
    Then the system should detect conflict
    And last-write-wins should be applied
    And conflict should be logged for audit

  @workflow @recovery_from_failure
  Scenario: Recover from system failure
    Given tasks have been modified
    When a simulated system crash occurs
    And the system is restarted
    Then SQLite WAL should be replayed
    And all committed changes should be recovered
    And no data should be lost

  @workflow @rollback
  Scenario: Rollback task changes
    Given task "1.0" was updated 5 times today
    When I request rollback to 3 versions ago
    Then task should be restored to that version
    And rollback should be logged as new change
    And version history should be preserved

  # ==========================================================================
  # Compliance Workflows
  # ==========================================================================

  @workflow @audit_trail
  Scenario: Maintain complete audit trail
    Given task "1.0" has been modified 10 times
    When I query audit trail for task "1.0"
    Then I should see all 10 modifications
    And each entry should have timestamp, actor, and change details
    And entries should be in immutable register

  @workflow @compliance_report
  Scenario: Generate compliance report
    When I generate compliance report for Q1 2026
    Then the report should include:
      | item                    |
      | All task changes        |
      | Agent access attempts   |
      | Access violations       |
      | Data retention status   |
      | Policy compliance score |

  # ==========================================================================
  # Performance Workflows
  # ==========================================================================

  @workflow @bulk_operations
  Scenario: Perform bulk task operations efficiently
    Given 1000 tasks need status update
    When I bulk update all tasks to "archived"
    Then all updates should complete within 10 seconds
    And database should remain responsive

  @workflow @high_load
  Scenario: Handle high concurrent load
    Given 50 concurrent users/agents
    When all perform read/write operations
    Then system should maintain sub-second response
    And no deadlocks should occur
    And data should remain consistent
