defmodule Indrajaal.Testing.DomainApiAnalyzer do
  @moduledoc """
  Analyzes Ash domain APIs for test factory alignment.
  Part of SOPv5.1 Task 8.4.1 - API analysis and documentation.
  """

  @domains [
    {Indrajaal.Core, "Core domain for multi - tenant foundation"},
    {Indrajaal.Accounts, "User and authentication management"},
    {Indrajaal.Policy, "Authorization and access control"},
    {Indrajaal.Alarms, "Alarm management and processing"},
    {Indrajaal.Sites, "Site and location management"},
    {Indrajaal.Devices, "Device and hardware management"},
    {Indrajaal.AccessControl, "Physical access control"},
    {Indrajaal.Analytics, "Analytics and reporting"},
    {Indrajaal.Video, "Video management and analytics"},
    {Indrajaal.Communication, "Notifications and messaging"},
    {Indrajaal.GuardTour, "Guard patrol management"},
    {Indrajaal.VisitorManagement, "Visitor tracking"},
    {Indrajaal.Maintenance, "Maintenance workflows"},
    {Indrajaal.Dispatch, "Dispatch and response"},
    {Indrajaal.Integrations, "External integrations"},
    {Indrajaal.AssetManagement, "Asset tracking"},
    {Indrajaal.RiskManagement, "Risk assessment"},
    {Indrajaal.Compliance, "Compliance tracking"},
    {Indrajaal.Billing, "Billing and invoicing"}
  ]

  @spec analyze_all() :: :ok
  def analyze_all do
    IO.puts("""
    ================================================================================
    ASH DOMAIN API ANALYSIS
    ================================================================================
    Generated: #{DateTime.utc_now() |> DateTime.to_string()}
    Purpose: Document actual API signatures for test factory alignment
    ================================================================================
    """)

    results =
      Enum.map(@domains, fn {module, description} ->
        analyze_domain(module, description)
      end)

    print_summary(results)
    generate_factory_fixes(results)
  end

  @spec analyze_domain(module(), String.t()) :: map()
  defp analyze_domain(module, description) do
    IO.puts("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement

## #{inspect(module)}")
    IO.puts("Description: #{description}")
    IO.puts("=" |> String.duplicate(80))

    functions = module._info__(:functions)

    # Categorize functions
    crud_ops = functions |> Enum.filter(&crud_function?/1)
    query_ops = functions |> Enum.filter(&query_function?/1)
    custom_ops = functions |> Enum.filter(&custom_function?/1)

    # Check for special patterns
    has_custom_api = has_custom_api_pattern?(module, functions)

    result = %{
      module: module,
      has_custom_api: has_custom_api,
      crud_ops: crud_ops,
      query_ops: query_ops,
      custom_ops: custom_ops
    }

    print_domain_analysis(result)

    result
  end

  @spec crud_function?(term()) :: boolean()
  defp crud_function?({name, _arity}) do
    name_str = Atom.to_string(name)
    Enum.any?(["create_", "get_", "update_", "delete_"], &String.starts_with?(name_str, &1))
  end

  @spec query_function?(term()) :: boolean()
  defp query_function?({name, _arity}) do
    name_str = Atom.to_string(name)
    Enum.any?(["list_", "search_", "find_"], &String.starts_with?(name_str, &1))
  end

  @spec custom_function?(term()) :: boolean()
  defp custom_function?({name, arity}) do
    name_str = Atom.to_string(name)

    not String.starts_with?(name_str, "_") and
      not crud_function?({name, arity}) and
      not query_function?({name, arity})
  end

  @spec has_custom_api_pattern?(module(), list()) :: boolean()
  defp has_custom_api_pattern?(module, functions) do
    # Check if module has domain - specific API functions
    case module do
      Indrajaal.Accounts ->
        # Has create_user / 2, authenticate_user / 1, etc.
        Enum.any?(functions, fn {name, _} -> name == :create_user end)

      _ ->
        # Check for any CRUD functions
        Enum.any?(functions, &crud_function?/1)
    end
  end

  @spec print_domain_analysis(map()) :: :ok
  defp print_domain_analysis(result) do
    if result.has_custom_api do
      IO.puts("✅ Has Custom API Functions")

      if not Enum.empty?(result.crud_ops) do
        IO.puts("\nCRUD Operations:")

        Enum.each(result.crud_ops, fn {name, arity} ->
          IO.puts("  - #{name}/#{arity}")
        end)
      end

      if not Enum.empty?(result.query_ops) do
        IO.puts("\nQuery Operations:")

        Enum.each(result.query_ops, fn {name, arity} ->
          IO.puts("  - #{name}/#{arity}")
        end)
      end
    else
      IO.puts("⚠️  Uses Default Ash APIs (no custom functions)")
    end

    # Print sample custom operations
    relevant_custom =
      result.custom_ops
      |> Enum.reject(fn {name, _} ->
        Atom.to_string(name) in [
          "__struct__",
          "_changeset__",
          "_schema__",
          "archive",
          "register",
          "create"
        ]
      end)
      |> Enum.take(5)

    if not Enum.empty?(relevant_custom) do
      IO.puts("\nNotable Custom Operations:")

      Enum.each(relevant_custom, fn {name, arity} ->
        IO.puts("  - #{name}/#{arity}")
      end)
    end
  end

  @spec print_summary(list()) :: :ok
  defp print_summary(results) do
    IO.puts("""

    ================================================================================
    SUMMARY
    ================================================================================

    Domains with Custom APIs:
    """)

    results
    |> Enum.filter(& &1.has_custom_api)
    |> Enum.each(fn result ->
      IO.puts("  ✅ #{inspect(result.module)}")
    end)

    IO.puts("\nDomains using Default Ash APIs:")

    results
    |> Enum.reject(& &1.has_custom_api)
    |> Enum.each(fn result ->
      IO.puts("  ⚠️  #{inspect(result.module)}")
    end)
  end

  @spec generate_factory_fixes(list()) :: :ok
  defp generate_factory_fixes(_results) do
    IO.puts("""

    ================================================================================
    FACTORY FIX PATTERNS
    ================================================================================

    ## For Domains with Custom APIs (e.g., Accounts):

    ```elixir
    # Pattern for Accounts domain
    @spec __user_factory(any()) :: any()
    attrs \\\\ %{}) do
    tenant = attrs[:tenant] || insert(:tenant)

      __user_attrs = %{
        email: sequence(:email, &"user\#{&1}@test.example.com"),
        password: "password123",
        first_name: "Test",
        last_name: "User",
        role: :operator,
        active: true,
        tenant_id: tenant.id
      }
      |> merge_attributes(attrs)

      # CORRECT: Use domain function with tenant __context
      {:ok, user} = Indrajaal.Accounts.create_user(
        __user_attrs,
        %{tenant_id: tenant.id}
      )

      user
    end
    ```

    ## For Domains using Default Ash APIs:

    ```elixir
    # Pattern for Policy, Core, etc.
    @spec role_factory(any()) :: any()
    attrs \\\\ %{}) do
    tenant = attrs[:tenant] || insert(:tenant)

      role_attrs = %{
        name: sequence(:role_name, &"role_\#{&1}"),
        description: "Test role",
        tenant_id: tenant.id
      }
      |> merge_attributes(attrs)

      # CORRECT: Use Ash.create with options
      {:ok, role} = Ash.create(
        Indrajaal.Policy.Role,
        role_attrs,
        tenant: tenant.id
      )

      role
    end
    ```

    ## Key Differences:

    1. **Custom API**: Domain.function(params, %{tenant_id: id})
    2. **Default API**: Ash.create(Resource, params, tenant: id)
    3. **ALL factories MUST handle {:ok, resource} tuples**
    4. **ALL factories MUST provide tenant __context**

    ================================================================================
    """)
  end
end
