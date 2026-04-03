/// Lustre component for Smriti Knowledge plane (SC-GLM-UI-001).
/// Tracks catalog entries, embeddings, search queries, and similarity.
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009
pub type SmritiModel {
  SmritiModel(
    catalog_entries: Int,
    embeddings_stored: Int,
    search_queries: Int,
    avg_similarity: Float,
  )
}

pub type SmritiMsg {
  EntryIngested
  SearchPerformed(Float)
  EmbeddingStored
  RefreshSmriti
}

pub fn init() -> SmritiModel {
  SmritiModel(
    catalog_entries: 0,
    embeddings_stored: 0,
    search_queries: 0,
    avg_similarity: 0.0,
  )
}

pub fn update(model: SmritiModel, msg: SmritiMsg) -> SmritiModel {
  case msg {
    EntryIngested ->
      SmritiModel(..model, catalog_entries: model.catalog_entries + 1)
    SearchPerformed(similarity) ->
      SmritiModel(
        ..model,
        search_queries: model.search_queries + 1,
        avg_similarity: similarity,
      )
    EmbeddingStored ->
      SmritiModel(..model, embeddings_stored: model.embeddings_stored + 1)
    RefreshSmriti -> model
  }
}

pub fn total_entries(model: SmritiModel) -> Int {
  model.catalog_entries
}

pub fn has_embeddings(model: SmritiModel) -> Bool {
  model.embeddings_stored > 0
}
