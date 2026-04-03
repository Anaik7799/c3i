/// SignalArrows Unit Tests
/// Tests for reactive operators and signal processing
module Cepaf.Cockpit.Tests.SignalArrowsTests

open System
open Expecto

// ============================================================================
// Unit Tests: Signal Filtering
// ============================================================================

let lowPassFilter (alpha: float) (signal: float list) =
    signal
    |> List.scan (fun acc x -> alpha * x + (1.0 - alpha) * acc) (List.head signal)
    |> List.tail

let highPassFilter (alpha: float) (signal: float list) =
    if List.isEmpty signal then []
    else
        let rec loop prev rest acc =
            match rest with
            | [] -> List.rev acc
            | x :: xs ->
                let filtered = alpha * (List.head acc + x - prev)
                loop x xs (filtered :: acc)
        match signal with
        | [] -> []
        | [x] -> [x]
        | x :: rest -> loop x rest [x]

[<Tests>]
let filterTests =
    testList "SignalFilters" [
        test "low-pass filter should smooth signal" {
            let signal = [10.0; 20.0; 30.0; 40.0; 50.0]
            let filtered = lowPassFilter 0.5 signal
            // Low-pass filter: List.scan produces n+1 elements, List.tail removes first -> n elements
            Expect.equal filtered.Length signal.Length "Should have same length as input"
        }

        test "low-pass filter with alpha=1 should pass signal through" {
            let signal = [10.0; 20.0; 30.0]
            let filtered = lowPassFilter 1.0 signal
            // With alpha=1: each output = 1.0 * x + 0.0 * acc = x (the input value)
            Expect.equal filtered signal "Alpha=1 should pass through unchanged"
        }

        test "low-pass filter with alpha=0 should hold initial value" {
            let signal = [10.0; 20.0; 30.0]
            let filtered = lowPassFilter 0.0 signal
            // With alpha=0: each output = 0.0 * x + 1.0 * acc = acc (always the initial value)
            Expect.equal filtered [10.0; 10.0; 10.0] "Alpha=0 should hold initial for all outputs"
        }
    ]

// ============================================================================
// Unit Tests: Signal Debouncing
// ============================================================================

type DebouncedSignal<'T> = {
    Value: 'T
    StableFor: TimeSpan
}

let debounce (minStableTime: TimeSpan) (signals: ('T * DateTime) list) : DebouncedSignal<'T> list =
    if List.isEmpty signals then []
    else
        signals
        |> List.pairwise
        |> List.filter (fun ((_, t1), (_, t2)) -> (t2 - t1) >= minStableTime)
        |> List.map (fun ((v, t1), (_, t2)) ->
            { Value = v; StableFor = t2 - t1 })

[<Tests>]
let debounceTests =
    testList "Debounce" [
        test "should filter rapid changes" {
            let now = DateTime.UtcNow
            let signals = [
                (1, now)
                (2, now.AddMilliseconds(10.0))  // Too fast
                (3, now.AddMilliseconds(50.0))  // Too fast
                (4, now.AddMilliseconds(200.0)) // Stable
            ]
            let debounced = debounce (TimeSpan.FromMilliseconds(100.0)) signals
            Expect.equal debounced.Length 1 "Should filter rapid changes"
        }

        test "should pass stable signals" {
            let now = DateTime.UtcNow
            let signals = [
                (1, now)
                (2, now.AddMilliseconds(150.0))
                (3, now.AddMilliseconds(300.0))
            ]
            let debounced = debounce (TimeSpan.FromMilliseconds(100.0)) signals
            Expect.equal debounced.Length 2 "Should pass stable signals"
        }

        test "should handle empty signals" {
            let debounced = debounce (TimeSpan.FromMilliseconds(100.0)) []
            Expect.isEmpty debounced "Should return empty for empty input"
        }
    ]

// ============================================================================
// Unit Tests: Signal Throttling
// ============================================================================

let throttle (minInterval: TimeSpan) (signals: ('T * DateTime) list) =
    match signals with
    | [] -> []
    | first :: rest ->
        let _, lastTime =
            rest
            |> List.fold (fun (acc, lastTime) (value, time) ->
                if time - lastTime >= minInterval then
                    ((value, time) :: acc, time)
                else
                    (acc, lastTime)
            ) ([first], snd first)
        fst (rest |> List.fold (fun (acc, lastTime) (value, time) ->
            if time - lastTime >= minInterval then
                ((value, time) :: acc, time)
            else
                (acc, lastTime)
        ) ([first], snd first))
        |> List.rev

[<Tests>]
let throttleTests =
    testList "Throttle" [
        test "should limit signal rate" {
            let now = DateTime.UtcNow
            let signals = [
                (1, now)
                (2, now.AddMilliseconds(50.0))
                (3, now.AddMilliseconds(100.0))
                (4, now.AddMilliseconds(250.0))
                (5, now.AddMilliseconds(300.0))
            ]
            let throttled = throttle (TimeSpan.FromMilliseconds(100.0)) signals
            Expect.isLessThanOrEqual throttled.Length 3 "Should throttle rate"
        }

        test "should pass signals at allowed rate" {
            let now = DateTime.UtcNow
            let signals = [
                (1, now)
                (2, now.AddMilliseconds(200.0))
                (3, now.AddMilliseconds(400.0))
            ]
            let throttled = throttle (TimeSpan.FromMilliseconds(100.0)) signals
            Expect.equal throttled.Length 3 "Should pass all when under rate"
        }

        test "should handle empty signals" {
            let throttled = throttle (TimeSpan.FromMilliseconds(100.0)) []
            Expect.isEmpty throttled "Should return empty for empty input"
        }
    ]

// ============================================================================
// Unit Tests: Signal Mapping and Composition
// ============================================================================

let mapSignal (f: 'a -> 'b) (signal: 'a list) : 'b list =
    List.map f signal

let combineSignals (f: 'a -> 'b -> 'c) (s1: 'a list) (s2: 'b list) : 'c list =
    List.map2 f s1 s2

let zipSignals (s1: 'a list) (s2: 'b list) : ('a * 'b) list =
    List.zip s1 s2

[<Tests>]
let compositionTests =
    testList "SignalComposition" [
        test "should map signal values" {
            let signal = [1.0; 2.0; 3.0]
            let mapped = mapSignal (fun x -> x * 2.0) signal
            Expect.equal mapped [2.0; 4.0; 6.0] "Should double values"
        }

        test "should combine two signals" {
            let s1 = [1.0; 2.0; 3.0]
            let s2 = [10.0; 20.0; 30.0]
            let combined = combineSignals (+) s1 s2
            Expect.equal combined [11.0; 22.0; 33.0] "Should add signals"
        }

        test "should zip two signals" {
            let s1 = [1; 2; 3]
            let s2 = ["a"; "b"; "c"]
            let zipped = zipSignals s1 s2
            Expect.equal zipped [(1, "a"); (2, "b"); (3, "c")] "Should zip signals"
        }
    ]

// ============================================================================
// Unit Tests: Alarm Detection
// ============================================================================

type AlarmLevel =
    | Info
    | Warning
    | Critical

type Alarm = {
    Level: AlarmLevel
    Message: string
    Timestamp: DateTime
}

let detectAlarms (threshold: float) (criticalThreshold: float) (values: float list) =
    values
    |> List.mapi (fun i v ->
        if v >= criticalThreshold then
            Some { Level = Critical; Message = sprintf "Value %d exceeded critical: %.1f" i v; Timestamp = DateTime.UtcNow }
        elif v >= threshold then
            Some { Level = Warning; Message = sprintf "Value %d exceeded threshold: %.1f" i v; Timestamp = DateTime.UtcNow }
        else
            None)
    |> List.choose id

[<Tests>]
let alarmDetectionTests =
    testList "AlarmDetection" [
        test "should detect warning alarms" {
            let values = [50.0; 85.0; 60.0; 90.0]
            let alarms = detectAlarms 80.0 95.0 values
            Expect.equal alarms.Length 2 "Should detect 2 warning alarms"
            Expect.isTrue (alarms |> List.forall (fun a -> a.Level = Warning)) "Should be warnings"
        }

        test "should detect critical alarms" {
            let values = [50.0; 98.0; 60.0; 99.0]
            let alarms = detectAlarms 80.0 95.0 values
            let criticals = alarms |> List.filter (fun a -> a.Level = Critical)
            Expect.equal criticals.Length 2 "Should detect 2 critical alarms"
        }

        test "should detect no alarms for normal values" {
            let values = [50.0; 60.0; 70.0; 75.0]
            let alarms = detectAlarms 80.0 95.0 values
            Expect.isEmpty alarms "Should detect no alarms"
        }

        test "should handle empty values" {
            let alarms = detectAlarms 80.0 95.0 []
            Expect.isEmpty alarms "Should return empty for empty input"
        }
    ]

// ============================================================================
// Unit Tests: Rate of Change
// ============================================================================

let rateOfChange (signal: float list) =
    match signal with
    | [] | [_] -> []
    | _ ->
        signal
        |> List.pairwise
        |> List.map (fun (a, b) -> b - a)

let accelerationOfChange (signal: float list) =
    rateOfChange (rateOfChange signal)

[<Tests>]
let rateOfChangeTests =
    testList "RateOfChange" [
        test "should calculate rate of change" {
            let signal = [10.0; 15.0; 25.0; 30.0]
            let rate = rateOfChange signal
            Expect.equal rate [5.0; 10.0; 5.0] "Should calculate differences"
        }

        test "should calculate acceleration" {
            let signal = [10.0; 15.0; 25.0; 30.0]
            let accel = accelerationOfChange signal
            Expect.equal accel [5.0; -5.0] "Should calculate second derivative"
        }

        test "should handle constant signal" {
            let signal = [10.0; 10.0; 10.0]
            let rate = rateOfChange signal
            Expect.equal rate [0.0; 0.0] "Constant signal has zero rate"
        }

        test "should handle empty signal" {
            let rate = rateOfChange []
            Expect.isEmpty rate "Should return empty for empty input"
        }

        test "should handle single value" {
            let rate = rateOfChange [42.0]
            Expect.isEmpty rate "Should return empty for single value"
        }
    ]
