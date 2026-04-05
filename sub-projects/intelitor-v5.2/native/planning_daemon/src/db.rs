use rusqlite::{params, Connection, Result as SqlResult};
use crate::errors::IgnitionError;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub status: String,
    pub priority: String,
    pub parent_id: Option<String>,
    pub owner: Option<String>,
    pub created: String,
}

pub fn open_db() -> Result<Connection, IgnitionError> {
    #[cfg(not(test))]
    let path = "data/smriti/Smriti.db".to_string();
    #[cfg(test)]
    let path = std::env::var("PLANNING_DB_PATH").unwrap_or_else(|_| "data/smriti/Smriti.db".to_string());

    let conn = Connection::open(&path).map_err(|e| IgnitionError::SqliteError(e.to_string()))?;
    // Enable WAL mode for better concurrency
    conn.execute("PRAGMA journal_mode=WAL", []).ok();
    // Set busy timeout to handle lock contention
    conn.busy_timeout(std::time::Duration::from_millis(5000)).ok();
    Ok(conn)
}

pub fn get_all_tasks() -> Result<Vec<Task>, IgnitionError> {
    let conn = open_db()?;
    let mut stmt = conn.prepare("SELECT Id, Title, Status, Priority, ParentId, Owner, Created FROM Tasks ORDER BY Created ASC, Id ASC")
        .map_err(|e| IgnitionError::SqliteError(e.to_string()))?;
    
    let task_iter = stmt.query_map([], |row| {
        Ok(Task {
            id: row.get(0)?,
            title: row.get(1)?,
            status: row.get(2)?,
            priority: row.get(3)?,
            parent_id: row.get(4)?,
            owner: row.get(5)?,
            created: row.get(6)?,
        })
    }).map_err(|e| IgnitionError::SqliteError(e.to_string()))?;

    let mut tasks = Vec::new();
    for t in task_iter {
        tasks.push(t.map_err(|e| IgnitionError::SqliteError(e.to_string()))?);
    }
    Ok(tasks)
}

pub fn add_task(title: &str, priority: &str) -> Result<String, IgnitionError> {
    let conn = open_db()?;
    let id = uuid::Uuid::new_v4().to_string().chars().take(8).collect::<String>();
    let created = chrono::Utc::now().to_rfc3339();
    
    conn.execute(
        "INSERT INTO Tasks (Id, Title, Status, Priority, Created, RawLines) VALUES (?1, ?2, 'pending', ?3, ?4, ?5)",
        params![id, title, priority, created, ""],
    ).map_err(|e| IgnitionError::SqliteError(e.to_string()))?;
    
    Ok(id)
}

pub fn update_task_status(id: &str, status: &str) -> Result<(), IgnitionError> {
    let conn = open_db()?;
    let updated = conn.execute(
        "UPDATE Tasks SET Status = ?1 WHERE Id = ?2",
        params![status, id],
    ).map_err(|e| IgnitionError::SqliteError(e.to_string()))?;
    
    if updated == 0 {
        return Err(IgnitionError::InternalError(format!("Task {} not found", id)));
    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;
    use std::sync::{Arc, Barrier};
    use std::thread;

    fn setup_test_db() -> NamedTempFile {
        let file = NamedTempFile::new().unwrap();
        let path = file.path().to_str().unwrap().to_string();
        std::env::set_var("PLANNING_DB_PATH", &path);
        
        let conn = Connection::open(&path).unwrap();
        conn.execute(
            "CREATE TABLE Tasks (
                Id TEXT PRIMARY KEY,
                Title TEXT NOT NULL,
                Status TEXT NOT NULL,
                Priority TEXT NOT NULL,
                ParentId TEXT,
                Owner TEXT,
                Created TEXT NOT NULL,
                RawLines TEXT
            )",
            [],
        ).unwrap();
        file
    }

    #[test]
    fn test_concurrent_db_stress() {
        let _tmp_db = setup_test_db();
        let num_threads = 10;
        let tasks_per_thread = 20;
        let barrier = Arc::new(Barrier::new(num_threads));
        let mut handles = vec![];

        for i in 0..num_threads {
            let barrier = Arc::clone(&barrier);
            let handle = thread::spawn(move || {
                barrier.wait();
                for j in 0..tasks_per_thread {
                    let title = format!("Task {}-{}", i, j);
                    let id = add_task(&title, "P2").expect("Failed to add task");
                    if j % 2 == 0 {
                        update_task_status(&id, "in_progress").expect("Failed to update status");
                    }
                }
            });
            handles.push(handle);
        }

        for handle in handles {
            handle.join().expect("Thread panicked");
        }

        let tasks = get_all_tasks().expect("Failed to get all tasks");
        assert_eq!(tasks.len(), num_threads * tasks_per_thread);
    }
}
