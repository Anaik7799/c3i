/// Entropy Badge Component - Visual indicator for knowledge freshness
///
/// Displays entropy level (0.0 fresh to 1.0 rotting) with color coding.
///
/// STAMP Constraints:
/// - SC-KMS-003: Entropy calculation matches Gardener.fs
module Cepaf.Smriti.Client.Components.EntropyBadge

open Feliz
open Cepaf.Smriti.Client.Model

/// Small circular indicator
[<ReactComponent>]
let Dot (entropy: float) =
    let color = entropyToColor entropy
    Html.span [
        prop.style [
            style.display.inlineBlock
            style.width (length.rem 0.5)
            style.height (length.rem 0.5)
            style.borderRadius (length.percent 50)
            style.backgroundColor color
        ]
        prop.title (entropyToLabel entropy)
    ]

/// Full entropy badge with label
[<ReactComponent>]
let Badge (entropy: float) =
    let color = entropyToColor entropy
    let label = entropyToLabel entropy
    let percentage = int (entropy * 100.0)

    Html.span [
        prop.style [
            style.display.inlineFlex
            style.alignItems.center
            style.gap (length.rem 0.25)
            style.padding (length.rem 0.25, length.rem 0.5)
            style.borderRadius (length.rem 0.25)
            style.fontSize (length.rem 0.75)
            style.fontWeight 500
            style.backgroundColor color
            style.color "white"
        ]
        prop.children [
            // Icon based on entropy level
            Html.span [
                prop.style [
                    style.width (length.rem 0.75)
                    style.height (length.rem 0.75)
                ]
                prop.children [
                    match getEntropyLevel entropy with
                    | Fresh -> Html.text "✓"
                    | Recent -> Html.text "○"
                    | Aging -> Html.text "◐"
                    | Stale -> Html.text "◑"
                    | Rotting -> Html.text "⚠"
                ]
            ]
            Html.span [
                prop.text $"{label} ({percentage}%%)"
            ]
        ]
    ]

/// Compact badge (just percentage)
[<ReactComponent>]
let Compact (entropy: float) =
    let color = entropyToColor entropy
    let percentage = int (entropy * 100.0)

    Html.span [
        prop.style [
            style.padding (length.rem 0.125, length.rem 0.375)
            style.borderRadius (length.rem 0.25)
            style.fontSize (length.rem 0.625)
            style.fontWeight 500
            style.backgroundColor color
            style.color "white"
        ]
        prop.text $"{percentage}%%"
    ]

/// Progress bar showing entropy level
[<ReactComponent>]
let ProgressBar (entropy: float) =
    let color = entropyToColor entropy
    let percentage = int (entropy * 100.0)

    Html.div [
        prop.style [
            style.width (length.percent 100)
            style.height (length.rem 0.5)
            style.backgroundColor "#e5e7eb"
            style.borderRadius (length.rem 0.25)
            style.overflow.hidden
        ]
        prop.children [
            Html.div [
                prop.style [
                    style.width (length.percent percentage)
                    style.height (length.percent 100)
                    style.backgroundColor color
                ]
            ]
        ]
    ]
