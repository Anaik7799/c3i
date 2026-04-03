defmodule Indrajaal.Observability.DualLoggingMock do
  @moduledoc """
  Test mock implementation for Indrajaal.Observability.DualLogging.

  Used with Mox.stub_with/2 to replace dual logging in isolated tests.
  All functions return :ok without side effects.
  """

  @spec validate_dual_logging!() :: :ok
  def validate_dual_logging!, do: :ok

  @spec configure_console_format(atom()) :: :ok
  def configure_console_format(_format \\ :detailed), do: :ok

  @spec log_domain_event(atom(), atom(), map(), atom()) :: :ok
  def log_domain_event(_domain, _event, _metadata \\ %{}, _level \\ :info), do: :ok

  @spec log_important(atom(), binary(), list()) :: :ok
  def log_important(_level, _message, _metadata \\ []), do: :ok
end
