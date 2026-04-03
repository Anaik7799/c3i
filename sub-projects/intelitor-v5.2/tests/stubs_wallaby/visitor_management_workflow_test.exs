defmodule Intelitor.VisitorManagementWorkflowTest do
  use Intelitor.WallabyCase

  @moduletag :wallaby
  @moduletag :e2e

  describe "Visitor Management Complete Workflow" do
    setup do
      # Setup test environment
      tenant = insert(:tenant, name: "Corporate Security")

      # Create users with different roles
      admin_user = insert(:user, tenant: tenant, email: "admin@corp.com", role: "admin")

      security_user =
        insert(:user, tenant: tenant, email: "security@corp.com", role: "security")

      receptionist_user =
        insert(:user, tenant: tenant, email: "reception@corp.com", role: "receptionist")

      # Setup site structure
      site = insert(:site, tenant: tenant, name: "Corporate Headquarters")
      building = insert(:building, site: site, tenant: tenant, name: "Main Building")
      floor = insert(:floor, building: building, tenant: tenant, name: "1st Floor")

      # Create locations
      lobby = insert(:location, floor: floor, tenant: tenant, name: "Main Lobby")
      conf_room_a = insert(:location, floor: floor, tenant: tenant, name: "Conference Room A")
      exec_floor = insert(:location, floor: floor, tenant: tenant, name: "Executive Floor")

      # Create visitor types
      guest_type =
        insert(:visitor_type, tenant: tenant, type_name: "Guest", access_level: "basic")

      contractor_type =
        insert(:visitor_type, tenant: tenant, type_name: "Contractor", access_level: "extended")

      vip_type =
        insert(:visitor_type, tenant: tenant, type_name: "VIP Guest", access_level: "premium")

      %{
        tenant: tenant,
        admin_user: admin_user,
        security_user: security_user,
        receptionist_user: receptionist_user,
        lobby: lobby,
        conf_room_a: conf_room_a,
        exec_floor: exec_floor,
        guest_type: guest_type,
        contractor_type: contractor_type,
        vip_type: vip_type
      }
    end

    test "Complete visitor registration and check-in workflow", %{session: session} = __context do
      session
      |> login_as(context.receptionist_user)
      |> visit("/visitors")
      |> assert_has(page_title("Visitor Management"))

      # Step 1: Register new visitor
      |> click(button("New Visitor"))
      |> assert_has(page_title("Register Visitor"))
      |> fill_in(text_field("First Name"), with: "John")
      |> fill_in(text_field("Last Name"), with: "Smith")
      |> fill_in(text_field("Email"), with: "john.smith@client.com")
      |> fill_in(text_field("Phone"), with: "+1-555-123-4567")
      |> fill_in(text_field("Company"), with: "Client Corporation")
      |> select(context.guest_type.type_name, from: "Visitor Type")
      |> fill_in(text_field("Purpose of Visit"), with: "Business meeting with sales team")
      |> fill_in(text_field("Host Employee"), with: "Sarah Johnson")
      |> select(context.conf_room_a.name, from: "Destination")
      # 30 minutes from now
      |> fill_in(datetime_field("Expected Arrival"), with: DateTime.add(DateTime.utc_now(), 1800))
      # 1.5 hours from now
      |> fill_in(datetime_field("Expected Departure"),
        with: DateTime.add(DateTime.utc_now(), 5400)
      )
      |> click(button("Register Visitor"))
      |> assert_has(css("[data-test='visitor-registered']"))
      |> assert_has(Wallaby.Query.text("Visitor John Smith registered successfully"))

      # Step 2: Navigate to visitor list and verify registration
      |> visit("/visitors")
      |> assert_has(Wallaby.Query.text("John Smith"))
      |> assert_has(Wallaby.Query.text("Client Corporation"))
      |> assert_has(css("[data-test='visitor-status']", text: "Expected"))

      # Step 3: Visitor arrives - perform check-in
      |> click(css("[data-test='visitor-john-smith'] [data-test='check-in-button']"))
      |> assert_has(css("[data-test='check-in-dialog']"))
      |> assert_has(Wallaby.Query.text("Check in John Smith"))

      # Capture visitor photo
      |> click(button("Take Photo"))
      |> assert_has(css("[data-test='camera-preview']"))
      |> click(button("Capture"))
      |> assert_has(css("[data-test='photo-captured']"))

      # ID verification
      |> fill_in(text_field("ID Type"), with: "Driver's License")
      |> fill_in(text_field("ID Number"), with: "DL123456789")
      |> click(checkbox("ID Verified"))

      # Security screening
      |> click(checkbox("Metal Detector Clear"))
      |> click(checkbox("Bag Inspection Complete"))
      |> fill_in(textarea("Security Notes"), with: "No prohibited items found")

      # Generate visitor badge
      |> click(button("Generate Badge"))
      |> assert_has(css("[data-test='badge-preview']"))
      |> assert_has(Wallaby.Query.text("John Smith"))
      |> assert_has(Wallaby.Query.text("Guest"))
      |> assert_has(Wallaby.Query.text("Conference Room A"))
      |> click(button("Print Badge"))
      |> assert_has(css("[data-test='badge-printed']"))

      # Complete check-in
      |> click(button("Complete Check-in"))
      |> assert_has(css("[data-test='check-in-complete']"))
      |> assert_has(Wallaby.Query.text("John Smith checked in successfully"))
      |> assert_has(css("[data-test='visitor-status']", text: "Checked In"))
    end

    test "Visitor access control and location tracking", %{session: session} = __context do
      # Pre-register a visitor
      visitor =
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Alice",
          last_name: "Johnson",
          email: "alice.johnson@vendor.com",
          company: "Vendor Solutions",
          visitor_type: context.contractor_type,
          status: :checked_in,
          checked_in_at: DateTime.utc_now()
        )

      # Create visitor access permissions
      access_grant =
        insert(:visitor_access,
          tenant: context.tenant,
          visitor: visitor,
          location: context.conf_room_a,
          access_level: :contractor,
          granted_at: DateTime.utc_now(),
          # 2 hours
          expires_at: DateTime.add(DateTime.utc_now(), 7200)
        )

      session
      |> login_as(context.security_user)
      |> visit("/visitors/tracking")
      |> assert_has(page_title("Visitor Tracking"))
      |> assert_has(Wallaby.Query.text("Alice Johnson"))
      |> assert_has(
        css("[data-test='visitor-#{visitor.id}'] [data-test='status']", text: "Checked In")
      )
      |> assert_has(
        css("[data-test='visitor-#{visitor.id}'] [data-test='location']",
          text: "Conference Room A"
        )
      )

      # Simulate access attempt to authorized location
      |> click(css("[data-test='visitor-#{visitor.id}'] [data-test='track-button']"))
      |> assert_has(css("[data-test='access-log']"))
      |> simulate_access_attempt(visitor.id, context.conf_room_a.id, "authorized")
      |> assert_has(css("[data-test='access-granted']", text: "Access Granted"))
      |> assert_has(Wallaby.Query.text("Conference Room A"))

      # Simulate access attempt to unauthorized location
      |> simulate_access_attempt(visitor.id, context.exec_floor.id, "unauthorized")
      |> assert_has(css("[data-test='access-denied']", text: "Access Denied"))
      |> assert_has(Wallaby.Query.text("Executive Floor"))
      |> assert_has(css("[data-test='security-alert']"))

      # View detailed access log
      |> click(tab("Access History"))
      |> assert_has(Wallaby.Query.text("Conference Room A - Granted"))
      |> assert_has(Wallaby.Query.text("Executive Floor - Denied"))
      |> assert_has(css("[data-test='access-count']", text: "2"))
    end

    test "Visitor badge management and printing", %{session: session} = __context do
      visitor =
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Michael",
          last_name: "Brown",
          company: "Tech Partners",
          visitor_type: context.vip_type,
          status: :registered
        )

      session
      |> login_as(context.receptionist_user)
      |> visit("/visitors/#{visitor.id}/badge")
      |> assert_has(page_title("Visitor Badge"))

      # Customize badge design
      |> select("VIP Template", from: "Badge Template")
      |> fill_in(text_field("Badge Number"), with: "VIP-001")
      |> select("Executive Floor", from: "Access Zones")
      |> fill_in(textarea("Special Instructions"), with: "Escort required to executive areas")

      # Badge preview
      |> click(button("Preview Badge"))
      |> assert_has(css("[data-test='badge-preview']"))
      |> assert_has(Wallaby.Query.text("Michael Brown"))
      |> assert_has(Wallaby.Query.text("Tech Partners"))
      |> assert_has(Wallaby.Query.text("VIP Guest"))
      |> assert_has(Wallaby.Query.text("VIP-001"))
      |> assert_has(css("[data-test='vip-styling']"))

      # Print badge
      |> click(button("Print Badge"))
      |> assert_has(css("[data-test='print-dialog']"))
      |> select("Badge Printer 1", from: "Printer")
      |> click(checkbox("Print Temporary Pass"))
      |> click(button("Print"))
      |> assert_has(css("[data-test='badge-printed']"))
      |> assert_has(Wallaby.Query.text("Badge printed successfully"))

      # Verify badge is issued
      |> visit("/visitors")
      |> assert_has(
        css("[data-test='visitor-#{visitor.id}'] [data-test='badge-status']", text: "Issued")
      )
    end

    test "Visitor check-out and departure workflow", %{session: session} = __context do
      visitor =
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Sarah",
          last_name: "Wilson",
          company: "Consulting Group",
          visitor_type: context.guest_type,
          status: :checked_in,
          # Checked in 1 hour ago
          checked_in_at: DateTime.add(DateTime.utc_now(), -3600),
          badge_number: "GUEST-123"
        )

      session
      |> login_as(context.receptionist_user)
      |> visit("/visitors")
      |> assert_has(Wallaby.Query.text("Sarah Wilson"))
      |> assert_has(
        css("[data-test='visitor-#{visitor.id}'] [data-test='status']", text: "Checked In")
      )

      # Initiate check-out process
      |> click(css("[data-test='visitor-#{visitor.id}'] [data-test='check-out-button']"))
      |> assert_has(css("[data-test='check-out-dialog']"))
      |> assert_has(Wallaby.Query.text("Check out Sarah Wilson"))

      # Badge collection
      |> click(checkbox("Badge Returned"))
      |> fill_in(text_field("Badge Condition"), with: "Good condition")

      # Exit interview (optional)
      |> fill_in(textarea("Visit Feedback"),
        with: "Very productive meeting, excellent facilities"
      )
      |> select("5 - Excellent", from: "Security Experience Rating")
      |> select("5 - Excellent", from: "Facility Rating")

      # Final security check
      |> click(checkbox("Exit Security Check Complete"))
      |> fill_in(textarea("Security Notes"), with: "No issues, visitor escorted to exit")

      # Complete check-out
      |> click(button("Complete Check-out"))
      |> assert_has(css("[data-test='check-out-complete']"))
      |> assert_has(Wallaby.Query.text("Sarah Wilson checked out successfully"))
      |> assert_has(css("[data-test='visitor-status']", text: "Departed"))

      # Verify departure time recorded
      |> click(css("[data-test='visitor-#{visitor.id}'] [data-test='view-details']"))
      |> assert_has(Wallaby.Query.text("Checked In:"))
      |> assert_has(Wallaby.Query.text("Checked Out:"))
      |> assert_has(Wallaby.Query.text("Visit Duration: 1 hour"))
    end

    test "Visitor group management workflow", %{session: session} = __context do
      session
      |> login_as(context.receptionist_user)
      |> visit("/visitors/groups")
      |> assert_has(page_title("Visitor Groups"))

      # Create new visitor group
      |> click(button("New Group"))
      |> assert_has(page_title("Create Visitor Group"))
      |> fill_in(text_field("Group Name"), with: "Board of Directors Meeting")
      |> fill_in(text_field("Lead Contact"), with: "Robert CEO")
      |> fill_in(text_field("Purpose"), with: "Quarterly board meeting")
      |> select(context.exec_floor.name, from: "Destination")
      |> fill_in(datetime_field("Expected Arrival"), with: DateTime.add(DateTime.utc_now(), 3600))
      |> fill_in(number_field("Expected Group Size"), with: "8")
      |> click(button("Create Group"))
      |> assert_has(css("[data-test='group-created']"))

      # Add visitors to group
      |> click(button("Add Visitor"))
      |> fill_in(text_field("First Name"), with: "Board")
      |> fill_in(text_field("Last Name"), with: "Member1")
      |> fill_in(text_field("Email"), with: "member1@board.com")
      |> select(context.vip_type.type_name, from: "Visitor Type")
      |> click(button("Add to Group"))
      |> assert_has(css("[data-test='visitor-added']"))

      # Add second visitor
      |> click(button("Add Visitor"))
      |> fill_in(text_field("First Name"), with: "Board")
      |> fill_in(text_field("Last Name"), with: "Member2")
      |> fill_in(text_field("Email"), with: "member2@board.com")
      |> select(context.vip_type.type_name, from: "Visitor Type")
      |> click(button("Add to Group"))
      |> assert_has(css("[data-test='visitor-added']"))

      # Verify group composition
      |> assert_has(css("[data-test='group-size']", text: "2 of 8 registered"))
      |> assert_has(Wallaby.Query.text("Board Member1"))
      |> assert_has(Wallaby.Query.text("Board Member2"))

      # Bulk check-in for group
      |> click(button("Group Check-in"))
      |> assert_has(css("[data-test='group-check-in']"))
      |> click(checkbox("All visitors present"))
      |> click(checkbox("Security screening complete for all"))
      |> click(button("Check in All Visitors"))
      |> assert_has(css("[data-test='group-checked-in']"))
      |> assert_has(Wallaby.Query.text("2 visitors checked in successfully"))
    end

    test "Visitor emergency evacuation workflow", %{session: session} = __context do
      # Setup checked-in visitors
      visitors = [
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Emergency",
          last_name: "Test1",
          status: :checked_in,
          checked_in_at: DateTime.utc_now()
        ),
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Emergency",
          last_name: "Test2",
          status: :checked_in,
          checked_in_at: DateTime.utc_now()
        ),
        insert(:visitor,
          tenant: context.tenant,
          first_name: "Emergency",
          last_name: "Test3",
          status: :checked_in,
          checked_in_at: DateTime.utc_now()
        )
      ]

      session
      |> login_as(context.security_user)
      |> visit("/visitors/emergency")
      |> assert_has(page_title("Emergency Visitor Management"))
      |> assert_has(css("[data-test='checked-in-count']", text: "3"))

      # Initiate emergency evacuation
      |> click(button("Emergency Evacuation"))
      |> assert_has(css("[data-test='emergency-alert']"))
      |> assert_has(Wallaby.Query.text("EMERGENCY EVACUATION INITIATED"))

      # Emergency visitor accountability
      |> assert_has(Wallaby.Query.text("Emergency Test1"))
      |> assert_has(Wallaby.Query.text("Emergency Test2"))
      |> assert_has(Wallaby.Query.text("Emergency Test3"))
      |> assert_has(css("[data-test='evacuation-status']", text: "IN PROGRESS"))

      # Mark visitors as accounted for
      |> click(css("[data-test='visitor-#{Enum.at(visitors, 0).id}'] [data-test='mark-safe']"))
      |> assert_has(
        css("[data-test='visitor-#{Enum.at(visitors, 0).id}'] [data-test='status']",
          text: "Safe"
        )
      )
      |> click(css("[data-test='visitor-#{Enum.at(visitors, 1).id}'] [data-test='mark-safe']"))
      |> assert_has(
        css("[data-test='visitor-#{Enum.at(visitors, 1).id}'] [data-test='status']",
          text: "Safe"
        )
      )
      |> click(css("[data-test='visitor-#{Enum.at(visitors, 2).id}'] [data-test='mark-safe']"))
      |> assert_has(
        css("[data-test='visitor-#{Enum.at(visitors, 2).id}'] [data-test='status']",
          text: "Safe"
        )
      )

      # Complete evacuation accountability
      |> assert_has(css("[data-test='all-accounted']", text: "All visitors accounted for"))
      |> click(button("Complete Evacuation"))
      |> assert_has(css("[data-test='evacuation-complete']"))
      |> assert_has(Wallaby.Query.text("Emergency evacuation completed - all visitors safe"))
    end

    test "Visitor analytics and reporting", %{session: session} = __context do
      # Create historical visitor data
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      last_week = Date.add(today, -7)

      # Today's visitors
      create_list(5, :visitor,
        tenant: context.tenant,
        status: :checked_in,
        checked_in_at: DateTime.new!(today, ~T[09:00:00])
      )

      create_list(3, :visitor,
        tenant: context.tenant,
        status: :departed,
        checked_in_at: DateTime.new!(today, ~T[10:00:00]),
        checked_out_at: DateTime.new!(today, ~T[15:00:00])
      )

      # Yesterday's visitors
      create_list(7, :visitor,
        tenant: context.tenant,
        status: :departed,
        checked_in_at: DateTime.new!(yesterday, ~T[09:00:00]),
        checked_out_at: DateTime.new!(yesterday, ~T[17:00:00])
      )

      session
      |> login_as(context.admin_user)
      |> visit("/visitors/analytics")
      |> assert_has(page_title("Visitor Analytics"))

      # Dashboard overview
      |> assert_has(css("[data-test='current-visitors']", text: "5"))
      |> assert_has(css("[data-test='today-total']", text: "8"))
      |> assert_has(css("[data-test='yesterday-total']", text: "7"))

      # Time-based analytics
      |> click(tab("Traffic Patterns"))
      |> assert_has(css("[data-test='peak-hours-chart']"))
      |> assert_has(Wallaby.Query.text("Peak Hours: 9:00 AM - 11:00 AM"))

      # Visitor type distribution
      |> click(tab("Visitor Types"))
      |> assert_has(css("[data-test='visitor-type-chart']"))
      |> assert_has(Wallaby.Query.text("Guest"))
      |> assert_has(Wallaby.Query.text("Contractor"))
      |> assert_has(Wallaby.Query.text("VIP Guest"))

      # Generate detailed report
      |> click(tab("Reports"))
      |> select("Last 7 Days", from: "Time Period")
      |> click(checkbox("Include Check-in/Check-out Times"))
      |> click(checkbox("Include Visitor Photos"))
      |> click(checkbox("Include Access Logs"))
      |> select("PDF", from: "Export Format")
      |> click(button("Generate Report"))
      |> assert_has(css("[data-test='report-generating']"))
      |> assert_has(css("[data-test='report-ready']"))
      |> click(link("Download Report"))
    end
  end

  # Use centralized authentication from WallabyCase
  defp login_as(session, user) do
    authenticate_user(session, user)
  end

  defp simulate_access_attempt(session, visitorid, location_id, result) do
    session
    |> execute_script(
      "window.dispatchEvent(new CustomEvent('access-attempt', { detail: { visitorId: '#{visitor_id}', locationId: '#{location_id}', result: '#{result}', timestamp: '#{DateTime.utc_now()}' } }))"
    )
  end

  defp page_title(title), do: css("h1", text: title)

  defp text_field(label),
    do: css("input[aria-label='#{label}'], label:contains('#{label}') + input")

  defp datetime_field(label),
    do:
      css(
        "input[type='datetime-local'][aria-label='#{label}'], label:contains('#{label}') + input[type='datetime-local']"
      )

  defp number_field(label),
    do:
      css(
        "input[type='number'][aria-label='#{label}'], label:contains('#{label}') + input[type='number']"
      )

  defp textarea(label),
    do: css("textarea[aria-label='#{label}'], label:contains('#{label}') + textarea")

  defp button(text), do: css("button:contains('#{text}')")
  defp tab(text), do: css("[role='tab']:contains('#{text}')")

  defp checkbox(label),
    do:
      css(
        "input[type='checkbox'][aria-label='#{label}'], label:contains('#{label}') input[type='checkbox']"
      )
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
