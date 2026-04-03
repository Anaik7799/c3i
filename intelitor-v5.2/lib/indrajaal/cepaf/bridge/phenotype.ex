defmodule Indrajaal.CEPAF.Bridge.Phenotype do
  @moduledoc """
  CEPAF Phenotype - Genotype Expression Engine for v20.0.0

  Implements phenotype expression from genetic workflows:
  - Genotype → Phenotype mapping
  - Environment-dependent expression
  - Phenotype evaluation
  - Adaptation strategies

  ## Expression Model

  Phenotype = f(Genotype, Environment)

  Where:
  - Genotype = workflow structure (genes/steps)
  - Environment = runtime context (resources, constraints)
  - Phenotype = executable behavior

  ## STAMP Constraints
  - SC-PHE-001: Expression MUST be deterministic for same inputs
  - SC-PHE-002: Environment changes MUST trigger re-expression
  - SC-PHE-003: Invalid genotypes MUST produce null phenotype
  - SC-PHE-004: Expression latency < 100ms
  """

  require Logger

  alias Indrajaal.CEPAF.Bridge.{Genetic, Grammar}

  @type environment :: %{
          resources: map(),
          constraints: [term()],
          capabilities: [atom()],
          load: float()
        }

  @type phenotype :: %{
          id: String.t(),
          genome_id: String.t(),
          workflow: Grammar.workflow(),
          environment: environment(),
          expressed_at: DateTime.t(),
          traits: map(),
          fitness: float() | nil
        }

  @type expression_strategy :: :full | :adaptive | :minimal | :cached

  @doc """
  Expresses a genotype into a phenotype given an environment.
  """
  @spec express(Genetic.genome(), environment(), expression_strategy()) ::
          {:ok, phenotype()} | {:error, term()}
  def express(genome, environment, strategy \\ :adaptive) do
    start = System.monotonic_time(:millisecond)

    result =
      case strategy do
        :full -> full_expression(genome, environment)
        :adaptive -> adaptive_expression(genome, environment)
        :minimal -> minimal_expression(genome, environment)
        :cached -> cached_expression(genome, environment)
      end

    elapsed = System.monotonic_time(:millisecond) - start

    if elapsed > 100 do
      Logger.warning("Phenotype expression took #{elapsed}ms (SC-PHE-004 violation)")
    end

    result
  end

  @doc """
  Evaluates phenotype fitness in current environment.
  """
  @spec evaluate_fitness(phenotype()) :: float()
  def evaluate_fitness(phenotype) do
    base_fitness = phenotype.fitness || 50.0

    # Adjust based on environment match
    resource_match = calculate_resource_match(phenotype)
    constraint_satisfaction = calculate_constraint_satisfaction(phenotype)
    load_adjustment = calculate_load_adjustment(phenotype)

    base_fitness * resource_match * constraint_satisfaction * load_adjustment
  end

  @doc """
  Adapts phenotype to environment changes.
  """
  @spec adapt(phenotype(), environment()) :: {:ok, phenotype()} | {:error, term()}
  def adapt(phenotype, new_environment) do
    if environment_changed?(phenotype.environment, new_environment) do
      # Re-express with new environment
      genome = %{
        id: phenotype.genome_id,
        chromosome: phenotype.workflow.steps,
        fitness: phenotype.fitness,
        generation: 0,
        parents: []
      }

      express(genome, new_environment, :adaptive)
    else
      {:ok, phenotype}
    end
  end

  @doc """
  Extracts observable traits from phenotype.
  """
  @spec extract_traits(phenotype()) :: map()
  def extract_traits(phenotype) do
    workflow = phenotype.workflow

    %{
      step_count: length(workflow.steps),
      parallelism: count_parallel_branches(workflow.steps),
      max_depth: calculate_max_depth(workflow.steps),
      has_loops: has_loops?(workflow.steps),
      has_choices: has_choices?(workflow.steps),
      estimated_duration: estimate_duration(workflow.steps),
      resource_requirements: extract_resource_requirements(workflow.steps),
      error_handling: has_error_handling?(workflow.steps)
    }
  end

  @doc """
  Compares two phenotypes for similarity.
  """
  @spec similarity(phenotype(), phenotype()) :: float()
  def similarity(pheno1, pheno2) do
    traits1 = extract_traits(pheno1)
    traits2 = extract_traits(pheno2)

    # Compare numeric traits
    numeric_keys = [:step_count, :parallelism, :max_depth, :estimated_duration]

    numeric_sim =
      numeric_keys
      |> Enum.map(fn key ->
        v1 = Map.get(traits1, key, 0)
        v2 = Map.get(traits2, key, 0)
        1.0 - abs(v1 - v2) / max(max(v1, v2), 1)
      end)
      |> Enum.sum()
      |> Kernel./(length(numeric_keys))

    # Compare boolean traits
    bool_keys = [:has_loops, :has_choices, :error_handling]

    bool_sim =
      bool_keys
      |> Enum.map(fn key ->
        if Map.get(traits1, key) == Map.get(traits2, key), do: 1.0, else: 0.0
      end)
      |> Enum.sum()
      |> Kernel./(length(bool_keys))

    (numeric_sim + bool_sim) / 2.0
  end

  @doc """
  Creates a default environment.
  """
  @spec default_environment() :: environment()
  def default_environment do
    %{
      resources: %{
        cpu: 1.0,
        memory: 1024,
        network: 100
      },
      constraints: [],
      capabilities: [:compute, :io, :network],
      load: 0.5
    }
  end

  # Private: Expression strategies

  defp full_expression(genome, environment) do
    # Express all genes without optimization
    workflow = Genetic.to_workflow(genome, :expressed_workflow)

    phenotype = %{
      id: generate_id(),
      genome_id: genome.id,
      workflow: workflow,
      environment: environment,
      expressed_at: DateTime.utc_now(),
      traits: %{},
      fitness: genome.fitness
    }

    # Extract traits
    traits = extract_traits(phenotype)
    {:ok, %{phenotype | traits: traits}}
  end

  defp adaptive_expression(genome, environment) do
    # Adapt expression based on environment
    adapted_steps = adapt_steps_to_environment(genome.chromosome, environment)

    workflow = %{
      name: :adaptive_workflow,
      steps: adapted_steps,
      inputs: [],
      outputs: [],
      metadata: %{strategy: :adaptive}
    }

    phenotype = %{
      id: generate_id(),
      genome_id: genome.id,
      workflow: workflow,
      environment: environment,
      expressed_at: DateTime.utc_now(),
      traits: %{},
      fitness: genome.fitness
    }

    traits = extract_traits(phenotype)
    {:ok, %{phenotype | traits: traits}}
  end

  defp minimal_expression(genome, environment) do
    # Express only essential steps
    essential_steps =
      genome.chromosome
      |> Enum.filter(&essential_step?/1)

    workflow = %{
      name: :minimal_workflow,
      steps: essential_steps,
      inputs: [],
      outputs: [],
      metadata: %{strategy: :minimal}
    }

    phenotype = %{
      id: generate_id(),
      genome_id: genome.id,
      workflow: workflow,
      environment: environment,
      expressed_at: DateTime.utc_now(),
      traits: %{},
      fitness: genome.fitness
    }

    traits = extract_traits(phenotype)
    {:ok, %{phenotype | traits: traits}}
  end

  defp cached_expression(genome, environment) do
    # Check cache (simplified - would use ETS in production)
    cache_key = {genome.id, :erlang.phash2(environment)}

    case Process.get({:phenotype_cache, cache_key}) do
      nil ->
        {:ok, phenotype} = full_expression(genome, environment)
        Process.put({:phenotype_cache, cache_key}, phenotype)
        {:ok, phenotype}

      cached ->
        {:ok, cached}
    end
  end

  # Private: Adaptation

  defp adapt_steps_to_environment(steps, environment) do
    steps
    |> Enum.map(fn step ->
      adapted = adapt_single_step(step, environment)
      adapted
    end)
  end

  defp adapt_single_step(%{type: :parallel, body: parallel_steps} = step, environment) do
    # Limit parallelism based on CPU
    max_parallel = round(environment.resources.cpu * 4)
    limited_steps = Enum.take(parallel_steps, max_parallel)
    %{step | body: limited_steps}
  end

  defp adapt_single_step(%{type: :action, constraints: constraints} = step, environment) do
    # Adjust timeouts based on load
    load_factor = 1.0 + environment.load

    adjusted_constraints =
      constraints
      |> Enum.map(fn
        %{type: :timeout, value: ms} ->
          %{type: :timeout, value: round(ms * load_factor)}

        other ->
          other
      end)

    %{step | constraints: adjusted_constraints}
  end

  defp adapt_single_step(step, _environment), do: step

  defp essential_step?(%{type: :action, name: name}) do
    essential_actions = [:compute, :transform, :aggregate, :output]
    name in essential_actions
  end

  defp essential_step?(%{type: type}) when type in [:choice, :loop], do: true
  defp essential_step?(_), do: false

  # Private: Environment comparison

  defp environment_changed?(env1, env2) do
    env1.load != env2.load or
      env1.resources != env2.resources or
      env1.capabilities != env2.capabilities
  end

  # Private: Fitness calculations

  defp calculate_resource_match(phenotype) do
    requirements = phenotype.traits[:resource_requirements] || %{}
    available = phenotype.environment.resources

    if map_size(requirements) == 0 do
      1.0
    else
      matches =
        requirements
        |> Enum.map(fn {resource, required} ->
          have = Map.get(available, resource, 0)
          min(1.0, have / max(required, 1))
        end)

      Enum.sum(matches) / length(matches)
    end
  end

  defp calculate_constraint_satisfaction(phenotype) do
    constraints = phenotype.environment.constraints
    workflow_constraints = count_workflow_constraints(phenotype.workflow.steps)

    if constraints == [] do
      1.0
    else
      # Simplified: assume constraints are satisfied if workflow has error handling
      if workflow_constraints > 0, do: 0.9, else: 0.7
    end
  end

  defp calculate_load_adjustment(phenotype) do
    load = phenotype.environment.load
    # Higher load reduces effective fitness
    1.0 - load * 0.3
  end

  # Private: Trait extraction

  defp count_parallel_branches(steps) do
    steps
    |> Enum.reduce(0, fn
      %{type: :parallel, body: body}, acc -> acc + length(body)
      _, acc -> acc
    end)
  end

  defp calculate_max_depth(steps) do
    calculate_depth(steps, 0)
  end

  defp calculate_depth([], current), do: current

  defp calculate_depth([step | rest], current) do
    step_depth =
      case step do
        %{type: :parallel, body: body} ->
          max(current + 1, calculate_depth(body, current + 1))

        %{type: :choice, body: %{then: then_branch, else: else_branch}} ->
          max(
            calculate_depth(then_branch, current + 1),
            calculate_depth(else_branch, current + 1)
          )

        %{type: :loop, body: %{body: loop_body}} ->
          calculate_depth(loop_body, current + 1)

        %{type: :sequence, body: seq_steps} ->
          calculate_depth(seq_steps, current + 1)

        _ ->
          current + 1
      end

    max(step_depth, calculate_depth(rest, current))
  end

  defp has_loops?(steps) do
    steps
    |> Enum.any?(fn
      %{type: :loop} -> true
      %{type: :parallel, body: body} -> has_loops?(body)
      %{type: :choice, body: %{then: t, else: e}} -> has_loops?(t) or has_loops?(e)
      %{type: :sequence, body: s} -> has_loops?(s)
      _ -> false
    end)
  end

  defp has_choices?(steps) do
    steps
    |> Enum.any?(fn
      %{type: :choice} -> true
      %{type: :parallel, body: body} -> has_choices?(body)
      %{type: :sequence, body: s} -> has_choices?(s)
      _ -> false
    end)
  end

  defp estimate_duration(steps) do
    steps
    |> Enum.reduce(0, fn step, acc ->
      step_duration =
        case step do
          %{type: :action, constraints: constraints} ->
            find_timeout(constraints, 1000)

          %{type: :parallel, body: body} ->
            # Parallel: max of children
            body
            |> Enum.map(&estimate_single_step_duration/1)
            |> Enum.max(fn -> 0 end)

          %{type: :loop, body: %{body: loop_body}} ->
            # Assume 3 iterations
            estimate_duration(loop_body) * 3

          _ ->
            100
        end

      acc + step_duration
    end)
  end

  defp estimate_single_step_duration(%{constraints: constraints}) do
    find_timeout(constraints, 1000)
  end

  defp estimate_single_step_duration(_), do: 100

  defp find_timeout(constraints, default) do
    case Enum.find(constraints, fn c -> c.type == :timeout end) do
      nil -> default
      %{value: ms} -> ms
    end
  end

  defp extract_resource_requirements(steps) do
    steps
    |> Enum.reduce(%{}, fn step, acc ->
      step_requirements = get_step_requirements(step)
      Map.merge(acc, step_requirements, fn _, v1, v2 -> max(v1, v2) end)
    end)
  end

  defp get_step_requirements(%{type: :action, name: name}) do
    case name do
      :compute -> %{cpu: 0.5}
      :transform -> %{cpu: 0.3, memory: 256}
      :aggregate -> %{memory: 512}
      :fetch -> %{network: 10}
      _ -> %{}
    end
  end

  defp get_step_requirements(%{type: :parallel, body: body}) do
    body
    |> Enum.reduce(%{}, fn step, acc ->
      Map.merge(acc, get_step_requirements(step), fn _, v1, v2 -> v1 + v2 end)
    end)
  end

  defp get_step_requirements(_), do: %{}

  defp has_error_handling?(steps) do
    steps
    |> Enum.any?(fn step ->
      constraints = Map.get(step, :constraints, [])
      constraints |> Enum.any?(fn c -> c.type in [:retry, :fallback] end)
    end)
  end

  defp count_workflow_constraints(steps) do
    steps
    |> Enum.reduce(0, fn step, acc ->
      acc + length(Map.get(step, :constraints, []))
    end)
  end

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(bytes, case: :lower)
  end
end
