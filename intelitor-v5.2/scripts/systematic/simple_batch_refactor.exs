#!/usr/bin/env elixir

defmodule SimpleBatchRefactor do
  @moduledoc """
  Simplified batch refactoring for domain __contexts using sed-based replacements.
  """

  @domains [
    "lib/indrajaal/accounts.ex",
    "lib/indrajaal/devices.ex",
    "lib/indrajaal/authentication.ex",
    "lib/indrajaal/communication.ex",
    "lib/indrajaal/compliance.ex"
  ]

  @spec main(term()) :: any()
  def main(_args \\ []) do
    IO.puts("🚀 Starting systematic batch domain refactoring...")
    IO.puts("🎯 Refactoring #{length(@domains)} domain __contexts")

    @domains
    |> Enum.each(&refactor_domain_simple/1)

    IO.puts("🏆 Batch refactoring completed!")
  end

  defp refactor_domain_simple(domain_file) do
    if File.exists?(domain_file) do
      IO.puts("📝 Refactoring: #{domain_file}")

      # Step 1: Update imports and aliases
      System.cmd("sed", [
        "-i",
        "s/import Ecto\\.Query/# import Ecto.Query - removed/g",
        domain_file
      ])

      System.cmd("sed", [
        "-i",
        "/alias Indrajaal\\.Repo/a\\  alias Indrajaal.Shared.{ContextHelpers, ValidationHelpers, ErrorHelpers}",
        domain_file
      ])

      IO.puts("✅ Updated #{domain_file}")
    else
      IO.puts("⚠️  File not found: #{domain_file}")
    end
  end
end

# Run the script
SimpleBatchRefactor.main(System.argv())
