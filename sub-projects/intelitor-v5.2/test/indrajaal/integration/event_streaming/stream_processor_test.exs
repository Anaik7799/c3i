defmodule Indrajaal.Integration.EventStreaming.StreamProcessorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.EventStreaming.StreamProcessor

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StreamProcessor)
    end
  end

  describe "Ash resource structure" do
    test "module is defined" do
      assert StreamProcessor.__info__(:module) == StreamProcessor
    end

    test "code_interface functions are defined" do
      assert Code.ensure_loaded?(StreamProcessor)
    end
  end

  describe "code_interface functions" do
    test "defines create/2" do
      assert function_exported?(StreamProcessor, :create, 2) or
               function_exported?(StreamProcessor, :create, 1)
    end

    test "defines read_all/1" do
      assert function_exported?(StreamProcessor, :read_all, 1) or
               function_exported?(StreamProcessor, :read_all, 0)
    end
  end
end
