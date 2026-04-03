defmodule Indrajaal.VisitorManagement.VisitorTest do
  @moduledoc """
  Comprehensive test suite for Visitor resource.
  Tests visitor registration, security clearance, and access management workflows.
  """

  use Indrajaal.DataCase, async: true
  # Removed VisitorManagementFactory to avoid undefined function errors
  # Using standard factories instead

  alias Indrajaal.VisitorManagement.Visitor
  alias Indrajaal.VisitorManagement

  describe "Visitor.register_visitor / 1" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      visitor_type =
        insert(:visitor_type, %{
          tenant_id: tenant.id,
          organization_id: organization.id,
          name: "Contractor",
          code: "CONT"
        })

      %{tenant: tenant, organization: organization, visitor_type: visitor_type}
    end

    test "registers new visitor with required attributes", %{
      tenant: tenant,
      visitor_type: visitor_type
    } do
      args = %{
        visitor_id: "VIS-2024-001",
        first_name: "John",
        last_name: "Smith",
        email: "john.smith@contractor.com",
        visitor_type_id: visitor_type.id,
        identification_type: :drivers_license,
        identification_number: "DL123456789"
      }

      actor = %{tenant_id: tenant.id, role: "security_officer"}

      assert {:ok, visitor} = Visitor.register_visitor(args, actor: actor)
      assert visitor.visitor_id == "VIS-2024-001"
      assert visitor.first_name == "John"
      assert visitor.last_name == "Smith"
      assert visitor.email == "john.smith@contractor.com"
      assert visitor.identification_type == :drivers_license
      assert visitor.identification_number == "DL123456789"
      assert visitor.tenant_id == tenant.id
      assert visitor.visitor_type_id == visitor_type.id
      assert visitor.security_clearance_level == :none
      assert visitor.background_check_status == :not_required
      assert visitor.blacklisted == false
    end

    test "supports all identification types", %{
      tenant: tenant,
      visitor_type: visitor_type
    } do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      identification_types = [:drivers_license, :passport, :national_id, :military_id, :other]

      Enum.each(identification_types, fn id_type ->
        id_number =
          case id_type do
            :drivers_license -> "DL#{:rand.uniform(99_999_999)}"
            :passport -> "P#{:rand.uniform(99_999_999)}"
            :national_id -> "#{:rand.uniform(999_999_999)}"
            :military_id -> "MIL#{:rand.uniform(9_999_999)}"
            :other -> "OTHER#{:rand.uniform(999_999)}"
          end

        args = %{
          visitor_id: "VIS-#{id_type}-001",
          first_name: "Test",
          last_name: "User",
          email: "test.#{id_type}@example.com",
          visitor_type_id: visitor_type.id,
          identification_type: id_type,
          identification_number: id_number
        }

        assert {:ok, visitor} = Visitor.register_visitor(args, actor: actor)
        assert visitor.identification_type == id_type
        assert visitor.identification_number == id_number
      end)
    end

    test "enforces unique visitor_id per tenant", %{
      tenant: tenant,
      visitor_type: visitor_type
    } do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      base_args = %{
        visitor_id: "VIS-DUPLICATE-001",
        first_name: "First",
        last_name: "Visitor",
        email: "first@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :passport,
        identification_number: "P123456789"
      }

      # Create first visitor
      assert {:ok, _visitor1} = Visitor.register_visitor(base_args, actor: actor)

      # Try to create duplicate
      duplicate_args = %{
        base_args
        | first_name: "Second",
          email: "second@example.com",
          identification_number: "P987654321"
      }

      assert {:error, changeset} = Visitor.register_visitor(duplicate_args, actor: actor)
      assert "has already been taken" in errors_on(changeset).visitor_id
    end

    test "enforces unique identification_number per tenant", %{
      tenant: tenant,
      visitor_type: visitor_type
    } do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      id_number = "DL555555555"

      args1 = %{
        visitor_id: "VIS-ID-001",
        first_name: "First",
        last_name: "Person",
        email: "first@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :drivers_license,
        identification_number: id_number
      }

      args2 = %{
        visitor_id: "VIS-ID-002",
        first_name: "Second",
        last_name: "Person",
        email: "second@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :drivers_license,
        identification_number: id_number
      }

      # Create first visitor
      assert {:ok, _visitor1} = Visitor.register_visitor(args1, actor: actor)

      # Try to create with same ID number
      assert {:error, changeset} = Visitor.register_visitor(args2, actor: actor)
      assert "has already been taken" in errors_on(changeset).identification_number
    end

    test "allows same visitor_id and identification across different tenants", %{
      visitor_type: visitor_type
    } do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      visitor_type2 = insert(:visitor_type, %{tenant_id: tenant2.id})

      actor1 = %{tenant_id: tenant1.id, role: "security_officer"}
      actor2 = %{tenant_id: tenant2.id, role: "security_officer"}

      shared_visitor_id = "VIS-SHARED-001"
      shared_id_number = "DL999999999"

      args1 = %{
        visitor_id: shared_visitor_id,
        first_name: "Tenant1",
        last_name: "Visitor",
        email: "tenant1@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :drivers_license,
        identification_number: shared_id_number
      }

      args2 = %{
        visitor_id: shared_visitor_id,
        first_name: "Tenant2",
        last_name: "Visitor",
        email: "tenant2@example.com",
        visitor_type_id: visitor_type2.id,
        identification_type: :drivers_license,
        identification_number: shared_id_number
      }

      assert {:ok, visitor1} = Visitor.register_visitor(args1, actor: actor1)
      assert {:ok, visitor2} = Visitor.register_visitor(args2, actor: actor2)

      assert visitor1.visitor_id == shared_visitor_id
      assert visitor2.visitor_id == shared_visitor_id
      assert visitor1.identification_number == shared_id_number
      assert visitor2.identification_number == shared_id_number
      assert visitor1.tenant_id != visitor2.tenant_id
    end

    test "validates email format", %{tenant: tenant, visitor_type: visitor_type} do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      invalid_emails = [
        "invalid-email",
        "missing@domain",
        "@missing-local.com",
        "spaces in@email.com",
        "double@@email.com"
      ]

      Enum.each(invalid_emails, fn invalid_email ->
        args = %{
          visitor_id: "VIS-INVALID-#{:rand.uniform(999)}",
          first_name: "Test",
          last_name: "User",
          email: invalid_email,
          visitor_type_id: visitor_type.id,
          identification_type: :passport,
          identification_number: "P#{:rand.uniform(99_999_999)}"
        }

        assert {:error, changeset} = Visitor.register_visitor(args, actor: actor)
        assert "must be a valid email address" in errors_on(changeset).email
      end)
    end
  end

  describe "Visitor.update_contact_info / 2" do
    setup do
      tenant = insert(:tenant)

      visitor =
        insert(:visitor, %{
          tenant_id: tenant.id,
          phone_number: "555-0100",
          company: "Old Company"
        })

      %{tenant: tenant, visitor: visitor}
    end

    test "updates contact information", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      args = %{
        phone_number: "555-0200",
        company: "New Company Inc",
        job_title: "Senior Engineer",
        emergency_contact_name: "Jane Doe",
        emergency_contact_phone: "555-0300"
      }

      assert {:ok, updated_visitor} = Visitor.update_contact_info(visitor, args, actor: actor)
      assert updated_visitor.phone_number == "555-0200"
      assert updated_visitor.company == "New Company Inc"
      assert updated_visitor.job_title == "Senior Engineer"
      assert updated_visitor.emergency_contact_name == "Jane Doe"
      assert updated_visitor.emergency_contact_phone == "555-0300"
    end

    test "allows partial updates", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      # Update only phone number
      args = %{phone_number: "555-9999"}

      assert {:ok, updated_visitor} = Visitor.update_contact_info(visitor, args, actor: actor)
      assert updated_visitor.phone_number == "555-9999"
      # Unchanged
      assert updated_visitor.company == "Old Company"
    end
  end

  describe "Visitor.update_security_clearance / 2" do
    setup do
      tenant = insert(:tenant)

      visitor =
        insert(:visitor, %{
          tenant_id: tenant.id,
          security_clearance_level: :none,
          background_check_status: :not_required
        })

      %{tenant: tenant, visitor: visitor}
    end

    test "updates security clearance and background check", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      check_date = Date.utc_today()
      expiry_date = Date.add(check_date, 365)

      args = %{
        clearance_level: :confidential,
        background_check_status: :approved,
        check_date: check_date,
        expiry_date: expiry_date
      }

      assert {:ok, updated_visitor} =
               Visitor.update_security_clearance(visitor, args, actor: actor)

      assert updated_visitor.security_clearance_level == :confidential
      assert updated_visitor.background_check_status == :approved
      assert updated_visitor.background_check_date == check_date
      assert updated_visitor.background_check_expiry == expiry_date
    end

    test "supports all clearance levels", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      clearance_levels = [:none, :public_trust, :confidential, :secret, :top_secret]

      Enum.each(clearance_levels, fn level ->
        args = %{
          clearance_level: level,
          background_check_status: :approved
        }

        assert {:ok, updated_visitor} =
                 Visitor.update_security_clearance(visitor, args, actor: actor)

        assert updated_visitor.security_clearance_level == level
      end)
    end

    test "supports all background check statuses", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      check_statuses = [:not_required, :pending, :in_progress, :approved, :rejected, :expired]

      Enum.each(check_statuses, fn status ->
        args = %{
          clearance_level: :public_trust,
          background_check_status: status
        }

        assert {:ok, updated_visitor} =
                 Visitor.update_security_clearance(visitor, args, actor: actor)

        assert updated_visitor.background_check_status == status
      end)
    end
  end

  describe "Visitor.blacklist_visitor / 2 and remove_from_blacklist / 1" do
    setup do
      tenant = insert(:tenant)

      visitor =
        insert(:visitor, %{
          tenant_id: tenant.id,
          blacklisted: false
        })

      %{tenant: tenant, visitor: visitor}
    end

    test "blacklists visitor with reason", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      args = %{reason: "Security breach-unauthorized access attempt"}

      assert {:ok, blacklisted_visitor} = Visitor.blacklist_visitor(visitor, args, actor: actor)
      assert blacklisted_visitor.blacklisted == true

      assert blacklisted_visitor.blacklist_reason ==
               "Security breach-unauthorized access attempt"
    end

    test "removes visitor from blacklist", %{tenant: tenant} do
      blacklisted_visitor =
        insert(:visitor, %{
          tenant_id: tenant.id,
          blacklisted: true,
          blacklist_reason: "Previous security incident"
        })

      actor = %{tenant_id: tenant.id, role: "security_manager"}

      assert {:ok, cleared_visitor} =
               Visitor.remove_from_blacklist(blacklisted_visitor, actor: actor)

      assert cleared_visitor.blacklisted == false
      assert cleared_visitor.blacklist_reason == nil
    end
  end

  describe "Visitor.upload_photo / 2" do
    setup do
      tenant = insert(:tenant)
      visitor = insert(:visitor, %{tenant_id: tenant.id})

      %{tenant: tenant, visitor: visitor}
    end

    test "uploads visitor photo", %{tenant: tenant, visitor: visitor} do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      args = %{photo_url: "https://storage.example.com/photos/visitor123.jpg"}

      assert {:ok, updated_visitor} = Visitor.upload_photo(visitor, args, actor: actor)
      assert updated_visitor.photo_url == "https://storage.example.com/photos/visitor123.jpg"
    end
  end

  describe "Visitor calculations" do
    setup do
      tenant = insert(:tenant)

      # Visitor with no expiry
      visitor_no_expiry =
        insert(:visitor, %{
          tenant_id: tenant.id,
          first_name: "John",
          last_name: "NoExpiry",
          background_check_expiry: nil
        })

      # Visitor with future expiry
      visitor_future_expiry =
        insert(:visitor, %{
          tenant_id: tenant.id,
          first_name: "Jane",
          last_name: "FutureExpiry",
          background_check_expiry: Date.add(Date.utc_today(), 30)
        })

      # Visitor with expired clearance
      visitor_expired =
        insert(:visitor, %{
          tenant_id: tenant.id,
          first_name: "Bob",
          last_name: "Expired",
          background_check_expiry: Date.add(Date.utc_today(), -10)
        })

      %{
        tenant: tenant,
        visitor_no_expiry: visitor_no_expiry,
        visitor_future_expiry: visitor_future_expiry,
        visitor_expired: visitor_expired
      }
    end

    test "calculates full_name", %{tenant: tenant, visitor_no_expiry: visitor_no_expiry} do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded]} =
               Visitor.read([visitor_no_expiry.id], actor: actor, load: [:full_name])

      assert loaded.full_name == "John NoExpiry"
    end

    test "calculates is_clearance_expired", %{
      tenant: tenant,
      visitor_no_expiry: visitor_no_expiry,
      visitor_future_expiry: visitor_future_expiry,
      visitor_expired: visitor_expired
    } do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded_no_expiry]} =
               Visitor.read([visitor_no_expiry.id], actor: actor, load: [:is_clearance_expired])

      assert loaded_no_expiry.is_clearance_expired == false

      assert {:ok, [loaded_future]} =
               Visitor.read([visitor_future_expiry.id],
                 actor: actor,
                 load: [:is_clearance_expired]
               )

      assert loaded_future.is_clearance_expired == false

      assert {:ok, [loaded_expired]} =
               Visitor.read([visitor_expired.id], actor: actor, load: [:is_clearance_expired])

      assert loaded_expired.is_clearance_expired == true
    end

    test "calculates days_until_clearance_expiry", %{
      tenant: tenant,
      visitor_no_expiry: visitor_no_expiry,
      visitor_future_expiry: visitor_future_expiry,
      visitor_expired: visitor_expired
    } do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded_no_expiry]} =
               Visitor.read([visitor_no_expiry.id],
                 actor: actor,
                 load: [:days_until_clearance_expiry]
               )

      assert loaded_no_expiry.days_until_clearance_expiry == nil

      assert {:ok, [loaded_future]} =
               Visitor.read([visitor_future_expiry.id],
                 actor: actor,
                 load: [:days_until_clearance_expiry]
               )

      assert loaded_future.days_until_clearance_expiry == 30

      assert {:ok, [loaded_expired]} =
               Visitor.read([visitor_expired.id],
                 actor: actor,
                 load: [:days_until_clearance_expiry]
               )

      assert loaded_expired.days_until_clearance_expiry == -10
    end
  end

  describe "Visitor authorization and tenant isolation" do
    setup do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      visitor1 = insert(:visitor, %{tenant_id: tenant1.id})
      visitor2 = insert(:visitor, %{tenant_id: tenant2.id})

      %{
        tenant1: tenant1,
        tenant2: tenant2,
        visitor1: visitor1,
        visitor2: visitor2
      }
    end

    test "users can only access visitors in their tenant", %{
      tenant1: tenant1,
      tenant2: tenant2,
      visitor1: visitor1,
      visitor2: visitor2
    } do
      actor1 = %{tenant_id: tenant1.id, role: "security_officer"}
      actor2 = %{tenant_id: tenant2.id, role: "security_officer"}

      # Actor1 can access visitor1 but not visitor2
      assert {:ok, [found_visitor]} = Visitor.read([visitor1.id], actor: actor1)
      assert found_visitor.id == visitor1.id

      assert {:ok, []} = Visitor.read([visitor2.id], actor: actor1)

      # Actor2 can access visitor2 but not visitor1
      assert {:ok, [found_visitor]} = Visitor.read([visitor2.id], actor: actor2)
      assert found_visitor.id == visitor2.id

      assert {:ok, []} = Visitor.read([visitor1.id], actor: actor2)
    end

    test "list queries respect tenant isolation", %{tenant1: tenant1, tenant2: tenant2} do
      actor1 = %{tenant_id: tenant1.id, role: "viewer"}
      actor2 = %{tenant_id: tenant2.id, role: "viewer"}

      assert {:ok, visitors1} = Visitor.read(actor: actor1)
      assert {:ok, visitors2} = Visitor.read(actor: actor2)

      assert Enum.all?(visitors1, &(&1.tenant_id == tenant1.id))
      assert Enum.all?(visitors2, &(&1.tenant_id == tenant2.id))

      # Should not overlap
      visitor1_ids = visitors1 |> Enum.map(& &1.id) |> MapSet.new()
      visitor2_ids = visitors2 |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.disjoint?(visitor1_ids, visitor2_ids)
    end
  end

  describe "Visitor bulk operations and enterprise scenarios" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      visitor_types =
        Enum.map([:visitor, :vip], fn type ->
          insert(:visitor_type, %{
            tenant_id: tenant.id,
            organization_id: organization.id,
            category: type
          })
        end)

      %{tenant: tenant, organization: organization, visitor_types: visitor_types}
    end

    test "handles enterprise visitor registration workflows", %{
      tenant: tenant,
      visitor_types: visitor_types
    } do
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      # Create comprehensive visitor database
      visitor_scenarios = [
        {
          "John Smith",
          "Contractor",
          "john.smith@contractor.com",
          :drivers_license,
          "DL123456789",
          :contractor,
          :confidential
        },
        {
          "Maria Garcia",
          "VIP Guest",
          "maria.garcia@vip.com",
          :passport,
          "P987654321",
          :vip,
          :secret
        },
        {
          "David Chen",
          "Vendor Rep",
          "david.chen@vendor.com",
          :national_id,
          "ID555666777",
          :vendor,
          :public_trust
        },
        {
          "Sarah Johnson",
          "Emergency Contractor",
          "sarah.johnson@emergency.com",
          :military_id,
          "MIL12345",
          :contractor,
          :top_secret
        }
      ]

      indexed = Enum.with_index(visitor_scenarios, 1)

      visitors =
        indexed
        |> Enum.map(fn {{first_name, last_name, email, id_type, id_number, type_category,
                         clearance}, i} ->
          visitor_type =
            Enum.find(visitor_types, &(&1.category == type_category)) || List.first(visitor_types)

          # Register visitor
          register_args = %{
            visitor_id: "VIS-2024-#{String.pad_leading(to_string(i), 3, "0")}",
            first_name: first_name |> String.split(" ") |> List.first(),
            last_name: first_name |> String.split(" ") |> List.last() || last_name,
            email: email,
            visitor_type_id: visitor_type.id,
            identification_type: id_type,
            identification_number: id_number
          }

          assert {:ok, visitor} = Visitor.register_visitor(register_args, actor: actor)

          # Update contact info
          contact_args = %{
            company: "#{type_category} Company #{i}",
            job_title: "#{type_category} Position",
            phone_number: "+1_555_000#{String.pad_leading(to_string(i), 4, "0")}"
          }

          assert {:ok, updated_visitor} =
                   Visitor.update_contact_info(visitor, contact_args, actor: actor)

          # Update security clearance
          clearance_args = %{
            clearance_level: clearance,
            background_check_status: :approved,
            check_date: Date.utc_today(),
            expiry_date: Date.add(Date.utc_today(), 365)
          }

          assert {:ok, final_visitor} =
                   Visitor.update_security_clearance(updated_visitor, clearance_args,
                     actor: actor
                   )

          final_visitor
        end)

      # Verify enterprise visitor database
      assert length(visitors) == 4
      assert Enum.all?(visitors, &(&1.tenant_id == tenant.id))
      assert Enum.all?(visitors, &(&1.background_check_status == :approved))

      # Verify clearance distribution
      clearance_levels = Enum.map(visitors, & &1.security_clearance_level)
      assert :confidential in clearance_levels
      assert :secret in clearance_levels
      assert :top_secret in clearance_levels
    end

    test "supports complex visitor filtering and security management", %{
      tenant: tenant,
      visitor_types: visitor_types
    } do
      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      # Create visitors with different security profiles
      _test_visitors =
        Enum.map(1..20, fn i ->
          visitor_type = Enum.at(visitor_types, rem(i, length(visitor_types)))

          clearance_level = Enum.at([:none, :public_trust, :confidential, :secret], rem(i, 4))
          check_status = Enum.at([:not_required, :approved, :pending, :expired], rem(i, 4))
          # Every 8th visitor is blacklisted
          blacklisted = rem(i, 8) == 0

          visitor =
            insert(:visitor, %{
              tenant_id: tenant.id,
              visitor_id: "TEST-#{String.pad_leading(to_string(i), 3, "0")}",
              first_name: "Test#{i}",
              last_name: "Visitor",
              email: "test#{i}@example.com",
              visitor_type_id: visitor_type.id,
              security_clearance_level: clearance_level,
              background_check_status: check_status,
              background_check_expiry:
                if(check_status == :approved, do: Date.add(Date.utc_today(), i * 10), else: nil),
              blacklisted: blacklisted,
              blacklist_reason: if(blacklisted, do: "Security violation #{i}", else: nil)
            })

          visitor
        end)

      # Query all visitors and verify structure
      {:ok, all_visitors} = Visitor.read(actor: actor)
      assert length(all_visitors) >= 20
      assert Enum.all?(all_visitors, &(&1.tenant_id == tenant.id))

      # Test security filtering capabilities
      _high_clearance_visitors =
        Enum.filter(all_visitors, &(&1.security_clearance_level in [:secret, :top_secret]))

      blacklisted_visitors = Enum.filter(all_visitors, & &1.blacklisted)
      approved_visitors = Enum.filter(all_visitors, &(&1.background_check_status == :approved))

      # Verify filtering works
      # Every 8th visitor
      assert length(blacklisted_visitors) >= 2
      assert length(approved_visitors) >= 4

      # Test clearance expiry calculations
      visitors_with_expiry = Enum.filter(all_visitors, &(!is_nil(&1.background_check_expiry)))
      assert length(visitors_with_expiry) >= 5
    end

    test "handles visitor lifecycle management", %{tenant: tenant, visitor_types: visitor_types} do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      visitor_type = List.first(visitor_types)

      # Complete visitor lifecycle
      register_args = %{
        visitor_id: "VIS-LIFECYCLE-001",
        first_name: "Complete",
        last_name: "Lifecycle",
        email: "complete.lifecycle@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :passport,
        identification_number: "P123456789"
      }

      # 1. Register
      assert {:ok, visitor} = Visitor.register_visitor(register_args, actor: actor)
      assert visitor.security_clearance_level == :none
      assert visitor.background_check_status == :not_required

      # 2. Update contact information
      contact_args = %{
        phone_number: "+1_555_123_456",
        company: "Lifecycle Test Company",
        job_title: "Test Engineer",
        emergency_contact_name: "Emergency Contact",
        emergency_contact_phone: "+1_555_654_321"
      }

      assert {:ok, contacted_visitor} =
               Visitor.update_contact_info(visitor, contact_args, actor: actor)

      assert contacted_visitor.company == "Lifecycle Test Company"

      # 3. Upload photo
      photo_args = %{photo_url: "https://storage.example.com/photos/lifecycle.jpg"}

      assert {:ok, photo_visitor} =
               Visitor.upload_photo(contacted_visitor, photo_args, actor: actor)

      assert photo_visitor.photo_url == "https://storage.example.com/photos/lifecycle.jpg"

      # 4. Update security clearance
      clearance_args = %{
        clearance_level: :confidential,
        background_check_status: :approved,
        check_date: Date.utc_today(),
        expiry_date: Date.add(Date.utc_today(), 365)
      }

      assert {:ok, cleared_visitor} =
               Visitor.update_security_clearance(photo_visitor, clearance_args, actor: actor)

      assert cleared_visitor.security_clearance_level == :confidential
      assert cleared_visitor.background_check_status == :approved

      # 5. Blacklist for security incident
      blacklist_args = %{reason: "Security protocol violation during test"}

      assert {:ok, blacklisted_visitor} =
               Visitor.blacklist_visitor(cleared_visitor, blacklist_args, actor: actor)

      assert blacklisted_visitor.blacklisted == true
      assert blacklisted_visitor.blacklist_reason == "Security protocol violation during test"

      # 6. Remove from blacklist after investigation
      assert {:ok, final_visitor} =
               Visitor.remove_from_blacklist(blacklisted_visitor, actor: actor)

      assert final_visitor.blacklisted == false
      assert final_visitor.blacklist_reason == nil

      # Verify final state
      assert final_visitor.security_clearance_level == :confidential
      assert final_visitor.background_check_status == :approved
      assert final_visitor.company == "Lifecycle Test Company"
      assert final_visitor.photo_url == "https://storage.example.com/photos/lifecycle.jpg"
    end
  end

  describe "Visitor validation and constraints" do
    test "validates field length constraints" do
      tenant = insert(:tenant)
      visitor_type = insert(:visitor_type, %{tenant_id: tenant.id})
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      # Test maximum field lengths
      # Exceeds 100 char limit
      long_first_name = String.duplicate("A", 101)
      # Exceeds 50 char limit
      long_visitor_id = String.duplicate("V", 51)

      invalid_args = %{
        visitor_id: long_visitor_id,
        first_name: long_first_name,
        last_name: "Valid",
        email: "valid@example.com",
        visitor_type_id: visitor_type.id,
        identification_type: :passport,
        identification_number: "P123456789"
      }

      assert {:error, changeset} = Visitor.register_visitor(invalid_args, actor: actor)

      errors = errors_on(changeset)
      assert "should be at most 50 character(s)" in (errors[:visitor_id] || [])
      assert "should be at most 100 character(s)" in (errors[:first_name] || [])
    end

    test "handles edge cases for dates and special fields" do
      tenant = insert(:tenant)
      visitor_type = insert(:visitor_type, %{tenant_id: tenant.id})
      actor = %{tenant_id: tenant.id, role: "security_officer"}

      # Create visitor with edge case dates
      # ~82 years old
      very_old_birth = Date.add(Date.utc_today(), -30_000)
      # 10 years future
      future_expiry = Date.add(Date.utc_today(), 3650)

      visitor =
        insert(:visitor, %{
          tenant_id: tenant.id,
          visitor_type_id: visitor_type.id,
          date_of_birth: very_old_birth,
          identification_expiry: future_expiry,
          special_requirements: [
            "wheelchair_accessible",
            "dietary_kosher",
            "interpreter_spanish"
          ]
        })

      # Test that edge cases are handled properly
      {:ok, [loaded_visitor]} = Visitor.read([visitor.id], actor: actor, load: [:full_name])
      assert loaded_visitor.date_of_birth == very_old_birth
      assert loaded_visitor.identification_expiry == future_expiry
      assert length(loaded_visitor.special_requirements) == 3
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic execution
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
