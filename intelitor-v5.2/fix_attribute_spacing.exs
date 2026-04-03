#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AttributeSpacingFixer do
  @moduledoc """
  Fix Phoenix template attribute spacing issues that cause 'key will be overridden in map' warnings.

  This script fixes patterns like:
  - "phx - click" -> "phx-click"
  - "class='mr - 1'" -> "class='mr-1'"
  - "hero - plus" -> "hero-plus"
  """

  def fix_file(file_path) do
    IO.puts("Fixing attribute spacing in: #{file_path}")

    content = File.read!(file_path)

    # Fix all spacing issues
    fixed_content =
      content
      |> fix_phx_attributes()
      |> fix_css_classes()
      |> fix_hero_icons()
      |> fix_id_attributes()
      |> fix_aria_attributes()
      |> fix_data_attributes()

    if content != fixed_content do
      File.write!(file_path, fixed_content)
      IO.puts("✅ Fixed spacing issues in #{file_path}")
    else
      IO.puts("✅ No spacing issues found in #{file_path}")
    end
  end

  defp fix_phx_attributes(content) do
    content
    # Fix phx-click and similar broken across lines
    |> String.replace(~r/phx\s*-\s*click/m, "phx-click")
    |> String.replace(~r/phx\s*-\s*value\s*-\s*id/m, "phx-value-id")
    |> String.replace(~r/phx\s*-\s*value\s*-\s*user\s*-\s*id/m, "phx-value-user-id")
    |> String.replace(~r/phx\s*-\s*value\s*-\s*role\s*-\s*id/m, "phx-value-role-id")
    |> String.replace(~r/phx\s*-\s*value\s*-\s*permission/m, "phx-value-permission")
    |> String.replace(~r/phx\s*-\s*value\s*-\s*flag/m, "phx-value-flag")
    |> String.replace(~r/phx\s*-\s*submit/m, "phx-submit")
    |> String.replace(~r/phx\s*-\s*keyup/m, "phx-keyup")
    |> String.replace(~r/phx\s*-\s*debounce/m, "phx-debounce")
    |> String.replace(~r/phx\s*-\s*hook/m, "phx-hook")
    # Fix any other phx- attributes
    |> String.replace(~r/phx\s*-\s*(\w+)/m, "phx-\\1")
  end

  defp fix_css_classes(content) do
    # Fix CSS classes with spacing using specific common patterns
    content
    |> String.replace("grid - cols", "grid-cols")
    |> String.replace("space - x", "space-x")
    |> String.replace("space - y", "space-y")
    |> String.replace("text - ", "text-")
    |> String.replace("bg - ", "bg-")
    |> String.replace("border - ", "border-")
    |> String.replace("rounded - ", "rounded-")
    |> String.replace("font - ", "font-")
    |> String.replace("flex - ", "flex-")
    |> String.replace("items - ", "items-")
    |> String.replace("justify - ", "justify-")
    |> String.replace("hover:bg - ", "hover:bg-")
    |> String.replace("col - span", "col-span")
    |> String.replace("gap - ", "gap-")
    |> String.replace("mt - ", "mt-")
    |> String.replace("mb - ", "mb-")
    |> String.replace("mr - ", "mr-")
    |> String.replace("ml - ", "ml-")
    |> String.replace("px - ", "px-")
    |> String.replace("py - ", "py-")
    |> String.replace("shadow - ", "shadow-")
    |> String.replace("w - ", "w-")
    |> String.replace("h - ", "h-")
    |> String.replace("min - w", "min-w")
    |> String.replace("max - w", "max-w")
    |> String.replace("min - h", "min-h")
    |> String.replace("max - h", "max-h")
    |> String.replace("top - ", "top-")
    |> String.replace("left - ", "left-")
    |> String.replace("right - ", "right-")
    |> String.replace("bottom - ", "bottom-")
    |> String.replace("p - ", "p-")
    |> String.replace("m - ", "m-")
    |> String.replace("lg:grid - cols", "lg:grid-cols")
    |> String.replace("md:grid - cols", "md:grid-cols")
    |> String.replace("sm:grid - cols", "sm:grid-cols")
  end

  defp fix_hero_icons(content) do
    content
    |> String.replace("hero - ", "hero-")
  end

  defp fix_id_attributes(content) do
    content
    |> String.replace(~r/id="([^"]*)\s+-\s+([^"]*)"/, "id=\"\\1-\\2\"")
  end

  defp fix_aria_attributes(content) do
    content
    |> String.replace(~r/aria\s*-\s*(\w+)/, "aria-\\1")
  end

  defp fix_data_attributes(content) do
    content
    |> String.replace(~r/data\s*-\s*(\w+)/, "data-\\1")
  end
end

# Get file paths to fix
files_to_fix = [
  "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal_web/live/permissions_management_live.ex",
  "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal_web/live/access_control_monitoring_live.ex",
  "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal_web/live/monitoring_dashboard_live.ex",
  "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex",
  "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
]

IO.puts("Phoenix Template Attribute Spacing Fixer")
IO.puts("========================================")
IO.puts("")

Enum.each(files_to_fix, &AttributeSpacingFixer.fix_file/1)

IO.puts("")
IO.puts("✅ All LiveView template attribute spacing issues fixed!")
