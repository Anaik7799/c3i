//// scripts/common/artifact — canonical artifact paths + URL builders.
////
//// SC-JOURNAL + SC-NOTIFY-JOURNAL + task-id page server convention.
////
//// Every script that produces journals / HTML / decks / diagrams goes through
//// this module so filenames, directories, and tailscale URLs stay consistent
//// and the sa-plan `/task-id/<tid>/<file>` server can always serve them.

import scripts/common/paths

/// Canonical directory that the sa-plan daemon serves at
///   http://vm-1.tail55d152.ts.net:4200/task-id/<tid>/<file>
///   https://vm-1.tail55d152.ts.net:8443/task-id/<tid>/<file>
pub fn journal_dir() -> String {
  paths.repo_root() <> "/sub-projects/c3i/docs/journal"
}

pub type Kind {
  Journal
  Analysis
  Deck
  LinksJson
  DiagramPng
  DiagramDot
  Report
}

fn kind_suffix(k: Kind, slug: String) -> String {
  case k {
    Journal -> "-" <> slug <> "-journal.md"
    Analysis -> "-" <> slug <> "-analysis.html"
    Deck -> "-" <> slug <> "-deck.html"
    LinksJson -> "-" <> slug <> "-links.json"
    DiagramPng -> "-" <> slug <> ".png"
    DiagramDot -> "-" <> slug <> ".dot"
    Report -> "-" <> slug <> "-report.json"
  }
}

/// Build the canonical filename (leaf only, no directory):
///   <stamp>-task-<tid>-<slug>-<suffix>
/// e.g.  20260421-1135-task-1a92520c-feature-evolution-journal.md
pub fn filename(stamp: String, tid: String, kind: Kind, slug: String) -> String {
  stamp <> "-task-" <> tid <> kind_suffix(kind, slug)
}

/// Absolute path for the canonical artifact directory + filename.
pub fn abs_path(stamp: String, tid: String, kind: Kind, slug: String) -> String {
  journal_dir() <> "/" <> filename(stamp, tid, kind, slug)
}

pub type UrlScheme {
  Http
  Https
}

pub fn host_http() -> String { "vm-1.tail55d152.ts.net:4200" }
pub fn host_https() -> String { "vm-1.tail55d152.ts.net:8443" }

pub fn link(scheme: UrlScheme, tid: String, file: String) -> String {
  let base = case scheme {
    Http -> "http://" <> host_http()
    Https -> "https://" <> host_https()
  }
  base <> "/task-id/" <> tid <> "/" <> file
}

/// Convenience — both HTTP + HTTPS links for a single file.
pub type LinkPair {
  LinkPair(http_url: String, https_url: String)
}

pub fn link_pair(tid: String, file: String) -> LinkPair {
  LinkPair(http_url: link(Http, tid, file), https_url: link(Https, tid, file))
}

/// Top-of-file HTTPS link required by SC-NOTIFY and task-id page convention.
pub fn top_https_line(tid: String, file: String) -> String {
  "# " <> link(Https, tid, file)
}
