//// scripts/common/delivery — SMTP email delivery + ZK ingest + links registry.
////
//// SC-NOTIFY-JOURNAL-001..004. Every new journal/HTML/deck from a
//// feature-evolution run goes through this module so deliveries follow the
//// project-wide rules (attach the .md, attach companion HTMLs and diagrams,
//// use sa-plan send-email, ingest once afterwards).

import gleam/int
import gleam/list
import gleam/string
import scripts/common/artifact
import scripts/common/errors.{type ScriptError}
import scripts/common/fsx
import scripts/common/logx
import scripts/common/saplan

const default_recipient = "Abhijit.Naik@bountytek.com"

pub type EmailPack {
  EmailPack(
    recipient: String,
    subject: String,
    body: String,
    attachments_abs: List(String),  // absolute paths
  )
}

/// Build the standard feature-evolution email:
///   journal (.md) first, then analysis.html, deck.html, links.json, diagrams.
pub fn build_pack(
  task_id: String,
  feature_title: String,
  stamp: String,
  journal_file: String,
  analysis_file: String,
  deck_file: String,
  links_file: String,
  diagram_files: List(String),
  recipient_override: String,
) -> EmailPack {
  let recipient = case recipient_override {
    "" -> default_recipient
    r -> r
  }
  let dir = artifact.journal_dir()
  let attachments = [
    dir <> "/" <> journal_file,
    dir <> "/" <> analysis_file,
    dir <> "/" <> deck_file,
    dir <> "/" <> links_file,
    ..list.map(diagram_files, fn(f) { dir <> "/" <> f })
  ]
  let subject =
    "[c3i] " <> feature_title <> " · " <> stamp <> " · task " <> task_id
  let body =
    feature_title <> " — artefact pack for task " <> task_id <> "\n\n"
    <> "Journal:  " <> artifact.link(artifact.Https, task_id, journal_file) <> "\n"
    <> "Analysis: " <> artifact.link(artifact.Https, task_id, analysis_file) <> "\n"
    <> "Deck:     " <> artifact.link(artifact.Https, task_id, deck_file) <> "\n"
    <> "Links:    " <> artifact.link(artifact.Https, task_id, links_file) <> "\n\n"
    <> "Paths are also reachable via HTTP :4200 + HTTPS :8443 task-id pages.\n"
  EmailPack(recipient: recipient, subject: subject, body: body, attachments_abs: attachments)
}

/// Send the pack via `sa-plan send-email`.  Returns the underlying RC.
pub fn send(pack: EmailPack) -> Result(Int, ScriptError) {
  let run =
    saplan.send_email(pack.recipient, pack.subject, pack.body, pack.attachments_abs)
  logx.info("common/delivery", "email rc=" <> int.to_string(run.rc) <> " to=" <> pack.recipient)
  case run.rc {
    0 -> Ok(0)
    n -> Error(errors.Upstream("sa-plan send-email rc=" <> int.to_string(n)))
  }
}

/// Trigger ZK ingest so new journals/HTMLs become searchable.  Thin wrapper
/// for `sa-plan ingest-docs`.
pub fn ingest_zk() -> Result(Int, ScriptError) {
  let run = saplan.invoke(["ingest-docs"])
  logx.info("common/delivery", "ingest-docs rc=" <> int.to_string(run.rc))
  case run.rc {
    0 -> Ok(0)
    n -> Error(errors.Upstream("sa-plan ingest-docs rc=" <> int.to_string(n)))
  }
}

/// Persist a typed task-id link registry as JSON in the canonical path
/// `docs/journal/task-<tid>-links.json`. This file is picked up by
/// sa-plan's existing task-id page when present.
pub type LinksPayload {
  LinksPayload(
    task_id: String,
    stamp: String,
    journal_file: String,
    analysis_file: String,
    deck_file: String,
    diagrams: List(String),
  )
}

pub fn write_links_registry(p: LinksPayload) -> Result(String, ScriptError) {
  let dia_urls_http =
    p.diagrams
    |> list.map(fn(f) { "\"" <> artifact.link(artifact.Http, p.task_id, f) <> "\"" })
    |> string.join(",")
  let body =
    "{\n"
    <> "  \"task_id\": \"" <> p.task_id <> "\",\n"
    <> "  \"generated_at\": \"" <> p.stamp <> "\",\n"
    <> "  \"links\": {\n"
    <> "    \"journal_md_http\":  \"" <> artifact.link(artifact.Http, p.task_id, p.journal_file) <> "\",\n"
    <> "    \"journal_md_https\": \"" <> artifact.link(artifact.Https, p.task_id, p.journal_file) <> "\",\n"
    <> "    \"analysis_http\":    \"" <> artifact.link(artifact.Http, p.task_id, p.analysis_file) <> "\",\n"
    <> "    \"analysis_https\":   \"" <> artifact.link(artifact.Https, p.task_id, p.analysis_file) <> "\",\n"
    <> "    \"deck_http\":        \"" <> artifact.link(artifact.Http, p.task_id, p.deck_file) <> "\",\n"
    <> "    \"deck_https\":       \"" <> artifact.link(artifact.Https, p.task_id, p.deck_file) <> "\",\n"
    <> "    \"diagrams\": [" <> dia_urls_http <> "]\n"
    <> "  }\n"
    <> "}\n"
  // Canonical filename (no stamp prefix): task-<tid>-links.json
  let filename = "task-" <> p.task_id <> "-links.json"
  case fsx.write_file(artifact.journal_dir(), filename, body) {
    Error(e) -> Error(errors.IoError(e))
    Ok(_) -> Ok(filename)
  }
}
