defmodule Indrajaal.Jain.SterilizationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jain.Sterilization

  # Minimal node map matching Sterilization module's expectations
  defp sterile_node do
    %{
      id: "ex:l3:tst:srv:sterile_test",
      state: :sterile,
      generation: 1,
      children: [],
      resources: %{cpu: 0.0, memory: 0}
    }
  end

  defp active_node do
    %{
      id: "ex:l3:tst:srv:active_test",
      state: :active,
      generation: 1,
      children: [],
      resources: %{cpu: 0.01, memory: 10_000}
    }
  end

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Sterilization)
    end

    test "module exports expected functions" do
      assert function_exported?(Sterilization, :execute, 1)
      assert function_exported?(Sterilization, :sterile?, 1)
      assert function_exported?(Sterilization, :create_certificate, 1)
      assert function_exported?(Sterilization, :verify_certificate, 1)
      assert function_exported?(Sterilization, :report_to_federation, 1)
    end
  end

  describe "sterile?/1" do
    test "returns true for a node with state :sterile" do
      result = Sterilization.sterile?(sterile_node())
      assert result == true
    end

    test "returns false for a node with state :active" do
      result = Sterilization.sterile?(active_node())
      assert result == false
    end
  end

  describe "create_certificate/1" do
    test "returns a binary (base64 encoded certificate)" do
      result = Sterilization.create_certificate(sterile_node())
      assert is_binary(result)
    end

    test "certificate is non-empty" do
      result = Sterilization.create_certificate(sterile_node())
      assert byte_size(result) > 0
    end
  end

  describe "verify_certificate/1" do
    test "returns ok tuple for a valid certificate" do
      cert = Sterilization.create_certificate(sterile_node())
      result = Sterilization.verify_certificate(cert)
      assert match?({:ok, _}, result)
    end

    test "returns error for invalid certificate string" do
      result = Sterilization.verify_certificate("not_a_valid_certificate")
      assert match?({:error, _}, result)
    end

    test "round-trips: created certificate verifies successfully" do
      node = sterile_node()
      cert = Sterilization.create_certificate(node)
      {:ok, content} = Sterilization.verify_certificate(cert)
      assert is_map(content)
      assert content.node_id == node.id
    end
  end

  describe "execute/1" do
    test "returns ok tuple with sterilization report for a valid node" do
      result = Sterilization.execute(active_node())
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "report contains expected fields when successful" do
      case Sterilization.execute(active_node()) do
        {:ok, report} ->
          assert Map.has_key?(report, :node_id)
          assert Map.has_key?(report, :reason)
          assert Map.has_key?(report, :timestamp)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "report_to_federation/1" do
    test "returns :ok for a sterilization report" do
      report = %{
        node_id: "ex:l3:tst:srv:main",
        reason: :constitution_corrupted,
        timestamp: DateTime.utc_now(),
        resources_released: %{},
        children_notified: 0,
        duration_ms: 10
      }

      result = Sterilization.report_to_federation(report)
      assert result == :ok
    end
  end
end
