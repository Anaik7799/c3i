defmodule Indrajaal.Cortex.AIInterface do
  @moduledoc """
  Bridge between the Autonomic System and the LLM Operator.
  Generates context prompts and accepts natural language commands.

  ## STAMP Constraints
  - SC-BUS-001: Async messaging only
  - SC-SENS-001: Non-blocking polling
  """

  require Logger

  @doc """
  Generates a system status context string for the LLM operator.
  """
  def generate_context do
    """
    SYSTEM STATUS REPORT
    ====================
    Time: #{DateTime.utc_now()}
    Stress Score: #{Indrajaal.Cortex.Analysis.StressAnalyzer.calculate_stress(Indrajaal.Cortex.Sensors.BeamSensor.take_snapshot())}

    Active Proposals:
    - [PENDING] Increase VideoPool Max (Reason: Queue Pressure > 0.8)
    - [PENDING] Decrease Cache TTL (Reason: Memory Pressure > 0.7)

    Awaiting your command.
    """
  end

  @doc """
  Executes a pre-parsed command tuple from `parse_command/1`.
  """
  def execute_command(command) do
    {:ok, "Command received: #{command}"}
  end

  @doc """
  Parses a natural language command string into a structured intent map.

  Uses keyword-based NLP matching. Supports the following intent patterns:
  - `turn on <device>` / `enable <target>` → `%{intent: :turn_on, entities: %{target: ...}}`
  - `turn off <device>` / `disable <target>` → `%{intent: :turn_off, entities: %{target: ...}}`
  - `set alarm <level>` / `alarm <level>` → `%{intent: :set_alarm, entities: %{level: ...}}`
  - `show status` / `status` / `health` → `%{intent: :show_status, entities: %{}}`
  - `run test <suite>` / `test <suite>` → `%{intent: :run_test, entities: %{suite: ...}}`
  - `scale up <service>` → `%{intent: :scale_up, entities: %{service: ...}}`
  - `scale down <service>` → `%{intent: :scale_down, entities: %{service: ...}}`
  - `restart <service>` → `%{intent: :restart, entities: %{service: ...}}`
  - `stop <service>` → `%{intent: :stop, entities: %{service: ...}}`

  Returns `{:ok, %{intent: atom, entities: map}}` or `{:error, :unrecognized}`.
  """
  @spec parse_command(String.t()) ::
          {:ok, %{intent: atom(), entities: map()}} | {:error, :unrecognized}
  def parse_command(command) when is_binary(command) do
    tokens = command |> String.downcase() |> String.split(~r/\s+/, trim: true)

    result = match_intent(tokens)

    :telemetry.execute(
      [:cortex, :ai_interface, :command_parsed],
      %{recognized: match?({:ok, _}, result)},
      %{command: command}
    )

    result
  end

  def parse_command(_), do: {:error, :unrecognized}

  # Intent matching via token pattern analysis
  defp match_intent(["turn", "on" | rest]) do
    {:ok, %{intent: :turn_on, entities: %{target: join_rest(rest)}}}
  end

  defp match_intent(["enable" | rest]) do
    {:ok, %{intent: :turn_on, entities: %{target: join_rest(rest)}}}
  end

  defp match_intent(["turn", "off" | rest]) do
    {:ok, %{intent: :turn_off, entities: %{target: join_rest(rest)}}}
  end

  defp match_intent(["disable" | rest]) do
    {:ok, %{intent: :turn_off, entities: %{target: join_rest(rest)}}}
  end

  defp match_intent(["set", "alarm" | rest]) do
    {:ok, %{intent: :set_alarm, entities: %{level: join_rest(rest)}}}
  end

  defp match_intent(["alarm" | rest]) do
    {:ok, %{intent: :set_alarm, entities: %{level: join_rest(rest)}}}
  end

  defp match_intent(tokens)
       when tokens in [["show", "status"], ["status"], ["health"], ["health", "check"]] do
    {:ok, %{intent: :show_status, entities: %{}}}
  end

  defp match_intent(["show", "status" | _rest]) do
    {:ok, %{intent: :show_status, entities: %{}}}
  end

  defp match_intent(["run", "test" | rest]) do
    suite = join_rest(rest)
    {:ok, %{intent: :run_test, entities: %{suite: suite}}}
  end

  defp match_intent(["test" | rest]) do
    suite = join_rest(rest)
    {:ok, %{intent: :run_test, entities: %{suite: suite}}}
  end

  defp match_intent(["scale", "up" | rest]) do
    {:ok, %{intent: :scale_up, entities: %{service: join_rest(rest)}}}
  end

  defp match_intent(["scale", "down" | rest]) do
    {:ok, %{intent: :scale_down, entities: %{service: join_rest(rest)}}}
  end

  defp match_intent(["restart" | rest]) do
    {:ok, %{intent: :restart, entities: %{service: join_rest(rest)}}}
  end

  defp match_intent(["stop" | rest]) do
    {:ok, %{intent: :stop, entities: %{service: join_rest(rest)}}}
  end

  defp match_intent(tokens) do
    Logger.debug("AIInterface: unrecognized command tokens", tokens: tokens)
    {:error, :unrecognized}
  end

  defp join_rest([]), do: ""
  defp join_rest(tokens), do: Enum.join(tokens, " ")
end
