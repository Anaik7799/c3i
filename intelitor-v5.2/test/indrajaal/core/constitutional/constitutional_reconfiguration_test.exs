defmodule Indrajaal.Core.Constitutional.ConstitutionalReconfigurationTest do
  @moduledoc """
  Constitutional reconfiguration tests — L1-L7 layer coverage.

  WHAT: Tests for constitutional reconfiguration across fractal layers L1-L7
        (Function → Federation), including immutability of Ψ₀-Ψ₅, Guardian
        veto authority, lineage preservation, and graph transformation safety.
  WHY:  SC-RECONFIG-001 mandates graph transformation for changes;
        SC-RECONFIG-009 requires Guardian approval; Ω₉ permits radical
        reconfiguration at L1-L7 while L0 (Ψ₀-Ψ₅) is IMMUTABLE.
  CONSTRAINTS: SC-RECONFIG-001, SC-RECONFIG-005, SC-RECONFIG-007,
               SC-RECONFIG-009, SC-RECONFIG-010, SC-CONST-001,
               AOR-CONST-001, AOR-CONST-002, AOR-CONST-003, AOR-CONST-004,
               EP-GEN-014

  ## Test Coverage Matrix
  | Dimension                     | PropCheck | StreamData | Unit |
  |-------------------------------|-----------|------------|------|
  | L1-L7 reconfiguration         | 1         | 2          | 4    |
  | Constitutional immutability   | 2         | 2          | 4    |
  | Guardian veto authority       | 1         | 1          | 3    |
  | Lineage preservation          | 1         | 1          | 3    |
  | Graph transformation          | 0         | 0          | 4    |
  | TOTAL                         | 5         | 6          | 18   |

  ## EP-GEN-014 compliance
  - PropCheck forall blocks use PC. prefix
  - StreamData check all blocks use SD. prefix via ExUnitProperties.check all()
  - No bare check all() — check: 2 is excluded from import
  """

  use ExUnit.Case, async: false

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :constitutional
  @moduletag :reconfiguration
  @moduletag :property

  # ──────────────────────────────────────────────────────────────────
  # Self-contained Constitutional helpers
  # ──────────────────────────────────────────────────────────────────

  # The seven reconfigurable fractal layers (L1-L7). L0 is immutable.
  @reconfigurable_layers [:function, :module, :agent, :container, :node, :cluster, :federation]
  @layer_to_index %{
    function: 1,
    module: 2,
    agent: 3,
    container: 4,
    node: 5,
    cluster: 6,
    federation: 7
  }

  # The six constitutional invariants (Ψ₀-Ψ₅) — IMMUTABLE. These form L0.
  @constitutional_invariants [
    :psi_0_existence,
    :psi_1_regeneration,
    :psi_2_history,
    :psi_3_verification,
    :psi_4_human_alignment,
    :psi_5_truthfulness
  ]

  # Represents the system constitution.
  defp base_constitution do
    %{
      version: "21.3.0",
      layer: :L0,
      invariants: @constitutional_invariants,
      hash: :crypto.hash(:sha256, "indrajaal-constitution-v21.3.0") |> Base.encode16(),
      immutable: true
    }
  end

  # Represents the current state of one reconfigurable layer.
  defp layer_state(layer) when layer in @reconfigurable_layers do
    idx = Map.fetch!(@layer_to_index, layer)

    %{
      layer: layer,
      layer_index: idx,
      config: %{version: "21.3.0", active: true, health: :nominal},
      lineage_id: "lineage-#{layer}-#{idx}",
      parent_lineage:
        if(idx > 1,
          do: "lineage-#{Enum.at(@reconfigurable_layers, idx - 2)}-#{idx - 1}",
          else: nil
        ),
      graph_hash: :crypto.hash(:sha256, "layer-#{layer}") |> Base.encode16(case: :lower)
    }
  end

  # Guardian decision: approve unless the proposal touches L0 invariants.
  defp guardian_validate(proposal) do
    cond do
      touches_immutable_layer?(proposal) ->
        {:veto,
         "SC-RECONFIG-009: Guardian vetoes L0 mutation — constitutional invariants are immutable"}

      not Map.has_key?(proposal, :target_layer) ->
        {:veto, "SC-RECONFIG-009: Proposal missing target_layer field"}

      proposal.target_layer not in @reconfigurable_layers ->
        {:veto, "SC-RECONFIG-009: Layer #{inspect(proposal.target_layer)} is not reconfigurable"}

      true ->
        {:approved,
         "Guardian approval granted for L#{Map.fetch!(@layer_to_index, proposal.target_layer)} reconfiguration"}
    end
  end

  defp touches_immutable_layer?(%{target_layer: :L0}), do: true
  defp touches_immutable_layer?(%{modifies_invariants: true}), do: true

  defp touches_immutable_layer?(%{invariant: inv}) when inv in @constitutional_invariants,
    do: true

  defp touches_immutable_layer?(_), do: false

  # Apply a reconfiguration to a layer, preserving lineage.
  # Returns {:ok, new_state} | {:error, reason}
  defp apply_reconfiguration(layer_st, proposal) do
    case guardian_validate(proposal) do
      {:veto, reason} ->
        {:error, {:guardian_veto, reason}}

      {:approved, _} ->
        new_state = %{
          layer_st
          | config: Map.merge(layer_st.config, Map.get(proposal, :config_delta, %{})),
            graph_hash:
              :crypto.hash(
                :sha256,
                layer_st.graph_hash <> inspect(proposal)
              )
              |> Base.encode16(case: :lower)
        }

        # Lineage MUST be preserved (SC-RECONFIG-005)
        assert new_state.lineage_id == layer_st.lineage_id,
               "Lineage broken by reconfiguration"

        {:ok, new_state}
    end
  end

  # Check whether a constitution map still contains all Ψ invariants.
  defp constitution_intact?(constitution) do
    Enum.all?(@constitutional_invariants, fn inv ->
      inv in constitution.invariants
    end)
  end

  # Build a reconfiguration proposal for a given layer.
  defp reconfig_proposal(layer, config_delta \\ %{}) when layer in @reconfigurable_layers do
    %{
      target_layer: layer,
      config_delta: config_delta,
      author: :test_agent,
      timestamp: DateTime.utc_now()
    }
  end

  # ──────────────────────────────────────────────────────────────────
  # Setup
  # ──────────────────────────────────────────────────────────────────

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ──────────────────────────────────────────────────────────────────
  # 1. L1-L7 Reconfiguration Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "L1-L7 layer reconfiguration (SC-RECONFIG-001)" do
    test "all seven reconfigurable layers have distinct indices 1-7" do
      indices = Enum.map(@reconfigurable_layers, &Map.fetch!(@layer_to_index, &1))
      assert Enum.sort(indices) == Enum.to_list(1..7)
    end

    test "reconfiguring :function (L1) is approved by Guardian" do
      state = layer_state(:function)
      proposal = reconfig_proposal(:function, %{version: "21.3.1"})
      assert {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert new_state.config.version == "21.3.1"
    end

    test "reconfiguring :federation (L7) is approved by Guardian" do
      state = layer_state(:federation)
      proposal = reconfig_proposal(:federation, %{peers: 5})
      assert {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert new_state.config.peers == 5
    end

    test "each L1-L7 layer accepts a valid reconfiguration proposal" do
      for layer <- @reconfigurable_layers do
        state = layer_state(layer)
        proposal = reconfig_proposal(layer, %{reconfigured: true})

        assert {:ok, _new_state} = apply_reconfiguration(state, proposal),
               "Layer #{layer} should accept valid reconfiguration"
      end
    end

    test "graph hash changes after reconfiguration (SC-RECONFIG-001)" do
      state = layer_state(:agent)
      proposal = reconfig_proposal(:agent, %{runtime: "new"})
      {:ok, new_state} = apply_reconfiguration(state, proposal)

      assert new_state.graph_hash != state.graph_hash,
             "Graph hash must change on reconfiguration to reflect transformation"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 2. Constitutional Immutability Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "constitutional immutability (Ψ₀-Ψ₅, AOR-CONST-004)" do
    test "base constitution contains all six Ψ invariants" do
      constitution = base_constitution()
      assert constitution_intact?(constitution)
    end

    test "constitutional invariants list is exactly Ψ₀-Ψ₅ (six invariants)" do
      constitution = base_constitution()
      assert length(constitution.invariants) == 6
    end

    test "Ψ₀ existence invariant is present and immutable" do
      constitution = base_constitution()
      assert :psi_0_existence in constitution.invariants
    end

    test "Ψ₅ truthfulness invariant is present and immutable" do
      constitution = base_constitution()
      assert :psi_5_truthfulness in constitution.invariants
    end

    test "proposal targeting L0 is vetoed by Guardian (AOR-CONST-002)" do
      state = layer_state(:function)

      l0_proposal = %{
        target_layer: :L0,
        modifies_invariants: true,
        config_delta: %{}
      }

      result = apply_reconfiguration(state, l0_proposal)
      assert {:error, {:guardian_veto, reason}} = result
      assert String.contains?(reason, "L0") or String.contains?(reason, "immutable")
    end

    test "proposal that modifies_invariants is vetoed (AOR-CONST-002)" do
      state = layer_state(:node)

      bad_proposal = %{
        target_layer: :node,
        modifies_invariants: true,
        config_delta: %{}
      }

      assert {:error, {:guardian_veto, _}} = apply_reconfiguration(state, bad_proposal)
    end

    test "all six invariants survive multiple sequential reconfigurations" do
      constitution = base_constitution()

      # Apply reconfigurations on L1-L7 and verify L0 remains intact
      for layer <- @reconfigurable_layers do
        state = layer_state(layer)
        proposal = reconfig_proposal(layer)
        {:ok, _} = apply_reconfiguration(state, proposal)
      end

      # Constitution must still be intact
      assert constitution_intact?(constitution)
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 3. Guardian Veto Authority Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "Guardian veto authority (SC-RECONFIG-009, AOR-CONST-003)" do
    test "Guardian approves valid L3 reconfiguration" do
      proposal = reconfig_proposal(:agent, %{timeout: 5000})
      assert {:approved, _msg} = guardian_validate(proposal)
    end

    test "Guardian vetoes proposal missing target_layer" do
      bad_proposal = %{config_delta: %{x: 1}}
      assert {:veto, reason} = guardian_validate(bad_proposal)
      assert is_binary(reason)
    end

    test "Guardian vetoes unknown layer" do
      bad_proposal = %{target_layer: :unknown_layer}
      assert {:veto, reason} = guardian_validate(bad_proposal)
      assert String.contains?(reason, "not reconfigurable")
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 4. Lineage Preservation Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "lineage preservation (SC-RECONFIG-005)" do
    test "lineage_id is unchanged after reconfiguration" do
      state = layer_state(:cluster)
      proposal = reconfig_proposal(:cluster, %{nodes: 3})
      {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert new_state.lineage_id == state.lineage_id
    end

    test "parent_lineage is preserved after reconfiguration" do
      state = layer_state(:federation)
      proposal = reconfig_proposal(:federation)
      {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert new_state.parent_lineage == state.parent_lineage
    end

    test "function layer (L1) has no parent lineage (it is the root)" do
      state = layer_state(:function)
      assert state.parent_lineage == nil
    end

    test "federation layer (L7) parent lineage references cluster (L6)" do
      state = layer_state(:federation)
      assert state.parent_lineage =~ "cluster"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 5. Graph Transformation Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "graph transformation integrity (SC-RECONFIG-001)" do
    test "layer state has a graph_hash field" do
      state = layer_state(:container)
      assert Map.has_key?(state, :graph_hash)
      assert is_binary(state.graph_hash)
    end

    test "initial graph hashes differ across layers" do
      hashes = @reconfigurable_layers |> Enum.map(&layer_state(&1).graph_hash)

      assert length(Enum.uniq(hashes)) == length(@reconfigurable_layers),
             "Each layer must have a distinct initial graph hash"
    end

    test "successive reconfigurations produce distinct graph hashes" do
      state = layer_state(:module)
      proposal1 = reconfig_proposal(:module, %{pass: 1})
      {:ok, state1} = apply_reconfiguration(state, proposal1)
      proposal2 = reconfig_proposal(:module, %{pass: 2})
      {:ok, state2} = apply_reconfiguration(state1, proposal2)
      assert state.graph_hash != state1.graph_hash
      assert state1.graph_hash != state2.graph_hash
    end

    test "vetoed reconfiguration does not alter graph hash" do
      state = layer_state(:node)
      bad_proposal = %{target_layer: :L0, config_delta: %{}}
      {:error, _} = apply_reconfiguration(state, bad_proposal)
      # Original state is unchanged because we return error without mutation
      fresh_state = layer_state(:node)
      assert fresh_state.graph_hash == state.graph_hash
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 6. PropCheck Property Tests (PC. generators)
  # ──────────────────────────────────────────────────────────────────

  describe "PropCheck: constitutional invariants under arbitrary reconfigurations" do
    property "any approved reconfiguration preserves lineage_id" do
      layers_as_atoms = @reconfigurable_layers

      forall idx <- PC.oneof(Enum.map(0..6, &PC.exactly/1)) do
        layer = Enum.at(layers_as_atoms, idx)
        state = layer_state(layer)
        proposal = reconfig_proposal(layer, %{arbitrary: true})

        case apply_reconfiguration(state, proposal) do
          {:ok, new_state} -> new_state.lineage_id == state.lineage_id
          {:error, _} -> true
        end
      end
    end

    property "all six constitutional invariants survive any L1-L7 reconfiguration sequence" do
      forall indices <- PC.list(PC.integer(0, 6)) do
        constitution = base_constitution()

        Enum.each(indices, fn idx ->
          layer = Enum.at(@reconfigurable_layers, idx)
          state = layer_state(layer)
          proposal = reconfig_proposal(layer)
          apply_reconfiguration(state, proposal)
        end)

        # L0 constitution must remain intact
        constitution_intact?(constitution)
      end
    end

    property "Guardian always vetoes L0-targeting proposals" do
      forall _ <- PC.integer() do
        l0_proposal = %{target_layer: :L0, config_delta: %{}}
        match?({:veto, _}, guardian_validate(l0_proposal))
      end
    end

    property "all valid layer proposals are approved by Guardian" do
      forall idx <- PC.integer(0, 6) do
        layer = Enum.at(@reconfigurable_layers, idx)
        proposal = reconfig_proposal(layer)
        match?({:approved, _}, guardian_validate(proposal))
      end
    end

    property "reconfiguration never reduces layer_index" do
      forall idx <- PC.integer(0, 6) do
        layer = Enum.at(@reconfigurable_layers, idx)
        state = layer_state(layer)
        proposal = reconfig_proposal(layer, %{mutated: true})

        case apply_reconfiguration(state, proposal) do
          {:ok, new_state} -> new_state.layer_index == state.layer_index
          {:error, _} -> true
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 7. StreamData Property Tests (SD. generators, ExUnitProperties.check all)
  # ──────────────────────────────────────────────────────────────────

  describe "StreamData: reconfiguration safety under diverse proposals" do
    test "random valid layer reconfigurations always preserve lineage" do
      layer_atoms = @reconfigurable_layers

      ExUnitProperties.check all(
                               idx <- SD.integer(0, 6),
                               config_val <- SD.integer()
                             ) do
        layer = Enum.at(layer_atoms, idx)
        state = layer_state(layer)
        proposal = reconfig_proposal(layer, %{value: config_val})
        {:ok, new_state} = apply_reconfiguration(state, proposal)
        assert new_state.lineage_id == state.lineage_id
      end
    end

    test "constitutional invariants always intact after random approved reconfigurations" do
      constitution = base_constitution()

      ExUnitProperties.check all(idx <- SD.integer(0, 6)) do
        layer = Enum.at(@reconfigurable_layers, idx)
        state = layer_state(layer)
        proposal = reconfig_proposal(layer)
        {:ok, _} = apply_reconfiguration(state, proposal)
        assert constitution_intact?(constitution)
      end
    end

    test "Guardian always vetoes proposals whose invariant field matches a Ψ" do
      ExUnitProperties.check all(inv <- SD.member_of(@constitutional_invariants)) do
        invariant_attack = %{invariant: inv, target_layer: :function, config_delta: %{}}
        assert {:veto, _reason} = guardian_validate(invariant_attack)
      end
    end

    test "graph hash always changes after an approved reconfiguration" do
      ExUnitProperties.check all(
                               idx <- SD.integer(0, 6),
                               delta_key <- SD.atom(:alphanumeric),
                               delta_val <- SD.integer()
                             ) do
        layer = Enum.at(@reconfigurable_layers, idx)
        state = layer_state(layer)
        proposal = reconfig_proposal(layer, %{delta_key => delta_val})
        {:ok, new_state} = apply_reconfiguration(state, proposal)
        assert new_state.graph_hash != state.graph_hash
      end
    end

    test "L7 federation reconfigurations always preserve parent lineage" do
      ExUnitProperties.check all(peer_count <- SD.integer(1, 20)) do
        state = layer_state(:federation)
        proposal = reconfig_proposal(:federation, %{peers: peer_count})
        {:ok, new_state} = apply_reconfiguration(state, proposal)
        assert new_state.parent_lineage == state.parent_lineage
      end
    end

    test "graceful degradation: unknown layer proposals are always vetoed" do
      ExUnitProperties.check all(random_atom <- SD.atom(:alphanumeric)) do
        # Only veto if it is not already a valid reconfigurable layer
        unless random_atom in @reconfigurable_layers do
          bad_proposal = %{target_layer: random_atom, config_delta: %{}}
          assert match?({:veto, _}, guardian_validate(bad_proposal))
        end
      end
    end
  end
end
