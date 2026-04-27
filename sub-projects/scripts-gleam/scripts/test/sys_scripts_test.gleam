import gleam/list
import gleeunit
import gleeunit/should
import qcheck
import sys_scripts.{
  Check, Doctor, Fmt, Help, Inventory, Secrets, Test as TestCmd, Unknown, parse,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// --- example tests (concrete cases, documentation value) -------------------

pub fn parse_empty_returns_help_test() {
  parse([]) |> should.equal(#(Help, []))
}

pub fn parse_doctor_test() {
  parse(["doctor"]) |> should.equal(#(Doctor, []))
}

pub fn parse_doctor_with_extra_args_test() {
  parse(["doctor", "--verbose", "foo"])
  |> should.equal(#(Doctor, ["--verbose", "foo"]))
}

pub fn parse_fmt_test() {
  parse(["fmt"]) |> should.equal(#(Fmt, []))
}

pub fn parse_test_subcommand_test() {
  parse(["test", "--only", "doctor"])
  |> should.equal(#(TestCmd, ["--only", "doctor"]))
}

pub fn parse_check_subcommand_test() {
  parse(["check"]) |> should.equal(#(Check, []))
}

pub fn parse_inventory_subcommand_test() {
  parse(["inventory", "list"]) |> should.equal(#(Inventory, ["list"]))
}

pub fn parse_secrets_subcommand_test() {
  parse(["secrets", "validate"]) |> should.equal(#(Secrets, ["validate"]))
}

/// Every documented keyword must parse to a non-Unknown command.
/// Regression guard for "added a Command variant but forgot to wire
/// parse/1".
pub fn every_known_keyword_is_wired_test() {
  let keywords = [
    "doctor",
    "fmt",
    "test",
    "deploy",
    "check",
    "inventory",
    "secrets",
    "help",
    "--help",
    "-h",
  ]
  list.each(keywords, fn(kw) {
    let #(cmd, _) = parse([kw])
    cmd
    |> should.not_equal(Unknown(kw))
  })
}

pub fn parse_help_aliases_test() {
  parse(["help"]) |> should.equal(#(Help, []))
  parse(["--help"]) |> should.equal(#(Help, []))
  parse(["-h"]) |> should.equal(#(Help, []))
}

pub fn parse_unknown_passes_name_through_test() {
  parse(["banana", "split"])
  |> should.equal(#(Unknown("banana"), ["split"]))
}

// --- property tests --------------------------------------------------------
//
// qcheck 1.x style: the property function takes the generated value and
// returns Nil, using `assert` (or `should`) to signal failure. Shrinking
// finds the smallest counter-example.

/// For any argv, the `rest` returned by parse/1 must be the tail of the input.
pub fn parse_preserves_tail_prop_test() {
  use args <- qcheck.given(argv_generator())
  let #(_cmd, rest) = parse(args)
  let expected_rest = case args {
    [] -> []
    [_, ..r] -> r
  }
  assert rest == expected_rest
}

/// Any first token that is not a known keyword must parse to Unknown(token)
/// and pass the remaining args through untouched.
pub fn parse_unknown_is_stable_prop_test() {
  use token <- qcheck.given(non_keyword_token())
  let #(cmd, rest) = parse([token, "x", "y"])
  assert cmd == Unknown(token)
  assert rest == ["x", "y"]
}

// --- generators ------------------------------------------------------------

fn argv_generator() -> qcheck.Generator(List(String)) {
  qcheck.list_from(qcheck.non_empty_string())
}

/// Strings guaranteed not to collide with a reserved subcommand keyword,
/// so we can property-test the Unknown branch without flaky collisions.
fn non_keyword_token() -> qcheck.Generator(String) {
  qcheck.non_empty_string()
  |> qcheck.map(fn(s) { "x-" <> s })
}
