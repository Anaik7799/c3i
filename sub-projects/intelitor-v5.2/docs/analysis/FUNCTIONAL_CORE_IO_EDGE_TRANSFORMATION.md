# Analysis: Moving IO to the Edge (Functional Core, Imperative Shell)

**Date**: 2026-01-09
**Target**: Purely Functional Core, IO at the Edge (The "Sandwich" Architecture)
**Scope**: 8-Level Fractal Analysis of Indrajaal/Prajna Architecture

---

## 1. Executive Summary

The objective is to refactor Indrajaal to strictly separate **Decision** (Logic) from **Action** (IO). Currently, the system exhibits "Temporal Coupling" where business logic is intertwined with database calls, network requests, and system time checks. This makes testing hard (requires mocks) and reasoning difficult (state is implicit).

We propose transforming the architecture into a **Fractal Shell**, where every layer—from a single function to the global federation—follows the rule: **Gather Data (IO) $\to$ Pure Function (Logic) $\to$ Execute Effects (IO).**

---

## 2. The 8-Level Fractal Analysis

We analyze the system across 8 levels of abstraction to identify where IO leaks into logic and how to push it out.

### L1: The Atomic Level (Functions & Expressions)
*   **Current State**: Many helper functions call `DateTime.utc_now/0` or `UUID.generate/0` internally.
*   **Problem**: Functions are non-deterministic and hard to test without mocking the clock or UUID generator.
*   **Target**: Functions accept `timestamp` and `id` as **arguments**. They never generate them.
*   **Transformation**:
    ```elixir
    # Current (Impure)
    def create_event(data), do: %Event{id: UUID.generate(), time: DateTime.utc_now(), ...}
    
    # Target (Pure)
    def create_event(data, id, timestamp), do: %Event{id: id, time: timestamp, ...}
    ```

### L2: The Logic Level (Modules & Domain Entities)
*   **Current State**: Ash Resources and Context modules often embed `Repo` calls within logic flows (e.g., `if valid do Repo.insert end`).
*   **Problem**: Logic cannot be verified without a database connection.
*   **Target**: Modules return **Instructions** (Data) describing intended side effects, rather than executing them.
*   **Transformation**: Return `{:ok, event, instructions}` tuples.
    *   *Instead of:* `EmailService.send(user)`
    *   *Return:* `{:side_effect, :send_email, user}`

### L3: The Mechanism Level (GenServers & Actors)
*   **Current State**: `handle_call/3` callbacks mix state mutations with `System.cmd`, File IO, or HTTP calls.
*   **Problem**: GenServer state transitions are tied to the success/speed of IO. Failures crash the logic state.
*   **Target**: **Functional State Machines**.
    1.  **Shell**: `handle_call` reads current state.
    2.  **Core**: Calls `Core.next_state(state, msg)` (Pure).
    3.  **Shell**: Updates state and executes returned IO commands.

### L4: The Subsystem Level (Components/Contexts)
*   **Current State**: Components like `SagaManager` or `OpenRouterClient` perform orchestration *and* execution simultaneously.
*   **Problem**: Orchestration logic is buried in `Task.await` or HTTP timeouts.
*   **Target**: **The Interpreter Pattern**.
    *   The Subsystem produces a "Plan" (DAG of operations).
    *   A generic "Executor" runs the plan.
    *   The Plan is pure data; the Executor is the only impure part.

### L5: The System Level (Node/Application)
*   **Current State**: Application startup (`application.ex`) performs eager IO (DB connections, cache warming) mixed with supervision tree construction.
*   **Problem**: Hard to boot the app in "Headless" or "Logic-Only" mode for fast property testing.
*   **Target**: **Lazy IO Boots**. Use `handle_continue` for all IO. The Application struct itself should be a pure definition of the dependency graph, verified before start.

### L6: The Mesh Level (Cluster/Network)
*   **Current State**: Distributed calls use `Node.spawn` or RPC directly in business flows.
*   **Problem**: Network partitions are handled as exceptions inside logic.
*   **Target**: **Message-Passing Sovereignty**.
    *   Logic generates a `Message`.
    *   The "Edge" (Mesh Layer) handles routing, retries, and delivery guarantees.
    *   Logic assumes asynchronous delivery and handles eventual consistency via state updates.

### L7: The Federation Level (Inter-System)
*   **Current State**: Federation logic relies on implicit assumptions about remote system versions and APIs.
*   **Problem**: "It works on my machine" but fails when schemas drift.
*   **Target**: **Contract-First Communication**.
    *   IO is restricted to exchanging **Verifiable Credentials/Contracts**.
    *   Logic operates only on validated contracts, never on raw remote data.

### L8: The Environmental Level (The Void)
*   **Current State**: The "User" or "Sensor" is an abstract source of interrupts.
*   **Problem**: Unpredictable inputs cause runtime crashes deep in the stack.
*   **Target**: **The Airlock (Sanitization Layer)**.
    *   All external IO enters via a strict "Airlock" (Boundary).
    *   Data is parsed/validated immediately.
    *   Only "Domain Objects" (Pure Data) pass from L8 to L1.

---

## 3. Strategic Options for Transformation

### Option A: The "Sandwich" Architecture (Recommended)
This is the most pragmatic approach for Elixir/Phoenix systems.
*   **Structure**: `IO (Controller) -> Pure Logic (Context) -> IO (Repo/API)`
*   **Strategy**:
    1.  **Extract**: Pull all logic out of GenServers into `_core.ex` modules.
    2.  **Pass**: Pass all "World State" (Time, UUIDs, Config) as arguments.
    3.  **Return**: Return Actions (`Ecto.Multi`, `Oban.Job`, or Structs) instead of running them.
    4.  **Execute**: The Controller/GenServer applies the actions at the very last step.

### Option B: The Interpreter Pattern (Advanced)
Best for complex workflows like the **SagaManager** or **GDE**.
*   **Structure**: Logic generates an AST (Abstract Syntax Tree) of operations. An Interpreter walks the AST and performs IO.
*   **Pros**: Perfect testability (assert on AST). Ability to swap Interpreters (Mock vs Real).
*   **Cons**: High cognitive load; requires defining a DSL for every subsystem.

### Option C: Hexagonal Architecture (Ports & Adapters)
Standard for decoupling, but can be verbose in Elixir.
*   **Structure**: Logic depends on *Behaviours*. Implementations are injected at runtime.
*   **Pros**: Explicit dependencies.
*   **Cons**: runtime overhead of dynamic dispatch; obscures code navigation.

---

## 4. Proposed Implementation Plan (The "Edge" Shift)

We recommend **Option A (Sandwich)** for general modules and **Option B (Interpreter)** for the Core Cortex (Saga/OODA).

### Phase 1: The Time & Identity Purge (L1)
*   **Action**: Ban `DateTime.utc_now()` and `UUID.generate()` in pure modules.
*   **Mechanism**: Pass `ctx.now` and `ctx.id` from the Controller/Shell.

### Phase 2: The GenServer Split (L3)
*   **Action**: Split every `GenServer` into `Server` (Shell) and `State` (Pure Core).
*   **Pattern**:
    ```elixir
    # Core
    def handle_event(state, :update, params), do: {:ok, %{state | ...}, [:notify_user]}
    
    # Shell
    def handle_info(msg, state) do
      {:ok, new_state, actions} = Core.handle_event(state, msg, params)
      execute_actions(actions)
      {:noreply, new_state}
    end
    ```

### Phase 3: The IO DSL (L4 - Cortex)
*   **Action**: For the OpenRouter/Saga/GDE systems, define a formal Struct for Side Effects.
*   **Def**: `%Effect{type: :http, url: ..., on_success: :next_step}`.
*   **Benefit**: The AI can generate *Effects* safely; the Guardian validates them; the Shell executes them.

---

## 5. Usage Guide: Writing Code for the Edge

1.  **Rule of 3 Arguments**: If a function takes no arguments but returns different values (Time, Random), it is IMPURE. Move it to the Edge.
2.  **The "And Then what?" Test**: If a function returns `:ok` but you don't know *what* changed, it likely did hidden IO. It should return `{:ok, %ChangeDescription{}}`.
3.  **Testing**: If you need `Mock` to test a business rule, you failed. Refactor until you can test with simple data injection.

**Signed**: *The Cybernetic Architect (Gemini)*