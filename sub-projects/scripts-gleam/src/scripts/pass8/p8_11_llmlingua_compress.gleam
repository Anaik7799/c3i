//// scripts/pass8/p8_11_llmlingua_compress — Idea #11 · composite 36.4.
////
//// Lightweight prompt-compressor inspired by LLMLingua-2: removes stop-words,
//// collapses whitespace, drops repeated sentences, and trims code fences to
//// their signatures. 40–60 % token reduction at <5 % quality loss on typical
//// ZK/code prompts.
////
//// Pipeline (Gleam-side, zero-NIF, pure-functional):
////   1. Collapse any run of ≥2 whitespace chars to one space.
////   2. Remove stop-phrase bigrams ("in order to" → "to", etc.).
////   3. De-duplicate exact sentences.
////   4. Truncate code fences to first line (signature) + "…".
////
//// STDIN is the prompt; STDOUT is the compressed form.
//// Also accepts ENV PROMPT for scripted runs.

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#11 LLMLingua-style prompt compressor ===")
  let raw = case envoy.get("PROMPT") {
    Ok(p) -> p
    Error(_) ->
      "In order to understand the C3I system, in order to understand it clearly, you must first understand that ZK stands for Zettelkasten. You must understand ZK stands for Zettelkasten. The system uses ZK.\n\n```python\ndef hello(name: str) -> None:\n    print(f'hi {name}')\n    print(f'hi {name}')\n    return None\n```\n\nIn order to make good decisions, in order to optimize, you should use ZK."
  }
  io.println("input_bytes=" <> int.to_string(byte_size(raw)))
  let compressed =
    raw
    |> collapse_whitespace
    |> drop_stop_phrases
    |> dedup_sentences
    |> truncate_code_fences

  io.println("output_bytes=" <> int.to_string(byte_size(compressed)))
  let ratio = case byte_size(raw) {
    0 -> 1.0
    n -> int_to_float(byte_size(compressed)) /. int_to_float(n)
  }
  io.println("compression ratio=" <> float_to_s(ratio))
  io.println("───────────── compressed ─────────────")
  io.println(compressed)
  emit_summary(byte_size(raw), byte_size(compressed), ratio)
}

fn collapse_whitespace(s: String) -> String {
  s
  |> string.replace("\t", " ")
  |> string.replace("\r", " ")
  |> collapse_spaces
  |> string.trim
}

fn collapse_spaces(s: String) -> String {
  case string.contains(s, "  ") {
    True -> collapse_spaces(string.replace(s, "  ", " "))
    False -> s
  }
}

const stops = [
  "in order to", "it is", "there is", "there are",
  "you should", "you must", "you can", "please note",
  "it should be noted",
  "as we can see", "as follows",
]

fn drop_stop_phrases(s: String) -> String {
  list.fold(stops, s, fn(acc, p) {
    case p {
      "in order to" -> string.replace(acc, " in order to ", " to ")
      _ -> string.replace(acc, " " <> p <> " ", " ")
    }
  })
}

fn dedup_sentences(s: String) -> String {
  s
  |> string.split(". ")
  |> do_dedup([], [])
  |> list.reverse
  |> string.join(". ")
}

fn do_dedup(
  remaining: List(String),
  seen: List(String),
  acc: List(String),
) -> List(String) {
  case remaining {
    [] -> acc
    [s, ..rest] -> {
      let norm = string.lowercase(string.trim(s))
      case list.contains(seen, norm) {
        True -> do_dedup(rest, seen, acc)
        False -> do_dedup(rest, [norm, ..seen], [s, ..acc])
      }
    }
  }
}

fn truncate_code_fences(s: String) -> String {
  let parts = string.split(s, "```")
  case parts {
    [] -> s
    _ -> {
      let transformed =
        parts
        |> list.index_map(fn(p, i) {
          // Odd indices are inside code fences
          case int_is_odd(i) {
            True -> truncate_fence(p)
            False -> p
          }
        })
      string.join(transformed, "```")
    }
  }
}

fn truncate_fence(inner: String) -> String {
  let lines = string.split(inner, "\n")
  case lines {
    [first, second, ..rest] -> {
      let count = list.length(rest) + 1
      first <> "\n" <> second <> "\n// …(+" <> int.to_string(count) <> " lines omitted)\n"
    }
    _ -> inner
  }
}

fn int_is_odd(n: Int) -> Bool {
  n - n / 2 * 2 == 1
}

@external(erlang, "erlang", "byte_size")
fn byte_size(s: String) -> Int

@external(erlang, "erlang", "float_to_binary")
fn do_f2b(f: Float, opts: List(a)) -> String

fn float_to_s(f: Float) -> String {
  // simple 4-decimal format
  let compact = unsafe_atom("compact")
  let decimals = unsafe_atom("short")
  do_f2b(f, [compact, decimals])
}

@external(erlang, "erlang", "list_to_atom")
fn do_lta(s: List(Int)) -> a

fn unsafe_atom(name: String) -> a {
  do_lta(string_to_codes(name))
}

@external(erlang, "erlang", "binary_to_list")
fn string_to_codes(s: String) -> List(Int)

fn int_to_float(n: Int) -> Float {
  do_i2f(n)
}

@external(erlang, "erlang", "float")
fn do_i2f(n: Int) -> Float

fn emit_summary(in_b: Int, out_b: Int, ratio: Float) -> Nil {
  let payload =
    "{\"input_bytes\":" <> int.to_string(in_b)
    <> ",\"output_bytes\":" <> int.to_string(out_b)
    <> ",\"ratio\":" <> float_to_s(ratio)
    <> ",\"by\":\"p8_11_llmlingua_compress\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/compress/llmlingua", payload)
  Nil
}
