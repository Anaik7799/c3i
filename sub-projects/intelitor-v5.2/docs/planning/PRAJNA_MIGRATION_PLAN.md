## 6.0 Appendix A: The Unified Substrate (Thread Model)

**Update (2026-01-15)**: The migration plan has been refined to explicitly adopt a **Thread-Based (Unified Process)** architecture for the internal logic of Prajna, utilizing F# Agents (`MailboxProcessor`).

For the complete specification, including mathematical analysis, STAMP constraints, and detailed BDD scenarios, refer to:
**`docs/architecture/PRAJNA_UNIFIED_SUBSTRATE_SPEC.md`**

### Summary of Change
*   **Architecture**: Single Process (Container) hosting multiple lightweight Agents (Threads).
*   **Latency**: Reduced from ~1ms (Container IPC) to ~100ns (Thread IPC).
*   **Safety**: Fault tolerance managed via internal "Supervisor" classes wrapping Agents.
*   **Scale**: Vertically scalable to 1000s of internal agents.