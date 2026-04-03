// =============================================================================
// Prajna C3I Cockpit - Video View
// =============================================================================
// STAMP: SC-HMI-001, SC-VIDEO-001 to SC-VIDEO-005
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module VideoView =

    let private streamCard (stream: VideoStream) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    // Stream header
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match stream.Status with
                                | VideoStatus.Live -> "🟢"
                                | VideoStatus.Recording -> "🔴"
                                | VideoStatus.Paused -> "⏸️"
                                | VideoStatus.Offline -> "⚫"
                            )

                            View.TextBlock(stream.Name)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    // Stream placeholder (would be actual video in real implementation)
                    View.Border(
                        View.TextBlock("📹 Video Stream")
                            .horizontalAlignment(HorizontalAlignment.Center)
                            .verticalAlignment(VerticalAlignment.Center)
                    )
                    .height(180.0)
                    .cornerRadius(4.0)

                    // Stream info
                    View.Grid(
                        ColumnDefinitions = "*, *",
                        Children = [
                            View.TextBlock($"Zone: {stream.Zone}")
                                .fontSize(11.0)
                                .opacity(0.7)
                                .gridColumn(0)

                            View.TextBlock($"Device: {stream.DeviceId}")
                                .fontSize(11.0)
                                .opacity(0.7)
                                .gridColumn(1)
                        ]
                    )

                    // Quality metrics
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"FPS: {stream.Fps}")
                                .fontSize(11.0)

                            View.TextBlock($"Bitrate: {stream.BitrateKbps}kbps")
                                .fontSize(11.0)

                            View.TextBlock($"Latency: {stream.LatencyMs}ms")
                                .fontSize(11.0)
                        ]
                    )

                    // Stream actions
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = [
                            match stream.Status with
                            | VideoStatus.Live ->
                                View.Button(View.TextBlock("Pause"))
                                    .onClick(fun _ -> dispatch (Video (PauseStream stream.Id)))

                                View.Button(View.TextBlock("Record"))
                                    .onClick(fun _ -> dispatch (Video (StartRecording stream.Id)))
                            | VideoStatus.Recording ->
                                View.Button(View.TextBlock("Stop"))
                                    .onClick(fun _ -> dispatch (Video (StopRecording stream.Id)))
                            | VideoStatus.Paused ->
                                View.Button(View.TextBlock("Resume"))
                                    .onClick(fun _ -> dispatch (Video (ResumeStream stream.Id)))
                            | VideoStatus.Offline ->
                                View.Button(View.TextBlock("Connect"))
                                    .onClick(fun _ -> dispatch (Video (ConnectStream stream.Id)))

                            View.Button(View.TextBlock("Snapshot"))
                                .onClick(fun _ -> dispatch (Video (TakeSnapshot stream.Id)))
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let private detectionPanel (detections: Detection list) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.TextBlock("RECENT DETECTIONS")
                        .fontSize(14.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.ScrollViewer(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 4.0,
                            Children = [
                                for detection in detections |> List.truncate 10 do
                                    View.Border(
                                        View.Grid(
                                            ColumnDefinitions = "Auto,*,Auto,Auto",
                                            Children = [
                                                View.TextBlock(
                                                    match detection.Type with
                                                    | DetectionType.Motion -> "🏃"
                                                    | DetectionType.Person -> "👤"
                                                    | DetectionType.Vehicle -> "🚗"
                                                    | DetectionType.Face -> "😊"
                                                    | DetectionType.License -> "🚘"
                                                    | DetectionType.Object -> "📦"
                                                )
                                                .gridColumn(0)
                                                .margin(0.0, 0.0, 8.0, 0.0)

                                                View.TextBlock(detection.Label)
                                                    .fontSize(12.0)
                                                    .gridColumn(1)

                                                View.TextBlock($"{detection.Confidence * 100.0:F0}%%")
                                                    .fontSize(11.0)
                                                    .opacity(0.7)
                                                    .gridColumn(2)
                                                    .margin(0.0, 0.0, 8.0, 0.0)

                                                View.TextBlock(detection.Timestamp.ToString("HH:mm:ss"))
                                                    .fontSize(11.0)
                                                    .opacity(0.7)
                                                    .gridColumn(3)
                                            ]
                                        )
                                    )
                                    .padding(8.0, 4.0)
                            ]
                        )
                    ).height(200.0)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let video = model.Video

        View.ScrollViewer(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    // Header
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("VIDEO SURVEILLANCE")
                                .fontSize(24.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"Live: {video.LiveStreams.Length} | Recording: {video.RecordingCount}")
                                .fontSize(14.0)
                                .opacity(0.7)
                                .margin(16.0, 0.0, 0.0, 0.0)
                                .verticalAlignment(VerticalAlignment.Center)

                            View.Button(View.TextBlock("Refresh"))
                                .onClick(fun _ -> dispatch (Video LoadStreams))
                                .horizontalAlignment(HorizontalAlignment.Right)
                        ]
                    )

                    // View mode selector
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.Button(View.TextBlock("Grid 2x2"))
                                .onClick(fun _ -> dispatch (Video (SetLayout Grid2x2)))

                            View.Button(View.TextBlock("Grid 3x3"))
                                .onClick(fun _ -> dispatch (Video (SetLayout Grid3x3)))

                            View.Button(View.TextBlock("Single"))
                                .onClick(fun _ -> dispatch (Video (SetLayout Single)))

                            View.Button(View.TextBlock("Picture-in-Picture"))
                                .onClick(fun _ -> dispatch (Video (SetLayout PiP)))
                        ]
                    )

                    // Video grid
                    View.WrapPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            for stream in video.LiveStreams do
                                streamCard stream dispatch
                        ]
                    )

                    // Detection panel
                    detectionPanel video.Detections
                ]
            )
        )
        .padding(16.0)
