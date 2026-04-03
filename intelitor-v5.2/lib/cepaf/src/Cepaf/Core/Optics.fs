namespace Cepaf.Core

open System

/// Functional Optics (Lenses, Prisms, Traversals) for immutable data access.
/// Provides composable, type-safe accessors for nested immutable structures.
///
/// WHAT: Lens, Prism, Iso, and Traversal optics for data manipulation
/// WHY: Eliminates boilerplate for nested record updates, enables composition
/// CONSTRAINTS:
///   - SC-FSH-030: Lenses must satisfy get-put and put-get laws
///   - SC-FSH-031: Prisms must satisfy preview-review laws
///   - SC-FSH-032: All optics must be composable
///
/// TDG Compliance:
///   - TDG-FSH-030: Lens laws tested (get-put, put-get)
///   - TDG-FSH-031: Prism laws tested (preview-review)
///
/// AOR Compliance:
///   - AOR-FSH-015: Use optics for nested record updates
module Optics =

    // =========================================================================
    // LENS - Focus on exactly one value
    // =========================================================================

    /// Lens type: Get and Set a value 'A within structure 'S
    type Lens<'S, 'A> = {
        Get: 'S -> 'A
        Set: 'A -> 'S -> 'S
    }

    /// Lens operations
    module Lens =
        /// Create a lens from get/set functions
        let create get set = { Get = get; Set = set }

        /// Get the focused value
        let get (lens: Lens<'S, 'A>) (s: 'S) : 'A = lens.Get s

        /// Set the focused value
        let set (lens: Lens<'S, 'A>) (a: 'A) (s: 'S) : 'S = lens.Set a s

        /// Modify the focused value with a function
        let over (lens: Lens<'S, 'A>) (f: 'A -> 'A) (s: 'S) : 'S =
            lens.Set (f (lens.Get s)) s

        /// Compose two lenses (left to right)
        let compose (outer: Lens<'S, 'A>) (inner: Lens<'A, 'B>) : Lens<'S, 'B> =
            {
                Get = fun s -> inner.Get (outer.Get s)
                Set = fun b s -> outer.Set (inner.Set b (outer.Get s)) s
            }

        /// Composition operator (>>)
        let (>->) outer inner = compose outer inner

        /// Identity lens
        let id<'S> : Lens<'S, 'S> = { Get = id; Set = fun a _ -> a }

        /// First element of a tuple
        let fst<'A, 'B> : Lens<'A * 'B, 'A> =
            { Get = fst; Set = fun a (_, b) -> (a, b) }

        /// Second element of a tuple
        let snd<'A, 'B> : Lens<'A * 'B, 'B> =
            { Get = snd; Set = fun b (a, _) -> (a, b) }

        /// Lens into list element at index (unsafe - use Prism for safe access)
        let atIndex (i: int) : Lens<'A list, 'A> =
            {
                Get = List.item i
                Set = fun a lst ->
                    lst |> List.mapi (fun idx x -> if idx = i then a else x)
            }

        /// Lens into Map value (unsafe - use Prism for safe access)
        let atKey (key: 'K) : Lens<Map<'K, 'V>, 'V> =
            {
                Get = Map.find key
                Set = fun v m -> Map.add key v m
            }

    // =========================================================================
    // PRISM - Focus on zero or one value
    // =========================================================================

    /// Prism type: Optionally focus on a value 'A within 'S
    type Prism<'S, 'A> = {
        Preview: 'S -> 'A option
        Review: 'A -> 'S
    }

    /// Prism operations
    module Prism =
        /// Create a prism from preview/review functions
        let create preview review = { Preview = preview; Review = review }

        /// Try to get the focused value
        let preview (prism: Prism<'S, 'A>) (s: 'S) : 'A option = prism.Preview s

        /// Construct the whole from the part
        let review (prism: Prism<'S, 'A>) (a: 'A) : 'S = prism.Review a

        /// Modify if present
        let over (prism: Prism<'S, 'A>) (f: 'A -> 'A) (s: 'S) : 'S =
            match prism.Preview s with
            | Some a -> prism.Review (f a)
            | None -> s

        /// Set if present
        let set (prism: Prism<'S, 'A>) (a: 'A) (s: 'S) : 'S =
            over prism (fun _ -> a) s

        /// Compose two prisms
        let compose (outer: Prism<'S, 'A>) (inner: Prism<'A, 'B>) : Prism<'S, 'B> =
            {
                Preview = fun s -> outer.Preview s |> Option.bind inner.Preview
                Review = fun b -> outer.Review (inner.Review b)
            }

        /// Composition operator
        let (>?>) outer inner = compose outer inner

        /// Prism for Some case of Option
        let some<'A> : Prism<'A option, 'A> =
            { Preview = id; Review = Some }

        /// Prism for None case (returns unit)
        let none<'A> : Prism<'A option, unit> =
            {
                Preview = function None -> Some () | _ -> None
                Review = fun () -> None
            }

        /// Prism for Ok case of Result
        let ok<'T, 'E> : Prism<Result<'T, 'E>, 'T> =
            {
                Preview = function Ok x -> Some x | Error _ -> None
                Review = Ok
            }

        /// Prism for Error case of Result
        let error<'T, 'E> : Prism<Result<'T, 'E>, 'E> =
            {
                Preview = function Error e -> Some e | Ok _ -> None
                Review = Error
            }

        /// Prism for list head
        let head<'A> : Prism<'A list, 'A> =
            {
                Preview = List.tryHead
                Review = fun a -> [a]
            }

        /// Prism for list element at index
        let atIndex (i: int) : Prism<'A list, 'A> =
            {
                Preview = List.tryItem i
                Review = fun a -> [a]  // Creates single-element list
            }

        /// Prism for Map value at key
        let atKey (key: 'K) : Prism<Map<'K, 'V>, 'V> =
            {
                Preview = Map.tryFind key
                Review = fun v -> Map.ofList [(key, v)]
            }

    // =========================================================================
    // ISO - Bidirectional transformation
    // =========================================================================

    /// Isomorphism: Lossless conversion between 'A and 'B
    type Iso<'A, 'B> = {
        Forward: 'A -> 'B
        Backward: 'B -> 'A
    }

    /// Iso operations
    module Iso =
        /// Create an isomorphism
        let create forward backward = { Forward = forward; Backward = backward }

        /// Apply forward transformation
        let forward (iso: Iso<'A, 'B>) (a: 'A) : 'B = iso.Forward a

        /// Apply backward transformation
        let backward (iso: Iso<'A, 'B>) (b: 'B) : 'A = iso.Backward b

        /// Reverse the isomorphism
        let reverse (iso: Iso<'A, 'B>) : Iso<'B, 'A> =
            { Forward = iso.Backward; Backward = iso.Forward }

        /// Compose two isomorphisms
        let compose (ab: Iso<'A, 'B>) (bc: Iso<'B, 'C>) : Iso<'A, 'C> =
            {
                Forward = ab.Forward >> bc.Forward
                Backward = bc.Backward >> ab.Backward
            }

        /// Composition operator
        let (<->) ab bc = compose ab bc

        /// Identity isomorphism
        let id<'A> : Iso<'A, 'A> = { Forward = id; Backward = id }

        /// Iso between tuples (swap)
        let swap<'A, 'B> : Iso<'A * 'B, 'B * 'A> =
            {
                Forward = fun (a, b) -> (b, a)
                Backward = fun (b, a) -> (a, b)
            }

        /// Iso between string and char array
        let stringChars : Iso<string, char array> =
            {
                Forward = fun s -> s.ToCharArray()
                Backward = fun (cs: char array) -> System.String(cs)
            }

        /// Iso between list and array
        let listArray<'A> : Iso<'A list, 'A array> =
            { Forward = List.toArray; Backward = Array.toList }

        /// Convert Iso to Lens
        let toLens (iso: Iso<'S, 'A>) : Lens<'S, 'A> =
            { Get = iso.Forward; Set = fun a _ -> iso.Backward a }

        /// Convert Iso to Prism (always succeeds)
        let toPrism (iso: Iso<'S, 'A>) : Prism<'S, 'A> =
            { Preview = iso.Forward >> Some; Review = iso.Backward }

    // =========================================================================
    // TRAVERSAL - Focus on multiple values
    // =========================================================================

    /// Traversal: Focus on zero or more values of type 'A within 'S
    type Traversal<'S, 'A> = {
        /// Get all focused values
        ToList: 'S -> 'A list
        /// Modify all focused values
        Over: ('A -> 'A) -> 'S -> 'S
    }

    /// Traversal operations
    module Traversal =
        /// Create a traversal
        let create toList over = { ToList = toList; Over = over }

        /// Get all focused values
        let toList (trav: Traversal<'S, 'A>) (s: 'S) : 'A list = trav.ToList s

        /// Modify all focused values
        let over (trav: Traversal<'S, 'A>) (f: 'A -> 'A) (s: 'S) : 'S = trav.Over f s

        /// Set all focused values
        let set (trav: Traversal<'S, 'A>) (a: 'A) (s: 'S) : 'S =
            over trav (fun _ -> a) s

        /// Compose traversals
        let compose (outer: Traversal<'S, 'A>) (inner: Traversal<'A, 'B>) : Traversal<'S, 'B> =
            {
                ToList = fun s -> outer.ToList s |> List.collect inner.ToList
                Over = fun f -> outer.Over (inner.Over f)
            }

        /// Composition operator
        let (>*>) outer inner = compose outer inner

        /// Traversal over list elements
        let each<'A> : Traversal<'A list, 'A> =
            { ToList = id; Over = List.map }

        /// Traversal over array elements
        let eachArray<'A> : Traversal<'A array, 'A> =
            { ToList = Array.toList; Over = Array.map }

        /// Traversal over Map values
        let eachValue<'K, 'V when 'K: comparison> : Traversal<Map<'K, 'V>, 'V> =
            {
                ToList = Map.toList >> List.map snd
                Over = fun f m -> Map.map (fun _ v -> f v) m
            }

        /// Traversal over Option value
        let optional<'A> : Traversal<'A option, 'A> =
            {
                ToList = Option.toList
                Over = Option.map
            }

        /// Filter traversal by predicate
        let filtered (pred: 'A -> bool) (trav: Traversal<'S, 'A>) : Traversal<'S, 'A> =
            {
                ToList = fun s -> trav.ToList s |> List.filter pred
                Over = fun f -> trav.Over (fun a -> if pred a then f a else a)
            }

        /// Convert Lens to Traversal
        let fromLens (lens: Lens<'S, 'A>) : Traversal<'S, 'A> =
            { ToList = lens.Get >> List.singleton; Over = Lens.over lens }

        /// Convert Prism to Traversal
        let fromPrism (prism: Prism<'S, 'A>) : Traversal<'S, 'A> =
            { ToList = prism.Preview >> Option.toList; Over = Prism.over prism }

    // =========================================================================
    // OPTIC COMBINATORS
    // =========================================================================

    /// Combine lens and prism (creates an AffineTraversal, simplified as Prism)
    /// Note: Review requires a default 'S since lens modification needs existing structure
    let lensAndPrism (defaultS: 'S) (lens: Lens<'S, 'A>) (prism: Prism<'A, 'B>) : Prism<'S, 'B> =
        {
            Preview = fun s -> prism.Preview (lens.Get s)
            Review = fun b -> lens.Set (prism.Review b) defaultS
        }

    /// Combine prism and lens (creates an AffineTraversal, simplified as Prism)
    /// Note: Review requires a default 'A since we need to construct intermediate value
    let prismAndLens (defaultA: 'A) (prism: Prism<'S, 'A>) (lens: Lens<'A, 'B>) : Prism<'S, 'B> =
        {
            Preview = fun s -> prism.Preview s |> Option.map lens.Get
            Review = fun b -> prism.Review (lens.Set b defaultA)
        }

    // =========================================================================
    // RECORD LENS HELPERS
    // =========================================================================

    /// Create lens for record field (inline helper)
    module RecordLens =
        /// Helper to create lenses for records with { r with field = value } syntax
        let inline field (getter: 'R -> 'F) (setter: 'F -> 'R -> 'R) : Lens<'R, 'F> =
            { Get = getter; Set = setter }

    // =========================================================================
    // VIEW PATTERN HELPERS
    // =========================================================================

    /// View the structure through a lens
    let view (lens: Lens<'S, 'A>) = Lens.get lens

    /// Preview the structure through a prism
    let preview (prism: Prism<'S, 'A>) = Prism.preview prism

    /// Modify through any optic
    let modify (lens: Lens<'S, 'A>) = Lens.over lens

    /// Set through any optic
    let setL (lens: Lens<'S, 'A>) = Lens.set lens

    // =========================================================================
    // COMMON LENS DEFINITIONS
    // =========================================================================

    /// Lenses for common types
    module CommonLenses =
        /// Lens for string length (read-only effectively)
        let stringLength : Lens<string, int> =
            {
                Get = String.length
                Set = fun len s ->
                    if len < s.Length then s.Substring(0, len)
                    else s.PadRight(len)
            }

        /// Lens for list length via padding/truncating
        let listLength<'A> (defaultValue: 'A) : Lens<'A list, int> =
            {
                Get = List.length
                Set = fun len lst ->
                    if len < lst.Length then List.take len lst
                    else lst @ List.replicate (len - lst.Length) defaultValue
            }
