defmodule Indrajaal.Instrumentation.Base do
  @moduledoc """
  Base module for Indrajaal instrumentation modules.

  Provides a `__using__/1` macro that injects common instrumentation
  functions (`setup/0`, `attach_handlers/0`, `domain/0`, `otp_app/0`)
  into any module that `use`s it.

  ## WHAT
  Shared behaviour template for instrumentation modules across all domains.

  ## WHY
  Avoids boilerplate duplication and enforces a consistent interface
  across all instrumentation modules.

  ## CONSTRAINTS
  - SC-DOC-001: moduledoc required
  - SC-AGT-CODE-025: 0 compiler warnings
  """

  @doc """
  When used, injects default instrumentation callbacks into the caller.

  ## Options
  - `:domain` – atom identifying the instrumentation domain (default: `:default`)
  - `:otp_app` – OTP application atom (default: `:indrajaal`)
  """
  defmacro __using__(opts \\ []) do
    domain = Keyword.get(opts, :domain, :default)
    otp_app = Keyword.get(opts, :otp_app, :indrajaal)

    quote do
      @doc "Returns the instrumentation domain for this module."
      @spec domain() :: atom()
      def domain, do: unquote(domain)

      @doc "Returns the OTP application for this instrumentation module."
      @spec otp_app() :: atom()
      def otp_app, do: unquote(otp_app)

      @doc "Sets up instrumentation for this module. Returns :ok."
      @spec setup() :: :ok
      def setup do
        attach_handlers()
        :ok
      end

      @doc "Attaches telemetry handlers for this module. Returns :ok."
      @spec attach_handlers() :: :ok
      def attach_handlers, do: :ok

      defoverridable domain: 0, otp_app: 0, setup: 0, attach_handlers: 0
    end
  end
end
