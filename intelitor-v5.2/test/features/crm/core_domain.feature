Feature: CRM Core Domain (WS5)
  As a sales professional
  I want to manage leads, accounts, contacts, and opportunities
  So that I can track and close deals effectively

  Background:
    Given a tenant "acme_corp" exists
    And a user "sales_rep" with email "sales@acme.com" exists in tenant "acme_corp"
    And the user "sales_rep" is authenticated

  #############################################################################
  # Lead Management Scenarios (3)
  #############################################################################

  @lead_management @scoring
  Scenario: Create lead with automatic scoring
    Given the following lead scoring rules exist:
      | criterion        | operator | value           | score |
      | company_size     | gte      | 100             | 25    |
      | industry         | eq       | Technology      | 20    |
      | budget_authority | eq       | true            | 30    |
      | annual_revenue   | gte      | 1000000         | 25    |
    When I create a lead with the following attributes:
      | first_name       | John                    |
      | last_name        | Smith                   |
      | email            | john.smith@techcorp.com |
      | company          | TechCorp Inc            |
      | title            | VP of Engineering       |
      | phone            | +1-555-0100             |
      | company_size     | 250                     |
      | industry         | Technology              |
      | annual_revenue   | 5000000                 |
      | budget_authority | true                    |
      | source           | Website                 |
    Then the lead should be created successfully
    And the lead score should be 100
    And the lead status should be "New"
    And the lead owner should be "sales_rep"
    And the lead should be in tenant "acme_corp"

  @lead_management @conversion
  Scenario: Convert qualified lead to account, contact, and opportunity
    Given a lead exists with the following attributes:
      | first_name     | Jane                     |
      | last_name      | Doe                      |
      | email          | jane.doe@enterprise.com  |
      | company        | Enterprise Solutions Ltd |
      | title          | CTO                      |
      | phone          | +1-555-0200              |
      | industry       | Software                 |
      | annual_revenue | 10000000                 |
      | status         | Qualified                |
      | score          | 85                       |
    When I convert the lead with the following conversion options:
      | create_account     | true                    |
      | create_contact     | true                    |
      | create_opportunity | true                    |
      | opportunity_name   | Enterprise Solutions Q1 |
      | opportunity_amount | 250000                  |
      | opportunity_stage  | Qualification           |
      | close_date         | 2026-03-31              |
    Then the lead status should be "Converted"
    And a new account should be created with:
      | name     | Enterprise Solutions Ltd |
      | industry | Software                 |
      | revenue  | 10000000                 |
    And a new contact should be created with:
      | first_name    | Jane                    |
      | last_name     | Doe                     |
      | email         | jane.doe@enterprise.com |
      | title         | CTO                     |
      | account_name  | Enterprise Solutions Ltd |
    And a new opportunity should be created with:
      | name          | Enterprise Solutions Q1 |
      | amount        | 250000                  |
      | stage         | Qualification           |
      | close_date    | 2026-03-31              |
      | account_name  | Enterprise Solutions Ltd |
      | contact_name  | Jane Doe                |
    And all created records should be in tenant "acme_corp"

  @lead_management @assignment
  Scenario: Lead assignment using round-robin
    Given the following sales reps exist in tenant "acme_corp":
      | name       | email              | team      | active | last_assignment |
      | Alice Rep  | alice@acme.com     | Sales A   | true   | 2026-01-10 10:00:00 |
      | Bob Rep    | bob@acme.com       | Sales A   | true   | 2026-01-10 09:00:00 |
      | Carol Rep  | carol@acme.com     | Sales A   | true   | 2026-01-10 11:00:00 |
      | Dave Rep   | dave@acme.com      | Sales B   | false  | 2026-01-10 08:00:00 |
    And the lead assignment rule is "round_robin" for team "Sales A"
    When I create the following leads:
      | first_name | last_name | email                | company    | team    |
      | Lead       | One       | lead1@test.com       | Test Co 1  | Sales A |
      | Lead       | Two       | lead2@test.com       | Test Co 2  | Sales A |
      | Lead       | Three     | lead3@test.com       | Test Co 3  | Sales A |
    Then the leads should be assigned as follows:
      | lead_email         | assigned_to |
      | lead1@test.com     | Bob Rep     |
      | lead2@test.com     | Alice Rep   |
      | lead3@test.com     | Bob Rep     |
    And the assignment should exclude inactive reps
    And the assignment should only include reps from team "Sales A"

  #############################################################################
  # Account Management Scenarios (3)
  #############################################################################

  @account_management @hierarchy
  Scenario: Create account with parent-child hierarchy
    Given a parent account exists with the following attributes:
      | name            | GlobalCorp International |
      | industry        | Conglomerate             |
      | annual_revenue  | 100000000                |
      | number_of_employees | 5000                 |
      | account_type    | Enterprise               |
      | billing_country | United States            |
    When I create a child account with the following attributes:
      | name                | GlobalCorp EMEA         |
      | industry            | Conglomerate            |
      | annual_revenue      | 25000000                |
      | number_of_employees | 1200                    |
      | account_type        | Enterprise              |
      | billing_country     | United Kingdom          |
      | parent_account      | GlobalCorp International |
    Then the child account should be created successfully
    And the child account parent should be "GlobalCorp International"
    And the parent account should have 1 child account
    And the account hierarchy should be:
      | level | account_name             |
      | 0     | GlobalCorp International |
      | 1     | GlobalCorp EMEA          |
    And both accounts should be in tenant "acme_corp"

  @account_management @team
  Scenario: Assign team members to account with roles
    Given an account "TechStart Inc" exists in tenant "acme_corp"
    And the following users exist:
      | name          | email                | role               |
      | Sarah Manager | sarah@acme.com       | Account Manager    |
      | Tom Engineer  | tom@acme.com         | Solution Engineer  |
      | Lisa Exec     | lisa@acme.com        | Executive Sponsor  |
    When I assign the following team members to account "TechStart Inc":
      | user_name     | account_role       | access_level | primary |
      | Sarah Manager | Account Manager    | Read/Write   | true    |
      | Tom Engineer  | Solution Engineer  | Read/Write   | false   |
      | Lisa Exec     | Executive Sponsor  | Read         | false   |
    Then the account "TechStart Inc" should have 3 team members
    And "Sarah Manager" should be the primary account owner
    And "Sarah Manager" should have "Read/Write" access
    And "Tom Engineer" should have "Read/Write" access
    And "Lisa Exec" should have "Read" access
    And all team members should be notified of their assignment

  @account_management @territory
  Scenario: Assign account to sales territory
    Given the following territories exist:
      | name          | region    | country        | state      | active |
      | West Coast    | Americas  | United States  | California | true   |
      | East Coast    | Americas  | United States  | New York   | true   |
      | EMEA North    | EMEA      | United Kingdom | null       | true   |
      | APAC South    | APAC      | Australia      | null       | false  |
    And the following accounts exist:
      | name            | billing_country | billing_state |
      | SF Startup      | United States   | California    |
      | NYC Enterprise  | United States   | New York      |
      | London Corp     | United Kingdom  | null          |
    When I assign territories based on billing address
    Then the accounts should be assigned to territories as follows:
      | account_name    | territory_name |
      | SF Startup      | West Coast     |
      | NYC Enterprise  | East Coast     |
      | London Corp     | EMEA North     |
    And the assignment should exclude inactive territories
    And each account should have exactly one territory

  #############################################################################
  # Contact Management Scenarios (3)
  #############################################################################

  @contact_management @creation
  Scenario: Create contact linked to account
    Given an account "InnovateCo" exists with the following attributes:
      | industry        | Technology      |
      | annual_revenue  | 5000000         |
      | account_type    | Customer        |
    When I create a contact with the following attributes:
      | first_name      | Michael               |
      | last_name       | Chen                  |
      | email           | michael.chen@innovate.co |
      | title           | Director of IT        |
      | phone           | +1-555-0300           |
      | mobile          | +1-555-0301           |
      | department      | Information Technology |
      | reports_to      | null                  |
      | assistant_name  | Jenny Smith           |
      | assistant_phone | +1-555-0302           |
      | account_name    | InnovateCo            |
    Then the contact should be created successfully
    And the contact should be linked to account "InnovateCo"
    And the contact should be in tenant "acme_corp"
    And the account "InnovateCo" should have 1 contact

  @contact_management @opportunity_role
  Scenario: Assign contact role on opportunity
    Given an account "BigDeal Corp" exists
    And the following contacts exist for account "BigDeal Corp":
      | first_name | last_name | email                 | title                |
      | Emma       | Wilson    | emma@bigdeal.com      | CEO                  |
      | Frank      | Miller    | frank@bigdeal.com     | CFO                  |
      | Grace      | Taylor    | grace@bigdeal.com     | VP of Operations     |
    And an opportunity "BigDeal Enterprise Deal" exists with:
      | account_name | BigDeal Corp |
      | amount       | 500000       |
      | stage        | Proposal     |
      | close_date   | 2026-06-30   |
    When I assign the following contact roles to the opportunity:
      | contact_name | role               | influence | decision_maker |
      | Emma Wilson  | Economic Buyer     | High      | true           |
      | Frank Miller | Financial Approver | High      | true           |
      | Grace Taylor | End User           | Medium    | false          |
    Then the opportunity should have 3 contact roles
    And "Emma Wilson" should be marked as a decision maker
    And "Frank Miller" should be marked as a decision maker
    And "Grace Taylor" should not be marked as a decision maker
    And the contact roles should influence opportunity probability

  @contact_management @activity_tracking
  Scenario: Track activities for contact
    Given a contact "Susan Brown" exists with email "susan@client.com"
    When I log the following activities for contact "Susan Brown":
      | activity_type | subject                     | due_date   | status    | priority | duration_minutes |
      | Call          | Initial discovery call      | 2026-01-15 | Completed | High     | 45               |
      | Email         | Follow-up pricing proposal  | 2026-01-16 | Completed | Medium   | null             |
      | Meeting       | Product demo                | 2026-01-20 | Scheduled | High     | 60               |
      | Task          | Send contract               | 2026-01-22 | Pending   | High     | null             |
    Then the contact should have 4 activities
    And 2 activities should be completed
    And 1 activity should be scheduled
    And 1 activity should be pending
    And the next scheduled activity should be "Product demo" on "2026-01-20"
    And all activities should be in tenant "acme_corp"

  #############################################################################
  # Opportunity Management Scenarios (3)
  #############################################################################

  @opportunity_management @creation
  Scenario: Create opportunity with stage and probability
    Given an account "ProspectCo" exists
    And a contact "David Lee" exists for account "ProspectCo"
    And the following opportunity stages exist:
      | stage_name      | probability | sort_order | is_closed | is_won |
      | Prospecting     | 10          | 1          | false     | false  |
      | Qualification   | 20          | 2          | false     | false  |
      | Proposal        | 50          | 3          | false     | false  |
      | Negotiation     | 75          | 4          | false     | false  |
      | Closed Won      | 100         | 5          | true      | true   |
      | Closed Lost     | 0           | 6          | true      | false  |
    When I create an opportunity with the following attributes:
      | name                 | ProspectCo Digital Transformation |
      | account_name         | ProspectCo                        |
      | primary_contact_name | David Lee                         |
      | amount               | 150000                            |
      | stage                | Qualification                     |
      | close_date           | 2026-04-30                        |
      | lead_source          | Referral                          |
      | next_step            | Schedule technical review         |
      | description          | Digital transformation initiative |
    Then the opportunity should be created successfully
    And the opportunity probability should be 20
    And the opportunity should not be marked as closed
    And the opportunity should not be marked as won
    And the weighted amount should be 30000
    And the opportunity should be in tenant "acme_corp"

  @opportunity_management @pipeline
  Scenario: Move opportunity through pipeline stages
    Given an opportunity "Pipeline Test Deal" exists with:
      | account_name | Pipeline Corp |
      | amount       | 100000        |
      | stage        | Prospecting   |
      | close_date   | 2026-05-31    |
    When I progress the opportunity through the following stages:
      | stage         | next_step                      | expected_probability |
      | Qualification | Conduct needs assessment       | 20                   |
      | Proposal      | Submit formal proposal         | 50                   |
      | Negotiation   | Finalize pricing and terms     | 75                   |
    Then the opportunity stage should be "Negotiation"
    And the opportunity probability should be 75
    And the stage history should contain:
      | from_stage    | to_stage      | changed_by |
      | Prospecting   | Qualification | sales_rep  |
      | Qualification | Proposal      | sales_rep  |
      | Proposal      | Negotiation   | sales_rep  |
    And the weighted amount should be 75000

  @opportunity_management @closure
  Scenario: Close opportunity as won or lost with validation
    Given an opportunity "Close Test Deal" exists with:
      | account_name | CloseCo     |
      | amount       | 200000      |
      | stage        | Negotiation |
      | close_date   | 2026-02-28  |
    When I close the opportunity as "won" with the following details:
      | actual_close_date | 2026-01-11           |
      | win_reason        | Best value           |
      | competitor        | null                 |
      | next_step         | Begin implementation |
    Then the opportunity stage should be "Closed Won"
    And the opportunity should be marked as closed
    And the opportunity should be marked as won
    And the opportunity probability should be 100
    And the weighted amount should be 200000
    And the win reason should be recorded as "Best value"

    When I attempt to close a different opportunity "Lost Deal" as "lost" without loss reason
    Then the closure should fail with validation error "Loss reason is required for closed lost opportunities"

    When I close opportunity "Lost Deal" as "lost" with the following details:
      | actual_close_date | 2026-01-11      |
      | loss_reason       | Price too high  |
      | competitor        | CompetitorCorp  |
    Then the opportunity stage should be "Closed Lost"
    And the opportunity should be marked as closed
    And the opportunity should not be marked as won
    And the opportunity probability should be 0
    And the loss reason should be recorded as "Price too high"
    And the competitor should be recorded as "CompetitorCorp"
