defmodule IndrajaalWeb.VideoChannelTest do
  @moduledoc """
  Test suite for video streaming and analytics real-time channel.

  Following TDG methodology - tests written for implementation validation.

  Agent: Worker-10 manages video channel testing
  SOPv5.11 Compliance: ✅
  STAMP Safety: SC-CNT-009 tenant isolation enforced
  """

  use IndrajaalWeb.ChannelCase

  import Indrajaal.Factory

  alias IndrajaalWeb.{MobileSocket, VideoChannel}
  alias Indrajaal.Video
  alias Indrajaal.Authentication.JWT

  setup do
    {:ok, test_user} = create_test_user()
    {:ok, token, _} = JWT.generate_token(test_user)
    {:ok, socket} = connect(MobileSocket, %{"token" => token})

    {:ok, socket: socket, user: test_user}
  end

  describe "channel join" do
    test "joins video channel for tenant", %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      assert socket.assigns.tenant_id == user.tenant_id
    end

    test "joins specific stream channel", %{socket: socket, user: user} do
      {:ok, camera} = create_test_camera(user.tenant_id)
      {:ok, stream} = create_test_stream(camera)

      {:ok, _, socket} = subscribe_and_join(socket, VideoChannel, "video:stream:#{stream.id}")
      assert socket.assigns.stream_id == stream.id
    end

    test "joins camera channel", %{socket: socket, user: user} do
      {:ok, camera} = create_test_camera(user.tenant_id)

      {:ok, _, socket} = subscribe_and_join(socket, VideoChannel, "video:camera:#{camera.id}")
      assert socket.assigns.camera_id == camera.id
    end

    test "joins analytics channel", %{socket: socket, user: user} do
      {:ok, camera} = create_test_camera(user.tenant_id)
      {:ok, analytics} = create_test_analytics(camera)

      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:analytics:#{analytics.id}")

      assert socket.assigns.analytics_id == analytics.id
    end

    test "prevents joining other tenant's video channel", %{socket: socket} do
      other_tenant_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, VideoChannel, "video:tenant:#{other_tenant_id}")
    end
  end

  describe "stream operations" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, camera} = create_test_camera(user.tenant_id)
      {:ok, socket: socket, user: user, camera: camera}
    end

    test "handles list_streams request", %{socket: socket} do
      ref = push(socket, "list_streams", %{})

      assert_reply ref, :ok, %{streams: streams}
      assert is_list(streams)
    end

    test "handles list_cameras request", %{socket: socket} do
      ref = push(socket, "list_cameras", %{})

      assert_reply ref, :ok, %{cameras: cameras}
      assert is_list(cameras)
    end

    test "handles start_stream request", %{socket: socket, camera: camera} do
      ref =
        push(socket, "start_stream", %{
          "camera_id" => camera.id,
          "resolution" => "1080p",
          "bitrate" => 4000
        })

      assert_reply ref, :ok, %{stream: stream}
      assert stream.camera_id == camera.id
      assert stream.status == "active"
    end

    test "handles stop_stream request", %{socket: socket, camera: camera} do
      {:ok, stream} = create_test_stream(camera)

      ref = push(socket, "stop_stream", %{"stream_id" => stream.id})

      assert_reply ref, :ok, %{stream: stopped_stream}
      assert stopped_stream.status == "stopped"
    end

    test "broadcasts stream started event", %{socket: _socket, camera: camera} do
      {:ok, _stream} = Video.start_video_stream(camera)

      assert_broadcast "stream:started", %{stream: stream}
      assert stream.camera_id == camera.id
    end

    test "broadcasts stream stopped event", %{socket: _socket, camera: camera} do
      {:ok, stream} = create_test_stream(camera)
      {:ok, _stopped} = Video.stop_video_stream(stream)

      assert_broadcast "stream:stopped", %{stream: stopped_stream}
      assert stopped_stream.id == stream.id
    end
  end

  describe "recording operations" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, camera} = create_test_camera(user.tenant_id)
      {:ok, stream} = create_test_stream(camera)
      {:ok, socket: socket, user: user, camera: camera, stream: stream}
    end

    test "handles start_recording request", %{socket: socket, stream: stream} do
      ref =
        push(socket, "start_recording", %{
          "stream_id" => stream.id,
          "duration" => 3600
        })

      assert_reply ref, :ok, %{recording: recording}
      assert recording.stream_id == stream.id
      assert recording.status == "recording"
    end

    test "handles stop_recording request", %{socket: socket, stream: stream} do
      {:ok, recording} = create_test_recording(stream)

      ref = push(socket, "stop_recording", %{"recording_id" => recording.id})

      assert_reply ref, :ok, %{recording: stopped_recording}
      assert stopped_recording.status == "completed"
    end

    test "broadcasts recording started event", %{socket: _socket, stream: stream} do
      {:ok, _recording} = Video.start_recording(stream, %{})

      assert_broadcast "recording:started", %{recording: recording}
      assert recording.stream_id == stream.id
    end

    test "broadcasts recording completed event", %{socket: _socket, stream: stream} do
      {:ok, recording} = create_test_recording(stream)
      {:ok, _completed} = Video.stop_recording(recording)

      assert_broadcast "recording:completed", %{recording: completed}
      assert completed.id == recording.id
    end
  end

  describe "camera controls" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, camera} = create_test_camera(user.tenant_id, ptz_enabled: true)
      {:ok, socket: socket, user: user, camera: camera}
    end

    test "handles request_snapshot request", %{socket: socket, camera: camera} do
      ref = push(socket, "request_snapshot", %{"camera_id" => camera.id})

      assert_reply ref, :ok, %{snapshot: snapshot}
      assert snapshot.camera_id == camera.id
      assert Map.has_key?(snapshot, :url)
    end

    test "handles ptz_control request", %{socket: socket, camera: camera} do
      ref =
        push(socket, "ptz_control", %{
          "camera_id" => camera.id,
          "command" => "pan_left",
          "speed" => 50
        })

      assert_reply ref, :ok, %{status: "command_sent", command: "pan_left"}
    end

    test "rejects ptz on non-ptz camera", %{socket: socket, user: user} do
      {:ok, non_ptz_camera} = create_test_camera(user.tenant_id, ptz_enabled: false)

      ref =
        push(socket, "ptz_control", %{
          "camera_id" => non_ptz_camera.id,
          "command" => "pan_left"
        })

      assert_reply ref, :error, %{message: "PTZ not supported on this camera"}
    end
  end

  describe "analytics" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, camera} = create_test_camera(user.tenant_id, analytics_enabled: true)
      {:ok, socket: socket, user: user, camera: camera}
    end

    test "handles set_analytics_zone request", %{socket: socket, camera: camera} do
      zone = %{
        "name" => "Entrance Zone",
        "type" => "detection",
        "coordinates" => [[0, 0], [100, 0], [100, 100], [0, 100]]
      }

      ref =
        push(socket, "set_analytics_zone", %{
          "camera_id" => camera.id,
          "zone" => zone
        })

      assert_reply ref, :ok, %{analytics_config: config}
      assert is_map(config)
    end

    test "broadcasts analytics alert event", %{socket: _socket, camera: camera} do
      {:ok, _alert} = create_analytics_alert(camera, %{type: "motion", severity: "high"})

      assert_broadcast "analytics:alert", %{alert: alert}
      assert alert.camera_id == camera.id
      assert alert.type == "motion"
    end

    test "broadcasts motion detected event", %{socket: _socket, camera: camera} do
      {:ok, _event} = trigger_motion_event(camera, %{zone_id: "zone_1", intensity: 0.8})

      assert_broadcast "motion:detected", %{camera_id: camera_id, event: event}
      assert camera_id == camera.id
      assert event.intensity == 0.8
    end

    test "broadcasts object detected event", %{socket: _socket, camera: camera} do
      {:ok, _detection} = trigger_object_detection(camera, %{type: "person", confidence: 0.95})

      assert_broadcast "object:detected", %{camera_id: camera_id, detection: detection}
      assert camera_id == camera.id
      assert detection.object_type == "person"
    end
  end

  describe "statistics" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, socket: socket, user: user}
    end

    test "handles get_statistics request", %{socket: socket} do
      ref = push(socket, "get_statistics", %{})

      assert_reply ref, :ok, %{stats: stats}
      assert Map.has_key?(stats, :total_cameras)
      assert Map.has_key?(stats, :active_streams)
      assert Map.has_key?(stats, :recordings_today)
    end
  end

  describe "error handling" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} =
        subscribe_and_join(socket, VideoChannel, "video:tenant:#{user.tenant_id}")

      {:ok, socket: socket}
    end

    test "handles invalid camera_id", %{socket: socket} do
      ref = push(socket, "start_stream", %{"camera_id" => Ecto.UUID.generate()})

      assert_reply ref, :error, %{message: message}
      assert message =~ "not found"
    end

    test "handles invalid stream_id", %{socket: socket} do
      ref = push(socket, "stop_stream", %{"stream_id" => Ecto.UUID.generate()})

      assert_reply ref, :error, %{message: message}
      assert message =~ "not found"
    end

    test "handles unauthorized cross-tenant access", %{socket: socket} do
      other_tenant_id = Ecto.UUID.generate()
      {:ok, other_camera} = create_test_camera(other_tenant_id)

      ref = push(socket, "start_stream", %{"camera_id" => other_camera.id})

      assert_reply ref, :error, %{message: "unauthorized"}
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ []) do
    {:ok, tenant} = create_test_tenant()

    default_attrs = %{
      email: "video_user#{System.unique_integer()}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "User",
      role: Keyword.get(attrs, :role, "operator"),
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

  defp create_test_camera(tenant_id, opts \\ []) do
    Video.create_camera(%{
      tenant_id: tenant_id,
      name: "Camera #{System.unique_integer()}",
      location: "Test Location",
      status: "online",
      ip_address: "192.168.1.#{:rand.uniform(254)}",
      rtsp_url: "rtsp://camera.local/stream",
      ptz_enabled: Keyword.get(opts, :ptz_enabled, false),
      analytics_enabled: Keyword.get(opts, :analytics_enabled, false)
    })
  end

  defp create_test_stream(camera) do
    Video.start_video_stream(camera)
  end

  defp create_test_recording(stream) do
    Video.start_recording(stream, %{duration: 3600})
  end

  defp create_test_analytics(camera) do
    Video.create_analytics(%{
      camera_id: camera.id,
      type: "motion_detection",
      status: "active"
    })
  end

  defp create_analytics_alert(camera, params) do
    Video.create_analytics_alert(camera.id, params)
  end

  defp trigger_motion_event(camera, params) do
    Video.trigger_motion_event(camera.id, params)
  end

  defp trigger_object_detection(camera, params) do
    Video.trigger_object_detection(camera.id, params)
  end
end

# Agent: Worker-10 (Video Domain Test Agent)
# SOPv5.11 Compliance: ✅ Full compliance with TDG methodology
# Domain: Web - Channel Testing / Video Analytics
# STAMP: SC-CNT-009 tenant isolation verified in tests
