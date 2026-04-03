# STAMP: SC-BOOT-012, SC-AI-001, SC-AI-004
# AOR: AOR-OPENROUTER-001 to AOR-OPENROUTER-005, AOR-RCA-001

@ai @openrouter @rca @SC-BOOT-012 @SC-AI-001
Feature: AI-Assisted Root Cause Analysis via OpenRouter
  As a system operator
  I want AI-assisted 7-level RCA via OpenRouter
  So that complex startup failures can be analyzed intelligently

  Background:
    Given the OpenRouter configuration is:
      | Setting       | Value                                    |
      | Endpoint      | https://openrouter.ai/api/v1/chat/completions |
      | DefaultModel  | anthropic/claude-3-haiku:free           |
      | TimeoutMs     | 30000                                    |
      | MaxRetries    | 3                                        |
    And the TPS 5-Why methodology is active

  # ============================================================================
  # Model Selection Strategy
  # ============================================================================

  @model-selection @complexity
  Scenario Outline: Select model based on error complexity
    Given the error complexity is <complexity>
    And no model is forced
    When I select the model
    Then the selected model should be "<model>"

    Examples:
      | complexity | model                        |
      | 1          | anthropic/claude-3-haiku:free|
      | 2          | anthropic/claude-3-haiku:free|
      | 3          | anthropic/claude-3-haiku:free|
      | 4          | anthropic/claude-3-sonnet    |
      | 5          | anthropic/claude-3-sonnet    |
      | 6          | anthropic/claude-3-sonnet    |
      | 7          | anthropic/claude-3-opus      |
      | 8          | anthropic/claude-3-opus      |
      | 10         | anthropic/claude-3-opus      |

  @model-selection @forced
  Scenario: Forced model selection
    Given the error complexity is 3
    And the model is forced to "anthropic/claude-3-opus"
    When I select the model
    Then the selected model should be "anthropic/claude-3-opus"

  @complexity @calculation
  Scenario Outline: Calculate error complexity from log
    Given the error log is "<error_log>"
    When I calculate the complexity
    Then the complexity should be <expected>

    Examples:
      | error_log                                           | expected |
      | Connection refused                                  | 1        |
      | oban_peers table undefined                          | 1        |
      | Architecture specification gap detected             | 4        |
      | systemic cross-module failure cascade               | 5        |
      | design pattern violation with cascade propagation   | 6        |

  # ============================================================================
  # Free Model Usage (AOR-OPENROUTER-001)
  # ============================================================================

  @free-models @AOR-OPENROUTER-001
  Scenario: Free models are available
    When I list available free models
    Then the list should include:
      | Model                                |
      | anthropic/claude-3-haiku:free        |
      | google/gemma-7b-it:free              |
      | mistralai/mistral-7b-instruct:free   |
      | meta-llama/llama-3-8b-instruct:free  |

  @free-models @default
  Scenario: Default model is free
    Given the default configuration
    When I check the default model
    Then it should be "anthropic/claude-3-haiku:free"
    And it should have the ":free" suffix

  # ============================================================================
  # Rate Limiting (AOR-OPENROUTER-002)
  # ============================================================================

  @rate-limit @backoff @AOR-OPENROUTER-002
  Scenario: Exponential backoff on rate limit (429)
    Given the API returns status code 429
    When I make 3 retry attempts
    Then the backoff should be exponential:
      | Retry | Backoff |
      | 1     | 2000ms  |
      | 2     | 4000ms  |
      | 3     | 8000ms  |

  @rate-limit @recovery
  Scenario: Recovery after rate limit
    Given the first 2 API calls return 429
    And the 3rd call succeeds
    When I analyze with AI
    Then the analysis should eventually succeed
    And the retry count should be logged

  # ============================================================================
  # Caching (AOR-OPENROUTER-003)
  # ============================================================================

  @cache @hit @AOR-OPENROUTER-003
  Scenario: Cache hit for identical error
    Given I have previously analyzed error "oban_peers table undefined"
    And the cached result is less than 24 hours old
    When I analyze the same error again
    Then the cached result should be returned
    And no API call should be made
    And the cache key should be a SHA256 hash

  @cache @miss
  Scenario: Cache miss for new error
    Given the error "new unknown error" has not been analyzed
    When I analyze with AI
    Then an API call should be made
    And the result should be cached for future use

  @cache @expiry
  Scenario: Cache expiry after 24 hours
    Given I have a cached result from 25 hours ago
    When I analyze the same error
    Then the cache should miss
    And a fresh API call should be made
    And the cache should be updated

  # ============================================================================
  # Audit Logging (AOR-OPENROUTER-004)
  # ============================================================================

  @audit @logging @AOR-OPENROUTER-004
  Scenario: API call is logged to audit trail
    When I make an API call to OpenRouter
    Then an audit entry should be created with:
      | Field          | Type      |
      | Timestamp      | DateTime  |
      | Model          | string    |
      | RequestSummary | string    |
      | Status         | string    |
      | TokensUsed     | int       |
      | LatencyMs      | int64     |
      | Error          | option    |

  @audit @success
  Scenario: Successful API call audit
    Given the API call succeeds with 500 tokens
    When I check the audit log
    Then the entry should have:
      | Field      | Value   |
      | Status     | Success |
      | TokensUsed | 500     |
      | Error      | None    |

  @audit @failure
  Scenario: Failed API call audit
    Given the API call fails with "Connection timeout"
    When I check the audit log
    Then the entry should have:
      | Field  | Value              |
      | Status | Failed             |
      | Error  | Connection timeout |

  @audit @summary
  Scenario: Print audit summary
    Given 10 API calls have been made:
      | Success | Failed | Total Tokens |
      | 8       | 2      | 5000         |
    When I print the audit summary
    Then I should see:
      | Metric        | Value   |
      | Total Calls   | 10      |
      | Success       | 8       |
      | Failed        | 2       |
      | Total Tokens  | 5000    |
      | Avg Latency   | present |
      | Cache Size    | present |

  # ============================================================================
  # Offline/Mock Mode (AOR-OPENROUTER-005)
  # ============================================================================

  @offline @mock @AOR-OPENROUTER-005
  Scenario: Mock mode when no API key
    Given the OPENROUTER_API_KEY environment variable is not set
    When I analyze with AI
    Then mock mode should be used
    And the local pattern matching should be invoked
    And a message should indicate mock mode

  @offline @mock @explicit
  Scenario: Explicit mock mode enabled
    Given MockMode is set to true
    And OPENROUTER_API_KEY is set
    When I analyze with AI
    Then mock mode should be used
    And no API call should be made

  @offline @fallback
  Scenario: Fallback to local analysis on API failure
    Given OPENROUTER_API_KEY is set
    But the API is unreachable
    When I analyze with AI
    Then local pattern matching should be used as fallback
    And the result should still be valid
    And the fallback should be logged

  # ============================================================================
  # Prompt Building
  # ============================================================================

  @prompt @structure
  Scenario: RCA prompt includes required sections
    Given the error log is "oban_peers table undefined"
    And context includes:
      | Key        | Value          |
      | Container  | indrajaal-app  |
      | Stage      | S3_APP_SEED    |
    When I build the RCA prompt
    Then the prompt should include:
      | Section               |
      | Error Log             |
      | Context               |
      | 7-Level RCA Matrix    |
      | Output Format (JSON)  |

  @prompt @json-format
  Scenario: Prompt requests JSON output
    When I build the RCA prompt
    Then the prompt should request JSON with fields:
      | Field              |
      | findings           |
      | rootCauseLevel     |
      | rootCauseSummary   |
      | recommendedFix     |
      | preventionStrategy |

  # ============================================================================
  # Response Parsing
  # ============================================================================

  @parse @success
  Scenario: Parse valid AI response
    Given the AI response is:
      """
      {
        "findings": [
          {"level": "L1", "finding": "App crashes"},
          {"level": "L2", "finding": "Oban error"},
          {"level": "L3", "finding": "No migrations"},
          {"level": "L4", "finding": "Missing gate"},
          {"level": "L5", "finding": "No state check"},
          {"level": "L6", "finding": "No contracts"},
          {"level": "L7", "finding": "No spec"}
        ],
        "rootCauseLevel": "L7",
        "rootCauseSummary": "Missing startup specification",
        "recommendedFix": "Add SC-BOOT-001 verification",
        "preventionStrategy": "Implement state vectors"
      }
      """
    When I parse the response
    Then I should get an RCAReport with 7 findings
    And the root cause level should be L7_Architecture

  @parse @markdown-wrapped
  Scenario: Parse JSON wrapped in markdown code blocks
    Given the AI response contains JSON in markdown:
      """
      Here's my analysis:
      ```json
      {
        "findings": [...],
        "rootCauseLevel": "L4",
        "rootCauseSummary": "Module issue",
        "recommendedFix": "Fix module",
        "preventionStrategy": "Testing"
      }
      ```
      """
    When I parse the response
    Then the JSON should be extracted correctly
    And parsing should succeed

  @parse @failure
  Scenario: Handle invalid AI response
    Given the AI response is malformed JSON
    When I parse the response
    Then the result should be None
    And no exception should be thrown

  # ============================================================================
  # Full Analysis Workflow
  # ============================================================================

  @workflow @success
  Scenario: Complete AI-assisted RCA analysis
    Given OPENROUTER_API_KEY is set
    And the API is available
    And the error is "complex multi-stage failure"
    When I run quickAnalyzeWithAI
    Then I should receive an RCAReport
    And AnalysisDurationMs should be recorded
    And the result should be cached
    And an audit entry should be created

  @workflow @context
  Scenario: Analysis with additional context
    Given the request includes context:
      | Key         | Value              |
      | Container   | indrajaal-ex-app-1 |
      | Stage       | S3_APP_SEED        |
      | StateVector | [1,1,1,1,0,0]      |
    When I analyze with AI
    Then the context should be included in the prompt
    And the AI should consider the context

  @workflow @timing
  Scenario: Analysis completes within timeout
    Given the timeout is 30000ms
    When I analyze with AI
    Then the analysis should complete within the timeout
    And LatencyMs should be less than 30000
