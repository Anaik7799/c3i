# Unified Checkpoint Registry (UCR) - 4-Phase State Capture & Recovery
# STAMP: SC-UCR-001 through SC-UCR-015 (Checkpoint constraints)
# AOR: AOR-UCR-001 through AOR-UCR-010 (Checkpoint operating rules)
# Author: Cybernetic Architect (CLAUDE Opus 4.5)
# Date: 2026-01-09
# Sprint: 32 (UCR)
# Priority: P0 (Infrastructure Critical - SIL-6)

@unified_checkpoint_registry @SC-UCR @SIL6 @critical
Feature: Unified Checkpoint Registry - 4-Phase State Capture & 8-Level Verification
  As the SIL-6 Biomorphic Fractal Mesh state management system
  I must capture all distributed state across 7 locations using 4 phases
  So that the system can restore to any verified state point
  And constitutional invariants (Ψ₀-Ψ₅) are preserved through all checkpoints
  And the 8-level fractal hash tree provides hierarchical verification

  Background:
    Given the UCR system is initialized
    And the checkpoint directory exists at "data/checkpoints/"
    And the KMS directory exists at "data/kms/" with 5 SQLite databases
    And the archive format is gzip-compressed tar
    And the protocol version is "21.2.0"
    And the FPPS 5-method consensus is active


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 1: PHASE 1 - FILE/KMS/GIT CHECKPOINT (SC-UCR-001, SC-UCR-002)
  # ══════════════════════════════════════════════════════════════════════════════════

  @phase1 @SC-UCR-001 @critical @AOR-UCR-001
  Scenario: Phase 1 captures file system artifacts
    Given Phase 1 checkpoint is initiated
    When the file system state is captured
    Then the following directories should be archived:
      | Directory | Purpose |
      | lib/ | Elixir source code |
      | config/ | Configuration files |
      | scripts/ | F# and Elixir scripts |
      | native/ | Rust NIF source |
      | priv/static/ | Static assets |
    And SHA-256 hashes should be computed for all files
    And the manifest should record file count and total size

  @phase1 @SC-UCR-012 @critical @AOR-UCR-008
  Scenario: Phase 1 captures KMS database state
    Given Phase 1 checkpoint is initiated
    And KMS directory contains 5 SQLite databases:
      | Database | Size |
      | main.db | ~12 MB |
      | sources.db | ~3 MB |
      | search.db | ~5 MB |
      | cache.db | ~3 MB |
      | metadata.db | ~2 MB |
    When the KMS state is captured
    Then all 5 database files should be copied to checkpoint archive
    And SHA-256 hashes should be generated for each database
    And FPPS 5-method consensus should verify integrity

  @phase1 @SC-UCR-002 @critical @AOR-UCR-001
  Scenario: Phase 1 captures Git repository state
    Given Phase 1 checkpoint is initiated
    And git repository is at commit "HEAD"
    When the Git state is captured
    Then the checkpoint manifest should contain:
      | Field | Description |
      | branch | Current branch name |
      | commit_hash | HEAD commit SHA |
      | remote_url | Origin remote URL |
      | status | Working tree status |
    And the .git directory should NOT be archived (excluded)
    And staged and unstaged changes should be recorded

  @phase1 @SC-UCR-007 @high @AOR-UCR-009
  Scenario: Phase 1 FPPS consensus verification
    Given Phase 1 checkpoint has completed
    When FPPS 5-method consensus is computed
    Then all 5 methods should agree:
      | Method | Description |
      | Pattern | File pattern matching |
      | AST | Abstract syntax tree analysis |
      | Statistical | Statistical content analysis |
      | Binary | Binary hash comparison |
      | LineByLine | Line-by-line comparison |
    And disagreement should trigger verification failure
    And consensus hash should be included in manifest


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 2: PHASE 2 - CRIU CONTAINER CHECKPOINT (SC-UCR-003)
  # ══════════════════════════════════════════════════════════════════════════════════

  @phase2 @SC-UCR-003 @high @AOR-UCR-002
  Scenario: Phase 2 requires all containers healthy
    Given Phase 2 checkpoint is initiated
    And the container status is:
      | Container | Status |
      | indrajaal-db-prod | healthy |
      | indrajaal-obs-prod | healthy |
      | indrajaal-ex-app-1 | healthy |
    When container health is verified
    Then Phase 2 should proceed with CRIU checkpoint
    And all 3 containers should be checkpointed

  @phase2 @SC-UCR-003 @high @AOR-UCR-002
  Scenario: Phase 2 skips when infrastructure offline
    Given Phase 2 checkpoint is initiated
    And the container status is:
      | Container | Status |
      | indrajaal-db-prod | not_running |
      | indrajaal-obs-prod | not_running |
      | indrajaal-ex-app-1 | not_running |
    When container health is verified
    Then Phase 2 should be SKIPPED (not failed)
    And the checkpoint manifest should record:
      | Field | Value |
      | phase2_status | skipped |
      | skip_reason | infrastructure_offline |
    And Phase 3 should still proceed

  @phase2 @SC-UCR-003 @high
  Scenario: Phase 2 captures container images and volumes
    Given Phase 2 checkpoint proceeds (healthy containers)
    When CRIU checkpoint is performed
    Then the following should be captured:
      | Type | Description |
      | Memory | Container memory state via CRIU |
      | Images | Container image hashes |
      | Volumes | Volume data snapshots |
      | Network | Network configuration |
    And the reconstruction manifest should enable restore


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 3: PHASE 3 - CHANDY-LAMPORT DISTRIBUTED SNAPSHOT (SC-UCR-004)
  # ══════════════════════════════════════════════════════════════════════════════════

  @phase3 @SC-UCR-004 @high @AOR-UCR-003
  Scenario: Phase 3 captures Zenoh mesh state
    Given Phase 3 checkpoint is initiated
    And Zenoh mesh has 3 active nodes
    When Chandy-Lamport algorithm executes
    Then vector clocks should be captured for all nodes
    And in-flight messages should be recorded
    And the consistent cut should be verified

  @phase3 @SC-UCR-013 @high @AOR-UCR-003
  Scenario: Phase 3 captures with vector clocks
    Given Phase 3 is capturing Zenoh state
    When vector clocks are synchronized
    Then the checkpoint should include:
      | Field | Description |
      | node_id | Each node's identifier |
      | vector_clock | Lamport timestamp vector |
      | channel_state | Messages in transit |
    And causal consistency should be verified
    And the distributed state manifest should be generated

  @phase3 @SC-UCR-014 @high
  Scenario: Phase 3 captures DuckDB analytics
    Given Phase 3 checkpoint includes DuckDB
    And DuckDB history is append-only
    When analytics state is captured
    Then the checkpoint should include DuckDB files
    And the last sequence number should be recorded
    And restoration should resume from sequence number

  @phase3 @SC-UCR-004 @high @AOR-UCR-003
  Scenario: Phase 3 skips when Zenoh offline
    Given Phase 3 checkpoint is initiated
    And Zenoh mesh is NOT running
    When Zenoh connectivity is checked
    Then Phase 3 should capture MINIMAL state
    And the manifest should record mesh_offline: true
    And environment variables should still be captured


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 4: PHASE 4 - MULTIVERSE VERIFICATION (SC-UCR-005, SC-UCR-006)
  # ══════════════════════════════════════════════════════════════════════════════════

  @phase4 @SC-UCR-005 @critical @AOR-UCR-004
  Scenario: Phase 4 runs 46-test verification suite
    Given Phase 4 verification is initiated
    And Phases 1-3 have completed
    When the 46-test suite executes
    Then the expected results are:
      | Category | Total | Pass | Skip | Fail |
      | Phase1 Tests | 14 | 14 | 0 | 0 |
      | Phase2 Tests | 10 | 6 | 4 | 0 |
      | Phase3 Tests | 10 | 8 | 2 | 0 |
      | Phase4 Tests | 12 | 12 | 0 | 0 |
    And 40 tests should PASS
    And 6 tests should be SAFETY SKIPPED
    And 0 tests should FAIL

  @phase4 @SC-UCR-005 @critical
  Scenario: Phase 4 builds 8-level fractal hash tree
    Given Phase 4 verification proceeds
    When the 8-level hash tree is computed
    Then the tree should have levels:
      | Level | Name | Description |
      | L1 | Function | Individual file/artifact hashes |
      | L2 | Component | Module-level hash aggregations |
      | L3 | Holon | Domain-level hash aggregations |
      | L4 | Container | Container state hashes |
      | L5 | Node | Node-level aggregations |
      | L6 | Cluster | Cluster state hash |
      | L7 | Federation | Federation hash |
      | L8 | Constitutional | Constitutional root hash |
    And each level should aggregate child hashes
    And L8 should be the Merkle root

  @phase4 @SC-UCR-006 @critical @AOR-UCR-005
  Scenario: Phase 4 verifies constitutional invariants
    Given Phase 4 constitutional verification runs
    When invariants Ψ₀-Ψ₅ are checked
    Then all invariants must PASS:
      | Invariant | Name | Verification |
      | Ψ₀ | Existence | Checkpoint data exists |
      | Ψ₁ | Regenerative | State can regenerate |
      | Ψ₂ | Continuity | Hash chain unbroken |
      | Ψ₃ | Verification | Integrity verifiable |
      | Ψ₄ | Human Alignment | Founder's Directive intact |
      | Ψ₅ | Truthfulness | No tampering detected |
    And failure of ANY invariant BLOCKS restore

  @phase4 @SC-UCR-007 @critical @AOR-UCR-009
  Scenario: Phase 4 FPPS 5-method verification
    Given Phase 4 FPPS verification runs
    When all 5 methods are applied
    Then consensus requires ALL methods to agree:
      | Method | Input | Output |
      | Pattern | Archive files | Pattern match score |
      | AST | Source files | Structural hash |
      | Statistical | Content bytes | Statistical signature |
      | Binary | Archive bytes | Binary checksum |
      | LineByLine | Text files | Line-level hash |
    And disagreement triggers VERIFICATION_FAILED
    And the consensus score should be recorded


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 5: CHECKPOINT MANIFEST (SC-UCR-008)
  # ══════════════════════════════════════════════════════════════════════════════════

  @manifest @SC-UCR-008 @high
  Scenario: Checkpoint manifest contains required fields
    Given a checkpoint has completed all phases
    When the manifest JSON is generated
    Then it should contain:
      | Field | Type | Description |
      | version | string | Protocol version (21.2.0) |
      | timestamp | ISO8601 | Creation timestamp |
      | phase_results | object | Results for all 4 phases |
      | l8_hash | string | Constitutional root hash |
      | fpps_consensus | object | 5-method consensus results |
      | files | array | List of archived files with hashes |
      | size_bytes | integer | Total archive size |
    And the manifest should be signed (Ed25519)

  @manifest @SC-UCR-008 @high
  Scenario: Manifest includes 8-level hash tree
    Given a checkpoint manifest is generated
    Then the manifest should include the complete hash tree:
      | Field | Content |
      | l1_hashes | Array of function-level hashes |
      | l2_hashes | Array of component-level hashes |
      | l3_hashes | Array of holon-level hashes |
      | l4_hashes | Array of container-level hashes |
      | l5_hash | Node aggregation hash |
      | l6_hash | Cluster aggregation hash |
      | l7_hash | Federation hash |
      | l8_hash | Constitutional root hash |
    And verification should use Merkle proof path


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 6: RESTORE OPERATIONS (SC-UCR-010, SC-UCR-015)
  # ══════════════════════════════════════════════════════════════════════════════════

  @restore @SC-UCR-010 @critical
  Scenario: Restore time must be under 5 minutes
    Given a valid checkpoint archive exists
    And the archive is 50 MB in size
    When a full restore is initiated
    Then the restore should complete in < 5 minutes
    And all 7 state locations should be restored:
      | Location | Status |
      | File System | restored |
      | KMS SQLite | restored |
      | Git State | verified |
      | Container Images | restored |
      | Container Volumes | restored |
      | Zenoh Mesh | restored |
      | DuckDB Analytics | restored |
    And the system should be operational

  @restore @SC-UCR-015 @critical
  Scenario: Restore requires rollback path
    Given a restore operation is initiated
    When the pre-restore backup is created
    Then a rollback checkpoint should exist
    And if restore fails, rollback should be available
    And rollback should restore to pre-restore state

  @restore @SC-UCR-005 @critical @AOR-UCR-005
  Scenario: Restore requires constitutional verification
    Given a checkpoint archive is selected for restore
    When constitutional verification runs before restore
    Then L8 hash must match stored value
    And Ψ₀-Ψ₅ invariants must pass
    And only VERIFIED checkpoints can be restored


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 7: SHADOW UNIVERSE (SC-UCR-011)
  # ══════════════════════════════════════════════════════════════════════════════════

  @shadow @SC-UCR-011 @critical @AOR-UCR-007
  Scenario: Shadow universe fork requires Guardian approval
    Given a shadow universe fork is requested
    When the request is submitted to Guardian
    Then Guardian MUST approve the fork
    And the approval should be logged to audit trail
    And the shadow should be isolated from production

  @shadow @SC-UCR-011 @critical @AOR-UCR-007
  Scenario: Shadow universe fork creates isolated copy
    Given Guardian has approved shadow fork
    When the fork operation executes
    Then a complete isolated copy should be created
    And the shadow should have separate:
      | Resource | Isolation |
      | Network | Separate subnet |
      | Volumes | Copy-on-write |
      | Database | Snapshot clone |
    And changes in shadow should NOT affect production


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 8: ARCHIVE INTEGRITY (SC-UCR-009)
  # ══════════════════════════════════════════════════════════════════════════════════

  @integrity @SC-UCR-009 @high @AOR-UCR-006
  Scenario: Archive integrity valid for 1 hour
    Given a checkpoint archive was created
    And the archive age is 45 minutes
    When archive integrity is checked
    Then the archive should be VALID
    And the integrity_status should be "fresh"

  @integrity @SC-UCR-009 @high @AOR-UCR-006
  Scenario: Archive older than 1 hour triggers regeneration
    Given a checkpoint archive was created
    And the archive age is 75 minutes (> 1 hour)
    When archive integrity is checked
    Then the archive should be STALE
    And a new checkpoint should be recommended
    And the manifest should record stale_warning: true


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 9: 7 STATE LOCATIONS (SC-UCR-012)
  # ══════════════════════════════════════════════════════════════════════════════════

  @locations @SC-UCR-012 @critical @AOR-UCR-008
  Scenario: All 7 distributed state locations captured
    Given a full checkpoint (all phases) completes
    Then all 7 state locations should be captured:
      | Location | Phase | Capture Method |
      | File System | Phase 1 | Directory traversal + SHA-256 |
      | KMS SQLite | Phase 1 | Database file copy |
      | Git State | Phase 1 | Git metadata extraction |
      | Container Images | Phase 2 | CRIU + image hashes |
      | Container Volumes | Phase 2 | Volume snapshot |
      | Zenoh Mesh | Phase 3 | Chandy-Lamport + vector clocks |
      | DuckDB Analytics | Phase 3 | Append-only snapshot |
    And missing ANY location should fail the checkpoint


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 10: DEVENV COMMANDS (OPERATIONS)
  # ══════════════════════════════════════════════════════════════════════════════════

  @devenv @operations @high
  Scenario: sa-checkpoint creates checkpoint
    Given devenv shell is active
    When "sa-checkpoint full" is executed
    Then Phase 1 should complete
    And Phase 2 should complete (or skip if offline)
    And Phase 3 should complete (or minimal if offline)
    And Phase 4 verification should run
    And a checkpoint archive should be created in "data/checkpoints/"

  @devenv @operations @high
  Scenario: sa-checkpoint-verify runs test suite
    Given devenv shell is active
    And a checkpoint exists
    When "sa-checkpoint-verify" is executed
    Then the 46-test verification suite should run
    And results should be displayed:
      | Result | Count |
      | Pass | 40 |
      | Skip | 6 |
      | Fail | 0 |

  @devenv @operations @high
  Scenario: sa-checkpoint-list shows available checkpoints
    Given devenv shell is active
    And multiple checkpoints exist
    When "sa-checkpoint-list" is executed
    Then all checkpoints should be listed with:
      | Field | Description |
      | Timestamp | Creation time |
      | Size | Archive size |
      | L8 Hash | Constitutional hash (truncated) |
      | Status | valid/stale |

  @devenv @operations @high
  Scenario: sa-checkpoint-restore restores from archive
    Given devenv shell is active
    And a valid checkpoint archive exists
    When "sa-checkpoint-restore [archive]" is executed
    Then constitutional verification should run first
    And the restore should proceed if verified
    And all 7 state locations should be restored
