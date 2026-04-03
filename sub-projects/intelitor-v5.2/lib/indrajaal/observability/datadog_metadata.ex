defmodule Indrajaal.Observability.DatadogMetadata do
  @moduledoc """
  Enhances Telemetry events with Datadog-specific tags.
  L6 Enhancement.
  """

  def tags(metadata) do
    # Standard DD tags: env, service, version
    # Custom tags: saga_id, graph_nodes

    base_tags = %{
      "env" => Application.get_env(:indrajaal, :env, :dev),
      "service" => "indrajaal",
      "version" => Application.spec(:indrajaal, :vsn)
    }

    specific_tags =
      case metadata do
        %{saga_name: name} -> %{"saga.name" => name}
        %{nodes: n} -> %{"graph.nodes" => n}
        _ -> %{}
      end

    Map.merge(base_tags, specific_tags)
  end
end
