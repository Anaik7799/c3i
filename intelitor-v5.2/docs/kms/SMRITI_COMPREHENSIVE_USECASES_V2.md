# SMRITI Comprehensive Use Cases (v2)

This document outlines primary use cases for the SMRITI, aligned with its core design principles of Immortality, Federation, and Automation.

---

### Use Case 1: Knowledge Preservation (The Archivist)
- **Persona**: System Administrator, AI Agent (Guardian)
- **Goal**: Ensure long-term survival of the knowledge base.
- **Scenario**:
  1. The Immortality Protocol runs automatically on its weekly schedule.
  2. It exports the entire SMRITI database to 5 formats: SQLite, JSON, Markdown, Org-Mode, and an Obsidian Vault.
  3. These exports are pushed to 3+ preservation targets (e.g., local disk, a Git LFS repository, and an S3 bucket).
  4. A `reconstruction_guide.md` is generated and included with each backup, containing the schema and steps to rebuild the system from scratch.
  5. The system verifies the integrity of the backups and logs the success to the telemetry bus.

---

### Use Case 2: Distributed Knowledge Sync (The Swarm)
- **Persona**: SMRITI Node
- **Goal**: Maintain eventual consistency across a distributed cluster of SMRITI instances.
- **Scenario**:
  1. A new `indrajaal-app` container joins the mesh.
  2. The Federation Protocol discovers the new peer via Zenoh.
  3. The nodes exchange version vectors to determine knowledge deltas.
  4. The Replication engine on each node sends missing holons to its peers.
  5. If a conflict is detected (e.g., two nodes updated the same holon while partitioned), the conflict resolution strategy (last-writer-wins) is applied to ensure convergence.

---

### Use Case 3: Autonomous System Health (The Doctor)
- **Persona**: AI Agent (KnowledgeAgent)
- **Goal**: Proactively monitor and maintain the health of the knowledge graph.
- **Scenario**:
  1. The Knowledge Agent's OODA loop executes every 30 seconds.
  2. **[OBSERVE]** The agent queries the Health Monitor for metrics (e.g., average holon entropy, number of orphan nodes).
  3. **[ORIENT]** It compares current metrics to historical trends. It notices that entropy is steadily increasing and orphan count has spiked.
  4. **[DECIDE]** It decides to trigger a "knowledge compaction" action and suggests linking operations for the orphan nodes.
  5. **[ACT]** It calls the appropriate `SmritiLifecycle` functions and logs its actions to the audit trail.

---

### Use Case 4: Developer Onboarding (The New Hire)
- **Persona**: Software Developer
- **Goal**: Quickly get up to speed on the Indrajaal architecture.
- **Scenario**:
  1. The developer runs `devenv shell`.
  2. They use the `smriti-search "architecture"` command to find relevant documents.
  3. The search returns `SMRITI_8LEVEL_FRACTAL_EVOLUTION_PLAN.md` and other key specs.
  4. The developer can explore the knowledge graph visually using the Elmish client to understand component relationships.
