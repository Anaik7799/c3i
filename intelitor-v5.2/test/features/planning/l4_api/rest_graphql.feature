# L4 API Level BDD Tests - REST and GraphQL
# STAMP: SC-PLAN-020 to SC-PLAN-030
# Coverage: 60 scenarios for API interface testing

@l4_api @rest @graphql
Feature: Planning System REST and GraphQL APIs
  As an external system or frontend
  I need REST and GraphQL APIs
  So that I can integrate with the Planning System programmatically

  Background:
    Given the Planning API server is running on port 4000
    And the database is initialized with test data
    And API authentication is configured

  # ==========================================================================
  # REST API - Task CRUD
  # ==========================================================================

  @rest @get_tasks
  Scenario: GET /api/planning/tasks returns all tasks
    Given 10 tasks exist in the repository
    When I send GET request to "/api/planning/tasks"
    Then the response status should be 200
    And the response should contain 10 tasks
    And each task should have id, title, status, priority fields

  @rest @get_task_by_id
  Scenario: GET /api/planning/tasks/:id returns single task
    Given task "1.0" exists with title "Test task"
    When I send GET request to "/api/planning/tasks/1.0"
    Then the response status should be 200
    And the response should contain task with id "1.0"
    And the response should include all task metadata

  @rest @get_task_not_found
  Scenario: GET /api/planning/tasks/:id returns 404 for missing task
    When I send GET request to "/api/planning/tasks/999.999"
    Then the response status should be 404
    And the response should contain error "Task not found"

  @rest @post_task
  Scenario: POST /api/planning/tasks creates new task
    When I send POST request to "/api/planning/tasks" with body:
      """json
      {
        "title": "New API task",
        "priority": "P1",
        "status": "pending"
      }
      """
    Then the response status should be 201
    And the response should contain the created task
    And the task should have an auto-generated ID

  @rest @post_task_validation
  Scenario: POST /api/planning/tasks validates required fields
    When I send POST request to "/api/planning/tasks" with body:
      """json
      {
        "priority": "P1"
      }
      """
    Then the response status should be 422
    And the response should contain validation error for "title"

  @rest @put_task
  Scenario: PUT /api/planning/tasks/:id updates task
    Given task "1.0" exists
    When I send PUT request to "/api/planning/tasks/1.0" with body:
      """json
      {
        "status": "completed",
        "priority": "P0"
      }
      """
    Then the response status should be 200
    And the task should have status "completed"
    And the task should have priority "P0"

  @rest @patch_task
  Scenario: PATCH /api/planning/tasks/:id partial update
    Given task "1.0" exists with status "pending"
    When I send PATCH request to "/api/planning/tasks/1.0" with body:
      """json
      {
        "status": "in_progress"
      }
      """
    Then the response status should be 200
    And only the status should be updated

  @rest @delete_task
  Scenario: DELETE /api/planning/tasks/:id removes task
    Given task "99.0" exists
    When I send DELETE request to "/api/planning/tasks/99.0"
    Then the response status should be 204
    And task "99.0" should no longer exist

  # ==========================================================================
  # REST API - Query Parameters
  # ==========================================================================

  @rest @filter_status
  Scenario Outline: Filter tasks by status query parameter
    Given tasks with various statuses exist
    When I send GET request to "/api/planning/tasks?status=<status>"
    Then only tasks with status "<status>" should be returned

    Examples:
      | status      |
      | pending     |
      | in_progress |
      | completed   |
      | blocked     |

  @rest @filter_priority
  Scenario: Filter tasks by priority
    Given tasks with various priorities exist
    When I send GET request to "/api/planning/tasks?priority=P0"
    Then only P0 tasks should be returned

  @rest @filter_assignee
  Scenario: Filter tasks by assignee
    Given tasks assigned to different agents exist
    When I send GET request to "/api/planning/tasks?assignee=claude"
    Then only tasks assigned to "claude" should be returned

  @rest @pagination
  Scenario: Paginate task list
    Given 100 tasks exist
    When I send GET request to "/api/planning/tasks?page=2&per_page=10"
    Then 10 tasks should be returned
    And pagination metadata should be included
    And tasks 11-20 should be returned

  @rest @sort
  Scenario Outline: Sort tasks by field
    Given tasks exist with various properties
    When I send GET request to "/api/planning/tasks?sort=<field>&order=<order>"
    Then tasks should be sorted by "<field>" in "<order>" order

    Examples:
      | field      | order |
      | id         | asc   |
      | id         | desc  |
      | priority   | asc   |
      | created_at | desc  |

  # ==========================================================================
  # REST API - Bulk Operations
  # ==========================================================================

  @rest @bulk_create
  Scenario: Bulk create tasks
    When I send POST request to "/api/planning/tasks/bulk" with body:
      """json
      {
        "tasks": [
          {"title": "Task 1", "priority": "P1"},
          {"title": "Task 2", "priority": "P2"},
          {"title": "Task 3", "priority": "P3"}
        ]
      }
      """
    Then the response status should be 201
    And 3 tasks should be created

  @rest @bulk_update
  Scenario: Bulk update task statuses
    Given tasks "1.0", "1.1", "1.2" exist with status "pending"
    When I send PUT request to "/api/planning/tasks/bulk" with body:
      """json
      {
        "ids": ["1.0", "1.1", "1.2"],
        "updates": {"status": "completed"}
      }
      """
    Then all 3 tasks should have status "completed"

  # ==========================================================================
  # GraphQL API - Queries
  # ==========================================================================

  @graphql @query_tasks
  Scenario: Query all tasks with GraphQL
    Given 5 tasks exist
    When I send GraphQL query:
      """graphql
      query {
        tasks {
          id
          title
          status
          priority
        }
      }
      """
    Then the response should contain 5 tasks
    And each task should have requested fields only

  @graphql @query_task_by_id
  Scenario: Query single task by ID
    Given task "1.0" exists with title "GraphQL test"
    When I send GraphQL query:
      """graphql
      query {
        task(id: "1.0") {
          id
          title
          status
          priority
          assignee
          createdAt
          updatedAt
        }
      }
      """
    Then the task with id "1.0" should be returned
    And all requested fields should be populated

  @graphql @query_with_filter
  Scenario: Query tasks with filter arguments
    Given tasks with various statuses exist
    When I send GraphQL query:
      """graphql
      query {
        tasks(filter: {status: PENDING, priority: P1}) {
          id
          title
        }
      }
      """
    Then only pending P1 tasks should be returned

  @graphql @query_nested
  Scenario: Query tasks with nested relationships
    Given task "1.0" has subtasks "1.1", "1.2"
    When I send GraphQL query:
      """graphql
      query {
        task(id: "1.0") {
          id
          title
          subtasks {
            id
            title
            status
          }
        }
      }
      """
    Then task "1.0" should include its subtasks

  @graphql @query_pagination
  Scenario: Query tasks with pagination
    Given 50 tasks exist
    When I send GraphQL query:
      """graphql
      query {
        tasks(first: 10, after: "cursor_10") {
          edges {
            node {
              id
              title
            }
            cursor
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
      """
    Then 10 tasks should be returned with cursor-based pagination

  # ==========================================================================
  # GraphQL API - Mutations
  # ==========================================================================

  @graphql @mutation_create
  Scenario: Create task with GraphQL mutation
    When I send GraphQL mutation:
      """graphql
      mutation {
        createTask(input: {
          title: "GraphQL created task"
          priority: P1
          status: PENDING
        }) {
          task {
            id
            title
            status
          }
        }
      }
      """
    Then a new task should be created
    And the response should include the new task

  @graphql @mutation_update
  Scenario: Update task with GraphQL mutation
    Given task "1.0" exists with status "pending"
    When I send GraphQL mutation:
      """graphql
      mutation {
        updateTask(id: "1.0", input: {
          status: COMPLETED
        }) {
          task {
            id
            status
          }
        }
      }
      """
    Then task "1.0" should have status "completed"

  @graphql @mutation_delete
  Scenario: Delete task with GraphQL mutation
    Given task "99.0" exists
    When I send GraphQL mutation:
      """graphql
      mutation {
        deleteTask(id: "99.0") {
          success
          deletedId
        }
      }
      """
    Then task "99.0" should be deleted
    And success should be true

  # ==========================================================================
  # GraphQL API - Subscriptions
  # ==========================================================================

  @graphql @subscription_task_updated
  Scenario: Subscribe to task updates
    Given I subscribe to GraphQL subscription:
      """graphql
      subscription {
        taskUpdated {
          id
          status
          updatedAt
        }
      }
      """
    When task "1.0" is updated to status "completed"
    Then I should receive a subscription event
    And the event should contain task "1.0" with new status

  @graphql @subscription_task_created
  Scenario: Subscribe to new task creation
    Given I subscribe to task creation events
    When a new task is created
    Then I should receive a creation event with task details

  # ==========================================================================
  # API Authentication
  # ==========================================================================

  @auth @api_key
  Scenario: Authenticate with API key
    When I send GET request to "/api/planning/tasks" with header "X-API-Key: valid_key"
    Then the response status should be 200

  @auth @invalid_key
  Scenario: Reject invalid API key
    When I send GET request to "/api/planning/tasks" with header "X-API-Key: invalid"
    Then the response status should be 401
    And the response should contain "Invalid API key"

  @auth @bearer_token
  Scenario: Authenticate with Bearer token
    Given a valid JWT token for user "admin"
    When I send GET request with Authorization header "Bearer <token>"
    Then the response status should be 200

  @auth @agent_access
  Scenario: Agent access uses authorized methods only
    Given agent "claude" is authenticated
    When agent sends request to "/api/planning/tasks"
    Then the request should be allowed
    And access should be logged with method "FSharpAPI"

  # ==========================================================================
  # API Rate Limiting
  # ==========================================================================

  @rate_limit @throttle
  Scenario: Rate limit excessive requests
    When I send 100 requests in 1 second
    Then requests after limit should receive status 429
    And response should include Retry-After header

  @rate_limit @quota
  Scenario: Track API quota
    Given user has quota of 1000 requests per hour
    When user makes 1001st request
    Then the request should be rejected with quota exceeded error

  # ==========================================================================
  # API Error Handling
  # ==========================================================================

  @error @validation
  Scenario: Return validation errors with details
    When I send POST with invalid task data
    Then the response status should be 422
    And the response should contain field-level error details

  @error @server_error
  Scenario: Handle internal errors gracefully
    Given the database is temporarily unavailable
    When I send a request
    Then the response status should be 503
    And error details should not expose internals

  @error @malformed_json
  Scenario: Handle malformed JSON request
    When I send POST with malformed JSON body
    Then the response status should be 400
    And the response should indicate JSON parse error

  # ==========================================================================
  # API Documentation
  # ==========================================================================

  @docs @openapi
  Scenario: OpenAPI spec is available
    When I send GET request to "/api/planning/openapi.json"
    Then the response should be valid OpenAPI 3.0 spec
    And all endpoints should be documented

  @docs @graphql_schema
  Scenario: GraphQL schema introspection
    When I send GraphQL introspection query
    Then the full schema should be returned
    And all types should be documented
