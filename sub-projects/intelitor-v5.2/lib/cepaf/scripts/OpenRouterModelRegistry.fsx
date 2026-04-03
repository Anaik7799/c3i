#!/usr/bin/env dotnet fsi

// =============================================================================
// OPENROUTER MODEL REGISTRY
// Comprehensive AI Model Tracking with Capabilities, Costs, and Auto-Selection
// =============================================================================
// Version: 1.0.0 | STAMP: SC-MODEL-001 to SC-MODEL-020
// Updated: 2026-01-11 | Sources: OpenRouter, Anthropic, Google, xAI
// =============================================================================

#r "nuget: System.Text.Json"
#r "nuget: Microsoft.Data.Sqlite"

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open Microsoft.Data.Sqlite

// =============================================================================
// CORE TYPES - MODEL METADATA
// =============================================================================

/// AI Provider enumeration
type Provider =
    | Anthropic
    | Google
    | XAI
    | OpenAI
    | DeepSeek
    | Meta

/// Model tier classification
type ModelTier =
    | Frontier      // Most capable, highest cost (Opus, GPT-5, etc.)
    | Performance   // High capability, balanced cost (Sonnet, Pro)
    | Efficient     // Good capability, low cost (Flash, Haiku)
    | Economy       // Basic capability, lowest cost (Mini, Lite)

/// Speed classification
type SpeedTier =
    | Realtime      // >400 tok/s - instant responses
    | Fast          // 200-400 tok/s - quick responses
    | Standard      // 100-200 tok/s - normal speed
    | Slow          // <100 tok/s - deliberate, high quality

// =============================================================================
// CAPABILITY SCORES (0.0 - 1.0)
// =============================================================================

/// Detailed capability scores for each model
[<CLIMutable>]
type CapabilityScores = {
    // Core Reasoning
    [<JsonPropertyName("general_reasoning")>]
    GeneralReasoning: float          // General problem solving
    [<JsonPropertyName("mathematical")>]
    Mathematical: float              // Math, AIME, competition math
    [<JsonPropertyName("logical")>]
    Logical: float                   // Logic puzzles, deduction
    [<JsonPropertyName("scientific")>]
    Scientific: float                // GPQA, science benchmarks

    // Coding
    [<JsonPropertyName("code_generation")>]
    CodeGeneration: float            // Writing new code
    [<JsonPropertyName("code_debugging")>]
    CodeDebugging: float             // Finding and fixing bugs
    [<JsonPropertyName("code_review")>]
    CodeReview: float                // Quality analysis
    [<JsonPropertyName("agentic_coding")>]
    AgenticCoding: float             // SWE-Bench, autonomous coding
    [<JsonPropertyName("terminal_cli")>]
    TerminalCLI: float               // Terminal/CLI operations

    // Language & Content
    [<JsonPropertyName("writing")>]
    Writing: float                   // Creative and technical writing
    [<JsonPropertyName("summarization")>]
    Summarization: float             // Condensing information
    [<JsonPropertyName("translation")>]
    Translation: float               // Multi-language
    [<JsonPropertyName("instruction_following")>]
    InstructionFollowing: float      // Following complex instructions

    // Multimodal
    [<JsonPropertyName("image_understanding")>]
    ImageUnderstanding: float        // Analyzing images
    [<JsonPropertyName("image_generation")>]
    ImageGeneration: float           // Creating images
    [<JsonPropertyName("video_understanding")>]
    VideoUnderstanding: float        // Analyzing video
    [<JsonPropertyName("audio_understanding")>]
    AudioUnderstanding: float        // Speech/audio analysis

    // Tool Use & Agents
    [<JsonPropertyName("tool_use")>]
    ToolUse: float                   // Function calling, APIs
    [<JsonPropertyName("agentic_planning")>]
    AgenticPlanning: float           // Multi-step planning
    [<JsonPropertyName("long_context")>]
    LongContext: float               // Utilizing large contexts effectively

    // Safety & Alignment
    [<JsonPropertyName("safety")>]
    Safety: float                    // Refusing harmful requests
    [<JsonPropertyName("factuality")>]
    Factuality: float                // Accuracy, avoiding hallucination
    [<JsonPropertyName("consistency")>]
    Consistency: float               // Consistent outputs
}

// =============================================================================
// PRICING STRUCTURE
// =============================================================================

/// Pricing per million tokens
[<CLIMutable>]
type Pricing = {
    [<JsonPropertyName("input_per_million")>]
    InputPerMillion: float           // $ per 1M input tokens
    [<JsonPropertyName("output_per_million")>]
    OutputPerMillion: float          // $ per 1M output tokens
    [<JsonPropertyName("cached_input_per_million")>]
    CachedInputPerMillion: float option  // Cached/prompt caching discount
    [<JsonPropertyName("batch_discount")>]
    BatchDiscount: float option      // Batch API discount percentage
}

// =============================================================================
// BENCHMARK SCORES
// =============================================================================

/// Industry standard benchmark scores
[<CLIMutable>]
type BenchmarkScores = {
    // Reasoning
    [<JsonPropertyName("gpqa_diamond")>]
    GPQADiamond: float option        // Graduate-level science QA
    [<JsonPropertyName("aime_2025")>]
    AIME2025: float option           // Math olympiad
    [<JsonPropertyName("arc_agi")>]
    ARCAGI: float option             // Abstract reasoning
    [<JsonPropertyName("humanitys_last_exam")>]
    HumanitysLastExam: float option  // Frontier evaluation

    // Coding
    [<JsonPropertyName("swe_bench_verified")>]
    SWEBenchVerified: float option   // Real GitHub issues
    [<JsonPropertyName("terminal_bench")>]
    TerminalBench: float option      // CLI/terminal tasks
    [<JsonPropertyName("human_eval")>]
    HumanEval: float option          // Code completion

    // General
    [<JsonPropertyName("mmlu_pro")>]
    MMLUPro: float option            // Multi-task language understanding
    [<JsonPropertyName("lmarena_elo")>]
    LMArenaElo: int option           // Chatbot Arena ELO
}

// =============================================================================
// COMPLETE MODEL DEFINITION
// =============================================================================

/// Complete model specification
[<CLIMutable>]
type ModelSpec = {
    // Identity
    [<JsonPropertyName("id")>]
    Id: string                       // OpenRouter model ID
    [<JsonPropertyName("name")>]
    Name: string                     // Human readable name
    [<JsonPropertyName("provider")>]
    Provider: string                 // Provider name
    [<JsonPropertyName("version")>]
    Version: string                  // Version string
    [<JsonPropertyName("release_date")>]
    ReleaseDate: string              // ISO date

    // Classification
    [<JsonPropertyName("tier")>]
    Tier: string                     // Frontier/Performance/Efficient/Economy
    [<JsonPropertyName("speed_tier")>]
    SpeedTier: string                // Realtime/Fast/Standard/Slow

    // Technical Specs
    [<JsonPropertyName("context_window")>]
    ContextWindow: int               // Max tokens
    [<JsonPropertyName("max_output")>]
    MaxOutput: int                   // Max output tokens
    [<JsonPropertyName("tokens_per_second")>]
    TokensPerSecond: int             // Approximate speed

    // Pricing
    [<JsonPropertyName("pricing")>]
    Pricing: Pricing

    // Capabilities
    [<JsonPropertyName("capabilities")>]
    Capabilities: CapabilityScores

    // Benchmarks
    [<JsonPropertyName("benchmarks")>]
    Benchmarks: BenchmarkScores

    // Metadata
    [<JsonPropertyName("supports_tools")>]
    SupportsTools: bool
    [<JsonPropertyName("supports_vision")>]
    SupportsVision: bool
    [<JsonPropertyName("supports_audio")>]
    SupportsAudio: bool
    [<JsonPropertyName("supports_video")>]
    SupportsVideo: bool
    [<JsonPropertyName("is_deprecated")>]
    IsDeprecated: bool
    [<JsonPropertyName("deprecation_date")>]
    DeprecationDate: string option
}

// =============================================================================
// TASK TYPES FOR MODEL SELECTION
// =============================================================================

/// Task categories for intelligent model selection
type TaskType =
    // Coding Tasks
    | CodeGeneration
    | CodeReview
    | BugFixing
    | Refactoring
    | TerminalOperation
    | AgenticCoding

    // Reasoning Tasks
    | MathProblem
    | LogicPuzzle
    | ScientificAnalysis
    | StrategicPlanning

    // Content Tasks
    | CreativeWriting
    | TechnicalWriting
    | Summarization
    | Translation

    // Analysis Tasks
    | ImageAnalysis
    | VideoAnalysis
    | DocumentAnalysis
    | DataAnalysis

    // Governance Tasks (Tricameral)
    | ExistentialDecision    // Highest stakes - use Opus
    | ConstitutionalDecision // High stakes - use Opus/Pro
    | ArchitecturalDecision  // Medium stakes - use Sonnet/Pro
    | OperationalDecision    // Standard - use Sonnet/Flash
    | TacticalDecision       // Fast - use Flash/Fast

    // General
    | GeneralChat
    | QuickQuestion

/// Constraints for model selection
type SelectionConstraints = {
    MaxCostPerMillion: float option      // Budget constraint
    MinContextWindow: int option          // Minimum context needed
    RequireVision: bool                   // Must support images
    RequireTools: bool                    // Must support function calling
    RequireSpeed: SpeedTier option        // Minimum speed tier
    PreferredProviders: Provider list     // Limit to specific providers
    ExcludeDeprecated: bool               // Skip deprecated models
}

// =============================================================================
// MODEL REGISTRY - LATEST MODELS (January 2026)
// =============================================================================

/// Default capability scores for a model
let defaultCapabilities () = {
    GeneralReasoning = 0.5
    Mathematical = 0.5
    Logical = 0.5
    Scientific = 0.5
    CodeGeneration = 0.5
    CodeDebugging = 0.5
    CodeReview = 0.5
    AgenticCoding = 0.5
    TerminalCLI = 0.5
    Writing = 0.5
    Summarization = 0.5
    Translation = 0.5
    InstructionFollowing = 0.5
    ImageUnderstanding = 0.0
    ImageGeneration = 0.0
    VideoUnderstanding = 0.0
    AudioUnderstanding = 0.0
    ToolUse = 0.5
    AgenticPlanning = 0.5
    LongContext = 0.5
    Safety = 0.7
    Factuality = 0.7
    Consistency = 0.7
}

/// Default benchmarks (empty)
let defaultBenchmarks () = {
    GPQADiamond = None
    AIME2025 = None
    ARCAGI = None
    HumanitysLastExam = None
    SWEBenchVerified = None
    TerminalBench = None
    HumanEval = None
    MMLUPro = None
    LMArenaElo = None
}

// -----------------------------------------------------------------------------
// ANTHROPIC CLAUDE MODELS
// -----------------------------------------------------------------------------

let claudeOpus45 = {
    Id = "anthropic/claude-3-opus"
    Name = "Claude 3 Opus"
    Provider = "Anthropic"
    Version = "3.0"
    ReleaseDate = "2024-02-29"
    Tier = "Frontier"
    SpeedTier = "Slow"
    ContextWindow = 200000
    MaxOutput = 32000
    TokensPerSecond = 70
    Pricing = {
        InputPerMillion = 15.0
        OutputPerMillion = 75.0
        CachedInputPerMillion = Some 3.75
        BatchDiscount = Some 0.5
    }
    Capabilities = {
        GeneralReasoning = 0.98
        Mathematical = 0.93
        Logical = 0.96
        Scientific = 0.92
        CodeGeneration = 0.97
        CodeDebugging = 0.96
        CodeReview = 0.97
        AgenticCoding = 0.97  // 77.2% SWE-Bench leader
        TerminalCLI = 0.95    // 60%+ Terminal-Bench
        Writing = 0.98
        Summarization = 0.95
        Translation = 0.90
        InstructionFollowing = 0.98
        ImageUnderstanding = 0.92
        ImageGeneration = 0.0
        VideoUnderstanding = 0.30
        AudioUnderstanding = 0.0
        ToolUse = 0.97
        AgenticPlanning = 0.96
        LongContext = 0.90
        Safety = 0.98
        Factuality = 0.95
        Consistency = 0.96
    }
    Benchmarks = {
        GPQADiamond = Some 0.89
        AIME2025 = Some 0.928
        ARCAGI = Some 0.72
        HumanitysLastExam = Some 0.35
        SWEBenchVerified = Some 0.772
        TerminalBench = Some 0.614
        HumanEval = Some 0.95
        MMLUPro = Some 0.91
        LMArenaElo = Some 1485
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

let claudeSonnet45 = {
    Id = "anthropic/claude-3.5-sonnet"
    Name = "Claude 3.5 Sonnet"
    Provider = "Anthropic"
    Version = "3.5"
    ReleaseDate = "2024-10-22"
    Tier = "Performance"
    SpeedTier = "Standard"
    ContextWindow = 1000000
    MaxOutput = 64000
    TokensPerSecond = 150
    Pricing = {
        InputPerMillion = 3.0
        OutputPerMillion = 15.0
        CachedInputPerMillion = Some 0.75
        BatchDiscount = Some 0.5
    }
    Capabilities = {
        GeneralReasoning = 0.94
        Mathematical = 0.88
        Logical = 0.92
        Scientific = 0.88
        CodeGeneration = 0.94
        CodeDebugging = 0.93
        CodeReview = 0.94
        AgenticCoding = 0.92
        TerminalCLI = 0.90
        Writing = 0.95
        Summarization = 0.93
        Translation = 0.88
        InstructionFollowing = 0.95
        ImageUnderstanding = 0.90
        ImageGeneration = 0.0
        VideoUnderstanding = 0.25
        AudioUnderstanding = 0.0
        ToolUse = 0.95
        AgenticPlanning = 0.92
        LongContext = 0.95  // 1M context
        Safety = 0.97
        Factuality = 0.93
        Consistency = 0.94
    }
    Benchmarks = {
        GPQADiamond = Some 0.85
        AIME2025 = Some 0.88
        ARCAGI = Some 0.65
        HumanitysLastExam = Some 0.28
        SWEBenchVerified = Some 0.72
        TerminalBench = Some 0.55
        HumanEval = Some 0.93
        MMLUPro = Some 0.88
        LMArenaElo = Some 1420
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

let claudeHaiku45 = {
    Id = "anthropic/claude-3.5-haiku"
    Name = "Claude 3.5 Haiku"
    Provider = "Anthropic"
    Version = "3.5"
    ReleaseDate = "2024-10-22"
    Tier = "Efficient"
    SpeedTier = "Fast"
    ContextWindow = 200000
    MaxOutput = 8192
    TokensPerSecond = 300
    Pricing = {
        InputPerMillion = 0.80
        OutputPerMillion = 4.0
        CachedInputPerMillion = Some 0.20
        BatchDiscount = Some 0.5
    }
    Capabilities = {
        GeneralReasoning = 0.82
        Mathematical = 0.75
        Logical = 0.80
        Scientific = 0.75
        CodeGeneration = 0.85
        CodeDebugging = 0.82
        CodeReview = 0.83
        AgenticCoding = 0.75
        TerminalCLI = 0.78
        Writing = 0.85
        Summarization = 0.88
        Translation = 0.82
        InstructionFollowing = 0.88
        ImageUnderstanding = 0.80
        ImageGeneration = 0.0
        VideoUnderstanding = 0.0
        AudioUnderstanding = 0.0
        ToolUse = 0.88
        AgenticPlanning = 0.75
        LongContext = 0.85
        Safety = 0.95
        Factuality = 0.88
        Consistency = 0.90
    }
    Benchmarks = {
        GPQADiamond = Some 0.70
        AIME2025 = Some 0.65
        ARCAGI = Some 0.45
        HumanitysLastExam = None
        SWEBenchVerified = Some 0.55
        TerminalBench = Some 0.40
        HumanEval = Some 0.88
        MMLUPro = Some 0.80
        LMArenaElo = Some 1280
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

// -----------------------------------------------------------------------------
// GOOGLE GEMINI MODELS
// -----------------------------------------------------------------------------

let gemini3Pro = {
    Id = "google/gemini-2.0-flash-thinking-exp:free"
    Name = "Gemini 2.0 Flash Thinking"
    Provider = "Google"
    Version = "2.0"
    ReleaseDate = "2024-12-19"
    Tier = "Frontier"
    SpeedTier = "Standard"
    ContextWindow = 1000000
    MaxOutput = 65536
    TokensPerSecond = 180
    Pricing = {
        InputPerMillion = 1.0
        OutputPerMillion = 4.0
        CachedInputPerMillion = Some 0.25
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.97
        Mathematical = 0.95  // 95% AIME
        Logical = 0.95
        Scientific = 0.95   // 91.9% GPQA Diamond - leader
        CodeGeneration = 0.90
        CodeDebugging = 0.88
        CodeReview = 0.88
        AgenticCoding = 0.85
        TerminalCLI = 0.82
        Writing = 0.92
        Summarization = 0.94
        Translation = 0.95
        InstructionFollowing = 0.94
        ImageUnderstanding = 0.96
        ImageGeneration = 0.0
        VideoUnderstanding = 0.92  // Best video understanding
        AudioUnderstanding = 0.88
        ToolUse = 0.92
        AgenticPlanning = 0.90
        LongContext = 0.96  // 1M context, well optimized
        Safety = 0.94
        Factuality = 0.93
        Consistency = 0.92
    }
    Benchmarks = {
        GPQADiamond = Some 0.919  // Leader
        AIME2025 = Some 0.95     // Leader
        ARCAGI = Some 0.78
        HumanitysLastExam = Some 0.41  // Leader
        SWEBenchVerified = Some 0.68
        TerminalBench = Some 0.48
        HumanEval = Some 0.92
        MMLUPro = Some 0.90
        LMArenaElo = Some 1501    // First to break 1500
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = true
    SupportsVideo = true
    IsDeprecated = false
    DeprecationDate = None
}

let gemini3Flash = {
    Id = "google/gemini-2.0-flash-exp:free"
    Name = "Gemini 2.0 Flash"
    Provider = "Google"
    Version = "2.0"
    ReleaseDate = "2024-12-11"
    Tier = "Efficient"
    SpeedTier = "Realtime"
    ContextWindow = 1000000
    MaxOutput = 32768
    TokensPerSecond = 400
    Pricing = {
        InputPerMillion = 0.50
        OutputPerMillion = 1.50
        CachedInputPerMillion = Some 0.125
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.88
        Mathematical = 0.90  // 90.4% AIME - impressive for Flash
        Logical = 0.88
        Scientific = 0.85
        CodeGeneration = 0.85
        CodeDebugging = 0.82
        CodeReview = 0.82
        AgenticCoding = 0.78
        TerminalCLI = 0.75
        Writing = 0.88
        Summarization = 0.92
        Translation = 0.92
        InstructionFollowing = 0.90
        ImageUnderstanding = 0.92
        ImageGeneration = 0.0
        VideoUnderstanding = 0.88
        AudioUnderstanding = 0.85
        ToolUse = 0.88
        AgenticPlanning = 0.82
        LongContext = 0.94
        Safety = 0.92
        Factuality = 0.88
        Consistency = 0.90
    }
    Benchmarks = {
        GPQADiamond = Some 0.82
        AIME2025 = Some 0.904
        ARCAGI = Some 0.58
        HumanitysLastExam = Some 0.28
        SWEBenchVerified = Some 0.58
        TerminalBench = Some 0.38
        HumanEval = Some 0.88
        MMLUPro = Some 0.85
        LMArenaElo = Some 1380
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = true
    SupportsVideo = true
    IsDeprecated = false
    DeprecationDate = None
}

let gemini25Pro = {
    Id = "google/gemini-pro-1.5"
    Name = "Gemini 1.5 Pro"
    Provider = "Google"
    Version = "1.5"
    ReleaseDate = "2024-05-14"
    Tier = "Performance"
    SpeedTier = "Standard"
    ContextWindow = 1000000
    MaxOutput = 32768
    TokensPerSecond = 150
    Pricing = {
        InputPerMillion = 2.50
        OutputPerMillion = 10.0
        CachedInputPerMillion = Some 0.625
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.92
        Mathematical = 0.88
        Logical = 0.90
        Scientific = 0.90
        CodeGeneration = 0.88
        CodeDebugging = 0.85
        CodeReview = 0.85
        AgenticCoding = 0.82
        TerminalCLI = 0.78
        Writing = 0.90
        Summarization = 0.92
        Translation = 0.93
        InstructionFollowing = 0.92
        ImageUnderstanding = 0.94
        ImageGeneration = 0.0
        VideoUnderstanding = 0.90
        AudioUnderstanding = 0.85
        ToolUse = 0.90
        AgenticPlanning = 0.85
        LongContext = 0.95
        Safety = 0.93
        Factuality = 0.90
        Consistency = 0.91
    }
    Benchmarks = {
        GPQADiamond = Some 0.85
        AIME2025 = Some 0.82
        ARCAGI = Some 0.55
        HumanitysLastExam = Some 0.25
        SWEBenchVerified = Some 0.62
        TerminalBench = Some 0.42
        HumanEval = Some 0.90
        MMLUPro = Some 0.87
        LMArenaElo = Some 1350
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = true
    SupportsVideo = true
    IsDeprecated = false
    DeprecationDate = None
}

let gemini25Flash = {
    Id = "google/gemini-flash-1.5"
    Name = "Gemini 1.5 Flash"
    Provider = "Google"
    Version = "1.5"
    ReleaseDate = "2024-05-14"
    Tier = "Efficient"
    SpeedTier = "Fast"
    ContextWindow = 1000000
    MaxOutput = 16384
    TokensPerSecond = 350
    Pricing = {
        InputPerMillion = 0.30
        OutputPerMillion = 1.0
        CachedInputPerMillion = Some 0.075
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.82
        Mathematical = 0.78
        Logical = 0.80
        Scientific = 0.78
        CodeGeneration = 0.80
        CodeDebugging = 0.78
        CodeReview = 0.78
        AgenticCoding = 0.72
        TerminalCLI = 0.70
        Writing = 0.85
        Summarization = 0.90
        Translation = 0.90
        InstructionFollowing = 0.88
        ImageUnderstanding = 0.88
        ImageGeneration = 0.0
        VideoUnderstanding = 0.82
        AudioUnderstanding = 0.80
        ToolUse = 0.85
        AgenticPlanning = 0.75
        LongContext = 0.92
        Safety = 0.90
        Factuality = 0.85
        Consistency = 0.88
    }
    Benchmarks = {
        GPQADiamond = Some 0.72
        AIME2025 = Some 0.70
        ARCAGI = Some 0.42
        HumanitysLastExam = None
        SWEBenchVerified = Some 0.50
        TerminalBench = Some 0.32
        HumanEval = Some 0.85
        MMLUPro = Some 0.80
        LMArenaElo = Some 1280
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = true
    SupportsVideo = true
    IsDeprecated = false
    DeprecationDate = None
}

// -----------------------------------------------------------------------------
// XAI GROK MODELS
// -----------------------------------------------------------------------------

let grok41Fast = {
    Id = "x-ai/grok-2-1212"
    Name = "Grok 2"
    Provider = "xAI"
    Version = "2.0"
    ReleaseDate = "2024-12-12"
    Tier = "Performance"
    SpeedTier = "Realtime"
    ContextWindow = 2000000  // 2M - largest context
    MaxOutput = 131072
    TokensPerSecond = 455    // Fastest
    Pricing = {
        InputPerMillion = 1.0
        OutputPerMillion = 1.0  // Cheapest output
        CachedInputPerMillion = None
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.92
        Mathematical = 0.94    // 94% AIME
        Logical = 0.90
        Scientific = 0.88
        CodeGeneration = 0.92
        CodeDebugging = 0.90
        CodeReview = 0.88
        AgenticCoding = 0.88
        TerminalCLI = 0.85
        Writing = 0.88
        Summarization = 0.90
        Translation = 0.85
        InstructionFollowing = 0.90
        ImageUnderstanding = 0.85
        ImageGeneration = 0.0
        VideoUnderstanding = 0.0
        AudioUnderstanding = 0.0
        ToolUse = 0.90
        AgenticPlanning = 0.88
        LongContext = 0.98  // 2M context leader
        Safety = 0.85
        Factuality = 0.88
        Consistency = 0.88
    }
    Benchmarks = {
        GPQADiamond = Some 0.85
        AIME2025 = Some 0.94
        ARCAGI = Some 0.62
        HumanitysLastExam = Some 0.30
        SWEBenchVerified = Some 0.65
        TerminalBench = Some 0.45
        HumanEval = Some 0.90
        MMLUPro = Some 0.86
        LMArenaElo = Some 1400
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

let grok4 = {
    Id = "x-ai/grok-beta"
    Name = "Grok Beta"
    Provider = "xAI"
    Version = "1.0"
    ReleaseDate = "2024-08-01"
    Tier = "Performance"
    SpeedTier = "Fast"
    ContextWindow = 256000
    MaxOutput = 65536
    TokensPerSecond = 280
    Pricing = {
        InputPerMillion = 2.0
        OutputPerMillion = 6.0
        CachedInputPerMillion = None
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.90
        Mathematical = 0.88
        Logical = 0.88
        Scientific = 0.85
        CodeGeneration = 0.90
        CodeDebugging = 0.88
        CodeReview = 0.86
        AgenticCoding = 0.85
        TerminalCLI = 0.82
        Writing = 0.86
        Summarization = 0.88
        Translation = 0.82
        InstructionFollowing = 0.88
        ImageUnderstanding = 0.82
        ImageGeneration = 0.0
        VideoUnderstanding = 0.0
        AudioUnderstanding = 0.0
        ToolUse = 0.88
        AgenticPlanning = 0.85
        LongContext = 0.88
        Safety = 0.82
        Factuality = 0.86
        Consistency = 0.86
    }
    Benchmarks = {
        GPQADiamond = Some 0.80
        AIME2025 = Some 0.85
        ARCAGI = Some 0.55
        HumanitysLastExam = Some 0.25
        SWEBenchVerified = Some 0.60
        TerminalBench = Some 0.40
        HumanEval = Some 0.88
        MMLUPro = Some 0.83
        LMArenaElo = Some 1350
    }
    SupportsTools = true
    SupportsVision = true
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

let grokCodeFast = {
    Id = "x-ai/grok-2-vision-1212"
    Name = "Grok 2 Vision"
    Provider = "xAI"
    Version = "2.0"
    ReleaseDate = "2024-12-12"
    Tier = "Efficient"
    SpeedTier = "Realtime"
    ContextWindow = 256000
    MaxOutput = 32768
    TokensPerSecond = 500  // Fastest for code
    Pricing = {
        InputPerMillion = 0.50
        OutputPerMillion = 1.50
        CachedInputPerMillion = None
        BatchDiscount = None
    }
    Capabilities = {
        GeneralReasoning = 0.78
        Mathematical = 0.80
        Logical = 0.82
        Scientific = 0.75
        CodeGeneration = 0.92  // Optimized for code
        CodeDebugging = 0.90
        CodeReview = 0.88
        AgenticCoding = 0.85
        TerminalCLI = 0.88
        Writing = 0.72
        Summarization = 0.78
        Translation = 0.70
        InstructionFollowing = 0.85
        ImageUnderstanding = 0.0
        ImageGeneration = 0.0
        VideoUnderstanding = 0.0
        AudioUnderstanding = 0.0
        ToolUse = 0.88
        AgenticPlanning = 0.80
        LongContext = 0.85
        Safety = 0.80
        Factuality = 0.82
        Consistency = 0.85
    }
    Benchmarks = {
        GPQADiamond = Some 0.65
        AIME2025 = Some 0.70
        ARCAGI = Some 0.40
        HumanitysLastExam = None
        SWEBenchVerified = Some 0.58
        TerminalBench = Some 0.52
        HumanEval = Some 0.92
        MMLUPro = Some 0.75
        LMArenaElo = Some 1250
    }
    SupportsTools = true
    SupportsVision = false
    SupportsAudio = false
    SupportsVideo = false
    IsDeprecated = false
    DeprecationDate = None
}

// =============================================================================
// MODEL REGISTRY
// =============================================================================

/// Complete registry of all available models
let allModels = [
    // Anthropic
    claudeOpus45
    claudeSonnet45
    claudeHaiku45
    // Google
    gemini3Pro
    gemini3Flash
    gemini25Pro
    gemini25Flash
    // xAI
    grok41Fast
    grok4
    grokCodeFast
]

/// Get models by provider
let getModelsByProvider (provider: string) =
    allModels |> List.filter (fun m -> m.Provider.ToLower() = provider.ToLower())

/// Get models by tier
let getModelsByTier (tier: string) =
    allModels |> List.filter (fun m -> m.Tier.ToLower() = tier.ToLower())

/// Get model by ID
let getModelById (id: string) =
    allModels |> List.tryFind (fun m -> m.Id = id)

// =============================================================================
// TASK-BASED MODEL SELECTION
// =============================================================================

/// Get the best capability score for a task
let getTaskCapabilityScore (task: TaskType) (caps: CapabilityScores) =
    match task with
    | CodeGeneration -> caps.CodeGeneration
    | CodeReview -> caps.CodeReview
    | BugFixing -> caps.CodeDebugging
    | Refactoring -> (caps.CodeGeneration + caps.CodeReview) / 2.0
    | TerminalOperation -> caps.TerminalCLI
    | AgenticCoding -> caps.AgenticCoding
    | MathProblem -> caps.Mathematical
    | LogicPuzzle -> caps.Logical
    | ScientificAnalysis -> caps.Scientific
    | StrategicPlanning -> caps.AgenticPlanning
    | CreativeWriting -> caps.Writing
    | TechnicalWriting -> (caps.Writing + caps.InstructionFollowing) / 2.0
    | Summarization -> caps.Summarization
    | Translation -> caps.Translation
    | ImageAnalysis -> caps.ImageUnderstanding
    | VideoAnalysis -> caps.VideoUnderstanding
    | DocumentAnalysis -> (caps.LongContext + caps.Summarization) / 2.0
    | DataAnalysis -> (caps.Mathematical + caps.Logical) / 2.0
    | ExistentialDecision -> (caps.GeneralReasoning + caps.Safety + caps.Factuality) / 3.0
    | ConstitutionalDecision -> (caps.GeneralReasoning + caps.Safety) / 2.0
    | ArchitecturalDecision -> (caps.AgenticPlanning + caps.Logical) / 2.0
    | OperationalDecision -> (caps.InstructionFollowing + caps.GeneralReasoning) / 2.0
    | TacticalDecision -> caps.InstructionFollowing
    | GeneralChat -> caps.GeneralReasoning
    | QuickQuestion -> caps.InstructionFollowing

/// Select the best model for a task with constraints
let selectBestModel (task: TaskType) (constraints: SelectionConstraints) : ModelSpec option =
    let candidates =
        allModels
        |> List.filter (fun m ->
            // Apply constraints
            let costOk =
                match constraints.MaxCostPerMillion with
                | Some max -> m.Pricing.OutputPerMillion <= max
                | None -> true
            let contextOk =
                match constraints.MinContextWindow with
                | Some min -> m.ContextWindow >= min
                | None -> true
            let visionOk = not constraints.RequireVision || m.SupportsVision
            let toolsOk = not constraints.RequireTools || m.SupportsTools
            let speedOk =
                match constraints.RequireSpeed with
                | Some Realtime -> m.SpeedTier = "Realtime"
                | Some Fast -> m.SpeedTier = "Realtime" || m.SpeedTier = "Fast"
                | Some Standard -> m.SpeedTier <> "Slow"
                | Some Slow -> true
                | None -> true
            let providerOk =
                match constraints.PreferredProviders with
                | [] -> true
                | providers ->
                    providers |> List.exists (fun p ->
                        m.Provider.ToLower() = (sprintf "%A" p).ToLower())
            let deprecatedOk = not constraints.ExcludeDeprecated || not m.IsDeprecated

            costOk && contextOk && visionOk && toolsOk && speedOk && providerOk && deprecatedOk
        )

    candidates
    |> List.map (fun m -> (m, getTaskCapabilityScore task m.Capabilities))
    |> List.sortByDescending snd
    |> List.tryHead
    |> Option.map fst

/// Default constraints (no limits)
let defaultConstraints = {
    MaxCostPerMillion = None
    MinContextWindow = None
    RequireVision = false
    RequireTools = false
    RequireSpeed = None
    PreferredProviders = []
    ExcludeDeprecated = true
}

/// Budget-conscious constraints
let budgetConstraints = {
    MaxCostPerMillion = Some 5.0
    MinContextWindow = None
    RequireVision = false
    RequireTools = false
    RequireSpeed = None
    PreferredProviders = []
    ExcludeDeprecated = true
}

/// Speed-focused constraints
let speedConstraints = {
    MaxCostPerMillion = None
    MinContextWindow = None
    RequireVision = false
    RequireTools = false
    RequireSpeed = Some Fast
    PreferredProviders = []
    ExcludeDeprecated = true
}

// =============================================================================
// TRICAMERAL CHAMBER SELECTION
// =============================================================================

/// Chamber role definitions for tricameral governance
type ChamberRole =
    | Constitutional  // Ethics, safety, alignment - Claude preferred
    | Technical       // Architecture, systems - Gemini preferred
    | Pragmatic       // Execution, speed - Grok preferred

/// Get recommended model for each chamber role
let getModelForChamberRole (role: ChamberRole) (tier: string) =
    match role, tier with
    // Constitutional chamber - Claude is best for ethics/safety
    | Constitutional, "Frontier" -> claudeOpus45
    | Constitutional, "Performance" -> claudeSonnet45
    | Constitutional, _ -> claudeHaiku45

    // Technical chamber - Gemini best for systems/multimodal
    | Technical, "Frontier" -> gemini3Pro
    | Technical, "Performance" -> gemini25Pro
    | Technical, _ -> gemini3Flash

    // Pragmatic chamber - Grok best for speed/execution
    | Pragmatic, "Frontier" -> grok4
    | Pragmatic, "Performance" -> grok41Fast
    | Pragmatic, _ -> grokCodeFast

/// Get tricameral configuration for a decision category
let getTricameralConfig (category: string) =
    let tier =
        match category.ToLower() with
        | "existential" | "constitutional" -> "Frontier"
        | "architectural" | "operational" -> "Performance"
        | _ -> "Efficient"

    {|
        Claude = getModelForChamberRole Constitutional tier
        Gemini = getModelForChamberRole Technical tier
        Grok = getModelForChamberRole Pragmatic tier
        Tier = tier
    |}

// =============================================================================
// COST ESTIMATION
// =============================================================================

/// Estimate cost for a request
let estimateCost (model: ModelSpec) (inputTokens: int) (outputTokens: int) =
    let inputCost = float inputTokens * model.Pricing.InputPerMillion / 1_000_000.0
    let outputCost = float outputTokens * model.Pricing.OutputPerMillion / 1_000_000.0
    inputCost + outputCost

/// Compare costs across models for same task
let compareCosts (inputTokens: int) (outputTokens: int) =
    allModels
    |> List.map (fun m ->
        let cost = estimateCost m inputTokens outputTokens
        (m.Name, cost, m.Tier))
    |> List.sortBy (fun (_, cost, _) -> cost)

// =============================================================================
// DATABASE PERSISTENCE
// =============================================================================

let projectRoot =
    let current = Directory.GetCurrentDirectory()
    if current.Contains("lib/cepaf") then
        Path.GetFullPath(Path.Combine(current, "../.."))
    else current

let dataPath = Path.Combine(projectRoot, "data", "models")
let dbPath = Path.Combine(dataPath, "model_registry.db")
let jsonPath = Path.Combine(dataPath, "models.json")

/// Initialize database
let ensureDatabase () =
    Directory.CreateDirectory(dataPath) |> ignore

    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        CREATE TABLE IF NOT EXISTS models (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            provider TEXT NOT NULL,
            version TEXT NOT NULL,
            tier TEXT NOT NULL,
            context_window INTEGER,
            input_price REAL,
            output_price REAL,
            spec_json TEXT,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS usage_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_id TEXT,
            task_type TEXT,
            input_tokens INTEGER,
            output_tokens INTEGER,
            cost REAL,
            latency_ms INTEGER,
            success INTEGER,
            timestamp TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_usage_model ON usage_stats(model_id);
        CREATE INDEX IF NOT EXISTS idx_usage_task ON usage_stats(task_type);
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.ExecuteNonQuery() |> ignore
    printfn "[MODEL] Database initialized at %s" dbPath

/// Save all models to JSON
let saveModelsToJson () =
    Directory.CreateDirectory(dataPath) |> ignore
    let options = JsonSerializerOptions(WriteIndented = true)
    let json = JsonSerializer.Serialize(allModels, options)
    File.WriteAllText(jsonPath, json)
    printfn "[MODEL] Saved %d models to %s" (List.length allModels) jsonPath

/// Record usage statistics
let recordUsage (modelId: string) (task: string) (inputTokens: int) (outputTokens: int) (cost: float) (latencyMs: int) (success: bool) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        INSERT INTO usage_stats (model_id, task_type, input_tokens, output_tokens, cost, latency_ms, success, timestamp)
        VALUES (@model, @task, @input, @output, @cost, @latency, @success, @ts)
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@model", modelId) |> ignore
    cmd.Parameters.AddWithValue("@task", task) |> ignore
    cmd.Parameters.AddWithValue("@input", inputTokens) |> ignore
    cmd.Parameters.AddWithValue("@output", outputTokens) |> ignore
    cmd.Parameters.AddWithValue("@cost", cost) |> ignore
    cmd.Parameters.AddWithValue("@latency", latencyMs) |> ignore
    cmd.Parameters.AddWithValue("@success", if success then 1 else 0) |> ignore
    cmd.Parameters.AddWithValue("@ts", DateTime.UtcNow.ToString("o")) |> ignore

    cmd.ExecuteNonQuery() |> ignore

// =============================================================================
// CLI INTERFACE
// =============================================================================

let showModels () =
    printfn ""
    printfn "╔════════════════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  OPENROUTER MODEL REGISTRY                                              [Jan 2026]    ║"
    printfn "╠════════════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  %-25s │ %-12s │ %8s │ %8s │ %6s │ %-10s ║" "MODEL" "PROVIDER" "CONTEXT" "$/M OUT" "TOK/S" "TIER"
    printfn "╠════════════════════════════════════════════════════════════════════════════════════════╣"

    for m in allModels do
        let ctx = if m.ContextWindow >= 1000000 then sprintf "%dM" (m.ContextWindow / 1000000) else sprintf "%dK" (m.ContextWindow / 1000)
        printfn "║  %-25s │ %-12s │ %8s │ %8.2f │ %6d │ %-10s ║"
            m.Name m.Provider ctx m.Pricing.OutputPerMillion m.TokensPerSecond m.Tier

    printfn "╚════════════════════════════════════════════════════════════════════════════════════════╝"

let showCapabilities (modelId: string) =
    match getModelById modelId with
    | Some m ->
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════════╗"
        printfn "║  %s CAPABILITIES" (m.Name.ToUpper())
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  REASONING                                                           ║"
        printfn "║    General: %.0f%%  Math: %.0f%%  Logic: %.0f%%  Science: %.0f%%           ║"
            (m.Capabilities.GeneralReasoning * 100.0)
            (m.Capabilities.Mathematical * 100.0)
            (m.Capabilities.Logical * 100.0)
            (m.Capabilities.Scientific * 100.0)
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  CODING                                                              ║"
        printfn "║    Generation: %.0f%%  Debug: %.0f%%  Review: %.0f%%  Agentic: %.0f%%       ║"
            (m.Capabilities.CodeGeneration * 100.0)
            (m.Capabilities.CodeDebugging * 100.0)
            (m.Capabilities.CodeReview * 100.0)
            (m.Capabilities.AgenticCoding * 100.0)
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  MULTIMODAL                                                          ║"
        printfn "║    Image: %.0f%%  Video: %.0f%%  Audio: %.0f%%                            ║"
            (m.Capabilities.ImageUnderstanding * 100.0)
            (m.Capabilities.VideoUnderstanding * 100.0)
            (m.Capabilities.AudioUnderstanding * 100.0)
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  TOOL USE & AGENTS                                                   ║"
        printfn "║    Tools: %.0f%%  Planning: %.0f%%  Long Context: %.0f%%                  ║"
            (m.Capabilities.ToolUse * 100.0)
            (m.Capabilities.AgenticPlanning * 100.0)
            (m.Capabilities.LongContext * 100.0)
        printfn "╚══════════════════════════════════════════════════════════════════════╝"
    | None ->
        printfn "[MODEL] Model not found: %s" modelId

let showTricameral (category: string) =
    let config = getTricameralConfig category
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL CONFIGURATION: %s" (category.ToUpper())
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  Tier: %s" config.Tier
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  CLAUDE (Constitutional): %-42s ║" config.Claude.Id
    printfn "║    Ethics/Safety: %.0f%%  Reasoning: %.0f%%  Cost: $%.2f/M             ║"
        (config.Claude.Capabilities.Safety * 100.0)
        (config.Claude.Capabilities.GeneralReasoning * 100.0)
        config.Claude.Pricing.OutputPerMillion
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  GEMINI (Technical): %-46s ║" config.Gemini.Id
    printfn "║    Science: %.0f%%  Multimodal: %.0f%%  Cost: $%.2f/M                  ║"
        (config.Gemini.Capabilities.Scientific * 100.0)
        (config.Gemini.Capabilities.ImageUnderstanding * 100.0)
        config.Gemini.Pricing.OutputPerMillion
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  GROK (Pragmatic): %-48s ║" config.Grok.Id
    printfn "║    Speed: %d tok/s  Context: %dM  Cost: $%.2f/M                    ║"
        config.Grok.TokensPerSecond
        (config.Grok.ContextWindow / 1000000)
        config.Grok.Pricing.OutputPerMillion
    printfn "╚══════════════════════════════════════════════════════════════════════╝"

let showHelp () =
    printfn """
╔══════════════════════════════════════════════════════════════════════════╗
║  OPENROUTER MODEL REGISTRY                                               ║
║  Comprehensive AI Model Tracking with Intelligent Selection              ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  COMMANDS:                                                               ║
║    list                    Show all registered models                    ║
║    show <model-id>         Show model capabilities                       ║
║    tricameral <category>   Show tricameral config for category           ║
║    compare <task>          Compare models for a task type                ║
║    costs <input> <output>  Compare costs for token counts                ║
║    export                  Export models to JSON                         ║
║    help                    Show this help                                ║
║                                                                          ║
║  TASK TYPES:                                                             ║
║    code, debug, review, math, logic, science, writing, summary,          ║
║    image, video, existential, constitutional, architectural,             ║
║    operational, tactical                                                 ║
║                                                                          ║
║  TRICAMERAL CATEGORIES:                                                  ║
║    existential, constitutional, architectural, operational, tactical     ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

let parseTaskType (s: string) =
    match s.ToLower() with
    | "code" -> Some CodeGeneration
    | "debug" -> Some BugFixing
    | "review" -> Some CodeReview
    | "terminal" -> Some TerminalOperation
    | "agentic" -> Some AgenticCoding
    | "math" -> Some MathProblem
    | "logic" -> Some LogicPuzzle
    | "science" -> Some ScientificAnalysis
    | "planning" -> Some StrategicPlanning
    | "writing" -> Some CreativeWriting
    | "technical" -> Some TechnicalWriting
    | "summary" -> Some Summarization
    | "translate" -> Some Translation
    | "image" -> Some ImageAnalysis
    | "video" -> Some VideoAnalysis
    | "data" -> Some DataAnalysis
    | "existential" -> Some ExistentialDecision
    | "constitutional" -> Some ConstitutionalDecision
    | "architectural" -> Some ArchitecturalDecision
    | "operational" -> Some OperationalDecision
    | "tactical" -> Some TacticalDecision
    | "chat" -> Some GeneralChat
    | _ -> None

let showComparison (taskStr: string) =
    match parseTaskType taskStr with
    | Some task ->
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════════╗"
        printfn "║  MODEL COMPARISON FOR: %s" (taskStr.ToUpper())
        printfn "╠══════════════════════════════════════════════════════════════════════╣"

        let ranked =
            allModels
            |> List.map (fun m -> (m, getTaskCapabilityScore task m.Capabilities))
            |> List.sortByDescending snd

        for (m, score) in ranked do
            let bar = String.replicate (int (score * 40.0)) "█"
            printfn "║  %-20s │ %s %.0f%%" m.Name bar (score * 100.0)

        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  RECOMMENDED: %-54s ║" (fst ranked.[0]).Name
        printfn "╚══════════════════════════════════════════════════════════════════════╝"
    | None ->
        printfn "[MODEL] Unknown task type: %s" taskStr

let showCosts (inputTokens: int) (outputTokens: int) =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════╗"
    printfn "║  COST COMPARISON: %dK input, %dK output tokens" (inputTokens/1000) (outputTokens/1000)
    printfn "╠══════════════════════════════════════════════════════════════════════╣"

    let costs = compareCosts inputTokens outputTokens

    for (name, cost, tier) in costs do
        printfn "║  %-20s │ $%-8.4f │ %-12s ║" name cost tier

    printfn "╚══════════════════════════════════════════════════════════════════════╝"

// =============================================================================
// MAIN
// =============================================================================

let main (args: string[]) =
    ensureDatabase()

    if args.Length = 0 then
        showHelp()
    else
        match args.[0].ToLower() with
        | "help" | "--help" | "-h" -> showHelp()
        | "list" | "models" -> showModels()
        | "show" when args.Length > 1 -> showCapabilities args.[1]
        | "tricameral" when args.Length > 1 -> showTricameral args.[1]
        | "compare" when args.Length > 1 -> showComparison args.[1]
        | "costs" when args.Length > 2 ->
            showCosts (Int32.Parse args.[1]) (Int32.Parse args.[2])
        | "export" ->
            saveModelsToJson()
            printfn "[MODEL] Models exported successfully"
        | _ ->
            printfn "[MODEL] Unknown command: %s" args.[0]
            showHelp()

// Entry point
main (fsi.CommandLineArgs |> Array.skip 1)
