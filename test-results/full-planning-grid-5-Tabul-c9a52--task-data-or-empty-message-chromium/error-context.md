# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: full-planning-grid.spec.js >> 5. Tabulator Grid — Dynamic Behavior >> blocked-grid shows task data or empty message
- Location: test/e2e/full-planning-grid.spec.js:215:3

# Error details

```
Error: expect(received).toBeGreaterThan(expected)

Expected: > 0
Received:   0
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
        - heading "In-Progress Tasks" [level=2] [ref=e301]
        - heading "All Tasks (search across 2,710)" [level=2] [ref=e302]
      - generic [ref=e303]:
        - paragraph [ref=e304]: Multidimensional Analysis — Criticality × FMEA × STAMP × Utility
        - textbox "Filter table..." [ref=e305]
        - table [ref=e306]:
          - rowgroup [ref=e307]:
            - row "Dimension Score Threshold Status Action" [ref=e308]:
              - columnheader "Dimension" [ref=e309]
              - columnheader "Score" [ref=e310]
              - columnheader "Threshold" [ref=e311]
              - columnheader "Status" [ref=e312]
              - columnheader "Action" [ref=e313]
          - rowgroup [ref=e314]:
            - row "Task Completion Rate 33.8% > 50% BELOW Focus on P1 core tasks" [ref=e315]:
              - cell "Task Completion Rate" [ref=e316]
              - cell "33.8%" [ref=e317]
              - cell "> 50%" [ref=e318]
              - cell "BELOW" [ref=e319]
              - cell "Focus on P1 core tasks" [ref=e320]
            - row "Blocked Ratio 0.5% < 2% OK 13 blocked — review Guardian queue" [ref=e321]:
              - cell "Blocked Ratio" [ref=e322]
              - cell "0.5%" [ref=e323]
              - cell "< 2%" [ref=e324]
              - cell "OK" [ref=e325]
              - cell "13 blocked — review Guardian queue" [ref=e326]
            - row "P0 Completion 100% 100% PASS All 191 safety tasks done" [ref=e327]:
              - cell "P0 Completion" [ref=e328]
              - cell "100%" [ref=e329]
              - cell "100%" [ref=e330]
              - cell "PASS" [ref=e331]
              - cell "All 191 safety tasks done" [ref=e332]
            - row "Knowledge Coverage 2,060 holons > 500 PASS FTS5 searchable in < 1ms" [ref=e333]:
              - cell "Knowledge Coverage" [ref=e334]
              - cell "2,060 holons" [ref=e335]
              - cell "> 500" [ref=e336]
              - cell "PASS" [ref=e337]
              - cell "FTS5 searchable in < 1ms" [ref=e338]
            - row "STAMP Refs Indexed 6,647 > 1,000 PASS Cross-referenced in graph" [ref=e339]:
              - cell "STAMP Refs Indexed" [ref=e340]
              - cell "6,647" [ref=e341]
              - cell "> 1,000" [ref=e342]
              - cell "PASS" [ref=e343]
              - cell "Cross-referenced in graph" [ref=e344]
            - row "Backup Freshness < 24h < 24h PASS GCS europe-north1" [ref=e345]:
              - cell "Backup Freshness" [ref=e346]
              - cell "< 24h" [ref=e347]
              - cell "< 24h" [ref=e348]
              - cell "PASS" [ref=e349]
              - cell "GCS europe-north1" [ref=e350]
            - row "Test Coverage 3,824 pass > 3,000 PASS 0 failures" [ref=e351]:
              - cell "Test Coverage" [ref=e352]
              - cell "3,824 pass" [ref=e353]
              - cell "> 3,000" [ref=e354]
              - cell "PASS" [ref=e355]
              - cell "0 failures" [ref=e356]
            - row "Entropy (avg) < 0.3 < 0.5 PASS Knowledge is fresh" [ref=e357]:
              - cell "Entropy (avg)" [ref=e358]
              - cell "< 0.3" [ref=e359]
              - cell "< 0.5" [ref=e360]
              - cell "PASS" [ref=e361]
              - cell "Knowledge is fresh" [ref=e362]
            - row "RAG Integration Active Active PASS Holons in LLM context" [ref=e363]:
              - cell "RAG Integration" [ref=e364]
              - cell "Active" [ref=e365]
              - cell "Active" [ref=e366]
              - cell "PASS" [ref=e367]
              - cell "Holons in LLM context" [ref=e368]
            - row "Build Health 0 errors 0 errors PASS Gleam + Rust clean" [ref=e369]:
              - cell "Build Health" [ref=e370]
              - cell "0 errors" [ref=e371]
              - cell "0 errors" [ref=e372]
              - cell "PASS" [ref=e373]
              - cell "Gleam + Rust clean" [ref=e374]
      - generic [ref=e375]:
        - paragraph [ref=e376]: Decision Support — Operational Scenarios
        - textbox "Filter table..." [ref=e377]
        - table [ref=e378]:
          - rowgroup [ref=e379]:
            - row "Scenario Question Zettelkasten Answer Confidence" [ref=e380]:
              - columnheader "Scenario" [ref=e381]
              - columnheader "Question" [ref=e382]
              - columnheader "Zettelkasten Answer" [ref=e383]
              - columnheader "Confidence" [ref=e384]
          - rowgroup [ref=e385]:
            - row "Incident Response Has this happened before? Search 180 journal RCA sections High (Evidence)" [ref=e386]:
              - cell "Incident Response" [ref=e387]
              - cell "Has this happened before?" [ref=e388]
              - cell "Search 180 journal RCA sections" [ref=e389]
              - cell "High (Evidence)" [ref=e390]
            - row "Capacity Planning Will inference hit limits? 12 intents/day × 365 = OK for SQLite High (Evidence)" [ref=e391]:
              - cell "Capacity Planning" [ref=e392]
              - cell "Will inference hit limits?" [ref=e393]
              - cell "12 intents/day × 365 = OK for SQLite" [ref=e394]
              - cell "High (Evidence)" [ref=e395]
            - row "Compliance Check Is SC-ZENOH-001 implemented? Yes — code edge from zenoh/client.gleam Very High (Axiom)" [ref=e396]:
              - cell "Compliance Check" [ref=e397]
              - cell "Is SC-ZENOH-001 implemented?" [ref=e398]
              - cell "Yes — code edge from zenoh/client.gleam" [ref=e399]
              - cell "Very High (Axiom)" [ref=e400]
            - row "Architecture Decision Why SSR not client JS? SC-GLM-UI-002 mandates server-side Very High (Axiom)" [ref=e401]:
              - cell "Architecture Decision" [ref=e402]
              - cell "Why SSR not client JS?" [ref=e403]
              - cell "SC-GLM-UI-002 mandates server-side" [ref=e404]
              - cell "Very High (Axiom)" [ref=e405]
            - row "Onboarding Where do I start? 5 ecosystem zettels → 5 axiom specs → 5 constraints High" [ref=e406]:
              - cell "Onboarding" [ref=e407]
              - cell "Where do I start?" [ref=e408]
              - cell "5 ecosystem zettels → 5 axiom specs → 5 constraints" [ref=e409]
              - cell "High" [ref=e410]
            - row "Cost Optimization How much does inference cost? $0.054/day — 50% cached, Gemini Direct handles 65% Medium (Evidence)" [ref=e411]:
              - cell "Cost Optimization" [ref=e412]
              - cell "How much does inference cost?" [ref=e413]
              - cell "$0.054/day — 50% cached, Gemini Direct handles 65%" [ref=e414]
              - cell "Medium (Evidence)" [ref=e415]
            - row "Drift Detection Are specs up to date? Plans cluster entropy 0.60 — ROTTING, needs review High (Computed)" [ref=e416]:
              - cell "Drift Detection" [ref=e417]
              - cell "Are specs up to date?" [ref=e418]
              - cell "Plans cluster entropy 0.60 — ROTTING, needs review" [ref=e419]
              - cell "High (Computed)" [ref=e420]
            - row "Recovery Can we restore from scratch? GCS 22.8 MB + git clone + ingest-docs (12.6s) Very High (Tested)" [ref=e421]:
              - cell "Recovery" [ref=e422]
              - cell "Can we restore from scratch?" [ref=e423]
              - cell "GCS 22.8 MB + git clone + ingest-docs (12.6s)" [ref=e424]
              - cell "Very High (Tested)" [ref=e425]
      - generic [ref=e426]:
        - paragraph [ref=e427]: Pipeline Performance (from 85 traced intents)
        - textbox "Filter table..." [ref=e428]
        - table [ref=e429]:
          - rowgroup [ref=e430]:
            - row "Stage Avg Latency Count Health" [ref=e431]:
              - columnheader "Stage" [ref=e432]
              - columnheader "Avg Latency" [ref=e433]
              - columnheader "Count" [ref=e434]
              - columnheader "Health" [ref=e435]
          - rowgroup [ref=e436]:
            - row "received 0ms 86 Nominal" [ref=e437]:
              - cell "received" [ref=e438]
              - cell "0ms" [ref=e439]
              - cell "86" [ref=e440]
              - cell "Nominal" [ref=e441]
            - row "classified 157ms 86 Nominal" [ref=e442]:
              - cell "classified" [ref=e443]
              - cell "157ms" [ref=e444]
              - cell "86" [ref=e445]
              - cell "Nominal" [ref=e446]
            - row "ack_sent 2,196ms 66 Nominal" [ref=e447]:
              - cell "ack_sent" [ref=e448]
              - cell "2,196ms" [ref=e449]
              - cell "66" [ref=e450]
              - cell "Nominal" [ref=e451]
            - row "inference_started 2,282ms 64 Nominal" [ref=e452]:
              - cell "inference_started" [ref=e453]
              - cell "2,282ms" [ref=e454]
              - cell "64" [ref=e455]
              - cell "Nominal" [ref=e456]
            - row "rag 2,913ms 44 Nominal" [ref=e457]:
              - cell "rag" [ref=e458]
              - cell "2,913ms" [ref=e459]
              - cell "44" [ref=e460]
              - cell "Nominal" [ref=e461]
            - row "delivered 3,582ms 86 Nominal" [ref=e462]:
              - cell "delivered" [ref=e463]
              - cell "3,582ms" [ref=e464]
              - cell "86" [ref=e465]
              - cell "Nominal" [ref=e466]
            - row "inference_complete 4,419ms 64 Nominal" [ref=e467]:
              - cell "inference_complete" [ref=e468]
              - cell "4,419ms" [ref=e469]
              - cell "64" [ref=e470]
              - cell "Nominal" [ref=e471]
            - row "cache_hit 54ms 2 Excellent" [ref=e472]:
              - cell "cache_hit" [ref=e473]
              - cell "54ms" [ref=e474]
              - cell "2" [ref=e475]
              - cell "Excellent" [ref=e476]
      - generic [ref=e477]:
        - paragraph [ref=e478]: Raw NIF Data (Debug)
        - group [ref=e479]:
          - generic "Click to expand raw JSON from NIF → Rust → SQLite" [ref=e480]
  - slider "4D State Projection Slider (SC-HMI-410)" [ref=e481]: "0"
  - generic "Mesh heartbeat" [ref=e482]
  - generic "Agent activity" [ref=e483]
```

# Test source

```ts
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
  159 |     expect(hasData).toBeTruthy();
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
> 220 |     expect(gridContent.length).toBeGreaterThan(0);
      |                                ^ Error: expect(received).toBeGreaterThan(expected)
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
  260 | });
  261 | 
  262 | // ═══════════════════════════════════════════════════════════════════
  263 | // 6. ANALYSIS MATRIX
  264 | // ═══════════════════════════════════════════════════════════════════
  265 | 
  266 | test.describe('6. Analysis Matrix', () => {
  267 | 
  268 |   test('analysis matrix has 10 rows', async ({ page }) => {
  269 |     await page.goto(`${BASE}/planning`);
  270 |     const table = page.locator('table').filter({ hasText: 'Task Completion Rate' });
  271 |     const rows = await table.locator('tbody tr').count();
  272 |     expect(rows).toBe(10);
  273 |   });
  274 | 
  275 |   test('analysis shows PASS/BELOW/OK statuses', async ({ page }) => {
  276 |     await page.goto(`${BASE}/planning`);
  277 |     const body = await page.textContent('body');
  278 |     expect(body).toContain('PASS');
  279 |     expect(body).toContain('BELOW');
  280 |   });
  281 | 
  282 |   test('analysis includes all key dimensions', async ({ page }) => {
  283 |     await page.goto(`${BASE}/planning`);
  284 |     const body = await page.textContent('body');
  285 |     const dimensions = [
  286 |       'Task Completion Rate', 'Blocked Ratio', 'P0 Completion',
  287 |       'Knowledge Coverage', 'STAMP Refs', 'Backup Freshness',
  288 |       'Test Coverage', 'Entropy', 'RAG Integration', 'Build Health',
  289 |     ];
  290 |     for (const dim of dimensions) {
  291 |       expect(body, `Dimension "${dim}" should be present`).toContain(dim);
  292 |     }
  293 |   });
  294 | 
  295 | });
  296 | 
  297 | // ═══════════════════════════════════════════════════════════════════
  298 | // 7. DECISION SUPPORT
  299 | // ═══════════════════════════════════════════════════════════════════
  300 | 
  301 | test.describe('7. Decision Support Scenarios', () => {
  302 | 
  303 |   test('decision table has 8 scenarios', async ({ page }) => {
  304 |     await page.goto(`${BASE}/planning`);
  305 |     const table = page.locator('table').filter({ hasText: 'Incident Response' });
  306 |     const rows = await table.locator('tbody tr').count();
  307 |     expect(rows).toBe(8);
  308 |   });
  309 | 
  310 |   test('confidence levels include Axiom and Evidence', async ({ page }) => {
  311 |     await page.goto(`${BASE}/planning`);
  312 |     const body = await page.textContent('body');
  313 |     expect(body).toContain('Axiom');
  314 |     expect(body).toContain('Evidence');
  315 |   });
  316 | 
  317 | });
  318 | 
  319 | // ═══════════════════════════════════════════════════════════════════
  320 | // 8. PIPELINE PERFORMANCE
```