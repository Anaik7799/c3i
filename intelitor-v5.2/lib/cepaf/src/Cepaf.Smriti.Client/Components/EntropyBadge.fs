namespace Cepaf.Smriti.Client.Components

/// <summary>
/// Entropy badge component for visualizing zettel decay.
///
/// ## WHAT
/// Visual indicator of zettel freshness using color-coded badges.
///
/// ## WHY
/// Immediate visual feedback on knowledge decay helps prioritize maintenance.
///
/// ## CONSTRAINTS
/// - SC-KMS-003: Entropy calculation must match Gardener.fs backend
/// - SC-KMS-005: Visual representation must be intuitive
/// </summary>
module EntropyBadge

open Feliz
open Fable.Core.JsInterop

/// <summary>
/// Map entropy (0.0-1.0) to color hex code.
/// </summary>
/// <param name="entropy">Entropy value from 0.0 (fresh) to 1.0 (rotting)</param>
let entropyToColor (entropy: float) : string =
    match entropy with
    | e when e < 0.2 -> "#22c55e"  // Green (fresh)
    | e when e < 0.4 -> "#84cc16"  // Lime (good)
    | e when e < 0.6 -> "#eab308"  // Yellow (aging)
    | e when e < 0.8 -> "#f97316"  // Orange (stale)
    | _ -> "#ef4444"               // Red (rotting)

/// <summary>
/// Map entropy to human-readable label.
/// </summary>
let entropyToLabel (entropy: float) : string =
    match entropy with
    | e when e < 0.2 -> "Fresh"
    | e when e < 0.4 -> "Good"
    | e when e < 0.6 -> "Aging"
    | e when e < 0.8 -> "Stale"
    | _ -> "Rotting"

/// <summary>
/// Map entropy to emoji indicator.
/// </summary>
let entropyToEmoji (entropy: float) : string =
    match entropy with
    | e when e < 0.2 -> "🌱"  // Seedling
    | e when e < 0.4 -> "🌿"  // Herb
    | e when e < 0.6 -> "🍂"  // Fallen leaf
    | e when e < 0.8 -> "🥀"  // Wilted flower
    | _ -> "💀"               // Skull (decay)

/// <summary>
/// Render entropy badge component.
/// </summary>
/// <param name="entropy">Entropy value from 0.0 to 1.0</param>
/// <param name="showPercentage">Whether to show numeric percentage</param>
let render (entropy: float) (showPercentage: bool) =
    let color = entropyToColor entropy
    let label = entropyToLabel entropy
    let emoji = entropyToEmoji entropy
    let percentage = entropy * 100.0

    Html.span [
        prop.className "entropy-badge"
        prop.style [
            style.display.inlineBlock
            style.padding (5, 10)
            style.borderRadius 4
            style.backgroundColor color
            style.color "#ffffff"
            style.fontSize 14
            style.fontWeight 600
            style.marginLeft 8
        ]
        prop.children [
            Html.span [
                prop.text (sprintf "%s %s" emoji label)
            ]
            if showPercentage then
                Html.span [
                    prop.style [ style.marginLeft 5; style.opacity 0.8 ]
                    prop.text (sprintf "(%.0f%%)" percentage)
                ]
        ]
    ]

/// <summary>
/// Render compact entropy indicator (just emoji + color).
/// </summary>
let renderCompact (entropy: float) =
    let color = entropyToColor entropy
    let emoji = entropyToEmoji entropy

    Html.span [
        prop.className "entropy-compact"
        prop.style [
            style.display.inlineBlock
            style.padding (2, 6)
            style.borderRadius 3
            style.backgroundColor color
            style.fontSize 12
        ]
        prop.text emoji
        prop.title (sprintf "%s (%.0f%%)" (entropyToLabel entropy) (entropy * 100.0))
    ]

/// <summary>
/// Render entropy progress bar.
/// </summary>
let renderProgressBar (entropy: float) (width: int) =
    let color = entropyToColor entropy
    let percentage = entropy * 100.0
    let label = entropyToLabel entropy

    Html.div [
        prop.className "entropy-progress"
        prop.style [
            style.width width
            style.height 20
            style.backgroundColor "#e5e7eb"
            style.borderRadius 4
            style.overflow.hidden
            style.position.relative
        ]
        prop.children [
            Html.div [
                prop.style [
                    style.width (length.percent percentage)
                    style.height 20
                    style.backgroundColor color
                    style.transitionProperty "width"
                    style.transitionDuration (System.TimeSpan.FromMilliseconds(300.0))
                ]
            ]
            Html.span [
                prop.style [
                    style.position.absolute
                    style.top 0
                    style.left 0
                    style.right 0
                    style.bottom 0
                    style.display.flex
                    style.alignItems.center
                    style.justifyContent.center
                    style.fontSize 12
                    style.fontWeight 600
                    style.color "#374151"
                ]
                prop.text (sprintf "%s (%.0f%%)" label percentage)
            ]
        ]
    ]
