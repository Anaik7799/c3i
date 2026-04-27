#!/usr/bin/env python3
"""
Indrajaal Symbiosis & Triple-Interface Parity Audit
Authoritative test suite for L0-L7 fractal layers.
"""

import subprocess
import json
import os
import sys
import time
import urllib.request
import urllib.error

# Configuration
GLEAM_PORT = 4100
RUST_DAEMON_PORT = 9999
BASE_URL = f"http://localhost:{GLEAM_PORT}"
API_URL = f"{BASE_URL}/api/v1"

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def log_section(title):
    print(f"\n{Colors.HEADER}{Colors.BOLD}╔══════════════════════════════════════════════════════╗")
    print(f"║  {title.center(50)}  ║")
    print(f"╚══════════════════════════════════════════════════════╝{Colors.ENDC}")

def check(desc, condition):
    if condition:
        print(f"  {Colors.OKGREEN}✓{Colors.ENDC} {desc}")
        return True
    else:
        print(f"  {Colors.FAIL}✗{Colors.ENDC} {desc}")
        return False

def run_cmd(cmd, shell=False):
    try:
        result = subprocess.run(cmd, shell=shell, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"ERROR: {e.stderr}"

def http_get(url):
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            return response.read().decode('utf-8'), response.getcode()
    except urllib.error.HTTPError as e:
        try:
            return e.read().decode('utf-8'), e.code
        except:
            return str(e), e.code
    except Exception as e:
        return str(e), 0

def audit_gleam_api():
    log_section("Gleam Wisp API Audit")
    
    endpoints = [
        "health", "pages", "dashboard", "immune", "zenoh", 
        "verification", "integrity", "evolution", "biomorphic", 
        "ooda/decide", "plan/status"
    ]
    
    success = True
    for ep in endpoints:
        url = f"{API_URL}/{ep}"
        body, code = http_get(url)
        is_ok = code == 200
        check(f"GET /api/v1/{ep} (status {code})", is_ok)
        if is_ok:
            try:
                data = json.loads(body)
                # Structural validation
                if ep == "pages":
                    check("  - contains 'pages' array", "pages" in data and isinstance(data["pages"], list))
                elif ep == "plan/status":
                    check("  - contains 'total' count", "total" in data)
            except Exception as e:
                check(f"  - valid JSON ({e})", False)
                success = False
        else:
            success = False
    return success

def audit_triple_interface_parity():
    log_section("Triple-Interface Parity Audit")
    
    # Check if HTML title matches JSON title for key pages
    pages = ["dashboard", "planning", "immune", "zenoh", "biomorphic"]
    
    success = True
    for p in pages:
        # 1. Get JSON data
        body, code = http_get(f"{API_URL}/{p}")
        if code != 200:
            check(f"Parity [{p}]: Failed to get JSON (status {code})", False)
            success = False
            continue
            
        try:
            api_data = json.loads(body)
            api_page_name = api_data.get("page", "")
            
            # 2. Get HTML data
            html_content, html_code = http_get(f"{BASE_URL}/{p}")
            
            # 3. Compare
            parity = api_page_name in html_content
            check(f"Parity [{p}]: JSON '{api_page_name}' found in HTML", parity)
            if not parity:
                success = False
        except Exception as e:
            check(f"Parity [{p}]: ERROR ({e})", False)
            success = False
            
    return success

def audit_rust_symbiosis():
    log_section("Rust sa-plan Symbiosis Audit")
    
    # 1. Get planning status from Rust CLI
    rust_status = run_cmd(["./sa-plan", "status"])
    rust_completed = 0
    if "Completed:" in rust_status:
        try:
            # Extract number after 'Completed:'
            parts = rust_status.split("Completed:")[1].split()
            rust_completed = int(parts[0].strip())
        except Exception as e:
            print(f"  {Colors.WARNING}! Failed to parse Rust completed count: {e}{Colors.ENDC}")
    
    # 2. Get planning status from Gleam API
    body, code = http_get(f"{API_URL}/plan/status")
    if code != 200:
        check(f"Symbiosis: Failed to get Gleam status (status {code})", False)
        return False
        
    try:
        gleam_status = json.loads(body)
        gleam_completed = gleam_status.get("completed", 0)
        
        # 3. Cross-verify
        match = rust_completed == gleam_completed
        check(f"Symbiosis: Rust completed ({rust_completed}) == Gleam completed ({gleam_completed})", match)
        return match
    except Exception as e:
        check(f"Symbiosis: ERROR ({e})", False)
        return False

def main():
    print(f"{Colors.OKCYAN}{Colors.BOLD}INDRAJAAL EXHAUSTIVE PARITY & SYMBIOSIS SUITE{Colors.ENDC}")
    
    overall_success = True
    
    # Ensure server is running
    _, code = http_get(BASE_URL)
    if code != 200:
        print(f"{Colors.WARNING}⚠ Gleam server not detected on port {GLEAM_PORT}. Attempting to start...{Colors.ENDC}")
        subprocess.Popen(["./sa-gleam-start", "-d"])
        time.sleep(10) # Give it more time
    
    overall_success &= audit_gleam_api()
    overall_success &= audit_triple_interface_parity()
    overall_success &= audit_rust_symbiosis()
    
    if overall_success:
        print(f"\n{Colors.OKGREEN}{Colors.BOLD}✅ ALL PARITY & SYMBIOSIS CHECKS PASSED{Colors.ENDC}")
        sys.exit(0)
    else:
        print(f"\n{Colors.FAIL}{Colors.BOLD}❌ SOME CHECKS FAILED{Colors.ENDC}")
        sys.exit(1)

if __name__ == "__main__":
    main()
