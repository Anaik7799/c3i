namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I - Settings Page
/// =============================================================================
/// Application settings and configuration interface.
/// STAMP: SC-HMI-001 (MVU), SC-HMI-007 (User preferences)
/// Standards: ISO 9241-110 (Dialogue principles), WCAG 2.1 (Accessibility)
/// =============================================================================

module Settings =

    type SettingsModel = {
        ActiveTab: SettingsTab
        PendingChanges: Map<string, obj>
        HasUnsavedChanges: bool
    }

    and SettingsTab =
        | AppearanceTab
        | NotificationsTab
        | ConnectionTab
        | AdvancedTab

    type SettingsMsg =
        | SelectTab of SettingsTab
        | UpdateTheme of string
        | UpdateRefreshRate of int
        | ToggleDarkCockpit
        | UpdateNotificationLevel of string
        | UpdateConnectionTimeout of int
        | SaveSettings
        | ResetSettings
        | CancelChanges

    let init () =
        {
            ActiveTab = AppearanceTab
            PendingChanges = Map.empty
            HasUnsavedChanges = false
        }

    let update (msg: SettingsMsg) (model: SettingsModel) (dispatch: Message -> unit) =
        match msg with
        | SelectTab tab ->
            { model with ActiveTab = tab }

        | UpdateTheme theme ->
            dispatch (SetTheme theme)
            { model with
                PendingChanges = model.PendingChanges.Add("theme", box theme)
                HasUnsavedChanges = true }

        | UpdateRefreshRate rate ->
            dispatch (SetRefreshRate rate)
            { model with
                PendingChanges = model.PendingChanges.Add("refreshRate", box rate)
                HasUnsavedChanges = true }

        | ToggleDarkCockpit ->
            dispatch Message.ToggleDarkCockpit
            { model with HasUnsavedChanges = true }

        | UpdateNotificationLevel level ->
            { model with
                PendingChanges = model.PendingChanges.Add("notificationLevel", box level)
                HasUnsavedChanges = true }

        | UpdateConnectionTimeout timeout ->
            { model with
                PendingChanges = model.PendingChanges.Add("connectionTimeout", box timeout)
                HasUnsavedChanges = true }

        | SaveSettings ->
            { model with
                PendingChanges = Map.empty
                HasUnsavedChanges = false }

        | ResetSettings ->
            { model with
                PendingChanges = Map.empty
                HasUnsavedChanges = false }

        | CancelChanges ->
            { model with
                PendingChanges = Map.empty
                HasUnsavedChanges = false }

    /// Render tab navigation
    let private renderTabNavigation (activeTab: SettingsTab) dispatch =
        div {
            attr.``class`` "settings-tabs"
            button {
                attr.``class`` (if activeTab = AppearanceTab then "tab-btn active" else "tab-btn")
                on.click (fun _ -> dispatch (SelectTab AppearanceTab))
                text "Appearance"
            }

            button {
                attr.``class`` (if activeTab = NotificationsTab then "tab-btn active" else "tab-btn")
                on.click (fun _ -> dispatch (SelectTab NotificationsTab))
                text "Notifications"
            }

            button {
                attr.``class`` (if activeTab = ConnectionTab then "tab-btn active" else "tab-btn")
                on.click (fun _ -> dispatch (SelectTab ConnectionTab))
                text "Connection"
            }

            button {
                attr.``class`` (if activeTab = AdvancedTab then "tab-btn active" else "tab-btn")
                on.click (fun _ -> dispatch (SelectTab AdvancedTab))
                text "Advanced"
            }
        }

    /// Render appearance settings
    let private renderAppearanceSettings (appModel: Model.AppModel) dispatch =
        div {
            attr.``class`` "settings-section"
            h2 { text "Appearance Settings" }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Theme"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        attr.value appModel.Theme
                        on.change (fun e -> dispatch (UpdateTheme (e.Value :?> string)))
                        option {
                            attr.value "dark-cockpit"
                            text "Dark Cockpit (Default)"
                        }
                        option {
                            attr.value "light"
                            text "Light"
                        }
                        option {
                            attr.value "high-contrast"
                            text "High Contrast"
                        }
                        option {
                            attr.value "nasa-std-3000"
                            text "NASA-STD-3000"
                        }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Choose the visual theme for the interface"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Dark Cockpit Mode"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input {
                            attr.``type`` "checkbox"
                            attr.``checked`` appModel.DarkCockpitEnabled
                            on.change (fun _ -> dispatch ToggleDarkCockpit)
                        }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Dim interface when no anomalies present (NASA-STD-3000 Dark Cockpit principle)"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Refresh Rate"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        attr.value (string appModel.RefreshRateMs)
                        on.change (fun e -> dispatch (UpdateRefreshRate (int (e.Value :?> string))))
                        option { attr.value "500"; text "500ms (Very Fast)" }
                        option { attr.value "1000"; text "1s (Fast)" }
                        option { attr.value "2000"; text "2s (Normal)" }
                        option { attr.value "5000"; text "5s (Slow)" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "How often the dashboard refreshes data"
                }
            }

            div {
                attr.``class`` "setting-row"
                div {
                    attr.``class`` "theme-preview"
                    h3 { text "Preview" }
                    div {
                        attr.``class`` "preview-content"
                        div {
                            attr.``class`` "preview-card"
                            div {
                                attr.``class`` "preview-header"
                                text "Sample Card"
                            }
                            div {
                                attr.``class`` "preview-body"
                                text "This is how content will appear with your current theme"
                            }
                        }
                    }
                }
            }
        }

    /// Render notification settings
    let private renderNotificationSettings dispatch =
        div {
            attr.``class`` "settings-section"
            h2 { text "Notification Settings" }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Notification Level"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        on.change (fun e -> dispatch (UpdateNotificationLevel (e.Value :?> string)))
                        option { attr.value "all"; text "All Notifications" }
                        option { attr.value "critical"; text "Critical Only" }
                        option { attr.value "critical-high"; text "Critical + High" }
                        option { attr.value "none"; text "None" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Minimum severity level for notifications"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Sound Notifications"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` true }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Play sound for critical alarms"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Browser Notifications"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` false }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Show browser notifications for critical events"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Auto-acknowledge Timeout"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        option { attr.value "never"; text "Never" }
                        option { attr.value "300"; text "5 minutes" }
                        option { attr.value "900"; text "15 minutes" }
                        option { attr.value "3600"; text "1 hour" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Automatically acknowledge alarms after specified time"
                }
            }
        }

    /// Render connection settings
    let private renderConnectionSettings dispatch =
        div {
            attr.``class`` "settings-section"
            h2 { text "Connection Settings" }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Backend URL"
                }
                div {
                    attr.``class`` "setting-control"
                    input {
                        attr.``type`` "text"
                        attr.value "http://localhost:4000"
                        attr.readonly true
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Elixir backend API endpoint"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Connection Timeout"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        on.change (fun e -> dispatch (UpdateConnectionTimeout (int (e.Value :?> string))))
                        option { attr.value "5000"; text "5 seconds" }
                        option { attr.value "10000"; text "10 seconds" }
                        option { attr.value "30000"; text "30 seconds" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Timeout for backend connection attempts"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Auto-reconnect"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` true }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Automatically reconnect when connection is lost"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Zenoh Telemetry"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` true; attr.readonly true }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Real-time telemetry via Zenoh (Always enabled per SC-ZENOH-001)"
                }
            }
        }

    /// Render advanced settings
    let private renderAdvancedSettings dispatch =
        div {
            attr.``class`` "settings-section"
            h2 { text "Advanced Settings" }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Enable Debug Mode"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` false }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Show additional debugging information"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Log Level"
                }
                div {
                    attr.``class`` "setting-control"
                    select {
                        option { attr.value "error"; text "Error" }
                        option { attr.value "warning"; text "Warning" }
                        option { attr.value "info"; text "Info" }
                        option { attr.value "debug"; text "Debug" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Minimum log level for console output"
                }
            }

            div {
                attr.``class`` "setting-row"
                label {
                    attr.``class`` "setting-label"
                    text "Performance Metrics"
                }
                div {
                    attr.``class`` "setting-control"
                    label {
                        attr.``class`` "toggle-switch"
                        input { attr.``type`` "checkbox"; attr.``checked`` true }
                        span { attr.``class`` "slider" }
                    }
                }
                div {
                    attr.``class`` "setting-description"
                    text "Collect and display performance metrics"
                }
            }

            div {
                attr.``class`` "setting-row danger-zone"
                h3 {
                    attr.``class`` "danger-zone-title"
                    text "⚠ Danger Zone"
                }

                button {
                    attr.``class`` "btn-danger"
                    on.click (fun _ -> dispatch ResetSettings)
                    text "Reset All Settings"
                }

                button {
                    attr.``class`` "btn-danger"
                    attr.disabled true
                    text "Clear All Data"
                }
            }
        }

    /// Render action buttons
    let private renderActionButtons (hasChanges: bool) dispatch =
        div {
            attr.``class`` "settings-actions"
            button {
                attr.``class`` "btn-primary"
                attr.disabled (not hasChanges)
                on.click (fun _ -> dispatch SaveSettings)
                text "Save Changes"
            }

            button {
                attr.``class`` "btn-secondary"
                attr.disabled (not hasChanges)
                on.click (fun _ -> dispatch CancelChanges)
                text "Cancel"
            }

            cond hasChanges <| function
            | true ->
                div {
                    attr.``class`` "unsaved-changes-notice"
                    text "⚠ You have unsaved changes"
                }
            | false -> empty ()
        }

    /// Main view
    let view (appModel: Model.AppModel) (localModel: SettingsModel) (localDispatch: SettingsMsg -> unit) (dispatch: Message -> unit) =
        div {
            attr.``class`` "page-settings"
            div {
                attr.``class`` "page-header"
                h1 { text "Settings" }
                div {
                    attr.``class`` "page-meta"
                    text "Configure application preferences and behavior"
                }
            }

            renderTabNavigation localModel.ActiveTab localDispatch

            div {
                attr.``class`` "settings-content"
                match localModel.ActiveTab with
                | AppearanceTab ->
                    renderAppearanceSettings appModel localDispatch
                | NotificationsTab ->
                    renderNotificationSettings localDispatch
                | ConnectionTab ->
                    renderConnectionSettings localDispatch
                | AdvancedTab ->
                    renderAdvancedSettings localDispatch
            }

            renderActionButtons localModel.HasUnsavedChanges localDispatch
        }

type SettingsComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Settings.init ()
    let mutable lastDispatch: (Message -> unit) option = None

    let localDispatch (msg: Settings.SettingsMsg) =
        match lastDispatch with
        | Some dispatch -> localModel <- Settings.update msg localModel dispatch
        | None -> localModel <- Settings.update msg localModel ignore

    override this.View model dispatch =
        lastDispatch <- Some dispatch
        Settings.view model localModel localDispatch dispatch
