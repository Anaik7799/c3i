import urllib.request
import re
import sys

URL = "http://vm-1.tail55d152.ts.net:4100"

PAGES = [
    ("/dashboard", ["Dashboard", "card-grid"]),
    ("/planning", ["Planning", "card-grid"]),
    ("/immune", ["Immune System", "card-grid"]),
    ("/knowledge", ["Knowledge (Smriti)", "card-grid"]),
    ("/zenoh", ["Zenoh Mesh", "card-grid"]),
    ("/cockpit", ["Cockpit", "card-grid"]),
    ("/verification", ["Verification", "card-grid"]),
    ("/substrate", ["Substrate", "card-grid"]),
    ("/metabolic", ["Metabolic", "card-grid"]),
    ("/podman", ["Podman", "card-grid"]),
    ("/mcp", ["MCP Server", "card-grid"]),
    ("/kms", ["KMS Catalog", "card-grid"]),
    ("/telemetry", ["Telemetry", "card-grid"]),
    ("/integrity", ["Mathematical Integrity", "card-grid"]),
    ("/evolution", ["Evolution Vectors", "card-grid"]),
    ("/biomorphic", ["Biomorphic Matrix", "card-grid"]),
    ("/homeostasis", ["Homeostasis Controls", "card-grid"]),
    ("/bicameral", ["Bicameral Sign-Off", "card-grid"]),
    ("/singularity", ["Singularity Estimation", "card-grid"]),
    ("/federation", ["Federation (L7)", "card-grid"]),
    ("/health-grid", ["Device Health Grid"]),
    ("/prajna", ["Prajna Biomorphic"]),
    ("/agents", ["Cybernetic Agents"]),
    ("/holon", ["Holon Identity"]),
    ("/config", ["Mesh Configuration"]),
    ("/git", ["Git Intelligence"]),
    ("/database", ["Database"]),
    ("/bridge", ["Bridge"]),
    ("/smriti", ["Smriti Knowledge"]),
    ("/planning-dashboard", ["Planning Dashboard"])
]

def test_pages():
    errors = 0
    for path, expected_strings in PAGES:
        req = urllib.request.Request(f"{URL}{path}")
        try:
            with urllib.request.urlopen(req) as response:
                html = response.read().decode('utf-8')
                for expected in expected_strings:
                    if expected not in html:
                        print(f"❌ {path}: Missing expected string '{expected}'")
                        errors += 1
                
                # Check for standard a2ui elements (sanity check that rendering works)
                if 'class="w-full"' not in html:
                    print(f"❌ {path}: Missing wrapper class='w-full'")
                    errors += 1
                    
                print(f"✅ {path} - Verified OK")
        except Exception as e:
            print(f"❌ {path}: Failed to load ({e})")
            errors += 1
            
    if errors > 0:
        print(f"E2E Test Failed with {errors} errors.")
        sys.exit(1)
    else:
        print("E2E Test Passed! All pages rendered correctly with expected elements.")

test_pages()
