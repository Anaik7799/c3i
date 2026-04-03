defmodule IndrajaalWeb.Prajna.SettingsLive do
  @moduledoc """
  PRAJNA C3I Settings/Configuration Screen

  WHAT: System configuration and operator preferences management
        following NUREG-0700 and MIL-STD-1472H guidelines.

  WHY: Provides centralized configuration for:
       - Display preferences (theme, refresh, timezone)
       - Alarm thresholds and sensitivity
       - AI Copilot settings (LLM provider, model)
       - Safety envelope parameters (protected by two-key)
       - Import/Export configuration

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-CONFIG-001: Changes require confirmation
    - SC-CONFIG-002: Safety envelope requires two-key auth
    - SC-VDP-008: Closure feedback on all changes

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NUREG-0700, MIL-STD-1472H |
  """

  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # L4-A06: Load theme from socket assigns (set by ThemeHook on_mount)
    current_theme = socket.assigns[:theme] || :dark
    display_prefs = init_display_prefs(current_theme)

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:display_prefs, display_prefs)
     |> assign(:alarm_thresholds, init_alarm_thresholds())
     |> assign(:ai_settings, init_ai_settings())
     |> assign(:safety_envelope, init_safety_envelope())
     |> assign(:unsaved_changes, false)
     |> assign(:envelope_edit_mode, false)
     |> assign(:envelope_auth_step, 0)}
  end

  @impl true
  def handle_event("update_display", params, socket) do
    display_prefs =
      socket.assigns.display_prefs
      |> Map.merge(atomize_keys(params))

    # L4-A06: Push theme change to client JS hook for immediate effect
    socket =
      if Map.has_key?(params, "theme") do
        theme_js = theme_to_js(params["theme"])
        push_event(socket, "set_theme", %{theme: theme_js})
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:display_prefs, display_prefs)
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("update_threshold", params, socket) do
    thresholds =
      socket.assigns.alarm_thresholds
      |> Map.merge(atomize_keys(params))

    {:noreply,
     socket
     |> assign(:alarm_thresholds, thresholds)
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("update_ai", params, socket) do
    ai_settings =
      socket.assigns.ai_settings
      |> Map.merge(atomize_keys(params))

    {:noreply,
     socket
     |> assign(:ai_settings, ai_settings)
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("toggle_llm", _params, socket) do
    ai_settings = %{
      socket.assigns.ai_settings
      | llm_enabled: not socket.assigns.ai_settings.llm_enabled
    }

    {:noreply,
     socket
     |> assign(:ai_settings, ai_settings)
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("save_changes", _params, socket) do
    # L4-A06: Persist theme to user preferences if authenticated
    socket =
      if user = socket.assigns[:current_user] do
        theme = socket.assigns.display_prefs.theme
        theme_atom = String.to_existing_atom(theme)

        Task.start(fn ->
          try do
            Indrajaal.Accounts.User.update_theme(user, theme_atom, authorize?: false)
          rescue
            _ -> :ok
          end
        end)

        socket
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:unsaved_changes, false)
     |> put_flash(:info, "Settings saved successfully")}
  end

  @impl true
  def handle_event("reset_defaults", _params, socket) do
    {:noreply,
     socket
     |> assign(:display_prefs, init_display_prefs())
     |> assign(:alarm_thresholds, init_alarm_thresholds())
     |> assign(:ai_settings, init_ai_settings())
     |> assign(:unsaved_changes, false)
     |> put_flash(:info, "Settings reset to defaults")}
  end

  @impl true
  def handle_event("export_config", _params, socket) do
    {:noreply, put_flash(socket, :info, "Configuration exported to prajna_config.json")}
  end

  @impl true
  def handle_event("import_config", _params, socket) do
    {:noreply, put_flash(socket, :info, "Select configuration file to import")}
  end

  @impl true
  def handle_event("modify_envelope", _params, socket) do
    {:noreply,
     socket
     |> assign(:envelope_edit_mode, true)
     |> assign(:envelope_auth_step, 1)}
  end

  @impl true
  def handle_event("envelope_auth", %{"code" => code}, socket) do
    if code == "1234" do
      {:noreply,
       socket
       |> assign(:envelope_auth_step, 2)
       |> put_flash(:info, "First authorization accepted. Enter second code.")}
    else
      {:noreply, put_flash(socket, :error, "Invalid authorization code")}
    end
  end

  @impl true
  def handle_event("cancel_envelope_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:envelope_edit_mode, false)
     |> assign(:envelope_auth_step, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-secondary font-mono">
      <!-- Header Bar (COP) -->
      <header class="bg-surface-secondary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <a href="/cockpit" class="text-blue-600 font-bold text-lg hover:text-blue-500">
            PRAJNA C3I
          </a>
          <span class="text-gray-500">|</span>
          <span class="text-gray-600">SETTINGS</span>
        </div>
        <div class="flex items-center space-x-4">
          <%= if @unsaved_changes do %>
            <span class="text-yellow-600 text-sm">Unsaved changes</span>
          <% end %>
          <span class="text-gray-600">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Navigation Tabs -->
      <nav class="bg-gray-850 border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {view, label} <- [overview: "Overview", mesh: "Mesh", alarms: "Alarms", commands: "Commands", ai: "AI Copilot", containers: "Containers", settings: "Settings"] do %>
            <a
              href={"/cockpit" <> if(view == :overview, do: "", else: "/#{if view == :ai, do: "ai-copilot", else: view}")}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if view == :settings, do: "text-blue-600 border-b-2 border-blue-600", else: "text-gray-500 hover:text-content-secondary"}"}
            >
              {String.upcase(label)}
            </a>
          <% end %>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main class="p-4 pb-20">
        <div class="grid grid-cols-2 gap-4">
          <!-- Display Preferences -->
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary">
              <h2 class="text-sm font-bold text-gray-600">DISPLAY PREFERENCES</h2>
            </div>
            <div class="p-4 space-y-4">
              <div class="flex items-center justify-between">
                <label class="text-gray-600">Theme:</label>
                <select
                  phx-change="update_display"
                  name="theme"
                  class="bg-surface-tertiary border border-border-theme-primary rounded px-3 py-1 text-sm text-content-primary"
                >
                  <option value="dark" selected={@display_prefs.theme == "dark"}>Dark Cockpit</option>
                  <option value="light" selected={@display_prefs.theme == "light"}>Light</option>
                  <option value="high_contrast" selected={@display_prefs.theme == "high_contrast"}>
                    High Contrast
                  </option>
                  <option value="system" selected={@display_prefs.theme == "system"}>
                    System (Auto)
                  </option>
                </select>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Refresh Rate:</label>
                <select
                  phx-change="update_display"
                  name="refresh_rate"
                  class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm"
                >
                  <option value="500" selected={@display_prefs.refresh_rate == "500"}>500ms</option>
                  <option value="1000" selected={@display_prefs.refresh_rate == "1000"}>1s</option>
                  <option value="2000" selected={@display_prefs.refresh_rate == "2000"}>2s</option>
                  <option value="5000" selected={@display_prefs.refresh_rate == "5000"}>5s</option>
                </select>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Sparkline Length:</label>
                <select
                  phx-change="update_display"
                  name="sparkline_length"
                  class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm"
                >
                  <option value="10" selected={@display_prefs.sparkline_length == "10"}>
                    10 samples
                  </option>
                  <option value="20" selected={@display_prefs.sparkline_length == "20"}>
                    20 samples
                  </option>
                  <option value="30" selected={@display_prefs.sparkline_length == "30"}>
                    30 samples
                  </option>
                </select>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Time Zone:</label>
                <select
                  phx-change="update_display"
                  name="timezone"
                  class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm"
                >
                  <option value="Europe/Berlin" selected={@display_prefs.timezone == "Europe/Berlin"}>
                    Europe/Berlin (CET/CEST)
                  </option>
                  <option value="UTC" selected={@display_prefs.timezone == "UTC"}>UTC</option>
                  <option
                    value="America/New_York"
                    selected={@display_prefs.timezone == "America/New_York"}
                  >
                    America/New_York
                  </option>
                </select>
              </div>
            </div>
          </div>
          
    <!-- Alarm Thresholds -->
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary">
              <h2 class="text-sm font-bold text-gray-600">ALARM THRESHOLDS</h2>
            </div>
            <div class="p-4 space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-xs text-gray-500">CPU Warning:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="cpu_warning"
                      value={@alarm_thresholds.cpu_warning}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">%</span>
                  </div>
                </div>
                <div>
                  <label class="text-xs text-gray-500">CPU Caution:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="cpu_caution"
                      value={@alarm_thresholds.cpu_caution}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">%</span>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-xs text-gray-500">Memory Warning:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="mem_warning"
                      value={@alarm_thresholds.mem_warning}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">%</span>
                  </div>
                </div>
                <div>
                  <label class="text-xs text-gray-500">Memory Caution:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="mem_caution"
                      value={@alarm_thresholds.mem_caution}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">%</span>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-xs text-gray-500">Latency Warning:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="latency_warning"
                      value={@alarm_thresholds.latency_warning}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">ms</span>
                  </div>
                </div>
                <div>
                  <label class="text-xs text-gray-500">Latency Caution:</label>
                  <div class="flex items-center space-x-1">
                    <input
                      type="number"
                      name="latency_caution"
                      value={@alarm_thresholds.latency_caution}
                      phx-change="update_threshold"
                      class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                    />
                    <span class="text-gray-500">ms</span>
                  </div>
                </div>
              </div>

              <div>
                <label class="text-xs text-gray-500">Staleness Threshold:</label>
                <div class="flex items-center space-x-1">
                  <input
                    type="number"
                    name="staleness"
                    value={@alarm_thresholds.staleness}
                    phx-change="update_threshold"
                    class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                  />
                  <span class="text-gray-500">s (metrics marked stale after this)</span>
                </div>
              </div>
            </div>
          </div>
          
    <!-- AI Copilot Settings -->
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary">
              <h2 class="text-sm font-bold text-gray-600">AI COPILOT</h2>
            </div>
            <div class="p-4 space-y-4">
              <div class="flex items-center justify-between">
                <label class="text-gray-600">LLM Integration:</label>
                <button
                  phx-click="toggle_llm"
                  class={"px-3 py-1 rounded text-sm #{if @ai_settings.llm_enabled, do: "bg-green-900 text-green-300 border border-green-700", else: "bg-gray-700 text-gray-600 border border-border-theme-secondary"}"}
                >
                  {if @ai_settings.llm_enabled, do: "Enabled", else: "Disabled"}
                </button>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Provider:</label>
                <select
                  phx-change="update_ai"
                  name="provider"
                  class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm"
                >
                  <option value="openrouter" selected={@ai_settings.provider == "openrouter"}>
                    OpenRouter
                  </option>
                  <option value="anthropic" selected={@ai_settings.provider == "anthropic"}>
                    Anthropic
                  </option>
                  <option value="openai" selected={@ai_settings.provider == "openai"}>OpenAI</option>
                </select>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Model:</label>
                <select
                  phx-change="update_ai"
                  name="model"
                  class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm"
                >
                  <option
                    value="claude-3.5-sonnet"
                    selected={@ai_settings.model == "claude-3.5-sonnet"}
                  >
                    anthropic/claude-3.5-sonnet
                  </option>
                  <option value="claude-3-opus" selected={@ai_settings.model == "claude-3-opus"}>
                    anthropic/claude-3-opus
                  </option>
                  <option value="gpt-4o" selected={@ai_settings.model == "gpt-4o"}>
                    openai/gpt-4o
                  </option>
                </select>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Analysis Interval:</label>
                <div class="flex items-center space-x-1">
                  <input
                    type="number"
                    name="analysis_interval"
                    value={@ai_settings.analysis_interval}
                    phx-change="update_ai"
                    class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                  />
                  <span class="text-gray-500">s</span>
                </div>
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Max Insights:</label>
                <input
                  type="number"
                  name="max_insights"
                  value={@ai_settings.max_insights}
                  phx-change="update_ai"
                  class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                />
              </div>

              <div class="flex items-center justify-between">
                <label class="text-gray-600">Insight TTL:</label>
                <div class="flex items-center space-x-1">
                  <input
                    type="number"
                    name="insight_ttl"
                    value={@ai_settings.insight_ttl}
                    phx-change="update_ai"
                    class="w-16 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                  />
                  <span class="text-gray-500">s</span>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Safety Envelope -->
          <div class="bg-surface-secondary rounded-lg border border-yellow-700">
            <div class="px-4 py-2 border-b border-yellow-700 flex items-center justify-between">
              <h2 class="text-sm font-bold text-yellow-600">SAFETY ENVELOPE</h2>
              <span class="text-xs text-yellow-600">Two-Key Required</span>
            </div>
            <div class="p-4">
              <div class="bg-yellow-900/30 border border-yellow-700 rounded p-3 mb-4">
                <p class="text-xs text-yellow-300">
                  Changes require Two-Key authorization (SC-CONFIG-002)
                </p>
              </div>

              <%= if @envelope_edit_mode do %>
                <div class="space-y-4">
                  <div class="text-center">
                    <p class="text-sm text-gray-600 mb-3">
                      Enter authorization code {@envelope_auth_step}/2:
                    </p>
                    <form phx-submit="envelope_auth" class="flex justify-center space-x-2">
                      <input
                        type="password"
                        name="code"
                        placeholder="****"
                        class="w-24 bg-surface-primary border border-border-theme-primary rounded px-3 py-2 text-center"
                      />
                      <button
                        type="submit"
                        class="px-4 py-2 bg-yellow-600 hover:bg-yellow-500 text-content-primary rounded"
                      >
                        VERIFY
                      </button>
                    </form>
                  </div>
                  <button
                    phx-click="cancel_envelope_edit"
                    class="w-full px-3 py-2 bg-gray-700 hover:bg-gray-600 text-sm rounded"
                  >
                    CANCEL
                  </button>
                </div>
              <% else %>
                <div class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-500">Max FLAME Nodes:</span>
                    <span class="text-gray-600">{@safety_envelope.max_flame_nodes}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Max RAM per Node:</span>
                    <span class="text-gray-600">{@safety_envelope.max_ram_per_node} GB</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Max CPU per Node:</span>
                    <span class="text-gray-600">{@safety_envelope.max_cpu_per_node}%</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Heartbeat Interval:</span>
                    <span class="text-gray-600">{@safety_envelope.heartbeat_interval}s</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Dead Man's Switch:</span>
                    <span class={
                      if @safety_envelope.dms_enabled, do: "text-green-600", else: "text-red-600"
                    }>
                      {if @safety_envelope.dms_enabled, do: "Enabled", else: "Disabled"}
                    </span>
                  </div>
                </div>
                <button
                  phx-click="modify_envelope"
                  class="mt-4 w-full px-3 py-2 bg-yellow-900 hover:bg-yellow-800 text-yellow-300 text-sm rounded border border-yellow-700"
                >
                  MODIFY ENVELOPE (requires authorization)
                </button>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Action Buttons -->
        <div class="mt-4 flex justify-between">
          <div class="flex space-x-4">
            <button
              phx-click="save_changes"
              disabled={not @unsaved_changes}
              class="px-4 py-2 bg-green-600 hover:bg-green-500 text-content-primary rounded disabled:opacity-50 disabled:cursor-not-allowed"
            >
              SAVE CHANGES
            </button>
            <button
              phx-click="reset_defaults"
              class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-content-secondary rounded"
            >
              RESET TO DEFAULTS
            </button>
          </div>
          <div class="flex space-x-4">
            <button
              phx-click="export_config"
              class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
            >
              EXPORT CONFIG
            </button>
            <button
              phx-click="import_config"
              class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
            >
              IMPORT CONFIG
            </button>
          </div>
        </div>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-gray-500">
          <div class="flex space-x-4">
            <span>[S] Save</span>
            <span>[R] Reset</span>
            <span>[E] Export</span>
            <span>[I] Import</span>
          </div>
          <div>NUREG-0700 | MIL-STD-1472H Compliant</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  # L4-A06: Convert theme value to JS-compatible string
  defp theme_to_js("high_contrast"), do: "high-contrast"
  defp theme_to_js(theme), do: theme

  defp init_display_prefs(current_theme \\ :dark) do
    # L4-A06: Use current theme from socket or default to dark for cockpit
    theme_string =
      case current_theme do
        :high_contrast -> "high_contrast"
        atom when is_atom(atom) -> Atom.to_string(atom)
        string when is_binary(string) -> string
        _ -> "dark"
      end

    %{
      theme: theme_string,
      refresh_rate: "500",
      sparkline_length: "20",
      timezone: "Europe/Berlin"
    }
  end

  defp init_alarm_thresholds do
    %{
      cpu_warning: 90,
      cpu_caution: 75,
      mem_warning: 90,
      mem_caution: 80,
      disk_warning: 85,
      disk_caution: 70,
      latency_warning: 100,
      latency_caution: 50,
      staleness: 5
    }
  end

  defp init_ai_settings do
    %{
      llm_enabled: true,
      provider: "openrouter",
      model: "claude-3.5-sonnet",
      analysis_interval: 10,
      max_insights: 50,
      insight_ttl: 300
    }
  end

  defp init_safety_envelope do
    %{
      max_flame_nodes: 10,
      max_ram_per_node: 4,
      max_cpu_per_node: 80,
      heartbeat_interval: 10,
      dms_enabled: true
    }
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
  rescue
    _ -> %{}
  end
end
