defmodule Indrajaal.Time.HLCTest do
  @moduledoc """
  TDG test suite for Indrajaal.Time.HLC (Hybrid Logical Clock).

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: @moduletag :zenoh_nif required

  ## TPS 5-Level RCA Context
  - L1 Symptom: HLC clock drift in distributed nodes
  - L5 Root Cause: Lack of monotonic hybrid clock guarantees
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Time.HLC

  describe "new/0" do
    test "creates a new HLC timestamp" do
      result = HLC.new()
      assert is_tuple(result)
      assert tuple_size(result) == 3
    end

    test "returns wall time as first element" do
      {wall_time, _logical, _node} = HLC.new()
      assert is_integer(wall_time)
      assert wall_time > 0
    end

    test "returns logical counter 0 for new clock" do
      {_wall_time, logical, _node} = HLC.new()
      assert logical == 0
    end

    test "returns node as third element" do
      {_wall_time, _logical, node} = HLC.new()
      assert node == Node.self()
    end

    test "two consecutive calls produce non-decreasing timestamps" do
      {t1, _, _} = HLC.new()
      {t2, _, _} = HLC.new()
      assert t2 >= t1
    end
  end

  describe "update/2" do
    test "updates local clock given a remote HLC" do
      local = HLC.new()
      remote = HLC.new()
      updated = HLC.update(local, remote)
      assert is_tuple(updated)
      assert tuple_size(updated) == 3
    end

    test "updated clock is not less than local clock" do
      local = HLC.new()
      remote = HLC.new()
      {updated_wall, _l, _n} = HLC.update(local, remote)
      {local_wall, _l2, _n2} = local
      assert updated_wall >= local_wall
    end

    test "updated clock is not less than remote clock" do
      local = HLC.new()
      remote = HLC.new()
      {updated_wall, _l, _n} = HLC.update(local, remote)
      {remote_wall, _l2, _n2} = remote
      assert updated_wall >= remote_wall
    end
  end

  describe "to_string/1" do
    test "converts HLC to string" do
      hlc = HLC.new()
      result = HLC.to_string(hlc)
      assert is_binary(result)
    end

    test "string representation is non-empty" do
      hlc = HLC.new()
      result = HLC.to_string(hlc)
      assert String.length(result) > 0
    end
  end
end
