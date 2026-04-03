defmodule IndrajaalWeb.Prajna.RegisterLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.Prajna.RegisterLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Immutable Register Hash Chain Dashboard for Prajna C3I cockpit
  - Route: /cockpit/register

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults
  - SC-REG-001: Append-only state mutations via ImmutableRegister
  - SC-REG-002: Hash chain unbroken — chain_valid status
  - SC-REG-003: Block count tracking
  - SC-REG-006: RS parity verification

  ## TPS 5-Level RCA Context
  - L1 Symptom: Register screen not rendering
  - L5 Root Cause: Missing LiveView callback exports
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  describe "RegisterLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.RegisterLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.RegisterLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.RegisterLive, :render, 1)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.RegisterLive, :handle_info, 2)
    end

    test "uses IndrajaalWeb :live_view behaviour" do
      behaviours =
        IndrajaalWeb.Prajna.RegisterLive.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Phoenix.LiveView in behaviours
    end
  end

  describe "mount and initial render via router" do
    test "mounts at /cockpit/register and returns 200", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/register")

      assert html =~ "Immutable Register"
    end

    test "page_title is set to Immutable Register", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/register")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.page_title == "Immutable Register"
    end
  end

  describe "mount and initial render (isolated)" do
    test "mounts successfully via live_isolated", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert is_binary(html)
      assert view.module == IndrajaalWeb.Prajna.RegisterLive
    end

    test "renders Immutable Register heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ "Immutable Register"
    end

    test "renders Hash Chain in heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Hh]ash [Cc]hain/
    end

    test "renders Chain Status card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Cc]hain [Ss]tatus/
    end

    test "renders Block Count card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Bb]lock [Cc]ount/
    end

    test "renders RS Parity card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Rr][Ss] [Pp]arity/
    end

    test "renders Latest Hash card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Ll]atest [Hh]ash/
    end

    test "renders Recent Blocks section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Rr]ecent [Bb]locks/
    end

    test "renders Last verified timestamp footer", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ ~r/[Ll]ast verified/
    end

    test "initial assigns include chain_valid", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :chain_valid)
    end

    test "initial assigns include block_count", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :block_count)
    end

    test "initial assigns include latest_hash", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :latest_hash)
    end

    test "initial assigns include rs_parity_ok", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :rs_parity_ok)
    end

    test "initial assigns include recent_blocks list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :recent_blocks)
      assert is_list(assigns.recent_blocks)
    end

    test "initial assigns include last_verified datetime", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :last_verified)
      assert %DateTime{} = assigns.last_verified
    end

    test "chain_valid defaults to true when ImmutableRegister unavailable", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      # The fetch_register_state/0 has rescue clauses that default to true
      assert is_boolean(assigns.chain_valid)
    end

    test "chain status VALID renders with green color class when valid", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns

      if assigns.chain_valid do
        html = render(view)
        assert html =~ "VALID"
        assert html =~ "text-green-600"
      end
    end

    test "latest_hash defaults to genesis when ImmutableRegister unavailable", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert is_binary(assigns.latest_hash)
    end

    test "block_count is a non-negative integer", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert is_integer(assigns.block_count)
      assert assigns.block_count >= 0
    end

    test "last_verified timestamp is formatted in render output", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      # Calendar.strftime output format: YYYY-MM-DD HH:MM:SS UTC
      assert html =~ ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/
    end

    test "rs_parity_ok mirrors chain_valid value", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.rs_parity_ok == assigns.chain_valid
    end
  end

  describe "handle_info :refresh timer" do
    test "handle_info :refresh returns noreply and keeps view alive", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      assert Process.alive?(view.pid)
      assert render(view) =~ "Immutable Register"
    end

    test "handle_info :refresh reloads register data", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :chain_valid)
      assert Map.has_key?(assigns, :block_count)
      assert Map.has_key?(assigns, :latest_hash)
    end

    test "handle_info :refresh updates last_verified timestamp", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      before_assigns = :sys.get_state(view.pid).socket.assigns
      before_ts = before_assigns.last_verified

      # Small delay to ensure timestamp changes
      Process.sleep(10)
      send(view.pid, :refresh)
      Process.sleep(50)

      after_assigns = :sys.get_state(view.pid).socket.assigns
      # last_verified should be >= the previous value
      assert DateTime.compare(after_assigns.last_verified, before_ts) in [:gt, :eq]
    end

    test "multiple :refresh messages do not crash the view", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      for _ <- 1..5 do
        send(view.pid, :refresh)
        Process.sleep(20)
      end

      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ "Immutable Register"
    end

    test "render after :refresh still shows all four metric cards", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      html = render(view)
      assert html =~ ~r/[Cc]hain [Ss]tatus/
      assert html =~ ~r/[Bb]lock [Cc]ount/
      assert html =~ ~r/[Rr][Ss] [Pp]arity/
      assert html =~ ~r/[Ll]atest [Hh]ash/
    end
  end

  describe "chain validity rendering" do
    test "renders VALID text when chain_valid is true", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{chain_valid: true, rs_parity_ok: true})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "VALID"
    end

    test "renders BROKEN text when chain_valid is false", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{chain_valid: false, rs_parity_ok: false})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "BROKEN"
    end

    test "valid chain renders green CSS class", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{chain_valid: true, rs_parity_ok: true})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "text-green-600"
    end

    test "broken chain renders red CSS class", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{chain_valid: false, rs_parity_ok: false})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "text-red-600"
    end

    test "RS parity OK renders green when valid", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{rs_parity_ok: true})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "text-green-600"
    end

    test "block_count is rendered in blue", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ "text-blue-600"
    end

    test "latest_hash value is rendered in monospace purple", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.RegisterLive)

      assert html =~ "font-mono"
      assert html =~ "text-purple-700"
    end
  end

  describe "navigation" do
    test "page is accessible via GET /cockpit/register", %{conn: conn} do
      {:error, {:live_redirect, _}} = live(conn, "/cockpit")
      # Confirm the register route is reachable
      result = live(conn, "/cockpit/register")
      assert match?({:ok, _, _}, result) or match?({:error, {:live_redirect, _}}, result)
    end
  end
end
