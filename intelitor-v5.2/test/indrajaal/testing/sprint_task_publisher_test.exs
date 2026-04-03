defmodule Indrajaal.Testing.SprintTaskPublisherTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Testing.SprintTaskPublisher

  test "module is loaded" do
    assert Code.ensure_loaded?(SprintTaskPublisher)
  end

  test "task_registry/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_registry, 0)
  end

  test "dependency_dag/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :dependency_dag, 0)
  end

  test "waves/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :waves, 0)
  end

  test "task_info/1 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_info, 1)
  end

  test "tasks_for_wave/1 is defined" do
    assert function_exported?(SprintTaskPublisher, :tasks_for_wave, 1)
  end

  test "dependencies/1 is defined" do
    assert function_exported?(SprintTaskPublisher, :dependencies, 1)
  end

  test "dependencies_satisfied?/2 is defined" do
    assert function_exported?(SprintTaskPublisher, :dependencies_satisfied?, 2)
  end

  test "task_started/1 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_started, 1)
  end

  test "task_progress/4 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_progress, 4)
  end

  test "task_completed/2 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_completed, 2)
  end

  test "task_failed/2 is defined" do
    assert function_exported?(SprintTaskPublisher, :task_failed, 2)
  end

  test "wave_started/1 is defined" do
    assert function_exported?(SprintTaskPublisher, :wave_started, 1)
  end

  test "wave_completed/2 is defined" do
    assert function_exported?(SprintTaskPublisher, :wave_completed, 2)
  end

  test "wave_gate/2 is defined" do
    assert function_exported?(SprintTaskPublisher, :wave_gate, 2)
  end

  test "critical_tasks/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :critical_tasks, 0)
  end

  test "tasks_by_wave/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :tasks_by_wave, 0)
  end

  test "critical_path/0 is defined" do
    assert function_exported?(SprintTaskPublisher, :critical_path, 0)
  end

  test "task_registry/0 returns a map" do
    registry = SprintTaskPublisher.task_registry()
    assert is_map(registry)
  end

  test "waves/0 returns an enumerable (list or map)" do
    waves = SprintTaskPublisher.waves()

    assert is_list(waves) or is_map(waves),
           "Expected waves/0 to return a list or map, got: #{inspect(waves)}"
  end

  test "critical_tasks/0 returns a list" do
    tasks = SprintTaskPublisher.critical_tasks()
    assert is_list(tasks)
  end

  test "tasks_by_wave/0 returns an enumerable (map or list)" do
    by_wave = SprintTaskPublisher.tasks_by_wave()

    assert is_map(by_wave) or is_list(by_wave),
           "Expected tasks_by_wave/0 to return a map or list, got: #{inspect(by_wave)}"
  end

  test "dependency_dag/0 returns a map" do
    dag = SprintTaskPublisher.dependency_dag()
    assert is_map(dag)
  end
end
