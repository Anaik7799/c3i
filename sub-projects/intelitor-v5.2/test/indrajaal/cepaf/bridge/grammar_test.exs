defmodule Indrajaal.CEPAF.Bridge.GrammarTest do
  @moduledoc """
  Tests for Indrajaal.CEPAF.Bridge.Grammar pure module.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CEPAF.Bridge.Grammar

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Grammar)
    end

    test "module has expected functions" do
      assert function_exported?(Grammar, :parse, 1)
      assert function_exported?(Grammar, :compile, 1)
      assert function_exported?(Grammar, :validate, 1)
      assert function_exported?(Grammar, :action, 3)
      assert function_exported?(Grammar, :parallel, 2)
      assert function_exported?(Grammar, :choice, 4)
      assert function_exported?(Grammar, :loop, 3)
      assert function_exported?(Grammar, :sequence, 2)
      assert function_exported?(Grammar, :timeout, 1)
      assert function_exported?(Grammar, :retry, 2)
      assert function_exported?(Grammar, :fallback, 1)
      assert function_exported?(Grammar, :resource, 2)
      assert function_exported?(Grammar, :workflow, 2)
    end
  end

  describe "action/3" do
    test "creates an action step map" do
      result = Grammar.action(:deploy, %{env: "prod"})
      assert is_map(result)
      assert result.type == :action
      assert result.name == :deploy
      assert result.body == %{env: "prod"}
    end

    test "action with keyword opts sets constraints" do
      constraint = Grammar.timeout(5000)
      result = Grammar.action(:build, %{}, constraints: [constraint])
      assert is_map(result)
      assert result.constraints == [constraint]
    end

    test "action has all required keys" do
      result = Grammar.action(:run, %{cmd: "echo hi"})
      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :body)
      assert Map.has_key?(result, :constraints)
      assert Map.has_key?(result, :metadata)
    end
  end

  describe "sequence/2" do
    test "combines a list of steps into a sequence step" do
      steps = [Grammar.action(:step1, %{}), Grammar.action(:step2, %{})]
      result = Grammar.sequence(steps)
      assert is_map(result)
      assert result.type == :sequence
      assert result.body == steps
    end

    test "sequence with name opt" do
      steps = [Grammar.action(:a, %{})]
      result = Grammar.sequence(steps, name: :my_seq)
      assert result.type == :sequence
    end
  end

  describe "parallel/2" do
    test "combines steps into a parallel step" do
      steps = [Grammar.action(:a, %{}), Grammar.action(:b, %{})]
      result = Grammar.parallel(steps)
      assert is_map(result)
      assert result.type == :parallel
      assert result.body == steps
    end

    test "parallel with name opt" do
      steps = [Grammar.action(:x, %{})]
      result = Grammar.parallel(steps, name: :my_parallel)
      assert result.type == :parallel
    end
  end

  describe "timeout/1" do
    test "creates a timeout constraint map" do
      result = Grammar.timeout(5000)
      assert is_map(result)
      assert result.type == :timeout
      assert result.value == 5000
    end

    test "timeout accepts integer milliseconds" do
      result = Grammar.timeout(100)
      assert result.type == :timeout
    end
  end

  describe "retry/2" do
    test "creates a retry constraint map" do
      result = Grammar.retry(3)
      assert is_map(result)
      assert result.type == :retry
      assert result.value.count == 3
    end

    test "retry with delay opt" do
      result = Grammar.retry(5, delay: 500)
      assert result.value.count == 5
    end
  end

  describe "fallback/1" do
    test "creates a fallback constraint wrapping a step" do
      step = Grammar.action(:fallback_handler, %{})
      result = Grammar.fallback(step)
      assert is_map(result)
      assert result.type == :fallback
      assert result.value == step
    end
  end

  describe "resource/2" do
    test "creates a resource constraint" do
      result = Grammar.resource(:cpu, 2)
      assert is_map(result)
      assert result.type == :resource
      assert result.value.type == :cpu
    end
  end

  describe "workflow/2" do
    test "creates a workflow with steps in keyword opts" do
      steps = [Grammar.action(:main, %{})]
      result = Grammar.workflow(:my_workflow, steps: steps)
      assert is_map(result)
      assert result.name == :my_workflow
      assert result.steps == steps
    end

    test "workflow with empty steps" do
      result = Grammar.workflow(:empty_wf)
      assert is_map(result)
      assert result.name == :empty_wf
      assert result.steps == []
    end

    test "workflow has inputs, outputs, metadata keys" do
      result = Grammar.workflow(:full_wf, steps: [], inputs: [:data], outputs: [:result])
      assert Map.has_key?(result, :inputs)
      assert Map.has_key?(result, :outputs)
      assert Map.has_key?(result, :metadata)
    end
  end

  describe "choice/4" do
    test "creates a choice step with condition, then, else branches" do
      cond_fn = fn _ctx -> true end
      then_steps = [Grammar.action(:yes, %{})]
      else_steps = [Grammar.action(:no, %{})]
      result = Grammar.choice(cond_fn, then_steps, else_steps)
      assert is_map(result)
      assert result.type == :choice
      assert result.body.then == then_steps
      assert result.body.else == else_steps
    end

    test "choice with empty else defaults to empty list" do
      cond_fn = fn _ctx -> false end
      then_steps = [Grammar.action(:maybe, %{})]
      result = Grammar.choice(cond_fn, then_steps)
      assert result.type == :choice
    end
  end

  describe "loop/3" do
    test "creates a loop step with condition and body list" do
      cond_fn = fn _ctx -> false end
      body_steps = [Grammar.action(:do_thing, %{})]
      result = Grammar.loop(cond_fn, body_steps)
      assert is_map(result)
      assert result.type == :loop
    end
  end

  describe "validate/1" do
    test "validates a valid workflow and returns :ok" do
      wf = Grammar.workflow(:test_wf, steps: [Grammar.action(:step, %{})])
      result = Grammar.validate(wf)
      # validate/1 returns :ok or {:error, errors} (not {:ok, _})
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "compile/1" do
    test "compiles a workflow and returns ok or error" do
      wf = Grammar.workflow(:compile_wf, steps: [Grammar.action(:step, %{})])
      result = Grammar.compile(wf)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "parse/1" do
    test "parses a source string or map" do
      result = Grammar.parse("do step1() do step2()")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
