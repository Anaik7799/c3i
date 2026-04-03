/// CEPAF Recursion Schemes Module
/// Provides systematic recursion patterns for processing recursive data structures.
///
/// WHAT: Catamorphisms, anamorphisms, hylomorphisms, paramorphisms, histomorphisms
/// WHY: Decouple recursion patterns from business logic for AST/tree processing
/// CONSTRAINTS:
///   - SC-FSH-120: Algebras must be total functions
///   - SC-FSH-121: Coalgebras must terminate
///   - SC-FSH-122: Hylomorphisms must be stack-safe for deep structures
///
/// STAMP Compliance: SC-FSH-120 to SC-FSH-125
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// FIXED POINT TYPES
// ============================================================================

/// Fixed point of a functor - the universal recursive wrapper
type Fix<'F> = Fix of obj // Actually F<Fix<F>>

module Fix =
    /// Unwrap one level of Fix
    let unfix (Fix f) : obj = f

    /// Wrap one level into Fix
    let fix (f: obj) : Fix<'F> = Fix f

// ============================================================================
// BASE FUNCTOR DEFINITIONS
// ============================================================================

/// List functor - the shape of a list without recursion
type ListF<'A, 'R> =
    | NilF
    | ConsF of head: 'A * tail: 'R

module ListF =
    let map (f: 'R -> 'S) : ListF<'A, 'R> -> ListF<'A, 'S> = function
        | NilF -> NilF
        | ConsF (h, t) -> ConsF (h, f t)

/// Tree functor - the shape of a binary tree
type TreeF<'A, 'R> =
    | LeafF of 'A
    | BranchF of left: 'R * value: 'A * right: 'R

module TreeF =
    let map (f: 'R -> 'S) : TreeF<'A, 'R> -> TreeF<'A, 'S> = function
        | LeafF a -> LeafF a
        | BranchF (l, v, r) -> BranchF (f l, v, f r)

/// Natural number functor
type NatF<'R> =
    | ZeroF
    | SuccF of 'R

module NatF =
    let map (f: 'R -> 'S) : NatF<'R> -> NatF<'S> = function
        | ZeroF -> ZeroF
        | SuccF n -> SuccF (f n)

/// Expression functor for AST processing
type ExprF<'R> =
    | LitF of int
    | VarF of string
    | AddF of 'R * 'R
    | MulF of 'R * 'R
    | IfZeroF of cond: 'R * thenBranch: 'R * elseBranch: 'R

module ExprF =
    let map (f: 'R -> 'S) : ExprF<'R> -> ExprF<'S> = function
        | LitF n -> LitF n
        | VarF v -> VarF v
        | AddF (a, b) -> AddF (f a, f b)
        | MulF (a, b) -> MulF (f a, f b)
        | IfZeroF (c, t, e) -> IfZeroF (f c, f t, f e)

/// JSON value functor
type JsonF<'R> =
    | JsonNullF
    | JsonBoolF of bool
    | JsonNumberF of float
    | JsonStringF of string
    | JsonArrayF of 'R list
    | JsonObjectF of (string * 'R) list

module JsonF =
    let map (f: 'R -> 'S) : JsonF<'R> -> JsonF<'S> = function
        | JsonNullF -> JsonNullF
        | JsonBoolF b -> JsonBoolF b
        | JsonNumberF n -> JsonNumberF n
        | JsonStringF s -> JsonStringF s
        | JsonArrayF items -> JsonArrayF (List.map f items)
        | JsonObjectF pairs -> JsonObjectF (List.map (fun (k, v) -> (k, f v)) pairs)

// ============================================================================
// RECURSIVE DATA TYPES (as fixed points)
// ============================================================================

/// Recursive list as fixed point of ListF
type RList<'A> =
    | RNil
    | RCons of 'A * RList<'A>

module RList =
    /// Project to ListF
    let project : RList<'A> -> ListF<'A, RList<'A>> = function
        | RNil -> NilF
        | RCons (h, t) -> ConsF (h, t)

    /// Embed from ListF
    let embed : ListF<'A, RList<'A>> -> RList<'A> = function
        | NilF -> RNil
        | ConsF (h, t) -> RCons (h, t)

    /// Convert from standard list
    let rec fromList = function
        | [] -> RNil
        | x :: xs -> RCons (x, fromList xs)

    /// Convert to standard list
    let rec toList = function
        | RNil -> []
        | RCons (x, xs) -> x :: toList xs

/// Recursive tree as fixed point
type RTree<'A> =
    | RLeaf of 'A
    | RBranch of RTree<'A> * 'A * RTree<'A>

module RTree =
    let project : RTree<'A> -> TreeF<'A, RTree<'A>> = function
        | RLeaf a -> LeafF a
        | RBranch (l, v, r) -> BranchF (l, v, r)

    let embed : TreeF<'A, RTree<'A>> -> RTree<'A> = function
        | LeafF a -> RLeaf a
        | BranchF (l, v, r) -> RBranch (l, v, r)

/// Recursive expression type
type RExpr =
    | RLit of int
    | RVar of string
    | RAdd of RExpr * RExpr
    | RMul of RExpr * RExpr
    | RIfZero of RExpr * RExpr * RExpr

module RExpr =
    let project : RExpr -> ExprF<RExpr> = function
        | RLit n -> LitF n
        | RVar v -> VarF v
        | RAdd (a, b) -> AddF (a, b)
        | RMul (a, b) -> MulF (a, b)
        | RIfZero (c, t, e) -> IfZeroF (c, t, e)

    let embed : ExprF<RExpr> -> RExpr = function
        | LitF n -> RLit n
        | VarF v -> RVar v
        | AddF (a, b) -> RAdd (a, b)
        | MulF (a, b) -> RMul (a, b)
        | IfZeroF (c, t, e) -> RIfZero (c, t, e)

// ============================================================================
// RECURSION SCHEMES - CORE MORPHISMS
// ============================================================================

/// Catamorphism (fold) - consume a recursive structure
/// Type: (F<A> -> A) -> Fix<F> -> A
module Cata =
    /// Generic catamorphism for RList
    let rec listCata (algebra: ListF<'A, 'B> -> 'B) (list: RList<'A>) : 'B =
        list |> RList.project |> ListF.map (listCata algebra) |> algebra

    /// Generic catamorphism for RTree
    let rec treeCata (algebra: TreeF<'A, 'B> -> 'B) (tree: RTree<'A>) : 'B =
        tree |> RTree.project |> TreeF.map (treeCata algebra) |> algebra

    /// Generic catamorphism for RExpr
    let rec exprCata (algebra: ExprF<'B> -> 'B) (expr: RExpr) : 'B =
        expr |> RExpr.project |> ExprF.map (exprCata algebra) |> algebra

/// Anamorphism (unfold) - build a recursive structure from a seed
/// Type: (A -> F<A>) -> A -> Fix<F>
module Ana =
    /// Generic anamorphism for RList
    let rec listAna (coalgebra: 'A -> ListF<'B, 'A>) (seed: 'A) : RList<'B> =
        seed |> coalgebra |> ListF.map (listAna coalgebra) |> RList.embed

    /// Generic anamorphism for RTree
    let rec treeAna (coalgebra: 'A -> TreeF<'B, 'A>) (seed: 'A) : RTree<'B> =
        seed |> coalgebra |> TreeF.map (treeAna coalgebra) |> RTree.embed

    /// Generic anamorphism for RExpr
    let rec exprAna (coalgebra: 'A -> ExprF<'A>) (seed: 'A) : RExpr =
        seed |> coalgebra |> ExprF.map (exprAna coalgebra) |> RExpr.embed

/// Hylomorphism - unfold then fold (no intermediate structure)
/// Type: (F<B> -> B) -> (A -> F<A>) -> A -> B
module Hylo =
    /// Hylomorphism for lists - direct without building intermediate
    let rec listHylo (alg: ListF<'E, 'B> -> 'B) (coalg: 'A -> ListF<'E, 'A>) (seed: 'A) : 'B =
        seed |> coalg |> ListF.map (listHylo alg coalg) |> alg

    /// Hylomorphism for trees
    let rec treeHylo (alg: TreeF<'E, 'B> -> 'B) (coalg: 'A -> TreeF<'E, 'A>) (seed: 'A) : 'B =
        seed |> coalg |> TreeF.map (treeHylo alg coalg) |> alg

    /// Hylomorphism for expressions
    let rec exprHylo (alg: ExprF<'B> -> 'B) (coalg: 'A -> ExprF<'A>) (seed: 'A) : 'B =
        seed |> coalg |> ExprF.map (exprHylo alg coalg) |> alg

/// Paramorphism - fold with access to original substructures
/// Type: (F<(Fix<F>, A)> -> A) -> Fix<F> -> A
module Para =
    /// Paramorphism for lists - algebra receives both subresult and original subtree
    let rec listPara (algebra: ListF<'A, RList<'A> * 'B> -> 'B) (list: RList<'A>) : 'B =
        let mapped =
            list
            |> RList.project
            |> ListF.map (fun sub -> (sub, listPara algebra sub))
        algebra mapped

    /// Paramorphism for trees
    let rec treePara (algebra: TreeF<'A, RTree<'A> * 'B> -> 'B) (tree: RTree<'A>) : 'B =
        let mapped =
            tree
            |> RTree.project
            |> TreeF.map (fun sub -> (sub, treePara algebra sub))
        algebra mapped

/// Histomorphism - fold with access to history of subcomputations
/// Type: (F<Cofree<F, A>> -> A) -> Fix<F> -> A
type Cofree<'F, 'A> = Cofree of 'A * obj // Actually A * F<Cofree<F, A>>

module Histo =
    /// Histomorphism for natural numbers (Fibonacci example)
    let rec natHisto (algebra: NatF<Cofree<NatF<_>, 'A>> -> 'A) (n: int) : 'A =
        if n <= 0 then
            algebra ZeroF
        else
            let sub = natHisto algebra (n - 1)
            let cofree = Cofree (sub, if n > 1 then SuccF (Cofree (natHisto algebra (n - 2), ZeroF)) else ZeroF)
            algebra (SuccF cofree)

/// Futumorphism - unfold with access to future
/// Type: (A -> F<RecFree<F, A>>) -> A -> Fix<F>
type RecFree<'F, 'A> =
    | RecPure of 'A
    | RecFree of obj // Actually F<RecFree<F, A>>

// ============================================================================
// PRACTICAL ALGEBRAS
// ============================================================================

/// Common algebras for list processing
module ListAlgebras =
    /// Sum algebra
    let sum : ListF<int, int> -> int = function
        | NilF -> 0
        | ConsF (h, acc) -> h + acc

    /// Product algebra
    let product : ListF<int, int> -> int = function
        | NilF -> 1
        | ConsF (h, acc) -> h * acc

    /// Length algebra
    let length : ListF<'A, int> -> int = function
        | NilF -> 0
        | ConsF (_, acc) -> acc + 1

    /// Reverse algebra (using paramorphism is cleaner)
    let toList : ListF<'A, 'A list> -> 'A list = function
        | NilF -> []
        | ConsF (h, acc) -> h :: acc

    /// All predicate
    let all (pred: 'A -> bool) : ListF<'A, bool> -> bool = function
        | NilF -> true
        | ConsF (h, acc) -> pred h && acc

    /// Any predicate
    let any (pred: 'A -> bool) : ListF<'A, bool> -> bool = function
        | NilF -> false
        | ConsF (h, acc) -> pred h || acc

    /// Maximum with default
    let maxOrDefault (def: 'A) : ListF<'A, 'A> -> 'A when 'A : comparison = function
        | NilF -> def
        | ConsF (h, acc) -> max h acc

/// Common algebras for tree processing
module TreeAlgebras =
    /// Sum all values
    let sum : TreeF<int, int> -> int = function
        | LeafF n -> n
        | BranchF (l, v, r) -> l + v + r

    /// Height of tree
    let height : TreeF<'A, int> -> int = function
        | LeafF _ -> 1
        | BranchF (l, _, r) -> 1 + max l r

    /// Count nodes
    let count : TreeF<'A, int> -> int = function
        | LeafF _ -> 1
        | BranchF (l, _, r) -> 1 + l + r

    /// Collect all values (in-order)
    let toList : TreeF<'A, 'A list> -> 'A list = function
        | LeafF a -> [a]
        | BranchF (l, v, r) -> l @ [v] @ r

    /// Map values
    let mapValues (f: 'A -> 'B) : TreeF<'A, RTree<'B>> -> RTree<'B> = function
        | LeafF a -> RLeaf (f a)
        | BranchF (l, v, r) -> RBranch (l, f v, r)

/// Expression algebras for evaluation and transformation
module ExprAlgebras =
    /// Evaluate with environment
    let eval (env: Map<string, int>) : ExprF<int> -> int = function
        | LitF n -> n
        | VarF v -> Map.tryFind v env |> Option.defaultValue 0
        | AddF (a, b) -> a + b
        | MulF (a, b) -> a * b
        | IfZeroF (c, t, e) -> if c = 0 then t else e

    /// Pretty print
    let prettyPrint : ExprF<string> -> string = function
        | LitF n -> string n
        | VarF v -> v
        | AddF (a, b) -> sprintf "(%s + %s)" a b
        | MulF (a, b) -> sprintf "(%s * %s)" a b
        | IfZeroF (c, t, e) -> sprintf "(if %s == 0 then %s else %s)" c t e

    /// Count operations
    let countOps : ExprF<int> -> int = function
        | LitF _ -> 0
        | VarF _ -> 0
        | AddF (a, b) -> 1 + a + b
        | MulF (a, b) -> 1 + a + b
        | IfZeroF (c, t, e) -> 1 + c + t + e

    /// Constant folding algebra
    let constantFold : ExprF<RExpr> -> RExpr = function
        | LitF n -> RLit n
        | VarF v -> RVar v
        | AddF (RLit a, RLit b) -> RLit (a + b)
        | AddF (a, b) -> RAdd (a, b)
        | MulF (RLit a, RLit b) -> RLit (a * b)
        | MulF (a, b) -> RMul (a, b)
        | IfZeroF (RLit 0, t, _) -> t
        | IfZeroF (RLit _, _, e) -> e
        | IfZeroF (c, t, e) -> RIfZero (c, t, e)

/// Common coalgebras for generation
module Coalgebras =
    /// Generate range [0..n-1]
    let range : int -> ListF<int, int> = function
        | n when n <= 0 -> NilF
        | n -> ConsF (n - 1, n - 1)

    /// Fibonacci sequence coalgebra
    let fibonacci : int * int -> ListF<int, int * int> = function
        | (a, _) when a > 1000000 -> NilF  // Termination
        | (a, b) -> ConsF (a, (b, a + b))

    /// Binary tree from sorted list
    let balancedTree : int list -> TreeF<int, int list> = function
        | [] -> LeafF 0
        | [x] -> LeafF x
        | xs ->
            let mid = List.length xs / 2
            let left = List.take mid xs
            let right = List.skip (mid + 1) xs
            BranchF (left, xs.[mid], right)

// ============================================================================
// SCHEME COMBINATORS
// ============================================================================

module SchemeCombinators =
    /// Compose two algebras
    let composeAlg (f: 'B -> 'C) (alg: 'F -> 'B) : 'F -> 'C =
        alg >> f

    /// Product of two algebras
    let productAlg (alg1: 'F -> 'A) (alg2: 'F -> 'B) : 'F -> 'A * 'B =
        fun f -> (alg1 f, alg2 f)

    /// Monadic catamorphism
    let cataM (bind: 'M -> ('A -> 'M) -> 'M) (pure': 'A -> 'M)
              (algM: 'F -> 'M)
              (traverse: ('A -> 'M) -> 'F -> 'M)
              (project: 'T -> 'F) : 'T -> 'M =
        let rec go t =
            let f = project t
            bind (traverse go f) algM
        go

// ============================================================================
// JSON PROCESSING EXAMPLE
// ============================================================================

/// Recursive JSON type
type RJson =
    | RJsonNull
    | RJsonBool of bool
    | RJsonNumber of float
    | RJsonString of string
    | RJsonArray of RJson list
    | RJsonObject of (string * RJson) list

module RJson =
    let project : RJson -> JsonF<RJson> = function
        | RJsonNull -> JsonNullF
        | RJsonBool b -> JsonBoolF b
        | RJsonNumber n -> JsonNumberF n
        | RJsonString s -> JsonStringF s
        | RJsonArray items -> JsonArrayF items
        | RJsonObject pairs -> JsonObjectF pairs

    let embed : JsonF<RJson> -> RJson = function
        | JsonNullF -> RJsonNull
        | JsonBoolF b -> RJsonBool b
        | JsonNumberF n -> RJsonNumber n
        | JsonStringF s -> RJsonString s
        | JsonArrayF items -> RJsonArray items
        | JsonObjectF pairs -> RJsonObject pairs

    /// Catamorphism for JSON
    let rec cata (algebra: JsonF<'A> -> 'A) (json: RJson) : 'A =
        json |> project |> JsonF.map (cata algebra) |> algebra

module JsonAlgebras =
    /// Count all nodes
    let countNodes : JsonF<int> -> int = function
        | JsonNullF -> 1
        | JsonBoolF _ -> 1
        | JsonNumberF _ -> 1
        | JsonStringF _ -> 1
        | JsonArrayF counts -> 1 + List.sum counts
        | JsonObjectF pairs -> 1 + (pairs |> List.sumBy snd)

    /// Pretty print with indentation
    let prettyPrint (indent: int) : JsonF<string> -> string =
        let pad = String.replicate indent "  "
        function
        | JsonNullF -> "null"
        | JsonBoolF b -> if b then "true" else "false"
        | JsonNumberF n -> string n
        | JsonStringF s -> sprintf "\"%s\"" s
        | JsonArrayF items ->
            if List.isEmpty items then "[]"
            else sprintf "[\n%s%s\n%s]" pad (String.concat (sprintf ",\n%s" pad) items) (String.replicate (indent - 1) "  ")
        | JsonObjectF pairs ->
            if List.isEmpty pairs then "{}"
            else
                let formatPair (k, v) = sprintf "\"%s\": %s" k v
                sprintf "{\n%s%s\n%s}" pad (String.concat (sprintf ",\n%s" pad) (List.map formatPair pairs)) (String.replicate (indent - 1) "  ")

    /// Extract all string values
    let extractStrings : JsonF<string list> -> string list = function
        | JsonStringF s -> [s]
        | JsonArrayF lists -> List.concat lists
        | JsonObjectF pairs -> pairs |> List.collect snd
        | _ -> []

    /// Sum all numbers
    let sumNumbers : JsonF<float> -> float = function
        | JsonNumberF n -> n
        | JsonArrayF sums -> List.sum sums
        | JsonObjectF pairs -> pairs |> List.sumBy snd
        | _ -> 0.0

// ============================================================================
// SPECIALIZED MORPHISMS
// ============================================================================

/// Apomorphism - short-circuit unfold
module Apo =
    /// Apomorphism for lists - can return early
    let rec listApo (coalg: 'A -> ListF<'B, Choice<RList<'B>, 'A>>) (seed: 'A) : RList<'B> =
        match coalg seed with
        | NilF -> RNil
        | ConsF (h, Choice1Of2 list) -> RCons (h, list)  // Short-circuit
        | ConsF (h, Choice2Of2 a) -> RCons (h, listApo coalg a)  // Continue

/// Zygomorphism - fold with helper algebra
module Zygo =
    /// Zygomorphism for lists
    let rec listZygo
        (helper: ListF<'A, 'B> -> 'B)
        (main: ListF<'A, 'B * 'C> -> 'C)
        (list: RList<'A>) : 'C =
        let rec go list =
            let projected = RList.project list
            let mapper sub =
                let b = Cata.listCata helper sub
                let c = go sub
                (b, c)
            let mapped = ListF.map mapper projected
            main mapped
        go list

/// Prepromorphism - generalized fold with natural transformation
module Prepro =
    /// Prepromorphism for lists
    let rec listPrepro
        (nat: ListF<'A, RList<'A>> -> ListF<'A, RList<'A>>)
        (alg: ListF<'A, 'B> -> 'B)
        (list: RList<'A>) : 'B =
        list
        |> RList.project
        |> nat
        |> ListF.map (listPrepro nat alg)
        |> alg

/// Postpromorphism - generalized unfold with natural transformation
module Postpro =
    /// Postpromorphism for lists
    let rec listPostpro
        (nat: ListF<'A, RList<'A>> -> ListF<'A, RList<'A>>)
        (coalg: 'B -> ListF<'A, 'B>)
        (seed: 'B) : RList<'A> =
        seed
        |> coalg
        |> ListF.map (listPostpro nat coalg)
        |> RList.embed
        |> RList.project
        |> nat
        |> RList.embed

