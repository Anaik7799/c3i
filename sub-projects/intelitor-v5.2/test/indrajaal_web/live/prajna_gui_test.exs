defmodule IndrajaalWeb.PrajnaGUITest do
  use ExUnit.Case, async: false
  use Wallaby.Feature

  import Wallaby.Query

  @moduledoc """
  Closed-loop GUI feedback test for Prajna Cockpit.
  """

  feature "Prajna Cockpit loads and displays health metrics", %{session: session} do
    session
    |> visit("/prajna")
    |> assert_has(css(".prajna-cockpit"))
    |> assert_has(css(".health-sparkline"))
    |> take_screenshot()
  end
end
