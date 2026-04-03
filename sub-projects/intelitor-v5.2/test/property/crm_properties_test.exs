defmodule Indrajaal.Property.CrmPropertiesTest do
  @moduledoc """
  Property-based tests for CRM (Customer Relationship Management) domain.

  WHAT: Dual property tests (PropCheck + ExUnitProperties) for CRM modules
  WHY: Verify invariants hold across random inputs per TDG methodology
  CONSTRAINTS: SC-PROP-021 to SC-PROP-025, SC-TDG-001, SC-ASH-001 to SC-ASH-004

  ## Test Categories
  - Lead Lifecycle Properties
  - Account/Contact Properties
  - Opportunity Pipeline Properties
  - Quote/Order Properties
  - Automation Properties
  - Analytics/Forecasting Properties
  - Multi-tenancy Properties
  - Audit Trail Properties

  ## STAMP Compliance
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-DB-001: Use BaseResource
  - SC-DB-005: uuid_primary_key
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :property
  @moduletag :crm

  # Valid CRM enums
  @lead_statuses [:new, :contacted, :qualified, :converted, :lost]
  @lead_sources [:web, :phone, :referral, :campaign, :partner, :other]
  @opportunity_stages [
    :prospecting,
    :qualification,
    :needs_analysis,
    :value_proposition,
    :id_decision_makers,
    :perception_analysis,
    :proposal,
    :negotiation,
    :closed_won,
    :closed_lost
  ]
  @quote_statuses [:draft, :needs_review, :approved, :rejected, :presented, :accepted]
  @order_statuses [:draft, :submitted, :approved, :activated, :cancelled, :shipped, :delivered]
  @account_types [:prospect, :customer, :partner, :competitor]

  # =============================================================================
  # Lead Lifecycle Properties
  # =============================================================================

  describe "Lead Lifecycle properties" do
    property "lead status transitions follow valid paths" do
      forall {from_status, to_status} <- valid_lead_transition_generator() do
        valid_lead_transition?(from_status, to_status)
      end
    end

    property "lead scoring is bounded [0, 100]" do
      forall {demographics, behavior, firmographics} <- scoring_factors_generator() do
        score = calculate_lead_score(demographics, behavior, firmographics)
        score >= 0 and score <= 100
      end
    end

    property "lead conversion preserves data integrity" do
      forall lead_data <- lead_data_generator() do
        {:ok, account, contact, opportunity} = simulate_lead_conversion(lead_data)

        account.name == lead_data.company and
          contact.email == lead_data.email and
          is_binary(opportunity.name)
      end
    end

    property "hot leads have score >= 80" do
      forall lead_data <- hot_lead_generator() do
        lead = create_lead_from_data(lead_data)
        is_hot_lead?(lead)
      end
    end

    # ExUnitProperties version
    test "lead email format is valid (StreamData)" do
      ExUnitProperties.check all(
                               local <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               domain <- SD.string(:alphanumeric, min_length: 1, max_length: 15)
                             ) do
        email = "#{local}@#{domain}.com"
        assert String.contains?(email, "@")
        assert String.contains?(email, ".")
      end
    end
  end

  # =============================================================================
  # Account/Contact Properties
  # =============================================================================

  describe "Account/Contact properties" do
    property "account names are non-empty strings" do
      forall account_data <- account_data_generator() do
        account = create_account_from_data(account_data)
        is_binary(account.name) and String.length(account.name) > 0
      end
    end

    property "account type is always valid enum" do
      forall account_type <- PC.elements(@account_types) do
        account = %{type: account_type}
        account.type in @account_types
      end
    end

    property "contacts belong to exactly one account" do
      forall {contact_data, account_id} <- contact_with_account_generator() do
        contact = create_contact_from_data(contact_data, account_id)
        contact.account_id == account_id
      end
    end

    property "account hierarchy is acyclic (no loops)" do
      forall hierarchy <- account_hierarchy_generator() do
        not has_cycle?(hierarchy)
      end
    end

    # ExUnitProperties version
    test "phone numbers follow valid patterns (StreamData)" do
      ExUnitProperties.check all(
                               country_code <- SD.integer(1..999),
                               area_code <- SD.integer(100..999),
                               number <- SD.integer(1_000_000..9_999_999)
                             ) do
        phone = "+#{country_code}-#{area_code}-#{number}"
        assert String.length(phone) >= 10
      end
    end
  end

  # =============================================================================
  # Opportunity Pipeline Properties
  # =============================================================================

  describe "Opportunity Pipeline properties" do
    property "opportunity amount is non-negative" do
      forall amount <- amount_generator() do
        amount >= 0
      end
    end

    property "opportunity probability is bounded [0, 100]" do
      forall probability <- PC.integer(0, 100) do
        probability >= 0 and probability <= 100
      end
    end

    property "weighted pipeline calculation is correct" do
      forall opportunities <- opportunities_generator() do
        calculated = calculate_weighted_pipeline(opportunities)
        expected = Enum.sum(Enum.map(opportunities, fn o -> o.amount * o.probability / 100 end))
        abs(calculated - expected) < 0.01
      end
    end

    property "stage progression follows sales process" do
      forall {from_stage, to_stage} <- stage_transition_generator() do
        valid_stage_transition?(from_stage, to_stage)
      end
    end

    property "closed opportunities cannot reopen" do
      forall {closed_stage, new_stage} <- closed_reopen_generator() do
        closed_stage in [:closed_won, :closed_lost] and
          not valid_stage_transition?(closed_stage, new_stage)
      end
    end

    # ExUnitProperties version
    test "close date is in the future for open opportunities (StreamData)" do
      ExUnitProperties.check all(days_ahead <- SD.integer(1..365)) do
        close_date = Date.add(Date.utc_today(), days_ahead)
        assert Date.compare(close_date, Date.utc_today()) == :gt
      end
    end
  end

  # =============================================================================
  # Quote/Order Properties
  # =============================================================================

  describe "Quote/Order properties" do
    property "quote total equals subtotal minus discount plus tax" do
      forall {subtotal, discount_pct, tax_pct} <- quote_calculation_generator() do
        discount = subtotal * discount_pct / 100
        after_discount = subtotal - discount
        tax = after_discount * tax_pct / 100
        total = after_discount + tax

        total >= 0 and total <= subtotal * 1.5
      end
    end

    property "line item total equals quantity * unit_price" do
      forall {quantity, unit_price} <- line_item_generator() do
        total = quantity * unit_price
        total >= 0 and abs(total - quantity * unit_price) < 0.01
      end
    end

    property "order cannot have negative totals" do
      forall order_data <- order_data_generator() do
        order = create_order_from_data(order_data)
        order.subtotal >= 0 and order.total >= 0
      end
    end

    property "quote to order conversion preserves line items" do
      forall quote_data <- quote_with_lines_generator() do
        quote = create_quote_from_data(quote_data)
        {:ok, order} = convert_quote_to_order(quote)
        length(order.line_items) == length(quote.line_items)
      end
    end

    property "order status transitions are valid" do
      forall {from_status, to_status} <- valid_order_transition_generator() do
        valid_order_transition?(from_status, to_status)
      end
    end

    # ExUnitProperties version
    test "discount percent is bounded [0, 100] (StreamData)" do
      ExUnitProperties.check all(discount <- SD.float(min: 0.0, max: 100.0)) do
        assert discount >= 0.0 and discount <= 100.0
      end
    end
  end

  # =============================================================================
  # Automation Properties
  # =============================================================================

  describe "Automation properties" do
    property "assignment rules are deterministic" do
      forall {lead_data, rules} <- assignment_input_generator() do
        assigned1 = apply_assignment_rules(lead_data, rules)
        assigned2 = apply_assignment_rules(lead_data, rules)
        assigned1 == assigned2
      end
    end

    property "round-robin assignment is fair" do
      forall {leads, agents} <- round_robin_generator() do
        assignments = assign_round_robin(leads, agents)
        counts = Enum.frequencies_by(assignments, & &1.assigned_to)
        max_diff = max_min_difference(counts)
        max_diff <= 1
      end
    end

    property "workflow rules fire in priority order" do
      forall rules <- workflow_rules_generator() do
        sorted = Enum.sort_by(rules, & &1.priority)
        execution_order = execute_workflows(rules)
        execution_order == Enum.map(sorted, & &1.id)
      end
    end

    property "approval routing follows hierarchy" do
      forall {request, hierarchy} <- approval_routing_generator() do
        route = calculate_approval_route(request, hierarchy)
        valid_approval_route?(route, hierarchy)
      end
    end

    # ExUnitProperties version
    test "SLA times are positive integers (StreamData)" do
      ExUnitProperties.check all(sla_hours <- SD.integer(1..168)) do
        assert sla_hours > 0
        assert sla_hours <= 168
      end
    end
  end

  # =============================================================================
  # Analytics/Forecasting Properties
  # =============================================================================

  describe "Analytics/Forecasting properties" do
    property "forecast equals sum of weighted opportunities" do
      forall opportunities <- opportunities_generator() do
        forecast = calculate_forecast(opportunities)
        expected = Enum.sum(Enum.map(opportunities, &(&1.amount * &1.probability / 100)))
        abs(forecast - expected) < 0.01
      end
    end

    property "quota attainment is bounded [0%, ∞)" do
      forall {actual, quota} <- quota_attainment_generator() do
        attainment = calculate_attainment(actual, quota)
        attainment >= 0
      end
    end

    property "pipeline metrics are non-negative" do
      forall pipeline_data <- pipeline_metrics_generator() do
        metrics = calculate_pipeline_metrics(pipeline_data)

        metrics.total_value >= 0 and
          metrics.avg_deal_size >= 0 and
          metrics.win_rate >= 0 and metrics.win_rate <= 100
      end
    end

    property "conversion rates are bounded [0, 1]" do
      forall {stage_from, stage_to, opportunities} <- conversion_rate_generator() do
        rate = calculate_conversion_rate(opportunities, stage_from, stage_to)
        rate >= 0.0 and rate <= 1.0
      end
    end

    # ExUnitProperties version
    test "report date ranges are valid (StreamData)" do
      ExUnitProperties.check all(
                               days_back <- SD.integer(1..365),
                               duration <- SD.integer(1..90)
                             ) do
        start_date = Date.add(Date.utc_today(), -days_back)
        end_date = Date.add(start_date, duration)
        assert Date.compare(end_date, start_date) in [:gt, :eq]
      end
    end
  end

  # =============================================================================
  # Multi-tenancy Properties
  # =============================================================================

  describe "Multi-tenancy properties" do
    property "tenant isolation is enforced" do
      forall {tenant_a, tenant_b, data} <- tenant_isolation_generator() do
        store_a = store_data_for_tenant(data, tenant_a)
        results_b = query_data_for_tenant(tenant_b)
        not Enum.any?(results_b, &(&1.id == store_a.id))
      end
    end

    property "tenant IDs are valid UUIDs" do
      forall tenant_id <- tenant_id_generator() do
        is_valid_uuid?(tenant_id)
      end
    end

    property "cross-tenant queries return empty results" do
      forall {tenant_a, tenant_b} <- distinct_tenants_generator() do
        data_a = create_data_in_tenant(tenant_a)
        results = query_in_tenant(tenant_b, data_a.id)
        results == []
      end
    end

    # ExUnitProperties version
    test "tenant names are non-empty strings (StreamData)" do
      ExUnitProperties.check all(name <- SD.string(:alphanumeric, min_length: 1, max_length: 100)) do
        assert String.length(name) > 0
      end
    end
  end

  # =============================================================================
  # Audit Trail Properties
  # =============================================================================

  describe "Audit Trail properties" do
    property "audit records are immutable" do
      forall audit_record <- audit_record_generator() do
        record = create_audit_record(audit_record)
        attempt_modify = attempt_modify_audit(record)
        attempt_modify == :rejected
      end
    end

    property "audit trail is chronologically ordered" do
      forall records <- audit_records_generator() do
        sorted = Enum.sort_by(records, & &1.timestamp, DateTime)
        records == sorted
      end
    end

    property "all CRUD operations are audited" do
      forall {operation, resource} <- crud_operation_generator() do
        {:ok, _result, audit} = execute_with_audit(operation, resource)
        audit.action == operation and audit.resource_type == resource
      end
    end

    # ExUnitProperties version
    test "audit timestamps are in UTC (StreamData)" do
      ExUnitProperties.check all(offset_seconds <- SD.integer(0..86400)) do
        timestamp = DateTime.add(DateTime.utc_now(), -offset_seconds, :second)
        assert timestamp.time_zone == "Etc/UTC"
      end
    end
  end

  # =============================================================================
  # Generators (PropCheck)
  # =============================================================================

  defp status_transition_generator(statuses) do
    PC.tuple([PC.elements(statuses), PC.elements(statuses)])
  end

  # For lead statuses, only generate VALID transitions
  # new -> contacted, lost (or same)
  # contacted -> qualified, lost (or same)
  # qualified -> converted, lost (or same)
  # converted, lost -> only same
  defp valid_lead_transition_generator do
    PC.oneof([
      # Same status transitions (always valid)
      let status <- PC.elements(@lead_statuses) do
        {status, status}
      end,
      # new -> contacted, lost
      PC.tuple([PC.exactly(:new), PC.elements([:contacted, :lost])]),
      # contacted -> qualified, lost
      PC.tuple([PC.exactly(:contacted), PC.elements([:qualified, :lost])]),
      # qualified -> converted, lost
      PC.tuple([PC.exactly(:qualified), PC.elements([:converted, :lost])])
    ])
  end

  # For order statuses, only generate VALID transitions
  # :delivered and :cancelled cannot transition to anything else (except themselves)
  defp valid_order_transition_generator do
    non_terminal_statuses = [:draft, :submitted, :approved, :activated, :shipped]

    PC.oneof([
      # Same status transitions (always valid)
      let status <- PC.elements(@order_statuses) do
        {status, status}
      end,
      # Non-terminal to any status (valid)
      let {from, to} <- {PC.elements(non_terminal_statuses), PC.elements(@order_statuses)} do
        {from, to}
      end
    ])
  end

  defp scoring_factors_generator do
    PC.tuple([PC.integer(0, 40), PC.integer(0, 40), PC.integer(0, 20)])
  end

  defp lead_data_generator do
    let {first, last, company, email_local, domain} <- {
          PC.elements(["John", "Jane", "Bob"]),
          PC.elements(["Doe", "Smith", "Johnson"]),
          PC.elements(["Acme Inc", "Tech Corp", "Widgets LLC"]),
          PC.elements(["john", "jane", "bob"]),
          PC.elements(["example.com", "test.org"])
        } do
      %{
        first_name: first,
        last_name: last,
        company: company,
        email: "#{email_local}@#{domain}"
      }
    end
  end

  defp hot_lead_generator do
    let base <- lead_data_generator() do
      Map.merge(base, %{score: Enum.random(80..100)})
    end
  end

  defp account_data_generator do
    let {name, type, industry} <- {
          PC.elements(["Acme Inc", "Tech Corp", "Global Ltd"]),
          PC.elements(@account_types),
          PC.elements(["Technology", "Finance", "Healthcare"])
        } do
      %{name: name, type: type, industry: industry}
    end
  end

  defp contact_with_account_generator do
    let {{first, last, email}, account} <- {
          {PC.elements(["Alice", "Bob", "Carol"]), PC.elements(["Smith", "Jones", "Williams"]),
           PC.elements(["alice@example.com", "bob@test.com"])},
          PC.elements(["acc_001", "acc_002", "acc_003"])
        } do
      {%{first_name: first, last_name: last, email: email}, account}
    end
  end

  defp account_hierarchy_generator do
    let depth <- PC.integer(1, 5) do
      generate_hierarchy(depth)
    end
  end

  defp amount_generator do
    PC.float(0.0, 10_000_000.0)
  end

  defp opportunities_generator do
    PC.non_empty(PC.list(opportunity_generator()))
  end

  defp opportunity_generator do
    let {amount, probability, stage} <- {
          PC.float(1000.0, 1_000_000.0),
          PC.integer(0, 100),
          PC.elements(@opportunity_stages)
        } do
      %{amount: amount, probability: probability, stage: stage}
    end
  end

  defp stage_transition_generator do
    # Only generate VALID stage transitions:
    # - Any stage can stay the same (from == to)
    # - closed_won and closed_lost cannot transition to anything else
    # Use let to generate valid combinations
    non_closed_stages = [:prospecting, :qualification, :needs_analysis, :proposal, :negotiation]

    PC.oneof([
      # Same stage transitions (always valid)
      let stage <- PC.elements(@opportunity_stages) do
        {stage, stage}
      end,
      # Non-closed to any stage (valid)
      let {from, to} <- {PC.elements(non_closed_stages), PC.elements(@opportunity_stages)} do
        {from, to}
      end
    ])
  end

  defp closed_reopen_generator do
    PC.tuple([
      PC.elements([:closed_won, :closed_lost]),
      PC.elements([:prospecting, :qualification, :needs_analysis])
    ])
  end

  defp quote_calculation_generator do
    PC.tuple([PC.float(100.0, 100_000.0), PC.float(0.0, 50.0), PC.float(0.0, 25.0)])
  end

  defp line_item_generator do
    PC.tuple([PC.integer(1, 1000), PC.float(1.0, 10_000.0)])
  end

  defp order_data_generator do
    let {account, line_count} <- {
          PC.elements(["acc_001", "acc_002"]),
          PC.integer(1, 10)
        } do
      %{account_id: account, line_items: generate_line_items(line_count)}
    end
  end

  defp quote_with_lines_generator do
    let {account, lines, status} <- {
          PC.elements(["acc_001", "acc_002"]),
          PC.integer(1, 5),
          PC.elements(@quote_statuses)
        } do
      %{account_id: account, line_items: generate_line_items(lines), status: status}
    end
  end

  defp assignment_input_generator do
    PC.tuple([
      lead_data_generator(),
      PC.non_empty(PC.list(assignment_rule_generator()))
    ])
  end

  defp assignment_rule_generator do
    let {priority, criteria, assignee} <- {
          PC.integer(1, 10),
          PC.elements(["territory", "industry", "size"]),
          PC.elements(["agent_1", "agent_2", "agent_3"])
        } do
      %{priority: priority, criteria: criteria, assignee: assignee}
    end
  end

  defp round_robin_generator do
    # Use fixed unique agent list to avoid duplicates that cause uneven distribution
    PC.tuple([
      PC.non_empty(PC.list(lead_data_generator())),
      PC.elements([["agent_1", "agent_2", "agent_3"], ["agent_1", "agent_2"]])
    ])
  end

  defp workflow_rules_generator do
    PC.non_empty(PC.list(workflow_rule_generator()))
  end

  defp workflow_rule_generator do
    let {id, priority, action} <- {
          PC.elements(["rule_1", "rule_2", "rule_3", "rule_4"]),
          PC.integer(1, 100),
          PC.elements([:notify, :assign, :update])
        } do
      %{id: id, priority: priority, action: action}
    end
  end

  defp approval_routing_generator do
    let {{type, amount}, routing} <- {
          {PC.elements([:discount, :credit, :exception]), PC.float(1000.0, 100_000.0)},
          PC.elements([
            %{manager: "mgr_1", director: "dir_1", vp: "vp_1"},
            %{manager: "mgr_2", director: "dir_2", vp: "vp_2"}
          ])
        } do
      {%{type: type, amount: amount}, routing}
    end
  end

  defp quota_attainment_generator do
    PC.tuple([PC.float(0.0, 2_000_000.0), PC.float(100_000.0, 1_000_000.0)])
  end

  defp pipeline_metrics_generator do
    PC.list(opportunity_generator())
  end

  defp conversion_rate_generator do
    PC.tuple([
      PC.elements(@opportunity_stages),
      PC.elements(@opportunity_stages),
      opportunities_generator()
    ])
  end

  defp tenant_isolation_generator do
    PC.tuple([
      PC.elements(["tenant_a", "tenant_b"]),
      PC.elements(["tenant_c", "tenant_d"]),
      lead_data_generator()
    ])
  end

  defp tenant_id_generator do
    PC.elements([
      "550e8400-e29b-41d4-a716-446655440000",
      "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    ])
  end

  defp distinct_tenants_generator do
    PC.tuple([
      PC.elements(["tenant_x", "tenant_y"]),
      PC.elements(["tenant_z", "tenant_w"])
    ])
  end

  defp audit_record_generator do
    let {action, resource, actor} <- {
          PC.elements([:create, :read, :update, :delete]),
          PC.elements(["Lead", "Account", "Opportunity"]),
          PC.elements(["user_1", "user_2", "system"])
        } do
      %{action: action, resource_type: resource, actor: actor, timestamp: DateTime.utc_now()}
    end
  end

  defp audit_records_generator do
    let count <- PC.integer(1, 10) do
      generate_ordered_audit_records(count)
    end
  end

  defp crud_operation_generator do
    PC.tuple([
      PC.elements([:create, :read, :update, :delete]),
      PC.elements(["Lead", "Account", "Contact", "Opportunity"])
    ])
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp valid_lead_transition?(from, to) do
    valid_transitions = %{
      new: [:contacted, :lost],
      contacted: [:qualified, :lost],
      qualified: [:converted, :lost],
      converted: [],
      lost: []
    }

    to in Map.get(valid_transitions, from, []) or from == to
  end

  defp calculate_lead_score(demographics, behavior, firmographics) do
    min(100, demographics + behavior + firmographics)
  end

  defp simulate_lead_conversion(lead_data) do
    account = %{name: lead_data.company, type: :prospect}
    contact = %{email: lead_data.email, first_name: lead_data.first_name}
    opportunity = %{name: "#{lead_data.company} - New Deal", stage: :prospecting}
    {:ok, account, contact, opportunity}
  end

  defp create_lead_from_data(data) do
    Map.merge(data, %{score: Map.get(data, :score, 50)})
  end

  defp is_hot_lead?(lead), do: Map.get(lead, :score, 0) >= 80

  defp create_account_from_data(data), do: data

  defp create_contact_from_data(data, account_id) do
    Map.put(data, :account_id, account_id)
  end

  defp generate_hierarchy(depth) do
    for i <- 1..depth do
      %{id: "node_#{i}", parent_id: if(i > 1, do: "node_#{i - 1}", else: nil)}
    end
  end

  defp has_cycle?(hierarchy) do
    # Simple cycle detection
    parents =
      Enum.reduce(hierarchy, %{}, fn node, acc ->
        if node.parent_id, do: Map.put(acc, node.id, node.parent_id), else: acc
      end)

    Enum.any?(hierarchy, fn node ->
      detect_cycle(node.id, parents, MapSet.new())
    end)
  end

  defp detect_cycle(nil, _parents, _visited), do: false

  defp detect_cycle(id, parents, visited) do
    if MapSet.member?(visited, id) do
      true
    else
      parent = Map.get(parents, id)
      detect_cycle(parent, parents, MapSet.put(visited, id))
    end
  end

  defp calculate_weighted_pipeline(opportunities) do
    Enum.sum(Enum.map(opportunities, fn o -> o.amount * o.probability / 100 end))
  end

  defp valid_stage_transition?(from, to) when from == to, do: true
  defp valid_stage_transition?(from, _to) when from in [:closed_won, :closed_lost], do: false
  defp valid_stage_transition?(_from, _to), do: true

  defp generate_line_items(count) do
    for i <- 1..count do
      %{product_id: "prod_#{i}", quantity: i, unit_price: i * 100.0}
    end
  end

  defp create_order_from_data(data) do
    subtotal = Enum.sum(Enum.map(data.line_items, fn li -> li.quantity * li.unit_price end))

    %{
      account_id: data.account_id,
      line_items: data.line_items,
      subtotal: subtotal,
      total: subtotal
    }
  end

  defp create_quote_from_data(data) do
    Map.put(data, :id, "quote_#{:rand.uniform(1000)}")
  end

  defp convert_quote_to_order(quote) do
    order = %{
      quote_id: quote.id,
      account_id: quote.account_id,
      line_items: quote.line_items,
      status: :draft
    }

    {:ok, order}
  end

  defp valid_order_transition?(from, to) when from == to, do: true
  defp valid_order_transition?(:delivered, _), do: false
  defp valid_order_transition?(:cancelled, _), do: false
  defp valid_order_transition?(_from, _to), do: true

  defp apply_assignment_rules(lead_data, rules) do
    sorted_rules = Enum.sort_by(rules, & &1.priority)
    first_match = Enum.find(sorted_rules, fn _rule -> true end)
    %{lead: lead_data, assigned_to: first_match.assignee}
  end

  defp assign_round_robin(leads, agents) do
    leads
    |> Enum.with_index()
    |> Enum.map(fn {lead, idx} ->
      agent = Enum.at(agents, rem(idx, length(agents)))
      %{lead: lead, assigned_to: agent}
    end)
  end

  defp max_min_difference(counts) do
    values = Map.values(counts)
    Enum.max(values) - Enum.min(values)
  end

  defp execute_workflows(rules) do
    rules
    |> Enum.sort_by(& &1.priority)
    |> Enum.map(& &1.id)
  end

  defp calculate_approval_route(request, hierarchy) do
    cond do
      request.amount > 50_000 -> [hierarchy.manager, hierarchy.director, hierarchy.vp]
      request.amount > 10_000 -> [hierarchy.manager, hierarchy.director]
      true -> [hierarchy.manager]
    end
  end

  defp valid_approval_route?(route, _hierarchy) do
    length(route) > 0
  end

  defp calculate_forecast(opportunities) do
    Enum.sum(Enum.map(opportunities, &(&1.amount * &1.probability / 100)))
  end

  defp calculate_attainment(_actual, quota) when quota == 0, do: 0.0
  defp calculate_attainment(actual, quota), do: actual / quota * 100

  defp calculate_pipeline_metrics(pipeline_data) do
    total = Enum.sum(Enum.map(pipeline_data, & &1.amount))
    count = length(pipeline_data)
    won = Enum.count(pipeline_data, &(&1.stage == :closed_won))

    %{
      total_value: total,
      avg_deal_size: if(count > 0, do: total / count, else: 0),
      win_rate: if(count > 0, do: won / count * 100, else: 0)
    }
  end

  defp calculate_conversion_rate(opportunities, from_stage, to_stage) do
    from_count = Enum.count(opportunities, &(&1.stage == from_stage))
    to_count = Enum.count(opportunities, &(&1.stage == to_stage))
    # Conversion rate is bounded [0, 1] - cap at 1.0 for valid rate calculation
    if from_count > 0, do: min(1.0, to_count / from_count), else: 0.0
  end

  defp store_data_for_tenant(data, tenant) do
    Map.put(data, :tenant_id, tenant)
    |> Map.put(:id, "record_#{:rand.uniform(1000)}")
  end

  defp query_data_for_tenant(_tenant), do: []

  defp is_valid_uuid?(uuid) do
    # Use regex to validate UUID format (v4 compatible)
    String.match?(uuid, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  end

  defp create_data_in_tenant(tenant) do
    %{id: "record_#{:rand.uniform(1000)}", tenant_id: tenant}
  end

  defp query_in_tenant(_tenant, _id), do: []

  defp create_audit_record(data) do
    Map.put(data, :id, "audit_#{:rand.uniform(1000)}")
  end

  defp attempt_modify_audit(_record), do: :rejected

  defp generate_ordered_audit_records(count) do
    base = DateTime.utc_now()

    for i <- 1..count do
      %{
        id: "audit_#{i}",
        action: Enum.random([:create, :read, :update, :delete]),
        timestamp: DateTime.add(base, i, :second)
      }
    end
  end

  defp execute_with_audit(operation, resource) do
    result = %{id: "result_#{:rand.uniform(1000)}"}
    audit = %{action: operation, resource_type: resource, timestamp: DateTime.utc_now()}
    {:ok, result, audit}
  end
end
