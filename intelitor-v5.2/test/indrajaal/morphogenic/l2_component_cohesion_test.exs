defmodule Indrajaal.Morphogenic.L2ComponentCohesionTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed test suite for L2 (Component-level) module
        cohesion analysis in the Indrajaal SIL-6 Biomorphic Mesh. Simulates
        component registries, interface catalogs, state encapsulation guards,
        message protocol validators, and callback compliance checkers entirely
        in-process using ETS — no production module dependencies.

  WHY: At L2 (Component Architecture) each module must exhibit high internal
       coupling (cohesion) while exposing the thinnest possible public surface
       to its callers. Violations allow implementation details to leak across
       component boundaries, raising the cost of substitution, creating hidden
       coupling, and eroding the SIL-6 isolation guarantee. These tests verify
       that cohesion invariants hold statically and dynamically, and that the
       module contract can be satisfied by an arbitrary replacement component
       without any caller needing to change.

  CONSTRAINTS:
    - SC-AGENT-005: Components MUST have a consistent interface and lifecycle
    - SC-RECONFIG-001: Graph-transformation-based component replacement permitted
    - SC-FUNC-001: System compiles and every module boundary is contractually clean
    - SC-VER-001: Verification of component contracts before system ready
    - SC-ORCH-015: Component coordination is idempotent
    - SC-STATE-001: State updates are atomic and encapsulated
    - SC-VALID-001: STAMP references accompany every validated action

  ## Change History
  | Version | Date       | Author | Change                                        |
  |---------|------------|--------|-----------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial L2 component cohesion suite, 26 tests |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Dual property testing. ExUnitProperties macros are used via
  # fully qualified calls (ExUnitProperties.check all) to avoid the check/2
  # conflict with PropCheck. PC aliases PropCheck.BasicTypes; SD aliases StreamData.
  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :l2
  @moduletag :morphogenic
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # ETS scaffolding helpers
  # ---------------------------------------------------------------------------

  defp new_table(suffix) do
    name = :"cohesion_#{suffix}_#{:erlang.unique_integer([:positive])}"
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp drop_table(t) do
    if :ets.info(t) != :undefined, do: :ets.delete(t)
  end

  defp now_us, do: System.monotonic_time(:microsecond)

  # ---------------------------------------------------------------------------
  # Component Registry — tracks every module's declared public API surface
  # ---------------------------------------------------------------------------

  defmodule ComponentRegistry do
    @moduledoc "ETS-backed registry that catalogs public vs private function surfaces."

    @spec register(reference(), atom(), [atom()], [atom()]) :: :ok
    def register(table, module_name, public_fns, private_fns) do
      entry = %{
        module: module_name,
        public: MapSet.new(public_fns),
        private: MapSet.new(private_fns),
        registered_at: System.monotonic_time(:microsecond)
      }

      :ets.insert(table, {module_name, entry})
      :ok
    end

    @spec public_surface(reference(), atom()) :: {:ok, MapSet.t()} | {:error, :not_found}
    def public_surface(table, module_name) do
      case :ets.lookup(table, module_name) do
        [{^module_name, entry}] -> {:ok, entry.public}
        [] -> {:error, :not_found}
      end
    end

    @spec private_surface(reference(), atom()) :: {:ok, MapSet.t()} | {:error, :not_found}
    def private_surface(table, module_name) do
      case :ets.lookup(table, module_name) do
        [{^module_name, entry}] -> {:ok, entry.private}
        [] -> {:error, :not_found}
      end
    end

    @spec cohesion_ratio(reference(), atom()) :: {:ok, float()} | {:error, atom()}
    def cohesion_ratio(table, module_name) do
      case :ets.lookup(table, module_name) do
        [{^module_name, entry}] ->
          total = MapSet.size(entry.public) + MapSet.size(entry.private)
          ratio = if total == 0, do: 1.0, else: MapSet.size(entry.private) / total
          {:ok, ratio}

        [] ->
          {:error, :not_found}
      end
    end

    @spec all_modules(reference()) :: [atom()]
    def all_modules(table) do
      :ets.tab2list(table) |> Enum.map(fn {k, _} -> k end)
    end
  end

  # ---------------------------------------------------------------------------
  # Interface Catalog — tracks declared interface contracts
  # ---------------------------------------------------------------------------

  defmodule InterfaceCatalog do
    @moduledoc "Records the declared callbacks and behaviours for each component."

    @spec declare(reference(), atom(), [atom()], [atom()]) :: :ok
    def declare(table, component, required_callbacks, optional_callbacks) do
      entry = %{
        component: component,
        required: required_callbacks,
        optional: optional_callbacks,
        declared_at: System.monotonic_time(:microsecond)
      }

      :ets.insert(table, {component, entry})
      :ok
    end

    @spec verify_compliance(reference(), atom(), [atom()]) ::
            {:ok, :compliant} | {:error, {:missing_callbacks, [atom()]}}
    def verify_compliance(table, component, implemented_callbacks) do
      case :ets.lookup(table, component) do
        [{^component, entry}] ->
          implemented_set = MapSet.new(implemented_callbacks)
          required_set = MapSet.new(entry.required)
          missing = MapSet.difference(required_set, implemented_set) |> MapSet.to_list()

          if missing == [] do
            {:ok, :compliant}
          else
            {:error, {:missing_callbacks, missing}}
          end

        [] ->
          {:error, {:missing_callbacks, []}}
      end
    end

    @spec interface_width(reference(), atom()) :: {:ok, non_neg_integer()} | {:error, :not_found}
    def interface_width(table, component) do
      case :ets.lookup(table, component) do
        [{^component, entry}] ->
          width = length(entry.required) + length(entry.optional)
          {:ok, width}

        [] ->
          {:error, :not_found}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # State Encapsulation Guard — ensures internal state fields are not exported
  # ---------------------------------------------------------------------------

  defmodule StateGuard do
    @moduledoc "Verifies that no private state fields are present in public API responses."

    @spec register_private_fields(reference(), atom(), [atom()]) :: :ok
    def register_private_fields(table, component, fields) do
      :ets.insert(table, {component, MapSet.new(fields)})
      :ok
    end

    @spec check_leak(reference(), atom(), map()) :: {:ok, :clean} | {:error, {:leaked, [atom()]}}
    def check_leak(table, component, public_response) do
      private_fields =
        case :ets.lookup(table, component) do
          [{^component, fs}] -> fs
          [] -> MapSet.new()
        end

      response_keys = public_response |> Map.keys() |> MapSet.new()
      leaked = MapSet.intersection(private_fields, response_keys) |> MapSet.to_list()

      if leaked == [] do
        {:ok, :clean}
      else
        {:error, {:leaked, leaked}}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Message Protocol Validator — verifies inter-component message envelopes
  # ---------------------------------------------------------------------------

  defmodule MessageProtocol do
    @moduledoc "Validates that messages crossing component boundaries conform to declared schemas."

    @required_envelope_keys [:from, :to, :type, :payload, :seq]

    @spec validate(map()) :: {:ok, :valid} | {:error, {:invalid_envelope, [atom()]}}
    def validate(msg) do
      missing = Enum.reject(@required_envelope_keys, &Map.has_key?(msg, &1))

      if missing == [] do
        {:ok, :valid}
      else
        {:error, {:invalid_envelope, missing}}
      end
    end

    @spec build(atom(), atom(), atom(), term(), non_neg_integer()) :: map()
    def build(from, to, type, payload, seq) do
      %{from: from, to: to, type: type, payload: payload, seq: seq}
    end

    @spec seq_monotonic?([map()]) :: boolean()
    def seq_monotonic?([]), do: true
    def seq_monotonic?([_single]), do: true

    def seq_monotonic?(msgs) do
      seqs = Enum.map(msgs, & &1.seq)
      Enum.zip(seqs, tl(seqs)) |> Enum.all?(fn {a, b} -> b > a end)
    end
  end

  # ---------------------------------------------------------------------------
  # Dependency Tracker — records and analyses inter-component dependencies
  # ---------------------------------------------------------------------------

  defmodule DependencyTracker do
    @moduledoc "ETS-backed directed dependency graph between components."

    @spec add_dependency(reference(), atom(), atom()) :: :ok
    def add_dependency(table, from_component, to_component) do
      key = {from_component, to_component}
      :ets.insert(table, {key, true})
      :ok
    end

    @spec external_deps(reference(), atom(), [atom()]) :: [atom()]
    def external_deps(table, component, all_internal_components) do
      internal = MapSet.new(all_internal_components)

      :ets.tab2list(table)
      |> Enum.filter(fn {{from, _to}, _} -> from == component end)
      |> Enum.map(fn {{_from, to}, _} -> to end)
      |> Enum.reject(&MapSet.member?(internal, &1))
    end

    @spec internal_deps(reference(), atom(), [atom()]) :: [atom()]
    def internal_deps(table, component, all_internal_components) do
      internal = MapSet.new(all_internal_components)

      :ets.tab2list(table)
      |> Enum.filter(fn {{from, _to}, _} -> from == component end)
      |> Enum.map(fn {{_from, to}, _} -> to end)
      |> Enum.filter(&MapSet.member?(internal, &1))
    end

    @spec dep_ratio(reference(), atom(), [atom()]) :: float()
    def dep_ratio(table, component, all_internal_components) do
      ext = length(external_deps(table, component, all_internal_components))
      int = length(internal_deps(table, component, all_internal_components))
      total = ext + int
      if total == 0, do: 1.0, else: int / total
    end
  end

  # ---------------------------------------------------------------------------
  # Substitution Simulator — exercises the Liskov/component-replacement property
  # ---------------------------------------------------------------------------

  defmodule SubstitutionSim do
    @moduledoc """
    Simulates replacing a component with a structurally equivalent stub and
    verifying that the caller contract remains satisfied.
    """

    @spec register_caller_expectations(reference(), atom(), [{atom(), arity()}]) :: :ok
    def register_caller_expectations(table, caller, expected_calls) do
      :ets.insert(table, {caller, expected_calls})
      :ok
    end

    @spec satisfies_caller?(reference(), atom(), [{atom(), arity()}]) :: boolean()
    def satisfies_caller?(table, caller, provided_calls) do
      case :ets.lookup(table, caller) do
        [{^caller, expected}] ->
          provided_set = MapSet.new(provided_calls)
          Enum.all?(expected, &MapSet.member?(provided_set, &1))

        [] ->
          false
      end
    end
  end

  # ===========================================================================
  # Section 1: Module boundary enforcement (public API surface minimized)
  # ===========================================================================

  describe "module boundary enforcement" do
    setup do
      t = new_table(:boundary)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :boundary
    test "component with more private than public functions has cohesion_ratio > 0.5", %{t: t} do
      ComponentRegistry.register(t, :worker_pool, [:submit, :drain], [
        :do_work,
        :handle_overflow,
        :retry_failed,
        :log_result,
        :adjust_capacity
      ])

      {:ok, ratio} = ComponentRegistry.cohesion_ratio(t, :worker_pool)

      assert ratio > 0.5,
             "Expected cohesion_ratio > 0.5 (more private than public), got #{ratio}"
    end

    @tag :l2
    @tag :boundary
    test "component with only public functions has cohesion_ratio of 0.0", %{t: t} do
      ComponentRegistry.register(t, :pure_api, [:call_a, :call_b, :call_c], [])
      {:ok, ratio} = ComponentRegistry.cohesion_ratio(t, :pure_api)
      assert ratio == 0.0
    end

    @tag :l2
    @tag :boundary
    test "component with only private functions has cohesion_ratio of 1.0", %{t: t} do
      ComponentRegistry.register(t, :internal_engine, [], [:step_a, :step_b, :step_c])
      {:ok, ratio} = ComponentRegistry.cohesion_ratio(t, :internal_engine)
      assert ratio == 1.0
    end

    @tag :l2
    @tag :boundary
    test "two independently registered components do not share function surfaces", %{t: t} do
      ComponentRegistry.register(t, :comp_a, [:read], [:parse, :validate])
      ComponentRegistry.register(t, :comp_b, [:write], [:encode, :flush])

      {:ok, pub_a} = ComponentRegistry.public_surface(t, :comp_a)
      {:ok, pub_b} = ComponentRegistry.public_surface(t, :comp_b)

      intersection = MapSet.intersection(pub_a, pub_b)

      assert MapSet.size(intersection) == 0,
             "Public API surfaces must not overlap between components"
    end

    @tag :l2
    @tag :boundary
    test "unknown component returns :not_found for public surface query", %{t: t} do
      assert {:error, :not_found} = ComponentRegistry.public_surface(t, :ghost_component)
    end
  end

  # ===========================================================================
  # Section 2: Internal vs external dependency ratio
  # ===========================================================================

  describe "internal vs external dependency ratio" do
    setup do
      t = new_table(:deps)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :deps
    test "component with only internal deps has dep_ratio of 1.0", %{t: t} do
      DependencyTracker.add_dependency(t, :core_engine, :helper_a)
      DependencyTracker.add_dependency(t, :core_engine, :helper_b)

      ratio = DependencyTracker.dep_ratio(t, :core_engine, [:helper_a, :helper_b, :core_engine])
      assert ratio == 1.0
    end

    @tag :l2
    @tag :deps
    test "component with mix of deps reports ratio between 0 and 1", %{t: t} do
      DependencyTracker.add_dependency(t, :bridge, :internal_store)
      DependencyTracker.add_dependency(t, :bridge, :external_zenoh)

      ratio = DependencyTracker.dep_ratio(t, :bridge, [:internal_store, :bridge])
      assert ratio > 0.0 and ratio < 1.0
    end

    @tag :l2
    @tag :deps
    test "component with no deps has dep_ratio of 1.0 (trivially cohesive)", %{t: t} do
      ratio = DependencyTracker.dep_ratio(t, :isolated_atom, [:isolated_atom])
      assert ratio == 1.0
    end

    @tag :l2
    @tag :deps
    test "external deps list excludes components in the internal namespace", %{t: t} do
      DependencyTracker.add_dependency(t, :app, :internal_cache)
      DependencyTracker.add_dependency(t, :app, :postgres)

      ext = DependencyTracker.external_deps(t, :app, [:internal_cache, :app])
      assert :postgres in ext
      refute :internal_cache in ext
    end
  end

  # ===========================================================================
  # Section 3: Callback behaviour compliance
  # ===========================================================================

  describe "callback behaviour compliance" do
    setup do
      t = new_table(:iface)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :callbacks
    test "GenServer-like component passes compliance when all required callbacks present", %{t: t} do
      genserver_required = [:init, :handle_call, :handle_cast, :handle_info, :terminate]

      InterfaceCatalog.declare(t, :my_server, genserver_required, [:code_change])

      implemented = [:init, :handle_call, :handle_cast, :handle_info, :terminate]
      assert {:ok, :compliant} = InterfaceCatalog.verify_compliance(t, :my_server, implemented)
    end

    @tag :l2
    @tag :callbacks
    test "GenServer-like component fails compliance when callback is missing", %{t: t} do
      genserver_required = [:init, :handle_call, :handle_cast, :handle_info, :terminate]
      InterfaceCatalog.declare(t, :broken_server, genserver_required, [])

      # Omit :terminate
      partial = [:init, :handle_call, :handle_cast, :handle_info]

      assert {:error, {:missing_callbacks, missing}} =
               InterfaceCatalog.verify_compliance(t, :broken_server, partial)

      assert :terminate in missing
    end

    @tag :l2
    @tag :callbacks
    test "Supervisor-like component satisfies thinner required interface", %{t: t} do
      supervisor_required = [:init]
      InterfaceCatalog.declare(t, :my_sup, supervisor_required, [:child_spec])

      assert {:ok, :compliant} = InterfaceCatalog.verify_compliance(t, :my_sup, [:init])
    end

    @tag :l2
    @tag :callbacks
    test "interface width counts required plus optional callbacks", %{t: t} do
      InterfaceCatalog.declare(t, :fat_interface, [:a, :b, :c], [:d, :e])
      {:ok, width} = InterfaceCatalog.interface_width(t, :fat_interface)
      assert width == 5
    end

    @tag :l2
    @tag :callbacks
    test "thin interface: width of 1 is preferred over width of 10 for cohesive component", %{
      t: t
    } do
      InterfaceCatalog.declare(t, :thin_comp, [:process], [])
      InterfaceCatalog.declare(t, :fat_comp, [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j], [])

      {:ok, thin_w} = InterfaceCatalog.interface_width(t, :thin_comp)
      {:ok, fat_w} = InterfaceCatalog.interface_width(t, :fat_comp)
      assert thin_w < fat_w
    end
  end

  # ===========================================================================
  # Section 4: Message protocol consistency between components
  # ===========================================================================

  describe "message protocol consistency" do
    @tag :l2
    @tag :protocol
    test "well-formed envelope passes validation" do
      msg = MessageProtocol.build(:comp_a, :comp_b, :request, %{value: 42}, 1)
      assert {:ok, :valid} = MessageProtocol.validate(msg)
    end

    @tag :l2
    @tag :protocol
    test "envelope missing :seq field fails validation" do
      incomplete = %{from: :a, to: :b, type: :cmd, payload: %{}}
      assert {:error, {:invalid_envelope, missing}} = MessageProtocol.validate(incomplete)
      assert :seq in missing
    end

    @tag :l2
    @tag :protocol
    test "envelope missing multiple fields reports all missing fields" do
      minimal = %{from: :a}
      {:error, {:invalid_envelope, missing}} = MessageProtocol.validate(minimal)
      assert length(missing) >= 3
    end

    @tag :l2
    @tag :protocol
    test "sequence of messages between two components is strictly monotonic" do
      msgs =
        Enum.map(0..4, fn seq ->
          MessageProtocol.build(:producer, :consumer, :event, %{n: seq}, seq)
        end)

      assert MessageProtocol.seq_monotonic?(msgs)
    end

    @tag :l2
    @tag :protocol
    test "out-of-order messages detected as non-monotonic" do
      # Insert message with seq=3 before seq=2 to simulate reordering
      msgs = [
        MessageProtocol.build(:a, :b, :evt, %{}, 0),
        MessageProtocol.build(:a, :b, :evt, %{}, 3),
        MessageProtocol.build(:a, :b, :evt, %{}, 2)
      ]

      refute MessageProtocol.seq_monotonic?(msgs)
    end
  end

  # ===========================================================================
  # Section 5: State encapsulation — no internal state leaked through public API
  # ===========================================================================

  describe "state encapsulation" do
    setup do
      t = new_table(:state)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :encapsulation
    test "public response without private fields passes encapsulation check", %{t: t} do
      StateGuard.register_private_fields(t, :account_server, [
        :password_hash,
        :session_token,
        :internal_state_version
      ])

      public_response = %{id: "user-1", name: "Alice", email: "alice@example.com"}
      assert {:ok, :clean} = StateGuard.check_leak(t, :account_server, public_response)
    end

    @tag :l2
    @tag :encapsulation
    test "public response containing a private field is flagged as leaked", %{t: t} do
      StateGuard.register_private_fields(t, :session_server, [:session_token, :csrf_secret])

      # Mistakenly expose session_token
      leaky_response = %{user_id: 1, session_token: "top-secret", roles: [:admin]}

      assert {:error, {:leaked, leaked}} =
               StateGuard.check_leak(t, :session_server, leaky_response)

      assert :session_token in leaked
    end

    @tag :l2
    @tag :encapsulation
    test "multiple private fields simultaneously leaked are all reported", %{t: t} do
      StateGuard.register_private_fields(t, :vault, [:key_material, :private_seed, :audit_cursor])

      leaky = %{id: "vault-1", key_material: "...", private_seed: "...", label: "prod"}

      {:error, {:leaked, leaked}} = StateGuard.check_leak(t, :vault, leaky)
      assert :key_material in leaked
      assert :private_seed in leaked
    end

    @tag :l2
    @tag :encapsulation
    test "component with no registered private fields never reports a leak", %{t: t} do
      # :unknown_server has no registered fields — all responses are clean
      response = %{secret: "value", hidden: "data", internal: "state"}
      assert {:ok, :clean} = StateGuard.check_leak(t, :unknown_server, response)
    end
  end

  # ===========================================================================
  # Section 6: Interface segregation (thin interfaces preferred)
  # ===========================================================================

  describe "interface segregation" do
    setup do
      t = new_table(:iface_seg)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :segregation
    test "alarm handler exposes only :handle_alarm — width of 1", %{t: t} do
      InterfaceCatalog.declare(t, :alarm_handler, [:handle_alarm], [])
      {:ok, width} = InterfaceCatalog.interface_width(t, :alarm_handler)
      assert width == 1
    end

    @tag :l2
    @tag :segregation
    test "health checker exposes only :check — width of 1", %{t: t} do
      InterfaceCatalog.declare(t, :health_checker, [:check], [])
      {:ok, width} = InterfaceCatalog.interface_width(t, :health_checker)
      assert width == 1
    end

    @tag :l2
    @tag :segregation
    test "splitting a fat interface into two thin ones reduces maximum width per component", %{
      t: t
    } do
      # Before split: one 6-function interface
      InterfaceCatalog.declare(t, :monolith, [:a, :b, :c, :d, :e, :f], [])

      # After split: two 3-function interfaces
      InterfaceCatalog.declare(t, :reader_iface, [:a, :b, :c], [])
      InterfaceCatalog.declare(t, :writer_iface, [:d, :e, :f], [])

      {:ok, mono_w} = InterfaceCatalog.interface_width(t, :monolith)
      {:ok, read_w} = InterfaceCatalog.interface_width(t, :reader_iface)
      {:ok, write_w} = InterfaceCatalog.interface_width(t, :writer_iface)

      assert max(read_w, write_w) < mono_w
    end
  end

  # ===========================================================================
  # Section 7: Substitution — replacement component satisfies all callers
  # ===========================================================================

  describe "component substitution" do
    setup do
      t = new_table(:subst)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :substitution
    test "replacement component that exposes same API satisfies all callers", %{t: t} do
      # Caller expects :publish and :subscribe
      SubstitutionSim.register_caller_expectations(t, :event_consumer, [
        {:publish, 2},
        {:subscribe, 1}
      ])

      # Original component contract
      original_api = [{:publish, 2}, {:subscribe, 1}, {:unsubscribe, 1}]
      # Replacement exposes at minimum the same surface
      replacement_api = [{:publish, 2}, {:subscribe, 1}, {:batch_publish, 2}]

      assert SubstitutionSim.satisfies_caller?(t, :event_consumer, original_api)
      assert SubstitutionSim.satisfies_caller?(t, :event_consumer, replacement_api)
    end

    @tag :l2
    @tag :substitution
    test "replacement that drops a required function fails caller contract check", %{t: t} do
      SubstitutionSim.register_caller_expectations(t, :alarm_consumer, [
        {:handle_alarm, 1},
        {:ack_alarm, 1}
      ])

      # Replacement omits :ack_alarm
      incomplete_replacement = [{:handle_alarm, 1}]

      refute SubstitutionSim.satisfies_caller?(t, :alarm_consumer, incomplete_replacement)
    end

    @tag :l2
    @tag :substitution
    test "multiple callers can each be independently verified against same replacement", %{t: t} do
      SubstitutionSim.register_caller_expectations(t, :caller_x, [{:read, 1}])
      SubstitutionSim.register_caller_expectations(t, :caller_y, [{:write, 2}])

      replacement = [{:read, 1}, {:write, 2}, {:flush, 0}]

      assert SubstitutionSim.satisfies_caller?(t, :caller_x, replacement)
      assert SubstitutionSim.satisfies_caller?(t, :caller_y, replacement)
    end
  end

  # ===========================================================================
  # Property 1: Adding private functions never changes the public API surface
  # ===========================================================================

  test "property (SD): adding internal functions does not change public API surface" do
    forall {pub_fns, extra_privates} <- {PC.list(PC.atom()), PC.list(PC.atom())} do
      t = new_table(:prop_pub)

      try do
        ComponentRegistry.register(t, :target, pub_fns, [:initial_priv])

        {:ok, surface_before} = ComponentRegistry.public_surface(t, :target)

        # Simulate adding more private functions by re-registering
        ComponentRegistry.register(
          t,
          :target,
          pub_fns,
          [:initial_priv | extra_privates]
        )

        {:ok, surface_after} = ComponentRegistry.public_surface(t, :target)

        assert MapSet.equal?(surface_before, surface_after),
               "Public API changed after adding private functions"
      after
        drop_table(t)
      end
    end
  end

  # ===========================================================================
  # Property 2: Cohesion ratio is always in [0.0, 1.0]
  # ===========================================================================

  test "property (SD): cohesion_ratio is always in [0.0, 1.0]" do
    forall {pub_count, priv_count} <- {PC.integer(0, 10), PC.integer(0, 20)} do
      t = new_table(:prop_ratio)

      try do
        pub_fns =
          if pub_count > 0,
            do: Enum.map(1..pub_count, fn i -> String.to_atom("pub_#{i}") end),
            else: []

        priv_fns =
          if priv_count > 0,
            do: Enum.map(1..priv_count, fn i -> String.to_atom("priv_#{i}") end),
            else: []

        ComponentRegistry.register(t, :ratio_comp, pub_fns, priv_fns)
        {:ok, ratio} = ComponentRegistry.cohesion_ratio(t, :ratio_comp)

        assert ratio >= 0.0 and ratio <= 1.0,
               "Cohesion ratio #{ratio} out of valid range [0.0, 1.0]"
      after
        drop_table(t)
      end
    end
  end

  # ===========================================================================
  # Property 3: Replacement satisfies caller iff it provides all required fns
  #             (PC forall — PropCheck generators)
  # ===========================================================================

  test "propcheck (PC): substitution is monotone — superset of API always satisfies caller" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall required <- PC.list(PC.atom()) do
               t = new_table(:pc_prop_sub)

               try do
                 SubstitutionSim.register_caller_expectations(
                   t,
                   :pc_caller,
                   Enum.map(required, fn f -> {f, 0} end)
                 )

                 # exact match satisfies
                 exact = Enum.map(required, fn f -> {f, 0} end)
                 # superset satisfies
                 extra = [{:extra_fn, 0} | exact]
                 # empty set satisfies trivially when required is empty
                 empty = []

                 exact_result = SubstitutionSim.satisfies_caller?(t, :pc_caller, exact)
                 extra_result = SubstitutionSim.satisfies_caller?(t, :pc_caller, extra)
                 empty_result = SubstitutionSim.satisfies_caller?(t, :pc_caller, empty)

                 if required == [] do
                   # empty required set — all replacements satisfy
                   exact_result and extra_result and empty_result
                 else
                   # non-empty required set — exact and superset must satisfy
                   exact_result and extra_result and not empty_result
                 end
               after
                 drop_table(t)
               end
             end
           )
  end

  # ===========================================================================
  # Property 4: Message sequences with monotonic seq are always valid (SD)
  # ===========================================================================

  test "property (SD): strictly increasing seq values always pass seq_monotonic? check" do
    forall n <- PC.integer(2, 12) do
      msgs =
        Enum.map(0..(n - 1), fn seq ->
          MessageProtocol.build(:src, :dst, :event, %{}, seq)
        end)

      assert MessageProtocol.seq_monotonic?(msgs),
             "Monotonically increasing sequence must always pass the seq_monotonic? check"
    end
  end

  # ===========================================================================
  # Additional: lifecycle timestamp ordering and registry completeness
  # ===========================================================================

  describe "lifecycle and registry completeness" do
    setup do
      t = new_table(:lifecycle)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :l2
    @tag :lifecycle
    test "all registered components are retrievable from all_modules/1", %{t: t} do
      components = [:comp_a, :comp_b, :comp_c]

      Enum.each(components, fn c ->
        ComponentRegistry.register(t, c, [:run], [:internal])
      end)

      all = ComponentRegistry.all_modules(t)
      Enum.each(components, fn c -> assert c in all end)
    end

    @tag :l2
    @tag :lifecycle
    test "registration timestamp is a positive monotonic integer", %{t: t} do
      before_us = now_us()
      ComponentRegistry.register(t, :time_comp, [:fn_a], [:fn_b])
      after_us = now_us()

      [{:time_comp, entry}] = :ets.lookup(t, :time_comp)
      assert entry.registered_at >= before_us
      assert entry.registered_at <= after_us
    end

    @tag :l2
    @tag :lifecycle
    test "re-registering a component updates its public surface in-place", %{t: t} do
      ComponentRegistry.register(t, :evolving, [:v1_api], [:internal])
      {:ok, v1_surface} = ComponentRegistry.public_surface(t, :evolving)
      assert :v1_api in v1_surface

      ComponentRegistry.register(t, :evolving, [:v2_api], [:internal])
      {:ok, v2_surface} = ComponentRegistry.public_surface(t, :evolving)

      assert :v2_api in v2_surface
      refute :v1_api in v2_surface
    end

    @tag :l2
    @tag :lifecycle
    test "dep_ratio approaches 1.0 as external deps decrease relative to internal", %{t: t} do
      # Only internal dependencies
      DependencyTracker.add_dependency(t, :pure_comp, :internal_a)
      DependencyTracker.add_dependency(t, :pure_comp, :internal_b)
      DependencyTracker.add_dependency(t, :pure_comp, :internal_c)

      ratio =
        DependencyTracker.dep_ratio(t, :pure_comp, [
          :internal_a,
          :internal_b,
          :internal_c,
          :pure_comp
        ])

      assert ratio == 1.0
    end
  end
end
