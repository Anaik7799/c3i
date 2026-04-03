defmodule Indrajaal.Substrate.L5.ClosureOperator do
  @moduledoc """
  L5 Closure Operator — Implements organisational closure (self-referential boundary).

  Pure module that checks whether a proposed operation stays within the identity
  boundary of the holon. Organisational closure means the holon's operations are
  self-referential: outputs feed back as inputs, and no operation may reference
  external authorities that contradict the Constitutional layer (L5).

  A "leak" is an operation that references an external dependency or outcome that
  falls outside the declared identity boundary. Closure degree is the fraction of
  operations that are fully contained.

  ## STAMP Compliance
  - SC-S5-001: Closure check validates constitutional boundary at L5
  - SC-S5-002: Leaks enumerated and returned for Guardian escalation
  - SC-S5-003: Boundary definition is immutable at L5 (compile-time constant)
  - SC-S5-004: Closure degree threshold >= 0.9 recommended

  ## Constitutional Alignment
  - Ψ₀ (Existence): Closure ensures the holon survives by remaining self-contained
  - Ω₇ (Holon State Sovereignty): External state dependencies violate closure
  - Ω₉ (Constitutional Reconfiguration): Boundary is fixed at L5
  """

  @type operation :: map()
  @type leak :: %{
          operation_id: term(),
          external_ref: term(),
          reason: String.t()
        }

  @type closure_check :: %{
          closed: boolean(),
          degree: float(),
          leaks: [leak()],
          checked_count: non_neg_integer()
        }

  # The declared identity boundary: permitted external domains
  @permitted_external [
    :zenoh_router,
    :postgresql,
    :otel_collector,
    :loki,
    :prometheus,
    :grafana
  ]

  # Internal namespaces that are always within boundary
  @internal_namespaces [
    :indrajaal,
    :cepaf,
    :prajna,
    :smriti,
    :sentinel,
    :cortex,
    :guardian,
    :chaya
  ]

  @closure_threshold 0.9

  @doc """
  Checks whether a list of operations satisfies organisational closure.

  An operation is within the boundary if all its `:dependencies` are either
  internal namespaces or explicitly permitted external systems.

  ## Parameters
  - `operations` — list of operation maps, each with optional `:id` and `:dependencies` keys

  ## Returns
  A `closure_check/0` map.
  """
  @spec is_closed?([operation()]) :: closure_check()
  def is_closed?([]) do
    %{closed: true, degree: 1.0, leaks: [], checked_count: 0}
  end

  def is_closed?(operations) when is_list(operations) do
    all_leaks =
      operations
      |> Enum.flat_map(fn op ->
        op_id = Map.get(op, :id, :unknown)
        deps = Map.get(op, :dependencies, [])
        find_leaks(op_id, deps)
      end)

    n = length(operations)
    leaked_ops = all_leaks |> Enum.map(& &1.operation_id) |> Enum.uniq() |> length()
    degree = if n > 0, do: Float.round((n - leaked_ops) / n, 4), else: 1.0

    %{
      closed: all_leaks == [],
      degree: degree,
      leaks: all_leaks,
      checked_count: n
    }
  end

  def is_closed?(_), do: %{closed: false, degree: 0.0, leaks: [], checked_count: 0}

  @doc """
  Returns the declared identity boundary.

  ## Returns
  Map with `:internal` and `:permitted_external` keys listing allowed namespaces.
  """
  @spec boundary() :: map()
  def boundary do
    %{
      internal: @internal_namespaces,
      permitted_external: @permitted_external,
      closure_threshold: @closure_threshold
    }
  end

  @doc """
  Computes the closure degree of a single operation.

  ## Parameters
  - `operation` — a single operation map with optional `:dependencies` key

  ## Returns
  Float in [0.0, 1.0]: 1.0 means fully closed, 0.0 means entirely external.
  """
  @spec closure_degree(operation()) :: float()
  def closure_degree(operation) when is_map(operation) do
    deps = Map.get(operation, :dependencies, [])

    case deps do
      [] ->
        1.0

      deps_list ->
        closed_count =
          Enum.count(deps_list, fn dep ->
            within_boundary?(dep)
          end)

        Float.round(closed_count / length(deps_list), 4)
    end
  end

  def closure_degree(_), do: 0.0

  @doc """
  Returns all leaks from a list of operations.

  ## Parameters
  - `operations` — list of operation maps

  ## Returns
  List of `leak/0` maps for all boundary violations found.
  """
  @spec leaks([operation()]) :: [leak()]
  def leaks(operations) when is_list(operations) do
    Enum.flat_map(operations, fn op ->
      op_id = Map.get(op, :id, :unknown)
      deps = Map.get(op, :dependencies, [])
      find_leaks(op_id, deps)
    end)
  end

  def leaks(_), do: []

  # --- Private helpers ---

  @spec find_leaks(term(), [term()]) :: [leak()]
  defp find_leaks(op_id, deps) when is_list(deps) do
    deps
    |> Enum.reject(&within_boundary?/1)
    |> Enum.map(fn ext_ref ->
      %{
        operation_id: op_id,
        external_ref: ext_ref,
        reason: "Dependency '#{inspect(ext_ref)}' is outside identity boundary."
      }
    end)
  end

  defp find_leaks(_, _), do: []

  @spec within_boundary?(term()) :: boolean()
  defp within_boundary?(dep) when is_atom(dep) do
    namespace = extract_namespace(dep)

    Enum.member?(@internal_namespaces, namespace) or
      Enum.member?(@permitted_external, dep) or
      Enum.member?(@permitted_external, namespace)
  end

  defp within_boundary?(dep) when is_binary(dep) do
    atom_dep = String.to_atom(String.split(dep, ".") |> List.first() |> String.downcase())
    within_boundary?(atom_dep)
  end

  defp within_boundary?(_), do: false

  @spec extract_namespace(atom()) :: atom()
  defp extract_namespace(atom) do
    atom
    |> Atom.to_string()
    |> String.split(".")
    |> List.first()
    |> String.downcase()
    |> String.to_atom()
  rescue
    _ -> atom
  end
end
