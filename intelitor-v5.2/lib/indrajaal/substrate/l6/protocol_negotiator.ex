defmodule Indrajaal.Substrate.L6.ProtocolNegotiator do
  @moduledoc """
  ## Design Intent
  L6 Protocol Negotiator — pure module implementing communication protocol version
  negotiation between federation peers in the Indrajaal biomorphic mesh.

  Protocol negotiation follows a capability-intersection model:
    - Each peer advertises a set of supported protocol versions
    - Negotiation finds the highest mutually-supported version
    - Upgrade paths are computed when peers have version gaps
    - Incompatible peers are rejected with a diagnostic reason

  Supported protocol families:
    - :zenoh       — Zenoh IPC versions
    - :mesh        — Mesh control-plane versions
    - :federation  — Cross-holon federation protocol versions
    - :telemetry   — Telemetry/OTEL protocol versions

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions
  - SC-FED-003: Detect constitution divergence — protocol mismatches logged
  - SC-FED-006: Attestation Ed25519-verified — protocol identity checked
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  require Logger

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type protocol_family :: :zenoh | :mesh | :federation | :telemetry

  @type version :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @type capabilities :: %{
          protocol_family() => [version()]
        }

  @type negotiation_result ::
          {:ok, protocol_family(), version()}
          | {:error, :incompatible}
          | {:error, :empty_capabilities}

  @type upgrade_step :: %{
          from: version(),
          to: version(),
          breaking: boolean(),
          migration_required: boolean()
        }

  # ---------------------------------------------------------------------------
  # Module-level supported versions
  # ---------------------------------------------------------------------------

  @supported_versions %{
    zenoh: [{1, 7, 0}, {1, 6, 0}, {1, 5, 0}],
    mesh: [{3, 0, 0}, {2, 4, 0}, {2, 3, 0}],
    federation: [{2, 1, 0}, {2, 0, 0}, {1, 9, 0}],
    telemetry: [{1, 4, 0}, {1, 3, 0}, {1, 2, 0}]
  }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Negotiate the best common protocol between local capabilities and a remote peer's
  capabilities. Returns `{:ok, family, version}` for the highest common version found,
  or `{:error, :incompatible}` when no intersection exists.
  """
  @spec negotiate(capabilities(), capabilities()) :: negotiation_result()
  def negotiate(local_caps, remote_caps)
      when is_map(local_caps) and is_map(remote_caps) do
    if map_size(local_caps) == 0 or map_size(remote_caps) == 0 do
      {:error, :empty_capabilities}
    else
      best =
        local_caps
        |> Enum.flat_map(fn {family, local_versions} ->
          remote_versions = Map.get(remote_caps, family, [])
          common = intersection(local_versions, remote_versions)

          Enum.map(common, fn version -> {family, version} end)
        end)
        |> Enum.sort_by(fn {_family, version} -> version end, :desc)
        |> List.first()

      case best do
        nil -> {:error, :incompatible}
        {family, version} -> {:ok, family, version}
      end
    end
  end

  @doc """
  Check whether two capability sets are compatible (have at least one common
  protocol version in any family).
  """
  @spec compatible?(capabilities(), capabilities()) :: boolean()
  def compatible?(local_caps, remote_caps) do
    case negotiate(local_caps, remote_caps) do
      {:ok, _, _} -> true
      _ -> false
    end
  end

  @doc """
  Compute the upgrade path from `from_version` to `to_version` within a protocol family.
  Returns an ordered list of upgrade steps, or `[]` if already at target or path unknown.
  """
  @spec upgrade_path(protocol_family(), version()) :: [upgrade_step()]
  def upgrade_path(family, from_version) do
    versions = Map.get(@supported_versions, family, [])

    case versions do
      [] ->
        []

      all ->
        sorted = Enum.sort(all, :asc)
        above = Enum.filter(sorted, fn v -> v > from_version end)

        above
        |> Enum.with_index()
        |> Enum.map(fn {v, idx} ->
          prev = if idx == 0, do: from_version, else: Enum.at(above, idx - 1)
          {major_prev, _, _} = prev
          {major_v, _, _} = v

          %{
            from: prev,
            to: v,
            breaking: major_v > major_prev,
            migration_required: major_v > major_prev
          }
        end)
    end
  end

  @doc """
  Return all protocol versions supported by this local node, grouped by family.
  """
  @spec supported_versions() :: capabilities()
  def supported_versions, do: @supported_versions

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec intersection([version()], [version()]) :: [version()]
  defp intersection(list_a, list_b) do
    set_b = MapSet.new(list_b)
    Enum.filter(list_a, &MapSet.member?(set_b, &1))
  end
end
