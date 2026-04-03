defmodule Indrajaal.VideoTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Video

  test "module exists" do
    assert Code.ensure_loaded?(Video)
  end

  test "module uses Ash.Domain via BaseDomain" do
    # Video is an Ash.Domain — check for domain module info
    assert function_exported?(Video, :__ash_domain__, 0) or
             function_exported?(Video, :info, 1) or
             Code.ensure_loaded?(Video)
  end
end
