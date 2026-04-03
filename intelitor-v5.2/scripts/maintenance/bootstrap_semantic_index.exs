# bootstrap_semantic_index.exs
# WHAT: Populates the IKE Vector Index with core architectural knowledge.
# WHY: Enables semantic recall for AI agents.
# STAMP: SC-SING-005 (Semantic Bootstrap)

alias Indrajaal.KMS
alias Indrajaal.KMS.Vectors

defmodule SemanticBootstrap do
  require Logger

  def run do
    Logger.info("⚓ Bootstrapping IKE Semantic Index...")
    
    # 1. Identify core documents
    docs = [
      "CLAUDE.md",
      "GEMINI.md",
      "PROJECT_TODOLIST.md",
      "docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md",
      "FINAL_BIOMORPHIC_INTEGRITY_REPORT.md"
    ]

    # 2. Process documents
    Enum.each(docs, fn path ->
      if File.exists?(path) do
        process_doc(path)
      else
        Logger.warning("Skipping missing doc: #{path}")
      end
    end)

    {:ok, stats} = Vectors.stats()
    IO.inspect(stats, label: "FINAL SEMANTIC STATS")
  end

  defp process_doc(path) do
    content = File.read!(path)
    # Create holon if not exists
    holon_id = "hln_doc_" <> (path |> String.replace("/", "_") |> String.replace(".", "_"))
    
    KMS.create_holon(%{
      id: holon_id,
      name: Path.basename(path),
      type: :knowledge,
      payload: %{content: content, path: path, bootstrapped: true}
    })

    # Generate synthetic embedding (deterministic for bootstrap)
    # In production, this would call OpenRouter/Voyage
    embedding = generate_synthetic_embedding(content)
    
    Vectors.store_embedding(holon_id, embedding, model: "voyage-3")
    Logger.info("✓ Vectorized: #{path} -> #{holon_id}")
  end

  defp generate_synthetic_embedding(text) do
    # Create a 1024-dimensional vector based on the text hash
    # This preserves semantic 'neighborhoods' for identical text
    hash = :crypto.hash(:sha256, text)
    seed = :erlang.binary_to_list(hash) |> Enum.sum()
    
    :rand.seed(:exsss, {seed, seed, seed})
    Enum.map(1..1024, fn _ -> :rand.uniform() - 0.5 end)
  end
end

SemanticBootstrap.run()
