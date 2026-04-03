/// Tests for Version Vector operations.
///
/// STAMP Compliance: SC-XHOLON-007, SC-CONC-001, SC-CONC-002
/// Coverage: Mathematical properties from formal specification
module Cepaf.Database.Tests.VersionVectorTests

open Expecto
open FsCheck
open Cepaf.Database.HolonConcurrencyHandler

// ==========================================================================
// Generators
// ==========================================================================

let holonIdGen =
    Gen.elements ["ex"; "fs"; "zig"; "rs"]
    |> Gen.map2 (fun layer runtime ->
        let domain = Gen.elements ["kms"; "prj"; "ana"; "obs"] |> Gen.sample 1 1 |> List.head
        let typ = Gen.elements ["srv"; "agt"; "wkr"] |> Gen.sample 1 1 |> List.head
        let instance = Gen.elements ["main"; "backup"; "test"] |> Gen.sample 1 1 |> List.head
        sprintf "%s:l%d:%s:%s:%s" runtime layer domain typ instance
    ) (Gen.choose (1, 7))

let versionVectorGen =
    Gen.listOf (Gen.map2 (fun h v -> h, v) holonIdGen (Gen.choose (0L, 1000L)))
    |> Gen.map Map.ofList

type VersionVectorGenerators =
    static member VersionVector() = Arb.fromGen versionVectorGen
    static member HolonId() = Arb.fromGen holonIdGen

// ==========================================================================
// Unit Tests
// ==========================================================================

[<Tests>]
let versionVectorUnitTests =
    testList "Version Vector Unit Tests" [

        testList "newVersionVector" [
            test "creates vector with single entry at 0" {
                let vv = newVersionVector "holon1"
                Expect.equal vv (Map.ofList ["holon1", 0L]) "Should have single entry"
            }
        ]

        testList "increment" [
            test "increments existing entry" {
                let vv = Map.ofList ["holon1", 5L]
                let result = increment vv "holon1"
                Expect.equal (Map.find "holon1" result) 6L "Should increment to 6"
            }

            test "adds new entry with value 1" {
                let vv = Map.ofList ["holon1", 5L]
                let result = increment vv "holon2"
                Expect.equal (Map.find "holon2" result) 1L "New entry should be 1"
                Expect.equal (Map.find "holon1" result) 5L "Existing entry unchanged"
            }

            test "handles empty map" {
                let result = increment Map.empty "holon1"
                Expect.equal result (Map.ofList ["holon1", 1L]) "Should add first entry"
            }
        ]

        testList "merge" [
            test "takes max of each component" {
                let vv1 = Map.ofList ["h1", 3L; "h2", 5L]
                let vv2 = Map.ofList ["h1", 7L; "h3", 2L]
                let result = merge vv1 vv2
                Expect.equal result (Map.ofList ["h1", 7L; "h2", 5L; "h3", 2L]) "Should have max values"
            }

            test "handles disjoint keys" {
                let vv1 = Map.ofList ["h1", 3L]
                let vv2 = Map.ofList ["h2", 5L]
                let result = merge vv1 vv2
                Expect.equal result (Map.ofList ["h1", 3L; "h2", 5L]) "Should union keys"
            }
        ]

        testList "versionGte" [
            test "returns true when vv1 >= vv2 for all components" {
                let vv1 = Map.ofList ["h1", 5L; "h2", 3L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 2L]
                Expect.isTrue (versionGte vv1 vv2) "5,3 >= 5,2"
            }

            test "returns false when any component of vv1 < vv2" {
                let vv1 = Map.ofList ["h1", 5L; "h2", 1L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 2L]
                Expect.isFalse (versionGte vv1 vv2) "5,1 not >= 5,2"
            }

            test "treats missing keys as 0" {
                let vv1 = Map.ofList ["h1", 5L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 0L]
                Expect.isTrue (versionGte vv1 vv2) "Missing h2 treated as 0"
            }

            test "returns false when vv1 missing key that vv2 has > 0" {
                let vv1 = Map.ofList ["h1", 5L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 1L]
                Expect.isFalse (versionGte vv1 vv2) "Missing h2 < 1"
            }
        ]

        testList "happensBefore" [
            test "returns true when vv1 < vv2" {
                let vv1 = Map.ofList ["h1", 3L; "h2", 2L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 3L]
                Expect.isTrue (happensBefore vv1 vv2) "(3,2) < (5,3)"
            }

            test "returns false when vv1 == vv2" {
                let vv = Map.ofList ["h1", 3L; "h2", 2L]
                Expect.isFalse (happensBefore vv vv) "Not strictly less than"
            }

            test "returns false for concurrent versions" {
                let vv1 = Map.ofList ["h1", 5L; "h2", 2L]
                let vv2 = Map.ofList ["h1", 3L; "h2", 4L]
                Expect.isFalse (happensBefore vv1 vv2) "Concurrent: neither precedes"
                Expect.isFalse (happensBefore vv2 vv1) "Concurrent: neither precedes"
            }
        ]

        testList "concurrent" [
            test "returns true when neither happens-before" {
                let vv1 = Map.ofList ["h1", 5L; "h2", 2L]
                let vv2 = Map.ofList ["h1", 3L; "h2", 4L]
                Expect.isTrue (concurrent vv1 vv2) "Neither precedes the other"
            }

            test "returns false when one happens-before" {
                let vv1 = Map.ofList ["h1", 3L; "h2", 2L]
                let vv2 = Map.ofList ["h1", 5L; "h2", 3L]
                Expect.isFalse (concurrent vv1 vv2) "vv1 < vv2"
            }
        ]

        testList "versionVectorToString and parseVersionVector" [
            test "roundtrip conversion" {
                let vv = Map.ofList ["h1", 5L; "h2", 3L]
                let str = versionVectorToString vv
                let parsed = parseVersionVector str

                match parsed with
                | Ok result -> Expect.equal result vv "Should roundtrip"
                | Error e -> failtest $"Parse failed: {e}"
            }
        ]
    ]

// ==========================================================================
// Property-Based Tests
// ==========================================================================

[<Tests>]
let versionVectorPropertyTests =
    testList "Version Vector Property Tests" [

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "SC-XHOLON-007: Increment is monotonic"
            (fun (vv: VersionVector) (h: string) ->
                let incremented = increment vv h
                versionGte incremented vv
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "Merge is commutative"
            (fun (vv1: VersionVector) (vv2: VersionVector) ->
                merge vv1 vv2 = merge vv2 vv1
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "Merge is associative"
            (fun (vv1: VersionVector) (vv2: VersionVector) (vv3: VersionVector) ->
                merge (merge vv1 vv2) vv3 = merge vv1 (merge vv2 vv3)
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "Merge is idempotent"
            (fun (vv: VersionVector) ->
                merge vv vv = vv
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "Merge produces upper bound (>= both inputs)"
            (fun (vv1: VersionVector) (vv2: VersionVector) ->
                let merged = merge vv1 vv2
                versionGte merged vv1 && versionGte merged vv2
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "HappensBefore is irreflexive"
            (fun (vv: VersionVector) ->
                not (happensBefore vv vv)
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "HappensBefore is transitive"
            (fun (vv1: VersionVector) (vv2: VersionVector) (vv3: VersionVector) ->
                not (happensBefore vv1 vv2 && happensBefore vv2 vv3) ||
                happensBefore vv1 vv3
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "Concurrent is symmetric"
            (fun (vv1: VersionVector) (vv2: VersionVector) ->
                concurrent vv1 vv2 = concurrent vv2 vv1
            )

        testPropertyWithConfig
            { FsCheckConfig.defaultConfig with arbitrary = [typeof<VersionVectorGenerators>] }
            "HappensBefore and Concurrent are mutually exclusive"
            (fun (vv1: VersionVector) (vv2: VersionVector) ->
                if happensBefore vv1 vv2 then
                    not (concurrent vv1 vv2)
                else
                    true
            )
    ]

// ==========================================================================
// Run Tests
// ==========================================================================

[<EntryPoint>]
let main args =
    runTestsWithCLIArgs [] args versionVectorUnitTests
    |> (+) (runTestsWithCLIArgs [] args versionVectorPropertyTests)
