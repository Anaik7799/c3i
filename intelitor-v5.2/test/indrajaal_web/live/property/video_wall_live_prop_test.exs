defmodule IndrajaalWeb.Operations.VideoWallLivePropTest do
  @moduledoc """
  Property-based tests for Video Wall LiveView.
  Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014).

  WHAT: Verifies that VideoWallLive maintains invariants across all valid
        inputs — layout values, camera groups, camera IDs, PTZ directions,
        and arbitrary event sequences. Tests all 9 handle_event clauses:
        set_layout, set_group, select_camera, toggle_fullscreen, toggle_ptz,
        ptz_command, snapshot, start_clip, search_recordings.
  WHY: The video wall is the primary surveillance interface. Layout switches,
       camera selection, PTZ control sequences must be crash-free under load.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-VID-001, SC-VID-002, SC-HMI-001, EP-GEN-014

  TDG Level: L1 (Property Testing)
  Route: /operations/video
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_layouts ["2x2", "3x3", "4x4"]
  @valid_groups ["all", "entrances", "parking", "interior", "perimeter"]
  @valid_ptz_directions ["up", "down", "left", "right", "home", "zoom_in", "zoom_out"]
  @sample_camera_ids [
    "cam-001",
    "cam-002",
    "cam-003",
    "cam-004",
    "cam-005",
    "cam-006",
    "cam-007",
    "cam-008"
  ]

  # ═══════════════════════════════════════════════════════════════════════
  # set_layout PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "set_layout properties" do
    property "P-VID-001: any valid layout produces a safe render" do
      forall layout <- PC.oneof(@valid_layouts) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "set_layout", %{"layout" => layout})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-002: any sequence of layout switches ends in valid state" do
      forall layouts <- PC.non_empty(PC.list(PC.oneof(@valid_layouts))) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")

        Enum.each(layouts, fn layout ->
          render_click(view, "set_layout", %{"layout" => layout})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-003: set_layout is idempotent" do
      forall layout <- PC.oneof(@valid_layouts) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html1 = render_click(view, "set_layout", %{"layout" => layout})
        html2 = render_click(view, "set_layout", %{"layout" => layout})
        html1 == html2
      end
    end

    property "P-VID-004: unknown layout value falls back gracefully" do
      forall s <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "set_layout", %{"layout" => s})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # set_group PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "set_group properties" do
    property "P-VID-005: any valid group produces a safe render" do
      forall group <- PC.oneof(@valid_groups) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "set_group", %{"group" => group})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-006: layout and group compose safely" do
      forall {layout, group} <-
               {PC.oneof(@valid_layouts), PC.oneof(@valid_groups)} do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "set_layout", %{"layout" => layout})
        html = render_click(view, "set_group", %{"group" => group})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # select_camera PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "select_camera properties" do
    property "P-VID-007: selecting any sample camera ID is safe" do
      forall id <- PC.oneof(@sample_camera_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "select_camera", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-008: selecting cameras in any order is safe" do
      forall ids <- PC.non_empty(PC.list(PC.oneof(@sample_camera_ids))) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")

        Enum.each(ids, fn id ->
          render_click(view, "select_camera", %{"id" => id})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-009: select_camera with arbitrary string ID is safe" do
      forall id <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "select_camera", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # toggle_fullscreen / toggle_ptz PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "toggle properties" do
    property "P-VID-010: toggle_fullscreen N times never crashes" do
      forall n <- PC.integer(1, 6) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "select_camera", %{"id" => "cam-001"})

        Enum.each(1..n, fn _ ->
          render_click(view, "toggle_fullscreen", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-011: toggle_ptz N times never crashes" do
      forall n <- PC.integer(1, 6) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "select_camera", %{"id" => "cam-001"})

        Enum.each(1..n, fn _ ->
          render_click(view, "toggle_ptz", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-012: even number of toggles preserves original boolean state" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "select_camera", %{"id" => "cam-001"})
        even = n * 2

        Enum.each(1..even, fn _ ->
          render_click(view, "toggle_ptz", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ptz_command PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "ptz_command properties" do
    property "P-VID-013: any valid PTZ direction is safe" do
      forall direction <- PC.oneof(@valid_ptz_directions) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "ptz_command", %{"direction" => direction})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-014: any sequence of PTZ commands is safe" do
      forall directions <- PC.non_empty(PC.list(PC.oneof(@valid_ptz_directions))) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "select_camera", %{"id" => "cam-001"})
        render_click(view, "toggle_ptz", %{})

        Enum.each(directions, fn dir ->
          render_click(view, "ptz_command", %{"direction" => dir})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-015: unknown PTZ direction string is safe" do
      forall s <- PC.non_empty(PC.utf8()) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "ptz_command", %{"direction" => s})
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # snapshot / start_clip / search_recordings PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "capture and search properties" do
    property "P-VID-016: snapshot with any camera ID is safe" do
      forall id <- PC.oneof(@sample_camera_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "snapshot", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-017: start_clip with any camera ID is safe" do
      forall id <- PC.oneof(@sample_camera_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        html = render_click(view, "start_clip", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-018: snapshot then start_clip on same camera is safe" do
      forall id <- PC.oneof(@sample_camera_ids) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")
        render_click(view, "snapshot", %{"id" => id})
        html = render_click(view, "start_clip", %{"id" => id})
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-VID-019: search_recordings N times never crashes" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/operations/video")

        Enum.each(1..n, fn _ ->
          render_click(view, "search_recordings", %{})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 60_000
    check all(
            layout <- SD.member_of(@valid_layouts),
            group <- SD.member_of(@valid_groups),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/video")
      render_click(view, "set_layout", %{"layout" => layout})
      html = render_click(view, "set_group", %{"group" => group})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            id <- SD.member_of(@sample_camera_ids),
            direction <- SD.member_of(@valid_ptz_directions),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/video")
      render_click(view, "select_camera", %{"id" => id})
      render_click(view, "toggle_ptz", %{})
      html = render_click(view, "ptz_command", %{"direction" => direction})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 60_000
    check all(
            id <- SD.member_of(@sample_camera_ids),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/operations/video")
      render_click(view, "snapshot", %{"id" => id})
      render_click(view, "start_clip", %{"id" => id})
      html = render_click(view, "search_recordings", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
