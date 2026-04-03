defmodule Indrajaal.PropertyTestCase do
  @moduledoc """
  A test case module that centralizes the setup for dual property testing
  using both ExUnitProperties and PropCheck.

  This module handles macro import conflicts by explicitly excluding `property/2`
  and `check/2` from `ExUnitProperties` when `PropCheck` is used,
  and provides a unified `property/2` macro.
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: true

      # Always include PropCheck first, it has a more direct `property/2`
      use PropCheck

      # Include ExUnitProperties, but exclude conflicting macros
      # We rely on PropCheck's `property/2` for general property tests
      # If specific `ExUnitProperties.check` functionality is needed, it must
      # be explicitly called or aliased.
      import ExUnitProperties, except: [property: 2, property: 3, check: 2]

      # Import necessary helper for StreamData generation (if needed)
      import StreamData

      # Additional common imports or setup can go here
      # For example:
      # alias Indrajaal.Test.PropertyTestingUtils
      # import Indrajaal.Shared.TestSupport
    end
  end
end

defmodule Indrajaal.PropCheckHelpers do
  @moduledoc """
  Helper functions for PropCheck property testing.
  Provides missing generator combinators like fixed_map/1.
  """

  @doc """
  Generate a fixed-structure map where each value is a PropCheck generator.
  Similar to StreamData.fixed_map/1 but for PropCheck generators.

  ## Example

      fixed_map(%{
        name: PropCheck.BasicTypes.binary(),
        age: PropCheck.BasicTypes.integer(0, 120)
      })
  """
  def fixed_map(generator_map) when is_map(generator_map) do
    {keys, generators} = Enum.unzip(Map.to_list(generator_map))

    :proper_types.bind(
      PropCheck.BasicTypes.fixed_list(generators),
      fn values ->
        :proper_types.exactly(
          keys
          |> Enum.zip(values)
          |> Map.new()
        )
      end,
      false
    )
  end
end
