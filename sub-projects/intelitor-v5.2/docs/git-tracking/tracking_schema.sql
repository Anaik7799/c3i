CREATE TABLE IF NOT EXISTS issues (
    id TEXT PRIMARY KEY,
    priority TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL,
    branch_name TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    methodology_compliance TEXT,
    git_commits INTEGER DEFAULT 0,
    resolution_progress REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS progress_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_id TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    old_status TEXT,
    new_status TEXT,
    git_commit_hash TEXT,
    notes TEXT,
    FOREIGN KEY (issue_id) REFERENCES issues (id)
);

CREATE TABLE IF NOT EXISTS methodology_compliance (
    issue_id TEXT PRIMARY KEY,
    stamp_analysis BOOLEAN DEFAULT FALSE,
    tdg_compliance BOOLEAN DEFAULT FALSE,
    gde_alignment BOOLEAN DEFAULT FALSE,
    compliance_score REAL DEFAULT 0.0,
    last_validated TEXT,
    FOREIGN KEY (issue_id) REFERENCES issues (id)
);
