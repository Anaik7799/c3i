namespace Cepaf.Core

open System

/// Domain-specific Units of Measure extending Core/Units.fs for specialized domains.
/// Provides type-safe representations for efficiency, sampling, resources, and metrics.
///
/// WHAT: Extended Units of Measure for domain-specific quantities
/// WHY: Eliminates confusion between different percentage types, rates, and metrics
/// CONSTRAINTS:
///   - SC-FSH-004: All numeric domain values must be typed
///   - SC-FSH-014: Domain units must extend core units coherently
///   - SC-FSH-015: Conversion functions must be bidirectional
///
/// TDG Compliance:
///   - TDG-FSH-004: Arithmetic operations tested for correctness
///   - TDG-FSH-014: Boundary conditions (0, max, negative) tested
///
/// AOR Compliance:
///   - AOR-FSH-003: Raw floats/ints prohibited in domain calculations
module DomainUnits =

    // =========================================================================
    // CORE UNIT IMPORTS
    // =========================================================================

    // Re-export base units for convenience
    open Cepaf.Core.Units

    // =========================================================================
    // EFFICIENCY & PERFORMANCE UNITS (SC-AGT-017)
    // =========================================================================

    /// Agent efficiency percentage (0-100)
    [<Measure>] type efficiency

    /// CPU utilization percentage (0-100+)
    [<Measure>] type cpu_percent

    /// Memory utilization percentage (0-100)
    [<Measure>] type mem_percent

    /// Disk utilization percentage (0-100)
    [<Measure>] type disk_percent

    /// Generic percentage for other uses
    [<Measure>] type pct

    /// Efficiency operations
    module Efficiency =
        /// SC-AGT-017: Minimum required efficiency
        let threshold = 90.0<efficiency>

        /// Convert from raw float
        let fromFloat (f: float) : float<efficiency> =
            if f < 0.0 then 0.0<efficiency>
            elif f > 100.0 then 100.0<efficiency>
            else f * 1.0<efficiency>

        /// Convert to raw float
        let toFloat (e: float<efficiency>) : float = float e

        /// Check if efficiency meets SC-AGT-017 threshold
        let isCompliant (e: float<efficiency>) : bool = e >= threshold

        /// Check if efficiency is warning level (80-90%)
        let isWarning (e: float<efficiency>) : bool =
            e >= 80.0<efficiency> && e < threshold

        /// Check if efficiency is critical (<80%)
        let isCritical (e: float<efficiency>) : bool = e < 80.0<efficiency>

    /// CPU operations
    module CPU =
        /// High CPU threshold
        let highThreshold = 70.0<cpu_percent>

        /// Critical CPU threshold (SC-LOG-002: Auto-throttle >90%)
        let criticalThreshold = 90.0<cpu_percent>

        let fromFloat (f: float) : float<cpu_percent> =
            if f < 0.0 then 0.0<cpu_percent>
            else f * 1.0<cpu_percent>

        let toFloat (c: float<cpu_percent>) : float = float c

        let isNormal (c: float<cpu_percent>) : bool = c < highThreshold
        let isHigh (c: float<cpu_percent>) : bool = c >= highThreshold && c < criticalThreshold
        let isCritical (c: float<cpu_percent>) : bool = c >= criticalThreshold

    /// Memory operations
    module Memory =
        /// High memory threshold
        let highThreshold = 70.0<mem_percent>

        /// Critical memory threshold
        let criticalThreshold = 90.0<mem_percent>

        let fromFloat (f: float) : float<mem_percent> =
            if f < 0.0 then 0.0<mem_percent>
            elif f > 100.0 then 100.0<mem_percent>
            else f * 1.0<mem_percent>

        let toFloat (m: float<mem_percent>) : float = float m

        let isNormal (m: float<mem_percent>) : bool = m < highThreshold
        let isHigh (m: float<mem_percent>) : bool = m >= highThreshold && m < criticalThreshold
        let isCritical (m: float<mem_percent>) : bool = m >= criticalThreshold

    // =========================================================================
    // SAMPLING & RATE UNITS (SC-LOG-*)
    // =========================================================================

    /// Sampling rate (0.0-1.0)
    [<Measure>] type sample_rate

    /// Events per second throughput
    [<Measure>] type events_per_sec

    /// Messages per second
    [<Measure>] type msgs_per_sec

    /// Requests per second
    [<Measure>] type rps

    /// Sampling rate operations
    module SamplingRate =
        /// P0: Never drop (100%)
        let full = 1.0<sample_rate>

        /// P1: 10% sampling
        let tenPercent = 0.10<sample_rate>

        /// P2: 1% sampling
        let onePercent = 0.01<sample_rate>

        /// P3: Disabled (debug only)
        let disabled = 0.0<sample_rate>

        let fromFloat (f: float) : float<sample_rate> =
            if f < 0.0 then 0.0<sample_rate>
            elif f > 1.0 then 1.0<sample_rate>
            else f * 1.0<sample_rate>

        let toFloat (s: float<sample_rate>) : float = float s

        /// Get sampling rate for priority level
        let forPriority (priority: int) : float<sample_rate> =
            match priority with
            | 0 -> full           // P0: Never drop
            | 1 -> tenPercent     // P1: 10%
            | 2 -> onePercent     // P2: 1%
            | _ -> disabled       // P3: Debug only

        /// Check if message should be sampled
        let shouldSample (rate: float<sample_rate>) : bool =
            let rnd = Random().NextDouble()
            rnd < float rate

    /// Throughput operations
    module Throughput =
        let fromFloat (f: float) : float<events_per_sec> = f * 1.0<events_per_sec>
        let toFloat (t: float<events_per_sec>) : float = float t

        /// Convert to messages per second
        let toMsgs (t: float<events_per_sec>) : float<msgs_per_sec> =
            (float t) * 1.0<msgs_per_sec>

    // =========================================================================
    // CONTAINER RESOURCE UNITS
    // =========================================================================

    /// Container CPU in millicores (1000 = 1 core)
    [<Measure>] type millicores

    /// Container memory in MiB
    [<Measure>] type mib

    /// Container memory in GiB
    [<Measure>] type gib

    /// Container CPU operations
    module ContainerCPU =
        /// One full core
        let oneCore = 1000<millicores>

        /// Half core
        let halfCore = 500<millicores>

        /// Quarter core
        let quarterCore = 250<millicores>

        let fromCores (cores: float) : int<millicores> =
            int (cores * 1000.0) * 1<millicores>

        let toCores (mc: int<millicores>) : float =
            float (int mc) / 1000.0

    /// Container memory operations
    module ContainerMemory =
        let fromMiB (m: int) : int<mib> = m * 1<mib>
        let fromGiB (g: float) : int<mib> = int (g * 1024.0) * 1<mib>

        let toMiB (m: int<mib>) : int = int m
        let toGiB (m: int<mib>) : float = float (int m) / 1024.0

        /// Common memory sizes
        let mem256M = 256<mib>
        let mem512M = 512<mib>
        let mem1G = 1024<mib>
        let mem2G = 2048<mib>
        let mem4G = 4096<mib>

    // =========================================================================
    // NETWORK UNITS
    // =========================================================================

    /// Bandwidth in Mbps
    [<Measure>] type mbps

    /// Bandwidth in Gbps
    [<Measure>] type gbps

    /// Packet count
    [<Measure>] type packets

    /// Latency in microseconds (more precise than ms for Zenoh)
    [<Measure>] type us

    /// Network bandwidth operations
    module Bandwidth =
        let fromMbps (m: float) : float<mbps> = m * 1.0<mbps>
        let fromGbps (g: float) : float<mbps> = g * 1000.0<mbps>

        let toMbps (b: float<mbps>) : float = float b
        let toGbps (b: float<mbps>) : float = float b / 1000.0

    /// Microsecond latency operations (for HLC and Zenoh)
    module Microseconds =
        let fromMs (m: float) : int64<us> = int64 (m * 1000.0) * 1L<us>
        let toMs (u: int64<us>) : float = float (int64 u) / 1000.0

        let fromSec (s: float) : int64<us> = int64 (s * 1_000_000.0) * 1L<us>
        let toSec (u: int64<us>) : float = float (int64 u) / 1_000_000.0

        /// Zenoh target latency (<1ms = 1000us)
        let zenohTarget = 1000L<us>

        /// Check if latency meets Zenoh target
        let meetsZenohTarget (lat: int64<us>) : bool = lat <= zenohTarget

    // =========================================================================
    // FRACTAL LOG UNITS
    // =========================================================================

    /// Fractal level (1-5)
    [<Measure>] type flevel

    /// Priority level (0-3)
    [<Measure>] type plevel

    /// Batch size for log batching
    [<Measure>] type batch_size

    /// TTL in seconds for boosts
    [<Measure>] type ttl_sec

    /// Fractal log operations
    module FractalLevel =
        let l1 = 1<flevel>
        let l2 = 2<flevel>
        let l3 = 3<flevel>
        let l4 = 4<flevel>
        let l5 = 5<flevel>

        let fromInt (i: int) : int<flevel> =
            if i < 1 then 1<flevel>
            elif i > 5 then 5<flevel>
            else i * 1<flevel>

        let toInt (l: int<flevel>) : int = int l

        /// Check if level requires HLC (SC-LOG-006: L3+ MUST have HLC)
        let requiresHLC (l: int<flevel>) : bool = int l >= 3

    /// Priority level operations
    module PriorityLevel =
        let p0 = 0<plevel>  // Never drop
        let p1 = 1<plevel>  // 10% sampling
        let p2 = 2<plevel>  // 1% sampling
        let p3 = 3<plevel>  // Debug only

        let fromFractalLevel (fl: int<flevel>) : int<plevel> =
            match int fl with
            | 5 | 4 -> p0
            | 3 -> p1
            | 2 -> p2
            | _ -> p3

    /// Boost TTL operations (SC-LOG-005: Boosts require TTL)
    module BoostTTL =
        /// Default TTL: 5 minutes
        let defaultTtl = 300<ttl_sec>

        /// Short TTL: 1 minute
        let shortTtl = 60<ttl_sec>

        /// Long TTL: 30 minutes
        let longTtl = 1800<ttl_sec>

        /// Maximum TTL: 1 hour
        let maxTtl = 3600<ttl_sec>

        let fromSeconds (s: int) : int<ttl_sec> =
            if s < 0 then 0<ttl_sec>
            elif s > int maxTtl then maxTtl
            else s * 1<ttl_sec>

        let toSeconds (t: int<ttl_sec>) : int = int t
        let toTimeSpan (t: int<ttl_sec>) : TimeSpan = TimeSpan.FromSeconds(float (int t))

    // =========================================================================
    // HLC UNITS (SC-LOG-006)
    // =========================================================================

    /// HLC physical time in microseconds
    [<Measure>] type hlc_physical

    /// HLC counter (0-65535)
    [<Measure>] type hlc_counter

    /// HLC drift in microseconds
    [<Measure>] type drift_us

    /// HLC operations
    module HLCUnits =
        /// Maximum acceptable drift
        let maxDrift = 100_000L<drift_us>  // 100ms

        let physicalNow () : int64<hlc_physical> =
            DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L * 1L<hlc_physical>

        let toMicroseconds (p: int64<hlc_physical>) : int64 = int64 p

        let counterMax = 65535<hlc_counter>

        let incrementCounter (c: int<hlc_counter>) : int<hlc_counter> =
            if int c >= int counterMax then 0<hlc_counter>
            else c + 1<hlc_counter>

    // =========================================================================
    // SAFETY CONSTRAINT UNITS (SC-EMR-*, SC-PRF-*)
    // =========================================================================

    /// Emergency stop timeout in seconds (SC-EMR-057: <5s)
    [<Measure>] type emergency_sec

    /// Response latency threshold in ms (SC-PRF-050: <50ms)
    [<Measure>] type response_ms

    /// Blocking threshold in ms (SC-PRF-055: <50ms)
    [<Measure>] type blocking_ms

    /// Safety threshold operations
    module SafetyThresholds =
        /// SC-EMR-057: Emergency stop must complete in <5s
        let emergencyStopMax = 5<emergency_sec>

        /// SC-PRF-050: Response latency <50ms
        let responseLatencyMax = 50<response_ms>

        /// SC-PRF-055: No blocking >50ms
        let blockingMax = 50<blocking_ms>

        let isEmergencyCompliant (t: int<emergency_sec>) : bool =
            int t <= int emergencyStopMax

        let isResponseCompliant (t: int<response_ms>) : bool =
            int t <= int responseLatencyMax

        let isNonBlocking (t: int<blocking_ms>) : bool =
            int t <= int blockingMax

    // =========================================================================
    // AGENT UNITS (SC-AGT-*)
    // =========================================================================

    /// Agent count
    [<Measure>] type agent_count

    /// Task queue depth
    [<Measure>] type queue_depth

    /// Agent retry count
    [<Measure>] type retry_count

    /// Agent operations
    module AgentUnits =
        /// Total agents in 50-agent model
        let totalAgents = 50<agent_count>

        /// Executive agents (1)
        let executiveCount = 1<agent_count>

        /// Domain supervisor agents (10)
        let domainSupervisorCount = 10<agent_count>

        /// Functional supervisor agents (15)
        let functionalSupervisorCount = 15<agent_count>

        /// Worker agents (24)
        let workerCount = 24<agent_count>

        /// Maximum queue depth before backpressure
        let maxQueueDepth = 100<queue_depth>

        /// Maximum retry attempts
        let maxRetries = 3<retry_count>
