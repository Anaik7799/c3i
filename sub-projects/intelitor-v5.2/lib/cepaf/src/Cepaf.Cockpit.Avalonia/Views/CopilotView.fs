// =============================================================================
// Prajna C3I Cockpit - AI Copilot View
// =============================================================================
// STAMP: SC-PRAJNA-001 to SC-PRAJNA-007, SC-FOUNDER-001
// AOR: AOR-PRAJNA-002 (Founder Alignment)
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module CopilotView =

    let private messageRow (message: ChatMessage) =
        let isUser = message.Role = ChatRole.User

        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match message.Role with
                                | ChatRole.User -> "👤 You"
                                | ChatRole.Assistant -> "🤖 Copilot"
                                | ChatRole.System -> "⚙️ System"
                            )
                            .fontSize(12.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(message.Timestamp.ToString("HH:mm:ss"))
                                .fontSize(10.0)
                                .opacity(0.6)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(message.Content)
                        .fontSize(14.0)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)

                    if message.FounderAligned.IsSome then
                        View.StackPanel(
                            Orientation = Orientation.Horizontal,
                            Spacing = 8.0,
                            Children = [
                                View.TextBlock(
                                    if message.FounderAligned.Value then "✅ Founder Aligned"
                                    else "⚠️ Needs Review"
                                )
                                .fontSize(10.0)
                                .opacity(0.7)
                            ]
                        )
                ]
            )
        )
        .padding(12.0)
        .margin(
            if isUser then 48.0 else 0.0,
            4.0,
            if isUser then 0.0 else 48.0,
            4.0
        )
        .cornerRadius(8.0)

    let private suggestionCard (suggestion: CopilotSuggestion) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match suggestion.Category with
                                | SuggestionCategory.Optimization -> "⚡"
                                | SuggestionCategory.Safety -> "🛡️"
                                | SuggestionCategory.Compliance -> "📋"
                                | SuggestionCategory.Performance -> "📈"
                                | SuggestionCategory.Security -> "🔒"
                            )

                            View.TextBlock(suggestion.Title)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(suggestion.Description)
                        .fontSize(12.0)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)
                        .opacity(0.9)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock($"Confidence: {suggestion.Confidence * 100.0:F0}%%")
                                .fontSize(11.0)
                                .opacity(0.7)

                            View.TextBlock($"Impact: {suggestion.ImpactLevel}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = [
                            View.Button(View.TextBlock("Apply"))
                                .onClick(fun _ -> dispatch (Copilot (ApplySuggestion suggestion.Id)))

                            View.Button(View.TextBlock("Dismiss"))
                                .onClick(fun _ -> dispatch (Copilot (DismissSuggestion suggestion.Id)))
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)
        .margin(0.0, 4.0)

    let private inputPanel (inputText: string) (isProcessing: bool) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "*, Auto",
                Children = [
                    View.TextBox()
                        .text(inputText)
                        .watermark("Ask the AI Copilot...")
                        .isEnabled(not isProcessing)
                        .gridColumn(0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            if isProcessing then
                                View.ProgressBar()
                                    .isIndeterminate(true)
                                    .width(100.0)

                            View.Button(
                                View.TextBlock(if isProcessing then "..." else "Send")
                            )
                            .isEnabled(not isProcessing && not (String.IsNullOrWhiteSpace inputText))
                            .onClick(fun _ -> dispatch (Copilot SendMessage))
                        ]
                    ).gridColumn(1).margin(8.0, 0.0, 0.0, 0.0)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let copilot = model.Copilot

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, *, Auto",
            Children = [
                // Header
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("AI COPILOT")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.TextBlock(
                            match copilot.Status with
                            | CopilotStatus.Ready -> "🟢 Ready"
                            | CopilotStatus.Processing -> "🔄 Processing"
                            | CopilotStatus.Error -> "🔴 Error"
                        )
                        .fontSize(12.0)
                        .margin(16.0, 0.0, 0.0, 0.0)
                        .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Clear Chat"))
                            .onClick(fun _ -> dispatch (Copilot ClearChat))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Chat messages
                View.ScrollViewer(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            for message in copilot.Messages do
                                messageRow message
                        ]
                    )
                )
                .gridRow(1)
                .gridColumn(0)

                // Suggestions panel
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 12.0,
                        Children = [
                            View.TextBlock("SUGGESTIONS")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            if copilot.Suggestions.IsEmpty then
                                View.TextBlock("No suggestions available")
                                    .fontSize(12.0)
                                    .opacity(0.7)
                                    .horizontalAlignment(HorizontalAlignment.Center)
                            else
                                View.ScrollViewer(
                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            for suggestion in copilot.Suggestions do
                                                suggestionCard suggestion dispatch
                                        ]
                                    )
                                )

                            // Quick actions
                            View.TextBlock("QUICK ACTIONS")
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(0.0, 16.0, 0.0, 8.0)

                            View.WrapPanel(
                                Orientation = Orientation.Horizontal,
                                Children = [
                                    View.Button(View.TextBlock("📊 Status"))
                                        .onClick(fun _ -> dispatch (Copilot (QuickAction "status")))

                                    View.Button(View.TextBlock("🔍 Analyze"))
                                        .onClick(fun _ -> dispatch (Copilot (QuickAction "analyze")))

                                    View.Button(View.TextBlock("⚡ Optimize"))
                                        .onClick(fun _ -> dispatch (Copilot (QuickAction "optimize")))

                                    View.Button(View.TextBlock("🛡️ Security"))
                                        .onClick(fun _ -> dispatch (Copilot (QuickAction "security")))
                                ]
                            )
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(1)
                .gridColumn(1)
                .margin(16.0, 0.0, 0.0, 0.0)

                // Input panel
                (inputPanel copilot.InputText (copilot.Status = CopilotStatus.Processing) dispatch)
                    .gridRow(2)
                    .gridColumn(0)
                    .gridColumnSpan(2)
                    .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
