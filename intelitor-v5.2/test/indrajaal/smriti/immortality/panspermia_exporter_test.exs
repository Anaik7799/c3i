defmodule Indrajaal.SMRITI.Immortality.PanspermiaExporterTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Immortality.PanspermiaExporter

  @test_export_path "tmp/smriti_export_test.json"

  setup do
    File.mkdir_p!(Path.dirname(@test_export_path))
    on_exit(fn -> File.rm(@test_export_path) end)
    :ok
  end

  describe "Panspermia Exporter" do
    test "exports system state to json" do
      state = %{users: [], configs: %{}}
      assert {:ok, path} = PanspermiaExporter.export(state, @test_export_path)
      assert File.exists?(path)

      content = File.read!(path)
      assert content =~ "configs"
    end

    test "verifies export integrity" do
      state = %{critical_data: "seed_123"}
      PanspermiaExporter.export(state, @test_export_path)

      assert {:ok, verified_state} = PanspermiaExporter.verify_import(@test_export_path)
      assert verified_state["critical_data"] == "seed_123"
    end
  end
end
