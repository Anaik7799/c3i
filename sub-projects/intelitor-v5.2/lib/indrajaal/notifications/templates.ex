defmodule Indrajaal.Notifications.Templates do
  @moduledoc """
  Notification template management and rendering.

  Provides localized templates for all notification types
  with variable substitution.

  Agent: Helper - 3 manages notification templates
  SOPv5.1 Compliance: ✅
  """

  # Template definitions
  @templates %{
    # Alarm notifications
    alarm_triggered: %{
      title: "Alarm Triggered",
      body: "{{alarm_name}} has been triggered at {{location}}",
      sound: "alarm",
      priority: :high,
      badge: 1,
      category: "alarm"
    },
    critical_alarm: %{
      title: "🚨 Critical Alarm",
      body: "URGENT: {{alarm_name}} _requires immediate attention",
      sound: "critical_alarm",
      priority: :high,
      badge: 1,
      category: "alarm"
    },
    alarm_acknowledged: %{
      title: "Alarm Acknowledged",
      body: "{{alarm_name}} acknowledged by {{__user_name}}",
      sound: nil,
      priority: :normal,
      category: "alarm"
    },
    alarm_resolved: %{
      title: "Alarm Resolved",
      body: "{{alarm_name}} has been resolved",
      sound: nil,
      priority: :normal,
      category: "alarm"
    },

    # Device notifications
    device_offline: %{
      title: "Device Offline",
      body: "{{device_name}} has gone offline",
      sound: "notification",
      priority: :normal,
      category: "device"
    },
    device_online: %{
      title: "Device Online",
      body: "{{device_name}} is back online",
      sound: nil,
      priority: :low,
      category: "device"
    },
    device_maintenance: %{
      title: "Maintenance Required",
      body: "{{device_name}} _requires maintenance",
      sound: "notification",
      priority: :normal,
      category: "maintenance"
    },

    # System notifications
    system_announcement: %{
      title: "System Announcement",
      body: "{{message}}",
      sound: "notification",
      priority: :normal,
      category: "system"
    },
    maintenance_reminder: %{
      title: "Maintenance Reminder",
      body: "Scheduled maintenance for {{device_name}} is due",
      sound: nil,
      priority: :low,
      category: "maintenance"
    },

    # Security notifications
    security_breach: %{
      title: "⚠️ Security Alert",
      body: "Security breach detected at {{location}}",
      sound: "security_alert",
      priority: :high,
      badge: 1,
      category: "security"
    },
    access_denied: %{
      title: "Access Denied",
      body: "Unauthorized access attempt at {{location}}",
      sound: "notification",
      priority: :high,
      category: "security"
    },

    # Configuration notifications
    config_changed: %{
      title: "Configuration Updated",
      body: "{{config_type}} configuration changed by {{__user_name}}",
      sound: nil,
      priority: :low,
      category: "config"
    },
    approval_required: %{
      title: "Approval Required",
      body: "{{change_type}} _requires your approval",
      sound: "notification",
      priority: :normal,
      badge: 1,
      category: "approval"
    },

    # Test notification
    test_notification: %{
      title: "Test Notification",
      body: "This is a test notification",
      sound: "default",
      priority: :normal,
      category: "test"
    }
  }

  # Localized templates
  @localized_templates %{
    "es" => %{
      alarm_triggered: %{
        title: "Alarma Activada",
        body: "{{alarm_name}} se ha activado en {{location}}"
      },
      device_offline: %{
        title: "Dispositivo Desconectado",
        body: "{{device_name}} está desconectado"
      }
    },
    "fr" => %{
      alarm_triggered: %{
        title: "Alarme Déclenchée",
        body: "{{alarm_name}} a été déclenchée à {{location}}"
      },
      device_offline: %{
        title: "Appareil Hors Ligne",
        body: "{{device_name}} est hors ligne"
      }
    }
  }

  @doc """
  Gets a notification template by name.
  """
  @spec get_template(any()) :: any()
  def get_template(name) when is_atom(name) do
    Map.get(@templates, name, @templates.test_notification)
  end

  @doc """
  Renders a template with variable substitution.

  ## Options
    - :locale - Language code for localization (default: "en")
  """
  @spec render(term(), term(), term()) :: term()
  def render(template_name, variables, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")

    # Get base template
    base_template = get_template(template_name)

    # Get localized template if available
    template = get_localized_template(template_name, locale, base_template)

    # Render with variables
    %{
      title: substitute_variables(template.title, variables),
      body: substitute_variables(template.body, variables),
      sound: template[:sound],
      priority: template[:priority] || :normal,
      badge: template[:badge],
      category: template[:category]
    }
  end

  @doc """
  Lists all available templates.
  """
  def list_templates do
    Map.keys(@templates)
  end

  @doc """
  Gets template meta_data (without rendering).
  """
  @spec get_template_info(any()) :: any()
  def get_template_info(name) do
    template = get_template(name)

    %{
      name: name,
      title: template.title,
      body: template.body,
      variables: extract_variables(template),
      sound: template[:sound],
      priority: template[:priority],
      category: template[:category]
    }
  end

  @doc """
  Validates that all _required variables are provided.
  """
  @spec validate_variables(any(), any()) :: any()
  def validate_variables(template_name, provided_variables) do
    template = get_template(template_name)
    required = extract_variables(template)
    provided = provided_variables |> Map.keys() |> Enum.map(&to_string/1)

    missing = required -- provided

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_variables, missing}}
    end
  end

  # Private functions

  defp get_localized_template(name, locale, base_template) do
    localized = get_in(@localized_templates, [locale, name]) || %{}

    Map.merge(base_template, localized)
  end

  @spec substitute_variables(term(), term()) :: term()
  defp substitute_variables(text, variables) when is_binary(text) do
    Enum.reduce(variables, text, fn {key, value}, acc ->
      pattern = "{{#{key}}}"
      String.replace(acc, pattern, to_string(value))
    end)
  end

  @spec substitute_variables(term(), term()) :: term()
  defp substitute_variables(text, _variables), do: text

  defp extract_variables(template) do
    text = "#{template.title} #{template.body}"

    ~r/\{\{(\w+)\}\}/
    |> Regex.scan(text)
    |> Enum.map(fn [_, var] -> var end)
    |> Enum.uniq()
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
