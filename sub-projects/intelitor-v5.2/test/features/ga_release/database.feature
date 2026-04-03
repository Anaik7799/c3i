# BDD Feature: Database Management Scenarios
# GA Release v21.2.1-SIL6 - Runtime Command Verification
# STAMP: SC-CMD-021 to SC-CMD-024, SC-DB-*, SC-MIG-*

@ga-release @database @critical
Feature: Database Management Commands
  As an operator
  I want reliable database management commands
  So that I can manage the PostgreSQL database lifecycle

  Background:
    Given the development environment is initialized via "devenv shell"
    And PostgreSQL is running on port 5433

  # SC-DB-001: Fresh Database Setup
  @sc-cmd-021 @setup
  Scenario: Setup fresh database
    Given the database "indrajaal_dev" does not exist
    When I execute "db-setup"
    Then the database should be created
    And migrations should be applied
    And seeds should be loaded if present
    And the setup should complete without errors

  # SC-DB-002: Database Reset
  @sc-cmd-022 @reset @destructive
  Scenario: Reset database to clean state
    Given the database "indrajaal_dev" exists with data
    When I execute "db-reset"
    Then the database should be dropped
    And the database should be recreated
    And all migrations should be reapplied
    And the database should be in a clean state

  # SC-DB-003: Run Migrations
  @sc-cmd-023 @migrations @sc-mig-001
  Scenario: Apply pending migrations
    Given the database exists
    And there are pending migrations
    When I execute "db-migrate"
    Then all pending migrations should be applied
    And the schema version should be updated
    And no migration conflicts should occur

  # SC-DB-004: Database Console Access
  @sc-cmd-024 @console @debugging
  Scenario: Open database console
    Given PostgreSQL is running on port 5433
    When I execute "db-console"
    Then I should have a psql prompt
    And I should be connected to "indrajaal_dev"
    And I should be authenticated as "postgres"

  # SC-MIG-002: Migration Preflight
  @migrations @validation
  Scenario: Validate migration before apply
    Given pending migrations exist
    When I run migration preflight check
    Then migration syntax should be valid
    And no destructive operations should be unmarked
    And rollback path should be defined

  # FMEA: Connection Refused Recovery
  @fmea @recovery
  Scenario: Recover from database connection refused
    Given PostgreSQL is not running
    When I execute "db-setup"
    Then the command should fail with connection error
    And the error message should indicate "connection refused"
    When I start PostgreSQL via "sa-db"
    And I retry "db-setup"
    Then the setup should succeed

  # FMEA: Active Connection Blocking
  @fmea @recovery
  Scenario: Handle active connections during reset
    Given the database has active connections
    When I execute "db-reset"
    Then the command should handle connection termination gracefully
    Or provide clear instructions to close connections
