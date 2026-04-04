use ratatui::Frame;
use ratatui::layout::Rect;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OtelSpan {
    pub trace_id: String,
    pub span_id: String,
    pub name: String,
}

#[derive(Default)]
pub struct DashboardState {
    pub tab_index: usize,
}

pub async fn run_dashboard(test_mode: bool) -> Result<(), crate::errors::IgnitionError> {
    Ok(())
}

pub fn draw_ui(f: &mut Frame, _state: &DashboardState) {
    // Minimal TUI for planning
}
