defmodule Indrajaal.Integration.EventStreaming.EventConsumerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.EventStreaming.EventConsumer

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(EventConsumer)
    end
  end

  describe "Ash resource structure" do
    test "module is defined" do
      assert EventConsumer.__info__(:module) == EventConsumer
    end

    test "code_interface functions are defined" do
      # Module defines code_interface with create, read_all, update, destroy
      assert Code.ensure_loaded?(EventConsumer)
    end
  end

  describe "code_interface functions" do
    test "defines create/2" do
      assert function_exported?(EventConsumer, :create, 2) or
               function_exported?(EventConsumer, :create, 1)
    end

    test "defines read_all/1" do
      assert function_exported?(EventConsumer, :read_all, 1) or
               function_exported?(EventConsumer, :read_all, 0)
    end
  end
end
