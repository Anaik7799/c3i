//// scripts/common/html_deck — reusable slide-deck builder.
////
//// Sibling to `scripts/common/html_doc`. Produces a full-height-per-slide
//// HTML file that works in any browser, with a top link back to the paired
//// analysis doc and optional embedded diagram images.

import gleam/list
import gleam/string
import scripts/common/artifact
import scripts/common/fsx

pub type SlideBody {
  Bullets(items: List(String))
  Image(caption: String, src_filename: String)
  Text(paragraph: String)
}

pub type Slide {
  Slide(title: String, body: SlideBody)
}

pub type Meta {
  Meta(
    stamp: String,
    task_id: String,
    feature_slug: String,
    title: String,
    subtitle: String,
    pair_analysis_file: String,
  )
}

fn escape(s: String) -> String {
  s
  |> string.replace(each: "&", with: "&amp;")
  |> string.replace(each: "<", with: "&lt;")
  |> string.replace(each: ">", with: "&gt;")
}

fn slide_html(meta: Meta, s: Slide) -> String {
  let content = case s.body {
    Bullets(items) ->
      "<ul>"
      <> string.join(list.map(items, fn(i) { "<li>" <> i <> "</li>" }), "")
      <> "</ul>"
    Image(caption, file) -> {
      let url = artifact.link(artifact.Http, meta.task_id, file)
      "<p>" <> escape(caption) <> "</p><img src=\"" <> url <> "\">"
    }
    Text(p) -> "<p>" <> p <> "</p>"
  }
  "<div class=\"slide\"><h2>" <> escape(s.title) <> "</h2>" <> content <> "</div>"
}

pub fn render(meta: Meta, slides: List(Slide)) -> String {
  let analysis_link = artifact.link(artifact.Https, meta.task_id, meta.pair_analysis_file)
  "<!DOCTYPE html>\n<html lang=\"en\"><head>\n"
  <> "<meta charset=\"utf-8\">\n"
  <> "<title>" <> escape(meta.title) <> " · task " <> meta.task_id <> "</title>\n"
  <> "<style>body{font-family:system-ui,-apple-system,sans-serif;margin:0;background:#0b1b2b;color:#f0f0f0}\n"
  <> ".slide{min-height:100vh;display:flex;flex-direction:column;justify-content:center;align-items:center;padding:2em;border-bottom:2px solid #1f3a57}\n"
  <> ".slide h1{font-size:2.6em;margin:.2em 0}\n"
  <> ".slide h2{font-size:2em;margin:.2em 0;color:#9ad1ff}\n"
  <> ".slide ul{font-size:1.2em;max-width:900px;margin:.6em auto}\n"
  <> ".slide img{max-width:80%;max-height:60vh;background:#fff;border-radius:8px;padding:.5em}\n"
  <> ".slide code{background:#132c43;padding:.1em .3em;border-radius:3px}\n"
  <> ".top{position:fixed;top:0;left:0;right:0;background:#07111a;padding:.5em 1em;font-size:.9em;z-index:10}\n"
  <> ".top a{color:#9ad1ff}</style></head><body>\n"
  <> "<div class=\"top\">Analysis → <a href=\"" <> analysis_link <> "\">" <> analysis_link <> "</a></div>\n"
  <> "<div class=\"slide\"><h1>" <> escape(meta.title) <> "</h1>"
  <> "<h2>" <> escape(meta.subtitle) <> "</h2>"
  <> "<p>" <> escape(meta.stamp) <> " UTC · task " <> escape(meta.task_id) <> "</p></div>\n"
  <> string.join(list.map(slides, fn(s) { slide_html(meta, s) }), "\n")
  <> "</body></html>\n"
}

pub fn write(meta: Meta, slides: List(Slide)) -> Result(String, String) {
  let filename = artifact.filename(meta.stamp, meta.task_id, artifact.Deck, meta.feature_slug)
  case fsx.write_file(artifact.journal_dir(), filename, render(meta, slides)) {
    Error(e) -> Error(e)
    Ok(_) -> Ok(filename)
  }
}
