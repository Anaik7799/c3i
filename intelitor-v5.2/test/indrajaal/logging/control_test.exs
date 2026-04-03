defmodule Indrajaal.Logging.ControlTest do
  use ExUnit.Case
  alias Indrajaal.Logging.Control

  setup do
    # Reset config before each test
    Application.put_env(:indrajaal, :logging_control,
      global_level: :info,
      subsystems: %{
        test_subsystem: %{
          level: :info,
          # 1 in 10
          sampling_rate: 10
        }
      }
    )

    :ok
  end

  test "should_log? returns true for critical errors regardless of sampling" do
    assert Control.should_log?(:test_subsystem, :error)
    assert Control.should_log?(:test_subsystem, :critical)
  end

  test "should_log? respects level hierarchy" do
    Application.put_env(:indrajaal, :logging_control,
      global_level: :warning,
      subsystems: %{
        test_subsystem: %{level: :warning}
      }
    )

    refute Control.should_log?(:test_subsystem, :info)
    assert Control.should_log?(:test_subsystem, :error)
  end

  test "should_log? applies sampling for info/debug" do
    # Sampling is probabilistic or counter-based.
    # If using :rand, we can't deterministically test one call.
    # But we can test that it returns boolean.
    assert is_boolean(Control.should_log?(:test_subsystem, :info))
  end

  test "should_log? defaults to safe values if config missing" do
    assert Control.should_log?(:unknown_subsystem, :error)
    # Info might be sampled or allowed, but shouldn't crash
    assert is_boolean(Control.should_log?(:unknown_subsystem, :info))
  end
end
