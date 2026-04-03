defmodule Mix.Tasks.Performance.SetupData do
  @moduledoc """
  Generate comprehensive test data for performance testing.

  This task creates realistic multi - tenant data with appropriate relationships
  and historical patterns to support accurate performance testing.

  NOTE: Currently disabled due to incomplete DomainApi implementation.
  """
  use Mix.Task

  @shortdoc "Generate performance test data"

  # alias Indrajaal.DomainApi

  # @tenant_count 50
  # @__users_per_tenant 100
  # @sites_per_tenant 10
  # @devices_per_tenant 200
  # @historical_alarms 100_000

  @spec run(term()) :: term()
  def run(_args) do
    Mix.shell().info("⚠️  Performance data setup currently disabled due to incomplete DomainApi
        implementation.")

    Mix.shell().info("    This task __requires full DomainApi implementation for all domains.")
    :ok

    # Original implementation commented out until DomainApi is complete

    # { opts, _} =
    #   OptionParser.parse!(args,
    #     switches: [
    #       tenants: :integer,
    #       __users_per_tenant: :integer,
    #       sites_per_tenant: :integer,
    #       devices_per_tenant: :integer,
    #       historical_alarms: :integer,
    #       clean: :boolean
    #     ]
    #   )

    # Mix.Task.run("app.start")

    # tenant_count = opts[:tenants] || @tenant_count
    # __users_per_tenant = opts[:__users_per_tenant] || @__users_per_tenant
    # sites_per_tenant = opts[:sites_per_tenant] || @sites_per_tenant
    # devices_per_tenant = opts[:devices_per_tenant] || @devices_per_tenant
    # historical_alarms = opts[:historical_alarms] || @historical_alarms

    # if opts[:clean] do
    #   Mix.shell().info("🧹 Cleaning existing performance test data...")
    #   clean_performance_data()
    # end

    # Mix.shell().info("[LAUNCH] Generating performance test data...")
    # Mix.shell().info("[STATS] Configuration:")
    # Mix.shell().info("   Tenants: #{tenant_count}")
    # Mix.shell().info("   Users per tenant: #{__users_per_tenant}")
    # Mix.shell().info("   Sites per tenant: #{sites_per_tenant}")
    # Mix.shell().info("   Devices per tenant: #{devices_per_tenant}")
    # Mix.shell().info("   Historical alarms: #{historical_alarms}")

    # start_time = System.monotonic_time(:millisecond)

    # # Generate data in parallel where possible
    # performance_data =
    #   generate_performance_dataset(%{
    #     tenant_count: tenant_count,
    #     __users_per_tenant: __users_per_tenant,
    #     sites_per_tenant: sites_per_tenant,
    #     devices_per_tenant: devices_per_tenant,
    #     historical_alarms: historical_alarms
    #   })

    # end_time = System.monotonic_time(:millisecond)
    # duration = end_time - start_time

    # Mix.shell().info("✅ Performance test data generation completed!")
    # Mix.shell().info("⏱️  Generation time: #{Float.round(duration / 1000, 2)} seconds")
    # Mix.shell().info("📈 Data summary:")

    # Enum.each(performance_data, fn {category, items} ->
    #   count = if is_list(items), do: length(items), else: items
    #   Mix.shell().info("   #{String.capitalize(to_string(category))}: #{count}")
    # end)

    # # Save metadata for performance tests
    # save_performance_metadata(performance_data, duration)
  end

  #   # All private functions commented out until DomainApi is complete
  #
  #   # defp generate_performance_dataset(config) do
  #     Mix.shell().info("1️⃣ Generating tenants...")
  #     tenants = generate_tenants(config.tenant_count)
  #
  #     Mix.shell().info("2️⃣ Generating organizations...")
  #     organizations = generate_organizations(tenants)
  #
  #     Mix.shell().info("3️⃣ Generating __users...")
  #     __users = generate_users_for_tenants(tenants, config.__users_per_tenant)
  #
  #     Mix.shell().info("4️⃣ Generating sites and infrastructure...")
  #     sites = generate_sites_for_tenants(tenants, organizations, config.sites
  #     {_buildings, _zones} = generate_site_infrastructure(sites)
  #
  #     Mix.shell().info("5️⃣ Generating devices...")
  #     devices = generate_devices_for_tenants(tenants, sites, zones, config.de
  #
  #     Mix.shell().info("6️⃣ Generating access control data...")
  #     accessdata = generate_access_control_data(tenants, sites, __users)
  #
  #     Mix.shell().info("7️⃣ Generating historical alarms...")
  #
  #     historical_alarms =
  #       generate_historical_alarms(tenants, devices, sites, __users, config.his
  #
  #     Mix.shell().info("8️⃣ Generating workflow data...")
  #     workflowdata = generate_workflow_data(tenants, __users)
  #
  #     %{
  #       tenants: tenants,
  #       organizations: organizations,
  #       __users: __users,
  #       sites: sites,
  #       buildings: buildings,
  #       zones: zones,
  #       devices: devices,
  #       access_data: access_data,
  #       historical_alarms: historical_alarms,
  #       workflow_data: workflow_data
  #     }
  #   end
  #
  #   defp generate_tenants(count) do
  #     1..count
  #     |> Enum.map(fn i ->
  #       {:ok, tenant} =
  #         DomainApi.create_tenant(
  #           %{
  #             name: "Performance Test Tenant #{i}",
  #             slug: "perf - tenant-#{i}"
  #           },
  #           actor: %{is_system: true}
  #         )
  #
  #       tenant
  #     end)
  #   end
  #
  #   defp generate_organizations(tenants) do
  #     tenants
  #     |> Enum.map(fn tenant ->
  #       {:ok, org} =
  #         DomainApi.create_organization(
  #           %{
  #             name: "#{tenant.name} Organization",
  #             tenant_id: tenant.id
  #           },
  #           actor: %{tenant_id: tenant.id}
  #         )
  #
  #       org
  #     end)
  #   end
  #
  #   defp generate_users_for_tenants(tenants, usersper_tenant) do
  #     tenants
  #     |> Enum.flat_map(fn tenant ->
  #       1..__users_per_tenant
  #       |> Enum.map(fn i ->
  #         role_type =
  #           case rem(i, 10) do
  #             0 -> "admin"
  #             n when n <= 2 -> "operator"
  #             n when n <= 6 -> "viewer"
  #             _ -> "guest"
  #           end
  #
  #         {:ok, user} =
  #           DomainApi.create_user(
  #             %{
  #               email: "user#{i}@#{tenant.slug}.test",
  #               first_name: "User#{i}",
  #               last_name: "Tenant#{tenant.id}",
  #               tenant_id: tenant.id
  #             },
  #             actor: %{tenant_id: tenant.id}
  #           )
  #
  #         # Assign role
  #         {:ok, role} = ensure_role_exists(tenant, role_type)
  #
  #         {:ok, user_role} =
  #           DomainApi.assign_user_role(
  #             user.id,
  #             role.id,
  #             %{tenant_id: tenant.id},
  #             actor: %{tenant_id: tenant.id}
  #           )
  #
  #         user
  #       end)
  #     end)
  #   end
  #
  #   defp generate_sites_for_tenants(tenants, organizations, sites_per_tenant)
  #     tenants
  #     |> Enum.zip(organizations)
  #     |> Enum.flat_map(fn {tenant, organization} ->
  #       1..sites_per_tenant
  #       |> Enum.map(fn i ->
  #         site_types = ["office", "warehouse", "retail", "manufacturing", "da
  #         site_type = Enum.at(site_types, rem(i, length(site_types)))
  #
  #         {:ok, site} =
  #           DomainApi.create_site(
  #             %{
  #               name: "#{site_type} Site #{i}",
  #               location: "#{i}00 Performance Test Ave, City #{i}",
  #               tenant_id: tenant.id,
  #               organization_id: organization.id
  #             },
  #             actor: %{tenant_id: tenant.id}
  #           )
  #
  #         site
  #       end)
  #     end)
  #   end
  #
  #   defp generate_site_infrastructure(sites) do
  #     buildings =
  #       sites
  #       |> Enum.flat_map(fn site ->
  #         # 2 - 4 buildings per site
  #         building_count = :rand.uniform(3) + 1
  #
  #         1..building_count
  #         |> Enum.map(fn i ->
  #           {:ok, building} =
  #             DomainApi.create_building(
  #               %{
  #                 name: "Building #{i}",
  #                 site_id: site.id,
  #                 tenant_id: site.tenant_id
  #               },
  #               actor: %{tenant_id: site.tenant_id}
  #             )
  #
  #           building
  #         end)
  #       end)
  #
  #     zones =
  #       buildings
  #       |> Enum.flat_map(fn building ->
  #         # 3 - 7 zones per building
  #         zone_count = :rand.uniform(5) + 2
  #
  #         1..zone_count
  #         |> Enum.map(fn i ->
  #           criticalities = [:low, :medium, :high, :critical]
  #           criticality = Enum.at(criticalities, rem(i, length(criticalities)))
  #
  #           {:ok, zone} =
  #             DomainApi.create_zone(
  #               %{
  #                 name: "Zone #{i}",
  #                 building_id: building.id,
  #                 site_id: building.site_id,
  #                 tenant_id: building.tenant_id,
  #                 criticality: criticality
  #               },
  #               actor: %{tenant_id: building.tenant_id}
  #             )
  #
  #           zone
  #         end)
  #       end)
  #
  #     {buildings, zones}
  #   end
  #
  #   defp generate_devices_for_tenants(tenants, sites, zones, devices_per_tena
  #     tenant_sites = Enum.group_by(sites, & &1.tenant_id)
  #     tenant_zones = Enum.group_by(zones, & &1.tenant_id)
  #
  #     tenants
  #     |> Enum.flat_map(fn tenant ->
  #       tenant_site_list = Map.get(tenant_sites, tenant.id, [])
  #       tenant_zone_list = Map.get(tenant_zones, tenant.id, [])
  #
  #       1..devices_per_tenant
  #       |> Enum.map(fn i ->
  #         device_types = [:camera, :sensor, :panel, :reader]
  #         device_type = Enum.at(device_types, rem(i, length(device_types)))
  #
  #         # Randomly assign to site and zone
  #         site = Enum.random(tenant_site_list)
  #         zone = Enum.random(tenant_zone_list)
  #
  #         devicedata = %{
  #           name: "#{String.capitalize(to_string(device_type))} #{i}",
  #           device_type: device_type,
  #           site_id: site.id,
  #           zone_id: zone.id,
  #           tenant_id: tenant.id,
  #           account_number: "DEV#{String.pad_leading(to_string(i), 6, "0")}"
  #         }
  #
  #         {:ok, device} =
  #           case device_type do
  #             :camera ->
  #               DomainApi.create_camera(
  #                 Map.merge(device_data, %{
  #                   camera_type: :dome,
  #                   stream_url: "rtsp://test.camera#{i}/stream"
  #                 }),
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #
  #             :panel ->
  #               DomainApi.create_panel(
  #                 Map.merge(device_data, %{
  #                   panel_type: :main,
  #                   max_zones: 32
  #                 }),
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #
  #             :reader ->
  #               DomainApi.create_reader(
  #                 Map.merge(device_data, %{
  #                   location: "Zone #{zone.name} Entry"
  #                 }),
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #
  #             :sensor ->
  #               DomainApi.create_sensor(
  #                 Map.merge(device_data, %{
  #                   sensor_type: :motion
  #                 }),
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #           end
  #
  #         device
  #       end)
  #     end)
  #   end
  #
  #   defp generate_access_control_data(tenants, sites, users) do
  #     tenant_sites = Enum.group_by(sites, & &1.tenant_id)
  #     tenant_users = Enum.group_by(__users, & &1.tenant_id)
  #
  #     tenants
  #     |> Enum.flat_map(fn tenant ->
  #       tenant_site_list = Map.get(tenant_sites, tenant.id, [])
  #       tenant_user_list = Map.get(tenant_users, tenant.id, [])
  #
  #       # Generate access levels
  #       access_levels =
  #         ["Basic", "Standard", "Premium", "Executive"]
  #         |> Enum.map(fn level_name ->
  #           {:ok, level} =
  #             DomainApi.create_access_level(
  #               %{
  #                 name: level_name,
  #                 tenant_id: tenant.id
  #               },
  #               actor: %{tenant_id: tenant.id}
  #             )
  #
  #           level
  #         end)
  #
  #       # Generate access grants for __users
  #       access_grants =
  #         tenant_user_list
  #         # Limit for performance
  #         |> Enum.take(50)
  #         |> Enum.map(fn user ->
  #           level = Enum.random(access_levels)
  #           site = Enum.random(tenant_site_list)
  #
  #           {:ok, grant} =
  #             DomainApi.create_access_grant(
  #               %{
  #                 user_id: user.id,
  #                 access_level_id: level.id,
  #                 site_id: site.id,
  #                 tenant_id: tenant.id,
  #                 valid_from: DateTime.add(DateTime.utc_now(), -30, :day),
  #                 valid_until: DateTime.add(DateTime.utc_now(), 365, :day)
  #               },
  #               actor: %{tenant_id: tenant.id}
  #             )
  #
  #           grant
  #         end)
  #
  #       # Generate some access logs for recent activity
  #       access_logs =
  #         1..100
  #         |> Enum.map(fn _i ->
  #           user = Enum.random(tenant_user_list)
  #           site = Enum.random(tenant_site_list)
  #
  #           {:ok, log} =
  #             DomainApi.create_access_log(
  #               %{
  #                 user_id: user.id,
  #                 site_id: site.id,
  #                 # 90% success rate
  #                 access_granted: :rand.uniform() > 0.1,
  #                 attempted_at:
  #                   DateTime.add(DateTime.utc_now(), -:rand.uniform(7 * 24 * 60), :minute),
  #                 tenant_id: tenant.id
  #               },
  #               actor: %{tenant_id: tenant.id}
  #             )
  #
  #           log
  #         end)
  #
  #       %{
  #         access_levels: access_levels,
  #         access_grants: access_grants,
  #         access_logs: access_logs
  #       }
  #     end)
  #     |> Enum.reduce(%{access_levels: [], access_grants: [], access_logs: []}, fn _data, acc ->
  #       %{
  #         access_levels: acc.access_levels ++ data.access_levels,
  #         access_grants: acc.access_grants ++ data.access_grants,
  #         access_logs: acc.access_logs ++ data.access_logs
  #       }
  #     end)
  #   end
  #
  #   defp generate_historical_alarms(tenants, devices, sites, __users, alarm_cou
  #     tenant_devices = Enum.group_by(devices, & &1.tenant_id)
  #     tenant_sites = Enum.group_by(sites, & &1.tenant_id)
  #
  #     # Generate alarms distributed across the last 30 days
  #     base_time = DateTime.add(DateTime.utc_now(), -30, :day)
  #
  #     1..alarm_count
  #     |> Enum.map(fn i ->
  #       tenant = Enum.random(tenants)
  #       tenant_device_list = Map.get(tenant_devices, tenant.id, [])
  #       tenant_site_list = Map.get(tenant_sites, tenant.id, [])
  #
  #       if length(tenant_device_list) > 0 and length(tenant_site_list) > 0 do
  #         device = Enum.random(tenant_device_list)
  #         site = Enum.random(tenant_site_list)
  #
  #         # Generate time with realistic patterns (more during business hours)
  #         days_offset = :rand.uniform(30)
  #         hour_offset = generate_realistic_hour()
  #         triggered_at = DateTime.add(base_time, days_offset * 24 * 60 + hour_offset * 60, :minute)
  #
  #         __event_types = [:intrusion, :motion, :door, :fire, :tamper, :panic]
  #         __severities = [:low, :medium, :high, :critical]
  #
  #         # Weighted severity distribution (more low / medium than critical)
  #         severity =
  #           case :rand.uniform(100) do
  #             n when n <= 50 -> :low
  #             n when n <= 80 -> :medium
  #             n when n <= 95 -> :high
  #             _ -> :critical
  #           end
  #
  #         __event_type = Enum.random(__event_types)
  #
  #         {:ok, alarm} =
  #           Indrajaal.Alarms.Api.create_alarm_event(
  #             %{
  #               __event_code: "PERF#{String.pad_leading(to_string(i), 6, "0")}",
  #               event_type: event_type,
  #               severity: severity,
  #               description: "Performance test #{__event_type} alarm #{i}",
  #               device_id: device.id,
  #               site_id: site.id,
  #               tenant_id: tenant.id,
  #               triggered_at: triggered_at,
  #               metadata: %{
  #                 performance_test: true,
  #                 batch_id: "historical_#{div(i, 1000)}"
  #               }
  #             },
  #             actor: %{tenant_id: tenant.id}
  #           )
  #
  #         # Some alarms should be acknowledged / resolved
  #         case :rand.uniform(10) do
  #           n when n <= 6 ->
  #             # Leave triggered
  #             alarm
  #
  #           n when n <= 8 ->
  #             # Acknowledge
  #             {:ok, ack_alarm} =
  #               Indrajaal.Alarms.Api.acknowledge_alarm(
  #                 alarm.id,
  #                 Enum.random(
  #                   Map.get(
  #                     Enum.group_by(
  #                       Enum.filter(
  #                         Enum.flat_map(Map.values(Enum.group_by(__users, & &1.tenant_id)), & &1),
  #                         fn u -> u.tenant_id == tenant.id end
  #                       ),
  #                       & &1.tenant_id
  #                     ),
  #                     tenant.id,
  #                     []
  #                   )
  #                 ).id,
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #
  #             ack_alarm
  #
  #           _ ->
  #             # Resolve
  #             user_id =
  #               case Enum.filter(__users, fn u -> u.tenant_id == tenant.id end) do
  #                 [] -> nil
  #                 tenant_users -> Enum.random(tenant_users).id
  #               end
  #
  #             if user_id do
  #               {:ok, _ack} =
  #                 Indrajaal.Alarms.Api.acknowledge_alarm(
  #                   alarm.id,
  #                   user_id,
  #                   actor: %{tenant_id: tenant.id}
  #                 )
  #
  #               {:ok, resolved} =
  #                 Indrajaal.Alarms.Api.resolve_alarm(
  #                   alarm.id,
  #                   user_id,
  #                   "Performance test resolution",
  #                   actor: %{tenant_id: tenant.id}
  #                 )
  #
  #               resolved
  #             else
  #               alarm
  #             end
  #         end
  #       end
  #     end)
  #     # Remove nils
  #     |> Enum.filter(& &1)
  #   end
  #
  #   defp generate_workflow_data(tenants, users) do
  #     tenant_users = Enum.group_by(__users, & &1.tenant_id)
  #
  #     tenants
  #     |> Enum.flat_map(fn tenant ->
  #       __tenant_user_list = Map.get(tenant_users, tenant.id, [])
  #
  #       # Generate dispatch teams
  #       teams =
  #         1..3
  #         |> Enum.map(fn i ->
  #           {:ok, team} =
  #             DomainApi.create_dispatch_team(
  #               %{
  #                 name: "Security Team #{i}",
  #                 tenant_id: tenant.id
  #               },
  #               actor: %{tenant_id: tenant.id}
  #             )
  #
  #           team
  #         end)
  #
  #       # Generate officers
  #       officers =
  #         teams
  #         |> Enum.flat_map(fn team ->
  #           1..5
  #           |> Enum.map(fn i ->
  #             {:ok, officer} =
  #               DomainApi.create_dispatch_officer(
  #                 %{
  #                   badge_number: "SEC#{team.id}#{String.pad_leading(to_string(i), 2, "0")}",
  #                   first_name: "Officer#{i}",
  #                   last_name: "Team#{team.id}",
  #                   team_id: team.id,
  #                   tenant_id: tenant.id,
  #                   status: :available
  #                 },
  #                 actor: %{tenant_id: tenant.id}
  #               )
  #
  #             officer
  #           end)
  #         end)
  #
  #       %{teams: teams, officers: officers}
  #     end)
  #     |> Enum.reduce(%{teams: [], officers: []}, fn _data, acc ->
  #       %{
  #         teams: acc.teams ++ data.teams,
  #         officers: acc.officers ++ data.officers
  #       }
  #     end)
  #   end
  #
  #   defp generate_realistic_hour() do
  #     # Weight towards business hours (8 AM - 6 PM)
  #     case :rand.uniform(100) do
  #       # Business hours
  #       n when n <= 60 -> 8 + :rand.uniform(10)
  #       # Evening
  #       n when n <= 80 -> 18 + :rand.uniform(6)
  #       # Night / early morning
  #       _ -> :rand.uniform(8)
  #     end
  #   end
  #
  #   defp ensure_role_exists(tenant, roletype) do
  #     role_name = "Performance #{String.capitalize(role_type)}"
  #
  #     case DomainApi.get_role_by_name(role_name, actor: %{tenant_id: tenant.id}) do
  #       {:ok, role} ->
  #         {:ok, role}
  #
  #       {:error, _} ->
  #         DomainApi.create_role(
  #           %{
  #             name: role_name,
  #             tenant_id: tenant.id
  #           },
  #           actor: %{tenant_id: tenant.id}
  #         )
  #     end
  #   end
  #
  #   defp clean_performance_data() do
  #     # This should clean only performance test data, not production data
  #     # Implementation would depend on specific data marking strategy
  #     Mix.shell().info(
  #       "⚠️  Clean functionality not implemented - manually clean test data if
  #     )
  #   end
  #
  #   defp save_performance_metadata(data, generation_time) do
  #     metadata = %{
  #       generated_at: DateTime.utc_now(),
  #       generation_time_ms: generation_time,
  #       data_summary:
  #         Enum.map(data, fn {key, items} ->
  #           count = if is_list(items), do: length(items), else: items
  #           {key, count}
  #         end)
  #         |> Map.new(),
  #       environment: %{
  #         elixir_version: System.version(),
  #         otp_version: System.otp_release(),
  #         database: "PostgreSQL 17"
  #       }
  #     }
  #
  #     File.mkdir_p!("tmp / performance")
  #     File.write!("tmp / performance / test_datametadata.json", Jason.encode!(metadata, pretty: true))
  #     Mix.shell().info("📋 Metadata saved to tmp / performance / test_datametadata.json")
  #   end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
