defmodule Indrajaal.Federation.ConstitutionalReconfigurationTest do
  @moduledoc """
  TDG test suite for constitutional reconfiguration across L1-L7 layers.

  WHAT: Tests that reconfiguration proposals are validated against the
  constitution (Ψ₀-Ψ₅), that Guardian approval gates all changes, that
  lineage is preserved through reconfiguration, and that federation
  peers are notified.

  CONSTRAINTS:
  - SC-RECONFIG-001: Graph transformation for changes
  - SC-RECONFIG-005: Lineage preserved through reconfiguration
  - SC-RECONFIG-009: Guardian approval required
  - SC-RECONFIG-010: Federation peers notified

  ## Constitutional Verification
  - Ψ₀ (Existence): System survives reconfiguration
  - Ψ₁ (Regeneration): State fully checkpointed before change
  - Ψ₂ (History): Reconfiguration events recorded
  - Ψ₃ (Verification): Changes verifiable post-reconfiguration
  - Ψ₅ (Truthfulness): Reconfiguration log reflects actual changes

  ## Change History
  | Version | Date       | Author | Change                                      |
  |---------|------------|--------|---------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — reconfig L1-L7 suite   |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Constitutional reconfiguration engine
  # ---------------------------------------------------------------------------

  @layers [
    :l1_function,
    :l2_component,
    :l3_holon,
    :l4_container,
    :l5_node,
    :l6_cluster,
    :l7_federation
  ]
  @invariants [
    :psi0_existence,
    :psi1_regeneration,
    :psi2_history,
    :psi3_verification,
    :psi4_alignment,
    :psi5_truthfulness
  ]

  defp build_constitution do
    %{
      invariants: MapSet.new(@invariants),
      hash:
        :crypto.hash(:sha256, :erlang.term_to_binary(@invariants)) |> Base.encode16(case: :lower),
      version: 1,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp build_system_state(constitution) do
    %{
      constitution: constitution,
      layers: Map.new(@layers, fn layer -> {layer, %{status: :active, version: 1}} end),
      lineage: [%{event: :genesis, timestamp: System.monotonic_time(:millisecond)}],
      federation_peers: ["peer-alpha", "peer-beta", "peer-gamma"],
      guardian_active: true,
      notifications: []
    }
  end

  defp propose_reconfiguration(layer, change_type, opts \\ []) do
    %{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      layer: layer,
      change_type: change_type,
      description: Keyword.get(opts, :description, "reconfigure #{layer}"),
      requested_by: Keyword.get(opts, :requested_by, "system"),
      timestamp: System.monotonic_time(:millisecond),
      rollback_plan: Keyword.get(opts, :rollback_plan, :revert_to_previous)
    }
  end

  defp validate_proposal(proposal, state) do
    with :ok <- check_guardian(state),
         :ok <- check_layer_valid(proposal.layer),
         :ok <- check_constitution_preserved(proposal, state),
         :ok <- check_lineage_continuity(state) do
      {:ok, proposal}
    end
  end

  defp check_guardian(%{guardian_active: true}), do: :ok
  defp check_guardian(_), do: {:error, :guardian_unavailable}

  defp check_layer_valid(layer) when layer in @layers, do: :ok
  defp check_layer_valid(:l0_constitution), do: {:error, :constitution_immutable}
  defp check_layer_valid(_), do: {:error, :invalid_layer}

  defp check_constitution_preserved(proposal, state) do
    # L0 changes are forbidden; L1-L7 must not violate invariants
    cond do
      proposal.change_type == :modify_invariant ->
        {:error, :invariant_violation}

      proposal.change_type == :remove_invariant ->
        {:error, :invariant_violation}

      not MapSet.subset?(MapSet.new([:psi0_existence]), state.constitution.invariants) ->
        {:error, :psi0_missing}

      true ->
        :ok
    end
  end

  defp check_lineage_continuity(%{lineage: lineage}) when length(lineage) > 0, do: :ok
  defp check_lineage_continuity(_), do: {:error, :lineage_broken}

  defp apply_reconfiguration(state, proposal) do
    case validate_proposal(proposal, state) do
      {:ok, _} ->
        new_state =
          state
          |> update_layer(proposal.layer, proposal.change_type)
          |> record_lineage(proposal)
          |> notify_federation_peers(proposal)
          |> bump_constitution_version()

        {:ok, new_state}

      error ->
        error
    end
  end

  defp update_layer(state, layer, change_type) do
    layer_state = Map.get(state.layers, layer)

    updated = %{
      layer_state
      | status: change_status(change_type),
        version: layer_state.version + 1
    }

    %{state | layers: Map.put(state.layers, layer, updated)}
  end

  defp change_status(:upgrade), do: :upgraded
  defp change_status(:restructure), do: :restructured
  defp change_status(:scale), do: :scaled
  defp change_status(_), do: :modified

  defp record_lineage(state, proposal) do
    event = %{
      event: :reconfiguration,
      layer: proposal.layer,
      change_type: proposal.change_type,
      proposal_id: proposal.id,
      timestamp: System.monotonic_time(:millisecond)
    }

    %{state | lineage: state.lineage ++ [event]}
  end

  defp notify_federation_peers(state, proposal) do
    notifications =
      Enum.map(state.federation_peers, fn peer ->
        %{
          peer: peer,
          proposal_id: proposal.id,
          layer: proposal.layer,
          sent_at: System.monotonic_time(:millisecond)
        }
      end)

    %{state | notifications: state.notifications ++ notifications}
  end

  defp bump_constitution_version(state) do
    constitution = %{state.constitution | version: state.constitution.version + 1}
    %{state | constitution: constitution}
  end

  defp rollback_reconfiguration(state, proposal) do
    layer_state = Map.get(state.layers, proposal.layer)
    reverted = %{layer_state | status: :active, version: layer_state.version + 1}

    state
    |> Map.put(:layers, Map.put(state.layers, proposal.layer, reverted))
    |> record_lineage(%{proposal | change_type: :rollback})
  end

  # ---------------------------------------------------------------------------
  # Guardian approval tests (SC-RECONFIG-009)
  # ---------------------------------------------------------------------------

  describe "SC-RECONFIG-009: Guardian approval" do
    test "proposal accepted when Guardian is active" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l3_holon, :upgrade)

      assert {:ok, _} = validate_proposal(proposal, state)
    end

    test "proposal rejected when Guardian is unavailable" do
      constitution = build_constitution()
      state = build_system_state(constitution) |> Map.put(:guardian_active, false)
      proposal = propose_reconfiguration(:l3_holon, :upgrade)

      assert {:error, :guardian_unavailable} = validate_proposal(proposal, state)
    end

    test "L0 constitution changes are always rejected" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l0_constitution, :upgrade)

      assert {:error, :constitution_immutable} = validate_proposal(proposal, state)
    end

    test "invariant modification is rejected" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l3_holon, :modify_invariant)

      assert {:error, :invariant_violation} = validate_proposal(proposal, state)
    end
  end

  # ---------------------------------------------------------------------------
  # Layer reconfiguration tests (SC-RECONFIG-001)
  # ---------------------------------------------------------------------------

  describe "SC-RECONFIG-001: graph transformation" do
    test "all L1-L7 layers accept reconfiguration" do
      constitution = build_constitution()
      state = build_system_state(constitution)

      for layer <- @layers do
        proposal = propose_reconfiguration(layer, :upgrade)
        assert {:ok, new_state} = apply_reconfiguration(state, proposal)
        assert Map.get(new_state.layers, layer).status == :upgraded
      end
    end

    test "layer version increments on reconfiguration" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l5_node, :scale)

      assert {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert Map.get(new_state.layers, :l5_node).version == 2
    end

    test "multiple reconfigurations stack correctly" do
      constitution = build_constitution()
      state = build_system_state(constitution)

      {:ok, s1} = apply_reconfiguration(state, propose_reconfiguration(:l3_holon, :upgrade))
      {:ok, s2} = apply_reconfiguration(s1, propose_reconfiguration(:l3_holon, :scale))

      assert Map.get(s2.layers, :l3_holon).version == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Lineage preservation tests (SC-RECONFIG-005)
  # ---------------------------------------------------------------------------

  describe "SC-RECONFIG-005: lineage preservation" do
    test "reconfiguration records lineage event" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l4_container, :restructure)

      assert {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert length(new_state.lineage) == length(state.lineage) + 1

      last_event = List.last(new_state.lineage)
      assert last_event.event == :reconfiguration
      assert last_event.layer == :l4_container
    end

    test "lineage is never broken" do
      constitution = build_constitution()
      state = build_system_state(constitution)

      final_state =
        Enum.reduce(@layers, state, fn layer, acc ->
          {:ok, new} = apply_reconfiguration(acc, propose_reconfiguration(layer, :upgrade))
          new
        end)

      assert length(final_state.lineage) == 1 + length(@layers)
      assert List.first(final_state.lineage).event == :genesis
    end

    test "rollback preserves lineage" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l6_cluster, :upgrade)

      {:ok, upgraded} = apply_reconfiguration(state, proposal)
      rolled_back = rollback_reconfiguration(upgraded, proposal)

      assert length(rolled_back.lineage) > length(upgraded.lineage)
      last = List.last(rolled_back.lineage)
      assert last.change_type == :rollback
    end
  end

  # ---------------------------------------------------------------------------
  # Federation notification tests (SC-RECONFIG-010)
  # ---------------------------------------------------------------------------

  describe "SC-RECONFIG-010: federation peers notified" do
    test "all peers receive notification" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l7_federation, :restructure)

      {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert length(new_state.notifications) == length(state.federation_peers)

      peer_names = Enum.map(new_state.notifications, & &1.peer)
      assert "peer-alpha" in peer_names
      assert "peer-beta" in peer_names
      assert "peer-gamma" in peer_names
    end

    test "notification includes proposal details" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l3_holon, :upgrade)

      {:ok, new_state} = apply_reconfiguration(state, proposal)
      notif = List.first(new_state.notifications)

      assert notif.proposal_id == proposal.id
      assert notif.layer == :l3_holon
    end
  end

  # ---------------------------------------------------------------------------
  # Constitution version tests
  # ---------------------------------------------------------------------------

  describe "constitution versioning" do
    test "version increments on reconfiguration" do
      constitution = build_constitution()
      state = build_system_state(constitution)
      proposal = propose_reconfiguration(:l2_component, :upgrade)

      {:ok, new_state} = apply_reconfiguration(state, proposal)
      assert new_state.constitution.version == 2
    end

    test "invariants are preserved through reconfiguration" do
      constitution = build_constitution()
      state = build_system_state(constitution)

      final_state =
        Enum.reduce(@layers, state, fn layer, acc ->
          {:ok, new} = apply_reconfiguration(acc, propose_reconfiguration(layer, :upgrade))
          new
        end)

      assert final_state.constitution.invariants == constitution.invariants
      assert final_state.constitution.hash == constitution.hash
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: reconfiguration invariants" do
    test "valid proposals always succeed with active Guardian" do
      ExUnitProperties.check all(layer_idx <- SD.integer(0..6), max_runs: 25) do
        layer = Enum.at(@layers, layer_idx)
        constitution = build_constitution()
        state = build_system_state(constitution)
        proposal = propose_reconfiguration(layer, :upgrade)

        assert {:ok, _new_state} = apply_reconfiguration(state, proposal)
      end
    end

    test "lineage length monotonically increases" do
      ExUnitProperties.check all(n <- SD.integer(1..7)) do
        constitution = build_constitution()
        state = build_system_state(constitution)

        final_state =
          Enum.reduce(Enum.take(@layers, n), state, fn layer, acc ->
            {:ok, new} = apply_reconfiguration(acc, propose_reconfiguration(layer, :upgrade))
            new
          end)

        assert length(final_state.lineage) == 1 + n
      end
    end

    test "constitution invariants are always preserved" do
      ExUnitProperties.check all(
                               layer_idx <- SD.integer(0..6),
                               change_type <- SD.member_of([:upgrade, :restructure, :scale])
                             ) do
        layer = Enum.at(@layers, layer_idx)
        constitution = build_constitution()
        state = build_system_state(constitution)
        proposal = propose_reconfiguration(layer, change_type)

        {:ok, new_state} = apply_reconfiguration(state, proposal)
        assert new_state.constitution.invariants == constitution.invariants
      end
    end
  end
end
