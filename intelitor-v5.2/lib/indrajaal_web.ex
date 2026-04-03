defmodule IndrajaalWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use IndrajaalWeb, :controller
      use IndrajaalWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  @spec static_paths() :: [String.t()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @spec router() :: any()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @spec channel() :: any()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @spec controller() :: any()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: IndrajaalWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: IndrajaalWeb.Gettext

      unquote(verified_routes())
    end
  end

  @spec live_view() :: any()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {IndrajaalWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @spec live_component() :: any()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @spec html() :: any()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for HTML generation
      unquote(html_helpers())
    end
  end

  @spec view() :: any()
  def view do
    quote do
      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Import Phoenix.View helpers for rendering
      import Phoenix.View

      use Gettext, backend: IndrajaalWeb.Gettext

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @spec html_helpers() :: any()
  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import IndrajaalWeb.CoreComponents
      # PRAJNA C3I Cockpit components
      import IndrajaalWeb.PrajnaComponents
      use Gettext, backend: IndrajaalWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @spec verified_routes() :: any()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: IndrajaalWeb.Endpoint,
        router: IndrajaalWeb.Router,
        statics: IndrajaalWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller / live_view / etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
