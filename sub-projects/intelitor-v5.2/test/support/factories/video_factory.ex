import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.VideoFactory do
  @moduledoc """
  Factory definitions for Video domain.
  Created as part of HYPERSPEED Wave 1 factory infrastructure.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      @spec camera_factory(any()) :: any()
      def camera_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle site dependency - create or use provided site
        site =
          case Map.pop(attrs_map, :site) do
            {nil, _} ->
              case Map.get(attrs_map, :site_id) do
                nil -> insert(:site, tenant_id: tenant.id)
                _site_id -> nil
              end

            {site, _} ->
              site
          end

        # Handle optional zone dependency
        zone_id =
          case Map.pop(attrs_map, :zone) do
            {nil, _} -> Map.get(attrs_map, :zone_id)
            {%{id: id}, _} -> id
          end

        camera_attrs =
          %{
            name: sequence(:camera_name, fn n -> "Camera #{n}" end),
            model: "Generic IP Camera",
            manufacturer: "Security Systems Inc",
            serial_number: sequence(:camera_serial, fn n -> "CAM-SN-#{n}" end),
            protocol: :rtsp,
            connection_url:
              sequence(:camera_url, fn n -> "rtsp://192.168.1.#{rem(n, 255)}/stream" end),
            port: 554,
            resolution: "1920x1080",
            framerate: 30,
            has_ptz?: false,
            has_audio?: true,
            has_infrared?: true,
            has_analytics?: false,
            recording_enabled?: true,
            recording_mode: :continuous,
            retention_days: 30,
            status: :offline,
            health_status: :good,
            analytics_enabled?: false,
            active?: true,
            tenant_id: tenant.id,
            site_id: if(site, do: site.id, else: attrs_map[:site_id]),
            zone_id: zone_id,
            metadata: %{}
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)
          |> Map.delete(:zone)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, camera} =
          Ash.create(
            Indrajaal.Video.Camera,
            camera_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        camera
      end

      unquote(video_factory_part_2())
    end
  end

  defp video_factory_part_2 do
    quote do
      @spec recording_factory(any()) :: any()
      def recording_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle camera dependency
        camera =
          case Map.pop(attrs_map, :camera) do
            {nil, _} ->
              case Map.get(attrs_map, :camera_id) do
                nil -> insert(:camera, tenant_id: tenant.id)
                _camera_id -> nil
              end

            {camera, _} ->
              camera
          end

        recording_attrs =
          %{
            name: sequence(:recording_name, fn n -> "Recording #{n}" end),
            start_time: DateTime.utc_now() |> DateTime.add(-3600, :second),
            end_time: DateTime.utc_now(),
            duration_seconds: 3600,
            file_path: sequence(:recording_path, fn n -> "/recordings/rec_#{n}.mp4" end),
            file_size_bytes: :rand.uniform(1_000_000_000),
            format: "mp4",
            resolution: "1920x1080",
            framerate: 30,
            status: :completed,
            tenant_id: tenant.id,
            camera_id: if(camera, do: camera.id, else: attrs_map[:camera_id]),
            metadata: %{}
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:camera)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, recording} =
          Ash.create(
            Indrajaal.Video.Recording,
            recording_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        recording
      end

      @spec stream_factory(any()) :: any()
      def stream_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle camera dependency
        camera =
          case Map.pop(attrs_map, :camera) do
            {nil, _} ->
              case Map.get(attrs_map, :camera_id) do
                nil -> insert(:camera, tenant_id: tenant.id)
                _camera_id -> nil
              end

            {camera, _} ->
              camera
          end

        stream_attrs =
          %{
            name: sequence(:stream_name, fn n -> "Stream #{n}" end),
            stream_type: :live,
            protocol: :rtsp,
            url: sequence(:stream_url, fn n -> "rtsp://192.168.1.#{rem(n, 255)}/live" end),
            resolution: "1920x1080",
            framerate: 30,
            bitrate_kbps: 4000,
            codec: "H.264",
            status: :active,
            tenant_id: tenant.id,
            camera_id: if(camera, do: camera.id, else: attrs_map[:camera_id]),
            metadata: %{}
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:camera)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, stream} =
          Ash.create(
            Indrajaal.Video.Stream,
            stream_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        stream
      end

      @spec clip_factory(any()) :: any()
      def clip_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle camera dependency
        camera =
          case Map.pop(attrs_map, :camera) do
            {nil, _} ->
              case Map.get(attrs_map, :camera_id) do
                nil -> insert(:camera, tenant_id: tenant.id)
                _camera_id -> nil
              end

            {camera, _} ->
              camera
          end

        clip_attrs =
          %{
            name: sequence(:clip_name, fn n -> "Clip #{n}" end),
            start_time: DateTime.utc_now() |> DateTime.add(-300, :second),
            end_time: DateTime.utc_now(),
            duration_seconds: 300,
            file_path: sequence(:clip_path, fn n -> "/clips/clip_#{n}.mp4" end),
            file_size_bytes: :rand.uniform(100_000_000),
            format: "mp4",
            resolution: "1920x1080",
            status: :ready,
            tenant_id: tenant.id,
            camera_id: if(camera, do: camera.id, else: attrs_map[:camera_id]),
            metadata: %{}
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:camera)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, clip} =
          Ash.create(
            Indrajaal.Video.Clip,
            clip_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        clip
      end
    end
  end
end

# Agent: Worker-3 (Video Domain Agent)
# SOPv5.11 Compliance: Video domain factory definitions
# Domain: Video/Testing
# Responsibilities: Camera, recording, stream, clip factory generation
# Multi-Agent Architecture: Integrated with factory infrastructure
# Cybernetic Feedback: Active feedback loops for test data quality
