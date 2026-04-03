defmodule IndrajaalWeb.PatrolChannelTest do
  @moduledoc """
  Test suite for patrol/guard tour real-time updates channel.

  Following TDG methodology - tests written for implementation validation.

  Agent: Worker-9 manages patrol channel testing
  SOPv5.11 Compliance: ✅
  STAMP Safety: SC-CNT-009 tenant isolation enforced
  """

  use IndrajaalWeb.ChannelCase

  import Indrajaal.Factory

  alias IndrajaalWeb.{MobileSocket, PatrolChannel}
  alias Indrajaal.GuardTours
  alias Indrajaal.Authentication.JWT

  setup do
    {:ok, test_user} = create_test_user()
    {:ok, token, _} = JWT.generate_token(test_user)
    {:ok, socket} = connect(MobileSocket, %{"token" => token})

    {:ok, socket: socket, user: test_user}
  end

  describe "channel join" do
    test "joins patrol channel for tenant", %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{user.tenant_id}")

      assert socket.assigns.tenant_id == user.tenant_id
    end

    test "joins specific tour channel", %{socket: socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)

      {:ok, _, socket} = subscribe_and_join(socket, PatrolChannel, "patrol:tour:#{tour.id}")
      assert socket.assigns.tour_id == tour.id
    end

    test "joins guard channel", %{socket: socket, user: user} do
      {:ok, guard} = create_test_guard(user.tenant_id)

      {:ok, _, socket} = subscribe_and_join(socket, PatrolChannel, "patrol:guard:#{guard.id}")
      assert socket.assigns.guard_id == guard.id
    end

    test "prevents joining other tenant's patrol channel", %{socket: socket} do
      other_tenant_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{other_tenant_id}")
    end
  end

  describe "tour events" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{user.tenant_id}")

      {:ok, socket: socket, user: user}
    end

    test "handles list_tours request", %{socket: socket} do
      ref = push(socket, "list_tours", %{})

      assert_reply ref, :ok, %{tours: tours}
      assert is_list(tours)
    end

    test "handles start_tour request", %{socket: socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)

      ref = push(socket, "start_tour", %{"tour_id" => tour.id})

      assert_reply ref, :ok, %{execution: execution}
      assert execution.tour_id == tour.id
      assert execution.status == "in_progress"
    end

    test "handles scan_checkpoint request", %{socket: socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)
      {:ok, checkpoint} = create_test_checkpoint(tour.id)
      {:ok, guard} = create_test_guard(user.tenant_id)

      ref =
        push(socket, "scan_checkpoint", %{
          "checkpoint_id" => checkpoint.id,
          "guard_id" => guard.id,
          "scan_data" => %{"method" => "nfc"}
        })

      assert_reply ref, :ok, %{scan: scan}
      assert scan.checkpoint_id == checkpoint.id
    end

    test "handles complete_tour request", %{socket: socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)
      {:ok, _execution} = start_tour_execution(tour, user)

      ref =
        push(socket, "complete_tour", %{
          "tour_id" => tour.id,
          "notes" => "Tour completed successfully"
        })

      assert_reply ref, :ok, %{tour: completed_tour}
      assert completed_tour.status == "completed"
    end

    test "broadcasts tour started event", %{socket: _socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)
      {:ok, _execution} = start_tour_execution(tour, user)

      assert_broadcast "tour:started", %{execution: execution}
      assert execution.tour_id == tour.id
    end

    test "broadcasts checkpoint scanned event", %{socket: _socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)
      {:ok, checkpoint} = create_test_checkpoint(tour.id)
      {:ok, guard} = create_test_guard(user.tenant_id)

      {:ok, _scan} = record_checkpoint_scan(checkpoint, guard)

      assert_broadcast "checkpoint:scanned", %{scan: scan}
      assert scan.checkpoint_id == checkpoint.id
    end
  end

  describe "exception handling" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{user.tenant_id}")

      {:ok, socket: socket, user: user}
    end

    test "handles report_exception request", %{socket: socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)

      ref =
        push(socket, "report_exception", %{
          "tour_id" => tour.id,
          "exception_type" => "missed_checkpoint",
          "details" => "Unable to access building"
        })

      assert_reply ref, :ok, %{exception: exception}
      assert exception.tour_id == tour.id
      assert exception.exception_type == "missed_checkpoint"
    end

    test "broadcasts exception reported event", %{socket: _socket, user: user} do
      {:ok, tour} = create_test_tour(user.tenant_id)
      {:ok, _exception} = report_tour_exception(tour, user, %{type: "missed_checkpoint"})

      assert_broadcast "exception:reported", %{exception: exception}
      assert exception.tour_id == tour.id
    end
  end

  describe "guard location tracking" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{user.tenant_id}")

      {:ok, guard} = create_test_guard(user.tenant_id)
      {:ok, socket: socket, user: user, guard: guard}
    end

    test "handles update_location request", %{socket: socket, guard: guard} do
      ref =
        push(socket, "update_location", %{
          "guard_id" => guard.id,
          "latitude" => 52.5200,
          "longitude" => 13.4050,
          "accuracy" => 10.0
        })

      assert_reply ref, :ok, %{location: location}
      assert location.guard_id == guard.id
      assert_in_delta location.latitude, 52.5200, 0.0001
    end

    test "broadcasts location updated event", %{socket: _socket, guard: guard} do
      {:ok, _location} = update_guard_location(guard, %{lat: 52.5200, lng: 13.4050})

      assert_broadcast "location:updated", %{guard_id: guard_id, location: _location}
      assert guard_id == guard.id
    end
  end

  describe "error handling" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, PatrolChannel, "patrol:tenant:#{user.tenant_id}")

      {:ok, socket: socket}
    end

    test "handles invalid tour_id", %{socket: socket} do
      ref = push(socket, "start_tour", %{"tour_id" => Ecto.UUID.generate()})

      assert_reply ref, :error, %{message: message}
      assert message =~ "not found"
    end

    test "handles missing required fields", %{socket: socket} do
      ref = push(socket, "scan_checkpoint", %{})

      assert_reply ref, :error, %{message: message}
      assert message =~ "required"
    end

    test "handles unauthorized cross-tenant access", %{socket: socket} do
      other_tenant_id = Ecto.UUID.generate()
      {:ok, other_tour} = create_test_tour(other_tenant_id)

      ref = push(socket, "start_tour", %{"tour_id" => other_tour.id})

      assert_reply ref, :error, %{message: "unauthorized"}
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ []) do
    {:ok, tenant} = create_test_tenant()

    default_attrs = %{
      email: "guard#{System.unique_integer()}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "Guard",
      role: Keyword.get(attrs, :role, "guard"),
      tenant_id: tenant.id
    }

    Indrajaal.Accounts.create_user(Map.merge(default_attrs, Map.new(attrs)))
  end

  defp create_test_tenant do
    Indrajaal.Tenants.create_tenant(%{
      name: "Test Tenant #{System.unique_integer()}",
      code: "test_#{System.unique_integer()}"
    })
  end

  defp create_test_tour(tenant_id) do
    GuardTours.create_tour(%{
      name: "Test Tour #{System.unique_integer()}",
      description: "Test patrol route",
      tenant_id: tenant_id,
      status: "active",
      estimated_duration: 3600
    })
  end

  defp create_test_checkpoint(tour_id) do
    GuardTours.create_checkpoint(%{
      tour_id: tour_id,
      name: "Checkpoint #{System.unique_integer()}",
      sequence_number: 1,
      location: %{lat: 52.5200, lng: 13.4050}
    })
  end

  defp create_test_guard(tenant_id) do
    GuardTours.create_guard(%{
      tenant_id: tenant_id,
      name: "Guard #{System.unique_integer()}",
      badge_number: "G#{System.unique_integer()}",
      status: "on_duty"
    })
  end

  defp start_tour_execution(tour, user) do
    GuardTours.start_tour_execution(tour, user.id, %{})
  end

  defp record_checkpoint_scan(checkpoint, guard) do
    GuardTours.record_checkpoint_scan(checkpoint, guard.id, %{method: "nfc"})
  end

  defp report_tour_exception(tour, user, params) do
    GuardTours.report_tour_exception(tour, user.id, params)
  end

  defp update_guard_location(guard, params) do
    GuardTours.update_guard_location(guard, params)
  end
end

# Agent: Worker-9 (Patrol Domain Test Agent)
# SOPv5.11 Compliance: ✅ Full compliance with TDG methodology
# Domain: Web - Channel Testing / Guard Tours
# STAMP: SC-CNT-009 tenant isolation verified in tests
