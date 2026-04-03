defmodule IndrajaalWeb.JournalLive do
  @moduledoc """
  Journal LiveView for browsing the Indrajaal evolution journal.

  Lists retrospective journal entries from docs/journal/, providing
  a dark-cockpit-themed read-only view of system evolution history.

  ## STAMP Compliance
  - SC-SYNC-DOC-002: Documentation sync — journal entries surfaced in the UI
  - SC-HMI-001: Dark cockpit theme applied throughout
  - SC-HMI-008: Theme-aware surface/content CSS classes used
  """

  use IndrajaalWeb, :live_view

  @journal_dir "docs/journal"

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    entries = load_journal_entries()

    socket =
      socket
      |> assign(:page_title, "Evolution Journal")
      |> assign(:entries, entries)
      |> assign(:search_query, "")
      |> assign(:filtered_entries, entries)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    entries = socket.assigns.entries
    query_lower = String.downcase(query)

    filtered =
      if query_lower == "" do
        entries
      else
        Enum.filter(entries, fn entry ->
          String.contains?(String.downcase(entry.name), query_lower)
        end)
      end

    {:noreply, assign(socket, search_query: query, filtered_entries: filtered)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="journal-dashboard bg-surface-primary min-h-screen p-6">
      <div class="header mb-8">
        <h1 class="text-2xl font-bold text-content-primary">Evolution Journal</h1>
        <p class="text-content-secondary mt-1">
          Indrajaal system retrospectives — {@entries |> length()} entries
        </p>
      </div>

      <div class="search-bar mb-6">
        <form phx-change="search" phx-submit="search">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search journal entries..."
            class="w-full px-4 py-2 rounded bg-gray-800
                   border border-gray-600 text-gray-100 placeholder-gray-500
                   focus:outline-none focus:border-blue-500"
          />
        </form>
      </div>

      <div :if={@filtered_entries == []} class="empty-state text-center py-12">
        <p class="text-gray-500 text-lg">No journal entries found.</p>
      </div>

      <ul class="entries-list space-y-2">
        <li
          :for={entry <- @filtered_entries}
          class="entry-item bg-gray-800 rounded-lg
                 border border-gray-700 px-5 py-3 flex items-center justify-between
                 hover:border-blue-500 transition-colors duration-150"
        >
          <div class="entry-name">
            <span class="text-gray-100 font-mono text-sm">{entry.name}</span>
          </div>
          <div class="entry-meta flex items-center gap-4">
            <span :if={entry.date != ""} class="text-gray-400 text-xs">
              {entry.date}
            </span>
            <span class="px-2 py-0.5 rounded text-xs bg-blue-900 text-blue-200">
              journal
            </span>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  defp load_journal_entries do
    path = Path.join(File.cwd!(), @journal_dir)

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort(:desc)
        |> Enum.take(50)
        |> Enum.map(fn filename ->
          %{name: Path.rootname(filename), date: extract_date(filename)}
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_date(filename) do
    case Regex.run(~r/^(\d{8})-(\d{4})-/, filename) do
      [_, date_str, time_str] ->
        <<y::binary-size(4), m::binary-size(2), d::binary-size(2)>> = date_str
        "#{y}-#{m}-#{d} #{String.slice(time_str, 0, 2)}:#{String.slice(time_str, 2, 2)}"

      _ ->
        ""
    end
  end
end
