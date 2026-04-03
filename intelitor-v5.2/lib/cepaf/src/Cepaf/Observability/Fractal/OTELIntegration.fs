// OTELIntegration.fs
// WHAT: OpenTelemetry Integration for F# Fractal Logging System
// WHY: Provides seamless integration with OTEL/SigNoz observability stack via
//      .NET ActivitySource (W3C traceparent) + custom fractal span context.
//      Bridges F# spans to OTLP collector alongside Elixir and Rust runtimes.
// CONSTRAINTS: Must align with Indrajaal.Observability.Fractal.OtelIntegration
// SOPv5.11 Compliance: SC-LOG-004, SC-OBS-069, SC-OBS-071
// W3C: traceparent header propagation across Elixir↔F#↔Rust
// v1.1.0: Added .NET ActivitySource bridge for proper distributed tracing

namespace Cepaf.Observability.Fractal

open System
open System.Collections.Concurrent
open System.Collections.Generic
open System.Diagnostics
open System.Net.Http
open System.Text
open System.Text.Json
open OpenTelemetry
open OpenTelemetry.Resources
open OpenTelemetry.Trace

/// TracerProvider bootstrap — registers ActivitySource listener so
/// ActivitySource.StartActivity returns non-null Activity objects.
/// Without this, the dual-emit path always falls to standalone OTELSpanContext.
/// SC-OBS-071: F# OTel pipeline activation
module TracerProviderBootstrap =
    let private endpoint =
        Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
        |> Option.ofObj |> Option.defaultValue "http://localhost:4317"

    let private provider =
        Sdk.CreateTracerProviderBuilder()
            .AddSource("cepaf-fsharp")
            .SetResourceBuilder(
                ResourceBuilder.CreateDefault()
                    .AddService("indrajaal-cepaf", serviceVersion = "21.2.1"))
            .AddOtlpExporter(fun o -> o.Endpoint <- Uri(endpoint))
            .Build()

    /// Check if the TracerProvider was initialized successfully
    let isActive () = provider <> null

/// OTEL Baggage for cross-service trace correlation (SC-LOG-004)
/// Aligned with Indrajaal.Observability.Fractal.OtelIntegration baggage format
module OTELBaggage =

    let private baggagePrefix = "ot-baggage-fractal-"

    /// Baggage keys matching Elixir implementation
    type BaggageKeys = {
        Level: string
        Module: string
        Function: string
        Boost: string
        TraceId: string
        HLC: string
        Expr: string
        Depth: string
        Filter: string
    }

    let keys = {
        Level = baggagePrefix + "level"
        Module = baggagePrefix + "module"
        Function = baggagePrefix + "function"
        Boost = baggagePrefix + "boost"
        TraceId = baggagePrefix + "trace-id"
        HLC = baggagePrefix + "hlc"
        Expr = baggagePrefix + "expr"
        Depth = baggagePrefix + "depth"
        Filter = baggagePrefix + "filter"
    }

    /// Per-span baggage via Activity.Current (not process-global).
    /// Falls back to ConcurrentDictionary when no Activity is active.
    /// SC-OTEL-MATH-009: context propagation integrity
    let private fallbackBaggage = ConcurrentDictionary<string, string>()

    let set (key: string) (value: string) =
        match Activity.Current with
        | null -> fallbackBaggage.[key] <- value
        | act -> act.SetBaggage(key, value) |> ignore

    let get (key: string) =
        match Activity.Current with
        | null ->
            match fallbackBaggage.TryGetValue(key) with
            | true, v -> Some v
            | false, _ -> None
        | act ->
            act.GetBaggageItem(key) |> Option.ofObj

    let getAll () =
        match Activity.Current with
        | null -> fallbackBaggage |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq
        | act -> act.Baggage |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq

    let clear () =
        fallbackBaggage.Clear()

    let setFractalContext (moduleName: string) (functionName: string) (level: FractalLevel) (traceId: string option) =
        let levelStr = FractalLevel.toString level
        set keys.Level levelStr
        set keys.Module moduleName
        set keys.Function functionName
        set keys.Depth levelStr
        set keys.Expr (sprintf "CEPAF/%s/%s" moduleName functionName)
        set keys.Filter "enabled"
        traceId |> Option.iter (fun tid -> set keys.TraceId tid)

    /// Inject baggage into HTTP headers for cross-service propagation
    let injectHeaders (headers: System.Collections.Generic.IDictionary<string, string>) =
        for (key, value) in getAll() |> Map.toSeq do
            headers.[key] <- value

    /// Extract baggage from HTTP headers
    let extractHeaders (headers: System.Collections.Generic.IDictionary<string, string>) =
        headers
        |> Seq.filter (fun kvp -> kvp.Key.StartsWith(baggagePrefix))
        |> Seq.iter (fun kvp -> set kvp.Key kvp.Value)

/// OTEL Span Context for distributed tracing
type OTELSpanContext = {
    TraceId: string
    SpanId: string
    ParentSpanId: string option
    StartTime: DateTimeOffset
    Module: string
    Function: string
    Level: FractalLevel
    Attributes: Map<string, obj>
}

/// .NET ActivitySource bridge for W3C traceparent distributed tracing.
/// This uses the standard System.Diagnostics.Activity API which the
/// OpenTelemetry .NET SDK instruments automatically when configured.
/// Bridges F# fractal spans into the unified OTLP pipeline alongside
/// Elixir (opentelemetry hex) and Rust (tracing-opentelemetry).
///
/// SC-OBS-071: Cross-runtime OTEL integration
/// SC-LOG-004: W3C traceparent context propagation
module ActivitySourceBridge =

    /// The single ActivitySource for all CEPAF F# operations.
    /// Name matches OTEL_SERVICE_NAME convention for SigNoz correlation.
    /// Exposed as internal for setParentFromTraceparent to start child activities.
    let internal source =
        new ActivitySource(
            "cepaf-fsharp",
            Environment.GetEnvironmentVariable("OTEL_SERVICE_VERSION")
            |> Option.ofObj |> Option.defaultValue "21.2.1")

    /// Start a .NET Activity (span) that the OTel SDK will export via OTLP.
    /// Returns Activity option — None if no listener is attached (OTel SDK not configured).
    let startActivity (operationName: string) (kind: ActivityKind) (tags: (string * string) list) : Activity option =
        let activity = source.StartActivity(operationName, kind)
        match activity with
        | null -> None
        | act ->
            for (key, value) in tags do
                act.SetTag(key, value) |> ignore
            Some act

    /// Start a fractal-aware Activity with standard attributes.
    /// Aligns with Elixir's Indrajaal.Observability.Tracing.trace_domain_operation/4
    let startFractalActivity (moduleName: string) (functionName: string) (level: FractalLevel) : Activity option =
        let opName = sprintf "fractal:%s.%s" (moduleName.Replace("Cepaf.", "")) functionName
        let tags = [
            "fractal.level", FractalLevel.toString level
            "fractal.module", moduleName
            "fractal.function", functionName
            "fractal.enabled", "true"
            "service.name", (Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME")
                             |> Option.ofObj |> Option.defaultValue "cepaf-fsharp")
        ]
        startActivity opName ActivityKind.Internal tags

    /// End an Activity with status. Sets OTEL status code.
    let endActivity (activity: Activity option) (status: Result<unit, exn>) =
        match activity with
        | None -> ()
        | Some act ->
            match status with
            | Ok () ->
                act.SetStatus(ActivityStatusCode.Ok) |> ignore
            | Error ex ->
                act.SetStatus(ActivityStatusCode.Error, ex.Message) |> ignore
                let evt = ActivityEvent("exception", tags = ActivityTagsCollection([
                    KeyValuePair("exception.type", ex.GetType().FullName :> obj)
                    KeyValuePair("exception.message", ex.Message :> obj)
                ]))
                act.AddEvent(evt) |> ignore
            act.Stop()

    /// Extract W3C traceparent from current Activity for cross-runtime propagation.
    /// Format: "00-{traceId}-{spanId}-{flags}"
    /// This header can be injected into Zenoh message payloads for Elixir/Rust correlation.
    let getTraceparent () : string option =
        match Activity.Current with
        | null -> None
        | act ->
            let flags = if act.Recorded then "01" else "00"
            Some (sprintf "00-%s-%s-%s" (act.TraceId.ToHexString()) (act.SpanId.ToHexString()) flags)

    /// Parse W3C traceparent header and start a child Activity with correct parent context.
    /// Used when receiving Zenoh messages from Elixir or Rust that carry trace context.
    /// SC-OTEL-MATH-009: W3C context propagation
    let setParentFromTraceparent (traceparent: string) : Activity option =
        try
            let parts = traceparent.Split('-')
            if parts.Length >= 4 then
                let traceId = ActivityTraceId.CreateFromString(parts.[1].AsSpan())
                let spanId = ActivitySpanId.CreateFromString(parts.[2].AsSpan())
                let flags = if parts.[3] = "01" then ActivityTraceFlags.Recorded else ActivityTraceFlags.None
                let parentCtx = ActivityContext(traceId, spanId, flags, isRemote = true)
                // Start child Activity with remote parent — the correct .NET pattern
                let activity = source.StartActivity("zenoh-receive", ActivityKind.Consumer, parentCtx)
                match activity with
                | null -> None
                | act -> Some act
            else
                None
        with _ -> None // Graceful degradation on malformed traceparent

/// OpenTelemetry Integration for Fractal Logging
/// Aligned with Indrajaal.Observability.Fractal.OtelIntegration
module OTELIntegration =

    let private otelEndpoint =
        Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
        |> Option.ofObj
        |> Option.defaultValue "http://localhost:4317"

    let private serviceName =
        Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME")
        |> Option.ofObj
        |> Option.defaultValue "cepaf-fsharp"

    let private httpClient = lazy(new HttpClient())

    /// Generate a random hex ID of specified length
    let private generateId (length: int) =
        let bytes = Array.zeroCreate<byte> (length / 2)
        System.Security.Cryptography.RandomNumberGenerator.Fill(bytes)
        BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant()

    /// Build span name in fractal format: "fractal:Module.Function"
    let private buildSpanName (moduleName: string) (functionName: string) =
        sprintf "fractal:%s.%s" (moduleName.Replace("Cepaf.", "")) functionName

    /// Start a new fractal span with OTEL context.
    /// Dual-emits: (1) custom OTELSpanContext for Zenoh/SigNoz push, and
    /// (2) .NET ActivitySource span for OTLP SDK export (W3C traceparent).
    /// Aligned with OtelIntegration.start_fractal_span/3 in Elixir.
    let startFractalSpan (moduleName: string) (functionName: string) (level: FractalLevel) : OTELSpanContext =
        // Start .NET Activity (picked up by OTel SDK if configured)
        let _activity = ActivitySourceBridge.startFractalActivity moduleName functionName level

        let traceId =
            // If Activity is active, reuse its trace ID for correlation
            match Activity.Current with
            | null -> generateId 32
            | act -> act.TraceId.ToHexString()
        let spanId =
            match Activity.Current with
            | null -> generateId 16
            | act -> act.SpanId.ToHexString()
        let hlc = FractalControl.hlcNow()

        // Set baggage for downstream propagation
        OTELBaggage.setFractalContext moduleName functionName level (Some traceId)
        OTELBaggage.set OTELBaggage.keys.HLC (sprintf "%d.%d@%s" hlc.Physical hlc.Counter hlc.NodeId)

        // Build span attributes matching Elixir implementation
        let attributes = Map.ofList [
            ("fractal.level", FractalLevel.toString level :> obj)
            ("fractal.module", moduleName :> obj)
            ("fractal.function", functionName :> obj)
            ("fractal.enabled", true :> obj)
            ("fractal.hlc.physical", hlc.Physical :> obj)
            ("fractal.hlc.counter", hlc.Counter :> obj)
            ("fractal.hlc.node_id", hlc.NodeId :> obj)
            ("service.name", serviceName :> obj)
        ]

        { TraceId = traceId
          SpanId = spanId
          ParentSpanId = None
          StartTime = DateTimeOffset.UtcNow
          Module = moduleName
          Function = functionName
          Level = level
          Attributes = attributes }

    /// End a fractal span with status
    /// Aligned with OtelIntegration.end_fractal_span/2 in Elixir
    let endFractalSpan (ctx: OTELSpanContext) (status: Result<unit, exn>) =
        let duration = DateTimeOffset.UtcNow - ctx.StartTime
        let statusCode = match status with Ok _ -> "OK" | Error _ -> "ERROR"

        // Clear baggage
        OTELBaggage.clear()

        (ctx, duration, statusCode)

    /// Record an exception on the span
    let recordException (ctx: OTELSpanContext) (exn: exn) =
        let exceptionAttrs = Map.ofList [
            ("exception.type", exn.GetType().FullName :> obj)
            ("exception.message", exn.Message :> obj)
            ("exception.stacktrace", (exn.StackTrace |> Option.ofObj |> Option.defaultValue "") :> obj)
        ]
        (ctx, exceptionAttrs)

    /// Get current L3 TraceID for correlation (SC-LOG-004)
    let getL3TraceId () =
        OTELBaggage.get OTELBaggage.keys.TraceId

    /// Link a log entry to L3 trace (SC-LOG-004)
    let linkToL3Trace (entry: FractalLogEntry) : FractalLogEntry =
        match getL3TraceId() with
        | None -> entry
        | Some traceId ->
            { entry with
                TraceId = Some traceId
                Baggage = entry.Baggage |> Map.add "l3_trace_id" traceId
                                        |> Map.add "trace_correlation" "true" }

/// SigNoz Integration for traces/metrics/logs (SC-OBS-069)
module SigNozIntegration =

    let private signozEndpoint =
        Environment.GetEnvironmentVariable("SIGNOZ_QUERY_SERVICE_URL")
        |> Option.ofObj
        |> Option.defaultValue "http://localhost:8080"

    let private signozEnabled =
        Environment.GetEnvironmentVariable("SIGNOZ_ENABLED")
        |> Option.ofObj
        |> Option.map (fun s -> s.ToLowerInvariant() = "true")
        |> Option.defaultValue false

    let private httpClient = lazy(new HttpClient())

    /// SigNoz trace data structure
    type TraceData = {
        TraceId: string
        SpanId: string
        ParentSpanId: string option
        OperationName: string
        ServiceName: string
        StartTimeUnixNano: int64
        DurationNano: int64
        Status: string
        Tags: Map<string, string>
        Events: list<Map<string, obj>>
    }

    /// Convert span context to SigNoz trace data
    let spanToTraceData (ctx: OTELSpanContext) (duration: TimeSpan) (status: string) : TraceData =
        {
            TraceId = ctx.TraceId
            SpanId = ctx.SpanId
            ParentSpanId = ctx.ParentSpanId
            OperationName = sprintf "fractal:%s.%s" ctx.Module ctx.Function
            ServiceName =
                Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME")
                |> Option.ofObj
                |> Option.defaultValue "cepaf-fsharp"
            StartTimeUnixNano = ctx.StartTime.ToUnixTimeMilliseconds() * 1_000_000L
            DurationNano = int64 (duration.TotalMilliseconds * 1_000_000.0)
            Status = status
            Tags = ctx.Attributes |> Map.map (fun _ v -> v.ToString())
            Events = []
        }

    /// Push trace to SigNoz
    let pushTrace (trace: TraceData) =
        async {
            if not signozEnabled then return false
            else
                try
                    let payload = JsonSerializer.Serialize(trace)
                    let content = new StringContent(payload, Encoding.UTF8, "application/json")
                    let! response = httpClient.Value.PostAsync(signozEndpoint + "/api/v1/traces", content) |> Async.AwaitTask
                    return response.IsSuccessStatusCode
                with
                | _ -> return false
        }

    /// Query traces from SigNoz
    let queryTraces (serviceName: string) (limit: int) =
        async {
            if not signozEnabled then return None
            else
                try
                    let url = sprintf "%s/api/v1/traces?service=%s&limit=%d" signozEndpoint serviceName limit
                    let! response = httpClient.Value.GetStringAsync(url) |> Async.AwaitTask
                    return Some response
                with
                | _ -> return None
        }

    /// Check SigNoz health
    let checkHealth () =
        async {
            if not signozEnabled then return false
            else
                try
                    let! response = httpClient.Value.GetAsync(signozEndpoint + "/api/v1/health") |> Async.AwaitTask
                    return response.IsSuccessStatusCode
                with
                | _ -> return false
        }

/// PII Masker for automatic sensitive data redaction (SC-LOG-003)
/// Aligned with Indrajaal.Observability.Fractal.PIIMasker
module OTELPIIMasker =

    let private piiPatterns = [
        (@"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b", "[EMAIL-REDACTED]")
        (@"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b", "[PHONE-REDACTED]")
        (@"\b\d{3}[-]?\d{2}[-]?\d{4}\b", "[SSN-REDACTED]")
        (@"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14})\b", "[CARD-REDACTED]")
        ("password", "[PASSWORD-FIELD]")
        ("secret", "[SECRET-FIELD]")
        ("api_key", "[API-KEY-FIELD]")
        ("token", "[TOKEN-FIELD]")
    ]

    /// Mask PII in a string value
    let mask (value: string) =
        if String.IsNullOrEmpty(value) then value
        else
            piiPatterns
            |> List.fold (fun acc (pattern, replacement) ->
                System.Text.RegularExpressions.Regex.Replace(
                    acc, pattern, replacement,
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase)) value

    /// Mask specific fields in a map
    let maskFields (fields: string list) (data: Map<string, obj>) =
        data |> Map.map (fun key value ->
            let keyLower = key.ToLowerInvariant()
            if List.exists (fun (f: string) -> keyLower.Contains(f.ToLowerInvariant())) fields then
                "[REDACTED]" :> obj
            else
                match value with
                | :? string as s -> mask s :> obj
                | other -> other)

/// Fractal Decorator for wrapping functions with automatic tracing
module OTELFractalDecorator =

    /// Wrap a function with automatic entry/exit logging and OTEL tracing
    let wrap<'a> (moduleName: string) (functionName: string) (level: FractalLevel) (fn: unit -> 'a) : 'a =
        let spanCtx = OTELIntegration.startFractalSpan moduleName functionName level
        let key = sprintf "CEPAF/%s/%s" moduleName functionName

        // Check if logging is enabled
        let baggage = OTELBaggage.getAll()
        let shouldLog = FractalControl.shouldLog key level baggage

        if not shouldLog then
            fn()
        else
            try
                let result = fn()
                let (ctx, duration, status) = OTELIntegration.endFractalSpan spanCtx (Ok ())

                // Push to SigNoz fire-and-forget (SC-LOG-001: non-blocking, SC-PRF-055: no starvation)
                SigNozIntegration.spanToTraceData ctx duration status
                |> SigNozIntegration.pushTrace
                |> Async.Ignore
                |> Async.Start

                result
            with
            | exn ->
                let (ctx, duration, status) = OTELIntegration.endFractalSpan spanCtx (Error exn)
                let (_, exnAttrs) = OTELIntegration.recordException spanCtx exn

                // Push error to SigNoz fire-and-forget
                let traceData = SigNozIntegration.spanToTraceData ctx duration status
                { traceData with Tags = Map.fold (fun acc k v -> Map.add k (v.ToString()) acc) traceData.Tags exnAttrs }
                |> SigNozIntegration.pushTrace
                |> Async.Ignore
                |> Async.Start

                reraise()

    /// Wrap an async function with automatic entry/exit logging and OTEL tracing
    let wrapAsync<'a> (moduleName: string) (functionName: string) (level: FractalLevel) (fn: Async<'a>) : Async<'a> =
        async {
            let spanCtx = OTELIntegration.startFractalSpan moduleName functionName level
            let key = sprintf "CEPAF/%s/%s" moduleName functionName

            // Check if logging is enabled
            let baggage = OTELBaggage.getAll()
            let shouldLog = FractalControl.shouldLog key level baggage

            if not shouldLog then
                return! fn
            else
                try
                    let! result = fn
                    let (ctx, duration, status) = OTELIntegration.endFractalSpan spanCtx (Ok ())

                    // Push to SigNoz asynchronously
                    do! SigNozIntegration.spanToTraceData ctx duration status
                        |> SigNozIntegration.pushTrace
                        |> Async.Ignore

                    return result
                with
                | exn ->
                    let (ctx, duration, status) = OTELIntegration.endFractalSpan spanCtx (Error exn)
                    let (_, exnAttrs) = OTELIntegration.recordException spanCtx exn

                    // Push error to SigNoz
                    let traceData = SigNozIntegration.spanToTraceData ctx duration status
                    do! { traceData with Tags = Map.fold (fun acc k v -> Map.add k (v.ToString()) acc) traceData.Tags exnAttrs }
                        |> SigNozIntegration.pushTrace
                        |> Async.Ignore

                    return raise exn
        }
