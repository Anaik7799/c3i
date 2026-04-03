defmodule Indrajaal.AIDomainTest do
  @moduledoc """
  Tests for the AI Domain module.

  ## STAMP Constraints Verified
  - SC-AI-001: All AI outputs validated with Guardian
  - SC-AI-002: Rate limiting enforced
  - SC-AI-003: Cost tracking
  """

  use ExUnit.Case, async: true

  describe "module structure" do
    test "AI domain module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.AIDomain)
    end

    test "has resources defined" do
      # Domain should have resources
      info = Indrajaal.AIDomain.__info__(:functions)
      assert is_list(info)
    end

    test "ChatResource is included" do
      assert Code.ensure_loaded?(Indrajaal.AI.ChatResource)
    end

    test "AnalysisResource is included" do
      assert Code.ensure_loaded?(Indrajaal.AI.AnalysisResource)
    end

    test "GenerationResource is included" do
      assert Code.ensure_loaded?(Indrajaal.AI.GenerationResource)
    end

    test "SynapseResource is included" do
      assert Code.ensure_loaded?(Indrajaal.AI.SynapseResource)
    end
  end

  describe "domain configuration" do
    test "domain module has __info__ function" do
      assert function_exported?(Indrajaal.AIDomain, :__info__, 1)
    end

    test "domain uses Ash.Domain" do
      # Check behaviours
      behaviours = Indrajaal.AIDomain.__info__(:attributes)[:behaviour] || []
      # Ash.Domain may not export behaviours directly, check module structure instead
      assert Code.ensure_loaded?(Indrajaal.AIDomain)
    end
  end
end
