#!/usr/bin/env elixir
require Ash.Query

tenant = Indrajaal.Factory.insert(:tenant)
IO.puts("Tenant ID: #{tenant.id}")

users = Indrajaal.AccountsComprehensiveFactory.bulk_create_users(tenant, 2)
user = List.first(users)
IO.puts("User tenant_id: #{user.tenant_id}")

sessions = Indrajaal.AccountsComprehensiveFactory.bulk_create_sessions(users, 3)
session = List.first(sessions)
IO.puts("Session tenant_id: #{session.tenant_id}")

# Check all sessions
all_sessions = Ash.read!(Indrajaal.Accounts.Session, actor: %{is_system: true}, authorize?: false)
IO.puts("\nAll sessions in DB (authorize?: false): #{length(all_sessions)}")

# Now test different query approaches
IO.puts("\n=== Testing query approaches ===")

# 1. Direct Ash.read! with filter and authorize?: false
query1 = Ash.Query.new(Indrajaal.Accounts.Session) |> Ash.Query.filter(tenant_id: tenant.id)
result1 = Ash.read!(query1, actor: %{is_system: true}, authorize?: false)
IO.puts("1. Ash.read! with filter, authorize?: false: #{length(result1)} sessions")

# 2. Direct Ash.read! with filter and authorize?: true
system_actor = %{is_system: true, tenant_id: tenant.id}
result2 = Ash.read!(query1, actor: system_actor, authorize?: true)
IO.puts("2. Ash.read! with filter, authorize?: true: #{length(result2)} sessions")

# 3. With :tenant option
result3 = Ash.read!(query1, actor: system_actor, tenant: tenant.id, authorize?: true)
IO.puts("3. Ash.read! with filter + tenant option: #{length(result3)} sessions")

# 4. Without explicit filter (let TenantResource do it)
query4 = Ash.Query.new(Indrajaal.Accounts.Session)
result4 = Ash.read!(query4, actor: system_actor, tenant: tenant.id, authorize?: true)
IO.puts("4. Ash.read! no filter, just tenant option: #{length(result4)} sessions")

# 5. Check if list_sessions! is getting the right parameters
IO.puts("\n=== Testing list_sessions! ===")
result5 = Indrajaal.Accounts.list_sessions!(tenant_id: tenant.id)
IO.puts("5. list_sessions!(tenant_id: tenant.id): #{length(result5)} sessions")
