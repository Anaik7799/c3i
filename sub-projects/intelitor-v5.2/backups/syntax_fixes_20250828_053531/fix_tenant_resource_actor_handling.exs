#!/usr/bin/env elixir

# SOPv5.1 Fix TenantResource to handle different actor types
# This fixes the root cause of SystemConfig test failures

defmodule FixTenantResourceActorHandling do
  @spec run() :: any()
  def run do
    IO.puts("🔧 Fixing TenantResource actor handling...")

    file = "lib/intelitor/multitenancy/tenant_resource.ex"

    if File.exists?(file) do
      content = File.read!(file)

      # Replace the change function to handle both map and struct actors
      updated_content = String.replace(content,
        """
      changes do
        change fn changeset, %{actor: actor} = _context ->
          if changeset.action.type == :create && actor do
            Ash.Changeset.force_change_attribute(changeset, :tenant_id, actor[:tenant_id])
          else
            changeset
          end
        end
      end""",
        """
      changes do
        change fn changeset, %{actor: actor} = _context ->
          if changeset.action.type == :create && actor do
            tenant_id = extract_tenant_id(actor)
            if tenant_id do
              Ash.Changeset.force_change_attribute(changeset, :tenant_id, tenant_id)
            else
              changeset
            end
          else
            changeset
          end
        end
      end

      # Helper function to extract tenant_id from different actor types
  @spec extract_tenant_id(map(), term()) :: term()
      defp extract_tenant_id(%{id: id, __struct__: Intelitor.Core.Tenant}), do: id
      defp extract_tenant_id(%{tenant_id: tenant_id}) when is_binary(tenant_id), do: tenant_id
      defp extract_tenant_id(actor) when is_map(actor), do: actor[:tenant_id]
  @spec extract_tenant_id(term()) :: term()
      defp extract_tenant_id(_), do: nil""")

      # Also fix the preparations block to handle different actor types
      updated_content = String.replace(updated_content,
        """
      preparations do
        prepare fn query, _context ->
          tenant_id = query.context[:actor][:tenant_id]

          if tenant_id do
            Ash.Query.filter(query, tenant_id: tenant_id)
          else
            query
          end
        end
      end""",
        """
      preparations do
        prepare fn query, _context ->
          actor = query.context[:actor]
          tenant_id = case actor do
            %{id: id, __struct__: Intelitor.Core.Tenant} -> id
            %{tenant_id: tenant_id} when is_binary(tenant_id) -> tenant_id
            actor when is_map(actor) -> actor[:tenant_id]
            _ -> nil
          end

          if tenant_id do
            Ash.Query.filter(query, tenant_id: tenant_id)
          else
            query
          end
        end
      end""")

      # Fix the validation to handle different actor types
      updated_content = String.replace(updated_content,
        """
      validations do
        validate attribute_equals(:tenant_id, {:actor, :tenant_id}) do
          message "Resources can only be created within the actor's tenant"
          on :create
        end
      end""",
        """
      validations do
        validate fn changeset ->
          actor = changeset.context[:actor]
          tenant_id = Ash.Changeset.get_attribute(changeset, :tenant_id)

          expected_tenant_id = case actor do
            %{id: id, __struct__: Intelitor.Core.Tenant} -> id
            %{tenant_id: tid} when is_binary(tid) -> tid
            actor when is_map(actor) -> actor[:tenant_id]
            _ -> nil
          end

          if expected_tenant_id && tenant_id != expected_tenant_id do
            {:error,
      field: :tenant_id, message: "Resources can only be created within the actor's tenant"}
          else
            :ok
          end
        end do
          on :create
        end
      end""")

      File.write!(file, updated_content)
      IO.puts("✓ Fixed TenantResource actor handling")
    end

    IO.puts("\n✅ TenantResource fix complete!")
  end
end

FixTenantResourceActorHandling.run()
end
end
end
end
end
