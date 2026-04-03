/// CEPAF Comonads Module
/// Provides comonad abstractions - the categorical dual of monads.
///
/// WHAT: Identity, Env, Store, Traced, NonEmpty, Zipper comonads
/// WHY: Model context-dependent computation, UI focus, spreadsheet evaluation
/// CONSTRAINTS:
///   - SC-FSH-150: Comonad laws must hold (extract/duplicate/extend)
///   - SC-FSH-151: Store comonad must provide consistent peek/seek
///   - SC-FSH-152: Zipper navigation must be reversible
///
/// STAMP Compliance: SC-FSH-150 to SC-FSH-155
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// COMONAD TYPE CLASS (as module pattern)
// ============================================================================

/// Comonad laws:
/// 1. extract (duplicate w) = w
/// 2. map extract (duplicate w) = w
/// 3. duplicate (duplicate w) = map duplicate (duplicate w)

// ============================================================================
// IDENTITY COMONAD
// ============================================================================

/// Identity comonad - simplest comonad wrapper
type Identity<'A> = Identity of 'A

module Identity =
    /// Extract value from Identity
    let extract (Identity a) = a

    /// Map over Identity
    let map (f: 'A -> 'B) (Identity a) : Identity<'B> = Identity (f a)

    /// Duplicate - wrap in another layer
    let duplicate (w: Identity<'A>) : Identity<Identity<'A>> = Identity w

    /// Extend - apply coKleisli arrow
    let extend (f: Identity<'A> -> 'B) (w: Identity<'A>) : Identity<'B> =
        Identity (f w)

    /// CoKleisli composition
    let (=>>) (w: Identity<'A>) (f: Identity<'A> -> 'B) : Identity<'B> =
        extend f w

// ============================================================================
// ENV COMONAD (Reader's dual - has context, returns value)
// ============================================================================

/// Env comonad - value with environment context
type Env<'E, 'A> = Env of env: 'E * value: 'A

module Env =
    /// Get environment
    let ask (Env (e, _)) = e

    /// Get value (extract)
    let extract (Env (_, a)) = a

    /// Map over value
    let map (f: 'A -> 'B) (Env (e, a)) : Env<'E, 'B> = Env (e, f a)

    /// Duplicate
    let duplicate (Env (e, a) as w) : Env<'E, Env<'E, 'A>> = Env (e, w)

    /// Extend
    let extend (f: Env<'E, 'A> -> 'B) (Env (e, _) as w) : Env<'E, 'B> =
        Env (e, f w)

    /// Local - modify environment for computation
    let local (f: 'E -> 'E) (Env (e, a)) : Env<'E, 'A> = Env (f e, a)

    /// Run with environment
    let runEnv (Env (e, a)) = (e, a)

    /// Create with environment
    let env (e: 'E) (a: 'A) : Env<'E, 'A> = Env (e, a)

    /// CoKleisli composition
    let (=>>) (w: Env<'E, 'A>) (f: Env<'E, 'A> -> 'B) : Env<'E, 'B> =
        extend f w

// ============================================================================
// STORE COMONAD (For spreadsheet-like computation)
// ============================================================================

/// Store comonad - a value at a position, with ability to peek at other positions
type Store<'S, 'A> = Store of getter: ('S -> 'A) * position: 'S

module Store =
    /// Get current value (extract)
    let extract (Store (f, s)) = f s

    /// Get current position
    let pos (Store (_, s)) = s

    /// Peek at a different position
    let peek (s: 'S) (Store (f, _)) = f s

    /// Peek at relative position
    let peeks (g: 'S -> 'S) (Store (f, s)) = f (g s)

    /// Move to new position (seek)
    let seek (s: 'S) (Store (f, _)) : Store<'S, 'A> = Store (f, s)

    /// Move to relative position
    let seeks (g: 'S -> 'S) (Store (f, s)) : Store<'S, 'A> = Store (f, g s)

    /// Map over value
    let map (g: 'A -> 'B) (Store (f, s)) : Store<'S, 'B> =
        Store ((f >> g), s)

    /// Duplicate
    let duplicate (Store (f, s)) : Store<'S, Store<'S, 'A>> =
        Store ((fun s' -> Store (f, s')), s)

    /// Extend
    let extend (g: Store<'S, 'A> -> 'B) (Store (f, s)) : Store<'S, 'B> =
        Store ((fun s' -> g (Store (f, s'))), s)

    /// Create a store
    let store (f: 'S -> 'A) (s: 'S) : Store<'S, 'A> = Store (f, s)

    /// Run a store to get value at position
    let runStore (Store (f, s)) = (f s, s)

    /// CoKleisli composition
    let (=>>) (w: Store<'S, 'A>) (f: Store<'S, 'A> -> 'B) : Store<'S, 'B> =
        extend f w

/// 2D Grid store for cellular automata / image processing
module GridStore =
    type Pos = int * int

    /// Create grid store from 2D array
    let fromArray (arr: 'A[,]) : Store<Pos, 'A> =
        let getter (x, y) =
            let x' = max 0 (min x (Array2D.length1 arr - 1))
            let y' = max 0 (min y (Array2D.length2 arr - 1))
            arr.[x', y']
        Store.store getter (0, 0)

    /// Get neighbors at position
    let neighbors (Store (f, (x, y))) : 'A list =
        [
            f (x-1, y-1); f (x, y-1); f (x+1, y-1)
            f (x-1, y);              f (x+1, y)
            f (x-1, y+1); f (x, y+1); f (x+1, y+1)
        ]

    /// Conway's Game of Life rule
    let gameOfLifeRule (store: Store<Pos, bool>) : bool =
        let alive = Store.extract store
        let aliveNeighbors = neighbors store |> List.filter id |> List.length
        match alive, aliveNeighbors with
        | true, 2 | true, 3 -> true  // Survive
        | false, 3 -> true            // Birth
        | _ -> false                  // Death

// ============================================================================
// TRACED COMONAD (For logging/tracing computation)
// ============================================================================

/// Traced comonad - computation that produces value from trace/log
type Traced<'M, 'A> = Traced of ('M -> 'A)

module Traced =
    /// Requires monoid operations for M
    type IMonoid<'M> =
        abstract Empty: 'M
        abstract Append: 'M -> 'M -> 'M

    /// Extract with empty trace
    let extractWith (monoid: IMonoid<'M>) (Traced f) = f monoid.Empty

    /// Map over result
    let map (g: 'A -> 'B) (Traced f) : Traced<'M, 'B> =
        Traced (f >> g)

    /// Duplicate with monoid
    let duplicateWith (monoid: IMonoid<'M>) (Traced f) : Traced<'M, Traced<'M, 'A>> =
        Traced (fun m1 -> Traced (fun m2 -> f (monoid.Append m1 m2)))

    /// Extend with monoid
    let extendWith (monoid: IMonoid<'M>) (g: Traced<'M, 'A> -> 'B) (Traced f) : Traced<'M, 'B> =
        Traced (fun m1 -> g (Traced (fun m2 -> f (monoid.Append m1 m2))))

    /// Listen to trace
    let listen (m: 'M) (Traced f) = f m

    /// Trace with current value
    let trace (m: 'M) (Traced f) = f m

    /// Create traced from function
    let traced (f: 'M -> 'A) : Traced<'M, 'A> = Traced f

    /// Run with trace
    let runTraced (Traced f) m = f m

/// String traced (log) comonad
module StringTraced =
    let monoid : Traced.IMonoid<string> = {
        new Traced.IMonoid<string> with
            member _.Empty = ""
            member _.Append a b = a + b
    }

    let extract t = Traced.extractWith monoid t
    let duplicate t = Traced.duplicateWith monoid t
    let extend f t = Traced.extendWith monoid f t

/// List traced comonad
module ListTraced =
    let monoid<'T> : Traced.IMonoid<'T list> = {
        new Traced.IMonoid<'T list> with
            member _.Empty = []
            member _.Append a b = a @ b
    }

    let extract t = Traced.extractWith monoid t
    let duplicate t = Traced.duplicateWith monoid t
    let extend f t = Traced.extendWith monoid f t

// ============================================================================
// NON-EMPTY COMONAD
// ============================================================================

/// NonEmpty list - always has at least one element
type NonEmpty<'A> = NonEmpty of head: 'A * tail: 'A list

module NonEmpty =
    /// Create from head and tail
    let create (head: 'A) (tail: 'A list) : NonEmpty<'A> = NonEmpty (head, tail)

    /// Create singleton
    let singleton (a: 'A) : NonEmpty<'A> = NonEmpty (a, [])

    /// Try to create from list
    let ofList (xs: 'A list) : NonEmpty<'A> option =
        match xs with
        | [] -> None
        | h :: t -> Some (NonEmpty (h, t))

    /// Convert to list
    let toList (NonEmpty (h, t)) = h :: t

    /// Get head (extract)
    let extract (NonEmpty (h, _)) = h

    /// Get tail
    let tail (NonEmpty (_, t)) = t

    /// Length
    let length (NonEmpty (_, t)) = 1 + List.length t

    /// Map
    let map (f: 'A -> 'B) (NonEmpty (h, t)) : NonEmpty<'B> =
        NonEmpty (f h, List.map f t)

    /// Duplicate - all suffixes
    let duplicate (NonEmpty (h, t) as ne) : NonEmpty<NonEmpty<'A>> =
        let rec suffixes = function
            | NonEmpty (_, []) as x -> [x]
            | NonEmpty (_, hd :: tl) as x -> x :: suffixes (NonEmpty (hd, tl))
        match suffixes ne with
        | [] -> NonEmpty (ne, [])  // Should never happen
        | x :: xs -> NonEmpty (x, xs)

    /// Extend
    let extend (f: NonEmpty<'A> -> 'B) (ne: NonEmpty<'A>) : NonEmpty<'B> =
        duplicate ne |> map f

    /// Append
    let append (NonEmpty (h1, t1)) (NonEmpty (h2, t2)) : NonEmpty<'A> =
        NonEmpty (h1, t1 @ [h2] @ t2)

    /// Fold
    let fold (folder: 'S -> 'A -> 'S) (initial: 'S) (NonEmpty (h, t)) : 'S =
        List.fold folder (folder initial h) t

    /// Reduce (fold with first element)
    let reduce (f: 'A -> 'A -> 'A) (NonEmpty (h, t)) : 'A =
        List.fold f h t

    /// Reverse
    let rev (NonEmpty (h, t)) : NonEmpty<'A> =
        match List.rev (h :: t) with
        | x :: xs -> NonEmpty (x, xs)
        | [] -> NonEmpty (h, [])  // Should never happen

    /// CoKleisli composition
    let (=>>) (w: NonEmpty<'A>) (f: NonEmpty<'A> -> 'B) : NonEmpty<'B> =
        extend f w

// ============================================================================
// ZIPPER COMONAD (For navigation)
// ============================================================================

/// List zipper - focused position in a list
type ListZipper<'A> = ListZipper of left: 'A list * focus: 'A * right: 'A list

module ListZipper =
    /// Create from list (focus on first element)
    let ofList (xs: 'A list) : ListZipper<'A> option =
        match xs with
        | [] -> None
        | h :: t -> Some (ListZipper ([], h, t))

    /// Convert to list
    let toList (ListZipper (l, f, r)) = List.rev l @ [f] @ r

    /// Get focused element (extract)
    let extract (ListZipper (_, f, _)) = f

    /// Move left
    let left (ListZipper (l, f, r)) : ListZipper<'A> option =
        match l with
        | [] -> None
        | h :: t -> Some (ListZipper (t, h, f :: r))

    /// Move right
    let right (ListZipper (l, f, r)) : ListZipper<'A> option =
        match r with
        | [] -> None
        | h :: t -> Some (ListZipper (f :: l, h, t))

    /// Update focused element
    let update (a: 'A) (ListZipper (l, _, r)) : ListZipper<'A> =
        ListZipper (l, a, r)

    /// Map over all elements
    let map (f: 'A -> 'B) (ListZipper (l, focus, r)) : ListZipper<'B> =
        ListZipper (List.map f l, f focus, List.map f r)

    /// Duplicate - zipper of zippers (all positions)
    let duplicate (z: ListZipper<'A>) : ListZipper<ListZipper<'A>> =
        let rec allLefts z =
            match left z with
            | None -> []
            | Some z' -> z' :: allLefts z'
        let rec allRights z =
            match right z with
            | None -> []
            | Some z' -> z' :: allRights z'
        ListZipper (allLefts z, z, allRights z)

    /// Extend
    let extend (f: ListZipper<'A> -> 'B) (z: ListZipper<'A>) : ListZipper<'B> =
        duplicate z |> map f

    /// Move to start
    let rec start (z: ListZipper<'A>) : ListZipper<'A> =
        match left z with
        | None -> z
        | Some z' -> start z'

    /// Move to end
    let rec finish (z: ListZipper<'A>) : ListZipper<'A> =
        match right z with
        | None -> z
        | Some z' -> finish z'

    /// Find element
    let rec find (pred: 'A -> bool) (z: ListZipper<'A>) : ListZipper<'A> option =
        if pred (extract z) then Some z
        else
            match right z with
            | None -> None
            | Some z' -> find pred z'

    /// Insert left of focus
    let insertLeft (a: 'A) (ListZipper (l, f, r)) : ListZipper<'A> =
        ListZipper (a :: l, f, r)

    /// Insert right of focus
    let insertRight (a: 'A) (ListZipper (l, f, r)) : ListZipper<'A> =
        ListZipper (l, f, a :: r)

    /// Delete focused (move right if possible, else left)
    let delete (ListZipper (l, _, r)) : ListZipper<'A> option =
        match r, l with
        | h :: t, _ -> Some (ListZipper (l, h, t))
        | [], h :: t -> Some (ListZipper (t, h, []))
        | [], [] -> None

    /// CoKleisli composition
    let (=>>) (w: ListZipper<'A>) (f: ListZipper<'A> -> 'B) : ListZipper<'B> =
        extend f w

/// Tree zipper for navigating tree structures
type TreeZipper<'A> =
    | TreeZipper of
        focus: Tree<'A> *
        context: TreeContext<'A> list

and Tree<'A> =
    | Leaf of 'A
    | Node of 'A * Tree<'A> list

and TreeContext<'A> =
    | Top
    | Context of value: 'A * left: Tree<'A> list * right: Tree<'A> list * parent: TreeContext<'A>

module TreeZipper =
    /// Create zipper from tree
    let ofTree (tree: Tree<'A>) : TreeZipper<'A> =
        TreeZipper (tree, [])

    /// Get focused tree
    let focus (TreeZipper (t, _)) = t

    /// Get focused value (extract)
    let extract (TreeZipper (t, _)) =
        match t with
        | Leaf a -> a
        | Node (a, _) -> a

    /// Go to first child
    let down (TreeZipper (t, ctx)) : TreeZipper<'A> option =
        match t with
        | Leaf _ -> None
        | Node (a, []) -> None
        | Node (a, h :: children) ->
            Some (TreeZipper (h, [Context (a, [], children, List.tryHead ctx |> Option.defaultValue Top)]))

    /// Go to parent
    let up (TreeZipper (t, ctx)) : TreeZipper<'A> option =
        match ctx with
        | [] -> None
        | Top :: _ -> None  // Top indicates root, no parent
        | Context (a, left, right, parent) :: rest ->
            let children = List.rev left @ [t] @ right
            Some (TreeZipper (Node (a, children), rest))

    /// Go to left sibling
    let left' (TreeZipper (t, ctx)) : TreeZipper<'A> option =
        match ctx with
        | [] -> None
        | Top :: _ -> None  // Top indicates root, no left sibling
        | Context (a, [], right, parent) :: _ -> None
        | Context (a, h :: left, right, parent) :: rest ->
            Some (TreeZipper (h, Context (a, left, t :: right, parent) :: rest))

    /// Go to right sibling
    let right' (TreeZipper (t, ctx)) : TreeZipper<'A> option =
        match ctx with
        | [] -> None
        | Top :: _ -> None  // Top indicates root, no right sibling
        | Context (a, left, [], parent) :: _ -> None
        | Context (a, left, h :: right, parent) :: rest ->
            Some (TreeZipper (h, Context (a, t :: left, right, parent) :: rest))

    /// Modify focused tree
    let modify (f: Tree<'A> -> Tree<'A>) (TreeZipper (t, ctx)) : TreeZipper<'A> =
        TreeZipper (f t, ctx)

    /// Replace focused tree
    let replace (t': Tree<'A>) (TreeZipper (_, ctx)) : TreeZipper<'A> =
        TreeZipper (t', ctx)

    /// Map over all values
    let rec mapTree (f: 'A -> 'B) (tree: Tree<'A>) : Tree<'B> =
        match tree with
        | Leaf a -> Leaf (f a)
        | Node (a, children) -> Node (f a, List.map (mapTree f) children)

    let map (f: 'A -> 'B) (TreeZipper (t, _)) : TreeZipper<'B> =
        TreeZipper (mapTree f t, [])  // Note: context is lost in simple map

// ============================================================================
// COMONAD TRANSFORMERS
// ============================================================================

/// EnvT transformer - add environment to any comonad
type EnvT<'E, 'W, 'A> = EnvT of 'E * 'W // Where W is W<A>

module EnvT =
    let ask (EnvT (e, _)) = e
    let lower (EnvT (_, w)) = w

/// StoreT transformer
type StoreT<'S, 'W, 'A> = StoreT of 'W * 'S // Where W is W<S -> A>

/// TracedT transformer
type TracedT<'M, 'W, 'A> = TracedT of 'W // Where W is W<M -> A>

// ============================================================================
// COMONAD UTILITIES
// ============================================================================

module ComonadUtils =
    /// Cokleisli composition
    let (>=>) (f: 'W -> 'B) (g: 'W -> 'C) (extend: ('W -> 'B) -> 'W -> 'W) (w: 'W) : 'C =
        g (extend f w)

    /// Comonad sum (coproduct)
    let cosum (f: 'A -> 'C) (g: 'B -> 'C) : Choice<'A, 'B> -> 'C = function
        | Choice1Of2 a -> f a
        | Choice2Of2 b -> g b

    /// Experiment - run multiple positions through store
    let experiment (positions: 'S -> 'S list) (Store.Store (f, s)) : 'A list =
        positions s |> List.map f

