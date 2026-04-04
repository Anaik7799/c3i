use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::env;
use crate::errors::IgnitionError;
use log::{debug, info, warn};

const OPENROUTER_API_URL: &str = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL: &str = "google/gemini-2.5-flash"; // Fast Gemini model

#[derive(Serialize)]
struct OpenRouterRequest<'a> {
    model: &'a str,
    messages: Vec<Message<'a>>,
}

#[derive(Serialize)]
struct Message<'a> {
    role: &'a str,
    content: &'a str,
}

#[derive(Deserialize, Debug)]
struct OpenRouterResponse {
    choices: Vec<Choice>,
}

#[derive(Deserialize, Debug)]
struct Choice {
    message: ResponseMessage,
}

#[derive(Deserialize, Debug)]
struct ResponseMessage {
    content: String,
}

/// Query the fast Gemini 3 model via OpenRouter for an AI RCA diagnosis or guidance.
pub async fn query_llm_advisor(prompt: &str) -> Result<String, IgnitionError> {
    let api_key = match env::var("OPENROUTER_API_KEY") {
        Ok(k) => k,
        Err(_) => {
            warn!("OPENROUTER_API_KEY not set. AI capabilities are disabled.");
            return Err(IgnitionError::InternalError("OPENROUTER_API_KEY not set".into()));
        }
    };

    // User asked for "fast gemini 3 model", fall back to openrouter default if custom not set.
    let model = env::var("OPENROUTER_MODEL").unwrap_or_else(|_| DEFAULT_MODEL.to_string());

    info!("Querying OpenRouter LLM Advisor (model: {})...", model);

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| IgnitionError::InternalError(format!("Failed to build reqwest client: {}", e)))?;

    let req_body = OpenRouterRequest {
        model: &model,
        messages: vec![
            Message {
                role: "system",
                content: "You are the AI Advisor for the C3I SIL-6 Biomorphic Mesh Ignition Daemon. Provide highly concise, expert-level root cause analysis and remediation advice for container orchestration, networking, and system faults.",
            },
            Message {
                role: "user",
                content: prompt,
            },
        ],
    };

    let res = client
        .post(OPENROUTER_API_URL)
        .header("Authorization", format!("Bearer {}", api_key))
        .header("HTTP-Referer", "https://github.com/Anaik7799/c3i") 
        .header("X-Title", "C3I Ignition Daemon")
        .json(&req_body)
        .send()
        .await
        .map_err(|e| IgnitionError::InternalError(format!("OpenRouter API error: {}", e)))?;

    if !res.status().is_success() {
        let err_text = res.text().await.unwrap_or_default();
        return Err(IgnitionError::InternalError(format!(
            "OpenRouter returned error: {}",
            err_text
        )));
    }

    let parsed: OpenRouterResponse = res
        .json()
        .await
        .map_err(|e| IgnitionError::InternalError(format!("Failed to parse OpenRouter response: {}", e)))?;

    if let Some(choice) = parsed.choices.into_iter().next() {
        Ok(choice.message.content)
    } else {
        Err(IgnitionError::InternalError("OpenRouter response contained no choices".into()))
    }
}
