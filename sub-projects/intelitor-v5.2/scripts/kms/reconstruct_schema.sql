PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
ALTER TABLE holons RENAME TO holons_old;
CREATE TABLE holons (
  id TEXT PRIMARY KEY,
  fqun TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index','task')),
  name TEXT NOT NULL,
  parent_id TEXT REFERENCES holons(id),
  genome TEXT NOT NULL DEFAULT '{}',
  vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
  membrane TEXT DEFAULT '{}',
  payload TEXT NOT NULL DEFAULT '{}',
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
INSERT INTO holons SELECT * FROM holons_old;
DROP TABLE holons_old;
COMMIT;
