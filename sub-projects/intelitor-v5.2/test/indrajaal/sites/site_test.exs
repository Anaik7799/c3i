defmodule Indrajaal.Sites.SiteTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  import Indrajaal.AccountsFixtures
  alias Indrajaal.Sites
  alias Indrajaal.Sites.Site

  describe "site creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates site with valid attributes", %{tenant: tenant} do
      attrs = %{
        name: "Corporate Headquarters",
        code: "HQ - 001",
        site_type: "headquarters",
        address: "123 Main Street",
        city: "New York",
        __state: "NY",
        country: "US",
        postal_code: "10_001",
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert site.name == "Corporate Headquarters"
      assert site.code == "HQ - 001"
      assert site.site_type == "headquarters"
      assert site.city == "New York"
      assert site.tenant_id == tenant.id
      assert site.status == "active"
    end

    test "validates __required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_site(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is __required"
      assert error_msg =~ "code: is __required"
    end

    test "validates code uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        name: "Site 1",
        code: "SITE - 001",
        tenant_id: tenant.id
      }

      assert {:ok, _site1} = Sites.create_site(attrs)
      assert {:error, error} = Sites.create_site(attrs)
      assert Exception.message(error) =~ "code: has already been taken"
    end

    test "allows same code across tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs1 = %{name: "Site A", code: "SITE - 001", tenant_id: tenant1.id}
      attrs2 = %{name: "Site B", code: "SITE - 001", tenant_id: tenant2.id}

      assert {:ok, site1} = Sites.create_site(attrs1)
      assert {:ok, site2} = Sites.create_site(attrs2)
      assert site1.code == site2.code
      assert site1.tenant_id != site2.tenant_id
    end

    test "validates site types", %{tenant: tenant} do
      valid_types = [
        "headquarters",
        "regional_office",
        "branch_office",
        "warehouse",
        "__data_center",
        "retail_location",
        "remote_facility"
      ]

      for type <- valid_types do
        attrs = %{
          name: "Test #{type}",
          code: "#{String.upcase(type)}-001",
          site_type: type,
          tenant_id: tenant.id
        }

        assert {:ok, site} = Sites.create_site(attrs)
        assert site.site_type == type
      end

      # Invalid type
      attrs = %{
        name: "Invalid",
        code: "INV - 001",
        site_type: "invalid_type",
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_site(attrs)
    end

    test "validates status values", %{tenant: tenant} do
      valid_statuses = ["planned", "construction", "active", "renovation", "inactive"]

      for status <- valid_statuses do
        attrs = %{
          name: "Test Status",
          code: "ST-#{status}",
          status: status,
          tenant_id: tenant.id
        }

        assert {:ok, site} = Sites.create_site(attrs)
        assert site.status == status
      end
    end

    test "creates site with coordinates", %{tenant: tenant} do
      attrs = %{
        name: "Geo Site",
        code: "GEO - 001",
        latitude: 40.7128,
        longitude: -74.0060,
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert site.latitude == 40.7128
      assert site.longitude == -74.0060
    end

    test "validates coordinate ranges", %{tenant: tenant} do
      # Valid coordinates
      attrs = %{
        name: "Valid Coords",
        code: "VC - 001",
        latitude: 45.0,
        longitude: -120.0,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_site(attrs)

      # Invalid latitude
      attrs = %{
        name: "Invalid Lat",
        code: "IL - 001",
        # > 90
        latitude: 91.0,
        longitude: 0.0,
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_site(attrs)

      # Invalid longitude
      attrs = %{
        name: "Invalid Long",
        code: "IL - 002",
        latitude: 0.0,
        # > 180
        longitude: 181.0,
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_site(attrs)
    end

    test "creates site with operational details", %{tenant: tenant} do
      attrs = %{
        name: "Operational Site",
        code: "OP - 001",
        operational_status: "operational",
        employee_count: 150,
        building_count: 3,
        total_area_sqft: 45_000,
        criticality: "high",
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert site.operational_status == "operational"
      assert site.employee_count == 150
      assert site.building_count == 3
      assert site.total_area_sqft == 45_000
      assert site.criticality == "high"
    end

    test "creates site with operating hours", %{tenant: tenant} do
      operating_hours = %{
        "monday" => "08:00 - 18:00",
        "tuesday" => "08:00 - 18:00",
        "wednesday" => "08:00 - 18:00",
        "thursday" => "08:00 - 18:00",
        "friday" => "08:00 - 17:00",
        "saturday" => "09:00 - 13:00",
        "sunday" => "closed"
      }

      attrs = %{
        name: "Business Hours Site",
        code: "BH - 001",
        operating_hours: operating_hours,
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert site.operating_hours["monday"] == "08:00 - 18:00"
      assert site.operating_hours["sunday"] == "closed"
    end

    test "creates site with emergency contacts", %{tenant: tenant} do
      contacts = [
        %{"name" => "John Doe", "role" => "Site Manager", "phone" => "+1 - 555 - 1234"},
        %{"name" => "Jane Smith", "role" => "Security", "phone" => "+1 - 555 - 5678"}
      ]

      attrs = %{
        name: "Emergency Site",
        code: "EM - 001",
        emergency_contacts: contacts,
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert length(site.emergency_contacts) == 2
      assert List.first(site.emergency_contacts)["role"] == "Site Manager"
    end

    test "creates site with metadata", %{tenant: tenant} do
      metadata = %{
        "certifications" => ["ISO 27_001", "LEED Gold"],
        "amenities" => ["Cafeteria", "Gym", "Parking"],
        "security_level" => "enhanced",
        "last_audit" => "2025 - 07 - 31"
      }

      attrs = %{
        name: "Meta__data Site",
        code: "MD - 001",
        metadata: metadata,
        tenant_id: tenant.id
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert "ISO 27_001" in site.metadata["certifications"]
      assert "Gym" in site.metadata["amenities"]
    end
  end

  describe "site updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "updates site details", %{site: site} do
      attrs = %{
        name: "Updated Name",
        operational_status: "limited_operations",
        employee_count: 200
      }

      assert {:ok, updated} = Sites.update_site(site, attrs)
      assert updated.name == "Updated Name"
      assert updated.operational_status == "limited_operations"
      assert updated.employee_count == 200
    end

    test "updates address information", %{site: site} do
      attrs = %{
        address: "456 New Street",
        city: "Los Angeles",
        __state: "CA",
        postal_code: "90_001"
      }

      assert {:ok, updated} = Sites.update_site(site, attrs)
      assert updated.address == "456 New Street"
      assert updated.city == "Los Angeles"
    end

    test "updates coordinates", %{site: site} do
      attrs = %{
        latitude: 34.0522,
        longitude: -118.2437
      }

      assert {:ok, updated} = Sites.update_site(site, attrs)
      assert updated.latitude == 34.0522
      assert updated.longitude == -118.2437
    end

    test "deactivates site", %{site: site} do
      assert {:ok, updated} = Sites.update_site(site, %{status: "inactive"})
      assert updated.status == "inactive"
    end

    test "pr__events code change", %{site: site} do
      assert {:error, error} = Sites.update_site(site, %{code: "NEW - CODE"})
      assert Exception.message(error) =~ "cannot change site code"
    end

    test "validates criticality changes", %{site: site} do
      # Can increase criticality
      assert {:ok, updated} = Sites.update_site(site, %{criticality: "critical"})
      assert updated.criticality == "critical"

      # Decreasing __requires reason
      assert {:error, error} = Sites.update_site(updated, %{criticality: "low"})
      assert Exception.message(error) =~ "reason __required for criticality
        decrease"

      # With reason
      assert {:ok, updated2} =
               Sites.update_site(updated, %{
                 criticality: "medium",
                 criticality_change_reason: "Risk reassessment completed"
               })

      assert updated2.criticality == "medium"
    end
  end

  describe "site queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 50)
      {:ok, tenant: tenant, sites: sites}
    end

    test "lists all sites for tenant", %{tenant: tenant, sites: sites} do
      result = Sites.list_sites!(tenant_id: tenant.id)
      assert length(result) >= length(sites)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters by status", %{tenant: tenant} do
      active_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [status: "active"]
        )

      assert Enum.all?(active_sites, &(&1.status == "active"))
    end

    test "filters by site type", %{tenant: tenant} do
      warehouses =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [site_type: "warehouse"]
        )

      assert Enum.all?(warehouses, &(&1.site_type == "warehouse"))
      assert length(warehouses) > 0
    end

    test "filters by operational status", %{tenant: tenant} do
      operational =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [operational_status: "operational"]
        )

      assert Enum.all?(operational, &(&1.operational_status == "operational"))
    end

    test "filters by criticality", %{tenant: tenant} do
      critical_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [criticality: "critical"]
        )

      assert Enum.all?(critical_sites, &(&1.criticality == "critical"))
    end

    test "filters by location", %{tenant: tenant} do
      # By country
      us_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [country: "US"]
        )

      assert Enum.all?(us_sites, &(&1.country == "US"))

      # By __state
      ny_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [__state: "NY"]
        )

      assert Enum.all?(ny_sites, &(&1.__state == "NY"))
    end

    test "searches by name", %{tenant: tenant} do
      hq_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%headquarters%"}]
        )

      assert Enum.all?(hq_sites, &String.contains?(String.downcase(&1.name), "headquarters"))
    end

    test "filters by employee count range", %{tenant: tenant} do
      large_sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          filter: [employee_count: {:>, 100}]
        )

      assert Enum.all?(large_sites, &(&1.employee_count > 100))
    end

    test "sorts by name", %{tenant: tenant} do
      sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(sites, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sorts by criticality and name", %{tenant: tenant} do
      sites =
        Sites.list_sites!(
          tenant_id: tenant.id,
          sort: [criticality: :desc, name: :asc]
        )

      # Verify criticality order
      criticality_order = ["critical", "high", "medium", "low"]
      grouped = Enum.group_by(sites, & &1.criticality)

      previous_index = -1

      for {crit, group} <- grouped do
        index = Enum.find_index(criticality_order, &(&1 == crit))
        assert index >= previous_index

        # Within same criticality, check name order
        names = Enum.map(group, & &1.name)
        assert names == Enum.sort(names)
      end
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_sites!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 0]
        )

      page2 =
        Sites.list_sites!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 20]
        )

      assert length(page1) == 20
      assert length(page2) >= 10

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "site hierarchy" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates parent - child site relationships", %{tenant: tenant} do
      # Create HQ
      {:ok, hq} =
        Sites.create_site(%{
          name: "Global HQ",
          code: "HQ - GLOBAL",
          site_type: "headquarters",
          tenant_id: tenant.id
        })

      # Create regional office under HQ
      {:ok, regional} =
        Sites.create_site(%{
          name: "Regional Office East",
          code: "RO - EAST",
          site_type: "regional_office",
          parent_site_id: hq.id,
          tenant_id: tenant.id
        })

      assert regional.parent_site_id == hq.id

      # Create branch under regional
      {:ok, branch} =
        Sites.create_site(%{
          name: "Branch NYC",
          code: "BR - NYC",
          site_type: "branch_office",
          parent_site_id: regional.id,
          tenant_id: tenant.id
        })

      assert branch.parent_site_id == regional.id
    end

    test "gets site hierarchy", %{tenant: tenant} do
      # Create hierarchy
      {:ok, hq} =
        Sites.create_site(%{
          name: "HQ",
          code: "HQ - 001",
          site_type: "headquarters",
          tenant_id: tenant.id
        })

      regional_sites =
        for i <- 1..3 do
          {:ok, site} =
            Sites.create_site(%{
              name: "Regional #{i}",
              code: "RO - 00#{i}",
              site_type: "regional_office",
              parent_site_id: hq.id,
              tenant_id: tenant.id
            })

          site
        end

      # Get children
      children = Sites.get_child_sites(hq.id)
      assert length(children) == 3
      assert Enum.all?(children, &(&1.parent_site_id == hq.id))
    end

    test "pr__events circular hierarchy", %{tenant: tenant} do
      # Create two sites
      {:ok, site1} =
        Sites.create_site(%{
          name: "Site 1",
          code: "S1",
          tenant_id: tenant.id
        })

      {:ok, site2} =
        Sites.create_site(%{
          name: "Site 2",
          code: "S2",
          parent_site_id: site1.id,
          tenant_id: tenant.id
        })

      # Try to make site1 child of site2 (circular)
      assert {:error, error} =
               Sites.update_site(site1, %{
                 parent_site_id: site2.id
               })

      assert Exception.message(error) =~ "circular hierarchy"
    end
  end

  describe "site statistics" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 50)
      {:ok, tenant: tenant, sites: sites}
    end

    test "counts sites by type", %{tenant: tenant} do
      counts = Sites.count_sites_by_type(tenant_id: tenant.id)

      assert counts["headquarters"] > 0
      assert counts["warehouse"] > 0
      assert counts["branch_office"] > 0

      total = Enum.sum(Map.values(counts))
      assert total >= 50
    end

    test "calculates total employees", %{tenant: tenant} do
      total = Sites.calculate_total_employees(tenant_id: tenant.id)
      assert total > 0
    end

    test "calculates total area", %{tenant: tenant} do
      total_sqft = Sites.calculate_total_area(tenant_id: tenant.id)
      assert total_sqft > 0
    end

    test "gets site utilization metrics", %{tenant: tenant, sites: sites} do
      site = List.first(sites)

      metrics = Sites.get_site_utilization(site.id)

      assert Map.has_key?(metrics, :employee_density)
      assert Map.has_key?(metrics, :space_per_employee)
      assert Map.has_key?(metrics, :building_utilization)
    end

    test "identifies underutilized sites", %{tenant: tenant} do
      # Create underutilized site
      {:ok, underutilized} =
        Sites.create_site(%{
          name: "Empty Warehouse",
          code: "WH - EMPTY",
          site_type: "warehouse",
          employee_count: 5,
          total_area_sqft: 50_000,
          tenant_id: tenant.id
        })

      underutilized_sites =
        Sites.find_underutilized_sites(
          tenant_id: tenant.id,
          min_sqft_per_employee: 1000
        )

      assert Enum.any?(underutilized_sites, &(&1.id == underutilized.id))
    end
  end

  describe "geographic analysis" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 50)
      {:ok, tenant: tenant, sites: sites}
    end

    test "finds sites within radius", %{tenant: tenant} do
      # NYC coordinates
      lat = 40.7128
      lng = -74.0060
      radius_km = 50

      nearby =
        Sites.find_sites_within_radius(
          tenant_id: tenant.id,
          latitude: lat,
          longitude: lng,
          radius_km: radius_km
        )

      # Verify all results are within radius
      for site <- nearby do
        distance = calculate_distance(lat, lng, site.latitude, site.longitude)
        assert distance <= radius_km
      end
    end

    test "groups sites by region", %{tenant: tenant} do
      regions = Sites.group_sites_by_region(tenant_id: tenant.id)

      assert Map.has_key?(regions, "US")
      assert is_list(regions["US"])

      # Verify grouping
      for {country, sites} <- regions do
        assert Enum.all?(sites, &(&1.country == country))
      end
    end

    test "calculates site distances", %{tenant: tenant, sites: sites} do
      site1 = Enum.at(sites, 0)
      site2 = Enum.at(sites, 1)

      distance = Sites.calculate_site_distance(site1.id, site2.id)
      assert distance >= 0
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "bulk creates sites", %{tenant: tenant} do
      sites = bulk_create_sites(tenant, 50)

      assert length(sites) >= 50
      assert Enum.all?(sites, &(&1.tenant_id == tenant.id))

      # Verify distribution
      by_type = Enum.group_by(sites, & &1.site_type)
      assert map_size(by_type) >= 5

      by_status = Enum.group_by(sites, & &1.status)
      assert Map.has_key?(by_status, "active")
    end

    test "bulk updates sites", %{tenant: tenant} do
      sites = bulk_create_sites(tenant, 10)
      site_ids = Enum.map(sites, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_sites(
                 filter: [id: {:in, site_ids}],
                 attributes: %{
                   metadata: %{"bulk_update" => true, "updated_at" => DateTime.utc_now()}
                 }
               )

      assert count == 10

      # Verify update
      updated = Sites.list_sites!(filter: [id: {:in, site_ids}])
      assert Enum.all?(updated, &(&1.metadata["bulk_update"] == true))
    end

    test "bulk deactivates sites", %{tenant: tenant} do
      # Create sites to deactivate
      sites =
        for i <- 1..5 do
          {:ok, site} =
            Sites.create_site(%{
              name: "To Deactivate #{i}",
              code: "DEACT-#{i}",
              tenant_id: tenant.id
            })

          site
        end

      site_ids = Enum.map(sites, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_sites(
                 filter: [id: {:in, site_ids}],
                 attributes: %{status: "inactive"}
               )

      assert count == 5

      # Verify all inactive
      inactive = Sites.list_sites!(filter: [id: {:in, site_ids}])
      assert Enum.all?(inactive, &(&1.status == "inactive"))
    end
  end

  describe "site validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates postal code format", %{tenant: tenant} do
      # US postal code
      attrs = %{
        name: "US Site",
        code: "US - 001",
        country: "US",
        postal_code: "12_345",
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_site(attrs)

      # Invalid US postal code
      attrs = %{
        name: "Invalid US",
        code: "US - 002",
        country: "US",
        # Too short
        postal_code: "123",
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_site(attrs)
    end

    test "validates operating hours format", %{tenant: tenant} do
      # Valid format
      valid_hours = %{
        "monday" => "09:00 - 17:00",
        "tuesday" => "09:00 - 17:00"
      }

      attrs = %{
        name: "Valid Hours",
        code: "VH - 001",
        operating_hours: valid_hours,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_site(attrs)

      # Invalid format
      invalid_hours = %{
        # Invalid times
        "monday" => "25:00 - 30:00"
      }

      attrs = %{
        name: "Invalid Hours",
        code: "IH - 001",
        operating_hours: invalid_hours,
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_site(attrs)
    end

    test "validates site capacity constraints", %{tenant: tenant} do
      # Building count can't exceed reasonable limit
      attrs = %{
        name: "Too Many Buildings",
        code: "TMB - 001",
        # Unreasonable
        building_count: 1000,
        # Too small for 1000 buildings
        total_area_sqft: 10_000,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_site(attrs)
      assert Exception.message(error) =~ "unrealistic building density"
    end

    test "validates criticality __requirements", %{tenant: tenant} do
      # Critical sites require emergency contacts
      attrs = %{
        name: "Critical Site",
        code: "CRIT - 001",
        criticality: "critical",
        # Empty
        emergency_contacts: [],
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_site(attrs)
      assert Exception.message(error) =~ "critical sites require emergency
        contacts"

      # With contacts
      attrs =
        Map.put(attrs, :emergency_contacts, [
          %{"name" => "John Doe", "role" => "Manager", "phone" => "+1 - 555 - 1234"}
        ])

      assert {:ok, _} = Sites.create_site(attrs)
    end
  end

  # Helper function for distance calculation
  defp calculate_distance(lat1, lng1, lat2, lng2) do
    # Haversine formula (simplified)
    # Earth radius in km
    r = 6371
    d_lat = (lat2 - lat1) * :math.pi() / 180
    d_lng = (lng2 - lng1) * :math.pi() / 180

    a =
      :math.sin(d_lat / 2) * :math.sin(d_lat / 2) +
        :math.cos(lat1 * :math.pi() / 180) * :math.cos(lat2 * :math.pi() / 180) *
          :math.sin(d_lng / 2) * :math.sin(d_lng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    r * c
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
