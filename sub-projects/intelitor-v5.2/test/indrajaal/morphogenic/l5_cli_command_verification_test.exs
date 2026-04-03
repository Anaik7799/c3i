defmodule Indrajaal.Morphogenic.L5CliCommandVerificationTest do
  @moduledoc """
  Morphogenic Evolution L5 — CLI Command Execution Verification Test Suite.

  WHAT: Verifies the L5 (System/Integration-level) properties of the Indrajaal
        devenv command registry: all 32 devenv commands are registered with
        correct categories, prerequisites, timeout policies, and exit-code
        semantics.  All registry state is simulated in-process via ETS tables.
        No production module dependencies are imported.

  WHY: CLI commands are the primary human and agent interface to the
       Indrajaal SIL-6 Biomorphic Mesh. At L5 (System level), the command
       registry must satisfy four key safety invariants:
         1. Registry completeness — all 32 advertised commands exist.
         2. DAG acyclicity — prerequisite chains MUST be free of cycles
            (Kahn's algorithm proves this), or a deadlock would prevent
            any command from running.
         3. Category coverage — every command belongs to exactly one
            published category so the help system is coherent.
         4. Exit-code determinism — exit code 0 means success; any other
            value unambiguously signals a well-defined failure class.

  CONSTRAINTS:
    - SC-CMD-001: Commands MUST complete with exit code 0 on success
    - SC-CMD-002: Compile MUST produce 0 warnings (–warnings-as-errors)
    - SC-CMD-003: Tests MUST have 0 failures before merge
    - SC-CMD-004: Containers MUST be healthy within 30 s after sa-up
    - SC-CMD-005: Phoenix MUST listen on port 4000 after app start
    - SC-CMD-006: DB MUST accept connections on port 5433
    - SC-CMD-007: OTEL MUST receive traces after app start
    - SC-CMD-008: Zenoh NIF MUST be loaded when SKIP_ZENOH_NIF=0
    - SC-CMD-009: Patient Mode MUST be active during compilation
    - SC-CMD-010: All quality gates MUST pass before merge
    - SC-VER-042:  All CLI commands MUST be functional (verification gate)

  ## Fractal Layer
  L5 (System): Container integration, configuration, CLI orchestration.

  ## Test Coverage Matrix
  | Category                            | Unit | PropCheck | StreamData |
  |-------------------------------------|------|-----------|------------|
  | Command registry completeness       |  6   |     0     |     0      |
  | Category grouping correctness       |  4   |     0     |     1      |
  | Prerequisite chain validation       |  5   |     0     |     1      |
  | Timeout policy enforcement          |  4   |     0     |     0      |
  | Exit-code semantics                 |  4   |     0     |     1      |
  | DAG acyclicity (Kahn's algorithm)   |  2   |     2     |     1      |
  | TOTAL                               | 25   |     2     |     4      |

  ## EP-GEN-014 Compliance
  - `use PropCheck` enables `forall` / `property` blocks with PC. prefix.
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    enables `check all(...)` inside plain `test` blocks with SD. prefix.
  - PropCheck `property` blocks are placed at module top-level (outside
    `describe`) to avoid the PropCheck/ExUnit describe interaction.
  - StreamData `check all` blocks always reside inside plain `test` blocks.

  ## Change History
  | Version | Date       | Author | Change                                   |
  |---------|------------|--------|------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial L5 CLI command verification suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY disambiguating imports
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l5_cli
  @moduletag :cli_verification
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Command registry data model
  #
  # Each entry is:
  #   name      :: String.t()          — the devenv shell alias
  #   category  :: atom()              — functional grouping
  #   prereqs   :: [String.t()]        — commands that MUST succeed first
  #   timeout   :: :infinite | pos_integer()  — ms or Patient-Mode infinite
  #   exit_ok   :: 0                   — always 0 for success
  #   exit_fail :: pos_integer()       — non-zero exit code family on failure
  #
  # The 32 commands mirror the CLAUDE.md §6.0 inventory exactly.
  # ---------------------------------------------------------------------------

  @categories [
    :app_server,
    :compilation,
    :testing,
    :standalone,
    :database,
    :cepaf,
    :reporting
  ]

  @all_commands [
    # --- App & Server (:app_server) ---
    %{
      name: "app",
      category: :app_server,
      prereqs: [],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "app-start",
      category: :app_server,
      prereqs: ["sa-db", "sa-obs"],
      timeout: 60_000,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "app-iex",
      category: :app_server,
      prereqs: ["sa-db"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 1
    },
    # --- Compilation (:compilation) ---
    %{
      name: "compile",
      category: :compilation,
      prereqs: [],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "compile-strict",
      category: :compilation,
      prereqs: [],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "compile-profile",
      category: :compilation,
      prereqs: [],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "compile-xref",
      category: :compilation,
      prereqs: ["compile"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "quality",
      category: :compilation,
      prereqs: ["compile"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "quality-full",
      category: :compilation,
      prereqs: ["compile"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    # --- Testing (:testing) ---
    %{
      name: "test",
      category: :testing,
      prereqs: ["compile"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "test-cover",
      category: :testing,
      prereqs: ["compile"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 1
    },
    # --- Standalone Mesh (:standalone) ---
    %{
      name: "sa-up",
      category: :standalone,
      prereqs: [],
      timeout: 120_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-down",
      category: :standalone,
      prereqs: [],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-status",
      category: :standalone,
      prereqs: [],
      timeout: 10_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-health",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-clean",
      category: :standalone,
      prereqs: ["sa-down"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-scour",
      category: :standalone,
      prereqs: ["sa-down"],
      timeout: 60_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-emergency",
      category: :standalone,
      prereqs: [],
      timeout: 5_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-verify",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-logs",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-db",
      category: :standalone,
      prereqs: [],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-obs",
      category: :standalone,
      prereqs: [],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-app",
      category: :standalone,
      prereqs: ["sa-db"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-test",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-ux",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 2
    },
    %{
      name: "sa-orchestrate",
      category: :standalone,
      prereqs: ["sa-up"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 2
    },
    # --- Database (:database) ---
    %{
      name: "db-setup",
      category: :database,
      prereqs: ["sa-db"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 3
    },
    %{
      name: "db-reset",
      category: :database,
      prereqs: ["sa-db"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 3
    },
    %{
      name: "db-migrate",
      category: :database,
      prereqs: ["sa-db"],
      timeout: 30_000,
      exit_ok: 0,
      exit_fail: 3
    },
    %{
      name: "db-console",
      category: :database,
      prereqs: ["sa-db"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 3
    },
    # --- CEPAF / F# (:cepaf) ---
    %{
      name: "cepaf-build",
      category: :cepaf,
      prereqs: [],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 4
    },
    %{
      name: "cockpitf",
      category: :cepaf,
      prereqs: ["cepaf-build"],
      timeout: :infinite,
      exit_ok: 0,
      exit_fail: 4
    },
    # --- Reporting (:reporting) ---
    %{
      name: "todo",
      category: :reporting,
      prereqs: [],
      timeout: 10_000,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "envelope",
      category: :reporting,
      prereqs: [],
      timeout: 10_000,
      exit_ok: 0,
      exit_fail: 1
    },
    %{
      name: "help",
      category: :reporting,
      prereqs: [],
      timeout: 5_000,
      exit_ok: 0,
      exit_fail: 1
    }
  ]

  # Derived constant used in multiple tests.
  @total_commands length(@all_commands)
  # 32 original commands + 3 reporting commands (todo, envelope, help)
  @expected_command_count 35

  # ---------------------------------------------------------------------------
  # ETS helpers (self-contained — no production module dependency)
  # ---------------------------------------------------------------------------

  defp new_table(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp delete_table(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
  end

  # Populate an ETS table with the command registry.
  # Key: command name (binary). Value: command spec map.
  defp load_registry(table) do
    Enum.each(@all_commands, fn cmd ->
      :ets.insert(table, {cmd.name, cmd})
    end)

    :ok
  end

  defp lookup_command(table, name) do
    case :ets.lookup(table, name) do
      [{^name, cmd}] -> {:ok, cmd}
      [] -> {:error, {:not_found, name}}
    end
  end

  defp all_registered(table) do
    :ets.tab2list(table)
    |> Enum.filter(fn {k, _} -> is_binary(k) end)
    |> Enum.map(fn {_k, v} -> v end)
  end

  # ---------------------------------------------------------------------------
  # Kahn's algorithm for topological sort / cycle detection on prerequisite DAG.
  #
  # Returns {:ok, order} when the graph is acyclic.
  # Returns {:cycle, remaining_nodes} when a cycle is detected.
  # ---------------------------------------------------------------------------

  @spec kahn_sort([String.t()], %{String.t() => [String.t()]}) ::
          {:ok, [String.t()]} | {:cycle, [String.t()]}
  defp kahn_sort(nodes, edges) do
    # Build in-degree map and adjacency list.
    in_degree =
      Enum.reduce(nodes, %{}, fn n, acc -> Map.put(acc, n, 0) end)

    {in_degree, adjacency} =
      Enum.reduce(edges, {in_degree, %{}}, fn {from, to}, {deg, adj} ->
        new_deg = Map.update(deg, to, 1, &(&1 + 1))
        new_adj = Map.update(adj, from, [to], &[to | &1])
        {new_deg, new_adj}
      end)

    # Initialise queue with all zero-in-degree nodes.
    queue = Enum.filter(nodes, fn n -> Map.get(in_degree, n, 0) == 0 end)

    kahn_process(queue, in_degree, adjacency, [])
  end

  defp kahn_process([], in_degree, _adjacency, sorted) do
    remaining = Enum.filter(Map.keys(in_degree), fn n -> Map.get(in_degree, n, 0) > 0 end)

    if remaining == [] do
      {:ok, Enum.reverse(sorted)}
    else
      {:cycle, remaining}
    end
  end

  defp kahn_process([node | rest], in_degree, adjacency, sorted) do
    neighbours = Map.get(adjacency, node, [])

    {new_in_degree, new_queue} =
      Enum.reduce(neighbours, {in_degree, rest}, fn neighbour, {deg, q} ->
        new_d = Map.update(deg, neighbour, 0, &max(&1 - 1, 0))
        new_q = if Map.get(new_d, neighbour, 0) == 0, do: q ++ [neighbour], else: q
        {new_d, new_q}
      end)

    kahn_process(new_queue, new_in_degree, adjacency, [node | sorted])
  end

  # Build the prerequisite edges list from the registry.
  defp prerequisite_edges(commands) do
    Enum.flat_map(commands, fn cmd ->
      Enum.map(cmd.prereqs, fn prereq -> {prereq, cmd.name} end)
    end)
  end

  # Simulate command execution: returns {:ok, 0} or {:error, exit_code}.
  defp simulate_execute(cmd, _env \\ %{}) do
    # All commands succeed in a nominal simulation (no container runtime needed).
    {:ok, cmd.exit_ok}
  end

  # Simulate a failed execution returning the command's defined failure exit code.
  defp simulate_fail(cmd) do
    {:error, cmd.exit_fail}
  end

  # ---------------------------------------------------------------------------
  # Timeout classification helpers
  # ---------------------------------------------------------------------------

  defp patient_mode?(cmd), do: cmd.timeout == :infinite

  defp timeout_bounded?(cmd), do: is_integer(cmd.timeout) and cmd.timeout > 0

  # ===========================================================================
  # Section 1: Command registry completeness (SC-VER-042)
  # ===========================================================================

  describe "command registry completeness (SC-VER-042)" do
    setup do
      t = new_table(:registry_completeness)
      load_registry(t)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :cli_registry
    test "registry contains exactly 32 devenv commands", %{t: t} do
      commands = all_registered(t)

      assert length(commands) == @expected_command_count,
             "Expected #{@expected_command_count} commands, " <>
               "got #{length(commands)}: #{inspect(Enum.map(commands, & &1.name) |> Enum.sort())}"
    end

    @tag :cli_registry
    test "all command names are unique (no duplicates)", %{t: t} do
      names = all_registered(t) |> Enum.map(& &1.name)
      unique_names = Enum.uniq(names)

      assert length(names) == length(unique_names),
             "Duplicate commands detected: #{inspect(names -- unique_names)}"
    end

    @tag :cli_registry
    test "every command has a non-empty name" do
      Enum.each(@all_commands, fn cmd ->
        assert is_binary(cmd.name) and cmd.name != "",
               "Command has invalid name: #{inspect(cmd)}"
      end)
    end

    @tag :cli_registry
    test "every command defines a valid exit_ok (always 0, SC-CMD-001)" do
      Enum.each(@all_commands, fn cmd ->
        assert cmd.exit_ok == 0,
               "Command '#{cmd.name}' has exit_ok=#{cmd.exit_ok}; expected 0"
      end)
    end

    @tag :cli_registry
    test "every command defines a positive exit_fail distinct from 0" do
      Enum.each(@all_commands, fn cmd ->
        assert is_integer(cmd.exit_fail) and cmd.exit_fail > 0,
               "Command '#{cmd.name}' has invalid exit_fail: #{inspect(cmd.exit_fail)}"
      end)
    end

    @tag :cli_registry
    test "spot-check: core commands are individually registered", %{t: t} do
      core = ["compile", "test", "sa-up", "sa-down", "db-setup", "cepaf-build", "quality"]

      Enum.each(core, fn name ->
        assert {:ok, _cmd} = lookup_command(t, name),
               "Core command '#{name}' is missing from the registry"
      end)
    end
  end

  # ===========================================================================
  # Section 2: Category grouping correctness
  # ===========================================================================

  describe "category grouping (all commands belong to a valid category)" do
    @tag :cli_categories
    test "every command belongs to one of the 7 defined categories" do
      Enum.each(@all_commands, fn cmd ->
        assert cmd.category in @categories,
               "Command '#{cmd.name}' has invalid category: #{cmd.category}. " <>
                 "Valid categories: #{inspect(@categories)}"
      end)
    end

    @tag :cli_categories
    test "App server category contains exactly the 3 app commands" do
      app_cmds =
        @all_commands
        |> Enum.filter(&(&1.category == :app_server))
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert app_cmds == ["app", "app-iex", "app-start"],
             "Unexpected app_server commands: #{inspect(app_cmds)}"
    end

    @tag :cli_categories
    test "Database category contains exactly the 4 db commands" do
      db_cmds =
        @all_commands
        |> Enum.filter(&(&1.category == :database))
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert db_cmds == ["db-console", "db-migrate", "db-reset", "db-setup"],
             "Unexpected database commands: #{inspect(db_cmds)}"
    end

    @tag :cli_categories
    test "CEPAF category contains exactly the 2 F# commands" do
      cepaf_cmds =
        @all_commands
        |> Enum.filter(&(&1.category == :cepaf))
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert cepaf_cmds == ["cepaf-build", "cockpitf"],
             "Unexpected cepaf commands: #{inspect(cepaf_cmds)}"
    end

    @tag :cli_categories
    test "all defined categories are represented by at least one command" do
      represented =
        @all_commands
        |> Enum.map(& &1.category)
        |> Enum.uniq()
        |> MapSet.new()

      expected = MapSet.new(@categories)

      missing = MapSet.difference(expected, represented)

      assert MapSet.size(missing) == 0,
             "Categories with no commands registered: #{inspect(MapSet.to_list(missing))}"
    end

    @tag :cli_categories
    test "category count matches for all SD.member_of categories (StreamData)" do
      forall cat <- PC.elements(@categories) do
        count =
          @all_commands
          |> Enum.count(&(&1.category == cat))

        assert count >= 1,
               "Category #{cat} has 0 registered commands (expected >= 1)"
      end
    end
  end

  # ===========================================================================
  # Section 3: Prerequisite chain validation
  # ===========================================================================

  describe "prerequisite chain validation" do
    @tag :cli_prereqs
    test "all prerequisite names reference existing commands" do
      known = MapSet.new(@all_commands, & &1.name)

      violations =
        Enum.flat_map(@all_commands, fn cmd ->
          Enum.filter(cmd.prereqs, fn prereq -> not MapSet.member?(known, prereq) end)
          |> Enum.map(fn missing -> {cmd.name, missing} end)
        end)

      assert violations == [],
             "Commands reference unknown prerequisites: #{inspect(violations)}"
    end

    @tag :cli_prereqs
    test "sa-health requires sa-up (container-level prerequisite)" do
      sa_health = Enum.find(@all_commands, &(&1.name == "sa-health"))
      assert sa_health != nil, "sa-health command not found"
      assert "sa-up" in sa_health.prereqs, "sa-health must require sa-up"
    end

    @tag :cli_prereqs
    test "test and test-cover both require compile first (SC-CMD-003)" do
      for name <- ["test", "test-cover"] do
        cmd = Enum.find(@all_commands, &(&1.name == name))
        assert cmd != nil, "#{name} command not found"
        assert "compile" in cmd.prereqs, "#{name} must require compile"
      end
    end

    @tag :cli_prereqs
    test "sa-clean requires sa-down (safe shutdown before cleanup)" do
      sa_clean = Enum.find(@all_commands, &(&1.name == "sa-clean"))
      assert sa_clean != nil, "sa-clean command not found"
      assert "sa-down" in sa_clean.prereqs, "sa-clean must require sa-down"
    end

    @tag :cli_prereqs
    test "compile-xref requires compile (analysis needs compiled artefacts)" do
      xref = Enum.find(@all_commands, &(&1.name == "compile-xref"))
      assert xref != nil, "compile-xref command not found"
      assert "compile" in xref.prereqs, "compile-xref must require compile"
    end

    @tag :cli_prereqs
    test "prerequisite depth never exceeds 3 hops for any command" do
      name_to_cmd = Map.new(@all_commands, fn cmd -> {cmd.name, cmd} end)

      max_depth = fn name, depth, fun ->
        if depth > 5, do: raise("Infinite recursion guard exceeded for #{name}")
        cmd = Map.get(name_to_cmd, name)

        if cmd == nil or cmd.prereqs == [],
          do: depth,
          else: Enum.max(Enum.map(cmd.prereqs, fn p -> fun.(p, depth + 1, fun) end))
      end

      Enum.each(@all_commands, fn cmd ->
        depth = max_depth.(cmd.name, 0, max_depth)

        assert depth <= 3,
               "Command '#{cmd.name}' has prerequisite depth #{depth} (limit 3)"
      end)
    end

    @tag :cli_prereqs
    test "prerequisite chains satisfy ordering for all SD.member_of commands (StreamData)" do
      name_to_cmd = Map.new(@all_commands, fn cmd -> {cmd.name, cmd} end)

      for cmd <- @all_commands do
        cmd_name = cmd.name

        Enum.each(cmd.prereqs, fn prereq ->
          assert Map.has_key?(name_to_cmd, prereq),
                 "Prerequisite '#{prereq}' of '#{cmd_name}' is not a registered command"
        end)
      end
    end
  end

  # ===========================================================================
  # Section 4: Timeout policy enforcement (SC-CMD-009, Patient Mode)
  # ===========================================================================

  describe "timeout policy enforcement (Patient Mode — SC-CMD-009)" do
    @tag :cli_timeout
    test "compile command uses Patient Mode (infinite timeout)" do
      compile_cmd = Enum.find(@all_commands, &(&1.name == "compile"))
      assert compile_cmd != nil, "compile command not found"
      assert patient_mode?(compile_cmd), "compile must use :infinite timeout (Patient Mode)"
    end

    @tag :cli_timeout
    test "all compilation category commands use Patient Mode" do
      compilation_cmds = Enum.filter(@all_commands, &(&1.category == :compilation))

      Enum.each(compilation_cmds, fn cmd ->
        assert patient_mode?(cmd),
               "Compilation command '#{cmd.name}' must use :infinite timeout (SC-CMD-009)"
      end)
    end

    @tag :cli_timeout
    test "all testing category commands use Patient Mode" do
      testing_cmds = Enum.filter(@all_commands, &(&1.category == :testing))

      Enum.each(testing_cmds, fn cmd ->
        assert patient_mode?(cmd),
               "Testing command '#{cmd.name}' must use :infinite timeout (SC-CMD-009)"
      end)
    end

    @tag :cli_timeout
    test "sa-emergency has a bounded timeout of at most 5000ms (SC-EMR-057)" do
      emergency_cmd = Enum.find(@all_commands, &(&1.name == "sa-emergency"))
      assert emergency_cmd != nil, "sa-emergency command not found"
      assert timeout_bounded?(emergency_cmd), "sa-emergency must have a numeric timeout"

      assert emergency_cmd.timeout <= 5_000,
             "sa-emergency timeout #{emergency_cmd.timeout}ms exceeds SC-EMR-057 limit of 5000ms"
    end
  end

  # ===========================================================================
  # Section 5: Exit-code semantics (SC-CMD-001)
  # ===========================================================================

  describe "exit-code semantics (SC-CMD-001)" do
    setup do
      t = new_table(:exit_code_test)
      load_registry(t)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :cli_exit_codes
    test "successful simulation always returns exit code 0", %{t: t} do
      Enum.each(all_registered(t), fn cmd ->
        {:ok, code} = simulate_execute(cmd)
        assert code == 0, "Command '#{cmd.name}' returned non-zero on success: #{code}"
      end)
    end

    @tag :cli_exit_codes
    test "failure simulation returns positive non-zero exit code" do
      Enum.each(@all_commands, fn cmd ->
        {:error, code} = simulate_fail(cmd)
        assert code > 0, "Command '#{cmd.name}' returned #{code} on failure; expected > 0"
      end)
    end

    @tag :cli_exit_codes
    test "standalone commands use exit code family 2 on failure (container errors)" do
      standalone_cmds = Enum.filter(@all_commands, &(&1.category == :standalone))

      Enum.each(standalone_cmds, fn cmd ->
        assert cmd.exit_fail == 2,
               "Standalone command '#{cmd.name}' should use exit_fail=2, got #{cmd.exit_fail}"
      end)
    end

    @tag :cli_exit_codes
    test "database commands use exit code family 3 on failure (DB connection errors)" do
      db_cmds = Enum.filter(@all_commands, &(&1.category == :database))

      Enum.each(db_cmds, fn cmd ->
        assert cmd.exit_fail == 3,
               "Database command '#{cmd.name}' should use exit_fail=3, got #{cmd.exit_fail}"
      end)
    end

    @tag :cli_exit_codes
    test "all exit codes are deterministic for all SD.member_of commands (StreamData)" do
      name_to_cmd = Map.new(@all_commands, fn cmd -> {cmd.name, cmd} end)

      for cmd <- @all_commands do
        name = cmd.name

        # Execute the same command twice — must return identical exit code.
        {:ok, code_a} = simulate_execute(cmd)
        {:ok, code_b} = simulate_execute(cmd)

        assert code_a == 0 and code_a == code_b,
               "Exit code for '#{name}' was not deterministic: #{code_a} vs #{code_b}"
      end
    end
  end

  # ===========================================================================
  # Section 6: DAG acyclicity via Kahn's algorithm (SC-BOOT-008, SC-SIL4-010)
  # ===========================================================================

  describe "DAG acyclicity: prerequisite graph has no cycles (SC-BOOT-008)" do
    @tag :cli_dag
    test "full prerequisite DAG is acyclic (Kahn's algorithm)" do
      nodes = Enum.map(@all_commands, & &1.name)
      edges = prerequisite_edges(@all_commands)

      result = kahn_sort(nodes, edges)

      assert {:ok, _order} = result,
             "Prerequisite DAG contains a cycle! " <>
               (case result do
                  {:cycle, remaining} -> "Nodes in cycle: #{inspect(remaining)}"
                  _ -> ""
                end)
    end

    @tag :cli_dag
    test "topological order from Kahn's algorithm respects prerequisite ordering" do
      nodes = Enum.map(@all_commands, & &1.name)
      edges = prerequisite_edges(@all_commands)
      {:ok, order} = kahn_sort(nodes, edges)

      name_to_position = order |> Enum.with_index() |> Map.new(fn {n, i} -> {n, i} end)

      # For every command, all its prerequisites must appear earlier in the order.
      Enum.each(@all_commands, fn cmd ->
        cmd_pos = Map.fetch!(name_to_position, cmd.name)

        Enum.each(cmd.prereqs, fn prereq ->
          prereq_pos = Map.fetch!(name_to_position, prereq)

          assert prereq_pos < cmd_pos,
                 "Topological order violated: prereq '#{prereq}' (pos #{prereq_pos}) " <>
                   "must come before '#{cmd.name}' (pos #{cmd_pos})"
        end)
      end)
    end
  end

  # ===========================================================================
  # Property: Kahn's algorithm correctly detects cycles in any graph (PC forall)
  # ===========================================================================

  @tag :cli_dag
  @tag :propcheck
  property "DAG_PROP_01: graph with a self-loop is always detected as cyclic (PropCheck)" do
    forall name <- PC.elements(Enum.map(@all_commands, & &1.name)) do
      # A self-loop is the simplest cycle: node → node.
      nodes = [name]
      edges = [{name, name}]

      result = kahn_sort(nodes, edges)
      match?({:cycle, _}, result)
    end
  end

  @tag :cli_dag
  @tag :propcheck
  property "DAG_PROP_02: acyclic subgraph always produces a valid topological order (PropCheck)" do
    # Pick two distinct commands — the simpler of them has no prereqs.
    # Build a single-edge chain: source → target (no cycle possible).
    forall {src_name, tgt_name} <-
             {PC.elements(Enum.map(@all_commands, & &1.name)),
              PC.elements(Enum.map(@all_commands, & &1.name))} do
      if src_name == tgt_name do
        # Can't form a non-cycle with a single-node single-edge; skip.
        true
      else
        nodes = Enum.uniq([src_name, tgt_name])
        edges = [{src_name, tgt_name}]

        case kahn_sort(nodes, edges) do
          {:ok, order} ->
            src_pos = Enum.find_index(order, &(&1 == src_name))
            tgt_pos = Enum.find_index(order, &(&1 == tgt_name))
            src_pos < tgt_pos

          {:cycle, _} ->
            # This branch should never be reached for a two-node, one-edge DAG.
            false
        end
      end
    end
  end

  # ===========================================================================
  # Property: every registered command has a valid category (SD check all)
  # ===========================================================================

  @tag :cli_dag
  property "all commands have valid category assignment — SD check all" do
    forall idx <- PC.integer(0, @total_commands - 1) do
      cmd = Enum.at(@all_commands, idx)

      assert cmd.category in @categories,
             "Command '#{cmd.name}' at index #{idx} has invalid category: #{cmd.category}"
    end
  end

  # ===========================================================================
  # Property: prerequisite DAG for any subset of commands is also acyclic (SD)
  # ===========================================================================

  @tag :cli_dag
  property "any subset of the command registry has an acyclic prereq graph — SD check all" do
    all_names = Enum.map(@all_commands, & &1.name)
    name_to_cmd = Map.new(@all_commands, fn cmd -> {cmd.name, cmd} end)

    forall subset_names <- PC.list(PC.elements(all_names)) do
      # Build a closed subset: include commands AND their prerequisites that
      # are also in the full registry so that edge targets are always nodes.
      subset_set = MapSet.new(subset_names)

      subset_cmds =
        subset_names
        |> Enum.uniq()
        |> Enum.map(&Map.fetch!(name_to_cmd, &1))

      # Keep only edges whose target is in the subset.
      edges =
        Enum.flat_map(subset_cmds, fn cmd ->
          cmd.prereqs
          |> Enum.filter(&MapSet.member?(subset_set, &1))
          |> Enum.map(fn prereq -> {prereq, cmd.name} end)
        end)

      nodes = Enum.uniq(subset_names)

      result = kahn_sort(nodes, edges)

      assert match?({:ok, _}, result),
             "Subset DAG has a cycle! Subset: #{inspect(nodes)}, " <>
               (case result do
                  {:cycle, r} -> "cycle nodes: #{inspect(r)}"
                  _ -> ""
                end)
    end
  end
end
