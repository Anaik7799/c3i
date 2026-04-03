defmodule Indrajaal.MCP.Prajna.Guardian.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.Guardian.Handler.

  ## STAMP Safety Integration
  - SC-PRAJNA-001: All commands through Guardian pre-approval
  - SC-PRAJNA-002: Founder's Directive validation mandatory
  - SC-CONST-007: Guardian has absolute veto

  ## Constitutional Verification
  - Ψ₀ Existence: Guardian veto preserves system existence
  - Ψ₄ Human Alignment: Founder's Directive validation active

  ## TPS 5-Level RCA Context
  - L1 Symptom: Guardian approve returns wrong proposal_id
  - L5 Root Cause: approve/3 context.client_id not set in test context
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.Guardian.Handler

  @context %{client_id: "guardian_test_client"}

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
    test "domain is :guardian" do
      assert Handler.domain() == :guardian
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

    test "includes guardian.status tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)
      assert "prajna.guardian.status" in names
    end

    test "veto tool requires Guardian and proof token" do
      tools = Handler.list_tools()
      veto = Enum.find(tools, fn t -> t.name == "prajna.guardian.veto" end)
      assert veto != nil
      assert veto.requires_guardian == true
      assert veto.requires_proof_token == true
    end
  end

  describe "handle(:status, args, context)" do
    test "returns ok with guardian_active true" do
      result = Handler.handle(:status, %{}, @context)
      assert {:ok, data} = result
      active = Map.get(data, :guardian_active) || Map.get(data, "guardian_active")
      assert active == true
    end

    test "returns invariants list" do
      {:ok, data} = Handler.handle(:status, %{}, @context)
      invariants = Map.get(data, :invariants) || Map.get(data, "invariants")
      assert is_list(invariants)
      assert length(invariants) == 6
    end
  end

  describe "handle(:propose, args, context)" do
    test "returns ok with proposal when action and resource provided" do
      args = %{"action" => "create", "resource" => "user:usr_001"}
      result = Handler.handle(:propose, args, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :proposal) or Map.has_key?(data, "proposal")
    end

    test "returns error when action is missing" do
      result = Handler.handle(:propose, %{"resource" => "user:usr_001"}, @context)
      assert {:error, _} = result
    end

    test "returns constitutional_status in response" do
      args = %{"action" => "read", "resource" => "alarm:alm_001"}
      {:ok, data} = Handler.handle(:propose, args, @context)

      assert Map.has_key?(data, :constitutional_status) or
               Map.has_key?(data, "constitutional_status")
    end
  end

  describe "handle(:approve, args, context)" do
    test "returns ok with approved status" do
      args = %{"proposal_id" => "prop_001"}
      result = Handler.handle(:approve, args, @context)
      assert {:ok, data} = result
      status = Map.get(data, :status) || Map.get(data, "status")
      assert status == "approved"
    end

    test "returns error when proposal_id is missing" do
      result = Handler.handle(:approve, %{}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:reject, args, context)" do
    test "returns ok with rejected status" do
      args = %{"proposal_id" => "prop_002", "reason" => "Insufficient justification"}
      result = Handler.handle(:reject, args, @context)
      assert {:ok, data} = result
      status = Map.get(data, :status) || Map.get(data, "status")
      assert status == "rejected"
    end

    test "returns error when reason is missing" do
      result = Handler.handle(:reject, %{"proposal_id" => "prop_002"}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:pending, args, context)" do
    test "returns ok with proposals list" do
      result = Handler.handle(:pending, %{}, @context)
      assert {:ok, data} = result
      proposals = Map.get(data, :proposals) || Map.get(data, "proposals")
      assert is_list(proposals)
    end
  end

  describe "handle(:history, args, context)" do
    test "returns ok with history list" do
      result = Handler.handle(:history, %{}, @context)
      assert {:ok, data} = result
      history = Map.get(data, :history) || Map.get(data, "history")
      assert is_list(history)
    end
  end

  describe "handle(:veto, args, context)" do
    test "returns ok with override_possible false" do
      args = %{"target" => "operation:op_001", "reason" => "Constitutional violation"}
      result = Handler.handle(:veto, args, @context)
      assert {:ok, data} = result
      veto = Map.get(data, :veto) || Map.get(data, "veto")
      override = Map.get(veto, :override_possible) || Map.get(veto, "override_possible")
      assert override == false
    end

    test "returns error when target is missing" do
      result = Handler.handle(:veto, %{"reason" => "no target"}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:constitution_check, args, context)" do
    test "returns ok with compliance result" do
      args = %{"action" => "read"}
      result = Handler.handle(:constitution_check, args, @context)
      assert {:ok, data} = result
      compliance = Map.get(data, :compliance) || Map.get(data, "compliance")
      assert is_map(compliance)
    end

    test "non-violating action returns compliant: true" do
      args = %{"action" => "read"}
      {:ok, data} = Handler.handle(:constitution_check, args, @context)
      compliance = Map.get(data, :compliance) || Map.get(data, "compliance")
      compliant = Map.get(compliance, :compliant) || Map.get(compliance, "compliant")
      assert compliant == true
    end

    test "violating action returns compliant: false" do
      args = %{"action" => "disable_guardian"}
      {:ok, data} = Handler.handle(:constitution_check, args, @context)
      compliance = Map.get(data, :compliance) || Map.get(data, "compliance")
      compliant = Map.get(compliance, :compliant) || Map.get(compliance, "compliant")
      assert compliant == false
    end
  end

  describe "handle(:founder_validate, args, context)" do
    test "returns ok with founder_alignment" do
      args = %{"action" => "expand"}
      result = Handler.handle(:founder_validate, args, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :founder_alignment) or Map.has_key?(data, "founder_alignment")
    end

    test "returns error when action is missing" do
      result = Handler.handle(:founder_validate, %{}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(unknown, args, context)" do
    test "returns error for unknown action" do
      result = Handler.handle(:completely_unknown_guardian_action, %{}, @context)
      assert {:error, _} = result
    end
  end
end
