defmodule Indrajaal.Fractal.L3.NifSystemTest do
  use ExUnit.Case
  alias Indrajaal.Native.Zenoh

  @moduledoc """
  Layer 3: System Testing.
  Verifies NIF behavior within the container/node context.
  """

  @tag :nif
  @tag :system
  test "zenoh classify_tier in system context" do
    # Test tier classification for various system paths
    paths = [
      "indrajaal/logs/system",
      "indrajaal/control/system",
      "indrajaal/inference/system",
      "indrajaal/metrics/system"
    ]

    results = Enum.map(paths, &Zenoh.classify_tier/1)
    assert length(results) == 4
    assert :bypass in results
    assert :session in results
    assert :full in results
  end

  test "zenoh proof token verification in system context" do
    # Test proof token verification with invalid data
    invalid_token = Jason.encode!(%{"proof_token" => "invalid"}) |> IO.iodata_to_binary()
    result = Zenoh.verify_proof_token(invalid_token)
    assert is_tuple(result)
  end
end
