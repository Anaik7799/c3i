defmodule Indrajaal.Notifications.Backends.BehaviourTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Backends.Behaviour

  test "module exists" do
    assert Code.ensure_loaded?(Behaviour)
  end

  test "defines send_notification callback" do
    callbacks = Behaviour.behaviour_info(:callbacks)
    assert is_list(callbacks)
    assert {:send_notification, 2} in callbacks or {:send_notification, 3} in callbacks
  end
end
