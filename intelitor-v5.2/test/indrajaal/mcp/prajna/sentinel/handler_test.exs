defmodule Indrajaal.MCP.Prajna.Sentinel.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.Sentinel.Handler.

  ## STAMP Safety Integration
  - SC-IMMUNE-001: Sentinel monitors continuously
  - SC-IMMUNE-002: Sentinel must NOT terminate kernel processes
  - SC-IMMUNE-004: PatternHunter detects pre-error signatures

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sentinel quarantine allows kernel process termination
  - L5 Root Cause: check_kernel_protection not called before quarantine
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.Sentinel.Handler

  @context %{client_id: "sentinel_test_client"}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end
  end

  describe "domain and namespace" do
    test "domain is :sentinel" do
      assert Handler.domain() == :sentinel
    end

    test "namespace is :prajna" do
      assert Handler.namespace() == :prajna
    end
  end

  describe "list_tools/0" do
    test "returns 9 tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) == 9
    end

    test "includes sentinel.health tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)
      assert "prajna.sentinel.health" in names
    end

    test "defend tool requires Guardian" do
      tools = Handler.list_tools()
      defend = Enum.find(tools, fn t -> t.name == "prajna.sentinel.defend" end)
      assert defend != nil
      assert defend.requires_guardian == true
    end
  end

  describe "handle(:health, args, context)" do
    test "returns ok with overall_score" do
      result = Handler.handle(:health, %{}, @context)
      assert {:ok, data} = result
      score = Map.get(data, :overall_score) || Map.get(data, "overall_score")
      assert is_float(score) or is_integer(score)
    end

    test "overall_score is between 0 and 1" do
      {:ok, data} = Handler.handle(:health, %{}, @context)
      score = Map.get(data, :overall_score) || Map.get(data, "overall_score")
      assert score >= 0.0 and score <= 1.0
    end

    test "returns components map" do
      {:ok, data} = Handler.handle(:health, %{}, @context)
      components = Map.get(data, :components) || Map.get(data, "components")
      assert is_map(components)
    end
  end

  describe "handle(:assess, args, context)" do
    test "returns ok with assessment id" do
      result = Handler.handle(:assess, %{}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :id) or Map.has_key?(data, "id")
    end

    test "deep_scan flag accepted" do
      result = Handler.handle(:assess, %{"deep_scan" => true}, @context)
      assert {:ok, data} = result
      deep = Map.get(data, :deep_scan) || Map.get(data, "deep_scan")
      assert deep == true
    end
  end

  describe "handle(:threats, args, context)" do
    test "returns ok with threats list" do
      result = Handler.handle(:threats, %{}, @context)
      assert {:ok, data} = result
      threats = Map.get(data, :threats) || Map.get(data, "threats")
      assert is_list(threats)
    end

    test "returns response_sla map" do
      {:ok, data} = Handler.handle(:threats, %{}, @context)
      sla = Map.get(data, :response_sla) || Map.get(data, "response_sla")
      assert is_map(sla)
    end
  end

  describe "handle(:patterns, args, context)" do
    test "returns ok with patterns list" do
      result = Handler.handle(:patterns, %{}, @context)
      assert {:ok, data} = result
      patterns = Map.get(data, :patterns) || Map.get(data, "patterns")
      assert is_list(patterns)
    end

    test "baseline_calibrated is boolean" do
      {:ok, data} = Handler.handle(:patterns, %{}, @context)
      calibrated = Map.get(data, :baseline_calibrated) || Map.get(data, "baseline_calibrated")
      assert is_boolean(calibrated)
    end
  end

  describe "handle(:defend, args, context)" do
    test "returns ok with defense status" do
      args = %{"threat_id" => "threat_001", "defense_type" => "isolation"}
      result = Handler.handle(:defend, args, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :status) or Map.has_key?(data, "status")
    end

    test "returns error when threat_id is missing" do
      result = Handler.handle(:defend, %{"defense_type" => "isolation"}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:quarantine, args, context)" do
    test "returns ok with kernel_protected field" do
      args = %{"target" => "worker_process_abc"}
      result = Handler.handle(:quarantine, args, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :kernel_protected) or Map.has_key?(data, "kernel_protected")
    end

    test "kernel processes are protected (SC-IMMUNE-002)" do
      args = %{"target" => "guardian"}
      {:ok, data} = Handler.handle(:quarantine, args, @context)
      kernel_protected = Map.get(data, :kernel_protected) || Map.get(data, "kernel_protected")
      is_kernel = Map.get(kernel_protected, :is_kernel) || Map.get(kernel_protected, "is_kernel")
      assert is_kernel == true
    end

    test "non-kernel processes can be quarantined" do
      args = %{"target" => "user_defined_process"}
      {:ok, data} = Handler.handle(:quarantine, args, @context)
      kernel_protected = Map.get(data, :kernel_protected) || Map.get(data, "kernel_protected")
      is_kernel = Map.get(kernel_protected, :is_kernel) || Map.get(kernel_protected, "is_kernel")
      assert is_kernel == false
    end
  end

  describe "handle(:heal, args, context)" do
    test "returns ok with healing steps" do
      result = Handler.handle(:heal, %{}, @context)
      assert {:ok, data} = result
      steps = Map.get(data, :steps) || Map.get(data, "steps")
      assert is_list(steps)
    end
  end

  describe "handle(:mara, args, context)" do
    test "returns ok with mara_test key" do
      result = Handler.handle(:mara, %{}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :mara_test) or Map.has_key?(data, "mara_test")
    end

    test "mara is in safe_mode" do
      {:ok, data} = Handler.handle(:mara, %{}, @context)
      mara = Map.get(data, :mara_test) || Map.get(data, "mara_test")
      safe = Map.get(mara, :safe_mode) || Map.get(mara, "safe_mode")
      assert safe == true
    end
  end

  describe "handle(:antibody, args, context)" do
    test "returns ok with active antibody" do
      args = %{"threat_id" => "threat_001"}
      result = Handler.handle(:antibody, args, @context)
      assert {:ok, data} = result
      status = Map.get(data, :status) || Map.get(data, "status")
      assert status == "active"
    end

    test "returns error when threat_id is missing" do
      result = Handler.handle(:antibody, %{}, @context)
      assert {:error, _} = result
    end
  end
end
