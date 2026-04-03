defmodule Indrajaal.SMRITI.Polish.DevenvWiringTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Polish.DevenvWiring

  describe "Devenv Wiring" do
    test "verifies wiring configuration" do
      config = DevenvWiring.get_config()
      assert Map.has_key?(config, :nix_version)
      assert config.status == :wired
    end

    test "generates wiring report" do
      report = DevenvWiring.generate_report()
      assert report =~ "Devenv Status: OK"
    end
  end
end
