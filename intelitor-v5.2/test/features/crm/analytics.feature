@crm @analytics @ws8
Feature: CRM Analytics (WS8)
  As a sales manager
  I need comprehensive analytics and forecasting capabilities
  So that I can track performance, predict outcomes, and optimize sales processes

  Background:
    Given the system is in a clean state
    And the current tenant is "acme_corp"
    And the following users exist:
      | id   | name           | role         | quota    |
      | u001 | Alice Johnson  | sales_rep    | 100000   |
      | u002 | Bob Smith      | sales_rep    | 100000   |
      | u003 | Carol Davis    | sales_rep    | 100000   |
      | u004 | David Lee      | manager      | 300000   |
      | u005 | Eve Martinez   | vp_sales     | 1000000  |

  # ============================================================================
  # PIPELINE ANALYTICS (SC-PRF-050: < 50ms)
  # ============================================================================

  @pipeline @conversion
  Scenario: Pipeline summary with conversion rates between stages
    Given the following opportunities exist in the pipeline:
      | id    | account     | owner | stage        | amount  | probability | created_days_ago |
      | opp01 | Account A   | u001  | Prospecting  | 10000   | 10          | 30               |
      | opp02 | Account B   | u001  | Prospecting  | 15000   | 10          | 25               |
      | opp03 | Account C   | u002  | Qualification| 20000   | 25          | 20               |
      | opp04 | Account D   | u002  | Qualification| 25000   | 25          | 18               |
      | opp05 | Account E   | u002  | Qualification| 30000   | 25          | 15               |
      | opp06 | Account F   | u003  | Needs Analysis| 35000  | 50          | 10               |
      | opp07 | Account G   | u003  | Proposal     | 40000   | 75          | 8                |
      | opp08 | Account H   | u003  | Proposal     | 45000   | 75          | 5                |
      | opp09 | Account I   | u001  | Negotiation  | 50000   | 90          | 3                |
      | opp10 | Account J   | u002  | Closed Won   | 55000   | 100         | 1                |
    When I request the pipeline summary
    Then the response time should be less than 50 milliseconds
    And the pipeline summary should show:
      | stage           | count | total_value | avg_value | weighted_value |
      | Prospecting     | 2     | 25000       | 12500     | 2500           |
      | Qualification   | 3     | 75000       | 25000     | 18750          |
      | Needs Analysis  | 1     | 35000       | 35000     | 17500          |
      | Proposal        | 2     | 85000       | 42500     | 63750          |
      | Negotiation     | 1     | 50000       | 50000     | 45000          |
      | Closed Won      | 1     | 55000       | 55000     | 55000          |
    And the conversion rates should be:
      | from_stage      | to_stage        | conversion_rate | avg_days |
      | Prospecting     | Qualification   | 60%             | 8        |
      | Qualification   | Needs Analysis  | 33%             | 7        |
      | Needs Analysis  | Proposal        | 100%            | 5        |
      | Proposal        | Negotiation     | 50%             | 4        |
      | Negotiation     | Closed Won      | 100%            | 2        |
    And the overall pipeline value should be "$325,000"
    And the weighted pipeline value should be "$202,500"

  @pipeline @winrate @velocity
  Scenario: Win rate and sales velocity calculation
    Given the following closed opportunities in the last 90 days:
      | id    | account     | owner | stage       | amount  | outcome    | days_to_close | created_at_days_ago | closed_at_days_ago |
      | c001  | Corp A      | u001  | Closed Won  | 50000   | won        | 45            | 50                  | 5                  |
      | c002  | Corp B      | u001  | Closed Won  | 60000   | won        | 40            | 48                  | 8                  |
      | c003  | Corp C      | u002  | Closed Won  | 70000   | won        | 35            | 42                  | 7                  |
      | c004  | Corp D      | u002  | Closed Lost | 80000   | lost       | 50            | 60                  | 10                 |
      | c005  | Corp E      | u003  | Closed Won  | 90000   | won        | 30            | 35                  | 5                  |
      | c006  | Corp F      | u003  | Closed Lost | 100000  | lost       | 55            | 65                  | 10                 |
    And there are 8 total opportunities in the same period
    When I request win rate and sales velocity analytics
    Then the response time should be less than 50 milliseconds
    And the win rate metrics should be:
      | metric                  | value   |
      | total_opportunities     | 8       |
      | won_opportunities       | 4       |
      | lost_opportunities      | 2       |
      | win_rate_by_count       | 50%     |
      | win_rate_by_value       | 56.25%  |
      | total_won_value         | 270000  |
      | total_lost_value        | 180000  |
      | avg_deal_size_won       | 67500   |
      | avg_deal_size_lost      | 90000   |
    And the sales velocity metrics should be:
      | metric                  | value    |
      | avg_deal_size           | 67500    |
      | avg_sales_cycle_days    | 37.5     |
      | win_rate                | 50%      |
      | num_opportunities       | 4        |
      | sales_velocity_per_day  | 900      |
    And the sales velocity calculation should be:
      """
      Sales Velocity = (Avg Deal Size × Win Rate × Num Opps) / Avg Sales Cycle
      Sales Velocity = ($67,500 × 0.5 × 4) / 37.5 days
      Sales Velocity = $135,000 / 37.5 = $3,600/day

      For won deals only:
      Sales Velocity = ($67,500 × 1.0 × 4) / 37.5 = $7,200/day

      Adjusted for pipeline (4 won in 90 days):
      Daily Rate = $270,000 / 90 days = $3,000/day
      """

  # ============================================================================
  # DASHBOARD (SC-PRF-050: < 50ms)
  # ============================================================================

  @dashboard @kpis
  Scenario: Executive dashboard with key performance indicators
    Given the current date is "2026-01-11"
    And the current quarter is "Q1 2026"
    And the following sales data for Q1 2026:
      | metric                  | value    |
      | quarterly_quota         | 1000000  |
      | closed_won_value        | 450000   |
      | pipeline_value          | 800000   |
      | weighted_pipeline       | 500000   |
      | num_opportunities       | 45       |
      | num_accounts            | 30       |
      | num_contacts            | 120      |
      | num_activities          | 450      |
      | avg_deal_size           | 50000    |
      | win_rate                | 55%      |
      | days_remaining_in_q     | 80       |
    When I request the executive dashboard
    Then the response time should be less than 50 milliseconds
    And the dashboard should display the following KPIs:
      | kpi_name                | current_value | target_value | percentage | trend | status  |
      | Quota Attainment        | 450000        | 1000000      | 45%        | ↑     | on-track|
      | Pipeline Coverage       | 950000        | 1000000      | 95%        | →     | healthy |
      | Win Rate                | 55%           | 50%          | 110%       | ↑     | exceeds |
      | Avg Deal Size           | 50000         | 45000        | 111%       | ↑     | exceeds |
      | Sales Velocity          | 3500          | 3000         | 117%       | ↑     | exceeds |
      | Activities per Day      | 5.6           | 5.0          | 112%       | ↑     | exceeds |
    And the forecast projection should be:
      | category        | amount   | probability | weighted_amount |
      | Closed          | 450000   | 100%        | 450000          |
      | Commit          | 200000   | 90%         | 180000          |
      | Best Case       | 300000   | 50%         | 150000          |
      | Pipeline        | 300000   | 25%         | 75000           |
      | Total Forecast  | 1250000  | -           | 855000          |
    And the quarter projection should show:
      """
      Based on current run rate of $3,500/day:
      Projected Q1 Close: $450,000 (current) + ($3,500 × 80 days) = $730,000
      Quota Gap: $1,000,000 - $730,000 = $270,000
      Required Daily Rate: $270,000 / 80 days = $3,375/day
      Stretch Goal Needed: $3,375 - $3,500 = -$125/day (ON TRACK)
      """

  @dashboard @leaderboard @realtime
  Scenario: Sales leaderboard with real-time metrics refresh
    Given the following sales rep performance data:
      | user_id | name          | quota   | closed_won | pipeline | weighted | num_opps | activities | win_rate |
      | u001    | Alice Johnson | 100000  | 75000      | 120000   | 80000    | 15       | 180        | 60%      |
      | u002    | Bob Smith     | 100000  | 65000      | 100000   | 65000    | 12       | 150        | 55%      |
      | u003    | Carol Davis   | 100000  | 55000      | 90000    | 55000    | 10       | 140        | 50%      |
    And the dashboard is configured to refresh every 30 seconds
    When I view the sales leaderboard
    Then the response time should be less than 50 milliseconds
    And the leaderboard should show:
      | rank | name          | quota_attainment | closed_won | pipeline_coverage | health_score | badge       |
      | 1    | Alice Johnson | 75%              | 75000      | 2.0x              | 92           | 🏆 Top Rep  |
      | 2    | Bob Smith     | 65%              | 65000      | 1.65x             | 85           | ⭐ Strong   |
      | 3    | Carol Davis   | 55%              | 55000      | 1.45x             | 78           | ✓ On Track  |
    And the health score calculation should be:
      """
      Alice Health Score:
      - Quota Attainment (40%): 75% × 40 = 30 points
      - Pipeline Coverage (30%): min(200%, 2.0x) / 2 × 30 = 30 points
      - Win Rate (20%): 60% / 60% × 20 = 20 points
      - Activity Level (10%): 180 / 150 × 10 = 12 points
      Total: 30 + 30 + 20 + 12 = 92 points
      """
    When a new opportunity worth "$10,000" is marked "Closed Won" for "Bob Smith"
    And I wait for real-time refresh
    Then the leaderboard should update within 2 seconds
    And Bob Smith's metrics should show:
      | metric            | old_value | new_value |
      | closed_won        | 65000     | 75000     |
      | quota_attainment  | 65%       | 75%       |
      | rank              | 2         | 1         |
    And the dashboard should show a notification:
      """
      🎉 Bob Smith just closed a $10,000 deal!
      New quota attainment: 75% (tied for #1)
      """

  # ============================================================================
  # FORECASTING (SC-PRF-050: < 50ms)
  # ============================================================================

  @forecasting @categories
  Scenario: Generate user forecast with probability categories
    Given I am logged in as "Alice Johnson" (sales rep)
    And the current quarter is "Q1 2026"
    And my quota is "$100,000"
    And I have the following opportunities:
      | id   | account   | amount | stage         | probability | forecast_category | close_date |
      | o001 | Acme Inc  | 20000  | Closed Won    | 100         | Closed            | 2026-01-05 |
      | o002 | Beta Corp | 15000  | Negotiation   | 90          | Commit            | 2026-02-15 |
      | o003 | Gamma LLC | 18000  | Negotiation   | 90          | Commit            | 2026-02-20 |
      | o004 | Delta Co  | 12000  | Proposal      | 75          | Commit            | 2026-03-01 |
      | o005 | Epsilon   | 10000  | Proposal      | 75          | Best Case         | 2026-03-10 |
      | o006 | Zeta Inc  | 8000   | Needs Analysis| 50          | Best Case         | 2026-03-15 |
      | o007 | Eta Corp  | 6000   | Qualification | 25          | Pipeline          | 2026-03-20 |
      | o008 | Theta LLC | 5000   | Prospecting   | 10          | Pipeline          | 2026-03-25 |
    When I generate my forecast for Q1 2026
    Then the response time should be less than 50 milliseconds
    And my forecast should show:
      | category   | count | total_amount | weighted_amount | quota_percentage |
      | Closed     | 1     | 20000        | 20000           | 20%              |
      | Commit     | 3     | 45000        | 40500           | 40.5%            |
      | Best Case  | 2     | 18000        | 12000           | 12%              |
      | Pipeline   | 2     | 11000        | 2200            | 2.2%             |
      | Total      | 8     | 94000        | 74700           | 74.7%            |
    And the forecast category rules should be:
      """
      Closed:     Stage = Closed Won (100% probability)
      Commit:     Probability ≥ 90% OR Stage = Negotiation (90%)
      Best Case:  Probability ≥ 50% OR Stage IN (Proposal, Needs Analysis)
      Pipeline:   Probability < 50% OR Stage IN (Qualification, Prospecting)
      Omitted:    Stage = Closed Lost (0% probability)
      """
    And my quota gap should be "$25,300" (100,000 - 74,700)
    And my forecast accuracy should be tracked

  @forecasting @hierarchy @rollup
  Scenario: Hierarchical forecast rollup from reps to manager to VP
    Given the following organizational hierarchy:
      | level     | user_id | name           | reports_to | quota    |
      | vp        | u005    | Eve Martinez   | null       | 1000000  |
      | manager   | u004    | David Lee      | u005       | 300000   |
      | rep       | u001    | Alice Johnson  | u004       | 100000   |
      | rep       | u002    | Bob Smith      | u004       | 100000   |
      | rep       | u003    | Carol Davis    | u004       | 100000   |
    And the following rep forecasts:
      | rep_id | name          | closed | commit | best_case | pipeline | total   |
      | u001   | Alice Johnson | 20000  | 40000  | 15000     | 10000    | 85000   |
      | u002   | Bob Smith     | 25000  | 35000  | 20000     | 12000    | 92000   |
      | u003   | Carol Davis   | 18000  | 30000  | 18000     | 8000     | 74000   |
    When I generate the hierarchical forecast rollup
    Then the response time should be less than 50 milliseconds
    And the manager "David Lee" forecast should show:
      | category   | amount | quota_percentage |
      | Closed     | 63000  | 21%              |
      | Commit     | 105000 | 35%              |
      | Best Case  | 53000  | 17.7%            |
      | Pipeline   | 30000  | 10%              |
      | Total      | 251000 | 83.7%            |
    And the VP "Eve Martinez" forecast should show:
      | category   | amount  | quota_percentage |
      | Closed     | 63000   | 6.3%             |
      | Commit     | 105000  | 10.5%            |
      | Best Case  | 53000   | 5.3%             |
      | Pipeline   | 30000   | 3.0%             |
      | Total      | 251000  | 25.1%            |
    And the forecast rollup should support drill-down:
      """
      VP (Eve Martinez): $251,000 / $1,000,000 (25.1%)
        └─ Manager (David Lee): $251,000 / $300,000 (83.7%)
             ├─ Alice Johnson: $85,000 / $100,000 (85%)
             ├─ Bob Smith: $92,000 / $100,000 (92%)
             └─ Carol Davis: $74,000 / $100,000 (74%)
      """

  @forecasting @adjustments @quota
  Scenario: Manager adjustments and quota attainment tracking
    Given I am logged in as "David Lee" (manager)
    And I manage 3 sales reps with total quota of "$300,000"
    And the team forecast is:
      | category   | rep_total | manager_view | adjustment | adjusted_total |
      | Closed     | 63000     | 63000        | 0          | 63000          |
      | Commit     | 105000    | 105000       | -10000     | 95000          |
      | Best Case  | 53000     | 53000        | -5000      | 48000          |
      | Pipeline   | 30000     | 30000        | -8000      | 22000          |
    And the adjustment rationale is:
      """
      Commit: -$10,000 (Beta Corp deal delayed to next quarter)
      Best Case: -$5,000 (Gamma LLC budget concerns)
      Pipeline: -$8,000 (Seasonal slowdown expected)
      """
    When I submit manager adjustments with rationale
    Then the response time should be less than 50 milliseconds
    And the adjusted forecast should be:
      | category       | amount | quota_percentage |
      | Closed         | 63000  | 21%              |
      | Commit         | 95000  | 31.7%            |
      | Best Case      | 48000  | 16%              |
      | Pipeline       | 22000  | 7.3%             |
      | Adjusted Total | 228000 | 76%              |
    And the quota attainment tracking should show:
      | period  | quota   | actual | forecast | attainment | gap     | status     |
      | Q1 2026 | 300000  | 63000  | 228000   | 76%        | 72000   | at-risk    |
      | Month 1 | 100000  | 30000  | 80000    | 80%        | 20000   | on-track   |
      | Month 2 | 100000  | 23000  | 75000    | 75%        | 25000   | at-risk    |
      | Month 3 | 100000  | 10000  | 73000    | 73%        | 27000   | behind     |
    And the adjustment history should be logged:
      | timestamp           | user      | category  | amount | rationale                        |
      | 2026-01-11 10:00:00 | David Lee | Commit    | -10000 | Beta Corp deal delayed           |
      | 2026-01-11 10:00:00 | David Lee | Best Case | -5000  | Gamma LLC budget concerns        |
      | 2026-01-11 10:00:00 | David Lee | Pipeline  | -8000  | Seasonal slowdown expected       |
    And an alert should be sent to VP:
      """
      Manager Adjustment Alert
      Team: David Lee
      Original Forecast: $251,000 (83.7%)
      Adjusted Forecast: $228,000 (76%)
      Delta: -$23,000 (-7.7%)
      Quota Gap: $72,000
      Status: AT RISK
      """

  # ============================================================================
  # CAMPAIGN ROI (SC-PRF-050: < 50ms)
  # ============================================================================

  @campaign @roi @performance
  Scenario: Campaign performance metrics and ROI calculation
    Given the following marketing campaigns in Q1 2026:
      | id   | name              | type       | cost   | start_date | end_date   | status |
      | c001 | Web Summit 2026   | Event      | 50000  | 2026-01-15 | 2026-01-17 | active |
      | c002 | LinkedIn Ads Q1   | Digital    | 25000  | 2026-01-01 | 2026-03-31 | active |
      | c003 | Email Nurture Jan | Email      | 5000   | 2026-01-01 | 2026-01-31 | closed |
    And the following campaign results:
      | campaign_id | leads_generated | qualified_leads | opportunities | closed_won | revenue |
      | c001        | 150             | 45              | 12            | 3          | 180000  |
      | c002        | 300             | 90              | 20            | 5          | 250000  |
      | c003        | 500             | 100             | 15            | 2          | 100000  |
    When I request campaign performance analytics
    Then the response time should be less than 50 milliseconds
    And the campaign performance should show:
      | campaign          | cost  | leads | qualified | opps | won | revenue | roi    | roi_percentage |
      | Web Summit 2026   | 50000 | 150   | 45        | 12   | 3   | 180000  | 130000 | 260%           |
      | LinkedIn Ads Q1   | 25000 | 300   | 90        | 20   | 5   | 250000  | 225000 | 900%           |
      | Email Nurture Jan | 5000  | 500   | 100       | 15   | 2   | 100000  | 95000  | 1900%          |
    And the ROI calculation should be:
      """
      ROI = (Revenue - Cost) / Cost × 100%

      Web Summit 2026:
      ROI = ($180,000 - $50,000) / $50,000 × 100% = 260%

      LinkedIn Ads Q1:
      ROI = ($250,000 - $25,000) / $25,000 × 100% = 900%

      Email Nurture Jan:
      ROI = ($100,000 - $5,000) / $5,000 × 100% = 1900%
      """
    And the conversion funnel should show:
      | campaign          | leads→qualified | qualified→opps | opps→won | overall_conversion |
      | Web Summit 2026   | 30%             | 26.7%          | 25%      | 2.0%               |
      | LinkedIn Ads Q1   | 30%             | 22.2%          | 25%      | 1.67%              |
      | Email Nurture Jan | 20%             | 15%            | 13.3%    | 0.4%               |

  @campaign @costperlead @response
  Scenario: Cost per lead calculation and response rate tracking
    Given the marketing campaign "Enterprise ABM Q1 2026"
    And the campaign details:
      | field              | value          |
      | type               | ABM            |
      | total_cost         | 100000         |
      | start_date         | 2026-01-01     |
      | end_date           | 2026-03-31     |
      | target_accounts    | 50             |
      | target_contacts    | 200            |
    And the campaign activities:
      | activity_type      | count | cost   | responses | qualified |
      | Direct Mail        | 200   | 10000  | 40        | 15        |
      | Email Sequences    | 800   | 5000   | 120       | 30        |
      | LinkedIn InMail    | 200   | 8000   | 30        | 12        |
      | Executive Dinners  | 10    | 25000  | 9         | 8         |
      | Webinars           | 5     | 15000  | 100       | 25        |
      | Field Events       | 3     | 37000  | 60        | 30        |
    When I calculate cost per lead and response rates
    Then the response time should be less than 50 milliseconds
    And the cost metrics should show:
      | metric                    | value    |
      | total_cost                | 100000   |
      | total_activities          | 1218     |
      | total_responses           | 359      |
      | total_qualified_leads     | 120      |
      | cost_per_activity         | 82.10    |
      | cost_per_response         | 278.55   |
      | cost_per_qualified_lead   | 833.33   |
      | cost_per_target_account   | 2000.00  |
    And the response rate analysis should show:
      | activity_type     | responses | response_rate | cost_per_response | efficiency_score |
      | Executive Dinners | 9         | 90%           | 2777.78           | High Touch       |
      | Field Events      | 60        | 2000%         | 616.67            | High Impact      |
      | Direct Mail       | 40        | 20%           | 250.00            | Good             |
      | Webinars          | 100       | 2000%         | 150.00            | Excellent        |
      | LinkedIn InMail   | 30        | 15%           | 266.67            | Good             |
      | Email Sequences   | 120       | 15%           | 41.67             | Best ROI         |
    And the cost per qualified lead by channel should show:
      | activity_type     | cost   | qualified | cpl      | recommendation |
      | Email Sequences   | 5000   | 30        | 166.67   | Scale Up       |
      | Webinars          | 15000  | 25        | 600.00   | Maintain       |
      | Direct Mail       | 10000  | 15        | 666.67   | Maintain       |
      | LinkedIn InMail   | 8000   | 12        | 666.67   | Maintain       |
      | Executive Dinners | 25000  | 8         | 3125.00  | High Value Only|
      | Field Events      | 37000  | 30        | 1233.33  | Optimize       |
    And the overall campaign health should be:
      """
      Campaign: Enterprise ABM Q1 2026

      Investment: $100,000
      Target Accounts Reached: 50 (100%)
      Total Responses: 359 (89.75% of contacts)
      Qualified Leads: 120 (60% of target, 33.4% of responses)

      Cost Efficiency:
      - Cost per Account: $2,000 (industry benchmark: $1,500) ⚠️
      - Cost per Qualified Lead: $833 (industry benchmark: $600) ⚠️
      - Response Rate: 29.5% (industry benchmark: 15%) ✓

      Recommendations:
      1. Scale email sequences (best CPL: $167)
      2. Maintain webinar cadence (good ROI)
      3. Optimize field event costs (high impact but expensive)
      4. Reserve executive dinners for top-tier accounts only
      """

  # ============================================================================
  # PERFORMANCE VALIDATION
  # ============================================================================

  @performance @stamp
  Scenario: Analytics performance validation (SC-PRF-050)
    Given a dataset with 1000 opportunities across 100 accounts
    And a dataset with 5000 activities across 200 users
    And a dataset with 50 campaigns over 12 months
    When I run the following analytics queries in parallel:
      | query_type              | dataset_size | expected_max_time_ms |
      | Pipeline Summary        | 1000         | 50                   |
      | Win Rate Calculation    | 1000         | 50                   |
      | Sales Velocity          | 5000         | 50                   |
      | Executive Dashboard     | 1000         | 50                   |
      | Sales Leaderboard       | 200          | 50                   |
      | Forecast Generation     | 1000         | 50                   |
      | Hierarchical Rollup     | 200          | 50                   |
      | Campaign ROI            | 50           | 50                   |
      | Cost Per Lead           | 5000         | 50                   |
    Then all queries should complete within their time limits
    And the 95th percentile response time should be less than 45 milliseconds
    And the 99th percentile response time should be less than 50 milliseconds
    And no query should experience timeouts
    And the analytics engine should log performance metrics:
      | metric                  | target  | actual  | status |
      | avg_response_time_ms    | < 30    | 28      | ✓      |
      | p95_response_time_ms    | < 45    | 42      | ✓      |
      | p99_response_time_ms    | < 50    | 48      | ✓      |
      | cache_hit_rate          | > 80%   | 87%     | ✓      |
      | db_query_count_avg      | < 5     | 3       | ✓      |
