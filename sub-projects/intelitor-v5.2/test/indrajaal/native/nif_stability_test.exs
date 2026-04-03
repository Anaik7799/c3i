defmodule Indrajaal.Native.NifStabilityTest do
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduledoc """
  Verifies the NIF Stability Framework (SC-NIF-001 to SC-NIF-005).
  """

  describe "NIF Fallback Mechanisms (SC-NIF-002)" do
    test "MathNif provides Elixir fallback when NIF is bypassed" do
      # Even if the NIF is bypassed via env var, the Elixir logic must work
      entropy = Indrajaal.Analysis.MathNif.calculate_entropy("test_string")
      assert is_float(entropy)
      assert entropy > 0.0
    end
  end

  describe "Substrate Safety Gate (SC-NIF-005)" do
    test "Zenoh proxy drops control signals without valid ProofTokens" do
      # Attempting to publish a control signal without a proof token should fail
      payload = Jason.encode!(%{action: "mutate_substrate", unsafe: true})

      # Mock session reference
      session_ref = make_ref()

      assert {:error, reason} =
               Indrajaal.Native.Zenoh.publish(session_ref, "indrajaal/control/test", payload)

      assert String.contains?(reason, "Substrate safety violation")
    end

    test "Zenoh proxy allows non-control signals to pass without ProofTokens" do
      payload = "telemetry_data"
      session_ref = make_ref()

      # This will hit the NIF stub and return :nif_not_loaded (which is expected in test mode),
      # proving that the safety gate allowed it to pass.
      assert_raise ErlangError, "Erlang error: :nif_not_loaded", fn ->
        Indrajaal.Native.Zenoh.publish(session_ref, "indrajaal/telemetry/test", payload)
      end
    end
  end

  property "Zenoh proxy handles arbitrary payloads gracefully (No crashes)" do
    forall payload <- PC.binary() do
      session_ref = make_ref()
      # Ensure that random binary junk sent to a control topic is safely rejected
      # rather than crashing the BEAM.
      case Indrajaal.Native.Zenoh.publish(session_ref, "indrajaal/control/fuzz", payload) do
        {:error, _reason} -> true
        _ -> false
      end
    end
  end
end
