# Feature: CRM Automation (WS7)
#
# WHAT: Automated business process execution for CRM operations
# WHY: Reduce manual work, ensure consistency, enforce business rules
# CONSTRAINTS: SC-AUTO-001, SC-AUTO-002, SC-WORKFLOW-001 to SC-WORKFLOW-005
#
# STAMP Constraints:
# - SC-AUTO-001: Max 100 active automation rules per tenant
# - SC-AUTO-002: Automation execution timeout 5s
# - SC-WORKFLOW-001: Workflow conditions MUST be deterministic
# - SC-WORKFLOW-002: Max 10 actions per workflow rule
# - SC-WORKFLOW-003: Approval process max 5 steps
# - SC-WORKFLOW-004: Assignment rules evaluated in priority order
# - SC-WORKFLOW-005: All automation logged to audit trail

@crm @automation @ws7
Feature: CRM Automation
  As a CRM administrator
  I want to automate business processes
  So that operations are consistent and efficient

  Background:
    Given I am authenticated as "admin@company.com"
    And the tenant "company" is active
    And I have permission "automation:manage"

  # ================================================================
  # ASSIGNMENT RULES
  # ================================================================

  @assignment-rules @criteria
  Scenario: Create assignment rule with criteria
    Given I am on the "Assignment Rules" page
    When I create an assignment rule:
      | Name              | Lead Assignment - USA           |
      | Object            | Lead                            |
      | Active            | true                            |
      | Priority          | 10                              |
      | Criteria Field    | country                         |
      | Criteria Operator | equals                          |
      | Criteria Value    | USA                             |
      | Assign To Type    | User                            |
      | Assign To ID      | user-123                        |
    Then the assignment rule should be created
    And the rule should appear in the active rules list
    And the rule priority should be "10"
    And I should see the criteria "country equals USA"
    And the audit trail should record "assignment_rule_created"

  @assignment-rules @round-robin
  Scenario: Round-robin lead assignment
    Given the following sales users exist:
      | User ID  | Name          | Active | Territory |
      | user-101 | Alice Sales   | true   | East      |
      | user-102 | Bob Sales     | true   | East      |
      | user-103 | Carol Sales   | true   | East      |
    And the following assignment rule exists:
      | Name              | East Territory Round Robin |
      | Object            | Lead                       |
      | Active            | true                       |
      | Priority          | 5                          |
      | Assignment Method | round_robin                |
      | Team ID           | team-east                  |
    When the following leads are created:
      | Name          | Country | Territory |
      | Lead Alpha    | USA     | East      |
      | Lead Beta     | USA     | East      |
      | Lead Gamma    | USA     | East      |
      | Lead Delta    | USA     | East      |
    Then lead "Lead Alpha" should be assigned to "Alice Sales"
    And lead "Lead Beta" should be assigned to "Bob Sales"
    And lead "Lead Gamma" should be assigned to "Carol Sales"
    And lead "Lead Delta" should be assigned to "Alice Sales"
    And the round-robin counter should be at position "2"
    And all assignments should complete within "5s"

  @assignment-rules @territory
  Scenario: Territory-based assignment
    Given the following territories exist:
      | Territory ID | Name      | Zipcodes        | Owner ID |
      | terr-001     | Northeast | 10000-19999     | user-201 |
      | terr-002     | Southeast | 30000-39999     | user-202 |
      | terr-003     | Midwest   | 60000-69999     | user-203 |
    And the following assignment rule exists:
      | Name              | Territory-Based Lead Assignment |
      | Object            | Lead                            |
      | Active            | true                            |
      | Priority          | 15                              |
      | Assignment Method | territory                       |
      | Territory Field   | zipcode                         |
    When I create a lead:
      | Name          | Lead New York Corp |
      | Zipcode       | 10001              |
      | Country       | USA                |
    Then the lead should be assigned to user "user-201"
    And the lead territory should be "Northeast"
    And the assignment reason should be "territory_match"
    And the assignment should complete within "2s"

  @assignment-rules @skill-based
  Scenario: Skill-based routing for cases
    Given the following support agents exist:
      | Agent ID | Name          | Skills                  | Available | Current Cases |
      | agent-01 | Tech Support  | technical,network,cloud | true      | 3             |
      | agent-02 | Billing Agent | billing,finance         | true      | 2             |
      | agent-03 | Cloud Expert  | cloud,devops,security   | true      | 1             |
    And the following assignment rule exists:
      | Name              | Skill-Based Case Routing |
      | Object            | Case                     |
      | Active            | true                     |
      | Priority          | 20                       |
      | Assignment Method | skill_match              |
      | Load Balancing    | true                     |
    When I create a case:
      | Subject       | Cloud deployment issue |
      | Category      | Technical              |
      | Required Skill| cloud                  |
      | Priority      | High                   |
    Then the case should be assigned to "Cloud Expert"
    And the assignment reason should be "skill_match_lowest_load"
    And agent "agent-03" current cases should be "2"
    And the assignment should complete within "3s"

  @assignment-rules @workload-balancing
  Scenario: Workload balancing prevents overload
    Given the following sales reps exist:
      | Rep ID   | Name          | Active Leads | Max Capacity | Available |
      | rep-001  | John Seller   | 45           | 50           | true      |
      | rep-002  | Jane Closer   | 48           | 50           | true      |
      | rep-003  | Mike Hunter   | 15           | 50           | true      |
    And the following assignment rule exists:
      | Name              | Balanced Lead Assignment |
      | Object            | Lead                     |
      | Active            | true                     |
      | Priority          | 10                       |
      | Assignment Method | balanced                 |
      | Team ID           | sales-team-1             |
      | Max Capacity      | 50                       |
    When I create 10 new leads in the "sales-team-1" territory
    Then all 10 leads should be assigned to "Mike Hunter"
    And rep "rep-001" should remain at "45" leads
    And rep "rep-002" should remain at "48" leads
    And rep "rep-003" should have "25" leads
    And no rep should exceed capacity "50"
    And all assignments should complete within "5s"

  # ================================================================
  # WORKFLOW RULES
  # ================================================================

  @workflow-rules @on-create
  Scenario: Create workflow rule with on_create trigger
    Given I am on the "Workflow Rules" page
    When I create a workflow rule:
      | Name              | New Lead Auto-Response          |
      | Object            | Lead                            |
      | Trigger           | on_create                       |
      | Active            | true                            |
      | Priority          | 10                              |
      | Condition Field   | source                          |
      | Condition Op      | equals                          |
      | Condition Value   | website                         |
    And I add the following actions:
      | Action Type       | send_email                      |
      | Template          | welcome_email                   |
      | Recipient Field   | email                           |
    And I add the following actions:
      | Action Type       | create_task                     |
      | Task Subject      | Follow up on web lead           |
      | Task Due Date     | +2 days                         |
      | Assign To         | lead.owner_id                   |
    Then the workflow rule should be created
    And the rule should have "2" actions
    And the rule trigger should be "on_create"
    And the rule should appear in active workflows

  @workflow-rules @on-update
  Scenario: Create workflow rule with on_update trigger and criteria evaluation
    Given the following workflow rule exists:
      | Name              | Opportunity Stage Change     |
      | Object            | Opportunity                  |
      | Trigger           | on_update                    |
      | Active            | true                         |
      | Priority          | 15                           |
    And the rule has conditions:
      | Field             | Operator      | Value         | Previous Value |
      | stage             | changed_to    | closed_won    | *              |
      | amount            | greater_than  | 10000         | -              |
    And the rule has actions:
      | Action Type       | send_email                   |
      | Template          | deal_won_celebration         |
      | Recipient         | opportunity.owner_id         |
    And the rule has actions:
      | Action Type       | update_field                 |
      | Field             | celebration_sent             |
      | Value             | true                         |
    When I update an opportunity:
      | Opportunity ID    | opp-123                      |
      | Previous Stage    | negotiation                  |
      | New Stage         | closed_won                   |
      | Amount            | 25000                        |
    Then the workflow rule should trigger
    And the criteria should evaluate to "true"
    And the "send_email" action should execute
    And the "update_field" action should execute
    And the opportunity field "celebration_sent" should be "true"
    And the workflow execution should complete within "5s"
    And the audit trail should record "workflow_executed"

  @workflow-rules @actions
  Scenario: Execute workflow actions with timeout compliance
    Given the following workflow rule exists:
      | Name              | Lead Status Update Chain     |
      | Object            | Lead                         |
      | Trigger           | on_update                    |
      | Active            | true                         |
      | Execution Timeout | 5000                         |
    And the rule has "10" actions:
      | Seq | Action Type       | Details                      |
      | 1   | update_field      | field: status, value: working|
      | 2   | create_task       | subject: Call lead           |
      | 3   | send_email        | template: lead_engaged       |
      | 4   | post_to_chatter   | message: Lead engaged        |
      | 5   | update_field      | field: last_activity_date    |
      | 6   | create_event      | subject: Follow-up scheduled |
      | 7   | send_notification | type: push, message: New lead|
      | 8   | update_related    | object: Account              |
      | 9   | log_metric        | metric: lead_engaged_count   |
      | 10  | trigger_webhook   | url: /api/crm/lead/engaged   |
    When the workflow rule is triggered for lead "lead-456"
    Then all "10" actions should execute
    And the execution time should be less than "5s"
    And each action should be logged to audit trail
    And if any action fails, subsequent actions should continue
    And failed actions should be logged with reason
    And the workflow status should be "completed"

  @workflow-rules @management
  Scenario: Deactivate and reactivate workflow rules
    Given the following active workflow rules exist:
      | Rule ID   | Name                    | Object | Active | Executions |
      | rule-001  | New Lead Auto-Response  | Lead   | true   | 1234       |
      | rule-002  | Opportunity Won Alert   | Opp    | true   | 567        |
      | rule-003  | Case Escalation         | Case   | true   | 89         |
    When I deactivate workflow rule "rule-001"
    Then the rule "rule-001" should be inactive
    And the rule should not trigger for new leads
    When I create a new lead with source "website"
    Then the workflow rule "rule-001" should not execute
    And the execution count should remain "1234"
    When I reactivate workflow rule "rule-001"
    Then the rule "rule-001" should be active
    When I create a new lead with source "website"
    Then the workflow rule "rule-001" should execute
    And the execution count should be "1235"
    And the audit trail should record:
      | Event                        | Timestamp          |
      | workflow_rule_deactivated    | 2026-01-11 10:00:00|
      | workflow_rule_reactivated    | 2026-01-11 10:05:00|
      | workflow_rule_executed       | 2026-01-11 10:06:00|

  # ================================================================
  # APPROVAL PROCESSES
  # ================================================================

  @approval-process @submit
  Scenario: Submit record for approval
    Given the following approval process exists:
      | Name              | Discount Approval Process    |
      | Object            | Opportunity                  |
      | Active            | true                         |
      | Entry Criteria    | discount_percent > 15        |
    And the approval process has steps:
      | Step | Approver Role    | Required | Auto-Approve If |
      | 1    | Sales Manager    | true     | -               |
      | 2    | VP Sales         | true     | discount < 25   |
      | 3    | CFO              | false    | discount >= 30  |
    And user "manager@company.com" has role "Sales Manager"
    When I submit opportunity "opp-789" for approval:
      | Opportunity ID    | opp-789                      |
      | Name              | Big Deal Corp                |
      | Amount            | 100000                       |
      | Discount Percent  | 20                           |
      | Submitter         | sales@company.com            |
    Then the approval request should be created
    And the approval status should be "pending"
    And the current step should be "1"
    And the current approver should be "manager@company.com"
    And an email notification should be sent to "manager@company.com"
    And the opportunity should be locked for editing
    And the audit trail should record "approval_submitted"

  @approval-process @approve-reject
  Scenario: Approve and reject approval requests
    Given an approval request exists:
      | Request ID        | req-001                      |
      | Object            | Opportunity                  |
      | Record ID         | opp-789                      |
      | Status            | pending                      |
      | Current Step      | 1                            |
      | Current Approver  | manager@company.com          |
    When user "manager@company.com" approves the request:
      | Request ID        | req-001                      |
      | Comments          | Discount is reasonable       |
    Then the approval status should be "approved_step_1"
    And the current step should be "2"
    And the current approver should be "vp-sales@company.com"
    And an email notification should be sent to "vp-sales@company.com"
    When user "vp-sales@company.com" rejects the request:
      | Request ID        | req-001                      |
      | Comments          | Discount too high            |
    Then the approval status should be "rejected"
    And the opportunity should be unlocked
    And the opportunity status should be "approval_rejected"
    And an email notification should be sent to "sales@company.com"
    And the audit trail should record:
      | Event                        | User                   |
      | approval_step_1_approved     | manager@company.com    |
      | approval_step_2_rejected     | vp-sales@company.com   |

  @approval-process @multi-step
  Scenario: Multi-step approval workflow
    Given the following approval process exists:
      | Name              | Large Deal Approval          |
      | Object            | Opportunity                  |
      | Active            | true                         |
      | Max Steps         | 5                            |
    And the approval process has steps:
      | Step | Approver          | Required | Criteria          |
      | 1    | Sales Manager     | true     | always            |
      | 2    | Regional Director | true     | amount > 50000    |
      | 3    | VP Sales          | true     | amount > 100000   |
      | 4    | CFO               | true     | amount > 250000   |
      | 5    | CEO               | true     | amount > 500000   |
    And the following users exist:
      | Email                  | Role               |
      | manager@company.com    | Sales Manager      |
      | director@company.com   | Regional Director  |
      | vp@company.com         | VP Sales           |
      | cfo@company.com        | CFO                |
      | ceo@company.com        | CEO                |
    When I submit opportunity "opp-mega" for approval:
      | Amount            | 750000                       |
      | Discount Percent  | 18                           |
    Then the approval process should require "5" steps
    When user "manager@company.com" approves at step "1"
    Then the current step should be "2"
    When user "director@company.com" approves at step "2"
    Then the current step should be "3"
    When user "vp@company.com" approves at step "3"
    Then the current step should be "4"
    When user "cfo@company.com" approves at step "4"
    Then the current step should be "5"
    When user "ceo@company.com" approves at step "5"
    Then the approval status should be "fully_approved"
    And the opportunity should be unlocked
    And the opportunity status should be "approved"
    And all approvers should receive confirmation emails
    And the total approval time should be tracked

  @approval-process @history
  Scenario: Track approval history and audit trail
    Given the following approval requests were processed:
      | Request ID | Object | Record ID | Submitter          | Status        | Created At          |
      | req-101    | Opp    | opp-001   | sales1@company.com | approved      | 2026-01-10 09:00:00 |
      | req-102    | Opp    | opp-002   | sales2@company.com | rejected      | 2026-01-10 10:00:00 |
      | req-103    | Quote  | quote-001 | sales3@company.com | pending       | 2026-01-10 11:00:00 |
    And approval request "req-101" has history:
      | Step | Approver           | Action   | Timestamp           | Comments           |
      | 1    | manager@company.com| approved | 2026-01-10 09:15:00 | Looks good         |
      | 2    | vp@company.com     | approved | 2026-01-10 09:30:00 | Approved           |
    And approval request "req-102" has history:
      | Step | Approver           | Action   | Timestamp           | Comments           |
      | 1    | manager@company.com| approved | 2026-01-10 10:10:00 | OK                 |
      | 2    | vp@company.com     | rejected | 2026-01-10 10:25:00 | Too risky          |
    When I view the approval history for "req-101"
    Then I should see "2" approval steps
    And I should see approver "manager@company.com" at step "1"
    And I should see approver "vp@company.com" at step "2"
    And I should see final status "approved"
    And I should see total time "30 minutes"
    When I view the approval history for "req-102"
    Then I should see "2" approval steps
    And I should see rejection at step "2"
    And I should see comments "Too risky"
    When I query approval metrics for date range "2026-01-10 to 2026-01-11"
    Then I should see metrics:
      | Metric                  | Value |
      | Total Requests          | 3     |
      | Approved                | 1     |
      | Rejected                | 1     |
      | Pending                 | 1     |
      | Avg Approval Time       | 30m   |
      | Avg Steps               | 2     |

  # ================================================================
  # CONSTRAINT VALIDATION
  # ================================================================

  @automation @constraints
  Scenario: Validate automation constraints and limits
    Given I have "95" active automation rules
    When I attempt to create "6" new automation rules
    Then the first "5" rules should be created successfully
    And the "6th" rule should fail with error "SC-AUTO-001: Max 100 active rules exceeded"
    And the current active rule count should be "100"
    When I deactivate "10" automation rules
    Then the active rule count should be "90"
    When I create a new automation rule
    Then the rule should be created successfully
    And the active rule count should be "91"

  @automation @performance
  Scenario: Automation execution timeout compliance
    Given the following workflow rule exists:
      | Name              | Complex Workflow             |
      | Object            | Lead                         |
      | Trigger           | on_create                    |
      | Execution Timeout | 5000                         |
    And the rule has "10" actions including external webhooks
    When the workflow is triggered for lead "lead-999"
    And the execution takes "4.8s"
    Then the workflow should complete successfully
    And all actions should be executed
    When the workflow is triggered for lead "lead-888"
    And the execution takes "5.2s"
    Then the workflow should timeout
    And completed actions should be preserved
    And incomplete actions should be marked as "timeout"
    And an alert should be sent to "admin@company.com"
    And the audit trail should record "workflow_timeout"
