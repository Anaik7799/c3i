# Ensure apps loaded
Mix.start()
Application.ensure_all_started(:indrajaal)

alias Indrajaal.KMS.Todo

# Seed Tasks
tasks = [
  {"Stabilize Substrate", :p0, :l1},
  {"Enable Neural Plasticity", :p1, :l2},
  {"Activate Telepathy", :p1, :l3},
  {"Optimize Metabolism", :p2, :l4},
  {"Begin Dreaming", :p2, :l5},
  {"Unify Swarm", :p1, :l6},
  {"Establish Federation", :p0, :l7}
]

IO.puts("🌱 Seeding KMS Memory...")

for {title, priority, layer} <- tasks do
  id = String.downcase(String.replace(title, " ", "_"))
  Todo.create!(%{
    name: title,
    fqun: "kms/l5/task/default/#{title}##{id}",
    payload: %{
      status: "pending",
      priority: priority,
      layer: layer
    }
  })
end

IO.puts("✅ Memory Implanted.")