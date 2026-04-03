namespace Cepaf.Cockpit.Web.Components

open System
open Bolero
open Bolero.Html

/// =============================================================================
/// SPARKLINE CHART COMPONENT - Mini Trend Visualization
/// =============================================================================
/// STAMP: SC-HMI-001 (Dark Cockpit), SC-HMI-002 (Trend vectors)
/// =============================================================================

module SparklineChart =

    module Colors =
        let normal = "#6b7280"
        let rising = "#10b981"
        let falling = "#dc2626"
        let stable = "#06b6d4"
        let threshold = "#f59e0b"
        let stale = "#4b5563"

    let getMinMax (values: float list) =
        match values with
        | [] -> 0.0, 100.0
        | vals ->
            let min = List.min vals
            let max = List.max vals
            let range = max - min
            let padding = range * 0.1
            min - padding, max + padding

    let dataToPath (values: float list) (width: float) (height: float) =
        if List.isEmpty values then ""
        else
            let minVal, maxVal = getMinMax values
            let range = maxVal - minVal
            let count = float (List.length values)
            let points =
                values
                |> List.mapi (fun i value ->
                    let x = (float i / (count - 1.0)) * width
                    let y = height - ((value - minVal) / range * height)
                    x, y)
            points
            |> List.fold (fun (acc, first) (x, y) ->
                if first then sprintf "M %.2f %.2f" x y, false
                else sprintf "%s L %.2f %.2f" acc x y, false) ("", true)
            |> fst

    let getTrendColor (values: float list) =
        match values with
        | [] -> Colors.normal
        | [_] -> Colors.stable
        | vals ->
            let first = List.head vals
            let last = List.last vals
            let change = if first <> 0.0 then ((last - first) / first) * 100.0 else 0.0
            if abs change < 5.0 then Colors.stable
            elif change > 0.0 then Colors.rising
            else Colors.falling

    let renderThreshold (threshold: float option) (minVal: float) (maxVal: float) (width: float) (height: float) =
        match threshold with
        | Some thresholdValue when thresholdValue >= minVal && thresholdValue <= maxVal ->
            let range = maxVal - minVal
            let y = height - ((thresholdValue - minVal) / range * height)
            elt "line" {
                "x1" => "0"
                "y1" => string y
                "x2" => string width
                "y2" => string y
                "stroke" => Colors.threshold
                "stroke-width" => "1"
                "stroke-dasharray" => "4,2"
                "opacity" => "0.6"
            }
        | _ -> empty ()

    let renderLastValueDot (values: float list) (width: float) (height: float) (color: string) =
        if List.isEmpty values then empty ()
        else
            let minVal, maxVal = getMinMax values
            let range = maxVal - minVal
            let lastValue = List.last values
            let y = height - ((lastValue - minVal) / range * height)
            elt "circle" {
                "cx" => string width
                "cy" => string y
                "r" => "3"
                "fill" => color
                "opacity" => "0.9"
            }

    let render (values: float list) (width: float) (height: float) (threshold: float option) (showDot: bool) (isStale: bool) =
        let color = if isStale then Colors.stale else getTrendColor values
        let pathData = dataToPath values width height
        let minVal, maxVal = getMinMax values

        elt "svg" {
            "width" => string width
            "height" => string height
            attr.``class`` "sparkline-chart"
            attr.style "display: inline-block; vertical-align: middle;"
            renderThreshold threshold minVal maxVal width height
            elt "path" {
                "d" => pathData
                "fill" => "none"
                "stroke" => color
                "stroke-width" => "2"
                "stroke-linecap" => "round"
                "stroke-linejoin" => "round"
                "opacity" => (if isStale then "0.3" else "1.0")
            }
            if showDot then renderLastValueDot values width height color else empty ()
        }

    let renderSimple (values: float list) =
        render values 100.0 30.0 None true false

    let renderWithThreshold (values: float list) (threshold: float) =
        render values 100.0 30.0 (Some threshold) true false

    let renderInline (values: float list) =
        render values 60.0 20.0 None false false

    let renderWithStaleness (values: float list) (lastUpdateSeconds: float) =
        let isStale = lastUpdateSeconds > 60.0
        render values 100.0 30.0 None true isStale
