# FY27 LinkedIn & Sales Navigator Integration Protocol (SC-FY27-LI)

## Mandate
**LinkedIn and Sales Navigator are PRIMARY sales intelligence sources. All interactions MUST be logged to ZK. All extracted data MUST be verified. Rate limits MUST be strictly respected.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FY27-LI-001 | ALL LinkedIn actions MUST be logged to activity log | CRITICAL |
| SC-FY27-LI-002 | Rate limits MUST be strictly enforced (NEVER exceed) | CRITICAL |
| SC-FY27-LI-003 | Extracted contact data MUST be saved to ZK contacts | HIGH |
| SC-FY27-LI-004 | CAPTCHA or restriction MUST cause immediate STOP | CRITICAL |
| SC-FY27-LI-005 | Passwords MUST never be stored in files or memory | INFINITE |
| SC-FY27-LI-006 | Session cookies handled by Playwright only (no manual cookie storage) | HIGH |
| SC-FY27-LI-007 | All outreach MUST be logged with exact message text | HIGH |
| SC-FY27-LI-008 | Sales Nav data MUST be cross-referenced with ZK before creating duplicates | HIGH |

## Daily Rate Limits (HARD CAPS)
| Action | Daily Limit | Monthly Limit |
|--------|------------|---------------|
| Profile views (LinkedIn) | 50 | 1,000 |
| Profile views (Sales Nav) | 25 | 500 |
| Connection requests | 25 | 500 |
| Messages (LinkedIn) | 50 | 1,000 |
| InMails (Sales Nav) | - | 20 |
| Search pages | 30 | 600 |
| Exports | 5 | 100 |

At 80%: WARN and slow down. At 100%: STOP that action type for the day.

## Authentication Flow
1. Navigate to https://www.linkedin.com/login via Playwright
2. User enters credentials manually (agent NEVER types passwords)
3. Agent waits for redirect to /feed/ (indicates success)
4. If 2FA prompt appears, agent waits for user to complete
5. Session persists in Playwright browser context for the conversation
6. If session expires mid-operation, re-authenticate

## Safety Protocol
| Trigger | Action |
|---------|--------|
| CAPTCHA displayed | STOP all LinkedIn ops, alert user, wait 30 min minimum |
| "Restricted" banner | STOP immediately, do NOT retry, alert user |
| "Commercial use limit" | STOP Sales Nav ops for 24h |
| Unusual activity warning | STOP all ops, alert user, wait 24h |
| Login from new device | Let user handle, wait |
| Account locked | STOP everything, user must resolve via LinkedIn |

## Data Flow
```
LinkedIn/Sales Nav --> Playwright browser_snapshot
  --> Parse accessibility tree for structured data
  --> Validate data (no empty fields, correct format)
  --> Match against ZK contacts (dedup by name + company)
  --> If new: INSERT to ZK
  --> If existing: UPDATE with enriched fields
  --> Log action to activity log
  --> Ingest to both ZKs
```

## CSV Export Standards
All LinkedIn/Sales Nav data exports use:
- RFC 4180 CSV format with UTF-8 BOM for Excel
- Header row always present
- Dates as YYYY-MM-DD
- Output directory: FY27-Plan/exports/

## Playwright Best Practices
1. Always use browser_snapshot (accessibility tree) for data extraction
2. Wait for page load before extracting data
3. Use browser_click with element descriptions for audit trail
4. Never automate password entry
5. Handle navigation failures gracefully (retry once, then alert)
6. 3-5 second delay between actions to mimic human behavior

## Available MCP Servers (can be installed for deeper integration)
| Server | Risk | Best For |
|--------|------|----------|
| stickerdaniel/linkedin-mcp-server | MODERATE | Full LinkedIn ops with anti-detection (Patchright) |
| globodai-group/mcp-linkedin-sales-navigator | HIGH | Sales Navigator automation |
| adhikasp/mcp-linkedin | MODERATE | Feed browsing, job search |
| Apify LinkedIn MCP | LOWER | Scraping without using your account |
| ZoomInfo MCP (official) | SAFE | Contact enrichment (paid) |

## Integration with FY27 Commands
| LinkedIn Action | Follow-up Command |
|----------------|-------------------|
| New contact found | /fy27-log contact "New contact: Name at Company" |
| Meeting scheduled | /fy27-log meeting Account "Meeting with Name" |
| Connection accepted | /fy27-log linkedin "Connection accepted: Name" |
| InMail sent | /fy27-log email "InMail to Name: subject" |
| Competitive intel | /fy27-log intel "Competitor X hiring for Y" |
| Job change alert | /fy27-log intel "Name moved from X to Y" |

## Available Commands
- /fy27-linkedin-ops -- Core LinkedIn operations (10 ops)
- /fy27-salesnav-ops -- Sales Navigator operations (10 ops)
- /fy27-csv-export -- Export ZK data to CSV for CRM import
- /fy27-log -- Log any activity to ZK
- /fy27-status -- Dashboard including LinkedIn activity metrics
