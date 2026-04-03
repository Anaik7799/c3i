defmodule IndrajaalWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext - based API.

  By using [Gettext](https://hexdocs.pm / gettext),
  your module gains a set of macros for translations, for example:

      import IndrajaalWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain - based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm / gettext) for detailed usage.
  """
  use Gettext.Backend, otp_app: :indrajaal
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
