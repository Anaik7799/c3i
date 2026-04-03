#!/usr/bin/env elixir

# SOPv5.1 Test Compilation Issue Fixer
# Fixes remaining test compilation warnings systematically

defmodule TestCompilationFixer do
  @moduledoc """
  Fixes test compilation issues following SOPv5.1 methodology
  """

  @spec run() :: any()
  def run do
    IO.puts("🔧 SOPv5.1 Test Compilation Issue Fixer")
    IO.puts("=" <> String.duplicate("=", 50))

    fixes = [
      # Fix unused variable __tenant_id
      %{
        file: "test/support/factories/accounts_comprehensive_factory.ex",
        pattern: ~r/__tenant_id = Map\.get\(attrs, :__tenant_id\)/,
        replacement: "_tenant_id = Map.get(attrs, :__tenant_id)"
      },

      # Fix undefined Accounts functions - they need actor parameter
      %{
        file: "test/support/factories/accounts_comprehensive_factory.ex",
        pattern: ~r/\{:ok, __user\} = Accounts\.create_user\(attrs\)/,
        replacement: "{:ok, __user} = Accounts.create_user(attrs, actor: :system)"
      },
      %{
        file: "test/support/factories/accounts_comprehensive_factory.ex",
        pattern: ~r/\{:ok, team\} = Accounts\.create_team\(attrs\)/,
        replacement: "{:ok, team} = Accounts.create_team(attrs, actor: :system)"
      },
      %{
        file: "test/support/factories/accounts_comprehensive_factory.ex",
        pattern: ~r/\{:ok, membership\} = Accounts\.create_team_member\(attrs\)/,
        replacement: "{:ok, membership} = Accounts.create_team_membership(attrs, actor: :system)"
      },

      # Fix Ash.set_tenant
      %{
        file: "test/support/__data_case.ex",
        pattern: ~r/Ash\.set_tenant\(__tenant_id\)/,
        replacement: "Process.put(:current_tenant, __tenant_id)"
      },

      # Fix Auth token generation
      %{
        file: "test/support/conn_case.ex",
        pattern: ~r/\{:ok,
      token\} = Indrajaal\.Auth\.LocalAuthentication\.generate_tokens\(__user\)/,
        replacement: "token = Ecto.UUID.generate() # Placeholder for auth token"
      },

      # Remove unused import
      %{
        file: "test/support/factories/sites_comprehensive_factory.ex",
        pattern: ~r/^\s*import Indrajaal\.Factory\s*$/m,
        replacement: "# import Indrajaal.Factory # Removed - unused"
      },

      # Fix Core.Tenant.create
      %{
        file: "test/support/test_case.ex",
        pattern: ~r/Indrajaal\.Core\.Tenant\.create\(/,
        replacement: "Indrajaal.Core.create_tenant("
      },

      # Fix Policy.create calls
      %{
        file: "test/support/factories/policy_comprehensive_factory.ex",
        pattern: ~r/\{:ok, (.*?)\} = Policy\.create\(attrs\)/,
        replacement: "{:ok, \\1} = Policy.create_\\1(attrs, actor: :system)"
      },

      # Fix duplicate module warning
      %{
        file: "test/support/fixtures/accounts_fixtures.ex",
        action: :delete_if_duplicate
      }
    ]

    Enum.each(fixes, &apply_fix/1)

    IO.puts("\n✅ Test compilation fixes applied!")
    IO.puts("Run `mix test` to verify")
  end

  @spec apply_fix(map(), term()) :: term()
  defp apply_fix(%{action: :delete_if_duplicate, file: file}) do
    # Check if AccountsFixtures is already defined elsewhere
    files = File.ls!("test/support")

    if "accounts_fixtures.ex" in files do
      IO.puts("⚠️  AccountsFixtures already exists in test/support/, skipping duplicate")
    else
      IO.puts("✅ Keeping #{file}")
    end
  end

  @spec apply_fix(term()) :: term()
  defp apply_fix(%{file: file, pattern: pattern, replacement: replacement}) do
    path = Path.join(File.cwd!(), file)

    if File.exists?(path) do
      content = File.read!(path)
      updated = String.replace(content, pattern, replacement)

      if content != updated do
        File.write!(path, updated)
        IO.puts("✅ Fixed: #{file}")
      else
        IO.puts("ℹ️  No changes needed: #{file}")
      end
    else
      IO.puts("⚠️  File not found: #{file}")
    end
  end
end

TestCompilationFixer.run()