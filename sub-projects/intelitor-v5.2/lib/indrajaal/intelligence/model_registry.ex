defmodule Indrajaal.Intelligence.ModelRegistry do
  @moduledoc """
  Federated Model Registry.
  STAMP: SC-AI-005
  """
  def register_model(name, version, weights_hash) do
    {:ok, %{name: name, version: version, hash: weights_hash}}
  end
end
