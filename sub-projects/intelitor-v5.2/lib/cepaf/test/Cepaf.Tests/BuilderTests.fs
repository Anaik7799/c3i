namespace Cepaf.Tests

open System
open Expecto
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Phases

module BuilderTests =

    let testRegistry = {
        LogPath = "test.log"
        DatabasePath = "test.db"
        TempDir = "test_tmp"
        ComposeFiles = Map.empty
        ContainerNames = Map.ofList [("db", "indrajaal-db"); ("app", "indrajaal-app"); ("obs", "indrajaal-obs")]
        PortMap = Map.ofList [("db", 5433); ("app", 4000); ("obs", 8123)]
        ReadyPatterns = Map.empty
        Dockerfiles = Map.empty
        Constraints = []
        PodmanSocket = None
    }

    let testConfig = {
        Environments = []
        Sterilize = false
        FormalVerify = false
        Build = false
        DbTestOnly = false
        ObsTestOnly = false
        StandaloneMode = false
        InfraCheck = false
        RunTests = false
        RunUiCheck = false
        AutoConfirm = false
        PatientMode = false
        PhicsEnabled = false
        BootThresholdMs = 30000L
        Registry = testRegistry
    }

    type MockRunner(response: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) =
        interface IProcessRunner with
            member _.Run(cmd, args, ?patientMode) = 
                async { return response }

    [<Tests>]
    let tests =
        testList "BuilderPhase" [
            testCaseAsync "Successfully builds image" <| async {
                let (logger, _) = createInfrastructure testRegistry
                let mockRes = Ok (CliWrap.Buffered.BufferedCommandResult(0, DateTimeOffset.Now, DateTimeOffset.Now, "", ""))
                let runner = MockRunner(mockRes)
                
                let! res = Builder.buildWithOoda logger runner testConfig "test-image" "Dockerfile"
                Expect.equal res (Ok ()) "Build should succeed"
            }

            testCaseAsync "Fails on unknown error" <| async {
                let (logger, _) = createInfrastructure testRegistry
                let mockRes = Error (ProcessError("podman", 1, "fatal error"))
                let runner = MockRunner(mockRes)
                
                let! res = Builder.buildWithOoda logger runner testConfig "test-image" "Dockerfile"
                match res with
                | Error (ProcessError _) -> ()
                | _ -> failwith "Should have returned process error"
            }
        ]