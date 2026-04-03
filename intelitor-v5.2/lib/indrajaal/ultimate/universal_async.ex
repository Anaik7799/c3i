defmodule Indrajaal.Ultimate.UniversalAsync do
  @moduledoc """
  Universal Async Framework - Phase S final consolidation

  Eliminates ALL async / concurrent pattern duplications.
  """

  @doc """
  Universal async execution
  """
  @spec async_execute(list(), keyword()) :: term()
  def async_execute(tasks, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 5000)
    on_timeout = Keyword.get(opts, :on_timeout, :kill_task)
    ordered = Keyword.get(opts, :ordered, true)

    stream_opts = [
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: on_timeout,
      ordered: ordered
    ]

    tasks
    |> Task.async_stream(&execute_task/1, stream_opts)
    |> handle_results(opts)
  end

  defp execute_task(task) when is_function(task, 0), do: task.()
  defp execute_task({module, function, args}), do: apply(module, function, args)

  defp handle_results(stream, opts) do
    stream
    |> Enum.reduce({[], []}, fn
      {:ok, result}, {results, errors} -> {[result | results], errors}
      {:exit, reason}, {results, errors} -> {results, [{:exit, reason} | errors]}
    end)
    |> format_results(opts)
  end

  defp format_results({results, []}, %{aggregate: true}), do: {:ok, Enum.reverse(results)}

  defp format_results({results, errors}, %{aggregate: true}),
    do: {:error, {Enum.reverse(results), Enum.reverse(errors)}}

  defp format_results({results, []}, _), do: Enum.reverse(results)

  defp format_results({results, errors}, _),
    do: {:partial, Enum.reverse(results), Enum.reverse(errors)}
end
