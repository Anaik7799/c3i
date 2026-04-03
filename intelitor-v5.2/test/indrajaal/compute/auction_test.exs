defmodule Indrajaal.Compute.AuctionTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Auction

  test "module exists" do
    assert Code.ensure_loaded?(Auction)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Auction, :start_link, 1)
  end

  test "create/2 is exported" do
    assert function_exported?(Auction, :create, 2)
  end

  test "bid/3 is exported" do
    assert function_exported?(Auction, :bid, 3)
  end

  test "resolve/1 is exported" do
    assert function_exported?(Auction, :resolve, 1)
  end
end
