/// Search Bar Component - Live search input with results
///
/// Provides instant search across the Zettelkasten with autocomplete.
module Cepaf.Smriti.Client.Components.SearchBar

open System
open Fable.Core
open Fable.Core.JsInterop
open Feliz
open Browser.Types
open Cepaf.Smriti.Client.Model
open Cepaf.Smriti.Client.Msg
open Cepaf.Smriti.Client.Components.EntropyBadge

/// Search bar component
[<ReactComponent>]
let SearchBar (query: string) (results: LoadingState<SearchResult list>) (dispatch: Msg -> unit) =
    let (isFocused, setFocused) = React.useState false
    let (selectedIndex, setSelectedIndex) = React.useState -1

    // Show dropdown when focused and has query
    let showDropdown =
        isFocused &&
        not (String.IsNullOrWhiteSpace query) &&
        match results with
        | Loaded results -> not (List.isEmpty results)
        | Loading -> true
        | _ -> false

    Html.div [
        prop.style [
            style.position.relative
            style.width (length.percent 100)
            style.maxWidth (length.rem 32)
        ]
        prop.children [
            // Input wrapper
            Html.div [
                prop.style [
                    style.display.flex
                    style.alignItems.center
                    style.backgroundColor "white"
                    style.border (1, borderStyle.solid, if isFocused then "#3b82f6" else "#d1d5db")
                    style.borderRadius (length.rem 0.5)
                    style.padding (length.rem 0.5, length.rem 0.75)
                ]
                prop.children [
                    // Search icon
                    Html.span [
                        prop.style [
                            style.width (length.rem 1.25)
                            style.height (length.rem 1.25)
                            style.color "#9ca3af"
                            style.marginRight (length.rem 0.5)
                        ]
                        prop.text "🔍"
                    ]
                    // Input
                    Html.input [
                        prop.style [
                            style.custom ("border", "none")
                            style.custom ("outline", "none")
                            style.width (length.percent 100)
                            style.fontSize (length.rem 1)
                            style.color "#1f2937"
                            style.backgroundColor.transparent
                        ]
                        prop.type' "text"
                        prop.placeholder "Search zettels..."
                        prop.value query
                        prop.onChange (fun (value: string) ->
                            dispatch (UpdateSearchQuery value)
                            if not (String.IsNullOrWhiteSpace value) then
                                dispatch (PerformSearch value)
                        )
                        prop.onFocus (fun _ -> setFocused true)
                        prop.onBlur (fun _ ->
                            JS.setTimeout (fun () -> setFocused false) 200 |> ignore
                        )
                    ]
                    // Clear button
                    if not (String.IsNullOrWhiteSpace query) then
                        Html.button [
                            prop.style [
                                style.display.flex
                                style.alignItems.center
                                style.justifyContent.center
                                style.width (length.rem 1.5)
                                style.height (length.rem 1.5)
                                style.borderRadius (length.percent 50)
                                style.backgroundColor "#f3f4f6"
                                style.custom ("border", "none")
                                style.cursor.pointer
                                style.color "#6b7280"
                            ]
                            prop.onClick (fun _ ->
                                dispatch (UpdateSearchQuery "")
                                dispatch ClearSearch
                            )
                            prop.text "✕"
                        ]
                ]
            ]

            // Dropdown results
            if showDropdown then
                Html.div [
                    prop.style [
                        style.position.absolute
                        style.top (length.percent 100)
                        style.left 0
                        style.right 0
                        style.marginTop (length.rem 0.25)
                        style.backgroundColor "white"
                        style.border (1, borderStyle.solid, "#e5e7eb")
                        style.borderRadius (length.rem 0.5)
                        style.zIndex 50
                        style.maxHeight (length.rem 20)
                        style.overflow.auto
                    ]
                    prop.children [
                        match results with
                        | Loading ->
                            Html.div [
                                prop.style [
                                    style.padding (length.rem 1)
                                    style.textAlign.center
                                    style.color "#6b7280"
                                ]
                                prop.text "Searching..."
                            ]
                        | Loaded searchResults ->
                            yield!
                                searchResults
                                |> List.mapi (fun index result ->
                                    Html.div [
                                        prop.key (string result.Zettel.Id)
                                        prop.style [
                                            style.padding (length.rem 0.75, length.rem 1)
                                            style.cursor.pointer
                                            style.borderBottom (1, borderStyle.solid, "#f3f4f6")
                                            style.backgroundColor (if index = selectedIndex then "#f9fafb" else "white")
                                        ]
                                        prop.onClick (fun _ ->
                                            dispatch (SelectZettel result.Zettel.Id)
                                            setFocused false
                                        )
                                        prop.onMouseEnter (fun _ -> setSelectedIndex index)
                                        prop.children [
                                            Html.div [
                                                prop.style [
                                                    style.fontWeight 500
                                                    style.color "#1f2937"
                                                    style.marginBottom (length.rem 0.25)
                                                ]
                                                prop.text result.Zettel.Title
                                            ]
                                            Html.div [
                                                prop.style [
                                                    style.fontSize (length.rem 0.875)
                                                    style.color "#6b7280"
                                                    style.overflow.hidden
                                                    style.textOverflow.ellipsis
                                                    style.custom ("whiteSpace", "nowrap")
                                                ]
                                                prop.text (
                                                    if result.Zettel.Content.Length > 100
                                                    then result.Zettel.Content.Substring(0, 100) + "..."
                                                    else result.Zettel.Content
                                                )
                                            ]
                                            Html.div [
                                                prop.style [
                                                    style.display.flex
                                                    style.alignItems.center
                                                    style.gap (length.rem 0.5)
                                                    style.marginTop (length.rem 0.25)
                                                    style.fontSize (length.rem 0.75)
                                                    style.color "#9ca3af"
                                                ]
                                                prop.children [
                                                    Compact result.Zettel.Entropy
                                                    Html.span [ prop.text $"Score: {result.Score:F2}" ]
                                                ]
                                            ]
                                        ]
                                    ]
                                )
                        | _ -> Html.none
                    ]
                ]
        ]
    ]
