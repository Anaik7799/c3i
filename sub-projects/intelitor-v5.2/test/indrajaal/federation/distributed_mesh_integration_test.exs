defmodule Indrajaal.Federation.DistributedMeshIntegrationTest do
  @moduledoc """
  L5.1: Distributed Mesh Integration Tests.

  Tests the distributed mesh infrastructure:
  - DistributedMesh supervisor
  - AgentMesh integration
  - WorkerMesh integration
  - Mesh status and health

  STAMP Constraints:
  - SC-MESH-001: Unified mesh supervision
  - SC-MESH-002: Worker supervision
  - SC-MESH-003: Agent supervision
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.DistributedMesh
  alias Indrajaal.Distributed.AgentMesh
  alias Indrajaal.Distributed.WorkerMesh

  describe "L5.1: DistributedMesh Module" do
    test "DistributedMesh module is defined" do
      assert Code.ensure_loaded?(DistributedMesh)
    end

    test "DistributedMesh exports start_link/1" do
      assert function_exported?(DistributedMesh, :start_link, 1)
    end

    test "DistributedMesh exports health_check/0" do
      assert function_exported?(DistributedMesh, :health_check, 0)
    end
  end

  describe "L5.1: AgentMesh Module" do
    test "AgentMesh module is defined" do
      assert Code.ensure_loaded?(AgentMesh)
    end

    test "AgentMesh exports start_link/1" do
      assert function_exported?(AgentMesh, :start_link, 1)
    end

    test "AgentMesh exports list_agents/0" do
      assert function_exported?(AgentMesh, :list_agents, 0)
    end
  end

  describe "L5.1: WorkerMesh Module" do
    test "WorkerMesh module is defined" do
      assert Code.ensure_loaded?(WorkerMesh)
    end

    test "WorkerMesh exports start_link/1" do
      assert function_exported?(WorkerMesh, :start_link, 1)
    end

    test "WorkerMesh exports list_workers/0" do
      assert function_exported?(WorkerMesh, :list_workers, 0)
    end
  end

  describe "L5.1: Distributed Mesh Health" do
    test "health_check returns health status" do
      health = DistributedMesh.health_check()

      assert is_map(health)
    end
  end

  describe "L5.1: Agent Mesh Operations" do
    test "list_agents returns agent list" do
      agents = AgentMesh.list_agents()

      assert is_list(agents)
    end
  end

  describe "L5.1: Worker Mesh Operations" do
    test "list_workers returns worker list" do
      workers = WorkerMesh.list_workers()

      assert is_list(workers)
    end
  end
end
