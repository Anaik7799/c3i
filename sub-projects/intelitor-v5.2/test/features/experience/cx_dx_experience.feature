@experience @cx @dx @P0
Feature: Customer Experience (CX) and Developer Experience (DX)
  As a user or developer
  I need excellent experience across all touchpoints
  So that I can effectively use and extend the system

  # =============================================================================
  # CUSTOMER EXPERIENCE (CX) - OPERATOR JOURNEYS
  # =============================================================================

  @cx @onboarding @P0
  Scenario: CX-ONB-001 - First-time operator onboarding
    Given I am a new operator accessing Prajna for the first time
    When I log in with my credentials
    Then I should see a welcome wizard
    And the wizard should include:
      | Step | Content                        |
      | 1    | System overview tour           |
      | 2    | Key features introduction      |
      | 3    | Role-specific training         |
      | 4    | Quick start checklist          |
    When I complete the wizard
    Then my onboarding status should be saved
    And I should have access to the dashboard

  @cx @onboarding @P1
  Scenario: CX-ONB-002 - Interactive feature discovery
    Given I am on the Prajna dashboard
    When I hover over a new feature
    Then a tooltip should explain the feature
    And there should be a "Learn More" link
    When I click "Learn More"
    Then a contextual help panel should open
    And relevant documentation should be displayed

  @cx @workflow @P0
  Scenario: CX-WFL-001 - Alarm response workflow efficiency
    Given I am an operator handling alarms
    When I receive a new alarm
    Then the following workflow should be possible:
      | Step | Action               | Clicks | Time   |
      | 1    | View alarm details   | 1      | <1s    |
      | 2    | Access site history  | 1      | <2s    |
      | 3    | Contact subscriber   | 1      | <1s    |
      | 4    | Dispatch response    | 2      | <3s    |
      | 5    | Log resolution       | 2      | <5s    |
    And the total workflow should complete in <60 seconds

  @cx @workflow @P0
  Scenario: CX-WFL-002 - Critical alarm escalation workflow
    Given I am handling a critical alarm
    When the alarm requires escalation
    Then I should see clear escalation options
    And one-click escalation should be available
    And the escalation chain should be visible
    And automatic notifications should be sent

  @cx @accessibility @P0
  Scenario: CX-ACC-001 - WCAG 2.1 AA compliance
    Given I am auditing accessibility
    Then the following should be met:
      | Criterion           | Requirement              |
      | Text contrast       | 4.5:1 minimum            |
      | Focus indicators    | Visible on all elements  |
      | Alt text            | All images have alt      |
      | Keyboard navigation | All features accessible  |
      | Screen reader       | All content readable     |
      | Error identification| Clear error messages     |

  @cx @accessibility @P0
  Scenario: CX-ACC-002 - Color-blind friendly design
    Given I have color vision deficiency
    Then critical information should not rely on color alone
    And icons/patterns should differentiate states
    And the color palette should be distinguishable:
      | State    | Primary Indicator   | Secondary Indicator |
      | Critical | Red + Alert icon    | Pulsing animation   |
      | Warning  | Yellow + Warning icon| Solid border        |
      | Normal   | Green + Check icon  | No border           |
      | Offline  | Gray + X icon       | Strikethrough       |

  @cx @mobile @P0
  Scenario: CX-MOB-001 - Mobile operator experience
    Given I am using Prajna on a mobile device
    Then the interface should be touch-optimized
    And critical actions should be within thumb reach
    And the following should be possible:
      | Action           | Mobile UX               |
      | View alarms      | Swipe-to-dismiss list   |
      | Acknowledge      | Single tap              |
      | Call subscriber  | Tap-to-call link        |
      | Add note         | Voice-to-text option    |

  @cx @mobile @P1
  Scenario: CX-MOB-002 - Offline capability
    Given I am on a mobile device with intermittent connectivity
    When I lose network connection
    Then I should see an offline indicator
    And I should be able to view cached data
    And critical actions should be queued
    When connectivity returns
    Then queued actions should sync automatically

  @cx @performance @P0
  Scenario: CX-PERF-001 - Response time perception
    Given I am performing common tasks
    Then the following response times should feel instant:
      | Action             | Perceived Time | Max Actual |
      | Click feedback     | Instant        | 100ms      |
      | Page navigation    | Fast           | 500ms      |
      | Data loading       | Acceptable     | 2000ms     |
      | Complex operations | Tolerable      | 5000ms     |
    And progress indicators should appear for >500ms operations

  @cx @consistency @P1
  Scenario: CX-CON-001 - UI consistency across modules
    Given I navigate between different Prajna modules
    Then the following should be consistent:
      | Element           | Consistency Requirement    |
      | Navigation        | Same position/behavior     |
      | Button styles     | Same appearance/placement  |
      | Table layouts     | Same column patterns       |
      | Modal dialogs     | Same structure             |
      | Error messages    | Same format                |

  @cx @feedback @P1
  Scenario: CX-FDB-001 - User feedback collection
    Given I am using Prajna
    When I encounter an issue
    Then I should be able to report feedback easily
    And the feedback form should include:
      | Field        | Auto-populated          |
      | Page URL     | Current location        |
      | Session info | User/time/browser       |
      | Screenshot   | Optional capture        |
    And feedback should be acknowledged immediately

  @cx @help @P0
  Scenario: CX-HLP-001 - Contextual help system
    Given I am on any Prajna page
    When I press F1 or click the help icon
    Then contextual help should appear
    And the help should be relevant to the current page
    And I should be able to search the help system
    And frequently asked questions should be visible

  @cx @notifications @P1
  Scenario: CX-NOT-001 - Notification preferences
    Given I am on the notification settings page
    Then I should be able to configure:
      | Setting          | Options                   |
      | Alert channels   | Email, SMS, Push, In-app  |
      | Severity filters | Critical, High, Medium    |
      | Quiet hours      | Time range selection      |
      | Digest frequency | Immediate, Hourly, Daily  |
    And my preferences should take effect immediately

  # =============================================================================
  # DEVELOPER EXPERIENCE (DX) - API & INTEGRATION
  # =============================================================================

  @dx @api @P0
  Scenario: DX-API-001 - REST API discoverability
    Given I am a developer integrating with Indrajaal
    When I access the API documentation at /api/docs
    Then I should see OpenAPI/Swagger documentation
    And the documentation should include:
      | Section        | Content                    |
      | Authentication | OAuth2 / API key methods   |
      | Endpoints      | Full CRUD operations       |
      | Models         | Request/response schemas   |
      | Examples       | Code samples in 5+ languages|
      | Try It         | Interactive API explorer   |

  @dx @api @P0
  Scenario: DX-API-002 - API authentication
    Given I am a developer
    When I attempt to authenticate
    Then the following methods should be supported:
      | Method     | Use Case                |
      | API Key    | Server-to-server        |
      | OAuth2     | User-delegated access   |
      | JWT        | Stateless authentication|
    And authentication errors should be clear and actionable

  @dx @api @P0
  Scenario: DX-API-003 - API error handling
    Given I am making API requests
    When an error occurs
    Then the response should include:
      | Field       | Description              |
      | status      | HTTP status code         |
      | error_code  | Machine-readable code    |
      | message     | Human-readable message   |
      | details     | Specific field errors    |
      | request_id  | For support reference    |
    And rate limit headers should always be present

  @dx @api @P1
  Scenario: DX-API-004 - API versioning
    Given I am using the API
    Then version should be specified via:
      | Method         | Example                    |
      | URL path       | /api/v1/alarms             |
      | Accept header  | application/vnd.indrajaal.v1|
    And deprecated endpoints should return warnings
    And a deprecation timeline should be documented

  @dx @sdk @P1
  Scenario: DX-SDK-001 - SDK availability
    Given I am a developer choosing an integration method
    Then SDKs should be available for:
      | Language   | Package Manager | Version |
      | Elixir     | Hex             | Latest  |
      | Python     | PyPI            | Latest  |
      | TypeScript | npm             | Latest  |
      | Rust       | Cargo           | Latest  |
      | Go         | Go Modules      | Latest  |
    And each SDK should have:
      | Feature        | Requirement           |
      | Type safety    | Full type definitions |
      | Auto-retry     | Built-in retry logic  |
      | Async support  | Native async/await    |
      | Documentation  | Inline docs + examples|

  @dx @webhooks @P0
  Scenario: DX-WHK-001 - Webhook integration
    Given I want to receive event notifications
    When I configure a webhook endpoint
    Then I should be able to:
      | Action           | Description              |
      | Register URL     | HTTPS endpoint           |
      | Select events    | Fine-grained event types |
      | Set secret       | HMAC signature key       |
      | Test delivery    | Send test payload        |
    And webhook payloads should include:
      | Field       | Description              |
      | event_type  | What happened            |
      | timestamp   | When it happened         |
      | data        | Event payload            |
      | signature   | HMAC verification        |

  @dx @webhooks @P1
  Scenario: DX-WHK-002 - Webhook reliability
    Given I have configured webhooks
    Then the system should provide:
      | Feature          | Behavior                   |
      | Retry policy     | Exponential backoff        |
      | Delivery logs    | Success/failure history    |
      | Failure alerts   | Email on repeated failures |
      | Manual replay    | Re-send failed events      |

  @dx @graphql @P1
  Scenario: DX-GQL-001 - GraphQL API support
    Given I prefer GraphQL over REST
    When I access /api/graphql
    Then I should have access to:
      | Feature         | Description             |
      | Schema explorer | GraphiQL playground     |
      | Queries         | All read operations     |
      | Mutations       | All write operations    |
      | Subscriptions   | Real-time via WebSocket |
      | Introspection   | Schema introspection    |

  @dx @cli @P0
  Scenario: DX-CLI-001 - Developer CLI tool
    Given I have installed the Indrajaal CLI
    Then the following commands should work:
      | Command          | Function                  |
      | indrajaal login  | Authenticate              |
      | indrajaal alarms | List/filter alarms        |
      | indrajaal sites  | Manage sites              |
      | indrajaal logs   | Stream logs               |
      | indrajaal config | Manage configuration      |
    And shell completion should be available

  @dx @testing @P0
  Scenario: DX-TEST-001 - API testing support
    Given I am developing an integration
    Then the following testing support should be available:
      | Feature         | Description              |
      | Sandbox env     | Isolated test environment|
      | Test data       | Seed data generation     |
      | Mock server     | Local API mock           |
      | Postman/Insomnia| Pre-built collections    |

  @dx @documentation @P0
  Scenario: DX-DOC-001 - Developer documentation quality
    Given I am reading the developer documentation
    Then the documentation should include:
      | Section           | Content                   |
      | Quick Start       | <5 min integration guide  |
      | Tutorials         | Step-by-step guides       |
      | API Reference     | Complete endpoint docs    |
      | Code Examples     | Copy-paste snippets       |
      | Best Practices    | Recommended patterns      |
      | Troubleshooting   | Common issues + solutions |
      | Changelog         | Version history           |

  @dx @documentation @P1
  Scenario: DX-DOC-002 - Documentation search
    Given I am on the documentation site
    When I search for a topic
    Then results should appear instantly
    And results should include:
      | Source        | Priority |
      | API Reference | High     |
      | Tutorials     | Medium   |
      | Examples      | Medium   |
      | FAQ           | Lower    |

  @dx @errors @P0
  Scenario: DX-ERR-001 - Error message quality
    Given I encounter an error during development
    Then error messages should include:
      | Element       | Description              |
      | What happened | Clear error description  |
      | Why           | Likely cause             |
      | How to fix    | Actionable guidance      |
      | Link          | Relevant documentation   |
      | Example       | Correct usage            |

  @dx @debugging @P1
  Scenario: DX-DBG-001 - Debug mode support
    Given I am debugging an integration
    When I enable debug mode
    Then I should see:
      | Information     | Detail Level            |
      | Request/Response| Full headers + body     |
      | Timing          | Per-operation timing    |
      | Trace IDs       | Distributed trace links |
      | Stack traces    | Full error context      |

  @dx @performance @P1
  Scenario: DX-PERF-001 - API performance
    Given I am making API requests
    Then performance should meet:
      | Operation     | p50   | p95    | p99    |
      | List (100)    | 50ms  | 150ms  | 300ms  |
      | Get single    | 20ms  | 50ms   | 100ms  |
      | Create        | 100ms | 200ms  | 500ms  |
      | Update        | 100ms | 200ms  | 500ms  |
      | Delete        | 50ms  | 100ms  | 200ms  |

  @dx @rate-limits @P0
  Scenario: DX-RATE-001 - Rate limiting transparency
    Given I am making API requests
    Then rate limit headers should be present:
      | Header                | Value                 |
      | X-RateLimit-Limit     | Requests per window   |
      | X-RateLimit-Remaining | Remaining requests    |
      | X-RateLimit-Reset     | Window reset time     |
    And 429 responses should include retry-after

  @dx @security @P0
  Scenario: DX-SEC-001 - Security best practices guidance
    Given I am implementing an integration
    Then documentation should guide me on:
      | Topic              | Guidance                  |
      | Secret storage     | Never hardcode secrets    |
      | Token rotation     | Regular rotation policy   |
      | HTTPS              | TLS 1.2+ required         |
      | Webhook validation | Signature verification    |
      | Least privilege    | Minimal scope grants      |

  # =============================================================================
  # DEVELOPER EXPERIENCE (DX) - LOCAL DEVELOPMENT
  # =============================================================================

  @dx @local @P0
  Scenario: DX-LOCAL-001 - Local development setup
    Given I am setting up local development
    When I run `devenv shell`
    Then the development environment should start
    And all dependencies should be available
    And the setup should take less than 5 minutes

  @dx @local @P1
  Scenario: DX-LOCAL-002 - Hot reload support
    Given I am developing locally
    When I save a file change
    Then the following should hot reload:
      | File Type  | Reload Time |
      | Elixir     | <3 seconds  |
      | LiveView   | <2 seconds  |
      | CSS        | <1 second   |
      | JavaScript | <2 seconds  |

  @dx @local @P1
  Scenario: DX-LOCAL-003 - Database seeding
    Given I need test data
    When I run seed commands
    Then realistic test data should be generated
    And I should be able to specify data volume
    And sensitive data should be anonymized

  @dx @contributing @P1
  Scenario: DX-CTB-001 - Contributing guidelines
    Given I want to contribute to the project
    Then I should find:
      | Document         | Content                    |
      | CONTRIBUTING.md  | How to contribute          |
      | CODE_OF_CONDUCT  | Community guidelines       |
      | Issue templates  | Bug/feature templates      |
      | PR template      | Pull request checklist     |
    And the contribution process should be clear

  @dx @ci @P0
  Scenario: DX-CI-001 - CI/CD integration
    Given I am contributing code
    When I submit a pull request
    Then CI should run automatically
    And the following should be checked:
      | Check           | Requirement              |
      | Compilation     | 0 errors, 0 warnings     |
      | Tests           | All passing              |
      | Coverage        | >= 95%                   |
      | Format          | mix format compliant     |
      | Credo           | 0 issues                 |
      | Security        | Sobelow passing          |

  # =============================================================================
  # ZENOH INTEGRATION EXPERIENCE
  # =============================================================================

  @dx @zenoh @P0 @SC-BRIDGE-005
  Scenario: DX-ZEN-001 - Zenoh pub/sub integration
    Given I am integrating with Zenoh
    Then I should be able to:
      | Action         | Example                    |
      | Subscribe      | zenoh:alarms/*             |
      | Publish        | zenoh:commands/dispatch    |
      | Query          | zenoh:state/sites/{id}     |
    And documentation should include Zenoh topic schema

  @dx @zenoh @P1
  Scenario: DX-ZEN-002 - Zenoh connection management
    Given I am using Zenoh
    Then the SDK should handle:
      | Scenario         | Behavior                   |
      | Connection loss  | Auto-reconnect             |
      | Message ordering | FIFO preserved             |
      | Backpressure     | Graceful handling          |
      | Timeouts         | Configurable               |

  # =============================================================================
  # TELEMETRY & OBSERVABILITY DX
  # =============================================================================

  @dx @observability @P0
  Scenario: DX-OBS-001 - Integration observability
    Given I have deployed an integration
    Then I should be able to observe:
      | Metric           | Dashboard Location        |
      | API calls        | Grafana API dashboard     |
      | Latency          | Request timing panel      |
      | Errors           | Error rate panel          |
      | Quota usage      | Rate limit panel          |

  @dx @tracing @P1
  Scenario: DX-TRC-001 - Distributed tracing support
    Given I am debugging a request flow
    When I inspect a trace
    Then I should see the full request path
    And I should be able to correlate with my system's traces
    And span data should include business context

  # =============================================================================
  # SUPPORT EXPERIENCE
  # =============================================================================

  @dx @support @P1
  Scenario: DX-SUP-001 - Developer support channels
    Given I need help with integration
    Then the following support should be available:
      | Channel         | Response Time | Use Case           |
      | Documentation   | Immediate     | Self-service       |
      | Community Forum | <24 hours     | General questions  |
      | GitHub Issues   | <48 hours     | Bug reports        |
      | Support Email   | <8 hours      | Account issues     |
      | Enterprise Chat | <1 hour       | Enterprise plans   |

  @dx @changelog @P0
  Scenario: DX-CHG-001 - API changelog
    Given I want to track API changes
    Then I should have access to:
      | Resource        | Content                   |
      | Changelog       | Version-by-version changes|
      | Migration guide | Breaking change guides    |
      | Deprecation     | Sunset timeline           |
      | RSS feed        | Subscribe to updates      |
