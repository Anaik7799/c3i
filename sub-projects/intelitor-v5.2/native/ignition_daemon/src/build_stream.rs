use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum BuildStreamEvent {
    Stream {
        stream: String,
    },
    Error {
        error: String,
        error_detail: Option<ErrorDetail>,
    },
    Status {
        status: String,
        progress: Option<String>,
        id: Option<String>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorDetail {
    pub message: String,
}

pub fn parse_build_stream_line(line: &str) -> Option<BuildStreamEvent> {
    serde_json::from_str(line).ok()
}
