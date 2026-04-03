# SMRITI AI vs Fallback Extraction Quality Comparison

**Version**: 21.3.0-SIL6
**Last Updated**: 2026-01-11
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001
**STAMP**: SC-AI-001 (AI Context Persistence via SMRITI)
**AOR**: AOR-AI-001 (Memory Persistence)

## Executive Summary

The SMRITI system supports two extraction modes:
1. **AI-Enhanced** (via Claude/OpenRouter): Semantic understanding, tag extraction, intelligent classification
2. **Fallback** (regex-based): Pattern matching, size-based classification, no semantic tags

## Quantitative Comparison

| Metric | AI-Enhanced | Fallback | Improvement |
|--------|-------------|----------|-------------|
| Total Zettels | 14 | 199 | - |
| Avg Content Length | 31,220 bytes | 20,397 bytes | +53% (includes summary) |
| Tag Coverage | 57.1% | 19.1% | +199% |
| Semantic Titles | 100% | ~20% | +400% |
| AI-Classified Level | 100% | 0% | - |

## Qualitative Differences

### Title Quality

**AI-Enhanced Examples:**
- "Comprehensive Security Hardening for STAMP, TDG, and GDE Systems"
- "Container Security Implementation Guide"
- "PROMETHEUS Technical Specification: Nervous System & Verification Layer"
- "Data Retention and Cleanup Policy Analysis for Indrajaal Security Monitoring System"

**Fallback Examples:**
- "DOCUMENT: Cybernetic Execution & Biomorphic Sovereignty Blueprint (v21.3.0)"
- "INDRAJAAL COMPLETE FORMAL SPECIFICATION v20.0"
- "SC-REG Formal Properties Analysis"

### Tag Extraction

**AI-Enhanced:**
```
vulnerability assessment,security,risk management
container security,image scanning,network policies
PostgreSQL,Extensions,Security,Monitoring,TimescaleDB
GDPR,DPDP,Compliance,Data Protection,Privacy
ontology,category theory,fractal geometry,user interface,visual design
PROMETHEUS,Nervous System,Verification Layer,Biomorphic Controller,Telemetry
```

**Fallback:**
- No automatic tag extraction
- Relies on manual tagging or document metadata

### Level Classification

| Level | AI (Intelligent) | Fallback (Size-Based) |
|-------|------------------|----------------------|
| atomic | 0 | 11 |
| molecular | 1 | 38 |
| organism | 12 | 127 |
| ecosystem | 1 | 23 |

AI classification considers:
- Content complexity
- Domain scope
- Integration breadth
- Conceptual depth

Fallback classification uses:
- `< 3000 bytes` → atomic
- `3000-10000 bytes` → molecular
- `> 10000 bytes` → organism

### Content Enhancement

AI-Enhanced Zettels include:
```markdown
## Summary

[AI-generated 2-sentence summary]

---

[Original content]
```

This provides:
- Quick overview for browsing
- Context for search results
- LLM-digestible summaries

## Recommendations

1. **Production Ingestion**: Always use AI extraction (`OPENROUTER_API_KEY` configured)
2. **Batch Processing**: Use `--max N` to control API costs
3. **Cluster Organization**: Semantic clusters based on AI understanding
4. **Tag Utilization**: Use AI-extracted tags for graph connections

## Cost Analysis

OpenRouter Claude-3-Haiku costs:
- ~$0.00025 per 1K input tokens
- ~$0.00125 per 1K output tokens

Average document (~6K tokens) costs ~$0.002 per extraction.

For 200 documents: ~$0.40 total

## Conclusion

AI-powered extraction provides significantly higher quality Zettels with:
- 3x better tag coverage
- Semantic title generation
- Intelligent level classification
- Automatic summarization

The marginal cost ($0.002/doc) is justified by the quality improvement.

## Related Documents

- [SMRITI Developer Guide](SMRITI_DEVELOPER_GUIDE.md)
- [SMRITI User Guide](SMRITI_USER_GUIDE.md)
- [User Operations Guide](../USER_OPERATIONS_GUIDE.md)
- [SMRITI AI Extraction Rules](SMRITI_AI_EXTRACTION_RULES.md)

---

*SMRITI Quality Comparison v21.3.0-SIL6 | Indrajaal Project | 2026-01-11*
