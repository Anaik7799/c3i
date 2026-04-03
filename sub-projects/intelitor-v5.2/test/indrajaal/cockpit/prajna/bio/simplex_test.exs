defmodule Indrajaal.Cockpit.Prajna.Bio.SimplexTest do
  use ExUnit.Case
  @moduletag :zenoh_nif
  use PropCheck
  alias Indrajaal.Cockpit.Prajna.Bio.Membrane
  alias Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload
  alias PropCheck.BasicTypes, as: PC

  # Mock Target Process
  defmodule MockNucleus do
    use GenServer
    def start_link, do: GenServer.start_link(__MODULE__, [], [])
    def init(_), do: {:ok, []}

    def handle_cast(msg, state) do
      send(:test_receiver, {:received, msg})
      {:noreply, state}
    end
  end

  setup do
    Process.register(self(), :test_receiver)
    {:ok, nucleus} = MockNucleus.start_link()
    {:ok, membrane} = Membrane.start_link(target: nucleus, name: :test_membrane)
    %{membrane: membrane}
  end

  test "SC-BIO-002: Membrane rejects non-genetic payloads", %{membrane: membrane} do
    # Poison Pill
    GenServer.cast(membrane, %{bad: "data"})

    refute_receive {:received, _}, 100
  end

  test "SC-BIO-002: Membrane accepts valid genetic payloads", %{membrane: membrane} do
    payload = %GeneticPayload{
      id: "123",
      timestamp: DateTime.utc_now(),
      genome_hash: "v1",
      dna: :valid_data
    }

    GenServer.cast(membrane, payload)

    assert_receive {:received, :valid_data}, 100
  end

  test "SC-IMMUNE-001: Compromised membrane rejects all messages", %{membrane: membrane} do
    # Antibody tags the membrane with :compromised (the tag that membrane checks for)
    GenServer.cast(membrane, {:immune_tag, :compromised})

    # Synchronize: ensure the immune_tag cast is processed before sending payload
    # GenServer processes messages in order, so a call after the cast ensures the cast completed
    _health = Membrane.health(membrane)

    payload = %GeneticPayload{dna: :valid_data}
    GenServer.cast(membrane, payload)

    refute_receive {:received, :valid_data}, 100
  end

  describe "property tests" do
    property "genetic payload DNA field is always preserved as atom" do
      forall payload_atom <- PC.atom() do
        payload = %GeneticPayload{
          id: "test",
          timestamp: DateTime.utc_now(),
          genome_hash: "v1",
          dna: payload_atom
        }

        is_atom(payload.dna) and payload.dna == payload_atom
      end
    end

    property "membrane health state is always a valid atom" do
      forall _value <- PC.integer() do
        unique_id = System.unique_integer([:positive, :monotonic])

        {:ok, membrane} =
          Membrane.start_link(target: self(), name: :"test_mem_prop_#{unique_id}")

        # health/1 returns %{status: atom(), metrics: map()}
        health_result = Membrane.health(membrane)
        status = health_result.status
        result = is_atom(status) and status in [:healthy, :degraded, :critical, :compromised]

        # Cleanup to prevent process accumulation
        GenServer.stop(membrane, :normal, 100)

        result
      end
    end

    property "casting identical payloads multiple times is idempotent" do
      forall count <- PC.integer(1, 5) do
        unique_id = System.unique_integer([:positive, :monotonic])

        # Create membrane that sends to self() (already registered as :test_receiver from setup)
        {:ok, membrane} =
          Membrane.start_link(target: self(), name: :"idempotent_prop_#{unique_id}")

        payload = %GeneticPayload{
          id: "test_#{unique_id}",
          timestamp: DateTime.utc_now(),
          genome_hash: "v1",
          dna: :test_data
        }

        # Get initial health to establish baseline
        health_before = Membrane.health(membrane)

        # Send payload multiple times
        Enum.each(1..count, fn _ -> GenServer.cast(membrane, payload) end)

        # Wait for async processing
        Process.sleep(20)

        # Get health after - membrane should remain healthy (idempotent operation)
        health_after = Membrane.health(membrane)

        # Cleanup
        GenServer.stop(membrane, :normal, 100)

        # Property: sending multiple identical payloads doesn't degrade membrane health
        health_before.status == :healthy and health_after.status == :healthy
      end
    end
  end
end
