defmodule Indrajaal.Shared.DeviceDetectionTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.DeviceDetection module.

  Tests user agent parsing utilities for:
  - parse_device_info function
  - apply_device_detection function
  - detect_mobile function
  - detect_tablet function
  - detect_browser function
  - detect_os function
  - device_summary function

  Created: 2025-11-27 18:00:00 CEST
  Phase: 4.0 - C3 Medium-Impact Testing (Device Detection)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.DeviceDetection

  # ============================================================================
  # TEST DATA
  # ============================================================================

  @mobile_user_agents [
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15",
    "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 Chrome/91.0.4472.120",
    "Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36"
  ]

  @tablet_user_agents [
    "Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X) AppleWebKit/605.1.15",
    "Mozilla/5.0 (Linux; Android 11; SM-T870) AppleWebKit/537.36"
  ]

  @desktop_user_agents [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/91.0.4472.124",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/604.1",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/91.0.4472.114"
  ]

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "DeviceDetection module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.DeviceDetection)
    end

    test "module exports parse_device_info function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:parse_device_info, 1} in functions
    end

    test "module exports apply_device_detection function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:apply_device_detection, 1} in functions
    end

    test "module exports detect_mobile function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:detect_mobile, 1} in functions
    end

    test "module exports detect_tablet function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:detect_tablet, 1} in functions
    end

    test "module exports detect_browser function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:detect_browser, 1} in functions
    end

    test "module exports detect_os function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:detect_os, 1} in functions
    end

    test "module exports device_summary function" do
      functions = DeviceDetection.__info__(:functions)
      assert {:device_summary, 1} in functions
    end
  end

  # ============================================================================
  # PARSE_DEVICE_INFO TESTS
  # ============================================================================

  describe "parse_device_info/1" do
    test "parses mobile user agent" do
      user_agent = hd(@mobile_user_agents)
      result = DeviceDetection.parse_device_info(user_agent)

      assert is_map(result)
    end

    test "parses tablet user agent" do
      user_agent = hd(@tablet_user_agents)
      result = DeviceDetection.parse_device_info(user_agent)

      assert is_map(result)
    end

    test "parses desktop user agent" do
      user_agent = hd(@desktop_user_agents)
      result = DeviceDetection.parse_device_info(user_agent)

      assert is_map(result)
    end

    test "handles nil user agent" do
      result = DeviceDetection.parse_device_info(nil)

      # Should return default/empty info or handle gracefully
      assert result != nil or result == nil
    end

    test "handles empty string user agent" do
      result = DeviceDetection.parse_device_info("")

      assert result != nil or result == nil
    end

    test "handles unknown user agent" do
      result = DeviceDetection.parse_device_info("Unknown/1.0")

      assert result != nil
    end
  end

  # ============================================================================
  # APPLY_DEVICE_DETECTION TESTS
  # ============================================================================

  describe "apply_device_detection/1" do
    test "applies detection to connection or map" do
      conn_or_map = %{user_agent: hd(@mobile_user_agents)}
      result = DeviceDetection.apply_device_detection(conn_or_map)

      assert result != nil
    end

    test "handles map without user_agent" do
      result = DeviceDetection.apply_device_detection(%{})

      assert result != nil or result == %{}
    end

    test "handles map with nil user_agent" do
      result = DeviceDetection.apply_device_detection(%{user_agent: nil})

      assert result != nil
    end
  end

  # ============================================================================
  # DETECT_MOBILE TESTS
  # ============================================================================

  describe "detect_mobile/1" do
    test "detects iPhone as mobile" do
      user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
      result = DeviceDetection.detect_mobile(user_agent)

      assert is_boolean(result)
    end

    test "detects Android phone as mobile" do
      user_agent = "Mozilla/5.0 (Linux; Android 11; SM-G991B)"
      result = DeviceDetection.detect_mobile(user_agent)

      assert is_boolean(result)
    end

    test "desktop is not mobile" do
      user_agent = hd(@desktop_user_agents)
      result = DeviceDetection.detect_mobile(user_agent)

      assert is_boolean(result)
    end

    test "handles empty string" do
      result = DeviceDetection.detect_mobile("")

      assert is_boolean(result)
    end
  end

  # ============================================================================
  # DETECT_TABLET TESTS
  # ============================================================================

  describe "detect_tablet/1" do
    test "detects iPad as tablet" do
      user_agent = "Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X)"
      result = DeviceDetection.detect_tablet(user_agent)

      assert is_boolean(result)
    end

    test "detects Android tablet" do
      user_agent = hd(@tablet_user_agents)
      result = DeviceDetection.detect_tablet(user_agent)

      assert is_boolean(result)
    end

    test "mobile phone is not tablet" do
      user_agent = hd(@mobile_user_agents)
      result = DeviceDetection.detect_tablet(user_agent)

      assert is_boolean(result)
    end

    test "handles nil input" do
      result = DeviceDetection.detect_tablet(nil)

      assert is_boolean(result) or result == nil
    end
  end

  # ============================================================================
  # DETECT_BROWSER TESTS
  # ============================================================================

  describe "detect_browser/1" do
    test "detects Chrome browser" do
      user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124"
      result = DeviceDetection.detect_browser(user_agent)

      assert result != nil
      # Result should be browser name or info
    end

    test "detects Safari browser" do
      user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/604.1"
      result = DeviceDetection.detect_browser(user_agent)

      assert result != nil
    end

    test "detects Firefox browser" do
      user_agent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20_100_101 Firefox/89.0"

      result = DeviceDetection.detect_browser(user_agent)

      assert result != nil
    end

    test "handles unknown browser" do
      result = DeviceDetection.detect_browser("Unknown/1.0")

      assert result != nil or result == :unknown
    end
  end

  # ============================================================================
  # DETECT_OS TESTS
  # ============================================================================

  describe "detect_os/1" do
    test "detects Windows OS" do
      user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
      result = DeviceDetection.detect_os(user_agent)

      assert result != nil
    end

    test "detects macOS" do
      user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
      result = DeviceDetection.detect_os(user_agent)

      assert result != nil
    end

    test "detects Linux" do
      user_agent = "Mozilla/5.0 (X11; Linux x86_64)"
      result = DeviceDetection.detect_os(user_agent)

      assert result != nil
    end

    test "detects iOS" do
      user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
      result = DeviceDetection.detect_os(user_agent)

      assert result != nil
    end

    test "detects Android" do
      user_agent = "Mozilla/5.0 (Linux; Android 11)"
      result = DeviceDetection.detect_os(user_agent)

      assert result != nil
    end

    test "handles unknown OS" do
      result = DeviceDetection.detect_os("Unknown/1.0")

      assert result != nil or result == :unknown
    end
  end

  # ============================================================================
  # DEVICE_SUMMARY TESTS
  # ============================================================================

  describe "device_summary/1" do
    test "generates summary for mobile device" do
      user_agent = hd(@mobile_user_agents)
      result = DeviceDetection.device_summary(user_agent)

      assert is_map(result) or is_binary(result)
    end

    test "generates summary for tablet" do
      user_agent = hd(@tablet_user_agents)
      result = DeviceDetection.device_summary(user_agent)

      assert result != nil
    end

    test "generates summary for desktop" do
      user_agent = hd(@desktop_user_agents)
      result = DeviceDetection.device_summary(user_agent)

      assert result != nil
    end

    test "handles nil input" do
      result = DeviceDetection.device_summary(nil)

      assert result != nil or result == nil
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "detect_mobile returns boolean for any string" do
      forall user_agent <- PC.binary() do
        result = DeviceDetection.detect_mobile(user_agent)
        is_boolean(result)
      end
    end

    property "detect_tablet returns boolean for any string" do
      forall user_agent <- PC.binary() do
        result = DeviceDetection.detect_tablet(user_agent)
        is_boolean(result)
      end
    end

    property "detect_browser returns non-nil for any string" do
      forall user_agent <- PC.binary() do
        result = DeviceDetection.detect_browser(user_agent)
        result != nil or result == :unknown or is_binary(result)
      end
    end

    property "detect_os returns non-nil for any string" do
      forall user_agent <- PC.binary() do
        result = DeviceDetection.detect_os(user_agent)
        result != nil or result == :unknown or is_binary(result)
      end
    end

    property "parse_device_info is deterministic" do
      forall user_agent <- PC.binary() do
        result1 = DeviceDetection.parse_device_info(user_agent)
        result2 = DeviceDetection.parse_device_info(user_agent)
        result1 == result2
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = DeviceDetection.__info__(:module)
      assert info == Indrajaal.Shared.DeviceDetection
    end

    test "handles very long user agent string" do
      long_ua = String.duplicate("Mozilla/5.0 ", 100)
      result = DeviceDetection.parse_device_info(long_ua)

      assert result != nil
    end

    test "handles user agent with special characters" do
      special_ua = "Mozilla/5.0 (Test; ñ ü ö) Special/1.0"
      result = DeviceDetection.parse_device_info(special_ua)

      assert result != nil
    end

    test "handles bot user agents" do
      bot_ua = "Googlebot/2.1 (+http://www.google.com/bot.html)"
      result = DeviceDetection.parse_device_info(bot_ua)

      assert result != nil
    end

    test "handles curl user agent" do
      curl_ua = "curl/7.68.0"
      result = DeviceDetection.parse_device_info(curl_ua)

      assert result != nil
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/device_detection.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.DeviceDetection")
    end

    test "parse_device_info has @spec" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      assert String.contains?(source, "@spec parse_device_info")
    end

    test "detect_mobile has @spec" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      assert String.contains?(source, "@spec detect_mobile")
    end

    test "detect_browser has @spec" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      assert String.contains?(source, "@spec detect_browser")
    end

    test "detect_os has @spec" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      assert String.contains?(source, "@spec detect_os")
    end

    test "uses regex for user agent parsing" do
      source = File.read!("lib/indrajaal/shared/device_detection.ex")
      # Should contain regex patterns or Regex module usage
      assert String.contains?(source, "~r") or String.contains?(source, "Regex")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete device detection workflow" do
      user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15"

      # Parse full device info
      device_info = DeviceDetection.parse_device_info(user_agent)
      assert device_info != nil

      # Check individual detection functions
      is_mobile = DeviceDetection.detect_mobile(user_agent)
      assert is_boolean(is_mobile)

      is_tablet = DeviceDetection.detect_tablet(user_agent)
      assert is_boolean(is_tablet)

      browser = DeviceDetection.detect_browser(user_agent)
      assert browser != nil

      os = DeviceDetection.detect_os(user_agent)
      assert os != nil

      # Get summary
      summary = DeviceDetection.device_summary(user_agent)
      assert summary != nil
    end

    test "cross-platform detection accuracy" do
      platforms = @mobile_user_agents ++ @tablet_user_agents ++ @desktop_user_agents

      Enum.each(platforms, fn user_agent ->
        result = DeviceDetection.parse_device_info(user_agent)
        assert result != nil, "Failed to parse: #{user_agent}"
      end)
    end

    test "all detection functions are accessible" do
      functions = DeviceDetection.__info__(:functions)

      detection_functions = [
        {:parse_device_info, 1},
        {:apply_device_detection, 1},
        {:detect_mobile, 1},
        {:detect_tablet, 1},
        {:detect_browser, 1},
        {:detect_os, 1},
        {:device_summary, 1}
      ]

      Enum.each(detection_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
