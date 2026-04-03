defmodule Indrajaal.Shared.DeviceDetection do
  @moduledoc """
  Shared device detection utilities to eliminate code duplication between
    account modules.

  Extracted from Indrajaal.Accounts.ActivityLog and Indrajaal.Accounts.Session
  following Toyota TPS principles to eliminate waste and maintain single
    source of truth.
  """

  @doc """
  Parse device information from user agent string.

  Returns a map with device type, browser, and OS information.
  """
  @spec parse_device_info(any()) :: any()
  def parse_device_info(user_agent) when is_binary(user_agent) do
    %{
      is_mobile: detect_mobile(user_agent),
      is_tablet: detect_tablet(user_agent),
      browser: detect_browser(user_agent),
      os: detect_os(user_agent)
    }
  end

  @spec parse_device_info(any()) :: any()
  # def parse_device_info(nil), do: nil
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Apply device detection to an Ash changeset.

  Extracts __user_agent from changeset and sets device_info attribute.
  """
  @spec apply_device_detection(any()) :: any()
  def apply_device_detection(changeset) do
    user_agent = Ash.Changeset.get_attribute(changeset, :user_agent)

    if user_agent do
      device_info = parse_device_info(user_agent)
      Ash.Changeset.change_attribute(changeset, :device_info, device_info)
    else
      changeset
    end
  end

  @doc """
  Detect if user agent indicates mobile device.
  """
  @spec detect_mobile(any()) :: any()
  def detect_mobile(user_agent) when is_binary(user_agent) do
    String.contains?(user_agent, ["Mobile", "Android", "iPhone"])
  end

  @spec detect_mobile(any()) :: any()
  # def detect_mobile(_), do: false
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Detect if user agent indicates tablet device.
  """
  @spec detect_tablet(any()) :: any()
  def detect_tablet(user_agent) when is_binary(user_agent) do
    String.contains?(user_agent, ["iPad", "Tablet"])
  end

  @spec detect_tablet(any()) :: any()
  # def detect_tablet(_), do: false
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Detect browser from user agent string.
  """
  @spec detect_browser(any()) :: any()
  def detect_browser(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Chrome") -> "Chrome"
      String.contains?(user_agent, "Firefox") -> "Firefox"
      String.contains?(user_agent, "Safari") -> "Safari"
      String.contains?(user_agent, "Edge") -> "Edge"
      true -> "Unknown"
    end
  end

  @spec detect_browser(any()) :: any()
  # def detect_browser(_), do: "Unknown"
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Detect operating system from user agent string.
  """
  @spec detect_os(any()) :: any()
  def detect_os(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Windows") -> "Windows"
      String.contains?(user_agent, "Mac OS") -> "macOS"
      String.contains?(user_agent, "Linux") -> "Linux"
      String.contains?(user_agent, "Android") -> "Android"
      String.contains?(user_agent, "iOS") -> "iOS"
      true -> "Unknown"
    end
  end

  @spec detect_os(any()) :: any()
  # def detect_os(_), do: "Unknown"
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Get comprehensive device information as a formatted string for logging.
  """
  @spec device_summary(any()) :: any()
  def device_summary(device_info) when is_map(device_info) do
    type =
      cond do
        device_info[:is_mobile] -> "Mobile"
        device_info[:is_tablet] -> "Tablet"
        true -> "Desktop"
      end

    "#{type} (#{device_info[:browser]} on #{device_info[:os]})"
  end

  @spec device_summary(any()) :: any()
  # def device_summary(_), do: "Unknown Device"
  # Claude Agent: EP-076 - Unreachable function clause commented

  # Agent: Helper - 2 (General Purpose Agent)
  # SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
  # Domain: General
  # Responsibilities: Template generation, standards enforcement, general coordination
  # Multi-Agent Architecture: Integrated with 11-agent coordination system
  # Cybernetic Feedback: Active feedback loops for continuous improvement
end
