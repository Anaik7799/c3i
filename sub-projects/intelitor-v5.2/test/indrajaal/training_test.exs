defmodule Indrajaal.TrainingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Training

  test "module exists" do
    assert Code.ensure_loaded?(Training)
  end

  test "list_courses/1 is exported" do
    assert function_exported?(Training, :list_courses, 1)
  end

  test "get_course/2 is exported" do
    assert function_exported?(Training, :get_course, 2)
  end

  test "create_course/2 is exported" do
    assert function_exported?(Training, :create_course, 2)
  end

  test "update_course/3 is exported" do
    assert function_exported?(Training, :update_course, 3)
  end
end
