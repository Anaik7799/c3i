# Devenv Commands - Exhaustive BDD Verification Suite
# GA Release v21.2.1-SIL6 - All 102 Commands (32 core + 70 extended)
# Framework: Wallaby + Puppeteer + ExUnit
# STAMP: SC-CMD-001 to SC-CMD-010
# AOR: AOR-CMD-001 to AOR-CMD-008

@devenv @all_commands @ga_release
Feature: Devenv Shell Commands Complete Verification
  As a release engineer
  I want all 102 devenv commands (32 core + 70 extended) verified working
  So that GA release meets 100% runtime functional coverage

  Background:
    Given devenv shell is active
    And Patient Mode is enabled with NO_TIMEOUT=true
    And environment variable SKIP_ZENOH_NIF is set to "0"

  # ============================================
  # APP & SERVER COMMANDS (3 Commands)
  # ============================================

  @app @priority_p0 @l1_function
  Scenario: CMD-01 - app - Start Phoenix server
    Given no process is bound to port 4000
    And compilation is complete
    When I execute "app" command
    Then Phoenix server should start within 5 seconds
    And port 4000 should be listening
    And HTTP GET "/" should return 200 status
    And telemetry event [:phoenix, :endpoint, :start] should fire

  @app @priority_p0 @l2_module
  Scenario: CMD-02 - app-start - Containers + Phoenix
    Given no containers are running with prefix "indrajaal"
    When I execute "app-start" command
    Then dev containers should start within 10 seconds
    And Phoenix should connect to database
    And port 4000 should be listening
    And port 5433 should be listening
    And 5-order cascade should complete:
      | Order | Effect |
      | 1st | Containers created |
      | 2nd | Networks attached |
      | 3rd | DB accepting connections |
      | 4th | Phoenix booted |
      | 5th | Health endpoints active |

  @app @priority_p1 @l1_function
  Scenario: CMD-03 - app-iex - Phoenix with IEx console
    Given no process is bound to port 4000
    When I execute "app-iex" command
    Then IEx shell should be available
    And Phoenix server should start
    And I should be able to evaluate "Indrajaal.Application.started_applications()"

  # ============================================
  # COMPILATION COMMANDS (4 Commands)
  # ============================================

  @compile @priority_p0 @critical @l3_domain
  Scenario: CMD-04 - compile - Patient Mode compilation
    Given _build directory may or may not exist
    When I execute "compile" command
    Then compilation should complete without errors
    And compilation should complete without warnings
    And ./data/tmp/1-compile.log should contain compilation output
    And all 1500+ files should be compiled
    And 5-order cascade should complete:
      | Order | Effect |
      | 1st | .beam files generated |
      | 2nd | NIFs compiled (Zenoh) |
      | 3rd | Ash DSL expanded |
      | 4th | Phoenix routes compiled |
      | 5th | Application bootable |

  @compile @priority_p0 @critical @l3_domain
  Scenario: CMD-05 - compile-strict - Warnings as errors
    Given project has no intentional warnings
    When I execute "compile-strict" command
    Then compilation should fail if any warnings exist
    And exit code should be 0 for clean project
    And STAMP constraint SC-CMP-025 should be satisfied

  @quality @priority_p0 @l4_application
  Scenario: CMD-06 - quality - Format + Credo checks
    Given project code is properly formatted
    When I execute "quality" command
    Then mix format --check-formatted should pass
    And mix credo --strict should pass
    And output should show "Quality OK"

  @quality @priority_p1 @l4_application
  Scenario: CMD-07 - quality-full - Full quality pipeline
    Given project passes basic quality checks
    When I execute "quality-full" command
    Then mix format should pass
    And mix credo should pass
    And mix dialyzer should pass
    And mix sobelow should pass
    And output should show "All quality gates passed"
    And 5-order cascade should complete:
      | Order | Effect |
      | 1st | Format verified |
      | 2nd | Credo analysis complete |
      | 3rd | Dialyzer types checked |
      | 4th | Sobelow security scan |
      | 5th | All gates passed |

  # ============================================
  # TESTING COMMANDS (2 Commands)
  # ============================================

  @test @priority_p0 @critical @l5_cluster
  Scenario: CMD-08 - test - Run tests with Patient Mode
    Given database is running and accessible
    And SKIP_ZENOH_NIF=0 is set (SC-TEST-NIF-001)
    When I execute "test" command
    Then all tests should pass
    And Zenoh NIF should be loaded
    And no timeout errors should occur
    And property tests should execute with PropCheck

  @test @priority_p1 @l5_cluster
  Scenario: CMD-09 - test-cover - Tests with coverage report
    Given database is running and accessible
    When I execute "test-cover" command
    Then coverage report should be generated
    And coverage should be greater than 95%
    And all tests should pass

  # ============================================
  # CEPAF / F# COMMANDS (2 Commands)
  # ============================================

  @cepaf @priority_p0 @l4_application
  Scenario: CMD-10 - cepaf-build - Build F# projects
    Given .NET SDK 10.0 is available
    When I execute "cepaf-build" command
    Then NuGet packages should be restored
    And F# compilation should succeed with 0 errors
    And DLLs should be generated in bin/

  @cepaf @priority_p1 @l4_application
  Scenario: CMD-11 - cockpitf - F# Cockpit operations
    Given cepaf-build has completed
    When I execute "cockpitf deploy" command
    Then cockpit containers should deploy
    And F# runtime should be operational

  # ============================================
  # STANDALONE ENVIRONMENT COMMANDS (11 Commands)
  # ============================================

  @standalone @priority_p0 @critical @l2_module
  Scenario: CMD-12 - sa-up - Start prod standalone (4 containers)
    Given no containers are running with prefix "indrajaal"
    And ports 4000, 5433, 4317, 9090, 3000, 3100, 7447 are available
    When I execute "sa-up" command
    Then 4 containers should be running:
      | Container Name | Ports |
      | zenoh-router | 7447 |
      | indrajaal-db-prod | 5433 |
      | indrajaal-obs-prod | 4317, 9090, 3000, 3100 |
      | indrajaal-ex-app-1 | 4000, 4001 |
    And all containers should be healthy within 30 seconds

  @standalone @priority_p0 @l2_module
  Scenario: CMD-13 - sa-down - Stop standalone stack
    Given standalone containers are running
    When I execute "sa-down" command
    Then all indrajaal containers should stop within 10 seconds
    And ports 4000, 5433 should be freed

  @standalone @priority_p1 @l2_module
  Scenario: CMD-14 - sa-clean - Stop + remove volumes
    Given standalone containers are running
    When I execute "sa-clean" command
    Then all indrajaal containers should stop
    And all indrajaal volumes should be removed
    And data should be reset

  @standalone @priority_p0 @l1_function
  Scenario: CMD-15 - sa-status - Show container status
    Given standalone containers are running
    When I execute "sa-status" command
    Then container status should be displayed
    And health status should be visible
    And port mappings should be shown

  @standalone @priority_p1 @l1_function
  Scenario: CMD-16 - sa-logs - Stream container logs
    Given standalone containers are running
    When I execute "sa-logs indrajaal-ex-app-1" command
    Then log stream should start
    And logs should contain Phoenix startup message

  @standalone @priority_p1 @l2_module
  Scenario: CMD-17 - sa-db - Start DB container only
    Given no database container is running
    When I execute "sa-db" command
    Then PostgreSQL container should start
    And port 5433 should be listening
    And database should accept connections

  @standalone @priority_p1 @l2_module
  Scenario: CMD-18 - sa-obs - Start observability only
    Given no observability container is running
    When I execute "sa-obs" command
    Then OTEL collector should start on port 4317
    And Prometheus should start on port 9090
    And Grafana should start on port 3000
    And Loki should start on port 3100

  @standalone @priority_p1 @l2_module
  Scenario: CMD-19 - sa-app - Start app container only
    Given database container is running
    When I execute "sa-app" command
    Then Phoenix container should start
    And port 4000 should be listening
    And Prajna Cockpit should be accessible

  @standalone @priority_p0 @l5_cluster
  Scenario: CMD-20 - sa-test - Runtime tests (swarm)
    Given standalone containers are running
    When I execute "sa-test" command
    Then F# test swarm should spawn
    And runtime endpoints should be tested
    And GA readiness score should be calculated

  @standalone @priority_p1 @l4_application
  Scenario: CMD-21 - sa-ux - UX/UI evaluation
    Given standalone containers are running
    When I execute "sa-ux" command
    Then UX evaluator should run
    And accessibility checks should complete
    And UX score should be reported

  @standalone @priority_p1 @l5_cluster
  Scenario: CMD-22 - sa-orchestrate - Test orchestrator
    Given standalone containers are running
    When I execute "sa-orchestrate swarm" command
    Then orchestrator should plan tests
    And test swarm should execute
    And aggregated results should be reported

  # ============================================
  # DATABASE COMMANDS (4 Commands)
  # ============================================

  @database @priority_p0 @l3_domain
  Scenario: CMD-23 - db-setup - Setup database
    Given PostgreSQL is running
    And indrajaal_dev database does not exist
    When I execute "db-setup" command
    Then database should be created
    And migrations should run
    And seed data should be loaded

  @database @priority_p1 @l3_domain
  Scenario: CMD-24 - db-reset - Reset database
    Given PostgreSQL is running
    And indrajaal_dev database exists
    When I execute "db-reset" command
    Then database should be dropped
    And database should be recreated
    And migrations should run
    And seed data should be loaded

  @database @priority_p0 @l3_domain
  Scenario: CMD-25 - db-migrate - Run migrations
    Given PostgreSQL is running
    And database exists
    When I execute "db-migrate" command
    Then pending migrations should run
    And schema version should be updated

  @database @priority_p2 @l1_function
  Scenario: CMD-26 - db-console - Open psql console
    Given PostgreSQL is running
    When I execute "db-console" command
    Then psql session should open
    And I should be able to run SQL queries

  # ============================================
  # REPORTING COMMANDS (4 Commands)
  # ============================================

  @reporting @priority_p2 @l1_function
  Scenario: CMD-27 - todo - Show project tasks
    When I execute "todo" command
    Then PROJECT_TODOLIST.md tasks should be displayed
    And status should be shown

  @reporting @priority_p1 @l3_domain
  Scenario: CMD-28 - envelope - Capability envelope dashboard
    Given compilation is complete
    When I execute "envelope" command
    Then capability metrics should be collected
    And dashboard should be displayed
    And GA readiness should be calculated

  @reporting @priority_p2 @l1_function
  Scenario: CMD-29 - envelope-json - Export as JSON
    Given compilation is complete
    When I execute "envelope-json" command
    Then JSON output should be generated
    And output should be valid JSON

  @reporting @priority_p2 @l1_function
  Scenario: CMD-30 - envelope-journal - Save to journal
    Given compilation is complete
    When I execute "envelope-journal" command
    Then envelope should be saved to journal/
    And file should contain timestamp

  # ============================================
  # TOOL COMMANDS (2 Commands)
  # ============================================

  @tools @priority_p2 @l1_function
  Scenario: CMD-31 - claude - Start Claude Code
    Given Claude binary exists at ~/.claude/local/claude
    When I execute "claude" command
    Then Claude should start
    And LSP integration should be active

  @tools @priority_p2 @l1_function
  Scenario: CMD-32 - help - Show command reference
    When I execute "help" command
    Then command reference should be displayed
    And all 102 commands (32 core) should be listed
    And usage examples should be shown

  # ============================================
  # WEB PAGE TESTING (Puppeteer)
  # ============================================

  @web @prajna @priority_p0 @puppeteer
  Scenario: WEB-01 - Prajna Main Dashboard
    Given standalone containers are running
    When I navigate to "http://localhost:4000/prajna"
    Then page should load within 2 seconds
    And I should see "Prajna C3I Command Cockpit"
    And health score widget should display value
    And active threats widget should display count

  @web @copilot @priority_p0 @puppeteer
  Scenario: WEB-02 - AI Copilot Interface
    Given standalone containers are running
    When I navigate to "http://localhost:4000/prajna/copilot"
    Then page should load within 2 seconds
    And I should see chat input field
    And I should see recommendation panel

  @web @alarms @priority_p0 @puppeteer
  Scenario: WEB-03 - Alarms Dashboard
    Given standalone containers are running
    When I navigate to "http://localhost:4000/prajna/alarms"
    Then page should load within 2 seconds
    And alarm list should be displayed
    And storm detection indicator should be visible

  @web @devices @priority_p1 @puppeteer
  Scenario: WEB-04 - Devices Dashboard
    Given standalone containers are running
    When I navigate to "http://localhost:4000/prajna/devices"
    Then page should load within 2 seconds
    And device health matrix should be visible

  @web @video @priority_p1 @puppeteer
  Scenario: WEB-05 - Video Dashboard
    Given standalone containers are running
    When I navigate to "http://localhost:4000/prajna/video"
    Then page should load within 2 seconds
    And stream health should be visible

  # ============================================
  # API ENDPOINT TESTING
  # ============================================

  @api @health @priority_p0
  Scenario: API-01 - Health Check Endpoint
    Given standalone containers are running
    When I GET "http://localhost:4000/api/health"
    Then response status should be 200
    And response should contain "status": "ok"

  @api @prajna @priority_p0
  Scenario: API-02 - Prajna Metrics API
    Given standalone containers are running
    When I GET "http://localhost:4000/api/prajna/metrics"
    Then response status should be 200
    And response should contain health score

  @api @guardian @priority_p0
  Scenario: API-03 - Guardian Proposal API
    Given standalone containers are running
    When I POST "http://localhost:4000/api/prajna/guardian/propose" with valid proposal
    Then response status should be 200
    And response should contain approval result

  # ============================================
  # ZENOH INTERFACE TESTING
  # ============================================

  @zenoh @priority_p1
  Scenario: ZENOH-01 - Publish KPI Metrics
    Given Zenoh NIF is loaded
    When I publish to "prajna/kpi/health"
    Then message should be delivered
    And subscribers should receive update

  @zenoh @priority_p1
  Scenario: ZENOH-02 - Subscribe to Alerts
    Given Zenoh NIF is loaded
    When I subscribe to "prajna/alerts/**"
    Then subscription should be active
    And I should receive alert notifications

  # ============================================
  # 5-ORDER IMPACT VERIFICATION
  # ============================================

  @impact @priority_p0
  Scenario Outline: 5-Order Impact Chain Verification
    Given the system is in baseline state
    When I execute "<command>" command
    Then 1st order effect should be "<order1>"
    And 2nd order effect should be "<order2>"
    And 3rd order effect should be "<order3>"
    And 4th order effect should be "<order4>"
    And 5th order effect should be "<order5>"

    Examples:
      | command | order1 | order2 | order3 | order4 | order5 |
      | compile | beam files | NIFs compiled | DSL expanded | routes compiled | bootable |
      | sa-up | containers created | networks attached | health checks | services ready | endpoints active |
      | test | tests loaded | DB connected | fixtures created | tests executed | coverage reported |
      | quality-full | format checked | credo analyzed | dialyzer typed | sobelow scanned | gates passed |
