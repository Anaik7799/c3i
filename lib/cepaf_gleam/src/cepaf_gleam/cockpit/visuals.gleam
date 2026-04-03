import gleam/float
import gleam/int
import gleam/list
import gleam/string

pub fn with_color(text: String, color: String) -> String {
  let code = case color {
    "green" -> "\u{001b}[32m"
    "red" -> "\u{001b}[31m"
    "yellow" -> "\u{001b}[33m"
    "blue" -> "\u{001b}[34m"
    "cyan" -> "\u{001b}[36m"
    "magenta" -> "\u{001b}[35m"
    _ -> ""
  }

  case code {
    "" -> text
    _ -> code <> text <> "\u{001b}[0m"
  }
}

pub fn render_progress_bar(percent: Float, width: Int) -> String {
  let filled_width = float.round(percent *. int.to_float(width))
  let empty_width = width - filled_width

  let color = case percent {
    p if p >=. 0.8 -> "green"
    p if p >=. 0.5 -> "yellow"
    _ -> "red"
  }

  let bar =
    "["
    <> string.repeat("=", filled_width)
    <> string.repeat(" ", empty_width)
    <> "]"
  with_color(bar, color)
}

pub fn render_sparkline(data: List(Float)) -> String {
  // Unicode block characters for sparklines:  ▂▃▄▅▆▇█
  let blocks = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  let max_val = list.fold(data, 0.0, float.max)

  list.map(data, fn(v) {
    let index = case max_val >. 0.0 {
      True -> float.round(v /. max_val *. 7.0)
      False -> 0
    }
    case list.drop(blocks, index) |> list.first {
      Ok(b) -> b
      Error(_) -> " "
    }
  })
  |> string.join("")
}
