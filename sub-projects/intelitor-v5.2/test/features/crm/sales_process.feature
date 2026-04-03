# CRM Sales Process Feature (WS6)
# STAMP: SC-COV-004, SC-BDD-001, SC-BDD-004, SC-ASH-001, SC-DB-001
# Author: Cybernetic Architect
# Date: 2026-01-11
# Purpose: BDD validation of CRM sales process including products, pricebooks, quotes, orders, and campaigns

Feature: CRM Sales Process (WS6) - End-to-End Sales Workflow
  As a sales representative
  I want to manage products, quotes, orders, and campaigns
  So that I can efficiently process sales opportunities and track revenue

  Background:
    Given the Indrajaal application is running
    And the database is seeded with test data
    And I am authenticated as "sales-rep" with role "sales_user"
    And the tenant context is set to "acme_corp"
    And Ash resources are loaded for CRM domain

  # =====================================================
  # PRODUCT CATALOG MANAGEMENT
  # =====================================================

  @critical @SC-ASH-001 @product-catalog @smoke
  Scenario: Create product with attributes
    Given I have product details:
      | Field | Value |
      | name | Enterprise Security Suite |
      | code | ESS-2025 |
      | description | Complete security platform |
      | category | Software |
      | is_active | true |
      | list_price | 9999.00 |
      | cost_price | 4500.00 |
    When I create a product using Ash.Changeset.for_create
    Then the product should be created successfully
    And the product should have a UUID primary key
    And the product attributes should match:
      | Field | Expected Value |
      | name | Enterprise Security Suite |
      | code | ESS-2025 |
      | is_active | true |
      | list_price | 9999.00 |
    And the audit trail should record the creation
    And telemetry should emit "product_created" event

  @high @SC-ASH-001 @product-catalog
  Scenario: Product family hierarchy with parent-child relationships
    Given I have a parent product "Security Platform Base" with code "SPB-2025"
    And the parent product has list_price "5000.00"
    When I create child products:
      | name | code | list_price | parent_code |
      | Access Control Module | ACM-2025 | 1500.00 | SPB-2025 |
      | Video Surveillance Module | VSM-2025 | 2500.00 | SPB-2025 |
      | Alarm Management Module | AMM-2025 | 1000.00 | SPB-2025 |
    Then all 3 child products should be created
    And each child product should reference parent "SPB-2025"
    And I should be able to query products by parent_id
    And the product family hierarchy should be:
      | Level | Product | Code | Count |
      | 0 | Security Platform Base | SPB-2025 | 1 parent |
      | 1 | Access Control Module | ACM-2025 | child 1 |
      | 1 | Video Surveillance Module | VSM-2025 | child 2 |
      | 1 | Alarm Management Module | AMM-2025 | child 3 |
    And telemetry should emit "product_hierarchy_created" event

  @high @SC-ASH-001 @product-catalog @lifecycle
  Scenario: Active and inactive product filtering
    Given I have products with different active states:
      | name | code | is_active |
      | Active Product A | AP-001 | true |
      | Active Product B | AP-002 | true |
      | Inactive Product C | IP-003 | false |
      | Inactive Product D | IP-004 | false |
    When I query for active products only
    Then I should receive 2 products
    And all returned products should have is_active = true
    And the products should be:
      | name | code |
      | Active Product A | AP-001 |
      | Active Product B | AP-002 |
    When I query for all products
    Then I should receive 4 products
    And I should be able to filter by is_active using Ash query
    And telemetry should emit "product_query" event

  # =====================================================
  # PRICEBOOK MANAGEMENT
  # =====================================================

  @critical @SC-ASH-001 @pricebook @smoke
  Scenario: Create pricebook with standard and custom entries
    Given I have a product "Enterprise Suite" with list_price "10000.00"
    And I create a standard pricebook "2025 Standard Pricing"
    And I create a custom pricebook "Q1 2025 Promotion" with discount "15%"
    When I add price entries:
      | pricebook | product | list_price | use_standard |
      | 2025 Standard Pricing | Enterprise Suite | 10000.00 | true |
      | Q1 2025 Promotion | Enterprise Suite | 8500.00 | false |
    Then both pricebook entries should be created
    And the standard pricebook entry should have:
      | Field | Value |
      | list_price | 10000.00 |
      | use_standard_price | true |
    And the custom pricebook entry should have:
      | Field | Value |
      | list_price | 8500.00 |
      | use_standard_price | false |
    And the discount should be calculated as:
      | Calculation | Value |
      | standard_price | 10000.00 |
      | custom_price | 8500.00 |
      | discount_amount | 1500.00 |
      | discount_percentage | 15.0% |
    And telemetry should emit "pricebook_entries_created" event

  @high @SC-ASH-001 @pricebook @lookup
  Scenario: Pricebook entry lookup with fallback to standard
    Given I have a standard pricebook "Standard 2025"
    And I have a custom pricebook "Enterprise Discount"
    And I have product "Widget Pro" with list_price "5000.00"
    And "Standard 2025" has entry for "Widget Pro" at "5000.00"
    And "Enterprise Discount" has NO entry for "Widget Pro"
    When I query price for "Widget Pro" from "Enterprise Discount"
    Then the lookup should fallback to standard pricebook
    And the returned price should be "5000.00"
    And the use_standard_price flag should be true
    When I add a custom entry for "Widget Pro" in "Enterprise Discount" at "4200.00"
    And I query price for "Widget Pro" from "Enterprise Discount"
    Then the returned price should be "4200.00"
    And the use_standard_price flag should be false
    And the price calculation should show:
      | Source | Price |
      | Standard | 5000.00 |
      | Custom | 4200.00 |
      | Discount | 800.00 (16%) |

  # =====================================================
  # QUOTE CREATION
  # =====================================================

  @critical @SC-ASH-001 @quote @calculation @smoke
  Scenario: Create quote from opportunity with line items and discounts
    Given I have an opportunity "ACME Corp - Security Upgrade" with stage "Proposal"
    And I have products with prices:
      | product | code | list_price |
      | Access Control System | ACS-001 | 15000.00 |
      | Camera Package | CAM-001 | 8500.00 |
      | Alarm Panel | ALP-001 | 3200.00 |
    When I create a quote for the opportunity with:
      | Field | Value |
      | name | Q1 2025 - ACME Security |
      | quote_number | Q-2025-001 |
      | valid_until | 2025-02-15 |
      | pricebook | Standard 2025 |
    And I add quote line items:
      | product | quantity | unit_price | discount_type | discount_value |
      | Access Control System | 2 | 15000.00 | percentage | 10 |
      | Camera Package | 3 | 8500.00 | amount | 500.00 |
      | Alarm Panel | 5 | 3200.00 | none | 0 |
    Then the quote should be created successfully
    And the quote line items should calculate as:
      | product | qty | unit_price | subtotal | discount | line_total |
      | Access Control System | 2 | 15000.00 | 30000.00 | 3000.00 | 27000.00 |
      | Camera Package | 3 | 8500.00 | 25500.00 | 1500.00 | 24000.00 |
      | Alarm Panel | 5 | 3200.00 | 16000.00 | 0.00 | 16000.00 |
    And the quote totals should be:
      | Field | Calculated Value |
      | subtotal | 71500.00 |
      | total_discount | 4500.00 |
      | total_before_tax | 67000.00 |
      | tax_rate | 0.0% |
      | tax_amount | 0.00 |
      | grand_total | 67000.00 |
    And the quote status should be "Draft"
    And telemetry should emit "quote_created" event with line item count

  @high @SC-ASH-001 @quote @discount @calculation
  Scenario: Quote with mixed percentage and amount discounts
    Given I have a quote "Enterprise Bundle" with pricebook "Standard 2025"
    And I have products:
      | product | list_price |
      | Premium License | 20000.00 |
      | Support Package | 5000.00 |
      | Training Services | 3000.00 |
    When I add line items with mixed discounts:
      | product | quantity | discount_type | discount_value |
      | Premium License | 1 | percentage | 20 |
      | Support Package | 2 | amount | 1000.00 |
      | Training Services | 3 | percentage | 15 |
    Then the line totals should calculate correctly:
      | product | qty | unit_price | subtotal | discount_calc | line_total |
      | Premium License | 1 | 20000.00 | 20000.00 | 20% = 4000.00 | 16000.00 |
      | Support Package | 2 | 5000.00 | 10000.00 | 1000.00 total | 9000.00 |
      | Training Services | 3 | 3000.00 | 9000.00 | 15% = 1350.00 | 7650.00 |
    And the quote grand total should be:
      | Calculation | Value |
      | sum_of_subtotals | 39000.00 |
      | sum_of_discounts | 6350.00 |
      | grand_total | 32650.00 |
    And the overall discount percentage should be "16.28%"
    And all calculations should use Decimal type for precision
    And telemetry should emit "quote_calculations_completed" event

  # =====================================================
  # ORDER PROCESSING
  # =====================================================

  @critical @SC-ASH-001 @order @workflow @smoke
  Scenario: Convert quote to order with status workflow
    Given I have a quote "Q-2025-100" with status "Accepted"
    And the quote has grand_total "50000.00"
    And the quote has 4 line items
    When I convert the quote to an order
    Then an order should be created with:
      | Field | Value |
      | order_number | AUTO-GENERATED |
      | status | Draft |
      | total_amount | 50000.00 |
      | order_date | TODAY |
    And all 4 quote line items should be copied to order line items
    And the order line items should preserve:
      | Field | Preserved |
      | product_id | YES |
      | quantity | YES |
      | unit_price | YES |
      | discount | YES |
      | line_total | YES |
    When I submit the order for processing
    Then the order status should transition to "Submitted"
    And the status_history should record:
      | From | To | Timestamp |
      | null | Draft | T0 |
      | Draft | Submitted | T1 |
    When I mark the order as shipped with tracking "TRK-12345"
    Then the order status should transition to "Shipped"
    And the shipping_date should be TODAY
    And the tracking_number should be "TRK-12345"
    When I mark the order as delivered on "2025-01-15"
    Then the order status should transition to "Delivered"
    And the delivered_date should be "2025-01-15"
    And the order workflow should be complete
    And telemetry should emit "order_workflow_completed" event with status history

  # =====================================================
  # CAMPAIGN MANAGEMENT
  # =====================================================

  @critical @SC-ASH-001 @campaign @tracking @smoke
  Scenario: Campaign with budget tracking and member conversions
    Given I create a campaign with details:
      | Field | Value |
      | name | Q1 2025 Security Awareness |
      | type | Email Marketing |
      | status | Active |
      | start_date | 2025-01-01 |
      | end_date | 2025-03-31 |
      | budget | 25000.00 |
      | expected_revenue | 150000.00 |
    And I have leads and contacts:
      | name | type | email |
      | John Smith | Lead | john@example.com |
      | Jane Doe | Contact | jane@example.com |
      | Bob Wilson | Lead | bob@example.com |
      | Alice Brown | Contact | alice@example.com |
    When I add campaign members:
      | member | status |
      | John Smith | Sent |
      | Jane Doe | Sent |
      | Bob Wilson | Sent |
      | Alice Brown | Sent |
    Then 4 campaign members should be added
    And the campaign should have:
      | Metric | Value |
      | total_members | 4 |
      | sent_count | 4 |
      | responded_count | 0 |
      | converted_count | 0 |
    When I track member responses:
      | member | response | converted |
      | John Smith | Clicked | true |
      | Jane Doe | Opened | false |
      | Bob Wilson | Clicked | true |
      | Alice Brown | No response | false |
    Then the campaign metrics should update to:
      | Metric | Calculated Value |
      | total_members | 4 |
      | sent_count | 4 |
      | responded_count | 3 |
      | converted_count | 2 |
      | response_rate | 75.0% |
      | conversion_rate | 50.0% |
    And the campaign ROI should calculate as:
      | Field | Calculation |
      | actual_cost | 25000.00 |
      | expected_revenue | 150000.00 |
      | potential_roi | 500.0% |
    When I create opportunities from conversions:
      | member | opportunity_name | amount |
      | John Smith | Smith Security Deal | 45000.00 |
      | Bob Wilson | Wilson Enterprise | 55000.00 |
    Then 2 opportunities should be created
    And each opportunity should link to the campaign
    And the campaign actual_revenue should be "100000.00"
    And the actual ROI should be:
      | Calculation | Value |
      | actual_revenue | 100000.00 |
      | actual_cost | 25000.00 |
      | actual_roi | 300.0% |
    And telemetry should emit "campaign_completed" event with full metrics

  # =====================================================
  # INTEGRATION: END-TO-END SALES WORKFLOW
  # =====================================================

  @integration @smoke @e2e
  Scenario: Complete sales workflow - Campaign to Order
    Given I have a campaign "Enterprise Expansion 2025"
    And I add 10 campaign members (leads and contacts)
    When 3 members respond positively
    And I convert 2 responses to opportunities
    And I create quotes for both opportunities
    And I apply 10% discount to both quotes
    And both quotes are accepted by customers
    And I convert both quotes to orders
    And I submit both orders
    And I ship both orders
    And I deliver both orders
    Then the complete workflow should show:
      | Stage | Count |
      | Campaign Members | 10 |
      | Responses | 3 |
      | Opportunities | 2 |
      | Quotes | 2 |
      | Orders | 2 |
      | Delivered | 2 |
    And the campaign ROI should be measurable
    And all state transitions should be in immutable register
    And telemetry should capture full workflow metrics

  # =====================================================
  # DATA INTEGRITY & VALIDATION
  # =====================================================

  @high @SC-ASH-001 @validation
  Scenario: Product validation rules enforcement
    Given I attempt to create a product with invalid data:
      | Field | Invalid Value |
      | name | "" |
      | list_price | -100.00 |
      | cost_price | 15000.00 |
    When I submit the product creation
    Then the creation should fail with validation errors:
      | Field | Error |
      | name | required |
      | list_price | must be positive |
      | cost_price | cannot exceed list_price |
    And no product should be persisted
    And telemetry should emit "validation_failure" event

  @high @SC-ASH-001 @calculation
  Scenario: Decimal precision in quote calculations
    Given I have a quote with products:
      | product | quantity | unit_price | discount_pct |
      | Service A | 3 | 1234.56 | 7.5 |
      | Service B | 7 | 987.65 | 12.3 |
    When the quote calculations are performed
    Then all monetary values should use Decimal type
    And calculations should be precise to 2 decimal places:
      | Line | Subtotal | Discount | Line Total |
      | Service A | 3703.68 | 277.78 | 3425.90 |
      | Service B | 6913.55 | 850.37 | 6063.18 |
    And the grand total should be "9489.08"
    And no floating point rounding errors should occur

  # =====================================================
  # PERFORMANCE & SCALABILITY
  # =====================================================

  @medium @performance
  Scenario: Bulk quote line item insertion performance
    Given I have a quote "Large Enterprise Deal"
    When I add 100 line items in a single batch
    Then all 100 line items should be inserted
    And the insertion should complete within 5 seconds
    And the quote totals should calculate correctly
    And memory usage should remain < 100MB
    And telemetry should emit "bulk_insert_completed" event

  # =====================================================
  # SECURITY & TENANT ISOLATION
  # =====================================================

  @critical @SC-ASH-001 @security @tenancy
  Scenario: Tenant isolation in multi-tenant sales process
    Given I have two tenants: "acme_corp" and "globex_inc"
    And "acme_corp" has products: ["Product A", "Product B"]
    And "globex_inc" has products: ["Product X", "Product Y"]
    When I query products as "acme_corp" user
    Then I should only see "Product A" and "Product B"
    And I should NOT see "Product X" or "Product Y"
    When I attempt to create a quote for "acme_corp" referencing "globex_inc" product
    Then the creation should fail with authorization error
    And no cross-tenant data leakage should occur
    And telemetry should emit "tenant_isolation_enforced" event

  # =====================================================
  # AUDIT TRAIL
  # =====================================================

  @high @SC-REG-001 @audit
  Scenario: Sales process audit trail in immutable register
    Given I perform a complete sales workflow
    When I create a product
    And I create a pricebook entry
    And I create a quote with 3 line items
    And I convert the quote to an order
    And I update the order status 3 times
    Then all 8+ actions should be logged in immutable register
    And each log entry should include:
      | Field | Required |
      | timestamp | YES |
      | actor_id | YES |
      | action_type | YES |
      | resource_type | YES |
      | resource_id | YES |
      | changes | YES |
    And the audit trail should be immutable and verifiable
    And I should be able to reconstruct the complete history
    And telemetry should emit "audit_trail_verified" event
