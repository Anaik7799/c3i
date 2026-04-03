# Indrajaal.Observability.OTLPExporter

API module for Indrajaal.Observability.OTLPExporter

## Module Information

- **Module**: `Indrajaal.Observability.OTLPExporter`
- **Behaviors**: [GenServer]
- **Functions**: 0 exported functions
- **Generated**: 2026-03-20 08:11:02.263301Z

## Overview

This module provides comprehensive API functionality for observability operations.
All functions include proper error handling, type specifications, and usage examples.


## Functions




## Types

### Common Types

```elixir
@type config() :: map()
@type result() :: {:ok, term()} | {:error, atom()}
@type timeout_ms() :: non_neg_integer()
```

### Module-Specific Types

```elixir
@type dashboard_config() :: %{
  title: String.t(),
  panels: list(atom()),
  metrics: list(String.t())
}

@type generation_result() :: %{
  file_path: String.t(),
  word_count: integer(),
  sections_count: integer()
}
```


## Callbacks

### GenServer Callbacks

This module implements the GenServer behavior with the following callbacks:

#### `init/1`
```elixir
@callback init(term()) :: {:ok, state()} | {:stop, reason()}
```

#### `handle_call/3`
```elixir
@callback handle_call(_request(), from(), state()) ::
  {:reply, reply(), new_state()} | {:stop, reason(), reply(), new_state()}
```


## Usage Examples

### Basic Usage

```elixir
# Start the process
{:ok, pid} = Indrajaal.Observability.OTLPExporter.start_link([])

# Basic operation example
{:ok, result} = Indrajaal.Observability.OTLPExporter.basic_operation(%{
  param1: "value1",
  param2: "value2"
})

IO.inspect(result)
```

### Advanced Usage

```elixir
# Advanced configuration example
config = %{
  advanced_option: true,
  timeout: 30_000,
  retry_attempts: 3
}

case Indrajaal.Observability.OTLPExporter.advanced_operation(config) do
  {:ok, __data} ->
    Logger.info("Operation successful: #{inspect(data)}")
  {:error, reason} ->
    Logger.error("Operation failed: #{reason}")
end
```

### Integration Example

```elixir
# Integration with other observability components
defmodule MyApp.Integration do
  alias Indrajaal.Observability.OTLPExporter

  def setup_observability do
    config = build_config()

    with {:ok, pid} <- Indrajaal.Observability.OTLPExporter.start_link(config),
         {:ok, result} <- Indrajaal.Observability.OTLPExporter.configure(config) do
      Logger.info("Observability setup complete")
      {:ok, result}
    else
      error ->
        Logger.error("Setup failed: #{inspect(error)}")
        error
    end
  end

  defp build_config do
    %{
      service_name: "my_app",
      environment: "production",
      telemetry_enabled: true
    }
  end
end
```
