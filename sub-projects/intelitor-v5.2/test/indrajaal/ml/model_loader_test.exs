defmodule Indrajaal.ML.ModelLoaderTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.ModelLoader

  test "module is loaded" do
    assert Code.ensure_loaded?(ModelLoader)
  end

  test "load_threat_model/0 is defined" do
    assert function_exported?(ModelLoader, :load_threat_model, 0)
  end

  test "load_anomaly_model/0 is defined" do
    assert function_exported?(ModelLoader, :load_anomaly_model, 0)
  end

  test "load_threat_model/0 returns ok tuple" do
    assert {:ok, _model} = ModelLoader.load_threat_model()
  end

  test "load_anomaly_model/0 returns ok tuple" do
    assert {:ok, _model} = ModelLoader.load_anomaly_model()
  end
end
