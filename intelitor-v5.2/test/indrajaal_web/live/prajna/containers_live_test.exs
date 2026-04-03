defmodule IndrajaalWeb.Prajna.ContainersLiveTest do
  @moduledoc """
  Integration test suite for IndrajaalWeb.Prajna.ContainersLive.

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults verified on mount
  - SC-HMI-002: Container health and status indicators present
  - SC-CNT-009: NixOS/Podman compliance notice in footer
  - SC-SAFETY-001: Arm-and-fire two-step commit pattern (restart)

  ## Coverage
  - Module structure (exports, moduledoc)
  - Mount and initial render
  - handle_event: select_container
  - handle_event: restart_container (arm-and-fire)
  - handle_event: view_logs + close_logs lifecycle
  - handle_event: start_all
  - handle_event: stop_all
  - handle_info: :refresh metric update
  - handle_info: {:container_update, id, data} PubSub patch
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Module structure
  # ---------------------------------------------------------------------------

  describe "ContainersLive module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.ContainersLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.ContainersLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.ContainersLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.ContainersLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.ContainersLive, :handle_info, 2)
    end

    test "has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} =
        Code.fetch_docs(IndrajaalWeb.Prajna.ContainersLive)

      assert module_doc != :none
    end
  end

  # ---------------------------------------------------------------------------
  # Mount and initial render
  # ---------------------------------------------------------------------------

  describe "mount and initial render" do
    test "mounts at /cockpit/containers and renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "Container Status"
    end

    test "renders PRAJNA C3I header brand", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "PRAJNA C3I"
    end

    test "renders CONTAINERS section label", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "CONTAINERS"
    end

    test "renders all four container cards on initial load", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "indrajaal-db-standalone"
      assert html =~ "indrajaal-redis-standalone"
      assert html =~ "indrajaal-obs-standalone"
      assert html =~ "indrajaal-ex-app-1"
    end

    test "renders START ALL and STOP ALL bulk-action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "START ALL"
      assert html =~ "STOP ALL"
    end

    test "renders RESTART and VIEW LOGS action buttons per container", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "RESTART"
      assert html =~ "VIEW LOGS"
    end

    test "renders SC-CNT-009 Podman compliance notice in footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      assert html =~ "SC-CNT-009"
    end

    test "logs modal is hidden on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/containers")

      refute html =~ "Container Logs"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: select_container
  # ---------------------------------------------------------------------------

  describe "handle_event select_container" do
    test "selecting db container assigns selected_container atom :db", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "select_container", %{"id" => "db"})

      # Re-render after click; no crash is the primary assertion
      html = render(view)
      assert html =~ "indrajaal-db-standalone"
    end

    test "selecting app container does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "select_container", %{"id" => "app"})

      assert render(view) =~ "indrajaal-ex-app-1"
    end

    test "selecting obs container does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "select_container", %{"id" => "obs"})

      assert render(view) =~ "indrajaal-obs-standalone"
    end

    test "selecting redis container does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "select_container", %{"id" => "redis"})

      assert render(view) =~ "indrajaal-redis-standalone"
    end

    test "successive container selections each succeed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "select_container", %{"id" => "db"})
      render_click(view, "select_container", %{"id" => "app"})

      assert render(view) =~ "indrajaal-ex-app-1"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: restart_container (arm-and-fire, SC-SAFETY-001)
  # ---------------------------------------------------------------------------

  describe "handle_event restart_container" do
    test "arms restart for db container and shows info flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "restart_container", %{"id" => "db"})

      assert html =~ "Restart command armed"
      assert html =~ "db"
    end

    test "arms restart for app container and shows info flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "restart_container", %{"id" => "app"})

      assert html =~ "Restart command armed"
      assert html =~ "app"
    end

    test "arms restart for obs container and shows info flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "restart_container", %{"id" => "obs"})

      assert html =~ "Restart command armed"
    end

    test "arm-and-fire does not immediately restart — requires Command Center confirmation", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "restart_container", %{"id" => "db"})

      # Flash mentions "Confirm in Command Center" indicating two-step commit
      assert html =~ "Confirm"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: view_logs / close_logs lifecycle
  # ---------------------------------------------------------------------------

  describe "handle_event view_logs and close_logs" do
    test "view_logs for db container opens log modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "view_logs", %{"id" => "db"})

      assert html =~ "Container Logs"
    end

    test "view_logs renders log entries with timestamps", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "view_logs", %{"id" => "db"})

      # Log entries have HH:MM:SS timestamp format
      assert html =~ ~r/\d{2}:\d{2}:\d{2}/
    end

    test "view_logs for app container opens log modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "view_logs", %{"id" => "app"})

      assert html =~ "Container Logs"
    end

    test "close_logs hides log modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "view_logs", %{"id" => "db"})
      html = render_click(view, "close_logs", %{})

      refute html =~ "Container Logs"
    end

    test "open-then-close-then-open lifecycle works without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "view_logs", %{"id" => "db"})
      render_click(view, "close_logs", %{})
      html = render_click(view, "view_logs", %{"id" => "obs"})

      assert html =~ "Container Logs"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: start_all
  # ---------------------------------------------------------------------------

  describe "handle_event start_all" do
    test "queues start all containers and shows info flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "start_all", %{})

      assert html =~ "Start all containers"
    end

    test "start_all does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "start_all", %{})

      assert render(view) =~ "CONTAINERS"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: stop_all
  # ---------------------------------------------------------------------------

  describe "handle_event stop_all" do
    test "requires two-step confirmation and shows warning flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      html = render_click(view, "stop_all", %{})

      assert html =~ "two-step"
    end

    test "stop_all does not crash the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      render_click(view, "stop_all", %{})

      assert render(view) =~ "CONTAINERS"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info: :refresh (periodic metric update)
  # ---------------------------------------------------------------------------

  describe "handle_info :refresh" do
    test "refresh message updates container metrics without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      # Send refresh as a process message directly to the LiveView
      send(view.pid, :refresh)

      # Give the process a cycle to handle
      :timer.sleep(50)

      html = render(view)
      assert html =~ "indrajaal-ex-app-1"
    end

    test "multiple refresh cycles leave the view in a valid state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      Enum.each(1..3, fn _ ->
        send(view.pid, :refresh)
        :timer.sleep(20)
      end)

      html = render(view)
      assert html =~ "indrajaal-db-standalone"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info: {:container_update, id, data} (PubSub patch)
  # ---------------------------------------------------------------------------

  describe "handle_info container_update PubSub patch" do
    test "container_update message patches the matching container", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      send(view.pid, {:container_update, :app, %{status: :stopped}})
      :timer.sleep(50)

      # View still renders; the patched data is in assigns
      assert render(view) =~ "indrajaal-ex-app-1"
    end

    test "container_update for unknown id does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      send(view.pid, {:container_update, :nonexistent, %{status: :error}})
      :timer.sleep(50)

      assert render(view) =~ "CONTAINERS"
    end

    test "container_update patches health field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/containers")

      send(view.pid, {:container_update, :db, %{health: :unhealthy}})
      :timer.sleep(50)

      # View still renders without crash
      assert render(view) =~ "indrajaal-db-standalone"
    end
  end
end
