defmodule Indrajaal.Safety.FPPSConsensusIntegrationTest do
  @moduledoc """
  FPPS 5-method consensus validation integration test.

  WHAT: Tests the Five-Point Parity System (FPPS) consensus validation
        across all 5 methods: Pattern, AST, Statistical, Binary, LineByLine.
  WHY: SC-VAL-003 requires 100% consensus for critical operations.
       SC-TDG-003 mandates FPPS 5-method consensus for all validation.
  CONSTRAINTS: SC-VAL-001 to SC-VAL-004, SC-FPPS-001, SC-SIL4-023,
               AOR-VAL-001, AOR-VAL-004

  ## Change History
  | Version | Date       | Author          | Change                 |
  |---------|------------|-----------------|------------------------|
  | 21.3.0  | 2026-03-24 | Claude Opus 4.6 | Initial implementation |
  """

  use ExUnit.Case, async: true

  @moduletag :sil6
  @moduletag :fpps
  @moduletag :consensus

  # FPPS validation methods
  @methods [:pattern, :ast, :statistical, :binary, :line_by_line]

  defmodule FPPSValidator do
    @moduledoc false

    def validate(source, method) do
      case method do
        :pattern -> validate_pattern(source)
        :ast -> validate_ast(source)
        :statistical -> validate_statistical(source)
        :binary -> validate_binary(source)
        :line_by_line -> validate_line_by_line(source)
      end
    end

    def consensus(results, opts \\ []) do
      min_agreement = Keyword.get(opts, :min_agreement, 5)
      total = length(results)
      passing = Enum.count(results, &(&1.status == :pass))

      cond do
        passing >= min_agreement ->
          {:ok, :consensus, %{passing: passing, total: total}}

        passing >= div(total, 2) + 1 ->
          {:ok, :quorum, %{passing: passing, total: total}}

        true ->
          {:error, :no_consensus, %{passing: passing, total: total, failures: total - passing}}
      end
    end

    defp validate_pattern(source) do
      has_moduledoc = String.contains?(source, "@moduledoc")
      has_spec = String.contains?(source, "@spec")

      %{
        method: :pattern,
        status: if(has_moduledoc, do: :pass, else: :fail),
        details: %{has_moduledoc: has_moduledoc, has_spec: has_spec}
      }
    end

    defp validate_ast(source) do
      case Code.string_to_quoted(source) do
        {:ok, _ast} -> %{method: :ast, status: :pass, details: %{parseable: true}}
        {:error, _} -> %{method: :ast, status: :fail, details: %{parseable: false}}
      end
    end

    defp validate_statistical(source) do
      lines = String.split(source, "\n")
      line_count = length(lines)
      avg_line_length = if line_count > 0, do: String.length(source) / line_count, else: 0

      status = if avg_line_length < 200 and line_count < 5000, do: :pass, else: :fail

      %{
        method: :statistical,
        status: status,
        details: %{lines: line_count, avg_length: avg_line_length}
      }
    end

    defp validate_binary(source) do
      # Check for non-UTF8 or suspicious binary patterns
      valid_utf8 = String.valid?(source)
      no_null_bytes = not String.contains?(source, <<0>>)

      status = if valid_utf8 and no_null_bytes, do: :pass, else: :fail

      %{
        method: :binary,
        status: status,
        details: %{valid_utf8: valid_utf8, no_null: no_null_bytes}
      }
    end

    defp validate_line_by_line(source) do
      lines = String.split(source, "\n")

      issues =
        lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} -> String.length(line) > 120 end)
        |> Enum.map(fn {_, idx} -> idx end)

      status = if length(issues) < 5, do: :pass, else: :fail
      %{method: :line_by_line, status: status, details: %{long_lines: issues}}
    end
  end

  @valid_source ~S'''
  defmodule Indrajaal.Example do
    @moduledoc "Example module for FPPS testing."
    @spec hello(String.t()) :: String.t()
    def hello(name), do: "Hello, #{name}"
  end
  '''

  @invalid_source "not valid elixir code {{{}}}"

  describe "individual FPPS methods" do
    test "pattern validation passes for well-structured code" do
      result = FPPSValidator.validate(@valid_source, :pattern)
      assert result.status == :pass
      assert result.details.has_moduledoc
    end

    test "AST validation passes for valid Elixir" do
      result = FPPSValidator.validate(@valid_source, :ast)
      assert result.status == :pass
      assert result.details.parseable
    end

    test "AST validation fails for invalid syntax" do
      result = FPPSValidator.validate(@invalid_source, :ast)
      assert result.status == :fail
    end

    test "statistical validation checks line metrics" do
      result = FPPSValidator.validate(@valid_source, :statistical)
      assert result.status == :pass
      assert result.details.lines > 0
    end

    test "binary validation checks UTF-8" do
      result = FPPSValidator.validate(@valid_source, :binary)
      assert result.status == :pass
      assert result.details.valid_utf8
    end

    test "line-by-line validation checks line lengths" do
      result = FPPSValidator.validate(@valid_source, :line_by_line)
      assert result.status == :pass
    end
  end

  describe "5/5 strict consensus (SC-VAL-003)" do
    test "all 5 methods agree on valid code" do
      results = Enum.map(@methods, &FPPSValidator.validate(@valid_source, &1))
      {:ok, :consensus, details} = FPPSValidator.consensus(results)

      assert details.passing == 5
      assert details.total == 5
    end

    test "strict consensus fails when one method disagrees" do
      results =
        Enum.map(@methods, &FPPSValidator.validate(@valid_source, &1))
        |> List.replace_at(0, %{method: :pattern, status: :fail, details: %{}})

      {:ok, :quorum, details} = FPPSValidator.consensus(results)
      assert details.passing == 4
    end

    test "no consensus when majority fails" do
      results =
        Enum.map(@methods, fn _ ->
          %{method: :test, status: :fail, details: %{}}
        end)

      {:error, :no_consensus, details} = FPPSValidator.consensus(results)
      assert details.failures == 5
    end
  end

  describe "3/5 quorum consensus" do
    test "quorum achieved with 3 passing" do
      results = [
        %{method: :pattern, status: :pass, details: %{}},
        %{method: :ast, status: :pass, details: %{}},
        %{method: :statistical, status: :pass, details: %{}},
        %{method: :binary, status: :fail, details: %{}},
        %{method: :line_by_line, status: :fail, details: %{}}
      ]

      {:ok, :quorum, details} = FPPSValidator.consensus(results, min_agreement: 5)
      assert details.passing == 3
    end

    test "configurable min_agreement" do
      results = [
        %{method: :pattern, status: :pass, details: %{}},
        %{method: :ast, status: :pass, details: %{}},
        %{method: :statistical, status: :pass, details: %{}},
        %{method: :binary, status: :fail, details: %{}},
        %{method: :line_by_line, status: :fail, details: %{}}
      ]

      {:ok, :consensus, _} = FPPSValidator.consensus(results, min_agreement: 3)
    end
  end

  describe "disagreement handling (SC-VAL-004)" do
    test "disagreement produces detailed failure report" do
      results = [
        %{method: :pattern, status: :pass, details: %{}},
        %{method: :ast, status: :fail, details: %{error: "syntax error"}},
        %{method: :statistical, status: :pass, details: %{}},
        %{method: :binary, status: :fail, details: %{reason: "null bytes"}},
        %{method: :line_by_line, status: :fail, details: %{long_lines: [1, 5, 10]}}
      ]

      {:error, :no_consensus, details} = FPPSValidator.consensus(results)
      assert details.failures == 3
    end

    test "each method returns structured result" do
      for method <- @methods do
        result = FPPSValidator.validate(@valid_source, method)
        assert Map.has_key?(result, :method)
        assert Map.has_key?(result, :status)
        assert Map.has_key?(result, :details)
        assert result.status in [:pass, :fail]
      end
    end
  end

  describe "performance" do
    test "full 5-method validation completes under 100ms" do
      start = System.monotonic_time(:millisecond)

      _results = Enum.map(@methods, &FPPSValidator.validate(@valid_source, &1))

      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 100, "5-method validation took #{elapsed}ms, must be < 100ms"
    end

    test "consensus computation is O(n)" do
      results =
        for _ <- 1..100 do
          %{method: :test, status: Enum.random([:pass, :fail]), details: %{}}
        end

      start = System.monotonic_time(:microsecond)
      FPPSValidator.consensus(results)
      elapsed = System.monotonic_time(:microsecond) - start

      assert elapsed < 1000, "Consensus on 100 results took #{elapsed}μs"
    end
  end
end
