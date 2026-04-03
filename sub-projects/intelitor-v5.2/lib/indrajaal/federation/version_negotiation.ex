defmodule Indrajaal.Federation.VersionNegotiation do
  @moduledoc """
  Protocol Version Negotiation for Federation.

  ## WHAT
  Handles capability exchange and protocol versioning between holons.

  ## WHY
  Allows the federation to evolve heterogeneously, with different nodes
  running different versions of the software while maintaining compatibility.
  """

  require Logger

  @supported_versions ["1.0", "1.1", "2.0"]

  @doc """
  Negotiate common protocol version with a peer.
  """
  def negotiate(peer_versions) do
    common =
      MapSet.intersection(
        MapSet.new(@supported_versions),
        MapSet.new(peer_versions)
      )

    case Enum.max(common, fn -> nil end) do
      nil -> {:error, :no_common_version}
      version -> {:ok, version}
    end
  end
end
