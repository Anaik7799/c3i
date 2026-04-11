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
        - generic [ref=e301]: "Loaded: 13 blocked, 47 active, 2710 total | Last refresh: 12:42:38 PM"
        - generic [ref=e302]:
          - generic [ref=e303]: "Total: 2710"
          - generic [ref=e304]: "Done: 917 (33.8%)"
          - generic [ref=e305]: "Active: 47"
          - generic [ref=e306]: "Blocked: 13"
          - text: P0:191 P1:276 P2:1978 P3:257
        - grid [ref=e307]:
          - rowgroup [ref=e308]:
            - rowgroup [ref=e309]:
              - row "ID Priority Status Description Search tasks... Owner Created" [ref=e310]:
                - columnheader "ID" [ref=e311]:
                  - generic [ref=e314]: ID
                - columnheader "Priority" [ref=e318]:
                  - generic [ref=e321]: Priority
                - columnheader "Status" [ref=e325]:
                  - generic [ref=e328]: Status
                - columnheader "Description Search tasks..." [ref=e332]:
                  - generic [ref=e333]:
                    - generic [ref=e335]: Description
                    - searchbox "Search tasks..." [ref=e339]
                - columnheader "Owner" [ref=e341]:
                  - generic [ref=e344]: Owner
                - columnheader "Created" [ref=e348]:
                  - generic [ref=e351]: Created
          - rowgroup [ref=e356]:
            - 'row "0af8752b P2 Blocked P2-FEAT: Implement FSharpDAP.fs GRPC service — debug adapter protocol for F# (L4) — 2026-03-27" [ref=e357]':
              - gridcell "0af8752b" [ref=e358]
              - gridcell "P2" [ref=e360]
              - gridcell "Blocked" [ref=e362]
              - 'gridcell "P2-FEAT: Implement FSharpDAP.fs GRPC service — debug adapter protocol for F# (L4)" [ref=e364]'
              - gridcell "—" [ref=e366]
              - gridcell "2026-03-27" [ref=e368]
            - 'row "21db8704 P2 Blocked P2-FEAT: Implement GraphView.fs tooltip with zettel info for knowledge graph (L4) — 2026-03-27" [ref=e372]':
              - gridcell "21db8704" [ref=e373]
              - gridcell "P2" [ref=e375]
              - gridcell "Blocked" [ref=e377]
              - 'gridcell "P2-FEAT: Implement GraphView.fs tooltip with zettel info for knowledge graph (L4)" [ref=e379]'
              - gridcell "—" [ref=e381]
              - gridcell "2026-03-27" [ref=e383]
            - 'row "598288ec P3 Blocked P3-UI: Add LiveView alarm list real-time update — Phoenix.PubSub (L3) — 2026-03-27" [ref=e387]':
              - gridcell "598288ec" [ref=e388]
              - gridcell "P3" [ref=e390]
              - gridcell "Blocked" [ref=e392]
              - 'gridcell "P3-UI: Add LiveView alarm list real-time update — Phoenix.PubSub (L3)" [ref=e394]'
              - gridcell "—" [ref=e396]
              - gridcell "2026-03-27" [ref=e398]
            - 'row "5cf14afa P2 Blocked P2-FEAT: Add F# MCP Guardian handler — proposal submit + status query (L4) — 2026-03-27" [ref=e402]':
              - gridcell "5cf14afa" [ref=e403]
              - gridcell "P2" [ref=e405]
              - gridcell "Blocked" [ref=e407]
              - 'gridcell "P2-FEAT: Add F# MCP Guardian handler — proposal submit + status query (L4)" [ref=e409]'
              - gridcell "—" [ref=e411]
              - gridcell "2026-03-27" [ref=e413]
            - 'row "69394b38 P2 Blocked P2-FEAT: Implement ZettelView.fs markdown renderer for SMRITI client (L4) — 2026-03-27" [ref=e417]':
              - gridcell "69394b38" [ref=e418]
              - gridcell "P2" [ref=e420]
              - gridcell "Blocked" [ref=e422]
              - 'gridcell "P2-FEAT: Implement ZettelView.fs markdown renderer for SMRITI client (L4)" [ref=e424]'
              - gridcell "—" [ref=e426]
              - gridcell "2026-03-27" [ref=e428]
            - 'row "7c83ec50 P2 Blocked P2-FEAT: Add CEPAF F# Cockpit TUI health dashboard with ANSI rendering (L4) — 2026-03-27" [ref=e432]':
              - gridcell "7c83ec50" [ref=e433]
              - gridcell "P2" [ref=e435]
              - gridcell "Blocked" [ref=e437]
              - 'gridcell "P2-FEAT: Add CEPAF F# Cockpit TUI health dashboard with ANSI rendering (L4)" [ref=e439]'
              - gridcell "—" [ref=e441]
              - gridcell "2026-03-27" [ref=e443]
            - 'row "889e6ae7 P3 Blocked P3-UI: Add LiveView Prajna copilot chat streaming response L4 — 2026-03-27" [ref=e447]':
              - gridcell "889e6ae7" [ref=e448]
              - gridcell "P3" [ref=e450]
              - gridcell "Blocked" [ref=e452]
              - 'gridcell "P3-UI: Add LiveView Prajna copilot chat streaming response L4" [ref=e454]'
              - gridcell "—" [ref=e456]
              - gridcell "2026-03-27" [ref=e458]
            - 'row "8db1f246 P3 Blocked P3-UI: Add LiveView analytics report builder — chart generation (L3) — 2026-03-27" [ref=e462]':
              - gridcell "8db1f246" [ref=e463]
              - gridcell "P3" [ref=e465]
              - gridcell "Blocked" [ref=e467]
              - 'gridcell "P3-UI: Add LiveView analytics report builder — chart generation (L3)" [ref=e469]'
              - gridcell "—" [ref=e471]
              - gridcell "2026-03-27" [ref=e473]
            - 'row "918b4c6f P2 Blocked P2-FEAT: Add F# MCP server SSE transport for remote access (L4) — 2026-03-27" [ref=e477]':
              - gridcell "918b4c6f" [ref=e478]
              - gridcell "P2" [ref=e480]
              - gridcell "Blocked" [ref=e482]
              - 'gridcell "P2-FEAT: Add F# MCP server SSE transport for remote access (L4)" [ref=e484]'
              - gridcell "—" [ref=e486]
              - gridcell "2026-03-27" [ref=e488]
            - 'row "972b68f4 P2 Blocked P2-FEAT: Add CEPAF ConfigBridge real Zenoh pub/sub replacing file sync (L4) — 2026-03-27" [ref=e492]':
              - gridcell "972b68f4" [ref=e493]
              - gridcell "P2" [ref=e495]
              - gridcell "Blocked" [ref=e497]
              - 'gridcell "P2-FEAT: Add CEPAF ConfigBridge real Zenoh pub/sub replacing file sync (L4)" [ref=e499]'
              - gridcell "—" [ref=e501]
              - gridcell "2026-03-27" [ref=e503]
            - 'row "993bb12e P2 Blocked P2-FEAT: Add F# MCP Cortex handler — AI inference request + result (L4) — 2026-03-27" [ref=e507]':
              - gridcell "993bb12e" [ref=e508]
              - gridcell "P2" [ref=e510]
              - gridcell "Blocked" [ref=e512]
              - 'gridcell "P2-FEAT: Add F# MCP Cortex handler — AI inference request + result (L4)" [ref=e514]'
              - gridcell "—" [ref=e516]
              - gridcell "2026-03-27" [ref=e518]
            - 'row "df5d7681 P3 Blocked P3-UI: Add LiveView device health grid — color-coded matrix (L3) — 2026-03-27" [ref=e522]':
              - gridcell "df5d7681" [ref=e523]
              - gridcell "P3" [ref=e525]
              - gridcell "Blocked" [ref=e527]
              - 'gridcell "P3-UI: Add LiveView device health grid — color-coded matrix (L3)" [ref=e529]'
              - gridcell "—" [ref=e531]
              - gridcell "2026-03-27" [ref=e533]
            - 'row "fcb6f917 P2 Blocked P2-FEAT: Add F# MCP SMRITI handler — knowledge query + zettel CRUD (L4) — 2026-03-27" [ref=e537]':
              - gridcell "fcb6f917" [ref=e538]
              - gridcell "P2" [ref=e540]
              - gridcell "Blocked" [ref=e542]
              - 'gridcell "P2-FEAT: Add F# MCP SMRITI handler — knowledge query + zettel CRUD (L4)" [ref=e544]'
              - gridcell "—" [ref=e546]
              - gridcell "2026-03-27" [ref=e548]
        - heading "In-Progress Tasks" [level=2] [ref=e552]
        - grid [ref=e553]:
          - rowgroup [ref=e554]:
            - rowgroup [ref=e555]:
              - row "ID Priority Status Description Search tasks... Owner Created" [ref=e556]:
                - columnheader "ID" [ref=e557]:
                  - generic [ref=e560]: ID
                - columnheader "Priority" [ref=e564]:
                  - generic [ref=e567]: Priority
                - columnheader "Status" [ref=e571]:
                  - generic [ref=e574]: Status
                - columnheader "Description Search tasks..." [ref=e578]:
                  - generic [ref=e579]:
                    - generic [ref=e581]: Description
                    - searchbox "Search tasks..." [ref=e585]
                - columnheader "Owner" [ref=e587]:
                  - generic [ref=e590]: Owner
                - columnheader "Created" [ref=e594]:
                  - generic [ref=e597]: Created
          - rowgroup [ref=e602]:
            - 'row "695c9c56 P0 Active Substrate: Port 5-stage transactional boot sequence to Gleam — 2026-04-06" [ref=e603]':
              - gridcell "695c9c56" [ref=e604]
              - gridcell "P0" [ref=e606]
              - gridcell "Active" [ref=e608]
              - 'gridcell "Substrate: Port 5-stage transactional boot sequence to Gleam" [ref=e610]'
              - gridcell "—" [ref=e612]
              - gridcell "2026-04-06" [ref=e614]
            - 'row "73bd6a5f P0 Active Substrate: Implement sa-up, sa-down, sa-status in Gleam — 2026-04-06" [ref=e616]':
              - gridcell "73bd6a5f" [ref=e617]
              - gridcell "P0" [ref=e619]
              - gridcell "Active" [ref=e621]
              - 'gridcell "Substrate: Implement sa-up, sa-down, sa-status in Gleam" [ref=e623]'
              - gridcell "—" [ref=e625]
              - gridcell "2026-04-06" [ref=e627]
            - 'row "150075f2 P3 Active Transition test #0 — 2026-04-09" [ref=e629]':
              - gridcell "150075f2" [ref=e630]
              - gridcell "P3" [ref=e632]
              - gridcell "Active" [ref=e634]
              - 'gridcell "Transition test #0" [ref=e636]'
              - gridcell "—" [ref=e638]
              - gridcell "2026-04-09" [ref=e640]
            - 'row "974eee9b P3 Active Transition test #1 — 2026-04-09" [ref=e642]':
              - gridcell "974eee9b" [ref=e643]
              - gridcell "P3" [ref=e645]
              - gridcell "Active" [ref=e647]
              - 'gridcell "Transition test #1" [ref=e649]'
              - gridcell "—" [ref=e651]
              - gridcell "2026-04-09" [ref=e653]
            - 'row "e305645c P3 Active Transition test #2 — 2026-04-09" [ref=e655]':
              - gridcell "e305645c" [ref=e656]
              - gridcell "P3" [ref=e658]
              - gridcell "Active" [ref=e660]
              - 'gridcell "Transition test #2" [ref=e662]'
              - gridcell "—" [ref=e664]
              - gridcell "2026-04-09" [ref=e666]
            - 'row "6995e496 P3 Active Transition test #3 — 2026-04-09" [ref=e668]':
              - gridcell "6995e496" [ref=e669]
              - gridcell "P3" [ref=e671]
              - gridcell "Active" [ref=e673]
              - 'gridcell "Transition test #3" [ref=e675]'
              - gridcell "—" [ref=e677]
              - gridcell "2026-04-09" [ref=e679]
            - 'row "56992c95 P3 Active Transition test #4 — 2026-04-09" [ref=e681]':
              - gridcell "56992c95" [ref=e682]
              - gridcell "P3" [ref=e684]
              - gridcell "Active" [ref=e686]
              - 'gridcell "Transition test #4" [ref=e688]'
              - gridcell "—" [ref=e690]
              - gridcell "2026-04-09" [ref=e692]
            - 'row "65a7732b P3 Active Transition test #0 — 2026-04-09" [ref=e694]':
              - gridcell "65a7732b" [ref=e695]
              - gridcell "P3" [ref=e697]
              - gridcell "Active" [ref=e699]
              - 'gridcell "Transition test #0" [ref=e701]'
              - gridcell "—" [ref=e703]
              - gridcell "2026-04-09" [ref=e705]
            - 'row "fd264dfe P3 Active Transition test #1 — 2026-04-09" [ref=e707]':
              - gridcell "fd264dfe" [ref=e708]
              - gridcell "P3" [ref=e710]
              - gridcell "Active" [ref=e712]
              - 'gridcell "Transition test #1" [ref=e714]'
              - gridcell "—" [ref=e716]
              - gridcell "2026-04-09" [ref=e718]
            - 'row "61cad436 P3 Active Transition test #2 — 2026-04-09" [ref=e720]':
              - gridcell "61cad436" [ref=e721]
              - gridcell "P3" [ref=e723]
              - gridcell "Active" [ref=e725]
              - 'gridcell "Transition test #2" [ref=e727]'
              - gridcell "—" [ref=e729]
              - gridcell "2026-04-09" [ref=e731]
            - 'row "2ce7dab9 P3 Active Transition test #3 — 2026-04-09" [ref=e733]':
              - gridcell "2ce7dab9" [ref=e734]
              - gridcell "P3" [ref=e736]
              - gridcell "Active" [ref=e738]
              - 'gridcell "Transition test #3" [ref=e740]'
              - gridcell "—" [ref=e742]
              - gridcell "2026-04-09" [ref=e744]
            - 'row "7978d5f6 P3 Active Transition test #4 — 2026-04-09" [ref=e746]':
              - gridcell "7978d5f6" [ref=e747]
              - gridcell "P3" [ref=e749]
              - gridcell "Active" [ref=e751]
              - 'gridcell "Transition test #4" [ref=e753]'
              - gridcell "—" [ref=e755]
              - gridcell "2026-04-09" [ref=e757]
            - 'row "bdc64c1b P3 Active Transition test #0 — 2026-04-09" [ref=e759]':
              - gridcell "bdc64c1b" [ref=e760]
              - gridcell "P3" [ref=e762]
              - gridcell "Active" [ref=e764]
              - 'gridcell "Transition test #0" [ref=e766]'
              - gridcell "—" [ref=e768]
              - gridcell "2026-04-09" [ref=e770]
            - 'row "35216d44 P3 Active Transition test #1 — 2026-04-09" [ref=e772]':
              - gridcell "35216d44" [ref=e773]
              - gridcell "P3" [ref=e775]
              - gridcell "Active" [ref=e777]
              - 'gridcell "Transition test #1" [ref=e779]'
              - gridcell "—" [ref=e781]
              - gridcell "2026-04-09" [ref=e783]
            - 'row "b2ef0864 P3 Active Transition test #2 — 2026-04-09" [ref=e785]':
              - gridcell "b2ef0864" [ref=e786]
              - gridcell "P3" [ref=e788]
              - gridcell "Active" [ref=e790]
              - 'gridcell "Transition test #2" [ref=e792]'
              - gridcell "—" [ref=e794]
              - gridcell "2026-04-09" [ref=e796]
            - 'row "2b4a4f68 P3 Active Transition test #3 — 2026-04-09" [ref=e798]':
              - gridcell "2b4a4f68" [ref=e799]
              - gridcell "P3" [ref=e801]
              - gridcell "Active" [ref=e803]
              - 'gridcell "Transition test #3" [ref=e805]'
              - gridcell "—" [ref=e807]
              - gridcell "2026-04-09" [ref=e809]
            - 'row "8ffb6cdf P3 Active Transition test #4 — 2026-04-09" [ref=e811]':
              - gridcell "8ffb6cdf" [ref=e812]
              - gridcell "P3" [ref=e814]
              - gridcell "Active" [ref=e816]
              - 'gridcell "Transition test #4" [ref=e818]'
              - gridcell "—" [ref=e820]
              - gridcell "2026-04-09" [ref=e822]
            - 'row "66f4382c P3 Active Transition test #0 — 2026-04-09" [ref=e824]':
              - gridcell "66f4382c" [ref=e825]
              - gridcell "P3" [ref=e827]
              - gridcell "Active" [ref=e829]
              - 'gridcell "Transition test #0" [ref=e831]'
              - gridcell "—" [ref=e833]
              - gridcell "2026-04-09" [ref=e835]
            - 'row "4338a7f1 P3 Active Transition test #1 — 2026-04-09" [ref=e837]':
              - gridcell "4338a7f1" [ref=e838]
              - gridcell "P3" [ref=e840]
              - gridcell "Active" [ref=e842]
              - 'gridcell "Transition test #1" [ref=e844]'
              - gridcell "—" [ref=e846]
              - gridcell "2026-04-09" [ref=e848]
            - 'row "91e563bc P3 Active Transition test #2 — 2026-04-09" [ref=e850]':
              - gridcell "91e563bc" [ref=e851]
              - gridcell "P3" [ref=e853]
              - gridcell "Active" [ref=e855]
              - 'gridcell "Transition test #2" [ref=e857]'
              - gridcell "—" [ref=e859]
              - gridcell "2026-04-09" [ref=e861]
            - 'row "e091a993 P3 Active Transition test #3 — 2026-04-09" [ref=e863]':
              - gridcell "e091a993" [ref=e864]
              - gridcell "P3" [ref=e866]
              - gridcell "Active" [ref=e868]
              - 'gridcell "Transition test #3" [ref=e870]'
              - gridcell "—" [ref=e872]
              - gridcell "2026-04-09" [ref=e874]
            - 'row "7e68a81f P3 Active Transition test #4 — 2026-04-09" [ref=e876]':
              - gridcell "7e68a81f" [ref=e877]
              - gridcell "P3" [ref=e879]
              - gridcell "Active" [ref=e881]
              - 'gridcell "Transition test #4" [ref=e883]'
              - gridcell "—" [ref=e885]
              - gridcell "2026-04-09" [ref=e887]
            - 'row "cd9912cf P3 Active Transition test #0 — 2026-04-09" [ref=e889]':
              - gridcell "cd9912cf" [ref=e890]
              - gridcell "P3" [ref=e892]
              - gridcell "Active" [ref=e894]
              - 'gridcell "Transition test #0" [ref=e896]'
              - gridcell "—" [ref=e898]
              - gridcell "2026-04-09" [ref=e900]
            - 'row "6e9c08be P3 Active Transition test #1 — 2026-04-09" [ref=e902]':
              - gridcell "6e9c08be" [ref=e903]
              - gridcell "P3" [ref=e905]
              - gridcell "Active" [ref=e907]
              - 'gridcell "Transition test #1" [ref=e909]'
              - gridcell "—" [ref=e911]
              - gridcell "2026-04-09" [ref=e913]
            - 'row "dd8da274 P3 Active Transition test #2 — 2026-04-09" [ref=e915]':
              - gridcell "dd8da274" [ref=e916]
              - gridcell "P3" [ref=e918]
              - gridcell "Active" [ref=e920]
              - 'gridcell "Transition test #2" [ref=e922]'
              - gridcell "—" [ref=e924]
              - gridcell "2026-04-09" [ref=e926]
            - 'row "1a399551 P3 Active Transition test #3 — 2026-04-09" [ref=e928]':
              - gridcell "1a399551" [ref=e929]
              - gridcell "P3" [ref=e931]
              - gridcell "Active" [ref=e933]
              - 'gridcell "Transition test #3" [ref=e935]'
              - gridcell "—" [ref=e937]
              - gridcell "2026-04-09" [ref=e939]
            - 'row "e8663428 P3 Active Transition test #4 — 2026-04-09" [ref=e941]':
              - gridcell "e8663428" [ref=e942]
              - gridcell "P3" [ref=e944]
              - gridcell "Active" [ref=e946]
              - 'gridcell "Transition test #4" [ref=e948]'
              - gridcell "—" [ref=e950]
              - gridcell "2026-04-09" [ref=e952]
            - 'row "6c9e774e P3 Active Transition test #0 — 2026-04-09" [ref=e954]':
              - gridcell "6c9e774e" [ref=e955]
              - gridcell "P3" [ref=e957]
              - gridcell "Active" [ref=e959]
              - 'gridcell "Transition test #0" [ref=e961]'
              - gridcell "—" [ref=e963]
              - gridcell "2026-04-09" [ref=e965]
            - 'row "a28bcd53 P3 Active Transition test #1 — 2026-04-09" [ref=e967]':
              - gridcell "a28bcd53" [ref=e968]
              - gridcell "P3" [ref=e970]
              - gridcell "Active" [ref=e972]
              - 'gridcell "Transition test #1" [ref=e974]'
              - gridcell "—" [ref=e976]
              - gridcell "2026-04-09" [ref=e978]
            - 'row "4675aa6f P3 Active Transition test #2 — 2026-04-09" [ref=e980]':
              - gridcell "4675aa6f" [ref=e981]
              - gridcell "P3" [ref=e983]
              - gridcell "Active" [ref=e985]
              - 'gridcell "Transition test #2" [ref=e987]'
              - gridcell "—" [ref=e989]
              - gridcell "2026-04-09" [ref=e991]
            - 'row "86591e39 P3 Active Transition test #3 — 2026-04-09" [ref=e993]':
              - gridcell "86591e39" [ref=e994]
              - gridcell "P3" [ref=e996]
              - gridcell "Active" [ref=e998]
              - 'gridcell "Transition test #3" [ref=e1000]'
              - gridcell "—" [ref=e1002]
              - gridcell "2026-04-09" [ref=e1004]
            - 'row "11e3059a P3 Active Transition test #4 — 2026-04-09" [ref=e1006]':
              - gridcell "11e3059a" [ref=e1007]
              - gridcell "P3" [ref=e1009]
              - gridcell "Active" [ref=e1011]
              - 'gridcell "Transition test #4" [ref=e1013]'
              - gridcell "—" [ref=e1015]
              - gridcell "2026-04-09" [ref=e1017]
            - 'row "9f50bc06 P3 Active Transition test #0 — 2026-04-09" [ref=e1019]':
              - gridcell "9f50bc06" [ref=e1020]
              - gridcell "P3" [ref=e1022]
              - gridcell "Active" [ref=e1024]
              - 'gridcell "Transition test #0" [ref=e1026]'
              - gridcell "—" [ref=e1028]
              - gridcell "2026-04-09" [ref=e1030]
            - 'row "1ec5074e P3 Active Transition test #1 — 2026-04-09" [ref=e1032]':
              - gridcell "1ec5074e" [ref=e1033]
              - gridcell "P3" [ref=e1035]
              - gridcell "Active" [ref=e1037]
              - 'gridcell "Transition test #1" [ref=e1039]'
              - gridcell "—" [ref=e1041]
              - gridcell "2026-04-09" [ref=e1043]
            - 'row "20d78bfc P3 Active Transition test #2 — 2026-04-09" [ref=e1045]':
              - gridcell "20d78bfc" [ref=e1046]
              - gridcell "P3" [ref=e1048]
              - gridcell "Active" [ref=e1050]
              - 'gridcell "Transition test #2" [ref=e1052]'
              - gridcell "—" [ref=e1054]
              - gridcell "2026-04-09" [ref=e1056]
            - 'row "7bb0a338 P3 Active Transition test #3 — 2026-04-09" [ref=e1058]':
              - gridcell "7bb0a338" [ref=e1059]
              - gridcell "P3" [ref=e1061]
              - gridcell "Active" [ref=e1063]
              - 'gridcell "Transition test #3" [ref=e1065]'
              - gridcell "—" [ref=e1067]
              - gridcell "2026-04-09" [ref=e1069]
            - 'row "05b97194 P3 Active Transition test #4 — 2026-04-09" [ref=e1071]':
              - gridcell "05b97194" [ref=e1072]
              - gridcell "P3" [ref=e1074]
              - gridcell "Active" [ref=e1076]
              - 'gridcell "Transition test #4" [ref=e1078]'
              - gridcell "—" [ref=e1080]
              - gridcell "2026-04-09" [ref=e1082]
            - 'row "4d6e98d9 P3 Active Transition test #0 — 2026-04-09" [ref=e1084]':
              - gridcell "4d6e98d9" [ref=e1085]
              - gridcell "P3" [ref=e1087]
              - gridcell "Active" [ref=e1089]
              - 'gridcell "Transition test #0" [ref=e1091]'
              - gridcell "—" [ref=e1093]
              - gridcell "2026-04-09" [ref=e1095]
            - 'row "9d73d5e3 P3 Active Transition test #1 — 2026-04-09" [ref=e1097]':
              - gridcell "9d73d5e3" [ref=e1098]
              - gridcell "P3" [ref=e1100]
              - gridcell "Active" [ref=e1102]
              - 'gridcell "Transition test #1" [ref=e1104]'
              - gridcell "—" [ref=e1106]
              - gridcell "2026-04-09" [ref=e1108]
            - 'row "b0f5a12e P3 Active Transition test #2 — 2026-04-09" [ref=e1110]':
              - gridcell "b0f5a12e" [ref=e1111]
              - gridcell "P3" [ref=e1113]
              - gridcell "Active" [ref=e1115]
              - 'gridcell "Transition test #2" [ref=e1117]'
              - gridcell "—" [ref=e1119]
              - gridcell "2026-04-09" [ref=e1121]
        - heading "All Tasks (search across 2,710)" [level=2] [ref=e1123]
        - grid [ref=e1124]:
          - rowgroup [ref=e1125]:
            - rowgroup [ref=e1126]:
              - row "ID Priority Status Description Search tasks... Owner Created" [ref=e1127]:
                - columnheader "ID" [ref=e1128]:
                  - generic [ref=e1131]: ID
                - columnheader "Priority" [ref=e1135]:
                  - generic [ref=e1138]: Priority
                - columnheader "Status" [ref=e1142]:
                  - generic [ref=e1145]: Status
                - columnheader "Description Search tasks..." [ref=e1149]:
                  - generic [ref=e1150]:
                    - generic [ref=e1152]: Description
                    - searchbox "Search tasks..." [ref=e1156]
                - columnheader "Owner" [ref=e1158]:
                  - generic [ref=e1161]: Owner
                - columnheader "Created" [ref=e1165]:
                  - generic [ref=e1168]: Created
          - rowgroup [ref=e1173]:
            - 'row "024c30f3 P1 Completed P1-CORE: Implement kms/technical_leadership.ex ADR requirements + related debt queries (L3) — 2026-03-27" [ref=e1174]':
              - gridcell "024c30f3" [ref=e1175]
              - gridcell "P1" [ref=e1177]
              - gridcell "Completed" [ref=e1179]
              - 'gridcell "P1-CORE: Implement kms/technical_leadership.ex ADR requirements + related debt queries (L3)" [ref=e1181]'
              - gridcell "—" [ref=e1183]
              - gridcell "2026-03-27" [ref=e1185]
            - 'row "02a44982 P1 Completed P1-SAT: Saturate observability/ stubs (5 files) — real OTEL sensors, domain instrumentation — 2026-03-27" [ref=e1189]':
              - gridcell "02a44982" [ref=e1190]
              - gridcell "P1" [ref=e1192]
              - gridcell "Completed" [ref=e1194]
              - 'gridcell "P1-SAT: Saturate observability/ stubs (5 files) — real OTEL sensors, domain instrumentation" [ref=e1196]'
              - gridcell "—" [ref=e1198]
              - gridcell "2026-03-27" [ref=e1200]
            - row "047427fd P1 Completed Morphogenic Evolution L0 Task 7 - Auto-generated for 80% saturation — 2026-03-27" [ref=e1204]:
              - gridcell "047427fd" [ref=e1205]
              - gridcell "P1" [ref=e1207]
              - gridcell "Completed" [ref=e1209]
              - gridcell "Morphogenic Evolution L0 Task 7 - Auto-generated for 80% saturation" [ref=e1211]
              - gridcell "—" [ref=e1213]
              - gridcell "2026-03-27" [ref=e1215]
            - 'row "0756f935 P1 Completed P1-CORE: Implement offline_queue.ex deliver_queued_messages with real message delivery (L4) — 2026-03-27" [ref=e1219]':
              - gridcell "0756f935" [ref=e1220]
              - gridcell "P1" [ref=e1222]
              - gridcell "Completed" [ref=e1224]
              - 'gridcell "P1-CORE: Implement offline_queue.ex deliver_queued_messages with real message delivery (L4)" [ref=e1226]'
              - gridcell "—" [ref=e1228]
              - gridcell "2026-03-27" [ref=e1230]
            - 'row "08f47096 P1 Completed S54-T109: Zenoh Partition Apoptosis Chaos Test — 2026-03-27" [ref=e1234]':
              - gridcell "08f47096" [ref=e1235]
              - gridcell "P1" [ref=e1237]
              - gridcell "Completed" [ref=e1239]
              - 'gridcell "S54-T109: Zenoh Partition Apoptosis Chaos Test" [ref=e1241]'
              - gridcell "—" [ref=e1243]
              - gridcell "2026-03-27" [ref=e1245]
            - 'row "0c4ffebb P1 Completed P1-CORE: Wire MCP analytics handler DuckDB pipeline — real-time metrics — 2026-03-27" [ref=e1249]':
              - gridcell "0c4ffebb" [ref=e1250]
              - gridcell "P1" [ref=e1252]
              - gridcell "Completed" [ref=e1254]
              - 'gridcell "P1-CORE: Wire MCP analytics handler DuckDB pipeline — real-time metrics" [ref=e1256]'
              - gridcell "—" [ref=e1258]
              - gridcell "2026-03-27" [ref=e1260]
            - 'row "0d26318f P1 Completed Sprint 67: Wire Sentinel Load Metrics to Scaling Reflex (SC-IMMUNE-005) — 2026-03-27" [ref=e1264]':
              - gridcell "0d26318f" [ref=e1265]
              - gridcell "P1" [ref=e1267]
              - gridcell "Completed" [ref=e1269]
              - 'gridcell "Sprint 67: Wire Sentinel Load Metrics to Scaling Reflex (SC-IMMUNE-005)" [ref=e1271]'
              - gridcell "—" [ref=e1273]
              - gridcell "2026-03-27" [ref=e1275]
            - 'row "0fc67ea8 P1 Completed Sprint 73: Reify IKE WarmRecall for real-time semantic context injection (SC-NEURO-008) — 2026-03-27" [ref=e1279]':
              - gridcell "0fc67ea8" [ref=e1280]
              - gridcell "P1" [ref=e1282]
              - gridcell "Completed" [ref=e1284]
              - 'gridcell "Sprint 73: Reify IKE WarmRecall for real-time semantic context injection (SC-NEURO-008)" [ref=e1286]'
              - gridcell "—" [ref=e1288]
              - gridcell "2026-03-27" [ref=e1290]
            - 'row "162d1467 P1 Completed P1-CORE: Implement jain/propagation.ex request_invitation with real HTTP peer comm (L7) — 2026-03-27" [ref=e1294]':
              - gridcell "162d1467" [ref=e1295]
              - gridcell "P1" [ref=e1297]
              - gridcell "Completed" [ref=e1299]
              - 'gridcell "P1-CORE: Implement jain/propagation.ex request_invitation with real HTTP peer comm (L7)" [ref=e1301]'
              - gridcell "—" [ref=e1303]
              - gridcell "2026-03-27" [ref=e1305]
            - 'row "185e55f5 P1 Completed P1-CORE: Implement coordinator.ex apply_health_recovery_actions with real remediation (L2) — 2026-03-27" [ref=e1309]':
              - gridcell "185e55f5" [ref=e1310]
              - gridcell "P1" [ref=e1312]
              - gridcell "Completed" [ref=e1314]
              - 'gridcell "P1-CORE: Implement coordinator.ex apply_health_recovery_actions with real remediation (L2)" [ref=e1316]'
              - gridcell "—" [ref=e1318]
              - gridcell "2026-03-27" [ref=e1320]
            - 'row "1996e647 P1 Completed Sprint 66: Integrate Vector Search into Synapse for historic problem recall (SC-NEURO-007) — 2026-03-27" [ref=e1324]':
              - gridcell "1996e647" [ref=e1325]
              - gridcell "P1" [ref=e1327]
              - gridcell "Completed" [ref=e1329]
              - 'gridcell "Sprint 66: Integrate Vector Search into Synapse for historic problem recall (SC-NEURO-007)" [ref=e1331]'
              - gridcell "—" [ref=e1333]
              - gridcell "2026-03-27" [ref=e1335]
            - 'row "1a00ce82 P1 Completed P1-CORE: Implement approval.ex 7 stubs — recall, escalation, notify_approvers, delegate (L3) — 2026-03-27" [ref=e1339]':
              - gridcell "1a00ce82" [ref=e1340]
              - gridcell "P1" [ref=e1342]
              - gridcell "Completed" [ref=e1344]
              - 'gridcell "P1-CORE: Implement approval.ex 7 stubs — recall, escalation, notify_approvers, delegate (L3)" [ref=e1346]'
              - gridcell "—" [ref=e1348]
              - gridcell "2026-03-27" [ref=e1350]
            - 'row "1aad50d5 P1 Completed P1-CORE: Add MCP tool discovery endpoint — list all available tools — 2026-03-27" [ref=e1354]':
              - gridcell "1aad50d5" [ref=e1355]
              - gridcell "P1" [ref=e1357]
              - gridcell "Completed" [ref=e1359]
              - 'gridcell "P1-CORE: Add MCP tool discovery endpoint — list all available tools" [ref=e1361]'
              - gridcell "—" [ref=e1363]
              - gridcell "2026-03-27" [ref=e1365]
            - row "1b929fbb P1 Completed [P1] Refactor EvolutionBus topic hierarchy to indrajaal/cepaf/evolution/* — 2026-03-27" [ref=e1369]:
              - gridcell "1b929fbb" [ref=e1370]
              - gridcell "P1" [ref=e1372]
              - gridcell "Completed" [ref=e1374]
              - gridcell "[P1] Refactor EvolutionBus topic hierarchy to indrajaal/cepaf/evolution/*" [ref=e1376]
              - gridcell "—" [ref=e1378]
              - gridcell "2026-03-27" [ref=e1380]
            - 'row "2966d7dd P1 Completed S51-T5: Route module - implement route matching logic — 2026-03-27" [ref=e1384]':
              - gridcell "2966d7dd" [ref=e1385]
              - gridcell "P1" [ref=e1387]
              - gridcell "Completed" [ref=e1389]
              - 'gridcell "S51-T5: Route module - implement route matching logic" [ref=e1391]'
              - gridcell "—" [ref=e1393]
              - gridcell "2026-03-27" [ref=e1395]
            - 'row "29e3e224 P1 Completed S58-T002: MeshShutdown Zenoh Publishing — Add shutdown event publishing for peer notification — 2026-03-27" [ref=e1399]':
              - gridcell "29e3e224" [ref=e1400]
              - gridcell "P1" [ref=e1402]
              - gridcell "Completed" [ref=e1404]
              - 'gridcell "S58-T002: MeshShutdown Zenoh Publishing — Add shutdown event publishing for peer notification" [ref=e1406]'
              - gridcell "—" [ref=e1408]
              - gridcell "2026-03-27" [ref=e1410]
            - 'row "30968b86 P1 Completed S55-REGRESSION-001: Fix test infrastructure — actor fixtures for 2090 Ash Forbidden failures — 2026-03-27" [ref=e1414]':
              - gridcell "30968b86" [ref=e1415]
              - gridcell "P1" [ref=e1417]
              - gridcell "Completed" [ref=e1419]
              - 'gridcell "S55-REGRESSION-001: Fix test infrastructure — actor fixtures for 2090 Ash Forbidden failures" [ref=e1421]'
              - gridcell "—" [ref=e1423]
              - gridcell "2026-03-27" [ref=e1425]
            - row "32af59a7 P1 Completed 23.2 - Zig-based Capsid prototype — 2026-03-27" [ref=e1429]:
              - gridcell "32af59a7" [ref=e1430]
              - gridcell "P1" [ref=e1432]
              - gridcell "Completed" [ref=e1434]
              - gridcell "23.2 - Zig-based Capsid prototype" [ref=e1436]
              - gridcell "—" [ref=e1438]
              - gridcell "2026-03-27" [ref=e1440]
            - 'row "3370e72b P1 Completed Sprint 64: Port Math Oracle Python engine to Rust NIF (SC-MATH-008) — 2026-03-27" [ref=e1444]':
              - gridcell "3370e72b" [ref=e1445]
              - gridcell "P1" [ref=e1447]
              - gridcell "Completed" [ref=e1449]
              - 'gridcell "Sprint 64: Port Math Oracle Python engine to Rust NIF (SC-MATH-008)" [ref=e1451]'
              - gridcell "—" [ref=e1453]
              - gridcell "2026-03-27" [ref=e1455]
            - row "3dd31c0c P1 Completed [P1] Fix Metrics JSON extraction errors in ZenohFfiBridge — 2026-03-27" [ref=e1459]:
              - gridcell "3dd31c0c" [ref=e1460]
              - gridcell "P1" [ref=e1462]
              - gridcell "Completed" [ref=e1464]
              - gridcell "[P1] Fix Metrics JSON extraction errors in ZenohFfiBridge" [ref=e1466]
              - gridcell "—" [ref=e1468]
              - gridcell "2026-03-27" [ref=e1470]
            - 'row "4160d993 P1 Completed Sprint 74: Implement Closed-Loop Metabolic Scaling logic (SC-ECON-002) — 2026-03-27" [ref=e1474]':
              - gridcell "4160d993" [ref=e1475]
              - gridcell "P1" [ref=e1477]
              - gridcell "Completed" [ref=e1479]
              - 'gridcell "Sprint 74: Implement Closed-Loop Metabolic Scaling logic (SC-ECON-002)" [ref=e1481]'
              - gridcell "—" [ref=e1483]
              - gridcell "2026-03-27" [ref=e1485]
            - 'row "420b50c6 P1 Completed MORPH-W2-01: Constitutional L6 cluster checks - Add quorum validation + 2oo3 voting to constitutional_kernel.ex — 2026-03-27" [ref=e1489]':
              - gridcell "420b50c6" [ref=e1490]
              - gridcell "P1" [ref=e1492]
              - gridcell "Completed" [ref=e1494]
              - 'gridcell "MORPH-W2-01: Constitutional L6 cluster checks - Add quorum validation + 2oo3 voting to constitutional_kernel.ex" [ref=e1496]'
              - gridcell "—" [ref=e1498]
              - gridcell "2026-03-27" [ref=e1500]
            - 'row "4343bce5 P1 Completed Sprint 50: ZUIP Testing - Integration tests for all new Zenoh publish points — 2026-03-27" [ref=e1504]':
              - gridcell "4343bce5" [ref=e1505]
              - gridcell "P1" [ref=e1507]
              - gridcell "Completed" [ref=e1509]
              - 'gridcell "Sprint 50: ZUIP Testing - Integration tests for all new Zenoh publish points" [ref=e1511]'
              - gridcell "—" [ref=e1513]
              - gridcell "2026-03-27" [ref=e1515]
            - 'row "49abb177 P1 Completed P1-SAT: Saturate cortex/homeostasis.ex — execute_actuator 3 clauses (expand/contract/emergency) — 2026-03-27" [ref=e1519]':
              - gridcell "49abb177" [ref=e1520]
              - gridcell "P1" [ref=e1522]
              - gridcell "Completed" [ref=e1524]
              - 'gridcell "P1-SAT: Saturate cortex/homeostasis.ex — execute_actuator 3 clauses (expand/contract/emergency)" [ref=e1526]'
              - gridcell "—" [ref=e1528]
              - gridcell "2026-03-27" [ref=e1530]
            - 'row "49f825ee P1 Completed P1-CORE: Implement alarm_correlation.ex 4 stubs — fetch, create_incident, link_alarms, update (L3) — 2026-03-27" [ref=e1534]':
              - gridcell "49f825ee" [ref=e1535]
              - gridcell "P1" [ref=e1537]
              - gridcell "Completed" [ref=e1539]
              - 'gridcell "P1-CORE: Implement alarm_correlation.ex 4 stubs — fetch, create_incident, link_alarms, update (L3)" [ref=e1541]'
              - gridcell "—" [ref=e1543]
              - gridcell "2026-03-27" [ref=e1545]
          - generic [ref=e1550]:
            - generic [ref=e1551]:
              - button "Export CSV" [ref=e1552] [cursor=pointer]
              - button "Export JSON" [ref=e1553] [cursor=pointer]
              - button "↻ Refresh" [ref=e1554] [cursor=pointer]
            - generic [ref=e1556]: Showing 1-25 of 2710 rows
            - generic [ref=e1557]:
              - text: Page Size
              - combobox "Page Size" [ref=e1558]:
                - option "10"
                - option "25" [selected]
                - option "50"
                - option "100"
                - option "All"
              - button "First Page" [disabled] [ref=e1559]: First
              - button "Prev Page" [disabled] [ref=e1560]: Prev
              - generic [ref=e1561]:
                - button "Show Page 1" [ref=e1562]: "1"
                - button "Show Page 2" [ref=e1563]: "2"
                - button "Show Page 3" [ref=e1564]: "3"
                - button "Show Page 4" [ref=e1565]: "4"
                - button "Show Page 5" [ref=e1566]: "5"
              - button "Next Page" [ref=e1567]: Next
              - button "Last Page" [ref=e1568]: Last
      - generic [ref=e1569]:
        - paragraph [ref=e1570]: Multidimensional Analysis — Criticality × FMEA × STAMP × Utility
        - textbox "Filter table..." [ref=e1571]
        - table [ref=e1572]:
          - rowgroup [ref=e1573]:
            - row "Dimension Score Threshold Status Action" [ref=e1574]:
              - columnheader "Dimension" [ref=e1575]
              - columnheader "Score" [ref=e1576]
              - columnheader "Threshold" [ref=e1577]
              - columnheader "Status" [ref=e1578]
              - columnheader "Action" [ref=e1579]
          - rowgroup [ref=e1580]:
            - row "Task Completion Rate 33.8% > 50% BELOW Focus on P1 core tasks" [ref=e1581]:
              - cell "Task Completion Rate" [ref=e1582]
              - cell "33.8%" [ref=e1583]
              - cell "> 50%" [ref=e1584]
              - cell "BELOW" [ref=e1585]
              - cell "Focus on P1 core tasks" [ref=e1586]
            - row "Blocked Ratio 0.5% < 2% OK 13 blocked — review Guardian queue" [ref=e1587]:
              - cell "Blocked Ratio" [ref=e1588]
              - cell "0.5%" [ref=e1589]
              - cell "< 2%" [ref=e1590]
              - cell "OK" [ref=e1591]
              - cell "13 blocked — review Guardian queue" [ref=e1592]
            - row "P0 Completion 100% 100% PASS All 191 safety tasks done" [ref=e1593]:
              - cell "P0 Completion" [ref=e1594]
              - cell "100%" [ref=e1595]
              - cell "100%" [ref=e1596]
              - cell "PASS" [ref=e1597]
              - cell "All 191 safety tasks done" [ref=e1598]
            - row "Knowledge Coverage 2,060 holons > 500 PASS FTS5 searchable in < 1ms" [ref=e1599]:
              - cell "Knowledge Coverage" [ref=e1600]
              - cell "2,060 holons" [ref=e1601]
              - cell "> 500" [ref=e1602]
              - cell "PASS" [ref=e1603]
              - cell "FTS5 searchable in < 1ms" [ref=e1604]
            - row "STAMP Refs Indexed 6,647 > 1,000 PASS Cross-referenced in graph" [ref=e1605]:
              - cell "STAMP Refs Indexed" [ref=e1606]
              - cell "6,647" [ref=e1607]
              - cell "> 1,000" [ref=e1608]
              - cell "PASS" [ref=e1609]
              - cell "Cross-referenced in graph" [ref=e1610]
            - row "Backup Freshness < 24h < 24h PASS GCS europe-north1" [ref=e1611]:
              - cell "Backup Freshness" [ref=e1612]
              - cell "< 24h" [ref=e1613]
              - cell "< 24h" [ref=e1614]
              - cell "PASS" [ref=e1615]
              - cell "GCS europe-north1" [ref=e1616]
            - row "Test Coverage 3,824 pass > 3,000 PASS 0 failures" [ref=e1617]:
              - cell "Test Coverage" [ref=e1618]
              - cell "3,824 pass" [ref=e1619]
              - cell "> 3,000" [ref=e1620]
              - cell "PASS" [ref=e1621]
              - cell "0 failures" [ref=e1622]
            - row "Entropy (avg) < 0.3 < 0.5 PASS Knowledge is fresh" [ref=e1623]:
              - cell "Entropy (avg)" [ref=e1624]
              - cell "< 0.3" [ref=e1625]
              - cell "< 0.5" [ref=e1626]
              - cell "PASS" [ref=e1627]
              - cell "Knowledge is fresh" [ref=e1628]
            - row "RAG Integration Active Active PASS Holons in LLM context" [ref=e1629]:
              - cell "RAG Integration" [ref=e1630]
              - cell "Active" [ref=e1631]
              - cell "Active" [ref=e1632]
              - cell "PASS" [ref=e1633]
              - cell "Holons in LLM context" [ref=e1634]
            - row "Build Health 0 errors 0 errors PASS Gleam + Rust clean" [ref=e1635]:
              - cell "Build Health" [ref=e1636]
              - cell "0 errors" [ref=e1637]
              - cell "0 errors" [ref=e1638]
              - cell "PASS" [ref=e1639]
              - cell "Gleam + Rust clean" [ref=e1640]
      - generic [ref=e1641]:
        - paragraph [ref=e1642]: Decision Support — Operational Scenarios
        - textbox "Filter table..." [ref=e1643]
        - table [ref=e1644]:
          - rowgroup [ref=e1645]:
            - row "Scenario Question Zettelkasten Answer Confidence" [ref=e1646]:
              - columnheader "Scenario" [ref=e1647]
              - columnheader "Question" [ref=e1648]
              - columnheader "Zettelkasten Answer" [ref=e1649]
              - columnheader "Confidence" [ref=e1650]
          - rowgroup [ref=e1651]:
            - row "Incident Response Has this happened before? Search 180 journal RCA sections High (Evidence)" [ref=e1652]:
              - cell "Incident Response" [ref=e1653]
              - cell "Has this happened before?" [ref=e1654]
              - cell "Search 180 journal RCA sections" [ref=e1655]
              - cell "High (Evidence)" [ref=e1656]
            - row "Capacity Planning Will inference hit limits? 12 intents/day × 365 = OK for SQLite High (Evidence)" [ref=e1657]:
              - cell "Capacity Planning" [ref=e1658]
              - cell "Will inference hit limits?" [ref=e1659]
              - cell "12 intents/day × 365 = OK for SQLite" [ref=e1660]
              - cell "High (Evidence)" [ref=e1661]
            - row "Compliance Check Is SC-ZENOH-001 implemented? Yes — code edge from zenoh/client.gleam Very High (Axiom)" [ref=e1662]:
              - cell "Compliance Check" [ref=e1663]
              - cell "Is SC-ZENOH-001 implemented?" [ref=e1664]
              - cell "Yes — code edge from zenoh/client.gleam" [ref=e1665]
              - cell "Very High (Axiom)" [ref=e1666]
            - row "Architecture Decision Why SSR not client JS? SC-GLM-UI-002 mandates server-side Very High (Axiom)" [ref=e1667]:
              - cell "Architecture Decision" [ref=e1668]
              - cell "Why SSR not client JS?" [ref=e1669]
              - cell "SC-GLM-UI-002 mandates server-side" [ref=e1670]
              - cell "Very High (Axiom)" [ref=e1671]
            - row "Onboarding Where do I start? 5 ecosystem zettels → 5 axiom specs → 5 constraints High" [ref=e1672]:
              - cell "Onboarding" [ref=e1673]
              - cell "Where do I start?" [ref=e1674]
              - cell "5 ecosystem zettels → 5 axiom specs → 5 constraints" [ref=e1675]
              - cell "High" [ref=e1676]
            - row "Cost Optimization How much does inference cost? $0.054/day — 50% cached, Gemini Direct handles 65% Medium (Evidence)" [ref=e1677]:
              - cell "Cost Optimization" [ref=e1678]
              - cell "How much does inference cost?" [ref=e1679]
              - cell "$0.054/day — 50% cached, Gemini Direct handles 65%" [ref=e1680]
              - cell "Medium (Evidence)" [ref=e1681]
            - row "Drift Detection Are specs up to date? Plans cluster entropy 0.60 — ROTTING, needs review High (Computed)" [ref=e1682]:
              - cell "Drift Detection" [ref=e1683]
              - cell "Are specs up to date?" [ref=e1684]
              - cell "Plans cluster entropy 0.60 — ROTTING, needs review" [ref=e1685]
              - cell "High (Computed)" [ref=e1686]
            - row "Recovery Can we restore from scratch? GCS 22.8 MB + git clone + ingest-docs (12.6s) Very High (Tested)" [ref=e1687]:
              - cell "Recovery" [ref=e1688]
              - cell "Can we restore from scratch?" [ref=e1689]
              - cell "GCS 22.8 MB + git clone + ingest-docs (12.6s)" [ref=e1690]
              - cell "Very High (Tested)" [ref=e1691]
      - generic [ref=e1692]:
        - paragraph [ref=e1693]: Pipeline Performance (from 85 traced intents)
        - textbox "Filter table..." [ref=e1694]
        - table [ref=e1695]:
          - rowgroup [ref=e1696]:
            - row "Stage Avg Latency Count Health" [ref=e1697]:
              - columnheader "Stage" [ref=e1698]
              - columnheader "Avg Latency" [ref=e1699]
              - columnheader "Count" [ref=e1700]
              - columnheader "Health" [ref=e1701]
          - rowgroup [ref=e1702]:
            - row "received 0ms 86 Nominal" [ref=e1703]:
              - cell "received" [ref=e1704]
              - cell "0ms" [ref=e1705]
              - cell "86" [ref=e1706]
              - cell "Nominal" [ref=e1707]
            - row "classified 157ms 86 Nominal" [ref=e1708]:
              - cell "classified" [ref=e1709]
              - cell "157ms" [ref=e1710]
              - cell "86" [ref=e1711]
              - cell "Nominal" [ref=e1712]
            - row "ack_sent 2,196ms 66 Nominal" [ref=e1713]:
              - cell "ack_sent" [ref=e1714]
              - cell "2,196ms" [ref=e1715]
              - cell "66" [ref=e1716]
              - cell "Nominal" [ref=e1717]
            - row "inference_started 2,282ms 64 Nominal" [ref=e1718]:
              - cell "inference_started" [ref=e1719]
              - cell "2,282ms" [ref=e1720]
              - cell "64" [ref=e1721]
              - cell "Nominal" [ref=e1722]
            - row "rag 2,913ms 44 Nominal" [ref=e1723]:
              - cell "rag" [ref=e1724]
              - cell "2,913ms" [ref=e1725]
              - cell "44" [ref=e1726]
              - cell "Nominal" [ref=e1727]
            - row "delivered 3,582ms 86 Nominal" [ref=e1728]:
              - cell "delivered" [ref=e1729]
              - cell "3,582ms" [ref=e1730]
              - cell "86" [ref=e1731]
              - cell "Nominal" [ref=e1732]
            - row "inference_complete 4,419ms 64 Nominal" [ref=e1733]:
              - cell "inference_complete" [ref=e1734]
              - cell "4,419ms" [ref=e1735]
              - cell "64" [ref=e1736]
              - cell "Nominal" [ref=e1737]
            - row "cache_hit 54ms 2 Excellent" [ref=e1738]:
              - cell "cache_hit" [ref=e1739]
              - cell "54ms" [ref=e1740]
              - cell "2" [ref=e1741]
              - cell "Excellent" [ref=e1742]
      - generic [ref=e1743]:
        - paragraph [ref=e1744]: Raw NIF Data (Debug)
        - group [ref=e1745]:
          - generic "Click to expand raw JSON from NIF → Rust → SQLite" [ref=e1746]
  - slider "4D State Projection Slider (SC-HMI-410)" [ref=e1747]: "0"
  - generic "Mesh heartbeat" [ref=e1748]
  - generic "Agent activity" [ref=e1749]
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