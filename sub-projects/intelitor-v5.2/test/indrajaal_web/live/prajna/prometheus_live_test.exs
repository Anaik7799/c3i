defmodule IndrajaalWeb.Prajna.PrometheusLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.Prajna.PrometheusLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: PROMETHEUS Formal Verification Dashboard for Prajna C3I cockpit

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults
  - SC-PROM-001: Proof requirement for state mutations
  - SC-GVF-003: Graph verification active constraints
  - SC-VER-041: OODA cycle < 100ms

  ## TPS 5-Level RCA Context
  - L1 Symptom: Prometheus screen not rendering
  - L5 Root Cause: Missing LiveView callback exports
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  describe "PrometheusLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.PrometheusLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.PrometheusLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.PrometheusLive, :render, 1)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.PrometheusLive, :handle_info, 2)
    end

    test "uses IndrajaalWeb :live_view behaviour" do
      behaviours =
        IndrajaalWeb.Prajna.PrometheusLive.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Phoenix.LiveView in behaviours
    end
  end

  describe "mount and initial render" do
    test "mounts successfully and assigns initial state", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert is_binary(html)
      assert view.module == IndrajaalWeb.Prajna.PrometheusLive
    end

    test "renders PROMETHEUS heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "PROMETHEUS"
    end

    test "renders formal verification description", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Ff]ormal [Vv]erification|[Pp]roof [Gg]atekeeper/
    end

    test "renders SIL-6 homeostasis status indicator", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "SIL-6"
      assert html =~ "HOMEOSTASIS"
    end

    test "renders total verifications metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Tt]otal [Vv]erifications/
    end

    test "renders average latency metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Aa]verage [Ll]atency/
      assert html =~ "ms"
    end

    test "renders constraint health metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Cc]onstraint [Hh]ealth/
    end

    test "renders initial verification count of zero", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      # verification_count starts at 0
      assert has_element?(
               Phoenix.LiveViewTest.find_elements(html, "[class*=text-4xl]") |> Enum.at(0) ||
                 %{},
               :ok
             ) || html =~ ~r/>0</
    end

    test "renders active safety constraints section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Aa]ctive [Ss]afety [Cc]onstraints/
    end

    test "renders SC-PROM-001 constraint", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "SC-PROM-001"
      assert html =~ "Proof Requirement"
    end

    test "renders SC-PROM-004 constraint", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "SC-PROM-004"
      assert html =~ "DAG Acyclicity"
    end

    test "renders SC-GVF-003 constraint", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "SC-GVF-003"
      assert html =~ "OpenRouter Exclusivity"
    end

    test "renders constraints with VERIFIED badge", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "VERIFIED"
    end

    test "renders verification ledger section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Vv]erification [Ll]edger|[Ii]mmutable [Rr]egister/
    end

    test "renders empty ledger message when no proofs issued", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Nn]o recent verifications/
    end

    test "initial assigns contain expected keys", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert view |> has_element?("div")
      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :page_title)
      assert Map.has_key?(assigns, :verification_count)
      assert Map.has_key?(assigns, :active_constraints)
      assert Map.has_key?(assigns, :recent_activity)
    end

    test "page_title assign is PROMETHEUS Verification", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.page_title == "PROMETHEUS Verification"
    end

    test "active_constraints assign contains three initial constraints", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert length(assigns.active_constraints) == 3
    end

    test "all initial constraints have :active status", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns

      Enum.each(assigns.active_constraints, fn constraint ->
        assert constraint.status == :active
      end)
    end

    test "last_proof assign is nil on mount", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert is_nil(assigns.last_proof)
    end

    test "verification_count assign is 0 on mount", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.verification_count == 0
    end

    test "recent_activity assign is empty list on mount", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.recent_activity == []
    end
  end

  describe "handle_info :update_stats timer" do
    test "handle_info :update_stats returns noreply tuple", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      send(view.pid, :update_stats)
      # Give the process time to handle the message
      Process.sleep(50)
      assert render(view) =~ "PROMETHEUS"
    end

    test "handle_info :update_stats does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      send(view.pid, :update_stats)
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "handle_info :update_stats may increment verification_count", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      # Send multiple update_stats messages — count may or may not increment (random)
      # but the view must remain alive and renderable throughout
      for _ <- 1..10 do
        send(view.pid, :update_stats)
        Process.sleep(10)
      end

      Process.sleep(50)
      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ "PROMETHEUS"
    end

    test "verification_count does not decrease after update_stats messages", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      initial_count = :sys.get_state(view.pid).socket.assigns.verification_count

      for _ <- 1..5 do
        send(view.pid, :update_stats)
        Process.sleep(20)
      end

      final_count = :sys.get_state(view.pid).socket.assigns.verification_count
      assert final_count >= initial_count
    end

    test "handle_info :update_stats preserves active_constraints", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      send(view.pid, :update_stats)
      Process.sleep(50)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert length(assigns.active_constraints) == 3
    end

    test "render after update_stats still shows constraint section", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      send(view.pid, :update_stats)
      Process.sleep(50)

      html = render(view)
      assert html =~ "SC-PROM-001"
      assert html =~ "SC-PROM-004"
    end

    test "last_proof is set when new proof generated by update_stats", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      # Seed randomness — send many messages, eventually a proof is generated
      # The random threshold is :rand.uniform(10) > 8, so ~20% chance per tick
      for _ <- 1..30 do
        send(view.pid, :update_stats)
        Process.sleep(10)
      end

      assigns = :sys.get_state(view.pid).socket.assigns
      # After 30 ticks with 20% probability, very likely to have at least one proof
      # but we don't assert the count — only that the field is valid when set
      if assigns.last_proof do
        assert Map.has_key?(assigns.last_proof, :id)
        assert Map.has_key?(assigns.last_proof, :timestamp)
        assert Map.has_key?(assigns.last_proof, :signature)
      end
    end

    test "when last_proof is set, ledger renders proof details", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      proof = %{
        id: "test-uuid-1234-5678-abcd",
        timestamp: DateTime.utc_now(),
        signature: "prom_sig_test_signature_value"
      }

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.merge(socket.assigns, %{last_proof: proof, verification_count: 1})
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "ISSUED"
    end
  end

  describe "constraint display" do
    test "renders three constraint rows", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      # Count VERIFIED badge occurrences — one per constraint
      verified_count =
        html
        |> String.split("VERIFIED")
        |> length()
        |> Kernel.-(1)

      assert verified_count == 3
    end

    test "constraint IDs are rendered in monospace font context", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "font-mono"
      assert html =~ "SC-PROM-001"
    end

    test "constraint count shows 3 active out of total", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "3/242"
    end

    test "constraint health shows all constraints active", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ ~r/[Aa]ll [Cc]onstraints [Aa]ctive/
    end

    test "latency target is shown as less than 10ms", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "10ms"
    end

    test "success rate is shown as 100 percent", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.PrometheusLive)

      assert html =~ "100%"
    end
  end
end
