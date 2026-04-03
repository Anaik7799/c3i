defmodule Indrajaal.Cockpit.Prajna.Bio.TypesTest do
  @moduledoc """
  Tests for Indrajaal.Cockpit.Prajna.Bio.Types nested struct definitions.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.Bio.Types

  describe "module existence" do
    test "Types module is loaded" do
      assert Code.ensure_loaded?(Types)
    end

    test "GeneticPayload submodule is loaded" do
      assert Code.ensure_loaded?(Types.GeneticPayload)
    end

    test "VitalSigns submodule is loaded" do
      assert Code.ensure_loaded?(Types.VitalSigns)
    end
  end

  describe "GeneticPayload struct" do
    test "can create an empty GeneticPayload struct" do
      payload = %Types.GeneticPayload{}
      assert is_struct(payload)
      assert payload.__struct__ == Types.GeneticPayload
    end

    test "GeneticPayload has id field" do
      payload = %Types.GeneticPayload{id: "genome-001"}
      assert payload.id == "genome-001"
    end

    test "GeneticPayload has timestamp field" do
      now = DateTime.utc_now()
      payload = %Types.GeneticPayload{timestamp: now}
      assert payload.timestamp == now
    end

    test "GeneticPayload has genome_hash field" do
      payload = %Types.GeneticPayload{genome_hash: "sha256-abc123"}
      assert payload.genome_hash == "sha256-abc123"
    end

    test "GeneticPayload has dna field" do
      dna = %{fitness: 0.85, traits: [:speed, :accuracy]}
      payload = %Types.GeneticPayload{dna: dna}
      assert payload.dna == dna
    end

    test "GeneticPayload has markers field" do
      markers = [:marker_a, :marker_b]
      payload = %Types.GeneticPayload{markers: markers}
      assert payload.markers == markers
    end

    test "GeneticPayload has signature field" do
      payload = %Types.GeneticPayload{signature: "sig-xyz"}
      assert payload.signature == "sig-xyz"
    end

    test "GeneticPayload can be fully constructed" do
      payload = %Types.GeneticPayload{
        id: "genome-full-001",
        timestamp: DateTime.utc_now(),
        genome_hash: "sha256-deadbeef",
        dna: %{generation: 5},
        markers: [:alpha, :beta],
        signature: "ed25519-sig"
      }

      assert payload.id == "genome-full-001"
      assert payload.genome_hash == "sha256-deadbeef"
      assert payload.dna == %{generation: 5}
    end
  end

  describe "VitalSigns struct" do
    test "can create an empty VitalSigns struct" do
      vitals = %Types.VitalSigns{}
      assert is_struct(vitals)
      assert vitals.__struct__ == Types.VitalSigns
    end

    test "VitalSigns has health field" do
      vitals = %Types.VitalSigns{health: 0.95}
      assert vitals.health == 0.95
    end

    test "VitalSigns has stress field" do
      vitals = %Types.VitalSigns{stress: 0.2}
      assert vitals.stress == 0.2
    end

    test "VitalSigns has energy field" do
      vitals = %Types.VitalSigns{energy: 0.8}
      assert vitals.energy == 0.8
    end

    test "VitalSigns has age field" do
      vitals = %Types.VitalSigns{age: 42}
      assert vitals.age == 42
    end

    test "VitalSigns has generation field" do
      vitals = %Types.VitalSigns{generation: 7}
      assert vitals.generation == 7
    end

    test "VitalSigns has intent field" do
      vitals = %Types.VitalSigns{intent: :survive}
      assert vitals.intent == :survive
    end

    test "VitalSigns can be fully constructed" do
      vitals = %Types.VitalSigns{
        health: 1.0,
        stress: 0.1,
        energy: 0.9,
        age: 0,
        generation: 1,
        intent: :evolve
      }

      assert vitals.health == 1.0
      assert vitals.generation == 1
      assert vitals.intent == :evolve
    end
  end

  describe "struct interoperability" do
    test "GeneticPayload and VitalSigns can coexist" do
      payload = %Types.GeneticPayload{id: "g1"}
      vitals = %Types.VitalSigns{health: 0.9}
      combined = %{genome: payload, vitals: vitals}
      assert combined.genome.id == "g1"
      assert combined.vitals.health == 0.9
    end
  end
end
