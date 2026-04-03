@prajna @l5_bdd @git_intelligence
Feature: Git Intelligence Analysis
  As a developer or system operator using the Prajna C3I cockpit
  I want to view git activity, commit analysis, branch status, and developer metrics
  So that I can understand code evolution, detect anomalies, and guide development priorities

  # STAMP: SC-GIT-006, SC-SMRITI-140, SC-SMRITI-141, SC-HMI-010, SC-HMI-011
  # AOR: AOR-CTX-001, AOR-VER-001
  # Layer: L2 (Module), L3 (Domain), L4 (System)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/git-intelligence"
    And the git intelligence LiveView is connected via WebSocket
    And the git repository is accessible

  # ----------------------------------------------------------
  # Happy Path: Git Dashboard Display
  # ----------------------------------------------------------

  @critical @sc_git_006 @smoke
  Scenario: Git intelligence dashboard renders commit activity
    Given the git repository has recent commit history
    When the git intelligence page loads
    Then I should see the commit activity timeline
    And I should see the top contributors list
    And I should see the active branches panel
    And commit counts per day should be visualized as a bar chart
    And the page should load within 2000ms

  @critical @sc_smriti_141
  Scenario: Commit feed updates in real-time via Zenoh telemetry
    Given I am viewing the git intelligence dashboard
    And the repository has 42 commits in the last 7 days
    When a new commit is pushed and the Zenoh event "indrajaal/git/commit" arrives
    Then the commit feed should add the new entry at the top without page reload
    And the commit count for today should increment by one
    And the new commit should be highlighted briefly to draw attention

  # ----------------------------------------------------------
  # Commit Analysis
  # ----------------------------------------------------------

  @high @sc_smriti_140
  Scenario: View detailed commit analysis with STAMP constraint references
    Given there is a commit with hash "abc1234" in the repository
    When I click on commit "abc1234" in the commit list
    Then the commit detail panel should expand
    And I should see the full commit message with ICP v2.0 type/scope parsed
    And I should see the list of files changed with additions and deletions
    And I should see any STAMP constraint IDs referenced in the commit message
    And I should see the author, timestamp, and branch name

  @high
  Scenario Outline: Filter commits by ICP commit type
    Given the repository has commits of multiple types
    When I filter the commit list by type "<type>"
    Then only commits of type "<type>" should appear
    And the commit count badge should update to reflect the filter

    Examples:
      | type     |
      | feat     |
      | fix      |
      | refactor |
      | docs     |
      | evolve   |

  @high @sc_hmi_010
  Scenario: Commit health score reflected with chromatic indicators
    Given the repository has commits with varying quality scores
    When the commit list renders
    Then commits with quality score above 90 should have a green badge
    And commits with score 60-90 should have an amber badge
    And commits with score below 60 should have a red badge
    And hovering a badge should show the quality breakdown

  # ----------------------------------------------------------
  # Branch Management View
  # ----------------------------------------------------------

  @high @sc_git_006
  Scenario: Active branch list shows divergence from main
    Given the repository has 5 active feature branches
    When I view the branches panel
    Then each branch should show commits ahead and behind main
    And stale branches (no activity in 14+ days) should be highlighted in amber
    And the branch with the most divergence should appear at the top
    And merge risk scores should be visible for each branch

  @critical @sc_git_006
  Scenario: Multiverse branch promotion requires Guardian approval notification
    Given there is a multiverse branch "multiverse/feature-xyz" ready for promotion
    When I click "Promote to Main" on the multiverse branch
    Then a Guardian approval required notice should appear
    And the notice should reference SC-GIT-006
    And the promotion should be submitted as a Guardian proposal
    And the branch should remain in pending state until Guardian approves

  # ----------------------------------------------------------
  # Developer Metrics
  # ----------------------------------------------------------

  @medium
  Scenario: Developer contribution heatmap renders 90-day activity
    Given the repository has activity from multiple contributors
    When I view the contributor heatmap tab
    Then each developer should have a 90-day activity grid
    And active days should render in shades from teal (low) to red (high)
    And hovering a cell should show commit count and primary types for that day

  @medium
  Scenario: Constraint evolution timeline shows SC-* reference trend
    Given the repository history includes commits with STAMP references
    When I view the "Constraint Evolution" timeline
    Then the chart should plot SC-* reference count per week
    And the overall trend line should show constraint coverage direction
    And clicking a data point should show the commits from that week

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: Empty repository shows onboarding state
    Given the git intelligence module has no repository data yet
    When I view the git intelligence page
    Then I should see an "Initializing Git Intelligence" message
    And a progress indicator should show the indexing status
    And no chart or table should crash or show errors

  @medium
  Scenario: Commit with very long message renders without overflow
    Given there is a commit with a message exceeding 500 characters
    When the commit appears in the commit list
    Then the message should be truncated to the first 120 characters
    And a "Read more" toggle should expand the full message
    And the row height should remain consistent with other rows
