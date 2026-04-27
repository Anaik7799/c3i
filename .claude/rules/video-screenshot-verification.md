# Video & Screenshot Verification Protocol (SC-VERIFY-VISUAL)
# वीडियो एवं स्क्रीनशॉट सत्यापन प्रोतोकॉल

## MANDATE
**Every feature evolution MUST include visual verification: screenshots of UI states and video recordings of user journeys. Visual evidence is NOT optional.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-VERIFY-VISUAL-001 | Screenshots MUST be captured for every HTML dashboard page | HIGH |
| SC-VERIFY-VISUAL-002 | Screenshots MUST be verified against spec (feature list match) | HIGH |
| SC-VERIFY-VISUAL-003 | Video user journeys MUST demonstrate key workflows | MEDIUM |
| SC-VERIFY-VISUAL-004 | Visual regression: screenshots MUST be compared across sessions | MEDIUM |
| SC-VERIFY-VISUAL-005 | All screenshots stored in docs/screenshots/ with timestamp | HIGH |
| SC-VERIFY-VISUAL-006 | Failed visual verification triggers recursive fix loop | HIGH |

## Screenshot Protocol
```bash
# Capture dashboard screenshots
mkdir -p docs/screenshots/$(date +%Y%m%d)

# Main dashboard
chromium --headless --no-sandbox \
  --screenshot=docs/screenshots/$(date +%Y%m%d)/index.png \
  --window-size=1400,900 http://localhost:4200/

# KPI dashboard
chromium --headless --no-sandbox \
  --screenshot=docs/screenshots/$(date +%Y%m%d)/kpi.png \
  --window-size=1400,900 http://localhost:4200/kpi

# Pi symbiosis dashboard
chromium --headless --no-sandbox \
  --screenshot=docs/screenshots/$(date +%Y%m%d)/pi-symbiosis.png \
  --window-size=1400,900 http://localhost:4200/pi-symbiosis

# Mobile viewport (responsive check)
chromium --headless --no-sandbox \
  --screenshot=docs/screenshots/$(date +%Y%m%d)/pi-symbiosis-mobile.png \
  --window-size=375,812 http://localhost:4200/pi-symbiosis
```

## Video Recording Protocol
```bash
# Record user journey with ffmpeg + Xvfb
Xvfb :99 -screen 0 1400x900x24 &
export DISPLAY=:99
chromium --no-sandbox http://localhost:4200/pi-symbiosis &
sleep 3
ffmpeg -f x11grab -video_size 1400x900 -i :99 \
  -t 30 -c:v libx264 -preset fast \
  docs/videos/$(date +%Y%m%d)-pi-symbiosis-journey.mp4
```

## Visual Verification Loop
```
1. Capture screenshot
2. Compare against spec checklist:
   - [ ] All sections visible
   - [ ] Correct data displayed
   - [ ] Responsive at all breakpoints
   - [ ] No broken layouts
   - [ ] Dark theme consistent
   - [ ] SVG diagrams render
3. If ANY check fails:
   a. Identify the failing element
   b. Fix the HTML/CSS
   c. Re-capture screenshot
   d. Re-verify
   e. LOOP until 100% convergence
4. Store final screenshot as evidence
5. Include in journal entry
```

## Spec Alignment Checklist (per dashboard)
| Element | Expected | Actual | Match |
|---------|----------|--------|-------|
| Header with title | Yes | ? | ? |
| Weather bar | Yes | ? | ? |
| Package cards | 7 | ? | ? |
| Architecture SVG | Yes | ? | ? |
| FMEA table | 8+ rows | ? | ? |
| STAMP table | 10 rows | ? | ? |
| KPI metrics | 6+ | ? | ? |
| Responsive mobile | Yes | ? | ? |
| Print-friendly | Yes | ? | ? |

## Integration
- Extends SC-FEAT-EVO-013 (screenshots captured and verified)
- Extends SC-SATYA-001 (display = truth)
- Extends SC-TRUTH-001 (only show verified data)
