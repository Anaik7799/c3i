namespace Cepaf.Tests

open System
open Expecto
open System.IO
open Cepaf
open Cepaf.Infrastructure
open Rop

module OrchestratorTests =

    let testTmpDir =
        let dir = Path.Combine(Path.GetTempPath(), "cepaf_test_tmp")
        if not (Directory.Exists dir) then Directory.CreateDirectory dir |> ignore
        dir

    let testRegistry = {
        LogPath = "test.log"
        DatabasePath = "test.db"
        TempDir = testTmpDir
        ComposeFiles = Map.empty
        ContainerNames = Map.ofList [("db", "indrajaal-db"); ("app", "indrajaal-app"); ("obs", "indrajaal-obs")]
        PortMap = Map.ofList [("db", 5433); ("app", 4000); ("obs", 8123)]
        ReadyPatterns = Map.empty
        Dockerfiles = Map.empty
        Constraints = []
        PodmanSocket = None
    }

    type MockRunner() =
        interface IProcessRunner with
            member _.Run(cmd, args, ?patientMode) = 
                async { 
                    return Ok (CliWrap.Buffered.BufferedCommandResult(0, DateTimeOffset.Now, DateTimeOffset.Now, "", ""))
                }

    [<Tests>]
    let tests =
        testList "Orchestrator" [
            testCaseAsync "Runs full protocol successfully" <| async {
                let (logger, _) = createInfrastructure testRegistry
                let runner = MockRunner()
                let config = {
                    Environments = [DEV]
                    Sterilize = false
                    FormalVerify = false
                    Build = false
                    DbTestOnly = false
                    ObsTestOnly = false
                    StandaloneMode = false
                    InfraCheck = true
                    RunTests = false
                    RunUiCheck = false
                    AutoConfirm = true
                    PatientMode = false
                    PhicsEnabled = true
                    BootThresholdMs = 30000L
                    Registry = testRegistry
                }

                let! res = Orchestrator.runProtocol logger runner config
                Expect.equal res (Ok ()) "Protocol should succeed"
            }
        ]