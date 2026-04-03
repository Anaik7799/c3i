/// CEPAF Parser Combinators Module
/// Provides monadic parser combinators for DSL and configuration parsing.
///
/// WHAT: Composable parser combinators following the Parsec/FParsec style
/// WHY: Enables type-safe parsing of DSLs, configs, and protocols without regex
/// CONSTRAINTS:
///   - SC-FSH-070: Parsers must be pure and composable
///   - SC-FSH-071: Error messages must include position info
///   - SC-FSH-072: Backtracking must be explicit (attempt combinator)
///
/// STAMP Compliance: SC-FSH-070 to SC-FSH-072
/// TDG Compliance: Tests written before implementation
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// PARSER TYPES
// ============================================================================

/// Position in the input stream
type Position = {
    Index: int
    Line: int
    Column: int
}

module Position =
    let initial = { Index = 0; Line = 1; Column = 1 }

    let advance c pos =
        match c with
        | '\n' -> { Index = pos.Index + 1; Line = pos.Line + 1; Column = 1 }
        | _ -> { Index = pos.Index + 1; Line = pos.Line; Column = pos.Column + 1 }

    let advanceString (s: string) pos =
        s |> Seq.fold (fun p c -> advance c p) pos

/// Parser state
type ParserState = {
    Input: string
    Position: Position
}

module ParserState =
    let create input = { Input = input; Position = Position.initial }

    let remaining state =
        if state.Position.Index >= state.Input.Length then ""
        else state.Input.Substring(state.Position.Index)

    let peek state =
        if state.Position.Index >= state.Input.Length then None
        else Some state.Input.[state.Position.Index]

    let advance state =
        match peek state with
        | None -> state
        | Some c -> { state with Position = Position.advance c state.Position }

    let advanceBy n state =
        let rec loop count s =
            if count <= 0 then s
            else loop (count - 1) (advance s)
        loop n state

/// Parser error
type ParserError = {
    Message: string
    Position: Position
    Expected: string list
}

module ParserError =
    let create msg pos = { Message = msg; Position = pos; Expected = [] }

    let expected exp pos = { Message = sprintf "Expected %s" exp; Position = pos; Expected = [exp] }

    let merge e1 e2 =
        if e1.Position.Index > e2.Position.Index then e1
        elif e2.Position.Index > e1.Position.Index then e2
        else { e1 with Expected = e1.Expected @ e2.Expected |> List.distinct }

    let format (input: string) error =
        let line =
            input.Split([|'\n'|])
            |> Array.tryItem (error.Position.Line - 1)
            |> Option.defaultValue ""
        let pointer = String.replicate (error.Position.Column - 1) " " + "^"
        sprintf "Parse error at line %d, column %d:\n%s\n%s\n%s"
            error.Position.Line
            error.Position.Column
            line
            pointer
            error.Message

/// Parser result
type ParseResult<'T> =
    | Success of 'T * ParserState
    | Failure of ParserError

/// The Parser monad
type Parser<'T> = Parser of (ParserState -> ParseResult<'T>)

// ============================================================================
// PARSER MONAD
// ============================================================================

module Parser =
    /// Run a parser
    let run input (Parser p) =
        p (ParserState.create input)

    /// Run and extract result or error string
    let runResult input parser =
        match run input parser with
        | Success (v, _) -> Ok v
        | Failure e -> Error (ParserError.format input e)

    /// Pure/return - wrap a value in a parser
    let pure' x = Parser (fun state -> Success (x, state))

    /// Map over parser result
    let map f (Parser p) = Parser (fun state ->
        match p state with
        | Success (x, state') -> Success (f x, state')
        | Failure e -> Failure e)

    /// Bind/flatMap
    let bind f (Parser p) = Parser (fun state ->
        match p state with
        | Success (x, state') ->
            let (Parser p') = f x
            p' state'
        | Failure e -> Failure e)

    /// Apply parser function to parser value (Applicative)
    let apply pf px = bind (fun f -> map f px) pf

    /// Sequence two parsers, keep second result
    let andThen (Parser p1) (Parser p2) = Parser (fun state ->
        match p1 state with
        | Success (_, state') -> p2 state'
        | Failure e -> Failure e)

    /// Sequence two parsers, keep first result
    let andThenLeft (Parser p1) (Parser p2) = Parser (fun state ->
        match p1 state with
        | Success (x, state') ->
            match p2 state' with
            | Success (_, state'') -> Success (x, state'')
            | Failure e -> Failure e
        | Failure e -> Failure e)

    /// Alternative - try first parser, if fails try second
    let orElse (Parser p1) (Parser p2) = Parser (fun state ->
        match p1 state with
        | Success _ as result -> result
        | Failure e1 ->
            match p2 state with
            | Success _ as result -> result
            | Failure e2 -> Failure (ParserError.merge e1 e2))

    /// Explicit backtracking - restore state on failure
    let attempt (Parser p) = Parser (fun state ->
        match p state with
        | Success _ as result -> result
        | Failure e -> Failure { e with Position = state.Position })

    /// Zero - always fails
    let zero () = Parser (fun state ->
        Failure (ParserError.create "zero" state.Position))

    /// Label a parser for better error messages
    let label msg (Parser p) = Parser (fun state ->
        match p state with
        | Success _ as result -> result
        | Failure e -> Failure { e with Message = msg; Expected = [msg] })

// ============================================================================
// PARSER COMPUTATION EXPRESSION
// ============================================================================

type ParserBuilder() =
    member _.Return(x) = Parser.pure' x
    member _.ReturnFrom(p) = p
    member _.Bind(p, f) = Parser.bind f p
    member _.Zero() = Parser.zero ()
    member _.Combine(p1, p2) = Parser.andThen p1 p2
    member _.Delay(f) = Parser (fun state ->
        let (Parser p) = f ()
        p state)

[<AutoOpen>]
module ParserBuilderModule =
    let parser = ParserBuilder()

// ============================================================================
// PRIMITIVE PARSERS
// ============================================================================

module Parsers =
    /// Parse end of input
    let eof = Parser (fun state ->
        if state.Position.Index >= state.Input.Length then
            Success ((), state)
        else
            Failure (ParserError.expected "end of input" state.Position))

    /// Parse any single character
    let anyChar = Parser (fun state ->
        match ParserState.peek state with
        | Some c -> Success (c, ParserState.advance state)
        | None -> Failure (ParserError.expected "any character" state.Position))

    /// Parse a specific character
    let char c = Parser (fun state ->
        match ParserState.peek state with
        | Some ch when ch = c -> Success (c, ParserState.advance state)
        | _ -> Failure (ParserError.expected (sprintf "'%c'" c) state.Position))

    /// Parse a character satisfying predicate
    let satisfy predicate desc = Parser (fun state ->
        match ParserState.peek state with
        | Some c when predicate c -> Success (c, ParserState.advance state)
        | _ -> Failure (ParserError.expected desc state.Position))

    /// Parse a specific string
    let string (s: string) = Parser (fun state ->
        let remaining = ParserState.remaining state
        if remaining.StartsWith(s) then
            Success (s, ParserState.advanceBy s.Length state)
        else
            Failure (ParserError.expected (sprintf "\"%s\"" s) state.Position))

    /// Parse one of the given characters
    let oneOf (chars: string) =
        satisfy (fun c -> chars.IndexOf(c) >= 0) (sprintf "one of '%s'" chars)

    /// Parse none of the given characters
    let noneOf (chars: string) =
        satisfy (fun c -> chars.IndexOf(c) < 0) (sprintf "none of '%s'" chars)

    /// Parse a digit
    let digit = satisfy Char.IsDigit "digit"

    /// Parse a letter
    let letter = satisfy Char.IsLetter "letter"

    /// Parse alphanumeric
    let alphaNum = satisfy Char.IsLetterOrDigit "alphanumeric"

    /// Parse whitespace character
    let whitespace = satisfy Char.IsWhiteSpace "whitespace"

    /// Parse a newline
    let newline = Parser.orElse (string "\r\n") (string "\n") |> Parser.map (fun _ -> '\n')

    /// Skip zero or more whitespace
    let spaces = Parser (fun state ->
        let rec skip s =
            match ParserState.peek s with
            | Some c when Char.IsWhiteSpace c -> skip (ParserState.advance s)
            | _ -> s
        Success ((), skip state))

    /// Skip one or more whitespace
    let spaces1 = Parser.andThen whitespace spaces |> Parser.map (fun _ -> ())

// ============================================================================
// COMBINATORS
// ============================================================================

module Combinators =
    open Parsers

    /// Try each parser in sequence until one succeeds
    let choice parsers =
        parsers |> List.reduce Parser.orElse

    /// Parse zero or more occurrences
    let many (Parser p) = Parser (fun state ->
        let rec loop acc s =
            match p s with
            | Success (x, s') -> loop (x :: acc) s'
            | Failure _ -> Success (List.rev acc, s)
        loop [] state)

    /// Parse one or more occurrences
    let many1 p = parser {
        let! first = p
        let! rest = many p
        return first :: rest
    }

    /// Parse zero or more, separated by separator
    let sepBy p sep =
        Parser.orElse
            (parser {
                let! first = p
                let! rest = many (Parser.andThen sep p)
                return first :: rest
            })
            (Parser.pure' [])

    /// Parse one or more, separated by separator
    let sepBy1 p sep = parser {
        let! first = p
        let! rest = many (Parser.andThen sep p)
        return first :: rest
    }

    /// Parse p separated by and ending with sep
    let endBy p sep = many (parser {
        let! x = p
        let! _ = sep
        return x
    })

    /// Optional parser
    let optional p =
        Parser.orElse (Parser.map Some p) (Parser.pure' None)

    /// Parse between open and close
    let between popen pclose p = parser {
        let! _ = popen
        let! x = p
        let! _ = pclose
        return x
    }

    /// Parse n occurrences
    let count n p =
        let rec loop acc remaining =
            if remaining <= 0 then Parser.pure' (List.rev acc)
            else parser {
                let! x = p
                return! loop (x :: acc) (remaining - 1)
            }
        loop [] n

    /// Skip zero or more
    let skipMany p = many p |> Parser.map ignore

    /// Skip one or more
    let skipMany1 p = many1 p |> Parser.map ignore

    /// Parse with lookahead (doesn't consume input)
    let lookAhead (Parser p) = Parser (fun state ->
        match p state with
        | Success (x, _) -> Success (x, state)  // Don't advance state
        | Failure e -> Failure e)

    /// Negative lookahead (succeeds if parser fails)
    let notFollowedBy (Parser p) = Parser (fun state ->
        match p state with
        | Success _ -> Failure (ParserError.create "unexpected" state.Position)
        | Failure _ -> Success ((), state))

    /// Chainl - left-associative chain
    let chainl1 p op = parser {
        let! first = p
        let rec loop acc =
            Parser.orElse
                (parser {
                    let! f = op
                    let! x = p
                    return! loop (f acc x)
                })
                (Parser.pure' acc)
        return! loop first
    }

    /// Chainr - right-associative chain
    let rec chainr1 p op =
        parser {
            let! x = p
            return!
                Parser.orElse
                    (parser {
                        let! f = op
                        let! y = chainr1 p op
                        return f x y
                    })
                    (Parser.pure' x)
        }

    /// Memoize parser for left-recursive grammars
    let memoize (Parser p) =
        let cache = System.Collections.Concurrent.ConcurrentDictionary<int, ParseResult<'T>>()
        Parser (fun state ->
            cache.GetOrAdd(state.Position.Index, fun _ -> p state))

// ============================================================================
// TOKEN PARSERS
// ============================================================================

module Tokens =
    open Parsers
    open Combinators

    /// Parse an integer
    let integer =
        parser {
            let! sign = optional (char '-')
            let! digits = many1 digit
            let numStr = String(List.toArray digits)
            let n = Int32.Parse(numStr)
            return if sign.IsSome then -n else n
        }
        |> Parser.label "integer"

    /// Parse a floating-point number
    let float' =
        let decPart' =
            parser {
                let! _ = char '.'
                let! frac = many1 digit
                return frac
            }
        let expPart' =
            parser {
                let! _ = oneOf "eE"
                let! expSign = optional (oneOf "+-")
                let! exp = many1 digit
                return (expSign, exp)
            }
        parser {
            let! sign = optional (char '-')
            let! intPart = many1 digit
            let! decPart = optional decPart'
            let! expPart = optional expPart'

            let sb = System.Text.StringBuilder()
            if sign.IsSome then sb.Append('-') |> ignore
            sb.Append(String(List.toArray intPart)) |> ignore
            match decPart with
            | Some frac ->
                sb.Append('.') |> ignore
                sb.Append(String(List.toArray frac)) |> ignore
            | None -> ()
            match expPart with
            | Some (expSign, exp) ->
                sb.Append('e') |> ignore
                match expSign with
                | Some s -> sb.Append(s) |> ignore
                | None -> ()
                sb.Append(String(List.toArray exp)) |> ignore
            | None -> ()

            return Double.Parse(sb.ToString())
        }
        |> Parser.label "float"

    /// Parse a quoted string
    let quotedString quote escape =
        let escapeSeq =
            parser {
                let! _ = char escape
                let! c = anyChar
                return
                    match c with
                    | 'n' -> '\n'
                    | 'r' -> '\r'
                    | 't' -> '\t'
                    | c -> c
            }
        parser {
            let! _ = char quote
            let! chars = many (
                Parser.orElse
                    escapeSeq
                    (satisfy (fun c -> c <> quote && c <> escape) "string char"))
            let! _ = char quote
            return String(List.toArray chars)
        }

    /// Double-quoted string
    let doubleQuotedString =
        quotedString '"' '\\'
        |> Parser.label "string"

    /// Single-quoted string
    let singleQuotedString =
        quotedString '\'' '\\'
        |> Parser.label "string"

    /// Parse an identifier (letter followed by alphanums)
    let identifier =
        parser {
            let! first = letter
            let! rest = many (Parser.orElse alphaNum (char '_'))
            return String(first :: rest |> List.toArray)
        }
        |> Parser.label "identifier"

    /// Lexeme - parse and skip trailing whitespace
    let lexeme p =
        parser {
            let! x = p
            let! _ = spaces
            return x
        }

    /// Symbol - parse string and skip trailing whitespace
    let symbol s = lexeme (string s)

    /// Parenthesized
    let parens p = between (symbol "(") (symbol ")") p

    /// Bracketed
    let brackets p = between (symbol "[") (symbol "]") p

    /// Braced
    let braces p = between (symbol "{") (symbol "}") p

    /// Comma-separated list
    let commaSep p = sepBy p (symbol ",")

    /// Comma-separated list with at least one element
    let commaSep1 p = sepBy1 p (symbol ",")

// ============================================================================
// JSON PARSER (Example/Demo)
// ============================================================================

module JsonParser =
    open Parsers
    open Combinators
    open Tokens

    /// JSON Value type
    type JsonValue =
        | JsonNull
        | JsonBool of bool
        | JsonNumber of float
        | JsonString of string
        | JsonArray of JsonValue list
        | JsonObject of (string * JsonValue) list

    /// Forward reference for recursive parsing
    let jsonValue, jsonValueRef =
        let r = ref (Unchecked.defaultof<Parser<JsonValue>>)
        Parser (fun state ->
            let (Parser p) = !r
            p state), r

    /// JSON null
    let jsonNull =
        symbol "null" |> Parser.map (fun _ -> JsonNull)

    /// JSON boolean
    let jsonBool =
        Parser.orElse
            (symbol "true" |> Parser.map (fun _ -> JsonBool true))
            (symbol "false" |> Parser.map (fun _ -> JsonBool false))

    /// JSON number
    let jsonNumber =
        lexeme float' |> Parser.map JsonNumber

    /// JSON string
    let jsonString =
        lexeme doubleQuotedString |> Parser.map JsonString

    /// JSON array
    let jsonArray =
        brackets (commaSep jsonValue) |> Parser.map JsonArray

    /// JSON object member
    let jsonMember = parser {
        let! key = lexeme doubleQuotedString
        let! _ = symbol ":"
        let! value = jsonValue
        return (key, value)
    }

    /// JSON object
    let jsonObject =
        braces (commaSep jsonMember) |> Parser.map JsonObject

    // Initialize the forward reference
    do jsonValueRef := choice [jsonNull; jsonBool; jsonNumber; jsonString; jsonArray; jsonObject]

    /// Parse JSON from string
    let parse input =
        Parser.runResult input (parser {
            let! _ = spaces
            let! value = jsonValue
            let! _ = eof
            return value
        })

// ============================================================================
// DSL BUILDER HELPERS
// ============================================================================

module DslBuilder =
    open Parsers
    open Combinators
    open Tokens

    /// Create keyword parser
    let keyword kw =
        Parser.attempt (parser {
            let! id = identifier
            if id = kw then return kw
            else return! Parser.zero ()
        }) |> Parser.label (sprintf "keyword '%s'" kw)

    /// Parse operator
    let operator (op: string) = symbol op |> Parser.label (sprintf "operator '%s'" op)

    /// Comment - skip to end of line
    let lineComment prefix = parser {
        let! _ = string prefix
        let! _ = many (noneOf "\n\r")
        let! _ = optional newline
        return ()
    }

    /// Block comment
    let blockComment (startMark: string) (endMark: string) =
        let charToString (c: char) = System.String([|c|])
        parser {
            let! _ = string startMark
            let! _ = many (
                Parser.attempt (parser {
                    let! (c: char) = anyChar
                    // Check we're not at the end marker
                    if endMark.StartsWith(charToString c) then
                        let! _ = notFollowedBy (string (endMark.Substring(1)))
                        return c
                    else
                        return c
                }))
            let! _ = string endMark
            return ()
        }

    /// Skip whitespace and comments
    let ws commentParsers =
        skipMany (Parser.orElse spaces1 (choice commentParsers |> Parser.map ignore))
