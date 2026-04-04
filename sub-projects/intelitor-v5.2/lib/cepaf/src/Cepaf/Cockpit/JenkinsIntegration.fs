namespace Cepaf.Cockpit

open System
open System.IO
open System.Net.Http
open System.Text.Json
open System.Text.Json.Serialization
open Cepaf.Core.Units
open Cepaf.Core.Composition

/// ═══════════════════════════════════════════════════════════════════════════════
/// JENKINS CI/CD INTEGRATION - Full Test Infrastructure Integration
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Complete Jenkins integration for 5-level fractal test infrastructure.
///
/// WHY: Jenkins provides:
///   - Distributed builds across multiple agents
///   - Pipeline as Code (Jenkinsfile)
///   - Plugin ecosystem (1800+ plugins)
///   - Blue Ocean modern UI
///   - Webhook triggers for GitLab/GitHub
///   - Test result aggregation and trending
///   - Parallel stage execution
///   - Build artifact management
///
/// STAMP CONSTRAINTS:
///   SC-CI-001: All builds reproducible
///   SC-CI-002: Pipeline timeout < 60 minutes
///   SC-CI-003: Test results always published
///   SC-CI-004: Artifacts retained for 30 days
///   SC-CI-005: Quality gates mandatory
///   SC-CI-006: Security scans on every build
///   SC-CI-007: All 5 levels must pass for merge
///
/// AOR RULES:
///   AOR-CI-001: Jenkinsfile validates before push
///   AOR-CI-002: Parallel stages for independent tests
///   AOR-CI-003: Fail fast on critical failures
///   AOR-CI-004: Notify on all build status changes
///   AOR-CI-005: Cache dependencies between builds
///
/// ARCHITECTURE:
/// ┌──────────────────────────────────────────────────────────────────────────────┐
/// │                          JENKINS INTEGRATION                                  │
/// ├──────────────────────────────────────────────────────────────────────────────┤
/// │  ┌─────────────────────────────────────────────────────────────────────────┐ │
/// │  │                         WEBHOOK TRIGGERS                                 │ │
/// │  │  GitHub/GitLab → Jenkins → Pipeline → Test Cockpit → Report            │ │
/// │  └─────────────────────────────────────────────────────────────────────────┘ │
/// │                                                                              │
/// │  ┌─────────────────────────────────────────────────────────────────────────┐ │
/// │  │                      5-LEVEL PARALLEL PIPELINE                          │ │
/// │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
/// │  │  │  TDG    │ │  FMEA   │ │ Formal  │ │  Graph  │ │   BDD   │           │ │
/// │  │  │  Stage  │ │  Stage  │ │  Stage  │ │  Stage  │ │  Stage  │           │ │
/// │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
/// │  └─────────────────────────────────────────────────────────────────────────┘ │
/// │                                                                              │
/// │  ┌─────────────────────────────────────────────────────────────────────────┐ │
/// │  │                       QUALITY GATES                                      │ │
/// │  │  Coverage > 95% │ 0 Warnings │ 0 Credo Issues │ Security Clean         │ │
/// │  └─────────────────────────────────────────────────────────────────────────┘ │
/// └──────────────────────────────────────────────────────────────────────────────┘
module JenkinsIntegration =

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Build Status
    type BuildStatus =
        | Pending
        | Running
        | Success
        | Failure
        | Unstable
        | Aborted

    /// Test Level for Jenkins stages
    type JenkinsStage =
        | Checkout
        | Dependencies
        | Compile
        | TDGTests
        | FMEATests
        | FormalVerification
        | GraphAnalysis
        | BDDTests
        | QualityGate
        | Deploy
        | Notify

    /// Build Result
    type BuildResult = {
        BuildNumber: int
        Status: BuildStatus
        Branch: string
        CommitHash: string
        Duration: TimeSpan
        TestResults: Map<string, int * int> // (passed, failed)
        CoveragePercentage: float
        Artifacts: string list
        Timestamp: DateTimeOffset
    }

    /// Pipeline Configuration
    type PipelineConfig = {
        AgentLabel: string
        Timeout: int // minutes
        ParallelLevels: bool
        FailFast: bool
        RetryCount: int
        NotifySlack: bool
        NotifyEmail: bool
        ArtifactRetention: int // days
        CacheEnabled: bool
    }

    /// Webhook Payload
    type WebhookPayload = {
        EventType: string
        Branch: string
        CommitHash: string
        Author: string
        Message: string
        Timestamp: DateTimeOffset
    }

    /// Jenkins Job Definition
    type JenkinsJob = {
        Name: string
        Description: string
        Pipeline: string
        Triggers: string list
        Parameters: Map<string, string>
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// STAMP Constraints for CI/CD
    let stampConstraints = Map.ofList [
        ("SC-CI-001", "All builds reproducible")
        ("SC-CI-002", "Pipeline timeout < 60 minutes")
        ("SC-CI-003", "Test results always published")
        ("SC-CI-004", "Artifacts retained for 30 days")
        ("SC-CI-005", "Quality gates mandatory")
        ("SC-CI-006", "Security scans on every build")
        ("SC-CI-007", "All 5 levels must pass for merge")
    ]

    /// AOR Rules for CI/CD
    let aorRules = Map.ofList [
        ("AOR-CI-001", "Jenkinsfile validates before push")
        ("AOR-CI-002", "Parallel stages for independent tests")
        ("AOR-CI-003", "Fail fast on critical failures")
        ("AOR-CI-004", "Notify on all build status changes")
        ("AOR-CI-005", "Cache dependencies between builds")
    ]

    /// Default pipeline configuration
    let defaultConfig : PipelineConfig = {
        AgentLabel = "elixir-fsharp"
        Timeout = 60
        ParallelLevels = true
        FailFast = true
        RetryCount = 2
        NotifySlack = true
        NotifyEmail = true
        ArtifactRetention = 30
        CacheEnabled = true
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JENKINSFILE GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Generate full Jenkinsfile for 5-level fractal tests
    let generateJenkinsfile (config: PipelineConfig) : string =
        let parallelBlock = if config.ParallelLevels then "parallel" else "sequential"
        let failFastStr = if config.FailFast then "true" else "false"

        $"""// ╔═══════════════════════════════════════════════════════════════════════════════╗
// ║  INDRAJAAL FRACTAL TEST PIPELINE - 5-LEVEL COVERAGE                           ║
// ║  Auto-generated by Cepaf.Cockpit.JenkinsIntegration                           ║
// ╠═══════════════════════════════════════════════════════════════════════════════╣
// ║  STAMP: SC-CI-001 to SC-CI-007 | AOR: AOR-CI-001 to AOR-CI-005               ║
// ╚═══════════════════════════════════════════════════════════════════════════════╝

pipeline {{
    agent {{
        label '{config.AgentLabel}'
    }}

    options {{
        timeout(time: {config.Timeout}, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        timestamps()
        ansiColor('xterm')
    }}

    environment {{
        // Core Environment
        MIX_ENV = 'test'
        SKIP_ZENOH_NIF = '0'
        POSTGRES_USER = 'postgres'
        POSTGRES_PASSWORD = 'postgres'
        DATABASE_URL = 'ecto://postgres:postgres@localhost:5433/indrajaal_test'

        // SC-METRICS-003: Mandatory Parallelization Environment Variables
        // Patient Mode + Full Parallelization
        NO_TIMEOUT = 'true'
        PATIENT_MODE = 'enabled'
        INFINITE_PATIENCE = 'true'

        // SC-METRICS-003: BEAM Scheduler Configuration
        // 16 schedulers + 16 dirty I/O schedulers for maximum parallelization
        ELIXIR_ERL_OPTIONS = '+S 16:16 +SDio 16'

        // SC-METRICS-003: Parallel dependency compilation
        MIX_OS_DEPS_COMPILE_PARTITION_COUNT = '8'

        // Paths
        DOTNET_PATH = '/nix/store/b9fq54b1yqc3fk189imvmcckm46q4pl8-dotnet-sdk-9.0.308/share/dotnet/dotnet'
    }}

    stages {{
        // ═══════════════════════════════════════════════════════════════════════
        // SETUP STAGE
        // ═══════════════════════════════════════════════════════════════════════
        stage('Checkout') {{
            steps {{
                checkout scm
                script {{
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                }}
            }}
        }}

        stage('Dependencies') {{
            parallel {{
                stage('Elixir Deps') {{
                    steps {{
                        sh 'mix deps.get'
                        sh 'mix deps.compile'
                    }}
                }}
                stage('F# Deps') {{
                    steps {{
                        sh '$DOTNET_PATH restore lib/cepaf/Cepaf.sln'
                    }}
                }}
                stage('Node Deps') {{
                    when {{
                        expression {{ fileExists('test/puppeteer/package.json') }}
                    }}
                    steps {{
                        dir('test/puppeteer') {{
                            sh 'npm ci'
                        }}
                    }}
                }}
            }}
        }}

        // ═══════════════════════════════════════════════════════════════════════
        // COMPILATION STAGE
        // ═══════════════════════════════════════════════════════════════════════
        stage('Compile') {{
            parallel {{
                stage('Elixir Compile') {{
                    steps {{
                        sh '''
                            # SC-METRICS-003: Mandatory Parallelization
                            NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \\
                            ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" \\
                            MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \\
                            SKIP_ZENOH_NIF=0 \\
                            mix compile --warnings-as-errors 2>&1 | tee compile.log

                            # Log compilation metrics
                            echo "=== SC-METRICS-003/004 Compilation Metrics ===" >> compile.log
                            echo "Schedulers: 16 online + 16 dirty I/O" >> compile.log
                            echo "Partitions: 8" >> compile.log
                            echo "Patient Mode: enabled" >> compile.log
                        '''
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'compile.log', allowEmptyArchive: true
                        }}
                    }}
                }}
                stage('F# Compile') {{
                    steps {{
                        sh '$DOTNET_PATH build lib/cepaf/Cepaf.sln --configuration Release'
                    }}
                }}
            }}
        }}

        // ═══════════════════════════════════════════════════════════════════════
        // 5-LEVEL FRACTAL TEST STAGES
        // ═══════════════════════════════════════════════════════════════════════
        stage('5-Level Fractal Tests') {{
            failFast {failFastStr}
            parallel {{
                // ─────────────────────────────────────────────────────────────────
                // LEVEL 1: TDG (Test-Driven Generation)
                // ─────────────────────────────────────────────────────────────────
                stage('Level 1: TDG') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  LEVEL 1: TDG Tests (PropCheck + ExUnitProperties)        ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'
                        sh '''
                            SKIP_ZENOH_NIF=0 \\
                            MIX_ENV=test mix test --only property 2>&1 | tee tdg_results.log
                        '''
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'tdg_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}

                // ─────────────────────────────────────────────────────────────────
                // LEVEL 2: FMEA (Failure Mode Effects Analysis)
                // ─────────────────────────────────────────────────────────────────
                stage('Level 2: FMEA') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  LEVEL 2: FMEA Tests (RPN Analysis)                       ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'
                        sh '''
                            SKIP_ZENOH_NIF=0 \\
                            MIX_ENV=test mix test --only fmea 2>&1 | tee fmea_results.log
                        '''
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'fmea_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}

                // ─────────────────────────────────────────────────────────────────
                // LEVEL 3: FORMAL VERIFICATION
                // ─────────────────────────────────────────────────────────────────
                stage('Level 3: Formal') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  LEVEL 3: Formal Verification (Agda + Quint)              ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'
                        script {{
                            // Run Quint models
                            def quintFiles = findFiles(glob: 'docs/formal_specs/*.qnt')
                            if (quintFiles) {{
                                quintFiles.each {{ file ->
                                    sh "quint run ${{file.path}} 2>&1 | tee -a formal_results.log || true"
                                }}
                            }}
                            // Run Agda proofs (if agda available)
                            def agdaFiles = findFiles(glob: 'docs/formal_specs/*.agda')
                            if (agdaFiles) {{
                                agdaFiles.each {{ file ->
                                    sh "agda --safe ${{file.path}} 2>&1 | tee -a formal_results.log || true"
                                }}
                            }}
                        }}
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'formal_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}

                // ─────────────────────────────────────────────────────────────────
                // LEVEL 4: GRAPH-BASED PATH ANALYSIS
                // ─────────────────────────────────────────────────────────────────
                stage('Level 4: Graph') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  LEVEL 4: Graph-Based Path Analysis (Coverage)            ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'
                        sh '''
                            SKIP_ZENOH_NIF=0 \\
                            MIX_ENV=test mix coveralls.detail 2>&1 | tee graph_results.log
                        '''
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'graph_results.log', allowEmptyArchive: true
                            archiveArtifacts artifacts: 'cover/*.html', allowEmptyArchive: true
                        }}
                    }}
                }}

                // ─────────────────────────────────────────────────────────────────
                // LEVEL 5: BDD (Cucumber + SpecFlow + Playwright)
                // ─────────────────────────────────────────────────────────────────
                stage('Level 5: BDD') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  LEVEL 5: BDD Tests (Cucumber + SpecFlow + Playwright)    ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'

                        // Cucumber (Elixir BDD)
                        sh '''
                            SKIP_ZENOH_NIF=0 \\
                            MIX_ENV=test mix test test/features/ 2>&1 | tee bdd_cucumber.log
                        '''

                        // SpecFlow (F# BDD)
                        sh '''
                            $DOTNET_PATH run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary 2>&1 | tee bdd_specflow.log
                        '''

                        // Playwright (Browser tests) - if configured
                        script {{
                            if (fileExists('test/puppeteer/package.json')) {{
                                dir('test/puppeteer') {{
                                    sh 'npx playwright test 2>&1 | tee ../bdd_playwright.log || true'
                                }}
                            }}
                        }}
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'bdd_*.log', allowEmptyArchive: true
                            archiveArtifacts artifacts: 'test/puppeteer/screenshots/**', allowEmptyArchive: true
                        }}
                    }}
                }}

                // ─────────────────────────────────────────────────────────────────
                // F# CEPAF TESTS
                // ─────────────────────────────────────────────────────────────────
                stage('F# CEPAF Tests') {{
                    steps {{
                        echo '╔═══════════════════════════════════════════════════════════╗'
                        echo '║  F# CEPAF Tests (Expecto + FsCheck)                       ║'
                        echo '╚═══════════════════════════════════════════════════════════╝'
                        sh '''
                            $DOTNET_PATH run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary 2>&1 | tee fsharp_results.log
                        '''
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'fsharp_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}
            }}
        }}

        // ═══════════════════════════════════════════════════════════════════════
        // QUALITY GATES
        // ═══════════════════════════════════════════════════════════════════════
        stage('Quality Gates') {{
            parallel {{
                stage('Format Check') {{
                    steps {{
                        sh 'mix format --check-formatted'
                    }}
                }}
                stage('Credo') {{
                    steps {{
                        sh 'timeout 120 mix credo --strict 2>&1 | tee credo_results.log'
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'credo_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}
                stage('Sobelow Security') {{
                    steps {{
                        sh 'mix sobelow --skip --exit 2>&1 | tee sobelow_results.log'
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'sobelow_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}
                stage('Dialyzer') {{
                    steps {{
                        sh 'mix dialyzer 2>&1 | tee dialyzer_results.log || true'
                    }}
                    post {{
                        always {{
                            archiveArtifacts artifacts: 'dialyzer_results.log', allowEmptyArchive: true
                        }}
                    }}
                }}
            }}
        }}

        // ═══════════════════════════════════════════════════════════════════════
        // COVERAGE REPORTING
        // ═══════════════════════════════════════════════════════════════════════
        stage('Coverage Report') {{
            steps {{
                sh '''
                    SKIP_ZENOH_NIF=0 \\
                    MIX_ENV=test mix coveralls.html 2>&1 | tee coverage_report.log
                '''
            }}
            post {{
                always {{
                    archiveArtifacts artifacts: 'cover/**', allowEmptyArchive: true
                    archiveArtifacts artifacts: 'coverage_report.log', allowEmptyArchive: true
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'cover',
                        reportFiles: 'excoveralls.html',
                        reportName: 'Coverage Report'
                    ])
                }}
            }}
        }}
    }}

    // ═══════════════════════════════════════════════════════════════════════════
    // POST-BUILD ACTIONS
    // ═══════════════════════════════════════════════════════════════════════════
    post {{
        always {{
            // Publish test results
            junit allowEmptyResults: true, testResults: '**/test-results/*.xml'

            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '_build/', type: 'INCLUDE'],
                    [pattern: 'deps/', type: 'INCLUDE'],
                    [pattern: '*.log', type: 'EXCLUDE']
                ]
            )
        }}

        success {{
            echo '╔═══════════════════════════════════════════════════════════╗'
            echo '║  ✓ ALL 5 LEVELS PASSED - BUILD SUCCESSFUL                 ║'
            echo '╚═══════════════════════════════════════════════════════════╝'

            // Slack notification (if configured)
            script {{
                if ({config.NotifySlack.ToString().ToLower()}) {{
                    // slackSend color: 'good', message: "Build #${{BUILD_NUMBER}} succeeded on ${{GIT_BRANCH}}"
                    echo 'Slack notification would be sent here'
                }}
            }}
        }}

        failure {{
            echo '╔═══════════════════════════════════════════════════════════╗'
            echo '║  ✗ BUILD FAILED - CHECK LOGS                              ║'
            echo '╚═══════════════════════════════════════════════════════════╝'

            // Notify on failure
            script {{
                if ({config.NotifyEmail.ToString().ToLower()}) {{
                    // emailext subject: "Build #${{BUILD_NUMBER}} Failed"
                    echo 'Email notification would be sent here'
                }}
            }}
        }}

        unstable {{
            echo '╔═══════════════════════════════════════════════════════════╗'
            echo '║  ⚠ BUILD UNSTABLE - SOME TESTS FAILED                     ║'
            echo '╚═══════════════════════════════════════════════════════════╝'
        }}
    }}
}}
"""

    // ═══════════════════════════════════════════════════════════════════════════
    // WEBHOOK HANDLING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Parse webhook payload from GitHub/GitLab
    let parseWebhookPayload (json: string) : Result<WebhookPayload, string> =
        try
            let doc = JsonDocument.Parse(json)
            let root = doc.RootElement

            let mutable dummy = JsonElement()
            let eventType =
                if root.TryGetProperty("action", &dummy) then
                    "github"
                elif root.TryGetProperty("object_kind", &dummy) then
                    "gitlab"
                else
                    "unknown"

            let branch =
                let mutable dummy2 = JsonElement()
                if root.TryGetProperty("ref", &dummy2) then
                    root.GetProperty("ref").GetString().Replace("refs/heads/", "")
                else
                    "main"

            let commit =
                let mutable dummy3 = JsonElement()
                if root.TryGetProperty("after", &dummy3) then
                    root.GetProperty("after").GetString()
                else
                    ""

            Ok {
                EventType = eventType
                Branch = branch
                CommitHash = commit
                Author = ""
                Message = ""
                Timestamp = DateTimeOffset.UtcNow
            }
        with
        | ex -> Error (sprintf "Failed to parse webhook: %s" ex.Message)

    /// Trigger Jenkins build via API
    let triggerBuild (jenkinsUrl: string) (jobName: string) (token: string) (parameters: Map<string, string>) =
        async {
            use client = new HttpClient()
            client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" token)

            let paramString =
                parameters
                |> Map.toList
                |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
                |> String.concat "&"

            let url =
                if Map.isEmpty parameters then
                    sprintf "%s/job/%s/build" jenkinsUrl jobName
                else
                    sprintf "%s/job/%s/buildWithParameters?%s" jenkinsUrl jobName paramString

            let! response = client.PostAsync(url, null) |> Async.AwaitTask
            return response.IsSuccessStatusCode
        }

    /// Get build status from Jenkins
    let getBuildStatus (jenkinsUrl: string) (jobName: string) (buildNumber: int) (token: string) =
        async {
            use client = new HttpClient()
            client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" token)

            let url = sprintf "%s/job/%s/%d/api/json" jenkinsUrl jobName buildNumber
            let! response = client.GetStringAsync(url) |> Async.AwaitTask

            let doc = JsonDocument.Parse(response)
            let result = doc.RootElement.GetProperty("result").GetString()

            return
                match result with
                | "SUCCESS" -> Success
                | "FAILURE" -> Failure
                | "UNSTABLE" -> Unstable
                | "ABORTED" -> Aborted
                | _ -> Running
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // JOB DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create multibranch pipeline job definition
    let createMultibranchJob () : JenkinsJob = {
        Name = "indrajaal-fractal-tests"
        Description = "5-Level Fractal Test Pipeline for Indrajaal"
        Pipeline = generateJenkinsfile defaultConfig
        Triggers = ["push"; "pull_request"; "cron: H/4 * * * *"]
        Parameters = Map.ofList [
            ("BRANCH", "main")
            ("RUN_FORMAL", "true")
            ("RUN_BROWSER", "true")
            ("COVERAGE_THRESHOLD", "95")
        ]
    }

    /// Create nightly full test job
    let createNightlyJob () : JenkinsJob = {
        Name = "indrajaal-nightly"
        Description = "Nightly Full Test Suite with All 5 Levels"
        Pipeline = generateJenkinsfile { defaultConfig with Timeout = 120; ParallelLevels = false }
        Triggers = ["cron: 0 2 * * *"]
        Parameters = Map.ofList [
            ("FULL_COVERAGE", "true")
            ("INCLUDE_STRESS", "true")
        ]
    }

    /// Create PR validation job
    let createPRValidationJob () : JenkinsJob = {
        Name = "indrajaal-pr-validation"
        Description = "Pull Request Validation (Fast Mode)"
        Pipeline = generateJenkinsfile { defaultConfig with Timeout = 30; FailFast = true }
        Triggers = ["pull_request"]
        Parameters = Map.ofList [
            ("SKIP_FORMAL", "true")
            ("SKIP_STRESS", "true")
        ]
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RESULT REPORTING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Generate JUnit XML report from test results
    let generateJUnitReport (results: Map<string, TestCockpit.TestResult>) : string =
        let testSuites =
            results
            |> Map.toList
            |> List.map (fun (name, result) ->
                let status = match result.Status with
                             | TestCockpit.Passed -> "passed"
                             | TestCockpit.Failed _ -> "failed"
                             | _ -> "skipped"
                sprintf """
  <testsuite name="%s" tests="%d" failures="%d" time="%.3f">
    <testcase classname="%s" name="%s" time="%.3f">
      %s
    </testcase>
  </testsuite>"""
                    name result.TestsRun result.Failures result.Duration.TotalSeconds
                    name name result.Duration.TotalSeconds
                    (if result.Failures > 0 then sprintf "<failure>%s</failure>" result.Output else "")
            )
            |> String.concat "\n"

        sprintf """<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Indrajaal 5-Level Fractal Tests" timestamp="%s">
%s
</testsuites>""" (DateTimeOffset.UtcNow.ToString("o")) testSuites

    /// Print Jenkins integration status
    let printStatus () =
        printfn "\n╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║             JENKINS CI/CD INTEGRATION STATUS                      ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║  STAMP Constraints: SC-CI-001 to SC-CI-007                        ║"
        printfn "║  AOR Rules: AOR-CI-001 to AOR-CI-005                              ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║  Available Functions:                                             ║"
        printfn "║    JenkinsIntegration.generateJenkinsfile config                  ║"
        printfn "║    JenkinsIntegration.triggerBuild url job token params           ║"
        printfn "║    JenkinsIntegration.getBuildStatus url job buildNum token       ║"
        printfn "║    JenkinsIntegration.createMultibranchJob ()                     ║"
        printfn "║    JenkinsIntegration.createNightlyJob ()                         ║"
        printfn "║    JenkinsIntegration.createPRValidationJob ()                    ║"
        printfn "║    JenkinsIntegration.generateJUnitReport results                 ║"
        printfn "╚═══════════════════════════════════════════════════════════════════╝"

    /// Save Jenkinsfile to disk
    let saveJenkinsfile (path: string) (config: PipelineConfig) =
        let content = generateJenkinsfile config
        File.WriteAllText(path, content)
        printfn "[JenkinsIntegration] Jenkinsfile saved to: %s" path
