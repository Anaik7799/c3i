defmodule Indrajaal.Formal.PropertyVerifier do
  @moduledoc """
  Property Verifier — L7 Formal Layer

  ## Design Intent
  Verifies system properties using lightweight formal methods. Combines
  runtime assertion checking with statistical property testing concepts
  to provide confidence in system correctness without full theorem proving.

  Properties are expressed as universally quantified predicates over system
  state. The verifier samples system state periodically and checks all
  registered properties, building a statistical confidence measure.

  ## STAMP Constraints
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-VALID-001: STAMP references for every validated action
  - SC-MATH-001: Discipline health monitored
  - SC-CV-001: Coverage validation framework

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :property_verifier
  @sample_interval_ms 10_000
  @pubsub_topic "formal:properties"
  @confidence_threshold 0.95
  @max_history 100

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type property_id :: atom()
  @type property_fn :: (-> boolean())
  @type confidence :: float()

  @type property :: %{
          id: property_id(),
          description: String.t(),
          check_fn: property_fn(),
          samples: non_neg_integer(),
          successes: non_neg_integer(),
          confidence: confidence(),
          last_checked: non_neg_integer() | nil,
          history: [boolean()]
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a property to be verified."
  @spec register_property(property_id(), String.t(), property_fn()) :: :ok
  def register_property(id, description, check_fn)
      when is_atom(id) and is_function(check_fn, 0) do
    GenServer.call(@name, {:register, id, description, check_fn})
  end

  @doc "Unregister a property."
  @spec unregister_property(property_id()) :: :ok
  def unregister_property(id) do
    GenServer.call(@name, {:unregister, id})
  end

  @doc "Get confidence level for a property."
  @spec confidence(property_id()) :: {:ok, confidence()} | {:error, :not_found}
  def confidence(id) do
    case :ets.lookup(@table, id) do
      [{^id, prop}] -> {:ok, prop.confidence}
      [] -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @doc "Get all properties with their confidence levels."
  @spec all_properties() :: [map()]
  def all_properties do
    GenServer.call(@name, :all_properties)
  end

  @doc "Force an immediate verification round."
  @spec verify_now() :: map()
  def verify_now do
    GenServer.call(@name, :verify_now, 30_000)
  end

  @doc "Returns properties below confidence threshold."
  @spec low_confidence_properties() :: [map()]
  def low_confidence_properties do
    GenServer.call(@name, :low_confidence)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :sample_interval_ms, @sample_interval_ms)

    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    schedule_sample(interval)

    Logger.info(
      "[PropertyVerifier] Started — interval=#{interval}ms threshold=#{@confidence_threshold} [SC-VER-074]"
    )

    {:ok, %{sample_interval_ms: interval, round_count: 0}}
  end

  @impl true
  def handle_call({:register, id, description, check_fn}, _from, state) do
    prop = %{
      id: id,
      description: description,
      check_fn: check_fn,
      samples: 0,
      successes: 0,
      confidence: 0.0,
      last_checked: nil,
      history: []
    }

    :ets.insert(@table, {id, prop})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, id}, _from, state) do
    :ets.delete(@table, id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:all_properties, _from, state) do
    props =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, p} -> Map.drop(p, [:check_fn, :history]) end)
      |> Enum.sort_by(& &1.confidence)

    {:reply, props, state}
  end

  @impl true
  def handle_call(:verify_now, _from, state) do
    results = run_verification_round()
    {:reply, results, %{state | round_count: state.round_count + 1}}
  end

  @impl true
  def handle_call(:low_confidence, _from, state) do
    props =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_id, p} -> p.confidence < @confidence_threshold and p.samples > 0 end)
      |> Enum.map(fn {_id, p} -> Map.drop(p, [:check_fn, :history]) end)

    {:reply, props, state}
  end

  @impl true
  def handle_info(:sample, state) do
    run_verification_round()
    schedule_sample(state.sample_interval_ms)
    {:noreply, %{state | round_count: state.round_count + 1}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp run_verification_round do
    now = System.system_time(:millisecond)

    results =
      :ets.tab2list(@table)
      |> Enum.map(fn {id, prop} ->
        passed =
          try do
            prop.check_fn.() == true
          rescue
            _ -> false
          end

        samples = prop.samples + 1
        successes = if passed, do: prop.successes + 1, else: prop.successes
        confidence = successes / max(samples, 1)
        history = Enum.take([passed | prop.history], @max_history)

        updated = %{
          prop
          | samples: samples,
            successes: successes,
            confidence: Float.round(confidence, 4),
            last_checked: now,
            history: history
        }

        :ets.insert(@table, {id, updated})

        if not passed and prop.confidence >= @confidence_threshold do
          broadcast_confidence_drop(prop.id, prop.confidence, confidence)
        end

        %{id: id, passed: passed, confidence: Float.round(confidence, 4)}
      end)

    total = length(results)
    passed = Enum.count(results, & &1.passed)

    emit_round_telemetry(total, passed)

    %{total: total, passed: passed, failed: total - passed, results: results}
  end

  defp broadcast_confidence_drop(id, old_conf, new_conf) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:confidence_drop,
       %{property_id: id, old: Float.round(old_conf, 4), new: Float.round(new_conf, 4)}}
    )
  rescue
    _ -> :ok
  end

  defp emit_round_telemetry(total, passed) do
    :telemetry.execute(
      [:indrajaal, :formal, :property_verifier, :round],
      %{total: total, passed: passed, failed: total - passed},
      %{}
    )
  rescue
    _ -> :ok
  end

  defp schedule_sample(interval) do
    Process.send_after(self(), :sample, interval)
  end
end
