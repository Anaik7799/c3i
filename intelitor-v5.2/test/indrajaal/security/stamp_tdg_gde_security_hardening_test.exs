defmodule Indrajaal.Security.StampTdgGdeSecurityHardeningTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Security.StampTdgGdeSecurityHardening

  test "module exists" do
    assert Code.ensure_loaded?(StampTdgGdeSecurityHardening)
  end

  test "analyze_stamp_security/1 is exported" do
    assert function_exported?(StampTdgGdeSecurityHardening, :analyze_stamp_security, 1)
  end

  test "validate_tdg_security/1 is exported" do
    assert function_exported?(StampTdgGdeSecurityHardening, :validate_tdg_security, 1)
  end

  test "assess_gde_security/1 is exported" do
    assert function_exported?(StampTdgGdeSecurityHardening, :assess_gde_security, 1)
  end
end
