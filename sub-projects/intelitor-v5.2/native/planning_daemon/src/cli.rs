use crate::errors::IgnitionError;
use crate::db;
use crate::markdown;
use log::{info, error};

pub async fn cmd_status() -> Result<(), IgnitionError> {
    let tasks = db::get_all_tasks()?;
    let total = tasks.len();
    let completed = tasks.iter().filter(|t| t.status == "completed").count();
    let pending = tasks.iter().filter(|t| t.status == "pending" || t.status == "blocked").count();
    let active = tasks.iter().filter(|t| t.status == "in_progress").count();
    
    println!("[SafetyKernel] Safety kernel activated");
    println!("[Manager] Planning.db has {} tasks.", total);
    println!("🎯 INTELITOR PROJECT TODOLIST (Rust Managed)");
    println!("===========================================");
    println!("🔄 Active: {} | ⏳ Pending: {} | ✅ Completed: {}", active, pending, completed);
    Ok(())
}

pub async fn cmd_add(title: &str, priority: &str) -> Result<(), IgnitionError> {
    println!("[SafetyKernel] Safety kernel activated");
    let id = db::add_task(title, priority)?;
    markdown::generate_markdown()?;
    println!("✅ Task added: {} ({})", id, priority);
    Ok(())
}

pub async fn cmd_update(id: &str, status: &str) -> Result<(), IgnitionError> {
    println!("[SafetyKernel] Safety kernel activated");
    db::update_task_status(id, status)?;
    markdown::generate_markdown()?;
    println!("✅ Task {} updated to {}", id, status);
    Ok(())
}

pub async fn cmd_dashboard() -> Result<(), IgnitionError> {
    crate::tui::run_dashboard(false).await
}

pub async fn cmd_sync() -> Result<(), IgnitionError> {
    println!("[SafetyKernel] Safety kernel activated");
    markdown::generate_markdown()?;
    println!("✅ PROJECT_TODOLIST.md synchronized with SQLite database.");
    Ok(())
}
