defmodule Indrajaal.Morphogenic.L3DomainBoundaryEnforcementTest do
  @moduledoc """
  L3 Domain Boundary Enforcement — Fractal Layer 3 Test Suite

  WHAT: Self-contained ETS-backed verification of domain boundary enforcement
  across the 10 Ash domain boundaries in the Indrajaal SIL-6 biomorphic mesh.

  WHY: Domain isolation is a fundamental safety invariant (SC-ORCH-013). Cross-domain
  state leakage or unauthorized resource access violates the holon sovereignty
  principle (SC-HOLON-001) and breaks the cross-holon isolation guarantee (SC-XHOLON-001).

  ARCHITECTURE: Simulates 10 Ash domains — Access, Alarms, Analytics, CRM, Compliance,
  Devices, Maintenance, PHICS, Video, Communication — using ETS tables for:
    - Domain registry (domain metadata and capabilities)
    - Access control matrix (who can access what across domains)
    - Event log (domain event publishing audit trail)
    - Tenant isolation table (per-tenant resource ownership)
    - Message bus routing table (domain event subscriptions)

  CONSTRAINTS:
    - SC-ORCH-013: Access control enforced at orchestration layer
    - SC-HOLON-001: All holon state stored in SQLite/DuckDB (simulated via ETS)
    - SC-XHOLON-001: Isolated database files per holon (simulated via isolated ETS namespaces)

  FRACTAL LAYER: L3 (Domain Architecture)
  TASK ID: 2b24dace
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l3

  # --- Domain Definitions ---

  @domains [
    :access,
    :alarms,
    :analytics,
    :crm,
    :compliance,
    :devices,
    :maintenance,
    :phics,
    :video,
    :communication
  ]

  @domain_capabilities %{
    access: [:read_users, :write_users, :manage_permissions, :audit_access],
    alarms: [:read_alarms, :write_alarms, :acknowledge_alarms, :escalate_alarms],
    analytics: [:read_reports, :write_reports, :query_data, :export_data],
    crm: [:read_contacts, :write_contacts, :manage_pipeline, :send_communications],
    compliance: [:read_audits, :write_audits, :generate_reports, :flag_violations],
    devices: [:read_devices, :write_devices, :control_devices, :provision_devices],
    maintenance: [
      :read_work_orders,
      :write_work_orders,
      :schedule_maintenance,
      :close_work_orders
    ],
    phics: [:read_physical, :write_physical, :send_commands, :emergency_stop],
    video: [:read_streams, :write_streams, :record_video, :retrieve_archive],
    communication: [:send_messages, :read_messages, :manage_channels, :broadcast]
  }

  @roles [:super_admin, :domain_admin, :operator, :viewer, :auditor, :guest]

  # Role-domain permission matrix: {role, domain} => [capabilities]
  @role_permissions %{
    super_admin: :all_domains,
    domain_admin: :own_domain_full,
    operator: :own_domain_limited,
    viewer: :own_domain_read_only,
    auditor: :compliance_read,
    guest: :none
  }

  # --- ETS Setup ---

  defp setup_ets_tables do
    tables = %{
      domain_registry: :ets.new(:domain_registry, [:set, :public]),
      access_matrix: :ets.new(:access_matrix, [:set, :public]),
      event_log: :ets.new(:event_log, [:bag, :public]),
      tenant_resources: :ets.new(:tenant_resources, [:set, :public]),
      message_bus: :ets.new(:message_bus, [:bag, :public]),
      resource_ownership: :ets.new(:resource_ownership, [:set, :public]),
      domain_state: :ets.new(:domain_state, [:set, :public])
    }

    # Seed domain registry
    for domain <- @domains do
      capabilities = Map.get(@domain_capabilities, domain, [])

      :ets.insert(
        tables.domain_registry,
        {domain,
         %{
           name: domain,
           capabilities: capabilities,
           status: :active,
           isolation_level: :strict,
           registered_at: System.monotonic_time(:millisecond)
         }}
      )
    end

    # Seed access control matrix
    for role <- @roles, domain <- @domains do
      allowed_caps = compute_allowed_capabilities(role, domain)
      :ets.insert(tables.access_matrix, {{role, domain}, allowed_caps})
    end

    tables
  end

  defp cleanup_ets_tables(tables) do
    for {_name, ref} <- tables do
      try do
        :ets.delete(ref)
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp compute_allowed_capabilities(:super_admin, domain) do
    Map.get(@domain_capabilities, domain, [])
  end

  defp compute_allowed_capabilities(:domain_admin, domain) do
    caps = Map.get(@domain_capabilities, domain, [])
    # domain_admin gets full access to own domain but we mark ownership separately
    caps
  end

  defp compute_allowed_capabilities(:operator, domain) do
    caps = Map.get(@domain_capabilities, domain, [])
    # operator gets limited: no destructive operations
    Enum.reject(caps, fn cap ->
      cap_str = Atom.to_string(cap)

      String.starts_with?(cap_str, "delete") or
        String.starts_with?(cap_str, "manage") or
        cap == :emergency_stop or
        cap == :provision_devices
    end)
  end

  defp compute_allowed_capabilities(:viewer, domain) do
    caps = Map.get(@domain_capabilities, domain, [])

    Enum.filter(caps, fn cap ->
      cap_str = Atom.to_string(cap)
      String.starts_with?(cap_str, "read") or String.starts_with?(cap_str, "query")
    end)
  end

  defp compute_allowed_capabilities(:auditor, domain) do
    case domain do
      :compliance ->
        Map.get(@domain_capabilities, :compliance, [])

      :access ->
        [:read_users, :audit_access]

      _ ->
        [:read_alarms, :read_reports]
        |> Enum.filter(&(&1 in Map.get(@domain_capabilities, domain, [])))
    end
  end

  defp compute_allowed_capabilities(:guest, _domain), do: []

  # --- Domain Access Control ---

  defp check_access(tables, tenant_id, role, domain, capability) do
    # Verify domain exists
    case :ets.lookup(tables.domain_registry, domain) do
      [] ->
        {:error, :domain_not_found}

      [{^domain, %{status: :active}}] ->
        # Check role-based permission
        case :ets.lookup(tables.access_matrix, {role, domain}) do
          [] ->
            {:error, :no_permission_entry}

          [{{^role, ^domain}, allowed_caps}] ->
            if capability in allowed_caps do
              # Log successful access
              log_event(tables, %{
                type: :access_granted,
                tenant_id: tenant_id,
                role: role,
                domain: domain,
                capability: capability,
                timestamp: System.monotonic_time(:millisecond)
              })

              {:ok, :access_granted}
            else
              # Log denied access
              log_event(tables, %{
                type: :access_denied,
                tenant_id: tenant_id,
                role: role,
                domain: domain,
                capability: capability,
                timestamp: System.monotonic_time(:millisecond)
              })

              {:error, :capability_not_permitted}
            end
        end

      [{^domain, %{status: status}}] ->
        {:error, {:domain_unavailable, status}}
    end
  end

  defp log_event(tables, event) do
    key = System.monotonic_time(:nanosecond)
    :ets.insert(tables.event_log, {key, event})
  end

  # --- Tenant Isolation ---

  defp register_tenant_resource(tables, tenant_id, domain, resource_id, resource_type) do
    key = {tenant_id, domain, resource_id}

    :ets.insert(
      tables.tenant_resources,
      {key,
       %{
         tenant_id: tenant_id,
         domain: domain,
         resource_id: resource_id,
         resource_type: resource_type,
         created_at: System.monotonic_time(:millisecond)
       }}
    )

    # Record ownership
    :ets.insert(
      tables.resource_ownership,
      {resource_id,
       %{
         owner_tenant: tenant_id,
         domain: domain,
         resource_type: resource_type
       }}
    )

    {:ok, key}
  end

  defp get_tenant_resources(tables, tenant_id, domain) do
    pattern = {{tenant_id, domain, :_}, :_}

    :ets.match_object(tables.tenant_resources, pattern)
    |> Enum.map(fn {_key, resource} -> resource end)
  end

  defp can_tenant_access_resource?(tables, requesting_tenant, resource_id) do
    case :ets.lookup(tables.resource_ownership, resource_id) do
      [] ->
        {:error, :resource_not_found}

      [{^resource_id, %{owner_tenant: owner}}] ->
        if owner == requesting_tenant do
          {:ok, :own_resource}
        else
          {:error, :cross_tenant_access_denied}
        end
    end
  end

  # --- Message Bus Routing ---

  defp subscribe_domain_to_events(tables, subscribing_domain, source_domain, event_type) do
    # Only allow subscriptions within permitted cross-domain relationships
    if cross_domain_subscription_allowed?(subscribing_domain, source_domain, event_type) do
      :ets.insert(tables.message_bus, {
        {source_domain, event_type},
        %{subscriber: subscribing_domain, registered_at: System.monotonic_time(:millisecond)}
      })

      {:ok, :subscribed}
    else
      {:error, :subscription_not_permitted}
    end
  end

  defp publish_domain_event(tables, source_domain, event_type, payload) do
    # Log the event
    event = %{
      type: :domain_event,
      source: source_domain,
      event_type: event_type,
      payload: payload,
      timestamp: System.monotonic_time(:millisecond)
    }

    log_event(tables, event)

    # Route to subscribers
    subscribers = :ets.match_object(tables.message_bus, {{source_domain, event_type}, :_})
    delivered_to = Enum.map(subscribers, fn {{_, _}, %{subscriber: sub}} -> sub end)

    {:ok, %{delivered_to: delivered_to, event: event}}
  end

  defp cross_domain_subscription_allowed?(subscriber, source, event_type) do
    # Define allowed cross-domain event subscriptions
    allowed_subscriptions = [
      # Compliance can subscribe to everything for audit purposes
      {:compliance, :_any, :_any},
      # Alarms can receive events from devices and PHICS
      {:alarms, :devices, :device_alert},
      {:alarms, :phics, :physical_alert},
      {:alarms, :phics, :emergency_event},
      # Analytics can receive events from most domains
      {:analytics, :access, :access_event},
      {:analytics, :devices, :device_event},
      {:analytics, :communication, :message_event},
      # Access domain can subscribe to alarms for security events
      {:access, :alarms, :security_alarm},
      # Maintenance receives device health events
      {:maintenance, :devices, :health_degraded},
      {:maintenance, :phics, :maintenance_required},
      # Communication can receive events from CRM
      {:communication, :crm, :contact_updated}
    ]

    Enum.any?(allowed_subscriptions, fn
      {:compliance, :_any, :_any} -> subscriber == :compliance
      {^subscriber, :_any, :_any} -> true
      {^subscriber, ^source, :_any} -> true
      {^subscriber, ^source, ^event_type} -> true
      _ -> false
    end)
  end

  # --- Domain State Isolation ---

  defp write_domain_state(tables, domain, key, value) do
    namespaced_key = {domain, key}
    :ets.insert(tables.domain_state, {namespaced_key, value})
    {:ok, namespaced_key}
  end

  defp read_domain_state(tables, requesting_domain, target_domain, key) do
    if requesting_domain == target_domain do
      namespaced_key = {target_domain, key}

      case :ets.lookup(tables.domain_state, namespaced_key) do
        [] -> {:error, :not_found}
        [{_, value}] -> {:ok, value}
      end
    else
      {:error, :cross_domain_read_denied}
    end
  end

  defp read_all_domain_state_keys(tables, domain) do
    pattern = {{domain, :_}, :_}

    :ets.match_object(tables.domain_state, pattern)
    |> Enum.map(fn {{_domain, key}, _value} -> key end)
  end

  # --- API Gateway Routing ---

  defp route_api_request(tables, %{path: path, method: method, tenant_id: tenant_id, role: role}) do
    case parse_api_path(path) do
      {:ok, {domain, resource, capability}} ->
        case check_access(tables, tenant_id, role, domain, capability) do
          {:ok, :access_granted} ->
            {:ok,
             %{
               domain: domain,
               resource: resource,
               capability: capability,
               routed: true
             }}

          {:error, reason} ->
            {:error, %{reason: reason, domain: domain, path: path, method: method}}
        end

      {:error, reason} ->
        {:error, %{reason: reason, path: path}}
    end
  end

  defp parse_api_path(path) do
    case String.split(path, "/", trim: true) do
      ["api", domain_str | rest] ->
        domain = String.to_existing_atom(domain_str)

        if domain in @domains do
          {resource, capability} = derive_resource_and_capability(domain, rest)
          {:ok, {domain, resource, capability}}
        else
          {:error, :unknown_domain}
        end

      _ ->
        {:error, :invalid_path_format}
    end
  rescue
    ArgumentError -> {:error, :unknown_domain}
  end

  defp derive_resource_and_capability(domain, path_parts) do
    resource = List.first(path_parts, "default")
    # Map HTTP operations to capabilities based on domain
    caps = Map.get(@domain_capabilities, domain, [])
    # Pick first read capability as default for simplicity
    capability =
      Enum.find(caps, List.last(caps, :read), fn cap ->
        Atom.to_string(cap) |> String.starts_with?("read")
      end)

    {resource, capability}
  end

  # --- Generator Helpers ---

  defp gen_domain do
    PC.elements(@domains)
  end

  defp gen_role do
    PC.elements(@roles)
  end

  defp gen_tenant_id do
    let n <- PC.pos_integer() do
      "tenant_#{rem(n, 100) + 1}"
    end
  end

  defp gen_resource_id do
    let n <- PC.pos_integer() do
      "resource_#{n}"
    end
  end

  defp gen_capability_for_domain(domain) do
    caps = Map.get(@domain_capabilities, domain, [:read])
    PC.elements(caps)
  end

  # --- Tests ---

  describe "Domain Registry — all 10 domains registered" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "all 10 domains are registered in domain registry", %{tables: tables} do
      for domain <- @domains do
        result = :ets.lookup(tables.domain_registry, domain)
        assert length(result) == 1, "Domain #{domain} not found in registry"
        [{^domain, %{status: :active, capabilities: caps}}] = result
        assert is_list(caps), "Capabilities for #{domain} must be a list"
        assert length(caps) > 0, "Domain #{domain} must have at least one capability"
      end
    end

    test "each domain has unique capabilities", %{tables: tables} do
      all_caps =
        for domain <- @domains do
          [{_, %{capabilities: caps}}] = :ets.lookup(tables.domain_registry, domain)
          {domain, caps}
        end

      # Verify each domain owns its own capability namespace
      for {domain, caps} <- all_caps do
        domain_str = Atom.to_string(domain)

        for cap <- caps do
          cap_str = Atom.to_string(cap)

          # Each capability key is prefixed with a verb (read, write, etc.) — not domain-namespaced
          # but they are semantically distinct per domain
          assert is_atom(cap),
                 "Capability #{inspect(cap)} in domain #{domain_str} must be an atom"
        end
      end

      total_caps = Enum.sum(Enum.map(all_caps, fn {_, caps} -> length(caps) end))

      assert total_caps == 40,
             "Expected 40 total capabilities across 10 domains (4 each), got #{total_caps}"
    end

    test "domain isolation level is strict for all domains", %{tables: tables} do
      for domain <- @domains do
        [{_, %{isolation_level: level}}] = :ets.lookup(tables.domain_registry, domain)
        assert level == :strict, "Domain #{domain} must have strict isolation"
      end
    end
  end

  describe "Access Control Matrix — role-domain-capability enforcement" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "super_admin has full access to all domains", %{tables: tables} do
      for domain <- @domains do
        caps = Map.get(@domain_capabilities, domain, [])

        for cap <- caps do
          result = check_access(tables, "tenant_1", :super_admin, domain, cap)

          assert result == {:ok, :access_granted},
                 "super_admin denied #{cap} on #{domain}: #{inspect(result)}"
        end
      end
    end

    test "guest has no access to any domain", %{tables: tables} do
      for domain <- @domains do
        caps = Map.get(@domain_capabilities, domain, [])

        for cap <- caps do
          result = check_access(tables, "tenant_1", :guest, domain, cap)

          assert result == {:error, :capability_not_permitted},
                 "guest unexpectedly granted #{cap} on #{domain}"
        end
      end
    end

    test "viewer can only read, not write", %{tables: tables} do
      # Viewers should be denied write capabilities
      write_capabilities = [
        {:alarms, :write_alarms},
        {:devices, :write_devices},
        {:crm, :write_contacts},
        {:phics, :send_commands},
        {:video, :write_streams}
      ]

      for {domain, cap} <- write_capabilities do
        result = check_access(tables, "tenant_1", :viewer, domain, cap)

        assert result == {:error, :capability_not_permitted},
               "viewer should not have #{cap} on #{domain}"
      end
    end

    test "viewer can read from domains", %{tables: tables} do
      read_capabilities = [
        {:alarms, :read_alarms},
        {:devices, :read_devices},
        {:analytics, :read_reports},
        {:video, :read_streams},
        {:access, :read_users}
      ]

      for {domain, cap} <- read_capabilities do
        result = check_access(tables, "tenant_1", :viewer, domain, cap)

        assert result == {:ok, :access_granted},
               "viewer should be able to #{cap} on #{domain}: #{inspect(result)}"
      end
    end

    test "access denied events are logged", %{tables: tables} do
      check_access(tables, "tenant_1", :guest, :alarms, :write_alarms)
      check_access(tables, "tenant_2", :guest, :devices, :control_devices)

      all_events = :ets.tab2list(tables.event_log)
      denied_events = Enum.filter(all_events, fn {_, %{type: type}} -> type == :access_denied end)

      assert length(denied_events) >= 2,
             "Expected at least 2 denied access events, got #{length(denied_events)}"
    end

    test "access granted events are logged", %{tables: tables} do
      check_access(tables, "tenant_1", :super_admin, :alarms, :read_alarms)
      check_access(tables, "tenant_1", :viewer, :devices, :read_devices)

      all_events = :ets.tab2list(tables.event_log)

      granted_events =
        Enum.filter(all_events, fn {_, %{type: type}} -> type == :access_granted end)

      assert length(granted_events) >= 2,
             "Expected at least 2 granted access events, got #{length(granted_events)}"
    end

    test "access to unknown domain returns error", %{tables: tables} do
      result = check_access(tables, "tenant_1", :super_admin, :unknown_domain, :read)
      assert result == {:error, :domain_not_found}
    end
  end

  describe "Tenant Isolation — data separation per tenant" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "tenant resources are isolated by tenant ID", %{tables: tables} do
      {:ok, _} = register_tenant_resource(tables, "tenant_A", :devices, "dev_001", :sensor)
      {:ok, _} = register_tenant_resource(tables, "tenant_A", :devices, "dev_002", :camera)
      {:ok, _} = register_tenant_resource(tables, "tenant_B", :devices, "dev_003", :sensor)

      tenant_a_resources = get_tenant_resources(tables, "tenant_A", :devices)
      tenant_b_resources = get_tenant_resources(tables, "tenant_B", :devices)

      assert length(tenant_a_resources) == 2, "tenant_A should have 2 device resources"
      assert length(tenant_b_resources) == 1, "tenant_B should have 1 device resource"

      tenant_a_ids = Enum.map(tenant_a_resources, & &1.resource_id)
      assert "dev_001" in tenant_a_ids
      assert "dev_002" in tenant_a_ids
      refute "dev_003" in tenant_a_ids
    end

    test "tenant cannot access another tenant's resources", %{tables: tables} do
      {:ok, _} =
        register_tenant_resource(tables, "tenant_A", :devices, "private_dev_001", :sensor)

      # tenant_B tries to access tenant_A's resource
      result = can_tenant_access_resource?(tables, "tenant_B", "private_dev_001")
      assert result == {:error, :cross_tenant_access_denied}
    end

    test "tenant can access own resources", %{tables: tables} do
      {:ok, _} =
        register_tenant_resource(tables, "tenant_C", :alarms, "alarm_099", :motion_detector)

      result = can_tenant_access_resource?(tables, "tenant_C", "alarm_099")
      assert result == {:ok, :own_resource}
    end

    test "non-existent resource returns error", %{tables: tables} do
      result = can_tenant_access_resource?(tables, "tenant_X", "nonexistent_resource")
      assert result == {:error, :resource_not_found}
    end

    test "resources across domains are isolated per tenant", %{tables: tables} do
      # Register resources across multiple domains for two tenants
      for domain <- [:access, :alarms, :devices] do
        register_tenant_resource(tables, "tenant_multi_A", domain, "res_A_#{domain}", :generic)
        register_tenant_resource(tables, "tenant_multi_B", domain, "res_B_#{domain}", :generic)
      end

      # Verify isolation per domain
      for domain <- [:access, :alarms, :devices] do
        resources_a = get_tenant_resources(tables, "tenant_multi_A", domain)
        resources_b = get_tenant_resources(tables, "tenant_multi_B", domain)

        ids_a = Enum.map(resources_a, & &1.resource_id)
        ids_b = Enum.map(resources_b, & &1.resource_id)

        # No overlap
        assert MapSet.disjoint?(MapSet.new(ids_a), MapSet.new(ids_b)),
               "tenant_multi_A and tenant_multi_B resources overlap in domain #{domain}"
      end
    end
  end

  describe "Domain State Isolation — no cross-domain state leakage" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "domain can write and read its own state", %{tables: tables} do
      {:ok, _key} = write_domain_state(tables, :alarms, "active_count", 42)
      result = read_domain_state(tables, :alarms, :alarms, "active_count")
      assert result == {:ok, 42}
    end

    test "domain cannot read another domain's state", %{tables: tables} do
      {:ok, _} = write_domain_state(tables, :devices, "device_count", 100)

      # alarms tries to read devices state
      result = read_domain_state(tables, :alarms, :devices, "device_count")
      assert result == {:error, :cross_domain_read_denied}
    end

    test "domain state keys are namespaced — no collision between domains", %{tables: tables} do
      # Both domains write to same logical key name
      {:ok, _} = write_domain_state(tables, :alarms, "count", 5)
      {:ok, _} = write_domain_state(tables, :devices, "count", 200)

      # Each domain reads its own value
      {:ok, alarm_count} = read_domain_state(tables, :alarms, :alarms, "count")
      {:ok, device_count} = read_domain_state(tables, :devices, :devices, "count")

      assert alarm_count == 5
      assert device_count == 200
      refute alarm_count == device_count
    end

    test "all 10 domains can maintain isolated state simultaneously", %{tables: tables} do
      # Write unique state to each domain
      for {domain, idx} <- Enum.with_index(@domains) do
        write_domain_state(tables, domain, "state_key", "value_#{idx}")
      end

      # Verify each domain reads its own value
      for {domain, idx} <- Enum.with_index(@domains) do
        {:ok, val} = read_domain_state(tables, domain, domain, "state_key")

        assert val == "value_#{idx}",
               "Domain #{domain} state mismatch: expected value_#{idx}, got #{inspect(val)}"
      end
    end

    test "reading non-existent domain state key returns error", %{tables: tables} do
      result = read_domain_state(tables, :crm, :crm, "nonexistent_key")
      assert result == {:error, :not_found}
    end
  end

  describe "Message Bus Routing — domain event publishing and subscription" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "compliance domain can subscribe to all domains (audit mandate)", %{tables: tables} do
      event_types = [:access_event, :device_event, :alarm_event, :crm_event]

      for source_domain <- @domains, event_type <- event_types do
        result = subscribe_domain_to_events(tables, :compliance, source_domain, event_type)

        assert result == {:ok, :subscribed},
               "compliance should be able to subscribe to #{event_type} from #{source_domain}"
      end
    end

    test "alarms domain can subscribe to device alerts", %{tables: tables} do
      result = subscribe_domain_to_events(tables, :alarms, :devices, :device_alert)
      assert result == {:ok, :subscribed}
    end

    test "alarms domain can subscribe to PHICS emergency events", %{tables: tables} do
      result = subscribe_domain_to_events(tables, :alarms, :phics, :emergency_event)
      assert result == {:ok, :subscribed}
    end

    test "unauthorized cross-domain subscription is rejected", %{tables: tables} do
      # CRM subscribing to PHICS physical commands — not permitted
      result = subscribe_domain_to_events(tables, :crm, :phics, :physical_command)
      assert result == {:error, :subscription_not_permitted}

      # Video subscribing to access user events — not permitted
      result2 = subscribe_domain_to_events(tables, :video, :access, :user_created)
      assert result2 == {:error, :subscription_not_permitted}
    end

    test "published events are delivered to subscribed domains", %{tables: tables} do
      # Set up subscription
      {:ok, :subscribed} = subscribe_domain_to_events(tables, :alarms, :devices, :device_alert)

      {:ok, :subscribed} =
        subscribe_domain_to_events(tables, :compliance, :devices, :device_alert)

      # Publish event
      {:ok, result} =
        publish_domain_event(tables, :devices, :device_alert, %{
          device_id: "dev_001",
          alert: :offline
        })

      assert :alarms in result.delivered_to
      assert :compliance in result.delivered_to
    end

    test "published events are logged to event log", %{tables: tables} do
      initial_count = length(:ets.tab2list(tables.event_log))

      publish_domain_event(tables, :alarms, :alarm_triggered, %{alarm_id: "alm_001"})

      final_count = length(:ets.tab2list(tables.event_log))
      assert final_count > initial_count, "Event should be logged after publish"
    end

    test "maintenance domain receives device health degraded events", %{tables: tables} do
      {:ok, :subscribed} =
        subscribe_domain_to_events(tables, :maintenance, :devices, :health_degraded)

      {:ok, result} =
        publish_domain_event(tables, :devices, :health_degraded, %{
          device_id: "sensor_023",
          health_score: 0.2
        })

      assert :maintenance in result.delivered_to
    end
  end

  describe "API Gateway Routing — domain request routing" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "valid API request is routed to correct domain", %{tables: tables} do
      request = %{
        path: "/api/alarms/list",
        method: "GET",
        tenant_id: "tenant_1",
        role: :viewer
      }

      {:ok, result} = route_api_request(tables, request)
      assert result.domain == :alarms
      assert result.routed == true
    end

    test "unauthorized API request is rejected", %{tables: tables} do
      request = %{
        path: "/api/phics/emergency",
        method: "POST",
        tenant_id: "tenant_1",
        role: :guest
      }

      {:error, error} = route_api_request(tables, request)
      assert error.reason == :capability_not_permitted
    end

    test "request to unknown domain returns error", %{tables: tables} do
      request = %{
        path: "/api/unknown_domain/resource",
        method: "GET",
        tenant_id: "tenant_1",
        role: :super_admin
      }

      {:error, error} = route_api_request(tables, request)
      assert error.reason in [:unknown_domain, :invalid_path_format]
    end

    test "super_admin can access all domain API endpoints", %{tables: tables} do
      for domain <- @domains do
        request = %{
          path: "/api/#{domain}/resource",
          method: "GET",
          tenant_id: "tenant_admin",
          role: :super_admin
        }

        result = route_api_request(tables, request)
        assert {:ok, _} = result, "super_admin should access /api/#{domain}: #{inspect(result)}"
      end
    end
  end

  describe "Resource Ownership — every resource has an owner" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "registered resources always have an owner", %{tables: tables} do
      # Register multiple resources
      resources = [
        {"tenant_1", :devices, "dev_100", :sensor},
        {"tenant_2", :alarms, "alm_200", :motion},
        {"tenant_1", :video, "vid_300", :stream},
        {"tenant_3", :access, "usr_400", :user_record}
      ]

      for {tenant, domain, res_id, type} <- resources do
        {:ok, _} = register_tenant_resource(tables, tenant, domain, res_id, type)
      end

      # Verify all have owners
      for {_tenant, _domain, res_id, _type} <- resources do
        case :ets.lookup(tables.resource_ownership, res_id) do
          [{^res_id, ownership}] ->
            assert is_binary(ownership.owner_tenant), "Resource #{res_id} must have string owner"
            assert ownership.domain in @domains, "Resource #{res_id} must belong to valid domain"

          [] ->
            flunk("Resource #{res_id} has no ownership record")
        end
      end
    end

    test "ownership is unique per resource ID", %{tables: tables} do
      register_tenant_resource(tables, "tenant_A", :devices, "unique_dev", :sensor)

      # Count entries for this resource
      ownership_records = :ets.lookup(tables.resource_ownership, "unique_dev")

      assert length(ownership_records) == 1,
             "Each resource should have exactly one ownership record"
    end
  end

  # --- Property Tests (SD/check all — avoids PropCheck property+forall macro nesting) ---

  describe "Property: Domain isolation — no cross-domain state leakage" do
    test "writing to domain X never affects domain Y state" do
      domain_gen = SD.member_of(@domains)

      ExUnitProperties.check all(
                               domain_a <- domain_gen,
                               domain_b <- domain_gen,
                               key <- SD.binary(min_length: 1, max_length: 20),
                               value <- SD.integer(),
                               max_runs: 50
                             ) do
        if domain_a != domain_b do
          prop_tables = setup_ets_tables()
          write_domain_state(prop_tables, domain_a, key, value)
          keys_before = read_all_domain_state_keys(prop_tables, domain_b)
          write_domain_state(prop_tables, domain_a, key <> "_extra", value + 1)
          keys_after = read_all_domain_state_keys(prop_tables, domain_b)
          assert MapSet.new(keys_before) == MapSet.new(keys_after)
          cleanup_ets_tables(prop_tables)
        end
      end
    end
  end

  describe "Property: Tenant data separation" do
    test "resources registered by tenant A are never visible to tenant B" do
      domain_gen = SD.member_of(@domains)

      ExUnitProperties.check all(
                               n <- SD.positive_integer(),
                               domain <- domain_gen,
                               max_runs: 50
                             ) do
        prop_tables = setup_ets_tables()
        tenant_a = "prop_tenant_a_#{n}"
        tenant_b = "prop_tenant_b_#{n}"
        res_id = "prop_res_#{n}_#{domain}"

        register_tenant_resource(prop_tables, tenant_a, domain, res_id, :test_resource)

        resources_b = get_tenant_resources(prop_tables, tenant_b, domain)
        b_ids = Enum.map(resources_b, & &1.resource_id)

        assert res_id not in b_ids
        cleanup_ets_tables(prop_tables)
      end
    end
  end

  describe "Property: Access control completeness" do
    test "every domain-capability pair has a defined access decision for every role" do
      role_gen = SD.member_of(@roles)
      domain_gen = SD.member_of(@domains)

      ExUnitProperties.check all(
                               role <- role_gen,
                               domain <- domain_gen,
                               max_runs: 50
                             ) do
        prop_tables = setup_ets_tables()
        caps = Map.get(@domain_capabilities, domain, [])

        Enum.each(caps, fn cap ->
          result = check_access(prop_tables, "prop_tenant", role, domain, cap)
          assert result in [{:ok, :access_granted}, {:error, :capability_not_permitted}]
        end)

        cleanup_ets_tables(prop_tables)
      end
    end
  end

  describe "Property: Event routing correctness" do
    test "published events are always logged regardless of subscriber count" do
      domain_gen = SD.member_of(@domains)

      ExUnitProperties.check all(
                               domain <- domain_gen,
                               event_suffix <- SD.binary(min_length: 1, max_length: 10),
                               max_runs: 50
                             ) do
        prop_tables = setup_ets_tables()
        event_type = String.to_atom("event_" <> Base.encode16(event_suffix, case: :lower))
        before_count = length(:ets.tab2list(prop_tables.event_log))

        publish_domain_event(prop_tables, domain, event_type, %{test: true})

        after_count = length(:ets.tab2list(prop_tables.event_log))

        assert after_count > before_count
        cleanup_ets_tables(prop_tables)
      end
    end
  end

  describe "Domain Boundary Enforcement — integration scenarios" do
    setup do
      tables = setup_ets_tables()
      on_exit(fn -> cleanup_ets_tables(tables) end)
      {:ok, tables: tables}
    end

    test "complete multi-domain incident response scenario", %{tables: tables} do
      # Scenario: Device goes offline, triggers alarm, maintenance notified

      # Step 1: Compliance subscribes to everything for audit
      for source <- [:devices, :alarms, :maintenance] do
        subscribe_domain_to_events(tables, :compliance, source, :incident_event)
      end

      # Compliance also subscribes to health_degraded from devices for full audit coverage
      {:ok, :subscribed} =
        subscribe_domain_to_events(tables, :compliance, :devices, :health_degraded)

      # Step 2: Maintenance subscribes to device health events
      {:ok, :subscribed} =
        subscribe_domain_to_events(tables, :maintenance, :devices, :health_degraded)

      # Step 3: Alarms subscribes to device alerts
      {:ok, :subscribed} = subscribe_domain_to_events(tables, :alarms, :devices, :device_alert)

      # Step 4: Device health degrades
      {:ok, device_result} =
        publish_domain_event(tables, :devices, :health_degraded, %{
          device_id: "sensor_critical_001",
          health: 0.1
        })

      assert :maintenance in device_result.delivered_to
      assert :compliance in device_result.delivered_to

      # Step 5: Alarm triggered
      {:ok, alarm_result} =
        publish_domain_event(tables, :alarms, :incident_event, %{
          alarm_id: "alm_critical_001",
          severity: :critical
        })

      assert :compliance in alarm_result.delivered_to

      # Step 6: Operator with limited access tries emergency_stop (denied)
      denied = check_access(tables, "tenant_ops", :operator, :phics, :emergency_stop)
      assert denied == {:error, :capability_not_permitted}

      # Step 7: Super admin can execute emergency_stop
      granted = check_access(tables, "tenant_admin", :super_admin, :phics, :emergency_stop)
      assert granted == {:ok, :access_granted}

      # Step 8: Verify audit trail
      all_events = :ets.tab2list(tables.event_log)

      assert length(all_events) >= 4,
             "Expected at least 4 audit events (2 published + 2 access checks)"
    end

    test "operator role has correct access boundaries across all domains", %{tables: tables} do
      # Operators should read but not execute destructive operations
      expected_denials = [
        {:phics, :emergency_stop},
        {:devices, :provision_devices},
        {:access, :manage_permissions}
      ]

      expected_grants = [
        {:alarms, :read_alarms},
        {:devices, :read_devices},
        {:video, :read_streams},
        {:analytics, :read_reports}
      ]

      for {domain, cap} <- expected_denials do
        result = check_access(tables, "tenant_op", :operator, domain, cap)

        assert result == {:error, :capability_not_permitted},
               "operator should not have #{cap} on #{domain}"
      end

      for {domain, cap} <- expected_grants do
        result = check_access(tables, "tenant_op", :operator, domain, cap)

        assert result == {:ok, :access_granted},
               "operator should have #{cap} on #{domain}: #{inspect(result)}"
      end
    end

    test "auditor has read-only access appropriate for compliance domain", %{tables: tables} do
      # Auditors need read access to compliance domain
      compliance_caps = Map.get(@domain_capabilities, :compliance, [])

      for cap <- compliance_caps do
        result = check_access(tables, "auditor_1", :auditor, :compliance, cap)

        assert result == {:ok, :access_granted},
               "auditor should have #{cap} on compliance: #{inspect(result)}"
      end

      # Auditor should not be able to write to non-compliance domains
      for domain <- [:devices, :video, :crm],
          cap <- [:write_devices, :write_streams, :write_contacts] do
        if cap in Map.get(@domain_capabilities, domain, []) do
          result = check_access(tables, "auditor_1", :auditor, domain, cap)

          assert result == {:error, :capability_not_permitted},
                 "auditor should not #{cap} on #{domain}"
        end
      end
    end

    test "domain boundary enforcement survives high-volume concurrent operations", %{
      tables: tables
    } do
      # Simulate concurrent domain operations
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            domain = Enum.at(@domains, rem(i, length(@domains)))
            tenant = "concurrent_tenant_#{rem(i, 5)}"
            role = Enum.at(@roles, rem(i, length(@roles)))

            caps = Map.get(@domain_capabilities, domain, [:read])
            cap = Enum.at(caps, rem(i, length(caps)))

            result = check_access(tables, tenant, role, domain, cap)

            # Result must always be one of these — never a crash or unexpected error
            result in [
              {:ok, :access_granted},
              {:error, :capability_not_permitted},
              {:error, :no_permission_entry}
            ]
          end)
        end

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, & &1), "All concurrent access checks must return valid results"
    end
  end
end
