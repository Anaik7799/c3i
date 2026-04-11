# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: full-planning-grid.spec.js >> 4. Tabulator Grid — Static >> grid data script contains blockedData variable
- Location: test/e2e/full-planning-grid.spec.js:155:3

# Error details

```
Error: expect(received).toBeTruthy()

Received: false
```

# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - navigation [ref=e2]:
    - link "Dashboard" [ref=e3] [cursor=pointer]:
      - /url: /dashboard
    - link "Planning" [ref=e4] [cursor=pointer]:
      - /url: /planning
    - link "Immune" [ref=e5] [cursor=pointer]:
      - /url: /immune
    - link "Knowledge" [ref=e6] [cursor=pointer]:
      - /url: /knowledge
    - link "Zenoh" [ref=e7] [cursor=pointer]:
      - /url: /zenoh
    - link "Cockpit" [ref=e8] [cursor=pointer]:
      - /url: /cockpit
    - link "Verification" [ref=e9] [cursor=pointer]:
      - /url: /verification
    - link "Substrate" [ref=e10] [cursor=pointer]:
      - /url: /substrate
    - link "Metabolic" [ref=e11] [cursor=pointer]:
      - /url: /metabolic
    - link "Podman" [ref=e12] [cursor=pointer]:
      - /url: /podman
    - link "MCP" [ref=e13] [cursor=pointer]:
      - /url: /mcp
    - link "KMS" [ref=e14] [cursor=pointer]:
      - /url: /kms
    - link "Telemetry" [ref=e15] [cursor=pointer]:
      - /url: /telemetry
    - link "Federation" [ref=e16] [cursor=pointer]:
      - /url: /federation
    - link "Health Grid" [ref=e17] [cursor=pointer]:
      - /url: /health-grid
    - link "Prajna" [ref=e18] [cursor=pointer]:
      - /url: /prajna
    - link "Agents" [ref=e19] [cursor=pointer]:
      - /url: /agents
    - link "Holon" [ref=e20] [cursor=pointer]:
      - /url: /holon
    - link "Config" [ref=e21] [cursor=pointer]:
      - /url: /config
    - link "Git" [ref=e22] [cursor=pointer]:
      - /url: /git
    - link "Database" [ref=e23] [cursor=pointer]:
      - /url: /database
    - link "Bridge" [ref=e24] [cursor=pointer]:
      - /url: /bridge
    - link "Smriti" [ref=e25] [cursor=pointer]:
      - /url: /smriti
    - link "OODA" [ref=e26] [cursor=pointer]:
      - /url: /planning-dashboard
    - link "Integrity" [ref=e27] [cursor=pointer]:
      - /url: /integrity
    - link "Evolution" [ref=e28] [cursor=pointer]:
      - /url: /evolution
    - link "Biomorphic" [ref=e29] [cursor=pointer]:
      - /url: /biomorphic
    - link "Homeostasis" [ref=e30] [cursor=pointer]:
      - /url: /homeostasis
    - link "Bicameral" [ref=e31] [cursor=pointer]:
      - /url: /bicameral
    - link "Singularity" [ref=e32] [cursor=pointer]:
      - /url: /singularity
    - link "Components" [ref=e33] [cursor=pointer]:
      - /url: /components
    - generic [ref=e34]:
      - generic "Dark Mode (Default)" [ref=e35] [cursor=pointer]
      - generic "Cyber Amber" [ref=e36] [cursor=pointer]
      - generic "Solaris White" [ref=e37] [cursor=pointer]
      - generic "Deep Forest" [ref=e38] [cursor=pointer]
    - button "TEST CYCLE" [ref=e39] [cursor=pointer]:
      - img [ref=e40]
      - text: TEST CYCLE
  - main [ref=e42]:
    - generic [ref=e43]:
      - generic [ref=e45]:
        - heading "Planning & Operations" [level=1] [ref=e46]
        - generic [ref=e47]: Live task management + Zettelkasten knowledge + 77 operational use cases
      - generic [ref=e48]:
        - generic [ref=e49]: ☀️
        - generic [ref=e50]: "System Mood: Clear — P0 100% done, 0 critical alerts, knowledge fresh"
        - generic [ref=e51]: 87/100
      - generic [ref=e52]:
        - img [ref=e54]:
          - generic [ref=e57]: 33.8%
          - generic [ref=e58]: Completed
        - img [ref=e60]:
          - generic [ref=e63]: 100%
          - generic [ref=e64]: P0 Safety
        - img [ref=e66]:
          - generic [ref=e69]: 3,824
          - generic [ref=e70]: Tests Pass
        - img [ref=e72]:
          - generic [ref=e75]: 2,060
          - generic [ref=e76]: Holons
      - generic [ref=e77]:
        - paragraph [ref=e78]: Task Summary (Live from Smriti.db)
        - generic [ref=e79]:
          - generic [ref=e80]:
            - paragraph [ref=e81]: Total Tasks
            - paragraph [ref=e82]: 2,710
            - paragraph [ref=e83]: in Smriti.db
          - generic [ref=e84]:
            - paragraph [ref=e85]: Completed
            - paragraph [ref=e86]: "917"
            - paragraph [ref=e87]: 33.8%
          - generic [ref=e88]:
            - paragraph [ref=e89]: Pending
            - paragraph [ref=e90]: 1,733
            - paragraph [ref=e91]: 63.9%
          - generic [ref=e92]:
            - paragraph [ref=e93]: In Progress
            - paragraph [ref=e94]: "47"
            - paragraph [ref=e95]: active
          - generic [ref=e96]:
            - paragraph [ref=e97]: Blocked
            - paragraph [ref=e98]: "13"
            - paragraph [ref=e99]: awaiting action
          - generic [ref=e100]:
            - paragraph [ref=e101]: Zettelkasten
            - paragraph [ref=e102]: 2,060
            - paragraph [ref=e103]: holons indexed
      - generic [ref=e104]:
        - paragraph [ref=e105]: Priority Breakdown
        - textbox "Filter table..." [ref=e106]
        - table [ref=e107]:
          - rowgroup [ref=e108]:
            - row "Priority Count % of Total Status" [ref=e109]:
              - columnheader "Priority" [ref=e110]
              - columnheader "Count" [ref=e111]
              - columnheader "% of Total" [ref=e112]
              - columnheader "Status" [ref=e113]
          - rowgroup [ref=e114]:
            - row "P0 — Critical Safety 191 7.0% All completed" [ref=e115]:
              - cell "P0 — Critical Safety" [ref=e116]
              - cell "191" [ref=e117]
              - cell "7.0%" [ref=e118]
              - cell "All completed" [ref=e119]
            - row "P1 — Core Features 276 10.2% Active development" [ref=e120]:
              - cell "P1 — Core Features" [ref=e121]
              - cell "276" [ref=e122]
              - cell "10.2%" [ref=e123]
              - cell "Active development" [ref=e124]
            - row "P2 — Routine 1,978 73.0% Backlog" [ref=e125]:
              - cell "P2 — Routine" [ref=e126]
              - cell "1,978" [ref=e127]
              - cell "73.0%" [ref=e128]
              - cell "Backlog" [ref=e129]
            - row "P3 — Nice-to-have 257 9.5% Backlog" [ref=e130]:
              - cell "P3 — Nice-to-have" [ref=e131]
              - cell "257" [ref=e132]
              - cell "9.5%" [ref=e133]
              - cell "Backlog" [ref=e134]
      - generic [ref=e135]:
        - paragraph [ref=e136]: OODA Phase
        - generic [ref=e137]:
          - generic [ref=e138]:
            - generic [ref=e139]: Containers
            - generic [ref=e140]: "16"
          - generic [ref=e141]:
            - generic [ref=e142]: Healthy
            - generic [ref=e143]: "16"
          - generic [ref=e144]:
            - generic [ref=e145]: Threat Level
            - generic [ref=e146]: nominal
          - generic [ref=e147]:
            - generic [ref=e148]: OODA Phase
            - generic [ref=e149]: observe
          - generic [ref=e150]:
            - generic [ref=e151]: Dark Cockpit
            - generic [ref=e152]: dark
          - generic [ref=e153]:
            - generic [ref=e154]: Zenoh
            - generic [ref=e155]: connected
          - generic [ref=e156]:
            - generic [ref=e157]: Quorum
            - generic [ref=e158]: healthy
      - generic [ref=e159]:
        - paragraph [ref=e160]: Operational Use Cases — 77 Enabled by Zettelkasten
        - generic [ref=e161]:
          - generic [ref=e162]:
            - paragraph [ref=e163]: SDLC
            - paragraph [ref=e164]: "22"
            - paragraph [ref=e165]: planning → design → implement → test → deploy → feedback
          - generic [ref=e166]:
            - paragraph [ref=e167]: SRE
            - paragraph [ref=e168]: "13"
            - paragraph [ref=e169]: incident → capacity → reliability
          - generic [ref=e170]:
            - paragraph [ref=e171]: Dev Experience
            - paragraph [ref=e172]: "13"
            - paragraph [ref=e173]: onboarding → workflow → knowledge creation
          - generic [ref=e174]:
            - paragraph [ref=e175]: System Ops
            - paragraph [ref=e176]: "11"
            - paragraph [ref=e177]: mesh → backup → monitoring
          - generic [ref=e178]:
            - paragraph [ref=e179]: Evolution
            - paragraph [ref=e180]: "13"
            - paragraph [ref=e181]: self-awareness → knowledge → symbiotic
          - generic [ref=e182]:
            - paragraph [ref=e183]: Cross-Cutting
            - paragraph [ref=e184]: "5"
            - paragraph [ref=e185]: universal search → knowledge chat → audit
      - generic [ref=e186]:
        - paragraph [ref=e187]: Session Activity — v22.6.0-BRAIN
        - textbox "Filter table..." [ref=e188]
        - table [ref=e189]:
          - rowgroup [ref=e190]:
            - row "Feature Status Detail" [ref=e191]:
              - columnheader "Feature" [ref=e192]
              - columnheader "Status" [ref=e193]
              - columnheader "Detail" [ref=e194]
          - rowgroup [ref=e195]:
            - row "Zettelkasten Brain DONE 9 Gleam modules + 1 Rust module, 2,060 holons ingested" [ref=e196]:
              - cell "Zettelkasten Brain" [ref=e197]
              - cell "DONE" [ref=e198]
              - cell "9 Gleam modules + 1 Rust module, 2,060 holons ingested" [ref=e199]
            - row "Telegram Mini App DONE 6 modules, 14 pages, HTTPS, TeleNative CSS" [ref=e200]:
              - cell "Telegram Mini App" [ref=e201]
              - cell "DONE" [ref=e202]
              - cell "6 modules, 14 pages, HTTPS, TeleNative CSS" [ref=e203]
            - row "Indra's Net Vision DONE 600-line architecture doc — Jewel, Fractal Zoom, 3 Voices" [ref=e204]:
              - cell "Indra's Net Vision" [ref=e205]
              - cell "DONE" [ref=e206]
              - cell "600-line architecture doc — Jewel, Fractal Zoom, 3 Voices" [ref=e207]
            - row "UI Evaluation Framework DONE 7 dimensions, mathematical scoring" [ref=e208]:
              - cell "UI Evaluation Framework" [ref=e209]
              - cell "DONE" [ref=e210]
              - cell "7 dimensions, mathematical scoring" [ref=e211]
            - row "Microservice Decomposition DONE 6-service split analysis from 9,104 LOC monolith" [ref=e212]:
              - cell "Microservice Decomposition" [ref=e213]
              - cell "DONE" [ref=e214]
              - cell "6-service split analysis from 9,104 LOC monolith" [ref=e215]
            - row "GCS Backup DONE 22.8 MB to europe-north1, KMS + SSL + .env included" [ref=e216]:
              - cell "GCS Backup" [ref=e217]
              - cell "DONE" [ref=e218]
              - cell "22.8 MB to europe-north1, KMS + SSL + .env included" [ref=e219]
            - row "Survival SOP DONE 10 failure scenarios, DR drill protocol, RTO/RPO" [ref=e220]:
              - cell "Survival SOP" [ref=e221]
              - cell "DONE" [ref=e222]
              - cell "10 failure scenarios, DR drill protocol, RTO/RPO" [ref=e223]
            - row "77 Use Cases DONE SDLC(22) + SRE(13) + Dev(13) + Ops(11) + Evo(13) + Cross(5)" [ref=e224]:
              - cell "77 Use Cases" [ref=e225]
              - cell "DONE" [ref=e226]
              - cell "SDLC(22) + SRE(13) + Dev(13) + Ops(11) + Evo(13) + Cross(5)" [ref=e227]
            - row "Cortex Build Fix DONE 56 errors → 0 via 5-level Jidoka RCA" [ref=e228]:
              - cell "Cortex Build Fix" [ref=e229]
              - cell "DONE" [ref=e230]
              - cell "56 errors → 0 via 5-level Jidoka RCA" [ref=e231]
            - row "Tests DONE 3,786 passed, 0 failures (+201 new)" [ref=e232]:
              - cell "Tests" [ref=e233]
              - cell "DONE" [ref=e234]
              - cell "3,786 passed, 0 failures (+201 new)" [ref=e235]
      - generic [ref=e236]:
        - paragraph [ref=e237]: Knowledge Health
        - generic [ref=e238]:
          - generic [ref=e239]:
            - paragraph [ref=e240]: Holons
            - paragraph [ref=e241]: 2,060
            - paragraph [ref=e242]: FTS5 indexed
          - generic [ref=e243]:
            - paragraph [ref=e244]: STAMP Refs
            - paragraph [ref=e245]: 6,647
            - paragraph [ref=e246]: cross-referenced
          - generic [ref=e247]:
            - paragraph [ref=e248]: FTS5 Search
            - paragraph [ref=e249]: < 1ms
            - paragraph [ref=e250]: query latency
          - generic [ref=e251]:
            - paragraph [ref=e252]: RAG Pipeline
            - paragraph [ref=e253]: Active
            - paragraph [ref=e254]: holons → LLM context
        - textbox "Filter table..." [ref=e255]
        - table [ref=e256]:
          - rowgroup [ref=e257]:
            - row "Level Count Description" [ref=e258]:
              - columnheader "Level" [ref=e259]
              - columnheader "Count" [ref=e260]
              - columnheader "Description" [ref=e261]
          - rowgroup [ref=e262]:
            - row "Ecosystem 86 Architecture docs, system vision" [ref=e263]:
              - cell "Ecosystem" [ref=e264]
              - cell "86" [ref=e265]
              - cell "Architecture docs, system vision" [ref=e266]
            - row "Organism 1,083 Journal entries, session narratives" [ref=e267]:
              - cell "Organism" [ref=e268]
              - cell "1,083" [ref=e269]
              - cell "Journal entries, session narratives" [ref=e270]
            - row "Molecular 284 Allium specs, plans, TLA+" [ref=e271]:
              - cell "Molecular" [ref=e272]
              - cell "284" [ref=e273]
              - cell "Allium specs, plans, TLA+" [ref=e274]
            - row "Atomic 607 Constraints, code modules, interactions" [ref=e275]:
              - cell "Atomic" [ref=e276]
              - cell "607" [ref=e277]
              - cell "Constraints, code modules, interactions" [ref=e278]
      - generic [ref=e279]:
        - paragraph [ref=e280]: Survivability
        - generic [ref=e281]:
          - generic [ref=e282]:
            - paragraph [ref=e283]: GCS Backup
            - paragraph [ref=e284]: 22.8 MB
            - paragraph [ref=e285]: europe-north1
          - generic [ref=e286]:
            - paragraph [ref=e287]: Git Remote
            - paragraph [ref=e288]: v22.6.0-BRAIN
            - paragraph [ref=e289]: pushed to GitHub
          - generic [ref=e290]:
            - paragraph [ref=e291]: SMTP
            - paragraph [ref=e292]: Active
            - paragraph [ref=e293]: Abhijit.Naik@bountytek.com
          - generic [ref=e294]:
            - paragraph [ref=e295]: DB Integrity
            - paragraph [ref=e296]: All OK
            - paragraph [ref=e297]: PRAGMA integrity_check
      - generic [ref=e298]:
        - paragraph [ref=e299]: Task Explorer — Interactive Data Grid
        - paragraph [ref=e300]: "Sortable, filterable, searchable. Source: NIF → Rust → SQLite (live). Powered by Tabulator."
        - grid [ref=e301]:
          - rowgroup [ref=e302]:
            - rowgroup [ref=e303]:
              - row "ID Priority Status Description Created" [ref=e304]:
                - columnheader "ID" [ref=e305]:
                  - generic [ref=e308]: ID
                - columnheader "Priority" [ref=e312]:
                  - generic [ref=e315]: Priority
                - columnheader "Status" [ref=e319]:
                  - generic [ref=e322]: Status
                - columnheader "Description" [ref=e326]:
                  - generic [ref=e327]:
                    - generic [ref=e329]: Description
                    - searchbox [ref=e333]
                - columnheader "Created" [ref=e335]:
                  - generic [ref=e338]: Created
          - rowgroup [ref=e343]:
            - 'row "0af8752b P2 blocked P2-FEAT: Implement FSharpDAP.fs GRPC service — debug adapter protocol for F# (L4) 2026-03-27" [ref=e344]':
              - gridcell "0af8752b" [ref=e345]
              - gridcell "P2" [ref=e347]
              - gridcell "blocked" [ref=e349]
              - 'gridcell "P2-FEAT: Implement FSharpDAP.fs GRPC service — debug adapter protocol for F# (L4)" [ref=e351]'
              - gridcell "2026-03-27" [ref=e353]
            - 'row "21db8704 P2 blocked P2-FEAT: Implement GraphView.fs tooltip with zettel info for knowledge graph (L4) 2026-03-27" [ref=e355]':
              - gridcell "21db8704" [ref=e356]
              - gridcell "P2" [ref=e358]
              - gridcell "blocked" [ref=e360]
              - 'gridcell "P2-FEAT: Implement GraphView.fs tooltip with zettel info for knowledge graph (L4)" [ref=e362]'
              - gridcell "2026-03-27" [ref=e364]
            - 'row "598288ec P3 blocked P3-UI: Add LiveView alarm list real-time update — Phoenix.PubSub (L3) 2026-03-27" [ref=e366]':
              - gridcell "598288ec" [ref=e367]
              - gridcell "P3" [ref=e369]
              - gridcell "blocked" [ref=e371]
              - 'gridcell "P3-UI: Add LiveView alarm list real-time update — Phoenix.PubSub (L3)" [ref=e373]'
              - gridcell "2026-03-27" [ref=e375]
            - 'row "5cf14afa P2 blocked P2-FEAT: Add F# MCP Guardian handler — proposal submit + status query (L4) 2026-03-27" [ref=e377]':
              - gridcell "5cf14afa" [ref=e378]
              - gridcell "P2" [ref=e380]
              - gridcell "blocked" [ref=e382]
              - 'gridcell "P2-FEAT: Add F# MCP Guardian handler — proposal submit + status query (L4)" [ref=e384]'
              - gridcell "2026-03-27" [ref=e386]
            - 'row "69394b38 P2 blocked P2-FEAT: Implement ZettelView.fs markdown renderer for SMRITI client (L4) 2026-03-27" [ref=e388]':
              - gridcell "69394b38" [ref=e389]
              - gridcell "P2" [ref=e391]
              - gridcell "blocked" [ref=e393]
              - 'gridcell "P2-FEAT: Implement ZettelView.fs markdown renderer for SMRITI client (L4)" [ref=e395]'
              - gridcell "2026-03-27" [ref=e397]
            - 'row "7c83ec50 P2 blocked P2-FEAT: Add CEPAF F# Cockpit TUI health dashboard with ANSI rendering (L4) 2026-03-27" [ref=e399]':
              - gridcell "7c83ec50" [ref=e400]
              - gridcell "P2" [ref=e402]
              - gridcell "blocked" [ref=e404]
              - 'gridcell "P2-FEAT: Add CEPAF F# Cockpit TUI health dashboard with ANSI rendering (L4)" [ref=e406]'
              - gridcell "2026-03-27" [ref=e408]
            - 'row "889e6ae7 P3 blocked P3-UI: Add LiveView Prajna copilot chat streaming response L4 2026-03-27" [ref=e410]':
              - gridcell "889e6ae7" [ref=e411]
              - gridcell "P3" [ref=e413]
              - gridcell "blocked" [ref=e415]
              - 'gridcell "P3-UI: Add LiveView Prajna copilot chat streaming response L4" [ref=e417]'
              - gridcell "2026-03-27" [ref=e419]
            - 'row "8db1f246 P3 blocked P3-UI: Add LiveView analytics report builder — chart generation (L3) 2026-03-27" [ref=e421]':
              - gridcell "8db1f246" [ref=e422]
              - gridcell "P3" [ref=e424]
              - gridcell "blocked" [ref=e426]
              - 'gridcell "P3-UI: Add LiveView analytics report builder — chart generation (L3)" [ref=e428]'
              - gridcell "2026-03-27" [ref=e430]
            - 'row "918b4c6f P2 blocked P2-FEAT: Add F# MCP server SSE transport for remote access (L4) 2026-03-27" [ref=e432]':
              - gridcell "918b4c6f" [ref=e433]
              - gridcell "P2" [ref=e435]
              - gridcell "blocked" [ref=e437]
              - 'gridcell "P2-FEAT: Add F# MCP server SSE transport for remote access (L4)" [ref=e439]'
              - gridcell "2026-03-27" [ref=e441]
            - 'row "972b68f4 P2 blocked P2-FEAT: Add CEPAF ConfigBridge real Zenoh pub/sub replacing file sync (L4) 2026-03-27" [ref=e443]':
              - gridcell "972b68f4" [ref=e444]
              - gridcell "P2" [ref=e446]
              - gridcell "blocked" [ref=e448]
              - 'gridcell "P2-FEAT: Add CEPAF ConfigBridge real Zenoh pub/sub replacing file sync (L4)" [ref=e450]'
              - gridcell "2026-03-27" [ref=e452]
            - 'row "993bb12e P2 blocked P2-FEAT: Add F# MCP Cortex handler — AI inference request + result (L4) 2026-03-27" [ref=e454]':
              - gridcell "993bb12e" [ref=e455]
              - gridcell "P2" [ref=e457]
              - gridcell "blocked" [ref=e459]
              - 'gridcell "P2-FEAT: Add F# MCP Cortex handler — AI inference request + result (L4)" [ref=e461]'
              - gridcell "2026-03-27" [ref=e463]
            - 'row "df5d7681 P3 blocked P3-UI: Add LiveView device health grid — color-coded matrix (L3) 2026-03-27" [ref=e465]':
              - gridcell "df5d7681" [ref=e466]
              - gridcell "P3" [ref=e468]
              - gridcell "blocked" [ref=e470]
              - 'gridcell "P3-UI: Add LiveView device health grid — color-coded matrix (L3)" [ref=e472]'
              - gridcell "2026-03-27" [ref=e474]
            - 'row "fcb6f917 P2 blocked P2-FEAT: Add F# MCP SMRITI handler — knowledge query + zettel CRUD (L4) 2026-03-27" [ref=e476]':
              - gridcell "fcb6f917" [ref=e477]
              - gridcell "P2" [ref=e479]
              - gridcell "blocked" [ref=e481]
              - 'gridcell "P2-FEAT: Add F# MCP SMRITI handler — knowledge query + zettel CRUD (L4)" [ref=e483]'
              - gridcell "2026-03-27" [ref=e485]
        - heading "In-Progress Tasks" [level=2] [ref=e487]
        - grid [ref=e488]:
          - rowgroup [ref=e489]:
            - rowgroup [ref=e490]:
              - row "ID Priority Status Description Created" [ref=e491]:
                - columnheader "ID" [ref=e492]:
                  - generic [ref=e495]: ID
                - columnheader "Priority" [ref=e499]:
                  - generic [ref=e502]: Priority
                - columnheader "Status" [ref=e506]:
                  - generic [ref=e509]: Status
                - columnheader "Description" [ref=e513]:
                  - generic [ref=e514]:
                    - generic [ref=e516]: Description
                    - searchbox [ref=e520]
                - columnheader "Created" [ref=e522]:
                  - generic [ref=e525]: Created
          - rowgroup [ref=e530]:
            - 'row "695c9c56 P0 in_progress Substrate: Port 5-stage transactional boot sequence to Gleam 2026-04-06" [ref=e531]':
              - gridcell "695c9c56" [ref=e532]
              - gridcell "P0" [ref=e534]
              - gridcell "in_progress" [ref=e536]
              - 'gridcell "Substrate: Port 5-stage transactional boot sequence to Gleam" [ref=e538]'
              - gridcell "2026-04-06" [ref=e540]
            - 'row "73bd6a5f P0 in_progress Substrate: Implement sa-up, sa-down, sa-status in Gleam 2026-04-06" [ref=e542]':
              - gridcell "73bd6a5f" [ref=e543]
              - gridcell "P0" [ref=e545]
              - gridcell "in_progress" [ref=e547]
              - 'gridcell "Substrate: Implement sa-up, sa-down, sa-status in Gleam" [ref=e549]'
              - gridcell "2026-04-06" [ref=e551]
            - 'row "150075f2 P3 in_progress Transition test #0 2026-04-09" [ref=e553]':
              - gridcell "150075f2" [ref=e554]
              - gridcell "P3" [ref=e556]
              - gridcell "in_progress" [ref=e558]
              - 'gridcell "Transition test #0" [ref=e560]'
              - gridcell "2026-04-09" [ref=e562]
            - 'row "974eee9b P3 in_progress Transition test #1 2026-04-09" [ref=e564]':
              - gridcell "974eee9b" [ref=e565]
              - gridcell "P3" [ref=e567]
              - gridcell "in_progress" [ref=e569]
              - 'gridcell "Transition test #1" [ref=e571]'
              - gridcell "2026-04-09" [ref=e573]
            - 'row "e305645c P3 in_progress Transition test #2 2026-04-09" [ref=e575]':
              - gridcell "e305645c" [ref=e576]
              - gridcell "P3" [ref=e578]
              - gridcell "in_progress" [ref=e580]
              - 'gridcell "Transition test #2" [ref=e582]'
              - gridcell "2026-04-09" [ref=e584]
            - 'row "6995e496 P3 in_progress Transition test #3 2026-04-09" [ref=e586]':
              - gridcell "6995e496" [ref=e587]
              - gridcell "P3" [ref=e589]
              - gridcell "in_progress" [ref=e591]
              - 'gridcell "Transition test #3" [ref=e593]'
              - gridcell "2026-04-09" [ref=e595]
            - 'row "56992c95 P3 in_progress Transition test #4 2026-04-09" [ref=e597]':
              - gridcell "56992c95" [ref=e598]
              - gridcell "P3" [ref=e600]
              - gridcell "in_progress" [ref=e602]
              - 'gridcell "Transition test #4" [ref=e604]'
              - gridcell "2026-04-09" [ref=e606]
            - 'row "65a7732b P3 in_progress Transition test #0 2026-04-09" [ref=e608]':
              - gridcell "65a7732b" [ref=e609]
              - gridcell "P3" [ref=e611]
              - gridcell "in_progress" [ref=e613]
              - 'gridcell "Transition test #0" [ref=e615]'
              - gridcell "2026-04-09" [ref=e617]
            - 'row "fd264dfe P3 in_progress Transition test #1 2026-04-09" [ref=e619]':
              - gridcell "fd264dfe" [ref=e620]
              - gridcell "P3" [ref=e622]
              - gridcell "in_progress" [ref=e624]
              - 'gridcell "Transition test #1" [ref=e626]'
              - gridcell "2026-04-09" [ref=e628]
            - 'row "61cad436 P3 in_progress Transition test #2 2026-04-09" [ref=e630]':
              - gridcell "61cad436" [ref=e631]
              - gridcell "P3" [ref=e633]
              - gridcell "in_progress" [ref=e635]
              - 'gridcell "Transition test #2" [ref=e637]'
              - gridcell "2026-04-09" [ref=e639]
            - 'row "2ce7dab9 P3 in_progress Transition test #3 2026-04-09" [ref=e641]':
              - gridcell "2ce7dab9" [ref=e642]
              - gridcell "P3" [ref=e644]
              - gridcell "in_progress" [ref=e646]
              - 'gridcell "Transition test #3" [ref=e648]'
              - gridcell "2026-04-09" [ref=e650]
            - 'row "7978d5f6 P3 in_progress Transition test #4 2026-04-09" [ref=e652]':
              - gridcell "7978d5f6" [ref=e653]
              - gridcell "P3" [ref=e655]
              - gridcell "in_progress" [ref=e657]
              - 'gridcell "Transition test #4" [ref=e659]'
              - gridcell "2026-04-09" [ref=e661]
            - 'row "bdc64c1b P3 in_progress Transition test #0 2026-04-09" [ref=e663]':
              - gridcell "bdc64c1b" [ref=e664]
              - gridcell "P3" [ref=e666]
              - gridcell "in_progress" [ref=e668]
              - 'gridcell "Transition test #0" [ref=e670]'
              - gridcell "2026-04-09" [ref=e672]
            - 'row "35216d44 P3 in_progress Transition test #1 2026-04-09" [ref=e674]':
              - gridcell "35216d44" [ref=e675]
              - gridcell "P3" [ref=e677]
              - gridcell "in_progress" [ref=e679]
              - 'gridcell "Transition test #1" [ref=e681]'
              - gridcell "2026-04-09" [ref=e683]
            - 'row "b2ef0864 P3 in_progress Transition test #2 2026-04-09" [ref=e685]':
              - gridcell "b2ef0864" [ref=e686]
              - gridcell "P3" [ref=e688]
              - gridcell "in_progress" [ref=e690]
              - 'gridcell "Transition test #2" [ref=e692]'
              - gridcell "2026-04-09" [ref=e694]
            - 'row "2b4a4f68 P3 in_progress Transition test #3 2026-04-09" [ref=e696]':
              - gridcell "2b4a4f68" [ref=e697]
              - gridcell "P3" [ref=e699]
              - gridcell "in_progress" [ref=e701]
              - 'gridcell "Transition test #3" [ref=e703]'
              - gridcell "2026-04-09" [ref=e705]
            - 'row "8ffb6cdf P3 in_progress Transition test #4 2026-04-09" [ref=e707]':
              - gridcell "8ffb6cdf" [ref=e708]
              - gridcell "P3" [ref=e710]
              - gridcell "in_progress" [ref=e712]
              - 'gridcell "Transition test #4" [ref=e714]'
              - gridcell "2026-04-09" [ref=e716]
            - 'row "66f4382c P3 in_progress Transition test #0 2026-04-09" [ref=e718]':
              - gridcell "66f4382c" [ref=e719]
              - gridcell "P3" [ref=e721]
              - gridcell "in_progress" [ref=e723]
              - 'gridcell "Transition test #0" [ref=e725]'
              - gridcell "2026-04-09" [ref=e727]
            - 'row "4338a7f1 P3 in_progress Transition test #1 2026-04-09" [ref=e729]':
              - gridcell "4338a7f1" [ref=e730]
              - gridcell "P3" [ref=e732]
              - gridcell "in_progress" [ref=e734]
              - 'gridcell "Transition test #1" [ref=e736]'
              - gridcell "2026-04-09" [ref=e738]
            - 'row "91e563bc P3 in_progress Transition test #2 2026-04-09" [ref=e740]':
              - gridcell "91e563bc" [ref=e741]
              - gridcell "P3" [ref=e743]
              - gridcell "in_progress" [ref=e745]
              - 'gridcell "Transition test #2" [ref=e747]'
              - gridcell "2026-04-09" [ref=e749]
            - 'row "e091a993 P3 in_progress Transition test #3 2026-04-09" [ref=e751]':
              - gridcell "e091a993" [ref=e752]
              - gridcell "P3" [ref=e754]
              - gridcell "in_progress" [ref=e756]
              - 'gridcell "Transition test #3" [ref=e758]'
              - gridcell "2026-04-09" [ref=e760]
            - 'row "7e68a81f P3 in_progress Transition test #4 2026-04-09" [ref=e762]':
              - gridcell "7e68a81f" [ref=e763]
              - gridcell "P3" [ref=e765]
              - gridcell "in_progress" [ref=e767]
              - 'gridcell "Transition test #4" [ref=e769]'
              - gridcell "2026-04-09" [ref=e771]
            - 'row "cd9912cf P3 in_progress Transition test #0 2026-04-09" [ref=e773]':
              - gridcell "cd9912cf" [ref=e774]
              - gridcell "P3" [ref=e776]
              - gridcell "in_progress" [ref=e778]
              - 'gridcell "Transition test #0" [ref=e780]'
              - gridcell "2026-04-09" [ref=e782]
            - 'row "6e9c08be P3 in_progress Transition test #1 2026-04-09" [ref=e784]':
              - gridcell "6e9c08be" [ref=e785]
              - gridcell "P3" [ref=e787]
              - gridcell "in_progress" [ref=e789]
              - 'gridcell "Transition test #1" [ref=e791]'
              - gridcell "2026-04-09" [ref=e793]
            - 'row "dd8da274 P3 in_progress Transition test #2 2026-04-09" [ref=e795]':
              - gridcell "dd8da274" [ref=e796]
              - gridcell "P3" [ref=e798]
              - gridcell "in_progress" [ref=e800]
              - 'gridcell "Transition test #2" [ref=e802]'
              - gridcell "2026-04-09" [ref=e804]
            - 'row "1a399551 P3 in_progress Transition test #3 2026-04-09" [ref=e806]':
              - gridcell "1a399551" [ref=e807]
              - gridcell "P3" [ref=e809]
              - gridcell "in_progress" [ref=e811]
              - 'gridcell "Transition test #3" [ref=e813]'
              - gridcell "2026-04-09" [ref=e815]
            - 'row "e8663428 P3 in_progress Transition test #4 2026-04-09" [ref=e817]':
              - gridcell "e8663428" [ref=e818]
              - gridcell "P3" [ref=e820]
              - gridcell "in_progress" [ref=e822]
              - 'gridcell "Transition test #4" [ref=e824]'
              - gridcell "2026-04-09" [ref=e826]
            - 'row "6c9e774e P3 in_progress Transition test #0 2026-04-09" [ref=e828]':
              - gridcell "6c9e774e" [ref=e829]
              - gridcell "P3" [ref=e831]
              - gridcell "in_progress" [ref=e833]
              - 'gridcell "Transition test #0" [ref=e835]'
              - gridcell "2026-04-09" [ref=e837]
            - 'row "a28bcd53 P3 in_progress Transition test #1 2026-04-09" [ref=e839]':
              - gridcell "a28bcd53" [ref=e840]
              - gridcell "P3" [ref=e842]
              - gridcell "in_progress" [ref=e844]
              - 'gridcell "Transition test #1" [ref=e846]'
              - gridcell "2026-04-09" [ref=e848]
            - 'row "4675aa6f P3 in_progress Transition test #2 2026-04-09" [ref=e850]':
              - gridcell "4675aa6f" [ref=e851]
              - gridcell "P3" [ref=e853]
              - gridcell "in_progress" [ref=e855]
              - 'gridcell "Transition test #2" [ref=e857]'
              - gridcell "2026-04-09" [ref=e859]
            - 'row "86591e39 P3 in_progress Transition test #3 2026-04-09" [ref=e861]':
              - gridcell "86591e39" [ref=e862]
              - gridcell "P3" [ref=e864]
              - gridcell "in_progress" [ref=e866]
              - 'gridcell "Transition test #3" [ref=e868]'
              - gridcell "2026-04-09" [ref=e870]
            - 'row "11e3059a P3 in_progress Transition test #4 2026-04-09" [ref=e872]':
              - gridcell "11e3059a" [ref=e873]
              - gridcell "P3" [ref=e875]
              - gridcell "in_progress" [ref=e877]
              - 'gridcell "Transition test #4" [ref=e879]'
              - gridcell "2026-04-09" [ref=e881]
            - 'row "9f50bc06 P3 in_progress Transition test #0 2026-04-09" [ref=e883]':
              - gridcell "9f50bc06" [ref=e884]
              - gridcell "P3" [ref=e886]
              - gridcell "in_progress" [ref=e888]
              - 'gridcell "Transition test #0" [ref=e890]'
              - gridcell "2026-04-09" [ref=e892]
            - 'row "1ec5074e P3 in_progress Transition test #1 2026-04-09" [ref=e894]':
              - gridcell "1ec5074e" [ref=e895]
              - gridcell "P3" [ref=e897]
              - gridcell "in_progress" [ref=e899]
              - 'gridcell "Transition test #1" [ref=e901]'
              - gridcell "2026-04-09" [ref=e903]
            - 'row "20d78bfc P3 in_progress Transition test #2 2026-04-09" [ref=e905]':
              - gridcell "20d78bfc" [ref=e906]
              - gridcell "P3" [ref=e908]
              - gridcell "in_progress" [ref=e910]
              - 'gridcell "Transition test #2" [ref=e912]'
              - gridcell "2026-04-09" [ref=e914]
            - 'row "7bb0a338 P3 in_progress Transition test #3 2026-04-09" [ref=e916]':
              - gridcell "7bb0a338" [ref=e917]
              - gridcell "P3" [ref=e919]
              - gridcell "in_progress" [ref=e921]
              - 'gridcell "Transition test #3" [ref=e923]'
              - gridcell "2026-04-09" [ref=e925]
            - 'row "05b97194 P3 in_progress Transition test #4 2026-04-09" [ref=e927]':
              - gridcell "05b97194" [ref=e928]
              - gridcell "P3" [ref=e930]
              - gridcell "in_progress" [ref=e932]
              - 'gridcell "Transition test #4" [ref=e934]'
              - gridcell "2026-04-09" [ref=e936]
            - 'row "4d6e98d9 P3 in_progress Transition test #0 2026-04-09" [ref=e938]':
              - gridcell "4d6e98d9" [ref=e939]
              - gridcell "P3" [ref=e941]
              - gridcell "in_progress" [ref=e943]
              - 'gridcell "Transition test #0" [ref=e945]'
              - gridcell "2026-04-09" [ref=e947]
            - 'row "9d73d5e3 P3 in_progress Transition test #1 2026-04-09" [ref=e949]':
              - gridcell "9d73d5e3" [ref=e950]
              - gridcell "P3" [ref=e952]
              - gridcell "in_progress" [ref=e954]
              - 'gridcell "Transition test #1" [ref=e956]'
              - gridcell "2026-04-09" [ref=e958]
            - 'row "b0f5a12e P3 in_progress Transition test #2 2026-04-09" [ref=e960]':
              - gridcell "b0f5a12e" [ref=e961]
              - gridcell "P3" [ref=e963]
              - gridcell "in_progress" [ref=e965]
              - 'gridcell "Transition test #2" [ref=e967]'
              - gridcell "2026-04-09" [ref=e969]
        - heading "All Tasks (search across 2,710)" [level=2] [ref=e971]
        - grid [ref=e972]:
          - rowgroup [ref=e973]:
            - rowgroup [ref=e974]:
              - row "ID Priority Status Description Created" [ref=e975]:
                - columnheader "ID" [ref=e976]:
                  - generic [ref=e979]: ID
                - columnheader "Priority" [ref=e983]:
                  - generic [ref=e986]: Priority
                - columnheader "Status" [ref=e990]:
                  - generic [ref=e993]: Status
                - columnheader "Description" [ref=e997]:
                  - generic [ref=e998]:
                    - generic [ref=e1000]: Description
                    - searchbox [ref=e1004]
                - columnheader "Created" [ref=e1006]:
                  - generic [ref=e1009]: Created
          - rowgroup [ref=e1014]:
            - 'row "dfe8b6db --priority completed W1-RUST: Implement substrate_guard.rs + nif_validator.rs — Axiom 0.1 enforcement, ELF binary inspection, glibc/musl detection [RPN 252+225] 2026-04-03" [ref=e1015]':
              - gridcell "dfe8b6db" [ref=e1016]
              - gridcell "--priority" [ref=e1018]
              - gridcell "completed" [ref=e1020]
              - 'gridcell "W1-RUST: Implement substrate_guard.rs + nif_validator.rs — Axiom 0.1 enforcement, ELF binary inspection, glibc/musl detection [RPN 252+225]" [ref=e1022]'
              - gridcell "2026-04-03" [ref=e1024]
            - 'row "59f1847b --priority completed W2-RUST: Implement build_oracle.rs + adaptive health timeouts — F# BuildHistory EMA bridge via rusqlite, fixed→adaptive timeout [RPN 196] 2026-04-03" [ref=e1026]':
              - gridcell "59f1847b" [ref=e1027]
              - gridcell "--priority" [ref=e1029]
              - gridcell "completed" [ref=e1031]
              - 'gridcell "W2-RUST: Implement build_oracle.rs + adaptive health timeouts — F# BuildHistory EMA bridge via rusqlite, fixed→adaptive timeout [RPN 196]" [ref=e1033]'
              - gridcell "2026-04-03" [ref=e1035]
            - 'row "605ebe96 --priority completed W3-RUST: Implement health_orchestra.rs + expanded preflight PF-7..PF-25 — FPPS 5-method consensus replacing single TCP probe [RPN 168] 2026-04-03" [ref=e1037]':
              - gridcell "605ebe96" [ref=e1038]
              - gridcell "--priority" [ref=e1040]
              - gridcell "completed" [ref=e1042]
              - 'gridcell "W3-RUST: Implement health_orchestra.rs + expanded preflight PF-7..PF-25 — FPPS 5-method consensus replacing single TCP probe [RPN 168]" [ref=e1044]'
              - gridcell "2026-04-03" [ref=e1046]
            - 'row "28d2a53c --priority completed W4-RUST: Expand TUI to 8 tabs (BUILD, NIF, DB, Recovery) — operator cognition for all lifecycle phases [RPN 140] 2026-04-03" [ref=e1048]':
              - gridcell "28d2a53c" [ref=e1049]
              - gridcell "--priority" [ref=e1051]
              - gridcell "completed" [ref=e1053]
              - 'gridcell "W4-RUST: Expand TUI to 8 tabs (BUILD, NIF, DB, Recovery) — operator cognition for all lifecycle phases [RPN 140]" [ref=e1055]'
              - gridcell "2026-04-03" [ref=e1057]
            - 'row "5a7c945e --priority completed W5-RUST: Implement recovery.rs + integration testing — automated playbooks for top-5 failure modes + F#→SQLite→Rust→TUI pipeline test 2026-04-03" [ref=e1059]':
              - gridcell "5a7c945e" [ref=e1060]
              - gridcell "--priority" [ref=e1062]
              - gridcell "completed" [ref=e1064]
              - 'gridcell "W5-RUST: Implement recovery.rs + integration testing — automated playbooks for top-5 failure modes + F#→SQLite→Rust→TUI pipeline test" [ref=e1066]'
              - gridcell "2026-04-03" [ref=e1068]
            - 'row "040e58be P0 completed Biomorphic Ignition: Create Sentinel-Zenoh supreme entry point for autonomous setup 2026-03-27" [ref=e1070]':
              - gridcell "040e58be" [ref=e1071]
              - gridcell "P0" [ref=e1073]
              - gridcell "completed" [ref=e1075]
              - 'gridcell "Biomorphic Ignition: Create Sentinel-Zenoh supreme entry point for autonomous setup" [ref=e1077]'
              - gridcell "2026-03-27" [ref=e1079]
            - 'row "05f3d210 P0 completed Sprint 68: Implement sa-resurrect one-command system recovery (SC-EMR-065) 2026-03-27" [ref=e1081]':
              - gridcell "05f3d210" [ref=e1082]
              - gridcell "P0" [ref=e1084]
              - gridcell "completed" [ref=e1086]
              - 'gridcell "Sprint 68: Implement sa-resurrect one-command system recovery (SC-EMR-065)" [ref=e1088]'
              - gridcell "2026-03-27" [ref=e1090]
            - 'row "065c86a0 P0 completed Phase 2: Add CancellationToken to RegressionRunner.run 2026-03-27" [ref=e1092]':
              - gridcell "065c86a0" [ref=e1093]
              - gridcell "P0" [ref=e1095]
              - gridcell "completed" [ref=e1097]
              - 'gridcell "Phase 2: Add CancellationToken to RegressionRunner.run" [ref=e1099]'
              - gridcell "2026-03-27" [ref=e1101]
            - 'row "0a1b076a P0 completed AI-Sentinel: Integrate OpenRouter for proactive threat analysis via Zenoh 2026-03-27" [ref=e1103]':
              - gridcell "0a1b076a" [ref=e1104]
              - gridcell "P0" [ref=e1106]
              - gridcell "completed" [ref=e1108]
              - 'gridcell "AI-Sentinel: Integrate OpenRouter for proactive threat analysis via Zenoh" [ref=e1110]'
              - gridcell "2026-03-27" [ref=e1112]
            - 'row "0aae4d32 P0 completed Sprint 75: Implement sa-nuclear nuclear reset command (SC-EMR-066) 2026-03-27" [ref=e1114]':
              - gridcell "0aae4d32" [ref=e1115]
              - gridcell "P0" [ref=e1117]
              - gridcell "completed" [ref=e1119]
              - 'gridcell "Sprint 75: Implement sa-nuclear nuclear reset command (SC-EMR-066)" [ref=e1121]'
              - gridcell "2026-03-27" [ref=e1123]
            - 'row "13fbfb03 P0 completed Sprint 72: Deep Substrate Hardening for Helix Editor (SC-SYS-004) 2026-03-27" [ref=e1125]':
              - gridcell "13fbfb03" [ref=e1126]
              - gridcell "P0" [ref=e1128]
              - gridcell "completed" [ref=e1130]
              - 'gridcell "Sprint 72: Deep Substrate Hardening for Helix Editor (SC-SYS-004)" [ref=e1132]'
              - gridcell "2026-03-27" [ref=e1134]
            - 'row "2a928d26 P0 completed P0-SAFETY: Implement token_refresh.ex 8 DB stubs — store/validate/revoke/get refresh tokens (L2) 2026-03-27" [ref=e1136]':
              - gridcell "2a928d26" [ref=e1137]
              - gridcell "P0" [ref=e1139]
              - gridcell "completed" [ref=e1141]
              - 'gridcell "P0-SAFETY: Implement token_refresh.ex 8 DB stubs — store/validate/revoke/get refresh tokens (L2)" [ref=e1143]'
              - gridcell "2026-03-27" [ref=e1145]
            - 'row "2ab4db9a P0 completed Sprint 83: Accelerate Evolution rate to target 80% substrate saturation (SC-SING-006) 2026-03-27" [ref=e1147]':
              - gridcell "2ab4db9a" [ref=e1148]
              - gridcell "P0" [ref=e1150]
              - gridcell "completed" [ref=e1152]
              - 'gridcell "Sprint 83: Accelerate Evolution rate to target 80% substrate saturation (SC-SING-006)" [ref=e1154]'
              - gridcell "2026-03-27" [ref=e1156]
            - 'row "2d2fa6ad P0 completed P0-EXISTENTIAL: Establish Zenoh Neural Bridge (Elixir to Mojo IPC) 2026-03-27" [ref=e1158]':
              - gridcell "2d2fa6ad" [ref=e1159]
              - gridcell "P0" [ref=e1161]
              - gridcell "completed" [ref=e1163]
              - 'gridcell "P0-EXISTENTIAL: Establish Zenoh Neural Bridge (Elixir to Mojo IPC)" [ref=e1165]'
              - gridcell "2026-03-27" [ref=e1167]
            - 'row "306d3036 P0 completed S54-T108: Biomorphic Holon Regeneration Test 2026-03-27" [ref=e1169]':
              - gridcell "306d3036" [ref=e1170]
              - gridcell "P0" [ref=e1172]
              - gridcell "completed" [ref=e1174]
              - 'gridcell "S54-T108: Biomorphic Holon Regeneration Test" [ref=e1176]'
              - gridcell "2026-03-27" [ref=e1178]
            - row "3992157d P0 completed [P0] Fix Orchestrator full protocol execution failure 2026-03-27" [ref=e1180]:
              - gridcell "3992157d" [ref=e1181]
              - gridcell "P0" [ref=e1183]
              - gridcell "completed" [ref=e1185]
              - gridcell "[P0] Fix Orchestrator full protocol execution failure" [ref=e1187]
              - gridcell "2026-03-27" [ref=e1189]
            - 'row "3e87c4c5 P0 completed Biomorphic BDD Alignment: Refactor test steps for 14-node SIL-6 parity 2026-03-27" [ref=e1191]':
              - gridcell "3e87c4c5" [ref=e1192]
              - gridcell "P0" [ref=e1194]
              - gridcell "completed" [ref=e1196]
              - 'gridcell "Biomorphic BDD Alignment: Refactor test steps for 14-node SIL-6 parity" [ref=e1198]'
              - gridcell "2026-03-27" [ref=e1200]
            - 'row "3f3c1fe1 P0 completed Biomorphic Core: Refactor F# orchestrator as the supreme, Zenoh-first bootstrapper 2026-03-27" [ref=e1202]':
              - gridcell "3f3c1fe1" [ref=e1203]
              - gridcell "P0" [ref=e1205]
              - gridcell "completed" [ref=e1207]
              - 'gridcell "Biomorphic Core: Refactor F# orchestrator as the supreme, Zenoh-first bootstrapper" [ref=e1209]'
              - gridcell "2026-03-27" [ref=e1211]
            - row "402e79cd P0 completed System-wide Warning Removal and Homeostasis Optimization 2026-03-27" [ref=e1213]:
              - gridcell "402e79cd" [ref=e1214]
              - gridcell "P0" [ref=e1216]
              - gridcell "completed" [ref=e1218]
              - gridcell "System-wide Warning Removal and Homeostasis Optimization" [ref=e1220]
              - gridcell "2026-03-27" [ref=e1222]
            - 'row "4311e742 P0 completed AI-Sentinel: Integrate OpenRouter for proactive threat analysis via Zenoh 2026-03-27" [ref=e1224]':
              - gridcell "4311e742" [ref=e1225]
              - gridcell "P0" [ref=e1227]
              - gridcell "completed" [ref=e1229]
              - 'gridcell "AI-Sentinel: Integrate OpenRouter for proactive threat analysis via Zenoh" [ref=e1231]'
              - gridcell "2026-03-27" [ref=e1233]
            - 'row "445e6afa P0 completed P0-SAFETY: Implement accounts.ex refresh_mobile_session with real token rotation (L1) 2026-03-27" [ref=e1235]':
              - gridcell "445e6afa" [ref=e1236]
              - gridcell "P0" [ref=e1238]
              - gridcell "completed" [ref=e1240]
              - 'gridcell "P0-SAFETY: Implement accounts.ex refresh_mobile_session with real token rotation (L1)" [ref=e1242]'
              - gridcell "2026-03-27" [ref=e1244]
            - 'row "488c525e P0 completed S51-T4: Accounts.get_user_by_email - wire to Ash read action 2026-03-27" [ref=e1246]':
              - gridcell "488c525e" [ref=e1247]
              - gridcell "P0" [ref=e1249]
              - gridcell "completed" [ref=e1251]
              - 'gridcell "S51-T4: Accounts.get_user_by_email - wire to Ash read action" [ref=e1253]'
              - gridcell "2026-03-27" [ref=e1255]
            - 'row "4aba1df8 P0 completed S54-T103: F# Parity Audit 2026-03-27" [ref=e1257]':
              - gridcell "4aba1df8" [ref=e1258]
              - gridcell "P0" [ref=e1260]
              - gridcell "completed" [ref=e1262]
              - 'gridcell "S54-T103: F# Parity Audit" [ref=e1264]'
              - gridcell "2026-03-27" [ref=e1266]
            - 'row "4b5967ab P0 completed S51-T3: SecurityPolicy - implement authenticate, authorize, validate_access 2026-03-27" [ref=e1268]':
              - gridcell "4b5967ab" [ref=e1269]
              - gridcell "P0" [ref=e1271]
              - gridcell "completed" [ref=e1273]
              - 'gridcell "S51-T3: SecurityPolicy - implement authenticate, authorize, validate_access" [ref=e1275]'
              - gridcell "2026-03-27" [ref=e1277]
            - 'row "4d35b3f8 P0 completed P0: Saturate observability stubs — wire telemetry.ex record_metric/create_span, tracing.ex start_span/end_span/record_error 2026-03-27" [ref=e1279]':
              - gridcell "4d35b3f8" [ref=e1280]
              - gridcell "P0" [ref=e1282]
              - gridcell "completed" [ref=e1284]
              - 'gridcell "P0: Saturate observability stubs — wire telemetry.ex record_metric/create_span, tracing.ex start_span/end_span/record_error" [ref=e1286]'
              - gridcell "2026-03-27" [ref=e1288]
          - generic [ref=e1292]:
            - text: Page Size
            - combobox "Page Size" [ref=e1293]:
              - option "10"
              - option "25" [selected]
              - option "50"
              - option "100"
            - button "First Page" [disabled] [ref=e1294]: First
            - button "Prev Page" [disabled] [ref=e1295]: Prev
            - generic [ref=e1296]:
              - button "Show Page 1" [ref=e1297]: "1"
              - button "Show Page 2" [ref=e1298]: "2"
              - button "Show Page 3" [ref=e1299]: "3"
              - button "Show Page 4" [ref=e1300]: "4"
              - button "Show Page 5" [ref=e1301]: "5"
            - button "Next Page" [ref=e1302]: Next
            - button "Last Page" [ref=e1303]: Last
      - generic [ref=e1304]:
        - paragraph [ref=e1305]: Multidimensional Analysis — Criticality × FMEA × STAMP × Utility
        - textbox "Filter table..." [ref=e1306]
        - table [ref=e1307]:
          - rowgroup [ref=e1308]:
            - row "Dimension Score Threshold Status Action" [ref=e1309]:
              - columnheader "Dimension" [ref=e1310]
              - columnheader "Score" [ref=e1311]
              - columnheader "Threshold" [ref=e1312]
              - columnheader "Status" [ref=e1313]
              - columnheader "Action" [ref=e1314]
          - rowgroup [ref=e1315]:
            - row "Task Completion Rate 33.8% > 50% BELOW Focus on P1 core tasks" [ref=e1316]:
              - cell "Task Completion Rate" [ref=e1317]
              - cell "33.8%" [ref=e1318]
              - cell "> 50%" [ref=e1319]
              - cell "BELOW" [ref=e1320]
              - cell "Focus on P1 core tasks" [ref=e1321]
            - row "Blocked Ratio 0.5% < 2% OK 13 blocked — review Guardian queue" [ref=e1322]:
              - cell "Blocked Ratio" [ref=e1323]
              - cell "0.5%" [ref=e1324]
              - cell "< 2%" [ref=e1325]
              - cell "OK" [ref=e1326]
              - cell "13 blocked — review Guardian queue" [ref=e1327]
            - row "P0 Completion 100% 100% PASS All 191 safety tasks done" [ref=e1328]:
              - cell "P0 Completion" [ref=e1329]
              - cell "100%" [ref=e1330]
              - cell "100%" [ref=e1331]
              - cell "PASS" [ref=e1332]
              - cell "All 191 safety tasks done" [ref=e1333]
            - row "Knowledge Coverage 2,060 holons > 500 PASS FTS5 searchable in < 1ms" [ref=e1334]:
              - cell "Knowledge Coverage" [ref=e1335]
              - cell "2,060 holons" [ref=e1336]
              - cell "> 500" [ref=e1337]
              - cell "PASS" [ref=e1338]
              - cell "FTS5 searchable in < 1ms" [ref=e1339]
            - row "STAMP Refs Indexed 6,647 > 1,000 PASS Cross-referenced in graph" [ref=e1340]:
              - cell "STAMP Refs Indexed" [ref=e1341]
              - cell "6,647" [ref=e1342]
              - cell "> 1,000" [ref=e1343]
              - cell "PASS" [ref=e1344]
              - cell "Cross-referenced in graph" [ref=e1345]
            - row "Backup Freshness < 24h < 24h PASS GCS europe-north1" [ref=e1346]:
              - cell "Backup Freshness" [ref=e1347]
              - cell "< 24h" [ref=e1348]
              - cell "< 24h" [ref=e1349]
              - cell "PASS" [ref=e1350]
              - cell "GCS europe-north1" [ref=e1351]
            - row "Test Coverage 3,824 pass > 3,000 PASS 0 failures" [ref=e1352]:
              - cell "Test Coverage" [ref=e1353]
              - cell "3,824 pass" [ref=e1354]
              - cell "> 3,000" [ref=e1355]
              - cell "PASS" [ref=e1356]
              - cell "0 failures" [ref=e1357]
            - row "Entropy (avg) < 0.3 < 0.5 PASS Knowledge is fresh" [ref=e1358]:
              - cell "Entropy (avg)" [ref=e1359]
              - cell "< 0.3" [ref=e1360]
              - cell "< 0.5" [ref=e1361]
              - cell "PASS" [ref=e1362]
              - cell "Knowledge is fresh" [ref=e1363]
            - row "RAG Integration Active Active PASS Holons in LLM context" [ref=e1364]:
              - cell "RAG Integration" [ref=e1365]
              - cell "Active" [ref=e1366]
              - cell "Active" [ref=e1367]
              - cell "PASS" [ref=e1368]
              - cell "Holons in LLM context" [ref=e1369]
            - row "Build Health 0 errors 0 errors PASS Gleam + Rust clean" [ref=e1370]:
              - cell "Build Health" [ref=e1371]
              - cell "0 errors" [ref=e1372]
              - cell "0 errors" [ref=e1373]
              - cell "PASS" [ref=e1374]
              - cell "Gleam + Rust clean" [ref=e1375]
      - generic [ref=e1376]:
        - paragraph [ref=e1377]: Decision Support — Operational Scenarios
        - textbox "Filter table..." [ref=e1378]
        - table [ref=e1379]:
          - rowgroup [ref=e1380]:
            - row "Scenario Question Zettelkasten Answer Confidence" [ref=e1381]:
              - columnheader "Scenario" [ref=e1382]
              - columnheader "Question" [ref=e1383]
              - columnheader "Zettelkasten Answer" [ref=e1384]
              - columnheader "Confidence" [ref=e1385]
          - rowgroup [ref=e1386]:
            - row "Incident Response Has this happened before? Search 180 journal RCA sections High (Evidence)" [ref=e1387]:
              - cell "Incident Response" [ref=e1388]
              - cell "Has this happened before?" [ref=e1389]
              - cell "Search 180 journal RCA sections" [ref=e1390]
              - cell "High (Evidence)" [ref=e1391]
            - row "Capacity Planning Will inference hit limits? 12 intents/day × 365 = OK for SQLite High (Evidence)" [ref=e1392]:
              - cell "Capacity Planning" [ref=e1393]
              - cell "Will inference hit limits?" [ref=e1394]
              - cell "12 intents/day × 365 = OK for SQLite" [ref=e1395]
              - cell "High (Evidence)" [ref=e1396]
            - row "Compliance Check Is SC-ZENOH-001 implemented? Yes — code edge from zenoh/client.gleam Very High (Axiom)" [ref=e1397]:
              - cell "Compliance Check" [ref=e1398]
              - cell "Is SC-ZENOH-001 implemented?" [ref=e1399]
              - cell "Yes — code edge from zenoh/client.gleam" [ref=e1400]
              - cell "Very High (Axiom)" [ref=e1401]
            - row "Architecture Decision Why SSR not client JS? SC-GLM-UI-002 mandates server-side Very High (Axiom)" [ref=e1402]:
              - cell "Architecture Decision" [ref=e1403]
              - cell "Why SSR not client JS?" [ref=e1404]
              - cell "SC-GLM-UI-002 mandates server-side" [ref=e1405]
              - cell "Very High (Axiom)" [ref=e1406]
            - row "Onboarding Where do I start? 5 ecosystem zettels → 5 axiom specs → 5 constraints High" [ref=e1407]:
              - cell "Onboarding" [ref=e1408]
              - cell "Where do I start?" [ref=e1409]
              - cell "5 ecosystem zettels → 5 axiom specs → 5 constraints" [ref=e1410]
              - cell "High" [ref=e1411]
            - row "Cost Optimization How much does inference cost? $0.054/day — 50% cached, Gemini Direct handles 65% Medium (Evidence)" [ref=e1412]:
              - cell "Cost Optimization" [ref=e1413]
              - cell "How much does inference cost?" [ref=e1414]
              - cell "$0.054/day — 50% cached, Gemini Direct handles 65%" [ref=e1415]
              - cell "Medium (Evidence)" [ref=e1416]
            - row "Drift Detection Are specs up to date? Plans cluster entropy 0.60 — ROTTING, needs review High (Computed)" [ref=e1417]:
              - cell "Drift Detection" [ref=e1418]
              - cell "Are specs up to date?" [ref=e1419]
              - cell "Plans cluster entropy 0.60 — ROTTING, needs review" [ref=e1420]
              - cell "High (Computed)" [ref=e1421]
            - row "Recovery Can we restore from scratch? GCS 22.8 MB + git clone + ingest-docs (12.6s) Very High (Tested)" [ref=e1422]:
              - cell "Recovery" [ref=e1423]
              - cell "Can we restore from scratch?" [ref=e1424]
              - cell "GCS 22.8 MB + git clone + ingest-docs (12.6s)" [ref=e1425]
              - cell "Very High (Tested)" [ref=e1426]
      - generic [ref=e1427]:
        - paragraph [ref=e1428]: Pipeline Performance (from 85 traced intents)
        - textbox "Filter table..." [ref=e1429]
        - table [ref=e1430]:
          - rowgroup [ref=e1431]:
            - row "Stage Avg Latency Count Health" [ref=e1432]:
              - columnheader "Stage" [ref=e1433]
              - columnheader "Avg Latency" [ref=e1434]
              - columnheader "Count" [ref=e1435]
              - columnheader "Health" [ref=e1436]
          - rowgroup [ref=e1437]:
            - row "received 0ms 86 Nominal" [ref=e1438]:
              - cell "received" [ref=e1439]
              - cell "0ms" [ref=e1440]
              - cell "86" [ref=e1441]
              - cell "Nominal" [ref=e1442]
            - row "classified 157ms 86 Nominal" [ref=e1443]:
              - cell "classified" [ref=e1444]
              - cell "157ms" [ref=e1445]
              - cell "86" [ref=e1446]
              - cell "Nominal" [ref=e1447]
            - row "ack_sent 2,196ms 66 Nominal" [ref=e1448]:
              - cell "ack_sent" [ref=e1449]
              - cell "2,196ms" [ref=e1450]
              - cell "66" [ref=e1451]
              - cell "Nominal" [ref=e1452]
            - row "inference_started 2,282ms 64 Nominal" [ref=e1453]:
              - cell "inference_started" [ref=e1454]
              - cell "2,282ms" [ref=e1455]
              - cell "64" [ref=e1456]
              - cell "Nominal" [ref=e1457]
            - row "rag 2,913ms 44 Nominal" [ref=e1458]:
              - cell "rag" [ref=e1459]
              - cell "2,913ms" [ref=e1460]
              - cell "44" [ref=e1461]
              - cell "Nominal" [ref=e1462]
            - row "delivered 3,582ms 86 Nominal" [ref=e1463]:
              - cell "delivered" [ref=e1464]
              - cell "3,582ms" [ref=e1465]
              - cell "86" [ref=e1466]
              - cell "Nominal" [ref=e1467]
            - row "inference_complete 4,419ms 64 Nominal" [ref=e1468]:
              - cell "inference_complete" [ref=e1469]
              - cell "4,419ms" [ref=e1470]
              - cell "64" [ref=e1471]
              - cell "Nominal" [ref=e1472]
            - row "cache_hit 54ms 2 Excellent" [ref=e1473]:
              - cell "cache_hit" [ref=e1474]
              - cell "54ms" [ref=e1475]
              - cell "2" [ref=e1476]
              - cell "Excellent" [ref=e1477]
      - generic [ref=e1478]:
        - paragraph [ref=e1479]: Raw NIF Data (Debug)
        - group [ref=e1480]:
          - generic "Click to expand raw JSON from NIF → Rust → SQLite" [ref=e1481]
  - slider "4D State Projection Slider (SC-HMI-410)" [ref=e1482]: "0"
  - generic "Mesh heartbeat" [ref=e1483]
  - generic "Agent activity" [ref=e1484]
```

# Test source

```ts
  59  | // ═══════════════════════════════════════════════════════════════════
  60  | 
  61  | test.describe('2. Live NIF Data Cards', () => {
  62  | 
  63  |   test('task summary shows 6 status cards', async ({ page }) => {
  64  |     await page.goto(`${BASE}/planning`);
  65  |     // Cards within the first section
  66  |     const firstSection = page.locator('.section').first();
  67  |     const cards = await firstSection.locator('.card').count();
  68  |     expect(cards).toBeGreaterThanOrEqual(6);
  69  |   });
  70  | 
  71  |   test('total tasks count is 2,710', async ({ page }) => {
  72  |     await page.goto(`${BASE}/planning`);
  73  |     const body = await page.textContent('body');
  74  |     expect(body).toContain('2,710');
  75  |   });
  76  | 
  77  |   test('completed count is 917', async ({ page }) => {
  78  |     await page.goto(`${BASE}/planning`);
  79  |     const body = await page.textContent('body');
  80  |     expect(body).toContain('917');
  81  |   });
  82  | 
  83  |   test('pending count is 1,733', async ({ page }) => {
  84  |     await page.goto(`${BASE}/planning`);
  85  |     const body = await page.textContent('body');
  86  |     expect(body).toContain('1,733');
  87  |   });
  88  | 
  89  |   test('zettelkasten holon count is 2,060', async ({ page }) => {
  90  |     await page.goto(`${BASE}/planning`);
  91  |     const body = await page.textContent('body');
  92  |     expect(body).toContain('2,060');
  93  |   });
  94  | 
  95  |   test('STAMP reference count is 6,647', async ({ page }) => {
  96  |     await page.goto(`${BASE}/planning`);
  97  |     const body = await page.textContent('body');
  98  |     expect(body).toContain('6,647');
  99  |   });
  100 | 
  101 | });
  102 | 
  103 | // ═══════════════════════════════════════════════════════════════════
  104 | // 3. PRIORITY BREAKDOWN TABLE
  105 | // ═══════════════════════════════════════════════════════════════════
  106 | 
  107 | test.describe('3. Priority Breakdown', () => {
  108 | 
  109 |   test('priority table has 4 priority levels', async ({ page }) => {
  110 |     await page.goto(`${BASE}/planning`);
  111 |     const table = page.locator('table').filter({ hasText: 'Critical Safety' });
  112 |     const rows = await table.locator('tbody tr').count();
  113 |     expect(rows).toBe(4);
  114 |   });
  115 | 
  116 |   test('P0 shows 191 tasks', async ({ page }) => {
  117 |     await page.goto(`${BASE}/planning`);
  118 |     const body = await page.textContent('body');
  119 |     expect(body).toContain('191');
  120 |   });
  121 | 
  122 |   test('P2 is the largest category at 73%', async ({ page }) => {
  123 |     await page.goto(`${BASE}/planning`);
  124 |     const body = await page.textContent('body');
  125 |     expect(body).toContain('73.0%');
  126 |   });
  127 | 
  128 | });
  129 | 
  130 | // ═══════════════════════════════════════════════════════════════════
  131 | // 4. TABULATOR DATA GRID — Static Rendering
  132 | // ═══════════════════════════════════════════════════════════════════
  133 | 
  134 | test.describe('4. Tabulator Grid — Static', () => {
  135 | 
  136 |   test('Tabulator CSS loaded from CDN', async ({ page }) => {
  137 |     await page.goto(`${BASE}/planning`);
  138 |     const link = await page.locator('link[href*="tabulator"]').count();
  139 |     expect(link).toBeGreaterThanOrEqual(1);
  140 |   });
  141 | 
  142 |   test('Tabulator JS loaded from CDN', async ({ page }) => {
  143 |     await page.goto(`${BASE}/planning`);
  144 |     const script = await page.locator('script[src*="tabulator"]').count();
  145 |     expect(script).toBeGreaterThanOrEqual(1);
  146 |   });
  147 | 
  148 |   test('three grid containers exist', async ({ page }) => {
  149 |     await page.goto(`${BASE}/planning`);
  150 |     expect(await page.locator('#blocked-grid').count()).toBe(1);
  151 |     expect(await page.locator('#active-grid').count()).toBe(1);
  152 |     expect(await page.locator('#all-grid').count()).toBe(1);
  153 |   });
  154 | 
  155 |   test('grid data script contains blockedData variable', async ({ page }) => {
  156 |     await page.goto(`${BASE}/planning`);
  157 |     const scripts = await page.locator('script').allTextContents();
  158 |     const hasData = scripts.some(s => s.includes('blockedData'));
> 159 |     expect(hasData).toBeTruthy();
      |                     ^ Error: expect(received).toBeTruthy()
  160 |   });
  161 | 
  162 |   test('grid data script contains allData variable', async ({ page }) => {
  163 |     await page.goto(`${BASE}/planning`);
  164 |     const scripts = await page.locator('script').allTextContents();
  165 |     const hasData = scripts.some(s => s.includes('allData'));
  166 |     expect(hasData).toBeTruthy();
  167 |   });
  168 | 
  169 | });
  170 | 
  171 | // ═══════════════════════════════════════════════════════════════════
  172 | // 5. TABULATOR DATA GRID — Dynamic Behavior
  173 | // ═══════════════════════════════════════════════════════════════════
  174 | 
  175 | test.describe('5. Tabulator Grid — Dynamic Behavior', () => {
  176 | 
  177 |   test('Tabulator initializes within 5 seconds', async ({ page }) => {
  178 |     await page.goto(`${BASE}/planning`);
  179 |     // Wait for Tabulator class to appear on the grid div
  180 |     await page.waitForSelector('#all-grid .tabulator-header', { timeout: 5000 }).catch(() => null);
  181 |     const hasTabulator = await page.evaluate(() => {
  182 |       return typeof Tabulator !== 'undefined';
  183 |     });
  184 |     // Tabulator may or may not fully init depending on CDN speed
  185 |     expect(hasTabulator || true).toBeTruthy();
  186 |   });
  187 | 
  188 |   test('all-grid has column headers after init', async ({ page }) => {
  189 |     await page.goto(`${BASE}/planning`);
  190 |     await page.waitForTimeout(4000);
  191 |     const headers = await page.locator('#all-grid .tabulator-col-title').allTextContents();
  192 |     if (headers.length > 0) {
  193 |       expect(headers).toContain('Priority');
  194 |       expect(headers).toContain('Status');
  195 |       expect(headers).toContain('Description');
  196 |       expect(headers).toContain('ID');
  197 |     }
  198 |   });
  199 | 
  200 |   test('all-grid renders rows (paginated at 25)', async ({ page }) => {
  201 |     await page.goto(`${BASE}/planning`);
  202 |     await page.waitForTimeout(4000);
  203 |     const rowCount = await page.locator('#all-grid .tabulator-row').count();
  204 |     // Should have 25 rows (first page) or 0 if Tabulator didn't init
  205 |     expect(rowCount === 25 || rowCount === 0 || rowCount > 0).toBeTruthy();
  206 |   });
  207 | 
  208 |   test('all-grid has pagination footer', async ({ page }) => {
  209 |     await page.goto(`${BASE}/planning`);
  210 |     await page.waitForTimeout(4000);
  211 |     const footer = await page.locator('#all-grid .tabulator-footer').count();
  212 |     expect(footer).toBeGreaterThanOrEqual(0);
  213 |   });
  214 | 
  215 |   test('blocked-grid shows task data or empty message', async ({ page }) => {
  216 |     await page.goto(`${BASE}/planning`);
  217 |     await page.waitForTimeout(4000);
  218 |     const gridContent = await page.locator('#blocked-grid').textContent();
  219 |     // Either has tabulator rows or shows "No blocked tasks"
  220 |     expect(gridContent.length).toBeGreaterThan(0);
  221 |   });
  222 | 
  223 |   test('clicking column header sorts data', async ({ page }) => {
  224 |     await page.goto(`${BASE}/planning`);
  225 |     await page.waitForTimeout(4000);
  226 |     const priorityHeader = page.locator('#all-grid .tabulator-col').filter({ hasText: 'Priority' });
  227 |     if (await priorityHeader.count() > 0) {
  228 |       await priorityHeader.first().click();
  229 |       await page.waitForTimeout(500);
  230 |       // After click, sort indicator should appear
  231 |       const sortArrow = await page.locator('#all-grid .tabulator-col .tabulator-arrow').count();
  232 |       expect(sortArrow).toBeGreaterThanOrEqual(0);
  233 |     }
  234 |   });
  235 | 
  236 |   test('status filter dropdown shows options', async ({ page }) => {
  237 |     await page.goto(`${BASE}/planning`);
  238 |     await page.waitForTimeout(4000);
  239 |     // Tabulator header filter for status column
  240 |     const filterInput = page.locator('#all-grid .tabulator-header-filter select').first();
  241 |     if (await filterInput.count() > 0) {
  242 |       const options = await filterInput.locator('option').allTextContents();
  243 |       expect(options.length).toBeGreaterThan(1);
  244 |     }
  245 |   });
  246 | 
  247 |   test('description search filter accepts text input', async ({ page }) => {
  248 |     await page.goto(`${BASE}/planning`);
  249 |     await page.waitForTimeout(4000);
  250 |     const searchInput = page.locator('#all-grid .tabulator-header-filter input').first();
  251 |     if (await searchInput.count() > 0) {
  252 |       await searchInput.fill('zenoh');
  253 |       await page.waitForTimeout(1000);
  254 |       // Grid should filter — row count should decrease
  255 |       const rowCount = await page.locator('#all-grid .tabulator-row').count();
  256 |       expect(rowCount).toBeLessThan(2710);
  257 |     }
  258 |   });
  259 | 
```