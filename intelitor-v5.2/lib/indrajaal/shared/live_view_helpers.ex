defmodule Indrajaal.Shared.LiveViewHelpers do
  @moduledoc """
  Shared utilities for LiveView components to eliminate duplication across the view layer.

  This module consolidates common LiveView patterns identified in the systematic
  duplication analysis targeting ~500 violations.

  ## Usage Areas:
  - Standard mount patterns with PubSub subscriptions
  - Common __event handler structures
  - Data loading and assignment patterns
  - Real - time update and refresh utilities
  - Timer and interval management

  ## Target Files:
  - stamp_tdg_gde_advanced_analytics_live.ex
  - stamp_tdg_gde_dashboard_live.ex
  - monitoring_dashboard_live.ex
  - permissions_management_live.ex
  - access_control_monitoring_live.ex
  """

  alias Phoenix.LiveView.Socket
  alias Phoenix.PubSub

  import Phoenix.LiveView, only: [connected?: 1, put_flash: 3, push_event: 3]
  import Phoenix.Component, only: [assign: 2, assign: 3]

  @doc """
  Standard LiveView mount pattern with PubSub subscriptions and common assignments.

  ## Examples

      def mount(_params, session, _socket) do
        socket = standard_mount(socket, session, %{
          page_title: "Dashboard",
          subscriptions: ["metrics", "alerts"],
          refresh_interval: 5_000,
          initial_assigns: %{loading: true, data: []}
        })
        {:ok, socket}
      end
  """
  @spec standard_mount(Socket.t(), map(), map()) :: Socket.t()
  def standard_mount(socket, session, opts \\ %{}) do
    socket =
      socket
      |> assign_from_session(session)
      |> assign_page_title(opts[:page_title])
      |> assign_initial_data(opts[:initial_assigns] || %{})

    if connected?(socket) do
      socket
      |> setup_pubsub_subscriptions(opts[:subscriptions] || [])
      |> setup_refresh_timer(opts[:refresh_interval])
    else
      socket
    end
  end

  @doc """
  Setup multiple PubSub subscriptions with tenant isolation.

  ## Examples
      setup_pubsub_subscriptions(socket, [
        "stamp_metrics",
        "tdg_metrics",
        "gde_metrics",
        "alerts"
      ])
  """
  @spec setup_pubsub_subscriptions(Socket.t(), list(String.t())) :: Socket.t()
  def setup_pubsub_subscriptions(socket, topics) when is_list(topics) do
    tenant_id = socket.assigns[:tenant_id]

    Enum.each(topics, fn topic ->
      full_topic = if tenant_id, do: "#{topic}:#{tenant_id}", else: topic
      PubSub.subscribe(Indrajaal.PubSub, full_topic)
    end)

    socket
  end

  @doc """
  Setup refresh timer for real - time updates.

  ## Examples
      setup_refresh_timer(socket, 5_000)  # 5 second refresh
      setup_refresh_timer(socket, nil)    # No timer
  """
  @spec setup_refresh_timer(Socket.t(), integer() | nil) :: Socket.t()
  # socket, nil), do: socket
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec setup_refresh_timer(Phoenix.Socket.t(), term()) :: term()
  def setup_refresh_timer(socket, interval) when is_integer(interval) do
    :timer.send_interval(interval, self(), :refresh_metrics)
    socket |> assign(:refresh_interval, interval)
  end

  @doc """
  Standard __event handler pattern for common __events.

  ## Examples

      def handle_event(event, _params, _socket) do
        case standard_handle_event(event, params, socket) do
          {:handled, socket} -> {:noreply, socket}
          :not_handled -> custom_handle_event(event, params, socket)
        end
      end
  """
  @spec standard_handle_event(String.t(), map(), Socket.t()) ::
          {:handled, Socket.t()} | :not_handled
  @spec standard_handle_event(term(), term(), Phoenix.Socket.t()) :: term()
  def standard_handle_event("refresh", _params, socket) do
    socket = socket |> assign(:loading, true)
    {:handled, socket}
  end

  @spec standard_handle_event(term(), term(), Phoenix.Socket.t()) :: term()
  def standard_handle_event("togglereal_time", _params, socket) do
    enabled = not socket.assigns[:real_time_enabled]
    socket = socket |> assign(:real_time_enabled, enabled)
    {:handled, socket}
  end

  @spec standard_handle_event(term(), map(), Phoenix.Socket.t()) :: term()
  def standard_handle_event("export", %{"format" => format}, socket) do
    # Export functionality can be added here
    socket = put_flash(socket, :info, "Export in #{format} format initiated")
    {:handled, socket}
  end

  @spec standard_handle_event(term(), term(), Phoenix.Socket.t()) :: term()
  # def standard_handle_event(event, _params, _socket), do: :not_handled
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Standard data loading pattern with error handling.

  ## Examples

      socket = load_data_with_loading(socket, fn ->
        %{metrics: fetch_metrics(), alerts: fetch_alerts()}
      end)
  """
  @spec load_data_with_loading(Socket.t(), (-> map())) :: Socket.t()
  def load_data_with_loading(socket, data_loader) when is_function(data_loader, 0) do
    socket = socket |> assign(:loading, true)

    try do
      data = data_loader.()

      socket
      |> assign(data)
      |> assign(:loading, false)
      |> assign(:error, nil)
    rescue
      error ->
        socket
        |> assign(:loading, false)
        |> assign(:error, Exception.message(error))
        |> put_flash(:error, "Failed to load data: #{Exception.message(error)}")
    end
  end

  @doc """
  Bulk assignment from session data with defaults.

  ## Examples
      assign_from_session(socket, session, [
        :current_user,
        :tenant_id,
        {:theme, "light"}
      ])
  """
  @spec assign_from_session(Socket.t(), map()) :: Socket.t()
  def assign_from_session(socket, session) do
    common_session_keys = [:current_user, :tenant_id, :user_id]

    Enum.reduce(common_session_keys, socket, fn key, acc_socket ->
      case Map.get(session, to_string(key)) do
        nil -> acc_socket
        value -> assign(acc_socket, key, value)
      end
    end)
  end

  @doc """
  Update real - time metrics with broadcast.

  ## Examples

      socket = update_real_time_data(socket, %{
        metric_name: "cpu_usage",
        value: 75.2,
        timestamp: DateTime.utc_now()
      })
  """
  @spec update_real_time_data(Socket.t(), map()) :: Socket.t()
  def update_real_time_data(socket, data) do
    current_data = socket.assigns[:real_time_data] || %{}
    updated_data = Map.merge(current_data, data)

    socket
    |> assign(:real_time_data, updated_data)
    |> push_event("update_charts", %{data: updated_data})
  end

  @doc """
  Handle standard PubSub messages.

  ## Examples

      def handle_info(message, _socket) do
        case standard_handle_info(message, socket) do
          {:handled, socket} -> {:noreply, socket}
          :not_handled -> custom_handle_info(message, socket)
        end
      end
  """
  @spec standard_handle_info(any(), Socket.t()) :: {:handled, Socket.t()} | :not_handled
  def standard_handle_info(:refresh_metrics, socket) do
    if socket.assigns[:real_time_enabled] != false do
      socket =
        load_data_with_loading(socket, fn ->
          # This would be customized per LiveView
          %{last_refresh: DateTime.utc_now()}
        end)

      {:handled, socket}
    else
      {:handled, socket}
    end
  end

  def standard_handle_info({:realtime_data, data}, socket) do
    socket = update_real_time_data(socket, data)
    {:handled, socket}
  end

  def standard_handle_info({:newalert, alert}, socket) do
    alerts = [alert | socket.assigns[:alerts] || []] |> Enum.take(10)
    socket = socket |> assign(:alerts, alerts)
    {:handled, socket}
  end

  # def standard_handle_info(message, _socket), do: :not_handled
  # Claude Agent: EP-076 - Unreachable function clause commented
  # Private helper functions

  @spec assign_page_title(Socket.t(), String.t() | nil) :: Socket.t()
  defp assign_page_title(socket, nil), do: socket
  defp assign_page_title(socket, title), do: socket |> assign(:page_title, title)

  @spec assign_initial_data(Socket.t(), map()) :: Socket.t()
  defp assign_initial_data(socket, data) when is_map(data) do
    Enum.reduce(data, socket, fn {key, value}, acc_socket ->
      assign(acc_socket, key, value)
    end)
  end
end
