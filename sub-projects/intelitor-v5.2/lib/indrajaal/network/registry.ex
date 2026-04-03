defmodule Indrajaal.Network.Registry do
  @moduledoc """
  Single Source of Truth for biomorphic node identities and FQDNs.
  Resolves logical identifiers to Tailscale addresses.
  """

  @registry_path "data/secrets/identity_registry.json"

  def get_node(node_key) do
    with {:ok, body} <- File.read(@registry_path),
         {:ok, registry} <- Jason.decode(body) do
      node = registry["nodes"][to_string(node_key)]
      if node, do: {:ok, node}, else: {:error, :not_found}
    else
      err -> err
    end
  end

  def get_fqdn(node_key) do
    case get_node(node_key) do
      {:ok, %{"fqdn" => fqdn}} -> fqdn
      _ -> "#{node_key}.local"
    end
  end

  def get_id(node_key) do
    case get_node(node_key) do
      {:ok, %{"id" => id}} -> id
      _ -> to_string(node_key)
    end
  end

  def list_nodes do
    with {:ok, body} <- File.read(@registry_path),
         {:ok, registry} <- Jason.decode(body) do
      {:ok, registry["nodes"]}
    else
      err -> err
    end
  end
end
