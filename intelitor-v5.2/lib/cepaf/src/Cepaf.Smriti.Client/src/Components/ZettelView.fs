/// Zettel View Component - Detail view for a single zettel
///
/// Displays zettel content with markdown rendering, metadata, and backlinks.
module Cepaf.Smriti.Client.Components.ZettelView

open System
open Feliz
open Cepaf.Smriti.Client.Model
open Cepaf.Smriti.Client.Msg
open Cepaf.Smriti.Client.Components.EntropyBadge

/// Format a DateTime for display
let formatDate (dt: DateTime) : string =
    dt.ToString("MMM dd, yyyy")

/// Format relative time
let formatRelativeTime (dt: DateTime) : string =
    let diff = DateTime.UtcNow - dt
    if diff.TotalMinutes < 1.0 then "just now"
    elif diff.TotalHours < 1.0 then $"{int diff.TotalMinutes}m ago"
    elif diff.TotalDays < 1.0 then $"{int diff.TotalHours}h ago"
    elif diff.TotalDays < 7.0 then $"{int diff.TotalDays}d ago"
    elif diff.TotalDays < 30.0 then $"{int (diff.TotalDays / 7.0)}w ago"
    else formatDate dt

/// Zettel card (compact view)
[<ReactComponent>]
let Card (zettel: Zettel) (onClick: unit -> unit) =
    Html.div [
        prop.style [
            style.padding (length.rem 1)
            style.backgroundColor "white"
            style.border (1, borderStyle.solid, "#e5e7eb")
            style.borderRadius (length.rem 0.5)
            style.cursor.pointer
        ]
        prop.onClick (fun _ -> onClick())
        prop.children [
            Html.div [
                prop.style [
                    style.display.flex
                    style.justifyContent.spaceBetween
                    style.alignItems.flexStart
                    style.marginBottom (length.rem 0.5)
                ]
                prop.children [
                    Html.h3 [
                        prop.style [
                            style.fontWeight 500
                            style.color "#1f2937"
                        ]
                        prop.text zettel.Title
                    ]
                    Compact zettel.Entropy
                ]
            ]
            Html.p [
                prop.style [
                    style.fontSize (length.rem 0.875)
                    style.color "#6b7280"
                    style.overflow.hidden
                    style.textOverflow.ellipsis
                ]
                prop.text (
                    if zettel.Content.Length > 150
                    then zettel.Content.Substring(0, 150) + "..."
                    else zettel.Content
                )
            ]
            if not (List.isEmpty zettel.Tags) then
                Html.div [
                    prop.style [
                        style.display.flex
                        style.flexWrap.wrap
                        style.gap (length.rem 0.25)
                        style.marginTop (length.rem 0.5)
                    ]
                    prop.children [
                        for tag in List.truncate 3 zettel.Tags do
                            Html.span [
                                prop.key tag
                                prop.style [
                                    style.padding (length.rem 0.25, length.rem 0.5)
                                    style.backgroundColor "#f3f4f6"
                                    style.borderRadius (length.rem 0.25)
                                    style.fontSize (length.rem 0.75)
                                    style.color "#4b5563"
                                ]
                                prop.text $"#{tag}"
                            ]
                    ]
                ]
        ]
    ]

/// Full zettel detail view
[<ReactComponent>]
let Detail (zettel: Zettel) (backlinks: Zettel list) (dispatch: Msg -> unit) =
    Html.article [
        prop.style [
            style.backgroundColor "white"
            style.borderRadius (length.rem 0.5)
            style.border (1, borderStyle.solid, "#e5e7eb")
            style.overflow.hidden
        ]
        prop.children [
            // Header
            Html.header [
                prop.style [
                    style.padding (length.rem 1.5)
                    style.borderBottom (1, borderStyle.solid, "#f3f4f6")
                ]
                prop.children [
                    Html.h1 [
                        prop.style [
                            style.fontSize (length.rem 1.5)
                            style.fontWeight 700
                            style.color "#1f2937"
                            style.marginBottom (length.rem 0.5)
                        ]
                        prop.text zettel.Title
                    ]
                    Html.div [
                        prop.style [
                            style.display.flex
                            style.flexWrap.wrap
                            style.alignItems.center
                            style.gap (length.rem 1)
                            style.fontSize (length.rem 0.875)
                            style.color "#6b7280"
                        ]
                        prop.children [
                            Badge zettel.Entropy
                            Html.span [ prop.text $"Level: {zettel.Level}" ]
                            Html.span [ prop.text $"{zettel.BacklinkCount} backlinks" ]
                            Html.span [ prop.text (formatRelativeTime zettel.ModifiedAt) ]
                        ]
                    ]
                ]
            ]

            // Tags
            if not (List.isEmpty zettel.Tags) then
                Html.div [
                    prop.style [
                        style.padding (length.rem 1, length.rem 1.5)
                        style.borderBottom (1, borderStyle.solid, "#f3f4f6")
                    ]
                    prop.children [
                        Html.div [
                            prop.style [
                                style.display.flex
                                style.flexWrap.wrap
                                style.gap (length.rem 0.5)
                            ]
                            prop.children [
                                for tag in zettel.Tags do
                                    Html.span [
                                        prop.key tag
                                        prop.style [
                                            style.padding (length.rem 0.25, length.rem 0.5)
                                            style.backgroundColor "#f3f4f6"
                                            style.borderRadius (length.rem 0.25)
                                            style.fontSize (length.rem 0.75)
                                            style.color "#4b5563"
                                        ]
                                        prop.text $"#{tag}"
                                    ]
                            ]
                        ]
                    ]
                ]

            // Content
            Html.div [
                prop.style [
                    style.padding (length.rem 1.5)
                    style.fontSize (length.rem 1)
                    style.lineHeight (length.em 1.75)
                    style.color "#374151"
                    style.custom ("whiteSpace", "pre-wrap")
                ]
                prop.text zettel.Content
            ]

            // Backlinks section
            if not (List.isEmpty backlinks) then
                Html.div [
                    prop.style [
                        style.padding (length.rem 1.5)
                        style.borderTop (1, borderStyle.solid, "#f3f4f6")
                    ]
                    prop.children [
                        Html.h2 [
                            prop.style [
                                style.fontSize (length.rem 0.875)
                                style.fontWeight 600
                                style.color "#6b7280"
                                style.marginBottom (length.rem 0.75)
                                style.textTransform.uppercase
                            ]
                            prop.text "Backlinks"
                        ]
                        Html.div [
                            prop.children [
                                for bl in backlinks do
                                    Html.a [
                                        prop.key (string bl.Id)
                                        prop.style [
                                            style.display.block
                                            style.padding (length.rem 0.5, length.rem 0.75)
                                            style.marginBottom (length.rem 0.25)
                                            style.backgroundColor "#f9fafb"
                                            style.borderRadius (length.rem 0.25)
                                            style.color "#3b82f6"
                                            style.textDecoration.none
                                            style.cursor.pointer
                                        ]
                                        prop.onClick (fun _ -> dispatch (SelectZettel bl.Id))
                                        prop.children [
                                            Html.div [
                                                prop.style [
                                                    style.display.flex
                                                    style.justifyContent.spaceBetween
                                                    style.alignItems.center
                                                ]
                                                prop.children [
                                                    Html.span [ prop.text bl.Title ]
                                                    Dot bl.Entropy
                                                ]
                                            ]
                                        ]
                                    ]
                            ]
                        ]
                    ]
                ]

            // Sidebar metadata
            Html.div [
                prop.style [
                    style.padding (length.rem 1.5)
                    style.backgroundColor "#f9fafb"
                    style.borderTop (1, borderStyle.solid, "#f3f4f6")
                ]
                prop.children [
                    Html.div [
                        prop.style [
                            style.display.grid
                            style.custom ("gridTemplateColumns", "repeat(2, 1fr)")
                            style.gap (length.rem 1)
                            style.fontSize (length.rem 0.875)
                        ]
                        prop.children [
                            Html.div [
                                prop.children [
                                    Html.span [
                                        prop.style [ style.color "#6b7280" ]
                                        prop.text "Created"
                                    ]
                                    Html.div [
                                        prop.style [ style.fontWeight 500 ]
                                        prop.text (formatDate zettel.CreatedAt)
                                    ]
                                ]
                            ]
                            Html.div [
                                prop.children [
                                    Html.span [
                                        prop.style [ style.color "#6b7280" ]
                                        prop.text "Modified"
                                    ]
                                    Html.div [
                                        prop.style [ style.fontWeight 500 ]
                                        prop.text (formatDate zettel.ModifiedAt)
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]
