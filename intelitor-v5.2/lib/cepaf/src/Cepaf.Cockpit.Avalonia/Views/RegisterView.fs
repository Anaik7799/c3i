// =============================================================================
// Prajna C3I Cockpit - Immutable Register View
// =============================================================================
// STAMP: SC-REG-001 to SC-REG-015, SC-HOLON-001
// AOR: AOR-REG-001 to AOR-REG-012
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module RegisterView =

    let private blockRow (block: RegisterBlock) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto, Auto, *, Auto, Auto, Auto",
                RowDefinitions = "Auto, Auto",
                Children = [
                    // Block number
                    View.TextBlock($"#{block.Number}")
                        .fontSize(14.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                        .gridColumn(0)
                        .gridRow(0)
                        .margin(0.0, 0.0, 12.0, 0.0)

                    // Verification status
                    View.TextBlock(
                        if block.Verified then "✅" else "⚠️"
                    )
                    .gridColumn(1)
                    .gridRow(0)
                    .margin(0.0, 0.0, 12.0, 0.0)

                    // Block type and content
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            View.TextBlock(
                                match block.Type with
                                | BlockType.StateChange -> "📝 State Change"
                                | BlockType.Configuration -> "⚙️ Configuration"
                                | BlockType.Evolution -> "🧬 Evolution"
                                | BlockType.Checkpoint -> "📌 Checkpoint"
                                | BlockType.Extension -> "🔌 Extension"
                            )
                            .fontSize(12.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(block.Summary)
                                .fontSize(11.0)
                                .opacity(0.8)
                        ]
                    )
                    .gridColumn(2)
                    .gridRow(0)

                    // Signature status
                    View.TextBlock(if block.Signed then "🔏" else "❌")
                        .gridColumn(3)
                        .gridRow(0)
                        .margin(0.0, 0.0, 12.0, 0.0)

                    // Timestamp
                    View.TextBlock(block.Timestamp.ToString("MM-dd HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(4)
                        .gridRow(0)
                        .margin(0.0, 0.0, 12.0, 0.0)

                    // Actions
                    View.Button(View.TextBlock("View"))
                        .onClick(fun _ -> dispatch (Register (ViewBlock block.Number)))
                        .gridColumn(5)
                        .gridRow(0)

                    // Hash chain (second row)
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Hash:")
                                .fontSize(10.0)
                                .opacity(0.6)

                            View.TextBlock(block.Hash.[..15] + "...")
                                .fontSize(10.0)
                                .fontFamily("Consolas")
                                .opacity(0.6)

                            View.TextBlock("←")
                                .fontSize(10.0)
                                .opacity(0.6)

                            View.TextBlock(block.PrevHash.[..15] + "...")
                                .fontSize(10.0)
                                .fontFamily("Consolas")
                                .opacity(0.6)
                        ]
                    )
                    .gridColumn(0)
                    .gridColumnSpan(6)
                    .gridRow(1)
                    .margin(0.0, 4.0, 0.0, 0.0)
                ]
            )
        )
        .padding(12.0, 8.0)
        .cornerRadius(4.0)
        .margin(0.0, 2.0)

    let private chainIntegrityPanel (integrity: ChainIntegrity) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("CHAIN INTEGRITY")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(if integrity.Valid then "✅ Valid" else "❌ Broken")
                                .fontSize(14.0)
                                .margin(16.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.Grid(
                        ColumnDefinitions = "*, *, *",
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Total Blocks").fontSize(11.0).opacity(0.7)
                                    View.TextBlock(string integrity.TotalBlocks)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(0)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Verified").fontSize(11.0).opacity(0.7)
                                    View.TextBlock(string integrity.VerifiedBlocks)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(1)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Signed").fontSize(11.0).opacity(0.7)
                                    View.TextBlock(string integrity.SignedBlocks)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(2)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"Merkle Root: {integrity.MerkleRoot.[..20]}...")
                                .fontSize(10.0)
                                .fontFamily("Consolas")
                                .opacity(0.7)

                            View.TextBlock($"Last Verified: {integrity.LastVerification.ToString(\"HH:mm:ss\")}")
                                .fontSize(10.0)
                                .opacity(0.7)
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    let private holonStatePanel (holon: HolonState) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.TextBlock("HOLON STATE")
                        .fontSize(14.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.Grid(
                        ColumnDefinitions = "*, *",
                        RowDefinitions = "Auto, Auto, Auto",
                        Children = [
                            View.TextBlock("SQLite Size:").fontSize(11.0).opacity(0.7).gridRow(0).gridColumn(0)
                            View.TextBlock($"{holon.SqliteSizeBytes / 1024L} KB")
                                .fontSize(12.0).gridRow(0).gridColumn(1)

                            View.TextBlock("DuckDB Size:").fontSize(11.0).opacity(0.7).gridRow(1).gridColumn(0)
                            View.TextBlock($"{holon.DuckDbSizeBytes / 1024L / 1024L} MB")
                                .fontSize(12.0).gridRow(1).gridColumn(1)

                            View.TextBlock("Evolution Count:").fontSize(11.0).opacity(0.7).gridRow(2).gridColumn(0)
                            View.TextBlock(string holon.EvolutionCount)
                                .fontSize(12.0).gridRow(2).gridColumn(1)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Checksum:")
                                .fontSize(10.0)
                                .opacity(0.7)

                            View.TextBlock(holon.Checksum.[..24] + "...")
                                .fontSize(10.0)
                                .fontFamily("Consolas")
                                .opacity(0.6)
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let register = model.Register

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, Auto, *, Auto",
            Children = [
                // Header
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("IMMUTABLE REGISTER")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.TextBlock($"Protocol v{register.ProtocolVersion}")
                            .fontSize(12.0)
                            .opacity(0.7)
                            .margin(16.0, 0.0, 0.0, 0.0)
                            .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Verify Chain"))
                            .onClick(fun _ -> dispatch (Register VerifyChain))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Chain integrity panel
                (chainIntegrityPanel register.Integrity)
                    .gridRow(1)
                    .gridColumn(0)
                    .gridColumnSpan(2)
                    .margin(0.0, 0.0, 0.0, 16.0)

                // Blocks list
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 8.0,
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Children = [
                                    View.TextBlock("BLOCK CHAIN")
                                        .fontSize(16.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.TextBlock($"(Latest 100 of {register.Integrity.TotalBlocks})")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                        .margin(8.0, 0.0, 0.0, 0.0)

                                    View.Button(View.TextBlock("Export"))
                                        .onClick(fun _ -> dispatch (Register ExportChain))
                                        .horizontalAlignment(HorizontalAlignment.Right)
                                ]
                            )

                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Children = [
                                        for block in register.Blocks |> List.truncate 100 do
                                            blockRow block dispatch
                                    ]
                                )
                            )
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(2)
                .gridColumn(0)

                // Right panel
                View.StackPanel(
                    Orientation = Orientation.Vertical,
                    Spacing = 16.0,
                    Children = [
                        // Holon state
                        holonStatePanel register.HolonState

                        // Reed-Solomon status
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock("REED-SOLOMON")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.TextBlock($"RS({register.ReedSolomon.N},{register.ReedSolomon.K})")
                                        .fontSize(12.0)

                                    View.TextBlock($"Repairs: {register.ReedSolomon.RepairCount}")
                                        .fontSize(11.0)
                                        .opacity(0.7)

                                    View.TextBlock($"Last Repair: {register.ReedSolomon.LastRepair.ToString(\"MM-dd HH:mm\")}")
                                        .fontSize(11.0)
                                        .opacity(0.7)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)

                        // Capability tokens
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock("CAPABILITY TOKENS")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.TextBlock($"Active: {register.ActiveTokens}")
                                        .fontSize(12.0)

                                    View.TextBlock($"Expired: {register.ExpiredTokens}")
                                        .fontSize(11.0)
                                        .opacity(0.7)

                                    View.Button(View.TextBlock("Manage Tokens"))
                                        .onClick(fun _ -> dispatch (Register ManageTokens))
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)

                        // Protocol info
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 4.0,
                                Children = [
                                    View.TextBlock("PROTOCOL").fontSize(14.0).fontWeight(Avalonia.Media.FontWeight.Bold)
                                    View.TextBlock($"Version: {register.ProtocolVersion}").fontSize(11.0)
                                    View.TextBlock($"Hash: SHA3-256").fontSize(11.0).opacity(0.7)
                                    View.TextBlock($"Signature: Ed25519").fontSize(11.0).opacity(0.7)
                                    View.TextBlock($"ECC: RS(255,223)").fontSize(11.0).opacity(0.7)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)
                    ]
                )
                .gridRow(2)
                .gridColumn(1)
                .margin(16.0, 0.0, 0.0, 0.0)

                // Footer actions
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Spacing = 8.0,
                    HorizontalAlignment = HorizontalAlignment.Right,
                    Children = [
                        View.Button(View.TextBlock("Create Checkpoint"))
                            .onClick(fun _ -> dispatch (Register CreateCheckpoint))

                        View.Button(View.TextBlock("Backup"))
                            .onClick(fun _ -> dispatch (Register BackupRegister))

                        View.Button(View.TextBlock("Verify All"))
                            .onClick(fun _ -> dispatch (Register VerifyAll))
                    ]
                )
                .gridRow(3)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
