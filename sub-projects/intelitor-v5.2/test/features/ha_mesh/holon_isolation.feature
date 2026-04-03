@ha_mesh @sil6 @holon @duckdb
Feature: Per-Node Holon Data Isolation
  As a system architect
  I want each app node to have isolated DuckDB storage
  So that there are no lock conflicts between nodes

  Background:
    Given HOLON_DATA_PATH is set to /app/data/holons for each node
    And each node has its own ha_appN_data volume
    And DuckDB files are stored at $HOLON_DATA_PATH/prajna_register.duckdb

  @P0 @lock_isolation
  Scenario: Concurrent DuckDB access without conflicts
    Given app-1 is writing to its prajna_register.duckdb
    And app-2 is writing to its prajna_register.duckdb
    When app-3 attempts to write to its prajna_register.duckdb
    Then all 3 writes should succeed within 100ms
    And no lock conflicts should occur
    And each node should have independent data

  @P0 @restart_isolation
  Scenario: Node restart with isolated data
    Given app-2 crashes while holding a DuckDB connection
    When app-2 restarts
    Then app-2 should open its own DuckDB file
    And app-1 and app-3 should be unaffected
    And app-2 should recover its state from its own DuckDB

  @P1 @volume_separation
  Scenario: Volume paths are correctly isolated
    Given all 3 apps are running
    When checking the holon data paths
    Then app-1 should use ha_app1_data:/app/data
    And app-2 should use ha_app2_data:/app/data
    And app-3 should use ha_app3_data:/app/data
    And no two apps should share the same volume

  @P1 @state_sovereignty
  Scenario: Holon state sovereignty per node
    Given app-1 writes state S1 to its register
    And app-2 writes state S2 to its register
    When app-3 queries its register
    Then app-3 should only see its own state
    And app-3 should not see S1 or S2
    And state isolation should be verified

  @P2 @backup_independence
  Scenario: Independent backup and restore
    Given a backup is taken of app-1's holon data
    When app-1 is restored from backup
    Then app-2 and app-3 should be unaffected
    And app-1 should have restored state
    And the cluster should remain healthy
