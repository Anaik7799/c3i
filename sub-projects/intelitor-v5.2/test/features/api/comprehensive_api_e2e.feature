@api @rest @graphql @P0
Feature: Comprehensive API End-to-End Coverage
  As an API consumer
  I need complete API functionality
  So that I can integrate with the Indrajaal system

  Background:
    Given the API server is running
    And I have valid API credentials
    And rate limits are not exceeded

  # =============================================================================
  # AUTHENTICATION API
  # =============================================================================

  @auth @oauth2 @P0
  Scenario: API-AUTH-001 - OAuth2 token acquisition
    When I POST to "/api/oauth/token" with:
      | Field         | Value                     |
      | grant_type    | client_credentials        |
      | client_id     | test_client               |
      | client_secret | test_secret               |
    Then the response status should be 200
    And the response should contain:
      | Field          | Type    |
      | access_token   | string  |
      | token_type     | "Bearer"|
      | expires_in     | integer |
      | refresh_token  | string  |

  @auth @api-key @P0
  Scenario: API-AUTH-002 - API key authentication
    When I make a request with header "X-API-Key: valid_api_key"
    Then the request should be authenticated
    And rate limiting should apply to the API key

  @auth @jwt @P0
  Scenario: API-AUTH-003 - JWT validation
    Given I have a valid JWT token
    When I make a request with "Authorization: Bearer <token>"
    Then the request should be authenticated
    And the token claims should be accessible
    When the token expires
    Then requests should return 401 Unauthorized

  @auth @refresh @P1
  Scenario: API-AUTH-004 - Token refresh
    Given I have a valid refresh token
    When I POST to "/api/oauth/token" with:
      | Field         | Value          |
      | grant_type    | refresh_token  |
      | refresh_token | <refresh_token>|
    Then I should receive a new access token
    And the old access token should be invalidated

  # =============================================================================
  # ALARMS API
  # =============================================================================

  @alarms @list @P0
  Scenario: API-ALM-001 - List alarms
    When I GET "/api/v1/alarms"
    Then the response status should be 200
    And the response should be paginated
    And each alarm should contain:
      | Field       | Type      |
      | id          | uuid      |
      | site_id     | uuid      |
      | type        | string    |
      | severity    | string    |
      | status      | string    |
      | created_at  | timestamp |

  @alarms @filter @P0
  Scenario: API-ALM-002 - Filter alarms
    When I GET "/api/v1/alarms" with query params:
      | Param    | Value     |
      | severity | critical  |
      | status   | active    |
      | site_id  | <uuid>    |
      | from     | 2026-01-01|
      | to       | 2026-01-31|
    Then only matching alarms should be returned

  @alarms @get @P0
  Scenario: API-ALM-003 - Get single alarm
    Given an alarm exists with id "<alarm_id>"
    When I GET "/api/v1/alarms/<alarm_id>"
    Then the response status should be 200
    And the full alarm details should be returned
    And related data should be included (site, subscriber)

  @alarms @acknowledge @P0
  Scenario: API-ALM-004 - Acknowledge alarm
    Given an active alarm exists
    When I POST "/api/v1/alarms/<id>/acknowledge" with:
      | Field    | Value              |
      | operator | operator@email.com |
      | note     | Investigating      |
    Then the response status should be 200
    And the alarm status should be "acknowledged"
    And the acknowledgment should be logged

  @alarms @resolve @P0
  Scenario: API-ALM-005 - Resolve alarm
    Given an acknowledged alarm exists
    When I POST "/api/v1/alarms/<id>/resolve" with:
      | Field      | Value              |
      | resolution | False alarm        |
      | note       | Verified by phone  |
    Then the response status should be 200
    And the alarm status should be "resolved"
    And the resolution should be logged

  @alarms @webhook @P1
  Scenario: API-ALM-006 - Alarm webhook delivery
    Given I have a webhook registered for alarm events
    When a new alarm is created
    Then a webhook should be delivered to my endpoint
    And the payload should include alarm details
    And the payload should be signed with HMAC

  # =============================================================================
  # SITES API
  # =============================================================================

  @sites @crud @P0
  Scenario: API-SITE-001 - Site CRUD operations
    When I POST "/api/v1/sites" with valid site data
    Then the site should be created
    And I should receive the site ID
    When I GET "/api/v1/sites/<id>"
    Then the site details should be returned
    When I PATCH "/api/v1/sites/<id>" with updates
    Then the site should be updated
    When I DELETE "/api/v1/sites/<id>"
    Then the site should be deactivated (soft delete)

  @sites @zones @P0
  Scenario: API-SITE-002 - Site zones management
    Given a site exists
    When I GET "/api/v1/sites/<id>/zones"
    Then all zones for the site should be listed
    When I POST "/api/v1/sites/<id>/zones" with zone data
    Then a new zone should be created
    When I DELETE "/api/v1/sites/<id>/zones/<zone_id>"
    Then the zone should be removed

  @sites @contacts @P1
  Scenario: API-SITE-003 - Site contacts management
    Given a site exists
    When I GET "/api/v1/sites/<id>/contacts"
    Then all contacts for the site should be listed
    And contacts should be ordered by priority
    When I POST "/api/v1/sites/<id>/contacts" with contact data
    Then a new contact should be added

  @sites @history @P1
  Scenario: API-SITE-004 - Site alarm history
    Given a site exists with alarm history
    When I GET "/api/v1/sites/<id>/alarms"
    Then paginated alarm history should be returned
    And I can filter by date range

  # =============================================================================
  # SUBSCRIBERS API
  # =============================================================================

  @subscribers @crud @P0
  Scenario: API-SUB-001 - Subscriber CRUD operations
    When I POST "/api/v1/subscribers" with valid subscriber data
    Then the subscriber should be created
    When I GET "/api/v1/subscribers/<id>"
    Then subscriber details should be returned
    When I PATCH "/api/v1/subscribers/<id>" with updates
    Then the subscriber should be updated

  @subscribers @sites @P0
  Scenario: API-SUB-002 - Subscriber sites relationship
    Given a subscriber exists
    When I GET "/api/v1/subscribers/<id>/sites"
    Then all sites for the subscriber should be listed
    When I POST "/api/v1/subscribers/<id>/sites" to link a site
    Then the site should be associated with the subscriber

  # =============================================================================
  # DEVICES API
  # =============================================================================

  @devices @list @P0
  Scenario: API-DEV-001 - List devices
    When I GET "/api/v1/devices"
    Then all devices should be listed
    And each device should include:
      | Field        | Type    |
      | id           | uuid    |
      | type         | string  |
      | model        | string  |
      | serial       | string  |
      | status       | string  |
      | last_contact | timestamp|

  @devices @status @P0
  Scenario: API-DEV-002 - Device status update
    Given a device exists
    When I PATCH "/api/v1/devices/<id>/status" with:
      | Field  | Value   |
      | status | offline |
    Then the device status should update
    And a status change event should be logged

  @devices @signals @P1
  Scenario: API-DEV-003 - Receive device signals
    When I POST "/api/v1/devices/signals" with:
      | Field   | Value              |
      | device  | <device_id>        |
      | signal  | BA (Burglary)      |
      | zone    | 001                |
    Then the signal should be processed
    And an alarm should be created if applicable

  # =============================================================================
  # OPERATORS API
  # =============================================================================

  @operators @crud @P0
  Scenario: API-OPR-001 - Operator management
    When I POST "/api/v1/operators" with operator data
    Then the operator should be created
    When I GET "/api/v1/operators"
    Then all operators should be listed
    When I GET "/api/v1/operators/<id>/performance"
    Then operator performance metrics should be returned

  @operators @permissions @P0
  Scenario: API-OPR-002 - Operator permissions
    Given an operator exists
    When I GET "/api/v1/operators/<id>/permissions"
    Then the operator's permissions should be listed
    When I PATCH "/api/v1/operators/<id>/permissions"
    Then permissions should be updated

  # =============================================================================
  # REPORTS API
  # =============================================================================

  @reports @generate @P0
  Scenario: API-RPT-001 - Generate report
    When I POST "/api/v1/reports" with:
      | Field       | Value          |
      | type        | monthly_summary|
      | date_range  | 2026-01-01/2026-01-31|
      | format      | pdf            |
    Then the report should be queued for generation
    And I should receive a job ID
    When I GET "/api/v1/reports/jobs/<job_id>"
    Then I should see job status
    When the job completes
    Then I should be able to download the report

  @reports @templates @P1
  Scenario: API-RPT-002 - Report templates
    When I GET "/api/v1/reports/templates"
    Then available report templates should be listed
    And each template should describe required parameters

  # =============================================================================
  # DISPATCH API
  # =============================================================================

  @dispatch @create @P0
  Scenario: API-DSP-001 - Create dispatch
    Given an alarm exists requiring response
    When I POST "/api/v1/dispatches" with:
      | Field       | Value              |
      | alarm_id    | <alarm_uuid>       |
      | type        | armed_response     |
      | priority    | high               |
    Then a dispatch should be created
    And the response team should be notified

  @dispatch @tracking @P0
  Scenario: API-DSP-002 - Track dispatch
    Given a dispatch is in progress
    When I GET "/api/v1/dispatches/<id>"
    Then dispatch details should be returned
    And current guard location should be included
    And ETA should be calculated

  @dispatch @complete @P0
  Scenario: API-DSP-003 - Complete dispatch
    Given a dispatch exists
    When I POST "/api/v1/dispatches/<id>/complete" with:
      | Field    | Value         |
      | status   | resolved      |
      | report   | All clear     |
      | photos   | [<photo_ids>] |
    Then the dispatch should be completed
    And the alarm should be updated

  # =============================================================================
  # ANALYTICS API
  # =============================================================================

  @analytics @metrics @P0
  Scenario: API-ANA-001 - Get metrics
    When I GET "/api/v1/analytics/metrics" with:
      | Param      | Value          |
      | metric     | alarm_count    |
      | period     | daily          |
      | from       | 2026-01-01     |
      | to         | 2026-01-31     |
    Then time-series metrics should be returned
    And data points should match the period granularity

  @analytics @aggregates @P1
  Scenario: API-ANA-002 - Get aggregates
    When I GET "/api/v1/analytics/aggregates" with:
      | Param      | Value          |
      | dimension  | severity       |
      | from       | 2026-01-01     |
      | to         | 2026-01-31     |
    Then aggregated data should be returned
    And grouped by the requested dimension

  # =============================================================================
  # GRAPHQL API
  # =============================================================================

  @graphql @query @P0
  Scenario: API-GQL-001 - GraphQL queries
    When I POST to "/api/graphql" with query:
      ```graphql
      query {
        alarms(first: 10, filter: {severity: CRITICAL}) {
          edges {
            node {
              id
              type
              severity
              site { name }
            }
          }
        }
      }
      ```
    Then alarms matching the query should be returned

  @graphql @mutation @P0
  Scenario: API-GQL-002 - GraphQL mutations
    When I POST to "/api/graphql" with mutation:
      ```graphql
      mutation {
        acknowledgeAlarm(id: "<alarm_id>", note: "Investigating") {
          alarm {
            id
            status
          }
        }
      }
      ```
    Then the alarm should be acknowledged

  @graphql @subscription @P1
  Scenario: API-GQL-003 - GraphQL subscriptions
    When I subscribe to:
      ```graphql
      subscription {
        newAlarm {
          id
          type
          severity
        }
      }
      ```
    Then I should receive real-time alarm notifications

  # =============================================================================
  # RATE LIMITING
  # =============================================================================

  @rate-limit @headers @P0
  Scenario: API-RATE-001 - Rate limit headers
    When I make any API request
    Then the response should include headers:
      | Header                  | Description        |
      | X-RateLimit-Limit       | Total requests     |
      | X-RateLimit-Remaining   | Requests left      |
      | X-RateLimit-Reset       | Reset timestamp    |

  @rate-limit @exceeded @P0
  Scenario: API-RATE-002 - Rate limit exceeded
    Given I have exceeded my rate limit
    When I make another request
    Then the response status should be 429
    And the response should include "Retry-After" header
    And the error message should indicate rate limit

  # =============================================================================
  # ERROR HANDLING
  # =============================================================================

  @errors @validation @P0
  Scenario: API-ERR-001 - Validation errors
    When I POST to "/api/v1/alarms" with invalid data
    Then the response status should be 400
    And the response should contain:
      | Field       | Description           |
      | error_code  | VALIDATION_ERROR      |
      | message     | Human-readable message|
      | details     | Field-specific errors |
      | request_id  | For debugging         |

  @errors @not-found @P0
  Scenario: API-ERR-002 - Resource not found
    When I GET "/api/v1/alarms/<non_existent_id>"
    Then the response status should be 404
    And the error should indicate resource not found

  @errors @unauthorized @P0
  Scenario: API-ERR-003 - Unauthorized access
    When I make a request without authentication
    Then the response status should be 401
    And the error should indicate authentication required

  @errors @forbidden @P0
  Scenario: API-ERR-004 - Forbidden access
    Given I am authenticated but lack permission
    When I try to access a restricted resource
    Then the response status should be 403
    And the error should indicate insufficient permissions

  # =============================================================================
  # BULK OPERATIONS
  # =============================================================================

  @bulk @create @P1
  Scenario: API-BULK-001 - Bulk create
    When I POST to "/api/v1/sites/bulk" with multiple sites
    Then all sites should be created
    And I should receive all created IDs
    And failures should be reported individually

  @bulk @update @P1
  Scenario: API-BULK-002 - Bulk update
    When I PATCH to "/api/v1/alarms/bulk/acknowledge" with:
      | Field     | Value         |
      | alarm_ids | [<id1>, <id2>]|
      | note      | Bulk ack      |
    Then all specified alarms should be acknowledged

  # =============================================================================
  # PAGINATION
  # =============================================================================

  @pagination @cursor @P0
  Scenario: API-PAG-001 - Cursor-based pagination
    When I GET "/api/v1/alarms?first=10"
    Then I should receive at most 10 results
    And the response should include:
      | Field       | Description          |
      | edges       | Result array         |
      | pageInfo    | Pagination metadata  |
      | hasNextPage | Boolean              |
      | endCursor   | For next page        |
    When I GET "/api/v1/alarms?first=10&after=<endCursor>"
    Then I should receive the next page

  @pagination @offset @P1
  Scenario: API-PAG-002 - Offset-based pagination
    When I GET "/api/v1/sites?page=2&per_page=20"
    Then I should receive page 2 results
    And the response should include total count
