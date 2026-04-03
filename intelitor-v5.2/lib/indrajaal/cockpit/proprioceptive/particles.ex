defmodule Indrajaal.Cockpit.Proprioceptive.Particles do
  @moduledoc """
  Particle System - Dynamic Visualization for v20.0.0

  Implements particle-based visualization for system activity:
  - Particle spawning based on events
  - Physics-based motion
  - Decay and lifecycle
  - Attraction/repulsion fields

  ## Particle Model

  Each particle represents an event/action:
  - Position: (x, y) in visualization space
  - Velocity: motion vector
  - Color: event type
  - Size: importance/impact
  - Lifetime: decay over time

  ## Physics

  F = Σ forces (gravity, attraction, drag)
  v' = v + (F/m) × dt
  x' = x + v × dt

  ## STAMP Constraints
  - SC-PRT-001: Max 1000 particles for performance
  - SC-PRT-002: Physics update < 16ms (60fps)
  - SC-PRT-003: Dead particles MUST be recycled
  - SC-PRT-004: Spawn rate MUST be throttled
  """

  use GenServer
  require Logger

  @type vector :: {float(), float()}
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), float()}

  @type particle :: %{
          id: String.t(),
          position: vector(),
          velocity: vector(),
          acceleration: vector(),
          color: color(),
          size: float(),
          lifetime: float(),
          max_lifetime: float(),
          event_type: atom(),
          metadata: map()
        }

  @type state :: %{
          particles: [particle()],
          emitters: map(),
          attractors: [map()],
          config: map()
        }

  # Max particles (SC-PRT-001)
  @max_particles 1000

  # Physics timestep (ms)
  @physics_timestep 16

  # Drag coefficient
  @drag 0.98

  # Gravity
  @gravity {0.0, 0.1}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Spawns a particle at position with velocity.
  """
  @spec spawn(vector(), vector(), atom(), Keyword.t()) :: :ok | {:error, :max_particles}
  def spawn(position, velocity, event_type, opts \\ []) do
    GenServer.call(__MODULE__, {:spawn, position, velocity, event_type, opts})
  end

  @doc """
  Spawns particles from an emitter.
  """
  @spec emit(String.t(), non_neg_integer()) :: :ok
  def emit(emitter_id, count) do
    GenServer.cast(__MODULE__, {:emit, emitter_id, count})
  end

  @doc """
  Registers an emitter.
  """
  @spec register_emitter(String.t(), vector(), map()) :: :ok
  def register_emitter(id, position, config \\ %{}) do
    GenServer.cast(__MODULE__, {:register_emitter, id, position, config})
  end

  @doc """
  Adds an attractor/repulsor field.
  """
  @spec add_attractor(vector(), float(), float()) :: :ok
  def add_attractor(position, strength, radius) do
    GenServer.cast(__MODULE__, {:add_attractor, position, strength, radius})
  end

  @doc """
  Gets current particle state.
  """
  @spec get_particles() :: [particle()]
  def get_particles do
    GenServer.call(__MODULE__, :get_particles)
  end

  @doc """
  Gets particle count.
  """
  @spec count() :: non_neg_integer()
  def count do
    GenServer.call(__MODULE__, :count)
  end

  @doc """
  Clears all particles.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc """
  Renders particles as JSON for web UI.
  """
  @spec render_json() :: map()
  def render_json do
    GenServer.call(__MODULE__, :render_json)
  end

  @doc """
  Gets particle system statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      particles: [],
      emitters: %{},
      attractors: [],
      bounds: Keyword.get(opts, :bounds, {800.0, 600.0}),
      stats: %{
        spawned: 0,
        expired: 0,
        updates: 0
      },
      config: %{
        max_particles: Keyword.get(opts, :max_particles, @max_particles),
        gravity: Keyword.get(opts, :gravity, @gravity),
        drag: Keyword.get(opts, :drag, @drag)
      }
    }

    # Start physics loop
    Process.send_after(self(), :physics_update, @physics_timestep)

    Logger.info("✨ Particle system started")

    {:ok, state}
  end

  @impl true
  def handle_call({:spawn, position, velocity, event_type, opts}, _from, state) do
    if length(state.particles) >= state.config.max_particles do
      {:reply, {:error, :max_particles}, state}
    else
      particle = create_particle(position, velocity, event_type, opts)
      new_particles = [particle | state.particles]
      new_stats = %{state.stats | spawned: state.stats.spawned + 1}
      {:reply, :ok, %{state | particles: new_particles, stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:get_particles, _from, state) do
    {:reply, state.particles, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, length(state.particles), state}
  end

  @impl true
  def handle_call(:render_json, _from, state) do
    json = %{
      particles:
        Enum.map(state.particles, fn p ->
          %{
            id: p.id,
            x: elem(p.position, 0),
            y: elem(p.position, 1),
            vx: elem(p.velocity, 0),
            vy: elem(p.velocity, 1),
            color: color_to_css(p.color),
            size: p.size,
            lifetime: p.lifetime / p.max_lifetime,
            type: p.event_type
          }
        end),
      emitters: Map.keys(state.emitters),
      attractors:
        Enum.map(state.attractors, fn a ->
          %{x: elem(a.position, 0), y: elem(a.position, 1), strength: a.strength}
        end),
      count: length(state.particles),
      max: state.config.max_particles
    }

    {:reply, json, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        active_particles: length(state.particles),
        emitter_count: map_size(state.emitters),
        attractor_count: length(state.attractors),
        utilization: length(state.particles) / state.config.max_particles
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:emit, emitter_id, count}, state) do
    case Map.get(state.emitters, emitter_id) do
      nil ->
        {:noreply, state}

      emitter ->
        new_particles = spawn_from_emitter(emitter, count, state)

        merged =
          (new_particles ++ state.particles)
          |> Enum.take(state.config.max_particles)

        new_stats = %{state.stats | spawned: state.stats.spawned + length(new_particles)}
        {:noreply, %{state | particles: merged, stats: new_stats}}
    end
  end

  @impl true
  def handle_cast({:register_emitter, id, position, config}, state) do
    emitter = %{
      id: id,
      position: position,
      spread: Map.get(config, :spread, :math.pi() / 4),
      speed: Map.get(config, :speed, 2.0),
      color: Map.get(config, :color, {255, 255, 255, 1.0}),
      size: Map.get(config, :size, 3.0),
      lifetime: Map.get(config, :lifetime, 2000.0),
      event_type: Map.get(config, :event_type, :generic)
    }

    new_emitters = Map.put(state.emitters, id, emitter)
    {:noreply, %{state | emitters: new_emitters}}
  end

  @impl true
  def handle_cast({:add_attractor, position, strength, radius}, state) do
    attractor = %{
      position: position,
      strength: strength,
      radius: radius
    }

    {:noreply, %{state | attractors: [attractor | state.attractors]}}
  end

  @impl true
  def handle_cast(:clear, state) do
    {:noreply, %{state | particles: []}}
  end

  @impl true
  def handle_info(:physics_update, state) do
    # Update physics
    dt = @physics_timestep / 1000.0

    {updated_particles, expired_count} =
      state.particles
      |> Enum.map(fn p -> update_particle(p, dt, state) end)
      |> Enum.split_with(fn p -> p.lifetime > 0 end)

    new_stats = %{
      state.stats
      | expired: state.stats.expired + length(expired_count),
        updates: state.stats.updates + 1
    }

    # Schedule next update
    Process.send_after(self(), :physics_update, @physics_timestep)

    {:noreply, %{state | particles: updated_particles, stats: new_stats}}
  end

  # Private helpers

  defp create_particle(position, velocity, event_type, opts) do
    lifetime = Keyword.get(opts, :lifetime, 2000.0)

    %{
      id: generate_id(),
      position: position,
      velocity: velocity,
      acceleration: {0.0, 0.0},
      color: Keyword.get(opts, :color, event_color(event_type)),
      size: Keyword.get(opts, :size, 3.0),
      lifetime: lifetime,
      max_lifetime: lifetime,
      event_type: event_type,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_bytes |> Base.encode16(case: :lower)
  end

  defp event_color(event_type) do
    case event_type do
      :success -> {0, 255, 0, 1.0}
      :error -> {255, 0, 0, 1.0}
      :warning -> {255, 255, 0, 1.0}
      :info -> {0, 150, 255, 1.0}
      :action -> {255, 150, 0, 1.0}
      :query -> {150, 0, 255, 1.0}
      _ -> {255, 255, 255, 1.0}
    end
  end

  defp spawn_from_emitter(emitter, count, state) do
    available = state.config.max_particles - length(state.particles)
    actual_count = min(count, available)

    Enum.map(1..actual_count, fn _ ->
      # Random angle within spread
      angle = :rand.uniform() * emitter.spread * 2 - emitter.spread
      speed = emitter.speed * (0.8 + :rand.uniform() * 0.4)

      velocity = {
        :math.cos(angle) * speed,
        :math.sin(angle) * speed
      }

      create_particle(
        emitter.position,
        velocity,
        emitter.event_type,
        color: emitter.color,
        size: emitter.size,
        lifetime: emitter.lifetime
      )
    end)
  end

  defp update_particle(particle, dt, state) do
    # Calculate forces
    gravity = state.config.gravity
    drag = state.config.drag

    # Attractor forces
    attractor_force =
      Enum.reduce(state.attractors, {0.0, 0.0}, fn attractor, {ax, ay} ->
        {fx, fy} = calculate_attractor_force(particle.position, attractor)
        {ax + fx, ay + fy}
      end)

    # Total acceleration
    {ax, ay} = {
      elem(gravity, 0) + elem(attractor_force, 0),
      elem(gravity, 1) + elem(attractor_force, 1)
    }

    # Update velocity
    {vx, vy} = particle.velocity

    new_velocity = {
      (vx + ax * dt) * drag,
      (vy + ay * dt) * drag
    }

    # Update position
    {px, py} = particle.position

    new_position = {
      px + elem(new_velocity, 0) * dt * 60,
      py + elem(new_velocity, 1) * dt * 60
    }

    # Bounce off bounds
    {bw, bh} = state.bounds
    {final_pos, final_vel} = bounce(new_position, new_velocity, bw, bh)

    # Update lifetime and color
    {new_lifetime, new_color} = update_particle_appearance(particle, dt)

    %{
      particle
      | position: final_pos,
        velocity: final_vel,
        lifetime: new_lifetime,
        color: new_color
    }
  end

  defp update_particle_appearance(particle, dt) do
    # Update lifetime
    new_lifetime = particle.lifetime - dt * 1000

    # Fade alpha based on lifetime
    {r, g, b, _a} = particle.color
    alpha = max(0.0, new_lifetime / particle.max_lifetime)
    new_color = {r, g, b, alpha}

    {new_lifetime, new_color}
  end

  defp calculate_attractor_force({px, py}, %{
         position: {ax, ay},
         strength: strength,
         radius: radius
       }) do
    dx = ax - px
    dy = ay - py
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist < radius and dist > 0.1 do
      # Normalize and scale by strength
      force = strength / (dist * dist)
      {dx / dist * force, dy / dist * force}
    else
      {0.0, 0.0}
    end
  end

  defp bounce({x, y}, {vx, vy}, width, height) do
    {new_x, new_vx} =
      cond do
        x < 0 -> {0, -vx * 0.8}
        x > width -> {width, -vx * 0.8}
        true -> {x, vx}
      end

    {new_y, new_vy} =
      cond do
        y < 0 -> {0, -vy * 0.8}
        y > height -> {height, -vy * 0.8}
        true -> {y, vy}
      end

    {{new_x, new_y}, {new_vx, new_vy}}
  end

  defp color_to_css({r, g, b, a}) do
    "rgba(#{r},#{g},#{b},#{Float.round(a, 2)})"
  end
end
