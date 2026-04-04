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
    let path = "data/smriti/planning.db";
    let conn = Connection::open(path).map_err(|e| IgnitionError::SqliteError(e.to_string()))?;
    Ok(conn)
}

pub fn get_all_tasks() -> Result<Vec<Task>, IgnitionError> {
    let conn = open_db()?;
    let mut stmt = conn.prepare("SELECT Id, Title, Status, Priority, ParentId, Owner, Created FROM Tasks")
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
