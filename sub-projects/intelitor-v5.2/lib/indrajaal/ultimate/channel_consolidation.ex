defmodule Indrajaal.Ultimate.ChannelConsolidation do
  @moduledoc """
  Ultimate Channel Consolidation - Phase V
  """

  # EP201: Removed unused import Phoenix.Channel
  # import Phoenix.Channel

  @doc """
  Universal channel join pattern
  """
  defmacro universal_join(topic_pattern, auth_check) do
    quote do
      @spec join(term()) :: term()
      def join(unquote(topic_pattern), payload, socket) do
        if unquote(auth_check).(socket, payload) do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end
    end
  end

  @doc """
  Universal channel __event handler
  """
  defmacro handle_universal_event(event, handler) do
    quote do
      @spec handle_in(term()) :: term()
      def handle_in(unquote(event), payload, socket) do
        case unquote(handler).(payload, socket) do
          {:ok, response} ->
            {:reply, {:ok, response}, socket}

          {:error, reason} ->
            {:reply, {:error, %{reason: reason}}, socket}

          {:noreply, new_socket} ->
            {:noreply, new_socket}
        end
      end
    end
  end
end
