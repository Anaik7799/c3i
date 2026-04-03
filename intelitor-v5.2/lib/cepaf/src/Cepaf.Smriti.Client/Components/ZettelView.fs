namespace Cepaf.Smriti.Client.Components

/// <summary>
/// Zettel detail view component.
///
/// ## WHAT
/// Displays full zettel content with metadata, backlinks, and actions.
///
/// ## WHY
/// Central component for viewing and interacting with individual zettels.
///
/// ## CONSTRAINTS
/// - SC-KMS-001: Read-only access (no editing yet)
/// - SC-KMS-003: Display entropy with visual indicator
/// </summary>
module ZettelView

open System
open Feliz
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Client

/// <summary>
/// Render tag pill component.
/// </summary>
let private renderTag (tag: string) =
    Html.span [
        prop.className "tag"
        prop.style [
            style.display.inlineBlock
            style.padding (4, 12)
            style.margin (2, 4)
            style.borderRadius 12
            style.backgroundColor "#e0e7ff"
            style.color "#4338ca"
            style.fontSize 12
            style.fontWeight 500
        ]
        prop.text (sprintf "#%s" tag)
    ]

/// <summary>
/// Render backlink item.
/// </summary>
let private renderBacklink (zettel: Zettel) (dispatch: Msg.Msg -> unit) =
    Html.li [
        prop.className "backlink-item"
        prop.style [
            style.padding (8, 0)
            style.borderBottom (1, borderStyle.solid, "#e5e7eb")
            style.cursor.pointer
        ]
        prop.onClick (fun _ -> dispatch (Msg.SelectZettel zettel.Id))
        prop.children [
            Html.div [
                prop.style [ style.fontWeight 600; style.color "#1f2937" ]
                prop.text zettel.Title
            ]
            Html.div [
                prop.style [ style.fontSize 12; style.color "#6b7280"; style.marginTop 4 ]
                prop.text (sprintf "Modified: %s" (zettel.ModifiedAt.ToString("yyyy-MM-dd")))
            ]
        ]
    ]

/// <summary>
/// Render metadata section.
/// </summary>
let private renderMetadata (zettel: Zettel) =
    Html.div [
        prop.className "metadata"
        prop.style [
            style.padding (16, 0)
            style.borderTop (1, borderStyle.solid, "#e5e7eb")
            style.borderBottom (1, borderStyle.solid, "#e5e7eb")
            style.marginTop 24
            style.marginBottom 24
        ]
        prop.children [
            Html.div [
                prop.style [ style.marginBottom 8 ]
                prop.children [
                    Html.span [
                        prop.style [ style.fontWeight 600; style.color "#6b7280" ]
                        prop.text "Created: "
                    ]
                    Html.span [
                        prop.text (zettel.CreatedAt.ToString("yyyy-MM-dd HH:mm"))
                    ]
                ]
            ]
            Html.div [
                prop.style [ style.marginBottom 8 ]
                prop.children [
                    Html.span [
                        prop.style [ style.fontWeight 600; style.color "#6b7280" ]
                        prop.text "Modified: "
                    ]
                    Html.span [
                        prop.text (zettel.ModifiedAt.ToString("yyyy-MM-dd HH:mm"))
                    ]
                ]
            ]
            Html.div [
                prop.children [
                    Html.span [
                        prop.style [ style.fontWeight 600; style.color "#6b7280" ]
                        prop.text "Entropy: "
                    ]
                    EntropyBadge.render zettel.Entropy true
                ]
            ]
        ]
    ]

/// <summary>
/// Render main zettel view.
/// </summary>
let render (zettel: Zettel) (backlinks: Zettel list) (dispatch: Msg.Msg -> unit) =
    Html.div [
        prop.className "zettel-view"
        prop.style [
            style.maxWidth 900
            style.margin (0, length.auto)
            style.padding 24
        ]
        prop.children [
            // Header
            Html.div [
                prop.style [ style.marginBottom 24 ]
                prop.children [
                    Html.h1 [
                        prop.style [
                            style.fontSize 32
                            style.fontWeight 700
                            style.color "#111827"
                            style.marginBottom 8
                        ]
                        prop.text zettel.Title
                    ]
                    Html.div [
                        prop.style [ style.display.flex; style.flexWrap.wrap ]
                        prop.children (zettel.Tags |> List.map renderTag)
                    ]
                ]
            ]

            // Content (Markdown - to be rendered with a markdown library)
            Html.div [
                prop.className "zettel-content"
                prop.style [
                    style.fontSize 16
                    style.lineHeight 1.6
                    style.color "#374151"
                    style.marginBottom 24
                ]
                // TODO: Use markdown renderer (e.g., Fable.React.Markdown)
                prop.dangerouslySetInnerHTML zettel.Content
            ]

            // Metadata
            renderMetadata zettel

            // Backlinks
            if not (List.isEmpty backlinks) then
                Html.div [
                    prop.className "backlinks-section"
                    prop.children [
                        Html.h2 [
                            prop.style [
                                style.fontSize 20
                                style.fontWeight 600
                                style.color "#111827"
                                style.marginBottom 16
                            ]
                            prop.text (sprintf "Backlinks (%d)" backlinks.Length)
                        ]
                        Html.ul [
                            prop.style [ style.listStyleType.none; style.padding 0 ]
                            prop.children (backlinks |> List.map (fun bl -> renderBacklink bl dispatch))
                        ]
                    ]
                ]
        ]
    ]

/// <summary>
/// Render loading state.
/// </summary>
let renderLoading () =
    Html.div [
        prop.className "zettel-loading"
        prop.style [
            style.display.flex
            style.justifyContent.center
            style.alignItems.center
            style.height (length.vh 50)
        ]
        prop.children [
            Html.div [
                prop.text "Loading zettel..."
                prop.style [ style.fontSize 18; style.color "#6b7280" ]
            ]
        ]
    ]

/// <summary>
/// Render error state.
/// </summary>
let renderError (message: string) =
    Html.div [
        prop.className "zettel-error"
        prop.style [
            style.padding 24
            style.backgroundColor "#fef2f2"
            style.borderRadius 8
            style.border (1, borderStyle.solid, "#fca5a5")
        ]
        prop.children [
            Html.h3 [
                prop.style [ style.color "#991b1b"; style.marginBottom 8 ]
                prop.text "Error Loading Zettel"
            ]
            Html.p [
                prop.style [ style.color "#7f1d1d" ]
                prop.text message
            ]
        ]
    ]
