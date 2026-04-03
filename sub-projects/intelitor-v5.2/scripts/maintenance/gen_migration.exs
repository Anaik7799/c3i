Mix.start()
Application.ensure_all_started(:indrajaal)

IO.puts("🚀 Generating Migration for Todos DB...")
Mix.Task.run("ash.codegen", ["create_todos_table"])
IO.puts("✅ Migration Generated.")
